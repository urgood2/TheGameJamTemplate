# ECS Lifecycle cm Rules Draft

Rules drafted from Phase 4B Entity Lifecycle documentation.
Import to cm playbook in Phase 8.

## Gotcha Rules (Critical)

### ecs-gotcha-001
- **rule_id**: ecs-gotcha-001
- **category**: ecs-gotchas
- **rule_text**: When initializing entity scripts, always assign data to the script table BEFORE calling attach_ecs() because data assigned after attach_ecs is lost and not accessible via getScriptTableFromEntityID
- **doc_id**: pattern:ecs.attach_ecs.assign_before_attach
- **test_ref**: test_entity_lifecycle.lua::ecs.attach_ecs.assign_before_attach
- **quirks_anchor**: ecs-gotcha-001-data-must-be-assigned-before-attach_ecs
- **status**: verified

### ecs-gotcha-002
- **rule_id**: ecs-gotcha-002
- **category**: ecs-gotchas
- **rule_text**: When storing entity data, never add custom fields to the GameObject component because it's C++ userdata that doesn't support arbitrary Lua keys - use script.data table instead
- **doc_id**: pattern:ecs.gameobject.no_data_storage
- **test_ref**: test_entity_lifecycle.lua::ecs.gameobject.script_table_usage
- **quirks_anchor**: ecs-gotcha-002-never-store-data-in-gameobject-component
- **status**: verified

### ecs-gotcha-003
- **rule_id**: ecs-gotcha-003
- **category**: ecs-gotchas
- **rule_text**: When using LuaJIT backend, group file-scope locals into tables because LuaJIT limits functions to 200 local variables and file-level locals count toward this limit
- **doc_id**: pattern:ecs.luajit.200_local_limit
- **test_ref**: N/A (manual verification)
- **quirks_anchor**: ecs-gotcha-003-luajit-200-local-variable-limit
- **status**: verified

### ecs-gotcha-004
- **rule_id**: ecs-gotcha-004
- **category**: ecs-gotchas
- **rule_text**: When destroying entities, always clean up references in timers, signals, and parent-child relationships because stale references to destroyed entities cause errors on access
- **doc_id**: pattern:ecs.destroy.no_stale_refs
- **test_ref**: test_entity_lifecycle.lua::ecs.destroy.no_stale_refs
- **quirks_anchor**: ecs-pattern-004-entity-destruction-and-cleanup
- **status**: verified

### ecs-gotcha-005
- **rule_id**: ecs-gotcha-005
- **category**: ecs-gotchas
- **rule_text**: When caching component references, do not hold them across frames if the entity might be destroyed because the cache is cleared on entity destruction and references become invalid
- **doc_id**: pattern:ecs.cache.get_after_destroy
- **test_ref**: test_entity_lifecycle.lua::ecs.cache.get_after_destroy
- **quirks_anchor**: ecs-pattern-003-component-cache-usage
- **status**: verified

## Pattern Rules (Best Practices)

### ecs-pattern-001
- **rule_id**: ecs-pattern-001
- **category**: ecs-patterns
- **rule_text**: When storing per-entity state, use the script.data table pattern with Node:extend() and assign data before attach_ecs
- **doc_id**: pattern:ecs.gameobject.script_table_usage
- **test_ref**: test_entity_lifecycle.lua::ecs.gameobject.script_table_usage
- **quirks_anchor**: ecs-gotcha-002-never-store-data-in-gameobject-component
- **status**: verified

### ecs-pattern-002
- **rule_id**: ecs-pattern-002
- **category**: ecs-patterns
- **rule_text**: When checking if an entity exists, use ensure_entity(eid) which returns true if the entity is valid in the registry
- **doc_id**: pattern:ecs.validate.ensure_entity
- **test_ref**: test_entity_lifecycle.lua::ecs.validate.ensure_entity_valid
- **quirks_anchor**: ecs-pattern-001-entity-validation
- **status**: verified

### ecs-pattern-003
- **rule_id**: ecs-pattern-003
- **category**: ecs-patterns
- **rule_text**: When checking if an entity has a script, use ensure_scripted_entity(eid) which returns true only if the entity exists AND has a ScriptComponent
- **doc_id**: pattern:ecs.validate.ensure_scripted_entity_valid
- **test_ref**: test_entity_lifecycle.lua::ecs.validate.ensure_scripted_entity_valid
- **quirks_anchor**: ecs-pattern-001-entity-validation
- **status**: verified

