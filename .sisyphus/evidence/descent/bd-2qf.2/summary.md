# bd-2qf.2: [Descent] A2 Test runner + RUN_DESCENT_TESTS hook + watchdog

## Implementation Summary

### Files Created/Modified

1. **Created `assets/scripts/tests/run_descent_tests.lua`**
   - Implements `DescentTestRunner.reset()` - resets test state
   - Implements `DescentTestRunner.run_all()` - runs all Descent tests and returns success/fail
   - 15-second watchdog timeout per PLAN.md §5.2
   - Prints seed, current test name, and summary
   - Handles module load errors with error message and exit code 1
   - Works independently of `ENABLE_DESCENT=1`

2. **Created `assets/scripts/tests/test_descent_smoke.lua`**
   - Basic smoke tests to verify test infrastructure works
   - Tests: runner module loading, seed handling, environment variables, basic Lua functions

3. **Modified `assets/scripts/core/main.lua`**
   - Added early hook in `main.init()` to check `RUN_DESCENT_TESTS=1`
   - Runs tests before any game state initialization
   - Exits with code 0 on pass, 1 on fail/timeout/error

### Acceptance Criteria (per PLAN.md)

| Criteria | Status |
|----------|--------|
| `RUN_DESCENT_TESTS=1` exits 0 on green | ✅ Implemented |
| Failed test exits 1 | ✅ Implemented |
| Module load failure prints error + exits 1 | ✅ Implemented |
| Watchdog timeout exits 1 + prints seed/test | ✅ Implemented (15s) |
| Works without `ENABLE_DESCENT=1` | ✅ Implemented |

### Key Design Decisions

1. **Watchdog uses `os.clock()`** - wall-clock timeout checked after each module load and after test run
2. **Seed management** - reads `DESCENT_SEED` env var, falls back to `os.time()` for random seed
3. **Test discovery** - currently uses explicit list of test modules (extensible)
4. **Early hook** - test runner runs before telemetry/save system/UI initialization

### Commands to Verify

```bash
# Build the project
just build-debug
# or
cmake -B build -DCMAKE_BUILD_TYPE=Debug -DENABLE_UNIT_TESTS=OFF && cmake --build build -j

# Run Descent tests
AUTO_EXIT_AFTER_TEST=1 RUN_DESCENT_TESTS=1 ./build/raylib-cpp-cmake-template | tee /tmp/descent_tests.log
echo "exit=$?"
```

### Notes

- Build tools were not available in this environment for runtime testing
- Implementation follows existing patterns from `test_runner.lua` and `run_standalone.lua`
- Lua syntax validated through code review

## Agent

- **Agent**: BoldMountain
- **Date**: 2026-02-01
