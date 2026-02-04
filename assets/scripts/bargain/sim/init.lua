-- assets/scripts/bargain/sim/init.lua

local constants = require("bargain.sim.constants")
local deal_apply = require("bargain.deals.apply")
local deal_offers = require("bargain.deals.offers")
local ai_system = require("bargain.ai.system")
local RNG = require("bargain.sim.rng")
local events = require("bargain.sim.events")
local stats = require("bargain.sim.stats")
local move_action = require("bargain.sim.actions.move")
local attack_action = require("bargain.sim.actions.attack")
local wait_action = require("bargain.sim.actions.wait")
local deal_skip_action = require("bargain.sim.actions.deal_skip")

local sim = {}

local function is_unit_dir(value)
    return value == -1 or value == 0 or value == 1
end

local function validate_input(input, phase)
    if type(input) ~= "table" then
        return false, "input_not_table"
    end

    local input_type = input.type
    if type(input_type) ~= "string" then
        return false, "input_missing_type"
    end

    if phase == constants.PHASES.DEAL_CHOICE then
        if input_type ~= "deal_choose" and input_type ~= "deal_skip" then
            return false, "deal_choice_required"
        end
    end

    if input_type == "move" or input_type == "attack" then
        if type(input.dx) ~= "number" or type(input.dy) ~= "number" then
            return false, "missing_direction"
        end
        if not is_unit_dir(input.dx) or not is_unit_dir(input.dy) then
            return false, "invalid_direction"
        end
        return true
    end

    if input_type == "wait" then
        return true
    end

    if input_type == "deal_choose" then
        if type(input.deal_id) ~= "string" then
            return false, "missing_deal_id"
        end
        return true
    end

    if input_type == "deal_skip" then
        return true
    end

    return false, "unknown_input_type"
end

local VALID_PHASES = {
    [constants.PHASES.DEAL_CHOICE] = true,
    [constants.PHASES.PLAYER_INPUT] = true,
    [constants.PHASES.PLAYER_ACTION] = true,
    [constants.PHASES.ENEMY_ACTIONS] = true,
    [constants.PHASES.END_TURN] = true,
}

local VALID_RUN_STATES = {
    [constants.RUN_STATES.RUNNING] = true,
    [constants.RUN_STATES.VICTORY] = true,
    [constants.RUN_STATES.DEATH] = true,
}

local function advance_phase(world)
    local phase = world.phase
    if phase == constants.PHASES.DEAL_CHOICE then
        world.phase = constants.PHASES.PLAYER_INPUT
        return
    end

    if phase == constants.PHASES.PLAYER_INPUT then
        world.phase = constants.PHASES.PLAYER_ACTION
    elseif phase == constants.PHASES.PLAYER_ACTION then
        world.phase = constants.PHASES.ENEMY_ACTIONS
    elseif phase == constants.PHASES.ENEMY_ACTIONS then
        world.phase = constants.PHASES.END_TURN
    elseif phase == constants.PHASES.END_TURN then
        world.phase = constants.PHASES.PLAYER_INPUT
        world.turn = (world.turn or 0) + 1
        stats.on_turn(world)
    else
        world.phase = constants.PHASES.PLAYER_INPUT
    end
end

local function consume_turn(world)
    world.turn = (world.turn or 0) + 1
    world.phase = constants.PHASES.PLAYER_INPUT
    stats.on_turn(world)
end

local function apply_caps(world)
    local steps = world._steps or 0
    local transitions = world._internal_transitions or 0
    if steps >= constants.MAX_STEPS_PER_RUN or transitions >= constants.MAX_INTERNAL_TRANSITIONS then
        world.caps_hit = true
        world.run_state = constants.RUN_STATES.DEATH
        return true
    end
    return false
end

function sim.new_world(seed)
    local s = seed or 0
    return {
        seed = s,
        rng = RNG.new(s),
        turn = 0,
        floor_num = 1,
        phase = constants.PHASES.PLAYER_INPUT,
        run_state = constants.RUN_STATES.RUNNING,
        caps_hit = false,
        player_id = "p.1",
        grid = {
            w = 3,
            h = 3,
            tiles = {},
        },
        entities = {
            order = { "p.1" },
            by_id = {
                ["p.1"] = {
                    id = "p.1",
                    kind = "player",
                    pos = { x = 1, y = 1 },
                    hp = 10,
                },
            },
        },
        deal_state = {
            pending_offer = nil,
            offers = {},
            chosen = {},
        },
        stats = {
            hp_lost_total = 0,
            turns_elapsed = 0,
            damage_dealt_total = 0,
            damage_taken_total = 0,
            forced_actions_count = 0,
            denied_actions_count = 0,
            visible_tiles_count = 0,
            resources_spent_total = 0,
        },
        _steps = 0,
        _internal_transitions = 0,
    }
