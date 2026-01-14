--[[
================================================================================
CONTENT DEBUG PANEL
================================================================================
Unified ImGui debug interface for testing content systems.

Tabs:
  1. Joker Tester - Add/remove jokers, trigger test events
  2. Projectile Spawner - Spawn projectiles with live tweaking
  3. Tag Inspector - View tag counts and active bonuses
]]

local ContentDebugPanel = {}

-- Dependencies (loaded lazily)
local JokerSystem = nil
local Projectiles = nil
local ProjectileSystem = nil
local component_cache = nil

local state = {
    initialized = false,
    current_tab = 1,

    joker_list = {},
    joker_test_result = nil,

    projectile_presets = {},
    selected_preset = 1,
    spawn_params = {
        speed = 500,
        homing_strength = 8,
        bounce_count = 3,
        explosion_radius = 60,
    },
    last_spawned = nil,

    tag_counts = {},
    spell_type_info = nil,

    card_list = {},
    card_filter_text = "",
    card_filter_tag = nil,
    card_sort_by = "name",
    card_sort_asc = true,
    selected_card = nil,
    available_tags = {},
    test_cast_result = nil,
}

--===========================================================================
-- INITIALIZATION
--===========================================================================
function ContentDebugPanel.init()
    if state.initialized then return end

    -- Load jokers
    local ok, jokers = pcall(require, "data.jokers")
    if ok then
        state.joker_list = {}
        for key, joker in pairs(jokers) do
            if type(joker) == "table" and joker.id then
                table.insert(state.joker_list, {
                    id = joker.id,
                    name = joker.name or joker.id,
                    rarity = joker.rarity or "Unknown",
                    description = joker.description or "",
                    active = false,
                })
            end
        end
        table.sort(state.joker_list, function(a, b) return a.name < b.name end)
    end

    -- Load projectile presets
    local ok2, projectiles = pcall(require, "data.projectiles")
    if ok2 then
        Projectiles = projectiles
        state.projectile_presets = {}
        for key, proj in pairs(projectiles) do
            if type(proj) == "table" and proj.id then
                table.insert(state.projectile_presets, {
                    id = proj.id,
                    name = proj.id,
                    data = proj,
                })
            end
        end
        table.sort(state.projectile_presets, function(a, b) return a.name < b.name end)
    end

    -- Try to load JokerSystem
    local ok3, js = pcall(require, "wand.joker_system")
    if ok3 then JokerSystem = js end

    -- Try to load ProjectileSystem
    local ok4, ps = pcall(require, "combat.projectile_system")
    if ok4 then ProjectileSystem = ps end

    -- Try to load component_cache
    local ok5, cc = pcall(require, "core.component_cache")
    if ok5 then component_cache = cc end

    -- Load cards
    local ok_cards, cards_data = pcall(require, "data.cards")
    if ok_cards then
        state.card_list = {}
        local tag_set = {}

        for key, card in pairs(cards_data) do
            if type(card) == "table" and card.id then
                local entry = {
                    id = card.id,
                    type = card.type or "action",
                    mana_cost = card.mana_cost or 0,
                    damage = card.damage or 0,
                    damage_type = card.damage_type or "physical",
                    tags = card.tags or {},
                    sprite = card.sprite or card.test_label or "card_back",
                    data = card,
                }
                table.insert(state.card_list, entry)

                -- Collect unique tags
                for _, tag in ipairs(entry.tags) do
                    tag_set[tag] = true
                end
            end
        end

        -- Build sorted tag list
        state.available_tags = {}
        for tag, _ in pairs(tag_set) do
            table.insert(state.available_tags, tag)
        end
        table.sort(state.available_tags)
    end

    state.initialized = true
end

--===========================================================================
-- CARDS TAB HELPERS
--===========================================================================
local function sort_cards()
    local sort_key = state.card_sort_by
    local asc = state.card_sort_asc

    table.sort(state.card_list, function(a, b)
        local va, vb
        if sort_key == "name" then
            va, vb = a.id:lower(), b.id:lower()
        elseif sort_key == "mana" then
            va, vb = a.mana_cost, b.mana_cost
        elseif sort_key == "damage" then
            va, vb = a.damage, b.damage
        elseif sort_key == "type" then
            va, vb = a.type, b.type
        else
            va, vb = a.id:lower(), b.id:lower()
        end

        if asc then
            return va < vb
        else
            return va > vb
        end
    end)
end

