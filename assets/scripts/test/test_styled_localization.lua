--- test_styled_localization.lua
--- Manual test for localization.getStyled()
--- Run from Lua console or require during development

local function test_styled_localization()
    print("=== Testing localization.getStyled() ===\n")

    local tests = {
        {
            name = "Basic color substitution",
            key = "test.styled_damage",
            params = { damage = 25 },
            expected = "Deal [25](color=red) damage"
        },
        {
            name = "Multiple params with colors",
            key = "test.styled_element",
            params = { element = "Fire", cost = 10 },
            expected = "Cast [Fire](color=fire) spell for [10](color=blue) mana"
        },
        {
            name = "Override color at runtime",
            key = "test.styled_damage",
            params = { damage = { value = 50, color = "gold" } },
            expected = "Deal [50](color=gold) damage"
        },
        {
            name = "No color specified",
            key = "test.styled_no_color",
            params = { count = 5 },
            expected = "You have 5 items"
        },
        {
            name = "Missing param stays as placeholder",
            key = "test.styled_damage",
            params = {},
            expected = "Deal {damage|red} damage"
        },
        {
            name = "Mixed manual markup and styled",
            key = "test.styled_mixed",
            params = { damage = 100 },
            expected = "A [powerful](color=gold) attack dealing [100](color=red) damage"
        }
    }

    local passed = 0
    local failed = 0

    for _, t in ipairs(tests) do
        local result = localization.getStyled(t.key, t.params)
        if result == t.expected then
            print("[PASS] " .. t.name)
            passed = passed + 1
        else
            print("[FAIL] " .. t.name)
            print("  Expected: " .. t.expected)
            print("  Got:      " .. result)
            failed = failed + 1
        end
    end

    print("\n=== Results: " .. passed .. " passed, " .. failed .. " failed ===")
    return failed == 0
end

return test_styled_localization
