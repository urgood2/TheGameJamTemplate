# Web UX Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Improve the web build experience with extended crash reporting, Balatro-style loading screen, working local dev server, and in-browser dev console.

**Architecture:** Pure JS/CSS additions to minshell.html for frontend; C++ extensions to existing crash_reporter for game state capture; Python server script for local testing.

**Tech Stack:** Emscripten 3.1.67, vanilla JS/CSS (no frameworks), C++20, Python 3

---

## Task 1: Add serve_web.py to Main Branch

**Files:**
- Create: `scripts/serve_web.py`

**Step 1: Create the server script**

```python
#!/usr/bin/env python3
"""
Local web server that mimics itch.io's hosting environment.
Serves gzipped WASM/data files with correct Content-Encoding headers.

Usage:
    just serve-web
    python3 scripts/serve_web.py [port]
"""

import os
import sys
from http import server
from functools import partial


class ItchIOHandler(server.SimpleHTTPRequestHandler):
    """HTTP handler with itch.io-identical headers and gzip support."""

    def end_headers(self):
        # COOP/COEP headers (required for SharedArrayBuffer/WASM threading)
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")

        # Disable caching for development
        self.send_header("Cache-Control", "no-cache, no-store, must-revalidate")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")

        # CORS headers
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

        super().end_headers()

    def send_head(self):
        """Override to add Content-Encoding for .gz files."""
        path = self.translate_path(self.path)

        if path.endswith('.wasm.gz') or path.endswith('.data.gz'):
            # Serve gzipped files with Content-Encoding header
            try:
                f = open(path, 'rb')
            except OSError:
                self.send_error(404, "File not found")
                return None

            self.send_response(200)

            if path.endswith('.wasm.gz'):
                self.send_header("Content-Type", "application/wasm")
            else:
                self.send_header("Content-Type", "application/octet-stream")

            self.send_header("Content-Encoding", "gzip")
            self.send_header("Content-Length", str(os.fstat(f.fileno()).st_size))
            self.end_headers()
            return f

        return super().send_head()

    def guess_type(self, path):
        """Return proper MIME types for WASM files."""
        if path.endswith('.wasm'):
            return 'application/wasm'
        if path.endswith('.wasm.gz'):
            return 'application/wasm'
        if path.endswith('.data'):
            return 'application/octet-stream'
        if path.endswith('.data.gz'):
            return 'application/octet-stream'
        return super().guess_type(path)


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080

    # Serve from build-emc directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    web_build_dir = os.path.join(project_root, "build-emc")

    if not os.path.exists(web_build_dir):
        print(f"Error: Web build directory not found: {web_build_dir}")
        print("Run 'just build-web' first.")
        sys.exit(1)

    os.chdir(web_build_dir)

    handler = partial(ItchIOHandler, directory=web_build_dir)

    with server.HTTPServer(("", port), handler) as httpd:
        print(f"Serving web build at http://localhost:{port}")
        print(f"Directory: {web_build_dir}")
        print(f"Headers: itch.io-identical (COOP/COEP + gzip Content-Encoding)")
        print("Press Ctrl+C to stop")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nStopped.")


if __name__ == '__main__':
    main()
```

**Step 2: Make executable**

Run: `chmod +x scripts/serve_web.py`

**Step 3: Commit**

```bash
git add scripts/serve_web.py
git commit -m "feat(web): add local dev server with itch.io-identical headers

Serves gzipped WASM/data files with correct Content-Encoding headers.
Includes COOP/COEP for SharedArrayBuffer support."
```

---

## Task 2: Update justfile serve-web Recipe

**Files:**
- Modify: `justfile` (serve-web recipe around line 170)

**Step 1: Update the serve-web recipe**

Find the existing `serve-web` recipe and replace it:

```just
# Serve web build locally for testing (itch.io-identical environment)
serve-web port="8080":
    python3 scripts/serve_web.py {{port}}
```

**Step 2: Verify**

Run: `just serve-web`
Expected: Server starts, prints "Headers: itch.io-identical (COOP/COEP + gzip Content-Encoding)"

**Step 3: Commit**

