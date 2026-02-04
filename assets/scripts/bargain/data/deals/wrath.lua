-- assets/scripts/bargain/data/deals/wrath.lua

local function noop(_) end

return {
    {
        id = "wrath.1",
        sin = "wrath",
        name = "Hot Blood",
        desc = "You lash out, taking more damage in the chaos.",
        tags = { "wrath" },
        requires = {},
        offers_weight = 1,
        downside = { damage_taken_total = 1 },
        on_apply = noop,
    },
    {
        id = "wrath.2",
        sin = "wrath",
        name = "No Restraint",
        desc = "Fury forces extra actions.",
        tags = { "wrath" },
        requires = {},
        offers_weight = 1,
        downside = { forced_actions_count = 1 },
        on_apply = noop,
    },
    {
        id = "wrath.3",
        sin = "wrath",
        name = "Blood Price",
        desc = "Victory costs a sliver of health.",
        tags = { "wrath" },
        requires = {},
        offers_weight = 1,
        downside = { hp_lost_total = 1 },
        on_apply = noop,
    },
}
