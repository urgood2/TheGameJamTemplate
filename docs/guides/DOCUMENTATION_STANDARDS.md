# C++ Documentation Standards

Guidelines for Doxygen-ready comments while the EngineContext and dependency-injection work is underway.

## Style Basics
- Use `/** ... */` blocks for public APIs; avoid `//` for interface docs.
- Keep the first line a short summary; follow with detail paragraphs and `@note` entries for constraints.
- Always state ownership, thread-safety, and initialization expectations.
- Place docs on declarations (headers) so both code and bindings see them.

## Templates

### File Header
```cpp
/**
 * @file engine_context.hpp
 * @brief Core engine state and dependency-injection container.
 */
```

### Class Comment
```cpp
/**
 * @class EngineContext
 * @brief Central state holder for all engine systems.
 *
 * Describes responsibilities and high-level usage. Mention required setup
 * and any invariants the class maintains.
 *
 * @note Thread-safety: Not thread-safe; main thread only unless noted.
 * @note Ownership: Owns subsystems via unique_ptr; destroyed in reverse order.
 * @see createEngineContext
 */
class EngineContext { /* ... */ };
```

### Function Comment
```cpp
/**
 * @brief Loads a texture into the atlas cache.
 *
 * @param path File path to load.
 * @param ctx EngineContext for cache access.
 * @return Result<Texture2D, std::string> with loaded texture or error text.
 *
 * @throws AssetLoadException on corrupt or missing file.
 * @note Thread-safety: main thread only.
 * @note Performance: may block on disk IO.
 */
Result<Texture2D, std::string> loadTexture(const std::string& path,
                                           EngineContext& ctx);
```

### Member Fields
```cpp
class PhysicsWorld {
private:
    /// Owned Chipmunk space (freed in destructor).
    std::unique_ptr<physics::Space> space_;
    /// Observer pointer; lifetime tied to space_.
    cpBody* staticBody_ = nullptr;
    /// Last step delta in seconds.
    float lastStepDt = 0.0f;
};
```

## Required Coverage
- Public headers: file purpose, when to include, notable platform constraints.
- Public classes: responsibilities, ownership semantics, thread-safety, usage sketch.
- Public APIs: params, return, errors/exceptions, side effects, perf notes, pre/postconditions.
- Components/structs with pointers: call out owner vs observer and lifetime.
- Systems touching EngineContext/registry: note required initialization order.

## Practical Rules
- Document invariants and sharp edges instead of restating obvious work.
- Keep examples small and EngineContext-aware; avoid heavy setup in docs.
- If behavior differs on web/native, record the divergence in a `@note`.
- Prefer updating comments when changing signatures; stale docs are worse than none.
- When unsure, add an `@note` explaining the current limitation instead of TODOs.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