end

function sim.validate_world(world)
    local errors = {}
    if type(world) ~= "table" then
        return false, { "world_not_table" }
    end

    local required = {
        { key = "seed", type = "number" },
        { key = "rng", type = "table" },
        { key = "turn", type = "number" },
        { key = "floor_num", type = "number" },
        { key = "phase", type = "string" },
        { key = "run_state", type = "string" },
        { key = "caps_hit", type = "boolean" },
        { key = "player_id", type = "string" },
        { key = "grid", type = "table" },
        { key = "entities", type = "table" },
        { key = "deal_state", type = "table" },
        { key = "stats", type = "table" },
    }

    for _, req in ipairs(required) do
        if type(world[req.key]) ~= req.type then
            errors[#errors + 1] = req.key
        end
    end

    local phase_ok = false
    if VALID_PHASES[world.phase] then
        phase_ok = true
    end
    if not phase_ok then
        errors[#errors + 1] = "phase_invalid"
    end

    local run_ok = false
    if VALID_RUN_STATES[world.run_state] then
        run_ok = true
    end
    if not run_ok then
        errors[#errors + 1] = "run_state_invalid"
    end

    return #errors == 0, errors
end

function sim.step(world, input)
    if type(world) ~= "table" then
        return { ok = false, err = "world_not_table", events = {}, world = world }
    end

    if world.run_state ~= constants.RUN_STATES.RUNNING then
        return { ok = false, err = "run_complete", events = {}, world = world }
    end

    events.begin(world)
    local function finish(ok, err)
        return { ok = ok, err = err, events = events.snapshot(world), world = world }
    end

    world._steps = (world._steps or 0) + 1
    world._internal_transitions = (world._internal_transitions or 0) + 1

    if apply_caps(world) then
        return finish(false, "cap_hit")
    end

    if world.phase == constants.PHASES.PLAYER_INPUT and world.deal_state then
        local queue = world.deal_state.offer_queue
        if type(queue) == "table" and #queue > 0 and not world.deal_state.pending_offer then
            world.phase = constants.PHASES.DEAL_CHOICE
            world.deal_state.pending_offer = table.remove(queue, 1)
        end
    end

    local valid, err = validate_input(input, world.phase)
    if not valid then
        if world.phase ~= constants.PHASES.DEAL_CHOICE then
            consume_turn(world)
        end
        return finish(false, err)
    end

    local wait_consumes_turn = false
    if input.type == "move" then
        move_action.apply(world, input.dx, input.dy)
    elseif input.type == "attack" then
        local ok, attack_err = attack_action.apply(world, input.dx, input.dy)
        if not ok then
            consume_turn(world)
            return finish(false, attack_err)
        end
    elseif input.type == "wait" then
        local before_phase = world.phase
        wait_action.apply(world)
        if before_phase == constants.PHASES.PLAYER_INPUT then
            world.phase = constants.PHASES.ENEMY_ACTIONS
            wait_consumes_turn = true
        end
    end

    if world.phase == constants.PHASES.DEAL_CHOICE then
        world.deal_state = world.deal_state or {}
        if not world.deal_state.pending_offer then
            deal_offers.create_pending_offer(world, "floor_start")
        end

        if input.type == "deal_skip" then
            local ok, skip_err = deal_skip_action.apply(world, input)
            if not ok then
                return finish(false, skip_err)
            end
        elseif input.type == "deal_choose" then
            local pending = world.deal_state.pending_offer
            local offered = {}
            if pending and type(pending.deals) == "table" then
                for _, id in ipairs(pending.deals) do
                    offered[id] = true
                end
            end
            if next(offered) and not offered[input.deal_id] then
                return finish(false, "deal_not_offered")
            end
            local ok, apply_err = deal_apply.apply_deal(world, input.deal_id)
            if not ok then
                return finish(false, apply_err)
            end
            world.deal_state.pending_offer = nil
            world.phase = constants.PHASES.PLAYER_INPUT
        end
    elseif world.phase == constants.PHASES.ENEMY_ACTIONS then
        if not wait_consumes_turn then
            ai_system.step_enemies(world)
            world.phase = constants.PHASES.END_TURN
        end
    else
        advance_phase(world)
    end

    return finish(true)
end

sim.constants = constants

return sim
