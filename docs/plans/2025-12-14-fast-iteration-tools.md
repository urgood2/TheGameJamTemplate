# Fast Iteration Tools Implementation Plan (Revised)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement four high-impact developer tools that dramatically reduce iteration time for Lua gameplay programming.

**Architecture:**
- Console enhancement via C++ command registration
- Lua ImGui panels for visual tools (hot-reloadable)
- Data-driven spawn presets for flexibility
- Comprehensive 8-tab Combat Debug Panel

**Tech Stack:** C++ (console commands), Lua + Sol2 ImGui bindings, EnTT ECS

---

## Overview

| Feature | Approach | Files | Effort |
|---------|----------|-------|--------|
| 1. Console Enhancement | Add C++ commands | `src/core/gui.cpp` | Low |
| 2. Cards Browser | Extend content panel | `assets/scripts/ui/content_debug_panel.lua` | Medium |
| 3. Spawn Presets | Data-driven module | `assets/scripts/core/spawn.lua`, `assets/scripts/data/spawn_presets.lua` | Low |
| 4. Combat Debug Panel | New 8-tab panel | `assets/scripts/ui/combat_debug_panel.lua` | High |

---

## Feature 1: Console Enhancement

### Context

Existing C++ ImGuiConsole in `src/core/gui.cpp` has `lua` and `luadump` commands. We'll add more gameplay-focused commands.

### Task 1.1: Add Spawn Commands to C++ Console

**Files:**
- Modify: `src/core/gui.cpp` (after line 109, in `initConsole()`)

**Step 1: Add spawn command**

After the existing `luadump` command registration, add:

```cpp
// Spawn command - spawn entities at cursor
consolePtr->System().RegisterCommand("spawn",
    "Spawns an entity. Usage: spawn <type> <preset> [x] [y]. Types: enemy, projectile, pickup, effect",
    [](const std::string& type, const std::string& preset, float x, float y) {
        std::string lua_code = "local spawn = require('core.spawn'); ";
        lua_code += "local x, y = " + std::to_string(x) + ", " + std::to_string(y) + "; ";
        lua_code += "if x == 0 and y == 0 then x, y = globals.mouseX or 0, globals.mouseY or 0 end; ";

        if (type == "enemy") {
            lua_code += "return spawn.enemy('" + preset + "', x, y)";
        } else if (type == "projectile") {
            lua_code += "return spawn.projectile('" + preset + "', x, y)";
        } else if (type == "pickup") {
            lua_code += "return spawn.pickup('" + preset + "', x, y)";
        } else if (type == "effect") {
            lua_code += "return spawn.effect('" + preset + "', x, y)";
        } else {
            consolePtr->System().Log(csys::ItemType::ERROR) << "Unknown spawn type: " << type << csys::endl;
            return;
        }

        try {
            auto result = ai_system::masterStateLua.script(lua_code);
            if (result.valid()) {
                consolePtr->System().Log(csys::ItemType::INFO) << "Spawned " << type << " '" << preset << "'" << csys::endl;
            }
        } catch (const std::exception& e) {
            consolePtr->System().Log(csys::ItemType::ERROR) << "Spawn error: " << e.what() << csys::endl;
        }
    },
    csys::Arg<csys::String>("type"),
    csys::Arg<csys::String>("preset"),
    csys::Arg<float>("x", 0.0f),
    csys::Arg<float>("y", 0.0f)
);
```

**Step 2: Add stat command**

```cpp
// Stat command - modify player stats
consolePtr->System().RegisterCommand("stat",
    "Modify player stat. Usage: stat <name> <value> OR stat <name> +<delta>",
    [](const std::string& stat_name, const std::string& value_str) {
        std::string lua_code;
        if (value_str[0] == '+' || value_str[0] == '-') {
            lua_code = "if globals.player and globals.player.stats then "
                       "globals.player.stats:add_base('" + stat_name + "', " + value_str + "); "
                       "return globals.player.stats:get('" + stat_name + "') end";
        } else {
            lua_code = "if globals.player and globals.player.stats then "
                       "local raw = globals.player.stats:get_raw('" + stat_name + "'); "
                       "if raw then raw.base = " + value_str + "; end; "
                       "return globals.player.stats:get('" + stat_name + "') end";
        }

        try {
            auto result = ai_system::masterStateLua.script(lua_code);
            if (result.valid()) {
                consolePtr->System().Log(csys::ItemType::INFO)
                    << stat_name << " = " << result.get<std::string>() << csys::endl;
            }
        } catch (const std::exception& e) {
            consolePtr->System().Log(csys::ItemType::ERROR) << "Stat error: " << e.what() << csys::endl;
        }
    },
    csys::Arg<csys::String>("stat_name"),
    csys::Arg<csys::String>("value")
);
```

