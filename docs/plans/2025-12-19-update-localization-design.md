# Update Localization Slash Command Design

**Date:** 2025-12-19
**Status:** Approved

## Overview

A hands-off slash command `/update_localization` that automatically syncs localization files, detects hardcoded strings, and generates Korean translations.

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Hardcoded detection | Pattern-based with smart filtering | Most hands-off, no manual markers needed |
| Translation | Claude-powered inline | Free, instant, context-aware |
| Apply mode | Auto-apply with backup | Fully automated workflow |
| New key generation | Full auto | Generates keys + translations for detected strings |

## Core Functionality

### 1. Parity Check & Sync
- Compare `en_us.json` and `ko_kr.json` keys
- For each English key missing in Korean: generate Korean translation, add to `ko_kr.json`
- For orphaned Korean keys: warn but don't delete

### 2. Hardcoded String Detection
- Scan `assets/scripts/**/*.lua` for patterns:
  - `dsl.text("...")`
  - `setText("...")`
  - Tooltip title/body string literals
- Filter out: single chars, format placeholders, sprite/event names, module paths
- Generate key names using convention: `ui.<snake_case_of_content>`

### 3. Auto-Add New Keys
- Add detected strings to `en_us.json` with original text
- Add to `ko_kr.json` with Claude-generated translation
- Output suggested code replacements

### 4. Backup & Write
- Create `en_us.json.backup` and `ko_kr.json.backup`
- Write updated JSON files with tab indentation

## Translation Guidelines

1. Use 해요체 (polite informal) for UI messages
2. Use noun forms for stats/labels
3. Keep format placeholders intact: `{damage}` → `{damage}`
4. Preserve special markup: `[text](color=red)` → `[텍스트](color=red)`
5. Match tone - playful English → playful Korean

## Edge Cases

| Situation | Behavior |
|-----------|----------|
| Malformed JSON | Abort with error, no changes |
| Backup exists | Overwrite `.backup` |
| Empty string value | Skip, warn in output |
| Nested keys | Fully supported |
| Duplicate hardcoded string | Add once, report all locations |

## File Location

`.claude/commands/update_localization.md`
