#!/usr/bin/env bash
#
# complete-task.sh - Mark a task as complete and move it to COMPLETED.md
#
# Usage: complete-task.sh <task-id>
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: $0 <task-id>"
    echo ""
    echo "Marks a task as complete and moves it from TODO.md to COMPLETED.md"
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

# Validate task ID
if [[ $# -ne 1 ]]; then
    usage
fi

TASK_ID="$1"

if ! [[ "$TASK_ID" =~ ^[0-9]+$ ]]; then
    log_error "Task ID must be a number"
    exit 1
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
    echo "$content" | grep -E "^\| \*\*$field\*\* \|" | sed -E 's/\| \*\*'$field'\*\* \| //;s/ \|//;s/^ //'
}

# Update field value
update_field() {
    local content="$1"
    local field="$2"
    local value="$3"
    
    echo "$content" | sed -E "s/(\| \*\*$field\*\* \| ).*( \|)/\1$value\2/"
}

# Get current date in ISO format
get_date() {
    date +%Y-%m-%d
}

# Get current month header
get_month_header() {
    date +"%Y-%m (%B %Y)"
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
    
    # Extract task content
    local task_content
    task_content=$(extract_task "$task_file" "$TASK_ID")
    
    if [[ -z "$task_content" ]]; then
        log_error "Could not extract task content"
        exit 1
    fi
    
    # Get task metadata
    local title status priority created
    title=$(echo "$task_content" | grep -E "^### [0-9]+\." | sed -E 's/^### [0-9]+\. //')
    status=$(get_field "$task_content" "status")
    priority=$(get_field "$task_content" "priority")
    created=$(get_field "$task_content" "created")
    
    log_info "Task: $title"
    log_info "Current status: $status"
    
    # Determine COMPLETED.md path
    local completed_file
    completed_file="$(dirname "$task_file")/COMPLETED.md"
    
    # Update task content
    local updated_content
    updated_content=$(update_field "$task_content" "status" "complete")
    updated_content=$(echo "$updated_content" | update_field - "completed" "$(get_date)")
    
    # If created field doesn't exist, add it
    if [[ -z "$created" ]]; then
        # Add created field after priority
        updated_content=$(echo "$updated_content" | sed -E "/\| \*\*priority\*\* \|/a | **created** | $(get_date) |")
    fi
    
    log_info "Moving to: $completed_file"
    
    # Create COMPLETED.md if it doesn't exist
    if [[ ! -f "$completed_file" ]]; then
        log_info "Creating new COMPLETED.md file"
        cat > "$completed_file" << 'EOF'
<!--
COMPLETED.md - Completed Tasks

⚠️ IMPORTANT: This file is APPEND-ONLY at the top.
Newest completed tasks go in "## Current Month" section.
See SKILL.md for completion workflow.
-->

# Completed Tasks

**Stats**: 0 total

---

## Current Month

<!-- New completed tasks go HERE (at the top) -->

---

## Previous Months

EOF
    fi
    
    # Check if task already exists in COMPLETED.md
    if grep -q "<!-- TASK:$TASK_ID -->" "$completed_file"; then
        log_warn "Task $TASK_ID already exists in COMPLETED.md"
        log_warn "Replacing with updated version"
        # Remove existing task
        local temp_file
        temp_file=$(mktemp)
        awk -v id="$TASK_ID" '
            $0 ~ "<!-- TASK:" id " -->" { skip=1 }
            $0 ~ "<!-- END TASK:" id " -->" { skip=0; next }
            !skip { print }
        ' "$completed_file" > "$temp_file"
        mv "$temp_file" "$completed_file"
    fi
    
    # Insert task at top of "## Current Month" section
    local temp_file
    temp_file=$(mktemp)
    
    # Find the line after "## Current Month" and before the comment
    awk -v content="$updated_content" '
        /^## Current Month$/ {
            print
            getline
            if (/<!-- New completed tasks go HERE/) {
                print
                print ""
                # Insert the task
                print content
                print ""
            }
            next
        }
        { print }
    ' "$completed_file" > "$temp_file"
    
    mv "$temp_file" "$completed_file"
    
    # Remove task from TODO.md
    local temp_todo
    temp_todo=$(mktemp)
    awk -v id="$TASK_ID" '
        $0 ~ "<!-- TASK:" id " -->" { skip=1 }
        $0 ~ "<!-- END TASK:" id " -->" { skip=0; next }
        !skip { print }
    ' "$task_file" > "$temp_todo"
    
    mv "$temp_todo" "$task_file"
    
    log_info "Task $TASK_ID moved to COMPLETED.md"
    
    # Regenerate Quick Reference
    log_info "Regenerating Quick Reference..."
    "$SCRIPT_DIR/regenerate-qr.sh" "$task_file" 2>/dev/null || log_warn "Failed to regenerate Quick Reference"
    
    # Validate
    log_info "Running validation..."
    if "$SCRIPT_DIR/validate-todos.py" 2>/dev/null; then
        log_info "✓ Task $TASK_ID successfully completed and validated!"
    else
        log_warn "Validation found issues - run 'validate-todos.py' for details"
    fi
}

main
