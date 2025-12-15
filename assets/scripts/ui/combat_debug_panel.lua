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
local PlayerStatsAccessor = nil  -- lazy loaded

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
    offense_stats = {
        weapon_min = 18,
        weapon_max = 25,
        attack_speed = 1.0,
        crit_damage_pct = 50,
        all_damage_pct = 0,
        life_steal_pct = 0,
    },
    damage_modifiers = {
        physical = 0, pierce = 0, fire = 0, cold = 0, lightning = 0,
        acid = 0, vitality = 0, aether = 0, chaos = 0, poison = 0,
    },
    dot_durations = {
        bleed = 1.0, trauma = 1.0, burn = 1.0, frostburn = 1.0,
        electrocute = 1.0, poison = 1.0, vitality_decay = 1.0,
    },
    penetration = {
        physical = 0, pierce = 0, fire = 0, cold = 0, lightning = 0,
        acid = 0, vitality = 0, aether = 0, chaos = 0, poison = 0,
    },

    -- Tab 3: Defense
    defense_stats = {
        armor = 0,
        dodge_chance_pct = 0,
        block_chance_pct = 0,
        block_amount = 0,
        block_recovery_reduction_pct = 50,
    },
    resistances = {
        physical = 0, pierce = 0, fire = 0, cold = 0, lightning = 0,
        acid = 0, vitality = 0, aether = 0, chaos = 0, poison = 0,
    },
    resist_caps = {
        physical = 80, pierce = 80, fire = 80, cold = 80, lightning = 80,
        acid = 80, vitality = 80, aether = 80, chaos = 80, poison = 80,
    },
    absorb = {
        percent = 0,
        flat = 0,
    },

    -- Damage preview
    damage_preview = {
        incoming = 100,
        damage_type = "physical",
        result = 0,
        breakdown = {},
    },

    -- Tab 4: Relics
    owned_relics = {},
    available_relics = {},
    gold = 0,
    relic_filter = "",

    -- Tab 5: Jokers
    active_jokers = {},
    available_jokers = {},
    joker_test_result = nil,
    joker_filter = "",
    joker_rarity_filter = "All",
    test_event_type = "on_spell_cast",

    -- Tab 6: Tags
    tag_counts = {
        Fire = 0, Cold = 0, Lightning = 0, Poison = 0,
        Projectile = 0, AoE = 0, Hazard = 0, Summon = 0, Buff = 0, Debuff = 0,
        Mobility = 0, Defense = 0, Brute = 0,
    },
    active_bonuses = {},
    active_procs = {},

    -- Tab 7: Wand
    wand_frames = {},
    active_wand = nil,
    deck_cards = {},
    deck_filter = "",
    deck_type_filter = "All",

    -- Tab 8: Status
    current_hp = 100,
    max_hp = 100,
    current_energy = 50,
    max_energy = 100,
    active_buffs = {},
    active_debuffs = {},
    active_dots = {},
    selected_buff = 1,
    selected_debuff = 1,
    selected_dot = 1,
    new_dot_dps = 10,
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

    local ok5, psa = pcall(require, "ui.player_stats_accessor")
    if ok5 then PlayerStatsAccessor = psa end

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
    if not PlayerStatsAccessor then
        print("[CombatDebugPanel] PlayerStatsAccessor not loaded")
        return
    end

    local player = PlayerStatsAccessor.get_player()
    if not player then
        print("[CombatDebugPanel] No player in combat context")
        return
    end

    -- Sync core stats
    for _, stat in ipairs(state.core_stats) do
        stat.value = PlayerStatsAccessor.get_raw(stat.name).base
    end

    -- Sync HP/Energy
    state.current_hp, state.max_hp = PlayerStatsAccessor.get_hp()
    state.current_energy = PlayerStatsAccessor.get('energy') or 50
    state.max_energy = PlayerStatsAccessor.get('energy') or 100

    -- Sync level
    state.player_level = player.level or 1
    state.player_xp = player.xp or 0

    -- Sync gold from globals
    if globals then
        state.gold = globals.currency or 0
    end

    CombatDebugPanel.calculate_derived_stats()
    print("[CombatDebugPanel] Synced from player")
end

function CombatDebugPanel.apply_to_player()
    -- Apply changes to player - implemented per-tab
end

--===========================================================================
-- STATS TAB FUNCTIONS
--===========================================================================
function CombatDebugPanel.calculate_derived_stats()
    -- Get core stat values
    local physique = state.core_stats[1].value
    local cunning = state.core_stats[2].value
    local spirit = state.core_stats[3].value

    -- Calculate derived stats with formulas
    state.derived_stats = {
        -- From Physique
        {
            name = "Max Health",
            value = 100 + physique * 10 + spirit * 2,
            formula = "100 + (Phy × 10) + (Spr × 2)"
        },
        {
            name = "Health Regen",
            value = math.max(0, physique - 10) * 0.2,
            formula = "max(0, Phy - 10) × 0.2"
        },

        -- From Spirit
        {
            name = "Max Energy",
            value = spirit * 10,
            formula = "Spr × 10"
        },
        {
            name = "Energy Regen",
            value = spirit * 0.5,
            formula = "Spr × 0.5"
        },

        -- From Cunning
        {
            name = "Offensive Ability",
            value = cunning * 1,
            formula = "Cun × 1"
        },
        {
            name = "Physical Damage %",
            value = math.floor(cunning / 5) * 1,
            formula = "floor(Cun / 5) × 1"
        },

        -- Elemental from Spirit
        {
            name = "Fire Damage %",
            value = math.floor(spirit / 5) * 1,
            formula = "floor(Spr / 5) × 1"
        },
        {
            name = "Cold Damage %",
            value = math.floor(spirit / 5) * 1,
            formula = "floor(Spr / 5) × 1"
        },
        {
            name = "Lightning Damage %",
            value = math.floor(spirit / 5) * 1,
            formula = "floor(Spr / 5) × 1"
        },
    }
end

function CombatDebugPanel.apply_stats_to_player()
    if not PlayerStatsAccessor then return end

    -- Apply core stats
    for _, stat in ipairs(state.core_stats) do
        PlayerStatsAccessor.set_base(stat.name, stat.value)
    end

    -- Apply level
    local player = PlayerStatsAccessor.get_player()
    if player then
        player.level = state.player_level
        player.xp = state.player_xp
    end

    print("[CombatDebugPanel] Applied stats to player")
end

