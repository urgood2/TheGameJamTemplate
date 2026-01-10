# Setup Ralph for Project

Sets up Ralph autonomous development for the current project. Creates all necessary files and provides guidance on usage.

## What This Command Does

1. **Checks Prerequisites** - Verifies `ralph` CLI is installed
2. **Analyzes Project** - Reads existing CLAUDE.md, structure, and context
3. **Creates PROMPT.md** - Project requirements file for Ralph
4. **Creates @fix_plan.md** - Task tracking file
5. **Creates specs/** - Specification directory (if needed)
6. **Provides Guidance** - Shows how to use both Ralph methods

---

## Instructions for Claude

When the user runs `/setup-ralph`, follow these steps:

### Step 1: Check Prerequisites

```bash
# Check if ralph CLI is installed
which ralph && ralph --help | head -5
```

If `ralph` is not found, inform the user:
- Run: `cd /path/to/ralph-claude-code && ./install.sh`
- Or: `git clone https://github.com/frankbria/ralph-claude-code.git && cd ralph-claude-code && ./install.sh`

### Step 2: Analyze Project Context

Read the following to understand the project:
- `CLAUDE.md` - Main project documentation
- `README.md` - Project overview
- Directory structure
- Any existing `PROMPT.md` or `@fix_plan.md`

### Step 3: Create PROMPT.md

Create a `PROMPT.md` file in the project root with this structure:

```markdown
# Project: [Project Name]

## Overview
[Brief description from CLAUDE.md/README.md]

## Current Objective
[What Ralph should work on - ASK THE USER]

## Context Files
- Read `CLAUDE.md` for coding guidelines
- Read `@fix_plan.md` for current tasks
- Check `specs/` for specifications

## Success Criteria
- [ ] All tasks in `@fix_plan.md` marked complete
- [ ] Code compiles without errors
- [ ] Tests pass (if applicable)

## Constraints
- Follow existing code patterns
- Don't modify unrelated files
- Commit changes incrementally

## Completion Signal
When all tasks are complete, output:
<promise>COMPLETE</promise>
```

### Step 4: Create @fix_plan.md

Create `@fix_plan.md` for task tracking:

```markdown
# Fix Plan

## Current Sprint

### TODO
- [ ] Task 1 (ask user what to work on)
- [ ] Task 2
- [ ] Task 3

### IN PROGRESS
(none)

### DONE
(none)

---

## Notes
- Update this file as tasks progress
- Move items between sections
- Add new tasks as discovered
```

### Step 5: Create specs/ Directory (if needed)

```bash
mkdir -p specs
```

If the project has complex requirements, create spec files:
- `specs/architecture.md` - System design
- `specs/api.md` - API specifications
- `specs/requirements.md` - Feature requirements

### Step 6: Provide Usage Guidance

After setup, explain both Ralph methods:

**Method 1: External Ralph (Shell-based)**
```bash
# Start with monitoring dashboard
ralph --monitor

# Or run without tmux
ralph --calls 50 --timeout 30

# Check status
ralph --status
```

**Method 2: In-Session Ralph (/ralph-loop)**
```
/ralph-loop "Implement the features in @fix_plan.md" --completion-promise "COMPLETE" --max-iterations 30
```

**Cancel either method:**
- External: `Ctrl+C` in tmux or `ralph --status` to check
- In-session: `/cancel-ralph`

---

## Arguments

This command accepts optional arguments:

- `--objective "description"` - Set the main objective directly
- `--quick` - Skip interactive prompts, use defaults
- `--external-only` - Only set up for external `ralph` command
- `--internal-only` - Only set up for `/ralph-loop`

## Examples

```
/setup-ralph
/setup-ralph --objective "Implement inventory grid UI"
/setup-ralph --quick
```
