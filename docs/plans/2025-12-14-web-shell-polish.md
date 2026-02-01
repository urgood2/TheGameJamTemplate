# Web Shell Polish Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Polish the web loading shell with pixelated aesthetics, floating card suit animation, and improved debug report UX.

**Architecture:** All changes are in `minshell.html` (CSS + JS + HTML) except for one C++ change in `crash_reporter.cpp` to replace the toast notification with a modal trigger.

**Tech Stack:** HTML5, CSS3 (clip-path, animations), vanilla JavaScript, Emscripten interop

---

## Task 1: Fix Alt Text and Add Pixel-Rounded CSS Class

**Files:**
- Modify: `src/minshell.html:323` (alt text)
- Modify: `src/minshell.html:31-317` (add CSS)

**Step 1: Add the pixel-rounded CSS class**

Add after line 57 (after the `body` styles):

```css
        /* Pixelated rounded corners via clip-path */
        .pixel-rounded {
            border-radius: 0 !important;
            clip-path: polygon(
                0 8px,
                2px 8px, 2px 4px,
                4px 4px, 4px 2px,
                8px 2px, 8px 0,
                calc(100% - 8px) 0,
                calc(100% - 8px) 2px, calc(100% - 4px) 2px,
                calc(100% - 4px) 4px, calc(100% - 2px) 4px,
                calc(100% - 2px) 8px, 100% 8px,
                100% calc(100% - 8px),
                calc(100% - 2px) calc(100% - 8px), calc(100% - 2px) calc(100% - 4px),
                calc(100% - 4px) calc(100% - 4px), calc(100% - 4px) calc(100% - 2px),
                calc(100% - 8px) calc(100% - 2px), calc(100% - 8px) 100%,
                8px 100%,
                8px calc(100% - 2px), 4px calc(100% - 2px),
                4px calc(100% - 4px), 2px calc(100% - 4px),
                2px calc(100% - 8px), 0 calc(100% - 8px)
            );
        }

        /* Small variant for buttons */
        .pixel-rounded-sm {
            border-radius: 0 !important;
            clip-path: polygon(
                0 4px,
                2px 4px, 2px 2px,
                4px 2px, 4px 0,
                calc(100% - 4px) 0,
                calc(100% - 4px) 2px, calc(100% - 2px) 2px,
                calc(100% - 2px) 4px, 100% 4px,
                100% calc(100% - 4px),
                calc(100% - 2px) calc(100% - 4px), calc(100% - 2px) calc(100% - 2px),
                calc(100% - 4px) calc(100% - 2px), calc(100% - 4px) 100%,
                4px 100%,
                4px calc(100% - 2px), 2px calc(100% - 2px),
                2px calc(100% - 4px), 0 calc(100% - 4px)
            );
        }
```

**Step 2: Update splash-image styles for alt text fallback**

Replace the `#splash-image` block (around line 144-151) with:

```css
        #splash-image {
            max-width: 100%;
            max-height: 120px;
            margin-bottom: 24px;
            image-rendering: pixelated;
            image-rendering: crisp-edges;
            filter: drop-shadow(0 0 8px rgba(255, 255, 255, 0.2));
            /* Alt text fallback styling */
            color: #8888aa;
            font-size: 14px;
            letter-spacing: 4px;
            display: flex;
            align-items: center;
            justify-content: center;
            min-height: 80px;
        }
```

**Step 3: Change alt text**

Change line 323 from:
```html
            <img id="splash-image" src="splash.png" alt="Loading..." />
```

To:
```html
            <img id="splash-image" src="splash.png" alt="~ ~ ~" />
```

**Step 4: Add pixel-rounded class to loading-container**

Change the loading-container div (line 322) from:
```html
        <div class="loading-container">
```

To:
```html
        <div class="loading-container pixel-rounded">
```

**Step 5: Verify in browser**

Run: `just build-web && python3 scripts/serve_web.py`
- Open http://localhost:8080
- Verify loading container has stepped corners
- Delete splash.png temporarily to verify alt text is styled

**Step 6: Commit**

```bash
git add src/minshell.html
git commit -m "feat(web): add pixel-rounded corners and fix alt text fallback"
```

---

## Task 2: Pixelate Progress Bar

**Files:**
- Modify: `src/minshell.html` (CSS for progress bar)

**Step 1: Update progress-container styles**

Replace `#progress-container` block (around line 154-163) with:

```css
        #progress-container {
            width: 100%;
            height: 20px;
            background: #0a0a14;
            border: 2px solid #3a3a5a;
            border-radius: 0;
            overflow: hidden;
            margin-bottom: 12px;
            box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.5);
        }
```

