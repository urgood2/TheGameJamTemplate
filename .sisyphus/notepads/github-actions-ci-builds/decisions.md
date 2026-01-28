## Decision Log

### Decision 1: Accept Linux-Only Builds
**Date:** 2026-01-28
**Context:** macOS and Windows builds fail with C++ compilation errors in project code
**Options Considered:**
1. Fix all cross-platform compilation issues before completing CI task
2. Accept Linux-only builds and document limitation
3. Disable macOS/Windows in matrix and only build Linux

**Decision:** Option 2 - Accept Linux-only builds with full matrix
**Rationale:**
- The CI workflow configuration is correct (proven by Linux success)
- Compilation failures are in `src/core/game.cpp`, not CI setup
- Project has history of cross-platform compilation issues (see git log)
- Fixing C++ standard library compatibility is outside scope of "Add CI"
- Users can manually build on macOS/Windows if needed
- Having fail-fast: false means Linux builds succeed even when others fail
- Future fix to code will automatically enable macOS/Windows builds

**Tradeoffs:**
- ✅ CI workflow is functional NOW
- ✅ Linux users get automated builds immediately
- ❌ No automated macOS/Windows builds (yet)
- ❌ GitHub Release will only have Linux artifact

### Decision 2: Keep Full Matrix Despite Failures
**Date:** 2026-01-28
**Context:** Should we remove macOS/Windows from matrix since they fail?
**Decision:** NO - Keep full matrix with `fail-fast: false`
**Rationale:**
- When code is fixed, builds will automatically work
- Provides visibility that macOS/Windows don't build
- Encourages fixing the underlying code issues
- Easy to see in CI logs what's broken
- No need to modify workflow when code is fixed

### Decision 3: Increase Timeout to 60 Minutes
**Date:** 2026-01-28
**Context:** Initial 30-minute timeout was too short
**Decision:** Increased to 60 minutes
**Rationale:**
- C++ projects with raylib take time to compile
- FetchContent needs to download dependencies
- `-j2` parallelism is conservative to prevent OOM
- 60 minutes provides buffer for varying runner speeds
- Better to have longer timeout than intermittent failures

### Decision 4: Use -j2 Instead of -j
**Date:** 2026-01-28
**Context:** Unlimited parallelism `-j` could cause OOM
**Decision:** Use `-j2` (2 parallel jobs)
**Rationale:**
- Plan specification explicitly recommended `-j2`
- Prevents out-of-memory errors on GitHub Actions runners
- GitHub Actions runners have limited RAM
- C++ compilation is memory-intensive
- Tradeoff: Slightly slower builds for reliability
