--[[
Crusenho UI Pack Demo

Additive demo module that reuses the existing UI system:
- ui.register_pack/ui.use_pack
- regular DSL containers/text/layout
- per-entity initFunc to apply pack-provided UIConfig
]]

local dsl = require("ui.ui_syntax_sugar")
local component_cache = require("core.component_cache")

local Demo = {}

local PACK_NAME = "crusenho_flat"
local PACK_MANIFEST = "assets/ui_packs/crusenho_flat/pack.json"

local cachedPack = nil
local attemptedRegistration = false

local function ensurePack()
    if cachedPack then
        return cachedPack
    end

    if not attemptedRegistration then
        attemptedRegistration = true
        local existing = ui.use_pack(PACK_NAME)
        if not existing then
            local ok = ui.register_pack(PACK_NAME, PACK_MANIFEST)
            if not ok then
                log_warn("[CrusenhoPackDemo] Failed to register pack: " .. PACK_MANIFEST)
            end
        end
    end

    cachedPack = ui.use_pack(PACK_NAME)
    if not cachedPack then
        log_warn("[CrusenhoPackDemo] Pack not available: " .. PACK_NAME)
    end
    return cachedPack
end

local function applyPackConfig(entity, src)
    if not src then return false end
    local cfg = component_cache.get(entity, UIConfig)
    if not cfg then return false end

    cfg.stylingType = src.stylingType
    cfg.nPatchInfo = src.nPatchInfo
    cfg.nPatchSourceTexture = src.nPatchSourceTexture
    cfg.spriteSourceTexture = src.spriteSourceTexture
    cfg.spriteSourceRect = src.spriteSourceRect
    cfg.spriteScaleMode = src.spriteScaleMode

    -- Preserve source texture colors exactly.
    cfg.color = Col(255, 255, 255, 255)
    cfg.emboss = 0
    cfg.shadow = false
    cfg.outlineThickness = nil
    cfg.outlineColor = nil

    return true
end

local function styledSwatch(opts)
    local id = opts.id
    local w = opts.w or 52
    local h = opts.h or 38
    local label = opts.label or id
    local fetch = opts.fetch

    local swatch = ui.definitions.def({
        type = "VERTICAL_CONTAINER",
        config = {
            id = id,
            minWidth = w,
            maxWidth = w,
            minHeight = h,
            maxHeight = h,
            color = util.getColor("blank"),
            padding = 0,
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
            canCollide = false,
            initFunc = function(_, entity)
                local pack = ensurePack()
                if not pack then return end
                local ok, src = pcall(fetch, pack)
                if ok and src then
                    applyPackConfig(entity, src)
                end
            end,
        },
        children = {},
    })

    return dsl.vbox({
        config = {
            padding = 2,
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
        },
        children = {
            swatch,
            dsl.text(label, {
                fontSize = 9,
                color = "gray_light",
                shadow = false,
            }),
        },
    })
end

local function section(title, children)
    return dsl.vbox({
        config = {
            padding = 4,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },
        children = {
            dsl.text(title, { fontSize = 13, color = "gold", shadow = true }),
            dsl.spacer(2, 2),
            dsl.hbox({
                config = { padding = 2, align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP) },
                children = children,
            }),
        },
    })
end

local function iconRows(iconNames)
    local rows = {}
    local row = {}
    local rowIndex = 1

    for i, iconName in ipairs(iconNames) do
        table.insert(row, styledSwatch({
            id = "crusenho_icon_" .. iconName,
            w = 28,
            h = 24,
            label = iconName,
            fetch = function(pack) return pack:icon(iconName) end,
        }))
        table.insert(row, dsl.spacer(4, 2))

        if i % 6 == 0 then
            table.insert(rows, dsl.hbox({
                config = { align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP) },
                children = row,
            }))
            row = {}
            rowIndex = rowIndex + 1
            if rowIndex <= 2 then
                table.insert(rows, dsl.spacer(2, 6))
            end
        end
    end

    if #row > 0 then
        table.insert(rows, dsl.hbox({
            config = { align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP) },
            children = row,
        }))
    end

    return rows
end

