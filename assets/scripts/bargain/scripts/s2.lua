-- assets/scripts/bargain/scripts/s2.lua

local constants = require("bargain.sim.constants")

return {
    id = "S2",
    description = "Deal interaction path.",
    setup = function(world)
        local boss = require("bargain.enemies.boss")
        world.floor_num = 7
        world.phase = constants.PHASES.PLAYER_INPUT
        world.deal_state.offer_queue = {
            { reason = "script", deals = { "wrath.1", "pride.1", "greed.1" } },
            { reason = "script", deals = { "sloth.1", "envy.1", "gluttony.1" } },
            { reason = "script", deals = { "lust.1", "wrath.2", "pride.2" } },
        }

        local b = boss.spawn(world, { x = 2, y = 2 })
        if b then
            b.hp = 0
        end
    end,
    inputs = {
        { type = "deal_choose", deal_id = "wrath.1" },
        { type = "deal_choose", deal_id = "sloth.1" },
        { type = "deal_choose", deal_id = "lust.1" },
        { type = "wait" },
    },
}
