#!/usr/bin/env python3
"""
Validation script for TODO.md and COMPLETED.md files.
"""

import re
import sys
from pathlib import Path
from typing import List, Tuple, Dict, Set

# Colors
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
NC = '\033[0m'

def log_info(msg: str):
    print(f"{GREEN}[INFO]{NC} {msg}")

def log_warn(msg: str):
    print(f"{YELLOW}[WARN]{NC} {msg}")

def log_error(msg: str):
    print(f"{RED}[ERROR]{NC} {msg}")

def find_task_files(root_dir: Path) -> List[Path]:
    """Find all TODO.md and COMPLETED.md files."""
    files = []
    for pattern in ["TODO.md", "COMPLETED.md"]:
        for f in root_dir.rglob(pattern):
            if "node_modules" in str(f) or "target" in str(f):
                continue
            if len(f.relative_to(root_dir).parts) <= 3:
                files.append(f)
    return sorted(files)

def extract_tasks(content: str) -> List[Dict]:
    """Extract tasks from file content."""
    tasks = []
    
    # Find all task blocks
    pattern = r'<!-- TASK:(\d+) -->(.*?)<!-- END TASK:\1 -->'
    for match in re.finditer(pattern, content, re.DOTALL):
        task_id = int(match.group(1))
        task_content = match.group(2)
        
        task = {'id': task_id, 'content': task_content}
        
        # Extract fields
        id_match = re.search(r'\|\s*\*\*id\*\*\s*\|\s*(\d+)\s*\|', task_content)
        status_match = re.search(r'\|\s*\*\*status\*\*\s*\|\s*(\w+)\s*\|', task_content, re.IGNORECASE)
        priority_match = re.search(r'\|\s*\*\*priority\*\*\s*\|\s*(\w+)\s*\|', task_content, re.IGNORECASE)
        
        if id_match:
            task['table_id'] = int(id_match.group(1))
        if status_match:
            task['status'] = status_match.group(1).lower()
        if priority_match:
            task['priority'] = priority_match.group(1).lower()
        
        tasks.append(task)
    
    return tasks

def validate_file(filepath: Path, all_ids: Set[int]) -> Tuple[int, List[str]]:
    """Validate a single file. Returns (error_count, errors)."""
    errors = []
    content = filepath.read_text()
    
    # Check for QR markers
    if "TODO.md" in filepath.name:
        if "<!-- QR-START" not in content:
            errors.append("Missing QR-START marker")
        if "<!-- QR-END" not in content:
            errors.append("Missing QR-END marker")
    
    # Extract and validate tasks
    tasks = extract_tasks(content)
    
    for task in tasks:
        task_id = task['id']
        
        # Check ID uniqueness across all files
        if task_id in all_ids:
            errors.append(f"Task {task_id}: Duplicate ID (exists in another file)")
        all_ids.add(task_id)
        
        # Check ID matches
        if 'table_id' in task and task['table_id'] != task_id:
            errors.append(f"Task {task_id}: ID mismatch - marker says {task_id}, table says {task['table_id']}")
        
        # Check required fields
        if 'status' not in task:
            errors.append(f"Task {task_id}: Missing status field")
        elif task['status'] not in ['pending', 'in_progress', 'blocked', 'complete']:
            errors.append(f"Task {task_id}: Invalid status '{task['status']}'")
        
        if 'priority' not in task:
            errors.append(f"Task {task_id}: Missing priority field")
        elif task['priority'] not in ['critical', 'high', 'medium', 'low']:
            errors.append(f"Task {task_id}: Invalid priority '{task['priority']}'")
        
        # Check completed tasks are in COMPLETED.md
        if 'TODO.md' in filepath.name and task.get('status') == 'complete':
            errors.append(f"Task {task_id}: Completed task in TODO.md (should be in COMPLETED.md)")
    
    return len(errors), errors

def main():
    script_dir = Path(__file__).parent
    root_dir = script_dir.parent.parent.parent.parent
    
    log_info("Scanning for TODO.md and COMPLETED.md files...")
    
    files = find_task_files(root_dir)
    
    if not files:
        log_error("No TODO.md or COMPLETED.md files found")
        sys.exit(1)
    
    log_info(f"Found {len(files)} files:")
    for f in files:
        print(f"  - {f}")
    print()
    
    all_ids = set()
    total_errors = 0
    total_tasks = 0
    
    for filepath in files:
        error_count, errors = validate_file(filepath, all_ids)
        
        tasks = extract_tasks(filepath.read_text())
        total_tasks += len(tasks)
        
        if error_count > 0:
            log_error(f"File '{filepath}' has {error_count} error(s):")
            for err in errors:
                print(f"  - {err}")
            total_errors += error_count
        else:
            log_info(f"File '{filepath}' is valid ({len(tasks)} tasks)")
    
    print()
    
    if total_errors == 0:
        log_info("✓ All validations passed!")
        log_info(f"  Total files: {len(files)}")
        log_info(f"  Total tasks: {total_tasks}")
        sys.exit(0)
    else:
        log_error(f"✗ Validation failed with {total_errors} error(s)")
        sys.exit(1)

if __name__ == '__main__':
    main()
