---
name: task-management
description: Manage tasks across nested projects with sequential ID tracking. Use when working with TODO.md files, task management, marking tasks complete/started/blocked, or tracking project status across multiple subprojects. Auto-discovers TODO.md files in subdirectories and maintains sequential task IDs across all projects.
---

# Task Management

This skill provides task tracking across nested projects with automatic TODO.md discovery and sequential ID management.

---

## 🚨 CRITICAL: HANDLING "list tasks" COMMAND

**WHEN THE USER SAYS "list tasks", YOU MUST:**

1. **RUN THE SCRIPT** - Execute `.claude/skills/task-management/list-tasks.sh`
2. **COPY THE OUTPUT INTO YOUR RESPONSE** - The script output goes directly in your
   response message. Do NOT summarize it. Do NOT describe it. Do NOT say "here are the results."
   Just paste the raw output.

**EXAMPLE OF CORRECT RESPONSE:**
```
## Root

| ID | Title | Status | Priority |
|----|-------|--------|----------|
| 1  | Task One | 📋 Pending | 🔴 High |

## CLI
...
```

**EXAMPLE OF WRONG RESPONSE:**
"I ran the script, here are the results:"  ← NEVER ADD THIS
[script output]

**That's it.** The script handles dynamic discovery and filtering. No validation needed at list time.

**⛔ NEVER:**
- Run validation checks during `list tasks`
- Fix TODO.md files during `list tasks`
- Delay showing output to run checks
- Add extra summaries or commentary after the script output

**✅ ALWAYS:**
- Run the script and immediately show output
- Trust the script to filter completed tasks
- Let the completion workflow handle validation

---

## TODO.md File Header Template

Every TODO.md file should include a header comment block that references this skill:

```markdown
<!-- 
TODO.md - Task Tracking for [Project Name]

⚠️ IMPORTANT: When editing this file, ALWAYS follow the task-management skill instructions:
- Location: `.claude/skills/task-management/SKILL.md`
- Key rules: Sequential IDs, move completed tasks to "Completed Tasks" section, 
  keep Quick Reference clean (active tasks only)

For details, read the skill file or ask: "what are the task management rules?"
-->

# [Project] Tasks

*This file tracks tasks for [project]. Cross-project tasks are in `/TODO.md`.*

**Key Documents**:
- `docs/[prd].md` - Product Requirements

**Quick Links**:
- [Active Tasks](#quick-reference---active-tasks)
- [Completed Tasks](#completed-tasks)

---

## Quick Reference - Active Tasks

| ID | Title | Status | Priority |
|----|-------|--------|----------|
...
```

---

## Task ID System

- **Sequential IDs**: Start at 1, increment across ALL subprojects
- **No ranges**: IDs are simply sequential (1, 2, 3, 49, 50, etc.)
- **Cross-project**: Task 1 in one folder and Task 2 in another - IDs are unique across all projects

---

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

---

## User Options

| User Says | Action |
|-----------|--------|
| "list tasks" | Run `list-tasks.sh` and show output immediately |
| "list all tasks" | Show ALL tasks including completed |
| "list completed tasks" | Show only completed tasks |
| "show task 51" | Show specific task details - USE ReadFile on appropriate TODO.md |

---

## Quick Reference Tables

All TODO.md files should have a **Quick Reference** table at the top for fast parsing:

```markdown
## Quick Reference - Active Tasks

| ID | Title | Status | Priority |
|----|-------|--------|----------|
| 9  | Clean Up CLI... | Pending | High |
```

**⚠️ Table Maintenance Rules:**
1. **Active tasks only** - Never include completed tasks in Quick Reference
2. **Keep sorted** - Priority order: Critical → High → Medium → Low
3. **Remove on completion** - Immediately delete row when task completes
4. **Consistent columns** - All tables use: ID, Title, Status, Priority

---

## Task Location Rules (CRITICAL)

| File | What Goes Here | Examples |
|------|---------------|----------|
| **Root TODO.md** | Cross-project tasks only (spans 2+ subprojects) | Task 62: Share Deletion (contracts + CLI) |
| **cli/TODO.md** | CLI-only tasks | Task 61: Discovery Module CLI Commands |
| **contracts/TODO.md** | Contract-only tasks | Task 58: Auto-Renewal Implementation |
| **discovery/TODO.md** | Discovery service tasks | Task 108: REST API Endpoints |

**If a task appears in the wrong file:**
- Move single-project tasks from root to appropriate subproject
- Keep cross-project tasks in root only
- Add "See root TODO.md" note in subproject tables for cross-project tasks

---

## Workflow

### 1. When Starting Work

1. Dynamically discover all TODO.md files using `find`
2. Read relevant TODO.md files to understand active tasks
3. Identify the task you're working on by ID

### 2. When Making Substantial Progress

