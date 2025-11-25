-- Test Harness for JokerSystem
-- Verifies that Jokers correctly modify stats based on events.

-- Get the directory of this script
local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = script_path:match("(.*/)")

-- Mock the module loading - add the script directory to the path
package.path = package.path .. ";" .. script_dir .. "?.lua"
local JokerSystem = require("joker_system")

local function run_test(name, setup_fn, trigger_fn, expected_check_fn)
    JokerSystem.clear_jokers()
    setup_fn()
    local result = trigger_fn()
    if expected_check_fn(result) then
        print(string.format("[PASS] %s", name))
    else
        print(string.format("[FAIL] %s", name))
        -- Debug output
        print("  Expected check failed. Result:")
        for k, v in pairs(result) do
            print(string.format("    %s = %s", k, tostring(v)))
        end
    end
end

print("--- Testing JokerSystem ---")

-- 1. Pyromaniac Test
run_test("Pyromaniac (Fire Buff)",
    function()
        JokerSystem.add_joker("pyromaniac")
    end,
    function()
        return JokerSystem.trigger_event("on_spell_cast", {
            spell_type = "Mono-Element",
            tags = { Fire = true }
        })
    end,
    function(result)
        return result.damage_mod == 10
    end
)

-- 2. Echo Chamber Test
run_test("Echo Chamber (Twin Cast)",
    function()
        JokerSystem.add_joker("echo_chamber")
    end,
    function()
        return JokerSystem.trigger_event("on_spell_cast", {
            spell_type = "Twin Cast"
        })
    end,
    function(result)
        return result.repeat_cast == 1
    end
)

-- 3. Tag Master Test
run_test("Tag Master (Scaling)",
    function()
        JokerSystem.add_joker("tag_master")
    end,
    function()
        return JokerSystem.trigger_event("calculate_damage", {
            player = { tag_counts = { Fire = 5, Ice = 5 } } -- Total 10 tags
        })
    end,
    function(result)
        -- Expected: 1 + (10 * 0.01) = 1.1
        return result.damage_mult == 1.1
    end
)

-- 4. Multiple Jokers
run_test("Multiple Jokers (Stacking)",
    function()
        JokerSystem.add_joker("pyromaniac")
        JokerSystem.add_joker("pyromaniac") -- Stack 2
    end,
    function()
        return JokerSystem.trigger_event("on_spell_cast", {
            spell_type = "Mono-Element",
            tags = { Fire = true }
        })
    end,
    function(result)
        return result.damage_mod == 20
    end
)

print("--- Test Complete ---")
