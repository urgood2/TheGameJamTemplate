# ClaudeBox Workflow Design

## Goals

- **Isolation**: Keep Claude's work sandboxed from the main system
- **Multi-instance**: Run parallel Claude sessions (feature + bugfix, exploratory work)
- **Git worktrees**: Each session works in its own branch, no conflicts

## Core Setup

### Installation

```bash
# Install ClaudeBox
cd ~/Projects/TheGameJamTemplate/TheGameJamTemplate
chmod +x claudebox.run
./claudebox.run

# Add to PATH if needed
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Development Profiles

Install native development tools:

```bash
claudebox profile c build-tools shell
```

This provides:
- **c**: C/C++ toolchain (gcc, g++, gdb, valgrind, clang-tidy)
- **build-tools**: CMake, Ninja, make, autotools
- **shell**: fzf, SSH, man pages

Web builds (Emscripten) stay on the host system.

### Network Allowlist

```bash
claudebox allowlist
```

Add these domains:
```
itch.io
*.itch.io
butler.itch.io
```

Defaults already include GitHub, npm, PyPI, and Anthropic API.

## Multi-Instance Workflow

### The Pattern

Main terminal stays on `master` for stable work. Parallel sessions use git worktrees:

```bash
# Terminal 1: Main session (master branch)
cd ~/Projects/TheGameJamTemplate/TheGameJamTemplate
claudebox

# Terminal 2: Exploratory work
git worktree add ../TheGameJamTemplate-explore feature/explore-new-approach
cd ../TheGameJamTemplate-explore
claudebox

# Terminal 3: Bugfix (if needed)
git worktree add ../TheGameJamTemplate-bugfix fix/issue-name
cd ../TheGameJamTemplate-bugfix
claudebox
```

### Session Isolation

| Session | Directory | Branch | Purpose |
|---------|-----------|--------|---------|
| Main | `TheGameJamTemplate/` | master | Stable feature work |
| Explore | `TheGameJamTemplate-explore/` | feature/* | "What if" experiments |
| Bugfix | `TheGameJamTemplate-bugfix/` | fix/* | Bug investigation |

Each session:
- Runs in a separate container
- Shares the same Docker image (no rebuild)
- Has independent git state
- Can build and test independently

### Merging and Cleanup

```bash
# Merge successful experiment
cd ~/Projects/TheGameJamTemplate/TheGameJamTemplate
git merge feature/explore-new-approach

# Remove worktree
git worktree remove ../TheGameJamTemplate-explore
```

## Quick Reference

### Daily Commands

```bash
# Start main session
claudebox

# Create parallel session
git worktree add ../TGJ-explore experiment/idea-name
cd ../TGJ-explore && claudebox

# Inside container - build commands work normally
just build-debug-ninja
just test

# Open container shell
claudebox shell

# Check status
claudebox info
```

### Housekeeping

```bash
# List worktrees
git worktree list

# Clean up worktree
git worktree remove ../TGJ-explore

# Clean project container/image
claudebox clean --project
```

### Optional: Saved Flags

```bash
# Save preferred flags
claudebox save --model opus

# Now `claudebox` always uses opus
```

## Setup Checklist

1. [ ] Run `chmod +x claudebox.run && ./claudebox.run`
2. [ ] Add `~/.local/bin` to PATH if needed
3. [ ] Run `claudebox profile c build-tools shell`
4. [ ] Run `claudebox allowlist` and add itch.io domains
5. [ ] Verify with `claudebox info`
6. [ ] Test build: `claudebox shell` then `just build-debug-ninja`
7. [ ] Test parallel session with a temporary worktree