**Step 3: Add heal command**

```cpp
// Heal command
consolePtr->System().RegisterCommand("heal",
    "Heal player. Usage: heal [amount] (default: full heal)",
    [](int amount) {
        std::string lua_code;
        if (amount <= 0) {
            lua_code = "if globals.player_state then "
                       "globals.player_state.health = globals.player_state.max_health; "
                       "return 'Full heal' end";
        } else {
            lua_code = "if globals.player_state then "
                       "globals.player_state.health = math.min(globals.player_state.health + " +
                       std::to_string(amount) + ", globals.player_state.max_health); "
                       "return globals.player_state.health end";
        }

        try {
            auto result = ai_system::masterStateLua.script(lua_code);
            consolePtr->System().Log(csys::ItemType::INFO) << "Healed: " << result.get<std::string>() << csys::endl;
        } catch (const std::exception& e) {
            consolePtr->System().Log(csys::ItemType::ERROR) << e.what() << csys::endl;
        }
    },
    csys::Arg<int>("amount", 0)
);
```

**Step 4: Add gold command**

```cpp
// Gold command
consolePtr->System().RegisterCommand("gold",
    "Add gold. Usage: gold <amount>",
    [](int amount) {
        std::string lua_code = "globals.currency = (globals.currency or 0) + " +
                               std::to_string(amount) + "; return globals.currency";
        try {
            auto result = ai_system::masterStateLua.script(lua_code);
            consolePtr->System().Log(csys::ItemType::INFO) << "Gold: " << result.get<int>() << csys::endl;
        } catch (const std::exception& e) {
            consolePtr->System().Log(csys::ItemType::ERROR) << e.what() << csys::endl;
        }
    },
    csys::Arg<int>("amount")
);
```

**Step 5: Add joker command**

```cpp
// Joker command
consolePtr->System().RegisterCommand("joker",
    "Add/remove joker. Usage: joker add <id> OR joker remove <id> OR joker list",
    [](const std::string& action, const std::string& joker_id) {
        std::string lua_code;
        if (action == "add") {
            lua_code = "local js = require('wand.joker_system'); "
                       "if js.add_joker then js.add_joker('" + joker_id + "'); return 'Added' end";
        } else if (action == "remove") {
            lua_code = "local js = require('wand.joker_system'); "
                       "if js.remove_joker then js.remove_joker('" + joker_id + "'); return 'Removed' end";
        } else if (action == "list") {
            lua_code = "local js = require('wand.joker_system'); "
                       "local result = ''; "
                       "if js.jokers then for _, j in ipairs(js.jokers) do "
                       "result = result .. j.id .. ', ' end end; "
                       "return result ~= '' and result or 'No active jokers'";
        } else {
            consolePtr->System().Log(csys::ItemType::ERROR) << "Unknown action: " << action << csys::endl;
            return;
        }

        try {
            auto result = ai_system::masterStateLua.script(lua_code);
            consolePtr->System().Log(csys::ItemType::INFO) << result.get<std::string>() << csys::endl;
        } catch (const std::exception& e) {
            consolePtr->System().Log(csys::ItemType::ERROR) << e.what() << csys::endl;
        }
    },
    csys::Arg<csys::String>("action"),
    csys::Arg<csys::String>("joker_id", "")
);
```

**Step 6: Build and test**

Run: `just build-debug && ./build/raylib-cpp-cmake-template`
Test commands in console:
- `spawn enemy kobold`
- `stat physique +10`
- `heal`
- `gold 1000`
- `joker add pyromaniac`

**Step 7: Commit**

```bash
git add src/core/gui.cpp
git commit -m "feat(console): add spawn, stat, heal, gold, joker commands"
```

---

## Feature 2: Cards Browser (Enhanced Content Panel)

### Task 2.1: Add Cards Tab with Sprite Preview, Sort, Filter, Test Cast

**Files:**
- Modify: `assets/scripts/ui/content_debug_panel.lua`

**Step 1: Add cards state**

In the `state` table (around line 22), add:

```lua
    -- Cards tab state (Tab 4)
    card_list = {},
    card_filter_text = "",
    card_filter_tag = nil,      -- nil = all, or specific tag
    card_sort_by = "name",      -- "name", "mana", "damage", "type"
    card_sort_asc = true,
    selected_card = nil,
    available_tags = {},
    test_cast_result = nil,
```

**Step 2: Load cards in init**

In the `init()` function, after loading projectiles, add:

```lua
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
```

**Step 3: Add sort/filter helpers**

Add these functions before `render_joker_tab()`:

```lua
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
```

**Step 4: Create render_cards_tab function**

```lua
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
    local tag_changed, new_tag_idx = ImGui.Combo("##tag_filter", current_tag_idx, tag_options, #tag_options)
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
```

**Step 5: Register the tab**

In `render()`, add the Cards tab button after Tags:
```lua
        ImGui.SameLine()
        if ImGui.Button(state.current_tab == 4 and "[Cards]" or "Cards") then
            state.current_tab = 4
        end
```

And in the tab rendering section:
```lua
        elseif state.current_tab == 4 then
            render_cards_tab()
```

**Step 6: Test**

Run game, open Content Debug Panel, verify Cards tab works with filter/sort/test cast.

**Step 7: Commit**

```bash
git add assets/scripts/ui/content_debug_panel.lua
git commit -m "feat(cards): add Cards tab with sprite preview, sort/filter, test cast"
```

---

## Feature 3: Spawn Presets (Data-Driven)

### Task 3.1: Create Spawn Presets Data File

**Files:**
- Create: `assets/scripts/data/spawn_presets.lua`

**Step 1: Create the data file**

```lua
--[[
================================================================================
SPAWN PRESETS - Data-driven entity templates
================================================================================
Edit this file to add/modify spawn presets. Hot-reloadable.

Structure:
  {
    sprite = "sprite_id",           -- Animation/sprite to use
    size = { width, height },       -- Entity size
    shadow = true/false,            -- Show shadow
    defaults = { ... },             -- Default script data
    physics = { ... },              -- Physics config (optional)
    shaders = { "shader1", ... },   -- Shaders to apply (optional)
  }
]]

return {
    --=========================================================================
    -- ENEMIES
    --=========================================================================
    enemies = {
        -- Example enemy (replace with your actual enemies)
        kobold = {
            sprite = "kobold",
            size = { 32, 32 },
            shadow = true,
            defaults = {
                health = 30,
                damage = 5,
                speed = 80,
                faction = "enemy",
            },
            physics = {
                shape = "circle",
                tag = "enemy",
            },
        },

        slime = {
            sprite = "slime",
            size = { 24, 24 },
            shadow = true,
            defaults = {
                health = 15,
                damage = 3,
                speed = 40,
                faction = "enemy",
            },
            physics = {
                shape = "circle",
                tag = "enemy",
            },
        },

        -- Add your actual enemies here
    },

    --=========================================================================
    -- PROJECTILES
    --=========================================================================
    projectiles = {
        fireball = {
            sprite = "fireball",
            size = { 16, 16 },
            defaults = {
                damage = 25,
                speed = 400,
                damage_type = "fire",
                lifetime = 2000,
            },
            physics = {
                shape = "circle",
                tag = "projectile",
                sensor = true,
            },
            shaders = { "glow_pulse" },
        },

        arrow = {
            sprite = "arrow",
            size = { 24, 8 },
            defaults = {
                damage = 15,
                speed = 600,
                damage_type = "physical",
                lifetime = 3000,
            },
            physics = {
                shape = "circle",
                tag = "projectile",
                sensor = true,
            },
        },

        icebolt = {
            sprite = "icebolt",
            size = { 12, 12 },
            defaults = {
                damage = 20,
                speed = 350,
                damage_type = "ice",
                lifetime = 2500,
            },
            physics = {
                shape = "circle",
                tag = "projectile",
                sensor = true,
            },
        },

        -- Add more projectiles
    },

    --=========================================================================
    -- PICKUPS
    --=========================================================================
    pickups = {
        health_potion = {
            sprite = "potion_health",
            size = { 16, 16 },
            shadow = true,
            defaults = {
                heal_amount = 25,
                pickup_type = "health",
            },
            physics = {
                shape = "circle",
                tag = "pickup",
                sensor = true,
            },
        },

        mana_potion = {
            sprite = "potion_mana",
            size = { 16, 16 },
            shadow = true,
            defaults = {
                mana_amount = 20,
                pickup_type = "mana",
            },
            physics = {
                shape = "circle",
                tag = "pickup",
                sensor = true,
            },
        },

        gold = {
            sprite = "gold_coin",
            size = { 12, 12 },
            defaults = {
                value = 10,
                pickup_type = "gold",
            },
            physics = {
                shape = "circle",
                tag = "pickup",
                sensor = true,
            },
        },

        -- Add more pickups
    },

    --=========================================================================
    -- EFFECTS (visual only, auto-destroy)
    --=========================================================================
    effects = {
        explosion = {
            sprite = "explosion",
            size = { 64, 64 },
            defaults = {
                lifetime = 500,
                auto_destroy = true,
            },
        },

        hit_spark = {
            sprite = "hit_spark",
            size = { 24, 24 },
            defaults = {
                lifetime = 200,
                auto_destroy = true,
            },
        },

        smoke_puff = {
            sprite = "smoke",
            size = { 32, 32 },
            defaults = {
                lifetime = 800,
                auto_destroy = true,
            },
        },

        -- Add more effects
    },
}
```