```bash
git add justfile
git commit -m "chore: update serve-web to use itch.io-compatible server"
```

---

## Task 3: Extend crash_reporter.hpp with New Fields

**Files:**
- Modify: `src/util/crash_reporter.hpp`

**Step 1: Add new fields to Report struct (after line 29)**

Find the `Report` struct and add these fields after `std::vector<LogEntry> logs;`:

```cpp
struct Report {
    std::string id;
    std::string timestamp;
    std::string reason;
    std::string build_id;
    std::string build_type;
    std::string platform;
    std::string thread_id;
    std::vector<std::string> stacktrace;
    std::vector<LogEntry> logs;

    // Game state (populated by callback)
    std::string current_scene;
    std::string player_position;
    int entity_count{0};
    std::string lua_script_context;

    // Web-specific
    std::string browser_info;
    std::string webgl_renderer;
    size_t estimated_memory_mb{0};
    double session_duration_sec{0.0};
};
```

**Step 2: Add callback type and setter (after line 52)**

Add after `std::string CreateSummary(const Report& report);`:

```cpp
// Game state callback - register to populate game-specific fields at capture time
using GameStateCallback = std::function<void(Report&)>;
void SetGameStateCallback(GameStateCallback cb);
```

**Step 3: Add itch.io URL constant (inside namespace, before functions)**

```cpp
// Itch.io community URL for bug reports
constexpr const char* ITCH_COMMUNITY_URL = "https://chugget.itch.io/testing/community";
```

**Step 4: Commit**

```bash
git add src/util/crash_reporter.hpp
git commit -m "feat(crash): add game state fields and callback to Report struct"
```

---

## Task 4: Implement crash_reporter Extensions

**Files:**
- Modify: `src/util/crash_reporter.cpp`

**Step 1: Add includes at top (after line 31)**

```cpp
#if defined(__EMSCRIPTEN__)
#include <emscripten/emscripten.h>
#include <emscripten/stack.h>
#include <emscripten/html5.h>
#endif
```

**Step 2: Add callback storage in State struct (around line 87)**

Find the `State` struct and add:

```cpp
struct State {
    Config config{};
    std::shared_ptr<RingSink> sink;
    std::string last_json;
    std::atomic<bool> handling_fatal{false};
    std::terminate_handler previous_terminate{nullptr};
    bool initialized{false};
    GameStateCallback game_state_callback;  // ADD THIS
    std::chrono::steady_clock::time_point session_start{std::chrono::steady_clock::now()};  // ADD THIS
};
```

**Step 3: Add SetGameStateCallback implementation (after IsEnabled, around line 322)**

```cpp
void SetGameStateCallback(GameStateCallback cb) {
    state().game_state_callback = std::move(cb);
}
```

**Step 4: Update CaptureReport to call callback and capture web info (around line 341)**

Find `CaptureReport` and add after `report.logs = state().sink->snapshot();`:

```cpp
    // Call game state callback if registered
    if (state().game_state_callback) {
        try {
            state().game_state_callback(report);
        } catch (const std::exception& e) {
            SPDLOG_WARN("Game state callback failed: {}", e.what());
        }
    }

    // Calculate session duration
    auto now_steady = std::chrono::steady_clock::now();
    report.session_duration_sec = std::chrono::duration<double>(
        now_steady - state().session_start).count();

#if defined(__EMSCRIPTEN__)
    // Capture browser info
    report.browser_info = reinterpret_cast<const char*>(EM_ASM_PTR({
        var str = navigator.userAgent;
        var len = lengthBytesUTF8(str) + 1;
        var buf = _malloc(len);
        stringToUTF8(str, buf, len);
        return buf;
    }));

    // Capture WebGL renderer
    report.webgl_renderer = reinterpret_cast<const char*>(EM_ASM_PTR({
        var canvas = document.getElementById('canvas');
        if (!canvas) return _malloc(1);
        var gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
        if (!gl) return _malloc(1);
        var debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
        var renderer = debugInfo ? gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL) : 'unknown';
        var len = lengthBytesUTF8(renderer) + 1;
        var buf = _malloc(len);
        stringToUTF8(renderer, buf, len);
        return buf;
    }));

    // Estimate memory usage (Emscripten heap)
    report.estimated_memory_mb = EM_ASM_INT({
        return Math.round(HEAP8.length / (1024 * 1024));
    });
#endif

    return report;
```

