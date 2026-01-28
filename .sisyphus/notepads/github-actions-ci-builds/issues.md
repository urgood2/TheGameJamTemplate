## [2026-01-28 01:08] Build Failures - Timeout and Parallelism

**Problem:**
- Initial builds failed with 30-minute timeout
- Using `-j` (unlimited parallelism) caused potential OOM/timeout issues

**Solution:**
- Increased timeout from 30 to 60 minutes
- Changed from `-j` to `-j2` (2 parallel jobs) to prevent OOM
- Per plan specification: `-j2` recommended to prevent OOM on CI runners

**Commits:**
- c0e90df37: fix(ci): increase timeout to 60min and limit parallelism to -j2 [build]
- 019be9581: fix(ci): move fail-fast into strategy block [build]
- c2a95deb2: fix(ci): remove accidentally committed build-release directory [build]

**Previous Issues Found:**
1. Workflow syntax error: `fail-fast: false` was at job level, needed to be in `strategy` block
2. Git submodule error: `build-release/` directory was accidentally committed

## [2026-01-28 10:42] Build Results - Mixed Success

**Run ID:** 21421261904

**Results:**
- ✅ **Linux (ubuntu-latest)**: SUCCESS
- ❌ **macOS (macos-14)**: FAILED - Compilation errors in src/core/game.cpp
- ❌ **Windows (windows-latest)**: FAILED - Compilation errors

**macOS Error:**
```
/Applications/Xcode_15.4.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/c++/v1/__memory/allocator_traits.h:304:9: error: no matching function for call to 'construct_at'
171 warnings and 6 errors generated.
make[2]: *** [CMakeFiles/raylib-cpp-cmake-template.dir/src/core/game.cpp.o] Error 1
```

**Analysis:**
- The CI workflow configuration is CORRECT (Linux build proves this)
- The failures are actual C++ code compilation issues, not CI configuration problems
- macOS: C++ standard library compatibility issue (likely C++20 features)
- Windows: Also compilation errors (need to investigate)

**Next Steps:**
1. Check Linux artifact to verify packaging works correctly
2. Investigate if these are known issues in the project
3. May need to adjust compiler flags or C++ standard for macOS/Windows
4. Or accept Linux-only builds for now and document the limitation
