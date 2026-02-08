#!/usr/bin/env bash
#
# next-id.sh - Find the next available task ID
#
# Usage: next-id.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Find all task IDs from TODO.md and COMPLETED.md files
find_all_ids() {
    local root_dir
    root_dir="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
    
    find "$root_dir" -maxdepth 3 \( -name "TODO.md" -o -name "COMPLETED.md" \) -type f 2>/dev/null | \
        xargs grep -h "<!-- TASK:" 2>/dev/null | \
        sed -E 's/.*<!-- TASK:([0-9]+) -->.*/\1/' | \
        sort -n
}

# Get the next ID
get_next_id() {
    local max_id
    max_id=$(find_all_ids | tail -1)
    
    if [[ -z "$max_id" ]]; then
        echo "1"
    else
        echo $((max_id + 1))
    fi
}

# Show some stats
show_stats() {
    local root_dir
    root_dir="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
    
    local total_tasks=0
    local completed_tasks=0
    local active_tasks=0
    
    while IFS= read -r file; do
        local file_tasks
        file_tasks=$(grep -c "<!-- TASK:" "$file" 2>/dev/null || echo "0")
        total_tasks=$((total_tasks + file_tasks))
        
        if [[ "$file" == *"/COMPLETED.md" ]]; then
            completed_tasks=$((completed_tasks + file_tasks))
        else
            active_tasks=$((active_tasks + file_tasks))
        fi
    done < <(find "$root_dir" -maxdepth 3 \( -name "TODO.md" -o -name "COMPLETED.md" \) -type f 2>/dev/null)
    
    echo "Task Statistics:"
    echo "  Total tasks: $total_tasks"
    echo "  Active tasks: $active_tasks"
    echo "  Completed tasks: $completed_tasks"
}

# Main
main() {
    local next_id
    next_id=$(get_next_id)
    
    echo "Next available task ID: $next_id"
    echo ""
    show_stats
}

main
