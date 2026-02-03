# UI Bindings

## Scope
Bindings for UI layout, UIBox construction, state tags, and UI element placement.

## Source Files
- `src/systems/ui/ui.cpp`
- `src/systems/ui/ui_pack_lua.cpp`

## Binding Patterns (C++)
- `ui` table holds submodules like `ui.box` and `ui.element`.
- UIBox creation via `ui.box.Initialize({x, y}, root_definition)`.
- UI packing via `ui.register_pack` + `ui.use_pack`.

## Frequency Scan
Commands used:
- `rg -n --glob 'assets/scripts/**/*.lua' 'ui\\.box\\.RenewAlignment'`
- `rg -n --glob 'assets/scripts/**/*.lua' 'ui\\.box\\.AddStateTagToUIBox'`
- `rg -n --glob 'assets/scripts/**/*.lua' 'ui\\.box\\.set_draw_layer'`

Counts:
- `ui.box.RenewAlignment`: 71
- `ui.box.AddStateTagToUIBox`: 93
- `ui.box.set_draw_layer`: 76

## Gotchas
- **RenewAlignment after structural changes**: Call `ui.box.RenewAlignment(registry, uiBox)` after offset/transform edits or after `ui.box.ReplaceChildren` to rebuild layout. Example:
  ```lua
  ui.box.ReplaceChildren(uiBox, newRoot)
  ui.box.RenewAlignment(registry, uiBox)
  ```
- **State tags after rebuild**: `ui.box.AddStateTagToUIBox` should be reapplied after `ReplaceChildren` since tag propagation can be lost during tree rebuild.
- **Draw layer assignment**: Call `ui.box.set_draw_layer(uiBox, "ui")` after initialization to ensure draw ordering is correct.
- **Screen-space interactions**: UI click detection typically requires `ScreenSpaceCollisionMarker` on relevant UI elements (not auto-added).
- **Draw command space**: Screen space UI draws should use `layer.DrawCommandSpace.Screen` to avoid camera transforms.

## Detail Tiers
- **Tier 0**: Extracted binding list only (see AUTOGEN list below).
- **Tier 1**: Semantics + minimal example (high-frequency bindings).
- **Tier 2**: Verified test id + evidence (not assigned here; see Phase 7).

## High-Frequency Bindings (Tier 1)
- `ui.box.Initialize` — Detail Tier: 1. Creates a UI box from a template node and transform table. Minimal usage:
  ```lua
  local root = ui.definitions.def({
      type = "ROOT",
      config = { id = "root" },
      children = { { type = "TEXT", config = { id = "label", text = "Hi" } } }
  })
  local box = ui.box.Initialize({ x = 0, y = 0 }, root)
  ```
  - Gotchas: Set draw layer after initialization, and re-run `ui.box.RenewAlignment` after changes to offsets or children.
- `ui.box.RenewAlignment` — Detail Tier: 1. Required after offset changes or replacing children.
  - Gotchas: Call after `ChildBuilder.setOffset` and after `ui.box.ReplaceChildren`.
- `ui.box.AddStateTagToUIBox` — Detail Tier: 1. Re-apply after `ReplaceChildren` to ensure tags persist.
  - Gotchas: State tags can be lost during tree rebuilds.
- `ui.box.set_draw_layer` — Detail Tier: 1. Must target a valid layer name (e.g. `"ui"`).
  - Gotchas: If missing, UI may render behind gameplay layers.
- `ui.box.ReplaceChildren` — Detail Tier: 1. Rebuilds UI subtree.
  - Gotchas: Must call `ui.box.RenewAlignment` and reapply state tags after replacement.
- `ui.box.GetUIEByID` — Detail Tier: 1. Returns `Entity|nil` for a UI element by id.
  - Gotchas: Returns nil when id is missing or the tree is stale.
- `ChildBuilder.setOffset` — Detail Tier: 1. Lua helper for adjusting child offsets.
  - Gotchas: Call `ui.box.RenewAlignment` after offset changes to reflow layout.

## Doc Divergences
- `ui.box.SetVisible` appears in planning notes but is not bound in `src/systems/ui/ui.cpp`.

## Related UI Helpers
- `ChildBuilder.setOffset` (Lua helper) changes offsets; call `ui.box.RenewAlignment` after this to reflow layout.

