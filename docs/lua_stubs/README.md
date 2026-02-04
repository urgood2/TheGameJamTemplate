# EmmyLua Stubs

This directory contains generated EmmyLua stubs for Lua Language Server (LuaLS).

## Regeneration

```bash
python3 scripts/generate_stubs.py
```

Outputs are derived from:
- `planning/inventory/bindings.*.json`
- `planning/inventory/components.*.json`

Do not edit the stub files by hand; regenerate instead.

## CI Drift Check

CI regenerates stubs and compares them against `docs/lua_stubs/`. If there is a diff,
the check fails and you should rerun:

```bash
python3 scripts/generate_stubs.py
```

The drift check is implemented in `scripts/e2e_test_scenarios.py` (stub scenario).

## Stub Format

Generated stubs use standard EmmyLua annotations:
- `---@meta` for module files
- `---@class` and `---@field` for usertypes/components
- `---@param` and `---@return` for functions

Globals that are not namespaced should be added to `.luarc.json` to keep IDE
diagnostics in sync with the runtime environment.
