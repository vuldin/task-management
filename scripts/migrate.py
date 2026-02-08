#!/usr/bin/env python3
"""
Migration script for TODO.md files from old format to new strict format.
"""

import re
import os
import sys
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional, Tuple

# Color codes for output
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
NC = '\033[0m'

def log_info(msg: str):
    print(f"{GREEN}[INFO]{NC} {msg}")

def log_warn(msg: str):
    print(f"{YELLOW}[WARN]{NC} {msg}")

def log_error(msg: str):
    print(f"{RED}[ERROR]{NC} {msg}")

def log_debug(msg: str):
    pass  # Only used when verbose

def find_todo_files(root_dir: Path) -> List[Path]:
    """Find all TODO.md files in the project."""
    todos = []
    for todo in root_dir.rglob("TODO.md"):
        # Skip node_modules and target
        if "node_modules" in str(todo) or "target" in str(todo):
            continue
        if len(todo.relative_to(root_dir).parts) <= 3:
            todos.append(todo)
    return sorted(todos)

def normalize_status(status: str) -> str:
    """Normalize status to allowed values."""
    status = status.lower().strip()
    
    # Remove emoji prefixes
    status = re.sub(r'^[📋🟡🚫✅]\s*', '', status)
    
    if 'pending' in status or 'not started' in status:
        return 'pending'
    elif 'in progress' in status or 'progress' in status:
        return 'in_progress'
    elif 'blocked' in status or 'block' in status:
        return 'blocked'
    elif 'complete' in status or 'done' in status:
        return 'complete'
    else:
        return 'pending'

def normalize_priority(priority: str) -> str:
    """Normalize priority to allowed values."""
    priority = priority.lower().strip()
    
    # Remove emoji prefixes
    priority = re.sub(r'^[🔴🟠🟡🟢]\s*', '', priority)
    
    if 'critical' in priority:
        return 'critical'
    elif 'high' in priority:
        return 'high'
    elif 'medium' in priority:
        return 'medium'
    elif 'low' in priority:
        return 'low'
    else:
        return 'medium'

def extract_date(text: str) -> Optional[str]:
    """Extract date from text."""
    # Look for YYYY-MM-DD format
    match = re.search(r'\d{4}-\d{2}-\d{2}', text)
    if match:
        return match.group(0)
    
    # Look for "Feb 5" or "Feb 5, 2026" format
    month_map = {
        'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04',
        'may': '05', 'jun': '06', 'jul': '07', 'aug': '08',
        'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12'
    }
    match = re.search(r'(\w{3})\s+(\d{1,2})(?:,\s+(\d{4}))?', text, re.IGNORECASE)
    if match:
        month = month_map.get(match.group(1).lower(), '01')
        day = int(match.group(2))
        year = match.group(3) or '2026'
        return f"{year}-{month}-{day:02d}"
    
    return None

class Task:
    def __init__(self, task_id: int, title: str, content: str):
        self.id = task_id
        self.title = title
        self.content = content
        self.status = 'pending'
        self.priority = 'medium'
        self.created = datetime.now().strftime('%Y-%m-%d')
        self.completed = None
        self.description = ""
        self.progress = ""
        self.files = ""
        self.notes = ""
        self._parse()
    
    def _parse(self):
        """Parse task content to extract metadata."""
        lines = self.content.split('\n')
        
        # Extract status
        for line in lines:
            if re.match(r'\*\*[Ss]tatus\*\*[:\s]+', line):
                status_text = re.sub(r'\*\*[Ss]tatus\*\*[:\s]+', '', line).strip()
                self.status = normalize_status(status_text)
                break
        
        # Extract priority
        for line in lines:
            if re.match(r'\*\*[Pp]riority\*\*[:\s]+', line):
                priority_text = re.sub(r'\*\*[Pp]riority\*\*[:\s]+', '', line).strip()
                self.priority = normalize_priority(priority_text)
                break
        
        # Extract completed date
        for line in lines:
            if re.match(r'\*\*[Cc]ompleted\*\*[:\s]+', line):
                completed_text = re.sub(r'\*\*[Cc]ompleted\*\*[:\s]+', '', line).strip()
                self.completed = extract_date(completed_text)
                break
        
        # Extract description (everything between title/metadata and other sections)
        in_description = False
        description_lines = []
        
        for line in lines[1:]:  # Skip title line
            # Skip empty lines at start
            if not in_description and not line.strip():
                continue
            
            # Check for section headers
            if re.match(r'\*\*(Progress|Files|Notes|Acceptance|Depends|Location|Implementation|Test|Architecture|Deliverables|Requirements|Cross-Project|Prerequisites|Environments|Phase|Verification)\*\*', line):
                in_description = False
                continue
            
            # Skip metadata lines
            if re.match(r'\*\*[A-Za-z]+\*\*[:\s]+', line):
                continue
            
            # Skip horizontal rules
            if re.match(r'^---+$', line.strip()):
                continue
            
            in_description = True
            description_lines.append(line)
        
        # Trim trailing empty lines
        while description_lines and not description_lines[-1].strip():
            description_lines.pop()
        
        self.description = '\n'.join(description_lines).strip()
        
        if not self.description:
            self.description = "Task description pending."
    
    def to_new_format(self) -> str:
        """Convert task to new format."""
        lines = [
            f"<!-- TASK:{self.id} -->",
            f"### {self.id}. {self.title}",
            "",
            "| Field | Value |",
            "|-------|-------|",
            f"| **id** | {self.id} |",
            f"| **status** | {self.status} |",
            f"| **priority** | {self.priority} |",
            f"| **created** | {self.created} |",
        ]
        
        if self.completed and self.status == 'complete':
            lines.append(f"| **completed** | {self.completed} |")
        
        lines.extend([
            "",
            "**Description**",
            self.description,
            "",
            f"<!-- END TASK:{self.id} -->"
        ])
        
        return '\n'.join(lines)

