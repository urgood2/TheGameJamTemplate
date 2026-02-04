-- assets/scripts/bargain/data/deals/sloth.lua

local function noop(_) end

return {
    {
        id = "sloth.1",
        sin = "sloth",
        name = "Dawdle",
        desc = "You lose time.",
        tags = { "sloth" },
        requires = {},
        offers_weight = 1,
        downside = { turns_elapsed = 2 },
        on_apply = noop,
    },
    {
        id = "sloth.2",
        sin = "sloth",
        name = "Listless",
        desc = "You act only when pushed.",
        tags = { "sloth" },
        requires = {},
        offers_weight = 1,
        downside = { forced_actions_count = 1 },
        on_apply = noop,
    },
    {
        id = "sloth.3",
        sin = "sloth",
        name = "Delay",
        desc = "Inaction blocks a choice.",
        tags = { "sloth" },
        requires = {},
        offers_weight = 1,
        downside = { denied_actions_count = 1 },
        on_apply = noop,
    },
}
