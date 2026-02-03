-- assets/scripts/test/test_registry_overrides.lua
-- Manual exceptions and overrides for test_registry.lua
--
-- This file is read by scripts/sync_registry_from_manifest.py
-- to apply manual exceptions to the auto-generated registry.
--
-- Use this for:
-- - Internal bindings not exposed to Lua gameplay
-- - Components that require visual verification only
-- - Deprecated items that won't receive tests
--
-- Format:
--   ["doc_id"] = { status = "verified"|"unverified", reason = "...", note = "..." }

return {
    -- Example entries (uncomment and modify as needed):
    --
    -- ["binding:physics.internal_function"] = {
    --     status = "unverified",
    --     reason = "Internal only, not exposed to Lua gameplay"
    -- },
    --
    -- ["component:DebugComponent"] = {
    --     status = "verified",
    --     test_id = "debug.manual_visual_check",
    --     note = "Manually verified via visual inspection"
    -- },
}
