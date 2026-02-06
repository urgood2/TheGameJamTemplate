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
- `FocusArgs.button` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:154`
- `FocusArgs.claim_focus_from` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:158`
- `FocusArgs.nav` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:160`
- `FocusArgs.no_loop` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:161`
- `FocusArgs.redirect_focus_to` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:159`
- `FocusArgs.registered` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:156`
- `FocusArgs.snap_to` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:155`
- `FocusArgs.type` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:157`
- `FocusArgs` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:140`
- `InventoryGridTileComponent.item` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:195`
- `InventoryGridTileComponent` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:188`
- `ObjectAttachedToUITag` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:19`
- `PackHandle` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui_pack_lua.cpp:69`
- `SliderComponent.color` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:178`
- `SliderComponent.decimal_places` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:183`
- `SliderComponent.h` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:185`
- `SliderComponent.max` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:181`
- `SliderComponent.min` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:180`
- `SliderComponent.text` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:179`
- `SliderComponent.value` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:182`
- `SliderComponent.w` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:184`
- `SliderComponent` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:164`
- `SpriteScaleMode.Fixed` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui_pack_lua.cpp:64`
- `SpriteScaleMode.Stretch` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui_pack_lua.cpp:62`
- `SpriteScaleMode.Tile` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui_pack_lua.cpp:63`
- `SpriteScaleMode` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui_pack_lua.cpp:60`
- `TextInput.allCaps` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:83`
- `TextInput.callback` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:84`
- `TextInput.cursorPos` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:81`
- `TextInput.maxLength` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:82`
- `TextInput.text` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:80`
- `TextInputHook.hookedEntity` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:94`
- `TextInputHook` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:87`
- `TextInput` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:69`
- `Tooltip.text` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:137`
- `Tooltip.title` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:136`
- `Tooltip` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:128`
- `UIBoxComponent.drawLayers` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:106`
- `UIBoxComponent.onBoxResize` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:107`
- `UIBoxComponent.uiRoot` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:105`
- `UIBoxComponent` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:97`
- `UIConfig.alignmentFlags` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:445`
- `UIConfig.buttonCallback` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:505`
- `UIConfig.buttonClicked` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:483`
- `UIConfig.buttonDelayEnd` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:482`
- `UIConfig.buttonDelayProgress` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:481`
- `UIConfig.buttonDelayStart` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:479`
- `UIConfig.buttonDelay` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:480`
- `UIConfig.buttonDistance` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:484`
- `UIConfig.buttonTemp` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:506`
- `UIConfig.button_UIE` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:467`
- `UIConfig.canCollide` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:464`
- `UIConfig.choice` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:493`
- `UIConfig.chosen_vert` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:496`
- `UIConfig.chosen` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:494`
- `UIConfig.collideable` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:465`
- `UIConfig.color` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:454`
- `UIConfig.computedFillSize` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:535`
- `UIConfig.dPopupConfig` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:522`
- `UIConfig.dPopup` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:520`
- `UIConfig.detailedTooltip` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:487`
- `UIConfig.disable_button` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:468`
- `UIConfig.drawLayer` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:423`
- `UIConfig.draw_after` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:497`
- `UIConfig.dynamicMotion` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:492`
- `UIConfig.emboss` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:526`
- `UIConfig.extend_up` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:524`
- `UIConfig.flexWeight` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:533`
- `UIConfig.focusArgs` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:498`
- `UIConfig.focusWithObject` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:434`
- `UIConfig.fontName` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:515`
- `UIConfig.fontSize` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:514`
- `UIConfig.forceCollision` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:466`
- `UIConfig.force_focus` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:491`
- `UIConfig.groupParent` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:425`
- `UIConfig.group` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:424`
- `UIConfig.hPopupConfig` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:521`
- `UIConfig.hPopup` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:519`
- `UIConfig.height` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:447`
- `UIConfig.hover` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:489`
- `UIConfig.id` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:420`
- `UIConfig.initFunc` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:501`
- `UIConfig.instaFunc` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:504`
- `UIConfig.instanceType` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:421`
- `UIConfig.isFiller` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:532`
- `UIConfig.language` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:516`
- `UIConfig.line_emboss` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:527`
- `UIConfig.location_bond` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:427`
- `UIConfig.makeMovementDynamic` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:457`
- `UIConfig.master` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:440`
- `UIConfig.maxFillSize` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:534`
- `UIConfig.maxHeight` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:449`
- `UIConfig.maxWidth` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:448`
- `UIConfig.mid` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:528`
- `UIConfig.minHeight` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:451`
- `UIConfig.minWidth` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:450`
- `UIConfig.nPatchInfo` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:414`
- `UIConfig.nPatchSourceTexture` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:415`
- `UIConfig.noFill` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:461`
- `UIConfig.noMovementWhenDragged` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:438`
- `UIConfig.noRole` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:529`
- `UIConfig.no_recalc` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:436`
- `UIConfig.non_recalc` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:437`
- `UIConfig.objectRecalculate` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:443`
- `UIConfig.object` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:442`
- `UIConfig.offset` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:431`
- `UIConfig.onDemandTooltip` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:488`
- `UIConfig.onUIResizeFunc` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:502`
- `UIConfig.onUIScalingResetToOne` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:503`
- `UIConfig.one_press` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:495`
- `UIConfig.outlineColor` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:455`
- `UIConfig.outlineShadow` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:459`
- `UIConfig.outlineThickness` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:456`
- `UIConfig.padding` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:452`
- `UIConfig.parent` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:441`
- `UIConfig.pixelatedRectangle` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:462`
- `UIConfig.prev_ref_value` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:512`
- `UIConfig.progressBarEmptyColor` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:472`
- `UIConfig.progressBarFetchValueLambda` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:470`
- `UIConfig.progressBarFullColor` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:473`
- `UIConfig.progressBarMaxValue` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:474`
- `UIConfig.progressBarValueComponentName` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:475`
- `UIConfig.progressBarValueFieldName` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:476`
- `UIConfig.progressBar` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:471`
- `UIConfig.ref_component` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:510`
- `UIConfig.ref_entity` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:509`
- `UIConfig.ref_value` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:511`
- `UIConfig.refreshMovement` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:435`
- `UIConfig.resolution` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:525`
- `UIConfig.role` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:530`
- `UIConfig.rotation_bond` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:428`
- `UIConfig.scale_bond` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:430`
- `UIConfig.scale` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:432`
- `UIConfig.shadowColor` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:460`
- `UIConfig.shadow` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:458`
- `UIConfig.size_bond` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:429`
- `UIConfig.spriteScaleMode` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:418`
- `UIConfig.spriteSourceRect` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:417`
- `UIConfig.spriteSourceTexture` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:416`
- `UIConfig.stylingType` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:413`
- `UIConfig.textGetter` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:507`
- `UIConfig.textSpacing` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:433`
- `UIConfig.text` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:513`
- `UIConfig.tooltip` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:486`
- `UIConfig.uiType` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:422`
- `UIConfig.ui_object_updated` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:477`
- `UIConfig.updateFunc` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:500`
- `UIConfig.verticalText` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:517`
- `UIConfig.width` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:446`
- `UIConfigBuilder` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:756`
- `UIConfigBundle.content` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:750`
- `UIConfigBundle.interaction` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:749`
- `UIConfigBundle.layout` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:748`
- `UIConfigBundle.style` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:747`
- `UIConfigBundle` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:737`
- `UIConfig` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:282`
- `UIContentConfig.fontName` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:727`
- `UIContentConfig.fontSize` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:726`
- `UIContentConfig.instanceType` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:734`
- `UIContentConfig.language` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:724`
- `UIContentConfig.objectRecalculate` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:730`
- `UIContentConfig.object` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:729`
- `UIContentConfig.progressBarMaxValue` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:732`
- `UIContentConfig.progressBar` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:731`
- `UIContentConfig.ref_entity` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:733`
- `UIContentConfig.textGetter` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:728`
- `UIContentConfig.text` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:723`
- `UIContentConfig.verticalText` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:725`
- `UIContentConfig` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:692`
- `UIDecoration.anchor` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:252`
- `UIDecoration.flipX` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:255`
- `UIDecoration.flipY` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:256`
- `UIDecoration.id` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:262`
- `UIDecoration.offset` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:253`
- `UIDecoration.opacity` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:254`
- `UIDecoration.rotation` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:257`
- `UIDecoration.scale` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:258`
- `UIDecoration.spriteName` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:251`
- `UIDecoration.tint` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:260`
- `UIDecoration.visible` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:261`
- `UIDecoration.zOffset` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:259`
- `UIDecorationAnchor.BottomCenter` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:230`
- `UIDecorationAnchor.BottomLeft` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:229`
- `UIDecorationAnchor.BottomRight` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:231`
- `UIDecorationAnchor.Center` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:227`
- `UIDecorationAnchor.MiddleLeft` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:226`
- `UIDecorationAnchor.MiddleRight` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:228`
- `UIDecorationAnchor.TopCenter` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:224`
- `UIDecorationAnchor.TopLeft` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:223`
- `UIDecorationAnchor.TopRight` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:225`
- `UIDecorationAnchor` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:221`
- `UIDecoration` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:234`
- `UIDecorations.items` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:277`
- `UIDecorations` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:265`
- `UIElementComponent.UIT` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:64`
- `UIElementComponent.config` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:66`
- `UIElementComponent.uiBox` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:65`
- `UIElementComponent` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:55`
- `UIElementCore.id` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:554`
- `UIElementCore.treeOrder` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:555`
- `UIElementCore.type` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:552`
- `UIElementCore.uiBox` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:553`
- `UIElementCore` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:542`
- `UIElementTemplateNode.children` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:988`
- `UIElementTemplateNode.config` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:987`
- `UIElementTemplateNode.type` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:986`
- `UIElementTemplateNodeBuilder` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:990`
- `UIElementTemplateNode` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:979`
- `UIInteractionConfig.buttonCallback` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:686`
- `UIInteractionConfig.buttonClicked` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:682`
- `UIInteractionConfig.canCollide` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:679`
- `UIInteractionConfig.choice` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:688`
- `UIInteractionConfig.disable_button` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:681`
- `UIInteractionConfig.dynamicMotion` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:689`
- `UIInteractionConfig.focusArgs` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:684`
- `UIInteractionConfig.force_focus` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:683`
- `UIInteractionConfig.hover` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:680`
- `UIInteractionConfig.tooltip` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:685`
- `UIInteractionConfig.updateFunc` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:687`
- `UIInteractionConfig` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:638`
- `UILayoutConfig.alignmentFlags` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:631`
- `UILayoutConfig.draw_after` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:635`
- `UILayoutConfig.height` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:625`
- `UILayoutConfig.maxHeight` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:627`
- `UILayoutConfig.maxWidth` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:626`
- `UILayoutConfig.mid` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:634`
- `UILayoutConfig.minHeight` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:629`
- `UILayoutConfig.minWidth` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:628`
- `UILayoutConfig.offset` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:632`
- `UILayoutConfig.padding` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:630`
- `UILayoutConfig.scale` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:633`
- `UILayoutConfig.width` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:624`
- `UILayoutConfig` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:594`
- `UIState.contentDimensions` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:121`
- `UIState.focus_timer` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:125`
- `UIState.last_clicked` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:123`
- `UIState.object_focus_timer` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:124`
- `UIState.textDrawable` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:122`
- `UIState` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:110`
- `UIStyleConfig.color` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:585`
- `UIStyleConfig.noFill` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:590`
- `UIStyleConfig.outlineColor` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:586`
- `UIStyleConfig.outlineThickness` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:588`
- `UIStyleConfig.pixelatedRectangle` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:591`
- `UIStyleConfig.shadowColor` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:587`
- `UIStyleConfig.shadow` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:589`
- `UIStyleConfig.stylingType` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:584`
- `UIStyleConfig` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:558`
- `UIStylingType.NinePatchBorders` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:206`
- `UIStylingType.RoundedRectangle` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:205`
- `UIStylingType.Sprite` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:207`
- `UIStylingType` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:203`
- `UITypeEnum.FILLER` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:53`
- `UITypeEnum.HORIZONTAL_CONTAINER` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:46`
- `UITypeEnum.INPUT_TEXT` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:49`
- `UITypeEnum.NONE` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:43`
- `UITypeEnum.OBJECT` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:52`
- `UITypeEnum.RECT_SHAPE` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:50`
- `UITypeEnum.ROOT` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:44`
- `UITypeEnum.SCROLL_PANE` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:47`
- `UITypeEnum.SLIDER_UI` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:48`
- `UITypeEnum.TEXT` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:51`
- `UITypeEnum.VERTICAL_CONTAINER` — (property) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:45`
- `UITypeEnum` — (enum) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:26`
- `UITypeEnum` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:41`
- `box.AddChild` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1230`
- `box.AddStateTagToUIBox` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1135`
- `box.AddTemplateToUIBox` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1176`
- `box.AssignLayerOrderComponents` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1219`
- `box.AssignStateTagsToUIBox` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1129`
- `box.AssignTreeOrderComponents` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1216`
- `box.BuildUIElementTree` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1099`
- `box.CalcTreeSizes` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1167`
- `box.ClampDimensionsToMinimumsIfPresent` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1164`
- `box.ClampDimensionsToMinimumsIfPresent` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1257`
- `box.ClearStateTagsFromUIBox` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1140`
- `box.DebugPrint` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1237`
- `box.Drag` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1226`
- `box.GetGroup` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1206`
- `box.GetUIEByID` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1186`
- `box.Initialize` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1116`
- `box.Initialize` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1117`
- `box.Move` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1223`
- `box.Recalculate` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1213`
- `box.RemoveGroup` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1203`
- `box.Remove` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1209`
- `box.RenewAlignment` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1173`
- `box.ReplaceChildren` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1243`
- `box.SetContainer` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1233`
- `box.SubCalculateContainerSize` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1182`
- `box.TraverseUITreeBottomUp` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1240`
- `box.TreeCalcSubContainer` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1179`
- `box.TreeCalcSubNonContainer` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1170`
- `box.buildUIBoxDrawList` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1253`
- `box.drawAllBoxes` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1250`
- `box.handleAlignment` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1096`
- `box.placeNonContainerUIE` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1160`
- `box.placeUIElementsRecursively` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1157`
- `box.set_draw_layer` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1102`
- `element.ApplyAlignment` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1049`
- `element.ApplyHover` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1061`
- `element.ApplyScalingToSubtree` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1040`
- `element.BuildUIDrawList` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1063`
- `element.CanBeDragged` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1047`
- `element.Click` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1059`
- `element.CollidesWithPoint` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1056`
- `element.DebugPrintTree` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1044`
- `element.DrawSelf` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1053`
- `element.InitializeVisualTransform` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1045`
- `element.Initialize` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1038`
- `element.JuiceUp` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1046`
- `element.PutFocusedCursor` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1057`
- `element.Release` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1060`
- `element.Remove` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1058`
- `element.SetAlignments` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1050`
- `element.SetValues` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1043`
- `element.SetWH` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1048`
- `element.StopHover` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1062`
- `element.UpdateObject` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1052`
- `element.UpdateText` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1051`
- `element.UpdateUIObjectScalingAndRecenter` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1041`
- `element.Update` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1055`
- `ui.box` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1093`
- `ui.element` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1035`
- `ui.register_pack` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui_pack_lua.cpp:330`
- `ui.use_pack` — (function) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui_pack_lua.cpp:343`
- `ui` — (usertype) — `/Users/joshuashin/Projects/TheGameJamTemplate/src/systems/ui/ui.cpp:1034`
<!-- AUTOGEN:END binding_list -->