## Extractor Normalization
- Converted extractor prefixes:
  - `box.*` → `ui.box.*`
  - `element.*` → `ui.element.*`

## Tests
- `ui.box.initialize.basic` → `sol2_function_box_initialize`
- `ui.box.renew_alignment.basic` → `sol2_function_box_renewalignment`
- `ui.box.add_state_tag.basic` → `sol2_function_box_addstatetagtouibox`
- `ui.box.set_draw_layer.basic` → `sol2_function_box_set_draw_layer`
- `ui.box.get_uie_by_id.basic` → `sol2_function_box_getuiebyid`
- `ui.box.replace_children.basic` → `sol2_function_box_replacechildren`
- `ui.child_builder.set_offset.basic` → `binding:ChildBuilder.setOffset`
- `ui.screen_space_collision_marker.toggle` → `component:ScreenSpaceCollisionMarker`
- `ui.draw_command_space.enum` → `binding:layer.DrawCommandSpace.Screen`
- `ui.draw_command_space.enum` → `binding:layer.DrawCommandSpace.World`

<!-- AUTOGEN:BEGIN binding_list -->
- `FocusArgs.button` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:154`
- `FocusArgs.claim_focus_from` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:158`
- `FocusArgs.nav` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:160`
- `FocusArgs.no_loop` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:161`
- `FocusArgs.redirect_focus_to` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:159`
- `FocusArgs.registered` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:156`
- `FocusArgs.snap_to` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:155`
- `FocusArgs.type` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:157`
- `FocusArgs` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:140`
- `InventoryGridTileComponent.item` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:195`
- `InventoryGridTileComponent` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:188`
- `ObjectAttachedToUITag` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:19`
- `PackHandle` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui_pack_lua.cpp:69`
- `SliderComponent.color` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:178`
- `SliderComponent.decimal_places` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:183`
- `SliderComponent.h` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:185`
- `SliderComponent.max` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:181`
- `SliderComponent.min` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:180`
- `SliderComponent.text` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:179`
- `SliderComponent.value` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:182`
- `SliderComponent.w` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:184`
- `SliderComponent` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:164`
- `SpriteScaleMode.Fixed` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui_pack_lua.cpp:64`
- `SpriteScaleMode.Stretch` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui_pack_lua.cpp:62`
- `SpriteScaleMode.Tile` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui_pack_lua.cpp:63`
- `SpriteScaleMode` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui_pack_lua.cpp:60`
- `TextInput.allCaps` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:83`
- `TextInput.callback` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:84`
- `TextInput.cursorPos` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:81`
- `TextInput.maxLength` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:82`
- `TextInput.text` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:80`
- `TextInputHook.hookedEntity` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:94`
- `TextInputHook` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:87`
- `TextInput` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:69`
- `Tooltip.text` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:137`
- `Tooltip.title` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:136`
- `Tooltip` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:128`
- `UIBoxComponent.drawLayers` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:106`
- `UIBoxComponent.onBoxResize` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:107`
- `UIBoxComponent.uiRoot` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:105`
- `UIBoxComponent` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:97`
- `UIConfig.alignmentFlags` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:445`
- `UIConfig.buttonCallback` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:505`
- `UIConfig.buttonClicked` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:483`
- `UIConfig.buttonDelayEnd` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:482`
- `UIConfig.buttonDelayProgress` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:481`
- `UIConfig.buttonDelayStart` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:479`
- `UIConfig.buttonDelay` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:480`
- `UIConfig.buttonDistance` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:484`
- `UIConfig.buttonTemp` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:506`
- `UIConfig.button_UIE` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:467`
- `UIConfig.canCollide` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:464`
- `UIConfig.choice` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:493`
- `UIConfig.chosen_vert` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:496`
- `UIConfig.chosen` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:494`
- `UIConfig.collideable` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:465`
- `UIConfig.color` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:454`
- `UIConfig.computedFillSize` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:535`
- `UIConfig.dPopupConfig` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:522`
- `UIConfig.dPopup` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:520`
- `UIConfig.detailedTooltip` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:487`
- `UIConfig.disable_button` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:468`
- `UIConfig.drawLayer` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:423`
- `UIConfig.draw_after` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:497`
- `UIConfig.dynamicMotion` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:492`
- `UIConfig.emboss` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:526`
- `UIConfig.extend_up` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:524`
- `UIConfig.flexWeight` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:533`
- `UIConfig.focusArgs` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:498`
- `UIConfig.focusWithObject` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:434`
- `UIConfig.fontName` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:515`
- `UIConfig.fontSize` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:514`
- `UIConfig.forceCollision` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:466`
- `UIConfig.force_focus` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:491`
- `UIConfig.groupParent` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:425`
- `UIConfig.group` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:424`
- `UIConfig.hPopupConfig` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:521`
- `UIConfig.hPopup` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:519`
- `UIConfig.height` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:447`
- `UIConfig.hover` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:489`
- `UIConfig.id` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:420`
- `UIConfig.initFunc` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:501`
- `UIConfig.instaFunc` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:504`
- `UIConfig.instanceType` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:421`
- `UIConfig.isFiller` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:532`
- `UIConfig.language` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:516`
- `UIConfig.line_emboss` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:527`
- `UIConfig.location_bond` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:427`
- `UIConfig.makeMovementDynamic` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:457`
- `UIConfig.master` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:440`
- `UIConfig.maxFillSize` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:534`
- `UIConfig.maxHeight` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:449`
- `UIConfig.maxWidth` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:448`
- `UIConfig.mid` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:528`
- `UIConfig.minHeight` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:451`
- `UIConfig.minWidth` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:450`
- `UIConfig.nPatchInfo` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:414`
- `UIConfig.nPatchSourceTexture` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:415`
- `UIConfig.noFill` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:461`
- `UIConfig.noMovementWhenDragged` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:438`
- `UIConfig.noRole` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:529`
- `UIConfig.no_recalc` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:436`
- `UIConfig.non_recalc` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:437`
- `UIConfig.objectRecalculate` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:443`
- `UIConfig.object` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:442`
- `UIConfig.offset` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:431`
- `UIConfig.onDemandTooltip` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:488`
- `UIConfig.onUIResizeFunc` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:502`
- `UIConfig.onUIScalingResetToOne` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:503`
- `UIConfig.one_press` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:495`
- `UIConfig.outlineColor` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:455`
- `UIConfig.outlineShadow` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:459`
- `UIConfig.outlineThickness` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:456`
- `UIConfig.padding` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:452`
- `UIConfig.parent` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:441`
- `UIConfig.pixelatedRectangle` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:462`
- `UIConfig.prev_ref_value` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:512`
- `UIConfig.progressBarEmptyColor` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:472`
- `UIConfig.progressBarFetchValueLambda` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:470`
- `UIConfig.progressBarFullColor` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:473`
- `UIConfig.progressBarMaxValue` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:474`
- `UIConfig.progressBarValueComponentName` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:475`
- `UIConfig.progressBarValueFieldName` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:476`
- `UIConfig.progressBar` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:471`
- `UIConfig.ref_component` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:510`
- `UIConfig.ref_entity` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:509`
- `UIConfig.ref_value` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:511`
- `UIConfig.refreshMovement` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:435`
- `UIConfig.resolution` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:525`
- `UIConfig.role` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:530`
- `UIConfig.rotation_bond` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:428`
- `UIConfig.scale_bond` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:430`
- `UIConfig.scale` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:432`
- `UIConfig.shadowColor` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:460`
- `UIConfig.shadow` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:458`
- `UIConfig.size_bond` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:429`
- `UIConfig.spriteScaleMode` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:418`
- `UIConfig.spriteSourceRect` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:417`
- `UIConfig.spriteSourceTexture` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:416`
- `UIConfig.stylingType` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:413`
- `UIConfig.textGetter` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:507`
- `UIConfig.textSpacing` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:433`
- `UIConfig.text` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:513`
- `UIConfig.tooltip` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:486`
- `UIConfig.uiType` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:422`
- `UIConfig.ui_object_updated` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:477`
- `UIConfig.updateFunc` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:500`
- `UIConfig.verticalText` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:517`
- `UIConfig.width` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:446`
- `UIConfigBuilder` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:756`
- `UIConfigBundle.content` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:750`
- `UIConfigBundle.interaction` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:749`
- `UIConfigBundle.layout` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:748`
- `UIConfigBundle.style` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:747`
- `UIConfigBundle` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:737`
- `UIConfig` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:282`
- `UIContentConfig.fontName` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:727`
- `UIContentConfig.fontSize` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:726`
- `UIContentConfig.instanceType` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:734`
- `UIContentConfig.language` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:724`
- `UIContentConfig.objectRecalculate` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:730`
- `UIContentConfig.object` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:729`
- `UIContentConfig.progressBarMaxValue` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:732`
- `UIContentConfig.progressBar` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:731`
- `UIContentConfig.ref_entity` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:733`
- `UIContentConfig.textGetter` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:728`
- `UIContentConfig.text` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:723`
- `UIContentConfig.verticalText` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:725`
- `UIContentConfig` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:692`
- `UIDecoration.anchor` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:252`
- `UIDecoration.flipX` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:255`
- `UIDecoration.flipY` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:256`
- `UIDecoration.id` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:262`
- `UIDecoration.offset` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:253`
- `UIDecoration.opacity` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:254`
- `UIDecoration.rotation` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:257`
- `UIDecoration.scale` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:258`
- `UIDecoration.spriteName` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:251`
- `UIDecoration.tint` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:260`
- `UIDecoration.visible` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:261`
- `UIDecoration.zOffset` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:259`
- `UIDecorationAnchor.BottomCenter` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:230`
- `UIDecorationAnchor.BottomLeft` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:229`
- `UIDecorationAnchor.BottomRight` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:231`
- `UIDecorationAnchor.Center` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:227`
- `UIDecorationAnchor.MiddleLeft` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:226`
- `UIDecorationAnchor.MiddleRight` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:228`
- `UIDecorationAnchor.TopCenter` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:224`
- `UIDecorationAnchor.TopLeft` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:223`
- `UIDecorationAnchor.TopRight` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:225`
- `UIDecorationAnchor` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:221`
- `UIDecoration` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:234`
- `UIDecorations.items` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:277`
- `UIDecorations` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:265`
- `UIElementComponent.UIT` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:64`
- `UIElementComponent.config` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:66`
- `UIElementComponent.uiBox` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:65`
- `UIElementComponent` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:55`
- `UIElementCore.id` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:554`
- `UIElementCore.treeOrder` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:555`
- `UIElementCore.type` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:552`
- `UIElementCore.uiBox` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:553`
- `UIElementCore` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:542`
- `UIElementTemplateNode.children` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:988`
- `UIElementTemplateNode.config` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:987`
- `UIElementTemplateNode.type` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:986`
- `UIElementTemplateNodeBuilder` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:990`
- `UIElementTemplateNode` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:979`
- `UIInteractionConfig.buttonCallback` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:686`
- `UIInteractionConfig.buttonClicked` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:682`
- `UIInteractionConfig.canCollide` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:679`
- `UIInteractionConfig.choice` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:688`
- `UIInteractionConfig.disable_button` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:681`
- `UIInteractionConfig.dynamicMotion` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:689`
- `UIInteractionConfig.focusArgs` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:684`
- `UIInteractionConfig.force_focus` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:683`
- `UIInteractionConfig.hover` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:680`
- `UIInteractionConfig.tooltip` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:685`
- `UIInteractionConfig.updateFunc` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:687`
- `UIInteractionConfig` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:638`
- `UILayoutConfig.alignmentFlags` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:631`
- `UILayoutConfig.draw_after` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:635`
- `UILayoutConfig.height` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:625`
- `UILayoutConfig.maxHeight` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:627`
- `UILayoutConfig.maxWidth` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:626`
- `UILayoutConfig.mid` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:634`
- `UILayoutConfig.minHeight` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:629`
- `UILayoutConfig.minWidth` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:628`
- `UILayoutConfig.offset` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:632`
- `UILayoutConfig.padding` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:630`
- `UILayoutConfig.scale` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:633`
- `UILayoutConfig.width` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:624`
- `UILayoutConfig` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:594`
- `UIState.contentDimensions` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:121`
- `UIState.focus_timer` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:125`
- `UIState.last_clicked` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:123`
- `UIState.object_focus_timer` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:124`
- `UIState.textDrawable` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:122`
- `UIState` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:110`
- `UIStyleConfig.color` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:585`
- `UIStyleConfig.noFill` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:590`
- `UIStyleConfig.outlineColor` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:586`
- `UIStyleConfig.outlineThickness` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:588`
- `UIStyleConfig.pixelatedRectangle` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:591`
- `UIStyleConfig.shadowColor` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:587`
- `UIStyleConfig.shadow` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:589`
- `UIStyleConfig.stylingType` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:584`
- `UIStyleConfig` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:558`
- `UIStylingType.NinePatchBorders` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:206`
- `UIStylingType.RoundedRectangle` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:205`
- `UIStylingType.Sprite` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:207`
- `UIStylingType` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:203`
- `UITypeEnum.FILLER` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:53`
- `UITypeEnum.HORIZONTAL_CONTAINER` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:46`
- `UITypeEnum.INPUT_TEXT` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:49`
- `UITypeEnum.NONE` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:43`
- `UITypeEnum.OBJECT` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:52`
- `UITypeEnum.RECT_SHAPE` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:50`
- `UITypeEnum.ROOT` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:44`
- `UITypeEnum.SCROLL_PANE` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:47`
- `UITypeEnum.SLIDER_UI` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:48`
- `UITypeEnum.TEXT` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:51`
- `UITypeEnum.VERTICAL_CONTAINER` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:45`
- `UITypeEnum` — (enum) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:26`
- `UITypeEnum` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:41`
- `ui.box.AddChild` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1230`
- `ui.box.AddStateTagToUIBox` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1135`
- `ui.box.AddTemplateToUIBox` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1176`
- `ui.box.AssignLayerOrderComponents` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1219`
- `ui.box.AssignStateTagsToUIBox` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1129`
- `ui.box.AssignTreeOrderComponents` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1216`
- `ui.box.BuildUIElementTree` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1099`
- `ui.box.CalcTreeSizes` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1167`
- `ui.box.ClampDimensionsToMinimumsIfPresent` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1164`
- `ui.box.ClampDimensionsToMinimumsIfPresent` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1257`
- `ui.box.ClearStateTagsFromUIBox` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1140`
- `ui.box.DebugPrint` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1237`
- `ui.box.Drag` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1226`
- `ui.box.GetGroup` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1206`
- `ui.box.GetUIEByID` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1186`
- `ui.box.Initialize` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1116`
- `ui.box.Initialize` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1117`
- `ui.box.Move` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1223`
- `ui.box.Recalculate` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1213`
- `ui.box.RemoveGroup` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1203`
- `ui.box.Remove` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1209`
- `ui.box.RenewAlignment` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1173`
- `ui.box.ReplaceChildren` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1243`
- `ui.box.SetContainer` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1233`
- `ui.box.SubCalculateContainerSize` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1182`
- `ui.box.TraverseUITreeBottomUp` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1240`
- `ui.box.TreeCalcSubContainer` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1179`
- `ui.box.TreeCalcSubNonContainer` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1170`
- `ui.box.buildUIBoxDrawList` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1253`
- `ui.box.drawAllBoxes` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1250`
- `ui.box.handleAlignment` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1096`
- `ui.box.placeNonContainerUIE` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1160`
- `ui.box.placeUIElementsRecursively` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1157`
- `ui.box.set_draw_layer` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1102`
- `ui.box` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1093`
- `ui.element.ApplyAlignment` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1049`
- `ui.element.ApplyHover` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1061`
- `ui.element.ApplyScalingToSubtree` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1040`
- `ui.element.BuildUIDrawList` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1063`
- `ui.element.CanBeDragged` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1047`
- `ui.element.Click` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1059`
- `ui.element.CollidesWithPoint` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1056`
- `ui.element.DebugPrintTree` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1044`
- `ui.element.DrawSelf` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1053`
- `ui.element.InitializeVisualTransform` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1045`
- `ui.element.Initialize` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1038`
- `ui.element.JuiceUp` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1046`
- `ui.element.PutFocusedCursor` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1057`
- `ui.element.Release` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1060`
- `ui.element.Remove` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1058`
- `ui.element.SetAlignments` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1050`
- `ui.element.SetValues` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1043`
- `ui.element.SetWH` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1048`
- `ui.element.StopHover` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1062`
- `ui.element.UpdateObject` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1052`
- `ui.element.UpdateText` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1051`
- `ui.element.UpdateUIObjectScalingAndRecenter` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1041`
- `ui.element.Update` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1055`
- `ui.element` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1035`
- `ui.register_pack` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui_pack_lua.cpp:330`
- `ui.use_pack` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui_pack_lua.cpp:343`
- `ui` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ui/ui.cpp:1034`
<!-- AUTOGEN:END binding_list -->
