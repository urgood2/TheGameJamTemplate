# QA Report - 2026-02-04

## Build Status
- [x] Builds successfully (with TRACY_ENABLE=OFF)
- Note: Full build succeeds but requires Tracy disabled for this Linux environment due to CPU TSC limitations

## Test Summary
- Total: 374 tests from 73 test suites
- Passed: Unknown (crashed before completion)
- Failed: 1+ (crash)
- Skipped: 0
- **Exit Code: 139 (SIGSEGV)** - Crash during `CrashReporterTest.DisabledConfigKeepsReporterOff`

## UBS Scan
- Files Scanned: 359
- Critical: 915 (mostly generic language checks, many false positives for C++ codebase)
- Warning: 8128
- Info: 11138
- Notes:
  - UBS is designed for multi-language projects; many findings are not applicable to this C++ game engine
  - No blocking issues from C++ specific analysis
  - Ruby/Rails/JS specific checks are false positives

## Open Beads
- Open: 2 (created during this QA)
- In Progress: 0
- Blocked: 0

## Verdict
- [ ] READY TO SYNC - All checks pass
- [x] NEEDS FIXES - See issues above

### Blocking Issues:
1. **SIGSEGV in Unit Tests** - Tests crash at `CrashReporterTest.DisabledConfigKeepsReporterOff` with exit code 139
2. **Tracy Profiler Compatibility** - Tests require `TRACY_ENABLE=OFF` due to CPU TSC limitations on this environment

## Created Beads
- `br-8mg`: Fix: SIGSEGV crash in CrashReporterTest.DisabledConfigKeepsReporterOff unit test (exit code 139) [P1]
- `br-2aj`: Fix: Tracy Profiler TSC compatibility - TRACY_TIMER_FALLBACK needed for test environments [P2]

## Environment Notes
- Platform: Linux (x86_64)
- Build-release executable is macOS ARM64 binary (not Linux compatible)
- Tests built successfully with: `cmake -B build -DENABLE_UNIT_TESTS=ON -DTRACY_ENABLE=OFF -DCMAKE_BUILD_TYPE=Release`

## Recommendations
1. Investigate and fix the segfault in CrashReporterTest (P1 - blocking)
2. Add TRACY_TIMER_FALLBACK to CMake config for CI/test environments without invariant TSC
3. Clear warning-level deprecation notices for globals API migration