**Step 2: Commit**

```bash
git add assets/scripts/data/spawn_presets.lua
git commit -m "feat: add spawn presets data file"
```

---

### Task 3.2: Create Spawn Module

**Files:**
- Create: `assets/scripts/core/spawn.lua`

**Step 1: Create the module**

```lua
--[[
================================================================================
SPAWN - One-Line Entity Creation
================================================================================
Data-driven spawn system. Presets loaded from data/spawn_presets.lua.

Usage:
    local spawn = require("core.spawn")

    spawn.enemy("kobold", 100, 200)
    spawn.enemy("kobold", 100, 200, { health = 50 })
    spawn.projectile("fireball", x, y, { target_x = tx, target_y = ty })
    spawn.pickup("gold", x, y, { value = 100 })
    spawn.effect("explosion", x, y)
    spawn.at_cursor(spawn.enemy, "kobold")

Extending:
    -- Edit data/spawn_presets.lua (hot-reloadable)
    -- OR register at runtime:
    spawn.register("enemies", "goblin", { sprite = "goblin", ... })
]]

if _G.__SPAWN__ then
    return _G.__SPAWN__
end

local spawn = {}

-- Dependencies
local EntityBuilder = require("core.entity_builder")
local entity_cache = require("core.entity_cache")

-- Optional dependencies
local PhysicsBuilder = nil
pcall(function() PhysicsBuilder = require("core.physics_builder") end)

-- Load presets from data file
local function load_presets()
    local ok, data = pcall(require, "data.spawn_presets")
    if ok then
        return data
    else
        log_warn("spawn: Could not load data/spawn_presets.lua: " .. tostring(data))
        return { enemies = {}, projectiles = {}, pickups = {}, effects = {} }
    end
end

spawn.presets = load_presets()

-- Reload presets (for hot-reload)
function spawn.reload()
    package.loaded["data.spawn_presets"] = nil
    spawn.presets = load_presets()
end

--------------------------------------------------------------------------------
-- CORE SPAWN FUNCTION
--------------------------------------------------------------------------------

local function spawn_from_preset(category, preset_name, x, y, overrides)
    local presets = spawn.presets[category]
    if not presets then
        log_warn("spawn: unknown category '" .. tostring(category) .. "'")
        return nil
    end

    local preset = presets[preset_name]
    if not preset then
        log_warn("spawn: unknown preset '" .. tostring(preset_name) .. "' in " .. category)
        -- Try first available preset as fallback
        for name, p in pairs(presets) do
            preset = p
            break
        end
        if not preset then return nil end
    end

    -- Merge defaults with overrides
    local data = { entity_type = category:sub(1, -2), preset = preset_name }  -- Remove trailing 's'
    if preset.defaults then
        for k, v in pairs(preset.defaults) do
            data[k] = v
        end
    end
    if overrides then
        for k, v in pairs(overrides) do
            data[k] = v
        end
    end

    -- Create entity
    local entity = EntityBuilder.create({
        sprite = preset.sprite,
        position = { x = x, y = y },
        size = preset.size or { 32, 32 },
        shadow = preset.shadow,
        data = data,
        shaders = preset.shaders,
    })

    -- Add physics
    if PhysicsBuilder and preset.physics then
        PhysicsBuilder.quick(entity, preset.physics)
    end

    -- Auto-destroy for effects
    if data.auto_destroy and data.lifetime then
        local timer = require("core.timer")
        timer.after(data.lifetime / 1000, function()
            if entity_cache.valid(entity) then
                registry:destroy(entity)
            end
        end)
    end

    return entity
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

function spawn.enemy(preset_name, x, y, overrides)
    return spawn_from_preset("enemies", preset_name, x, y, overrides)
end

function spawn.projectile(preset_name, x, y, opts)
    opts = opts or {}

    -- Calculate velocity if target provided
    if opts.target_x and opts.target_y then
        local preset = spawn.presets.projectiles[preset_name]
        local speed = opts.speed or (preset and preset.defaults and preset.defaults.speed) or 400

        local dx = opts.target_x - x
        local dy = opts.target_y - y
        local len = math.sqrt(dx * dx + dy * dy)

        if len > 0 then
            opts.velocity_x = (dx / len) * speed
            opts.velocity_y = (dy / len) * speed
        end
    end

    return spawn_from_preset("projectiles", preset_name, x, y, opts)
end

function spawn.pickup(preset_name, x, y, overrides)
    return spawn_from_preset("pickups", preset_name, x, y, overrides)
end

function spawn.effect(preset_name, x, y, overrides)
    return spawn_from_preset("effects", preset_name, x, y, overrides)
end

function spawn.at_cursor(spawn_fn, preset_name, overrides)
    local x = globals and globals.mouseX or 0
    local y = globals and globals.mouseY or 0
    return spawn_fn(preset_name, x, y, overrides)
end

--------------------------------------------------------------------------------
-- PRESET MANAGEMENT
--------------------------------------------------------------------------------

function spawn.register(category, name, config)
    if not spawn.presets[category] then
        spawn.presets[category] = {}
    end
    spawn.presets[category][name] = config
end

function spawn.list(category)
    local result = {}
    if spawn.presets[category] then
        for name, _ in pairs(spawn.presets[category]) do
            table.insert(result, name)
        end
        table.sort(result)
    end
    return result
end

function spawn.get_preset(category, name)
    return spawn.presets[category] and spawn.presets[category][name]
end

_G.__SPAWN__ = spawn
return spawn
```

