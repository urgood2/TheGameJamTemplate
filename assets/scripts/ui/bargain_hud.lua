-- assets/scripts/ui/bargain_hud.lua

local BargainHUD = {}

local function safeRequire(module)
    local ok, result = pcall(require, module)
    return ok and result or nil
end

local dsl = safeRequire("ui.ui_syntax_sugar")
local ui_scale = safeRequire("ui.ui_scale")
local z_orders = safeRequire("core.z_orders")

local UI = ui_scale and ui_scale.ui or function(v) return v end

local state = {
    visible = false,
    entity = nil,
    world = nil,
}

local function get_player(world)
    if not world or type(world.entities) ~= "table" then
        return nil
    end
    return world.entities[world.player_id]
end

local function format_hp()
    local player = get_player(state.world)
    local hp = player and player.hp or 0
    return string.format("HP: %s", tostring(hp))
end

local function format_floor()
    local floor_num = state.world and state.world.floor_num or 0
    return string.format("Floor: %s", tostring(floor_num))
end

local function format_turn()
    local turn = state.world and state.world.turn or 0
    return string.format("Turn: %s", tostring(turn))
end

local function format_deals()
    local chosen = state.world and state.world.deal_state and state.world.deal_state.chosen
    if type(chosen) ~= "table" or #chosen == 0 then
        return "Deals: none"
    end
    return "Deals: " .. table.concat(chosen, ", ")
end

local function build_hud_def()
    if not dsl then
        return nil
    end

    return dsl.root({
        config = {
            color = "blackberry",
            padding = UI(8),
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },
        children = {
            dsl.vbox({
                config = {
                    color = "charcoal",
                    padding = UI(8),
                    spacing = UI(4),
                },
                children = {
                    dsl.dynamicText(format_hp, UI(16), "", { color = "white" }),
                    dsl.dynamicText(format_floor, UI(16), "", { color = "white" }),
                    dsl.dynamicText(format_turn, UI(16), "", { color = "white" }),
                    dsl.dynamicText(format_deals, UI(14), "", { color = "gray" }),
                },
            }),
        },
    })
end

function BargainHUD.isVisible()
    return state.visible
end

function BargainHUD.set_context(world)
    state.world = world
end

function BargainHUD.hide()
    if state.entity and dsl and dsl.remove then
        dsl.remove(state.entity)
    end
    state.entity = nil
    state.visible = false
end

function BargainHUD.show(world)
    if not dsl then
        return false
    end

    state.world = world

    local hud_def = build_hud_def()
    if not hud_def then
        return false
    end

    if state.entity and dsl.remove then
        dsl.remove(state.entity)
        state.entity = nil
    end

    local pos = { x = UI(12), y = UI(12) }
    local z_index = (z_orders and z_orders.ui_tooltips or 900) + 5
    state.entity = dsl.spawn(pos, hud_def, "ui", z_index)
    state.visible = true
    return true
end

function BargainHUD.update(world)
    local ctx_world = world or state.world or rawget(_G, "bargain_world")
    state.world = ctx_world

    if not ctx_world or not dsl then
        if state.visible then
            BargainHUD.hide()
        end
        return
    end

    if not state.visible then
        BargainHUD.show(ctx_world)
    end
end

return BargainHUD
