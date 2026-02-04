-- assets/scripts/bargain/data/deals/gluttony.lua

local function noop(_) end

return {
    {
        id = "gluttony.1",
        sin = "gluttony",
        name = "Overindulge",
        desc = "Excess costs health and stores.",
        tags = { "gluttony" },
        requires = {},
        offers_weight = 1,
        downside = { hp_lost_total = 1, resources_spent_total = 1 },
        on_apply = noop,
    },
    {
        id = "gluttony.2",
        sin = "gluttony",
        name = "Stuffed",
        desc = "You move slower.",
        tags = { "gluttony" },
        requires = {},
        offers_weight = 1,
        downside = { turns_elapsed = 1 },
        on_apply = noop,
    },
    {
        id = "gluttony.3",
        sin = "gluttony",
        name = "Bloated",
        desc = "You take more damage.",
        tags = { "gluttony" },
        requires = {},
        offers_weight = 1,
        downside = { damage_taken_total = 1 },
        on_apply = noop,
    },
}
