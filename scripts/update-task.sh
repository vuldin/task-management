#!/usr/bin/env bash
#
# update-task.sh - Update fields on an existing task in TODO.md
#
# Usage: update-task.sh <task-id> [--status <v>] [--priority <v>] [--title <v>]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <task-id> [--status <v>] [--priority <v>] [--title <v>]"
    echo ""
    echo "Update fields on an existing task."
    echo ""
    echo "Options:"
    echo "  --status    Set status (pending, in_progress, blocked)"
    echo "  --priority  Set priority (critical, high, medium, low)"
    echo "  --title     Set task title"
    echo ""
    echo "Examples:"
    echo "  $0 3 --status in_progress"
    echo "  $0 7 --priority critical --title 'Urgent fix'"
    echo ""
    echo "Note: Use complete-task.sh to mark a task as complete."
    exit 1
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate args
if [[ $# -lt 2 ]]; then
    usage
fi

TASK_ID="$1"
shift

if ! [[ "$TASK_ID" =~ ^[0-9]+$ ]]; then
    log_error "Task ID must be a number"
    exit 1
fi

# Parse flags
NEW_STATUS=""
NEW_PRIORITY=""
NEW_TITLE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --status)
            [[ $# -lt 2 ]] && { log_error "--status requires a value"; exit 1; }
            NEW_STATUS="$2"
            shift 2
            ;;
        --priority)
            [[ $# -lt 2 ]] && { log_error "--priority requires a value"; exit 1; }
            NEW_PRIORITY="$2"
            shift 2
            ;;
        --title)
            [[ $# -lt 2 ]] && { log_error "--title requires a value"; exit 1; }
            NEW_TITLE="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            ;;
    esac
done

# Must provide at least one flag
if [[ -z "$NEW_STATUS" && -z "$NEW_PRIORITY" && -z "$NEW_TITLE" ]]; then
    log_error "At least one of --status, --priority, or --title must be provided"
    usage
fi

# Validate enum values
if [[ -n "$NEW_STATUS" ]]; then
    if [[ "$NEW_STATUS" == "complete" ]]; then
        log_error "Use complete-task.sh to mark a task as complete"
        exit 1
    fi
    if [[ "$NEW_STATUS" != "pending" && "$NEW_STATUS" != "in_progress" && "$NEW_STATUS" != "blocked" ]]; then
        log_error "Invalid status '$NEW_STATUS'. Allowed: pending, in_progress, blocked"
        exit 1
    fi
fi

if [[ -n "$NEW_PRIORITY" ]]; then
    if [[ "$NEW_PRIORITY" != "critical" && "$NEW_PRIORITY" != "high" && "$NEW_PRIORITY" != "medium" && "$NEW_PRIORITY" != "low" ]]; then
        log_error "Invalid priority '$NEW_PRIORITY'. Allowed: critical, high, medium, low"
        exit 1
    fi
fi

# Find the task in TODO.md files
find_task_file() {
    local root_dir
    root_dir="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

    find "$root_dir" -maxdepth 3 -name "TODO.md" -type f 2>/dev/null | while read -r file; do
        if grep -q "<!-- TASK:$TASK_ID -->" "$file"; then
            echo "$file"
            return
        fi
    done
}

# Extract task content
extract_task() {
    local file="$1"
    local id="$2"

    awk -v task_id="$id" '
        $0 ~ "<!-- TASK:" task_id " -->" {
            in_task = 1
            print
            next
        }
        $0 ~ "<!-- END TASK:" task_id " -->" {
            print
            in_task = 0
            exit
        }
        in_task { print }
    ' "$file"
}

# Get field value from task
get_field() {
    local content="$1"
    local field="$2"
    echo "$content" | grep -E "^\| \*\*$field\*\* \|" | sed -E 's/\| \*\*'"$field"'\*\* \| //;s/ \|//;s/^ //'
}

# Main
main() {
    log_info "Looking for task $TASK_ID..."

    local task_file
    task_file=$(find_task_file)

    if [[ -z "$task_file" ]]; then
        log_error "Task $TASK_ID not found in any TODO.md file"
        exit 1
    fi

    log_info "Found task in: $task_file"

    # Extract task content for before/after display
    local task_content
    task_content=$(extract_task "$task_file" "$TASK_ID")

    if [[ -z "$task_content" ]]; then
        log_error "Could not extract task content"
        exit 1
    fi

    # Get current values
    local old_title old_status old_priority
    old_title=$(echo "$task_content" | grep -E "^### [0-9]+\." | sed -E 's/^### [0-9]+\. //')
    old_status=$(get_field "$task_content" "status")
    old_priority=$(get_field "$task_content" "priority")

    log_info "Task: $old_title"

    # Apply updates via awk
    local temp_file
    temp_file=$(mktemp)

    awk -v task_id="$TASK_ID" \
        -v new_status="$NEW_STATUS" \
        -v new_priority="$NEW_PRIORITY" \
        -v new_title="$NEW_TITLE" '
        $0 ~ "<!-- TASK:" task_id " -->" { in_task = 1 }
        $0 ~ "<!-- END TASK:" task_id " -->" { in_task = 0 }

        in_task && new_title != "" && $0 ~ "^### " task_id "\\." {
            printf "### %s. %s\n", task_id, new_title
            next
        }
        in_task && new_status != "" && /\| \*\*status\*\* \|/ {
            printf "| **status** | %s |\n", new_status
            next
        }
        in_task && new_priority != "" && /\| \*\*priority\*\* \|/ {
            printf "| **priority** | %s |\n", new_priority
            next
        }
        { print }
    ' "$task_file" > "$temp_file"

    mv "$temp_file" "$task_file"

    # Show before/after
    echo ""
    if [[ -n "$NEW_STATUS" && "$NEW_STATUS" != "$old_status" ]]; then
        log_info "Status: $old_status → $NEW_STATUS"
    fi
    if [[ -n "$NEW_PRIORITY" && "$NEW_PRIORITY" != "$old_priority" ]]; then
        log_info "Priority: $old_priority → $NEW_PRIORITY"
    fi
    if [[ -n "$NEW_TITLE" && "$NEW_TITLE" != "$old_title" ]]; then
        log_info "Title: $old_title → $NEW_TITLE"
    fi

    # Regenerate Quick Reference
    log_info "Regenerating Quick Reference..."
    "$SCRIPT_DIR/regenerate-qr.sh" "$task_file" 2>/dev/null || log_warn "Failed to regenerate Quick Reference"

    # Validate
    log_info "Running validation..."
    if "$SCRIPT_DIR/validate-todos.py" 2>/dev/null; then
        log_info "✓ Task $TASK_ID successfully updated and validated!"
    else
        log_warn "Validation found issues - run 'validate-todos.py' for details"
    fi
}

main
