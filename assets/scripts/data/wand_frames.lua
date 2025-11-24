-- Wand Frames define the "chassis" of your wand.
-- You can equip multiple wands (e.g., 4 slots), each with a different frame.
-- The frame determines HOW and WHEN the cards inside are cast.

local WandFrames = {
    fanatic = {
        name = "Fanatic Frame",
        description = "Fast, predictable bursts.",

        -- Cast Mechanics
        cast_block_size = 2, -- Casts 2 cards per trigger
        shuffle = false, -- Fires in order (Top -> Bottom)
        cast_cooldown = 3.0, -- Base cooldown between triggers

        -- Overheat / Stats
        overheat_cap = 50, -- Low capacity, heats up fast
        cooling_rate = 10,

        -- Trigger: Fires automatically every N seconds
        trigger_type = "time"
    },

    engine = {
        name = "Engine Frame",
        description = "Heavy artillery. Slow but massive.",

        cast_block_size = 8, -- Dumps a huge hand
        shuffle = false,
        cast_cooldown = 8.0, -- Long reload

        overheat_cap = 150, -- High capacity
        cooling_rate = 5, -- Slow cooling

        trigger_type = "time"
    },

    scatter = {
        name = "Scatter Frame",
        description = "Chaotic shotgun spread.",

        cast_block_size = 5,
        shuffle = true, -- Random card order
        spread_angle = 45, -- Projectiles spread out

        cast_cooldown = 4.0,
        overheat_cap = 80,
        cooling_rate = 15,

        -- Trigger: Fires after moving X distance
        trigger_type = "movement",
        movement_threshold = 10 -- meters
    },

    ritual = {
        name = "Ritual Frame",
        description = "Power at a price.",

        cast_block_size = 3,
        shuffle = false,
        cast_cooldown = 1.0, -- Very fast internal CD

        overheat_cap = 100,
        cooling_rate = 20,

        -- Trigger: Fires on Kill
        trigger_type = "kill",

        -- Cost per trigger (Risk/Reward)
        cost = { hp_pct = 2 } -- Costs 2% HP to fire
    },

    reactive = {
        name = "Reactive Frame",
        description = "Defensive retaliation.",

        cast_block_size = 4,
        shuffle = true,
        cast_cooldown = 0.5, -- Near instant reaction

        overheat_cap = 60,
        cooling_rate = 30, -- Cools very fast

        -- Trigger: Fires when YOU take damage
        trigger_type = "on_hit"
    }
}

return WandFrames
