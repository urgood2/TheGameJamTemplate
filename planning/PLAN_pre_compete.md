# PLAN v0: End-to-End Game Testing System

**Status:** Draft
**Created:** 2026-02-02
**Based on:** [INTERVIEW_TRANSCRIPT.md](./INTERVIEW_TRANSCRIPT.md)

---

## Overview

Build a Playwright-like end-to-end testing framework for TheGameJamTemplate that can:
1. Launch the game in test mode
2. Inject scripted inputs (keys, mouse clicks, waits)
3. Verify results via screenshots, Lua state queries, and log assertions
4. Run headless for CI or visible for debugging

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Test Runner (Lua)                      │
│  • Loads test scripts                                       │
│  • Executes test steps sequentially                         │
│  • Reports pass/fail results                                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Test Mode (C++ Engine)                   │
│  • --test-mode flag enables test harness                    │
│  • Intercepts input system to read scripted inputs          │
│  • Exposes state query API to Lua                           │
│  • Screenshot capture on demand                             │
│  • Optional headless rendering (--headless)                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Verification Layer                       │
│  • assert_screenshot("baseline.png", threshold)             │
│  • assert_state("player.health", 80)                        │
│  • assert_log_contains("Enemy defeated")                    │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Test Mode Infrastructure (C++)

**Goal:** Enable the engine to run in a deterministic test mode.

| Task | Description |
|------|-------------|
| 1.1 | Add `--test-mode` command-line flag |
| 1.2 | Add `--headless` flag for windowless rendering (render to framebuffer) |
| 1.3 | Create `TestInputProvider` that overrides normal input |
| 1.4 | Expose `test_harness` global to Lua with input injection APIs |
| 1.5 | Add screenshot capture API (`test_harness.screenshot(path)`) |

**C++ APIs to expose:**
```cpp
// New test_harness bindings for Lua
test_harness.press_key(KEY_SPACE)
test_harness.release_key(KEY_SPACE)
test_harness.click(x, y)
test_harness.move_mouse(x, y)
test_harness.wait_frames(n)
test_harness.screenshot("path/to/output.png")
test_harness.get_state("path.to.value")  // Query Lua globals
test_harness.exit(code)
```

### Phase 2: Lua Test Framework

**Goal:** Create a simple, expressive test DSL in Lua.

| Task | Description |
|------|-------------|
| 2.1 | Create `tests/framework/test_runner.lua` |
| 2.2 | Implement `describe()` / `it()` test structure |
| 2.3 | Implement assertion helpers |
| 2.4 | Add test discovery (scan `tests/e2e/*.lua`) |
| 2.5 | JSON/TAP output for CI integration |

**Example test syntax:**
```lua
-- tests/e2e/menu_navigation_test.lua
local t = require("tests.framework.test_runner")

t.describe("Main Menu", function()
    t.it("should start game when Play is clicked", function()
        t.click_on("PlayButton")  -- Find by UI element name
        t.wait_for_scene("GameScene")
        t.assert_state("game.is_playing", true)
    end)

    t.it("should open settings menu", function()
        t.press_key(KEY_ESCAPE)
        t.wait_frames(10)
        t.assert_screenshot("settings_menu_open.png")
    end)
end)
```

### Phase 3: Verification Systems

**Goal:** Implement the three verification methods.

| Task | Description |
|------|-------------|
| 3.1 | Screenshot comparison with perceptual diff (allow threshold) |
| 3.2 | Lua state query system (traverse globals by path) |
| 3.3 | Log capture and assertion (ring buffer + pattern matching) |
| 3.4 | Baseline management (accept new baselines, update existing) |

**Screenshot comparison approach:**
- Use stb_image for loading
- Compute pixel-wise diff with configurable threshold
- Output diff image highlighting changes
- Store baselines in `tests/baselines/`

### Phase 4: CI Integration

**Goal:** Run tests automatically on every commit.

| Task | Description |
|------|-------------|
| 4.1 | GitHub Actions workflow for test execution |
| 4.2 | Artifact upload for failed screenshot diffs |
| 4.3 | Test result summary in PR comments |
| 4.4 | Parallel test execution (multiple test files) |

---

## File Structure

```
TheGameJamTemplate/
├── src/
│   └── testing/
│       ├── test_mode.hpp          # Test mode state and flags
│       ├── test_input_provider.cpp # Scripted input injection
│       ├── test_harness.cpp       # Lua bindings for test_harness
│       └── screenshot_compare.cpp  # Image diff utility
├── assets/scripts/
│   └── tests/
│       ├── framework/
│       │   ├── test_runner.lua    # Core test framework
│       │   ├── assertions.lua     # assert_*, expect_*
│       │   └── matchers.lua       # Screenshot/state matchers
│       └── e2e/
│           ├── menu_test.lua
│           ├── combat_test.lua
│           └── ui_test.lua
├── tests/
│   └── baselines/                 # Screenshot baselines
│       ├── menu_open.png
│       └── combat_idle.png
└── .github/
    └── workflows/
        └── e2e-tests.yml
```

---

## Open Questions

1. **Determinism**: How to handle random number generators? Seed them for tests?
2. **Timing**: Fixed timestep vs real-time for test execution?
3. **Asset loading**: Should tests wait for assets or assume preloaded?
4. **Web builds**: Should E2E tests run on Emscripten builds too?

---

## Success Criteria

- [ ] Can run `./game --test-mode --headless tests/e2e/menu_test.lua`
- [ ] Tests can simulate keyboard and mouse input
- [ ] Tests can assert on Lua game state
- [ ] Tests can compare screenshots with baseline images
- [ ] Tests produce CI-friendly output (exit code, JSON report)
- [ ] At least 3 example tests covering menu, combat, and UI

---

## Estimated Effort

| Phase | Complexity |
|-------|------------|
| Phase 1: Test Mode Infrastructure | Medium-High (C++ work) |
| Phase 2: Lua Test Framework | Medium |
| Phase 3: Verification Systems | Medium |
| Phase 4: CI Integration | Low |

---

## Next Steps

1. Review this plan and provide feedback
2. Prioritize which phase to start with
3. Identify any blocking dependencies
4. Begin implementation of Phase 1
