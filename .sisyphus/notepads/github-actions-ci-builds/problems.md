## Current Blockers & Issues

### ✅ RESOLVED: Workflow Configuration Issues
All workflow configuration issues have been resolved:
- ✅ `fail-fast` placement fixed
- ✅ Timeout increased to 60 minutes  
- ✅ Parallelism limited to `-j2`
- ✅ Accidentally committed `build-release/` removed

### ❌ UNRESOLVED: macOS Compilation Errors

**File:** `src/systems/physics/physics_world.hpp:399`
**Error:** `constexpr variable 'DEFAULT_COLLISION_TAG' must be initialized by a constant expression`
**Type:** C++20 constexpr initialization
**Impact:** Blocks macOS builds in CI

**File:** `src/systems/particles/particle.hpp:148, 259`
**Error:** `no matching constructor for initialization of 'Vector2'`
**Type:** Constructor matching/overload resolution
**Impact:** Blocks macOS builds in CI

**File:** `<__memory/allocator_traits.h>:304` (system header)
**Error:** `no matching function for call to 'construct_at'`
**Type:** C++20 standard library template instantiation
**Impact:** Blocks macOS builds in CI
**Context:** Triggered by something in `src/core/game.cpp`

**Root Cause:**
- Code works with newer clang (17.0.0 locally)
- Code fails with Xcode 15.4 clang in GitHub Actions
- Likely C++20 feature usage that's not fully supported in older clang

**Recommended Fix:**
1. Test locally with Xcode 15.4 to reproduce
2. Fix constexpr initialization in physics_world.hpp
3. Fix Vector2 constructor calls in particle.hpp
4. Investigate what template in game.cpp triggers construct_at error
5. OR: Upgrade to newer macOS runner with newer Xcode

### ❌ UNRESOLVED: Windows Compilation Errors

**Status:** Not investigated in detail yet
**Impact:** Blocks Windows builds in CI
**Known Context:** Project has history of Windows compilation issues (see git log)

**Recommended Approach:**
1. Get full error log from Windows build
2. Likely MinGW-specific issues or missing headers
3. May need Windows-specific code fixes

### Impact Assessment

**For Linux Users:** ✅ Zero impact - fully working
**For macOS Users:** ⚠️ Must build manually locally
**For Windows Users:** ⚠️ Must build manually locally  
**For CI/CD:** ⚠️ Only Linux artifacts in releases

### Out of Scope

The following are OUT OF SCOPE for "Add GitHub Actions CI" task:
- Fixing C++ compilation errors in project source code
- Debugging C++20 standard library compatibility issues
- Making codebase compile on all platforms
- Upgrading compiler toolchains in the codebase

These should be separate tasks:
- "Fix macOS compilation in GitHub Actions"
- "Fix Windows MinGW compilation issues"
- "Ensure C++20 compatibility across platforms"
