local M = {
  movement = {
    eight_way = true,
    diagonal = {
      allow = true,
      corner_cutting = "block_if_either_cardinal_blocked",
    },
    bindings = {
      north = { "W", "Up", "Numpad8" },
      south = { "S", "Down", "Numpad2" },
      west = { "A", "Left", "Numpad4" },
      east = { "D", "Right", "Numpad6" },
      northwest = { "Q", "Numpad7" },
      northeast = { "E", "Numpad9" },
      southwest = { "Z", "Numpad1" },
      southeast = { "C", "Numpad3" },
    },
  },

  turn_cost = {
    base_energy = 100,
    move = 100,
    melee = 100,
    cast = 100,
    use_item = 100,
    stairs = 100,
    wait = 100,
    pickup = 100,
    drop = 100,
    pickup_full_cost = 0,
  },

  speed_energy = {
    fast = 200,
    normal = 100,
    slow = 50,
  },

  fov = {
    algorithm = "recursive_shadowcasting",
    radius = 8,
    shape = "circle",
    opaque_tiles = { "wall" },
    diagonal_blocking = "no_corner_peek",
    explored_persists = true,
  },

  combat = {
    melee = {
      hit_chance = {
        base = 70,
        dex_mult = 2,
        enemy_evasion_mult = 2,
        clamp_min = 5,
        clamp_max = 95,
      },
      damage = {
        formula = "weapon_base + str_modifier + species_bonus",
        round = "floor",
      },
    },
    magic = {
      hit_chance = {
        base = 80,
        skill_mult = 3,
        clamp_min = 5,
        clamp_max = 95,
      },
      damage = {
        formula = "spell_base * (1 + int * 0.05) * species_multiplier",
        round = "floor",
      },
    },
    defense = {
      armor = {
        formula = "max(0, floor(raw - armor_value))",
      },
      evasion = {
        formula = "10 + (dex * 2) + dodge_skill",
      },
    },
  },

  stats = {
    starting_level = 1,
    base_attributes = { str = 10, dex = 10, int = 10 },
    hp = {
      base = 10,
      species_mod_field = "species_hp_mod",
      level_multiplier = 0.15,
      round = "floor",
    },
    mp = {
      base = 5,
      species_mod_field = "species_mp_mod",
      level_multiplier = 0.10,
      round = "floor",
    },
    xp = {
      base = 10,
      species_xp_mod_field = "species_xp_mod",
    },
  },

  floors = {
    total = 5,
    max_gen_attempts = 50,
    floors = {
      [1] = {
        width = 15,
        height = 15,
        enemies_min = 5,
        enemies_max = 8,
        shop = true,
        altar = false,
        miniboss = false,
        boss = false,
        stairs_down = true,
        stairs_up = false,
      },
      [2] = {
        width = 20,
        height = 20,
        enemies_min = 8,
        enemies_max = 12,
        shop = false,
        altar = true,
        miniboss = false,
        boss = false,
        stairs_down = true,
        stairs_up = true,
      },
      [3] = {
        width = 20,
        height = 20,
        enemies_min = 10,
        enemies_max = 15,
        shop = false,
        altar = true,
        miniboss = false,
        boss = false,
        stairs_down = true,
        stairs_up = true,
      },
      [4] = {
        width = 25,
        height = 25,
        enemies_min = 12,
        enemies_max = 18,
        shop = false,
        altar = true,
        miniboss = true,
        boss = false,
        stairs_down = true,
        stairs_up = true,
      },
      [5] = {
        width = 15,
        height = 15,
        enemies_min = 5,
        enemies_max = 5,
        shop = false,
        altar = false,
        miniboss = false,
        boss = true,
        stairs_down = false,
        stairs_up = true,
      },
    },
  },

  inventory = {
    capacity = 20,
    equip_slots = { "weapon", "armor" },
    pickup = {
      cost = 100,
      full_policy = "block",
      full_cost = 0,
    },
    drop = {
      cost = 100,
    },
    use = {
      cost = 100,
    },
  },

  scrolls = {
    label_pool = {
      "ashen",
      "scarlet",
      "ivory",
      "cobalt",
      "viridian",
      "umber",
      "cerulean",
      "amber",
      "ochre",
      "saffron",
      "violet",
      "teal",
    },
    labels_unique = true,
    labels_persist = true,
    identify_on_use = true,
    identify_scroll_reveals_one = true,
    identification_scope = "all_of_type",
  },

  boss = {
    floor = 5,
    arena = {
      width = 15,
      height = 15,
      exploration = false,
    },
    guards = 5,
    stats = {
      hp = 100,
      damage = 20,
      speed = "slow",
    },
    phases = {
      {
        id = 1,
        hp_pct_min = 0.50,
        behavior = "melee_only",
      },
      {
        id = 2,
        hp_pct_min = 0.25,
        behavior = "summon_guards",
        summon_count = 2,
        summon_interval_turns = 5,
      },
      {
        id = 3,
        hp_pct_min = 0.00,
        behavior = "berserk",
        damage_multiplier = 1.5,
      },
    },
    win_condition = "boss_hp_zero",
    post_win = "victory_screen_then_main_menu",
  },

  backtracking = {
    allowed = true,
    stairs_up_on_floors = { 2, 3, 4, 5 },
    stairs_down_on_floors = { 1, 2, 3, 4 },
    persist_floor_state = true,
    explored_persists = true,
  },
}

return M