local function card_matches_filter(card)
    -- Text filter
    if state.card_filter_text ~= "" then
        local filter_lower = state.card_filter_text:lower()
        if not card.id:lower():find(filter_lower, 1, true) then
            return false
        end
    end

    -- Tag filter
    if state.card_filter_tag then
        local has_tag = false
        for _, tag in ipairs(card.tags) do
            if tag == state.card_filter_tag then
                has_tag = true
                break
            end
        end
        if not has_tag then
            return false
        end
    end

    return true
end

local function test_cast_card(card)
    -- Simulate casting this card with current jokers/tags
    local result = { messages = {}, damage_mod = 0, damage_mult = 1.0 }

    if JokerSystem and JokerSystem.trigger_event then
        -- Build context
        local tag_table = {}
        for _, tag in ipairs(card.tags) do
            tag_table[tag] = true
        end

        local effects = JokerSystem.trigger_event("on_spell_cast", {
            spell_type = #card.tags == 1 and "Mono-Element" or "Multi-Tag",
            tags = tag_table,
            card = card.data,
        })

        if effects then
            result.damage_mod = effects.damage_mod or 0
            result.damage_mult = effects.damage_mult or 1.0
            if effects.message then
                table.insert(result.messages, effects.message)
            end
        end
    end

    -- Calculate final damage
    local base_damage = card.damage or 0
    result.final_damage = math.floor(base_damage * result.damage_mult + result.damage_mod)
    result.base_damage = base_damage

    return result
end

--===========================================================================
-- JOKER TAB
--===========================================================================
local function render_joker_tab()
    if not ImGui then return end

    ImGui.Text("Active Jokers:")
    ImGui.Separator()

    local active_count = 0
    for _, joker in ipairs(state.joker_list) do
        if joker.active then
            active_count = active_count + 1
            ImGui.PushID(joker.id .. "_active")

            ImGui.Text(string.format("[+] %s (%s)", joker.name, joker.rarity))
            ImGui.SameLine()
            if ImGui.SmallButton("Remove") then
                joker.active = false
                if JokerSystem and JokerSystem.remove_joker then
                    JokerSystem.remove_joker(joker.id)
                end
            end

            if ImGui.IsItemHovered() and joker.description ~= "" then
                ImGui.SetTooltip(joker.description)
            end

            ImGui.PopID()
        end
    end

    if active_count == 0 then
        ImGui.TextDisabled("No active jokers")
    end

    ImGui.Separator()
    ImGui.Text("Available Jokers:")
    ImGui.Separator()

    for _, joker in ipairs(state.joker_list) do
        if not joker.active then
            ImGui.PushID(joker.id .. "_available")

            ImGui.Text(string.format("[ ] %s (%s)", joker.name, joker.rarity))
            ImGui.SameLine()
            if ImGui.SmallButton("Add") then
                joker.active = true
                if JokerSystem and JokerSystem.add_joker then
                    JokerSystem.add_joker(joker.id)
                end
            end

            if ImGui.IsItemHovered() and joker.description ~= "" then
                ImGui.SetTooltip(joker.description)
            end

            ImGui.PopID()
        end
    end

    ImGui.Separator()
    ImGui.Text("Test Event:")

    if ImGui.Button("Trigger on_spell_cast (Fire)") then
        if JokerSystem and JokerSystem.trigger_event then
            local effects = JokerSystem.trigger_event("on_spell_cast", {
                spell_type = "Mono-Element",
                tags = { Fire = true },
                tag_analysis = {
                    diversity = 1,
                    primary_tag = "Fire",
                    primary_count = 1,
                    is_tag_heavy = false,
                    is_multi_tag = false,
                },
            })
            state.joker_test_result = effects or { message = "No effects triggered" }
        else
            state.joker_test_result = { message = "JokerSystem not loaded" }
        end
    end

    ImGui.SameLine()
    if ImGui.Button("Trigger on_spell_cast (AoE)") then
        if JokerSystem and JokerSystem.trigger_event then
            local effects = JokerSystem.trigger_event("on_spell_cast", {
                spell_type = "Scatter Cast",
                tags = { AoE = true, Fire = true },
                tag_analysis = {
                    diversity = 2,
                    primary_tag = "AoE",
                    primary_count = 1,
                    is_tag_heavy = false,
                    is_multi_tag = true,
                },
            })
            state.joker_test_result = effects or { message = "No effects triggered" }
        else
            state.joker_test_result = { message = "JokerSystem not loaded" }
        end
    end

    if state.joker_test_result then
        ImGui.Separator()
        ImGui.Text("Last Result:")
        if state.joker_test_result.damage_mod then
            ImGui.Text(string.format("  damage_mod: +%d", state.joker_test_result.damage_mod))
        end
        if state.joker_test_result.damage_mult then
            ImGui.Text(string.format("  damage_mult: x%.2f", state.joker_test_result.damage_mult))
        end
        if state.joker_test_result.repeat_cast then
            ImGui.Text(string.format("  repeat_cast: %d", state.joker_test_result.repeat_cast))
        end
        if state.joker_test_result.message then
            ImGui.Text(string.format("  message: %s", state.joker_test_result.message))
        end
        if not state.joker_test_result.damage_mod and not state.joker_test_result.damage_mult
           and not state.joker_test_result.repeat_cast and not state.joker_test_result.message then
            ImGui.TextDisabled("  (no effects triggered)")
        end
    end