**Step 2: Test**

In Lua console:
```lua
local spawn = require("core.spawn"); spawn.enemy("kobold", 100, 100)
spawn.list("enemies")
```

**Step 3: Commit**

```bash
git add assets/scripts/core/spawn.lua
git commit -m "feat: add data-driven spawn module"
```

---

## Feature 4: Combat Debug Panel (8 Tabs)

This is the largest feature. We'll implement it in multiple sub-tasks.

### Task 4.1: Create Combat Debug Panel Skeleton

**Files:**
- Create: `assets/scripts/ui/combat_debug_panel.lua`
- Modify: `assets/scripts/core/gameplay.lua` (add render call)

**Step 1: Create the module skeleton**

```lua
--[[
================================================================================
COMBAT DEBUG PANEL - Comprehensive Combat System Inspector
================================================================================
8-tab panel for viewing and modifying all combat-related state.

Tabs:
  1. Stats     - Core attributes + derived stats
  2. Combat    - Offense, damage modifiers, penetration
  3. Defense   - Armor, dodge, block, resistances, absorb
  4. Relics    - Equipment/items + economy
  5. Jokers    - Passive modifiers
  6. Tags      - Synergy breakpoints + procs
  7. Wand      - Spell system + deck editor
  8. Status    - Active buffs/debuffs/DoTs
]]

local CombatDebugPanel = {}

-- Dependencies (lazy loaded)
local component_cache = nil
local StatSystem = nil
local JokerSystem = nil
local TagEvaluator = nil

-- State
local state = {
    initialized = false,
    current_tab = 1,

    -- Tab 1: Stats
    core_stats = {
        { name = "physique", display = "Physique", value = 10, min = 1, max = 100 },
        { name = "cunning", display = "Cunning", value = 10, min = 1, max = 100 },
        { name = "spirit", display = "Spirit", value = 10, min = 1, max = 100 },
    },
    derived_stats = {},
    show_formulas = true,
    player_level = 1,
    player_xp = 0,

    -- Tab 2: Combat
    offense_stats = {},
    damage_modifiers = {},
    dot_durations = {},
    penetration = {},

    -- Tab 3: Defense
    defense_stats = {},
    resistances = {},
    resist_caps = {},
    absorb = {},

    -- Tab 4: Relics
    owned_relics = {},
    available_relics = {},
    gold = 0,

    -- Tab 5: Jokers
    active_jokers = {},
    available_jokers = {},
    joker_test_result = nil,

    -- Tab 6: Tags
    tag_counts = {},
    active_bonuses = {},
    active_procs = {},

    -- Tab 7: Wand
    wand_frames = {},
    active_wand = nil,
    deck_cards = {},

    -- Tab 8: Status
    current_hp = 0,
    max_hp = 0,
    current_energy = 0,
    max_energy = 0,
    active_buffs = {},
    active_debuffs = {},
    active_dots = {},
}

--===========================================================================
-- INITIALIZATION
--===========================================================================
function CombatDebugPanel.init()
    if state.initialized then return end

    -- Load dependencies
    local ok1, cc = pcall(require, "core.component_cache")
    if ok1 then component_cache = cc end

    local ok2, ss = pcall(require, "core.stat_system")
    if ok2 then StatSystem = ss end

    local ok3, js = pcall(require, "wand.joker_system")
    if ok3 then JokerSystem = js end

    local ok4, te = pcall(require, "wand.tag_evaluator")
    if ok4 then TagEvaluator = te end

    -- Load available relics from globals
    if globals and globals.relic_defs then
        state.available_relics = {}
        for id, def in pairs(globals.relic_defs) do
            table.insert(state.available_relics, { id = id, def = def })
        end
        table.sort(state.available_relics, function(a, b) return a.id < b.id end)
    end

    -- Load joker definitions
    local ok_jokers, jokers = pcall(require, "data.jokers")
    if ok_jokers then
        state.available_jokers = {}
        for id, joker in pairs(jokers) do
            if type(joker) == "table" and joker.id then
                table.insert(state.available_jokers, {
                    id = joker.id,
                    name = joker.name or joker.id,
                    rarity = joker.rarity or "Common",
                    description = joker.description or "",
                })
            end
        end
        table.sort(state.available_jokers, function(a, b) return a.name < b.name end)
    end

    -- Sync initial state from player
    CombatDebugPanel.sync_from_player()

    state.initialized = true
end

--===========================================================================
-- SYNC FROM/TO PLAYER
--===========================================================================
function CombatDebugPanel.sync_from_player()
    -- This will be implemented per-tab
    -- For now, just sync basic info
    if globals then
        state.gold = globals.currency or 0

        if globals.player_state then
            state.current_hp = globals.player_state.health or 0
            state.max_hp = globals.player_state.max_health or 100
            state.current_energy = globals.player_state.energy or 0
            state.max_energy = globals.player_state.max_energy or 100
        end

        if globals.ownedRelics then
            state.owned_relics = {}
            for _, relic in ipairs(globals.ownedRelics) do
                table.insert(state.owned_relics, relic.id or relic)
            end
        end
    end
end

function CombatDebugPanel.apply_to_player()
    -- Apply changes to player - implemented per-tab
end

--===========================================================================
-- TAB RENDERING (Stubs - to be implemented)
--===========================================================================
local function render_stats_tab()
    ImGui.TextDisabled("Stats tab - TODO")
end

local function render_combat_tab()
    ImGui.TextDisabled("Combat tab - TODO")
end

local function render_defense_tab()
    ImGui.TextDisabled("Defense tab - TODO")
end

local function render_relics_tab()
    ImGui.TextDisabled("Relics tab - TODO")
end

local function render_jokers_tab()
    ImGui.TextDisabled("Jokers tab - TODO")
end

local function render_tags_tab()
    ImGui.TextDisabled("Tags tab - TODO")
end

local function render_wand_tab()
    ImGui.TextDisabled("Wand tab - TODO")
end

local function render_status_tab()
    ImGui.TextDisabled("Status tab - TODO")
end

--===========================================================================
-- MAIN RENDER
--===========================================================================
function CombatDebugPanel.render()
    if not ImGui or not ImGui.Begin then return end

    CombatDebugPanel.init()

    if ImGui.Begin("Combat Debug Panel") then
        -- Tab buttons
        local tabs = { "Stats", "Combat", "Defense", "Relics", "Jokers", "Tags", "Wand", "Status" }

        for i, tab_name in ipairs(tabs) do
            local label = state.current_tab == i and ("[" .. tab_name .. "]") or tab_name
            if ImGui.Button(label) then
                state.current_tab = i
            end
            if i < #tabs then
                ImGui.SameLine()
            end
        end

        ImGui.Separator()

        -- Render current tab
        if state.current_tab == 1 then
            render_stats_tab()
        elseif state.current_tab == 2 then
            render_combat_tab()
        elseif state.current_tab == 3 then
            render_defense_tab()
        elseif state.current_tab == 4 then
            render_relics_tab()
        elseif state.current_tab == 5 then
            render_jokers_tab()
        elseif state.current_tab == 6 then
            render_tags_tab()
        elseif state.current_tab == 7 then
            render_wand_tab()
        elseif state.current_tab == 8 then
            render_status_tab()
        end
    end
    ImGui.End()
end

return CombatDebugPanel
```

