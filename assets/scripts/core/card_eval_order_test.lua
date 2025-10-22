local Node = require("monobehavior.behavior_script_v2") -- the new monobehavior script

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



local triggersToTest = {

    -- has shuffle and an always cast modifier.
    {
        id = "TEST_WAND_1",
        type = "trigger",
        max_uses = -1,                               -- infinite
        mana_max = 50,
        mana_recharge_rate = 5,                      -- per second
        cast_block_size = 2,                         -- number of cards per cast block
        cast_delay = 200,                            -- ms between spells in cast block
        recharge_time = 1000,                        -- ms after all cast blocks are done
        spread_angle = 10,                           -- degrees of random spread
        shuffle = true,                              -- shuffle cards before each full rotation
        total_card_slots = 5,                        -- total number of card slots
        always_cast_cards = { "TEST_DAMAGE_BOOST" }, -- always include this modifier card in each cast block
    },

    -- no shuffle, no always cast cards.
    {
        id = "TEST_WAND_2",
        type = "trigger",
        max_uses = -1,           -- infinite
        mana_max = 30,
        mana_recharge_rate = 10, -- per second
        cast_block_size = 1,     -- number of cards per cast block
        cast_delay = 100,        -- ms between spells in cast block
        recharge_time = 500,     -- ms after all cast blocks are done
        spread_angle = 5,        -- degrees of random spread
        shuffle = false,         -- do not shuffle cards
        total_card_slots = 10,   -- total number of card slots
        always_cast_cards = {},  -- no always cast cards
    },
}

-- action card
local TEST_PROJECTILE = {
    id = "TEST_PROJECTILE",
    type = "action",
    max_uses = -1, -- infinite
    mana_cost = 5,
    damage = 10,
    damage_type = "physical",
    radius_of_effect = 0,
    spread_angle = 5,
    projectile_speed = 500,
    lifetime = 2000,
    cast_delay = 100,
    recharge_time = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    weight = 1,
}

-- action card with timer
local TEST_PROJECTILE_TIMER = {
    id = "TEST_PROJECTILE_TIMER",
    type = "action",
    max_uses = -1, -- infinite
    mana_cost = 8,
    damage = 15,
    damage_type = "physical",
    radius_of_effect = 0,
    spread_angle = 3,
    projectile_speed = 400,
    lifetime = 3000,
    cast_delay = 150,
    recharge_time = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    timer_ms = 1000, -- spawns a new cast block after 1 second
    weight = 2,
}

-- action card with trigger
local TEST_PROJECTILE_TRIGGER = {
    id = "TEST_PROJECTILE_TRIGGER",
    type = "action",
    max_uses = -1, -- infinite
    mana_cost = 10,
    damage = 20,
    damage_type = "physical",
    radius_of_effect = 0,
    spread_angle = 2,
    projectile_speed = 600,
    lifetime = 2500,
    cast_delay = 200,
    recharge_time = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    trigger_on_collision = true, -- spawns a new cast block on collision
    weight = 2,
}

-- modifier card that modifies 1 card
local TEST_DAMAGE_BOOST = {
    id = "TEST_DAMAGE_BOOST",
    type = "modifier",
    max_uses = -1, -- infinite
    mana_cost = 3,
    damage_modifier = 5,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    multicast_count = 1, -- modifies 1 card
    weight = 1,
}

-- modifier card that modifies 2 cards
local TEST_MULTICAST_2 = {
    id = "TEST_MULTICAST",
    type = "modifier",
    max_uses = -1, -- infinite
    mana_cost = 7,
    damage_modifier = 0,
    spread_modifier = 0,
    speed_modifier = 0,
    lifetime_modifier = 0,
    critical_hit_chance_modifier = 0,
    multicast_count = 2, -- modifies 2 cards
    weight = 2,
}

-- optional table referencing them all, if you still want cardsToTest
local cardsToTest = {
    TEST_PROJECTILE,
    TEST_PROJECTILE_TIMER,
    TEST_PROJECTILE_TRIGGER,
    TEST_DAMAGE_BOOST,
    TEST_MULTICAST_2,
}


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

    return obj
