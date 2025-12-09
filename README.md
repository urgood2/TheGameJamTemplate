# Game Jam Template

![Tests](https://github.com/urgood2/TheGameJamTemplate/actions/workflows/tests.yml/badge.svg?branch=master)

A C++20 + Lua game-jam scaffold built on Raylib. It comes with a fast render pipeline, battle-ready combat systems, card/ability tooling, UI/layout helpers, shader pipelines (native + WebGL), and profiling/debug utilities so you can iterate quickly.

## Highlights
- Lua-first gameplay scripting with exposed engine systems (camera, physics, particles, timers, UI, combat, wand/cards, shaders)
- Layered render queue with shader batching, fullscreen effects, and web-compatible shader variants
- Rich UI toolkit (layouts, localization, controller navigation, tooltips, typing text, scroll panes, progress bars)
- Profiling and debug support (Tracy integration, Lua debugging hooks)
- Ownership watermarking system to help prevent casual game theft on itch.io (see `docs/guides/OWNERSHIP_SYSTEM.md`)
- Targets desktop and web (Emscripten) with shared assets

## Getting Started
Prerequisites: CMake (≥3.14), a C++20 toolchain, and [just](https://github.com/casey/just). For web builds you also need [emsdk](https://emscripten.org/).

Clone (init submodules if present):
```bash
git clone <repo-url>
cd TheGameJamTemplate
git submodule update --init --recursive
```

Build and run (native):
```bash
just build-debug          # or: cmake -B build -DCMAKE_BUILD_TYPE=Debug && cmake --build build -j
./build/raylib-cpp-cmake-template
```

Release build:
```bash
just build-release
```

Tests (GoogleTest):
```bash
just test                 # debug tests
just test-asan            # address sanitizer
```

Web build (Emscripten):
```bash
just build-web            # requires emsdk in PATH and copies assets into build-emc
```

## PostHog Metrics (optional)
- Build with metrics: `cmake -B build -DCMAKE_BUILD_TYPE=Debug -DENABLE_POSTHOG=ON` (native builds use libcurl; Web/Emscripten builds use browser fetch and don't need curl).
- Configure at runtime via env: `POSTHOG_ENABLED=1`, `POSTHOG_API_KEY=<key>`, `POSTHOG_HOST=https://us.i.posthog.com` (default), `POSTHOG_DISTINCT_ID=<anon-or-user-id>`. The same fields exist under `telemetry` in `assets/config.json`.
- Emit events in C++ with `telemetry::RecordEvent("app_start", {{"scene","menu"}});` or in Lua with `telemetry.record("app_start", { scene = "menu" })`. Payloads are POSTed to `/capture/` on the configured host.

## Documentation
- Full docs index: `docs/README.md`
- Architecture overview: `docs/guides/SYSTEM_ARCHITECTURE.md`
- Ownership system (game theft prevention): `docs/guides/OWNERSHIP_SYSTEM.md`
- C++ documentation standards: `docs/guides/DOCUMENTATION_STANDARDS.md`
- Error handling policy and Lua boundary coverage: `docs/guides/ERROR_HANDLING_POLICY.md` (see tests in `tests/unit/test_sound_system.cpp`, `tests/unit/test_text_waiters.cpp`, and controller nav focus/select tests in `tests/unit/test_controller_nav.cpp`)
- Changelog: `CHANGELOG.md`
- Profiling: `USING_TRACY.md`
- Draw-command/shader batching: `BATCHED_ENTITY_RENDERING.md`, `DRAW_COMMAND_OPTIMIZATION.md`
- Testing checklist: `TESTING_CHECKLIST.md`

## Credits & Licensing
- Project scaffold originally based on https://github.com/tupini07/raylib-cpp-cmake-template.
- All new code/assets are © Chugget. Please do not reuse without permission or explicit licensing.