--===========================================================================
-- COMBAT TAB FUNCTIONS
--===========================================================================
function CombatDebugPanel.sync_combat_from_player()
    if not PlayerStatsAccessor then return end

    -- Sync offense stats (using correct stat names)
    state.offense_stats.weapon_min = PlayerStatsAccessor.get('weapon_min')
    state.offense_stats.weapon_max = PlayerStatsAccessor.get('weapon_max')
    state.offense_stats.attack_speed = PlayerStatsAccessor.get('attack_speed')
    state.offense_stats.crit_damage_pct = PlayerStatsAccessor.get('crit_damage_pct')
    state.offense_stats.all_damage_pct = PlayerStatsAccessor.get('all_damage_pct')
    state.offense_stats.life_steal_pct = PlayerStatsAccessor.get('life_steal_pct')

    -- Sync damage modifiers per type (using correct names)
    local damage_types = PlayerStatsAccessor.get_damage_types()
    state.damage_modifiers = {}
    for _, dtype in ipairs(damage_types) do
        state.damage_modifiers[dtype] = PlayerStatsAccessor.get(dtype .. '_modifier_pct')
    end

    -- Sync penetration
    state.penetration = { all = PlayerStatsAccessor.get('penetration_all_pct') }
    for _, dtype in ipairs(damage_types) do
        state.penetration[dtype] = PlayerStatsAccessor.get('penetration_' .. dtype .. '_pct')
    end

    -- Sync DoT durations (using correct suffix: _duration_pct not _duration_mult_pct)
    local dot_types = { 'bleed', 'trauma', 'burn', 'frostburn', 'electrocute', 'poison', 'vitality_decay' }
    state.dot_durations = {}
    for _, dot in ipairs(dot_types) do
        state.dot_durations[dot] = PlayerStatsAccessor.get(dot .. '_duration_pct')
    end

    print("[CombatDebugPanel] Synced combat from player")
end

function CombatDebugPanel.apply_combat_to_player()
    if not PlayerStatsAccessor then return end

    -- Apply offense stats
    PlayerStatsAccessor.set_base('weapon_min', state.offense_stats.weapon_min or 18)
    PlayerStatsAccessor.set_base('weapon_max', state.offense_stats.weapon_max or 25)
    PlayerStatsAccessor.set_base('attack_speed', state.offense_stats.attack_speed or 1.0)
    PlayerStatsAccessor.set_base('crit_damage_pct', state.offense_stats.crit_damage_pct or 50)
    PlayerStatsAccessor.set_base('all_damage_pct', state.offense_stats.all_damage_pct or 0)
    PlayerStatsAccessor.set_base('life_steal_pct', state.offense_stats.life_steal_pct or 0)

    -- Apply damage modifiers
    for dtype, value in pairs(state.damage_modifiers or {}) do
        PlayerStatsAccessor.set_base(dtype .. '_modifier_pct', value)
    end

    -- Apply penetration
    if state.penetration then
        PlayerStatsAccessor.set_base('penetration_all_pct', state.penetration.all or 0)
        for dtype, value in pairs(state.penetration) do
            if dtype ~= 'all' then
                PlayerStatsAccessor.set_base('penetration_' .. dtype .. '_pct', value)
            end
        end
    end

    -- Apply DoT durations
    for dot, value in pairs(state.dot_durations or {}) do
        PlayerStatsAccessor.set_base(dot .. '_duration_pct', value)
    end

    print("[CombatDebugPanel] Applied combat to player")
end

--===========================================================================
-- RELICS TAB FUNCTIONS
--===========================================================================
function CombatDebugPanel.sync_relics_from_player()
    if not globals then return end

    state.gold = globals.currency or 0

    state.owned_relics = {}
    if globals.ownedRelics then
        for _, relic in ipairs(globals.ownedRelics) do
            table.insert(state.owned_relics, relic.id or relic)
        end
    end

    print("[Combat] Synced relics from player")
end

function CombatDebugPanel.apply_relics_to_player()
    if not globals then return end

    globals.currency = state.gold

    -- Rebuild ownedRelics
    globals.ownedRelics = {}
    for _, relic_id in ipairs(state.owned_relics) do
        table.insert(globals.ownedRelics, { id = relic_id })
    end

    local ok, signal = pcall(require, "external.hump.signal")
    if ok then signal.emit("relics_changed") end

    print("[Combat] Applied relics to player")
end

--===========================================================================
-- DEFENSE TAB FUNCTIONS
--===========================================================================
function CombatDebugPanel.sync_defense_from_player()
    if not PlayerStatsAccessor then return end

    -- Core defense stats (using correct names)
    state.defense_stats.armor = PlayerStatsAccessor.get('armor')
    state.defense_stats.dodge_chance_pct = PlayerStatsAccessor.get('dodge_chance_pct')
    state.defense_stats.block_chance_pct = PlayerStatsAccessor.get('block_chance_pct')
    state.defense_stats.block_amount = PlayerStatsAccessor.get('block_amount')
    state.defense_stats.block_recovery_reduction_pct = PlayerStatsAccessor.get('block_recovery_reduction_pct')

    -- Resistances (correct suffix: _resist_pct)
    local damage_types = PlayerStatsAccessor.get_damage_types()
    state.resistances = {}
    for _, dtype in ipairs(damage_types) do
        state.resistances[dtype] = PlayerStatsAccessor.get(dtype .. '_resist_pct')
    end

    -- Resist caps
    state.resist_caps = {}
    for _, dtype in ipairs(damage_types) do
        local cap = 80 + PlayerStatsAccessor.get('max_' .. dtype .. '_resist_cap_pct')
        state.resist_caps[dtype] = math.min(100, cap)
    end

    -- Absorb
    state.absorb.percent = PlayerStatsAccessor.get('percent_absorb_pct')
    state.absorb.flat = PlayerStatsAccessor.get('flat_absorb')

    print("[CombatDebugPanel] Synced defense from player")
end

function CombatDebugPanel.apply_defense_to_player()
    if not PlayerStatsAccessor then return end

    -- Core defense stats
    PlayerStatsAccessor.set_base('armor', state.defense_stats.armor)
    PlayerStatsAccessor.set_base('dodge_chance_pct', state.defense_stats.dodge_chance_pct)
    PlayerStatsAccessor.set_base('block_chance_pct', state.defense_stats.block_chance_pct)
    PlayerStatsAccessor.set_base('block_amount', state.defense_stats.block_amount)
    PlayerStatsAccessor.set_base('block_recovery_reduction_pct', state.defense_stats.block_recovery_reduction_pct)

    -- Resistances
    for dtype, value in pairs(state.resistances) do
        PlayerStatsAccessor.set_base(dtype .. '_resist_pct', value)
    end

    -- Absorb
    PlayerStatsAccessor.set_base('percent_absorb_pct', state.absorb.percent or 0)
    PlayerStatsAccessor.set_base('flat_absorb', state.absorb.flat or 0)

    print("[CombatDebugPanel] Applied defense to player")
end

--===========================================================================
-- JOKERS TAB FUNCTIONS
--===========================================================================
function CombatDebugPanel.sync_jokers_from_player()
    if not JokerSystem then return end

    state.active_jokers = {}
    for _, joker in ipairs(JokerSystem.jokers) do
        table.insert(state.active_jokers, joker.id)
    end

    print("[Combat] Synced jokers from player")
end

function CombatDebugPanel.apply_jokers_to_player()
    if not JokerSystem then return end

    -- Clear and rebuild joker list
    JokerSystem.clear_jokers()

    for _, joker_id in ipairs(state.active_jokers) do
        JokerSystem.add_joker(joker_id)
    end

    print("[Combat] Applied jokers to player")
end

