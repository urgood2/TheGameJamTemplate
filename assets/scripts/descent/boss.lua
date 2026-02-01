-- assets/scripts/descent/boss.lua
-- Boss AI + phases for Descent

local Boss = {}
Boss.__index = Boss

local spec = require("descent.spec")

local function phase_for_hp_pct(pct)
  local p1 = spec.boss.phases[1].hp_pct_min
  local p2 = spec.boss.phases[2].hp_pct_min
  if pct >= p1 then
    return 1
  end
  if pct >= p2 then
    return 2
  end
  return 3
end

local function clamp_hp(value)
  if value < 0 then return 0 end
  return value
end

function Boss.create()
  local cfg = spec.boss
  local self = setmetatable({}, Boss)
  self.hp_max = cfg.stats.hp
  self.hp = cfg.stats.hp
  self.base_damage = cfg.stats.damage
  self.damage_multiplier = 1.0
  self.phase = 1
  self.turns = 0
  self.alive = true
  return self
end

function Boss:is_dead()
  return not self.alive or self.hp <= 0
end

function Boss:update_phase()
  if self.hp_max <= 0 then
    return
  end
  local pct = self.hp / self.hp_max
  local new_phase = phase_for_hp_pct(pct)
  if new_phase ~= self.phase then
    self.phase = new_phase
  end

  if self.phase == 3 then
    self.damage_multiplier = spec.boss.phases[3].damage_multiplier or 1.5
  else
    self.damage_multiplier = 1.0
  end
end

function Boss:take_damage(amount)
  if self:is_dead() then
    return
  end
  self.hp = clamp_hp(self.hp - (amount or 0))
  if self.hp <= 0 then
    self.alive = false
  end
  self:update_phase()
end

function Boss:get_damage()
  return math.floor(self.base_damage * self.damage_multiplier)
end

function Boss:decide_action(turn_number)
  if self:is_dead() then
    return { type = "idle" }
  end

  local turn = turn_number or self.turns

  if self.phase == 2 then
    local interval = spec.boss.phases[2].summon_interval_turns or 5
    if interval > 0 and (turn % interval == 0) then
      return {
        type = "summon",
        count = spec.boss.phases[2].summon_count or 2,
      }
    end
  end

  return {
    type = "melee",
    damage = self:get_damage(),
  }
end

function Boss:tick(turn_number)
  if self:is_dead() then
    return { type = "idle" }
  end
  if turn_number then
    self.turns = turn_number
  else
    self.turns = self.turns + 1
  end
  return self:decide_action(self.turns)
end

return Boss
