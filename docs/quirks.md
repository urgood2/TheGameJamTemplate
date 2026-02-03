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
- [Physics System](#physics-system)
- [Rendering & Layers](#rendering--layers)
- [Shader System](#shader-system)
- [Sound System](#sound-system)
- [Camera System](#camera-system)
- [Animation System](#animation-system)
- [Combat System](#combat-system)
- [Input System](#input-system)

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