**Step 2: Register in gameplay.lua**

At top of file:
```lua
local CombatDebugPanel = require("ui.combat_debug_panel")
```

In `debugUI()`:
```lua
    -- Combat Debug Panel
    if CombatDebugPanel and CombatDebugPanel.render then
        CombatDebugPanel.render()
    end
```

**Step 3: Test skeleton**

Run game, verify "Combat Debug Panel" window appears with 8 tab buttons.

**Step 4: Commit**

```bash
git add assets/scripts/ui/combat_debug_panel.lua assets/scripts/core/gameplay.lua
git commit -m "feat: add Combat Debug Panel skeleton with 8 tabs"
```

---

### Task 4.2: Implement Stats Tab

**Files:**
- Modify: `assets/scripts/ui/combat_debug_panel.lua`

**Step 1: Implement render_stats_tab**

```lua
local function render_stats_tab()
    if not ImGui then return end

    -- Sync button
    if ImGui.Button("Sync from Player") then
        CombatDebugPanel.sync_from_player()
    end
    ImGui.SameLine()
    if ImGui.Button("Apply to Player") then
        CombatDebugPanel.apply_stats_to_player()
    end

    ImGui.Separator()
    ImGui.Text("CORE ATTRIBUTES")
    ImGui.Separator()

    -- Core stat sliders
    local any_changed = false
    for _, stat in ipairs(state.core_stats) do
        ImGui.PushID("core_" .. stat.name)

        local changed, new_value = ImGui.SliderInt(stat.display, stat.value, stat.min, stat.max)
        if changed then
            stat.value = new_value
            any_changed = true
        end

        ImGui.SameLine()
        if ImGui.SmallButton("-") and stat.value > stat.min then
            stat.value = stat.value - 1
            any_changed = true
        end
        ImGui.SameLine()
        if ImGui.SmallButton("+") and stat.value < stat.max then
            stat.value = stat.value + 1
            any_changed = true
        end

        ImGui.PopID()
    end

    -- Recalculate derived stats if changed
    if any_changed then
        CombatDebugPanel.calculate_derived_stats()
    end

    ImGui.Separator()

    -- Show formulas checkbox
    local formula_changed
    formula_changed, state.show_formulas = ImGui.Checkbox("Show Formulas", state.show_formulas)

    ImGui.Text("DERIVED STATS")
    ImGui.Separator()

    -- Display derived stats
    if #state.derived_stats > 0 then
        for _, derived in ipairs(state.derived_stats) do
            if state.show_formulas and derived.formula then
                ImGui.Text(string.format("  %s: %.1f  = %s", derived.name, derived.value, derived.formula))
            else
                ImGui.Text(string.format("  %s: %.1f", derived.name, derived.value))
            end
        end
    else
        ImGui.TextDisabled("  (calculating...)")
        CombatDebugPanel.calculate_derived_stats()
    end

    ImGui.Separator()
    ImGui.Text("LEVEL / XP")
    ImGui.Separator()

    ImGui.Text(string.format("  Level: %d", state.player_level))
    ImGui.SameLine()
    if ImGui.SmallButton("+Level") then
        state.player_level = state.player_level + 1
    end

    local xp_changed
    xp_changed, state.player_xp = ImGui.InputInt("XP", state.player_xp)

    ImGui.Separator()
    ImGui.Text("PRESETS")

    if ImGui.Button("Glass Cannon") then
        state.core_stats[1].value = 5   -- physique
        state.core_stats[2].value = 15  -- cunning
        state.core_stats[3].value = 40  -- spirit
        CombatDebugPanel.calculate_derived_stats()
    end
    ImGui.SameLine()

    if ImGui.Button("Tank") then
        state.core_stats[1].value = 50
        state.core_stats[2].value = 10
        state.core_stats[3].value = 10
        CombatDebugPanel.calculate_derived_stats()
    end
    ImGui.SameLine()

    if ImGui.Button("Balanced") then
        state.core_stats[1].value = 20
        state.core_stats[2].value = 20
        state.core_stats[3].value = 20
        CombatDebugPanel.calculate_derived_stats()
    end
    ImGui.SameLine()

    if ImGui.Button("Speedster") then
        state.core_stats[1].value = 15
        state.core_stats[2].value = 35
        state.core_stats[3].value = 20
        CombatDebugPanel.calculate_derived_stats()
    end
end
```

