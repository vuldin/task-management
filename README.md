# Task Management Skill

Manage tasks across nested projects with automatic TODO.md discovery and sequential ID management.

## Installation

Clone into your project's `.claude/skills` directory:

```bash
git clone https://github.com/vuldin/task-management.git .claude/skills/task-management
```

## Usage

### Listing Tasks

Use the provided script to list all active tasks:

```bash
.claude/skills/task-management/list-tasks.sh
```

Or copy it to your project for easier access:

```bash
cp .claude/skills/task-management/list-tasks.sh .claude/scripts/
./.claude/scripts/list-tasks.sh
```

### Kimi Commands

```
list tasks
list all tasks
create task: <title>
mark task <id> complete
update task <id> status to in_progress
```

## How It Works

- **Auto-discovery**: Finds all `TODO.md` files in subdirectories
- **Global IDs**: Sequential across all projects (1, 2, 3...)
- **Status**: pending | in_progress | blocked | complete
- **Priority**: Critical | High | Medium | Low

## Project Structure

```
project/
├── TODO.md                    # Cross-project tasks
├── cli/TODO.md               # CLI-only tasks
├── contracts/TODO.md         # Contract-only tasks
└── .claude/
    └── skills/
        └── task-management/
            ├── SKILL.md      # Full documentation
            └── list-tasks.sh # Helper script
```

## Files

| File | Description |
|------|-------------|
| `SKILL.md` | Complete skill documentation for Kimi |
| `list-tasks.sh` | Shell script to list all active tasks |
| `README.md` | This file |
