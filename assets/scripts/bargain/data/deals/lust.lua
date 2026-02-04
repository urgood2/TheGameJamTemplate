-- assets/scripts/bargain/data/deals/lust.lua

local function noop(_) end

return {
    {
        id = "lust.1",
        sin = "lust",
        name = "Tempted",
        desc = "Desire overrides your plan.",
        tags = { "lust" },
        requires = {},
        offers_weight = 1,
        downside = { forced_actions_count = 1 },
        on_apply = noop,
    },
    {
        id = "lust.2",
        sin = "lust",
        name = "Distracted",
        desc = "You hesitate when it matters.",
        tags = { "lust" },
        requires = {},
        offers_weight = 1,
        downside = { denied_actions_count = 1 },
        on_apply = noop,
    },
    {
        id = "lust.3",
        sin = "lust",
        name = "Blinded",
        desc = "Your vision narrows.",
        tags = { "lust" },
        requires = {},
        offers_weight = 1,
        downside = { visible_tiles_count = -1 },
        on_apply = noop,
    },
}