end

-- Simulate Noita-like cast block division, with trigger/timer behavior

--==============================================================
-- ✅ simulate_wand (corrected, ECS/handle-aware, recursion-safe)
--==============================================================


--==============================================================
-- ✅ simulate_wand (modifier inheritance + global modifier persistence)
--==============================================================
local function simulate_wand(wand, card_pool)
    print("\n=== Simulating " .. wand.id .. " ===")

    ----------------------------------------------------------------------
    -- Build deck (store card tables directly)
    ----------------------------------------------------------------------
    local deck = {}
    local max_cards = math.min(wand.total_card_slots, #card_pool)
    for i = 1, max_cards do table.insert(deck, card_pool[i]) end

    if wand.shuffle then
        math.randomseed(os.time())
        for i = #deck, 2, -1 do
            local j = math.random(i)
            deck[i], deck[j] = deck[j], deck[i]
        end
    end

    print("Deck: {")
    for _, c in ipairs(deck) do
        print("  " .. c.card_id .. ":" .. c:handle())
    end
    print("}")
    print(string.rep("-", 60))

    ----------------------------------------------------------------------
    -- Weight / overload calculation
    ----------------------------------------------------------------------
    local total_weight = 0
    for _, c in ipairs(deck) do total_weight = total_weight + (c.weight or 1) end

    local overload_ratio = 1.0
    if wand.mana_max and total_weight > wand.mana_max then
        local excess = total_weight - wand.mana_max
        overload_ratio = 1.0 + (excess / wand.mana_max) * 0.5
        print(string.format("⚠️ Wand overloaded: weight %.1f / %.1f → +%.0f%% cast/recharge delay",
            total_weight, wand.mana_max, (overload_ratio - 1.0) * 100))
    else
        print(string.format("✅ Wand within weight limit: weight %.1f / %.1f",
            total_weight, wand.mana_max or total_weight))
    end
    print(string.rep("-", 60))

    ----------------------------------------------------------------------
    -- Helpers
    ----------------------------------------------------------------------
    local function readable_card_id(card)
        return card.card_id .. ":" .. card:handle()
    end

    ----------------------------------------------------------------------
    -- Track active modifiers globally
    ----------------------------------------------------------------------
    local global_active_modifiers = {}

    ----------------------------------------------------------------------
    -- Build one cast block (Noita-style)
    ----------------------------------------------------------------------

    local function build_cast_block(start_index, depth, inherited_modifiers)
        depth = depth or 1
        local indent = string.rep("  ", depth - 1)
        local block = {
            cards = {},
            total_cast_delay = 0,
            total_recharge = 0,
            children = {},
            applied_modifiers = {}, -- modifiers that applied at block start
            remaining_modifiers = {}, -- modifiers that remain after execution
        }

        ------------------------------------------------------------
        -- 1. Merge inherited modifiers (deep copy)
        ------------------------------------------------------------
        local modifiers = {}
        if inherited_modifiers then
            for _, m in ipairs(inherited_modifiers) do
                table.insert(modifiers, { card = m.card, remaining = m.remaining })
            end
        end

        ------------------------------------------------------------
        -- 2. Add always-cast modifiers from global scope (if any)
        ------------------------------------------------------------
        for _, m in ipairs(global_active_modifiers) do
            table.insert(modifiers, { card = m.card, remaining = m.remaining })
        end

        ------------------------------------------------------------
        -- 3. Snapshot "applied_modifiers" before any actions
        ------------------------------------------------------------
        for _, m in ipairs(modifiers) do
            table.insert(block.applied_modifiers, { card = m.card, remaining = m.remaining })
        end

        local actions_collected = 0
        local i = start_index
        local safety = 0
        local target_actions = wand.cast_block_size or 1

        print(string.format("%s[Block] ➤ Building cast block starting at %d (target %d actions)",
            indent, start_index, target_actions))

        ------------------------------------------------------------
        -- 4. Main card iteration loop
        ------------------------------------------------------------
        while actions_collected < target_actions and safety < #deck * 2 do
            safety = safety + 1
            local idx = ((i - 1) % #deck) + 1
            local card = deck[idx]
            i = i + 1
            if not card then break end

            if card.type == "modifier" then
                ----------------------------------------------------
                -- Local modifier (affects this and subsequent actions)
                ----------------------------------------------------
                local mod = { card = card, remaining = card.multicast_count or 1 }
                print(string.format("%s  🔹 [MOD OPEN] '%s' ×%d",
                    indent, readable_card_id(card), mod.remaining))
                table.insert(modifiers, mod)
                table.insert(block.applied_modifiers, { card = card, remaining = mod.remaining })
            elseif card.type == "action" then
                ----------------------------------------------------
                -- Action: consumes modifiers, may spawn sub-cast
                ----------------------------------------------------
                actions_collected = actions_collected + 1
                table.insert(block.cards, card)
                block.total_cast_delay = block.total_cast_delay + (card.cast_delay or 0)
                block.total_recharge = block.total_recharge + (card.recharge_time or 0)
                print(string.format("%s  🔹 Action '%s' (%d/%d actions filled)",
                    indent, readable_card_id(card), actions_collected, target_actions))

                -- Apply modifiers to this action
                for j = #modifiers, 1, -1 do
                    local m = modifiers[j]
                    print(string.format("%s     ↳ under modifier '%s' (%d left)",
                        indent, readable_card_id(m.card), m.remaining - 1))
                    m.remaining = m.remaining - 1
                    if m.remaining <= 0 then
                        print(string.format("%s     🔸 [MOD CLOSE] '%s'",
                            indent, readable_card_id(m.card)))
                        table.remove(modifiers, j)
                    end
                end

                ----------------------------------------------------
                -- Recursively spawn sub-cast (timer or collision)
                ----------------------------------------------------
                if (card.timer_ms or card.trigger_on_collision) and i <= #deck then
                    local label = card.timer_ms
                        and string.format("+%dms timer", card.timer_ms)
                        or "on collision"
                    print(string.format("%s     ↳ Spawning sub-cast (%s)", indent, label))

                    -- Deep-copy modifier state so child doesn’t inherit unwanted ones
                    local inherited_copy = {}
                    for _, m in ipairs(modifiers) do
                        table.insert(inherited_copy, { card = m.card, remaining = m.remaining })
                    end

                    local child_block, new_i, _, _ = build_cast_block(i, depth + 1, inherited_copy)
                    i = new_i
                    table.insert(block.children, {
                        trigger = card,
                        delay = card.timer_ms,
                        collision = card.trigger_on_collision,
                        block = child_block
                    })
                end
            end

            if actions_collected < target_actions then
                print(string.format("%s    ...still need %d more actions to fill block...",
                    indent, target_actions - actions_collected))
            end
        end

        ------------------------------------------------------------
        -- 5. Record remaining modifiers for diagnostics
        ------------------------------------------------------------
        for _, m in ipairs(modifiers) do
            table.insert(block.remaining_modifiers, { card = m.card, remaining = m.remaining })
        end

        for _, m in ipairs(modifiers) do
            print(string.format("%s  🔸 [FORCE CLOSE MOD] '%s' (%d unfilled)",
                indent, readable_card_id(m.card), m.remaining))
        end

        print(string.format("%s  ✅ Finished block (%d/%d actions)",
            indent, #block.cards, target_actions))
        return block, i, block.total_cast_delay, block.total_recharge
    end



    ----------------------------------------------------------------------
    -- Pretty printer
    ----------------------------------------------------------------------
    local function describe_card(c)
        local desc = readable_card_id(c)
        if c.type == "modifier" then
            desc = desc .. string.format(" (modifier ×%d)", c.multicast_count or 1)
        elseif c.type == "action" then
            desc = desc .. " (action)"
            if c.timer_ms then
                desc = desc .. string.format(", delayed trigger +%dms", c.timer_ms)
            elseif c.trigger_on_collision then
                desc = desc .. " (collision trigger)"
            end
        end
        local total_delay = ((wand.cast_delay or 0) + (c.cast_delay or 0)) * overload_ratio
        return string.format("%s — cast_delay +%dms (total %.1fms w/ overload)",
            desc, c.cast_delay or 0, total_delay)
    end


    local function print_block(block, depth, label)
        local indent = string.rep("  ", depth)
        if label then print(indent .. label) end

        -- show how many modifiers are active in this block
        if block.applied_modifiers and #block.applied_modifiers > 0 then
            print(indent .. string.format("  🧩 Applied modifiers at block start: %d", #block.applied_modifiers))
            for _, m in ipairs(block.applied_modifiers) do
                print(string.format("%s    • '%s' (%d left at start)",
                    indent, m.card.card_id, m.remaining))
            end
        end

        if block.remaining_modifiers and #block.remaining_modifiers > 0 then
            print(indent .. string.format("  🌀 Remaining modifiers after cast: %d", #block.remaining_modifiers))
            for _, m in ipairs(block.remaining_modifiers) do
                print(string.format("%s    • '%s' (%d left after)", indent, m.card.card_id, m.remaining))
            end
        end

        for _, c in ipairs(block.cards) do
            print(indent .. "  • " .. describe_card(c))

            for _, child in ipairs(block.children or {}) do
                if child.trigger == c then
                    local inherited = child.block and child.block.active_modifiers or {}
                    local count = #inherited

                    local lbl = child.delay
                        and string.format("⏱ After %dms (inherits %d modifiers):", child.delay, count)
                        or string.format("⚡ On Collision (inherits %d modifiers):", count)
                    print(indent .. "  " .. lbl)

                    if count > 0 then
                        for _, m in ipairs(inherited) do
                            print(string.format("%s    ↳ inherits '%s' (%d left)",
                                indent, m.card.card_id, m.remaining))
                        end
                    end

                    print_block(child.block, depth + 1)
                end
            end
        end
    end

    ----------------------------------------------------------------------
    -- Main execution pass
    ----------------------------------------------------------------------
    local blocks = {}
    local pending_blocks = {}
    local total_cast_delay, total_recharge_time = 0, 0
    local i = 1

    while i <= #deck do
        local block, next_i, c_delay, c_recharge = build_cast_block(i)
        table.insert(blocks, block)
        for _, card in ipairs(block.cards) do
            if card.timer_ms then
                table.insert(pending_blocks, { index = next_i, delay = card.timer_ms, source = readable_card_id(card) })
            elseif card.trigger_on_collision then
                table.insert(pending_blocks, { index = next_i, collision = true, source = readable_card_id(card) })
            end
        end
        total_cast_delay = total_cast_delay + ((wand.cast_delay or 0) + c_delay) * overload_ratio
        total_recharge_time = total_recharge_time + ((wand.recharge_time or 0) + c_recharge) * overload_ratio
        i = next_i
    end


    ----------------------------------------------------------------------
    -- Print final results
    ----------------------------------------------------------------------
    print(string.rep("-", 60))
    for idx, block in ipairs(blocks) do
        print(string.format("Cast Block %d:", idx))
        print_block(block, 1)
        print("")
    end

    print(string.rep("-", 60))
    print(string.format("Wand '%s' Execution Complete", wand.id))
    print(string.format("→ Total Cast Delay: %.1f ms", total_cast_delay))
    print(string.format("→ Total Recharge Time: %.1f ms", total_recharge_time))
    print(string.rep("=", 60))
end


local function create_card_from_template(template)
    local card = Node {}
    card:attach_ecs { create_new = true }
    apply_card_properties(card, template)
    return card
end

function testWands()
    local card_pool = {
        create_card_from_template(TEST_PROJECTILE),
        create_card_from_template(TEST_PROJECTILE_TIMER),
        create_card_from_template(TEST_PROJECTILE_TRIGGER),
        create_card_from_template(TEST_DAMAGE_BOOST),
        create_card_from_template(TEST_MULTICAST_2),
    }

    simulate_wand(triggersToTest[2], card_pool) -- wand with no shuffle, no always cast, no shuffle, cast block size 1

    simulate_wand(triggersToTest[1], card_pool) -- wand with shuffle and always cast modifier, cast block size 2
end
