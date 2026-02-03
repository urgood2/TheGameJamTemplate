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
- doc_id: pattern:ecs.init.data_preserved
- Test: assets/scripts/tests/test_entity_lifecycle.lua::ecs.init.data_preserved
- Source: assets/scripts/monobehavior/behavior_script_v2.lua

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

Why: `init()` runs during construction. If you need init to see data, pass it in or use `Node.quick()`.

<a id="ecs-attach-ecs-timing"></a>
### attach_ecs Timing (Assign Data Before Attach)
- doc_id: pattern:ecs.attach_ecs.assign_before_attach
- Test: assets/scripts/tests/test_entity_lifecycle.lua::ecs.attach_ecs.assign_before_attach
- Source: assets/scripts/core/entity_builder.lua, docs/guides/entity-scripts.md

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

Why: attach-time hooks (`run_custom_func`, addStateTag, etc.) read fields immediately. Late data means hooks see nil.

<a id="ecs-gameobject-restrictions"></a>
### GameObject Component Restrictions
- doc_id: pattern:ecs.gameobject.no_data_storage
- Test: assets/scripts/tests/test_entity_lifecycle.lua::ecs.gameobject.no_data_storage
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
- doc_id: pattern:ecs.access.safe_script_get_valid
- Test: assets/scripts/tests/test_entity_lifecycle.lua::ecs.access.safe_script_get_valid
- Source: assets/scripts/util/util.lua

Minimal reproducible snippet:
```lua
local script = safe_script_get(eid)
local health = script_field(eid, "health", 100)
```

Why: `safe_script_get` returns nil on invalid/missing script. `script_field` safely returns a default.

<a id="ecs-validation"></a>
### Entity Validation (ensure_entity vs ensure_scripted_entity)
- doc_id: pattern:ecs.validate.ensure_entity_valid
- Test: assets/scripts/tests/test_entity_lifecycle.lua::ecs.validate.ensure_entity_valid
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
- doc_id: pattern:ecs.cache.get_valid
- Test: assets/scripts/tests/test_entity_lifecycle.lua::ecs.cache.get_valid
- Source: assets/scripts/core/component_cache.lua

Minimal reproducible snippet:
```lua
local transform = component_cache.get(eid, Transform)
-- invalidate when entity or component is removed
component_cache.invalidate(eid, Transform)
```

Related doc_ids: pattern:ecs.cache.get_after_destroy, pattern:ecs.cache.invalidation, pattern:ecs.cache.performance

Why: cached lookups are fast but must be invalidated on destroy/remove to avoid stale data.

<a id="ecs-destruction"></a>
### Entity Destruction & Cleanup
- doc_id: pattern:ecs.destroy.no_stale_refs
- Test: assets/scripts/tests/test_entity_lifecycle.lua::ecs.destroy.no_stale_refs
- Source: assets/scripts/core/entity_cleanup.lua

Minimal reproducible snippet:
```lua
local ref = eid
registry:destroy(eid)
-- use safe_script_get or ensure_entity to avoid stale references
if safe_script_get(ref) == nil then
    -- reference is stale
end
```

Why: destruction must clear caches and references. Always re-validate before using old ids.

<a id="ecs-luajit-locals"></a>
### LuaJIT 200 Local Variable Limit
- doc_id: pattern:ecs.luajit.200_local_limit
- Test: assets/scripts/tests/test_entity_lifecycle.lua::ecs.luajit.200_local_limit
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
Doc ID: pattern:ui.uibox_creation.basic

Symptom:
- UI elements render but never receive clicks or layout does not update after spawn.

Root cause:
- UIBox created without required components or missing post-spawn alignment/state setup.

Fix:
- Use DSL spawn helpers and follow UI Panel Implementation Guide.
- Add state tags after spawn and call RenewAlignment when replacing children.

Test:
- Covered indirectly by ui.statetag.add_after_spawn and ui.uibox_alignment.* tests.

### UIBox Alignment and RenewAlignment

<a id="renewalignment-after-setoffset"></a>
#### RenewAlignment after setOffset
Doc ID: pattern:ui.uibox_alignment.renew_after_offset

Symptom:
- Child elements stay at old positions after ChildBuilder.setOffset.

Root cause:
- InheritedProperties offsets update, but layout is not recomputed until RenewAlignment.

Fix:
- Call ui.box.RenewAlignment(registry, container) after ChildBuilder.setOffset.

