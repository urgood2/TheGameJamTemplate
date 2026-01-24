# Implementation Plan: Lua UI Usability Improvements

This plan covers the following improvements:
- Tooltip V2 refresh and layout (data changes, tag wrapping, zero-value stats).
- Inventory UX (search, sort indicators, keybind hints).
- Quick-equip success feedback (non-spammy).
- Death screen UI and input support.

## 1) Audit existing UI and input primitives

Goal: reuse existing systems before adding new widgets or helpers.

- Review UI DSL and helpers for input and text measurement:
  - `assets/scripts/ui/ui_syntax_sugar.lua`
  - `assets/scripts/ui/ui_definition_helper.lua`
  - `assets/scripts/ui/message_queue_ui.lua`
  - `assets/scripts/core/popup.lua` (if present)
- Review inventory grid API and visibility helpers:
  - `assets/scripts/core/inventory_grid.lua`
  - `assets/scripts/ui/inventory_grid_init.lua`
  - `assets/scripts/ui/player_inventory.lua` (visibility helpers already present)
- Review input system bindings for confirm/cancel:
  - `assets/scripts/core/gameplay.lua` (action bindings)
  - `assets/scripts/core/modal.lua` (usage of `input.action_pressed`)
- Check z-order conventions in:
  - `assets/scripts/core/z_orders.lua`

Deliverable: list of available helpers (text width, input widgets, toast/popup APIs, action names).

## 2) Tooltip V2 refresh and layout

Files: `assets/scripts/ui/tooltip_v2.lua`

### 2.1 Refresh on data change
- Add `State.activeKeys` (map anchorEntity -> cacheKey).
- In `TooltipV2.show`:
  - Compute `cacheKey` early.
  - If `State.active[anchorEntity]` exists and key matches, only reposition.
  - If key differs:
    - Clear state tags on existing boxes.
    - Move existing boxes offscreen (or destroy if desired).
    - Remove from `State.active` and `State.activeKeys`.
    - Proceed to reuse or rebuild based on new cacheKey.
- Update `TooltipV2.hide` to clear `State.activeKeys[anchorEntity]`.
- Keep cache reuse intact (do not invalidate `State.cache` unless needed).

### 2.2 Show zero-value stats
- In `buildInfoBox`, allow `0` values:
  - Replace `stat.value and stat.value ~= 0 and stat.value ~= -1` with
    `stat.value ~= nil and stat.value ~= -1`.
- In `TooltipV2.showCard.addStat`, allow `0`:
  - Replace `value and value ~= 0 and value ~= -1` with
    `value ~= nil and value ~= -1 and value ~= "N/A"`.

### 2.3 Tag wrapping in info box
- Determine text width API:
  - Check for a text measurement helper in `ui.definitions` or `Text` builder.
- Implement row wrapping:
  - Compute available width:
    `maxRowWidth = Style.BOX_WIDTH - (Style.infoPadding * 2)`.
  - Build rows by accumulating pill widths + gap.
  - If no exact measurement, approximate width:
    `approx = (#tag * Style.tagFontSize * 0.6) + padding`.
  - Use `dsl.vbox` of `dsl.hbox` rows.
- Add overflow handling:
  - Cap rows (example: 2 rows).
  - If overflow, replace remaining tags with a `+N` pill.

## 3) Inventory UX: search, sort indicators, keybind hints

Files: `assets/scripts/ui/player_inventory.lua`

### 3.1 Search input
- If a text input widget exists in the DSL:
  - Add a search row in header or footer.
  - Bind change handler to `state.searchFilter`.
- If no widget:
  - Implement a minimal "search mode":
    - Clicking "Search" toggles capture.
    - Accumulate alphanumerics and space; backspace deletes.
    - Enter confirms; Esc exits.
  - Render the current filter text in the UI.

### 3.2 Filtering logic
- Add `matchesFilter(cardData, filter)`:
  - Compare lower-case filter against:
    - `cardData.name`, `cardData.cardID`, `cardData.tags`, `cardData.type`.
- Apply filter by visibility:
  - Iterate `grid.getAllItems(state.activeGrid)`.
  - Call `setCardEntityVisible(itemEntity, matches)`.
  - Keep hidden items in their slots (do not remove from grid).

### 3.3 Sorting UX
- Track sort button entities (via IDs `sort_name_btn`, `sort_cost_btn`).
- Add `updateSortIndicators()`:
  - Active button shows direction (A-Z or Z-A).
  - Inactive button uses neutral color/label.
- Ensure indicators update on:
  - `toggleSort`
  - `switchTab`
  - Inventory open/show
- Decide sort behavior with filter:
  - Option A: sort all items regardless of filter.
  - Option B: sort only visible items while preserving hidden positions.
  - Choose one and document it in code.

### 3.4 Keybind and hint text
- Add compact hints to header/footer:
  - "I: Inventory, Esc: Close, Right click: Quick equip"
- Optional: if gamepad is connected, append a short controller hint.

## 4) Quick-equip success feedback

File: `assets/scripts/ui/inventory_quick_equip.lua`

- Add cooldown tracking (`state.lastSuccessTime` or frame).
- On successful equip:
  - If cooldown passed, show a short success toast.
  - Preferred: `MessageQueueUI.enqueue("Equipped")`.
  - Fallback: `popup.above(cardEntity, "Equipped")`.
- Keep failure feedback as-is (sound + popup).
- Avoid spamming when equipping multiple cards rapidly.

## 5) Death screen UI and input

File: `assets/scripts/ui/death_screen.lua`

### 5.1 Replace text-only with real UI
- Use DSL to build:
  - Full-screen dark overlay.
  - Center panel with title and "Try Again" button.
- Store entity IDs for cleanup.
- Ensure proper z-order (use `z_orders` or a high explicit z).
- Add state tags for UI visibility.

### 5.2 Input handling
- Button click via UI callback.
- Keyboard support:
  - `KEY_ENTER`, `KEY_KP_ENTER`, `KEY_SPACE`.
- Gamepad support:
  - Prefer `input.action_pressed` if a confirm action exists.
  - Otherwise check for `GamepadButton.GAMEPAD_BUTTON_RIGHT_FACE_DOWN`.
- Keep `DeathScreen.hide` to destroy UI elements and clear state.

## 6) Verification checklist

- Tooltip refresh: same anchor, new data updates live.
- Tooltip tag wrap: long tag list wraps and does not overflow.
- Tooltip stats: zero values display when meaningful.
- Inventory search: filter hides cards correctly, clears on empty input.
- Inventory sort: indicator matches active field and direction.
- Quick-equip: success toast appears with cooldown; failure feedback unchanged.
- Death screen: button, Enter/Space, and gamepad confirm all restart; repeated show/hide has no leaks.
