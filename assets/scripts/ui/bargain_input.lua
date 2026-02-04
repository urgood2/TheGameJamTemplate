-- assets/scripts/ui/bargain_input.lua

local BargainInput = {}

local function safeRequire(module)
    local ok, result = pcall(require, module)
    return ok and result or nil
end

local constants = safeRequire("bargain.sim.constants")
local DealModal = safeRequire("ui.bargain_deal_modal")
local BargainHUD = safeRequire("ui.bargain_hud")
local VictoryScreen = safeRequire("ui.bargain_victory_screen")
local DeathScreen = safeRequire("ui.bargain_death_screen")

local state = {
    world = nil,
    on_input = nil,
    input_queue = {},
}

local KEY_MAPPINGS = {
    up = { "KEY_UP", "KEY_W" },
    down = { "KEY_DOWN", "KEY_S" },
    left = { "KEY_LEFT", "KEY_A" },
    right = { "KEY_RIGHT", "KEY_D" },
    wait = { "KEY_SPACE", "KEY_ENTER" },
    deal_choose = { "KEY_ONE", "KEY_TWO", "KEY_THREE" },
    deal_skip = { "KEY_ESCAPE", "KEY_BACKSPACE" },
}

local function emit_input(payload)
    if state.on_input then
        state.on_input(payload)
    end
    state.input_queue[#state.input_queue + 1] = payload
end

local function is_pressed(key)
    return isKeyPressed and isKeyPressed(key) == true
end

local function any_pressed(keys)
    for _, key in ipairs(keys) do
        if is_pressed(key) then
            return true
        end
    end
    return false
end

local function read_move_input()
    local dx, dy = 0, 0
    if any_pressed(KEY_MAPPINGS.left) then dx = dx - 1 end
    if any_pressed(KEY_MAPPINGS.right) then dx = dx + 1 end
    if any_pressed(KEY_MAPPINGS.up) then dy = dy - 1 end
    if any_pressed(KEY_MAPPINGS.down) then dy = dy + 1 end
    if dx == 0 and dy == 0 then
        return nil
    end
    return { type = "move", dx = dx, dy = dy }
end

local function handle_deal_input(world)
    if not constants or not world or world.phase ~= constants.PHASES.DEAL_CHOICE then
        return false
    end

    local pending = world.deal_state and world.deal_state.pending_offer
    if not pending or type(pending.deals) ~= "table" then
        return false
    end

    for i, key in ipairs(KEY_MAPPINGS.deal_choose) do
        if is_pressed(key) then
            local deal_id = pending.deals[i]
            if deal_id then
                emit_input({ type = "deal_choose", deal_id = deal_id })
                return true
            end
        end
    end

    if any_pressed(KEY_MAPPINGS.deal_skip) then
        emit_input({ type = "deal_skip" })
        return true
    end

    return false
end

local function handle_player_input(world)
    if not constants or not world or world.phase ~= constants.PHASES.PLAYER_INPUT then
        return false
    end

    local move_input = read_move_input()
    if move_input then
        emit_input(move_input)
        return true
    end

    if any_pressed(KEY_MAPPINGS.wait) then
        emit_input({ type = "wait" })
        return true
    end

    return false
end

function BargainInput.pop_input()
    if #state.input_queue == 0 then
        return nil
    end
    return table.remove(state.input_queue, 1)
end

function BargainInput.set_context(world, on_input)
    state.world = world
    state.on_input = on_input
end

function BargainInput.update(world, on_input)
    local ctx_world = world or state.world or rawget(_G, "bargain_world")
    local ctx_input = on_input or state.on_input or rawget(_G, "bargain_on_input")

    if ctx_world ~= state.world or ctx_input ~= state.on_input then
        state.world = ctx_world
        state.on_input = ctx_input
    end

    if BargainHUD and BargainHUD.update then
        BargainHUD.update(ctx_world)
    end
    if VictoryScreen and VictoryScreen.update then
        VictoryScreen.update(ctx_world)
    end
    if DeathScreen and DeathScreen.update then
        DeathScreen.update(ctx_world)
    end

    if DealModal and DealModal.update then
        DealModal.update(ctx_world, emit_input)
    end

    if not ctx_world then
        return
    end
    if constants and ctx_world.run_state ~= constants.RUN_STATES.RUNNING then
        return
    end

    if handle_deal_input(ctx_world) then
        return
    end

    handle_player_input(ctx_world)
end

return BargainInput
