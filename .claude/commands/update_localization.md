# /update_localization

Sync localization files, detect hardcoded strings, and auto-translate missing Korean entries.

## Instructions

You are a localization maintenance assistant. Perform the following tasks in order:

### Step 1: Read Current State

1. Read `assets/localization/en_us.json` and `assets/localization/ko_kr.json`
2. Parse both as JSON and extract all keys (flattened with dot notation)
3. If either file is malformed, report the error and stop

### Step 2: Find Missing Korean Translations

1. Compare key sets: find keys in English that are missing from Korean
2. For each missing key, generate a Korean translation following these rules:
   - Use 해요체 (polite informal) for UI messages
   - Use noun forms for stat labels (e.g., "Dodge Chance" → "회피 확률")
   - Preserve format placeholders exactly: `{damage}` stays as `{damage}`
   - Preserve markup: `[text](color=red)` → `[텍스트](color=red)`
   - Match the tone of the English text
3. Collect all missing keys with their translations

### Step 3: Detect Hardcoded Strings

Scan `assets/scripts/**/*.lua` (excluding `assets/scripts_archived/`) for potential hardcoded strings:

**Patterns to detect:**
- `dsl.text("...")`
- `setText("...")`
- String literals in tooltip definitions (title/body fields)
- Direct string arguments to UI functions

**Ignore list (false positives):**
- Single characters: `"/"`, `":"`, `" "`, etc.
- Format-only strings: `"{damage}"`, `"{hp}/{maxHp}"`
- Module paths: strings containing `"."` that look like `"core.timer"`
- Sprite/asset names: lowercase_snake_case without spaces
- Event names: strings starting with `"on_"` or containing `"_event"`
- Strings that are already `localization.get()` calls
- Strings shorter than 3 characters
- Pure numbers or numeric formats

**For each detected hardcoded string:**
1. Generate a key name: `ui.<snake_case_version_of_content>` (max 40 chars)
2. Add to English JSON with the original text
3. Generate Korean translation and add to Korean JSON
4. Record the file path and line number for the code fix suggestion

### Step 4: Create Backups

1. Copy `assets/localization/en_us.json` to `assets/localization/en_us.json.backup`
2. Copy `assets/localization/ko_kr.json` to `assets/localization/ko_kr.json.backup`

### Step 5: Write Updated JSON Files

1. Merge new keys into the existing JSON structure
2. Maintain the nested structure (e.g., `ui.start_game` goes under `{"ui": {"start_game": ...}}`)
3. Write with tab indentation to match existing format
4. Sort keys alphabetically within each level

### Step 6: Report Summary

Output a summary in this format:

```
Localization Sync Complete

Synced Translations:
  - Added X missing Korean translations

New Keys from Hardcoded Strings:
  - Added Y new keys to both language files

Backups Created:
  - assets/localization/en_us.json.backup
  - assets/localization/ko_kr.json.backup

Code Fixes Needed:
  [file:line] "Original String"
    → Replace with: localization.get("ui.suggested_key")
  ...
```

If no changes were needed, report: "All localization files are up to date."

## Important Notes

- Never delete existing keys (only add)
- Never modify Lua source files (only suggest changes)
- If a Korean key already exists, do not overwrite it
- Warn about orphaned Korean keys (keys with no English equivalent)
