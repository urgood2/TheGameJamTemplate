# Combat Patterns

## pattern:combat.wave.telegraph_spawn
**doc_id:** `pattern:combat.wave.telegraph_spawn`
**Source:** assets/scripts/combat/wave_director.lua:104-123
**Frequency:** Found in 3 files

**Pattern:**
```lua
-- Telegraph first
timer.after(spawn_delay, function()
    WaveHelpers.spawn_telegraph(pos, enemy_type, telegraph_duration)
end, "wave_telegraph_" .. i)

-- Spawn after telegraph completes
timer.after(spawn_delay + telegraph_duration + spawn_buffer, function()
    WaveDirector.spawn_enemy(enemy_type, pos)
end, "wave_spawn_" .. i)
```

**Preconditions:**
- `WaveHelpers.spawn_telegraph` available
- `timer.after` available
- `wave.delay_between` and `wave.telegraph_duration` configured

**Verified:** Unverified: no automated test (used in wave runtime)

---

## pattern:combat.wave.elite_spawn
**doc_id:** `pattern:combat.wave.elite_spawn`
**Source:** assets/scripts/combat/wave_director.lua:143-186
**Frequency:** Found in 1 file

**Pattern:**
```lua
WaveHelpers.spawn_telegraph(pos, "elite", elite_telegraph_duration)

timer.after(elite_telegraph_duration + 0.1, function()
    local enemy_type, modifiers
    if type(elite_config) == "string" then
        enemy_type = elite_config
        modifiers = {}
    elseif elite_config.base then
        enemy_type = elite_config.base
        modifiers = elite_config.modifiers or elite_modifiers.roll_random(2)
    end
    WaveDirector.spawn_enemy(enemy_type, pos, modifiers)
end, "elite_spawn")
```

**Preconditions:**
- `stage_config.elite` populated
- `elite_modifiers.roll_random` available

**Verified:** Unverified: no automated test (manual wave runs)

---

## pattern:combat.wave.timed_schedule
**doc_id:** `pattern:combat.wave.timed_schedule`
**Source:** assets/scripts/combat/enemy_spawner.lua:137-169
**Frequency:** Found in 2 files

**Pattern:**
```lua
for schedule_index, entry in ipairs(spawn_schedule) do
    local timer_tag = string.format("wave_%d_spawn_%d", wave_number, schedule_index)
    timer.after(entry.delay or 0, function()
        for i = 1, (entry.count or 1) do
            self:spawn_enemy(entry.enemy, wave_config)
        end
    end, timer_tag)
end
```

**Preconditions:**
- `wave_config.spawn_schedule` entries with `delay`, `enemy`, `count`
- `timer.after` available

**Verified:** Unverified: no automated test (combat_loop_test.lua uses schedule)

---

## pattern:combat.wave.budget_weighted
**doc_id:** `pattern:combat.wave.budget_weighted`
**Source:** assets/scripts/combat/enemy_spawner.lua:178-227
**Frequency:** Found in 1 file

**Pattern:**
```lua
local affordable = {}
for _, enemy in ipairs(available_enemies) do
    if enemy.cost <= remaining_budget then
        table.insert(affordable, { item = enemy, w = enemy.weight })
    end
end

local chosen = random_utils.weighted_choice(affordable)
if chosen then
    self:spawn_enemy(chosen.type, wave_config)
    remaining_budget = remaining_budget - chosen.cost
end
```

**Preconditions:**
- `wave_config.budget` and `wave_config.enemies` with `cost`/`weight`
- `random_utils.weighted_choice` available

**Verified:** Unverified: no automated test (manual survival/endless runs)

---

## pattern:combat.wave.provider_sequence
**doc_id:** `pattern:combat.wave.provider_sequence`
**Source:** assets/scripts/combat/wave_system.lua:27-50, assets/scripts/combat/wave_test_init.lua:33-52
**Frequency:** Found in 4 files

**Pattern:**
```lua
local provider = providers.sequence(stages)
WaveSystem.start_run(provider)

local first_stage = provider.next()
if first_stage then
    WaveDirector.start_stage(first_stage)
end
```

**Preconditions:**
- `combat.stage_providers` loaded
- Stage configs have `waves` and `next` fields

**Verified:** Unverified: no automated test (wave_test_init.lua is manual)

---

## pattern:combat.enemy.spawn_context
**doc_id:** `pattern:combat.enemy.spawn_context`
**Source:** assets/scripts/combat/enemy_factory.lua:93-176
**Frequency:** Found in 1 file

**Pattern:**
```lua
local ctx = {
    type = enemy_type,
    hp = def.hp,
    max_hp = def.hp,
    speed = def.speed,
    damage = def.damage or 0,
    size = def.size or { spriteW, spriteH },
    entity = e,
    is_elite = #modifiers > 0,
}

-- Apply modifiers then store
WaveHelpers.set_enemy_ctx(e, ctx)
```

