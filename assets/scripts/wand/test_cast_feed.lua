--[[
================================================================================
TEST: CAST FEED & SPELL TYPE VISUALIZATION
================================================================================
]] --

local TestCastFeed = {}

-- Dependencies
local WandExecutor = require("wand.wand_executor")
local JokerSystem = require("wand.joker_system")
local cardEval = require("core.card_eval_order_test")
local signal = require("external.hump.signal")

function TestCastFeed.run()
    print("\n" .. string.rep("=", 60))
    print("TEST: Cast Feed & Spell Type Visualization")
    print(string.rep("=", 60))

    -- 1. Setup Mock UI Listener (to verify events are emitted)
    local receivedEvents = {}
    signal.register("on_spell_cast", function(data)
        print("[TEST] Received on_spell_cast: " .. tostring(data.spell_type))
        table.insert(receivedEvents, { type = "spell", data = data })
    end)
    signal.register("on_joker_trigger", function(data)
        print("[TEST] Received on_joker_trigger: " .. tostring(data.joker_name))
        table.insert(receivedEvents, { type = "joker", data = data })
    end)

    -- 2. Setup Wand with Twin Cast
    local wandDef = {
        id = "test_wand",
        type = "trigger",
        mana_max = 100,
        mana_recharge_rate = 10,
        cast_block_size = 2,
        cast_delay = 100,
        recharge_time = 500,
        spread_angle = 5,
        shuffle = false,
        total_card_slots = 2,
        always_cast_cards = {},
    }

    local cardPool = {
        cardEval.create_card_from_template(cardEval.card_defs.MULTI_DOUBLE_CAST),
        cardEval.create_card_from_template(cardEval.card_defs.ACTION_BASIC_PROJECTILE),
    }

    local triggerDef = { id = "every_N_seconds", type = "trigger", interval = 0.1 }

    WandExecutor.init()
    local wandId = WandExecutor.loadWand(wandDef, cardPool, triggerDef)

    -- 3. Add Joker
    JokerSystem.clear_jokers()
    JokerSystem.add_joker("echo_chamber")
    JokerSystem.add_joker("tag_master") -- Should trigger if we have tags

    -- 4. Simulate Update (Trigger Cast)
    print("Simulating frame update...")
    WandExecutor.update(0.2) -- Should trigger cast

    -- 5. Verify Events
    print("\nVerifying Events...")
    local foundSpell = false
    local foundJoker = false

    for _, event in ipairs(receivedEvents) do
        if event.type == "spell" and event.data.spell_type == "Twin Cast" then
            foundSpell = true
        end
        if event.type == "joker" and event.data.joker_name == "Echo Chamber" then
            foundJoker = true
        end
    end

    if foundSpell then
        print("[PASS] Spell Type 'Twin Cast' emitted.")
    else
        print("[FAIL] Spell Type 'Twin Cast' NOT emitted.")
    end

    if foundJoker then
        print("[PASS] Joker 'Echo Chamber' emitted.")
    else
        print("[FAIL] Joker 'Echo Chamber' NOT emitted.")
    end

    print("\nNOTE: Visual verification required in-game to see the UI popup.")
end

return TestCastFeed
