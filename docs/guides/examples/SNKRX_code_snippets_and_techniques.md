# Combat Patterns Reference (Full)

This document contains **20 reusable combat/gameplay patterns** distilled from the Seeker/Enemy scripts. Each entry includes a short **Why** and a **drop‑in snippet** you can adapt.

---

## 1) Push/Knockback as a tiny state machine (velocity-based exit)

**Why:** Robust knockback that naturally ends when motion dies out.

```lua
-- Push API
function Unit:start_push(force, dir, opts)
  local n = opts and opts.mult or 1.0
  self.being_pushed      = true
  self.steering_enabled  = false
  self.push_force        = n*force
  self.push_invulnerable = opts and opts.invuln or false

  self:apply_impulse(self.push_force*math.cos(dir), self.push_force*math.sin(dir))
  self:apply_angular_impulse(random:table{random:float(-12*math.pi, -4*math.pi), random:float(4*math.pi, 12*math.pi)})
  self:set_damping(1.5*(1/n))
  self:set_angular_damping(1.5*(1/n))
end

-- Call from update(dt)
function Unit:update_push_state(end_speed)
  if not self.being_pushed then return end
  if math.length(self:get_velocity()) < (end_speed or 25) then
    self.being_pushed      = false
    self.steering_enabled  = true
    self.push_invulnerable = false
    self:set_damping(0)
    self:set_angular_damping(0)
  end
end
```

---

## 2) Timer-driven status effects (start/stop hooks baked in)

**Why:** Consistent “apply X for Y seconds, then clean up.”

```lua
-- Generic timed status
function Status.apply(self, name, duration, on_start, on_end, key)
  key = key or name
  if on_start then on_start(self) end
  self[name] = true
  self.t:after(duration, function()
    self[name] = false
    if on_end then on_end(self) end
  end, key)
end

-- Examples
Status.apply(self, 'speed_boosting', 3.0,
  function(s) s.speed_boosting = love.timer.getTime() end,
  function(s) s.speed_boosting = false end,
  'speed_boost')

Status.apply(self, 'silenced', 4.0,
  function(s) s.silenced = true end,
  function(s) s.silenced = false end)
```

---

## 3) Multiplicative stat pipeline with one recompute point

**Why:** Sprinkle modifiers anywhere, compute once per frame.

```lua
function Unit:accumulate_mods()
  local mv = 1.0
  mv = mv * (self.speed_boosting_mvspd_m or 1)
  mv = mv * (self.slow_mvspd_m          or 1)
  mv = mv * (self.temporal_chains_mvspd_m or 1)
  mv = mv * (self.tank and 0.35 or 1)
  mv = mv * (self.deceleration_mvspd_m or 1)

  self.buff_mvspd_m = mv
  self.buff_def_m   = (self.seeping_def_m or 1)
end

-- In update:
self:accumulate_mods()
self:calculate_stats()  -- single source of truth
```

---

## 4) “Proc system” (chance-based triggers) centralized

**Why:** All the crit/stun/silence rolls are consistent and easy to extend.

```lua
Proc = {}
function Proc.roll(pct) return random:bool(pct) end

function Proc.critical(self, ctx)
  if not ctx.allow or ctx.is_dot or ctx.from_enemy then return 1 end
  if Proc.roll(ctx.crit_chance or 10) then
    -- VFX/SFX hooks here
    return ctx.crit_mult or 2
  end
  return 1
end

-- Example use inside hit():
local crit_mult = Proc.critical(self, { allow = main.current.player.critical_strike, is_dot = dot, from_enemy = from_enemy, crit_chance = 10, crit_mult = 2 })
local dmg = math.max(self:calculate_damage(base_damage) * crit_mult * (self.stun_dmg_m or 1), 0)
```

---

## 5) AIM/Steering cookbook (seek + wander + separation + facing)

**Why:** Decent enemies with 4 calls.

```lua
function Unit:steer_common(target_x, target_y, cfg)
  if self.steering_enabled == false then return end

  -- Primary goals
  self:seek_point(target_x, target_y)
  self:wander(cfg.wander_radius or 50, cfg.wander_distance or 100, cfg.wander_jitter or 20)

  -- Group behavior
  if cfg.separate_from then
    self:steering_separate(cfg.sep_radius or 16, cfg.separate_from)
  end

  -- Orientation
  if cfg.face_velocity then
    self:rotate_towards_velocity(cfg.face_lerp or 0.5)
  else
    self:rotate_towards_object(cfg.face_target or {x=target_x,y=target_y}, cfg.face_lerp or 0.5)
  end
end
```

