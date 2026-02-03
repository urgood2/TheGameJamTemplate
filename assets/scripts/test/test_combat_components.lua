-- test_combat_components.lua
-- Combat component access tests (Phase 3 B4)

local TestRunner = require("test.test_runner")
local test_utils = require("test.test_utils")

local function require_globals()
    test_utils.assert_not_nil(_G.registry, "registry available")
    test_utils.assert_not_nil(_G.component_cache, "component_cache available")
    test_utils.assert_not_nil(_G.BuffInstance, "BuffInstance available")
    test_utils.assert_not_nil(_G.Stats, "Stats available")
    test_utils.assert_not_nil(_G.DamageBundle, "DamageBundle available")
    test_utils.assert_not_nil(_G.Ability, "Ability available")
end

local function emplace_component(entity, comp_type, data)
    local payload = data or {}
    payload.__type = comp_type
    local ok, result = pcall(function()
        return _G.registry:emplace(entity, payload)
    end)
    test_utils.assert_true(ok, "registry:emplace succeeded")
    return result
end

TestRunner.register("combat.components.smoke", "components", function()
    require_globals()
end, {
    tags = {"combat", "components", "smoke"},
    doc_ids = {
        "component:BuffInstance",
        "component:Stats",
        "component:DamageBundle",
        "component:Ability",
    },
    requires = {"test_scene"},
})

TestRunner.register("combat.components.buffinstance.read_write", "components", function()
    require_globals()
    local entity = test_utils.spawn_test_entity()

    emplace_component(entity, BuffInstance, {
        id = 1,
        timeLeftSec = 3.5,
        stacks = 2,
        stackingKey = 99,
    })

    local buff = _G.component_cache.get(entity, BuffInstance)
    test_utils.assert_not_nil(buff, "BuffInstance component available")
    test_utils.assert_eq(buff.stacks, 2, "BuffInstance.stacks read")

    buff.stacks = 3
    buff.timeLeftSec = 2.0
    test_utils.assert_eq(buff.stacks, 3, "BuffInstance.stacks write")
    test_utils.assert_eq(buff.timeLeftSec, 2.0, "BuffInstance.timeLeftSec write")
end, {
    tags = {"combat", "components"},
    doc_ids = {"component:BuffInstance"},
    requires = {"test_scene"},
})

TestRunner.register("combat.components.stats.read_write", "components", function()
    require_globals()
    local entity = test_utils.spawn_test_entity()

    emplace_component(entity, Stats, {})
    local stats = _G.component_cache.get(entity, Stats)
    test_utils.assert_not_nil(stats, "Stats component available")

    if stats.base ~= nil then
        local before = stats.base[1] or 0
        stats.base[1] = before + 1
        test_utils.assert_eq(stats.base[1], before + 1, "Stats.base write")
    else
        test_utils.assert_true(type(stats.ClearAddMul) == "function", "Stats.ClearAddMul exists")
        local ok = pcall(stats.ClearAddMul, stats)
        test_utils.assert_true(ok, "Stats.ClearAddMul executed")
    end
end, {
    tags = {"combat", "components"},
    doc_ids = {"component:Stats"},
    requires = {"test_scene"},
})

TestRunner.register("combat.components.damagebundle.read_write", "components", function()
    require_globals()
    local entity = test_utils.spawn_test_entity()

    emplace_component(entity, DamageBundle, {
        weaponScalar = 1.1,
        tags = 0,
    })

    local bundle = _G.component_cache.get(entity, DamageBundle)
    test_utils.assert_not_nil(bundle, "DamageBundle component available")
    test_utils.assert_eq(bundle.weaponScalar, 1.1, "DamageBundle.weaponScalar read")

    bundle.weaponScalar = 1.25
    bundle.tags = 2
    test_utils.assert_eq(bundle.weaponScalar, 1.25, "DamageBundle.weaponScalar write")
    test_utils.assert_eq(bundle.tags, 2, "DamageBundle.tags write")
end, {
    tags = {"combat", "components"},
    doc_ids = {"component:DamageBundle"},
    requires = {"test_scene"},
})

TestRunner.register("combat.components.ability.cooldowns", "components", function()
    require_globals()
    local entity = test_utils.spawn_test_entity()

    emplace_component(entity, Ability, {
        cooldownSec = 2.0,
        cooldownLeft = 1.0,
        internalCooldownSec = 3.0,
        internalCooldownLeft = 0.5,
    })

    local ability = _G.component_cache.get(entity, Ability)
    test_utils.assert_not_nil(ability, "Ability component available")
    test_utils.assert_eq(ability.cooldownSec, 2.0, "Ability.cooldownSec read")

    ability.cooldownLeft = 0.0
    ability.internalCooldownLeft = 0.0
    test_utils.assert_eq(ability.cooldownLeft, 0.0, "Ability.cooldownLeft write")
    test_utils.assert_eq(ability.internalCooldownLeft, 0.0, "Ability.internalCooldownLeft write")
end, {
    tags = {"combat", "components"},
    doc_ids = {"component:Ability"},
    requires = {"test_scene"},
})