end

--===========================================================================
-- PROJECTILE TAB
--===========================================================================
local function render_projectile_tab()
    if not ImGui then return end

    ImGui.Text("Preset:")

    -- Preset dropdown
    local preset_names = {}
    for i, p in ipairs(state.projectile_presets) do
        preset_names[i] = p.name
    end

    if #preset_names > 0 then
        state.selected_preset, _ = ImGui.Combo("##preset", state.selected_preset, preset_names, #preset_names)

        local selected = state.projectile_presets[state.selected_preset]
        if selected then
            ImGui.TextDisabled(string.format("Movement: %s | Collision: %s",
                selected.data.movement or "?",
                selected.data.collision or "?"))
        end
    else
        ImGui.TextDisabled("No projectile presets loaded")
    end

    ImGui.Separator()
    ImGui.Text("Parameter Overrides:")

    -- Speed slider
    state.spawn_params.speed, _ = ImGui.SliderInt("Speed", state.spawn_params.speed, 100, 1500)

    -- Homing strength slider
    state.spawn_params.homing_strength, _ = ImGui.SliderInt("Homing", state.spawn_params.homing_strength, 0, 15)

    -- Bounce count slider
    state.spawn_params.bounce_count, _ = ImGui.SliderInt("Bounces", state.spawn_params.bounce_count, 0, 10)

    -- Explosion radius slider
    state.spawn_params.explosion_radius, _ = ImGui.SliderInt("Explosion", state.spawn_params.explosion_radius, 0, 200)

    ImGui.Separator()
    ImGui.Text("Spawn:")

    if ImGui.Button("Spawn at Player") then
        ContentDebugPanel.spawn_projectile("player")
    end

    ImGui.SameLine()
    if ImGui.Button("Spawn at Cursor") then
        ContentDebugPanel.spawn_projectile("cursor")
    end

    ImGui.SameLine()
    if ImGui.Button("Spawn Toward Cursor") then
        ContentDebugPanel.spawn_projectile("toward_cursor")
    end

    if state.last_spawned then
        ImGui.Separator()
        ImGui.TextDisabled(string.format("Last spawned: %s (entity #%s)",
            state.last_spawned.preset or "?",
            tostring(state.last_spawned.entity or "?")))
    end
end

function ContentDebugPanel.spawn_projectile(mode)
    if #state.projectile_presets == 0 then return end

    local preset = state.projectile_presets[state.selected_preset]
    if not preset then return end

    -- Get player position
    local px, py = 0, 0
    if globals and globals.player then
        local transform = component_cache and component_cache.get(globals.player, Transform)
        if transform then
            px = transform.actualX or 0
            py = transform.actualY or 0
        end
    end

    -- Get cursor position
    local cx, cy = px + 100, py
    if globals and globals.mouseX and globals.mouseY then
        cx = globals.mouseX
        cy = globals.mouseY
    end

    -- Determine spawn position and direction
    local spawn_x, spawn_y = px, py
    local dir_x, dir_y = 1, 0

    if mode == "cursor" then
        spawn_x, spawn_y = cx, cy
    elseif mode == "toward_cursor" then
        local dx = cx - px
        local dy = cy - py
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0 then
            dir_x = dx / len
            dir_y = dy / len
        end
    end

    -- Spawn projectile
    if ProjectileSystem and ProjectileSystem.spawn then
        local params = {
            position = { x = spawn_x, y = spawn_y },
            velocity = { x = dir_x * state.spawn_params.speed, y = dir_y * state.spawn_params.speed },
            damage = preset.data.damage or 10,
            damage_type = preset.data.damage_type or "physical",
            owner = globals and globals.player,
            movement = preset.data.movement,
            collision = preset.data.collision,
            lifetime = preset.data.lifetime or 2000,
            homing_strength = state.spawn_params.homing_strength,
            bounce_count = state.spawn_params.bounce_count,
            explosion_radius = state.spawn_params.explosion_radius,
            pierce_count = preset.data.pierce_count,
        }

        local entity = ProjectileSystem.spawn(params)
        state.last_spawned = {
            preset = preset.id,
            entity = entity,
        }
    else
        print("[ContentDebugPanel] ProjectileSystem not loaded, cannot spawn")
        state.last_spawned = {
            preset = preset.id,
            entity = "N/A (system not loaded)",
        }
    end
end

--===========================================================================
-- CARDS TAB
--===========================================================================
local function render_cards_tab()
    if not ImGui then return end

    -- Filter row
    local text_changed, new_text = ImGui.InputText("Search##cards", state.card_filter_text or "", 64)
    if text_changed then
        state.card_filter_text = new_text
    end

    ImGui.SameLine()

    -- Tag filter dropdown
    local tag_options = { "All Tags" }
    local current_tag_idx = 1
    for i, tag in ipairs(state.available_tags) do
        table.insert(tag_options, tag)
        if tag == state.card_filter_tag then
            current_tag_idx = i + 1
        end
    end

    ImGui.SetNextItemWidth(100)
    local new_tag_idx, tag_changed = ImGui.Combo("##tag_filter", current_tag_idx, tag_options, #tag_options)
    if tag_changed then
        state.card_filter_tag = new_tag_idx == 1 and nil or tag_options[new_tag_idx]
    end

    -- Sort buttons
    ImGui.SameLine()
    ImGui.Text("Sort:")
    ImGui.SameLine()

    local sort_options = { "name", "mana", "damage", "type" }
    for _, opt in ipairs(sort_options) do
        local label = opt
        if state.card_sort_by == opt then
            label = state.card_sort_asc and (opt .. " ▲") or (opt .. " ▼")
        end
        if ImGui.SmallButton(label) then
            if state.card_sort_by == opt then
                state.card_sort_asc = not state.card_sort_asc
            else
                state.card_sort_by = opt
                state.card_sort_asc = true
            end
            sort_cards()
        end
        ImGui.SameLine()
    end
    ImGui.NewLine()

    ImGui.Separator()

    -- Count matching cards
    local match_count = 0
    for _, card in ipairs(state.card_list) do
        if card_matches_filter(card) then
            match_count = match_count + 1
        end
    end
    ImGui.Text(string.format("Cards: %d / %d", match_count, #state.card_list))

    ImGui.Separator()

    -- Card list (scrollable)
    ImGui.BeginChild("CardsList", 0, 200, true)

    for _, card in ipairs(state.card_list) do
        if card_matches_filter(card) then
            ImGui.PushID(card.id)

            -- Type badge color
            local badge = "[" .. card.type:sub(1,3):upper() .. "]"

            -- Selectable row
            local is_selected = state.selected_card and state.selected_card.id == card.id
            local label = string.format("%s %s  (%d mana)", badge, card.id, card.mana_cost)

            if ImGui.Selectable(label, is_selected) then
                state.selected_card = card
                state.test_cast_result = nil
            end

            -- Quick tooltip
            if ImGui.IsItemHovered() then
                ImGui.BeginTooltip()
                ImGui.Text(card.id)
                if card.damage > 0 then
                    ImGui.Text(string.format("Damage: %d %s", card.damage, card.damage_type))
                end
                if #card.tags > 0 then
                    ImGui.Text("Tags: " .. table.concat(card.tags, ", "))
                end
                ImGui.EndTooltip()
            end

            ImGui.PopID()
        end
    end

    ImGui.EndChild()

    -- Selected card details
    if state.selected_card then
        ImGui.Separator()

        local card = state.selected_card

        -- Sprite preview (placeholder - would need actual sprite rendering)
        ImGui.BeginChild("CardPreview", 100, 140, true)
        ImGui.TextDisabled("[Sprite]")
        ImGui.TextDisabled(card.sprite or "?")
        ImGui.EndChild()

        ImGui.SameLine()

        -- Stats
        ImGui.BeginChild("CardStats", 0, 140, false)
        ImGui.Text(card.id)
        ImGui.TextDisabled(string.format("Type: %s | Mana: %d", card.type, card.mana_cost))

        if card.damage > 0 then
            ImGui.Text(string.format("Damage: %d (%s)", card.damage, card.damage_type))
        end

        if card.data.projectile_speed then
            ImGui.Text(string.format("Speed: %d | Lifetime: %dms",
                card.data.projectile_speed, card.data.lifetime or 0))
        end

        if card.data.radius_of_effect and card.data.radius_of_effect > 0 then
            ImGui.Text(string.format("AoE Radius: %d", card.data.radius_of_effect))
        end

        if #card.tags > 0 then
            ImGui.Text("Tags: " .. table.concat(card.tags, ", "))
        end
        ImGui.EndChild()

        ImGui.Separator()

        -- Action buttons
        if ImGui.Button("Add to Inventory") then
            if addCardToInventory then
                addCardToInventory(card.id)
                print("[Cards] Added to inventory: " .. card.id)
            else
                print("[Cards] addCardToInventory not available")
            end
        end

        ImGui.SameLine()

        if ImGui.Button("Spawn at Cursor") then
            if globals and globals.mouseX then
                local ok, EntityBuilder = pcall(require, "core.entity_builder")
                if ok then
                    EntityBuilder.create({
                        sprite = card.sprite or "card_back",
                        position = { x = globals.mouseX, y = globals.mouseY },
                        size = { 64, 96 },
                        data = { card_id = card.id },
                    })
                    print("[Cards] Spawned card entity")
                end
            end
        end

        ImGui.SameLine()

        if ImGui.Button("Test Cast") then
            state.test_cast_result = test_cast_card(card)
        end

        -- Test cast results
        if state.test_cast_result then
            ImGui.Separator()
            ImGui.Text("Test Cast Result:")

            local r = state.test_cast_result
            ImGui.Text(string.format("  Base: %d → Final: %d", r.base_damage, r.final_damage))

            if r.damage_mod ~= 0 then
                ImGui.Text(string.format("  + damage_mod: %+d", r.damage_mod))
            end
            if r.damage_mult ~= 1.0 then
                ImGui.Text(string.format("  × damage_mult: %.2f", r.damage_mult))
            end

            for _, msg in ipairs(r.messages) do
                ImGui.TextDisabled("  → " .. msg)
            end
        end
    end
end

--===========================================================================
-- TAG TAB
--===========================================================================
local function render_tag_tab()
    if not ImGui then return end

    ImGui.Text("Tag Counts (from deck):")
    ImGui.Separator()

    -- Get tag counts from player or mock
    local tag_counts = state.tag_counts
    if globals and globals.player_state and globals.player_state.tag_counts then
        tag_counts = globals.player_state.tag_counts
    end

    -- Sort tags by count
    local sorted_tags = {}
    for tag, count in pairs(tag_counts) do
        table.insert(sorted_tags, { tag = tag, count = count })
    end
    table.sort(sorted_tags, function(a, b) return a.count > b.count end)

    -- Thresholds
    local thresholds = { 3, 5, 7, 9 }

    if #sorted_tags == 0 then
        ImGui.TextDisabled("No tags tracked")

        -- Add mock data button
        if ImGui.Button("Add Mock Data") then
            state.tag_counts = {
                Fire = 8,
                Projectile = 12,
                Arcane = 3,
                Ice = 1,
                AoE = 5,
            }
        end
    else
        for _, entry in ipairs(sorted_tags) do
            -- Calculate bar
            local max_display = 15
            local bar_pct = math.min(entry.count / max_display, 1.0)

            -- Check thresholds
            local threshold_hit = nil
            for _, t in ipairs(thresholds) do
                if entry.count >= t then
                    threshold_hit = t
                end
            end

            -- Draw bar
            local bar_text = string.rep("|", math.floor(bar_pct * 10))
            local empty = string.rep(".", 10 - math.floor(bar_pct * 10))

            local threshold_mark = ""
            if threshold_hit then
                threshold_mark = string.format(" (>=%d)", threshold_hit)
            end

            ImGui.Text(string.format("%-12s %s%s %2d%s",
                entry.tag,
                bar_text,
                empty,
                entry.count,
                threshold_mark))
        end
    end

    ImGui.Separator()
    ImGui.Text("Active Bonuses:")
    ImGui.Separator()

    -- Show which thresholds are hit
    local any_bonus = false
    for _, entry in ipairs(sorted_tags) do
        for _, t in ipairs(thresholds) do
            if entry.count >= t then
                ImGui.Text(string.format("[*] %s %d+", entry.tag, t))
                any_bonus = true
            end
        end
    end

    if not any_bonus then
        ImGui.TextDisabled("No threshold bonuses active")
    end

    ImGui.Separator()
    ImGui.Text("Last Spell Type:")
    ImGui.Separator()

    if state.spell_type_info then
        ImGui.Text(string.format("Type: %s", state.spell_type_info.type or "?"))
        ImGui.Text(string.format("Diversity: %d tags", state.spell_type_info.diversity or 0))
        ImGui.Text(string.format("Primary: %s (x%d)",
            state.spell_type_info.primary_tag or "?",
            state.spell_type_info.primary_count or 0))
    else
        ImGui.TextDisabled("No spell cast yet")
    end
end

local function render_settings_tab()
    ImGui.Text("Feature Flags")
    ImGui.Separator()

    local gameplay_cfg = _G.gameplay_cfg
    if not gameplay_cfg then
        ImGui.TextDisabled("gameplay_cfg not loaded")
        return
    end

    local gridEnabled = gameplay_cfg.USE_GRID_INVENTORY == true
    ImGui.Text("USE_GRID_INVENTORY: " .. (gridEnabled and "ON" or "OFF"))
    ImGui.TextDisabled("(Requires restart to take effect)")

    ImGui.Spacing()
    if ImGui.Button(gridEnabled and "Disable Grid Inventory" or "Enable Grid Inventory") then
        gameplay_cfg.USE_GRID_INVENTORY = not gridEnabled
        _G.USE_GRID_INVENTORY = gameplay_cfg.USE_GRID_INVENTORY
        print("[ContentDebugPanel] USE_GRID_INVENTORY set to " .. tostring(gameplay_cfg.USE_GRID_INVENTORY))
        print("[ContentDebugPanel] Restart required for changes to take effect")
    end

    ImGui.Separator()
    ImGui.Text("Wand System")

    local WandLoadoutUI = nil
    local ok, mod = pcall(require, "ui.wand_loadout_ui")
    if ok then WandLoadoutUI = mod end

    if WandLoadoutUI then
        local wandCount = WandLoadoutUI.getWandCount and WandLoadoutUI.getWandCount() or 1
        local currentWand = WandLoadoutUI.getCurrentWandIndex and WandLoadoutUI.getCurrentWandIndex() or 1
        ImGui.Text(string.format("Wands: %d/%d", currentWand, wandCount))

        if wandCount > 1 then
            ImGui.SameLine()
            if ImGui.Button("<##wand") then
                WandLoadoutUI.selectWand(currentWand - 1)
            end
            ImGui.SameLine()
            if ImGui.Button(">##wand") then
                WandLoadoutUI.selectWand(currentWand + 1)
            end
        end
    else
        ImGui.TextDisabled("WandLoadoutUI not loaded")
    end
end

function ContentDebugPanel.render()
    if not ImGui or not ImGui.Begin then return end

    ContentDebugPanel.init()

    if ImGui.Begin("Content Debug Panel") then
        if ImGui.Button(state.current_tab == 1 and "[Jokers]" or "Jokers") then
            state.current_tab = 1
        end
        ImGui.SameLine()
        if ImGui.Button(state.current_tab == 2 and "[Projectiles]" or "Projectiles") then
            state.current_tab = 2
        end
        ImGui.SameLine()
        if ImGui.Button(state.current_tab == 3 and "[Tags]" or "Tags") then
            state.current_tab = 3
        end
        ImGui.SameLine()
        if ImGui.Button(state.current_tab == 4 and "[Cards]" or "Cards") then
            state.current_tab = 4
        end
        ImGui.SameLine()
        if ImGui.Button(state.current_tab == 5 and "[Settings]" or "Settings") then
            state.current_tab = 5
        end

        ImGui.Separator()

        if state.current_tab == 1 then
            render_joker_tab()
        elseif state.current_tab == 2 then
            render_projectile_tab()
        elseif state.current_tab == 3 then
            render_tag_tab()
        elseif state.current_tab == 4 then
            render_cards_tab()
        elseif state.current_tab == 5 then
            render_settings_tab()
        end

        ImGui.Separator()
        ImGui.Text("Misc:")
        if ImGui.Button("Init New Item Reward") then
            if initNewItemRewardText then
                initNewItemRewardText()
            else
                print("[ContentDebugPanel] initNewItemRewardText not found")
            end
        end
    end
    ImGui.End()
end

-- Update spell type info (called from wand system)
function ContentDebugPanel.set_spell_type_info(info)
    state.spell_type_info = info
end

-- Update tag counts (called from player state)
function ContentDebugPanel.set_tag_counts(counts)
    state.tag_counts = counts or {}
end

return ContentDebugPanel
