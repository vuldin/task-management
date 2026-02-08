#!/usr/bin/env bash
#
# list-tasks.sh - List tasks from all TODO.md files
#
# Usage: list-tasks.sh [--include-completed]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INCLUDE_COMPLETED=0

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --include-completed) INCLUDE_COMPLETED=1 ;;
        *) ;;
    esac
    shift
done

# Find project root and task files
find_task_files() {
    local root_dir
    root_dir="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
    find "$root_dir" -maxdepth 3 -name "TODO.md" -type f 2>/dev/null | sort
}

# Emoji mappings
status_emoji() {
    case "$1" in
        pending) echo "📋" ;;
        in_progress) echo "🟡" ;;
        blocked) echo "🚫" ;;
        complete) echo "✅" ;;
        *) echo "❓" ;;
    esac
}

priority_emoji() {
    case "$1" in
        critical) echo "🔴" ;;
        high) echo "🟠" ;;
        medium) echo "🟡" ;;
        low) echo "🟢" ;;
        *) echo "⚪" ;;
    esac
}

# Get project name from file path
get_project_name() {
    local file="$1"
    local dir
    dir=$(dirname "$file")
    
    if [[ "$dir" == "." ]] || [[ "$dir" == "$PWD" ]]; then
        echo "Root"
    else
        basename "$dir" | tr '-' ' ' | sed -E 's/\b\w/\u&/g'
    fi
}

# Extract tasks from file
extract_tasks() {
    local file="$1"
    local include_completed="$2"
    
    awk -v include_completed="$include_completed" '
        /<!-- TASK:[0-9]+ -->/ {
            match($0, /<!-- TASK:([0-9]+) -->/, arr)
            task_id = arr[1]
            in_task = 1
            next
        }
        /<!-- END TASK:[0-9]+ -->/ {
            in_task = 0
            next
        }
        in_task && /^### [0-9]+\./ {
            gsub(/^### /, "")
            gsub(/^[0-9]+\. /, "")
            titles[task_id] = $0
        }
        in_task && /\*\*id\*\*/ {
            gsub(/.*\| /, "")
            gsub(/ \|/, "")
            ids[task_id] = $0
        }
        in_task && /\*\*status\*\*/ {
            gsub(/.*\| /, "")
            gsub(/ \|/, "")
            statuses[task_id] = $0
        }
        in_task && /\*\*priority\*\*/ {
            gsub(/.*\| /, "")
            gsub(/ \|/, "")
            priorities[task_id] = $0
        }
        END {
            for (id in ids) {
                # Filter completed unless requested
                if (include_completed || statuses[id] != "complete") {
                    # Sort by priority: critical=1, high=2, medium=3, low=4
                    priority_order = 4
                    if (priorities[id] == "critical") priority_order = 1
                    else if (priorities[id] == "high") priority_order = 2
                    else if (priorities[id] == "medium") priority_order = 3
                    
                    printf "%d|%d|%s|%s|%s|%s\n", priority_order, id, id, titles[id], statuses[id], priorities[id]
                }
            }
        }
    ' "$file" | sort -t'|' -k1,1n -k2,2n | cut -d'|' -f3-
}

# Show tasks for a file
show_file_tasks() {
    local file="$1"
    local project_name
    project_name=$(get_project_name "$file")
    
    echo "## $project_name"
    echo ""
    echo "| ID | Title | Status | Priority |"
    echo "|----|-------|--------|----------|"
    
    local tasks
    tasks=$(extract_tasks "$file" "$INCLUDE_COMPLETED")
    
    if [[ -n "$tasks" ]]; then
        echo "$tasks" | while IFS='|' read -r id title status priority; do
            local status_emoji priority_emoji
            status_emoji=$(status_emoji "$status")
            priority_emoji=$(priority_emoji "$priority")
            
            # Truncate long titles
            if [[ ${#title} -gt 45 ]]; then
                title="${title:0:42}..."
            fi
            
            # Capitalize first letter
            local status_cap priority_cap
            status_cap=$(echo "$status" | sed -E 's/^(.)/\u\1/;s/_/ /')
            priority_cap=$(echo "$priority" | sed -E 's/^(.)/\u\1/')
            
            printf "| %s | %s | %s %s | %s %s |\n" "$id" "$title" "$status_emoji" "$status_cap" "$priority_emoji" "$priority_cap"
        done
    else
        echo "| - | No tasks | - | - |"
    fi
    
    echo ""
}

# Main
main() {
    local files
    files=$(find_task_files)
    
    if [[ -z "$files" ]]; then
        echo "No TODO.md files found"
        exit 1
    fi
    
    # Show each project's tasks
    for file in $files; do
        show_file_tasks "$file"
    done
    
    # Summary
    local total_active=0
    local total_completed=0
    local highest_id=0
    
    while IFS= read -r file; do
        local file_active file_completed file_max
        file_active=$(extract_tasks "$file" 0 | wc -l)
        file_completed=$(extract_tasks "$file" 1 | grep -c "complete" || true)
        file_max=$(grep -oE '<!-- TASK:[0-9]+ -->' "$file" 2>/dev/null | sed 's/<!-- TASK://;s/ -->//' | sort -n | tail -1 || echo "0")
        
        total_active=$((total_active + file_active))
        total_completed=$((total_completed + file_completed))
        
        if [[ "$file_max" -gt "$highest_id" ]]; then
            highest_id=$file_max
        fi
    done <<< "$files"
    
    # Also check COMPLETED.md files for highest ID
    local root_dir
    root_dir="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
    while IFS= read -r file; do
        local file_max
        file_max=$(grep -oE '<!-- TASK:[0-9]+ -->' "$file" 2>/dev/null | sed 's/<!-- TASK://;s/ -->//' | sort -n | tail -1 || echo "0")
        if [[ "$file_max" -gt "$highest_id" ]]; then
            highest_id=$file_max
        fi
    done < <(find "$root_dir" -maxdepth 3 -name "COMPLETED.md" -type f 2>/dev/null)
    
    echo "---------------------------------------------------------------------"
    if [[ $INCLUDE_COMPLETED -eq 1 ]]; then
        echo "$((total_active + total_completed)) tasks total ($total_active active, $total_completed completed)"
    else
        echo "$total_active active tasks across all projects"
    fi
    echo "Next available task ID: $((highest_id + 1))"
    echo ""
}

main
