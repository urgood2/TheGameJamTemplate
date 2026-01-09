# Memory Management Guide

Generated: 2026-01-09
Branch: cpp-refactor (Phase 6)

## Summary

| Category | Status |
|----------|--------|
| RAII wrappers for Chipmunk | ✅ Complete |
| Memory safety tests | ✅ 20+ tests |
| Third-party wrapper allocations | ⚠️ Raw new/delete (intentional) |
| AddressSanitizer support | ✅ `just test-asan` |

## RAII Patterns

### Chipmunk Physics (`src/systems/physics/chipmunk_raii.hpp`)

```cpp
namespace physics {
    // Custom deleters for Chipmunk types
    struct CpBodyDeleter {
        void operator()(cpBody* b) const noexcept { if (b) cpBodyFree(b); }
    };
    struct CpShapeDeleter {
        void operator()(cpShape* s) const noexcept { if (s) cpShapeFree(s); }
    };
    struct CpConstraintDeleter {
        void operator()(cpConstraint* c) const noexcept { if (c) cpConstraintFree(c); }
    };
    struct CpSpaceDeleter {
        void operator()(cpSpace* s) const noexcept { if (s) cpSpaceFree(s); }
    };

    // Smart pointer types
    using BodyPtr = std::unique_ptr<cpBody, CpBodyDeleter>;
    using ShapePtr = std::unique_ptr<cpShape, CpShapeDeleter>;
    using ConstraintPtr = std::unique_ptr<cpConstraint, CpConstraintDeleter>;
    using SpacePtr = std::unique_ptr<cpSpace, CpSpaceDeleter>;
}
```

### Usage Example

```cpp
// Instead of:
cpBody* body = cpBodyNew(mass, moment);
// ... use body
cpBodyFree(body);  // Easy to forget!

// Use:
physics::BodyPtr body(cpBodyNew(mass, moment));
// ... use body.get()
// Automatically freed when body goes out of scope
```

## Third-Party Chipmunk Wrappers

The Objective-C style wrappers in `src/systems/chipmunk_objectivec/` use raw `new`/`delete`:

| File | Allocations | Notes |
|------|-------------|-------|
| ChipmunkSpace.cpp | `_staticBody = new ChipmunkBody(...)` | Owned by ChipmunkSpace destructor |
| ChipmunkBody.cpp | Factory methods return raw pointers | Caller owns |
| ChipmunkShape.hpp | Factory methods return raw pointers | Caller owns |
| ChipmunkConstraints.hpp | Factory methods return raw pointers | Caller owns |
| ChipmunkMultiGrab.hpp | `new Grab(...)` | Managed internally |
| ChipmunkTileCache.hpp | `new CachedTile(...)` | Managed by cache |

**Why not convert?** These are stable wrappers that mirror Chipmunk's Objective-C API. Converting to smart pointers would:
- Change ownership semantics
- Risk breaking existing code
- Provide minimal benefit (no memory leaks detected)

## Memory Safety Testing

### Test File: `tests/unit/test_memory_safety.cpp`

Coverage includes:
- Rapid shader load/unload cycles
- Uniform operations with various string lengths
- Component copy/move semantics
- Smart pointer ownership transfer
- Edge cases (empty containers, self-assignment)
- Large allocations stress test

### Running with AddressSanitizer

```bash
just test-asan
```

This builds with `-fsanitize=address` to detect:
- Use-after-free
- Buffer overflows
- Memory leaks
- Double-free

## Guidelines for New Code

### DO Use Smart Pointers

```cpp
// Owned resource
auto texture = std::make_unique<Texture2D>();

// Shared resource
auto shader = std::make_shared<Shader>();

// Non-owning pointer (use raw pointer or reference)
void processShader(Shader* shader);  // Caller owns
void processShader(Shader& shader);  // Preferred
```

### DON'T Use Raw new/delete

```cpp
// Bad
auto* obj = new MyObject();
// ...
delete obj;  // Easy to leak!

// Good
auto obj = std::make_unique<MyObject>();
// Automatically cleaned up
```

### Use RAII Guards

```cpp
// For cleanup actions
struct ScopeGuard {
    std::function<void()> cleanup;
    ~ScopeGuard() { if (cleanup) cleanup(); }
};

void riskyOperation() {
    acquireResource();
    ScopeGuard guard{[]{ releaseResource(); }};
    // ... do work
    // Resource released even if exception thrown
}
```

## Verification Commands

```bash
# Run memory safety tests
./build/tests/unit_tests --gtest_filter="*MemorySafety*"

# Run with AddressSanitizer
just test-asan

# Check for raw new/delete in new code
git diff HEAD~10 -- "*.cpp" "*.hpp" | grep -E "new\s+\w|delete\s+"
```

## References

- [C++ Core Guidelines: Resource Management](https://isocpp.github.io/CppCoreGuidelines/CppCoreGuidelines#S-resource)
- [chipmunk_raii.hpp](../../src/systems/physics/chipmunk_raii.hpp)
- [test_memory_safety.cpp](../../tests/unit/test_memory_safety.cpp)