### ecs-pattern-004
- **rule_id**: ecs-pattern-004
- **category**: ecs-patterns
- **rule_text**: When accessing script fields that may be nil, use script_field(eid, field, default) to get a default value instead of nil
- **doc_id**: pattern:ecs.access.script_field_default
- **test_ref**: test_entity_lifecycle.lua::ecs.access.script_field_default
- **quirks_anchor**: ecs-pattern-002-safe-script-access
- **status**: verified

### ecs-pattern-005
- **rule_id**: ecs-pattern-005
- **category**: ecs-patterns
- **rule_text**: When accessing script tables for potentially invalid entities, use safe_script_get(eid) which returns nil instead of erroring for invalid entities
- **doc_id**: pattern:ecs.access.safe_script_get_valid
- **test_ref**: test_entity_lifecycle.lua::ecs.access.safe_script_get_valid
- **quirks_anchor**: ecs-pattern-002-safe-script-access
- **status**: verified

### ecs-pattern-006
- **rule_id**: ecs-pattern-006
- **category**: ecs-patterns
- **rule_text**: When accessing components frequently, use component_cache.get(entity, ComponentType) for efficient cached access
- **doc_id**: pattern:ecs.cache.get_valid
- **test_ref**: test_entity_lifecycle.lua::ecs.cache.get_valid
- **quirks_anchor**: ecs-pattern-003-component-cache-usage
- **status**: verified

### ecs-pattern-007
- **rule_id**: ecs-pattern-007
- **category**: ecs-patterns
- **rule_text**: When destroying entities, verify cleanup is complete by checking that safe_script_get returns nil
- **doc_id**: pattern:ecs.destroy.no_stale_refs
- **test_ref**: test_entity_lifecycle.lua::ecs.destroy.no_stale_refs
- **quirks_anchor**: ecs-pattern-004-entity-destruction-and-cleanup
- **status**: verified

### ecs-pattern-008
- **rule_id**: ecs-pattern-008
- **category**: ecs-patterns
- **rule_text**: When recreating entities after destruction, create fresh entities to ensure clean state because EnTT may reuse entity IDs
- **doc_id**: pattern:ecs.destroy.then_recreate
- **test_ref**: test_entity_lifecycle.lua::ecs.destroy.then_recreate
- **quirks_anchor**: ecs-pattern-006-destroy-then-recreate-pattern
- **status**: verified

### ecs-pattern-009
- **rule_id**: ecs-pattern-009
- **category**: ecs-patterns
- **rule_text**: When creating entities with data, use EntityBuilder.create() or Node.quick() to ensure correct initialization order automatically
- **doc_id**: pattern:ecs.builder.validated
- **test_ref**: See entity-builder tests
- **quirks_anchor**: ecs-pattern-005-using-entitybuilder-for-safe-initialization
- **status**: verified

### ecs-pattern-010
- **rule_id**: ecs-pattern-010
- **category**: ecs-patterns
- **rule_text**: When entities have dependency relationships, use EntityLinks.link() to automatically destroy dependents when the parent dies
- **doc_id**: pattern:ecs.links.linkTo
- **test_ref**: See entity-scripts.md
- **quirks_anchor**: N/A (in entity-scripts.md)
- **status**: verified

## Import Commands

```bash
# Import all rules to cm playbook (Phase 8)
cm playbook add "When initializing entity scripts, always assign data to the script table BEFORE calling attach_ecs() because data assigned after attach_ecs is lost" --category ecs-gotchas

cm playbook add "When storing entity data, never add custom fields to the GameObject component - use script.data table instead" --category ecs-gotchas

cm playbook add "When using LuaJIT backend, group file-scope locals into tables because LuaJIT limits functions to 200 local variables" --category ecs-gotchas

cm playbook add "When checking if an entity exists, use ensure_entity(eid)" --category ecs-patterns

cm playbook add "When checking if an entity has a script, use ensure_scripted_entity(eid)" --category ecs-patterns

cm playbook add "When accessing script fields that may be nil, use script_field(eid, field, default)" --category ecs-patterns

cm playbook add "When accessing script tables for potentially invalid entities, use safe_script_get(eid)" --category ecs-patterns

cm playbook add "When accessing components frequently, use component_cache.get(entity, ComponentType)" --category ecs-patterns

cm playbook add "When destroying entities, clean up references in timers, signals, and parent-child relationships" --category ecs-gotchas

cm playbook add "When recreating entities after destruction, create fresh entities to ensure clean state" --category ecs-patterns

cm playbook add "When creating entities with data, use EntityBuilder.create() or Node.quick() to ensure correct initialization order" --category ecs-patterns
```

---

_Drafted: 2026-02-03 Phase 4B_
