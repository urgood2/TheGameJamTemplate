-- assets/scripts/tests/bargain/ai_spec.lua

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local sim = require("bargain.sim")
local spawn = require("bargain.enemies.spawn")
local ai = require("bargain.ai.system")

local function set_player_pos(world, x, y)
    local player = world.entities.by_id[world.player_id]
    player.pos.x = x
    player.pos.y = y
end

t.describe("Bargain AI", function()
    t.it("template_test", function()
        local templates = require("bargain.enemies.templates")
        local ids = { "rat", "goblin", "skeleton" }
        for _, id in ipairs(ids) do
            local tmpl = templates[id]
            t.expect(tmpl).to_be_type("table")
            t.expect(tmpl.id).to_be(id)
            t.expect(tmpl.hp).to_be_type("number")
            t.expect(tmpl.atk).to_be_type("number")
            t.expect(tmpl.speed).to_be_type("number")
            t.expect(tmpl.behavior).to_be_type("string")
            t.expect(tmpl.floors).to_be_type("table")
        end
    end)

    t.it("chase_test", function()
        local world = sim.new_world(1)
        set_player_pos(world, 1, 1)
        local enemy = spawn.create_enemy(world, "skeleton", { x = 1, y = 3 })

        world.turn = 1
        local first = ai.choose_action(world, enemy.id)
        t.expect(first.type).to_be("wait")

        world.turn = 2
        local second = ai.choose_action(world, enemy.id)
        t.expect(second.type).to_be("chase")
        t.expect(second.dx).to_be(0)
        t.expect(second.dy).to_be(-1)
    end)

    t.it("attack_test", function()
        local world = sim.new_world(1)
        set_player_pos(world, 2, 2)
        local enemy = spawn.create_enemy(world, "goblin", { x = 2, y = 3 })
        local action = ai.choose_action(world, enemy.id)
        t.expect(action.type).to_be("attack")
        t.expect(action.target_id).to_be(world.player_id)
    end)

    t.it("ordering_test", function()
        local ordering = require("bargain.ai.ordering")
        local dirs = ordering.direction_order()
        t.expect(dirs[1].dx).to_be(0)
        t.expect(dirs[1].dy).to_be(-1)
        t.expect(dirs[2].dx).to_be(1)
        t.expect(dirs[2].dy).to_be(0)
        t.expect(dirs[3].dx).to_be(0)
        t.expect(dirs[3].dy).to_be(1)
        t.expect(dirs[4].dx).to_be(-1)
        t.expect(dirs[4].dy).to_be(0)

        local world = sim.new_world(1)
        spawn.create_enemy(world, "goblin", { x = 1, y = 3 })
        spawn.create_enemy(world, "goblin", { x = 2, y = 3 })
        spawn.create_enemy(world, "skeleton", { x = 3, y = 3 })
        local order = ordering.enemy_order(world)
        t.expect(order[1]).to_be("e.goblin.1")
        t.expect(order[2]).to_be("e.goblin.2")
        t.expect(order[3]).to_be("e.skeleton.1")
    end)

    t.it("tie_break_test", function()
        local world = sim.new_world(1)
        spawn.create_enemy(world, "goblin", { x = 1, y = 3 })
        spawn.create_enemy(world, "goblin", { x = 2, y = 3 })
        local order = ai.order_enemies(world)
        t.expect(order[1]).to_be("e.goblin.1")
        t.expect(order[2]).to_be("e.goblin.2")
    end)

    t.it("deterministic_targeting_test", function()
        local world = sim.new_world(1)
        set_player_pos(world, 1, 1)
        local enemy = spawn.create_enemy(world, "goblin", { x = 1, y = 3 })
        world.turn = 2

        local a1 = ai.choose_action(world, enemy.id)
        local a2 = ai.choose_action(world, enemy.id)
        t.expect(a1.type).to_be(a2.type)
        t.expect(a1.dx).to_be(a2.dx)
        t.expect(a1.dy).to_be(a2.dy)
    end)

    t.it("double_run_determinism_test", function()
        local function setup_world()
            local w = sim.new_world(1)
            set_player_pos(w, 1, 1)
            spawn.create_enemy(w, "goblin", { x = 1, y = 3 })
            spawn.create_enemy(w, "skeleton", { x = 3, y = 3 })
            w.turn = 2
            return w
        end

        local w1 = setup_world()
        local w2 = setup_world()

        local a1 = ai.step_enemies(w1)
        local a2 = ai.step_enemies(w2)
        t.expect(#a1).to_be(#a2)
        for i = 1, #a1 do
            t.expect(a1[i].action.type).to_be(a2[i].action.type)
            t.expect(a1[i].action.dx).to_be(a2[i].action.dx)
            t.expect(a1[i].action.dy).to_be(a2[i].action.dy)
            t.expect(a1[i].action.target_id).to_be(a2[i].action.target_id)
        end
    end)

    t.it("boss_test", function()
        local boss = require("bargain.enemies.boss")
        local world = sim.new_world(1)
        world.floor_num = 6
        local denied, err = boss.spawn(world, { x = 1, y = 1 })
        t.expect(denied).to_be_nil()
        t.expect(err).to_be("wrong_floor")

        world.floor_num = 7
        local enemy = boss.spawn(world, { x = 1, y = 3 })
        t.expect(enemy).to_be_type("table")
        t.expect(enemy.is_boss).to_be(true)

        world.turn = 1
        set_player_pos(world, 1, 1)
        local action = ai.choose_action(world, enemy.id)
        t.expect(action.type).never().to_be("wait")
    end)

    t.it("orders enemies by speed desc then id asc", function()
        local world = sim.new_world(1)
        spawn.create_enemy(world, "goblin", { x = 1, y = 3 })
        spawn.create_enemy(world, "skeleton", { x = 2, y = 3 })
        spawn.create_enemy(world, "goblin", { x = 3, y = 3 })

        local order = ai.order_enemies(world)
        t.expect(order[1]).to_be("e.goblin.1")
        t.expect(order[2]).to_be("e.goblin.2")
        t.expect(order[3]).to_be("e.skeleton.1")
    end)

    t.it("chases using canonical direction order", function()
        local world = sim.new_world(1)
        set_player_pos(world, 1, 1)
        local enemy = spawn.create_enemy(world, "skeleton", { x = 1, y = 3 })

        local action = ai.choose_action(world, enemy.id)
        t.expect(action.type).to_be("chase")
        t.expect(action.dx).to_be(0)
        t.expect(action.dy).to_be(-1)
    end)

    t.it("attacks when adjacent and deals damage", function()
        local world = sim.new_world(1)
        set_player_pos(world, 1, 1)
        local enemy = spawn.create_enemy(world, "goblin", { x = 1, y = 2 })
        local player = world.entities.by_id[world.player_id]
        local hp_before = player.hp

        local action = ai.step_enemy(world, enemy.id)
        t.expect(action.type).to_be("attack")
        t.expect(player.hp).to_be(hp_before - (enemy.atk or 1))
    end)
end)