def is_likely_task_definition(content: str) -> bool:
    """Check if content block looks like a real task definition."""
    # A real task definition should have a Status field (required)
    # This distinguishes tasks from test scenarios, examples, etc.
    has_status = bool(re.search(r'\*\*[Ss]tatus\*\*[:\s]+', content))
    
    return has_status

def parse_todo_file(filepath: Path) -> Tuple[List[Task], List[int]]:
    """Parse a TODO.md file and extract tasks."""
    content = filepath.read_text()
    lines = content.split('\n')
    
    tasks = []
    task_positions = []
    seen_ids = set()
    
    # Find all potential task headers (#### 123. Title)
    # Note: Real tasks use #### (4 hashes), section headers often use ### (3 hashes)
    potential_tasks = []
    for i, line in enumerate(lines):
        match = re.match(r'^####\s+(\d+)\.\s+(.+)$', line)
        if match:
            potential_tasks.append((i, int(match.group(1)), match.group(2).strip()))
    
    # Filter to actual task definitions by checking content
    for idx, (start_line, task_id, title) in enumerate(potential_tasks):
        # Find end of this task (start of next task or end of file/section)
        if idx + 1 < len(potential_tasks):
            end_line = potential_tasks[idx + 1][0]
        else:
            end_line = len(lines)
            for j in range(start_line + 1, len(lines)):
                if re.match(r'^#{1,2}\s', lines[j]):  # Section header
                    end_line = j
                    break
        
        task_content = '\n'.join(lines[start_line:end_line])
        
        # Skip if this doesn't look like a real task definition
        if not is_likely_task_definition(task_content):
            log_debug(f"Skipping line {start_line+1}: '{title}' - not a task definition")
            continue
        
        # Handle duplicates (take the first one we find)
        if task_id in seen_ids:
            log_warn(f"Duplicate task ID {task_id} in {filepath} at line {start_line+1}")
            continue
        
        seen_ids.add(task_id)
        task_positions.append((start_line, task_id, title, task_content))
    
    log_info(f"Found {len(task_positions)} task definitions")
    
    # Count actual duplicates (same ID, different location)
    id_counts = {}
    for _, task_id, _ in potential_tasks:
        id_counts[task_id] = id_counts.get(task_id, 0) + 1
    duplicates_found = sum(1 for count in id_counts.values() if count > 1)
    
    if duplicates_found > 0:
        log_warn(f"Skipped {duplicates_found} duplicate task ID(s)")
    
    # Create Task objects
    for start_line, task_id, title, task_content in task_positions:
        task = Task(task_id, title, task_content)
        tasks.append(task)
    
    return tasks, list(seen_ids)

def create_todo_md(project_name: str, tasks: List[Task]) -> str:
    """Create new TODO.md content."""
    active_tasks = [t for t in tasks if t.status != 'complete']
    task_sections = '\n\n'.join([t.to_new_format() for t in sorted(active_tasks, key=lambda x: x.id)])
    qr_table = regenerate_qr(tasks)
    
    content = f"""<!--
TODO.md - Active Tasks for {project_name}

⚠️ IMPORTANT: This file uses strict formatting. See:
  .claude/skills/task-management/SKILL.md

Generated sections are marked - DO NOT EDIT MANUALLY.
-->

# {project_name} Tasks

*Active tasks only. See [COMPLETED.md](./COMPLETED.md) for history.*

**Quick Links**: [Active Tasks](#quick-reference) | [Completed Tasks](./COMPLETED.md)

---

## Quick Reference

{qr_table}

---

## Tasks

<!-- TASKS-START -->

{task_sections}

<!-- TASKS-END -->
"""
    return content

