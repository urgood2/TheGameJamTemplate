# Web UX Improvements Design

**Date:** 2025-12-16
**Status:** Approved
**Branch:** `explore/web-ux-improvements`

## Overview

Improvements to the web build shell (`minshell.html`) focusing on resilience, branding, performance visibility, and user feedback.

## 1. Resilience

### Loading Timeout & Stall Detection
- Track last progress update timestamp
- After 15 seconds of no progress change, show warning: "Loading seems slow..."
- After 30 seconds, show retry prompt

### Retry Mechanism
- Simple "Retry" button that reloads the page (`location.reload()`)
- Appears on timeout or network error

### Error States

| Error | Detection | User Message |
|-------|-----------|--------------|
| Network failure | `onerror` on script/fetch | "Failed to download game files" |
| WebGL unsupported | Check `canvas.getContext('webgl2')` | "Your browser doesn't support WebGL" |
| WASM compile error | Emscripten `onAbort` | "Game failed to start" |
| Timeout/stall | Timer-based | "Download stalled" |

### UI Treatment
- Error message replaces progress bar area
- Red-tinted progress container (keeping the Balatro aesthetic)
- Retry button styled like existing debug buttons

## 2. Branding (Template System)

### Placeholders in minshell.html.in
```html
<title>@GAME_TITLE@</title>
<meta property="og:title" content="@GAME_TITLE@">
<meta property="og:description" content="@GAME_DESCRIPTION@">
<meta property="og:image" content="@OG_IMAGE_URL@">
<meta property="og:url" content="@GAME_URL@">
<link rel="shortcut icon" href="@FAVICON@">
```

### Build-time Injection
- Define variables in CMakeLists.txt or separate `web_config.cmake`
- Use `configure_file()` to replace placeholders

```cmake
set(GAME_TITLE "Your Game Name")
set(GAME_DESCRIPTION "A card-based roguelike")
set(OG_IMAGE_URL "https://yourdomain.com/og-image.png")
set(GAME_URL "https://yourgame.itch.io")
set(FAVICON "favicon.ico")

configure_file(src/minshell.html.in ${CMAKE_BINARY_DIR}/minshell.html @ONLY)
```

### File Changes
- Rename `minshell.html` → `minshell.html.in`
- Placeholder syntax: `@VARIABLE@` (CMake `@ONLY` mode)

## 3. FPS Indicator

### Display
- Small overlay in top-right corner
- Shows: `60 FPS` (minimal)
- Monospace font, semi-transparent background matching Balatro aesthetic

### Toggle
- Keyboard shortcut: `F3`
- State persisted in `sessionStorage`

### Implementation
- JavaScript `requestAnimationFrame` loop calculates frame delta
- Updates display every 500ms (avoids jittery numbers)
- Only runs when visible

### Styling
- Small pill shape with pixel-rounded corners
- Background: `#2a2a4a` with slight transparency
- Text: `#8888aa`

## 4. Tab Unfocused Pause Indicator

### Detection
- Page Visibility API: `document.addEventListener('visibilitychange', ...)`
- Check `document.hidden` state

### Visual Treatment
- Semi-transparent dark overlay covers the canvas
- Centered message: `PAUSED`
- Subtle pulsing animation on the text

### Behavior
- Overlay appears instantly when tab loses focus
- Disappears when tab regains focus
- Visual feedback only (engine handles actual pause logic)

### Styling
- Overlay: `rgba(10, 10, 18, 0.85)`
- Text: `#8888aa`, uppercase, letter-spacing: 4px
- Pulsing opacity animation

## Implementation Notes

### File Changes
1. `src/minshell.html` → `src/minshell.html.in` (rename + add placeholders)
2. `CMakeLists.txt` - Add web config variables and `configure_file()` call
3. Optionally create `cmake/web_config.cmake` for cleaner separation

### New Elements in Shell
- `#error-container` - For error state UI
- `#fps-indicator` - Performance overlay
- `#pause-overlay` - Tab unfocused indicator
- Retry button within error container

### JavaScript Additions
- Stall detection timer
- Error handler registration
- FPS calculation loop
- Visibility change listener