function Demo.createShowcase()
    local pack = ensurePack()
    local statusText = pack and "Pack loaded: crusenho_flat" or "Pack failed to load"
    local statusColor = pack and "lime" or "red"

    local rootChildren = {
        dsl.text("Crusenho UI Pack Demo", { fontSize = 18, color = "white", shadow = true }),
        dsl.text(statusText, { fontSize = 11, color = statusColor, shadow = false }),
        dsl.spacer(2, 6),

        section("Panels", {
            styledSwatch({
                id = "crusenho_panel_frame_01",
                w = 112, h = 74, label = "frame_01",
                fetch = function(p) return p:panel("frame01") end,
            }),
            dsl.spacer(4, 2),
            styledSwatch({
                id = "crusenho_panel_frame_02",
                w = 112, h = 74, label = "frame_02",
                fetch = function(p) return p:panel("frame02") end,
            }),
            dsl.spacer(4, 2),
            styledSwatch({
                id = "crusenho_panel_banner_01",
                w = 76, h = 30, label = "banner_01",
                fetch = function(p) return p:panel("banner01") end,
            }),
            dsl.spacer(4, 2),
            styledSwatch({
                id = "crusenho_panel_slot_01",
                w = 44, h = 44, label = "slot_01",
                fetch = function(p) return p:panel("frameslot01") end,
            }),
        }),
        dsl.spacer(2, 6),

        section("Buttons (primary states)", {
            styledSwatch({
                id = "crusenho_btn_primary_normal", w = 48, h = 40, label = "normal",
                fetch = function(p) return p:button("primary", "normal") end,
            }),
            dsl.spacer(4, 2),
            styledSwatch({
                id = "crusenho_btn_primary_hover", w = 48, h = 40, label = "hover",
                fetch = function(p) return p:button("primary", "hover") end,
            }),
            dsl.spacer(4, 2),
            styledSwatch({
                id = "crusenho_btn_primary_pressed", w = 48, h = 40, label = "pressed",
                fetch = function(p) return p:button("primary", "pressed") end,
            }),
            dsl.spacer(4, 2),
            styledSwatch({
                id = "crusenho_btn_primary_disabled", w = 48, h = 40, label = "disabled",
                fetch = function(p) return p:button("primary", "disabled") end,
            }),
        }),
        dsl.spacer(2, 6),

        section("Select + Toggles", {
            styledSwatch({
                id = "crusenho_select_normal", w = 42, h = 42, label = "select_n",
                fetch = function(p) return p:button("select_primary", "normal") end,
            }),
            dsl.spacer(4, 2),
            styledSwatch({
                id = "crusenho_select_pressed", w = 42, h = 42, label = "select_p",
                fetch = function(p) return p:button("select_primary", "pressed") end,
            }),
            dsl.spacer(10, 2),
            styledSwatch({
                id = "crusenho_toggle_round_off", w = 24, h = 24, label = "toggle_off",
                fetch = function(p) return p:button("toggle_round", "normal") end,
            }),
            dsl.spacer(4, 2),
            styledSwatch({
                id = "crusenho_toggle_round_on", w = 24, h = 24, label = "toggle_on",
                fetch = function(p) return p:button("toggle_round", "pressed") end,
            }),
            dsl.spacer(10, 2),
            styledSwatch({
                id = "crusenho_toggle_lr_off", w = 24, h = 24, label = "left_off",
                fetch = function(p) return p:button("toggle_lr", "normal") end,
            }),
            dsl.spacer(4, 2),
            styledSwatch({
                id = "crusenho_toggle_lr_on", w = 24, h = 24, label = "right_on",
                fetch = function(p) return p:button("toggle_lr", "pressed") end,
            }),
        }),
        dsl.spacer(2, 6),

        section("Inputs + Bars + Slider/Scrollbar Parts", {
            styledSwatch({
                id = "crusenho_input_normal", w = 76, h = 40, label = "input_n",
                fetch = function(p) return p:input("default", "normal") end,
            }),
            dsl.spacer(4, 2),
            styledSwatch({
                id = "crusenho_input_focus", w = 76, h = 40, label = "input_f",
                fetch = function(p) return p:input("default", "focus") end,
            }),
            dsl.spacer(10, 2),
            styledSwatch({
                id = "crusenho_progress_bg", w = 52, h = 20, label = "bar_bg",
                fetch = function(p) return p:progress_bar("style_01", "background") end,
            }),
            dsl.spacer(4, 2),
            styledSwatch({
                id = "crusenho_progress_fill", w = 52, h = 20, label = "bar_fill",
                fetch = function(p) return p:progress_bar("style_01", "fill") end,
            }),
            dsl.spacer(10, 2),
            styledSwatch({
                id = "crusenho_slider_track", w = 52, h = 20, label = "slider_t",
                fetch = function(p) return p:slider("default", "track") end,
            }),
            dsl.spacer(4, 2),
            styledSwatch({
                id = "crusenho_slider_thumb", w = 24, h = 24, label = "slider_h",
                fetch = function(p) return p:slider("default", "thumb") end,
            }),
            dsl.spacer(10, 2),
            styledSwatch({
                id = "crusenho_scroll_track", w = 52, h = 20, label = "scroll_t",
                fetch = function(p) return p:scrollbar("default", "track") end,
            }),
            dsl.spacer(4, 2),
            styledSwatch({
                id = "crusenho_scroll_thumb", w = 24, h = 24, label = "scroll_h",
                fetch = function(p) return p:scrollbar("default", "thumb") end,
            }),
        }),
        dsl.spacer(2, 6),

        dsl.text("Icons", { fontSize = 13, color = "gold", shadow = true }),
    }

    local icons = {
        "arrow_lg", "arrow_md", "arrow_sm", "check_lg", "check_md", "check_sm",
        "cross_lg", "cross_md", "cross_sm", "play_lg", "play_md", "play_sm",
    }
    local iconNodes = iconRows(icons)
    for _, node in ipairs(iconNodes) do
        table.insert(rootChildren, node)
    end

    return dsl.vbox({
        config = {
            padding = 8,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },
        children = rootChildren,
    })
end

return Demo
