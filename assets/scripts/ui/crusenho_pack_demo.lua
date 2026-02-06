--[[
Crusenho UI Pack Demo

Additive demo module that reuses the existing UI system:
- ui.register_pack/ui.use_pack
- regular DSL containers/text/layout
- per-entity initFunc to apply pack-provided UIConfig
]]

local dsl = require("ui.ui_syntax_sugar")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local json = require("external.json")
local timer = require("core.timer")

local Demo = {}

local PACK_NAME = "crusenho_flat"
local PACK_MANIFEST = "assets/ui_packs/crusenho_flat/pack.json"
local ANIM_TAG = "crusenho_pack_demo_anim"
local ANIM_GROUP = "crusenho_pack_demo"
local ANIM_TICK_STEP = 0.1

local cachedPack = nil
local attemptedRegistration = false
local cachedManifest = nil
local attemptedManifestLoad = false
local cachedAnimationSpecs = nil
local animationState = {
    running = false,
    entries = {},
}

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

local function readJsonFile(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end

    local content = file:read("*a")
    file:close()
    if not content or content == "" then
        return nil
    end

    local ok, decoded = pcall(json.decode, content)
    if not ok then
        log_warn("[CrusenhoPackDemo] Failed to parse JSON: " .. path)
        return nil
    end
    return decoded
end

local function ensureManifest()
    if attemptedManifestLoad then
        return cachedManifest
    end
    attemptedManifestLoad = true
    cachedManifest = readJsonFile(PACK_MANIFEST)
    if not cachedManifest then
        log_warn("[CrusenhoPackDemo] Could not load manifest JSON: " .. PACK_MANIFEST)
    end
    return cachedManifest
end

local function sortedKeys(tbl)
    local keys = {}
    if type(tbl) ~= "table" then
        return keys
    end
    for k, _ in pairs(tbl) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    return keys
end

local function regionToSwatchSize(region, defaultW, defaultH)
    local w = defaultW or 52
    local h = defaultH or 38
    if type(region) == "table" then
        local rw = tonumber(region[3])
        local rh = tonumber(region[4])
        if rw and rw > 0 then
            w = rw + 12
        end
        if rh and rh > 0 then
            h = rh + 12
        end
    end
    w = math.max(24, math.min(112, w))
    h = math.max(20, math.min(84, h))
    return w, h
end

local function buildLegacyAnimationSpecs()
    return {
        {
            id = "crusenho_anim_primary_cycle",
            w = 72,
            h = 42,
            label = "primary",
            interval = 0.45,
            fetches = {
                function(p) return p:button("primary", "normal") end,
                function(p) return p:button("primary", "hover") end,
                function(p) return p:button("primary", "pressed") end,
                function(p) return p:button("primary", "hover") end,
            },
        },
        {
            id = "crusenho_anim_select_cycle",
            w = 42,
            h = 42,
            label = "select",
            interval = 0.50,
            fetches = {
                function(p) return p:button("select_primary", "normal") end,
                function(p) return p:button("select_primary", "hover") end,
                function(p) return p:button("select_primary", "pressed") end,
                function(p) return p:button("select_primary", "hover") end,
            },
        },
        {
            id = "crusenho_anim_toggle_round_cycle",
            w = 24,
            h = 24,
            label = "toggle_r",
            interval = 0.55,
            fetches = {
                function(p) return p:button("toggle_round", "normal") end,
                function(p) return p:button("toggle_round", "pressed") end,
            },
        },
        {
            id = "crusenho_anim_toggle_lr_cycle",
            w = 24,
            h = 24,
            label = "toggle_lr",
            interval = 0.55,
            fetches = {
                function(p) return p:button("toggle_lr", "normal") end,
                function(p) return p:button("toggle_lr", "pressed") end,
            },
        },
        {
            id = "crusenho_anim_input_cycle",
            w = 76,
            h = 40,
            label = "input",
            interval = 0.65,
            fetches = {
                function(p) return p:input("default", "normal") end,
                function(p) return p:input("default", "focus") end,
            },
        },
    }
end

local function buildAnimationSpecFromManifest(animKey, spec, manifest)
    if type(spec) ~= "table" or type(manifest) ~= "table" then
        return nil
    end

    local kind = spec.kind
    local interval = tonumber(spec.interval) or 0.45
    local label = spec.label or animKey
    local fetches = {}
    local firstRegion = nil
    local progressStyles = nil
    local progressPart = nil

    if kind == "button" then
        local name = spec.name
        local states = spec.states
        local buttons = manifest.buttons
        if type(name) ~= "string" or type(states) ~= "table" or type(buttons) ~= "table" then
            return nil
        end
        local buttonDef = buttons[name]
        if type(buttonDef) ~= "table" then
            return nil
        end
        for _, state in ipairs(states) do
            if type(state) == "string" and type(buttonDef[state]) == "table" then
                if not firstRegion then
                    firstRegion = buttonDef[state].region
                end
                local localName = name
                local localState = state
                table.insert(fetches, function(pack)
                    return pack:button(localName, localState)
                end)
            end
        end
    elseif kind == "panel" then
        local frames = spec.frames
        local panels = manifest.panels
        if type(frames) ~= "table" or type(panels) ~= "table" then
            return nil
        end
        for _, frameKey in ipairs(frames) do
            if type(frameKey) == "string" and type(panels[frameKey]) == "table" then
                if not firstRegion then
                    firstRegion = panels[frameKey].region
                end
                local localFrameKey = frameKey
                table.insert(fetches, function(pack)
                    return pack:panel(localFrameKey)
                end)
            end
        end
    elseif kind == "input" then
        local name = spec.name
        local states = spec.states
        local inputs = manifest.inputs
        if type(name) ~= "string" or type(states) ~= "table" or type(inputs) ~= "table" then
            return nil
        end
        local inputDef = inputs[name]
        if type(inputDef) ~= "table" then
            return nil
        end
        for _, state in ipairs(states) do
            if type(state) == "string" and type(inputDef[state]) == "table" then
                if not firstRegion then
                    firstRegion = inputDef[state].region
                end
                local localName = name
                local localState = state
                table.insert(fetches, function(pack)
                    return pack:input(localName, localState)
                end)
            end
        end
    elseif kind == "icon" then
        local frames = spec.frames
        local icons = manifest.icons
        if type(frames) ~= "table" or type(icons) ~= "table" then
            return nil
        end
        for _, iconKey in ipairs(frames) do
            if type(iconKey) == "string" and type(icons[iconKey]) == "table" then
                if not firstRegion then
                    firstRegion = icons[iconKey].region
                end
                local localIconKey = iconKey
                table.insert(fetches, function(pack)
                    return pack:icon(localIconKey)
                end)
            end
        end
    elseif kind == "progress_bar" then
        local styles = spec.styles
        local part = spec.part
        local progressBars = manifest.progress_bars
        if type(styles) ~= "table" or type(part) ~= "string" or type(progressBars) ~= "table" then
            return nil
        end
        progressStyles = {}
        progressPart = part
        for _, styleKey in ipairs(styles) do
            if type(styleKey) == "string" and type(progressBars[styleKey]) == "table" and type(progressBars[styleKey][part]) == "table" then
                if not firstRegion then
                    firstRegion = progressBars[styleKey][part].region
                end
                table.insert(progressStyles, styleKey)
                local localStyleKey = styleKey
                local localPart = part
                table.insert(fetches, function(pack)
                    return pack:progress_bar(localStyleKey, localPart)
                end)
            end
        end
    end

    if #fetches < 2 then
        return nil
    end

    local swatchW, swatchH = regionToSwatchSize(firstRegion, 52, 38)
    return {
        id = "crusenho_anim_" .. tostring(animKey):gsub("[^%w_]+", "_"),
        kind = kind,
        w = swatchW,
        h = swatchH,
        label = label,
        interval = interval,
        fetches = fetches,
        progressStyles = progressStyles,
        progressPart = progressPart,
    }
end

local function ensureAnimationSpecs()
    if cachedAnimationSpecs then
        return cachedAnimationSpecs
    end

    local manifest = ensureManifest()
    local specs = {}
    if type(manifest) == "table" and type(manifest.animations) == "table" then
        local animKeys = sortedKeys(manifest.animations)
        for _, animKey in ipairs(animKeys) do
            local built = buildAnimationSpecFromManifest(animKey, manifest.animations[animKey], manifest)
            if built then
                specs[#specs + 1] = built
            end
        end
    end

    if #specs == 0 then
        specs = buildLegacyAnimationSpecs()
    end

    cachedAnimationSpecs = specs
    return cachedAnimationSpecs
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

local function setEntityWidth(entity, width)
    local clampedWidth = math.max(1, math.floor(width))
    local cfg = component_cache.get(entity, UIConfig)
    if cfg then
        cfg.minWidth = clampedWidth
        cfg.maxWidth = clampedWidth
    end
    local transform = component_cache.get(entity, Transform)
    if transform then
        transform.actualW = clampedWidth
    end
end

local function applyProgressStyle(pack, bgEntity, fillEntity, styleName)
    if not pack or type(styleName) ~= "string" then
        return
    end
    if bgEntity then
        local okBg, bgSrc = pcall(function()
            return pack:progress_bar(styleName, "background")
        end)
        if okBg and bgSrc then
            applyPackConfig(bgEntity, bgSrc)
        end
    end
    if fillEntity then
        local okFill, fillSrc = pcall(function()
            return pack:progress_bar(styleName, "fill")
        end)
        if okFill and fillSrc then
            applyPackConfig(fillEntity, fillSrc)
        end
    end
end

local function stopAnimationTicker()
    if animationState.running then
        if timer.kill_group then
            timer.kill_group(ANIM_GROUP)
        elseif timer.cancel then
            timer.cancel(ANIM_TAG)
        end
        animationState.running = false
    end
end

local function resetAnimationState()
    stopAnimationTicker()
    animationState.entries = {}
end

local function tickAnimations()
    local pack = ensurePack()
    if not pack then return end
    if #animationState.entries == 0 then
        stopAnimationTicker()
        return
    end

    local alive = 0
    for i = #animationState.entries, 1, -1 do
        local entry = animationState.entries[i]
        if not entry.entity or not entity_cache.valid(entry.entity) then
            table.remove(animationState.entries, i)
        else
            alive = alive + 1
            entry.elapsed = entry.elapsed + ANIM_TICK_STEP
            if entry.elapsed >= entry.interval then
                entry.elapsed = 0
                if entry.mode == "progress_fill" then
                    entry.progress = entry.progress + (entry.step * entry.direction)
                    if entry.progress >= 1.0 then
                        entry.progress = 1.0
                        entry.direction = -1
                    elseif entry.progress <= 0.0 then
                        entry.progress = 0.0
                        entry.direction = 1
                        entry.styleIndex = (entry.styleIndex % #entry.styles) + 1
                        applyProgressStyle(pack, entry.bgEntity, entry.entity, entry.styles[entry.styleIndex])
                    end
                    local targetWidth = entry.minWidth + ((entry.fullWidth - entry.minWidth) * entry.progress)
                    setEntityWidth(entry.entity, targetWidth)
                else
                    entry.index = (entry.index % #entry.fetches) + 1
                    local ok, src = pcall(entry.fetches[entry.index], pack)
                    if ok and src then
                        applyPackConfig(entry.entity, src)
                    end
                end
            end
        end
    end

    if alive == 0 then
        stopAnimationTicker()
    end
end

local function ensureAnimationTicker()
    if animationState.running then
        return
    end

    animationState.running = true
    timer.every_opts({
        delay = ANIM_TICK_STEP,
        tag = ANIM_TAG,
        group = ANIM_GROUP,
        action = tickAnimations,
    })
end

local function registerAnimatedSwatch(entity, fetches, interval)
    if not entity or not fetches or #fetches == 0 then
        return
    end
    table.insert(animationState.entries, {
        entity = entity,
        fetches = fetches,
        index = 1,
        interval = interval or 0.45,
        elapsed = 0,
    })
    ensureAnimationTicker()
end

local function registerProgressFillSwatch(fillEntity, bgEntity, styles, fullWidth, interval)
    if not fillEntity or type(styles) ~= "table" or #styles == 0 then
        return
    end

    local pack = ensurePack()
    if not pack then
        return
    end

    local minWidth = math.max(2, math.floor((fullWidth or 64) * 0.15))
    local initialWidth = math.max(minWidth, math.floor((fullWidth or 64) * 0.25))
    applyProgressStyle(pack, bgEntity, fillEntity, styles[1])
    setEntityWidth(fillEntity, initialWidth)

    table.insert(animationState.entries, {
        entity = fillEntity,
        bgEntity = bgEntity,
        mode = "progress_fill",
        styles = styles,
        styleIndex = 1,
        interval = interval or 0.08,
        elapsed = 0,
        progress = 0.25,
        direction = 1,
        step = 0.10,
        fullWidth = fullWidth or 64,
        minWidth = minWidth,
    })
    ensureAnimationTicker()
end

local function styledSwatch(opts)
    local id = opts.id
    local w = opts.w or 52
    local h = opts.h or 38
    local label = opts.label or id
    local fetch = opts.fetch
    local bgColor = opts.bgColor or util.getColor("blank")

    local swatch = ui.definitions.def({
        type = "VERTICAL_CONTAINER",
        config = {
            id = id,
            minWidth = w,
            maxWidth = w,
            minHeight = h,
            maxHeight = h,
            color = bgColor,
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

local function animatedSwatch(opts)
    local id = opts.id
    local w = opts.w or 52
    local h = opts.h or 38
    local label = opts.label or id
    local fetches = opts.fetches or {}
    local interval = opts.interval or 0.45

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

                local first = fetches[1]
                if first then
                    local ok, src = pcall(first, pack)
                    if ok and src then
                        applyPackConfig(entity, src)
                    end
                end

                registerAnimatedSwatch(entity, fetches, interval)
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

local function progressFillAnimatedSwatch(opts)
    local id = opts.id
    local label = opts.label or id
    local styles = opts.styles or {}
    local interval = opts.interval or 0.08
    local w = math.max(64, opts.w or 64)
    local h = math.max(18, opts.h or 20)
    local bgId = id .. "_bg"
    local fillId = id .. "_fill"

    local bar = ui.definitions.def({
        type = "HORIZONTAL_CONTAINER",
        config = {
            id = bgId,
            minWidth = w,
            maxWidth = w,
            minHeight = h,
            maxHeight = h,
            color = util.getColor("blank"),
            padding = 0,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
            canCollide = false,
        },
        children = {
            ui.definitions.def({
                type = "HORIZONTAL_CONTAINER",
                config = {
                    id = fillId,
                    minWidth = math.max(2, math.floor(w * 0.15)),
                    maxWidth = math.max(2, math.floor(w * 0.15)),
                    minHeight = h,
                    maxHeight = h,
                    color = util.getColor("blank"),
                    padding = 0,
                    align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
                    canCollide = false,
                    initFunc = function(_, entity)
                        local bgEntity = nil
                        if ui and ui.box and ui.box.GetUIEByID then
                            bgEntity = ui.box.GetUIEByID(registry, bgId)
                        end
                        registerProgressFillSwatch(entity, bgEntity, styles, w, interval)
                    end,
                },
                children = {},
            }),
        },
    })

    return dsl.vbox({
        config = {
            padding = 2,
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
        },
        children = {
            bar,
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

local function createScrollPane(contentNode)
    local screenW = (globals and globals.screenWidth and globals.screenWidth()) or 1280
    local screenH = (globals and globals.screenHeight and globals.screenHeight()) or 720
    local width = math.max(460, math.min(680, math.floor(screenW * 0.50)))
    local height = math.max(360, math.min(680, screenH - 240))

    return ui.definitions.def({
        type = "SCROLL_PANE",
        config = {
            id = "crusenho_pack_demo_scroll",
            maxWidth = width,
            width = width,
            maxHeight = height,
            height = height,
            padding = 4,
            color = util.getColor("blank"),
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },
        children = { contentNode },
    })
end

local function iconRows(iconSpecs, perRow)
    local rows = {}
    local row = {}
    local maxPerRow = perRow or 4

    for i, spec in ipairs(iconSpecs) do
        local iconName = spec.name
        table.insert(row, styledSwatch({
            id = "crusenho_icon_" .. iconName,
            w = spec.w or 28,
            h = spec.h or 24,
            label = spec.label or iconName,
            bgColor = spec.bgColor,
            fetch = function(pack) return pack:icon(iconName) end,
        }))
        table.insert(row, dsl.spacer(4, 2))

        if i % maxPerRow == 0 then
            table.insert(rows, dsl.hbox({
                config = { align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP) },
                children = row,
            }))
            row = {}
            if i < #iconSpecs then
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

local function animationRows(animationSpecs)
    local rows = {}
    local row = {}
    local perRow = 4

    for i, spec in ipairs(animationSpecs) do
        local node = nil
        if spec.kind == "progress_bar" and spec.progressPart == "fill" and type(spec.progressStyles) == "table" and #spec.progressStyles >= 1 then
            node = progressFillAnimatedSwatch({
                id = spec.id .. "_meter",
                label = spec.label,
                styles = spec.progressStyles,
                interval = math.min(spec.interval or 0.22, 0.08),
                w = math.max(72, spec.w or 52),
                h = math.max(20, spec.h or 20),
            })
        else
            node = animatedSwatch(spec)
        end
        row[#row + 1] = node
        if (i % perRow) ~= 0 and i < #animationSpecs then
            row[#row + 1] = dsl.spacer(6, 2)
        end

        if i % perRow == 0 then
            rows[#rows + 1] = dsl.hbox({
                config = { align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP) },
                children = row,
            })
            row = {}
            if i < #animationSpecs then
                rows[#rows + 1] = dsl.spacer(2, 6)
            end
        end
    end

    if #row > 0 then
        rows[#rows + 1] = dsl.hbox({
            config = { align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP) },
            children = row,
        })
    end

    return rows
end

function Demo.createShowcase()
    resetAnimationState()

    local pack = ensurePack()
    local manifest = ensureManifest()
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

        section("Inputs + Bars", {
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
        }),
        dsl.spacer(2, 6),

        section("Slider/Scrollbar Parts", {
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
    }

    local animationSpecs = ensureAnimationSpecs()
    table.insert(rootChildren, dsl.text("Animated Assets", { fontSize = 13, color = "gold", shadow = true }))
    table.insert(rootChildren, dsl.text("auto from pack metadata (fallback cycles)", { fontSize = 9, color = "gray_light", shadow = false }))
    table.insert(rootChildren, dsl.spacer(2, 2))
    local animNodes = animationRows(animationSpecs)
    for _, node in ipairs(animNodes) do
        table.insert(rootChildren, node)
    end
    table.insert(rootChildren, dsl.spacer(2, 6))

    table.insert(rootChildren, dsl.text("Icons", { fontSize = 13, color = "gold", shadow = true }))

    local iconSpecs = {}
    local iconBackdrop = Col(255, 255, 255, 28)
    if type(manifest) == "table" and type(manifest.icons) == "table" then
        for _, iconName in ipairs(sortedKeys(manifest.icons)) do
            local iconDef = manifest.icons[iconName]
            local w, h = regionToSwatchSize(iconDef and iconDef.region, 28, 24)
            local displayLabel = iconName
            local row, col = iconName:match("^anim_sheet_r(%d+)_c(%d+)$")
            if row and col then
                displayLabel = "sheet_" .. row .. "_" .. col
            end
            table.insert(iconSpecs, {
                name = iconName,
                label = displayLabel,
                w = math.max(24, math.min(52, w)),
                h = math.max(20, math.min(48, h)),
                bgColor = iconBackdrop,
            })
        end
    end

    if #iconSpecs == 0 then
        local fallback = {
            "arrow_lg", "arrow_md", "arrow_sm", "check_lg", "check_md", "check_sm",
            "cross_lg", "cross_md", "cross_sm", "play_lg", "play_md", "play_sm",
        }
        for _, iconName in ipairs(fallback) do
            table.insert(iconSpecs, {
                name = iconName,
                label = iconName,
                w = 32,
                h = 24,
                bgColor = iconBackdrop,
            })
        end
    end

    table.insert(rootChildren, dsl.text(string.format("showing %d icons from manifest", #iconSpecs), {
        fontSize = 9,
        color = "gray_light",
        shadow = false,
    }))
    table.insert(rootChildren, dsl.spacer(2, 2))
    local iconNodes = iconRows(iconSpecs, 4)
    for _, node in ipairs(iconNodes) do
        table.insert(rootChildren, node)
    end

    local content = dsl.vbox({
        config = {
            padding = 8,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },
        children = rootChildren,
    })
    return createScrollPane(content)
end

return Demo
