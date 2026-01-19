# Handoff: Obsidian Kanban → TODO Sync System

## Context
A one-way file sync system was built to automatically mirror an Obsidian Kanban board to a project TODO file. The user manages tasks in Obsidian and wants them reflected in the project repo.

## File Locations

### Source (Obsidian Kanban)
```
/Users/joshuashin/Documents/Bramses-opinionated/Surviorslike Kanban.md
```
- Obsidian Kanban plugin format (YAML frontmatter + `## Column` sections)
- Columns: TODO, In Progress, Waiting On, Abandoned, Done

### Target (Project TODO)
```
/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/docs/project-management/todos/TODO_prototype.md
```
- Synced content inserted at TOP between HTML comment markers
- All original content below markers is preserved

### Scripts Created
```
/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/scripts/
├── sync-kanban-to-todo.sh          # Core sync logic
├── watch-kanban.sh                 # fswatch real-time watcher
├── com.joshuashin.kanban-sync.plist # launchd service config
├── install-kanban-sync.sh          # One-command installer
└── uninstall-kanban-sync.sh        # Clean uninstaller
```

### State Directory
```
~/.kanban-sync/
├── last-sync-hash       # SHA-256 of synced section (conflict detection)
├── last-kanban-hash     # SHA-256 of Kanban file (change detection)
├── sync.log             # Sync operation logs
├── watcher.log          # fswatch watcher logs
├── launchd-stdout.log   # launchd stdout
└── launchd-stderr.log   # launchd stderr
```

## How Sync Works

1. **Trigger**: fswatch detects Kanban file save (2-second debounce)
2. **Transform**: Strips YAML frontmatter and kanban settings, keeps column headers + tasks
3. **Conflict check**: Compares hash of current synced section vs stored hash
4. **Write**: Inserts transformed content between markers, preserves content below
5. **Store**: Saves new hashes for next run

### Markers in TODO_prototype.md
```markdown
<!-- KANBAN-SYNC-START -->
## Synced from Obsidian Kanban
> Last synced: 2026-01-19 10:02:34
> Source: `Surviorslike Kanban.md`

## TODO
- [ ] Task here

## In Progress
...
<!-- KANBAN-SYNC-END -->

(original TODO_prototype.md content preserved below)
```

## Commands

```bash
# Manual sync (run from any terminal)
/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/scripts/sync-kanban-to-todo.sh

# Force sync (ignores conflict detection)
/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/scripts/sync-kanban-to-todo.sh --force

# Run file watcher manually (keeps terminal open)
/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/scripts/watch-kanban.sh

# Check launchd service status
launchctl list | grep kanban

# View sync logs
tail -f ~/.kanban-sync/sync.log

# Restart launchd service
launchctl unload ~/Library/LaunchAgents/com.joshuashin.kanban-sync.plist
launchctl load ~/Library/LaunchAgents/com.joshuashin.kanban-sync.plist
```

## Known Issue: macOS Full Disk Access

The Kanban file is in `~/Documents`, which requires Full Disk Access for background processes. The launchd service fails silently without FDA.

### Solutions (pick one):

**Option A: Grant FDA to bash**
1. System Settings → Privacy & Security → Full Disk Access
2. Click `+`, press Cmd+Shift+G, type `/bin/bash`, add it
3. Restart the launchd service

**Option B: Run watcher manually**
```bash
/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/scripts/watch-kanban.sh
```
(Requires keeping a Terminal window open)

**Option C: Move Obsidian vault**
Move vault out of `~/Documents` to a non-protected location like `~/Obsidian/`

## Conflict Detection

If the synced section in `TODO_prototype.md` is manually edited, the next sync will detect this (hash mismatch) and:
- Log: `CONFLICT DETECTED: Synced section was manually edited`
- Send macOS notification
- Exit without overwriting

To resolve: use `--force` flag or manually reconcile changes.

## Testing the Sync

```bash
# 1. Edit the Kanban file
echo "- [ ] Test task" >> "/Users/joshuashin/Documents/Bramses-opinionated/Surviorslike Kanban.md"

# 2. Run sync
/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/scripts/sync-kanban-to-todo.sh --force

# 3. Verify
head -20 "/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/docs/project-management/todos/TODO_prototype.md"
```

## Dependencies
- `fswatch` (installed via Homebrew: `brew install fswatch`)
- `terminal-notifier` (optional, for macOS notifications: `brew install terminal-notifier`)

## Cron Job (Backup/Restart Mechanism)

As a fallback/restart mechanism after reboot, set up a cron job:

```bash
# Add to crontab (runs on reboot)
crontab -e

# Add this line:
@reboot /Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/scripts/watch-kanban.sh >> ~/.kanban-sync/cron-restart.log 2>&1
```

This ensures the watcher auto-restarts even if:
- launchd service fails due to FDA issues
- System reboots
- Watcher process is killed

**Note:** Cron runs in minimal environment. If fswatch isn't found, use full path:
```bash
@reboot /opt/homebrew/bin/fswatch -e ".*" -i "\\.md$" "/Users/joshuashin/Documents/Bramses-opinionated" "/Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/scripts/sync-kanban-to-todo.sh" >> ~/.kanban-sync/cron-restart.log 2>&1
```

Or use the wrapper script:
```bash
@reboot /bin/zsh -c 'cd /Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/scripts && ./watch-kanban.sh' >> ~/.kanban-sync/cron-restart.log 2>&1
```
