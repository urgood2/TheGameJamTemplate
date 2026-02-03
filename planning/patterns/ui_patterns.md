# UI Patterns (Working Code)

Scope: UI/UIBox + inventory UI patterns verified in working Lua code.
Each pattern includes a doc_id, source_ref(s), and verification status.

## pattern:ui.uibox_alignment.renew_after_offset
- Name: RenewAlignment after ChildBuilder offset changes
- Description: When updating ChildBuilder offsets for a UIBox container, call `ui.box.RenewAlignment` so children recompute their layout.
- Source refs:
  - assets/scripts/ui/wand_panel.lua:positionTabs (ChildBuilder.setOffset + ui.box.RenewAlignment)
- Recommended: Yes
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.uibox_alignment.renew_after_offset

## pattern:ui.uibox_alignment.renew_after_replacechildren
- Name: RenewAlignment after ReplaceChildren
- Description: After `ui.box.ReplaceChildren`, call `ui.box.RenewAlignment` on the parent UIBox to recompute layout for injected children.
- Source refs:
  - assets/scripts/ui/player_inventory.lua:injectGridForTab (ReplaceChildren + RenewAlignment)
- Recommended: Yes
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.uibox_alignment.renew_after_replacechildren

## pattern:ui.statetag.add_after_spawn
- Name: AddStateTag after UIBox spawn
- Description: Newly spawned UI boxes need state tags (typically `default_state`) to render; add tags immediately after spawn.
- Source refs:
  - assets/scripts/ui/skills_panel.lua:initPanel (AddStateTagToUIBox after dsl.spawn)
- Recommended: Yes
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.statetag.add_after_spawn

## pattern:ui.statetag.add_after_replacechildren
- Name: Reapply state tags after ReplaceChildren
- Description: `ui.box.ReplaceChildren` clears tags; re-add required state tags so the UI remains visible.
- Source refs:
  - assets/scripts/ui/player_inventory.lua:injectGridForTab (AddStateTagToUIBox after ReplaceChildren)
- Recommended: Yes
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.statetag.add_after_replacechildren

## pattern:ui.statetag.persistence_check
- Name: Clear/reapply tags when state changes
- Description: Clear state tags before applying new state tags to avoid stale visibility combinations.
- Source refs:
  - assets/scripts/ui/stats_panel_v2.lua:_createPanel (ClearStateTagsFromUIBox + AddStateTagToUIBox)
- Recommended: Yes
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.statetag.persistence_check

## pattern:ui.visibility.move_transform_and_uiroot
- Name: Move Transform and UIBoxComponent.uiRoot together
- Description: When hiding/showing UIBoxes, update Transform and UIBoxComponent.uiRoot positions, then RenewAlignment.
- Source refs:
  - assets/scripts/ui/stats_panel_v2.lua:setEntityVisible (updates Transform + uiRoot)
- Recommended: Yes
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.visibility.move_transform_and_uiroot

## pattern:ui.visibility.transform_only_fails
- Name: Avoid moving only Transform (anti-pattern)
- Description: Moving only the UIBox Transform leaves uiRoot and inherited offsets stale, causing misaligned UI.
- Source refs:
  - assets/scripts/ui/stats_panel_v2.lua:setEntityVisible (commented rationale + full fix)
- Recommended: No (Anti-pattern)
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.visibility.transform_only_fails

## pattern:ui.collision.screenspace_marker_required
- Name: ScreenSpaceCollisionMarker for screen-space UI
- Description: Screen-space UI elements should have ScreenSpaceCollisionMarker for correct hit testing.
- Source refs:
  - assets/scripts/ui/trigger_strip_ui.lua:createEntry (transform.set_space + ScreenSpaceCollisionMarker)
- Recommended: Yes
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.collision.screenspace_marker_required

## pattern:ui.collision.click_detection_with_marker
- Name: Add ScreenSpaceCollisionMarker for clickable UI
- Description: Clickable UI entities should explicitly add ScreenSpaceCollisionMarker to enable click detection.
- Source refs:
  - assets/scripts/ui/stats_panel_v2.lua:_createTabMarker (ScreenSpaceCollisionMarker for click detection)
- Recommended: Yes
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.collision.click_detection_with_marker

## pattern:ui.collision.click_fails_without_marker
- Name: Missing ScreenSpaceCollisionMarker breaks clicks (anti-pattern)
- Description: Without ScreenSpaceCollisionMarker, clicks can silently fail even if the UI entity is visible.
- Source refs:
  - assets/scripts/ui/trigger_strip_ui.lua:createEntry (commented requirement for marker)
- Recommended: No (Anti-pattern)
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.collision.click_fails_without_marker

## pattern:ui.grid.cleanup_all_three_registries
- Name: Clean up grid registry, items, and DSL entry
- Description: Grid cleanup must clear item registry, run `grid.cleanup`, and `dsl.cleanupGrid` to avoid leaks.
- Source refs:
  - assets/scripts/ui/player_inventory.lua:cleanupGridEntity (itemRegistry.clearGrid + grid.cleanup + dsl.cleanupGrid)
- Recommended: Yes
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.grid.cleanup_all_three_registries

## pattern:ui.grid.cleanup_partial_fails
- Name: Partial grid cleanup fails (anti-pattern)
- Description: Cleaning only one registry leaves dangling UI state and item references.
- Source refs:
  - assets/scripts/ui/player_inventory.lua:cleanupGridEntity (full cleanup illustrates required steps)
- Recommended: No (Anti-pattern)
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.grid.cleanup_partial_fails

## pattern:ui.drawspace.world_follows_camera
- Name: World-space cards follow camera
- Description: Use `transform.set_space(entity, "world")` for board cards that should track camera and world collision.
- Source refs:
  - assets/scripts/ui/card_space_converter.lua:toWorldSpace
- Recommended: Yes
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.drawspace.world_follows_camera

## pattern:ui.drawspace.screen_fixed_hud
- Name: Screen-space UI stays fixed to HUD
- Description: Use `transform.set_space(entity, "screen")` for HUD elements and inventory cards.
- Source refs:
  - assets/scripts/ui/card_space_converter.lua:toScreenSpace
- Recommended: Yes
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.drawspace.screen_fixed_hud

## pattern:ui.attached.never_on_draggables
- Name: Avoid ObjectAttachedToUITag on draggables
- Description: ObjectAttachedToUITag removes entities from the shader pipeline; do not apply to draggable UI elements.
- Source refs:
  - assets/scripts/ui/trigger_strip_ui.lua:createEntry (comment warning)
  - assets/scripts/ui/player_inventory.lua:addItemToGrid (comment warning)
- Recommended: No (Anti-pattern)
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.attached.never_on_draggables

## pattern:ui.attached.correct_usage
- Name: ObjectAttachedToUITag for static UI-only icons
- Description: Apply ObjectAttachedToUITag for icons rendered exclusively in the UI pass (non-draggable).
- Source refs:
  - assets/scripts/ui/message_queue_ui.lua:tryMakeIcon (emplace ObjectAttachedToUITag)
- Recommended: Yes
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.attached.correct_usage

## Doc Divergences
- None observed during UI pattern mining.
