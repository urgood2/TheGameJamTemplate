# Engine Quirks & Gotchas

This document consolidates all known quirks, gotchas, and ordering requirements discovered in the engine codebase. Each entry follows a standard template for traceability and includes test references where available.

## Table of Contents

<!-- TOC: Keep stable anchors - cm rules reference these -->
- [Entry Template](#entry-template)
- [Entity Lifecycle](#entity-lifecycle)
  - [Script Initialization Order](#ecs-init-order)
  - [attach_ecs Timing](#ecs-attach-ecs-timing)
  - [GameObject Component Restrictions](#ecs-gameobject-restrictions)
  - [script_field and safe_script_get](#ecs-script-access)
  - [Entity Validation](#ecs-validation)
  - [Component Cache Usage](#ecs-component-cache)
  - [Entity Destruction & Cleanup](#ecs-destruction)
  - [LuaJIT 200 Local Variable Limit](#ecs-luajit-locals)
- [UI / UIBox System](#ui--uibox-system)
  - [UIBox Creation and Configuration](#uibox-creation-and-configuration)
  - [UIBox Alignment and RenewAlignment](#uibox-alignment-and-renewalignment)
  - [State Tags and UIBox State Management](#state-tags-and-uibox-state-management)
  - [Panel Visibility and uiRoot Coordination](#panel-visibility-and-uiroot-coordination)
  - [Grid Management and Cleanup](#grid-management-and-cleanup)
  - [ScreenSpaceCollisionMarker for Click Detection](#screenspacecollisionmarker-for-click-detection)
  - [DrawCommandSpace (World vs Screen)](#drawcommandspace-world-vs-screen)
  - [ChildBuilder.setOffset Patterns](#childbuildersetoffset-patterns)
  - [Slot Decorations and Sprite Panels](#slot-decorations-and-sprite-panels)
  - [ObjectAttachedToUITag for Draggables](#objectattachedtouitag-for-draggables)
- [Lua / C++ Bindings](#lua--c-bindings)
  - [C++ globals are injected, not require() modules](#lua-globals-vs-modules)
  - [Userdata newindex assignment failure](#lua-userdata-newindex)
  - [Use Color.new, not Lua tables](#lua-color-userdata)
  - [Callback signature mismatches](#lua-callback-signatures)
  - [Wrong require() paths cause module not found](#lua-require-paths)
- [Physics System](#physics-system)
  - [Collisions not working without tags and masks](#physics-collision-tags)
  - [Collision masks must be updated for both tags](#physics-collision-masks-update)
  - [Physics world lookup returns nil](#physics-world-nil)
  - [Body not moving due to sync mode](#physics-sync-mode)
  - [Sync mode order matters](#physics-sync-order)
  - [Arbiter data is only valid during callbacks](#physics-arbiter-lifetime)
- [Rendering & Layers](#rendering--layers)
  - [Wrong layer or Z-order hides entities](#rendering-z-order-layer)
  - [Layer ordering uses layer_order_system](#rendering-layer-order-system)
  - [DrawCommandSpace controls camera space](#rendering-drawcommandspace)
- [Shader System](#shader-system)
- [Sound System](#sound-system)
- [Camera System](#camera-system)
- [Animation System](#animation-system)
- [Combat System](#combat-system)
  - [Projectile collision tags must match targets](#combat-projectile-collision-tags)
  - [Arc projectiles need manual gravity if world gravity is zero](#combat-projectile-manual-gravity)
  - [Homing projectiles need non-zero homing_strength](#combat-homing-strength)
  - [Always set projectile lifetime](#combat-projectile-lifetime)
  - [Buff stacking depends on stack_mode](#combat-buff-stacking)
  - [Damage must flow through CombatSystem pipeline](#combat-damage-pipeline)
- [Input System](#input-system)
  - [Initialize input handler once](#input-handler-init-once)
  - [Delay input setup until systems are ready](#input-handler-delay)
  - [Capture input after systems initialize](#input-capture-timing)
  - [Controller focus requires active layer](#input-focus-management)
- [Registry Anchors (Auto)](#registry-anchors-auto)

---

<a id="entry-template"></a>
## Entry Template

<!-- Template for new quirks entries. Copy this structure for each new entry. -->
```markdown
<a id="unique-anchor-id"></a>
### Entry Title
- doc_id: pattern:system.feature.case (or binding:name, component:Name)
- Test: <test_file>::<test_id> (or "Unverified: <reason>")
- Source: <source_file> (or CLAUDE.md)

**Problem:**
Brief description of the symptom or failure mode.

**Root cause:**
Why this happens (technical explanation).

**Solution:**
Exact fix with code example if applicable.

```lua
-- Minimal reproducible snippet (correct pattern)
```

**Evidence:**
- Verified: Test: <test_file>::<test_id>
- OR Unverified: <reason> (Source: <source_ref>)
```

---

## Entity Lifecycle

Entity lifecycle has strict ordering and validation requirements. Violating these patterns causes data loss, stale references, or silent failures.

<a id="ecs-init-order"></a>
### Script Initialization Order
- doc_ids: pattern:ecs.init.data_preserved
- Tests: assets/scripts/tests/test_entity_lifecycle.lua::ecs.init.data_preserved
- Source: assets/scripts/monobehavior/behavior_script_v2.lua, docs/guides/entity-scripts.md

Minimal reproducible snippet:
```lua
local Node = require("monobehavior.behavior_script_v2")
local ScriptType = Node:extend()

function ScriptType:init()
    -- init can read fields assigned at construction time
    self.init_seen = self.data and self.data.value or nil
end

local script = ScriptType { data = { value = 99 } }
script:attach_ecs { create_new = false, existing_entity = eid }
```

Why: `init()` runs during construction. If you need init to see data, pass it in or use `Node.quick()` / `EntityBuilder.validated()` to guarantee data exists before attach.

<a id="ecs-attach-ecs-timing"></a>
### ecs-attach-ecs-timing
- doc_ids: pattern:ecs.attach_ecs.assign_before_attach, pattern:ecs.attach_ecs.assign_after_attach_fails
- Tests: assets/scripts/tests/test_entity_lifecycle.lua::ecs.attach_ecs.assign_before_attach, assets/scripts/tests/test_entity_lifecycle.lua::ecs.attach_ecs.assign_after_attach_fails
- Source: assets/scripts/core/entity_builder.lua, assets/scripts/monobehavior/behavior_script_v2.lua, docs/guides/entity-scripts.md

Minimal reproducible snippet (correct):
```lua
local EntityType = Node:extend()
local script = EntityType {}
script.data = { value = 42 }    -- Assign FIRST
script:attach_ecs { create_new = false, existing_entity = eid }  -- Attach LAST
```

Minimal reproducible snippet (wrong):
```lua
local script = EntityType {}
script:attach_ecs { create_new = false, existing_entity = eid }
script.data = { value = 42 }    -- WRONG: attach-time hooks miss data
```

Why: attach-time hooks (`run_custom_func`, `addStateTag`, etc.) read fields immediately. Late data means hooks see nil.
Preferred: `Node.quick(entity, data)` or `EntityBuilder.validated(ScriptType, entity, data)` to enforce ordering.

<a id="ecs-gameobject-restrictions"></a>
### ecs-gameobject-restrictions
- doc_ids: pattern:ecs.gameobject.no_data_storage, pattern:ecs.gameobject.script_table_usage
- Tests: assets/scripts/tests/test_entity_lifecycle.lua::ecs.gameobject.no_data_storage, assets/scripts/tests/test_entity_lifecycle.lua::ecs.gameobject.script_table_usage
- Source: CLAUDE.md

Minimal reproducible snippet (wrong):
```lua
local gameObj = component_cache.get(entity, GameObject)
gameObj.myData = {}  -- WRONG: bypasses script table system
```

Correct pattern:
```lua
local script = safe_script_get(entity)
script.myData = { hp = 10 }
```

Why: GameObject is a component wrapper. Script data must live on the script table to be discoverable via `safe_script_get`/`getScriptTableFromEntityID`.

<a id="ecs-script-access"></a>
### ecs-script-access
- doc_ids: pattern:ecs.access.script_field_default, pattern:ecs.access.script_field_nil, pattern:ecs.access.safe_script_get_valid, pattern:ecs.access.safe_script_get_invalid
- Tests: assets/scripts/tests/test_entity_lifecycle.lua::ecs.access.script_field_default, assets/scripts/tests/test_entity_lifecycle.lua::ecs.access.script_field_nil, assets/scripts/tests/test_entity_lifecycle.lua::ecs.access.safe_script_get_valid, assets/scripts/tests/test_entity_lifecycle.lua::ecs.access.safe_script_get_invalid
- Source: assets/scripts/util/util.lua

Minimal reproducible snippet:
```lua
local health = script_field(eid, "health", 100)
local mana = script_field(eid, "mana", nil)
local script = safe_script_get(eid)
if not script then return end
```

Why: `safe_script_get` returns nil on invalid/missing script. `script_field` safely returns the default (including nil) for missing fields.

<a id="ecs-validation"></a>
### ecs-validation
- doc_ids: pattern:ecs.validate.ensure_entity_valid, pattern:ecs.validate.ensure_entity_invalid, pattern:ecs.validate.ensure_scripted_entity_valid, pattern:ecs.validate.ensure_scripted_entity_invalid
- Tests: assets/scripts/tests/test_entity_lifecycle.lua::ecs.validate.ensure_entity_valid, assets/scripts/tests/test_entity_lifecycle.lua::ecs.validate.ensure_entity_invalid, assets/scripts/tests/test_entity_lifecycle.lua::ecs.validate.ensure_scripted_entity_valid, assets/scripts/tests/test_entity_lifecycle.lua::ecs.validate.ensure_scripted_entity_invalid
- Source: assets/scripts/util/util.lua

Minimal reproducible snippet:
```lua
if ensure_entity(eid) then
    -- entity exists (registry.valid + cache)
end

if ensure_scripted_entity(eid) then
    -- entity exists AND has ScriptComponent
end
```

Why: `ensure_entity` checks registry + cache validity. `ensure_scripted_entity` adds a ScriptComponent requirement.

<a id="ecs-component-cache"></a>
### ecs-component-cache
- doc_ids: pattern:ecs.cache.get_valid, pattern:ecs.cache.get_after_destroy, pattern:ecs.cache.invalidation, pattern:ecs.cache.performance
- Tests: assets/scripts/tests/test_entity_lifecycle.lua::ecs.cache.get_valid, assets/scripts/tests/test_entity_lifecycle.lua::ecs.cache.get_after_destroy, assets/scripts/tests/test_entity_lifecycle.lua::ecs.cache.invalidation, assets/scripts/tests/test_entity_lifecycle.lua::ecs.cache.performance
- Source: assets/scripts/core/component_cache.lua

Minimal reproducible snippet:
```lua
local transform = component_cache.get(eid, Transform)
-- invalidate when entity or component is removed
component_cache.invalidate(eid, Transform)
```

Why: cached lookups are fast but must be invalidated on destroy/remove to avoid stale data.

<a id="ecs-destruction"></a>
### ecs-destruction
- doc_ids: pattern:ecs.destroy.no_stale_refs, pattern:ecs.destroy.then_recreate, pattern:ecs.destroy.cleanup_all_references, pattern:ecs.destroy.cache_cleared
- Tests: assets/scripts/tests/test_entity_lifecycle.lua::ecs.destroy.no_stale_refs, assets/scripts/tests/test_entity_lifecycle.lua::ecs.destroy.then_recreate, assets/scripts/tests/test_entity_lifecycle.lua::ecs.destroy.cleanup_all_references, assets/scripts/tests/test_entity_lifecycle.lua::ecs.destroy.cache_cleared
- Source: assets/scripts/combat/entity_cleanup.lua, assets/scripts/core/component_cache.lua

Minimal reproducible snippet:
```lua
local ref = eid
registry:destroy(eid)
component_cache.invalidate(eid)
-- use safe_script_get or ensure_entity to avoid stale references
if safe_script_get(ref) == nil then
    -- reference is stale
end
```

Why: destruction must clear caches and references. Always re-validate before using old ids.

<a id="ecs-luajit-locals"></a>
### ecs-luajit-locals
- doc_ids: pattern:ecs.luajit.200_local_limit
- Tests: assets/scripts/tests/test_entity_lifecycle.lua::ecs.luajit.200_local_limit
- Source: CLAUDE.md

Minimal reproducible snippet (wrong):
```lua
-- 200+ locals in a single function scope can crash LuaJIT
local a1, a2, a3 = ...
```

Preferred pattern:
```lua
local sounds = { footsteps = { ... } }
```

---

<a id="ui--uibox-system"></a>
## UI / UIBox System

This section documents UI/UIBox ordering requirements and common failure modes.
Each entry includes a doc_id for traceability and a test reference where applicable.

<a id="uibox-creation-and-configuration"></a>
### UIBox Creation and Configuration
- doc_id: pattern:ui.uibox_creation.basic
- Test: assets/scripts/tests/test_ui_patterns.lua::ui.statetag.add_after_spawn
- Source: docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md

**Problem:**
UI elements render but never receive clicks or layout does not update after spawn.

**Root cause:**
UIBox created without required components or missing post-spawn alignment or state setup.

**Solution:**
Use DSL spawn helpers, add state tags after spawn, and realign after rebuilds.

```lua
local panelEntity = dsl.spawn({ x = panelX, y = panelY }, panelDef, "ui", PANEL_Z)
ui.box.AddStateTagToUIBox(registry, panelEntity, "default_state")
ui.box.RenewAlignment(registry, panelEntity)
```

**Evidence:**
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.statetag.add_after_spawn

### UIBox Alignment and RenewAlignment

<a id="renewalignment-after-setoffset"></a>
#### RenewAlignment after setOffset
- doc_id: pattern:ui.uibox_alignment.renew_after_offset
- Test: assets/scripts/tests/test_ui_patterns.lua::ui.uibox_alignment.renew_after_offset
- Source: assets/scripts/ui/wand_panel.lua:positionTabs

**Problem:**
Child elements stay at old positions after ChildBuilder.setOffset.

**Root cause:**
InheritedProperties offsets update, but layout is not recomputed until RenewAlignment.

**Solution:**
Call ui.box.RenewAlignment after changing child offsets.

```lua
ChildBuilder.setOffset(container, x, y)
ui.box.RenewAlignment(registry, container)
```

**Evidence:**
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.uibox_alignment.renew_after_offset

<a id="renewalignment-after-replacechildren"></a>
#### RenewAlignment after ReplaceChildren
- doc_id: pattern:ui.uibox_alignment.renew_after_replacechildren
- Test: assets/scripts/tests/test_ui_patterns.lua::ui.uibox_alignment.renew_after_replacechildren
- Source: assets/scripts/ui/player_inventory.lua:injectGridForTab

**Problem:**
Newly replaced children appear at incorrect positions or overlap.

**Root cause:**
ReplaceChildren invalidates cached layout; alignment is not recalculated.

**Solution:**
Call ui.box.RenewAlignment after ReplaceChildren.

```lua
ui.box.ReplaceChildren(gridContainer, gridDef)
ui.box.RenewAlignment(registry, gridContainer)
```

**Evidence:**
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.uibox_alignment.renew_after_replacechildren

### State Tags and UIBox State Management

<a id="addstatetagto-uibox-after-spawn"></a>
#### addstatetagto-uibox-after-spawn
- doc_id: pattern:ui.statetag.add_after_spawn
- Test: assets/scripts/tests/test_ui_patterns.lua::ui.statetag.add_after_spawn
- Source: assets/scripts/ui/skills_panel.lua:initPanel

**Problem:**
UI states never activate (hover, pressed, disabled visuals never appear).

**Root cause:**
State tags are not assigned after spawn.

**Solution:**
Add default state tags immediately after spawn.

```lua
local panelEntity = dsl.spawn({ x = panelX, y = panelY }, panelDef, "ui", PANEL_Z)
ui.box.AddStateTagToUIBox(registry, panelEntity, "default_state")
```

**Evidence:**
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.statetag.add_after_spawn

<a id="addstatetagto-uibox-after-replacechildren"></a>
#### addstatetagto-uibox-after-replacechildren
- doc_id: pattern:ui.statetag.add_after_replacechildren
- Test: assets/scripts/tests/test_ui_patterns.lua::ui.statetag.add_after_replacechildren
- Source: assets/scripts/ui/player_inventory.lua:injectGridForTab

**Problem:**
State tags disappear after ReplaceChildren, causing styling regressions.

**Root cause:**
ReplaceChildren wipes state tags from the UIBox tree.

**Solution:**
Re-apply state tags after ReplaceChildren.

```lua
ui.box.ReplaceChildren(gridContainer, gridDef)
ui.box.AddStateTagToUIBox(registry, panelEntity, "default_state")
```

**Evidence:**
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.statetag.add_after_replacechildren

<a id="state-tag-persistence-check"></a>
#### State tag persistence check
- doc_id: pattern:ui.statetag.persistence_check
- Test: assets/scripts/tests/test_ui_patterns.lua::ui.statetag.persistence_check
- Source: assets/scripts/ui/stats_panel_v2.lua:_createPanel

**Problem:**
State tags appear briefly, then stop responding to state transitions.

**Root cause:**
State tag list is mutated or cleared during subsequent UI operations.

**Solution:**
Clear and reapply tags whenever the UI tree is rebuilt or replaced.

```lua
ui.box.ClearStateTagsFromUIBox(entity)
ui.box.AddStateTagToUIBox(entity, "default_state")
```

**Evidence:**
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.statetag.persistence_check

### Panel Visibility and uiRoot Coordination

<a id="move-both-transform-and-uiboxcomponent-uiroot"></a>
#### move-both-transform-and-uiboxcomponent-uiroot
- doc_id: pattern:ui.visibility.move_transform_and_uiroot
- Test: assets/scripts/tests/test_ui_patterns.lua::ui.visibility.move_transform_and_uiroot
- Source: assets/scripts/ui/stats_panel_v2.lua:setEntityVisible

**Problem:**
Panel container moves but children stay in the old position.

**Root cause:**
uiRoot Transform is not moved alongside the UIBox Transform.

**Solution:**
Update Transform, uiRoot Transform, and then realign.

```lua
local t = component_cache.get(entity, Transform)
t.actualX = targetX
t.actualY = targetY

local boxComp = component_cache.get(entity, UIBoxComponent)
local rt = component_cache.get(boxComp.uiRoot, Transform)
rt.actualX = targetX
rt.actualY = targetY

ui.box.RenewAlignment(registry, entity)
```

**Evidence:**
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.visibility.move_transform_and_uiroot

<a id="transform-only-move-fails"></a>
#### Transform-only move fails
- doc_id: pattern:ui.visibility.transform_only_fails
- Test: assets/scripts/tests/test_ui_patterns.lua::ui.visibility.transform_only_fails
- Source: assets/scripts/ui/stats_panel_v2.lua:setEntityVisible

**Problem:**
Children remain at original coordinates after moving only the panel Transform.

**Root cause:**
UIBox children align to uiRoot, not the panel Transform alone.

**Solution:**
Always update uiRoot along with the main Transform.

```lua
local t = component_cache.get(entity, Transform)
t.actualX = targetX
t.actualY = targetY

local boxComp = component_cache.get(entity, UIBoxComponent)
local rt = component_cache.get(boxComp.uiRoot, Transform)
rt.actualX = targetX
rt.actualY = targetY
```

**Evidence:**
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.visibility.transform_only_fails

### Grid Management and Cleanup

<a id="cleanup-all-three-registries"></a>
#### Cleanup all three registries
- doc_id: pattern:ui.grid.cleanup_all_three_registries
- Test: assets/scripts/tests/test_ui_patterns.lua::ui.grid.cleanup_all_three_registries
- Source: assets/scripts/ui/player_inventory.lua:cleanupGridEntity

**Problem:**
Orphaned items or ghost slots remain after grid teardown.

**Root cause:**
Only partial cleanup is performed.

**Solution:**
Clear the item registry, cleanup the grid entity, and cleanup the DSL grid.

```lua
itemRegistry.clearGrid(gridEntity)
grid.cleanup(gridEntity)
dsl.cleanupGrid(cfg.id)
```

**Evidence:**
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.grid.cleanup_all_three_registries

<a id="partial-cleanup-fails"></a>
#### Partial cleanup fails
- doc_id: pattern:ui.grid.cleanup_partial_fails
- Test: assets/scripts/tests/test_ui_patterns.lua::ui.grid.cleanup_partial_fails
- Source: assets/scripts/ui/player_inventory.lua:cleanupGridEntity

**Problem:**
Old items remain registered even after grid is destroyed.

**Root cause:**
itemRegistry or DSL cleanup is skipped.

**Solution:**
Always perform all three cleanup steps.

```lua
itemRegistry.clearGrid(gridEntity)
grid.cleanup(gridEntity)
dsl.cleanupGrid(cfg.id)
```

**Evidence:**
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.grid.cleanup_partial_fails

### ScreenSpaceCollisionMarker for Click Detection

<a id="marker-required-for-clicks"></a>
#### Marker required for clicks
- doc_id: pattern:ui.collision.screenspace_marker_required
- Test: assets/scripts/tests/test_ui_patterns.lua::ui.collision.screenspace_marker_required
- Source: assets/scripts/ui/trigger_strip_ui.lua:createEntry

**Problem:**
UI buttons do not respond to clicks.

**Root cause:**
ScreenSpaceCollisionMarker is missing, so the input system ignores the UI entity.

**Solution:**
Attach ScreenSpaceCollisionMarker for screen-space UI.

```lua
if registry and registry.valid and collision and collision.ScreenSpaceCollisionMarker and registry:valid(entity) then
    if not registry:has(entity, collision.ScreenSpaceCollisionMarker) then
        registry:emplace(entity, collision.ScreenSpaceCollisionMarker)
    end
end
```

**Evidence:**
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.collision.screenspace_marker_required

<a id="click-detection-with-marker"></a>
#### Click detection with marker
- doc_id: pattern:ui.collision.click_detection_with_marker
- Test: assets/scripts/tests/test_ui_patterns.lua::ui.collision.click_detection_with_marker
- Source: assets/scripts/ui/stats_panel_v2.lua:_createTabMarker

**Problem:**
Clicks are not routed to callbacks even though the UI is visible.

**Root cause:**
Marker was never attached or was removed during rebuild.

**Solution:**
Ensure marker is attached at spawn and preserved after ReplaceChildren.

```lua
if registry.emplace and ScreenSpaceCollisionMarker then
    pcall(function()
        registry:emplace(entity, ScreenSpaceCollisionMarker {})
    end)
end
```

**Evidence:**
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.collision.click_detection_with_marker

<a id="click-fails-without-marker"></a>
#### Click fails without marker
- doc_id: pattern:ui.collision.click_fails_without_marker
- Test: assets/scripts/tests/test_ui_patterns.lua::ui.collision.click_fails_without_marker
- Source: assets/scripts/ui/trigger_strip_ui.lua:createEntry

**Problem:**
Clicking UI does nothing despite valid callbacks.

**Root cause:**
Input system rejects entities without the marker.

**Solution:**
Attach ScreenSpaceCollisionMarker before registering callbacks.

```lua
if registry and registry.valid and collision and collision.ScreenSpaceCollisionMarker then
    if not registry:has(entity, collision.ScreenSpaceCollisionMarker) then
        registry:emplace(entity, collision.ScreenSpaceCollisionMarker)
    end
end
```

**Evidence:**
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.collision.click_fails_without_marker

### DrawCommandSpace (World vs Screen)

<a id="world-draw-space-follows-camera"></a>
#### World draw space follows camera
- doc_id: pattern:ui.drawspace.world_follows_camera
- Test: assets/scripts/tests/test_ui_patterns.lua::ui.drawspace.world_follows_camera
- Source: assets/scripts/ui/card_space_converter.lua:toWorldSpace

**Problem:**
HUD elements drift with the camera.

**Root cause:**
DrawCommandSpace.World is used for screen-space UI.

**Solution:**
Use world space only for board elements that should track camera.

```lua
transform.set_space(cardEntity, "world")
```

**Evidence:**
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.drawspace.world_follows_camera

<a id="screen-draw-space-stays-fixed"></a>
#### Screen draw space stays fixed
- doc_id: pattern:ui.drawspace.screen_fixed_hud
- Test: assets/scripts/tests/test_ui_patterns.lua::ui.drawspace.screen_fixed_hud
- Source: assets/scripts/ui/card_space_converter.lua:toScreenSpace

**Problem:**
HUD elements still move with the camera.

**Root cause:**
DrawCommandSpace was not set explicitly or uses World by default.

**Solution:**
Use screen space for HUD elements that must remain fixed.

```lua
transform.set_space(cardEntity, "screen")
```

**Evidence:**
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.drawspace.screen_fixed_hud

### ChildBuilder.setOffset Patterns

<a id="setoffset-requires-renewalignment"></a>
#### setOffset requires RenewAlignment
- doc_id: pattern:ui.childbuilder.setoffset_requires_renew
- Test: assets/scripts/tests/test_ui_patterns.lua::ui.uibox_alignment.renew_after_offset
- Source: assets/scripts/ui/wand_panel.lua:positionTabs

**Problem:**
Child elements remain at old coordinates after setOffset.

**Root cause:**
InheritedProperties offset changes do not reflow UI layout automatically.

**Solution:**
Call ui.box.RenewAlignment after setOffset.

```lua
ChildBuilder.setOffset(container, x, y)
ui.box.RenewAlignment(registry, container)
```

**Evidence:**
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.uibox_alignment.renew_after_offset

<a id="slot-decorations-and-sprite-panels"></a>
### Slot Decorations and Sprite Panels
- doc_id: pattern:ui.slot_decorations.sprite_panel_scaling
- Test: Unverified: manual visual check
- Source: assets/scripts/ui/ui_syntax_sugar.lua:buildGridDefinition

**Problem:**
Decorations render misaligned or scaled incorrectly relative to slots.

**Root cause:**
Decorations are not scaled using sprite scale or slot config.

**Solution:**
Use slotConfig.decorations or gridConfig.slotDecorations and apply sprite scaling.

```lua
local slotDecorations = slotConfig.decorations or gridConfig.slotDecorations
if slotDecorations and type(slotDecorations) == "table" and next(slotDecorations) then
    slotNodeConfig._decorations = scaleSlotDecorations(slotDecorations, spriteScale)
end
```

**Evidence:**
- Unverified: Manual visual check

### ObjectAttachedToUITag for Draggables

<a id="never-use-objectattachedto-uitag-on-draggables"></a>
#### never-use-objectattachedto-uitag-on-draggables
- doc_id: pattern:ui.attached.never_on_draggables
- Test: assets/scripts/tests/test_ui_patterns.lua::ui.attached.never_on_draggables
- Source: assets/scripts/ui/trigger_strip_ui.lua:createEntry

**Problem:**
Draggable UI elements become stuck or cannot move.

**Root cause:**
ObjectAttachedToUITag forces attachment behavior that conflicts with drag logic.

**Solution:**
Do not add ObjectAttachedToUITag to draggable UI elements.

```lua
transform.set_space(entity, "screen")
-- Do not add ObjectAttachedToUITag on draggables
```

**Evidence:**
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.attached.never_on_draggables

<a id="objectattachedto-uitag-correct-usage"></a>
#### objectattachedto-uitag-correct-usage
- doc_id: pattern:ui.attached.correct_usage
- Test: assets/scripts/tests/test_ui_patterns.lua::ui.attached.correct_usage
- Source: assets/scripts/ui/message_queue_ui.lua:tryMakeIcon

**Problem:**
Non-draggable attachments fail to follow parent if tag is missing.

**Root cause:**
Attachment tag not applied for static attachments.

**Solution:**
Use ObjectAttachedToUITag only for non-draggable attachments.

```lua
transform.set_space(entity, "screen")
if registry and registry.valid and ObjectAttachedToUITag and registry:valid(entity) then
    if not registry:has(entity, ObjectAttachedToUITag) then
        registry:emplace(entity, ObjectAttachedToUITag)
    end
end
```

**Evidence:**
- Verified: Test: assets/scripts/tests/test_ui_patterns.lua::ui.attached.correct_usage

<a id="lua--c-bindings"></a>
## Lua / C++ Bindings

<a id="lua-globals-vs-modules"></a>
### C++ globals are injected, not require() modules
- doc_id: pattern:lua.bindings.globals_injected
- Test: Unverified: Documentation guidance
- Source: docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md, CLAUDE.md

**Problem:**
`module not found` when trying to `require()` engine globals like `registry` or `layers`.

**Root cause:**
Many engine bindings are injected into the Lua VM as C++ globals, not Lua files.

**Solution:**
Use `_G` (or bare globals) for C++ bindings. Only `require()` actual Lua modules from `assets/scripts/`.

```lua
-- WRONG: will fail
local registry = require("core.registry")

-- RIGHT: access globals
local registry = _G.registry
```

**Evidence:**
- Unverified: Documentation guidance (docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md)

<a id="input-capture-timing"></a>
### Capture input after systems initialize
- doc_id: pattern:input.capture.timing
- Test: Unverified: Documentation guidance
- Source: docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md

**Problem:**
`input.getState()` returns nil or missing fields during panel setup.

**Root cause:**
Input handlers run before input systems and globals are ready.

**Solution:**
Defer setup and poll input state inside the render-frame handler.

```lua
timer.after_opts({
    delay = 0.1,
    action = function() setupInputHandler() end,
    tag = "panel_input_setup",
    group = TIMER_GROUP,
})
```

**Evidence:**
- Unverified: Documentation guidance (docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md)

<a id="input-focus-management"></a>
### Controller focus requires active layer
- doc_id: pattern:input.focus.management
- Test: Unverified: Documentation guidance
- Source: docs/systems/advanced/controller_navigation.md

**Problem:**
Controller navigation does nothing or focus sticks after UI rebuilds.

**Root cause:**
No active layer or focused entity set after dynamic UI creation.

**Solution:**
Create group and layer, add group to layer, set the active layer, and focus the first entity.

```lua
controller_nav.create_group("menu_buttons")
controller_nav.create_layer("main_menu")
controller_nav.add_group_to_layer("main_menu", "menu_buttons")
controller_nav.ud:set_active_layer("main_menu")
controller_nav.focus_entity(first_button)
```

**Evidence:**
- Unverified: Documentation guidance (docs/systems/advanced/controller_navigation.md)
<a id="lua-userdata-newindex"></a>
### Userdata newindex assignment failure
- doc_id: pattern:lua.bindings.userdata_newindex
- Test: Unverified: Documentation guidance
- Source: docs/api/lua-cpp-documentation-guide.md

**Problem:**
Setting fields on C++ userdata throws `no new_index operation`.

**Root cause:**
Some bound userdata are read-only and do not support arbitrary field assignment.

**Solution:**
Guard assignments with `pcall` and store Lua-side data elsewhere.

```lua
local ok = pcall(function()
    go.methods.onHover = function() end
end)
if not ok then
    log_warn("Could not set userdata field")
end
```

**Evidence:**
- Unverified: Documentation guidance (docs/api/lua-cpp-documentation-guide.md)

<a id="lua-color-userdata"></a>
### Use Color.new, not Lua tables
- doc_id: pattern:lua.bindings.color_userdata
- Test: Unverified: Documentation guidance
- Source: docs/api/lua-cpp-documentation-guide.md

**Problem:**
Passing `{r,g,b,a}` tables where a Color userdata is required.

**Root cause:**
C++ expects `Color` userdata, not a plain Lua table.

**Solution:**
Use `Color.new(r, g, b, a)` to construct a proper userdata.

```lua
-- WRONG
local transparent = { r = 0, g = 0, b = 0, a = 0 }

-- RIGHT
local transparent = Color.new(0, 0, 0, 0)
```

**Evidence:**
- Unverified: Documentation guidance (docs/api/lua-cpp-documentation-guide.md)

<a id="lua-callback-signatures"></a>
### Callback signature mismatches
- doc_id: pattern:lua.bindings.callback_signature
- Test: Unverified: Documentation guidance
- Source: docs/api/lua-cpp-documentation-guide.md

**Problem:**
Callbacks silently fail or throw errors when invoked from C++.

**Root cause:**
Lua function signatures do not match the C++ binding expectations.

**Solution:**
Match the exact parameter order documented in the binding definition.

```lua
-- Example: expects (registry, entity, collisionList)
local function onCollision(registry, entity, collisions)
    -- ...
end
```

**Evidence:**
- Unverified: Documentation guidance (docs/api/lua-cpp-documentation-guide.md)

<a id="lua-require-paths"></a>
### Wrong require() paths cause module not found
- doc_id: pattern:lua.bindings.require_paths
- Test: Unverified: Documentation guidance
- Source: docs/guides/COMMON_PITFALLS.md, docs/guides/implementation-summaries/PROJECTILE_TEST_INTEGRATION.md

**Problem:**
`module not found` when using long or absolute require paths.

**Root cause:**
Lua module paths are rooted at `assets/scripts/` and should use short `require("core.timer")` style paths.

**Solution:**
Use the documented module paths; avoid `require("assets.scripts.core.timer")`.

```lua
-- WRONG
require("assets.scripts.core.timer")

-- RIGHT
require("core.timer")
```

**Evidence:**
- Unverified: Documentation guidance (docs/guides/COMMON_PITFALLS.md)

---

<a id="physics-system"></a>
## Physics System

<a id="physics-collision-tags"></a>
### Collisions not working without tags and masks
- doc_id: pattern:physics.collision.tags_masks
- Test: Unverified: Troubleshooting guide
- Source: docs/TROUBLESHOOTING.md

**Problem:**
Physics bodies pass through each other without colliding.

**Root cause:**
Missing collision tags/masks or bodies on the wrong physics world.

**Solution:**
Use PhysicsBuilder to set tags and collision masks, and ensure the world exists.

```lua
local PhysicsManager = require("core.physics_manager")
local PhysicsBuilder = require("core.physics_builder")

local world = PhysicsManager.get_world("world")
PhysicsBuilder.for_entity(entity)
    :circle()
    :tag("projectile")
    :collideWith({ "enemy", "WORLD" })
    :apply()
```

**Evidence:**
- Unverified: Troubleshooting guide (docs/TROUBLESHOOTING.md)

<a id="physics-collision-masks-update"></a>
### Collision masks must be updated for both tags
- doc_id: pattern:physics.collision.masks_bidirectional
- Test: Unverified: Cookbook guidance
- Source: docs/lua-cookbook/cookbook.md

**Problem:**
Collisions still fail after calling `enable_collision_between_many`.

**Root cause:**
Collision rules are registered, but existing bodies keep their old masks unless updated.

**Solution:**
After enabling collisions, update masks for both tags.

```lua
physics.enable_collision_between_many(world, "projectile", { "enemy", "WORLD" })
physics.enable_collision_between_many(world, "enemy", { "projectile" })
physics.update_collision_masks_for(world, "projectile", { "enemy", "WORLD" })
physics.update_collision_masks_for(world, "enemy", { "projectile" })
```

**Evidence:**
- Unverified: Cookbook guidance (docs/lua-cookbook/cookbook.md)

<a id="physics-world-nil"></a>
### Physics world lookup returns nil
- doc_id: pattern:physics.world.lookup
- Test: Unverified: Troubleshooting guide
- Source: docs/TROUBLESHOOTING.md

**Problem:**
`PhysicsManager.get_world("world")` returns nil.

**Root cause:**
Physics system not initialized or wrong world name; using legacy globals.

**Solution:**
Use PhysicsManager to fetch the world and guard nil results.

```lua
local PhysicsManager = require("core.physics_manager")
local world = PhysicsManager.get_world("world")
if not world then
    log_warn("Physics world not available")
    return
end
```

**Evidence:**
- Unverified: Troubleshooting guide (docs/TROUBLESHOOTING.md)

<a id="physics-sync-mode"></a>
### Body not moving due to sync mode
- doc_id: pattern:physics.sync.mode
- Test: Unverified: Troubleshooting guide
- Source: docs/TROUBLESHOOTING.md

**Problem:**
Physics body exists but the entity doesn't move.

**Root cause:**
Sync mode pulls from Transform instead of physics (authoritative transform).

**Solution:**
Set sync mode to physics so Transform follows the body.

```lua
PhysicsBuilder.for_entity(entity)
    :circle()
    :syncMode("physics")
    :apply()
```

**Evidence:**
- Unverified: Troubleshooting guide (docs/TROUBLESHOOTING.md)

<a id="physics-sync-order"></a>
### Sync mode order matters
- doc_id: pattern:physics.sync.order
- Test: Unverified: Cookbook guidance
- Source: docs/lua-cookbook/cookbook.md

**Problem:**
Entities snap back to old positions or ignore physics movement right after creation.

**Root cause:**
Physics setup order is wrong, leaving Transform as the authoritative source.

**Solution:**
Create sprite, position it, create physics body, configure properties, then set sync mode and collision masks.

```lua
-- 1. Create sprite + set transform position
-- 2. Create physics body
-- 3. Configure properties
physics.set_sync_mode(registry, entity, physics.PhysicsSyncMode.AuthoritativePhysics)
-- 4. Update collision masks
```

**Evidence:**
- Unverified: Cookbook guidance (docs/lua-cookbook/cookbook.md)

<a id="physics-arbiter-lifetime"></a>
### Arbiter data is only valid during callbacks
- doc_id: pattern:physics.arbiter.lifetime
- Test: Unverified: Documentation guidance
- Source: docs/api/physics_docs.md, docs/guides/COMMON_PITFALLS.md

**Problem:**
Accessing arbiter data after a collision callback causes undefined behavior.

**Root cause:**
Chipmunk arbiters are transient; pointers become invalid outside the callback.

**Solution:**
Copy the data you need inside the callback and do not retain arbiter references.

```lua
function onCollision(arbiter)
    local impulse = arbiter.totalImpulse
    -- store impulse, do not store arbiter
end
```

**Evidence:**
- Unverified: Documentation guidance (docs/api/physics_docs.md)

---

<a id="rendering--layers"></a>
## Rendering & Layers

<a id="rendering-z-order-layer"></a>
### Wrong layer or Z-order hides entities
- doc_id: pattern:rendering.layer.z_order
- Test: Unverified: Troubleshooting guide
- Source: docs/TROUBLESHOOTING.md

**Problem:**
Entities render behind or above the wrong elements.

**Root cause:**
`Transform.actualZ` or `EntityLayer.layer` is not set to the expected values.

**Solution:**
Assign a Z order and layer for UI vs world entities.

```lua
local z_orders = require("core.z_orders")
local transform = component_cache.get(entity, Transform)
transform.actualZ = z_orders.ui_foreground

local EntityLayer = _G.EntityLayer
if EntityLayer and not registry:has(entity, EntityLayer) then
    registry:emplace(entity, EntityLayer)
end
if EntityLayer then
    registry:get(entity, EntityLayer).layer = "ui"
end
```

**Evidence:**
- Unverified: Troubleshooting guide (docs/TROUBLESHOOTING.md)

<a id="rendering-layer-order-system"></a>
### Layer ordering uses layer_order_system
- doc_id: pattern:rendering.layer.layer_order_system
- Test: Unverified: Documentation guidance
- Source: docs/api/z-order-rendering.md

**Problem:**
Entities appear behind UI or ignore expected Z ordering.

**Root cause:**
Layer sorting uses `layer_order_system` and `z_orders` constants; relying only on `Transform.actualZ` is inconsistent.

**Solution:**
Assign Z order via `layer_order_system` or explicit draw command Z values.

```lua
layer_order_system.assignZIndexToEntity(entity, z_orders.ui_tooltips + 100)
```

**Evidence:**
- Unverified: Documentation guidance (docs/api/z-order-rendering.md)

<a id="rendering-drawcommandspace"></a>
### DrawCommandSpace controls camera space
- doc_id: pattern:rendering.drawspace.world_screen
- Test: Unverified: Documentation guidance
- Source: docs/api/z-order-rendering.md

**Problem:**
HUD elements move with the camera or world objects stick to the screen.

**Root cause:**
Draw commands default to World space if not explicitly set.

**Solution:**
Use Screen for fixed HUD, World for camera-following elements.

```lua
command_buffer.queueDrawRectangle(layers.ui, function(c) ... end, z, layer.DrawCommandSpace.Screen)
```

**Evidence:**
- Unverified: Documentation guidance (docs/api/z-order-rendering.md)

---

<a id="shader-system"></a>
## Shader System

<a id="shader-not-applying"></a>
### Shader not applying to entity
- doc_id: pattern:rendering.shader.not_applying
- Test: Unverified: Troubleshooting guide
- Source: docs/TROUBLESHOOTING.md

**Problem:**
Shader added to an entity but the effect is not visible.

**Root cause:**
Shader component missing, shader not present in library, or wrong render pass.

**Solution:**
Rebuild the shader chain with ShaderBuilder and validate the shader library.

```lua
local ShaderBuilder = require("core.shader_builder")

ShaderBuilder.for_entity(entity)
    :clear()
    :add("3d_skew_holo", { sheen_strength = 1.5 })
    :apply()

local shaderComp = component_cache.get(entity, ShaderComponent)
if not shaderComp then
    log_warn("Entity missing ShaderComponent")
end
```

**Evidence:**
- Unverified: Troubleshooting guide (docs/TROUBLESHOOTING.md)

---

<a id="sound-system"></a>
## Sound System

<!-- Stub: Sound quirks will be documented here -->
*No quirks documented yet. Add entries following the [Entry Template](#entry-template).*

Potential areas:
- Sound resource loading
- Audio playback timing
- Volume management
- Sound pooling/reuse

---

<a id="camera-system"></a>
## Camera System

<!-- Stub: Camera quirks will be documented here -->
*No quirks documented yet. Add entries following the [Entry Template](#entry-template).*

Potential areas:
- Camera target following
- Screen-to-world coordinate conversion
- Zoom behavior
- Camera bounds and clamping

---

<a id="animation-system"></a>
## Animation System

<!-- Stub: Animation quirks will be documented here -->
*No quirks documented yet. Add entries following the [Entry Template](#entry-template).*

Potential areas:
- Animation timing and frame rate
- Animation state transitions
- Sprite sheet indexing
- Animation callbacks and events

---

<a id="combat-system"></a>
## Combat System

<a id="combat-projectile-collision-tags"></a>
### Projectile collision tags must match targets
- doc_id: pattern:combat.projectile.collision_tags
- Test: Unverified: Documentation reference
- Source: docs/projectile_reference.md

**Problem:**
Projectiles never hit targets.

**Root cause:**
Collision tags/masks are not configured for `"projectile"` ↔ target tags.

**Solution:**
Use default tags or explicitly set `collideWithTags`/`targetCollisionTag`.

```lua
ProjectileSystem.spawn({
    movementType = "straight",
    collideWithTags = { "enemy", "WORLD" },
    targetCollisionTag = "enemy",
})
```

**Evidence:**
- Unverified: Documentation reference (docs/projectile_reference.md)

<a id="combat-projectile-manual-gravity"></a>
### Arc projectiles need manual gravity if world gravity is zero
- doc_id: pattern:combat.projectile.manual_gravity
- Test: Unverified: Documentation reference
- Source: docs/projectile_reference.md

**Problem:**
Arc projectiles fly straight when physics world gravity is zero.

**Root cause:**
Arc movement relies on gravity; if the world has no gravity, the arc never bends.

**Solution:**
Enable manual gravity and optionally disable physics integration.

```lua
ProjectileSystem.spawn({
    movementType = "arc",
    forceManualGravity = true,
    usePhysics = false,
})
```

**Evidence:**
- Unverified: Documentation reference (docs/projectile_reference.md)

<a id="combat-homing-strength"></a>
### Homing projectiles need non-zero homing_strength
- doc_id: pattern:combat.projectile.homing_strength
- Test: Unverified: Common pitfalls list
- Source: docs/guides/COMMON_PITFALLS.md

**Problem:**
Homing projectiles ignore targets and fly straight.

**Root cause:**
`homing_strength` defaults to 0, so homing behavior never engages.

**Solution:**
Set `homingStrength` to a positive value.

```lua
ProjectileSystem.spawn({
    movementType = "homing",
    homingStrength = 0.8,
})
```

**Evidence:**
- Unverified: Common pitfalls list (docs/guides/COMMON_PITFALLS.md)

<a id="combat-projectile-lifetime"></a>
### Always set projectile lifetime
- doc_id: pattern:combat.projectile.lifetime_required
- Test: Unverified: Common pitfalls list
- Source: docs/guides/COMMON_PITFALLS.md

**Problem:**
Projectiles never despawn and accumulate.

**Root cause:**
`lifetime` is unset; missed projectiles live forever.

**Solution:**
Always set `lifetime` on projectile spawns.

```lua
ProjectileSystem.spawn({
    movementType = "straight",
    lifetime = 2.5,
})
```

**Evidence:**
- Unverified: Common pitfalls list (docs/guides/COMMON_PITFALLS.md)

<a id="combat-buff-stacking"></a>
### Buff stacking depends on stack_mode
- doc_id: pattern:combat.status.stack_mode
- Test: Unverified: Documentation reference
- Source: docs/api/combat-systems.md

**Problem:**
Reapplying a buff does not increase effect or unexpectedly resets duration.

**Root cause:**
`stack_mode` defaults to replace behavior and `stat_mods` apply only once.

**Solution:**
Set `stack_mode` explicitly and use `stat_mods_per_stack` when you want per-stack scaling.

```lua
StatusEffects.burning = {
    id = "burning",
    stack_mode = "intensity",
    max_stacks = 99,
    duration = 5,
    stat_mods_per_stack = { damage_pct = 0.05 },
}
```

**Evidence:**
- Unverified: Documentation reference (docs/api/combat-systems.md)

<a id="combat-damage-pipeline"></a>
### Damage must flow through CombatSystem pipeline
- doc_id: pattern:combat.damage.pipeline_order
- Test: Unverified: Documentation reference
- Source: docs/api/combat-systems.md, docs/systems/combat/PROJECTILE_ARCHITECTURE.md

**Problem:**
Damage ignores resists, armor, block, or absorbs.

**Root cause:**
Direct HP modification bypasses the combat pipeline and its order of operations.

**Solution:**
Always call `CombatSystem.applyDamage` with `damageType` so the pipeline applies resist, armor, block, and absorb rules in order.

```lua
CombatSystem.applyDamage({
    target = target,
    source = source,
    damage = baseDamage,
    damageType = "fire",
})
```

**Evidence:**
- Unverified: Documentation reference (docs/api/combat-systems.md)

---

<a id="input-system"></a>
## Input System

<a id="input-handler-init-once"></a>
### Initialize input handler once
- doc_id: pattern:input.handler.init_once
- Test: Unverified: Documentation guidance
- Source: docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md

**Problem:**
Input handlers run multiple times per frame or duplicate timers stack up.

**Root cause:**
Input setup is called repeatedly without a guard, creating multiple render-frame timers.

**Solution:**
Use a boolean guard (e.g., `state.inputHandlerInitialized`) before registering the handler.

```lua
if state.inputHandlerInitialized then return end
state.inputHandlerInitialized = true
timer.run_every_render_frame(function() ... end, nil, "panel_input", TIMER_GROUP)
```

**Evidence:**
- Unverified: Documentation guidance (docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md)

<a id="input-handler-delay"></a>
### Delay input setup until systems are ready
- doc_id: pattern:input.handler.defer_setup
- Test: Unverified: Documentation guidance
- Source: docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md

**Problem:**
Input handler runs before systems are ready, causing nil globals or missing state.

**Root cause:**
Input setup runs immediately on module load instead of after initialization.

**Solution:**
Defer setup with a short timer and a dedicated tag/group.

```lua
timer.after_opts({
    delay = 0.1,
    action = function() setupInputHandler() end,
    tag = "panel_input_setup",
    group = TIMER_GROUP,
})
```

**Evidence:**
- Unverified: Documentation guidance (docs/guides/UI_PANEL_IMPLEMENTATION_GUIDE.md)

---

## Registry Anchors (Auto)

These entries are generated from `planning/cm_rules_candidates.yaml` to ensure registry anchors have a home in this document. Expand or relocate entries into the main system sections as needed.

### ECS Patterns

#### child-builder-attach-offset
- doc_id: pattern:core.child_builder.attach_offset
- Test: test_core_patterns.lua::core.child_builder.attach_offset
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When attaching child entities, use ChildBuilder to configure inherited properties and offsets in one flow.

**Root cause:**
ChildBuilder sets role inheritance, offsets, and alignment correctly for child entities.

**Solution:**
```lua
ChildBuilder.for_entity(child):attachTo(parent):offset(20, 0):rotateWith():apply()
```

**Anti-pattern:**
```lua
-- attach child without inherited properties configured
```

**Evidence:**
- Verified: Test: test_core_patterns.lua::core.child_builder.attach_offset

#### ecs-cache-performance
- doc_id: pattern:ecs.cache.performance
- Test: test_entity_lifecycle.lua::ecs.cache.performance
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When repeatedly accessing components, use component_cache for fast lookups and invalidate on teardown.

**Root cause:**
Cached lookups avoid repeated registry access while remaining safe when invalidated.

**Solution:**
```lua
local t = component_cache.get(eid, Transform)
component_cache.invalidate(eid, Transform)
```

**Anti-pattern:**
```lua
local t = registry:get(eid, Transform) -- repeated each frame
```

**Evidence:**
- Verified: Test: test_entity_lifecycle.lua::ecs.cache.performance

#### ecs-init-data-preserved
- doc_id: pattern:ecs.init.data_preserved
- Test: test_entity_lifecycle.lua::ecs.init.data_preserved
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When initializing scripts, pass data in the constructor so init can read it before attach_ecs.

**Root cause:**
init runs during construction; passing data up front preserves initialization state.

**Solution:**
```lua
local ScriptType = Node:extend()
local script = ScriptType { data = { value = 99 } }
script:attach_ecs { create_new = false, existing_entity = eid }
```

**Anti-pattern:**
```lua
local ScriptType = Node:extend()
local script = ScriptType {}
script.data = { value = 99 }
script:attach_ecs { create_new = false, existing_entity = eid }
```

**Evidence:**
- Verified: Test: test_entity_lifecycle.lua::ecs.init.data_preserved

#### entity-builder-create
- doc_id: pattern:core.entity_builder.create
- Test: test_core_patterns.lua::core.entity_builder.create
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When creating entities with standard fields, use EntityBuilder.create with a config table for consistent setup.

**Root cause:**
EntityBuilder.create wires sprite, transform, and data in one deterministic call.

**Solution:**
```lua
local entity, script = EntityBuilder.create({ sprite = "kobold", position = { x = 100, y = 200 }, size = { 64, 64 }, data = { health = 100 } })
```

**Anti-pattern:**
```lua
-- manual component wiring scattered across files
```

**Evidence:**
- Verified: Test: test_core_patterns.lua::core.entity_builder.create

#### entity-builder-fluent-chain
- doc_id: pattern:core.entity_builder.fluent_chain
- Test: test_core_patterns.lua::core.entity_builder.fluent_chain
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When chaining entity creation steps, use the EntityBuilder fluent API for readable setup.

**Root cause:**
Fluent chaining keeps spawn parameters together and avoids partial setup.

**Solution:**
```lua
local entity = EntityBuilder.new("wall_tile"):at(wx, wy):build()
```

**Anti-pattern:**
```lua
-- create entity then patch fields across multiple functions
```

**Evidence:**
- Verified: Test: test_core_patterns.lua::core.entity_builder.fluent_chain

### ECS Gotchas

#### attach-ecs-assign-after-fails
- doc_id: pattern:ecs.attach_ecs.assign_after_attach_fails
- Test: test_entity_lifecycle.lua::ecs.attach_ecs.assign_after_attach_fails
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When attach_ecs is called before assigning script data, attach-time hooks read nil values and initialization fails.

**Root cause:**
attach_ecs captures data immediately; assigning after the call does not backfill state.

**Solution:**
```lua
local script = EntityType {}
script.data = { value = 42 }
script:attach_ecs { create_new = false, existing_entity = eid }
```

**Anti-pattern:**
```lua
local script = EntityType {}
script:attach_ecs { create_new = false, existing_entity = eid }
script.data = { value = 42 }
```

**Evidence:**
- Verified: Test: test_entity_lifecycle.lua::ecs.attach_ecs.assign_after_attach_fails

#### cache-get-after-destroy
- doc_id: pattern:ecs.cache.get_after_destroy
- Test: test_entity_lifecycle.lua::ecs.cache.get_after_destroy
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When an entity is destroyed, cached component handles become invalid and must not be reused.

**Root cause:**
component_cache entries are invalidated on destroy; reuse leads to stale data.

**Solution:**
```lua
registry:destroy(eid)
component_cache.invalidate(eid)
local t = component_cache.get(eid, Transform) -- nil
```

**Anti-pattern:**
```lua
local t = component_cache.get(eid, Transform)
registry:destroy(eid)
-- reusing t after destroy
```

**Evidence:**
- Verified: Test: test_entity_lifecycle.lua::ecs.cache.get_after_destroy

#### destroy-cache-cleared
- doc_id: pattern:ecs.destroy.cache_cleared
- Test: test_entity_lifecycle.lua::ecs.destroy.cache_cleared
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When destroying entities, invalidate cached components so later lookups do not return stale data.

**Root cause:**
component_cache can retain destroyed entries unless explicitly cleared.

**Solution:**
```lua
registry:destroy(eid)
component_cache.invalidate(eid)
```

**Anti-pattern:**
```lua
registry:destroy(eid)
-- cache not invalidated
```

**Evidence:**
- Verified: Test: test_entity_lifecycle.lua::ecs.destroy.cache_cleared

#### destroy-cleanup-references
- doc_id: pattern:ecs.destroy.cleanup_all_references
- Test: test_entity_lifecycle.lua::ecs.destroy.cleanup_all_references
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When destroying entities, remove timer, signal, and parent-child references to avoid callbacks hitting dead entities.

**Root cause:**
Timers and signals keep references alive after destroy; cleanup prevents late callbacks.

**Solution:**
```lua
registry:destroy(eid)
timer.cancel(timer_handle)
entity_links.unlink(eid)
```

**Anti-pattern:**
```lua
registry:destroy(eid)
-- timers and links still reference eid
```

**Evidence:**
- Verified: Test: test_entity_lifecycle.lua::ecs.destroy.cleanup_all_references

#### destroy-no-stale-refs
- doc_id: pattern:ecs.destroy.no_stale_refs
- Test: test_entity_lifecycle.lua::ecs.destroy.no_stale_refs
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When destroying entities, clear external references because stale ids can reappear and point at new entities.

**Root cause:**
Entt can reuse ids; stale references can mutate unrelated entities.

**Solution:**
```lua
registry:destroy(eid)
component_cache.invalidate(eid)
ref = nil
```

**Anti-pattern:**
```lua
registry:destroy(eid)
-- ref still used later
```

**Evidence:**
- Verified: Test: test_entity_lifecycle.lua::ecs.destroy.no_stale_refs

#### ensure-entity-invalid
- doc_id: pattern:ecs.validate.ensure_entity_invalid
- Test: test_entity_lifecycle.lua::ecs.validate.ensure_entity_invalid
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When ensure_entity returns false, stop processing because the entity id is invalid and any component access will be stale.

**Root cause:**
Invalid entity ids can point to destroyed entities; guard before using component_cache.

**Solution:**
```lua
if not ensure_entity(eid) then return end
local t = component_cache.get(eid, Transform)
```

**Anti-pattern:**
```lua
local t = component_cache.get(eid, Transform) -- no validity check
```

**Evidence:**
- Verified: Test: test_entity_lifecycle.lua::ecs.validate.ensure_entity_invalid

#### ensure-entity-nil
- doc_id: pattern:ecs.validate.ensure_entity_nil
- Test: Unverified: no test
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When ensure_entity receives entt_null or nil, treat it as invalid and return early.

**Root cause:**
nil or entt_null ids are never valid; short-circuit prevents invalid lookups.

**Solution:**
```lua
if not ensure_entity(eid) then return end
```

**Anti-pattern:**
```lua
local t = component_cache.get(eid, Transform) -- eid may be nil
```

**Evidence:**
- Unverified: unverified

#### ensure-scripted-entity-invalid
- doc_id: pattern:ecs.validate.ensure_scripted_entity_invalid
- Test: test_entity_lifecycle.lua::ecs.validate.ensure_scripted_entity_invalid
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When ensure_scripted_entity returns false, do not access script tables because ScriptComponent is missing.

**Root cause:**
Script lookups fail when ScriptComponent is missing; guard with ensure_scripted_entity.

**Solution:**
```lua
if not ensure_scripted_entity(eid) then return end
local script = safe_script_get(eid)
```

**Anti-pattern:**
```lua
local script = safe_script_get(eid) -- eid may not be scripted
```

**Evidence:**
- Verified: Test: test_entity_lifecycle.lua::ecs.validate.ensure_scripted_entity_invalid

#### safe-script-get-invalid
- doc_id: pattern:ecs.access.safe_script_get_invalid
- Test: test_entity_lifecycle.lua::ecs.access.safe_script_get_invalid
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When safe_script_get returns nil, abort script logic because the entity is invalid or missing ScriptComponent.

**Root cause:**
safe_script_get fails on invalid entities; continuing with nil scripts causes crashes.

**Solution:**
```lua
local script = safe_script_get(eid)
if not script then return end
```

**Anti-pattern:**
```lua
local script = safe_script_get(eid)
script.health = 0 -- script may be nil
```

**Evidence:**
- Verified: Test: test_entity_lifecycle.lua::ecs.access.safe_script_get_invalid

#### safe-script-get-nil
- doc_id: pattern:ecs.access.safe_script_get_nil
- Test: Unverified: no test
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When safe_script_get returns nil for entt_null, skip logic because the entity is not scripted.

**Root cause:**
nil scripts are expected for invalid ids; continue only when script exists.

**Solution:**
```lua
local script = safe_script_get(eid)
if not script then return end
```

**Anti-pattern:**
```lua
local script = safe_script_get(eid)
script:tick()
```

**Evidence:**
- Unverified: unverified

#### script-field-nil-default
- doc_id: pattern:ecs.access.script_field_nil
- Test: test_entity_lifecycle.lua::ecs.access.script_field_nil
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When script_field is used with a nil default, treat missing fields as intentional nil to avoid unintended fallbacks.

**Root cause:**
script_field returns the provided default even if it is nil; callers must handle nil explicitly.

**Solution:**
```lua
local mana = script_field(eid, "mana", nil)
if mana == nil then return end
```

**Anti-pattern:**
```lua
local mana = script_field(eid, "mana", nil)
-- assume mana is always a number
```

**Evidence:**
- Verified: Test: test_entity_lifecycle.lua::ecs.access.script_field_nil

### Lua / C++ Bindings

#### binding-addshaderpass
- doc_id: pattern:binding.addshaderpass
- Test: Unverified: binding docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When calling addShaderPass, pass arguments in the bound order because the C++ binding does not validate optional parameters.

**Root cause:**
Binding signatures are strict; argument mismatches cause runtime errors or silent misbehavior.

**Solution:**
```lua
-- addShaderPass usage
addShaderPass(...)
```

**Anti-pattern:**
```lua
-- missing required args
addShaderPass()
```

**Evidence:**
- Unverified: unverified

#### binding-layertbl.createlayer
- doc_id: pattern:binding.layertbl.createlayer
- Test: Unverified: binding docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When calling layerTbl.CreateLayer, pass arguments in the bound order because the C++ binding does not validate optional parameters.

**Root cause:**
Binding signatures are strict; argument mismatches cause runtime errors or silent misbehavior.

**Solution:**
```lua
-- layerTbl.CreateLayer usage
layerTbl.CreateLayer(...)
```

**Anti-pattern:**
```lua
-- missing required args
layerTbl.CreateLayer()
```

**Evidence:**
- Unverified: unverified

#### binding-layertbl.updatelayerzindex
- doc_id: pattern:binding.layertbl.updatelayerzindex
- Test: Unverified: binding docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When calling layerTbl.UpdateLayerZIndex, pass arguments in the bound order because the C++ binding does not validate optional parameters.

**Root cause:**
Binding signatures are strict; argument mismatches cause runtime errors or silent misbehavior.

**Solution:**
```lua
-- layerTbl.UpdateLayerZIndex usage
layerTbl.UpdateLayerZIndex(...)
```

**Anti-pattern:**
```lua
-- missing required args
layerTbl.UpdateLayerZIndex()
```

**Evidence:**
- Unverified: unverified

#### binding-physics_table.clear_pair_handlers
- doc_id: pattern:binding.physics_table.clear_pair_handlers
- Test: Unverified: binding docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When calling physics_table.clear_pair_handlers, pass arguments in the bound order because the C++ binding does not validate optional parameters.

**Root cause:**
Binding signatures are strict; argument mismatches cause runtime errors or silent misbehavior.

**Solution:**
```lua
-- physics_table.clear_pair_handlers usage
physics_table.clear_pair_handlers(...)
```

**Anti-pattern:**
```lua
-- missing required args
physics_table.clear_pair_handlers()
```

**Evidence:**
- Unverified: unverified

#### binding-physics_table.disable_collision_between
- doc_id: pattern:binding.physics_table.disable_collision_between
- Test: Unverified: binding docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When calling physics_table.disable_collision_between, pass arguments in the bound order because the C++ binding does not validate optional parameters.

**Root cause:**
Binding signatures are strict; argument mismatches cause runtime errors or silent misbehavior.

**Solution:**
```lua
-- physics_table.disable_collision_between usage
physics_table.disable_collision_between(...)
```

**Anti-pattern:**
```lua
-- missing required args
physics_table.disable_collision_between()
```

**Evidence:**
- Unverified: unverified

#### binding-physics_table.enable_collision_between
- doc_id: pattern:binding.physics_table.enable_collision_between
- Test: Unverified: binding docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When calling physics_table.enable_collision_between, pass arguments in the bound order because the C++ binding does not validate optional parameters.

**Root cause:**
Binding signatures are strict; argument mismatches cause runtime errors or silent misbehavior.

**Solution:**
```lua
-- physics_table.enable_collision_between usage
physics_table.enable_collision_between(...)
```

**Anti-pattern:**
```lua
-- missing required args
physics_table.enable_collision_between()
```

**Evidence:**
- Unverified: unverified

#### binding-physics_table.on_pair_begin
- doc_id: pattern:binding.physics_table.on_pair_begin
- Test: Unverified: binding docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When calling physics_table.on_pair_begin, pass arguments in the bound order because the C++ binding does not validate optional parameters.

**Root cause:**
Binding signatures are strict; argument mismatches cause runtime errors or silent misbehavior.

**Solution:**
```lua
-- physics_table.on_pair_begin usage
physics_table.on_pair_begin(...)
```

**Anti-pattern:**
```lua
-- missing required args
physics_table.on_pair_begin()
```

**Evidence:**
- Unverified: unverified

#### binding-physics_table.on_pair_postsolve
- doc_id: pattern:binding.physics_table.on_pair_postsolve
- Test: Unverified: binding docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When calling physics_table.on_pair_postsolve, pass arguments in the bound order because the C++ binding does not validate optional parameters.

**Root cause:**
Binding signatures are strict; argument mismatches cause runtime errors or silent misbehavior.

**Solution:**
```lua
-- physics_table.on_pair_postsolve usage
physics_table.on_pair_postsolve(...)
```

**Anti-pattern:**
```lua
-- missing required args
physics_table.on_pair_postsolve()
```

**Evidence:**
- Unverified: unverified

#### binding-physics_table.on_pair_presolve
- doc_id: pattern:binding.physics_table.on_pair_presolve
- Test: Unverified: binding docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When calling physics_table.on_pair_presolve, pass arguments in the bound order because the C++ binding does not validate optional parameters.

**Root cause:**
Binding signatures are strict; argument mismatches cause runtime errors or silent misbehavior.

**Solution:**
```lua
-- physics_table.on_pair_presolve usage
physics_table.on_pair_presolve(...)
```

**Anti-pattern:**
```lua
-- missing required args
physics_table.on_pair_presolve()
```

**Evidence:**
- Unverified: unverified

#### binding-physics_table.on_pair_separate
- doc_id: pattern:binding.physics_table.on_pair_separate
- Test: Unverified: binding docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When calling physics_table.on_pair_separate, pass arguments in the bound order because the C++ binding does not validate optional parameters.

**Root cause:**
Binding signatures are strict; argument mismatches cause runtime errors or silent misbehavior.

**Solution:**
```lua
-- physics_table.on_pair_separate usage
physics_table.on_pair_separate(...)
```

**Anti-pattern:**
```lua
-- missing required args
physics_table.on_pair_separate()
```

**Evidence:**
- Unverified: unverified

#### binding-physics_table.reapply_all_filters
- doc_id: pattern:binding.physics_table.reapply_all_filters
- Test: Unverified: binding docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When calling physics_table.reapply_all_filters, pass arguments in the bound order because the C++ binding does not validate optional parameters.

**Root cause:**
Binding signatures are strict; argument mismatches cause runtime errors or silent misbehavior.

**Solution:**
```lua
-- physics_table.reapply_all_filters usage
physics_table.reapply_all_filters(...)
```

**Anti-pattern:**
```lua
-- missing required args
physics_table.reapply_all_filters()
```

**Evidence:**
- Unverified: unverified

#### binding-physics_table.set_collision_tags
- doc_id: pattern:binding.physics_table.set_collision_tags
- Test: Unverified: binding docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When calling physics_table.set_collision_tags, pass arguments in the bound order because the C++ binding does not validate optional parameters.

**Root cause:**
Binding signatures are strict; argument mismatches cause runtime errors or silent misbehavior.

**Solution:**
```lua
-- physics_table.set_collision_tags usage
physics_table.set_collision_tags(...)
```

**Anti-pattern:**
```lua
-- missing required args
physics_table.set_collision_tags()
```

**Evidence:**
- Unverified: unverified

#### binding-physics_table.update_collision_masks_for
- doc_id: pattern:binding.physics_table.update_collision_masks_for
- Test: Unverified: binding docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When calling physics_table.update_collision_masks_for, pass arguments in the bound order because the C++ binding does not validate optional parameters.

**Root cause:**
Binding signatures are strict; argument mismatches cause runtime errors or silent misbehavior.

**Solution:**
```lua
-- physics_table.update_collision_masks_for usage
physics_table.update_collision_masks_for(...)
```

**Anti-pattern:**
```lua
-- missing required args
physics_table.update_collision_masks_for()
```

**Evidence:**
- Unverified: unverified

#### binding-sh.loadshadersfromjson
- doc_id: pattern:binding.sh.loadshadersfromjson
- Test: Unverified: binding docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When calling sh.loadShadersFromJSON, pass arguments in the bound order because the C++ binding does not validate optional parameters.

**Root cause:**
Binding signatures are strict; argument mismatches cause runtime errors or silent misbehavior.

**Solution:**
```lua
-- sh.loadShadersFromJSON usage
sh.loadShadersFromJSON(...)
```

**Anti-pattern:**
```lua
-- missing required args
sh.loadShadersFromJSON()
```

**Evidence:**
- Unverified: unverified

#### binding-sp.loadfromfile
- doc_id: pattern:binding.sp.loadfromfile
- Test: Unverified: binding docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When calling sp.loadFromFile, pass arguments in the bound order because the C++ binding does not validate optional parameters.

**Root cause:**
Binding signatures are strict; argument mismatches cause runtime errors or silent misbehavior.

**Solution:**
```lua
-- sp.loadFromFile usage
sp.loadFromFile(...)
```

**Anti-pattern:**
```lua
-- missing required args
sp.loadFromFile()
```

**Evidence:**
- Unverified: unverified

#### binding-t.after
- doc_id: pattern:binding.t.after
- Test: Unverified: binding docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When calling t.after, pass arguments in the bound order because the C++ binding does not validate optional parameters.

**Root cause:**
Binding signatures are strict; argument mismatches cause runtime errors or silent misbehavior.

**Solution:**
```lua
-- t.after usage
t.after(...)
```

**Anti-pattern:**
```lua
-- missing required args
t.after()
```

**Evidence:**
- Unverified: unverified

#### binding-t.cancel
- doc_id: pattern:binding.t.cancel
- Test: Unverified: binding docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When calling t.cancel, pass arguments in the bound order because the C++ binding does not validate optional parameters.

**Root cause:**
Binding signatures are strict; argument mismatches cause runtime errors or silent misbehavior.

**Solution:**
```lua
-- t.cancel usage
t.cancel(...)
```

**Anti-pattern:**
```lua
-- missing required args
t.cancel()
```

**Evidence:**
- Unverified: unverified

#### binding-t.every
- doc_id: pattern:binding.t.every
- Test: Unverified: binding docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When calling t.every, pass arguments in the bound order because the C++ binding does not validate optional parameters.

**Root cause:**
Binding signatures are strict; argument mismatches cause runtime errors or silent misbehavior.

**Solution:**
```lua
-- t.every usage
t.every(...)
```

**Anti-pattern:**
```lua
-- missing required args
t.every()
```

**Evidence:**
- Unverified: unverified

#### binding-t.run_every_render_frame
- doc_id: pattern:binding.t.run_every_render_frame
- Test: Unverified: binding docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When calling t.run_every_render_frame, pass arguments in the bound order because the C++ binding does not validate optional parameters.

**Root cause:**
Binding signatures are strict; argument mismatches cause runtime errors or silent misbehavior.

**Solution:**
```lua
-- t.run_every_render_frame usage
t.run_every_render_frame(...)
```

**Anti-pattern:**
```lua
-- missing required args
t.run_every_render_frame()
```

**Evidence:**
- Unverified: unverified

#### binding-t.update
- doc_id: pattern:binding.t.update
- Test: Unverified: binding docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When calling t.update, pass arguments in the bound order because the C++ binding does not validate optional parameters.

**Root cause:**
Binding signatures are strict; argument mismatches cause runtime errors or silent misbehavior.

**Solution:**
```lua
-- t.update usage
t.update(...)
```

**Anti-pattern:**
```lua
-- missing required args
t.update()
```

**Evidence:**
- Unverified: unverified

### Physics Patterns

#### physics-add-collider
- doc_id: pattern:physics.add_collider
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When adding colliders, create physics first and then call AddCollider with correct shape and sensor flags.

**Root cause:**
Collider creation depends on physics bodies; calling before setup creates invalid shapes.

**Solution:**
```lua
physics.AddCollider(world, entity, "player", "rectangle", 32, 48, 0, 0, false)
```

**Anti-pattern:**
```lua
physics.AddCollider(world, entity, "player", "rectangle", 32, 48, 0, 0, false) -- no body
```

**Evidence:**
- Unverified: unverified

#### physics-add-shape
- doc_id: pattern:physics.add_shape_to_entity
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When adding extra shapes, use add_shape_to_entity so the body and primary shape stay consistent.

**Root cause:**
Multi-shape bodies require consistent bookkeeping that helpers provide.

**Solution:**
```lua
physics.add_shape_to_entity(world, entity, "player", "circle", 16, 0, 0, 0, false)
```

**Anti-pattern:**
```lua
-- manually attach shapes without tracking indices
```

**Evidence:**
- Unverified: unverified

#### physics-builder-basic-chain
- doc_id: pattern:core.physics_builder.basic_chain
- Test: test_core_patterns.lua::core.physics_builder.basic_chain
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When setting up physics on an entity, use PhysicsBuilder to apply colliders, tags, and masks in one chain.

**Root cause:**
PhysicsBuilder centralizes collider configuration and reduces missing tag or mask setup.

**Solution:**
```lua
PhysicsBuilder.for_entity(entity):circle():tag("projectile"):bullet():collideWith({ "enemy", "WORLD" }):apply()
```

**Anti-pattern:**
```lua
-- collider configured without tags or masks
```

**Evidence:**
- Verified: Test: test_core_patterns.lua::core.physics_builder.basic_chain

#### physics-create-from-transform
- doc_id: pattern:physics.create_physics_for_transform
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When creating physics from transforms, call create_physics_for_transform with proper shape config.

**Root cause:**
Transform-backed physics ensures colliders align with visual positions.

**Solution:**
```lua
physics.create_physics_for_transform(registry, PhysicsManager, entity, { shape = "rectangle", tag = "player" })
```

**Anti-pattern:**
```lua
-- manually create body without syncing to transform
```

**Evidence:**
- Unverified: unverified

#### physics-enable-collision-between
- doc_id: pattern:physics.enable_collision_between
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When enabling collisions between groups, use enable_collision_between or enable_collision_between_many to keep masks consistent.

**Root cause:**
Centralizing mask updates prevents missing pairings when new tags are added.

**Solution:**
```lua
physics.enable_collision_between(world, "player", { "enemy", "terrain" })
```

**Anti-pattern:**
```lua
-- manually toggling shape masks without updating tag list
```

**Evidence:**
- Unverified: unverified

#### physics-entity-from-ptr
- doc_id: pattern:physics.raycast_entity_from_ptr
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When converting raycast hits, use entity_from_ptr to map shape or body pointers back to entities.

**Root cause:**
Hit structures expose raw pointers; entity_from_ptr restores entity ids safely.

**Solution:**
```lua
local e = physics.entity_from_ptr(hit.shape)
```

**Anti-pattern:**
```lua
-- treat hit.shape as an entity id
```

**Evidence:**
- Unverified: unverified

#### physics-segment-query
- doc_id: pattern:physics.segment_query_with_callback
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When running segment queries, use the provided callback pattern so you can terminate or continue properly.

**Root cause:**
Segment queries require callback return values to control traversal.

**Solution:**
```lua
physics.segment_query_first(world, from, to, function(hit) return true end)
```

**Anti-pattern:**
```lua
-- ignoring callback return value
```

**Evidence:**
- Unverified: unverified

#### physics-set-collision-tags
- doc_id: pattern:physics.set_collision_tags
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When defining collision categories, register tags and masks before spawning bodies so filters apply to existing shapes.

**Root cause:**
Collision tags must be defined before filters are applied to shapes.

**Solution:**
```lua
physics.set_collision_tags(world, { "player", "enemy", "terrain" })
```

**Anti-pattern:**
```lua
-- spawn shapes before tags are registered
```

**Evidence:**
- Unverified: unverified

#### physics-update-collision-masks
- doc_id: pattern:physics.update_collision_masks_for
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When changing mask rules at runtime, call update_collision_masks_for to reapply filters to existing shapes.

**Root cause:**
Existing shapes keep old filters unless masks are reapplied.

**Solution:**
```lua
physics.update_collision_masks_for(world, "player", { "enemy", "terrain" })
```

**Anti-pattern:**
```lua
-- update tag list without reapplying masks
```

**Evidence:**
- Unverified: unverified

#### physics-world-create
- doc_id: pattern:physics.world_create
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When creating a physics world, pass meter scale and gravity at initialization for consistent simulation units.

**Root cause:**
Consistent unit scaling avoids mismatched forces and collider sizes.

**Solution:**
```lua
local world = physics.PhysicsWorld(registry, 64.0, 0.0, 900.0)
```

**Anti-pattern:**
```lua
local world = physics.PhysicsWorld(registry, 1.0, 0.0, 900.0) -- inconsistent scale
```

**Evidence:**
- Unverified: unverified

### Rendering Patterns

#### render-batch-group
- doc_id: pattern:render.batch_group.use
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When batching draw commands, keep batch group ids stable to avoid flickering ordering.

**Root cause:**
Stable batch ids ensure deterministic sorting and grouping in the renderer.

**Solution:**
```lua
command_buffer.queueDraw(layers.ui, fn, 0, layer.DrawCommandSpace.Screen, "inventory")
```

**Anti-pattern:**
```lua
-- dynamic batch ids per frame
```

**Evidence:**
- Unverified: unverified

#### render-command-buffer
- doc_id: pattern:render.command_buffer.queue_draw
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When issuing draw calls, enqueue them through the command buffer for deterministic render order.

**Root cause:**
Command buffers centralize draw order and layer sorting.

**Solution:**
```lua
command_buffer.queueDraw(layers.ui, fn, 0, layer.DrawCommandSpace.Screen)
```

**Anti-pattern:**
```lua
-- call draw functions directly outside command buffer
```

**Evidence:**
- Unverified: unverified

#### render-draw-space-screen
- doc_id: pattern:render.drawcommandspace.screen
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When drawing HUD elements, use DrawCommandSpace.Screen to keep them fixed to the viewport.

**Root cause:**
Screen space commands ignore camera transforms and keep UI stable.

**Solution:**
```lua
command_buffer.queueDraw(layers.ui, fn, 0, layer.DrawCommandSpace.Screen)
```

**Anti-pattern:**
```lua
command_buffer.queueDraw(layers.ui, fn, 0, layer.DrawCommandSpace.World)
```

**Evidence:**
- Unverified: unverified

#### render-draw-space-world
- doc_id: pattern:render.drawcommandspace.world
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When drawing world-space visuals, use DrawCommandSpace.World so they track camera transforms.

**Root cause:**
World space commands align with camera and physics coordinates.

**Solution:**
```lua
command_buffer.queueDraw(layers.world, fn, 0, layer.DrawCommandSpace.World)
```

**Anti-pattern:**
```lua
-- using screen space for world objects
```

**Evidence:**
- Unverified: unverified

#### render-global-uniforms
- doc_id: pattern:render.global_uniforms.before_draw
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When using global shader uniforms, update them before enqueuing draw commands.

**Root cause:**
Uniform changes after queueing will not affect already captured draw state.

**Solution:**
```lua
globalShaderUniforms.time = t
command_buffer.queueDraw(...)
```

**Anti-pattern:**
```lua
command_buffer.queueDraw(...)
globalShaderUniforms.time = t
```

**Evidence:**
- Unverified: unverified

#### render-groups-register
- doc_id: pattern:render.render_groups.register
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When grouping renderables, create render groups and update them via render group helpers.

**Root cause:**
Render groups keep related entities on consistent layers and z offsets.

**Solution:**
```lua
layerTbl.CreateLayer("ui")
render_groups.register("inventory", layers.ui)
```

**Anti-pattern:**
```lua
-- ad hoc layer assignment without grouping
```

**Evidence:**
- Unverified: unverified

#### render-layer-z-order
- doc_id: pattern:render.layer_z_order
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When ordering draw layers, update layer Z indices so higher layers draw last.

**Root cause:**
Explicit Z ordering prevents UI or effects from drawing under gameplay layers.

**Solution:**
```lua
layerTbl.UpdateLayerZIndex(layers.ui, 200)
```

**Anti-pattern:**
```lua
-- rely on default ordering without updating Z
```

**Evidence:**
- Unverified: unverified

#### render-shader-pipeline-attach
- doc_id: pattern:render.shader_pipeline.attach
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When building shader pipelines, attach passes before setting uniforms to avoid missing references.

**Root cause:**
Uniforms are stored per pass; passes must exist before applying values.

**Solution:**
```lua
addShaderPass(pipeline, "glow")
sh.ApplyUniformsToShader(pipeline, uniforms)
```

**Anti-pattern:**
```lua
sh.ApplyUniformsToShader(pipeline, uniforms) -- no passes yet
```

**Evidence:**
- Unverified: unverified

#### render-transform-local
- doc_id: pattern:render.transform_local_callback
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When using transform-local render callbacks, ensure transforms are updated before rendering.

**Root cause:**
Local render callbacks rely on up-to-date transforms to compute offsets.

**Solution:**
```lua
update_transforms()
render_local_callbacks()
```

**Anti-pattern:**
```lua
render_local_callbacks() -- transforms not updated
```

**Evidence:**
- Unverified: unverified

#### shader-builder-add-apply
- doc_id: pattern:core.shader_builder.add_apply
- Test: test_core_patterns.lua::core.shader_builder.add_apply
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When applying shaders, use ShaderBuilder.add(...):apply() to ensure the pipeline component is attached.

**Root cause:**
ShaderBuilder ensures shader passes are attached and configured before draw.

**Solution:**
```lua
ShaderBuilder.for_entity(entity):add("3d_skew_holo"):apply()
```

**Anti-pattern:**
```lua
-- set shader name without attaching ShaderPipelineComponent
```

**Evidence:**
- Verified: Test: test_core_patterns.lua::core.shader_builder.add_apply

### Combat Patterns

#### combat-ability-cost
- doc_id: pattern:combat.ability.cost_check
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When executing abilities, verify resource costs before resolving effects to avoid negative resources.

**Root cause:**
Cost validation prevents abilities from firing when resources are insufficient.

**Solution:**
```lua
if can_pay_cost(caster, cost) then pay_cost(caster, cost) end
```

**Anti-pattern:**
```lua
pay_cost(caster, cost) -- no check
```

**Evidence:**
- Unverified: unverified

#### combat-buff-order
- doc_id: pattern:combat.buff.application_order
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When applying buffs and debuffs, process application order before damage to ensure correct scaling.

**Root cause:**
Buff order affects damage outcomes and status calculations.

**Solution:**
```lua
apply_buffs(attacker)
apply_damage(target)
```

**Anti-pattern:**
```lua
apply_damage(target)
apply_buffs(attacker)
```

**Evidence:**
- Unverified: unverified

#### combat-damage-bundle
- doc_id: pattern:combat.damage_bundle.create
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When dealing damage, construct a DamageBundle with base damage and modifiers before applying resistances.

**Root cause:**
Bundling damage values keeps modifiers and resistances applied consistently.

**Solution:**
```lua
local bundle = DamageBundle.new(base, modifiers)
combat.apply_damage(target, bundle)
```

**Anti-pattern:**
```lua
combat.apply_damage(target, base) -- no modifiers
```

**Evidence:**
- Unverified: unverified

#### combat-damage-resist
- doc_id: pattern:combat.damage.apply_resist
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When applying damage, run resist calculations before reducing health.

**Root cause:**
Resist calculations change final damage and should be applied consistently.

**Solution:**
```lua
local final = apply_resist(target, bundle)
apply_damage(target, final)
```

**Anti-pattern:**
```lua
apply_damage(target, bundle) -- no resist
```

**Evidence:**
- Unverified: unverified

#### combat-effect-graph
- doc_id: pattern:combat.effect_graph.resolve
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When resolving effect graphs, process nodes deterministically to keep combat outcomes stable.

**Root cause:**
Deterministic resolution prevents order-dependent bugs in combat logic.

**Solution:**
```lua
effect_graph.resolve(sequence)
```

**Anti-pattern:**
```lua
-- iterate nodes in unordered table
```

**Evidence:**
- Unverified: unverified

#### combat-event-on-hit
- doc_id: pattern:combat.event.emit_on_hit
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When processing hits, emit combat events so downstream systems can react.

**Root cause:**
Combat events drive VFX, UI updates, and triggers.

**Solution:**
```lua
combat_bus.emit("hit", attacker, target, bundle)
```

**Anti-pattern:**
```lua
apply_damage(target, bundle) -- no event
```

**Evidence:**
- Unverified: unverified

#### combat-projectile-lifecycle
- doc_id: pattern:combat.projectile.lifecycle
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When spawning projectiles, register them with the combat system and clean them up on hit or timeout.

**Root cause:**
Projectile lifecycle management prevents orphan entities and missed hit processing.

**Solution:**
```lua
local proj = spawn_projectile(params)
projectile_system.register(proj)
```

**Anti-pattern:**
```lua
spawn_projectile(params) -- not registered
```

**Evidence:**
- Unverified: unverified

#### combat-projectile-remove
- doc_id: pattern:combat.projectile.remove_on_hit
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When projectiles hit, remove them immediately to prevent double hits.

**Root cause:**
Leaving projectiles alive risks repeated collisions and duplicate effects.

**Solution:**
```lua
on_hit(function(p) destroy_projectile(p) end)
```

**Anti-pattern:**
```lua
-- projectile keeps moving after hit
```

**Evidence:**
- Unverified: unverified

#### combat-status-stacking
- doc_id: pattern:combat.status.stack_rules
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When stacking status effects, enforce stack limits and refresh timers rather than duplicating entries.

**Root cause:**
Stack rules keep buffs predictable and prevent runaway power scaling.

**Solution:**
```lua
status.apply_or_refresh(target, status_id, stacks)
```

**Anti-pattern:**
```lua
status.apply(target, status_id) -- duplicates without refresh
```

**Evidence:**
- Unverified: unverified

#### combat-target-filter
- doc_id: pattern:combat.target.filter_alive
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When selecting targets, filter for alive entities and valid teams before applying effects.

**Root cause:**
Filtering prevents applying effects to dead or invalid targets.

**Solution:**
```lua
local targets = filter_alive(team_targets)
```

**Anti-pattern:**
```lua
local targets = team_targets -- includes dead
```

**Evidence:**
- Unverified: unverified

### Timer Patterns

#### timer-after-basic
- doc_id: pattern:core.timer.after_basic
- Test: test_core_patterns.lua::core.timer.after_basic
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When scheduling delayed work, use timer.after with a small callback to keep logic deterministic.

**Root cause:**
timer.after provides a consistent delayed callback hook.

**Solution:**
```lua
local tag = timer.after(0.5, function() do_work() end)
```

**Anti-pattern:**
```lua
-- manual frame countdown scattered across update loops
```

**Evidence:**
- Verified: Test: test_core_patterns.lua::core.timer.after_basic

#### timer-cancel-on-cleanup
- doc_id: pattern:timer.cancel_on_cleanup
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When a delayed action can be canceled, store the timer handle and cancel it on cleanup.

**Root cause:**
Canceling timers prevents callbacks after entities are destroyed.

**Solution:**
```lua
local handle = timer.after(1.0, fn)
timer.cancel(handle)
```

**Anti-pattern:**
```lua
timer.after(1.0, fn) -- no cancel on cleanup
```

**Evidence:**
- Unverified: unverified

#### timer-every-guarded
- doc_id: pattern:core.timer.every_guarded_tick
- Test: test_core_patterns.lua::core.timer.every_guarded_tick
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When running repeated ticks, guard timer.every callbacks with validity checks to prevent stale entity work.

**Root cause:**
Guarded callbacks stop timers when entities are destroyed.

**Solution:**
```lua
timer.every(interval, function() if not entity_cache.valid(e) then return false end end)
```

**Anti-pattern:**
```lua
timer.every(interval, function() use_entity(e) end)
```

**Evidence:**
- Verified: Test: test_core_patterns.lua::core.timer.every_guarded_tick

#### timer-group-cancel
- doc_id: pattern:timer.group_cancel
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When managing groups of timers, use a shared tag or group id for bulk cancellation.

**Root cause:**
Grouping timers simplifies cleanup and avoids leaks.

**Solution:**
```lua
local tag = timer.every(1.0, fn, 0, false, nil, "ui")
timer.cancel(tag)
```

**Anti-pattern:**
```lua
-- individual timers without group cleanup
```

**Evidence:**
- Unverified: unverified

#### timer-tween-scalar
- doc_id: pattern:core.timer.tween_scalar
- Test: test_core_patterns.lua::core.timer.tween_scalar
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When tweening scalar values, use timer.tween_scalar with getter and setter functions.

**Root cause:**
tween_scalar provides deterministic interpolation with explicit getters and setters.

**Solution:**
```lua
timer.tween_scalar(duration, getter, setter, target)
```

**Anti-pattern:**
```lua
-- manual interpolation with inconsistent dt
```

**Evidence:**
- Verified: Test: test_core_patterns.lua::core.timer.tween_scalar

### Signal Patterns

#### signal-emit
- doc_id: pattern:core.signal.emit
- Test: test_core_patterns.lua::core.signal.emit
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When emitting events, use signal.emit with explicit parameters to keep handlers consistent.

**Root cause:**
signal.emit sends arguments to all handlers in a predictable order.

**Solution:**
```lua
signal.emit("grid_transfer_failed", item, from, to, reason)
```

**Anti-pattern:**
```lua
-- direct handler calls without signal bus
```

**Evidence:**
- Verified: Test: test_core_patterns.lua::core.signal.emit

#### signal-event-bridge
- doc_id: pattern:core.event_bridge.attach
- Test: test_core_patterns.lua::core.event_bridge.attach
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When bridging bus events to signals, call EventBridge.attach to connect the systems.

**Root cause:**
EventBridge attaches signal forwarding to the shared event bus.

**Solution:**
```lua
local EventBridge = require("core.event_bridge")
EventBridge.attach(ctx)
```

**Anti-pattern:**
```lua
-- emit bus events without signal bridge
```

**Evidence:**
- Verified: Test: test_core_patterns.lua::core.event_bridge.attach

#### signal-group-cleanup
- doc_id: pattern:core.signal_group.cleanup
- Test: test_core_patterns.lua::core.signal_group.cleanup
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When managing multiple listeners, use SignalGroup and call cleanup to unregister them.

**Root cause:**
SignalGroup keeps related listeners together and cleans them in one call.

**Solution:**
```lua
local group = SignalGroup.new("menu")
group:on("game_state_changed", handler)
group:cleanup()
```

**Anti-pattern:**
```lua
-- listeners registered without cleanup
```

**Evidence:**
- Verified: Test: test_core_patterns.lua::core.signal_group.cleanup

#### signal-register
- doc_id: pattern:core.signal.register
- Test: test_core_patterns.lua::core.signal.register
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When registering listeners, use signal.register and store the handler for cleanup.

**Root cause:**
Registering through the signal bus centralizes event handling.

**Solution:**
```lua
signal.register("character_select_opened", function() setMainMenuVisible(false) end)
```

**Anti-pattern:**
```lua
-- ad hoc event tables without unregister
```

**Evidence:**
- Verified: Test: test_core_patterns.lua::core.signal.register

#### signal-unregister
- doc_id: pattern:signal.unregister
- Test: Unverified: docs only
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When listeners are no longer needed, unregister them to prevent duplicate callbacks.

**Root cause:**
Unregistering keeps handler lists short and avoids double firing.

**Solution:**
```lua
signal.remove("event_name", handler)
```

**Anti-pattern:**
```lua
-- leave handler registered forever
```

**Evidence:**
- Unverified: unverified

### Wand Patterns

#### wand-cumulative-stats
- doc_id: pattern:wand.cumulative_stats.apply
- Test: Unverified: wand_cumulative_test.lua
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When applying cumulative wand stats, recompute totals after all modifiers are attached.

**Root cause:**
Recomputing totals after modifiers avoids inconsistent stat displays.

**Solution:**
```lua
wand.recompute_stats(wand)
```

**Anti-pattern:**
```lua
-- use cached stats after adding modifiers
```

**Evidence:**
- Unverified: proposed

#### wand-system-integration
- doc_id: pattern:wand.system.integration
- Test: Unverified: wand_system_integration_test.lua
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When integrating wand systems, ensure the panel and runtime state stay synchronized.

**Root cause:**
UI and runtime state must remain consistent to avoid desync.

**Solution:**
```lua
wand_panel.sync_from_state(wand_state)
```

**Anti-pattern:**
```lua
-- update runtime without UI sync
```

**Evidence:**
- Unverified: proposed

#### wand-template-apply
- doc_id: pattern:wand.template.apply
- Test: Unverified: test_wand_templates_phase2.lua
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When creating wands, apply a template first so base stats and slots are initialized.

**Root cause:**
Templates establish baseline stats before custom modifications.

**Solution:**
```lua
local wand = wand_templates.apply(template_id, overrides)
```

**Anti-pattern:**
```lua
-- build wand stats without template baseline
```

**Evidence:**
- Unverified: proposed

#### wand-trigger-order
- doc_id: pattern:wand.trigger.phase_order
- Test: Unverified: test_wand_triggers_phase2.lua
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When firing spells, respect trigger ordering so phase effects resolve predictably.

**Root cause:**
Trigger ordering prevents spells from skipping or double-applying effects.

**Solution:**
```lua
wand.apply_triggers(wand, "pre")
wand.cast_spells(wand)
wand.apply_triggers(wand, "post")
```

**Anti-pattern:**
```lua
wand.cast_spells(wand) -- no trigger phases
```

**Evidence:**
- Unverified: proposed

#### wand-upgrade-apply
- doc_id: pattern:wand.upgrade.apply
- Test: Unverified: wand_upgrade_behavior_test.lua
- Source: planning/cm_rules_candidates.yaml

**Problem:**
When upgrading wands, apply upgrade behavior rules to preserve balance constraints.

**Root cause:**
Upgrade rules prevent invalid slot counts or stat overflows.

**Solution:**
```lua
wand_upgrades.apply(wand, upgrade_id)
```

**Anti-pattern:**
```lua
-- direct stat edits without upgrade rules
```

**Evidence:**
- Unverified: proposed
