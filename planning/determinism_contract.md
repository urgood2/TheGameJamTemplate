# Determinism Contract (Phase 0)

This document captures the determinism requirements for test mode and the current engine audit findings.

## Rule 1: Wall-Clock Time
Requirement: Simulation time must be derived from frame count and fixed dt, not wall-clock.
Audit:
- `src/main.cpp:345` uses `GetFrameTime()` to compute `rawDeltaTime` and drives `main_loop::mainLoop` timers.
- `src/core/init.cpp:903-908` seeds RNG with `std::chrono::system_clock::now()`.
Status: Not compliant for test mode.
Mitigation:
- In test mode, override dt with fixed timestep and avoid using `GetFrameTime()` to drive simulation.
- Replace wall-clock seeding with deterministic seed from `TestModeConfig` in test mode.
Tripwire: `DET_TIME`.

## Rule 2: Seeded RNG
Requirement: All RNG must be seeded deterministically and reset per test/run.
Audit:
- `src/core/init.cpp:903-908` seeds RNG from system clock.
- `src/core/init.cpp:979-981` seeds RNG from config seed.
Status: Partially compliant.
Mitigation:
- In test mode, force deterministic seed from CLI (`--seed`) and re-seed per test/run.
Tripwire: `DET_RNG`.

## Rule 3: Stable Update Order
Requirement: No unordered container iteration affecting outcomes.
Audit:
- `src/core/init.cpp:67-123` uses `std::filesystem::recursive_directory_iterator` and `std::unordered_set` for asset scanning.
- `src/systems/ai/ai_system.cpp:770-785` uses `std::filesystem::directory_iterator` for Lua file discovery without sorting.
Status: Not compliant for deterministic ordering.
Mitigation:
- Sort all directory enumeration results before use.
- Avoid iterating `unordered_*` containers in gameplay-critical paths or copy to sorted vectors.
Tripwire: `DET_FS_ORDER` and `DET_UPDATE_ORDER`.

## Rule 4: Deterministic Async
Requirement: Jobs must be disabled or have a stable completion order.
Audit:
- `src/core/init.cpp:1095-1147` uses a background thread for async init.
- `src/main.cpp:504-513` starts async init with `init::startInitAsync` and waits.
Status: Not compliant for deterministic test mode.
Mitigation:
- In test mode, disable async initialization and run `init::startInit()` synchronously.
- Force single-thread execution for job systems in test mode.
Tripwire: `DET_ASYNC_ORDER`.

## Rule 5: Deterministic Asset Streaming
Requirement: Tests must be able to wait for asset readiness.
Audit:
- `src/core/init.cpp:827-895` loads assets during base init, and async init uses loading stages.
- `src/main.cpp:506-513` loops on loading progress before continuing.
Status: Partially compliant.
Mitigation:
- Expose an explicit `wait_until_assets_loaded()` for tests.
- Provide deterministic signals from loading_screen or asset manager.
Tripwire: `DET_ASSET_READY`.

## Rule 6: Pinned FP Environment
Requirement: Set FTZ/DAZ and rounding mode at startup in test mode.
Audit:
- No explicit FP environment configuration found in core init or main loop.
Status: Not compliant.
Mitigation:
- Add FP environment pinning during test-mode startup and record in run manifest.
Tripwire: `DET_FP`.

## Rule 7: Pinned Environment
Requirement: Set locale=C and timezone=UTC for deterministic formatting.
Audit:
- No explicit locale or timezone pinning detected in startup code.
Status: Not compliant.
Mitigation:
- Set `setlocale(LC_ALL, "C")` and force `TZ=UTC` early in test mode.
Tripwire: `DET_ENV`.

## Rule 8: Filesystem Determinism
Requirement: Directory enumeration must be sorted and no mtime-based logic.
Audit:
- `src/core/init.cpp:88-93` enumerates assets with `recursive_directory_iterator`.
- `src/systems/ai/ai_system.cpp:770-785` enumerates Lua files with `directory_iterator`.
Status: Not compliant.
Mitigation:
- Sort collected paths deterministically before use.
Tripwire: `DET_FS_ORDER`.

## Rule 9: GPU Sync for Readback
Requirement: Screenshot/readback occurs at defined frame boundary after render passes.
Audit:
- `src/systems/layer/layer.cpp:1834-1855` tracks `shader_pipeline::GetLastRenderTarget`, but no readback helper exists.
Status: Not compliant.
Mitigation:
- Add synchronous readback utility using the last render target and perform capture at the end of render.
Tripwire: `DET_GPU_SYNC`.

## Rule 10: Network Disabled
Requirement: Network is off by default and blocked in test mode.
Audit:
- `src/main.cpp:583-590` records telemetry and flushes, implying network use.
Status: Not compliant.
Mitigation:
- Gate telemetry and any network clients behind `--allow-network` (deny by default).
- Add network tripwire or socket block in test mode.
Tripwire: `DET_NET`.

## Tripwire Codes
- `DET_TIME`
- `DET_RNG`
- `DET_UPDATE_ORDER`
- `DET_ASYNC_ORDER`
- `DET_ASSET_READY`
- `DET_FP`
- `DET_ENV`
- `DET_FS_ORDER`
- `DET_GPU_SYNC`
- `DET_NET`

## Summary
- The engine currently violates determinism for test mode in wall-clock usage, RNG seeding, async init, filesystem ordering, FP/environment pinning, GPU readback, and network gating.
- Implementing the mitigations above is required before determinism claims can be made in `run_manifest.json`.