function CombatDebugPanel.fire_test_joker_event(event_type)
    local results = {}
    local jokers_data = require("data.jokers")

    -- Build mock context
    local context = {
        event = event_type,
        tags = { Fire = true, Ice = true },
        spell_type = "Mono-Element",
        player = { tag_counts = { Fire = 3, Ice = 2 } }
    }

    -- Fire event on each active joker
    for _, joker_id in ipairs(state.active_jokers) do
        local joker = jokers_data[joker_id]
        if joker and joker.calculate then
            local ok, effect = pcall(joker.calculate, joker, context)
            if ok and effect then
                table.insert(results, {
                    joker = joker.name or joker_id,
                    message = effect.message or "effect returned",
                    effect = effect
                })
            end
        end
    end

    if #results == 0 then
        table.insert(results, { joker = "(none)", message = "No jokers triggered" })
    end

    return results
end

--===========================================================================
-- TAGS TAB FUNCTIONS
--===========================================================================
function CombatDebugPanel.sync_tags_from_player()
    if globals and globals.player_state and globals.player_state.tag_counts then
        state.tag_counts = {}
        for tag, count in pairs(globals.player_state.tag_counts) do
            state.tag_counts[tag] = count
        end
    end
    CombatDebugPanel.recalculate_tag_bonuses()
    print("[Combat] Synced tags from player")
end

function CombatDebugPanel.apply_tags_to_player()
    if globals and globals.player_state then
        globals.player_state.tag_counts = {}
        for tag, count in pairs(state.tag_counts) do
            if count > 0 then
                globals.player_state.tag_counts[tag] = count
            end
        end
    end

    local ok, signal = pcall(require, "external.hump.signal")
    if ok then signal.emit("stats_recomputed") end

    print("[Combat] Applied tags to player")
end

function CombatDebugPanel.recalculate_tag_bonuses()
    state.active_bonuses = {}
    state.active_procs = {}

    -- Get breakpoint definitions from TagEvaluator if available
    local breakpoint_defs = nil
    if TagEvaluator and TagEvaluator.get_breakpoints then
        breakpoint_defs = TagEvaluator.get_breakpoints()
    end

    for tag, count in pairs(state.tag_counts) do
        if count >= 3 then
            -- Check each breakpoint
            for _, threshold in ipairs({ 3, 5, 7, 9 }) do
                if count >= threshold then
                    -- Look up bonus in breakpoint_defs if available
                    local desc = string.format("+%d%% %s bonus", threshold * 2, tag)
                    if breakpoint_defs and breakpoint_defs[tag] and breakpoint_defs[tag][threshold] then
                        local bp = breakpoint_defs[tag][threshold]
                        if bp.type == "stat" then
                            desc = string.format("+%d %s", bp.value, bp.stat)
                        elseif bp.type == "proc" then
                            table.insert(state.active_procs, { tag = tag, proc_id = bp.proc_id })
                            desc = "Proc: " .. bp.proc_id
                        end
                    end
                    table.insert(state.active_bonuses, {
                        tag = tag,
                        threshold = threshold,
                        description = desc
                    })
                end
            end
        end
    end
end

--===========================================================================
-- STATUS TAB FUNCTIONS
--===========================================================================
function CombatDebugPanel.sync_status_from_player()
    if not globals then return end

    local ps = globals.player_state
    if ps then
        state.current_hp = ps.health or ps.current_hp or 100
        state.max_hp = ps.max_health or ps.max_hp or 100
        state.current_energy = ps.energy or ps.current_energy or 50
        state.max_energy = ps.max_energy or 100

        state.active_buffs = ps.buffs and {} or {}  -- Copy if exists
        state.active_debuffs = ps.debuffs and {} or {}
        state.active_dots = ps.dots and {} or {}
    end

    print("[Combat] Synced status from player")
end

function CombatDebugPanel.apply_status_to_player()
    if not globals then return end

    local ps = globals.player_state
    if ps then
        ps.health = state.current_hp
        ps.max_health = state.max_hp
        ps.energy = state.current_energy
        ps.max_energy = state.max_energy

        ps.buffs = state.active_buffs
        ps.debuffs = state.active_debuffs
        ps.dots = state.active_dots
    end

    print("[Combat] Applied status to player")
end

