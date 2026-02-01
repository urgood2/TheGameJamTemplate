# Vertical Slice Plan (2–3 Months)

Actionable roadmap to ship a playable demo to itch.io + Steam. Timebox is ~10–12 weeks; adjust pacing by combining or stretching weeks as needed.

---

## Goal & Scope
- One 8–12 minute run: start → waves → shop → boss/elite → victory/defeat.
- 1 hero kit (dash + stamina), 1 wand chassis with 2 triggers (`every_N_seconds`, `on_dash`), 4 actions (bolt, pierce line, hazard patch, summon turret/minion), 3 modifiers (double-cast, pierce, speed/haste).
- 3 enemy types + 1 elite/boss; 1 LDtk map with collisions; XP/gold drops; shop to buy/swap cards; basic leveling (physique/cunning/spirit).
- Controller + mouse both usable; readable tooltips; stable framerate; no crashes in a full loop.

---

## Phase Plan (High-Level)
- **Phase 1 (Weeks 1–2): Unblock Core Systems** — Projectiles visible/moving; physics ↔ transform stability; LDtk map with colliders; fast reset loop.
- **Phase 2 (Weeks 3–4): Wand Execution + Card Bridge** — Trigger → action → modifier execution end-to-end; validation; damage plumbed into CombatSystem.
- **Phase 3 (Weeks 5–6): Combat Loop + Progression** — Wave manager, state machine, XP/gold, shop, level-up; HUD for HP/stamina/wand.
- **Phase 4 (Weeks 7–10): Content + UX + Release** — Enemies, balance, controller polish, tooltips, audio pass, performance, packaging, store assets.

---

## Week-by-Week Checklist

### Weeks 1–2: Core System Unblocks
- [ ] Make projectiles visible and moving (hit the top block of `TESTING_CHECKLIST.md`).
- [ ] Fix physics/transform jitter, drag/drop collider drift, and z-order on first overlap (Task 5 in `TODO_systems_refined.md`).
- [ ] Build one LDtk map with colliders; wire into Chipmunk (also covers “sample map with colliders” from `TODO.md`).
- [ ] Add “Reset run” debug action: fully clear state and reload scripts.
- [ ] Verify batching vs. non-batching rendering path for cards; pick one for the slice.

### Weeks 3–4: Wand Execution + Card Bridge
- [ ] Implement minimal WandExecutor path: trigger (`every_N_seconds`, `on_dash`) → action → modifiers (double-cast, pierce, speed).
- [ ] Enforce wand/card validation: slot caps, trigger/action limits, stacking z-order reset.
- [ ] Ensure projectiles inherit wand stats and emit hit events into `CombatSystem`.
- [ ] Connect card definitions to gameplay (card → spell conversion) and add basic cost/requirements.
- [ ] Smoke test: run loop where one trigger fires `fire_basic_bolt` and deals damage.

### Weeks 5–6: Combat Loop + Progression
- [ ] Wave manager + spawner (3 mobs + elite/boss) on the LDtk map.
- [ ] State machine: INIT → COMBAT → SHOP → NEXT → VICTORY/DEFEAT; no board-update stalls on state change.
- [ ] XP/gold drops; simple shop UI to buy/sell/swap cards; level-up (+physique/+cunning/+spirit).
- [ ] HUD: HP, dash stamina, wand cooldowns, gold/XP; death/victory screens.
- [ ] Stability: no crashes over 5 back-to-back runs.

### Weeks 7–8: Content + UX Polish
- [ ] Finalize vertical-slice card list numbers; tune 2–3 enemy behaviors (charger, ranged, hazard dropper).
- [ ] Controller fixes: cursor snapping/accuracy, disable mouse when controller active, trigger area single-card, main menu navigation.
- [ ] Tooltip readability, card area shifting under load, card stack z-order reset; avoid broken shaders (skip `starry_tunnel`/`3d_skew` on cards).
- [ ] Audio pass: dash/loot variations, volume normalization, toggle for tick sounds.
- [ ] Juice essentials only: shake on hit, brief flash on loot, clean shop confirm/deny feedback.

### Weeks 9–10 (Stretch 11–12): Freeze + Release Prep
- [ ] Performance/memory: WASM leak check; card drag perf; batch render path for stacks.
- [ ] QA sweep with `TESTING_CHECKLIST.md` integration cases; 10-run balance loop.
- [ ] Builds: desktop (Win/macOS/Linux), web (itch) if perf is acceptable; automate scripts.
- [ ] Steam: depots + demo branch; minimal Steamworks init (no achievements needed).
- [ ] Itch: upload web build (if smooth) + desktop zip; controller note in page copy.
- [ ] Store assets: 5–7 screenshots, 30–45s gameplay clip, short “How to play” blurb.
- [ ] Disable unfinished menus/features; ship only the slice.

---

## Workstream Checklists

