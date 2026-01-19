local Node = require("monobehavior.behavior_script_v2") -- the new monobehavior script

--[[
================================================================================
NOITA-STYLE WAND CASTING SYSTEM
================================================================================
This system simulates Noita's wand mechanics with:
- Trigger slots (wands) with configurable properties
- Action cards (projectiles with various behaviors)
- Modifier cards (damage boosts, multicasts, etc.)
- Always-cast mechanics
- Recursive cast blocks (timers/collision triggers)
- Weight-based overload penalties
================================================================================
]]

-- Set to true to enable verbose wand simulation output
local VERBOSE_WAND_SIM = false

-- Helper for conditional printing
local function vprint(...)
    if VERBOSE_WAND_SIM then
        print(...)
    end
end

-- testing out how noita wand-like eval order would work for cards.

-- trigger slots have:
-- 1. shuffle
-- 2. action cards per cast (cast block size)
-- 3. cast delay (time between spells within cast blocks)
-- 4. recharge time (time to recharge trigger after all cast blocks are done)
-- 5. number of cards total (a numerical slot limit)
-- 6. local mana maximum.
-- 7. local mana recharge rate.
-- 8. random projectile spread angle.
-- 9. "always cast" modifiers. Just an action card/modifier card that always gets included into each cast block.


-- individual cards have:
-- 1. Max use. May be infinite.
-- 2. Mana cost.
-- 3. Damage number and type.
-- 4. Radius of effect, if applicable.
-- 5. Random spread angle, determines accuracy.
-- 6. Speed of projectile, if applicable.
-- 7. Lifetime, how long the projectile will live.
-- 8. Cast delay, which is added to the wand's cast delay after this card is cast.
-- 9. Recharge time, which is added to the wand's total recharge time.
-- 10. Spread modifier, which is added to the wand's spread angle.
-- 11. Speed modifier, which is added to this card's projectile speed.
-- 12. Lifetime modifier, which is added to this card's lifetime.
-- 13. Critical hit chance modifier, if applicable.