Test:
- assets/scripts/tests/test_ui_patterns.lua::ui.uibox_alignment.renew_after_offset

<a id="renewalignment-after-replacechildren"></a>
#### RenewAlignment after ReplaceChildren
Doc ID: pattern:ui.uibox_alignment.renew_after_replacechildren

Symptom:
- Newly replaced children appear at incorrect positions or overlap.

Root cause:
- ReplaceChildren invalidates cached layout; alignment is not recalculated.

Fix:
- Call ui.box.RenewAlignment(registry, container) after ReplaceChildren.

Test:
- assets/scripts/tests/test_ui_patterns.lua::ui.uibox_alignment.renew_after_replacechildren

### State Tags and UIBox State Management

<a id="addstatetagto-uibox-after-spawn"></a>
#### AddStateTagToUIBox after spawn
Doc ID: pattern:ui.statetag.add_after_spawn

Symptom:
- UI states never activate (hover/pressed/disabled visuals never appear).

Root cause:
- State tags are not assigned after spawn.

Fix:
- Call ui.box.AddStateTagToUIBox(registry, entity, "default_state") after spawn.

Test:
- assets/scripts/tests/test_ui_patterns.lua::ui.statetag.add_after_spawn

<a id="addstatetagto-uibox-after-replacechildren"></a>
#### AddStateTagToUIBox after ReplaceChildren
Doc ID: pattern:ui.statetag.add_after_replacechildren

Symptom:
- State tags disappear after ReplaceChildren, causing styling regressions.

Root cause:
- ReplaceChildren wipes state tags from the UIBox tree.

Fix:
- Re-apply state tags with ui.box.AddStateTagToUIBox after ReplaceChildren.

Test:
- assets/scripts/tests/test_ui_patterns.lua::ui.statetag.add_after_replacechildren

<a id="state-tag-persistence-check"></a>
#### State tag persistence check
Doc ID: pattern:ui.statetag.persistence_check

Symptom:
- State tags appear briefly, then stop responding to state transitions.

Root cause:
- State tag list is mutated or cleared during subsequent UI operations.

Fix:
- Reapply tags whenever the UI tree is rebuilt or replaced.

Test:
- assets/scripts/tests/test_ui_patterns.lua::ui.statetag.persistence_check

### Panel Visibility and uiRoot Coordination

<a id="move-both-transform-and-uiboxcomponent-uiroot"></a>
#### Move both Transform and UIBoxComponent.uiRoot
Doc ID: pattern:ui.visibility.move_transform_and_uiroot

Symptom:
- Panel container moves but children stay in the old position.

Root cause:
- uiRoot Transform is not moved alongside the UIBox Transform.

Fix:
- Update Transform and UIBoxComponent.uiRoot, then call RenewAlignment.

Test:
- assets/scripts/tests/test_ui_patterns.lua::ui.visibility.move_transform_and_uiroot

<a id="transform-only-move-fails"></a>
#### Transform-only move fails
Doc ID: pattern:ui.visibility.transform_only_fails

Symptom:
- Children remain at original coordinates after moving only the panel Transform.

Root cause:
- UIBox children align to uiRoot, not the panel Transform alone.

Fix:
- Always move uiRoot in addition to the panel Transform.

Test:
- assets/scripts/tests/test_ui_patterns.lua::ui.visibility.transform_only_fails

### Grid Management and Cleanup

<a id="cleanup-all-three-registries"></a>
#### Cleanup all three registries
Doc ID: pattern:ui.grid.cleanup_all_three_registries

Symptom:
- Orphaned items or ghost slots remain after grid teardown.

Root cause:
- Only partial cleanup is performed.

Fix:
- Clear itemRegistry, call grid:destroy(), and dsl.cleanupGrid(registry).

Test:
- assets/scripts/tests/test_ui_patterns.lua::ui.grid.cleanup_all_three_registries

<a id="partial-cleanup-fails"></a>
#### Partial cleanup fails
Doc ID: pattern:ui.grid.cleanup_partial_fails

Symptom:
- Old items remain registered even after grid is destroyed.

Root cause:
- itemRegistry or DSL cleanup is skipped.

Fix:
- Always perform all three cleanup steps.

Test:
- assets/scripts/tests/test_ui_patterns.lua::ui.grid.cleanup_partial_fails

### ScreenSpaceCollisionMarker for Click Detection

<a id="marker-required-for-clicks"></a>
#### Marker required for clicks
Doc ID: pattern:ui.collision.screenspace_marker_required

