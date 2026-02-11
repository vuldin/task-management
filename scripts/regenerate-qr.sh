#!/usr/bin/env bash
#
# regenerate-qr.sh - Regenerate Quick Reference table in TODO.md files
#
# Usage: regenerate-qr.sh <file> | regenerate-qr.sh --all
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 <TODO.md-file>"
    echo "       $0 --all"
    echo ""
    echo "Regenerates the Quick Reference table from task metadata"
    exit 1
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

# Extract all tasks from file and build QR table
generate_qr() {
    local file="$1"
    
    # Extract tasks and their metadata
    awk '
        /<!-- TASK:[0-9]+ -->/ {
            match($0, /<!-- TASK:([0-9]+) -->/, arr)
            task_id = arr[1]
            in_task = 1
            next
        }
        /<!-- END TASK:[0-9]+ -->/ {
            in_task = 0
            task_id = ""
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
                # Only output active tasks (not complete)
                if (statuses[id] != "complete") {
                    # Sort by priority: critical=1, high=2, medium=3, low=4
                    priority_order = 4
                    if (priorities[id] == "critical") priority_order = 1
                    else if (priorities[id] == "high") priority_order = 2
                    else if (priorities[id] == "medium") priority_order = 3
                    
                    printf "%d|%d|%s|%s|%s\n", priority_order, id, id, titles[id], statuses[id], priorities[id]
                }
            }
        }
    ' "$file" | sort -t'|' -k1,1n -k2,2n | cut -d'|' -f3-
}

# Regenerate QR for a single file
regenerate_file() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        echo "Error: File not found: $file"
        return 1
    fi
    
    # Check if file has QR markers
    if ! grep -q "<!-- QR-START" "$file"; then
        echo "Warning: $file missing QR-START marker, skipping"
        return 0
    fi
    
    # Generate new QR content
    local qr_content
    qr_content=$(generate_qr "$file")
    
    # Build new QR section
    local temp_file
    temp_file=$(mktemp)
    
    {
        echo "<!-- QR-START (AUTO-GENERATED - DO NOT EDIT) -->"
        echo ""
        echo "| ID | Title | Status | Priority |"
        echo "|----|-------|--------|----------|"
        
        if [[ -n "$qr_content" ]]; then
            echo "$qr_content" | while IFS='|' read -r id title status priority; do
                local status_emoji priority_emoji
                status_emoji=$(status_emoji "$status")
                priority_emoji=$(priority_emoji "$priority")
                
                # Truncate long titles
                if [[ ${#title} -gt 40 ]]; then
                    title="${title:0:37}..."
                fi
                
                printf "| %s | %s | %s %s | %s %s |\n" "$id" "$title" "$status_emoji" "${status^}" "$priority_emoji" "${priority^}"
            done
        fi
        
        echo ""
        echo "<!-- QR-END -->"
    } > "$temp_file"
    
    # Replace QR section in file
    local final_file
    final_file=$(mktemp)
    
    awk -v qr_file="$temp_file" '
        /<!-- QR-START/,/<!-- QR-END/ {
            if (!replaced) {
                while ((getline line < qr_file) > 0) {
                    print line
                }
                close(qr_file)
                replaced = 1
            }
            next
        }
        { print }
    ' "$file" > "$final_file"
    
    mv "$final_file" "$file"
    rm "$temp_file"
    
    local task_count
    task_count=$(echo "$qr_content" | grep -c '^' || true)
    echo "✓ Regenerated Quick Reference for $file ($task_count active tasks)"
}

# Main
main() {
    if [[ $# -eq 0 ]]; then
        usage
    fi
    
    if [[ "$1" == "--all" ]]; then
        local root_dir
        root_dir="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
        
        find "$root_dir" -maxdepth 3 -name "TODO.md" -type f 2>/dev/null | while read -r file; do
            regenerate_file "$file"
        done
    else
        regenerate_file "$1"
    fi
}

main "$@"
