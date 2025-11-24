# Game Jam Template

![Tests](https://github.com/urgood2/TheGameJamTemplate/actions/workflows/tests.yml/badge.svg?branch=master)

A C++20 + Lua game-jam scaffold built on Raylib. It comes with a fast render pipeline, battle-ready combat systems, card/ability tooling, UI/layout helpers, shader pipelines (native + WebGL), and profiling/debug utilities so you can iterate quickly.

## Highlights
- Lua-first gameplay scripting with exposed engine systems (camera, physics, particles, timers, UI, combat, wand/cards, shaders)
- Layered render queue with shader batching, fullscreen effects, and web-compatible shader variants
- Rich UI toolkit (layouts, localization, controller navigation, tooltips, typing text, scroll panes, progress bars)
- Profiling and debug support (Tracy integration, Lua debugging hooks)
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

## Documentation
- Full docs index: `docs/README.md`
- Architecture overview: `docs/guides/SYSTEM_ARCHITECTURE.md`
- C++ documentation standards: `docs/guides/DOCUMENTATION_STANDARDS.md`
- Changelog: `CHANGELOG.md`
- Profiling: `USING_TRACY.md`
- Draw-command/shader batching: `BATCHED_ENTITY_RENDERING.md`, `DRAW_COMMAND_OPTIMIZATION.md`
- Testing checklist: `TESTING_CHECKLIST.md`

## Credits & Licensing
- Project scaffold originally based on https://github.com/tupini07/raylib-cpp-cmake-template.
- All new code/assets are © Chugget. Please do not reuse without permission or explicit licensing.