Symptom:
- UI buttons do not respond to clicks.

Root cause:
- ScreenSpaceCollisionMarker is missing, so input system ignores the UI entity.

Fix:
- Add ScreenSpaceCollisionMarker {} to all clickable UI entities.

Test:
- assets/scripts/tests/test_ui_patterns.lua::ui.collision.screenspace_marker_required

<a id="click-detection-with-marker"></a>
#### Click detection with marker
Doc ID: pattern:ui.collision.click_detection_with_marker

Symptom:
- Clicks are not routed to callbacks even though the UI is visible.

Root cause:
- Marker was never attached or was removed during rebuild.

Fix:
- Ensure marker is attached at spawn and preserved after ReplaceChildren.

Test:
- assets/scripts/tests/test_ui_patterns.lua::ui.collision.click_detection_with_marker

<a id="click-fails-without-marker"></a>
#### Click fails without marker
Doc ID: pattern:ui.collision.click_fails_without_marker

Symptom:
- Clicking UI does nothing despite valid callbacks.

Root cause:
- Input system rejects entities without the marker.

Fix:
- Attach ScreenSpaceCollisionMarker before registering callbacks.

Test:
- assets/scripts/tests/test_ui_patterns.lua::ui.collision.click_fails_without_marker

### DrawCommandSpace (World vs Screen)

<a id="world-draw-space-follows-camera"></a>
#### World draw space follows camera
Doc ID: pattern:ui.drawspace.world_follows_camera

Symptom:
- HUD elements drift with the camera.

Root cause:
- DrawCommandSpace.World is used for screen-space UI.

Fix:
- Use DrawCommandSpace.Screen for HUD elements.

Test:
- assets/scripts/tests/test_ui_patterns.lua::ui.drawspace.world_follows_camera

<a id="screen-draw-space-stays-fixed"></a>
#### Screen draw space stays fixed
Doc ID: pattern:ui.drawspace.screen_fixed_hud

Symptom:
- HUD elements still move with the camera.

Root cause:
- DrawCommandSpace was not set explicitly or uses World by default.

Fix:
- Set DrawCommandSpace.Screen when queuing UI draws.

Test:
- assets/scripts/tests/test_ui_patterns.lua::ui.drawspace.screen_fixed_hud

### ChildBuilder.setOffset Patterns

<a id="setoffset-requires-renewalignment"></a>
#### setOffset requires RenewAlignment
Doc ID: pattern:ui.childbuilder.setoffset_requires_renew

Symptom:
- Child elements remain at old coordinates after setOffset.

Root cause:
- InheritedProperties offset changes do not reflow UI layout automatically.

Fix:
- Call ui.box.RenewAlignment after setOffset.

Test:
- assets/scripts/tests/test_ui_patterns.lua::ui.uibox_alignment.renew_after_offset

<a id="slot-decorations-and-sprite-panels"></a>
### Slot Decorations and Sprite Panels

Doc ID: pattern:ui.slot_decorations.sprite_panel_scaling

Symptom:
- Decorations render misaligned or scaled incorrectly relative to slots.

Root cause:
- Decorations are not scaled using ui_scale.SPRITE_SCALE or the slot config.

Fix:
- Use slotConfig.decorations or gridConfig.slotDecorations for sprite panels.

Test:
- Manual verification (visual).

### ObjectAttachedToUITag for Draggables

<a id="never-use-objectattachedto-uitag-on-draggables"></a>
#### Never use ObjectAttachedToUITag on draggables
Doc ID: pattern:ui.attached.never_on_draggables

Symptom:
- Draggable UI elements become stuck or cannot move.

Root cause:
- ObjectAttachedToUITag forces attachment behavior that conflicts with drag logic.

Fix:
- Do not add ObjectAttachedToUITag to draggable UI elements.

Test:
- assets/scripts/tests/test_ui_patterns.lua::ui.attached.never_on_draggables

<a id="objectattachedto-uitag-correct-usage"></a>
#### ObjectAttachedToUITag correct usage
Doc ID: pattern:ui.attached.correct_usage

Symptom:
- Non-draggable attachments fail to follow parent if tag missing.

Root cause:
- Attachment tag not applied for static attachments.

Fix:
- Use ObjectAttachedToUITag only for non-draggable attachments.

Test:
- assets/scripts/tests/test_ui_patterns.lua::ui.attached.correct_usage

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