**Step 5: Update SerializeReport to include new fields (around line 360)**

Find `SerializeReport` and add after `j["stacktrace"] = report.stacktrace;`:

```cpp
    // Game state
    j["current_scene"] = report.current_scene;
    j["player_position"] = report.player_position;
    j["entity_count"] = report.entity_count;
    j["lua_script_context"] = report.lua_script_context;

    // Web-specific
    j["browser_info"] = report.browser_info;
    j["webgl_renderer"] = report.webgl_renderer;
    j["estimated_memory_mb"] = report.estimated_memory_mb;
    j["session_duration_sec"] = report.session_duration_sec;
```

**Step 6: Update ShowCaptureNotification to add "Report Bug" button (in EM_ASM block)**

Find `ShowCaptureNotification` and add a third button after the dismissBtn creation (around line 545):

```javascript
        const reportBtn = document.createElement('button');
        reportBtn.id = 'crash-report-btn';
        reportBtn.style.cssText = `
            background: rgba(255,255,255,0.1);
            color: rgba(255,255,255,0.8);
            border: none;
            padding: 6px 12px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 12px;
        `;
        reportBtn.textContent = 'Report Bug';
        reportBtn.onclick = function() {
            window.open('https://chugget.itch.io/testing/community', '_blank');
        };

        buttonContainer.appendChild(copyBtn);
        buttonContainer.appendChild(reportBtn);  // ADD between copy and dismiss
        buttonContainer.appendChild(dismissBtn);
```

**Step 7: Commit**

```bash
git add src/util/crash_reporter.cpp
git commit -m "feat(crash): implement game state callback and web info capture

- Add SetGameStateCallback for Lua context population
- Capture browser info, WebGL renderer, memory usage on web
- Track session duration
- Add 'Report Bug' button linking to itch.io community"
```

---

## Task 5: Add gameReady Signal to init.cpp

**Files:**
- Modify: `src/core/init.cpp`

**Step 1: Add Emscripten include if not present (top of file)**

Verify this include exists, add if needed:

```cpp
#if defined(__EMSCRIPTEN__)
#include <emscripten/emscripten.h>
#endif
```

**Step 2: Add gameReady call at end of startInit (line 910)**

Find `globals::setCurrentGameState(GameState::MAIN_MENU);` and add right after it:

```cpp
  globals::setCurrentGameState(GameState::MAIN_MENU);

#if defined(__EMSCRIPTEN__)
  // Signal to HTML that game is fully initialized and ready
  EM_ASM({
      if (typeof window.gameReady === 'function') {
          window.gameReady();
      }
  });
#endif
```

**Step 3: Commit**

```bash
git add src/core/init.cpp
git commit -m "feat(web): signal gameReady to HTML after init complete"
```

---

## Task 6: Register Game State Callback in Scripting System

**Files:**
- Modify: `src/systems/scripting/scripting_functions.cpp`

**Step 1: Add crash_reporter include (top of file)**

```cpp
#include "util/crash_reporter.hpp"
```

**Step 2: Find initScriptingSystem function end (around line 1590)**

Add before the closing brace of `initScriptingSystem`:

```cpp
  // Register crash reporter callback to capture Lua context
  crash_reporter::SetGameStateCallback([&stateToInit](crash_reporter::Report& report) {
      // Get current Lua debug info if available
      lua_Debug ar;
      lua_State* L = stateToInit.lua_state();

      if (lua_getstack(L, 1, &ar)) {
          lua_getinfo(L, "nSl", &ar);
          std::ostringstream ctx;
          ctx << (ar.source ? ar.source : "?");
          ctx << ":" << (ar.name ? ar.name : "?");
          ctx << ":" << ar.currentline;
          report.lua_script_context = ctx.str();
      }

      // Get entity count from registry
      if (globals::g_ctx && globals::g_ctx->registry) {
          report.entity_count = static_cast<int>(globals::g_ctx->registry->storage<entt::entity>().in_use());
      }

      // Current game state as scene
      report.current_scene = std::to_string(static_cast<int>(globals::getCurrentGameState()));
  });
```