--===========================================================================
-- WAND TAB FUNCTIONS
--===========================================================================
function CombatDebugPanel.sync_deck_from_player()
    state.deck_cards = {}

    -- Try to get player cards from various sources
    local player_cards = nil
    if globals and globals.playerTarget and globals.playerTarget.cards then
        player_cards = globals.playerTarget.cards
    elseif globals and globals.player and globals.player.cards then
        player_cards = globals.player.cards
    end

    if player_cards then
        local ok, Cards = pcall(require, "data.cards")
        for _, card in ipairs(player_cards) do
            local card_id = card.cardID or card.id or card
            local def = ok and Cards[card_id]
            table.insert(state.deck_cards, {
                id = card_id,
                type = def and def.type or "action",
                mana_cost = def and def.mana_cost or 0,
                damage = def and def.damage or 0,
                tags = def and def.tags or {},
            })
        end
    end

    print("[Combat] Synced deck from player: " .. #state.deck_cards .. " cards")
end

function CombatDebugPanel.apply_deck_to_player()
    local player = globals and (globals.playerTarget or globals.player)
    if not player then
        print("[Combat] No player found")
        return
    end

    player.cards = {}
    for _, card in ipairs(state.deck_cards) do
        table.insert(player.cards, { cardID = card.id, id = card.id })
    end

    -- Emit deck changed signal
    local ok, signal = pcall(require, "external.hump.signal")
    if ok then signal.emit("deck_changed", { source = "debug_panel" }) end

    print("[Combat] Applied deck to player: " .. #state.deck_cards .. " cards")
end

function CombatDebugPanel.load_deck_preset(preset_name)
    state.deck_cards = {}

    local ok, Cards = pcall(require, "data.cards")
    if not ok then return end

    local preset_cards = {}

    if preset_name == "starter" then
        -- Balanced starter deck
        preset_cards = { "SPARK", "SPARK", "SPARK", "FROST_BOLT", "HEAL_MINOR" }
    elseif preset_name == "fire" then
        -- Fire-focused
        for card_id, card in pairs(Cards) do
            if type(card) == "table" and card.tags then
                for _, tag in ipairs(card.tags) do
                    if tag == "Fire" then
                        table.insert(preset_cards, card_id)
                        break
                    end
                end
            end
        end
    elseif preset_name == "damage" then
        -- High damage cards
        local damage_cards = {}
        for card_id, card in pairs(Cards) do
            if type(card) == "table" and (card.damage or 0) > 20 then
                table.insert(damage_cards, { id = card_id, damage = card.damage })
            end
        end
        table.sort(damage_cards, function(a, b) return a.damage > b.damage end)
        for i = 1, math.min(10, #damage_cards) do
            table.insert(preset_cards, damage_cards[i].id)
        end
    end

    -- Build deck from preset
    for _, card_id in ipairs(preset_cards) do
        local def = Cards[card_id]
        if def then
            table.insert(state.deck_cards, {
                id = card_id,
                type = def.type or "action",
                mana_cost = def.mana_cost or 0,
                damage = def.damage or 0,
                tags = def.tags or {},
            })
        end
    end

    print("[Combat] Loaded preset: " .. preset_name .. " (" .. #state.deck_cards .. " cards)")
end

--===========================================================================
-- TAB RENDERING
--===========================================================================
local function render_stats_tab()
    if not ImGui then return end

    -- Sync/Apply buttons
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

    -- Core stat sliders with +/- buttons
    local any_changed = false
    for _, stat in ipairs(state.core_stats) do
        ImGui.PushID("core_" .. stat.name)

        local new_value, changed = ImGui.SliderInt(stat.display, stat.value, stat.min, stat.max)
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

    if any_changed then
        CombatDebugPanel.calculate_derived_stats()
    end

    -- Show formulas checkbox
    ImGui.Separator()
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

    -- Level/XP controls
    ImGui.Separator()
    ImGui.Text("LEVEL / XP")
    ImGui.Separator()

    ImGui.Text(string.format("  Level: %d", state.player_level))
    ImGui.SameLine()
    if ImGui.SmallButton("+Level") then
        state.player_level = state.player_level + 1
    end

    state.player_xp, _ = ImGui.InputInt("XP", state.player_xp)

    -- Presets
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

local function render_combat_tab()
    if not ImGui then return end

    -- Sync/Apply buttons
    if ImGui.Button("Sync from Player") then
        CombatDebugPanel.sync_combat_from_player()
    end
    ImGui.SameLine()
    if ImGui.Button("Apply to Player") then
        CombatDebugPanel.apply_combat_to_player()
    end

    ImGui.Separator()

    -- SECTION A: Offense Stats
    ImGui.Text("OFFENSE")
    ImGui.Separator()

    local off = state.offense_stats

    off.base_damage, _ = ImGui.SliderInt("Base Damage", off.base_damage, 0, 100)
    off.attack_speed, _ = ImGui.SliderFloat("Attack Speed", off.attack_speed, 0.1, 3.0, "%.2f")
    off.crit_chance, _ = ImGui.SliderInt("Crit Chance %", off.crit_chance, 0, 100)
    off.crit_damage, _ = ImGui.SliderInt("Crit Damage %", off.crit_damage, 100, 500)

    ImGui.Separator()

    -- SECTION B: Damage Modifiers
    ImGui.Text("DAMAGE MODIFIERS (% bonus)")
    ImGui.Separator()

    local damage_types = { "physical", "pierce", "fire", "cold", "lightning", "acid", "vitality", "aether", "chaos", "poison" }

    -- Display in columns for better layout
    ImGui.Columns(3, "dmg_mod_cols", false)
    for _, dtype in ipairs(damage_types) do
        ImGui.PushID("dmg_" .. dtype)
        local val = state.damage_modifiers[dtype] or 0
        ImGui.SetNextItemWidth(80)
        local new_val, c = ImGui.InputInt(dtype:sub(1,1):upper() .. dtype:sub(2), val)
        if c then
            state.damage_modifiers[dtype] = math.max(-100, math.min(200, new_val))
        end
        ImGui.PopID()
        ImGui.NextColumn()
    end
    ImGui.Columns(1)

    ImGui.Separator()

    -- SECTION C: DoT Durations
    ImGui.Text("DOT DURATION MULTIPLIERS")
    ImGui.Separator()

    local dot_types = { "bleed", "trauma", "burn", "frostburn", "electrocute", "poison", "vitality_decay" }
    for _, dot in ipairs(dot_types) do
        ImGui.PushID("dot_" .. dot)
        local val = state.dot_durations[dot] or 1.0
        ImGui.SetNextItemWidth(120)
        local new_val, c = ImGui.SliderFloat(dot:sub(1,1):upper() .. dot:sub(2), val, 0.5, 3.0, "%.1fx")
        if c then state.dot_durations[dot] = new_val end
        ImGui.PopID()
    end

    ImGui.Separator()

    -- SECTION D: Penetration
    ImGui.Text("PENETRATION (% resist reduction)")
    ImGui.Separator()

    ImGui.Columns(3, "pen_cols", false)
    for _, dtype in ipairs(damage_types) do
        ImGui.PushID("pen_" .. dtype)
        local val = state.penetration[dtype] or 0
        ImGui.SetNextItemWidth(80)
        local new_val, c = ImGui.InputInt(dtype:sub(1,1):upper() .. dtype:sub(2), val)
        if c then
            state.penetration[dtype] = math.max(0, math.min(100, new_val))
        end
        ImGui.PopID()
        ImGui.NextColumn()
    end
    ImGui.Columns(1)
end

local function render_defense_tab()
    if not ImGui then return end

    -- Sync/Apply buttons
    if ImGui.Button("Sync from Player") then
        CombatDebugPanel.sync_defense_from_player()
    end
    ImGui.SameLine()
    if ImGui.Button("Apply to Player") then
        CombatDebugPanel.apply_defense_to_player()
    end

    ImGui.Separator()

    -- SECTION A: Core Defense
    ImGui.Text("CORE DEFENSE")
    ImGui.Separator()

    local def = state.defense_stats

    def.armor, _ = ImGui.SliderInt("Armor", def.armor, 0, 500)
    def.dodge_chance_pct, _ = ImGui.SliderInt("Dodge Chance %", def.dodge_chance_pct, 0, 75)
    def.block_chance_pct, _ = ImGui.SliderInt("Block Chance %", def.block_chance_pct, 0, 75)
    def.block_amount, _ = ImGui.SliderInt("Block Amount", def.block_amount, 0, 100)
    def.block_recovery_reduction_pct, _ = ImGui.SliderInt("Block Recovery Reduction %", def.block_recovery_reduction_pct, 0, 100)

    ImGui.Separator()

    -- SECTION B: Resistances with visual bars
    ImGui.Text("RESISTANCES")
    ImGui.Separator()

    local damage_types = { "physical", "pierce", "fire", "cold", "lightning", "acid", "vitality", "aether", "chaos", "poison" }

    for _, dtype in ipairs(damage_types) do
        ImGui.PushID("res_" .. dtype)

        local res = state.resistances[dtype] or 0
        local cap = state.resist_caps[dtype] or 80

        -- Label
        ImGui.Text(string.format("%-10s", dtype:sub(1,1):upper() .. dtype:sub(2)))
        ImGui.SameLine()

        -- Slider
        ImGui.SetNextItemWidth(100)
        local new_res, c = ImGui.SliderInt("##res", res, -50, cap)
        if c then state.resistances[dtype] = new_res end

        ImGui.SameLine()

        -- Visual bar showing cap (use ProgressBar)
        local bar_pct = math.max(0, (res + 50) / (cap + 50))  -- normalize -50 to cap into 0-1
        ImGui.ProgressBar(bar_pct, 80, 14, "")

        ImGui.SameLine()
        ImGui.TextDisabled(string.format("(cap %d%%)", cap))

        ImGui.PopID()
    end

    ImGui.Separator()

    -- SECTION C: Resist Caps (collapsible)
    if ImGui.CollapsingHeader("Resist Caps (Advanced)") then
        ImGui.Columns(3, "cap_cols", false)
        for _, dtype in ipairs(damage_types) do
            ImGui.PushID("cap_" .. dtype)
            local cap = state.resist_caps[dtype] or 80
            ImGui.SetNextItemWidth(60)
            local new_cap, c = ImGui.InputInt(dtype:sub(1,3), cap)
            if c then state.resist_caps[dtype] = math.max(50, math.min(100, new_cap)) end
            ImGui.PopID()
            ImGui.NextColumn()
        end
        ImGui.Columns(1)
    end

    ImGui.Separator()

    -- SECTION D: Absorb
    ImGui.Text("ABSORB")
    ImGui.Separator()

    local abs = state.absorb
    abs.amount, _ = ImGui.SliderInt("Absorb Amount", abs.amount, 0, 50)

    -- Remaining is display-only
    ImGui.Text(string.format("  Remaining: %d / %d", abs.remaining, abs.amount))

    if ImGui.SmallButton("Refill Absorb") then
        abs.remaining = abs.amount
    end
end

local function render_relics_tab()
    if not ImGui then return end

    -- Sync/Apply buttons
    if ImGui.Button("Sync from Player") then
        CombatDebugPanel.sync_relics_from_player()
    end
    ImGui.SameLine()
    if ImGui.Button("Apply to Player") then
        CombatDebugPanel.apply_relics_to_player()
    end

    ImGui.Separator()

    -- SECTION A: Economy
    ImGui.Text("ECONOMY")
    ImGui.Separator()

    ImGui.SetNextItemWidth(100)
    local new_gold, changed = ImGui.InputInt("Gold", state.gold)
    if changed then state.gold = math.max(0, new_gold) end

    ImGui.SameLine()
    if ImGui.SmallButton("+100") then state.gold = state.gold + 100 end
    ImGui.SameLine()
    if ImGui.SmallButton("+1000") then state.gold = state.gold + 1000 end
    ImGui.SameLine()
    if ImGui.SmallButton("Reset") then state.gold = 0 end

    ImGui.Separator()

    -- SECTION B: Owned Relics
    ImGui.Text(string.format("OWNED RELICS (%d)", #state.owned_relics))
    ImGui.Separator()

    if #state.owned_relics == 0 then
        ImGui.TextDisabled("  (none)")
    else
        ImGui.BeginChild("OwnedRelics", 0, 120, true)
        local to_remove = nil
        for i, relic_id in ipairs(state.owned_relics) do
            ImGui.PushID("owned_" .. i)

            -- Find def for description
            local desc = ""
            for _, avail in ipairs(state.available_relics) do
                if avail.id == relic_id and avail.def then
                    desc = avail.def.description or avail.def.name or ""
                    break
                end
            end

            ImGui.Text(relic_id)
            if desc ~= "" then
                ImGui.SameLine()
                ImGui.TextDisabled("- " .. desc:sub(1, 40))
            end

            ImGui.SameLine(ImGui.GetWindowWidth() - 60)
            if ImGui.SmallButton("Remove") then
                to_remove = i
            end

            ImGui.PopID()
        end
        ImGui.EndChild()

        -- Remove after iteration
        if to_remove then
            table.remove(state.owned_relics, to_remove)
        end
    end

    ImGui.Separator()

    -- SECTION C: Available Relics
    ImGui.Text("AVAILABLE RELICS")

    -- Filter
    ImGui.SetNextItemWidth(150)
    local filter_changed, new_filter = ImGui.InputText("Filter", state.relic_filter, 64)
    if filter_changed then state.relic_filter = new_filter end

    ImGui.Separator()

    ImGui.BeginChild("AvailableRelics", 0, 150, true)

    local filter_lower = state.relic_filter:lower()

    for _, relic in ipairs(state.available_relics) do
        -- Skip if already owned
        local is_owned = false
        for _, owned_id in ipairs(state.owned_relics) do
            if owned_id == relic.id then
                is_owned = true
                break
            end
        end

        if not is_owned then
            -- Apply filter
            local matches = filter_lower == "" or relic.id:lower():find(filter_lower, 1, true)

            if matches then
                ImGui.PushID("avail_" .. relic.id)

                if ImGui.SmallButton("Add") then
                    table.insert(state.owned_relics, relic.id)
                end
                ImGui.SameLine()
                ImGui.Text(relic.id)

                if relic.def and relic.def.description then
                    ImGui.SameLine()
                    ImGui.TextDisabled("- " .. relic.def.description:sub(1, 50))
                end

                ImGui.PopID()
            end
        end
    end

    ImGui.EndChild()
end

local RARITY_COLORS = {
    Common = { 0.8, 0.8, 0.8, 1 },
    Uncommon = { 0.2, 0.8, 0.2, 1 },
    Rare = { 0.2, 0.4, 1.0, 1 },
    Epic = { 0.8, 0.2, 0.8, 1 },
    Legendary = { 1.0, 0.8, 0.2, 1 },
}

local TEST_EVENTS = {
    "on_spell_cast", "calculate_damage", "on_hit", "on_kill",
    "on_player_attack", "on_low_health", "on_dash"
}

local function render_jokers_tab()
    if not ImGui then return end

    -- Sync/Apply buttons
    if ImGui.Button("Sync from Player") then
        CombatDebugPanel.sync_jokers_from_player()
    end
    ImGui.SameLine()
    if ImGui.Button("Apply to Player") then
        CombatDebugPanel.apply_jokers_to_player()
    end

    ImGui.Separator()

    -- SECTION A: Active Jokers
    ImGui.Text(string.format("ACTIVE JOKERS (%d)", #state.active_jokers))
    ImGui.Separator()

    if #state.active_jokers == 0 then
        ImGui.TextDisabled("  (none active)")
    else
        ImGui.BeginChild("ActiveJokers", 0, 100, true)
        local to_remove = nil
        for i, joker_id in ipairs(state.active_jokers) do
            ImGui.PushID("active_" .. i)

            -- Find joker def
            local joker = nil
            for _, j in ipairs(state.available_jokers) do
                if j.id == joker_id then joker = j break end
            end

            if joker then
                local color = RARITY_COLORS[joker.rarity] or RARITY_COLORS.Common
                ImGui.TextColored(color[1], color[2], color[3], color[4], joker.name)
                ImGui.SameLine()
                ImGui.TextDisabled("[" .. joker.rarity .. "]")
                ImGui.SameLine()
                if ImGui.SmallButton("Remove") then to_remove = i end
            else
                ImGui.Text(joker_id)
                ImGui.SameLine()
                if ImGui.SmallButton("Remove") then to_remove = i end
            end

            ImGui.PopID()
        end
        ImGui.EndChild()
        if to_remove then table.remove(state.active_jokers, to_remove) end
    end

    ImGui.Separator()

    -- SECTION B: Available Jokers
    ImGui.Text("AVAILABLE JOKERS")

    -- Filters
    ImGui.SetNextItemWidth(120)
    state.joker_filter = state.joker_filter or ""
    local _, new_filter = ImGui.InputText("Name", state.joker_filter, 64)
    state.joker_filter = new_filter

    ImGui.SameLine()
    ImGui.SetNextItemWidth(100)
    local rarities = { "All", "Common", "Uncommon", "Rare", "Epic", "Legendary" }
    state.joker_rarity_filter = state.joker_rarity_filter or "All"
    local current_idx = 1
    for i, r in ipairs(rarities) do
        if r == state.joker_rarity_filter then current_idx = i break end
    end
    local new_idx, changed = ImGui.Combo("Rarity", current_idx, rarities, #rarities)
    if changed then state.joker_rarity_filter = rarities[new_idx] end

    ImGui.BeginChild("AvailableJokers", 0, 120, true)
    for _, joker in ipairs(state.available_jokers) do
        -- Skip if active
        local is_active = false
        for _, aid in ipairs(state.active_jokers) do
            if aid == joker.id then is_active = true break end
        end

        if not is_active then
            -- Apply filters
            local matches_name = state.joker_filter == "" or joker.name:lower():find(state.joker_filter:lower(), 1, true)
            local matches_rarity = state.joker_rarity_filter == "All" or joker.rarity == state.joker_rarity_filter

            if matches_name and matches_rarity then
                ImGui.PushID("avail_" .. joker.id)
                if ImGui.SmallButton("Add") then
                    table.insert(state.active_jokers, joker.id)
                end
                ImGui.SameLine()
                local color = RARITY_COLORS[joker.rarity] or RARITY_COLORS.Common
                ImGui.TextColored(color[1], color[2], color[3], color[4], joker.name)
                ImGui.SameLine()
                ImGui.TextDisabled(joker.description:sub(1, 40))
                ImGui.PopID()
            end
        end
    end
    ImGui.EndChild()

    ImGui.Separator()

    -- SECTION C: Test Event
    ImGui.Text("TEST EVENT")
    ImGui.Separator()

    ImGui.SetNextItemWidth(150)
    state.test_event_type = state.test_event_type or TEST_EVENTS[1]
    local evt_idx = 1
    for i, e in ipairs(TEST_EVENTS) do
        if e == state.test_event_type then evt_idx = i break end
    end
    local new_evt_idx, evt_changed = ImGui.Combo("Event", evt_idx, TEST_EVENTS, #TEST_EVENTS)
    if evt_changed then state.test_event_type = TEST_EVENTS[new_evt_idx] end

    ImGui.SameLine()
    if ImGui.Button("Fire Test Event") then
        state.joker_test_result = CombatDebugPanel.fire_test_joker_event(state.test_event_type)
    end

    -- Display results
    if state.joker_test_result then
        ImGui.Separator()
        ImGui.Text("Results:")
        for _, result in ipairs(state.joker_test_result) do
            ImGui.Text(string.format("  %s: %s", result.joker, result.message or "triggered"))
        end
    end
end

local TAG_CATEGORIES = {
    { name = "Elements", color = { 0.4, 0.6, 1.0, 1 }, tags = { "Fire", "Ice", "Lightning", "Poison", "Arcane", "Holy", "Void" } },
    { name = "Mechanics", color = { 0.4, 0.8, 0.4, 1 }, tags = { "Projectile", "AoE", "Hazard", "Summon", "Buff", "Debuff" } },
    { name = "Playstyle", color = { 1.0, 0.7, 0.3, 1 }, tags = { "Mobility", "Defense", "Brute" } },
}

local BREAKPOINTS = { 3, 5, 7, 9 }

local function get_active_breakpoint(count)
    local active = 0
    for _, bp in ipairs(BREAKPOINTS) do
        if count >= bp then active = bp end
    end
    return active
end

local function render_tags_tab()
    if not ImGui then return end

    -- Sync/Apply buttons
    if ImGui.Button("Sync from Player") then
        CombatDebugPanel.sync_tags_from_player()
    end
    ImGui.SameLine()
    if ImGui.Button("Apply to Player") then
        CombatDebugPanel.apply_tags_to_player()
    end
    ImGui.SameLine()
    if ImGui.Button("Recalculate Bonuses") then
        CombatDebugPanel.recalculate_tag_bonuses()
    end

    ImGui.Separator()

    -- SECTION A: Tag Counts by Category
    ImGui.Text("TAG COUNTS")
    ImGui.Separator()

    for _, category in ipairs(TAG_CATEGORIES) do
        -- Category header with color
        ImGui.TextColored(category.color[1], category.color[2], category.color[3], 1, category.name)

        -- 2 columns for tags
        ImGui.Columns(2, "tag_cols_" .. category.name, false)

        for _, tag in ipairs(category.tags) do
            ImGui.PushID("tag_" .. tag)

            local count = state.tag_counts[tag] or 0
            local active_bp = get_active_breakpoint(count)

            -- Tag name
            ImGui.Text(tag)
            ImGui.SameLine()

            -- Count with +/- buttons
            if ImGui.SmallButton("-") and count > 0 then
                state.tag_counts[tag] = count - 1
                CombatDebugPanel.recalculate_tag_bonuses()
            end
            ImGui.SameLine()
            ImGui.Text(tostring(count))
            ImGui.SameLine()
            if ImGui.SmallButton("+") and count < 15 then
                state.tag_counts[tag] = count + 1
                CombatDebugPanel.recalculate_tag_bonuses()
            end

            -- Breakpoint indicator
            ImGui.SameLine()
            if active_bp > 0 then
                ImGui.TextColored(0.2, 1.0, 0.2, 1, string.format("[%d]", active_bp))
            else
                ImGui.TextDisabled("[ ]")
            end

            ImGui.PopID()
            ImGui.NextColumn()
        end

        ImGui.Columns(1)
        ImGui.Separator()
    end

    -- SECTION B: Active Bonuses
    ImGui.Text("ACTIVE BONUSES")
    ImGui.Separator()

    if #state.active_bonuses == 0 then
        ImGui.TextDisabled("  (none - need 3+ cards with same tag)")
    else
        for _, bonus in ipairs(state.active_bonuses) do
            ImGui.Text(string.format("  %s [%d]: %s", bonus.tag, bonus.threshold, bonus.description))
        end
    end

    ImGui.Separator()

    -- SECTION C: Active Procs
    ImGui.Text("ACTIVE PROCS")
    ImGui.Separator()

    if #state.active_procs == 0 then
        ImGui.TextDisabled("  (none)")
    else
        for _, proc in ipairs(state.active_procs) do
            ImGui.Text(string.format("  %s: %s", proc.tag, proc.proc_id))
        end
    end
end

local function render_wand_tab()
    if not ImGui then return end

    -- Sync/Apply buttons
    if ImGui.Button("Sync from Player") then
        CombatDebugPanel.sync_deck_from_player()
    end
    ImGui.SameLine()
    if ImGui.Button("Apply to Player") then
        CombatDebugPanel.apply_deck_to_player()
    end
    ImGui.SameLine()
    if ImGui.Button("Clear Deck") then
        state.deck_cards = {}
    end

    ImGui.Separator()

    -- SECTION A: Deck Overview
    ImGui.Text("DECK OVERVIEW")
    ImGui.Separator()

    -- Count by type
    local action_count, modifier_count, trigger_count = 0, 0, 0
    local tag_counts = {}
    for _, card in ipairs(state.deck_cards) do
        if card.type == "action" then action_count = action_count + 1
        elseif card.type == "modifier" then modifier_count = modifier_count + 1
        elseif card.type == "trigger" then trigger_count = trigger_count + 1
        end
        for _, tag in ipairs(card.tags or {}) do
            tag_counts[tag] = (tag_counts[tag] or 0) + 1
        end
    end

    ImGui.Text(string.format("Total: %d cards", #state.deck_cards))
    ImGui.Text(string.format("  Actions: %d | Modifiers: %d | Triggers: %d",
        action_count, modifier_count, trigger_count))

    -- Tag summary (horizontal)
    local tag_strs = {}
    for tag, count in pairs(tag_counts) do
        table.insert(tag_strs, string.format("%s:%d", tag, count))
    end
    if #tag_strs > 0 then
        ImGui.TextDisabled("Tags: " .. table.concat(tag_strs, " "))
    end

    ImGui.Separator()

    -- SECTION B: Deck Editor
    ImGui.Text(string.format("DECK (%d cards)", #state.deck_cards))
    ImGui.Separator()

    ImGui.BeginChild("DeckEditor", 0, 180, true)

    local to_remove = nil
    local swap_up = nil
    local swap_down = nil

    for i, card in ipairs(state.deck_cards) do
        ImGui.PushID("deck_" .. i)

        -- Type badge
        local badge = "[" .. (card.type or "?"):sub(1,3):upper() .. "]"
        ImGui.TextDisabled(badge)
        ImGui.SameLine()

        -- Card name
        ImGui.Text(card.id)
        ImGui.SameLine()

        -- Mana/damage
        ImGui.TextDisabled(string.format("(%d mana", card.mana_cost or 0))
        if (card.damage or 0) > 0 then
            ImGui.SameLine()
            ImGui.TextDisabled(string.format(", %d dmg)", card.damage))
        else
            ImGui.SameLine()
            ImGui.TextDisabled(")")
        end

        -- Reorder buttons (right-aligned)
        ImGui.SameLine(ImGui.GetWindowWidth() - 90)
        if i > 1 then
            if ImGui.SmallButton("▲") then swap_up = i end
        else
            ImGui.TextDisabled(" ")
        end
        ImGui.SameLine()
        if i < #state.deck_cards then
            if ImGui.SmallButton("▼") then swap_down = i end
        else
            ImGui.TextDisabled(" ")
        end
        ImGui.SameLine()
        if ImGui.SmallButton("✕") then
            to_remove = i
        end

        ImGui.PopID()
    end

    ImGui.EndChild()

    -- Process operations after iteration
    if swap_up then
        state.deck_cards[swap_up], state.deck_cards[swap_up - 1] =
            state.deck_cards[swap_up - 1], state.deck_cards[swap_up]
    end
    if swap_down then
        state.deck_cards[swap_down], state.deck_cards[swap_down + 1] =
            state.deck_cards[swap_down + 1], state.deck_cards[swap_down]
    end
    if to_remove then
        table.remove(state.deck_cards, to_remove)
    end

    ImGui.Separator()

    -- SECTION C: Add Cards
    ImGui.Text("ADD CARDS")

    -- Filters
    state.deck_filter = state.deck_filter or ""
    ImGui.SetNextItemWidth(120)
    local _, new_filter = ImGui.InputText("Name", state.deck_filter, 64)
    state.deck_filter = new_filter

    ImGui.SameLine()
    state.deck_type_filter = state.deck_type_filter or "All"
    local types = { "All", "action", "modifier", "trigger" }
    local type_idx = 1
    for i, t in ipairs(types) do
        if t == state.deck_type_filter then type_idx = i break end
    end
    ImGui.SetNextItemWidth(80)
    local new_type_idx, type_changed = ImGui.Combo("Type", type_idx, types, #types)
    if type_changed then state.deck_type_filter = types[new_type_idx] end

    ImGui.BeginChild("AddCards", 0, 120, true)

    -- Load cards from data.cards
    local ok, Cards = pcall(require, "data.cards")
    if ok then
        local filter_lower = state.deck_filter:lower()
        for card_id, card in pairs(Cards) do
            if type(card) == "table" and card.id then
                -- Apply filters
                local matches_name = filter_lower == "" or card_id:lower():find(filter_lower, 1, true)
                local matches_type = state.deck_type_filter == "All" or card.type == state.deck_type_filter

                if matches_name and matches_type then
                    ImGui.PushID("add_" .. card_id)
                    if ImGui.SmallButton("+") then
                        table.insert(state.deck_cards, {
                            id = card.id,
                            type = card.type,
                            mana_cost = card.mana_cost or 0,
                            damage = card.damage or 0,
                            tags = card.tags or {},
                        })
                    end
                    ImGui.SameLine()
                    ImGui.TextDisabled("[" .. (card.type or "?"):sub(1,3):upper() .. "]")
                    ImGui.SameLine()
                    ImGui.Text(card.id)
                    ImGui.PopID()
                end
            end
        end
    end

    ImGui.EndChild()

    ImGui.Separator()

    -- SECTION D: Quick Presets
    ImGui.Text("PRESETS")

    if ImGui.Button("Starter Deck") then
        CombatDebugPanel.load_deck_preset("starter")
    end
    ImGui.SameLine()
    if ImGui.Button("Fire Build") then
        CombatDebugPanel.load_deck_preset("fire")
    end
    ImGui.SameLine()
    if ImGui.Button("Max Damage") then
        CombatDebugPanel.load_deck_preset("damage")
    end
end

-- Buff/Debuff/DoT type definitions
local BUFF_TYPES = {
    { id = "haste", name = "Haste", description = "+30% movement speed" },
    { id = "strength", name = "Strength", description = "+20% damage" },
    { id = "shield", name = "Shield", description = "Absorb 50 damage" },
    { id = "regeneration", name = "Regeneration", description = "+5 HP/sec" },
    { id = "focus", name = "Focus", description = "+15% crit chance" },
}

local DEBUFF_TYPES = {
    { id = "slow", name = "Slow", description = "-30% movement speed" },
    { id = "weaken", name = "Weaken", description = "-20% damage" },
    { id = "vulnerable", name = "Vulnerable", description = "+25% damage taken" },
    { id = "curse", name = "Curse", description = "-10% all stats" },
    { id = "blind", name = "Blind", description = "-50% accuracy" },
}

local DOT_TYPES = { "burn", "freeze", "shock", "poison", "bleed" }

local function render_status_tab()
    if not ImGui then return end

    -- Sync/Apply buttons
    if ImGui.Button("Sync from Player") then
        CombatDebugPanel.sync_status_from_player()
    end
    ImGui.SameLine()
    if ImGui.Button("Apply to Player") then
        CombatDebugPanel.apply_status_to_player()
    end

    ImGui.Separator()

    -- SECTION A: Health & Energy
    ImGui.Text("HEALTH & ENERGY")
    ImGui.Separator()

    -- HP bar
    local hp_pct = state.max_hp > 0 and (state.current_hp / state.max_hp) or 0
    ImGui.Text("HP:")
    ImGui.SameLine()
    ImGui.ProgressBar(hp_pct, 150, 16, string.format("%d / %d", state.current_hp, state.max_hp))
    ImGui.SameLine()
    ImGui.SetNextItemWidth(60)
    local new_hp, _ = ImGui.InputInt("##hp", state.current_hp)
    state.current_hp = math.max(0, math.min(state.max_hp, new_hp))
    ImGui.SameLine()
    ImGui.Text("/")
    ImGui.SameLine()
    ImGui.SetNextItemWidth(60)
    local new_max_hp, _ = ImGui.InputInt("##maxhp", state.max_hp)
    state.max_hp = math.max(1, new_max_hp)

    -- Energy bar
    local energy_pct = state.max_energy > 0 and (state.current_energy / state.max_energy) or 0
    ImGui.Text("Energy:")
    ImGui.SameLine()
    ImGui.ProgressBar(energy_pct, 150, 16, string.format("%d / %d", state.current_energy, state.max_energy))
    ImGui.SameLine()
    ImGui.SetNextItemWidth(60)
    local new_energy, _ = ImGui.InputInt("##energy", state.current_energy)
    state.current_energy = math.max(0, math.min(state.max_energy, new_energy))
    ImGui.SameLine()
    ImGui.Text("/")
    ImGui.SameLine()
    ImGui.SetNextItemWidth(60)
    local new_max_energy, _ = ImGui.InputInt("##maxenergy", state.max_energy)
    state.max_energy = math.max(1, new_max_energy)

    -- Quick buttons
    if ImGui.SmallButton("Full Heal") then
        state.current_hp = state.max_hp
        state.current_energy = state.max_energy
    end
    ImGui.SameLine()
    if ImGui.SmallButton("1 HP") then state.current_hp = 1 end
    ImGui.SameLine()
    if ImGui.SmallButton("+25 HP") then
        state.current_hp = math.min(state.max_hp, state.current_hp + 25)
    end
    ImGui.SameLine()
    if ImGui.SmallButton("-25 HP") then
        state.current_hp = math.max(0, state.current_hp - 25)
    end

    ImGui.Separator()

    -- SECTION B: Active Buffs
    ImGui.Text(string.format("BUFFS (%d)", #state.active_buffs))

    ImGui.SameLine(ImGui.GetWindowWidth() - 80)
    if ImGui.SmallButton("Clear Buffs") then
        state.active_buffs = {}
    end

    ImGui.Separator()

    -- Add buff dropdown
    state.selected_buff = state.selected_buff or 1
    local buff_names = {}
    for _, b in ipairs(BUFF_TYPES) do table.insert(buff_names, b.name) end
    ImGui.SetNextItemWidth(100)
    local new_buff, buff_changed = ImGui.Combo("##addbuff", state.selected_buff, buff_names, #buff_names)
    if buff_changed then state.selected_buff = new_buff end
    ImGui.SameLine()
    if ImGui.SmallButton("Add Buff") then
        local buff = BUFF_TYPES[state.selected_buff]
        table.insert(state.active_buffs, {
            type = buff.id,
            name = buff.name,
            duration = 10.0,
            description = buff.description
        })
    end

    -- List buffs
    if #state.active_buffs > 0 then
        local to_remove = nil
        for i, buff in ipairs(state.active_buffs) do
            ImGui.PushID("buff_" .. i)
            ImGui.Text(string.format("  %s (%.1fs) - %s", buff.name, buff.duration, buff.description))
            ImGui.SameLine()
            if ImGui.SmallButton("X") then to_remove = i end
            ImGui.PopID()
        end
        if to_remove then table.remove(state.active_buffs, to_remove) end
    else
        ImGui.TextDisabled("  (no active buffs)")
    end

    ImGui.Separator()

    -- SECTION C: Active Debuffs
    ImGui.Text(string.format("DEBUFFS (%d)", #state.active_debuffs))

    ImGui.SameLine(ImGui.GetWindowWidth() - 90)
    if ImGui.SmallButton("Clear Debuffs") then
        state.active_debuffs = {}
    end

    ImGui.Separator()

    -- Add debuff dropdown
    state.selected_debuff = state.selected_debuff or 1
    local debuff_names = {}
    for _, d in ipairs(DEBUFF_TYPES) do table.insert(debuff_names, d.name) end
    ImGui.SetNextItemWidth(100)
    local new_debuff, debuff_changed = ImGui.Combo("##adddebuff", state.selected_debuff, debuff_names, #debuff_names)
    if debuff_changed then state.selected_debuff = new_debuff end
    ImGui.SameLine()
    if ImGui.SmallButton("Add Debuff") then
        local debuff = DEBUFF_TYPES[state.selected_debuff]
        table.insert(state.active_debuffs, {
            type = debuff.id,
            name = debuff.name,
            duration = 5.0,
            description = debuff.description
        })
    end

    -- List debuffs
    if #state.active_debuffs > 0 then
        local to_remove = nil
        for i, debuff in ipairs(state.active_debuffs) do
            ImGui.PushID("debuff_" .. i)
            ImGui.Text(string.format("  %s (%.1fs) - %s", debuff.name, debuff.duration, debuff.description))
            ImGui.SameLine()
            if ImGui.SmallButton("X") then to_remove = i end
            ImGui.PopID()
        end
        if to_remove then table.remove(state.active_debuffs, to_remove) end
    else
        ImGui.TextDisabled("  (no active debuffs)")
    end

    ImGui.Separator()

    -- SECTION D: Active DoTs
    ImGui.Text(string.format("DOTS (%d)", #state.active_dots))

    ImGui.SameLine(ImGui.GetWindowWidth() - 80)
    if ImGui.SmallButton("Clear DoTs") then
        state.active_dots = {}
    end

    ImGui.Separator()

    -- Add DoT
    state.selected_dot = state.selected_dot or 1
    state.new_dot_dps = state.new_dot_dps or 10
    ImGui.SetNextItemWidth(80)
    local new_dot, dot_changed = ImGui.Combo("##adddot", state.selected_dot, DOT_TYPES, #DOT_TYPES)
    if dot_changed then state.selected_dot = new_dot end
    ImGui.SameLine()
    ImGui.SetNextItemWidth(50)
    local new_dps, _ = ImGui.InputInt("DPS##dotdps", state.new_dot_dps)
    state.new_dot_dps = math.max(1, new_dps)
    ImGui.SameLine()
    if ImGui.SmallButton("Add DoT") then
        table.insert(state.active_dots, {
            type = DOT_TYPES[state.selected_dot],
            dps = state.new_dot_dps,
            duration = 5.0,
            total_damage = 0
        })
    end

    -- List DoTs
    if #state.active_dots > 0 then
        local to_remove = nil
        for i, dot in ipairs(state.active_dots) do
            ImGui.PushID("dot_" .. i)
            ImGui.Text(string.format("  %s: %d DPS (%.1fs) [Total: %d]",
                dot.type:sub(1,1):upper() .. dot.type:sub(2),
                dot.dps, dot.duration, dot.total_damage))
            ImGui.SameLine()
            if ImGui.SmallButton("X") then to_remove = i end
            ImGui.PopID()
        end
        if to_remove then table.remove(state.active_dots, to_remove) end
    else
        ImGui.TextDisabled("  (no active DoTs)")
    end
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
