-- assets/scripts/bargain/data/deals/envy.lua

local function noop(_) end

return {
    {
        id = "envy.1",
        sin = "envy",
        name = "Covet",
        desc = "Jealousy dulls your blows.",
        tags = { "envy" },
        requires = {},
        offers_weight = 1,
        downside = { damage_dealt_total = -1 },
        on_apply = noop,
    },
    {
        id = "envy.2",
        sin = "envy",
        name = "Want",
        desc = "Chasing others drains resources.",
        tags = { "envy" },
        requires = {},
        offers_weight = 1,
        downside = { resources_spent_total = 2 },
        on_apply = noop,
    },
    {
        id = "envy.3",
        sin = "envy",
        name = "Green Bite",
        desc = "Envy nips at your health.",
        tags = { "envy" },
        requires = {},
        offers_weight = 1,
        downside = { hp_lost_total = 1 },
        on_apply = noop,
    },
}
