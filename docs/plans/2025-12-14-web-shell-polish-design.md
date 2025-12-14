# Web Shell Polish Design

**Date:** 2025-12-14
**Status:** Approved
**Branch:** feature/web-ux-improvements

## Overview

Polish the web loading shell and debug reporting UX to match the game's pixel art aesthetic and improve crash report discoverability.

## Goals

1. Fix stray "Loading..." text visible when splash image fails to load
2. Add persistent debug button for manual crash report capture
3. Pixelate progress bar and containers to match game aesthetic
4. Add subtle floating card suit animation during loading
5. Consolidate crash notifications into a single modal interface

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Debug button location | Bottom-left | Avoids common UI hotspots (settings, pause typically top/bottom-right) |
| Visual polish level | Subtle | Build on existing Balatro style without scope creep |
| Crash notification | Modal only | Single consistent interface, no auto-dismissing toasts |
| Corner style | Pixelated rounded | Match game's pixel art aesthetic using clip-path |

---

## 1. Fix Stray "Loading..." Text

**Problem:** When `splash.png` fails to load, browser shows `alt="Loading..."` in black text against dark background.

**Solution:**

```html
<!-- Change alt text to thematic fallback -->
<img id="splash-image" src="splash.png" alt="♠ ♥ ♦ ♣" />
```

```css
#splash-image {
    /* Style alt text as fallback */
    color: #8888aa;
    font-size: 14px;
    letter-spacing: 2px;
    text-transform: uppercase;
    display: flex;
    align-items: center;
    justify-content: center;
    min-height: 80px;
}
```

---

## 2. Pixelated Rounded Corners

Replace smooth `border-radius` with stepped clip-path for pixel art aesthetic.

```css
.pixel-rounded {
    border-radius: 0;
    clip-path: polygon(
        /* Top-left corner (3-step) */
        0 8px,
        2px 8px, 2px 4px,
        4px 4px, 4px 2px,
        8px 2px, 8px 0,
        /* Top edge */
        calc(100% - 8px) 0,
        /* Top-right corner */
        calc(100% - 8px) 2px, calc(100% - 4px) 2px,
        calc(100% - 4px) 4px, calc(100% - 2px) 4px,
        calc(100% - 2px) 8px, 100% 8px,
        /* Right edge */
        100% calc(100% - 8px),
        /* Bottom-right corner */
        calc(100% - 2px) calc(100% - 8px), calc(100% - 2px) calc(100% - 4px),
        calc(100% - 4px) calc(100% - 4px), calc(100% - 4px) calc(100% - 2px),
        calc(100% - 8px) calc(100% - 2px), calc(100% - 8px) 100%,
        /* Bottom edge */
        8px 100%,
        /* Bottom-left corner */
        8px calc(100% - 2px), 4px calc(100% - 2px),
        4px calc(100% - 4px), 2px calc(100% - 4px),
        2px calc(100% - 8px), 0 calc(100% - 8px)
    );
}
```

**Apply to:** `.loading-container`, `#progress-container`, `#dev-console`, `.debug-modal`

---

## 3. Pixelated Progress Bar

Segmented fill that looks like retro HP bars.

```css
#progress-container {
    border-radius: 0;
    border: 2px solid #3a3a5a;
    background: #0a0a14;
}

#progress-bar {
    border-radius: 0;

    /* Discrete 8px segments with 2px gaps */
    background: repeating-linear-gradient(
        90deg,
        #4a6cd4 0px,
        #4a6cd4 8px,
        #3a5cc4 8px,
        #3a5cc4 10px
    );

    image-rendering: pixelated;
    image-rendering: crisp-edges;
}
```

---

## 4. Floating Card Suits Animation

Subtle ambient particles behind loading container.

```css
@keyframes floatUp {
    0% {
        transform: translateY(0) rotate(0deg);
        opacity: 0;
    }
    10% { opacity: 0.6; }
    90% { opacity: 0.6; }
    100% {
        transform: translateY(-120px) rotate(15deg);
        opacity: 0;
    }
}

.floating-suit {
    position: absolute;
    font-size: 20px;
    color: #4a6cd4;
    opacity: 0;
    animation: floatUp 4s ease-in-out infinite;
    text-shadow: 0 0 8px rgba(100, 140, 230, 0.5);
    pointer-events: none;
    z-index: 1;
}
```

**Implementation:**
- Spawn 4-6 suit elements (♠ ♥ ♦ ♣) at random horizontal positions
- Stagger animation-delay for each (0s, 0.8s, 1.6s, 2.4s, etc.)
- Position below loading container, float upward

---

## 5. Persistent Debug Button

Always-visible button in bottom-left corner.

```html
<button id="debug-btn" class="debug-btn pixel-rounded" title="Capture Debug Report">
    🐛 <span class="debug-btn-text">?</span>
</button>
```

