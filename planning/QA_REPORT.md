# QA Report - 2026-02-04

## Build Status
- [x] Builds successfully OR N/A

## Test Summary
- Total: 355
- Passed: 355
- Failed: 0
- Skipped: 4 (disabled tests)

## UBS Scan
- Critical: 0 (in src/)
- Warnings: 0 (in src/)
- Notes: External dependencies have findings but are excluded from analysis

## Open Beads
- Open: 0
- In Progress: 6 (manual verification tasks)
- Blocked: 0

## Verdict
[x] READY TO SYNC - All checks pass
[ ] NEEDS FIXES - See issues above

## Fixed Issues
1. **GOAP test heap corruption** - Added value-initialization (`{}`) to `actionplanner_t` members in 4 test classes (`GOAPReplanDiffTest`, `GOAPPlanDriftTest`, `GOAPAtomCapTest`, `GOAPReplanToGoalTest`) to prevent `goap_actionplanner_clear()` from calling `free()` on garbage pointers
2. **Crash reporter dangling callback** - Added `crash_reporter::SetGameStateCallback(nullptr)` to `monobehavior_system::shutdown()` and ensured tests call `shutdown()` before local registry/lua go out of scope

## Resolved Beads
- `bd-1472`: Fixed CrashReporterTest segfault - root cause was dangling references in crash_reporter callback
