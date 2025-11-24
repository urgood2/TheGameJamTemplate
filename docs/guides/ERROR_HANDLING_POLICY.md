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

## Lua Boundary
- Wrap C++->Lua calls; catch `sol::error` and log script name + function + message.
- Provide safe stubs for missing Lua functions when reasonable; otherwise bubble failure.
- Never swallow errors during init; during runtime, log and degrade gracefully where safe.

## Asset Loading
- Required asset missing: log + fail init; surface message to caller/test.
- Optional asset missing: log warning + load placeholder (solid color/1x1 texture) and tag it.
- Shader compile fail: log full shader name/stage + info log; fall back to default shader.

## Testing Hooks
- Add unit tests for Result-returning functions; assert both success and failure paths.
- Add a smoke test that fails if required assets/configs are missing.
- In tests, prefer injecting mock/fallback assets via EngineContext rather than touching globals.

## Logging Levels
- `LOG_ERROR`: crashes or undefined behavior if ignored.
- `LOG_WARNING`: degraded behavior with fallback.
- `LOG_INFO`: expected-but-rare branches (e.g., hot-reload placeholder used).

## Ownership & Lifetimes
- If recovery requires freeing/reallocating resources, document the owner; avoid raw-pointer escape hatches without comments.
- Do not retry by recreating EngineContext mid-frame; tear down and reinit instead.
