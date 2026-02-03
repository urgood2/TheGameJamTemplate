# Engine Integration Points for Test Mode

## CLI Parsing
Location: `src/main.cpp:466` main entry point is `int main(void)` and constructs the engine via `createEngineContext("config.json")` before initialization.
Location: `src/testing/test_mode_config.cpp:423` provides `parse_test_mode_args` and `src/testing/test_mode_config.cpp:910` provides `validate_and_finalize`.
Hook strategy: Change `main` to `int main(int argc, char** argv)` and invoke `testing::parse_test_mode_args` before `createEngineContext`, then call `testing::validate_and_finalize` after config defaults are applied to decide test mode, output roots, and exit codes.
Existing abstractions: `testing::TestModeConfig` plus parsing and validation in `src/testing/test_mode_config.cpp`.
Refactor note: No argv path is currently available in `main`, so test-mode flags are not wired into the engine.

## Game Loop Timestep
Location: `src/main.cpp:244` `RunGameLoop` drives per-frame logic.
Location: `src/main.cpp:345` uses `GetFrameTime` and smoothing to compute `main_loop::mainLoop.rawDeltaTime` and `main_loop::mainLoop.smoothedDeltaTime`.
Location: `src/main.cpp:631` `updateSystems` is the main per-frame update entry point used for input, scripting, and systems.
Hook strategy: Insert test runtime frame stepping in `RunGameLoop` and `MainLoopFixedUpdateAbstraction` by gating on `TestModeConfig`, and override `main_loop::mainLoop.rate` and `main_loop::mainLoop.timescale` for determinism or fixed timestep.
Existing abstractions: `main_loop::initMainLoopData` in `src/main.cpp:488` sets update rate and framerate.
Refactor note: `RunGameLoop` already includes an internal `while (!WindowShouldClose())` loop, and `main` also loops over `RunGameLoop`, so test mode needs a single authoritative loop to avoid double-stepping.

## Input Backend
Location: `src/main.cpp:653` calls `input::Update` each update tick.
Location: `src/systems/input/input_functions.cpp:143` `input::Update` performs per-frame input handling and calls `handleRawInput`.
Location: `src/systems/input/input_polling.cpp:118` `poll_all_inputs` is the central polling function.
Location: `src/systems/input/input_polling.cpp:77` `input::polling::set_provider` swaps the input provider.
Hook strategy: In test mode, inject a deterministic input provider via `input::polling::set_provider` and feed recorded input into `poll_all_inputs` without calling Raylib directly.
Existing abstractions: `IInputProvider` and `RaylibInputProvider` in `src/systems/input/input_polling.cpp:21`.
Refactor note: Input is currently derived from Raylib polling; tests should override provider early in initialization.

## Renderer Readback
Location: `src/systems/layer/layer.cpp:1834` sets `shader_pipeline::SetLastRenderTarget` after shader passes.
Location: `src/systems/layer/layer.cpp:1837` stores the final `RenderTexture2D` for post-process output.
Location: `src/systems/shaders/shader_pipeline.hpp:497` exposes `GetLastRenderTarget` for retrieving the final render texture.
Hook strategy: Implement screenshot/readback by calling `LoadImageFromTexture` on the final render target returned by `shader_pipeline::GetLastRenderTarget` or by the post-pass cache before `EndDrawing`.
Existing abstractions: `shader_pipeline::GetLastRenderTarget` and `shader_pipeline::GetPostShaderPassRenderTextureCache`.
Refactor note: There is no existing screenshot/readback helper in the codebase; test mode should add a small utility that reads the last render texture into an `Image` and writes via `ExportImage`.

## Logger Sink
Location: `src/main.cpp:485` attaches the crash reporter sink to the default logger.
Location: `src/util/crash_reporter.cpp:330` defines `crash_reporter::AttachSinkToLogger`, which appends a ring-buffer sink to the logger.
Hook strategy: For test mode, add a dedicated sink that captures structured log events and enforces `--fail-on-log-level` and `--fail-on-log-category`, using the same pattern as `AttachSinkToLogger`.
Existing abstractions: `RingBufferSink` and `AttachSinkToLogger` in `src/util/crash_reporter.cpp`.
Refactor note: There is no log filtering by category or level beyond the spdlog global level.

## Lua Registry
Location: `src/systems/scripting/scripting_functions.cpp:88` `scripting::initLuaMasterState` opens libraries, sets Lua package path, and registers C++ bindings.
Location: `src/core/game.cpp:551` resets the master Lua state on hot reload.
Hook strategy: In test mode, register the test harness API by extending `scripting::initLuaMasterState` or adding a dedicated `test_harness::exposeToLua` call after core bindings.
Existing abstractions: `BindingRecorder` and the sequence of `exposeToLua` calls inside `scripting::initLuaMasterState`.
Refactor note: Lua globals are set during init without test-mode gating; a test-specific registry should be isolated to avoid contaminating normal gameplay.

## Verification Checklist
- CLI: Confirm `main` receives `argc/argv`, parse test flags using `testing::parse_test_mode_args`, and exit with code `2` on invalid flags.
- Game loop: Confirm a test-only loop can step frames deterministically without interacting with `WindowShouldClose`.
- Input: Confirm a custom `IInputProvider` feeds deterministic input events into `input::polling::poll_all_inputs`.
- Renderer readback: Confirm the final `RenderTexture2D` can be read into an `Image` and saved to disk under `tests/out/<run_id>/artifacts`.
- Logger: Confirm a custom spdlog sink receives all log messages and can trigger a failure on configured levels.
- Lua: Confirm test harness globals are registered in `scripting::initLuaMasterState` and can be invoked from a test script.
