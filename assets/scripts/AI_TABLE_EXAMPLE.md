["entity_types"] = {
  ["kobold"] = {
    ["initial"] = {
      ["has_food"] = true
      ["enemyvisible"] = false
      ["hungry"] = true
    }
    ["goal"] = {
      ["hungry"] = false
    }
  }
}
["actions"] = {
  ["eat"] = {
    ["pre"] = {
      ["hungry"] = true
    }
    ["start"] = function: 0x147e25880
    ["update"] = function: 0x147e25b20
    ["cost"] = 1
    ["finish"] = function: 0x147e25b50
    ["name"] = eat
    ["post"] = {
      ["hungry"] = false
    }
  }
}
["blackboard_init"] = {
  ["kobold"] = function: 0x158b5f350
}
["goal_selectors"] = {
  ["kobold"] = function: 0x147e26010
}
["worldstate_updaters"] = {
  ["enemy_sight"] = function: 0x157fd0070
  ["hunger_check"] = function: 0x157fc8e20
}