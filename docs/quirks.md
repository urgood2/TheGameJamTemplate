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
- [Physics System](#physics-system)
- [Shader System](#shader-system)
- [Sound System](#sound-system)
- [Camera System](#camera-system)
- [Animation System](#animation-system)
- [Combat System](#combat-system)

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
### attach_ecs Timing (Assign Data Before Attach)
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
### GameObject Component Restrictions
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
### script_field and safe_script_get
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
### Entity Validation (ensure_entity vs ensure_scripted_entity)
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
### Component Cache Usage
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
### Entity Destruction & Cleanup
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
### LuaJIT 200 Local Variable Limit
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

### CM Rule Candidates (Entity Lifecycle)

Each rule references the quirks anchor and the test id in assets/scripts/tests/test_entity_lifecycle.lua.

1. rule_id: ecs-gotcha-001
   rule_text: When attaching scripts, always assign data before attach_ecs because attach-time hooks read fields immediately.
   doc_id: pattern:ecs.attach_ecs.assign_before_attach
   test_ref: test_entity_lifecycle.lua::ecs.attach_ecs.assign_before_attach
   quirks_anchor: ecs-attach-ecs-timing
   status: verified

2. rule_id: ecs-gotcha-002
   rule_text: Never store gameplay data on GameObject components; use the script table instead to keep data discoverable.
   doc_id: pattern:ecs.gameobject.no_data_storage
   test_ref: test_entity_lifecycle.lua::ecs.gameobject.no_data_storage
   quirks_anchor: ecs-gameobject-restrictions
   status: verified

3. rule_id: ecs-gotcha-003
   rule_text: Keep LuaJIT functions under ~200 locals by grouping values in tables to avoid crashes.
   doc_id: pattern:ecs.luajit.200_local_limit
   test_ref: test_entity_lifecycle.lua::ecs.luajit.200_local_limit
   quirks_anchor: ecs-luajit-locals
   status: verified

4. rule_id: ecs-pattern-001
   rule_text: Use Node.quick or EntityBuilder.validated to guarantee data assignment occurs before attach_ecs.
   doc_id: pattern:ecs.attach_ecs.assign_before_attach
   test_ref: test_entity_lifecycle.lua::ecs.attach_ecs.assign_before_attach
   quirks_anchor: ecs-attach-ecs-timing
   status: verified

5. rule_id: ecs-pattern-002
   rule_text: Store entity state on the script table so safe_script_get and script_field can retrieve it reliably.
   doc_id: pattern:ecs.gameobject.script_table_usage
   test_ref: test_entity_lifecycle.lua::ecs.gameobject.script_table_usage
   quirks_anchor: ecs-gameobject-restrictions
   status: verified

6. rule_id: ecs-pattern-003
   rule_text: Validate entity ids with ensure_entity before component or script access to avoid invalid lookups.
   doc_id: pattern:ecs.validate.ensure_entity_valid
   test_ref: test_entity_lifecycle.lua::ecs.validate.ensure_entity_valid
   quirks_anchor: ecs-validation
   status: verified

7. rule_id: ecs-pattern-004
   rule_text: Use ensure_scripted_entity when you require a ScriptComponent to avoid nil script tables.
   doc_id: pattern:ecs.validate.ensure_scripted_entity_valid
   test_ref: test_entity_lifecycle.lua::ecs.validate.ensure_scripted_entity_valid
   quirks_anchor: ecs-validation
   status: verified

8. rule_id: ecs-pattern-005
   rule_text: Use safe_script_get for script access and guard nil to prevent crashes on destroyed entities.
   doc_id: pattern:ecs.access.safe_script_get_valid
   test_ref: test_entity_lifecycle.lua::ecs.access.safe_script_get_valid
   quirks_anchor: ecs-script-access
   status: verified

9. rule_id: ecs-pattern-006
   rule_text: Prefer script_field(eid, field, default) to avoid nil checks and express defaults explicitly.
   doc_id: pattern:ecs.access.script_field_default
   test_ref: test_entity_lifecycle.lua::ecs.access.script_field_default
   quirks_anchor: ecs-script-access
   status: verified

10. rule_id: ecs-pattern-007
    rule_text: Use component_cache.get for hot paths instead of registry:get to avoid redundant lookups.
    doc_id: pattern:ecs.cache.get_valid
    test_ref: test_entity_lifecycle.lua::ecs.cache.get_valid
    quirks_anchor: ecs-component-cache
    status: verified

11. rule_id: ecs-gotcha-004
    rule_text: Invalidate component_cache entries on destroy or component removal to prevent stale data.
    doc_id: pattern:ecs.cache.invalidation
    test_ref: test_entity_lifecycle.lua::ecs.cache.invalidation
    quirks_anchor: ecs-component-cache
    status: verified

12. rule_id: ecs-pattern-008
    rule_text: After destroying entities, clear cached components to avoid stale reference bugs.
    doc_id: pattern:ecs.destroy.cache_cleared
    test_ref: test_entity_lifecycle.lua::ecs.destroy.cache_cleared
    quirks_anchor: ecs-destruction
    status: verified

13. rule_id: ecs-pattern-009
    rule_text: On destruction, revalidate references with safe_script_get or ensure_entity before reuse.
    doc_id: pattern:ecs.destroy.no_stale_refs
    test_ref: test_entity_lifecycle.lua::ecs.destroy.no_stale_refs
    quirks_anchor: ecs-destruction
    status: verified

14. rule_id: ecs-pattern-010
    rule_text: Destroy-then-recreate should produce a clean script table with no cached garbage.
    doc_id: pattern:ecs.destroy.then_recreate
    test_ref: test_entity_lifecycle.lua::ecs.destroy.then_recreate
    quirks_anchor: ecs-destruction
    status: verified

15. rule_id: ecs-gotcha-005
    rule_text: Attach-time callbacks (run_custom_func/addStateTag) require data assigned before attach_ecs.
    doc_id: pattern:ecs.attach_ecs.assign_before_attach
    test_ref: test_entity_lifecycle.lua::ecs.attach_ecs.assign_before_attach
    quirks_anchor: ecs-attach-ecs-timing
    status: verified

16. rule_id: ecs-pattern-011
    rule_text: Remove invalid entity references from registries or lists after destroy to avoid stale lookups.
    doc_id: pattern:ecs.destroy.cleanup_all_references
    test_ref: test_entity_lifecycle.lua::ecs.destroy.cleanup_all_references
    quirks_anchor: ecs-destruction
    status: verified

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
#### AddStateTagToUIBox after spawn
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
#### AddStateTagToUIBox after ReplaceChildren
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
#### Move both Transform and UIBoxComponent.uiRoot
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
#### Never use ObjectAttachedToUITag on draggables
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
#### ObjectAttachedToUITag correct usage
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

### UI Rule Candidates

1. rule_id: ui-gotcha-001
    rule_text: After ChildBuilder.setOffset, always call ui.box.RenewAlignment so child layout recomputes.
    doc_id: pattern:ui.uibox_alignment.renew_after_offset
    test_ref: test_ui_patterns.lua::ui.uibox_alignment.renew_after_offset
    quirks_anchor: renewalignment-after-setoffset
    status: verified

2. rule_id: ui-gotcha-002
    rule_text: After ReplaceChildren, call ui.box.RenewAlignment to avoid mispositioned children.
    doc_id: pattern:ui.uibox_alignment.renew_after_replacechildren
    test_ref: test_ui_patterns.lua::ui.uibox_alignment.renew_after_replacechildren
    quirks_anchor: renewalignment-after-replacechildren
    status: verified

3. rule_id: ui-gotcha-003
    rule_text: Add state tags after UIBox spawn to enable hover/pressed styling.
    doc_id: pattern:ui.statetag.add_after_spawn
    test_ref: test_ui_patterns.lua::ui.statetag.add_after_spawn
    quirks_anchor: addstatetagto-uibox-after-spawn
    status: verified

4. rule_id: ui-gotcha-004
    rule_text: Re-apply AddStateTagToUIBox after ReplaceChildren because tags are cleared.
    doc_id: pattern:ui.statetag.add_after_replacechildren
    test_ref: test_ui_patterns.lua::ui.statetag.add_after_replacechildren
    quirks_anchor: addstatetagto-uibox-after-replacechildren
    status: verified

5. rule_id: ui-gotcha-005
    rule_text: Reapply state tags whenever the UI tree is rebuilt to preserve state transitions.
    doc_id: pattern:ui.statetag.persistence_check
    test_ref: test_ui_patterns.lua::ui.statetag.persistence_check
    quirks_anchor: state-tag-persistence-check
    status: verified

6. rule_id: ui-gotcha-006
    rule_text: Move both Transform and UIBoxComponent.uiRoot when relocating panels.
    doc_id: pattern:ui.visibility.move_transform_and_uiroot
    test_ref: test_ui_patterns.lua::ui.visibility.move_transform_and_uiroot
    quirks_anchor: move-both-transform-and-uiboxcomponent-uiroot
    status: verified

7. rule_id: ui-gotcha-007
    rule_text: Moving only Transform leaves children behind because uiRoot is the alignment anchor.
    doc_id: pattern:ui.visibility.transform_only_fails
    test_ref: test_ui_patterns.lua::ui.visibility.transform_only_fails
    quirks_anchor: transform-only-move-fails
    status: verified

8. rule_id: ui-gotcha-008
    rule_text: Add ScreenSpaceCollisionMarker to all clickable UI so input is detected.
    doc_id: pattern:ui.collision.screenspace_marker_required
    test_ref: test_ui_patterns.lua::ui.collision.screenspace_marker_required
    quirks_anchor: marker-required-for-clicks
    status: verified

9. rule_id: ui-gotcha-009
    rule_text: Preserve collision markers across ReplaceChildren to keep click handling.
    doc_id: pattern:ui.collision.click_detection_with_marker
    test_ref: test_ui_patterns.lua::ui.collision.click_detection_with_marker
    quirks_anchor: click-detection-with-marker
    status: verified

10. rule_id: ui-gotcha-010
    rule_text: Without ScreenSpaceCollisionMarker, click callbacks never fire.
    doc_id: pattern:ui.collision.click_fails_without_marker
    test_ref: test_ui_patterns.lua::ui.collision.click_fails_without_marker
    quirks_anchor: click-fails-without-marker
    status: verified

11. rule_id: ui-gotcha-011
    rule_text: Cleanup grid teardown by clearing itemRegistry, destroying grid, then dsl.cleanupGrid.
    doc_id: pattern:ui.grid.cleanup_all_three_registries
    test_ref: test_ui_patterns.lua::ui.grid.cleanup_all_three_registries
    quirks_anchor: cleanup-all-three-registries
    status: verified

12. rule_id: ui-gotcha-012
    rule_text: Partial grid cleanup leaves orphan registry entries and ghost slots.
    doc_id: pattern:ui.grid.cleanup_partial_fails
    test_ref: test_ui_patterns.lua::ui.grid.cleanup_partial_fails
    quirks_anchor: partial-cleanup-fails
    status: verified

13. rule_id: ui-gotcha-013
    rule_text: DrawCommandSpace.World makes HUD elements follow the camera.
    doc_id: pattern:ui.drawspace.world_follows_camera
    test_ref: test_ui_patterns.lua::ui.drawspace.world_follows_camera
    quirks_anchor: world-draw-space-follows-camera
    status: verified

14. rule_id: ui-gotcha-014
    rule_text: Use DrawCommandSpace.Screen for fixed HUDs that should not move with camera.
    doc_id: pattern:ui.drawspace.screen_fixed_hud
    test_ref: test_ui_patterns.lua::ui.drawspace.screen_fixed_hud
    quirks_anchor: screen-draw-space-stays-fixed
    status: verified

15. rule_id: ui-gotcha-015
    rule_text: Never attach ObjectAttachedToUITag to draggable UI elements.
    doc_id: pattern:ui.attached.never_on_draggables
    test_ref: test_ui_patterns.lua::ui.attached.never_on_draggables
    quirks_anchor: never-use-objectattachedto-uitag-on-draggables
    status: verified

16. rule_id: ui-gotcha-016
    rule_text: ObjectAttachedToUITag is safe for static attachments that must follow parent.
    doc_id: pattern:ui.attached.correct_usage
    test_ref: test_ui_patterns.lua::ui.attached.correct_usage
    quirks_anchor: objectattachedto-uitag-correct-usage
    status: verified

17. rule_id: ui-gotcha-017
    rule_text: UIBox creation requires post-spawn state tags and alignment to activate interaction.
    doc_id: pattern:ui.uibox_creation.basic
    test_ref: test_ui_patterns.lua::ui.statetag.add_after_spawn
    quirks_anchor: uibox-creation-and-configuration
    status: verified

18. rule_id: ui-gotcha-018
    rule_text: ChildBuilder.setOffset changes require RenewAlignment to reflow layout.
    doc_id: pattern:ui.childbuilder.setoffset_requires_renew
    test_ref: test_ui_patterns.lua::ui.uibox_alignment.renew_after_offset
    quirks_anchor: setoffset-requires-renewalignment
    status: verified

19. rule_id: ui-gotcha-019
    rule_text: Slot decorations must apply sprite scale or slot config to avoid misaligned panels.
    doc_id: pattern:ui.slot_decorations.sprite_panel_scaling
    test_ref: Unverified: manual visual check
    quirks_anchor: slot-decorations-and-sprite-panels
    status: unverified

20. rule_id: ui-gotcha-020
    rule_text: Call RenewAlignment after ReplaceChildren to avoid cached layout using old children.
    doc_id: pattern:ui.uibox_alignment.renew_after_replacechildren
    test_ref: test_ui_patterns.lua::ui.uibox_alignment.renew_after_replacechildren
    quirks_anchor: renewalignment-after-replacechildren
    status: verified

---

<a id="physics-system"></a>
## Physics System

<!-- Stub: Physics quirks will be documented here -->
*No quirks documented yet. Add entries following the [Entry Template](#entry-template).*

Potential areas:
- Collision mask ordering
- Physics body creation timing
- Chipmunk shape lifecycle
- Raycast vs segment query differences

---

<a id="shader-system"></a>
## Shader System

<!-- Stub: Shader quirks will be documented here -->
*No quirks documented yet. Add entries following the [Entry Template](#entry-template).*

Potential areas:
- Shader uniform timing
- Multi-pass pipeline ordering
- globalShaderUniforms lifecycle
- ShaderBuilder attachment requirements

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

<!-- Stub: Combat quirks will be documented here -->
*No quirks documented yet. Add entries following the [Entry Template](#entry-template).*

Potential areas:
- Damage calculation ordering
- Projectile lifecycle
- Status effect stacking
- Card/ability timing