**Step 3: Add required includes at top**

```cpp
#include <sstream>
```

**Step 4: Commit**

```bash
git add src/systems/scripting/scripting_functions.cpp
git commit -m "feat(crash): register Lua context callback for crash reports

Captures current Lua file/function/line, entity count, and game state."
```

---

## Task 7: Rewrite minshell.html with Balatro Aesthetic

**Files:**
- Modify: `src/minshell.html`

**Step 1: Replace entire file contents**

```html
<!DOCTYPE html>
<html lang="en-us">
<head>
    <meta charset="utf-8">
    <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    <title>Game</title>
    <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
    <link rel="shortcut icon" href="favicon.ico">

    <style>
        /* Pixelated font */
        @font-face {
            font-family: 'PixelFont';
            src: local('Courier New'), local('monospace');
        }

        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            background: linear-gradient(180deg, #0a0a12 0%, #12121f 50%, #0a0a12 100%);
            min-height: 100vh;
            overflow: hidden;
            font-family: 'PixelFont', 'Courier New', monospace;
            image-rendering: pixelated;
        }

        /* Subtle CRT scanlines overlay */
        body::before {
            content: '';
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: repeating-linear-gradient(
                0deg,
                transparent,
                transparent 2px,
                rgba(0, 0, 0, 0.1) 2px,
                rgba(0, 0, 0, 0.1) 4px
            );
            pointer-events: none;
            z-index: 10000;
        }

        /* Canvas */
        #canvas {
            display: block;
            margin: 0 auto;
            background: #000;
            opacity: 0;
            transition: opacity 0.5s ease-in-out;
        }

        #canvas.visible {
            opacity: 1;
        }

        /* Splash Screen */
        #splash {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: linear-gradient(180deg, #0a0a12 0%, #12121f 50%, #0a0a12 100%);
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            z-index: 1000;
            opacity: 0;
            animation: fadeIn 0.4s ease-out forwards;
        }

        #splash.fade-out {
            animation: fadeOut 0.5s ease-in-out forwards;
        }

        @keyframes fadeIn {
            from { opacity: 0; }
            to { opacity: 1; }
        }

        @keyframes fadeOut {
            from { opacity: 1; }
            to { opacity: 0; pointer-events: none; }
        }

        /* Splash Image */
        #splash-image {
            max-width: 80%;
            max-height: 40%;
            margin-bottom: 30px;
            image-rendering: pixelated;
            filter: drop-shadow(0 0 20px rgba(255, 200, 100, 0.3));
        }

        /* Progress Container - Balatro style rounded rect */
        #progress-container {
            width: min(400px, 70%);
            height: 24px;
            background: #1a1a2e;
            border-radius: 12px;
            overflow: hidden;
            border: 2px solid #2a2a4a;
            box-shadow:
                0 0 10px rgba(0, 0, 0, 0.5),
                inset 0 2px 4px rgba(0, 0, 0, 0.3);
            margin-bottom: 12px;
        }

        /* Progress Bar */
        #progress-bar {
            width: 0%;
            height: 100%;
            background: linear-gradient(90deg, #4a6fa5 0%, #6a9fd5 50%, #4a6fa5 100%);
            border-radius: 10px;
            transition: width 0.2s ease;
            box-shadow: 0 0 15px rgba(106, 159, 213, 0.4);
            animation: pulse 1.5s ease-in-out infinite;
        }

        @keyframes pulse {
            0%, 100% { opacity: 0.85; }
            50% { opacity: 1; }
        }

        /* Progress Text */
        #progress-text {
            color: #8a8aaa;
            font-size: 14px;
            letter-spacing: 2px;
            text-transform: uppercase;
            text-shadow: 0 0 10px rgba(138, 138, 170, 0.3);
        }

        /* Dev Console */
        #dev-console {
            position: fixed;
            bottom: 0;
            left: 0;
            width: 100%;
            max-height: 40vh;
            background: rgba(10, 10, 18, 0.95);
            border-top: 2px solid #2a2a4a;
            z-index: 9999;
            display: none;
            flex-direction: column;
            font-family: 'Courier New', monospace;
            font-size: 12px;
        }

        #dev-console.visible {
            display: flex;
        }

        #console-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 8px 12px;
            background: #1a1a2e;
            border-bottom: 1px solid #2a2a4a;
        }

        #console-header span {
            color: #6a9fd5;
            font-weight: bold;
        }

        #console-buttons button {
            background: #2a2a4a;
            color: #8a8aaa;
            border: none;
            padding: 4px 10px;
            margin-left: 6px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 11px;
        }

        #console-buttons button:hover {
            background: #3a3a5a;
        }

        #console-log {
            flex: 1;
            overflow-y: auto;
            padding: 8px 12px;
            color: #aaa;
        }

        .log-entry {
            padding: 2px 0;
            border-bottom: 1px solid rgba(42, 42, 74, 0.3);
        }

        .log-entry.warn {
            color: #ffa500;
        }

        .log-entry.error {
            color: #ff6b6b;
        }

        .log-time {
            color: #555;
            margin-right: 8px;
        }

        /* Hidden output element */
        #output {
            display: none;
        }
    </style>
</head>
<body>
    <!-- Splash Screen -->
    <div id="splash">
        <img id="splash-image" src="splash.png" alt="Loading..." />
        <div id="progress-container">
            <div id="progress-bar"></div>
        </div>
        <div id="progress-text">LOADING</div>
    </div>

    <!-- Game Canvas -->
    <canvas class="emscripten" id="canvas" oncontextmenu="event.preventDefault()" tabindex="-1"></canvas>

    <!-- Dev Console -->
    <div id="dev-console">
        <div id="console-header">
            <span>Dev Console</span>
            <div id="console-buttons">
                <button id="console-copy">Copy All</button>
                <button id="console-clear">Clear</button>
                <button id="console-close">Close</button>
            </div>
        </div>
        <div id="console-log"></div>
    </div>

    <p id="output"></p>

    <script>
        // ============================================
        // Dev Console - Log Capture System
        // ============================================
        const DevConsole = {
            STARTUP_LIMIT: 5000,
            RUNTIME_LIMIT: 500,
            startupLogs: [],
            runtimeLogs: [],
            gameIsReady: false,
            isVisible: false,

            init() {
                this.interceptConsole();
                this.setupKeyboardToggle();
                this.setupButtons();

                // Restore visibility state
                if (sessionStorage.getItem('devConsoleVisible') === 'true') {
                    this.show();
                }
            },

            interceptConsole() {
                const self = this;
                const originalLog = console.log;
                const originalWarn = console.warn;
                const originalError = console.error;

                console.log = function(...args) {
                    self.capture('info', args);
                    originalLog.apply(console, args);
                };

                console.warn = function(...args) {
                    self.capture('warn', args);
                    originalWarn.apply(console, args);
                };

                console.error = function(...args) {
                    self.capture('error', args);
                    originalError.apply(console, args);
                };
            },

            capture(level, args) {
                const entry = {
                    time: new Date().toLocaleTimeString('en-US', { hour12: false }),
                    level,
                    message: args.map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ')
                };

                if (!this.gameIsReady && this.startupLogs.length < this.STARTUP_LIMIT) {
                    this.startupLogs.push(entry);
                } else {
                    this.runtimeLogs.push(entry);
                    if (this.runtimeLogs.length > this.RUNTIME_LIMIT) {
                        this.runtimeLogs.shift();
                    }
                }

                if (this.isVisible) {
                    this.appendEntry(entry);
                }
            },

            appendEntry(entry) {
                const logEl = document.getElementById('console-log');
                const div = document.createElement('div');
                div.className = 'log-entry ' + entry.level;
                div.innerHTML = `<span class="log-time">${entry.time}</span>${this.escapeHtml(entry.message)}`;
                logEl.appendChild(div);
                logEl.scrollTop = logEl.scrollHeight;
            },

            escapeHtml(text) {
                const div = document.createElement('div');
                div.textContent = text;
                return div.innerHTML;
            },

            render() {
                const logEl = document.getElementById('console-log');
                logEl.innerHTML = '';

                // Separator for startup logs
                if (this.startupLogs.length > 0) {
                    const sep = document.createElement('div');
                    sep.style.cssText = 'color: #6a9fd5; padding: 4px 0; border-bottom: 1px solid #2a2a4a;';
                    sep.textContent = `=== STARTUP LOGS (${this.startupLogs.length}) ===`;
                    logEl.appendChild(sep);

                    this.startupLogs.forEach(e => this.appendEntry(e));
                }

                if (this.runtimeLogs.length > 0) {
                    const sep = document.createElement('div');
                    sep.style.cssText = 'color: #6a9fd5; padding: 4px 0; margin-top: 8px; border-bottom: 1px solid #2a2a4a;';
                    sep.textContent = `=== RUNTIME LOGS (${this.runtimeLogs.length}) ===`;
                    logEl.appendChild(sep);

                    this.runtimeLogs.forEach(e => this.appendEntry(e));
                }

                logEl.scrollTop = logEl.scrollHeight;
            },

            show() {
                this.isVisible = true;
                document.getElementById('dev-console').classList.add('visible');
                sessionStorage.setItem('devConsoleVisible', 'true');
                this.render();
            },

            hide() {
                this.isVisible = false;
                document.getElementById('dev-console').classList.remove('visible');
                sessionStorage.setItem('devConsoleVisible', 'false');
            },

            toggle() {
                this.isVisible ? this.hide() : this.show();
            },

            clear() {
                this.runtimeLogs = [];
                if (this.isVisible) this.render();
            },

            copyAll() {
                const allLogs = [...this.startupLogs, ...this.runtimeLogs];
                const text = allLogs.map(e => `[${e.time}] [${e.level.toUpperCase()}] ${e.message}`).join('\n');
                navigator.clipboard.writeText(text).then(() => {
                    console.log('Logs copied to clipboard');
                });
            },

            setupKeyboardToggle() {
                document.addEventListener('keydown', (e) => {
                    // Backtick or F12
                    if (e.key === '`' || e.key === 'F12') {
                        e.preventDefault();
                        this.toggle();
                    }
                });
            },

            setupButtons() {
                document.getElementById('console-copy').onclick = () => this.copyAll();
                document.getElementById('console-clear').onclick = () => this.clear();
                document.getElementById('console-close').onclick = () => this.hide();
            },

            markGameReady() {
                this.gameIsReady = true;
                console.log(`[DevConsole] Game ready. Startup logs frozen at ${this.startupLogs.length} entries.`);
            }
        };

        // Initialize console capture immediately
        DevConsole.init();

        // ============================================
        // Game Ready Handler
        // ============================================
        window.gameReady = function() {
            DevConsole.markGameReady();

            // Fade out splash
            const splash = document.getElementById('splash');
            splash.classList.add('fade-out');

            // Show canvas
            const canvas = document.getElementById('canvas');
            canvas.classList.add('visible');

            // Remove splash after animation
            setTimeout(() => {
                splash.style.display = 'none';
            }, 500);
        };

        // ============================================
        // Emscripten Module Configuration
        // ============================================
        var Module = {
            preRun: [],
            postRun: [
                function() {
                    // Fallback: if gameReady wasn't called, trigger it now
                    if (!DevConsole.gameIsReady) {
                        console.warn('[Module.postRun] gameReady not called by game, triggering fallback');
                        window.gameReady();
                    }
                }
            ],
            print: (function() {
                var element = document.getElementById('output');
                if (element) element.value = '';
                return function(text) {
                    if (arguments.length > 1) text = Array.prototype.slice.call(arguments).join(' ');
                    console.log(text);
                    if (element) {
                        element.value += text + "\n";
                        element.scrollTop = element.scrollHeight;
                    }
                };
            })(),
            canvas: (function() {
                return document.getElementById('canvas');
            })(),
            setStatus: function(text) {
                const progressBar = document.getElementById('progress-bar');
                const progressText = document.getElementById('progress-text');

                let match = text.match(/([^(]+)\((\d+(\.\d+)?)\/(\d+)\)/);
                if (match) {
                    // During download: scale to 0-90%
                    let rawPercent = (parseFloat(match[2]) / parseFloat(match[4])) * 100;
                    let scaledPercent = Math.floor(rawPercent * 0.9);
                    progressBar.style.width = scaledPercent + '%';
                    progressText.textContent = scaledPercent + '%';
                } else if (text === 'All downloads complete.') {
                    // Downloads done, game initializing: jump to 90%
                    progressBar.style.width = '90%';
                    progressText.textContent = 'STARTING';
                } else if (text) {
                    progressText.textContent = text.toUpperCase();
                }
            },
            totalDependencies: 0,
            monitorRunDependencies: function(left) {
                this.totalDependencies = Math.max(this.totalDependencies, left);
                Module.setStatus(left
                    ? 'Preparing... (' + (this.totalDependencies - left) + '/' + this.totalDependencies + ')'
                    : 'All downloads complete.');
            }
        };

        Module.setStatus('LOADING');
    </script>

    {{{ SCRIPT }}}
</body>
</html>
```

**Step 2: Verify syntax**

Run: `just build-web` (or at minimum check HTML validity)

**Step 3: Commit**

```bash
git add src/minshell.html
git commit -m "feat(web): redesign loading screen with Balatro aesthetic

- Pixelated rounded rectangle progress bar with subtle bloom
- Smooth fade transitions (splash in/out, canvas in)
- Subtle CRT scanlines overlay (CSS-only, no performance impact)
- Two-phase loading: 0-90% download, 90-100% game init
- In-browser dev console (backtick to toggle)
- 5000 startup + 500 runtime log retention
- Copy/Clear/Close buttons on console"
```

---

## Task 8: Build and Test Locally

**Step 1: Build web**

Run: `just build-web`
Expected: Build completes without errors

**Step 2: Start local server**

Run: `just serve-web`
Expected: Server starts with "Headers: itch.io-identical" message

**Step 3: Test in browser**

Open: `http://localhost:8080`

Verify:
- [ ] Splash fades in smoothly
- [ ] Progress bar fills 0-90% during download
- [ ] Progress shows "STARTING" at 90%
- [ ] Splash fades out when game ready
- [ ] Canvas fades in simultaneously
- [ ] Press backtick (`) - dev console appears
- [ ] Console shows startup logs with separator
- [ ] Copy/Clear/Close buttons work
- [ ] Press F10 in game - crash report notification appears
- [ ] "Report Bug" button opens itch.io community

**Step 4: Commit verification**

```bash
git add .
git commit -m "test: verify web UX improvements working locally"
```

---

## Task 9: Final Integration Test

**Step 1: Clean build**

Run: `just clean-web && just build-web-full`

**Step 2: Test zip file structure**

Run: `unzip -l raylib-cpp-cmake-template_web.zip | head -20`
Expected: Contains index.html, .wasm.gz, .data.gz, splash.png, assets/

**Step 3: Commit and push**

```bash
git add .
git commit -m "chore: finalize web UX improvements

Summary:
- Extended crash reporter with game state, browser info, 'Report Bug' button
- Balatro-style loading screen with smooth transitions
- Two-phase progress (download 0-90%, init 90-100%)
- In-browser dev console with 5000 startup log retention
- Fixed local dev server with itch.io-identical headers"

git push origin feature/web-ux-improvements
```

---

## Verification Checklist

After implementation, verify:

- [ ] `just serve-web` works and serves gzipped files correctly
- [ ] Local build matches itch.io behavior (no CORS/path errors)
- [ ] Loading screen has Balatro aesthetic (rounded rect, pixelated, slight bloom)
- [ ] Splash fades in/out smoothly (no jarring transitions)
- [ ] Progress bar shows two phases (download then init)
- [ ] `window.gameReady()` called after Lua init
- [ ] Dev console opens with backtick key
- [ ] Startup logs preserved (up to 5000)
- [ ] Crash reports include Lua context, entity count, browser info
- [ ] "Report Bug" button opens itch.io community page
- [ ] CI workflow still builds successfully (no changes to pipeline)

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
