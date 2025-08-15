traits = {
  AntLikeBuff = {
    trigger = { on = "OnDeath" },
    target  = { fn = "RandomAllies", n = 1 },
    effects = {
      { op = "ModifyStats", params = {
          { stat = "MaxHP", add = 10 },
          { stat = "OffensiveAbility", add = 5 },
      }},
    }
  }
}

spells = {
  ShiverStrike = {
    trigger = { on = "OnCast" },
    target  = { fn = "TargetEnemy" },
    effects = {
      { op = "DealDamage", params = { weaponScalar = 1.10, flatCold = 25 } },
      { op = "ApplyStatus", params = { chilled = true } },
      { op = "ApplyRR",     params = { rr = 25 } }, -- Type1 RR for Cold in loader
      { op = "KillExecute" },
    },
    cooldown = 4.0
  }
}