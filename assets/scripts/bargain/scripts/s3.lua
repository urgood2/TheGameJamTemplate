-- assets/scripts/bargain/scripts/s3.lua

local boss = require("bargain.boss")

return {
    id = "S3",
    description = "Victory path with boss defeated on floor 7.",
    setup = function(world)
        world.floor_num = 7
        local b = boss.spawn(world, { x = 2, y = 2 })
        b.hp = 0
    end,
    inputs = {
        { type = "wait" },
        { type = "wait" },
    },
}