-- types of cards:
-- 1. trigger cards (used for trigger slots or "wands")
-- 2. action cards (discrete actions, e.g. shoot projectile, heal, buff, debuff, etc). Some action cards will branch off and make additional cast blocks (e.g., arrow with trigger will trigger a new cast block after it upon collision, and arrow with timer will do the same thing, but after a set time). This will not extend the current cast block, but will rather run as a separate cast block, in parallel.
-- 3. modifier cards (modify other cards, e.g. increase damage, increase speed, add status effect, etc). Utility cards, multicast cards, etc. are all in this category, and they just differ in how many cards they modify. If they modify more than one, they will potentially extend the current cast block. Along with action cards that branch off, these can "wrap around" the trigger slots if not enough cards are present to fill the cast block. Modifiers apply to the entire cast block, rather than just the next spell. If the next spell is a cast block (maybe it's a multicast, followed by actions), then the modifier applies to all spells in that cast block.

-- other implementation details to test:
-- 1. "always cast" cards that are always included in each cast block.
-- 2. card shuffling before each full rotation, if the trigger has shuffle enabled.
-- 3. handling of insufficient mana in the trigger's local mana pool.
-- 4. handling of max uses for cards.
-- 5. cast delay and recharge time from cards should add to the trigger's base cast delay and recharge time.



--------------------------------------------------------------------------------
-- CARD DEFINITIONS
--------------------------------------------------------------------------------

local CardRegistry = require("wand.card_registry")
local CardTemplates = CardRegistry.get_all_cards()



-- -------------------------------------------------------------------------- --
--             WAND-defining trigger cards that DON't GO IN WANDS             --
-- -------------------------------------------------------------------------- 

local TriggerCardTemplates = CardRegistry.get_all_trigger_cards()


--------------------------------------------------------------------------------
-- WAND (TRIGGER) DEFINITIONS
--------------------------------------------------------------------------------

local WandTemplates = {
    -- Wand with shuffle 
    {
        id = "TEST_WAND_1",
        type = "trigger",
        max_uses = -1,
        mana_max = 50,
        mana_recharge_rate = 5,
        cast_block_size = 2,
        cast_delay = 200,
        recharge_time = 1000,
        spread_angle = 10,
        shuffle = false,
        total_card_slots = 5,
        always_cast_cards = { },
        
    },

    -- Simple wand with no shuffle or always-cast
    {
        id = "TEST_WAND_2",
        type = "trigger",
        max_uses = -1,
        mana_max = 30,
        mana_recharge_rate = 10,
        cast_block_size = 1,
        cast_delay = 100,
        recharge_time = 500,
        spread_angle = 5,
        shuffle = false,
        total_card_slots = 10,
        always_cast_cards = {},
    },
    
    -- Wand with always-cast cards
    {
        id = "TEST_WAND_3",
        type = "trigger",
        max_uses = -1,
        mana_max = 60,
        mana_recharge_rate = 8,
        cast_block_size = 3,
        cast_delay = 150,
        recharge_time = 800,
        spread_angle = 15,
        shuffle = true,
        total_card_slots = 7,
        always_cast_cards = {
            "ACTION_BASIC_PROJECTILE"
        },
    },
    
    -- Wand with low mana and high overload potential
    {
        id = "TEST_WAND_4",
        type = "trigger",
        max_uses = -1,
        mana_max = 20,
        mana_recharge_rate = 4,
        cast_block_size = 2,
        cast_delay = 250,
        recharge_time = 1200,
        spread_angle = 20,
        shuffle = true,
        total_card_slots = 8,
        always_cast_cards = {
            "MOD_DAMAGE_UP",
            "ACTION_FAST_ACCURATE_PROJECTILE"
        },
    },

    --------------------------------------------------------------------------------
    -- PHASE 2 DEMO: Findable Wand Templates
    --------------------------------------------------------------------------------

    -- RAGE FIST: Timer-based aggressive wand
    -- Automatically fires every few seconds, rewards aggressive play
    {
        id = "RAGE_FIST",
        name = "Rage Fist",
        type = "trigger",
        trigger_type = "every_N_seconds",
        trigger_interval = 2.0,  -- Fires every 2 seconds
        max_uses = -1,
        mana_max = 40,
        mana_recharge_rate = 8,
        cast_block_size = 1,
        cast_delay = 100,
        recharge_time = 400,
        spread_angle = 5,
        shuffle = false,
        total_card_slots = 4,
        always_cast_cards = {},  -- Player fills with their own cards
        description = "Automatically fires every 2 seconds. Channel your rage!",
    },

    -- STORM WALKER: Bump-triggered wand
    -- Fires when colliding with enemies, rewards melee playstyle
    {
        id = "STORM_WALKER",
        name = "Storm Walker",
        type = "trigger",
        trigger_type = "on_bump_enemy",
        max_uses = -1,
        mana_max = 35,
        mana_recharge_rate = 12,
        cast_block_size = 2,
        cast_delay = 50,
        recharge_time = 300,
        spread_angle = 15,
        shuffle = false,
        total_card_slots = 5,
        always_cast_cards = {
            "ACTION_CHAIN_LIGHTNING"  -- Lightning theme
        },
        description = "Triggers when you bump into enemies. Walk the storm!",
    },

    -- FROST ANCHOR: Stand-still triggered wand
    -- Fires when player stands still, rewards defensive/positioning play
    {
        id = "FROST_ANCHOR",
        name = "Frost Anchor",
        type = "trigger",
        trigger_type = "on_stand_still",
        trigger_idle_threshold = 1.5,  -- 1.5 seconds of standing still
        max_uses = -1,
        mana_max = 60,
        mana_recharge_rate = 6,
        cast_block_size = 3,
        cast_delay = 200,
        recharge_time = 800,
        spread_angle = 20,
        shuffle = true,
        total_card_slots = 6,
        always_cast_cards = {
            "ACTION_SLOW_ORB"  -- Ice/slow theme
        },
        description = "Triggers when you stand still. Plant your feet and unleash ice!",
    },

    -- SOUL SIPHON: Kill-triggered wand
    -- Fires when killing enemies, rewards aggressive clearing
    {
        id = "SOUL_SIPHON",
        name = "Soul Siphon",
        type = "trigger",
        trigger_type = "enemy_killed",
        max_uses = -1,
        mana_max = 50,
        mana_recharge_rate = 5,
        cast_block_size = 1,
        cast_delay = 100,
        recharge_time = 200,
        spread_angle = 10,
        shuffle = false,
        total_card_slots = 4,
        always_cast_cards = {},  -- Player fills, rewards builds
        description = "Triggers when you kill an enemy. Harvest their souls!",
    },

    -- PAIN ECHO: Distance-traveled triggered wand
    -- Fires after moving a certain distance, rewards mobile playstyle
    {
        id = "PAIN_ECHO",
        name = "Pain Echo",
        type = "trigger",
        trigger_type = "on_distance_traveled",
        trigger_distance = 150,  -- Fires every 150 pixels traveled
        max_uses = -1,
        mana_max = 30,
        mana_recharge_rate = 10,
        cast_block_size = 1,
        cast_delay = 50,
        recharge_time = 100,
        spread_angle = 5,
        shuffle = false,
        total_card_slots = 3,
        always_cast_cards = {},  -- Player fills
        description = "Triggers as you move. Every step echoes with power!",
    },

    -- EMBER PULSE: Timer + AoE themed wand
    -- Fires periodically with fire/AoE focus
    {
        id = "EMBER_PULSE",
        name = "Ember Pulse",
        type = "trigger",
        trigger_type = "every_N_seconds",
        trigger_interval = 3.0,  -- Fires every 3 seconds
        max_uses = -1,
        mana_max = 70,
        mana_recharge_rate = 7,
        cast_block_size = 2,
        cast_delay = 150,
        recharge_time = 600,
        spread_angle = 30,  -- Wide spread for AoE feel
        shuffle = true,
        total_card_slots = 6,
        always_cast_cards = {
            "ACTION_EXPLOSIVE_FIRE_PROJECTILE"  -- Fire AoE theme
        },
        description = "Pulses fire every 3 seconds. Burn everything nearby!",
    },
}

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

--- Copies card properties from a template to an object
--- @param obj table Destination object
--- @param card_table table Card template
--- @param card_type string|nil Optional type filter
--- @return table The modified object
local function apply_card_properties(obj, card_table, card_type)
    if card_type and card_table.type ~= card_type then
        return obj
    end

    for k, v in pairs(card_table) do
        if k ~= "id" and k ~= "handle" then
            local vtype = type(v)
            if vtype == "number" or vtype == "boolean" or vtype == "string" or vtype == "table" then
                if obj[k] == nil then
                    obj[k] = v
                end
            end
        end
    end

    if not obj.card_id then
        obj.card_id = card_table.id
    end
    if (not obj.cardID or obj.cardID == "unknown") and card_table.id then
        obj.cardID = card_table.id
    end

    return obj
end

--- Creates a card instance from a template
--- @param template table Card template
--- @return table Card instance
local function create_card_from_template(template)
    local card = Node {}
    card:attach_ecs { create_new = true }
    apply_card_properties(card, template)
    return card
end

--- Returns a human-readable card identifier
--- @param card table Card instance
--- @return string Formatted card ID
local function readable_card_id(card)
    return card.card_id .. ":" .. card:handle()
end


--- Copies all key–value pairs from a card definition table into an object.
--- Optionally filters by card type (e.g. "action", "modifier", "trigger").
--- Does not overwrite existing keys on the target unless they are nil.
---
--- @param obj table  The destination object (e.g., a Lua entity or component)
--- @param card_table table  The card definition table (e.g., TEST_PROJECTILE)
--- @param card_type string|nil  Optional. Only apply if card_table.type matches.
--- @return table obj  The same object, now enriched with card properties.
function apply_card_properties(obj, card_table, card_type)
    -- Skip if the card has a type mismatch (when filter is specified)
    if card_type and card_table.type ~= card_type then
        return obj
    end

    -- Copy all numeric, boolean, and string fields
    for k, v in pairs(card_table) do
        -- Avoid copying reserved/meta keys
        if k ~= "id" and k ~= "handle" then
            -- Only copy plain values (avoid functions/metatables)
            local vtype = type(v)
            if vtype == "number" or vtype == "boolean" or vtype == "string" or vtype == "table" then
                if obj[k] == nil then
                    obj[k] = v
                end
            end
        end
    end

    -- Optionally tag it with the card id
    if not obj.card_id then
        obj.card_id = card_table.id
    end
    if (not obj.cardID or obj.cardID == "unknown") and card_table.id then
        obj.cardID = card_table.id
    end

    return obj
end

-- Simulate Noita-like cast block division, with trigger/timer behavior

--==============================================================
-- [OK] simulate_wand (modifier inheritance + global modifier persistence)
--==============================================================
local function simulate_wand(wand, card_pool)
    vprint("\n=== Simulating " .. wand.id .. " ===")
    
    -- Track execution status of every card
    local card_execution = {}   -- card object -> "unused" | "partial" | "full"

    -- Initialize all cards to unused
    for _, card in ipairs(card_pool) do
        card_execution[card:handle()] = "unused"
    end

    ----------------------------------------------------------------------
    -- [+] Step 1. Build Card Lookup
    ----------------------------------------------------------------------
    local card_lookup = {}
    for _, card in ipairs(card_pool) do
        
        card_lookup[card.card_id] = card
    end

    ----------------------------------------------------------------------
    -- [+] Step 2. Build Deck (store card tables directly)
    ----------------------------------------------------------------------
    local deck = {}
    local max_cards = math.min(wand.total_card_slots, #card_pool)

    for i = 1, max_cards do
        table.insert(deck, card_pool[i])
    end

    -- Shuffle deck if wand has shuffle flag
    if wand.shuffle then
        math.randomseed(os.time())
        for i = #deck, 2, -1 do
            local j = math.random(i)
            deck[i], deck[j] = deck[j], deck[i]
        end
    end

    -- Print deck summary
    vprint("Deck: {")
    for _, card in ipairs(deck) do
        vprint(string.format("  %s:%s", card.card_id, card:handle()))
    end
        vprint("}")
        vprint(string.rep("-", 60))

    ----------------------------------------------------------------------
    -- [+] Step 3. Calculate Weight / Overload
    ----------------------------------------------------------------------
    local total_weight = 0
    for _, card in ipairs(deck) do
        total_weight = total_weight + (card.weight or 1)
    end

    local overload_ratio = 1.0
    if wand.mana_max and total_weight > wand.mana_max then
        local excess = total_weight - wand.mana_max
        overload_ratio = 1.0 + (excess / wand.mana_max) * 0.5

        vprint(string.format(
            "[!] Wand overloaded: weight %.1f / %.1f > +%.0f%% cast/recharge delay",
            total_weight, wand.mana_max, (overload_ratio - 1.0) * 100
        ))
    else
        vprint(string.format(
            "[OK] Wand within weight limit: weight %.1f / %.1f",
            total_weight, wand.mana_max or total_weight
        ))
    end

        vprint(string.rep("-", 60))

    ----------------------------------------------------------------------
    -- [+] Step 4. Utility Functions
    ----------------------------------------------------------------------
    local function readable_card_id(card)
        return string.format("%s:%s", card.card_id, card:handle())
    end

    ----------------------------------------------------------------------
    -- [+] Step 5. Global Modifier Setup
    ----------------------------------------------------------------------
    local global_active_modifiers = {}

    -- [MODS] Initialize global always-cast modifiers once per wand
    local global_always_modifiers = {}
    if wand.always_cast_cards and #wand.always_cast_cards > 0 then
        for _, always_id in ipairs(wand.always_cast_cards) do
            local always_card = card_lookup[always_id]
            if always_card then
                local mod = {
                    card = always_card,
                    remaining = always_card.multicast_count or 1,
                    persistent_until_chain_end = true,
                }

        vprint(string.format("  [+] [ALWAYS CAST INIT] '%s' x%d", always_id, mod.remaining))
                table.insert(global_always_modifiers, mod)
            else
        vprint(string.format("  [!] Missing always-cast card '%s'", always_id))
            end
        end
    end

    ----------------------------------------------------------------------
    -- Helper: deep copy modifiers (used for inheritance)
    ----------------------------------------------------------------------
    local function copy_modifiers(source)
        local result = {}
        for _, m in ipairs(source or {}) do
            table.insert(result, {
                card = m.card,
                remaining = m.remaining,
                persistent_until_chain_end = m.persistent_until_chain_end or false
            })
        end
        return result
    end


    ----------------------------------------------------------------------
    -- Helper: merge inherited + global modifiers
    ----------------------------------------------------------------------
    local function merge_modifiers(inherited_modifiers)
        local merged = copy_modifiers(inherited_modifiers)

        for _, m in ipairs(global_active_modifiers) do
            table.insert(merged, { card = m.card, remaining = m.remaining })
        end
        return merged
    end


    ----------------------------------------------------------------------
    -- Helper: apply modifiers after an action executes
    ----------------------------------------------------------------------
    local function apply_modifiers(indent, modifiers, card)
        for j = #modifiers, 1, -1 do
            local m = modifiers[j]
        vprint(string.format("%s     |-> under modifier '%s' (%d left)",
                indent, readable_card_id(m.card), m.remaining - 1))

            m.remaining = m.remaining - 1
            if m.remaining <= 0 then
        vprint(string.format("%s     [-] [MOD EXHAUSTED] '%s' (persists=%s)",
                    indent, readable_card_id(m.card),
                    tostring(m.persistent_until_chain_end)))
                if not m.persistent_until_chain_end then
                    table.remove(modifiers, j)
                end
            end
        end
    end


    ----------------------------------------------------------------------
    -- Helper: spawn sub-cast (timer or trigger)
    ----------------------------------------------------------------------
    local function spawn_sub_cast(i, depth, indent, trigger_card, modifiers, visited_cards)
        -- Trigger cards that spawn a sub-cast are considered "partial" unless executed later.
        if card_execution[trigger_card:handle()] == "unused" then
            card_execution[trigger_card:handle()] = "partial"
        end

        local label = trigger_card.timer_ms
            and string.format("+%dms timer", trigger_card.timer_ms)
            or "on collision"

        vprint(string.format("%s     |-> Spawning sub-cast (%s)", indent, label))
        vprint(string.format("%s     └─── [RECURSION TREE] Enter sub-cast (Depth %d -> %d)",
            indent, depth, depth + 1))

        -- Inherit modifiers (minus global duplicates)
        local inherited_copy = copy_modifiers(modifiers)
        for _, m in ipairs(global_always_modifiers) do
            for idx = #inherited_copy, 1, -1 do
                if inherited_copy[idx].card == m.card then
                    table.remove(inherited_copy, idx)
                    break
                end
            end
        end

        -- Recurse
        local sub_block, new_i = build_cast_block(i, depth + 1, inherited_copy, visited_cards, 1, true)
        vprint(string.format("%s     └─── [RECURSION TREE] Exit sub-cast (Back to Depth %d)", indent, depth))
        vprint(string.format("%s     [END] Ending block after trigger '%s' (no further actions in this block)",
            indent, readable_card_id(trigger_card)))

        return sub_block, new_i
    end


    ----------------------------------------------------------------------
    -- Helper: handle always-cast cards (run before deck)
    ----------------------------------------------------------------------
    local function handle_always_casts(indent, depth, block, modifiers, visited_cards, i, target_actions)
        if not wand.always_cast_cards or #wand.always_cast_cards == 0 then
            return i, target_actions
        end

        vprint(string.format("%s  [-] [ALWAYS CAST EXEC] running %d always-cast cards at start",
            indent, #wand.always_cast_cards))

        for _, always_id in ipairs(wand.always_cast_cards) do
            local acard = card_lookup[always_id]
            if not acard then
        vprint(string.format("%s    [!] Missing always-cast card '%s'", indent, always_id))
                goto continue
            end

        vprint(string.format("%s    * Executing always-cast '%s'", indent, readable_card_id(acard)))

            if acard.type == "modifier" then
                -- Modifier adds multicast
                local mod = {
                    card = acard,
                    remaining = acard.multicast_count or 1,
                    persistent_until_chain_end = true,
                }

        vprint(string.format("%s      [+] [ALWAYS MOD OPEN] '%s' x%d",
                    indent, readable_card_id(acard), mod.remaining))

                table.insert(modifiers, mod)
                table.insert(block.applied_modifiers, { card = acard, remaining = mod.remaining })

                -- Expand target size if multicast
                if (acard.multicast_count or 1) > 1 then
                    local extra = (acard.multicast_count - 1)
                    target_actions = target_actions + extra
        vprint(string.format("%s     =>> Expanded block target to %d due to multicast (%+d)",
                        indent, target_actions, extra))
                end
            elseif acard.type == "action" then
        vprint(string.format("%s      [+] [ALWAYS ACTION] '%s'", indent, readable_card_id(acard)))
                table.insert(block.cards, acard)

                block.total_cast_delay = block.total_cast_delay + (acard.cast_delay or 0)
                block.total_recharge   = block.total_recharge + (acard.recharge_time or 0)

                apply_modifiers(indent, modifiers, acard)

                if (acard.timer_ms or acard.trigger_on_collision) then
                    local sub_block
                    sub_block, i = spawn_sub_cast(i, depth, indent, acard, modifiers, visited_cards)
                    table.insert(block.children, {
                        trigger = acard,
                        delay = acard.timer_ms,
                        collision = acard.trigger_on_collision,
                        block = sub_block,
                        recursion_depth = depth + 1,
                    })
                    break
                end
            end

            ::continue::
        end
        return i, target_actions
    end


    ----------------------------------------------------------------------
    -- Helper: process a single card during deck evaluation
    ----------------------------------------------------------------------
    local function process_card(indent, card, modifiers, block, depth, i, visited_cards, target_actions,
                                actions_collected)
        if card.type == "modifier" then
            -- Mark card as fully executed
            card_execution[card:handle()] = "full"
            
            local mod = {
                card = card,
                remaining = card.multicast_count or 1,
                persistent_until_chain_end = true,
            }

        vprint(string.format("%s  [+] [MOD OPEN] '%s' x%d",
                indent, readable_card_id(card), mod.remaining))

            table.insert(modifiers, mod)
            table.insert(block.applied_modifiers, { card = card, remaining = mod.remaining })

            if (card.multicast_count or 1) > 1 then
                local extra = (card.multicast_count - 1)
                target_actions = target_actions + extra
        vprint(string.format("%s     =>> Expanded block target to %d due to multicast (%+d)",
                    indent, target_actions, extra))
            end
        elseif card.type == "action" then
            -- Mark card as fully executed
            card_execution[card:handle()] = "full"
            
            actions_collected = actions_collected + 1
            table.insert(block.cards, card)
            
            -- Add cast delay BEFORE updating total
            local cardCastDelay = card.cast_delay or 0
            
            -- Record cumulative delay for this card
            table.insert(block.card_delays, {
                card = card,
                card_index = actions_collected,
                individual_delay = cardCastDelay,
                cumulative_delay = block.total_cast_delay + cardCastDelay,  -- Delay up to and including this card
            })
            
            block.total_cast_delay = block.total_cast_delay + cardCastDelay
            block.total_recharge   = block.total_recharge + (card.recharge_time or 0)

        vprint(string.format("%s  [+] Action '%s' (%d/%d actions filled)",
                indent, readable_card_id(card), actions_collected, target_actions))

            apply_modifiers(indent, modifiers, card)

            if (card.timer_ms or card.trigger_on_collision) then
                local sub_block
                sub_block, i = spawn_sub_cast(i, depth, indent, card, modifiers, visited_cards)
                table.insert(block.children, {
                    trigger = card,
                    delay = card.timer_ms,
                    collision = card.trigger_on_collision,
                    block = sub_block,
                    recursion_depth = depth + 1,
                })
                return i, target_actions, actions_collected, true
            end
        end

        return i, target_actions, actions_collected, false
    end


    ----------------------------------------------------------------------
    -- Helper: record remaining modifiers at the end
    ----------------------------------------------------------------------
    local function finalize_modifiers(indent, block, modifiers)
        for _, m in ipairs(modifiers) do
            table.insert(block.remaining_modifiers, { card = m.card, remaining = m.remaining })
        vprint(string.format("%s  [-] [FORCE CLOSE MOD] '%s' (%d unfilled)",
                indent, readable_card_id(m.card), m.remaining))
        end
    end


    ----------------------------------------------------------------------
    -- Main: build_cast_block
    ----------------------------------------------------------------------
    function build_cast_block(start_index, depth, inherited_modifiers, visited_cards, sub_block_override,
                              suppress_always_casts)
        depth = depth or 1
        visited_cards = visited_cards or {}
        local indent = string.rep("  ", depth - 1)

        local block = {
            cards = {},
            children = {},
            applied_modifiers = {},
            remaining_modifiers = {},
            total_cast_delay = 0,
            total_recharge = 0,
            target_override = sub_block_override,
            card_delays = {},  -- Track cumulative delay after each card
        }

        ------------------------------------------------------------
        -- Merge modifiers
        ------------------------------------------------------------
        local modifiers = merge_modifiers(inherited_modifiers)
        for _, m in ipairs(modifiers) do
            table.insert(block.applied_modifiers, { card = m.card, remaining = m.remaining })
        end

        ------------------------------------------------------------
        -- Setup casting parameters
        ------------------------------------------------------------
        local actions_collected = 0
        local i = start_index
        local safety = 0
        local target_actions = block.target_override or wand.cast_block_size or 1

        ------------------------------------------------------------
        -- Handle always-casts
        ------------------------------------------------------------
        if not suppress_always_casts then
            i, target_actions = handle_always_casts(indent, depth, block, modifiers, visited_cards, i, target_actions)
        end

        ------------------------------------------------------------
        -- Begin deck evaluation loop
        ------------------------------------------------------------
        vprint(string.format("%s[Depth %d] >>> Building cast block starting at %d (target %d actions)",
            indent, depth, start_index, target_actions))

        while actions_collected < target_actions and safety < #deck * 4 do
            safety = safety + 1
            local idx = ((i - 1) % #deck) + 1
            local card = deck[idx]
            
            -- If card is seen but not guaranteed to execute, mark it partial.
            -- process_card(...) will upgrade it to "full" if it actually executes.
            if card_execution[card:handle()] == "unused" then
                card_execution[card:handle()] = "partial"
            end
            
            if not card then break end
            i = i + 1

            -- Visit / recursion guards
            local count = visited_cards[card] or 0
            if count > 0 then
                local limit = card.revisit_limit or 0
                if limit == 0 then
        vprint(string.format("%s  [!] Card '%s' already used %dx; halting (no revisit).", indent,
                        readable_card_id(card), count))
                    break
                elseif limit > 0 and count >= limit then
        vprint(string.format("%s  [!] Card '%s' revisit limit reached (%d).", indent, readable_card_id(card),
                        limit))
                    break
                else
        vprint(string.format("%s  [REV] Revisiting card '%s' (%d/%s)",
                        indent, readable_card_id(card), count + 1,
                        (limit == -1 and "INF" or tostring(limit))))
                end
            end
            visited_cards[card] = count + 1

            if card.allow_recursion and card.recursion_depth and depth > card.recursion_depth then
        vprint(string.format("%s  [!] Card '%s' recursion depth limit reached (%d).",
                    indent, readable_card_id(card), card.recursion_depth))
                break
            end

            -- Process card
            local sub_ended
            i, target_actions, actions_collected, sub_ended =
                process_card(indent, card, modifiers, block, depth, i, visited_cards, target_actions, actions_collected)

            if sub_ended then break end

            if actions_collected < target_actions then
        vprint(string.format("%s    ...still need %d more actions to fill block...",
                    indent, target_actions - actions_collected))
            end
        end

        ------------------------------------------------------------
        -- Finalize
        ------------------------------------------------------------
        finalize_modifiers(indent, block, modifiers)
        vprint(string.format("%s  [OK] Finished block (%d/%d actions) at depth %d",
            indent, #block.cards, target_actions, depth))

        return block, i, block.total_cast_delay, block.total_recharge
    end

    ----------------------------------------------------------------------
    -- Pretty printer helpers
    ----------------------------------------------------------------------

    -- Describes a single card, including type, modifiers, and delays
    local function describe_card(c)
        local desc = readable_card_id(c)

        if c.type == "modifier" then
            desc = desc .. string.format(" (modifier x%d)", c.multicast_count or 1)
        elseif c.type == "action" then
            desc = desc .. " (action)"
            if c.timer_ms then
                desc = desc .. string.format(", delayed trigger +%dms", c.timer_ms)
            elseif c.trigger_on_collision then
                desc = desc .. " (collision trigger)"
            end
        end

        local base_delay = wand.cast_delay or 0
        local total_delay = (base_delay + (c.cast_delay or 0)) * overload_ratio

        return string.format("%s - cast_delay +%dms (total %.1fms w/ overload)",
            desc, c.cast_delay or 0, total_delay)
    end


    -- Prints a list of modifiers with consistent formatting
    local function print_modifiers(indent, modifiers, header, suffix)
        if modifiers and #modifiers > 0 then
        vprint(indent .. string.format("  %s %d", header, #modifiers))
            for _, m in ipairs(modifiers) do
        vprint(string.format("%s    * '%s' (%d %s)",
                    indent, m.card.card_id, m.remaining, suffix))
            end
        end
    end


    -- Finds a child block triggered by a specific card (if any)
    local function find_child_for_card(block, card)
        for _, child in ipairs(block.children or {}) do
            if child.trigger == card then
                return child
            end
        end
        return nil
    end


    -- Recursively prints a block and its children
    local function print_block(block, depth, label)
        local indent = string.rep("  ", depth)
        if label then vprint(indent .. label) end

        -- Modifiers (start and end state)
        print_modifiers(indent, block.applied_modifiers, "[MODS] Applied modifiers at block start:", "left at start")
        print_modifiers(indent, block.remaining_modifiers, "[REM] Remaining modifiers after cast:", "left after")

        -- Cards and sub-blocks
        for _, c in ipairs(block.cards) do
        vprint(indent .. "  * " .. describe_card(c))

            local child = find_child_for_card(block, c)
            if child then
                local lbl = child.delay
                    and string.format("[TIME] After %dms:", child.delay)
                    or "[COLL] On Collision:"
        vprint(indent .. "  " .. lbl)
                print_block(child.block, depth + 1)
            end
        end
    end


    ----------------------------------------------------------------------
    -- Summary printer
    ----------------------------------------------------------------------

    local function print_execution_summary(blocks, wand, total_cast_delay, total_recharge_time)
        local line = string.rep("-", 60)
        vprint(line)

        for idx, block in ipairs(blocks) do
        vprint(string.format("Cast Block %d:", idx))
            print_block(block, 1)
        vprint("")
        end

        vprint(line)
        vprint(string.format("Wand '%s' Execution Complete", wand.id))
        vprint(string.format("-> Total Cast Delay: %.1f ms", total_cast_delay))
        vprint(string.format("-> Total Recharge Time: %.1f ms", total_recharge_time))
        vprint(string.rep("=", 60))
    end


    ----------------------------------------------------------------------
    -- Execution driver
    ----------------------------------------------------------------------
    -- -----------------------------
    -- Add this local table BEFORE execute_wand(deck)
    -- -----------------------------
    local simulation_result = {
        wand_id = wand.id,

        deck = deck,
        total_cast_delay = 0,
        total_recharge_time = 0,
        blocks = nil,  -- filled in after execution
        total_weight = total_weight,
        overload_ratio = overload_ratio,
        global_always_modifiers = global_always_modifiers,
        card_execution = card_execution,
    }

    -- -----------------------------
    -- Replace execute_wand() so it writes into simulation_result
    -- -----------------------------
    local function execute_wand(deck)
        local blocks = {}
        local total_cast_delay, total_recharge_time = 0, 0
        local i = 1
        local safety = 0
        local max_iterations = #deck * 2  -- Prevent infinite loops

        local base_cast_delay = wand.cast_delay or 0
        local base_recharge_time = wand.recharge_time or 0

        while i <= #deck and safety < max_iterations do
            safety = safety + 1
            
            local block, next_i, c_delay, c_recharge = build_cast_block(i)
            
            -- Only add block if it actually cast any cards
            if #block.cards > 0 then
                table.insert(blocks, block)
                total_cast_delay  = total_cast_delay  + (base_cast_delay  + c_delay) * overload_ratio
                total_recharge_time = total_recharge_time + (base_recharge_time + c_recharge) * overload_ratio
            end

            -- If we didn't advance past the current card, we're stuck - break out
            if next_i == i then
                break
            end

            i = next_i
        end

        simulation_result.blocks = blocks
        simulation_result.total_cast_delay = total_cast_delay
        simulation_result.total_recharge_time = total_recharge_time

        -- keep the existing printer (optional)
        print_execution_summary(blocks, wand, total_cast_delay, total_recharge_time)
    end

    execute_wand(deck)

    return simulation_result
end

function testWands()
    -- local card_pool = {
    --     create_card_from_template(TEST_PROJECTILE),
    --     create_card_from_template(TEST_PROJECTILE),
    --     create_card_from_template(TEST_PROJECTILE),
    --     create_card_from_template(TEST_DAMAGE_BOOST),
    --     create_card_from_template(TEST_PROJECTILE_TIMER),
    --     create_card_from_template(TEST_PROJECTILE_TRIGGER),
    --     create_card_from_template(TEST_DAMAGE_BOOST),
    --     create_card_from_template(TEST_MULTICAST_2),
    --     create_card_from_template(TEST_MULTICAST_2),
    --     create_card_from_template(TEST_MULTICAST_2),
    --     create_card_from_template(TEST_MULTICAST_2),

    -- }

    local card_pool = {
        create_card_from_template(CardTemplates.TEST_PROJECTILE),
        create_card_from_template(CardTemplates.TEST_PROJECTILE),
        create_card_from_template(CardTemplates.TEST_PROJECTILE),
        create_card_from_template(CardTemplates.TEST_DAMAGE_BOOST),
        create_card_from_template(CardTemplates.TEST_PROJECTILE_TIMER),
        create_card_from_template(CardTemplates.TEST_PROJECTILE_TRIGGER),
        create_card_from_template(CardTemplates.TEST_DAMAGE_BOOST),
        create_card_from_template(CardTemplates.TEST_MULTICAST_2),
        create_card_from_template(CardTemplates.TEST_MULTICAST_2),
        create_card_from_template(CardTemplates.TEST_MULTICAST_2),
        create_card_from_template(CardTemplates.TEST_MULTICAST_2),
    }


    simulate_wand(WandTemplates[2], card_pool) -- wand with no shuffle, no always cast, no shuffle, cast block size 1

    simulate_wand(WandTemplates[1], card_pool) -- wand with shuffle and always cast modifier, cast block size 2
end

-- return the various features of this file
return {
    wand_defs = WandTemplates,
    card_defs = CardTemplates,
    trigger_card_defs = TriggerCardTemplates,
    testWands = testWands,
    
    -- functions that might be useful
    apply_card_properties = apply_card_properties,
    create_card_from_template = create_card_from_template,
    readable_card_id = readable_card_id,
    simulate_wand = simulate_wand,
}
