


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
-- Simulate Noita-like cast block division with cast-block–aware payload building
local function simulate_wand(wand, card_pool)
    print("=== Simulating " .. wand.id .. " ===")

    ----------------------------------------------------------------------
    -- Lookup helpers
    ----------------------------------------------------------------------
    local function get_card_by_id(id)
        for _, c in ipairs(card_pool) do
            if c.id == id then return c end
        end
        return nil
    end

    ----------------------------------------------------------------------
    -- Build deck (loop around if needed)
    ----------------------------------------------------------------------
    local deck = {}
    for i = 1, wand.total_card_slots do
        table.insert(deck, card_pool[(i % #card_pool) + 1].id)
    end

    if wand.shuffle then
        math.randomseed(os.time())
        for i = #deck, 2, -1 do
            local j = math.random(i)
            deck[i], deck[j] = deck[j], deck[i]
        end
    end

    ----------------------------------------------------------------------
    -- Helper: build one valid cast block (modifier + action, etc.)
    ----------------------------------------------------------------------
    local function build_one_cast_block(start_index)
        local block = {}
        local i = start_index
        local safety = 0
        local required_actions = 1       -- how many actions are still needed to close this block

        while required_actions > 0 and safety < #deck * 4 do  -- safety multiplier for wrap-around
            safety = safety + 1
            local idx = ((i - 1) % #deck) + 1
            local cid = deck[idx]
            local card = get_card_by_id(cid)
            table.insert(block, cid)
            i = i + 1

            if card then
                if card.type == "modifier" then
                    -- modifiers don’t close anything, they just apply to the next action
                    -- add more required actions if multicast
                    if card.multicast_count and card.multicast_count > 1 then
                        required_actions = required_actions + (card.multicast_count - 1)
                    end
                    
                elseif card.type == "action" then
                    required_actions = required_actions - 1

                    -- if action has timer or trigger, build its nested payload block
                    if card.timer_ms or card.trigger_on_collision then
                        local payload_block, new_i = build_one_cast_block(i)
                        if card.timer_ms then
                            table.insert(block, { delay = card.timer_ms, cards = payload_block })
                        end
                        if card.trigger_on_collision then
                            table.insert(block, { collision = true, cards = payload_block })
                        end
                        i = new_i
                    end
                elseif card.type == "modifier" and card.multicast_count and card.multicast_count > 1 then
                    -- multicast is treated as a modifier that expands required actions
                    local multicast_n = card.multicast_count
                    for n = 1, multicast_n do
                        local sub_block, new_i = build_one_cast_block(i)
                        table.insert(block, sub_block)
                        i = new_i
                    end
                    required_actions = required_actions - 1 -- multicast still satisfies one "action" slot
                end
            end
        end

        return block, i
    end

    ----------------------------------------------------------------------
    -- Recursive evaluator
    ----------------------------------------------------------------------
    local function build_blocks(start_index, cards, blocks)
        local i = start_index
        local pending_mods = {}

        while i <= #cards do
            local card_id = cards[i]
            local card = get_card_by_id(card_id)
            if not card then
                i = i + 1

            elseif card.type == "modifier" then
                table.insert(pending_mods, card_id)
                i = i + 1

            elseif card.type == "action" then
                -- normal block
                local block = {}
                for _, m in ipairs(pending_mods) do table.insert(block, m) end
                pending_mods = {}
                table.insert(block, card_id)
                table.insert(blocks, block)
                i = i + 1

                -- check trigger/timer
                if card.timer_ms or card.trigger_on_collision then
                    local payload_block, new_index = build_one_cast_block(i)
                    if #payload_block > 0 then
                        if card.timer_ms then
                            table.insert(blocks, { delay = card.timer_ms, cards = payload_block })
                            -- build_blocks(1, payload_block, blocks)
                        end
                        if card.trigger_on_collision then
                            table.insert(blocks, { collision = true, cards = payload_block })
                            -- build_blocks(1, payload_block, blocks)
                        end
                    end
                    i = new_index
                end
            else
                i = i + 1
            end
        end
    end

    ----------------------------------------------------------------------
    -- Run
    ----------------------------------------------------------------------
    local blocks = {}
    build_blocks(1, deck, blocks)

    ----------------------------------------------------------------------
    -- Output
    ----------------------------------------------------------------------
    for idx, block in ipairs(blocks) do
        if block.cards then
            if block.delay then
                print(string.format("Cast Block %d (delayed %d ms):", idx, block.delay))
            elseif block.collision then
                print(string.format("Cast Block %d (on collision):", idx))
            else
                print(string.format("Cast Block %d:", idx))
            end
            for _, cid in ipairs(block.cards) do
                print("  *", cid)
            end
        else
            print(string.format("Cast Block %d:", idx))
            for _, cid in ipairs(block) do
                print("  *", cid)
            end
        end
    end
end

function testWands() 
    
    local card_pool = {TEST_DAMAGE_BOOST, TEST_PROJECTILE, TEST_PROJECTILE_TIMER,  TEST_MULTICAST_2, TEST_PROJECTILE_TRIGGER, TEST_PROJECTILE}
    
    simulate_wand(triggersToTest[2], card_pool) -- wand with no shuffle, no always cast, no shuffle, cast block size 1 
end


