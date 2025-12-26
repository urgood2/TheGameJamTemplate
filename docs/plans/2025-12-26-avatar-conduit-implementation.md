# Avatar of the Conduit - Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement the Avatar of the Conduit with lightning resistance, damage boost, and Conduit Charge system.

**Architecture:** Data-driven avatar definition + new trigger handler + new proc effect. Signal emission for damage tracking. Decay timer managed by avatar system.

**Tech Stack:** Lua, signal system (hump.signal), timer system, combat system stats.

---

## Task 1: Add Avatar Definition

**Files:**
- Modify: `assets/scripts/data/avatars.lua:151-152` (after bloodgod, before closing brace)

**Step 1: Add the conduit avatar entry**

Insert after line 151 (after the closing `}` of bloodgod):

```lua
    conduit = {
        name = "Avatar of the Conduit",
        description = "Pain becomes power. Lightning becomes you.",

        unlock = {
            chain_lightning_propagations = 20
        },

        effects = {
            {
                type = "stat_buff",
                stat = "lightning_resist_pct",
                value = 30
            },
            {
                type = "stat_buff",
                stat = "lightning_modifier_pct",
                value = 30
            },
            {
                type = "proc",
                trigger = "on_physical_damage_taken",
                effect = "conduit_charge",
                config = {
                    damage_per_stack = 10,
                    max_stacks = 20,
                    damage_bonus_per_stack = 5,
                    decay_interval = 5.0
                }
            }
        }
    },
```

**Step 2: Verify syntax**

Run: `luac -p assets/scripts/data/avatars.lua`
Expected: No output (success)

**Step 3: Commit**

```bash
git add assets/scripts/data/avatars.lua
git commit -m "feat(avatar): add Avatar of the Conduit definition"
```

---

## Task 2: Track Chain Lightning Propagations

**Files:**
- Modify: `assets/scripts/wand/wand_actions.lua:1209-1210` (after `totalChainsDone = totalChainsDone + 1`)

**Step 1: Add propagation tracking**

After line 1210 (`totalChainsDone = totalChainsDone + 1`), add:

```lua
        -- Track chain propagation for avatar unlock
        local playerScript = context and context.playerScript
        if playerScript then
            local AvatarSystem = require("wand.avatar_system")
            AvatarSystem.record_progress(playerScript, "chain_lightning_propagations", 1)
        end
```

**Step 2: Verify syntax**

Run: `luac -p assets/scripts/wand/wand_actions.lua`
Expected: No output (success)

**Step 3: Commit**

```bash
git add assets/scripts/wand/wand_actions.lua
git commit -m "feat(avatar): track chain lightning propagations for Conduit unlock"
```

---

## Task 3: Emit player_damaged Signal with Damage Type

**Files:**
- Modify: `assets/scripts/combat/projectile_system.lua:1838-1839` (after hp_lost tracking, before `else`)

**Step 1: Add signal emission**

After line 1838 (after the `log_warn` else block closing), before line 1839 (`end`), add:

```lua
            -- Emit player_damaged signal for avatar procs
            local signal = require("external.hump.signal")
            signal.emit("player_damaged", targetEntity, {
                amount = finalDamage,
                damage_type = dmgType
            })
```

The full block (lines 1830-1840) should now look like:

```lua
        -- Track avatar progress with actual damage dealt
        if data.faction == "enemy" and targetCombatActor and targetCombatActor.side == 1 then
            local AvatarSystem = require("wand.avatar_system")
            local playerScript = getScriptTableFromEntityID(targetEntity)
            if playerScript then
                AvatarSystem.record_progress(playerScript, "hp_lost", finalDamage)
            else
                log_warn("Player entity missing script table; avatar progress not tracked")
            end

            -- Emit player_damaged signal for avatar procs
            local signal = require("external.hump.signal")
            signal.emit("player_damaged", targetEntity, {
                amount = finalDamage,
                damage_type = dmgType
            })
        end
```

**Step 2: Verify syntax**

Run: `luac -p assets/scripts/combat/projectile_system.lua`
Expected: No output (success)

**Step 3: Commit**

```bash
git add assets/scripts/combat/projectile_system.lua
git commit -m "feat(avatar): emit player_damaged signal with damage type"
```

---

## Task 4: Add conduit_charge Proc Effect

**Files:**
- Modify: `assets/scripts/wand/avatar_system.lua:63-65` (add to PROC_EFFECTS table)

**Step 1: Add the conduit_charge effect**

After line 64 (after the `poison_spread` closing `end,`), add:

```lua
    --- Initialize Conduit Charge system with decay timer
    --- @param player table Player script table
    --- @param effect table Effect definition with .config
    conduit_charge = function(player, effect)
        local config = effect.config or {}
        local decay_interval = config.decay_interval or 5.0
        local bonus_per_stack = config.damage_bonus_per_stack or 5

        -- Initialize stack counter
        player.conduit_stacks = 0

        -- Start decay timer
        local timer = require("core.timer")
        timer.every_opts({
            delay = decay_interval,
            action = function()
                if player.conduit_stacks and player.conduit_stacks > 0 then
                    player.conduit_stacks = player.conduit_stacks - 1

                    -- Remove one stack's worth of bonus
                    local combatActor = player.combatTable
                    if combatActor and combatActor.stats then
                        combatActor.stats:add_add_pct("all_damage_pct", -bonus_per_stack)
                        combatActor.stats:recompute()
                    end
                end
            end,
            tag = "conduit_decay",
            group = "avatar_conduit"
        })
    end,
```

**Step 2: Verify syntax**

Run: `luac -p assets/scripts/wand/avatar_system.lua`
Expected: No output (success)

**Step 3: Commit**

```bash
git add assets/scripts/wand/avatar_system.lua
git commit -m "feat(avatar): add conduit_charge proc effect with decay timer"
```

