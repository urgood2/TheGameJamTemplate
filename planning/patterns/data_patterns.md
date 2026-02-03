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
## pattern:data.cards.definition_schema
**doc_id:** `pattern:data.cards.definition_schema`
**Source:** assets/scripts/data/cards.lua:38; assets/scripts/data/cards.lua:98
**Frequency:** Found in 1 file

**Pattern:**
```lua
Cards.MY_FIREBALL = {
    id = "MY_FIREBALL",
    type = "action",
    mana_cost = 12,
    tags = { "Fire", "Projectile" },
    description = "...",
    projectile_speed = 400,
    lifetime = 2000,
}

Cards.TEST_DAMAGE_BOOST = {
    id = "TEST_DAMAGE_BOOST",
    type = "modifier",
    damage_modifier = 5,
    multicast_count = 1,
}
```

**Preconditions:**
- `id` matches table key and `type` is `"action"` or `"modifier"`
- Defaults applied via `data.content_defaults` when fields omitted

**Unverified:** No dedicated pattern test (cards validated in gameplay).

---

## pattern:data.enemies.definition_schema
**doc_id:** `pattern:data.enemies.definition_schema`
**Source:** assets/scripts/data/enemies.lua:26; assets/scripts/data/enemies.lua:49
**Frequency:** Found in 1 file

**Pattern:**
```lua
enemies.goblin = {
    sprite = "enemy_type_1.png",
    hp = 30,
    speed = 60,
    damage = 5,
    size = { 32, 32 },
    behaviors = {
        "chase",
        { "dash", cooldown = "dash_cooldown", speed = "dash_speed" },
    },
    on_death = function(e, ctx, helpers)
        helpers.spawn_particles("enemy_death", e)
    end,
}
```

**Preconditions:**
- Behavior system resolves string or table behaviors using ctx fields

**Unverified:** No dedicated pattern test (enemy runtime validates behaviors).

---

## pattern:data.equipment.definition_schema
**doc_id:** `pattern:data.equipment.definition_schema`
**Source:** assets/scripts/data/equipment.lua:10; assets/scripts/data/demo_equipment.lua:12
**Frequency:** Found in 2 files

**Pattern:**
```lua
Equipment.flaming_sword = {
    id = "flaming_sword",
    name = "Flaming Sword",
    slot = "main_hand",
    rarity = "Rare",
    stats = { weapon_min = 50, weapon_max = 80, fire_damage = 20 },
    requires = { attribute = "physique", value = 20, mode = "sole" },
    procs = {
        {
            trigger = Triggers.COMBAT.ON_HIT,
            chance = 30,
            effect = function(ctx, src, ev)
                getStatusEngine().apply(ctx, ev.target, "burning", { stacks = 3, source = src })
            end,
        },
    },
    conversions = { { from = "physical", to = "fire", pct = 50 } },
}
```

**Preconditions:**
- Trigger registry (`data.triggers`) loaded
- Status engine available for proc effects

**Unverified:** No dedicated pattern test (equipment effects validated in combat runtime).

---

## pattern:data.jokers.calculate_context
**doc_id:** `pattern:data.jokers.calculate_context`
**Source:** assets/scripts/data/jokers.lua:19; assets/scripts/data/artifacts.lua:33
**Frequency:** Found in 2 files

**Pattern:**
```lua
lightning_rod = {
    id = "lightning_rod",
    name = "Lightning Rod",
    rarity = "Uncommon",
    calculate = function(self, context)
        if context.event == "on_spell_cast" and context.tags and context.tags.Lightning then
            return { damage_mod = 15, extra_chain = 1, message = "Lightning Rod!" }
        end
    end,
}
```

**Preconditions:**
- `context.event` strings match combat/event pipeline
- `calculate` returns a table of effect deltas or nil

**Unverified:** No dedicated pattern test (jokers/artifacts validated in gameplay).

---

## pattern:data.status_effects.definition_schema
**doc_id:** `pattern:data.status_effects.definition_schema`
**Source:** assets/scripts/data/status_effects.lua:35; assets/scripts/data/status_effects.lua:68
**Frequency:** Found in 1 file

**Pattern:**
```lua
StatusEffects.electrocute = {
    id = "electrocute",
    dot_type = true,
    damage_type = "lightning",
    stack_mode = "intensity",
    max_stacks = 99,
    duration = 5,
    base_dps = 5,
    icon = "status-electrocute.png",
    shader = "electric_crackle",
    shader_uniforms = { intensity = 0.6 },
    particles = function()
        return Particles.define()
            :shape("line")
            :size(2, 4)
            :color("cyan", "white")
            :velocity(30, 60)
            :lifespan(0.15, 0.25)
            :fade()
    end,
}
```

**Preconditions:**
- Status engine interprets stack_mode, dot_type, and visual fields
- `core.particles` loaded for particle chains

**Unverified:** No dedicated pattern test (effects validated in gameplay).

---

## pattern:data.disciplines.card_pools
**doc_id:** `pattern:data.disciplines.card_pools`
**Source:** assets/scripts/data/disciplines.lua:15; assets/scripts/data/disciplines.lua:39
**Frequency:** Found in 1 file

**Pattern:**
```lua
Disciplines.arcane_discipline = {
    name = "Arcane Discipline",
    description = "Mastery of pure magic and spell manipulation.",
    tags = { "Arcane", "Projectile" },
    actions = { "arcane_missile", "chain_lightning" },
    modifiers = { "echo", "chain", "pierce" },
}
```

**Preconditions:**
- Shop pool builder consumes `actions`/`modifiers` lists

**Unverified:** No dedicated pattern test (discipline filtering validated in UI/runtime).

---

## pattern:data.skills.definition_schema
**doc_id:** `pattern:data.skills.definition_schema`
**Source:** assets/scripts/data/skills.lua:32; assets/scripts/data/skills.lua:45
**Frequency:** Found in 1 file

**Pattern:**
```lua
Skills.kindle = {
    id = "kindle",
    name = "Kindle",
    description = "Your fire sparks to life faster.",
    element = "fire",
    icon = "skill_kindle",
    cost = 1,
    effects = {
        { type = "stat_buff", stat = "fire_modifier_pct", value = 10 },
    },
}
```

**Preconditions:**
- Skill system interprets effect tables by `type`

**Unverified:** No dedicated pattern test (skills validated in gameplay).

---

## pattern:data.registry.accessors
**doc_id:** `pattern:data.registry.accessors`
**Source:** assets/scripts/data/equipment.lua:402; assets/scripts/data/equipment.lua:416
**Frequency:** Found in 1 file

**Pattern:**
```lua
function Equipment.get(id)
    return Equipment[id]
end

function Equipment.getAll()
    local items = {}
    for _, v in pairs(Equipment) do
        if type(v) == "table" and v.id then
            items[#items + 1] = v
        end
    end
    return items
end
```

**Preconditions:**
- Registry entries include an `id` field

**Unverified:** No dedicated pattern test (used by content consumers).

---
