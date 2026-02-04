-- assets/scripts/bargain/enemies/templates.lua

local templates = {
    rat = {
        id = "rat",
        name = "Rat",
        hp = 2,
        atk = 1,
        speed = 3,
        behavior = "skitter",
        floors = { 1, 2 },
    },
    goblin = {
        id = "goblin",
        name = "Goblin",
        hp = 3,
        atk = 1,
        speed = 2,
        behavior = "aggressive",
        floors = { 1, 2, 3 },
    },
    skeleton = {
        id = "skeleton",
        name = "Skeleton",
        hp = 4,
        atk = 2,
        speed = 1,
        behavior = "stalker",
        floors = { 3, 4, 5 },
    },
    boss = {
        id = "boss",
        name = "The Boss",
        hp = 12,
        atk = 3,
        speed = 1,
        behavior = "boss",
        floors = { 7 },
        is_boss = true,
    },
}

return templates
