# Descent Spec Snapshot (Gameplay Constants)

This file is the human-readable source of truth for Descent gameplay constants. It must be mirrored in `assets/scripts/descent/spec.lua`.

## 1) Movement + Input
- Movement model: 8-way.
- Diagonal movement is allowed, but **no corner-cutting**: a diagonal move is blocked if either adjacent cardinal tile is blocked.
- All movement directions cost the same turn cost (see Turn Costs).
- Key bindings (primary):
  - North: `W` / `Up Arrow` / `Numpad 8`
  - South: `S` / `Down Arrow` / `Numpad 2`
  - West: `A` / `Left Arrow` / `Numpad 4`
  - East: `D` / `Right Arrow` / `Numpad 6`
  - Northwest: `Q` / `Numpad 7`
  - Northeast: `E` / `Numpad 9`
  - Southwest: `Z` / `Numpad 1`
  - Southeast: `C` / `Numpad 3`

## 2) Turn Costs + Action Economy
- Base action cost: **100 energy**.
- Player actions:
  - Move: 100
  - Melee attack: 100
  - Spell cast: 100
  - Item use: 100
  - Stairs (up/down): 100
  - Wait/skip: 100
  - Pickup item: 100
  - Drop item: 100
- If a pickup is attempted while inventory is full, it fails and **costs 0 energy**.

Enemy speed energy per player turn (energy-based system):
- fast: 200
- normal: 100
- slow: 50
- Enemies act while `energy >= 100`, spending 100 per action.

## 3) FOV (Field of View)
- Algorithm: recursive shadowcasting.
- Radius: **8 tiles**, circular (distance check uses `dx*dx + dy*dy <= r*r`).
- Opaque tiles: walls only (for MVP).
- Diagonal visibility uses the same corner rules as movement: no corner-peeking through two blocked adjacent cardinals.
- Explored tiles persist per floor and remain dimly visible when not currently in FOV.

## 4) Combat
### 4.1 Hit Chance
- Melee hit chance:
  - `hit = 70 + (dex * 2) - (enemy_evasion * 2)`
  - Clamp to **[5, 95]**.
- Ranged/magic hit chance:
  - `hit = 80 + (skill * 3)`
  - Clamp to **[5, 95]**.

### 4.2 Damage
- Melee raw damage:
  - `raw = weapon_base + str_modifier + species_bonus`
- Magic raw damage:
  - `raw = spell_base * (1 + int * 0.05) * species_multiplier`
- Rounding: **floor to integer** after all multipliers.
- Armor reduction:
  - `final = max(0, floor(raw - armor_value))`

### 4.3 Defense / Evasion
- Evasion chance baseline:
  - `evasion = 10 + (dex * 2) + dodge_skill`
- In MVP, `enemy_evasion` is the defender's evasion value.

## 5) HP / MP / XP
### 5.1 Starting Stats
- Starting level: **1**.
- Base attributes (Human, MVP):
  - STR 10, DEX 10, INT 10.

### 5.2 HP / MP Scaling
- `max_hp = (10 + species_hp_mod) * (1 + level * 0.15)`
- `max_mp = (5 + species_mp_mod) * (1 + level * 0.10)`
- Rounding: **floor to integer** after multiplication.

### 5.3 XP Thresholds
- `xp_for_level_n = 10 * n * species_xp_mod`

## 6) Floors
- Total floors: **5**.
- Max generation attempts per floor before fallback layout: **50**.

Per-floor size + quotas:
- Floor 1: **15x15**, enemies **5-8**, guaranteed **shop**.
- Floor 2: **20x20**, enemies **8-12**, guaranteed **altar** (first).
- Floor 3: **20x20**, enemies **10-15**, guaranteed **altar** (second).
- Floor 4: **25x25**, enemies **12-18**, guaranteed **altar** (third) + **miniboss**.
- Floor 5: **15x15** boss arena, **5 guards + boss**.

Guaranteed placements:
- Every floor has a player start tile.
- Floors 1-4 have stairs down.
- Floors 2-5 have stairs up (backtracking enabled).

## 7) Inventory
- Inventory capacity: **20 slots** (list inventory, no grid/tetris).
- Equip slots (MVP): **weapon**, **armor**.
- Pickup rules:
  - If space available, pickup succeeds and costs 100 energy.
  - If full, pickup fails and costs 0 energy.
- Drop rules:
  - Dropping places the item on the player's current tile and costs 100 energy.

## 8) Scroll Identification
- Label pool size: **12** labels.
- Label pool (explicit list):
  - ashen, scarlet, ivory, cobalt, viridian, umber,
    cerulean, amber, ochre, saffron, violet, teal
- Each scroll type is assigned a unique label per run.
- Labels persist for the entire run.
- Using any scroll **identifies that scroll type** for the rest of the run.
- Scroll of Identify (when added) reveals **one** unknown scroll type.

## 9) Boss
- Boss floor: **Floor 5** (arena only, no exploration).
- Boss stats (MVP): **100 HP**, **20 base damage**, speed **slow**.
- Phases:
  1. Phase 1: **100% - 50% HP**, melee only.
  2. Phase 2: **50% - 25% HP**, summon **2** enemies every **5** turns.
  3. Phase 3: **25% - 0% HP**, berserk (**+50% damage**).
- Win condition: boss HP reaches **0**.
- Post-win: transition to Victory screen, then return to main menu.

## 10) Backtracking
- Backtracking is **allowed**.
- Stairs up/down connect adjacent floors.
- Floor state persists when revisited:
  - Layout unchanged
  - Explored tiles retained
  - Remaining enemies/items remain as last seen
