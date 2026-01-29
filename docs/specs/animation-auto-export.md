# Animation Auto-Export System

## Overview

Extend the existing sprite auto-export pipeline to support animated sprites from Aseprite. Animation frames should be exported automatically with consistent naming and added to `animations.json` with the correct format.

## Source Files

- **Location:** `assets/animations/*.aseprite`
- **Structure:** Each animated entity gets its own `.aseprite` file
- **Animation definition:** Aseprite tags define named animations within each file
  - A single file can have multiple tags (e.g., `goblin.aseprite` with `idle`, `walk`, `attack` tags)
- **No tags fallback:** Files without tags export as `{filename}_no-tag` animation

## Export Output

### Frame Files

- **Output directory:** `assets/graphics/auto-exported-sprites-from-aseprite/` (same as static sprites)
- **Naming pattern:** `{filename}_{tag}_{frame:03d}.png`
  - Example: `goblin_idle_000.png`, `goblin_idle_001.png`, `goblin_walk_000.png`
  - No-tag example: `explosion_no-tag_000.png`, `explosion_no-tag_001.png`
- **Frame padding:** 3 digits (000-999)

### animations.json Format

Auto-exported animations follow the existing format with these additions:

```json
{
  "goblin_idle": {
    "frames": [
      {
        "sprite_UUID": "goblin_idle_000.png",
        "duration_seconds": 0.1,
        "fg_color": "WHITE",
        "bg_color": "NONE"
      },
      {
        "sprite_UUID": "goblin_idle_001.png",
        "duration_seconds": 0.1,
        "fg_color": "WHITE",
        "bg_color": "NONE"
      }
    ],
    "aseDirection": "forward"
  }
}
```

### Field Details

| Field | Source | Notes |
|-------|--------|-------|
| `sprite_UUID` | Generated filename | Matches exported PNG name |
| `duration_seconds` | Aseprite frame duration | Converted from ms to seconds |
| `fg_color` | Default `"WHITE"` | Standard tint color |
| `bg_color` | Default `"NONE"` | No background |
| `aseDirection` | Aseprite tag direction | `forward`, `reverse`, `pingpong`, `pingpong_reverse` |

## Pipeline Integration

### Just Recipes

```bash
# Existing recipe, now includes animations
just update-sprites      # export-aseprite + export-animations + rebuild-atlas

# New standalone recipe
just export-animations   # Only process animation files

# New watch recipe
just watch-animations    # Watch assets/animations/ for changes
```

### Recipe Flow

```
update-sprites
├── export-aseprite          # Static sprites from auto_export_assets.aseprite
├── export-animations        # Animated sprites from assets/animations/*.aseprite
│   ├── Clean existing frames (per-animation pattern match)
│   ├── Export frames via Aseprite CLI
│   ├── Parse Aseprite JSON for timing/tags
│   └── Update animations.json
└── rebuild-atlas            # TexturePacker rebuilds atlas
```

## Implementation

### New Python Script: `scripts/export_animations.py`

Responsibilities:
1. Discover all `.aseprite` files in `assets/animations/`
2. For each file:
   - Export to Aseprite JSON+sheet format (for metadata)
   - Export individual frames as PNGs
   - Parse JSON for tag names, frame ranges, durations, directions
3. **Clean before export:** Delete existing frames matching `{filename}_*_*.png` pattern
4. Generate/update `animations.json`:
   - Animation name: `{filename}_{tag}` (or `{filename}_no-tag`)
   - Preserve manually-created entries that don't match auto-export patterns
   - **Overwrite** auto-exported entries (source of truth is .aseprite files)

### Aseprite CLI Commands

```bash
# Export JSON data (for parsing metadata)
aseprite -b input.aseprite --data output.json --format json-array

# Export individual frames as PNGs
aseprite -b input.aseprite --save-as "{filename}_{tag}_{frame:03d}.png"
```

### Edge Cases

| Case | Behavior |
|------|----------|
| No tags in file | Export as `{filename}_no-tag` animation |
| Single frame animation | Valid - create animations.json entry |
| Empty frames in tag | Skip empty frames (Aseprite reports them) |
| Existing manual entry | Overwrite with auto-export data |
| File deleted | Orphaned frames remain (manual cleanup or `clean-animations`) |

## Animation System Update

The engine's animation system needs to support the new `aseDirection` field:

```lua
-- In animation playback code
local direction = anim.aseDirection or "forward"

if direction == "forward" then
    -- Normal playback
elseif direction == "reverse" then
    -- Play frames in reverse order
elseif direction == "pingpong" then
    -- Forward then reverse, repeat
elseif direction == "pingpong_reverse" then
    -- Reverse then forward, repeat
end
```

## File Structure

```
assets/
├── animations/                          # NEW: Animation source files
│   ├── goblin.aseprite                  # Has tags: idle, walk, attack
│   ├── explosion.aseprite               # No tags (single animation)
│   └── player.aseprite                  # Has tags: idle, run, jump, fall
├── graphics/
│   ├── animations.json                  # Updated by export script
│   ├── auto-exported-sprites-from-aseprite/
│   │   ├── goblin_idle_000.png          # NEW: Animation frames
│   │   ├── goblin_idle_001.png
│   │   ├── goblin_walk_000.png
│   │   ├── explosion_no-tag_000.png
│   │   ├── explosion_no-tag_001.png
│   │   └── ... (plus existing static sprites)
│   └── sprites_atlas-*.png              # Rebuilt by TexturePacker
└── auto_export_assets.aseprite          # Existing static sprites
```

## Testing Checklist

- [ ] Export single .aseprite file with one tag
- [ ] Export single .aseprite file with multiple tags
- [ ] Export file with no tags (→ `_no-tag` suffix)
- [ ] Frame timing matches Aseprite (ms → seconds conversion)
- [ ] Direction field matches Aseprite tag setting
- [ ] Re-export updates animations.json correctly
- [ ] Re-export with fewer frames cleans up orphans
- [ ] TexturePacker includes animation frames in atlas
- [ ] Engine plays animation with correct timing
- [ ] Engine respects aseDirection (pingpong, reverse)
- [ ] watch-animations triggers on file changes

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