---

## 6) “Boss scheduler” with `every/during/after` and visual telegraph

**Why:** Clean attack timelines + a free progress bar hook.

```lua
-- Schedule pattern
self.t:every(6, function()
  if self.silenced or self.barbarian_stunned then return end

  -- Telegraph phase
  self.t:during(2.0, function(dt)
    -- e.g., pull enemies to a point, spin up VFX, etc.
  end, function()
    -- Release phase
    -- e.g., emit projectiles / apply pushes
  end)

end, nil, nil, 'boss_attack')

-- Drawing a charge bar:
local t, c = self.t:get_timer_and_delay('boss_attack')
local n = (c and c > 0) and (t/c) or 0
-- draw n as [0..1] progress
```

---

## 7) Area sensors as first-class objects

**Why:** Reuse circles/rects for queries and visuals; keep them in sync.

```lua
-- Create and keep synced
self.area_sensor = Circle(self.x, self.y, 128)
-- In update:
if self.area_sensor then self.area_sensor:move_to(self.x, self.y) end

-- Queries
local enemies = self:get_objects_in_shape(self.area_sensor, main.current.enemies)
```

---

## 8) Pull/Push fields proportional to distance

**Why:** Forces that feel physical and scale nicely.

```lua
-- Pull all enemies toward (px,py) with strength falling off by distance
for _, e in ipairs(self:get_objects_in_shape(Circle(px, py, r), main.current.enemies)) do
  local ang = e:angle_to_point(px, py)
  local F   = math.remap(e:distance_to_point(px, py), 0, r, 400, 200)  -- inner stronger
  e:apply_steering_force(F, ang)
end
```

---

## 9) Staggered salvos with nested timers

**Why:** Easy “burst fire” patterns without writing a custom FSM.

```lua
-- 3-shot burst where each shot is offset by 0.15s * i
self.t:every({4, 6}, function()
  for i = 1, 3 do
    self.t:after(0.15*(i-1), function()
      local r = self.r
      -- spawn projectile at angle r
    end)
  end
end, nil, nil, 'burst_fire')
```

---

## 10) DOT engine with a single `every` + bounded ticks

**Why:** Reuse across burn/poison/void, consistent SFX/VFX, bounded lifetime.

```lua
function Unit:apply_dot(total_dmg, duration, color)
  local per_tick = (total_dmg / (duration / 0.25))
  self.t:every(0.25, function()
    self:hit(per_tick, nil, true)
    -- small VFX
  end, math.floor(duration / 0.25))
end
```

---

## 11) Collision responses as declarative handlers

**Why:** Keep logic readable by splitting by “what I hit”.

```lua
function Unit:on_collision_enter(other, contact)
  local hit_wall = other:is(Wall)
  local hit_enemy = table.any(main.current.enemies, function(v) return other:is(v) end)

  if hit_wall then
    self:bounce(contact:getNormal())
    if self.being_pushed then
      -- transfer impulse, tremor AOE, fracture shrapnel, etc.
    end
    if self.headbutter and self.headbutting then
      self.headbutting = false
    end
    return
  end

  if hit_enemy then
    if self.being_pushed and math.length(self:get_velocity()) > 60 then
      -- damage exchange + knockback + VFX
    elseif self.headbutting then
      -- shoulder charge logic
    end
    return
  end

  if other:is(Turret) then
    -- light knockback, minor damage, reset charge
  end
end
```

---

## 12) “Curses/Buffs” as a dispatch table

**Why:** Adding a new effect is just a new function.

