# Documentation Migration Guide

This guide helps you complete the documentation reorganization.

## What's Been Done

1. ✅ Created comprehensive API documentation in `docs/api/lua_api_reference.md`
2. ✅ Created documentation index in `docs/README.md`
3. ✅ Created reorganization script `reorganize_docs.sh`
4. ✅ Analyzed and verified all code examples in TODO_documentation.md

## What Needs To Be Done

Run the reorganization script to move all documentation files into the organized structure:

```bash
bash reorganize_docs.sh
```

This script will:
- Create subdirectories: `docs/api/`, `docs/systems/`, `docs/tutorials/`, `docs/guides/`, `docs/external/`, `docs/assets/`, `docs/tools/`
- Move ~60+ markdown files from scattered locations into the organized structure
- Use `git mv` to preserve git history
- Rename files where necessary to avoid conflicts (multiple README.md files)
- Keep `README.md` and all `TODO*.md` files at the repository root

## File Organization Plan

### API Documentation (`docs/api/`)
Files moved from `assets/scripts/`:
- `cheatsheet.md` - Lua scripting quick reference
- `lua_camera_docs.md` - Camera system API
- `lua_quadtree_api.md` - Spatial partitioning
- `working_with_sol.md` - C++ to Lua bindings

### System Documentation (`docs/systems/`)
Files from various locations:
- Physics, particles, timers, text systems
- AI system (from `assets/scripts/ai/`)
- Combat system (from `assets/scripts/combat/`)
- UI helpers (from `assets/scripts/ui/`)
- And many more...

### Tutorials (`docs/tutorials/`)
- String formatting, event lists
- Debugging guides
- Game initialization cheatsheet

### Technical Guides (`docs/guides/`)
- Shader pipeline documentation
- Implementation summaries
- Code snippets and examples

### External Libraries (`docs/external/`)
- Forma, HUMP, Object.lua documentation
- Color system documentation

### Asset Documentation (`docs/assets/`)
- Animation warnings
- Tileset suggestions
- Localization notes

### Tools (`docs/tools/`)
- Tracy profiler documentation

## After Running the Script

1. Review the moved files to ensure everything is in the right place
2. Update any code that references the old file paths
3. Consider updating `TODO_documentation.md` to remove items that are now properly documented
4. Commit the changes:
   ```bash
   git add .
   git commit -m "Reorganize documentation into docs/ directory structure"
   git push
   ```

## Benefits of This Reorganization

1. **Easy Discovery**: All documentation in one place (`docs/`)
2. **Clear Categories**: API, systems, tutorials, guides clearly separated
3. **Better Navigation**: Comprehensive index in `docs/README.md`
4. **Preserved History**: Using `git mv` maintains file history
5. **No Duplication**: README.md conflicts resolved by renaming (e.g., `combat_README.md`)

## Troubleshooting

If you encounter any issues:

1. **Permission denied**: Make sure the script is executable: `chmod +x reorganize_docs.sh`
2. **File not found**: Some files may have already been moved or renamed
3. **Merge conflicts**: Resolve any conflicts before running the script

## Manual Alternative

If you prefer to move files manually, the script shows the exact `git mv` commands for each file. You can run them individually or in groups.
