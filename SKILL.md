---
name: task-management
description: Manage tasks across nested projects with sequential ID tracking. Use when working with TODO.md files, task management, marking tasks complete/started/blocked, or tracking project status across multiple subprojects. Auto-discovers TODO.md files in subdirectories and maintains sequential task IDs across all projects.
---

# Task Management

This skill provides task tracking across nested projects with automatic TODO.md discovery and sequential ID management.

## Task ID System

- **Sequential IDs**: Start at 1, increment across ALL subprojects
- **No ranges**: IDs are simply sequential (1, 2, 3, 49, 50, etc.)
- **Cross-project**: Task 1 in one folder and Task 2 in another - IDs are unique across all projects

## Auto-Discover TODO Files

Always scan for TODO.md files before working with tasks:

```bash
# Find all TODO.md files
find . -name "TODO.md" -type f 2>/dev/null | grep -v node_modules | grep -v target | grep -v ".git"
```

TODO.md files can exist at any level:
- `./TODO.md` (root cross-project tasks)
- `./project-a/TODO.md`
- `./project-b/TODO.md`
- Any subdirectory may have one

## Quick Reference Tables

All TODO.md files should have a **Quick Reference** table at the top for fast parsing:

```markdown
| ID | Title | Status | Priority | Location |
|----|-------|--------|----------|----------|
| 9  | Clean up CLI... | Pending | High | root |
```

**Parse the quick reference table** for fast task listing:
```bash
# Extract all active tasks from quick reference tables
for file in $(find . -name "TODO.md" -type f 2>/dev/null | grep -v node_modules | grep -v target | grep -v ".git"); do
  awk '/^\| [0-9]+ \|/ && !/ID.*Title/' "$file" 2>/dev/null
done
```

## Status & Priority Values

**Statuses:**
- `pending` - Not started
- `in_progress` - Currently being worked on
- `blocked` - Waiting on something
- `complete` - Finished

**Priorities:**
- `critical` - Must do immediately
- `high` - Important, do soon
- `medium` - Normal priority
- `low` - Nice to have

## Workflow

### 1. When Starting Work

1. Scan for all TODO.md files
2. Read relevant TODO.md files to understand active tasks
3. Identify the task you're working on by ID

### 2. When Making Substantial Progress

**Auto-update the TODO.md when:**
- Task status changes (pending → in_progress → complete)
- Context/details about the task change significantly
- New information discovered that affects the task
- Blockers identified or resolved

### 3. Marking Tasks Complete

When user says a task is complete:
1. Find the task in the appropriate TODO.md
2. Update status to `complete`
3. Add completion date if not present
4. Update any relevant context

### 4. Creating New Tasks

**Location Rule:**
- Create task in the **project-specific TODO.md** where the work will be done
- Only use root `./TODO.md` for **cross-project** tasks (affects multiple subprojects)
- Example: Backend fixes go in `backend/TODO.md`, not root

**Steps:**
1. Find the highest existing task ID across ALL TODO.md files
2. Next task gets ID = highest + 1
3. Add to the **appropriate project-level TODO.md** (not always root!)
4. Include: ID, title, status, priority, description, files

### 5. Removing/Deleting Tasks

**If a task is removed (not marked complete):**
- Simply delete the task entry from the TODO.md file
- Do NOT try to reuse the ID number for future tasks
- IDs are sequential and never reused - gaps are acceptable
- Example: If tasks 1,2,3 exist and task 2 is deleted, next task is 4 (not 2)

## Example Task Format

```markdown
#### 49. Dev Environment Speedup
**Status**: ✅ Complete  
**Priority**: High  
**Description**: Optimize shell loading with direnv

**Progress**:
- ✅ Configured direnv
- ✅ Added bind mount workaround
- ✅ Updated welcome messages

**Files**:
- `flake.nix`
- `DEVELOPMENT_SPEEDUP.md`
- `.envrc`
```

## Commands

```bash
# Find all TODO.md files
todo_files=$(find . -name "TODO.md" -type f 2>/dev/null | grep -v node_modules | grep -v target | grep -v ".git")

# List active tasks from quick reference tables (FAST)
for file in $todo_files; do
  awk '/^\| [0-9]+ \|/ && !/ID.*Title/' "$file" 2>/dev/null
done

# Parse specific status from tables
for file in $todo_files; do
  awk '/^\| [0-9]+ \|/ && /Pending/' "$file" 2>/dev/null
done

# Find next available task ID
find . -name "TODO.md" -exec grep -h "^#### [0-9]" {} + 2>/dev/null | sed 's/.*#### \([0-9]*\).*/\1/' | sort -n | tail -1
```

## Listing Tasks for Users

When the user asks to "list tasks", simply display the **Quick Reference tables** from each TODO.md file:

**Simple approach:**
1. Read the Quick Reference table from each TODO.md
2. Display them grouped by file/location
3. The tables are maintained by this skill with proper status/priority ordering

**Example output:**
```
## Root (./TODO.md)

| ID | Title | Status | Priority | Location |
|----|-------|--------|----------|----------|
| 3 | Contract-First Feature Testing | Pending | Medium | root |
| 5 | Full Test Coverage on PRE Module | Pending | Medium | root |
| 9 | Clean Up CLI for Publication | Pending | High | root |

## Backend (./backend/TODO.md)

| ID | Title | Status | Priority |
|----|-------|--------|----------|
| 13 | Complete API Implementation | In Progress | High |
| 17 | Minimize Cache Usage | Pending | Medium |
| 22 | Serialization Completion | Blocked | Medium |

## Frontend (./frontend/TODO.md)

| ID | Title | Status | Priority |
|----|-------|--------|----------|
| 33 | Multi-Currency Test Fixes | Pending | High |
| 35 | Test Suite Repair - Phase 3 | In Progress | Medium |
| 36 | Add Coverage Tooling | Blocked | Medium |
```

**Rules:**
- The Quick Reference tables are the **source of truth** for active tasks
- This skill maintains the tables (organizing by status/priority/location)
- For listing: just display what's in the tables - no re-sorting needed
- Assume tables are in proper state when listing
