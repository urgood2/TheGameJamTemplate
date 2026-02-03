# Interview Transcript: End-to-End Testing Automation

**Date:** 2026-02-02
**Interviewer:** Claude
**Subject:** Testing automation for TheGameJamTemplate

---

## Round 1: Vision & Scope

### Q: What is the primary goal of this testing automation work?

**Answer:** Create an end-to-end testing system for the game executable—similar to Playwright but for native games. The system should simulate player inputs (clicks, keypresses) and verify their results automatically.

### Q: Do you have any existing testing infrastructure?

**Answer:** No existing system for this type of testing. Starting from scratch.

---

## Round 2: Implementation Details

### Q: How do you want to verify test results?

**Answer:** Combination of methods:
- Screenshot/image comparison (visual regression)
- Reading game state from Lua (e.g., `player.health == 80`)
- Log output parsing (grep for expected messages)

### Q: What kinds of interactions do you want to test first?

**Answer (multiple selections):**
1. Menu navigation
2. Combat & abilities
3. UI clicking and response

### Q: How should tests execute?

**Answer:** Both headless and visible modes:
- Headless for CI pipelines (fast, automated)
- Visible window for debugging (see what's happening)

### Q: How should input be injected into the game?

**Answer:** Built-in test mode (recommended approach)
- Engine reads scripted inputs from file or IPC
- Most reliable and deterministic
- Avoids OS-level input simulation fragility

---

## Key Requirements Summary

| Requirement | Detail |
|-------------|--------|
| **Test Type** | End-to-end, black-box style |
| **Input Method** | Built-in test mode (scripted inputs) |
| **Verification** | Screenshots + Lua state queries + log parsing |
| **Execution Modes** | Headless (CI) + Visible (debug) |
| **Priority Areas** | Menu nav, combat/abilities, UI interactions |
| **Existing Infrastructure** | None - greenfield implementation |

---

## Technical Constraints Identified

1. **Cross-platform**: Engine runs on Linux, macOS, Windows, and Web (Emscripten)
2. **Lua-first architecture**: Game logic lives in Lua, C++ provides engine systems
3. **Raylib-based**: Input/rendering through Raylib APIs
4. **LuaJIT optional**: Tests should work with both Lua 5.4 and LuaJIT backends