def create_completed_md(project_name: str, completed_tasks: List[Task]) -> str:
    """Create new COMPLETED.md content."""
    if not completed_tasks:
        return ""
    
    # Sort by completion date (newest first)
    sorted_tasks = sorted(completed_tasks, key=lambda x: x.completed or '', reverse=True)
    
    task_sections = '\n\n'.join([t.to_new_format() for t in sorted_tasks])
    
    current_month = datetime.now().strftime("%Y-%m (%B %Y)")
    
    content = f"""<!--
COMPLETED.md - Completed Tasks for {project_name}

⚠️ IMPORTANT: This file is APPEND-ONLY at the top.
Newest completed tasks go in "## Current Month" section.
See SKILL.md for completion workflow.
-->

# Completed Tasks - {project_name}

**Stats**: {len(completed_tasks)} total

---

## Current Month ({current_month})

<!-- New completed tasks go HERE (at the top) -->

{task_sections}

---

## Previous Months

<!-- Migrated completed tasks will be organized here -->
"""
    return content

def regenerate_qr(tasks: List[Task]) -> str:
    """Generate Quick Reference table from tasks."""
    active_tasks = [t for t in tasks if t.status != 'complete']
    
    # Sort by priority then ID
    priority_order = {'critical': 1, 'high': 2, 'medium': 3, 'low': 4}
    sorted_tasks = sorted(active_tasks, key=lambda t: (priority_order.get(t.priority, 4), t.id))
    
    # Build table
    table_lines = [
        "<!-- QR-START (AUTO-GENERATED - DO NOT EDIT) -->",
        "",
        "| ID | Title | Status | Priority |",
        "|----|-------|--------|----------|"
    ]
    
    status_emoji = {'pending': '📋', 'in_progress': '🟡', 'blocked': '🚫', 'complete': '✅'}
    priority_emoji = {'critical': '🔴', 'high': '🟠', 'medium': '🟡', 'low': '🟢'}
    
    for task in sorted_tasks:
        se = status_emoji.get(task.status, '❓')
        pe = priority_emoji.get(task.priority, '⚪')
        status_cap = task.status.replace('_', ' ').title()
        priority_cap = task.priority.title()
        
        # Truncate long titles
        title = task.title
        if len(title) > 40:
            title = title[:37] + '...'
        
        table_lines.append(f"| {task.id} | {title} | {se} {status_cap} | {pe} {priority_cap} |")
    
    if not sorted_tasks:
        table_lines.append("| - | No active tasks | - | - |")
    
    table_lines.extend([
        "",
        "<!-- QR-END -->"
    ])
    
    return '\n'.join(table_lines)

def migrate_file(todo_path: Path, dry_run: bool = False) -> Tuple[int, int]:
    """Migrate a single TODO.md file."""
    log_info(f"Migrating: {todo_path}")
    
    # Parse tasks
    tasks, duplicates = parse_todo_file(todo_path)
    log_info(f"Found {len(tasks)} tasks")
    
    # Separate active and completed
    active_tasks = [t for t in tasks if t.status != 'complete']
    completed_tasks = [t for t in tasks if t.status == 'complete']
    
    log_info(f"Active: {len(active_tasks)}, Completed: {len(completed_tasks)}")
    
    # Get project name
    dir_name = todo_path.parent.name
    if dir_name == '.' or todo_path.parent == todo_path.parent.parent:
        project_name = "Root"
    else:
        project_name = dir_name.replace('-', ' ').title()
    
    # Create new content
    new_todo = create_todo_md(project_name, tasks)
    
    # Write files
    if not dry_run:
        # Backup
        backup_path = todo_path.with_suffix('.md.backup')
        if not backup_path.exists():
            todo_path.rename(backup_path)
        
        # Write new TODO.md
        todo_path.write_text(new_todo)
        log_info(f"Updated: {todo_path}")
        
        # Write COMPLETED.md if needed
        if completed_tasks:
            completed_path = todo_path.parent / "COMPLETED.md"
            completed_content = create_completed_md(project_name, completed_tasks)
            completed_path.write_text(completed_content)
            log_info(f"Created: {completed_path}")
    else:
        log_info("[DRY RUN] Would update TODO.md")
        if completed_tasks:
            log_info("[DRY RUN] Would create COMPLETED.md")
    
    return len(active_tasks), len(completed_tasks)

def main():
    import argparse
    parser = argparse.ArgumentParser(description='Migrate TODO.md files to new format')
    parser.add_argument('--dry-run', action='store_true', help='Show what would happen without making changes')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    args = parser.parse_args()
    
    # Find script directory and project root
    script_dir = Path(__file__).parent
    root_dir = script_dir.parent.parent.parent.parent
    
    log_info("Starting migration...")
    if args.dry_run:
        log_info("DRY RUN MODE - No files will be modified")
    
    # Find TODO files
    todo_files = find_todo_files(root_dir)
    log_info(f"Found {len(todo_files)} TODO.md files")
    print()
    
    total_active = 0
    total_completed = 0
    
    for todo_file in todo_files:
        active, completed = migrate_file(todo_file, args.dry_run)
        total_active += active
        total_completed += completed
        print()
    
    log_info("Migration complete!")
    log_info(f"Total active tasks: {total_active}")
    log_info(f"Total completed tasks: {total_completed}")

if __name__ == '__main__':
    main()