**Step 2: Update progress-bar styles**

Replace `#progress-bar` block (around line 166-177) with:

```css
        #progress-bar {
            width: 0%;
            height: 100%;
            border-radius: 0;
            transition: width 0.3s ease;
            /* Pixelated segments - 8px chunks with 2px gaps */
            background: repeating-linear-gradient(
                90deg,
                #4a6cd4 0px,
                #4a6cd4 8px,
                #3a5cc4 8px,
                #3a5cc4 10px
            );
            image-rendering: pixelated;
            image-rendering: crisp-edges;
            box-shadow: 0 0 10px rgba(100, 140, 230, 0.5);
        }
```

**Step 3: Update loading animation**

Replace `#progress-bar.loading` block (around line 179-181) with:

```css
        #progress-bar.loading {
            animation: progressPulse 1.5s ease-in-out infinite;
        }
```

Remove the `progressShine` animation reference (the segmented look doesn't need it).

**Step 4: Verify in browser**

Run: `just build-web && python3 scripts/serve_web.py`
- Verify progress bar has discrete segments
- Verify it fills smoothly during load

**Step 5: Commit**

```bash
git add src/minshell.html
git commit -m "feat(web): pixelate progress bar with segmented fill"
```

---

## Task 3: Add Floating Card Suits Animation

**Files:**
- Modify: `src/minshell.html` (CSS + HTML + JS)

**Step 1: Add floating suit CSS**

Add after the progress bar styles (around line 200):

```css
        /* Floating Card Suits Animation */
        .floating-suits-container {
            position: absolute;
            bottom: 0;
            left: 50%;
            transform: translateX(-50%);
            width: 300px;
            height: 150px;
            pointer-events: none;
            overflow: hidden;
            z-index: 1;
        }

        @keyframes floatUp {
            0% {
                transform: translateY(0) rotate(0deg);
                opacity: 0;
            }
            10% { opacity: 0.5; }
            90% { opacity: 0.5; }
            100% {
                transform: translateY(-140px) rotate(15deg);
                opacity: 0;
            }
        }

        .floating-suit {
            position: absolute;
            bottom: 0;
            font-size: 18px;
            color: #4a6cd4;
            opacity: 0;
            animation: floatUp 4s ease-in-out infinite;
            text-shadow: 0 0 8px rgba(100, 140, 230, 0.4);
        }

        .floating-suit:nth-child(1) { left: 10%; animation-delay: 0s; }
        .floating-suit:nth-child(2) { left: 30%; animation-delay: 0.8s; }
        .floating-suit:nth-child(3) { left: 50%; animation-delay: 1.6s; }
        .floating-suit:nth-child(4) { left: 70%; animation-delay: 2.4s; }
        .floating-suit:nth-child(5) { left: 90%; animation-delay: 3.2s; }
```

**Step 2: Add floating suits HTML**

Add inside the `#splash` div, before the loading-container (around line 322):

```html
        <!-- Floating card suits background animation -->
        <div class="floating-suits-container">
            <span class="floating-suit">♠</span>
            <span class="floating-suit">♥</span>
            <span class="floating-suit">♦</span>
            <span class="floating-suit">♣</span>
            <span class="floating-suit">♠</span>
        </div>
```

**Step 3: Verify in browser**

Run: `just build-web && python3 scripts/serve_web.py`
- Verify card suits float upward behind loading container
- Verify they're subtle and don't distract

**Step 4: Commit**

```bash
git add src/minshell.html
git commit -m "feat(web): add floating card suits animation during loading"
```

---

## Task 4: Add Debug Button

**Files:**
- Modify: `src/minshell.html` (CSS + HTML + JS)

**Step 1: Add debug button CSS**

Add after the dev console styles (around line 303):

```css
        /* ============================================
           DEBUG BUTTON
           ============================================ */
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
            pointer-events: none;
            transition: opacity 0.3s ease, background 0.2s ease, box-shadow 0.2s ease;
        }

        .debug-btn.visible {
            opacity: 1;
            pointer-events: auto;
        }

        .debug-btn:hover {
            background: #3a3a5a;
            color: #aaaacc;
            box-shadow: 0 0 12px rgba(100, 140, 230, 0.3);
        }

        @keyframes crashPulse {
            0%, 100% { box-shadow: 0 0 0 0 rgba(220, 80, 80, 0.7); }
            50% { box-shadow: 0 0 0 8px rgba(220, 80, 80, 0); }
        }

        .debug-btn.crash-alert {
            animation: crashPulse 1s ease-in-out 3;
            border-color: #dd4444;
        }
```

**Step 2: Add debug button HTML**

Add after the dev console div (around line 350):

```html
    <!-- Debug Button -->
    <button id="debug-btn" class="debug-btn pixel-rounded-sm" title="Capture Debug Report">
        🐛 ?
    </button>
```

**Step 3: Add debug button JS**

Add inside the loading system IIFE (around line 550, after the `gameReady` function):

```javascript
            // Show debug button when game is ready
            window.gameReady = function() {
                console.log('[Loading] Game ready signal received');

                if (window._endStartupPhase) {
                    window._endStartupPhase();
                }

                progressBar.style.width = '100%';
                progressBar.classList.remove('loading');
                progressText.textContent = 'READY';

                setTimeout(function() {
                    splash.classList.add('fade-out');
                    canvas.classList.add('visible');

                    // Show debug button
                    document.getElementById('debug-btn').classList.add('visible');

                    setTimeout(function() {
                        splash.style.display = 'none';
                    }, 500);
                }, 200);
            };
```

**Step 4: Verify in browser**

Run: `just build-web && python3 scripts/serve_web.py`
- Wait for game to load
- Verify debug button appears in bottom-left
- Verify hover effect works

**Step 5: Commit**

```bash
git add src/minshell.html
git commit -m "feat(web): add persistent debug button in bottom-left"
```

---

## Task 5: Add Debug Modal

**Files:**
- Modify: `src/minshell.html` (CSS + HTML + JS)

**Step 1: Add debug modal CSS**

Add after the debug button styles:

```css
        /* ============================================
           DEBUG MODAL
           ============================================ */
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
            padding: 0;
            line-height: 1;
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

        .debug-action-btn.success {
            background: #2a4a2a;
            border-color: #3a6a3a;
        }
```

**Step 2: Add debug modal HTML**

Add after the debug button:

```html
    <!-- Debug Modal -->
    <div id="debug-modal" class="debug-modal">
        <div class="debug-modal-backdrop" id="debug-modal-backdrop"></div>
        <div class="debug-modal-content pixel-rounded">
            <div class="debug-modal-header">
                <span>🐛 DEBUG REPORT</span>
                <button class="debug-modal-close" id="debug-modal-close">✕</button>
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

**Step 3: Add debug modal JS**

Add a new IIFE after the loading system (around line 618):

```javascript
    // ============================================
    // DEBUG MODAL SYSTEM
    // ============================================
    (function() {
        const debugBtn = document.getElementById('debug-btn');
        const debugModal = document.getElementById('debug-modal');
        const debugModalBackdrop = document.getElementById('debug-modal-backdrop');
        const debugModalClose = document.getElementById('debug-modal-close');
        const debugCopy = document.getElementById('debug-copy');
        const debugDownload = document.getElementById('debug-download');
        const debugReport = document.getElementById('debug-report');

        let lastReport = null;

        function openModal() {
            debugModal.classList.add('open');
        }

        function closeModal() {
            debugModal.classList.remove('open');
        }

        function captureReport() {
            // Capture console logs
            const logs = window._getConsoleLogs ? window._getConsoleLogs() : [];

            lastReport = {
                timestamp: new Date().toISOString(),
                userAgent: navigator.userAgent,
                url: window.location.href,
                screen: { width: screen.width, height: screen.height },
                viewport: { width: window.innerWidth, height: window.innerHeight },
                logs: logs.slice(-200) // Last 200 log entries
            };

            // Try to get WebGL info
            try {
                const canvas = document.getElementById('canvas');
                const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');
                if (gl) {
                    const debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
                    if (debugInfo) {
                        lastReport.webglRenderer = gl.getParameter(debugInfo.UNMASKED_RENDERER_WEBGL);
                    }
                }
            } catch (e) {
                lastReport.webglRenderer = 'unknown';
            }

            return lastReport;
        }

        function getReportText() {
            if (!lastReport) captureReport();
            return JSON.stringify(lastReport, null, 2);
        }

        // Debug button click
        debugBtn.addEventListener('click', function() {
            captureReport();
            openModal();
        });

        // Close handlers
        debugModalClose.addEventListener('click', closeModal);
        debugModalBackdrop.addEventListener('click', closeModal);
        document.addEventListener('keydown', function(e) {
            if (e.key === 'Escape' && debugModal.classList.contains('open')) {
                closeModal();
            }
        });

        // Copy to clipboard
        debugCopy.addEventListener('click', function() {
            const text = getReportText();
            navigator.clipboard.writeText(text).then(function() {
                debugCopy.textContent = '✓ COPIED!';
                debugCopy.classList.add('success');
                setTimeout(function() {
                    debugCopy.textContent = '📋 COPY TO CLIPBOARD';
                    debugCopy.classList.remove('success');
                }, 2000);
            }).catch(function(err) {
                console.error('Copy failed:', err);
                debugCopy.textContent = '✗ FAILED';
                setTimeout(function() {
                    debugCopy.textContent = '📋 COPY TO CLIPBOARD';
                }, 2000);
            });
        });

        // Download report
        debugDownload.addEventListener('click', function() {
            const text = getReportText();
            const blob = new Blob([text], { type: 'application/json' });
            const url = URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = url;
            link.download = 'debug_report_' + new Date().toISOString().replace(/[:.]/g, '-') + '.json';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            URL.revokeObjectURL(url);

            debugDownload.textContent = '✓ DOWNLOADED!';
            debugDownload.classList.add('success');
            setTimeout(function() {
                debugDownload.textContent = '💾 DOWNLOAD REPORT';
                debugDownload.classList.remove('success');
            }, 2000);
        });

        // Report bug
        debugReport.addEventListener('click', function() {
            window.open('https://chugget.itch.io/testing/community', '_blank');
        });

        // Expose for C++ crash reporter
        window.openDebugModal = function() {
            captureReport();
            debugBtn.classList.add('crash-alert');
            setTimeout(function() {
                debugBtn.classList.remove('crash-alert');
            }, 3000);
            openModal();
        };

        // Expose function to set report from C++
        window.setDebugReport = function(reportJson) {
            try {
                lastReport = JSON.parse(reportJson);
            } catch (e) {
                lastReport = { raw: reportJson };
            }
        };
    })();
```

**Step 4: Expose console logs for capture**

Add to the dev console IIFE (around line 500, after `updateStats` function):

```javascript
            // Expose logs for debug report capture
            window._getConsoleLogs = function() {
                return [...startupLogs, ...runtimeLogs];
            };
```

**Step 5: Verify in browser**

Run: `just build-web && python3 scripts/serve_web.py`
- Click debug button → modal opens
- Test Copy button → clipboard contains JSON
- Test Download button → .json file downloads
- Test Report button → opens itch.io
- ESC closes modal
- Click backdrop closes modal

**Step 6: Commit**

```bash
git add src/minshell.html
git commit -m "feat(web): add debug modal with copy/download/report actions"
```

---

## Task 6: Update C++ Crash Reporter

**Files:**
- Modify: `src/util/crash_reporter.cpp:530-703`

**Step 1: Simplify ShowCaptureNotification**

Replace the entire `ShowCaptureNotification` function (lines 530-703) with:

```cpp
void ShowCaptureNotification(const std::string& message) {
    // Pass the serialized report to JS and open the modal
    const auto& json = state().last_json;
    EM_ASM({
        // Set the report data
        if (window.setDebugReport) {
            window.setDebugReport(UTF8ToString($0));
        }
        // Open the modal
        if (window.openDebugModal) {
            window.openDebugModal();
        }
    }, json.c_str());
}
```

**Step 2: Build and test**

Run: `just build-web`
- Verify no compile errors

**Step 3: Commit**

```bash
git add src/util/crash_reporter.cpp
git commit -m "refactor(crash): replace toast notification with modal trigger"
```

---

## Task 7: Final Polish and Testing

**Files:**
- Modify: `src/minshell.html` (minor tweaks if needed)

**Step 1: Full integration test**

Run: `just build-web && python3 scripts/serve_web.py`

Test checklist:
- [ ] Loading screen shows with pixelated corners
- [ ] Progress bar fills with discrete segments
- [ ] Card suits float upward during loading
- [ ] Alt text shows styled if splash.png missing
- [ ] Debug button appears after game loads (bottom-left)
- [ ] Click debug button → modal opens
- [ ] Modal has pixelated corners
- [ ] Copy works with feedback
- [ ] Download works
- [ ] Report opens itch.io
- [ ] ESC closes modal
- [ ] Dev console still works (` key)

**Step 2: Push to remote**

```bash
git push origin feature/web-ux-improvements
```

**Step 3: Create summary commit if needed**

If all tests pass and no additional changes needed, the feature is complete.

---

## Summary

| Task | Description | Estimated |
|------|-------------|-----------|
| 1 | Pixel-rounded CSS + alt text fix | 5 min |
| 2 | Pixelated progress bar | 3 min |
| 3 | Floating card suits animation | 5 min |
| 4 | Debug button | 5 min |
| 5 | Debug modal | 10 min |
| 6 | C++ crash reporter update | 3 min |
| 7 | Integration testing | 5 min |

**Total: ~36 minutes**

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
