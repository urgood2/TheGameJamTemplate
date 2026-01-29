# Sprite Atlas Workflow

## Overview

Sprites are managed through a two-stage pipeline:
1. **Aseprite** → Individual PNG files (one per layer)
2. **TexturePacker** → Packed atlas sheets + JSON metadata

## File Locations

| File | Purpose |
|------|---------|
| `assets/auto_export_assets.aseprite` | Source file with sprite layers |
| `assets/graphics/auto-exported-sprites-from-aseprite/` | Exported PNGs (auto-generated) |
| `assets/graphics/sprites_texturepacker.tps` | TexturePacker project (has smart folder) |
| `assets/graphics/sprites_atlas-{n}.png` | Output atlas sheets |
| `assets/graphics/sprites-{n}.json` | Output sprite metadata |

## Commands

```bash
just check-sprite-tools       # Verify Aseprite/TexturePacker installed
just export-aseprite          # Export Aseprite layers to PNGs
just rebuild-atlas            # Rebuild TexturePacker atlas
just update-sprites           # Full pipeline (export + rebuild)
just watch-sprites            # Auto-rebuild on file changes (requires fswatch)
just clean-sprites            # Remove exported PNGs
```

## Quick Workflow

```bash
# 1. Edit sprites in Aseprite
open assets/auto_export_assets.aseprite

# 2. Run the pipeline (exports layers + rebuilds atlas)
just update-sprites

# 3. Use sprite in Lua by layer name
local entity = animation_system.createAnimatedObjectWithTransform("LayerName", false)
```

## Auto-Rebuild on Save

```bash
# Install fswatch (one-time)
brew install fswatch

# Start watcher (runs in foreground)
just watch-sprites
```

The watcher monitors `assets/auto_export_assets.aseprite` and automatically runs `just update-sprites` when the file is saved (with 2-second debounce).

### VS Code Auto-Start

The sprite watcher starts automatically when you open the workspace in VS Code. This is configured via `.vscode/tasks.json` with `runOn: folderOpen`.

**First-time setup:** VS Code will prompt "This workspace has tasks that run on folder open. Do you want to allow them to run?" — click **Allow and Run**.

**Manual control:**
- Stop: Click trash icon on the "Watch Sprites" terminal tab
- Start: `Cmd+Shift+P` → "Tasks: Run Task" → "Watch Sprites"
- View output: Check the "Watch Sprites" tab in Terminal panel

## Layer Naming Rules

- Layer names become sprite identifiers (e.g., layer "player_idle" → sprite "player_idle")
- Names must be unique (duplicates overwrite)
- Avoid special characters (`/`, `\`, `:`, etc.)
- Hidden layers are included (uses `--all-layers` flag)

## Adding to Existing Atlas

The TexturePacker project uses a **smart folder** pointing to `auto-exported-sprites-from-aseprite/`. Any PNG added to this folder is automatically included in the next atlas rebuild.

To add sprites manually:
1. Drop PNG files into `assets/graphics/auto-exported-sprites-from-aseprite/`
2. Run `just rebuild-atlas`

## How It Works

### Aseprite Export

The `just export-aseprite` command runs:
```bash
aseprite -b assets/auto_export_assets.aseprite \
  --all-layers \
  --save-as "assets/graphics/auto-exported-sprites-from-aseprite/{layer}.png"
```

This exports each layer as a separate PNG file named after the layer.

### TexturePacker Rebuild

The `just rebuild-atlas` command runs:
```bash
TexturePacker assets/graphics/sprites_texturepacker.tps
```

TexturePacker reads the `.tps` project file which includes:
- Smart folder watching `auto-exported-sprites-from-aseprite/`
- All other sprite sources in `pre-packing-files_globbed/`
- Output settings (4096x4096 max, JSON-array format, etc.)

## Troubleshooting

```bash
# Verify tools are installed
just check-sprite-tools

# Clean and rebuild from scratch
just clean-sprites
just update-sprites

# Check if sprite is in atlas
grep "sprite_name" assets/graphics/sprites-*.json

# View exported files
ls -la assets/graphics/auto-exported-sprites-from-aseprite/
```

### Common Issues

| Issue | Solution |
|-------|----------|
| "Aseprite not found" | Check Steam/Applications install paths |
| "TexturePacker not found" | Install from codeandweb.com |
| Sprite not appearing in atlas | Check layer name, run `just rebuild-atlas` |
| fswatch not working | Install with `brew install fswatch` |

## Tool Requirements

- **Aseprite**: Any recent version (tested with 1.3.16.1)
- **TexturePacker**: Version 7.x with Pro license (CLI requires Pro)
- **fswatch** (optional): For auto-rebuild on save (`brew install fswatch`)

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
