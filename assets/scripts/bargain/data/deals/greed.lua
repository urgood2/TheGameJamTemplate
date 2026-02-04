-- assets/scripts/bargain/data/deals/greed.lua

local function noop(_) end

return {
    {
        id = "greed.1",
        sin = "greed",
        name = "Taxed",
        desc = "Every gain costs a resource.",
        tags = { "greed" },
        requires = {},
        offers_weight = 1,
        downside = { resources_spent_total = 1 },
        on_apply = noop,
    },
    {
        id = "greed.2",
        sin = "greed",
        name = "Clutch",
        desc = "You cling and take a scratch.",
        tags = { "greed" },
        requires = {},
        offers_weight = 1,
        downside = { damage_taken_total = 1 },
        on_apply = noop,
    },
    {
        id = "greed.3",
        sin = "greed",
        name = "Hoarder",
        desc = "Hoarding costs a bit of vitality.",
        tags = { "greed" },
        requires = {},
        offers_weight = 1,
        downside = { hp_lost_total = 2 },
        on_apply = noop,
    },
}
