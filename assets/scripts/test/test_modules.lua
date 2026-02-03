-- assets/scripts/test/test_modules.lua
-- Deterministic list of all test modules.
--
-- Order matters for reproducibility. Tests are loaded and registered
-- in this exact order. Modify with care.
--
-- Categories:
--   selftest  - Test harness self-tests (run first to validate harness)
--   unit      - Unit tests for specific systems
--   smoke     - Quick smoke tests for basic functionality
--   visual    - Visual/screenshot tests
--
-- To add a new test module:
-- 1. Create the file in assets/scripts/test/
-- 2. Add entry here with correct order/category
-- 3. Run the test suite to verify

return {
    -- ==== Self-tests (validate harness first) ====
    "test.test_selftest",           -- Basic harness self-tests
    "test.test_harness_self_test",  -- Comprehensive harness self-tests (53 tests)

    -- ==== Smoke tests (quick validation) ====
    "test.test_smoke",              -- Basic smoke tests

    -- ==== Entity & ECS ====
    "test.test_entity_lifecycle",   -- Entity lifecycle patterns

    -- ==== Localization ====
    "test.test_styled_localization", -- Styled localization tests

    -- ==== Future test modules (uncomment as created) ====
    -- "test.test_physics_bindings",
    -- "test.test_ui_bindings",
    -- "test.test_timer_anim_bindings",
    -- "test.test_core_bindings",
    -- "test.test_input_sound_ai_bindings",
    -- "test.test_shader_layer_bindings",
    -- "test.test_ui_patterns",
    -- "test.test_core_patterns",
    -- "test.test_combat_patterns",
    -- "test.test_data_patterns",
    -- "test.test_wand_patterns",
}
