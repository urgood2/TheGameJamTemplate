Telemetry plan (desktop + web)
==============================

Objectives
----------
- Light-weight, opt-in telemetry to spot crashes, feature usage, and shader failures across desktop and web builds.
- Never ship PII; only anonymous install id plus coarse session/app info.
- Safe failure mode: if the network is unavailable, drop or cache locally without affecting gameplay.

What to collect
---------------
- Session lifecycle: app start/stop, build id, platform, version, locale.
- Error/crash breadcrumbs: shader load/compile failures, asset misses, fatal exceptions (reuse existing crash reporter hooks).
- Feature checkpoints: screen/view names, menu actions, level start/end, optional custom events from scripts.
- Performance pulses: frame time histogram + GPU/CPU name (coarsened), sent at most once every few minutes.

Common architecture
-------------------
- `telemetry::Event { name, ts, props (string/number/bool) }`
- `telemetry::Sink` interface with `Enqueue(Event)` and `Flush()`.
- `TelemetryService` holds a ring buffer, batches to JSON array payloads (max N events or T seconds).
- Build flag: `ENABLE_TELEMETRY` (CMake option) gates compilation; config flag: `config.json -> telemetry.enabled` gates runtime.
- Config keys (all optional): `telemetry.enabled` (bool), `telemetry.endpoint` (string), `telemetry.api_key` (string).
- `installation_id`: UUID stored in `assets/config.json` or a small sidecar file; web uses `localStorage`.
- Provide a `NullSink` so the code path is a no-op when disabled; swap to an HTTPS sink when enabled.

Endpoint options
----------------
- Default to no endpoint in configs; telemetry stays off until explicitly configured.
- For local testing: run an OpenTelemetry collector and point at `http://localhost:4318/v1/logs` (OTLP/HTTP). The stub sink can POST JSON batches here without auth.
- For hosted, low-cost collectors:
  - Cloudflare Worker + Durable Object/KV (HTTPS endpoint you control)
  - Fly.io/Render free tier HTTP service writing to S3-compatible storage
  - Supabase/Neon/PostHog/Plausible free tiers if you prefer managed analytics
- Keep the endpoint and API key fully configurable so builds don’t hard-code vendor URLs.

Desktop (Windows/macOS/Linux)
-----------------------------
- Sink: HTTPS POST via a minimal dependency (candidate: `libcurl` already available on most build targets; fallback to WinHTTP on Windows if curl is unavailable).
- Batch file backup: if POST fails, write newline-delimited JSON to `%APPDATA%/TheGameJamTemplate/telemetry_backlog.log` and retry next launch.
- Threading: single worker thread triggered by `TelemetryService::Tick(dt)` to avoid stalling the render thread; flush on exit.
- Security: pin endpoint to HTTPS; optionally include an HMAC signature using a static key baked into the binary only for release builds.

Web (Emscripten)
----------------
- Sink: `fetch` from JavaScript via `EM_JS` bridge or `emscripten_fetch`; POST JSON to the same endpoint.
- Storage: use `localStorage` to persist the anonymous install id and any unsent batches when offline; flush on next tick when `navigator.onLine` is true.
- Rate limits: cap to one batch per 15 seconds and max payload size (e.g., 32 KB) to stay within browser constraints.
- CORS: ensure the endpoint allows the game origin; consider a CDN-backed collector endpoint to reduce latency.

Event API surface
-----------------
- C++: `telemetry::RecordEvent("shader_load_failed", {{"name", shaderName}, {"platform", "desktop"}});`
- Lua (optional): expose `telemetry.record(name, tableOfProps)` for gameplay scripts; guard behind config to avoid spam.
- Shader system hook: on load failure or hot-reload failure, emit an event with shader name + platform (desktop/web) + error message.
- Crash reporter hook: emit a `crash` or `fatal_error` event before handing off to existing crash reporter.

Implemented signals (current)
-----------------------------
- Startup: `app_start` tagged with platform, build id, build type, release flag, locale, distinct_id.
- Failures: `json_load_failed` (path/error), `shader_manifest_load_failed`, `shader_load_failed` (paths + platform + build), `crash_report` (reason/build/platform).
- Lua gameplay: `scene_enter` (main menu/game), `start_game_clicked`, `lua_runtime_init`, `debug_tests_enabled`, `session_start`, `phase_enter/phase_exit` with duration and session id, language changes, discord/follow clicks.
- Transport: native sends via libcurl; web/Emscripten uses `fetch` from JS (CORS still required).

Future signals to add
---------------------
- Session lifecycle: `app_exit`/`session_end`, plus session id stitched to start/end.
- Loading milestones: emit `loading_stage_started/completed` events from the event bus to spot stalls.
- Asset coverage: texture/sound load failures and missing UUID lookups (de-duped per path).
- Performance pulses: periodic frame time histogram and hardware summary (GPU/CPU coarse strings).
- User actions: language toggles, controller navigation focus/activation, and menu funnel checkpoints.
- Web parity: persist install id + offline queue in `localStorage`, opt-out via `?telemetry=off` query param.

Config and privacy defaults
---------------------------
- Default to disabled for developer builds; enable only in release with an explicit `telemetry.enabled: true` in `config.json`.
- Provide `TELEMETRY_OPTOUT=1` env var on desktop and `?telemetry=off` query param on web to disable at runtime.
- Strip raw file paths, usernames, and exact timestamps; use session-relative timestamps and coarse hardware info.

Testing strategy
----------------
- Unit tests for batching/queue rollover and JSON payload formatting (no network).
- Desktop integration test with a local HTTP echo server (off by default; run in CI with `ENABLE_TELEMETRY_TESTS`).
- Web mock using a JS `fetch` mock in `shell.html` to verify the bridge.
- Add a manual smoke test checklist: start game, trigger shader load failure, verify POST payload content and opt-out behaviors.

Rollout steps
-------------
1) Land `TelemetryService`, `Sink` interface, `NullSink`, and CMake `ENABLE_TELEMETRY` option (default OFF).
2) Hook into config load to read `telemetry.enabled` + session id creation.
3) Wire shader-system failure paths and crash reporter to emit events.
4) Add web bridge + `fetch` sink; test on a hosted endpoint (or local dev tunnel).
5) Turn on for a small internal build; validate payloads and size limits; document how to opt out.
