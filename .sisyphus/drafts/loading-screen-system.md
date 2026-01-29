# Draft: Comprehensive Loading Screen System

## User's Request
- Replace any black screen gaps during game startup with a comprehensive loading screen
- Use multithreading for background loading
- Desktop builds only (incompatible with web/Emscripten)

## Requirements (confirmed)
- [Platform constraint]: Desktop only (`#ifndef __EMSCRIPTEN__`)
- [Threading]: Use Taskflow library (already in codebase at `include/taskflow-master/`)

## Research Findings

### Existing Infrastructure
1. **GameState system exists** (`src/core/globals.hpp:86`)
   - `LOADING_SCREEN` state already defined in enum
   - State management via `globals::setCurrentGameState()`

2. **Basic loading screen renderer exists** (`src/main.cpp:172-177`)
   ```cpp
   auto loadingScreenStateGameLoopRender(float dt) -> void {
     ClearBackground(RAYWHITE);
     DrawText("Loading...", 20, 20, 40, LIGHTGRAY);
   }
   ```
   - Very basic, just white background + text

3. **Taskflow library available** (`include/taskflow-master/taskflow/`)
   - Full taskflow implementation ready to use
   - Can create background loading tasks

4. **Platform detection pattern** (`src/main.cpp:35`)
   ```cpp
   #if defined(PLATFORM_WEB) || defined(__EMSCRIPTEN__)
   // web code
   #endif
   ```
   - Use `#ifndef __EMSCRIPTEN__` for desktop-only code

5. **Startup sequence** (`src/core/init.cpp:942-1006`)
   - `startInit()` is the main initialization function
   - Calls: `initSystems()`, `initECS()`, localization loading, seed setup
   - Currently SYNCHRONOUS (blocking main thread)
   - Sets GameState to MAIN_MENU when done

6. **Loading stages tracking** (`src/core/globals.hpp:243-246`)
   ```cpp
   extern std::map<int, std::string> loadingStages;
   extern int loadingStateIndex;
   ```
   - Basic progress tracking infrastructure exists

7. **Event bus system** (`src/core/globals.hpp:577-578`, `events.hpp`)
   - `events::LoadingStageStarted` and `events::LoadingStageCompleted` events already exist
   - Can hook into these for progress updates

### Current Startup Flow (what causes black screen)
1. `main()` starts
2. `createEngineContext()` called
3. `init::base_init()` called - sets up raylib window
4. **BLACK SCREEN GAP** - Window visible but no rendering while:
   - `startInit()` runs synchronously
   - All JSON loading, texture loading, shader loading, etc.
5. Game loop starts

### What Needs to Change
1. Render a loading screen DURING initialization
2. Move heavy init tasks to background threads
3. Keep main thread responsive for rendering
4. Report progress back to main thread

## Technical Decisions
- [PENDING]: Visual style of loading screen (minimalist? animated? splash image?)
- [PENDING]: What assets to load synchronously vs async
- [PENDING]: Progress bar granularity

## Open Questions
1. Should the loading screen show a splash image/logo?
2. What loading stages should be displayed?
3. Should there be loading tips/hints?
4. Spinner vs progress bar vs both?
5. Minimum display time (for branding) or disappear as soon as ready?

## Scope Boundaries
- INCLUDE: Desktop loading screen with multithreaded loading
- INCLUDE: Progress reporting
- INCLUDE: Platform guards (`#ifndef __EMSCRIPTEN__`)
- EXCLUDE: Web build loading (already has HTML-based loading in minshell.html)
- EXCLUDE: Changes to web build behavior