**Systems (must-fix for slice)**  
- [ ] Physics/transform jitter and drag/drop drift resolved.  
- [ ] Card z-order on first overlap; card area shifting with many cards.  
- [ ] Tooltip text overflow fixed; background translucency regression verified.  
- [ ] Avoid broken shaders in slice (`starry_tunnel`, `item_glow`, `3d_skew` on cards).  
- [ ] WASM memory leak addressed; timers/entities cleaned up on wave end.

**Content (minimal slice)**
- [ ] Triggers: `every_N_seconds`, `on_dash`.  
- [ ] Actions: fire_basic_bolt, piercing_line, spike/hazard patch, summon_turret.  
- [ ] Modifiers: double_effect (double-cast), projectile_pierces_twice, speed_up.  
- [ ] Enemy set: charger, ranged, hazard dropper; 1 elite/boss pattern.  
- [ ] LDtk map with collisions and spawn points.

**UX/Input**
- [ ] Controller + mouse parity; disable mouse when controller active.  
- [ ] Cursor snaps to selection; trigger area enforces single-card; main menu navigable.  
- [ ] Tooltips readable, concise; card stacking/z-order reliable.  
- [ ] HUD shows HP/stamina/wand CD/gold/XP; death/victory screens.

**Release**
- [ ] Deterministic build scripts (desktop + web if viable).  
- [ ] Steam demo branch set; itch page drafted with builds.  
- [ ] QA matrix: KB/mouse + controller, 1080p/1440p, stable 60 FPS target.  
- [ ] 5 crash-free full-loop runs minimum before upload.

---

## Daily/Weekly Cadence
- Daily: 1–2 focused goals, 1 playtest, log bugs into TODOs with repro steps.
- End of each week: checkpoint against this file + `TESTING_CHECKLIST.md`; prune scope if slipping.
- Keep slice-only mindset: defer non-slice shaders, fancy effects, or extra card types.

---

## Fast Start (Next 7 Days)
- [ ] Verify projectile visibility/movement; tick the top block in `TESTING_CHECKLIST.md`.  
- [ ] Fix physics jitter/drag/drop drift and first-overlap z-order.  
- [ ] Build LDtk map with colliders and hook into Chipmunk.  
- [ ] Implement minimal WandExecutor path for `every_N_seconds` → `fire_basic_bolt` + one modifier; confirm damage lands.  
- [ ] Add “Reset run” debug action to reload scripts/state quickly.  

---

## Solo Dev Tips (First Release)
- Lock scope weekly: keep 2–3 active tasks; push new ideas to “post-launch.”
- Automate builds: one-button desktop/web script; nightly build + smoke test; tag releases on a clean branch.
- In-game feedback: bug-report link (mailto with logs path), console overlay, include seed/run ID in logs.
- Analytics light: session start/end, run length, waves cleared, deaths, hardware (GPU/CPU). No PII.
- Store prep early: draft Steam/itch pages now; capture 5–7 screenshots + 30–45s clip once loop is stable; add a short “how to play.”
- QA on other machines: 3–5 friends across KB/mouse + controller; test alt-tab, resize, first-run settings, corrupted save handling.
- Settings must-haves: volume sliders, fullscreen/windowed toggle, controller layout hint or remap prompt, mute tick option.
- Saves: simple versioned JSON; auto-backup last save; migrate gracefully when fields change.
- Accessibility quick wins: larger text option, color-blind-friendly telegraphs, reduced-flash toggle, readable tooltips.
- Community handling: pinned “bugs & feedback” thread and a short FAQ; prepare template replies for common issues.
- Legal/attribution: verify licenses for music/SFX/fonts; include credits; add a short demo disclaimer/EULA.
- Launch checklist: test with Steam overlay on/off, offline mode, no-controller plugged; if shipping web, verify memory cap and mobile fail-fast messaging.  

### Owner/Date Tracker (prefilled target weeks)
| Item | Owner | Due (Target Week) | Status |
| --- | --- | --- | --- |
| Nightly build + smoke test script | You | End of Week 2 (Phase 1) |  |
| In-game bug report link | You | Mid Week 3 (Phase 2) |  |
| Lightweight analytics events | You | End of Week 4 (Phase 2) |  |
| Store pages drafted (Steam/itch) | You | End of Week 5 (Phase 3) |  |
| QA with 3–5 friends | You | Week 7 (Phase 4 start) |  |
| Launch checklist dry run | You | Week 9 (pre-freeze) |  |

### In-Game Bug Report & Logging Checklist
- [ ] Add bug button/menu item linking to mailto/URL; prefill subject with build tag + platform.
- [ ] Include log path on screen when bug form opens; optionally add “copy logs” button.
- [ ] Capture: build tag, platform, GPU/CPU, run seed/ID, wave number, wand loadout hash, controller vs. KB/mouse.
- [ ] Console overlay toggle: shows last 50 log lines + errors; keep it non-blocking in release.
- [ ] Log rotation: cap log size and keep last N files; avoid PII; include timestamps.
- [ ] Crash/fatal handler: write last message + stack (if available) and seed; reopen game to a “sorry” screen with log location.  

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
