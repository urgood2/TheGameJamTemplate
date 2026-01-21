# Feature Showcase Implementation Plan

**Date:** 2026-01-20
**Source Design:** docs/plans/2026-01-20-feature-showcase-design.md
**Decision Updates:**
- Use raw data fields (no localization lookups).
- Integrate via the existing Tab Demo panel (new tab), not a standalone main menu button.

## Goals
- Implement a fullscreen Feature Showcase UI that demonstrates Phase 1–6 gameplay systems.
- Surface automated pass/fail badges per item with a category summary row.
- Provide simple navigation (tabs, scroll) with a view-only card gallery.

## Entry Point (Tab Demo)
- Add a new tab to `createTabDemo()` in `assets/scripts/core/main.lua`.
- The tab label should be **"Showcase"**.
- The tab content should either:
  - Directly render the Feature Showcase UI, or
  - Provide an "Open Feature Showcase" button that opens the fullscreen overlay (recommended to avoid cramped layout inside the tab panel).

## Data Sources (Raw Fields)
- **Gods & Classes:** `assets/scripts/data/avatars.lua`
  - Filter by `type == "god"` or `type == "class"`.
- **Skills:** `assets/scripts/data/skills.lua`
- **Artifacts:** `assets/scripts/data/artifacts.lua`
- **Status Effects:** `assets/scripts/data/status_effects.lua`
- **Wands:** `assets/scripts/core/card_eval_order_test.lua` (use `wand_defs` like tests do)

## New Modules

### 1) `assets/scripts/ui/showcase/showcase_verifier.lua`
**Responsibility:**
- Run validations for each category and return badge data.
- Cache results so repeated UI opens are fast.

**API:**
```
ShowcaseVerifier = {
  runAll = function() -> results
  invalidate = function() -> nil
}
```

**Results Shape:**
```
results = {
  categories = {
    gods_classes = {
      pass = 7, total = 7,
      items = {
        pyra = { ok = true },
        frost = { ok = true },
        ...
      }
    },
    skills = {...},
    artifacts = {...},
    wands = {...},
    status_effects = {...}
  },
  errors = { "optional fatal messages" }
}
```

**Validation Rules (raw):**
- **Gods & Classes:** entry exists, `type` is `"god"` or `"class"`, has at least one `effects` entry; for gods, ensure at least one `effects` entry with `type == "blessing"`.
- **Skills:** entry exists with `id`, `name`, `element`, and `buffs` or `effects` table.
- **Artifacts:** entry exists, has `rarity`, and a `calculate` function.
- **Wands:** entry exists with `id`, `trigger_type`, `mana_max`.
- **Status Effects:** entry exists with `effect_type` and `duration`.

### 2) `assets/scripts/ui/showcase/showcase_cards.lua`
**Responsibility:**
- Build UI cards for each category using `dsl.strict`.
- Consistent layout, fixed min sizes, shared badge rendering.

**Helpers:**
- `renderBadge(ok)` returns a small icon/text block (green ✓ / red ✗).
- `formatEffects(effects)` returns short strings for display.
- `safeGet(value, fallback)` for missing fields.

**Per-Card Contents:**
- **Gods & Classes:** icon (optional), name, type, passive stat buffs (from `effects`), blessing summary (name + cooldown + key config).
- **Skills:** name, element, short buff list.
- **Artifacts:** name, rarity, element (if any), short effect description (raw field or first line).
- **Wands:** name/id, trigger type, mana stats, cast block, always-cast list.
- **Status Effects:** name/id, effect type, duration, short description.

### 3) `assets/scripts/ui/showcase/feature_showcase.lua`
**Responsibility:**
- Fullscreen overlay UI with title, close button, summary row, tabs, and scrollable card grid.

**API:**
```
FeatureShowcase = {
  init = function(),
  show = function(),
  hide = function(),
  switchCategory = function(categoryId),
  cleanup = function()
}
```

**Layout:**
- Fullscreen root overlay (dark background panel).
- Top bar with title and [X] close.
- Summary row showing pass/total per category.
- Tab row with 5 categories.
- Scrollable content area with a responsive 2–3 card grid.

**Navigation:**
- Tab clicks and Left/Right keys to switch category.
- Mouse wheel scrolls content.
- ESC closes.

## Integration Steps

### Step 1: Add New Tab in Main Menu
- File: `assets/scripts/core/main.lua`
- Add a **Showcase** tab in `createTabDemo()` tabs list.
- In `content`, call `FeatureShowcase.show()` via a button, or embed the showcase content directly.

### Step 2: Implement Verifier
- File: `assets/scripts/ui/showcase/showcase_verifier.lua`
- Read data modules with `pcall(require, ...)`.
- Construct results for each category with item-level pass/fail.
- Provide `invalidate()` to reset cache if needed.

### Step 3: Implement Card Builders
- File: `assets/scripts/ui/showcase/showcase_cards.lua`
- Use `dsl.strict` UI to build cards with consistent sizing.
- Provide one function per category for clarity.

### Step 4: Implement Feature Showcase UI
- File: `assets/scripts/ui/showcase/feature_showcase.lua`
- Build overlay, render summary, tabs, and card grid.
- Bind ESC / close button.
- On `show()`, call verifier and render.
- On `hide()`, remove UI entities and clear references.

## Ordered Items (from design doc)
- **Gods & Classes:** pyra, frost, storm, void, warrior, mage, rogue
- **Skills:** flame_affinity, pyromaniac, frost_affinity, permafrost, storm_affinity, chain_mastery, void_affinity, void_conduit, battle_hardened, swift_casting
- **Artifacts:** ember_heart, inferno_lens, frost_core, glacial_ward, storm_core, static_field, void_heart, entropy_shard, battle_trophy, desperate_power
- **Wands:** RAGE_FIST, STORM_WALKER, FROST_ANCHOR, SOUL_SIPHON, PAIN_ECHO, EMBER_PULSE
- **Status Effects:** arcane_charge, focused, fireform, iceform, stormform, voidform

## UI Validation
- After spawning the showcase UI, call `UIValidator.validate()` and log errors/warnings.
- Ensure scroll container and cards are all in Screen space and `layers.ui`.

## Testing
- Manual:
  - Open main menu → Tab Demo → Showcase tab → Open Feature Showcase.
  - Verify summary counts, tabs, scroll, and badge icons.
  - Press ESC and [X] to close.
- Optional automation:
  - Add a small test file that calls `ShowcaseVerifier.runAll()` and asserts totals match the ordered lists.

## Acceptance Criteria
- Feature Showcase opens from Tab Demo.
- Five categories render cards with raw fields.
- Summary row shows correct pass/total per category.
- Badge status shows ✓ for valid items and ✗ for invalid/missing.
- Tabs and scrolling work; ESC closes the overlay.
- UIValidator reports no errors after spawn.
