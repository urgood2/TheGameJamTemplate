# Data Patterns

## pattern:data.localization.L_helper
**doc_id:** `pattern:data.localization.L_helper`
**Source:** assets/scripts/data/cards.lua:27; assets/scripts/data/skills.lua:17; assets/scripts/data/avatars.lua:26
**Frequency:** Found in 9 files

**Pattern:**
```lua
local function L(key, fallback)
    if localization and localization.get then
        local result = localization.get(key)
        if result and result ~= key then return result end
    end
    return fallback
end
```

**Preconditions:**
- `localization.get` available for localized strings

**Unverified:** No dedicated pattern test (data modules use this directly).

---

## pattern:data.registry.id_matches_key
**doc_id:** `pattern:data.registry.id_matches_key`
**Source:** assets/scripts/data/cards.lua:39; assets/scripts/data/projectiles.lua:21; assets/scripts/data/status_effects.lua:36; assets/scripts/data/equipment.lua:11
**Frequency:** Found in 11 files

**Pattern:**
```lua
Cards.MY_FIREBALL = {
    id = "MY_FIREBALL",
    type = "action",
    tags = { "Fire", "Projectile" },
}
```

**Preconditions:**
- Table key and `id` field must match for lookup consistency

**Unverified:** No dedicated pattern test (validated by data registry usage).

---

## pattern:data.content_defaults.apply_card_defaults
**doc_id:** `pattern:data.content_defaults.apply_card_defaults`
**Source:** assets/scripts/data/content_defaults.lua:178
**Frequency:** Found in 1 file

**Pattern:**
```lua
local defaults = require("data.content_defaults")
local with_defaults = defaults.apply_card_defaults(card_def)
```

**Preconditions:**
- `card_def.type` set to `"action"`, `"modifier"`, or `"trigger"`

**Unverified:** No dedicated pattern test (utility function used by content pipelines).

---

## pattern:data.spawn_presets.entity_template
**doc_id:** `pattern:data.spawn_presets.entity_template`
**Source:** assets/scripts/data/spawn_presets.lua:49
**Frequency:** Found in 1 file

**Pattern:**
```lua
SpawnPresets.enemies.kobold = {
    sprite = "enemy_type_1.png",
    size = { 32, 32 },
    shadow = true,
    physics = { shape = "rectangle", tag = C.CollisionTags.ENEMY },
    data = { health = 50, damage = 10 },
    interactive = { hover = { title = "...", body = "..." }, collision = true },
}
```

**Preconditions:**
- Presets remain data-only (no functions)
- Data assigned before attach_ecs (per CLAUDE guidance)

**Unverified:** No dedicated pattern test (used by spawn flows).

---

## pattern:data.enemies.behaviors_declarative
**doc_id:** `pattern:data.enemies.behaviors_declarative`
**Source:** assets/scripts/data/enemies.lua:49
**Frequency:** Found in 1 file

**Pattern:**
```lua
enemies.goblin = {
    speed = 60,
    behaviors = {
        "chase",
        { "dash", cooldown = "dash_cooldown", speed = "dash_speed" },
    },
}
```

**Preconditions:**
- Behavior system resolves string aliases and ctx field references

**Unverified:** No dedicated pattern test (behavior engine validates at runtime).

---

## pattern:data.particles.define_chain
**doc_id:** `pattern:data.particles.define_chain`
**Source:** assets/scripts/data/status_effects.lua:55; assets/scripts/data/cards.lua:180
**Frequency:** Found in 2 files

**Pattern:**
```lua
particles = function()
    return Particles.define()
        :shape("circle")
        :size(2, 4)
        :color("cyan", "white")
        :velocity(30, 60)
        :lifespan(0.15, 0.25)
        :fade()
end
```

**Preconditions:**
- `core.particles` loaded and provides `Particles.define()` chain API

**Unverified:** No dedicated pattern test (visual effects verified in-game).

---

## pattern:data.equipment.proc_triggers
**doc_id:** `pattern:data.equipment.proc_triggers`
**Source:** assets/scripts/data/equipment.lua:25
**Frequency:** Found in 1 file

**Pattern:**
```lua
procs = {
    {
        trigger = Triggers.COMBAT.ON_HIT,
        chance = 30,
        effect = function(ctx, src, ev)
            getStatusEngine().apply(ctx, ev.target, "burning", { stacks = 3, source = src })
        end,
    },
}
```

**Preconditions:**
- `data.triggers` loaded
- Status engine available via combat system

**Unverified:** No dedicated pattern test (behavior verified in combat runtime).

---

## pattern:data.triggers.registry_flatten
**doc_id:** `pattern:data.triggers.registry_flatten`
**Source:** assets/scripts/data/triggers.lua:106
**Frequency:** Found in 1 file

**Pattern:**
```lua
local function flattenTriggers()
    local all = {}
    for _, triggers in pairs(Triggers) do
        for _, value in pairs(triggers) do
            all[value] = value
        end
    end
    return all
end

Triggers.ALL = flattenTriggers()
```

**Preconditions:**
- Trigger categories stored as tables

**Unverified:** No dedicated pattern test (validation functions are used by trigger consumers).

---

## pattern:data.projectiles.movement_collision
**doc_id:** `pattern:data.projectiles.movement_collision`
**Source:** assets/scripts/data/projectiles.lua:24
**Frequency:** Found in 1 file

**Pattern:**
```lua
basic_bolt = {
    id = "basic_bolt",
    movement = "straight",
    collision = "destroy",
    speed = 500,
    lifetime = 2000,
}
```

**Preconditions:**
- Projectile system interprets `movement` and `collision` strings

**Unverified:** No dedicated pattern test (runtime validation on spawn).

---
