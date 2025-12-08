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

-- State
local state = {
    initialized = false,
    current_tab = 1,  -- 1=Jokers, 2=Projectiles, 3=Tags

    -- Joker tab state
    joker_list = {},
    joker_test_result = nil,

    -- Projectile tab state
    projectile_presets = {},
    selected_preset = 1,
    spawn_params = {
        speed = 500,
        homing_strength = 8,
        bounce_count = 3,
        explosion_radius = 60,
    },
    last_spawned = nil,

    -- Tag tab state
    tag_counts = {},
    spell_type_info = nil,
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

    state.initialized = true
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
        local changed
        changed, state.selected_preset = ImGui.Combo("##preset", state.selected_preset, preset_names, #preset_names)

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
    local speed_changed
    speed_changed, state.spawn_params.speed = ImGui.SliderInt("Speed", state.spawn_params.speed, 100, 1500)

    -- Homing strength slider
    local homing_changed
    homing_changed, state.spawn_params.homing_strength = ImGui.SliderInt("Homing", state.spawn_params.homing_strength, 0, 15)

    -- Bounce count slider
    local bounce_changed
    bounce_changed, state.spawn_params.bounce_count = ImGui.SliderInt("Bounces", state.spawn_params.bounce_count, 0, 10)

    -- Explosion radius slider
    local explode_changed
    explode_changed, state.spawn_params.explosion_radius = ImGui.SliderInt("Explosion", state.spawn_params.explosion_radius, 0, 200)

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

--===========================================================================
-- MAIN RENDER
--===========================================================================
function ContentDebugPanel.render()
    if not ImGui or not ImGui.Begin then return end

    ContentDebugPanel.init()

    if ImGui.Begin("Content Debug Panel") then
        -- Tab buttons
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

        ImGui.Separator()

        -- Render current tab
        if state.current_tab == 1 then
            render_joker_tab()
        elseif state.current_tab == 2 then
            render_projectile_tab()
        elseif state.current_tab == 3 then
            render_tag_tab()
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