---

## Task 5: Add on_physical_damage_taken Trigger Handler

**Files:**
- Modify: `assets/scripts/wand/avatar_system.lua:128-130` (add to TRIGGER_HANDLERS table)

**Step 1: Add the trigger handler**

After line 129 (after the `distance_moved_5m` closing `end,`), add:

```lua
    --- Trigger when player takes physical damage
    --- @param handlers SignalGroup Signal group for cleanup
    --- @param player table Player script table
    --- @param effect table Effect definition with .config
    on_physical_damage_taken = function(handlers, player, effect)
        local config = effect.config or {}
        local damage_per_stack = config.damage_per_stack or 10
        local max_stacks = config.max_stacks or 20
        local bonus_per_stack = config.damage_bonus_per_stack or 5

        handlers:on("player_damaged", function(entity, data)
            -- Only process physical damage
            if data.damage_type ~= "physical" then return end

            local stacks_gained = math.floor((data.amount or 0) / damage_per_stack)
            if stacks_gained < 1 then return end

            -- Get or create conduit state
            player.conduit_stacks = player.conduit_stacks or 0
            local old_stacks = player.conduit_stacks
            player.conduit_stacks = math.min(max_stacks, old_stacks + stacks_gained)
            local actual_gained = player.conduit_stacks - old_stacks

            if actual_gained > 0 then
                -- Apply damage bonus
                local combatActor = player.combatTable
                if combatActor and combatActor.stats then
                    combatActor.stats:add_add_pct("all_damage_pct", actual_gained * bonus_per_stack)
                    combatActor.stats:recompute()
                end
            end
        end)
    end,
```

**Step 2: Verify syntax**

Run: `luac -p assets/scripts/wand/avatar_system.lua`
Expected: No output (success)

**Step 3: Commit**

```bash
git add assets/scripts/wand/avatar_system.lua
git commit -m "feat(avatar): add on_physical_damage_taken trigger handler"
```

---

## Task 6: Add Conduit Cleanup to cleanup_procs

**Files:**
- Modify: `assets/scripts/wand/avatar_system.lua:191-197` (enhance cleanup_procs function)

**Step 1: Add conduit-specific cleanup**

Replace the current `cleanup_procs` function (lines 191-197) with:

```lua
--- Cleanup all proc handlers for player
--- @param player table Player script table
function AvatarSystem.cleanup_procs(player)
    local state = player and player.avatar_state
    if state and state._proc_handlers then
        state._proc_handlers:cleanup()
        state._proc_handlers = nil
    end

    -- Clean up Conduit Charge stacks and timer
    if player.conduit_stacks and player.conduit_stacks > 0 then
        local combatActor = player.combatTable
        if combatActor and combatActor.stats then
            -- Remove all stacks' worth of bonus (5% per stack)
            combatActor.stats:add_add_pct("all_damage_pct", -player.conduit_stacks * 5)
            combatActor.stats:recompute()
        end
        player.conduit_stacks = 0
    end

    -- Kill the decay timer
    local timer = require("core.timer")
    timer.kill_group("avatar_conduit")
end
```

**Step 2: Verify syntax**

Run: `luac -p assets/scripts/wand/avatar_system.lua`
Expected: No output (success)

**Step 3: Commit**

```bash
git add assets/scripts/wand/avatar_system.lua
git commit -m "feat(avatar): add Conduit Charge cleanup to cleanup_procs"
```

---

## Task 7: Add Unit Tests

**Files:**
- Modify: `assets/scripts/tests/test_avatar_system.lua` (add new tests at end before final print)

**Step 1: Add conduit unlock test**

Add before the final `print("All avatar system tests passed!")`:

```lua
    -- Test: Conduit avatar unlocks via chain_lightning_propagations metric
    reset()
    local playerConduit = {}
    for _ = 1, 20 do
        AvatarSystem.record_progress(playerConduit, "chain_lightning_propagations", 1)
    end
    assert_true(playerConduit.avatar_state.unlocked.conduit,
        "conduit should unlock after 20 chain_lightning_propagations")
    print("✓ Conduit unlock test passed")

    -- Test: Conduit stat buffs applied on equip
    reset()
    local playerConduit2 = {
        avatar_state = { unlocked = { conduit = true } },
        combatTable = {
            stats = {
                _values = {},
                add_add_pct = function(self, stat, value)
                    self._values[stat] = (self._values[stat] or 0) + value
                end,
                recompute = function(self) end,
                get = function(self, stat) return self._values[stat] or 0 end
            }
        }
    }
    AvatarSystem.equip(playerConduit2, "conduit")
    assert_equals(playerConduit2.combatTable.stats._values["lightning_resist_pct"], 30,
        "conduit should add 30% lightning resistance")
    assert_equals(playerConduit2.combatTable.stats._values["lightning_modifier_pct"], 30,
        "conduit should add 30% lightning damage")
    print("✓ Conduit stat buffs test passed")
```

**Step 2: Run tests**

Run: `lua assets/scripts/tests/test_avatar_system.lua`
Expected: All tests pass including new conduit tests

**Step 3: Commit**

```bash
git add assets/scripts/tests/test_avatar_system.lua
git commit -m "test(avatar): add Conduit avatar unlock and stat buff tests"
```

---

## Task 8: Run Full Test Suite

**Step 1: Run all tests**

Run: `just test`
Expected: All tests pass

**Step 2: Run ASAN tests (if available)**

Run: `just test-asan`
Expected: All tests pass without memory errors

---

## Task 9: Final Commit

**Step 1: Verify all changes**

Run: `git status`
Expected: Working tree clean (all changes committed)

**Step 2: Tag for reference (optional)**

```bash
git tag avatar-conduit-v1
```
