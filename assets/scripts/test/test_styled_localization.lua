-- test_styled_localization.lua
-- Tests for localization.getStyled()

local TestRunner = require("test.test_runner")
local test_utils = require("test.test_utils")

local function register(test_id, fn)
    TestRunner.register(test_id, "localization", fn, {
        tags = {"localization"},
        requires = {"test_scene"},
        doc_ids = {"pattern:localization.get_styled"},
    })
end

local function assert_eq(actual, expected, label)
    test_utils.assert_eq(actual, expected, label)
end

register("localization.styled.basic_color", function()
    local result = localization.getStyled("test.styled_damage", { damage = 25 })
    assert_eq(result, "Deal [25](color=red) damage", "Basic color substitution")
end)

register("localization.styled.multiple_params", function()
    local result = localization.getStyled("test.styled_element", { element = "Fire", cost = 10 })
    assert_eq(result, "Cast [Fire](color=fire) spell for [10](color=blue) mana", "Multiple params with colors")
end)

register("localization.styled.override_color", function()
    local result = localization.getStyled("test.styled_damage", { damage = { value = 50, color = "gold" } })
    assert_eq(result, "Deal [50](color=gold) damage", "Override color at runtime")
end)

register("localization.styled.no_color", function()
    local result = localization.getStyled("test.styled_no_color", { count = 5 })
    assert_eq(result, "You have 5 items", "No color specified")
end)

register("localization.styled.missing_param", function()
    local result = localization.getStyled("test.styled_damage", {})
    assert_eq(result, "Deal {damage|red} damage", "Missing param stays as placeholder")
end)

register("localization.styled.mixed_markup", function()
    local result = localization.getStyled("test.styled_mixed", { damage = 100 })
    assert_eq(result, "A [powerful](color=gold) attack dealing [100](color=red) damage", "Mixed manual markup")
end)

return true
