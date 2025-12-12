# Web Build: Loading Screen & Error Handling

## Overview

Improve the web build with a polished loading screen and user-friendly error handling, integrating with the existing crash reporter system.

## Loading Screen

### Visual Design
- Black background (unchanged)
- Centered `splash.png` image
- CSS-only animated spinner below image (rotating ring with gradient border)
- Progress bar below spinner showing percentage
- Status text updates: "Downloading..." → "Preparing..." → percentage

### Two-Phase Progress
- **Phase 1 (0-80%)**: Download progress from Emscripten's `setStatus` callback
- **Phase 2 (80-100%)**: Initialization progress from `monitorRunDependencies`

This provides accurate feedback during both the download and the "starting up" phases.

### Transition
- Smooth fade-out (opacity 0 over 300ms)
- Then `display: none` to remove from layout
- Triggered by `postRun` callback (existing behavior)

### CSS Animation
```css
@keyframes spin {
    0% { transform: rotate(0deg); }
    100% { transform: rotate(360deg); }
}

.spinner {
    width: 40px;
    height: 40px;
    border: 3px solid rgba(255,255,255,0.2);
    border-top-color: #fff;
    border-radius: 50%;
    animation: spin 1s linear infinite;
}
```

## Error Handling

### Error Types Caught
1. Network/download failures (WASM or data file fails to load)
2. Runtime JavaScript errors (`window.onerror`, `unhandledrejection`)
3. Emscripten abort messages
4. Game crash reports (via `Module.onCrashReport` callback)

### Modal Dialog UI
```
┌─────────────────────────────────┐
│         ⚠ (CSS icon)            │
│                                 │
│    Something went wrong         │
│                                 │
│  [Simplified error message]     │
│                                 │
│  [ Copy Report ]  [ Reload ]    │
└─────────────────────────────────┘
```

- Centered card on dark semi-transparent overlay
- Warning icon drawn with CSS (triangle with exclamation)
- "Copy Report" button: Only shown when crash JSON is available
- "Reload Game" button: Always shown, calls `location.reload()`

### Error Message Simplification
- Network errors: "Failed to load game resources. Check your connection and try again."
- Runtime errors: "The game encountered an unexpected error."
- Crash reports: "The game crashed. Copy the report to help us fix this."

Raw stack traces are NOT shown to users (but included in copied report).

## Crash Reporter Integration

### C++ Change (crash_reporter.cpp)

Add to `handle_fatal()` after `persist_report_internal()`:

```cpp
#if defined(__EMSCRIPTEN__)
EM_ASM({
    if (typeof Module !== 'undefined' && Module.onCrashReport) {
        Module.onCrashReport(UTF8ToString($0));
    }
}, s.last_json.c_str());
#endif
```

### JavaScript Side (minshell.html)

```javascript
var Module = {
    // ... existing config ...
    onCrashReport: function(jsonString) {
        window._lastCrashReport = jsonString;
        showErrorModal('The game crashed.', true);
    }
};
```

## Implementation Files

| File | Changes |
|------|---------|
| `src/minshell.html` | Add spinner CSS, two-phase progress, error modal, fade transition |
| `src/util/crash_reporter.cpp` | Add `Module.onCrashReport` callback (~3 lines) |

## Safety Measures

1. **Error handler registered early**: Before any loading begins
2. **Single error display**: Flag prevents showing multiple modals
3. **No external dependencies**: All CSS/JS inline
4. **Minimal Module changes**: Only adds callbacks, doesn't modify existing ones
5. **CSS-only animations**: No JS animation loops that could interfere with WASM

## Testing Checklist

- [ ] Normal load: Spinner animates, progress updates, fade-out works
- [ ] Slow network: Progress bar reflects actual download progress
- [ ] Network failure: Error modal appears with reload button
- [ ] Game crash: Modal shows with "Copy Report" button
- [ ] Copy report: Clipboard contains valid JSON
- [ ] Reload button: Page refreshes correctly
- [ ] Mobile: Layout responsive, buttons tappable
