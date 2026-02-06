# UI Asset Pack Compatibility Plan (Crusenho Complete UI Essential Pack Free)

**Date:** 2026-02-06  
**Status:** Proposed  
**Primary Goal:** Ensure full practical compatibility with third-party UI packs like `/Users/joshuashin/Downloads/Complete_UI_Essential_Pack_Free`, then prove support with an in-engine interactive demo and verification evidence.

---

## 1. Objective

Deliver a repeatable compatibility workflow that:

1. Imports and maps all meaningful UI elements from the target pack.
2. Verifies rendering and interaction behavior across supported UI components.
3. Documents unsupported cases with explicit fallbacks or implementation tasks.
4. Produces a visual demo and test evidence proving real support.

---

## 2. Source Pack Inventory (Current Reality)

Input pack path:

- `/Users/joshuashin/Downloads/Complete_UI_Essential_Pack_Free`

Observed structure:

- `01_Flat_Theme/Spritesheets/Spritesheet_UI_Flat.png` (736x288)
- `01_Flat_Theme/Spritesheets/Spritesheet_UI_Flat_Animated.png` (128x128)
- `01_Flat_Theme/Sprites/*.png` (98 loose sprites)
- `01_Flat_Theme/Aseprite/*.aseprite`

Observed sprite families (count):

- `Bar` (13), `BarFill` (7), `Handle` (6)
- `Button` (8), `Select` (8), `ToggleOn/Off/Left/Right` (8 combined)
- `InputField` (2)
- `Frame`, `FrameSlot`, `FrameMarker`, `Banner`
- `Icon*` families (arrow/check/cross/play/point/dropdown/line/stripe)

License metadata present:

- CC BY 4.0 attribution requirement (must preserve credit in demo docs).

---

## 3. Existing Engine Support Baseline

Already implemented in this repo:

1. UI pack manifest loader (`ui.register_pack`, `ui.use_pack`).
2. Region schema with `region`, optional `9patch`, optional `scale_mode`.
3. Element buckets:
   - `panels`
   - `buttons` (normal/hover/pressed/disabled)
   - `progress_bars` (background/fill)
   - `scrollbars` (track/thumb)
   - `sliders` (track/thumb)
   - `inputs` (normal/focus)
   - `icons`
4. Rendering modes:
   - 9-patch
   - Sprite stretch/tile/fixed

Existing higher-level UI functionality to preserve and reuse first:

1. `assets/scripts/ui/ui_background.lua` for per-state background swapping (color / ninepatch / sprite).
2. `assets/scripts/ui/ui_decorations.lua` for badges/overlays without changing core layout behavior.
3. `assets/scripts/ui/ui_syntax_sugar.lua` + `assets/scripts/ui/ui_definition_helper.lua`:
   - `dsl.spritePanel`
   - `dsl.spriteButton`
   - sprite panel/button special field translation into existing `UIConfig`.
4. Existing sprite UI showcase and tests:
   - `assets/scripts/ui/sprite_ui_showcase.lua`
   - `assets/scripts/tests/test_sprite_ui.lua`
   - `assets/scripts/tests/test_ui_pack.lua`

Known likely gaps to validate:

1. No first-class semantic types for toggle/select/dropdown; currently composited from generic controls.
2. Pack editor has TODO paths for adding some non-button element types through the UI tool.
3. Animated atlas support is not explicit in pack schema (needs adapter strategy if required).

---

## 3.1 Minimal-Additions Policy (Hard Guardrail)

Before adding new code, each requirement must pass this decision order:

1. Reuse existing production path unchanged.
2. Reuse existing path with data/config only (manifest, sprite mapping, Lua table changes).
3. Add thin adapter around existing APIs.
4. Add new engine/runtime code only if 1-3 cannot satisfy compatibility.

Mandatory constraints:

1. Do not replace existing custom panel backgrounds or current UI behavior.
2. Do not fork duplicate widget systems when `ui_background`, `ui_decorations`, or DSL sprite components already fit.
3. Keep changes additive and localized to compatibility pack integration/demo paths unless a bug fix is required.
4. Any core runtime change must include a short rationale referencing why existing paths were insufficient.

---

## 4. Compatibility Matrix (What Must Be Proven)

For each pack family below, we must classify: `Native`, `Mapped`, or `Gap`.