**Step 2: Add derived stats calculation**

```lua
function CombatDebugPanel.calculate_derived_stats()
    local physique = state.core_stats[1].value
    local cunning = state.core_stats[2].value
    local spirit = state.core_stats[3].value

    state.derived_stats = {
        -- From Physique
        { name = "health", value = 100 + physique * 10 + spirit * 2,
          formula = string.format("100 + (%d×10) + (%d×2)", physique, spirit) },
        { name = "health_regen", value = math.max(0, physique - 10) * 0.2,
          formula = string.format("max(0, %d-10) × 0.2", physique) },

        -- From Spirit
        { name = "energy", value = spirit * 10,
          formula = string.format("%d × 10", spirit) },
        { name = "energy_regen", value = spirit * 0.5,
          formula = string.format("%d × 0.5", spirit) },

        -- From Cunning
        { name = "offensive_ability", value = cunning * 1,
          formula = string.format("%d × 1", cunning) },
        { name = "physical_mod_%", value = math.floor(cunning / 5) * 1,
          formula = string.format("floor(%d/5) × 1", cunning) },

        -- Elemental from Spirit
        { name = "fire_mod_%", value = math.floor(spirit / 5) * 1,
          formula = string.format("floor(%d/5) × 1", spirit) },
        { name = "cold_mod_%", value = math.floor(spirit / 5) * 1,
          formula = string.format("floor(%d/5) × 1", spirit) },
        { name = "lightning_mod_%", value = math.floor(spirit / 5) * 1,
          formula = string.format("floor(%d/5) × 1", spirit) },
    }
end

function CombatDebugPanel.apply_stats_to_player()
    if not globals or not globals.player then return end

    -- Apply core stats
    if globals.player.stats then
        for _, stat in ipairs(state.core_stats) do
            local raw = globals.player.stats:get_raw(stat.name)
            if raw then
                raw.base = stat.value
            end
        end
        globals.player.stats:recompute()
    end

    -- Emit signal
    local ok, signal = pcall(require, "external.hump.signal")
    if ok then
        signal.emit("stats_recomputed")
    end

    print("[CombatDebugPanel] Applied stats to player")
end
```

