# Unit Testing Guide

Quick notes for adding tests while the EngineContext migration is ongoing.

- Build target: `unit_tests` (CMake option `ENABLE_UNIT_TESTS=ON` by default).
- Run locally:
  - `just test` (configures, builds, runs)
  - `scripts/run_tests.sh` (same flow, configurable path inside)
- Layout (all paths workspace-relative):
  - `tests/unit/` – normal unit specs
  - `tests/mocks/` – lightweight mocks (e.g., `MockEngineContext`)
  - `tests/helpers/` – glue/stubs (e.g., main_loop/ImGui stubs for linking)
- Add sources under test to `tests/CMakeLists.txt` if they’re not already part of the main target.
- Prefer context-aware APIs: use `MockEngineContext` and clear globals/UUID maps in test setup/teardown.
- Keep tests fast and hermetic; stub heavy systems instead of pulling real rendering/input.
- If linking fails on UI/ImGui, add minimal stubs in `tests/helpers/` rather than touching production code.

Goal: keep adding coverage alongside the globals→EngineContext refactor to catch regressions early.

## Related Docs
- [System Architecture Overview](SYSTEM_ARCHITECTURE.md) - Subsystem map, ownership, and init order.
- [C++ Documentation Standards](DOCUMENTATION_STANDARDS.md) - Comment templates and required coverage.


<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