1. Frame / FrameSlot / FrameMarker / Banner -> `panels` (9-patch or sprite).
2. Button variants (`Button01a_*`, `Button02a_*`, plus symbol buttons) -> `buttons` state mapping.
3. Select variants (`Select01a_*`, `Select02a_*`) -> mapped to button/radio-style state groups.
4. Toggle variants (`ToggleOn/Off/...`) -> mapped to toggled button state sets.
5. Bars + fills (`Bar*`, `BarFill*`) -> `progress_bars`, `sliders`, `scrollbars`.
6. Handles (`Handle*`) -> slider/scrollbar `thumb`.
7. Input fields (`InputField01/02`) -> `inputs` normal/focus.
8. Icons (`Icon*`) -> `icons` (fixed scale where appropriate).
9. Animated spritesheet -> explicit decision:
   - `Supported` via frame swap adapter, or
   - `Deferred` with documented non-goal and static fallback.

Any family not passing `Native` or `Mapped` must have a concrete remediation step before final signoff.

---

## 5. Implementation Phases

## Phase 0: Planning + Evidence Scaffolding

Deliverables:

1. This plan file.
2. Tracking checklist for each sprite family and UI behavior.
3. Baseline audit of existing UI usage (where current backgrounds/sprite panels are already active).

Exit criteria:

1. Checklist is complete enough to drive implementation without ambiguity.
2. Baseline reuse map is complete enough to prevent redundant implementation.

## Phase 1: Pack Ingestion + Manifest Authoring

Deliverables:

1. New pack folder under repo assets (non-destructive import copy).
2. `pack.json` manifest covering all selected sprites with naming conventions.
3. Optional helper script for deterministic manifest generation from loose sprite names.

Validation:

1. `ui.register_pack(...)` succeeds without atlas bounds warnings.
2. `ui.use_pack(...)` returns a valid handle.

## Phase 2: Semantic Mapping Layer

Deliverables:

1. Prefer config-only mapping through existing systems first:
   - `dsl.spritePanel`
   - `dsl.spriteButton`
   - `ui_background`
2. If needed, add a thin Lua helper/adaptor module that maps pack primitives into higher-level controls:
   - toggle
   - segmented/select controls
   - dropdown-like header/button style
3. Consistent naming contract for stateful widgets.

Validation:

1. All matrix families are reachable through one of:
   - direct pack call (`panel`, `button`, etc.)
   - existing sprite UI DSL/background systems
   - adaptor API.

## Phase 3: Comprehensive Compatibility Checks

Deliverables:

1. Automated checks (Lua/script/unit where practical):
   - manifest schema/load checks
   - missing region/state checks
   - bounds/size sanity checks
2. Runtime verification scenes/scripts for:
   - all button states
   - toggle transitions
   - input focus states
   - slider and scrollbar track/thumb behavior
   - progress fill behavior
   - icon rendering at multiple scales
3. Resolution checks at minimum:
   - 1280x720
   - 1920x1080

Validation:

1. No missing-asset runtime errors in verification flow.
2. No severe visual clipping/stretch artifacts for mapped components.

## Phase 4: Demo Proof

Deliverables:

1. A dedicated interactive demo scene/script that displays:
   - all mapped widget families
   - live state changes (hover/pressed/disabled, toggled, focused, filled)
   - side-by-side reference labels for which source sprite is used
2. Captured evidence:
   - baseline screenshots
   - concise compatibility report (pass/fail + notes per family)

Validation:

1. Demo runs from a documented command/path in this repo.
2. Every matrix family is visibly demonstrated or explicitly flagged as deferred with fallback.

## Phase 5: Final Signoff

Deliverables:

1. Compatibility report with:
   - status per family (`Native` / `Mapped` / `Gap`)
   - known constraints
   - next steps for remaining gaps
2. Attribution note for CC BY 4.0 in demo/report docs.

Exit criteria:

1. User can run one command/workflow and see proof of compatibility end-to-end.

---

## 6. Verification Commands (Planned)

Build + tests (use exact command subset relevant to modified code):

1. `just build-debug-fast`
2. `just test-ui-sizing`
3. `just ui-test-all`
4. Targeted Lua test entry for the new pack compatibility suite.

Visual verification:

1. Launch demo script/scene with auto-start flags where possible.
2. Capture/update UI baselines if we add deterministic snapshot points.

---

## 7. Definition Of Done

This effort is done when all are true:

1. The Crusenho pack is imported and registered through `ui.register_pack`.
2. All major sprite families are either supported directly or mapped via adapters.
3. Comprehensive checks pass with documented output.
4. A runnable interactive demo proves behavior across widget states.
5. A compatibility report is committed with evidence and any residual gaps.

---

## 8. Risks + Mitigations

1. Ambiguous sprite semantics (multiple plausible mappings).
   - Mitigation: keep mapping table explicit and demo each chosen mapping.
2. Animated assets not covered by current schema.
   - Mitigation: implement adapter frame-switching or formally defer with static fallback and documented rationale.
3. State explosion (many variants).
   - Mitigation: enforce naming conventions + automated completeness checks.
4. Visual regressions in existing UI.
   - Mitigation: use existing UI tests/baselines before and after integration.
