-- assets/scripts/ui/bargain_death_screen.lua

local DeathScreen = {}

local function safeRequire(module)
    local ok, result = pcall(require, module)
    return ok and result or nil
end

local constants = safeRequire("bargain.sim.constants")
local dsl = safeRequire("ui.ui_syntax_sugar")
local ui_scale = safeRequire("ui.ui_scale")
local z_orders = safeRequire("core.z_orders")
local signal = safeRequire("external.hump.signal")

local UI = ui_scale and ui_scale.ui or function(v) return v end

local state = {
    visible = false,
    entity = nil,
    world = nil,
    on_restart = nil,
}

local function resolve_screen()
    local screenW = 1920
    local screenH = 1080
    if _G.globals then
        if globals.screenWidth then
            screenW = globals.screenWidth()
        elseif globals.getScreenWidth then
            screenW = globals.getScreenWidth()
        end
        if globals.screenHeight then
            screenH = globals.screenHeight()
        elseif globals.getScreenHeight then
            screenH = globals.getScreenHeight()
        end
    end
    return screenW, screenH
end

local function emit_restart()
    if state.on_restart then
        state.on_restart()
        return
    end
    if signal and signal.emit then
        signal.emit("restart_game")
    end
end

local function stat_value(label, value)
    return string.format("%s: %s", label, tostring(value))
end

local function stat_floor()
    local floor_num = state.world and state.world.floor_num or 0
    return stat_value("Floor", floor_num)
end

local function stat_turn()
    local turn = state.world and state.world.turn or 0
    return stat_value("Turn", turn)
end

local function stat_damage_dealt()
    local stats = state.world and state.world.stats or nil
    local value = stats and stats.damage_dealt_total or 0
    return stat_value("Damage dealt", value)
end

local function stat_damage_taken()
    local stats = state.world and state.world.stats or nil
    local value = stats and stats.damage_taken_total or 0
    return stat_value("Damage taken", value)
end

local function stat_hp_lost()
    local stats = state.world and state.world.stats or nil
    local value = stats and stats.hp_lost_total or 0
    return stat_value("HP lost", value)
end

local function stat_deals()
    local chosen = state.world and state.world.deal_state and state.world.deal_state.chosen
    local count = type(chosen) == "table" and #chosen or 0
    return stat_value("Deals chosen", count)
end

local function stat_caps_hit()
    local caps_hit = state.world and state.world.caps_hit
    return stat_value("Caps hit", caps_hit and "yes" or "no")
end

local function build_screen_def()
    if not dsl then
        return nil
    end

    return dsl.root({
        config = {
            color = "blackberry",
            padding = UI(14),
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
        },
        children = {
            dsl.vbox({
                config = {
                    color = "charcoal",
                    padding = UI(16),
                    spacing = UI(8),
                    minWidth = UI(420),
                },
                children = {
                    dsl.text("Death", { fontSize = UI(28), color = "red", shadow = true }),
                    dsl.text("Run Summary", { fontSize = UI(16), color = "white" }),
                    dsl.dynamicText(stat_floor, UI(16), "", { color = "white" }),
                    dsl.dynamicText(stat_turn, UI(16), "", { color = "white" }),
                    dsl.dynamicText(stat_damage_dealt, UI(14), "", { color = "gray" }),
                    dsl.dynamicText(stat_damage_taken, UI(14), "", { color = "gray" }),
                    dsl.dynamicText(stat_hp_lost, UI(14), "", { color = "gray" }),
                    dsl.dynamicText(stat_deals, UI(14), "", { color = "gray" }),
                    dsl.dynamicText(stat_caps_hit, UI(14), "", { color = "gray" }),
                    dsl.spacer(0, UI(6)),
                    dsl.button("Restart", {
                        color = "green",
                        minWidth = UI(140),
                        minHeight = UI(34),
                        onClick = emit_restart,
                    }),
                },
            }),
        },
    })
end

function DeathScreen.isVisible()
    return state.visible
end

function DeathScreen.set_context(world, on_restart)
    state.world = world
    state.on_restart = on_restart
end

function DeathScreen.hide()
    if state.entity and dsl and dsl.remove then
        dsl.remove(state.entity)
    end
    state.entity = nil
    state.visible = false
end

function DeathScreen.show(world)
    if not dsl then
        return false
    end

    state.world = world

    local screen_def = build_screen_def()
    if not screen_def then
        return false
    end

    if state.entity and dsl.remove then
        dsl.remove(state.entity)
        state.entity = nil
    end

    local screenW, screenH = resolve_screen()
    local pos = {
        x = (screenW - UI(420)) * 0.5,
        y = (screenH - UI(330)) * 0.5,
    }
    local z_index = (z_orders and z_orders.ui_tooltips or 900) + 15
    state.entity = dsl.spawn(pos, screen_def, "ui", z_index)
    state.visible = true
    return true
end

function DeathScreen.update(world, on_restart)
    local ctx_world = world or state.world or rawget(_G, "bargain_world")
    local ctx_restart = on_restart or state.on_restart or rawget(_G, "bargain_on_restart")

    state.world = ctx_world
    state.on_restart = ctx_restart

    if not ctx_world or not constants or ctx_world.run_state ~= constants.RUN_STATES.DEATH then
        if state.visible then
            DeathScreen.hide()
        end
        return
    end

    if not state.visible then
        DeathScreen.show(ctx_world)
    end

    if isKeyPressed and (isKeyPressed("KEY_ENTER") or isKeyPressed("KEY_SPACE")) then
        emit_restart()
    end
end

return DeathScreen
