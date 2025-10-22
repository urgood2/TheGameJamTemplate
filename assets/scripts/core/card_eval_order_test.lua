


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
        max_uses = -1, -- infinite
        mana_max = 50,
        mana_recharge_rate = 5, -- per second
        cast_block_size = 2, -- number of cards per cast block
        cast_delay = 200, -- ms between spells in cast block
        recharge_time = 1000, -- ms after all cast blocks are done
        spread_angle = 10, -- degrees of random spread
        shuffle = true, -- shuffle cards before each full rotation
        total_card_slots = 5, -- total number of card slots
        always_cast_cards = { "TEST_DAMAGE_BOOST" }, -- always include this modifier card in each cast block
    },
    
    -- no shuffle, no always cast cards.
    {
        id = "TEST_WAND_2",
        type = "trigger",
        max_uses = -1, -- infinite
        mana_max = 30,
        mana_recharge_rate = 10, -- per second
        cast_block_size = 1, -- number of cards per cast block
        cast_delay = 100, -- ms between spells in cast block
        recharge_time = 500, -- ms after all cast blocks are done
        spread_angle = 5, -- degrees of random spread
        shuffle = false, -- do not shuffle cards
        total_card_slots = 10, -- total number of card slots
        always_cast_cards = {}, -- no always cast cards
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

-- Simulate Noita-like cast block division, with trigger/timer behavior
local function simulate_wand(wand, card_pool)
    print("\n=== Simulating " .. wand.id .. " ===")

    ----------------------------------------------------------------------
    -- Lookup helper
    ----------------------------------------------------------------------
    local function get_card_by_id(id)
        for _, c in ipairs(card_pool) do
            if c.id == id then return c end
        end
        return nil
    end

    ----------------------------------------------------------------------
    -- Build deck (limited to pool size)
    ----------------------------------------------------------------------
    local deck = {}
    local max_cards = math.min(wand.total_card_slots, #card_pool)
    for i = 1, max_cards do
        table.insert(deck, card_pool[i].id)
    end

    if wand.shuffle then
        math.randomseed(os.time())
        for i = #deck, 2, -1 do
            local j = math.random(i)
            deck[i], deck[j] = deck[j], deck[i]
        end
    end

    print("Deck: {" .. table.concat(deck, ",\n\t") .. "}")
    print(string.rep("-", 60))

    ----------------------------------------------------------------------
    -- 🟡 New: Calculate total weight and overload ratio
    ----------------------------------------------------------------------
    local total_weight = 0
    for _, c in ipairs(card_pool) do
        total_weight = total_weight + (c.weight or 1)
    end

    local overload_ratio = 1.0
    if wand.mana_max and total_weight > wand.mana_max then
        local excess = total_weight - wand.mana_max
        overload_ratio = 1.0 + (excess / wand.mana_max) * 0.5
        print(string.format("⚠️ Wand overloaded: weight %.1f / %.1f → +%.0f%% cast/recharge delay",
            total_weight, wand.mana_max, (overload_ratio - 1.0) * 100))
    else
        print(string.format("✅ Wand within weight limit: weight %.1f / %.1f", total_weight, wand.mana_max or total_weight))
    end
    print(string.rep("-", 60))

    ----------------------------------------------------------------------
    -- Recursive builder for a single valid cast block
    ----------------------------------------------------------------------
    local function build_one_cast_block(start_index, depth, parent_open_cards)
    depth = (depth or 0) + 1

    -- Create a per-block copy of open cards (local scope only)
    local open_cards = {}
    if parent_open_cards then
        for k, v in pairs(parent_open_cards) do
            open_cards[k] = v
        end
    end

    local indent = string.rep("  ", depth - 1)
    print(string.format("%s[Depth %d] ➤ Building cast block starting at index %d", indent, depth, start_index))

    local block, i, safety = {}, start_index, 0
    local required_actions, total_cast_delay, total_recharge = 1, 0, 0
    local modifier_stack = {}

    while required_actions > 0 and safety < #deck * 4 do
        safety = safety + 1
        local idx = ((i - 1) % #deck) + 1
        local cid = deck[idx]
        local card = get_card_by_id(cid)
        i = i + 1
        if not card then goto continue end

        ----------------------------------------------------------------------
        -- 🚫 Prevent recursion into already-open cards (within this block only)
        ----------------------------------------------------------------------
        if open_cards[cid] then
            print(string.format("%s[Depth %d] ⛔ '%s' already used in this block — halting block.", indent, depth, cid))
            break
        end

        open_cards[cid] = true
        table.insert(block, cid)

        ----------------------------------------------------------------------
        -- 🔹 Log card open
        ----------------------------------------------------------------------
        if card.type == "modifier" then
            print(string.format("%s[Depth %d] 🔹 [MOD OPEN] '%s' (modifier ×%d)",
                indent, depth, cid, card.multicast_count or 1))
            table.insert(modifier_stack, { id = cid, remaining = card.multicast_count or 1 })
        else
            print(string.format("%s[Depth %d] 🔹 Open '%s' (%s)", indent, depth, cid, card.type))
        end

        ----------------------------------------------------------------------
        -- 🧩 Core action/modifier behavior
        ----------------------------------------------------------------------
        if card.type == "modifier" and card.multicast_count and card.multicast_count > 1 then
            required_actions = required_actions + (card.multicast_count - 1)
        elseif card.type == "action" then
            required_actions = required_actions - 1
            total_cast_delay = total_cast_delay + (card.cast_delay or 0)
            total_recharge = total_recharge + (card.recharge_time or 0)

            -- handle active modifiers wrapping actions
            if #modifier_stack > 0 then
                local top = modifier_stack[#modifier_stack]
                top.remaining = top.remaining - 1
                print(string.format("%s[Depth %d]   ↳ '%s' inside modifier '%s' (%d left)",
                    indent, depth, cid, top.id, top.remaining))
                if top.remaining <= 0 then
                    print(string.format("%s[Depth %d] 🔸 [MOD CLOSE] '%s'", indent, depth, top.id))
                    table.remove(modifier_stack)
                end
            end

            ------------------------------------------------------------------
            -- ✅ Safe recursion: payload gets a *fresh* open_cards snapshot
            ------------------------------------------------------------------
            if card.timer_ms or card.trigger_on_collision then
                print(string.format("%s[Depth %d] ↳ Building payload for '%s'", indent, depth, cid))
                -- payload uses its own isolated open_cards, copied from this block
                local payload_block, new_i = build_one_cast_block(i, depth, open_cards)
                i = new_i
                if card.timer_ms then
                    table.insert(block, { delay = card.timer_ms, cards = payload_block })
                elseif card.trigger_on_collision then
                    table.insert(block, { collision = true, cards = payload_block })
                end
                print(string.format("%s[Depth %d] ↩ Finished payload for '%s'", indent, depth, cid))
            end
        end

        ----------------------------------------------------------------------
        -- 🔸 Normal close logging
        ----------------------------------------------------------------------
        print(string.format("%s[Depth %d] 🔸 Close '%s'", indent, depth, cid))
        ::continue::
    end

    -- Force close unfilled modifiers
    for _, mod in ipairs(modifier_stack) do
        print(string.format("%s[Depth %d] 🔸 [FORCE CLOSE MOD] '%s' (%d unfilled)",
            indent, depth, mod.id, mod.remaining))
    end

    print(string.format("%s[Depth %d] ✅ Finished block (%d cards)", indent, depth, #block))
    return block, i, total_cast_delay, total_recharge
end





    ----------------------------------------------------------------------
    -- Pretty print (recursive)
    ----------------------------------------------------------------------
    local function describe_card(cid)
        local c = get_card_by_id(cid)
        if not c then return cid end

        local desc = cid
        if c.type == "modifier" then
            local n = c.multicast_count or 1
            desc = string.format("%s (modifier ×%d)", cid, n)
        elseif c.type == "action" then
            desc = string.format("%s (action)", cid)
            if c.timer_ms then
                desc = desc .. string.format(", delayed trigger +%dms", c.timer_ms)
            elseif c.trigger_on_collision then
                desc = desc .. " (collision trigger)"
            end
        end

        local total_delay = ((wand.cast_delay or 0) + (c.cast_delay or 0)) * overload_ratio
        desc = string.format("%s — cast_delay +%dms (total %.1fms with overload)",
            desc, c.cast_delay or 0, total_delay)
        return desc
    end

    local function print_block(block, depth, label)
        local indent = string.rep("  ", depth)
        if label then print(indent .. label) end

        for _, entry in ipairs(block) do
            if type(entry) == "table" and entry.cards then
                local tag = entry.delay and
                    (string.format("Delayed (%dms) Parallel Block:", entry.delay)) or
                    (entry.collision and "On-Collision Parallel Block:")
                print_block(entry.cards, depth + 1, tag)
            elseif type(entry) == "table" and not entry.cards then
                print_block(entry, depth + 1)
            else
                print(indent .. "  • " .. describe_card(entry))
            end
        end
    end

    ----------------------------------------------------------------------
    -- Main execution
    ----------------------------------------------------------------------
    local blocks = {}
    local i = 1
    local total_cast_delay = 0
    local total_recharge_time = 0

    while i <= #deck do
        local open_cards = {} -- reset between top-level blocks
        local block, new_i, c_delay, c_recharge = build_one_cast_block(i)

        -- prepend always-cast cards
        if #wand.always_cast_cards > 0 then
            local full_block = {}
            for _, ac in ipairs(wand.always_cast_cards) do table.insert(full_block, ac) end
            for _, c in ipairs(block) do table.insert(full_block, c) end
            block = full_block
        end

        table.insert(blocks, block)
        total_cast_delay = total_cast_delay + ((wand.cast_delay or 0) + c_delay) * overload_ratio
        total_recharge_time = total_recharge_time + ((wand.recharge_time or 0) + c_recharge) * overload_ratio
        i = new_i
    end

    ----------------------------------------------------------------------
    -- Print results
    ----------------------------------------------------------------------
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




function testWands() 
    
    local card_pool = {TEST_DAMAGE_BOOST, TEST_PROJECTILE, TEST_PROJECTILE_TIMER,  TEST_MULTICAST_2, TEST_PROJECTILE_TRIGGER, TEST_PROJECTILE}
    
    simulate_wand(triggersToTest[2], card_pool) -- wand with no shuffle, no always cast, no shuffle, cast block size 1 
    
    simulate_wand(triggersToTest[1], card_pool) -- wand with shuffle and always cast modifier, cast block size 2
end