```lua
local CURSES = {
  launcher = function(self, duration, push_force, launcher_ref)
    self.t:after(duration, function()
      self.launcher_push = push_force
      self.launcher      = launcher_ref
      self:start_push(random:float(50, 75)*self.launcher.knockback_m, random:table{0, math.pi, math.pi/2, -math.pi/2})
    end, 'launcher_curse')
  end,

  jester = function(self, duration, lvl3, ref)
    self.jester_cursed, self.jester_lvl3, self.jester_ref = true, lvl3, ref
    self.t:after(duration, function() self.jester_cursed = false end, 'jester_curse')
  end,

  -- add more here...
}

function Unit:curse(kind, duration, ...)
  buff1:play{pitch = random:float(0.65, 0.75), volume = 0.25}
  local f = CURSES[kind]
  if f then f(self, duration, ...) end
end
```

---

## 13) Telegraph + payoff with spring/flash hooks (FX hygiene)

**Why:** Highly readable, centralized juice.

```lua
function FX.hit_flash(self, mag, dur)
  self.hfx:use('hit', dur or 0.25, 200, 10)
end

function FX.spring_pulse(self, k, mag, damp)
  self.spring:pull(k or 0.15, mag or 200, damp or 10)
end
```

---

## 14) Target selection fallbacks (taunt/closest/player)

**Why:** Clean, deterministic target choice.

```lua
function Unit:choose_target()
  if self.taunted and not self.taunted.dead then return self.taunted end
  local p = main.current.player
  if self.boss then
    local enemies = main.current.main:get_objects_by_classes(main.current.enemies)
    if #enemies > 1 then
      local sx, sy = 0, 0
      for _, e in ipairs(enemies) do sx, sy = sx + e.x, sy + e.y end
      return { x = sx/#enemies, y = sy/#enemies } -- center mass
    end
  end
  return p
end
```

---

## 15) NaN guard on spawn (hardening)

**Why:** Prevents crashy edge cases.

```lua
local function is_nan(v) return tostring(v) == tostring(0/0) end

function SafeSpawned:init(args)
  self:init_game_object(args)
  if is_nan(self.x) or is_nan(self.y) then self.dead = true; return end
end
```

---

## 16) Death payload pipeline (loot/VFX/chain effects)

**Why:** Keep “on death” logic composable without giant if-trees.

```lua
function Unit:on_death(ctx)
  -- Always
  HitCircle{group = main.current.effects, x = self.x, y = self.y, rs = 12}:scale_down(0.3):change_color(0.5, self.color)

  -- Conditional payloads
  if ctx.drop_gold then
    trigger:after(0.01, function()
      if main.current.main.world then Gold{group = main.current.main, x = self.x, y = self.y} end
    end)
  end

  if ctx.spawn_mine then
    trigger:after(0.01, function()
      ExploderMine{group = main.current.main, x = self.x, y = self.y, color = blue[0], parent = self}
    end)
  end

  -- etc...
end
```

---

## 17) “Every multiplier” trick for difficulty/haste effects

**Why:** Dynamically speed up (or slow down) a scheduled loop.

```lua
-- Speed up a named every() loop by setting a multiplier (e.g., with level scaling)
self.t:set_every_multiplier('shooter', math.max(0.75, 1 - self.level*0.02))
```

---

## 18) Color telegraph via tween, then snap back

**Why:** Clear signal before a lunge/charge/shot.

```lua
self.headbutt_charging = true
self.t:tween(2.0, self.color, {r = fg[0].r, g = fg[0].g, b = fg[0].b}, math.cubic_in_out, function()
  self.t:tween(0.25, self.color, {r = orange[0].r, g = orange[0].g, b = orange[0].b}, math.linear)
  self.headbutt_charging = false
  -- perform the charge…
end)
```

---

## 19) Angle-aware bounce (cheap, readable)

**Why:** Immediate feel-good response off walls.

```lua
function Unit:bounce(n) -- n = contact:getNormal()
  local vx, vy = self:get_velocity()
  -- reflect velocity across normal n
  local dot = vx*n.x + vy*n.y
  self:set_velocity(vx - 2*dot*n.x, vy - 2*dot*n.y)
end
```

---

## 20) Staggered radial emission (rings, barrages, mines)

**Why:** Parametric bullet hell.

```lua
local function radial_emit(n, cb)
  for i = 1, n do
    local r = (i-1) * (math.pi*2/n)
    cb(r, i)
  end
end

-- Example:
radial_emit(8 + current_new_game_plus*2, function(r)
  EnemyProjectile{group = main.current.main, x = self.x, y = self.y, r = r, v = 140 + 3.5*self.level}
end)
```

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