**Auto-update the TODO.md when:**
- Task status changes (pending → in_progress → complete)
- Context/details about the task change significantly
- New information discovered that affects the task
- Blockers identified or resolved

### 3. Marking Tasks Complete

When user says a task is complete, follow these steps:

#### Step 1: Update Task Status and Move to Completed Section
1. Find the task in the appropriate TODO.md
2. Update status to `✅ Complete` in the task description
3. Add completion date if not present
4. **Move the entire task entry to a "Completed Tasks" section**
   - If the section doesn't exist, **CREATE IT** at the end of the file
   - The section header should be: `## Completed Tasks`
   - Place completed tasks in reverse chronological order (newest first)

**Example of creating the Completed Tasks section:**
```markdown
## Completed Tasks

#### 49. Dev Environment Speedup
**Status**: ✅ Complete  
**Completed**: Feb 5, 2026  
**Priority**: High  
**Description**: Optimize shell loading with direnv
...
```

#### Step 2: Remove from Quick Reference (MANDATORY)
**Delete the task row from the Quick Reference table.** This table is ONLY for active tasks.

Example: Remove this row from the table:
```markdown
| 51 | Add canDeleteProfile() Function | 📋 Pending | 🟠 High |
```

#### Step 3: Validate TODO.md State
**AFTER completing a task, run validation to ensure the file is clean:**

```bash
# Check for completed tasks still in Quick Reference
find . -name "TODO.md" -type f 2>/dev/null | while read -r file; do
  result=$(awk '/## Quick Reference/{qr=1; next} /## Detailed Task Descriptions/{qr=0} qr && /^\| [0-9]+ \|/ && (/Complete/ || /✅/ || /Done/){print}' "$file" 2>/dev/null)
  if [ -n "$result" ]; then
    echo "WARNING: Completed tasks found in $file Quick Reference:"
    echo "$result"
  fi
done
```

**If completed tasks are found in Quick Reference:**
1. **DO NOT ignore this** - the file is in an invalid state
2. Remove the completed task rows immediately using StrReplaceFile
3. Re-run the validation check to confirm it's clean
4. Only proceed after the check passes

**Validation is required at completion time to ensure:**
- Quick Reference tables only contain active tasks
- `list tasks` output is always accurate
- No manual cleanup needed later

### 4. Creating New Tasks

**Location Rule (CRITICAL):**
- Create task in the **project-specific TODO.md** where the work will be done
- Only use root `./TODO.md` for **cross-project** tasks (affects multiple subprojects)
- **Cross-project indicator**: Task requires changes in 2+ subprojects (contracts + CLI, etc.)

**Steps:**
1. Find the highest existing task ID across ALL TODO.md files
2. Next task gets ID = highest + 1
3. Add to the **appropriate project-level TODO.md** (not always root!)
4. **Update Quick Reference table** in that file (active tasks only)
5. For cross-project tasks: Add note in subproject TODOs: "See root TODO.md for task X"

**Find highest task ID:**
```bash
find . -name "TODO.md" -exec grep -h "^#### [0-9]" {} + 2>/dev/null | sed 's/.*#### \([0-9]*\).*/\1/' | sort -n | tail -1
```

### 5. Removing/Deleting Tasks

**If a task is removed (not marked complete):**
- Simply delete the task entry from the TODO.md file
- Do NOT try to reuse the ID number for future tasks
- IDs are sequential and never reused - gaps are acceptable
- Example: If tasks 1,2,3 exist and task 2 is deleted, next task is 4 (not 2)

---

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

---

## Auto-Discover TODO Files

**CRITICAL: Always dynamically discover TODO.md files - never hardcode paths.**

The `list-tasks.sh` script handles this automatically, but if you need to find files manually:

```bash
# Find all TODO.md files dynamically
find . -name "TODO.md" -type f 2>/dev/null | grep -v node_modules | grep -v target
```

**Dynamically detected locations:**
| Path | Project | Task Type |
|------|---------|-----------|
| `./TODO.md` | Root | Cross-project tasks (spans 2+ subprojects) |
| `./cli/TODO.md` | CLI | CLI-only tasks |
| `./contracts/TODO.md` | Smart Contracts | Contract-only tasks |
| `./discovery/TODO.md` | Discovery Service | Discovery service tasks |
| `./drasil-co-site/TODO.md` | Website | Website tasks |

**⚠️ IMPORTANT:** New subprojects may be added anytime. The script handles this by using `find` to discover TODO.md files dynamically.

---

## Skill Files

This skill includes a helper script that can be checked into your project:

| File | Purpose |
|------|---------|
| `SKILL.md` | This documentation |
| `list-tasks.sh` | Executable script to list all active tasks |

**To use in your project:**
```bash
# Copy the script to your project (optional - can also run from skill folder)
cp .claude/skills/task-management/list-tasks.sh .claude/scripts/

# Run it
./.claude/scripts/list-tasks.sh
```