```css
.debug-btn {
    position: fixed;
    bottom: 12px;
    left: 12px;
    z-index: 8000;

    background: #2a2a4a;
    color: #8888aa;
    border: 2px solid #3a3a5a;
    padding: 8px 12px;

    font-family: 'PixelFont', 'Courier New', monospace;
    font-size: 14px;
    cursor: pointer;

    opacity: 0;
    transition: opacity 0.3s ease, box-shadow 0.2s ease;
}

.debug-btn.visible {
    opacity: 1;
}

.debug-btn:hover {
    background: #3a3a5a;
    color: #aaaacc;
    box-shadow: 0 0 12px rgba(100, 140, 230, 0.3);
}

/* Crash alert pulse */
@keyframes crashPulse {
    0%, 100% { box-shadow: 0 0 0 0 rgba(220, 80, 80, 0.7); }
    50% { box-shadow: 0 0 0 8px rgba(220, 80, 80, 0); }
}

.debug-btn.crash-alert {
    animation: crashPulse 1s ease-in-out 3;
    border-color: #dd4444;
}
```

**Behavior:**
- Hidden during splash, fades in with game canvas
- Click → captures debug report → opens modal
- After crash → pulses red 3 times, modal opens automatically

---

## 6. Debug Modal

Centered modal for debug report actions.

```html
<div id="debug-modal" class="debug-modal">
    <div class="debug-modal-backdrop"></div>
    <div class="debug-modal-content pixel-rounded">
        <div class="debug-modal-header">
            <span>🐛 DEBUG REPORT</span>
            <button class="debug-modal-close">✕</button>
        </div>
        <div class="debug-modal-body">
            <p>A debug report has been captured. Share this with the developer to help fix issues.</p>

            <button class="debug-action-btn" id="debug-copy">
                📋 COPY TO CLIPBOARD
            </button>
            <button class="debug-action-btn" id="debug-download">
                💾 DOWNLOAD REPORT
            </button>
            <button class="debug-action-btn" id="debug-report">
                🐞 REPORT BUG ON ITCH.IO
            </button>
        </div>
    </div>
</div>
```

```css
.debug-modal {
    display: none;
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    z-index: 9500;
    align-items: center;
    justify-content: center;
}

.debug-modal.open {
    display: flex;
}

.debug-modal-backdrop {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background: rgba(0, 0, 0, 0.7);
}

.debug-modal-content {
    position: relative;
    background: linear-gradient(145deg, #1a1a2e 0%, #0f0f1a 100%);
    border: 3px solid #3a3a5a;
    padding: 0;
    max-width: 400px;
    width: 90%;
    box-shadow: 0 0 40px rgba(0, 0, 0, 0.5);
}

.debug-modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px 20px;
    border-bottom: 2px solid #3a3a5a;
    color: #8888aa;
    font-size: 14px;
    letter-spacing: 2px;
    text-transform: uppercase;
}

.debug-modal-close {
    background: none;
    border: none;
    color: #666688;
    font-size: 18px;
    cursor: pointer;
}

.debug-modal-close:hover {
    color: #aaaacc;
}

.debug-modal-body {
    padding: 20px;
}

.debug-modal-body p {
    color: #8888aa;
    font-size: 13px;
    line-height: 1.5;
    margin: 0 0 20px 0;
}

.debug-action-btn {
    display: block;
    width: 100%;
    padding: 12px 16px;
    margin-bottom: 10px;

    background: #2a2a4a;
    color: #aaaacc;
    border: 2px solid #3a3a5a;
    border-radius: 0;

    font-family: 'PixelFont', 'Courier New', monospace;
    font-size: 12px;
    letter-spacing: 1px;
    text-align: left;
    cursor: pointer;

    transition: all 0.15s ease;
}

.debug-action-btn:hover {
    background: #3a3a5a;
    color: #ffffff;
    border-color: #4a6cd4;
}

.debug-action-btn:last-child {
    margin-bottom: 0;
}
```

**Behavior:**
- ESC key closes modal
- Click backdrop closes modal
- Copy button shows "Copied!" feedback
- Report button opens itch.io community in new tab

---

## 7. Remove Old Crash Toast

Delete `ShowCaptureNotification` toast implementation from `crash_reporter.cpp`. Replace with call to open the debug modal via JavaScript interop.

```cpp
#if defined(__EMSCRIPTEN__)
void ShowCaptureNotification(const std::string& message) {
    // Open the debug modal instead of showing toast
    EM_ASM({
        if (window.openDebugModal) {
            window.openDebugModal();
        }
    });
}
#endif
```

---

## Summary of Changes

| File | Changes |
|------|---------|
| `src/minshell.html` | Alt text fix, pixel CSS classes, progress bar, floating suits, debug button, debug modal, JS handlers |
| `src/util/crash_reporter.cpp` | Replace toast with modal trigger |

## Testing Checklist

- [ ] Splash image missing → card suits show styled, not black "Loading..."
- [ ] Progress bar fills in pixelated segments
- [ ] Floating card suits animate behind loading container
- [ ] All containers have pixelated rounded corners
- [ ] Debug button visible after game loads (bottom-left)
- [ ] Click debug button → report captured → modal opens
- [ ] Modal: Copy works and shows feedback
- [ ] Modal: Download triggers .json file download
- [ ] Modal: Report opens itch.io community
- [ ] ESC closes modal
- [ ] On crash → modal opens automatically, button pulses red
- [ ] Dev console still works (` key)
