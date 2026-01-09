# Error Handling Policy

Lightweight guidance for adding guardrails during the EngineContext migration.

## Goals
- Fail loudly on developer errors; fail soft with user-facing fallbacks when safe.
- Keep crashes reproducible: log context, ids, and config paths.
- Avoid global mutation as recovery; prefer scoped fallbacks and Result-returning APIs.

## Classification
- Critical (fail-fast): invalid config/schema, missing required assets, invariant violations, null EngineContext/registry, double-free/ownership errors.
- Recoverable (fallback/log): optional asset missing, shader compile failure with compatible fallback, minor Lua script error in non-critical path.
- Deferred (warn/track): perf regressions, feature flags missing, non-blocking cache misses.

## Practices
- Prefer `Result<T, std::string>` or optional + explicit error string over silent defaults.
- Always log with system prefix: `[asset]`, `[lua]`, `[physics]`, `[render]`, `[ctx]`.
- Include identifiers in errors: entity id, asset name, shader name, config path.
- Keep recovery local: substitute fallback texture/color/shader; do not mutate globals.
- When disabling a feature (e.g., post-process shader), log once and continue.
- Propagate context: functions taking `EngineContext&` should not reach for globals during recovery.

## Exception + Result Patterns
- Exception types (C++): `EngineException`, `AssetLoadException`, `ConfigException`, `PhysicsException` (derive from `std::runtime_error`).
- Result wrapper (recoverable paths):
  ```cpp
  template<typename T, typename E = std::string>
  class Result {
      std::variant<T, E> data;
      bool ok;
  public:
      Result(T v) : data(std::move(v)), ok(true) {}
      Result(E e) : data(std::move(e)), ok(false) {}
      bool isOk() const { return ok; }
      bool isErr() const { return !ok; }
      T&& valueOrThrow() {
          if (!ok) throw std::runtime_error(std::get<E>(data));
          return std::move(std::get<T>(data));
      }
      T valueOr(T def) const { return ok ? std::get<T>(data) : def; }
      const E& error() const { return std::get<E>(data); }
  };
  ```
- Logging helper:
  ```cpp
  template<typename Fn>
  auto tryWithLog(Fn&& fn, std::string ctx)
      -> Result<decltype(fn()), std::string> {
      try { return Result(fn()); }
      catch (const std::exception& e) {
          SPDLOG_ERROR("[{}] {}", ctx, e.what());
          return Result<decltype(fn()), std::string>(e.what());
      }
  }
  ```
- Retry helper:
  ```cpp
  template<typename T>
  Result<T, std::string> loadWithRetry(std::function<Result<T>()> loader,
                                       int maxRetries = 3,
                                       std::chrono::milliseconds delay = 100ms) {
      for (int i = 0; i < maxRetries; ++i) {
          if (auto r = loader(); r.isOk()) return r;
          SPDLOG_WARN("retry {}/{}", i + 1, maxRetries);
          std::this_thread::sleep_for(delay);
      }
      return loader(); // final attempt
  }
  ```

## Helper Usage (live code)
- Asset loading: textures (`init.cpp`) and shaders (`shader_system.cpp`) use `tryWithLog`/`Result` to log and skip bad loads (guarding `id==0`); sound loading is guarded the same way.
- Audio init: wrapped with `tryWithLog` to log and exit cleanly if device setup fails.
- Lua calls: `safeLuaCall` wraps `main.init/update/draw`, AI action start/finish/abort hooks, timer callbacks, controller nav focus/select hooks, `camera.with` callbacks, layer queue/execute init lambdas, physics collision callbacks, script coroutines, and text wait coroutines; errors are logged with context instead of failing silently.
- Controller navigation: group/global select callbacks prefer group handlers; both focus and select callbacks are wrapped in `safeLuaCall` and have regression tests.

## Lua Boundary
- Wrap C++->Lua calls; catch `sol::error` and log script name + function + message.
- Provide safe stubs for missing Lua functions when reasonable; otherwise bubble failure.
- Never swallow errors during init; during runtime, log and degrade gracefully where safe.
- Example wrapper:
  ```cpp
  template<typename... Args>
  auto safeLuaCall(sol::state& lua, const std::string& fn, Args&&... args)
      -> Result<sol::object, std::string> {
      sol::protected_function f = lua[fn];
      auto res = f(std::forward<Args>(args)...);
      if (!res.valid()) return Result<sol::object, std::string>(sol::error(res).what());
      return Result<sol::object, std::string>(res);
  }
  ```

## Asset Loading
- Required asset missing: log + fail init; surface message to caller/test.
- Optional asset missing: log warning + load placeholder (solid color/1x1 texture) and tag it.
- Shader compile fail: log full shader name/stage + info log; fall back to default shader.

## Testing Hooks
- Add unit tests for Result-returning functions; assert both success and failure paths.
- Add a smoke test that fails if required assets/configs are missing.
- In tests, prefer injecting mock/fallback assets via EngineContext rather than touching globals.
- Add config validation tests for required fields (e.g., `screenWidth`, `fonts`).
- Coverage to keep: `safeLuaCall` focus/select in controller nav, sound config loader rejecting malformed JSON/types, tryWithLog success/failure paths.

## Logging Levels
- `LOG_ERROR`: crashes or undefined behavior if ignored.
- `LOG_WARNING`: degraded behavior with fallback.
- `LOG_INFO`: expected-but-rare branches (e.g., hot-reload placeholder used).

## Ownership & Lifetimes
- If recovery requires freeing/reallocating resources, document the owner; avoid raw-pointer escape hatches without comments.
- Do not retry by recreating EngineContext mid-frame; tear down and reinit instead.
- If recovery frees and reallocates GPU/physics objects, state ownership and thread expectations inline.

## Decision Tree

```
Error occurs
    │
    ├─► Is it a developer bug? (null ptr, invalid args, invariant violation)
    │       └─► YES: throw exception / assert (fail fast)
    │
    ├─► Is recovery possible without user impact?
    │       └─► YES: Use Result<T,E>, log warning, apply fallback
    │
    ├─► Is it during initialization?
    │       └─► YES: Log error, fail init cleanly
    │
    ├─► Is it a Lua callback?
    │       └─► YES: Use safeLuaCall, log with context, continue
    │
    └─► Default: Log error with system prefix, return error state
```

## Quick Reference

| Scenario | Pattern |
|----------|---------|
| C++ function that can fail | Return `Result<T, std::string>` |
| Lua callback | Wrap with `safeLuaCall()` |
| Exception-throwing code | Wrap with `tryWithLog()` |
| Asset that might not exist | Use `loadWithRetry()` or guard with fallback |
| Lambda in Sol2 binding | Use `LUA_BINDING_TRY`/`CATCH` macros |