**Step 3: Commit**

```bash
git add assets/scripts/ui/combat_debug_panel.lua
git commit -m "feat(combat-panel): implement Stats tab with core/derived stats"
```

---

### Tasks 4.3-4.9: Remaining Tabs

The remaining tabs follow the same pattern. Each task:
1. Implements the `render_*_tab()` function
2. Adds any helper functions needed
3. Tests and commits

**Task 4.3:** Combat Tab (offense, damage modifiers, DoT durations, penetration)
**Task 4.4:** Defense Tab (armor, dodge, block, resistances, absorb)
**Task 4.5:** Relics Tab (owned relics, add/remove, economy)
**Task 4.6:** Jokers Tab (active jokers, test events)
**Task 4.7:** Tags Tab (tag counts, breakpoints, procs)
**Task 4.8:** Wand Tab (wand frames, cooldowns, deck editor)
**Task 4.9:** Status Tab (HP/energy, buffs, debuffs, DoTs)

Each tab implementation will be ~100-200 lines following the same ImGui patterns.

---

## Summary

| Task | Feature | Commits |
|------|---------|---------|
| 1.1 | Console commands (spawn, stat, heal, gold, joker) | 1 |
| 2.1 | Cards tab (preview, sort, filter, test cast) | 1 |
| 3.1 | Spawn presets data file | 1 |
| 3.2 | Spawn module | 1 |
| 4.1 | Combat panel skeleton | 1 |
| 4.2 | Stats tab | 1 |
| 4.3 | Combat tab | 1 |
| 4.4 | Defense tab | 1 |
| 4.5 | Relics tab | 1 |
| 4.6 | Jokers tab | 1 |
| 4.7 | Tags tab | 1 |
| 4.8 | Wand tab (with deck editor) | 1 |
| 4.9 | Status tab | 1 |

**Total: 13 tasks → ~13 commits**

---

## Execution Strategy

1. **Subagent-driven development** - Fresh subagent per task for clean context
2. **Code review between tasks** - Verify each tab works before moving on
3. **Pre-compaction status dumps** - If context runs low, commit WIP and document next steps
4. **Hot-reload testing** - All Lua panels can be tested without rebuilding (except console commands)

---

## Testing Checklist

After all tasks:

- [ ] Console: `spawn enemy kobold` works
- [ ] Console: `stat physique +10` works
- [ ] Console: `heal`, `gold 1000`, `joker add/remove` work
- [ ] Cards tab: filter, sort, test cast all work
- [ ] Spawn: `spawn.enemy()`, `spawn.projectile()` work
- [ ] Combat Panel: All 8 tabs render
- [ ] Stats tab: Sliders change derived stats, Apply works
- [ ] Combat tab: Damage modifiers editable
- [ ] Defense tab: Resistances with visual caps
- [ ] Relics tab: Add/remove relics, gold editable
- [ ] Jokers tab: Add/remove, test events show results
- [ ] Tags tab: +/- buttons change counts, bonuses update
- [ ] Wand tab: Deck editor can add/remove/reorder cards
- [ ] Status tab: HP/energy bars, buff/debuff/DoT management

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
