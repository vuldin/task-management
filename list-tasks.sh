#!/bin/sh
# Script to list all active tasks across Drasil MVP4 projects
# Dynamically discovers all TODO.md files in subdirectories
# Usage: ./list-tasks.sh (from project root)

# Function to extract and display tasks from a TODO.md file
show_section() {
  _name="$1"
  _file="$2"
  [ -f "$_file" ] || return
  printf '\n## %s\n\n' "$_name"
  printf '| ID | Title | Status | Priority |\n'
  printf '|----|-------|--------|----------|\n'
  awk '/## Quick Reference/{qr=1; next} /## Detailed Task Descriptions/{qr=0} qr && /^\| [0-9]+ \|/ && !/ID.*Title/ {
    gsub(/^\|[ \t]*/, ""); gsub(/[ \t]*\|$/, "")
    split($0, p, /\s*\|\s*/)
    # Filter out completed tasks based on Status column (p[3])
    if (p[3] ~ /Complete/ || p[3] ~ /✅/ || p[3] ~ /Done/) next
    if (p[4] ~ /Critical/) ord=1; else if (p[4] ~ /High/) ord=2; else if (p[4] ~ /Medium/) ord=3; else ord=4
    printf "%d|%04d|%s|%s|%s|%s\n", ord, p[1], p[1], p[2], p[3], p[4]
  }' "$_file" | sort -t'|' -k1,1n -k2,2n | cut -d'|' -f3- | while IFS='|' read -r id title status priority; do
    printf '| %s | %s | %s | %s |\n' "$id" "$title" "$status" "$priority"
  done
}

# Main output

# First, show root TODO.md if it exists
if [ -f "TODO.md" ]; then
  show_section "Root" "TODO.md"
fi

# Then dynamically discover all subdirectories with TODO.md files
find . -mindepth 2 -name "TODO.md" -type f 2>/dev/null | \
  grep -v node_modules | \
  grep -v target | \
  grep -v dist | \
  grep -v build | \
  grep -v ".git" | \
  sort | \
  while read -r todo_file; do
    # Get the directory name (e.g., ./cli/TODO.md -> cli)
    dir=$(dirname "$todo_file" | sed 's|^\./||')
    show_section "$dir" "$todo_file"
  done

# Summary
printf "\n"
printf '%s\n' "---------------------------------------------------------------------"
cnt=$(find . -name "TODO.md" -exec awk '/## Detailed Task Descriptions/{exit} /^\| [0-9]+ \|/ && !/ID.*Title/ {
  split($0, p, /\s*\|\s*/)
  if (p[4] ~ /Complete/ || p[4] ~ /✅/ || p[4] ~ /Done/) next
  print
}' {} \; 2>/dev/null | wc -l)
next=$(find . -name "TODO.md" -exec grep -h "^###\+ [0-9]" {} + 2>/dev/null | sed 's/.*### \([0-9]*\).*/\1/' | sort -n | tail -1)
printf "%s active tasks across all projects.\n" "$cnt"
printf "Next available task ID: %s\n\n" "$((next + 1))"
