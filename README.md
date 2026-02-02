# Task Management Skill

Manage tasks across nested projects with automatic TODO.md discovery and sequential ID management.

## Installation

Clone into your project's `.claude/skills` directory:

```bash
git clone https://github.com/vuldin/task-management.git .claude/skills/task-management
```

## Usage

```
list tasks
create task: <title>
mark task <id> complete
update task <id> status to in_progress
```

## How It Works

- **Auto-discovery**: Finds all `TODO.md` files in subdirectories
- **Global IDs**: Sequential across all projects (1, 2, 3...)
- **Status**: pending | in_progress | blocked | complete

Project structure:
```
project/
├── TODO.md
├── backend/TODO.md
└── frontend/TODO.md
```