**Preconditions:**
- Enemy definition in `data/enemies.lua`
- WaveHelpers available for context storage

**Verified:** Unverified: no automated test (enemy_factory used in wave runtime)

---

## pattern:combat.enemy.physics_builder_chain
**doc_id:** `pattern:combat.enemy.physics_builder_chain`
**Source:** assets/scripts/combat/enemy_factory.lua:182-193
**Frequency:** Found in 1 file

**Pattern:**
```lua
PhysicsBuilder.for_entity(e)
    :circle()
    :tag(C.CollisionTags.ENEMY)
    :sensor(false)
    :density(1.0)
    :friction(0)
    :inflate(-4)
    :collideWith({ C.CollisionTags.PLAYER, C.CollisionTags.ENEMY, C.CollisionTags.PROJECTILE })
    :apply()
```

**Preconditions:**
- `core.physics_builder` and collision tags available

**Verified:** Unverified: no automated test (enemy_factory runtime)

---

## pattern:combat.enemy.steering_physics_step
**doc_id:** `pattern:combat.enemy.steering_physics_step`
**Source:** assets/scripts/combat/enemy_factory.lua:278-296
**Frequency:** Found in 2 files

**Pattern:**
```lua
local steeringTimerTag = "wave_enemy_steering_" .. tostring(e)

timer.every_physics_step(function()
    if not entity_cache.valid(e) then return false end
    local playerT = survivorEntity and component_cache.get(survivorEntity, Transform)
    if steering and steering.seek_point then
        steering.seek_point(registry, e, playerLocation, 1.0, 0.5)
        steering.wander(registry, e, 300.0, 300.0, 150.0, 3)
    end
end, steeringTimerTag)
```

**Preconditions:**
- `timer.every_physics_step` available
- `steering.seek_point` binding available

**Verified:** Unverified: no automated test (manual wave runtime)

---

## pattern:combat.projectile.spawn_basic
**doc_id:** `pattern:combat.projectile.spawn_basic`
**Source:** assets/scripts/combat/projectile_system.lua:451-538
**Frequency:** Found in 3 files

**Pattern:**
```lua
local entity = create_transform_entity()
add_state_tag(entity, ACTION_STATE)

local width = (params.size or 8) * (params.sizeMultiplier or 1.0)
if params.positionIsCenter then
    spawnX = spawnX - width * 0.5
end

local projectileData = ProjectileSystem.createProjectileData(params)
local projectileBehavior = ProjectileSystem.createProjectileBehavior(params)
local projectileLifetime = ProjectileSystem.createProjectileLifetime({
    maxLifetime = params.lifetime or 5.0,
    maxDistance = params.maxDistance,
    startPosition = startCenter,
    maxHits = params.maxHits
})
```

**Preconditions:**
- `create_transform_entity`, `component_cache`, and animation system available
- ACTION_STATE defined for combat phase

**Verified:** Unverified: no automated test (projectile_examples.lua is manual)

---

## pattern:combat.projectile.homing_config
**doc_id:** `pattern:combat.projectile.homing_config`
**Source:** assets/scripts/combat/projectile_examples.lua:74-131
**Frequency:** Found in 2 files

**Pattern:**
```lua
ProjectileSystem.spawn({
    movementType = ProjectileSystem.MovementType.HOMING,
    homingTarget = targetEntity,
    homingStrength = 10.0,
    homingMaxSpeed = 500,
    direction = { x = dx / dist, y = dy / dist },
})
```

**Preconditions:**
- Valid `targetEntity` with Transform
- ProjectileSystem loaded

**Verified:** Unverified: no automated test (projectile_examples.lua)

---

## pattern:combat.projectile.pierce_config
**doc_id:** `pattern:combat.projectile.pierce_config`
**Source:** assets/scripts/combat/projectile_examples.lua:141-160
**Frequency:** Found in 2 files

**Pattern:**
```lua
ProjectileSystem.spawn({
    collisionBehavior = ProjectileSystem.CollisionBehavior.PIERCE,
    pierceCount = 0,
    maxPierceCount = 3,
})
```

**Preconditions:**
- ProjectileSystem collision behaviors configured

**Verified:** Unverified: no automated test (projectile_examples.lua)

---

## pattern:combat.helpers.enemy_context_weak_table
**doc_id:** `pattern:combat.helpers.enemy_context_weak_table`
**Source:** assets/scripts/combat/wave_helpers.lua:164-171
**Frequency:** Found in 1 file

**Pattern:**
```lua
local enemy_contexts = setmetatable({}, { __mode = "k" })

function WaveHelpers.set_enemy_ctx(e, ctx)
    enemy_contexts[e] = ctx
end
```

**Preconditions:**
- Enemy entities are numeric keys in the registry

**Verified:** Unverified: no automated test (context tracked in wave runtime)
