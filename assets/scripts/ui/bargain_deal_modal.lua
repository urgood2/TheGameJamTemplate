-- assets/scripts/ui/bargain_deal_modal.lua

local DealModal = {}

local function safeRequire(module)
    local ok, result = pcall(require, module)
    return ok and result or nil
end

local constants = safeRequire("bargain.sim.constants")
local loader = safeRequire("bargain.deals.loader")
local dsl = safeRequire("ui.ui_syntax_sugar")
local ui_scale = safeRequire("ui.ui_scale")
local z_orders = safeRequire("core.z_orders")

local UI = ui_scale and ui_scale.ui or function(v) return v end

local MODAL_WIDTH = UI(520)
local MODAL_PADDING = UI(12)
local DEAL_SPACING = UI(10)
local BUTTON_WIDTH = UI(120)
local BUTTON_HEIGHT = UI(32)

local state = {
    visible = false,
    modalEntity = nil,
    offer_key = nil,
    world = nil,
    on_input = nil,
    input_queue = {},
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

local function emit_input(payload)
    if state.on_input then
        state.on_input(payload)
        return
    end
    state.input_queue[#state.input_queue + 1] = payload
end

local function offer_key(pending)
    if not pending or type(pending.deals) ~= "table" then
        return ""
    end
    return table.concat(pending.deals, "|")
end

local function build_deal_nodes(deals)
    local nodes = {}
    if not dsl then
        return nodes
    end

    for _, deal in ipairs(deals) do
        local title = string.format("%s (%s)", deal.name or deal.id or "Deal", deal.sin or "?")
        local desc = deal.desc or ""
        local deal_id = deal.id

        local section = dsl.section(title, {
            titleBg = "black",
            color = "gray",
            padding = UI(8),
            children = {
                dsl.text(desc, { fontSize = UI(14), color = "white", shadow = false }),
                dsl.spacer(0, UI(6)),
                dsl.button("Accept", {
                    color = "green",
                    minWidth = BUTTON_WIDTH,
                    minHeight = BUTTON_HEIGHT,
                    onClick = function()
                        emit_input({ type = "deal_choose", deal_id = deal_id })
                    end,
                }),
            },
        })

        nodes[#nodes + 1] = section
    end

    return nodes
end

local function build_modal_def(deals)
    if not dsl then
        return nil
    end

    local deal_nodes = build_deal_nodes(deals)
    local content = {
        dsl.text("Choose a Deal", { fontSize = UI(20), color = "white", shadow = true }),
        dsl.vbox({ config = { spacing = DEAL_SPACING }, children = deal_nodes }),
        dsl.spacer(0, UI(6)),
        dsl.button("Skip", {
            color = "red",
            minWidth = BUTTON_WIDTH,
            minHeight = BUTTON_HEIGHT,
            onClick = function()
                emit_input({ type = "deal_skip" })
            end,
        }),
    }

    return dsl.root({
        config = { color = "blackberry", padding = MODAL_PADDING },
        children = {
            dsl.vbox({
                config = {
                    color = "charcoal",
                    padding = MODAL_PADDING,
                    spacing = DEAL_SPACING,
                    minWidth = MODAL_WIDTH,
                },
                children = content,
            })
        }
    })
end

function DealModal.isVisible()
    return state.visible
end

function DealModal.pop_input()
    if #state.input_queue == 0 then
        return nil
    end
    return table.remove(state.input_queue, 1)
end

function DealModal.set_context(world, on_input)
    state.world = world
    state.on_input = on_input
end

function DealModal.hide()
    if state.modalEntity and dsl and dsl.remove then
        dsl.remove(state.modalEntity)
    end
    state.modalEntity = nil
    state.visible = false
    state.offer_key = nil
end

function DealModal.show(world, on_input)
    if not dsl or not world or not world.deal_state then
        return false
    end

    local pending = world.deal_state.pending_offer
    if not pending or type(pending.deals) ~= "table" then
        return false
    end

    state.world = world
    state.on_input = on_input
    state.offer_key = offer_key(pending)

    local data = loader and loader.load and loader.load() or { by_id = {} }
    local deals = {}
    for _, id in ipairs(pending.deals) do
        local deal = (data.by_id and data.by_id[id]) or { id = id, name = id, desc = "", sin = "?" }
        deals[#deals + 1] = deal
    end

    local modal_def = build_modal_def(deals)
    if not modal_def then
        return false
    end

    local screenW, screenH = resolve_screen()
    local estimated_height = UI(180 + (#deals * 120))
    local pos = {
        x = (screenW - MODAL_WIDTH) * 0.5,
        y = (screenH - estimated_height) * 0.5,
    }

    if state.modalEntity and dsl.remove then
        dsl.remove(state.modalEntity)
        state.modalEntity = nil
    end

    local z_index = (z_orders and z_orders.ui_tooltips or 900) + 10
    state.modalEntity = dsl.spawn(pos, modal_def, "ui", z_index)
    state.visible = true
    return true
end

function DealModal.update(world, on_input)
    local ctx_world = world or state.world or rawget(_G, "bargain_world")
    local ctx_input = on_input or state.on_input or rawget(_G, "bargain_on_input")

    if not ctx_world or not constants then
        if state.visible then
            DealModal.hide()
        end
        return
    end

    if ctx_world.phase ~= constants.PHASES.DEAL_CHOICE then
        if state.visible then
            DealModal.hide()
        end
        return
    end

    local pending = ctx_world.deal_state and ctx_world.deal_state.pending_offer
    if not pending or type(pending.deals) ~= "table" then
        if state.visible then
            DealModal.hide()
        end
        return
    end

    local key = offer_key(pending)
    if not state.visible or state.offer_key ~= key then
        DealModal.show(ctx_world, ctx_input)
    end
end

return DealModal
