-- assets/scripts/tests/bargain/contracts_spec.lua

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local sim = require("bargain.sim")
local constants = require("bargain.sim.constants")

t.describe("Bargain contracts", function()
    t.it("world schema includes required fields", function()
        local world = sim.new_world(123)
        t.expect(world).to_be_type("table")
        t.expect(world.seed).to_be(123)
        t.expect(world.rng).to_be_type("table")
        t.expect(world.turn).to_be_type("number")
        t.expect(world.floor_num).to_be_type("number")
        t.expect(world.phase).to_be(constants.PHASES.PLAYER_INPUT)
        t.expect(world.run_state).to_be(constants.RUN_STATES.RUNNING)
        t.expect(world.caps_hit).to_be(false)
        t.expect(world.player_id).to_be_type("string")
        t.expect(world.grid).to_be_type("table")
        t.expect(world.entities).to_be_type("table")
        t.expect(world.deal_state).to_be_type("table")
        t.expect(world.stats).to_be_type("table")

        local ok, errors = sim.validate_world(world)
        t.expect(ok).to_be(true)
        t.expect(#errors).to_be(0)
    end)

    t.it("grid_test", function()
        local grid = require("bargain.sim.grid")
        local state = grid.build(5, 5)
        t.expect(state.w).to_be(5)
        t.expect(state.h).to_be(5)
        t.expect(state.tiles).to_be_type("table")
        t.expect(state.tiles[1][1]).to_be(grid.TILES.wall)
        t.expect(state.tiles[2][2]).to_be(grid.TILES.floor)
        t.expect(state.tiles[4][4]).to_be(grid.TILES.stairs_down)
        t.expect(grid.in_bounds(state, 1, 1)).to_be(true)
        t.expect(grid.in_bounds(state, 0, 1)).to_be(false)
        t.expect(grid.in_bounds(state, 5, 6)).to_be(false)
        t.expect(grid.get_tile(state, 2, 2)).to_be(grid.TILES.floor)
    end)

    t.it("floor_transition_test", function()
        local transition = require("bargain.floors.transition")
        local world = sim.new_world(17)

        world.floor_num = 1
        local ok, next_floor = transition.descend(world)
        t.expect(ok).to_be(true)
        t.expect(world.floor_num).to_be(2)
        t.expect(next_floor).to_be(2)
        t.expect(transition.is_boss_floor(world)).to_be(false)

        world.floor_num = 6
        local ok2 = transition.descend(world)
        t.expect(ok2).to_be(true)
        t.expect(world.floor_num).to_be(7)
        t.expect(transition.is_boss_floor(world)).to_be(true)

        local ok3 = transition.descend(world)
        t.expect(ok3).to_be(false)
        t.expect(world.floor_num).to_be(7)
    end)

    t.it("step returns ok/events/world for valid input", function()
        local world = sim.new_world(1)
        local result = sim.step(world, { type = "wait" })
        t.expect(result.ok).to_be(true)
        t.expect(result.events).to_be_type("table")
        t.expect(result.world).to_be(world)
    end)

    t.it("invalid input consumes turn in player input", function()
        local world = sim.new_world(1)
        world.phase = constants.PHASES.PLAYER_INPUT
        local start_turn = world.turn
        local result = sim.step(world, { type = "move", dx = 2, dy = 0 })
        t.expect(result.ok).to_be(false)
        t.expect(world.turn).to_be(start_turn + 1)
        t.expect(world.phase).to_be(constants.PHASES.PLAYER_INPUT)
    end)

    t.it("deal choice pins phase until resolved", function()
        local world = sim.new_world(1)
        world.phase = constants.PHASES.DEAL_CHOICE
        world.deal_state.pending_offer = { id = "deal.1" }

        local rejected = sim.step(world, { type = "move", dx = 1, dy = 0 })
        t.expect(rejected.ok).to_be(false)
        t.expect(world.phase).to_be(constants.PHASES.DEAL_CHOICE)
        t.expect(world.deal_state.pending_offer).to_be_truthy()

        local resolved = sim.step(world, { type = "deal_skip" })
        t.expect(resolved.ok).to_be(true)
        t.expect(world.phase).to_be(constants.PHASES.PLAYER_INPUT)
        t.expect(world.deal_state.pending_offer).to_be_nil()
    end)

    t.it("deal_choose_test", function()
        local action = require("bargain.sim.actions.deal_choose")
        local loader = require("bargain.deals.loader")

        local data = loader.load()
        local deal = data.list[1]

        local world = sim.new_world(2)
        world.phase = constants.PHASES.DEAL_CHOICE
        world.deal_state.pending_offer = { deals = { deal.id } }

        local key, delta = next(deal.downside or {})
        if key then
            world.stats[key] = 0
        end

        local ok = action.apply(world, { type = "deal_choose", deal_id = deal.id })
        t.expect(ok).to_be(true)
        t.expect(world.phase).to_be(constants.PHASES.PLAYER_INPUT)
        t.expect(world.deal_state.pending_offer).to_be_nil()

        local chosen = false
        for _, id in ipairs(world.deal_state.chosen or {}) do
            if id == deal.id then
                chosen = true
                break
            end
        end
        t.expect(chosen).to_be(true)
        if key then
            t.expect(world.stats[key]).to_be(delta)
        end

        local world_bad = sim.new_world(3)
        world_bad.phase = constants.PHASES.DEAL_CHOICE
        world_bad.deal_state.pending_offer = { deals = { deal.id } }
        local bad = action.apply(world_bad, { type = "deal_choose", deal_id = "unknown.id" })
        t.expect(bad).to_be(false)
        t.expect(world_bad.phase).to_be(constants.PHASES.DEAL_CHOICE)
        t.expect(world_bad.deal_state.pending_offer).to_be_truthy()
    end)

    t.it("deal_skip_test", function()
        local action = require("bargain.sim.actions.deal_skip")
        local loader = require("bargain.deals.loader")

        local data = loader.load()
        local deal = data.list[1]

        local world = sim.new_world(2)
        world.phase = constants.PHASES.DEAL_CHOICE
        world.deal_state.pending_offer = { deals = { deal.id } }
        world.deal_state.chosen = {}
        world.stats.damage_taken_total = world.stats.damage_taken_total or 0
        local before = world.stats.damage_taken_total

        local ok = action.apply(world, { type = "deal_skip" })
        t.expect(ok).to_be(true)
        t.expect(world.phase).to_be(constants.PHASES.PLAYER_INPUT)
        t.expect(world.deal_state.pending_offer).to_be_nil()
        t.expect(#(world.deal_state.chosen or {})).to_be(0)
        t.expect(world.stats.damage_taken_total).to_be(before)
    end)

    t.it("event_test", function()
        local events = require("bargain.sim.events")
        local spawn = require("bargain.enemies.spawn")
        local loader = require("bargain.deals.loader")

        local world_move = sim.new_world(1)
        local moved = sim.step(world_move, { type = "move", dx = 1, dy = 0 })
        t.expect(moved.ok).to_be(true)
        t.expect(moved.events[1].type).to_be("move")

        local world_attack = sim.new_world(2)
        local player = world_attack.entities.by_id[world_attack.player_id]
        player.pos.x = 2
        player.pos.y = 2
        local enemy = spawn.create_enemy(world_attack, "rat", { x = 2, y = 1 })
        enemy.hp = 1
        local attacked = sim.step(world_attack, { type = "attack", dx = 0, dy = -1 })
        t.expect(attacked.ok).to_be(true)
        t.expect(attacked.events[1].type).to_be("damage")
        t.expect(attacked.events[#attacked.events].type).to_be("death")

        local world_deal = sim.new_world(3)
        local data = loader.load()
        local deal = data.list[1]
        world_deal.phase = constants.PHASES.DEAL_CHOICE
        world_deal.deal_state.pending_offer = { deals = { deal.id } }
        local dealt = sim.step(world_deal, { type = "deal_choose", deal_id = deal.id })
        local found = false
        for _, ev in ipairs(dealt.events) do
            if ev.type == "deal_applied" and ev.deal_id == deal.id then
                found = true
                break
            end
        end
        t.expect(found).to_be(true)

        events.begin(world_deal)
        for i = 1, 25 do
            events.emit(world_deal, { type = "test", idx = i })
        end
        local snapshot = events.snapshot(world_deal)
        t.expect(#snapshot).to_be(20)
        t.expect(snapshot[1].idx).to_be(1)
        t.expect(snapshot[20].idx).to_be(20)
    end)

    t.it("phase machine cycles in canonical order", function()
        local world = sim.new_world(1)
        t.expect(world.phase).to_be(constants.PHASES.PLAYER_INPUT)

        sim.step(world, { type = "move", dx = 0, dy = 0 })
        t.expect(world.phase).to_be(constants.PHASES.PLAYER_ACTION)

        sim.step(world, { type = "move", dx = 0, dy = 0 })
        t.expect(world.phase).to_be(constants.PHASES.ENEMY_ACTIONS)

        sim.step(world, { type = "move", dx = 0, dy = 0 })
        t.expect(world.phase).to_be(constants.PHASES.END_TURN)

        local start_turn = world.turn
        sim.step(world, { type = "move", dx = 0, dy = 0 })
        t.expect(world.phase).to_be(constants.PHASES.PLAYER_INPUT)
        t.expect(world.turn).to_be(start_turn + 1)
    end)

    t.it("caps trip forces terminal death", function()
        local world = sim.new_world(1)
        world._steps = constants.MAX_STEPS_PER_RUN - 1
        local result = sim.step(world, { type = "wait" })
        t.expect(result.ok).to_be(false)
        t.expect(world.caps_hit).to_be(true)
        t.expect(world.run_state).to_be(constants.RUN_STATES.DEATH)
    end)

    t.it("deal_apply_test", function()
        local apply = require("bargain.deals.apply")
        local loader = require("bargain.deals.loader")

        local data = loader.load()
        local deal = data.list[1]

        local original_apply = deal.on_apply
        local original_floor = deal.on_floor_start
        local original_level = deal.on_level_up

        local world = { stats = {}, deal_state = { chosen = {} } }
        local called = { apply = 0, floor = 0, level = 0 }

        deal.on_apply = function(w)
            w.stats.apply_calls = (w.stats.apply_calls or 0) + 1
            called.apply = called.apply + 1
        end
        deal.on_floor_start = function(w)
            w.stats.floor_calls = (w.stats.floor_calls or 0) + 1
            called.floor = called.floor + 1
        end
        deal.on_level_up = function(w)
            w.stats.level_calls = (w.stats.level_calls or 0) + 1
            called.level = called.level + 1
        end

        local ok = apply.apply_deal(world, deal.id)
        t.expect(ok).to_be(true)
        t.expect(called.apply).to_be(1)
        t.expect(world.stats.apply_calls).to_be(1)

        local floor_ok = apply.dispatch(world, "on_floor_start")
        t.expect(floor_ok).to_be(true)
        t.expect(called.floor).to_be(1)
        t.expect(world.stats.floor_calls).to_be(1)

        local level_ok = apply.dispatch(world, "on_level_up")
        t.expect(level_ok).to_be(true)
        t.expect(called.level).to_be(1)
        t.expect(world.stats.level_calls).to_be(1)

        deal.on_apply = original_apply
        deal.on_floor_start = original_floor
        deal.on_level_up = original_level
    end)

    t.it("stats_tracking_test", function()
        local stats = require("bargain.sim.stats")

        local world_a = sim.new_world(5)
        local world_b = sim.new_world(5)

        stats.ensure(world_a)
        stats.ensure(world_b)
        for i = 1, #stats.KEYS do
            t.expect(world_a.stats[stats.KEYS[i]]).to_be_type("number")
            t.expect(world_b.stats[stats.KEYS[i]]).to_be_type("number")
        end

        local inputs = {
            { type = "wait" },
            { type = "wait" },
            { type = "wait" },
            { type = "wait" },
        }
        for _, input in ipairs(inputs) do
            sim.step(world_a, input)
            sim.step(world_b, input)
        end

        for i = 1, #stats.KEYS do
            local key = stats.KEYS[i]
            t.expect(world_a.stats[key]).to_be(world_b.stats[key])
        end
        t.expect(world_a.stats.turns_elapsed).to_be(1)
    end)

    t.it("entity_test", function()
        local entities = require("bargain.sim.entities")

        local reg = entities.new_registry()
        local player = entities.spawn(reg, "player", {
            x = 1,
            y = 2,
            hp = 10,
            max_hp = 10,
            speed = 2,
            damage = 3,
        })
        local enemy = entities.spawn(reg, "enemy", {
            x = 3,
            y = 4,
            hp = 4,
            speed = 1,
            damage = 1,
        })
        local boss = entities.spawn(reg, "boss", {
            x = 5,
            y = 6,
            hp = 12,
            speed = 1,
            damage = 4,
        })

        t.expect(player.type).to_be("player")
        t.expect(enemy.type).to_be("enemy")
        t.expect(boss.type).to_be("boss")
        t.expect(player.hp).to_be(10)
        t.expect(player.max_hp).to_be(10)

        local ids = entities.ordered_ids(reg)
        t.expect(#ids).to_be(3)
        t.expect(ids[1] <= ids[2]).to_be(true)
        t.expect(ids[2] <= ids[3]).to_be(true)

        entities.remove(reg, enemy.id)
        local enemy2 = entities.spawn(reg, "enemy", { x = 7, y = 8, hp = 2 })
        t.expect(enemy2.id).never().to_be(enemy.id)
    end)
end)
