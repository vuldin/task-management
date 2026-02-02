# Task Management Skill

Manage tasks across nested projects with automatic TODO.md discovery and sequential ID management.

## Installation

Tell your LLM assistant:

> "Install the task-management skill from https://github.com/vuldin/task-management"

Or copy `SKILL.md` to your tool's skills directory.

## Quick Start

Create a `TODO.md` in your project root:

```markdown
## Quick Reference

| ID | Title | Status | Priority |
|----|-------|--------|----------|
| 1  | Example task | In Progress | High |

---

#### 1. Example task
**Status**: 🔄 In Progress  
**Priority**: High  
**Description**: Task description here
```

Then ask your LLM:

> "List my tasks"  
> "Mark task 1 complete"  
> "Add a new task for implementing auth"

## How It Works

- **Auto-discovery**: Finds all `TODO.md` files in subdirectories
- **Global IDs**: Task IDs are sequential across all projects (1, 2, 3...)
- **Status icons**: ⬜ pending | 🔄 in_progress | 🚫 blocked | ✅ complete

Add project-specific TODOs anywhere:
```
project/
├── TODO.md
├── backend/TODO.md
└── frontend/TODO.md
```
