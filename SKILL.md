---
name: task-management
description: Manage tasks across nested projects with sequential ID tracking. Use when working with TODO.md files, task management, marking tasks complete/started/blocked, or tracking project status across multiple subprojects. Auto-discovers TODO.md files in subdirectories and maintains sequential task IDs across all projects.
---

# Task Management

This skill provides task tracking across nested projects with automatic TODO.md discovery and sequential ID management.

---

## 🚨 CRITICAL: HANDLING "list tasks" COMMAND

**WHEN THE USER SAYS "list tasks", YOU MUST:**

1. **DYNAMICALLY DISCOVER ALL TODO.md FILES** - Use `find` to locate ALL TODO.md files
2. **USE SHELL COMMANDS ONLY** - Never use `ReadFile` on TODO.md files
3. **RUN THE VALIDATION CHECKLIST** - Check for completed tasks, wrong locations, missing tasks
4. **FIX ANY ISSUES BEFORE SHOWING OUTPUT** - Do not show bad data to user
5. **USE EXACT OUTPUT FORMAT** - As specified below

**⛔ NEVER:**
- Assume only certain TODO.md files exist
- Use `ReadFile` tool to read TODO.md files for "list tasks"
- Skip the validation checklist
- Show output with completed tasks
- Create your own output format or add summaries
- Show output before validation passes
- Add extra tables, counts, or summaries

**✅ ALWAYS:**
- Run the `list-tasks.sh` script from the skill folder
- Validate FIRST - Run checklist, fix issues, then show output
- Show clean, accurate output from ALL subprojects
- Output ends after the script runs - No additional commentary

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

## Step 1: RUN THE LIST TASKS SCRIPT

**Use the provided script to list all active tasks:**

```bash
.claude/skills/task-management/list-tasks.sh
```

**What the script does:**
- Discovers all TODO.md files dynamically
- Extracts active tasks from Quick Reference tables
- Sorts by priority (Critical → High → Medium → Low), then by ID
- Displays formatted markdown tables per project
- Shows task count summary and next available ID

**Script location:** `.claude/skills/task-management/list-tasks.sh`

---

## Step 2: VALIDATION CHECKLIST (MUST RUN - DO NOT SKIP)

**AFTER running the list command, you MUST verify output BEFORE showing to user:**

### 2a. Check for completed tasks in Quick Reference
```bash
find . -name "TODO.md" -type f 2>/dev/null | grep -v node_modules | grep -v target | while read -r file; do
  result=$(awk '/## Quick Reference/{qr=1; next} /## Detailed Task Descriptions/{qr=0} qr && /^\| [0-9]+ \|/ && (/Complete/ || /✅/ || /Done/){print}' "$file" 2>/dev/null)
  if [ -n "$result" ]; then
    echo "ISSUE: Completed tasks found in $file Quick Reference:"
    echo "$result"
  fi
done
```

### 2b. Check for missing tasks (in detailed descriptions but not in Quick Reference)
```bash
echo "Tasks missing from Quick Reference:"
find . -name "TODO.md" -exec grep -h "^#### [0-9]" {} + 2>/dev/null | sed 's/.*#### \([0-9]*\).*/\1/' | sort -u > /tmp/all_tasks.txt
find . -name "TODO.md" -exec awk '/## Detailed Task Descriptions/{exit} /^\| [0-9]+ \|/{print}' {} \; 2>/dev/null | sed 's/| \([0-9]*\).*/\1/' | sort -u > /tmp/qr_tasks.txt
comm -23 /tmp/all_tasks.txt /tmp/qr_tasks.txt
```

### 2c. Checklist - ALL must pass before showing output:
- [ ] No ✅/Complete/Done tasks in output
- [ ] Priority sorting: Critical → High → Medium → Low
- [ ] ALL subprojects included: Root, CLI, Contracts, Discovery, Website, etc.
- [ ] Root only has cross-project tasks (spanning 2+ subprojects)
- [ ] Each subproject table has only its own tasks
- [ ] All rows are markdown table format (| ID | Title | Status | Priority |)

**If any check fails:**
1. DO NOT show output to user yet
2. Fix the issues (see "Step 3: Fix Issues" below)
3. Re-run the list command
4. Re-validate
5. Only show to user after all checks pass

---

## Step 3: FIX ISSUES (If Found)

### Issue A: Completed task in Quick Reference table

**Fix:** Remove the row from the table using StrReplaceFile

### Issue B: Task in wrong file

| Task Type | Should Be In | Action |
|-----------|--------------|--------|
| Cross-project (2+ subprojects) | Root TODO.md | Move from subproject to root |
| CLI-only | cli/TODO.md | Move from root/contracts to cli |
| Contract-only | contracts/TODO.md | Move from root/cli to contracts |

### Issue C: Missing task from Quick Reference

**Fix:** Add the row to the appropriate Quick Reference table in priority-sorted position

---

## Step 4: SHOW OUTPUT

Only after all validation checks pass, show the clean output to the user.

---

## User Options for "list tasks"

| User Says | Action |
|-----------|--------|
| "list tasks" | Show ONLY active tasks (pending/in_progress/blocked), properly filtered and organized |
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

**⚠️ CRITICAL: When marking a task complete, you MUST:**
1. Update the task's status to `✅ Complete` in its detailed section
2. **REMOVE the row from Quick Reference table** (this table is ONLY for active tasks)
3. Add completion date to the task description

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

When user says a task is complete:
1. Find the task in the appropriate TODO.md
2. Update status to `complete` (or ✅ Complete) in the task description
3. **REMOVE from Quick Reference table** - delete the entire row
4. Add completion date if not present
5. Move to "Completed Tasks" section if there is one
6. Update any relevant context

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
