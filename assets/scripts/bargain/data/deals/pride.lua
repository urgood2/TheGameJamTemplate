-- assets/scripts/bargain/data/deals/pride.lua

local function noop(_) end

return {
    {
        id = "pride.1",
        sin = "pride",
        name = "Stubborn",
        desc = "Pride denies a needed action.",
        tags = { "pride" },
        requires = {},
        offers_weight = 1,
        downside = { denied_actions_count = 1 },
        on_apply = noop,
    },
    {
        id = "pride.2",
        sin = "pride",
        name = "Grandstanding",
        desc = "You linger to be seen.",
        tags = { "pride" },
        requires = {},
        offers_weight = 1,
        downside = { turns_elapsed = 1 },
        on_apply = noop,
    },
    {
        id = "pride.3",
        sin = "pride",
        name = "Overconfident",
        desc = "You take a heavier hit.",
        tags = { "pride" },
        requires = {},
        offers_weight = 1,
        downside = { damage_taken_total = 2 },
        on_apply = noop,
    },
}
