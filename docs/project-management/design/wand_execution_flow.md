# Wand Execution Flow & Cooldown Mechanics

This document details how stats, modifiers, and cooldowns are applied during wand execution.

## 1. Execution Flow (Card-by-Card)

When `WandExecutor.execute(wandId)` is called, the following happens:

1.  **Context Creation**:
    *   A `context` object is created.
    *   **Player Stats** are fetched (e.g., `damage_mult`, `cast_speed`) and stored in `context.playerStats`.

2.  **Cast Block Construction**:
    *   The deck is iterated to build "Cast Blocks" (groups of cards to be executed together, e.g., 1 Action + Modifiers).
    *   **Modifiers** in each block are aggregated into a single `modifiers` object.
        *   *Example*: `Damage Mod (+10)` + `Speed Mod (+500)` -> `modifiers = { damageBonus=10, speedBonus=500, ... }`.
    *   **Player Stats Merge**: `WandModifiers.mergePlayerStats` is called.
        *   Player stats (e.g., `all_damage_pct = 100%`) are snapshotted into `modifiers.statsSnapshot`.

3.  **Action Execution (Per Card)**:
    *   For each **Action Card** in the block:
        *   **Base Stats**: Taken from the card definition (e.g., `Damage=10`, `Delay=50ms`).
        *   **Application**: `WandModifiers.applyToAction(actionCard, modifiers)` is called.
            *   **Damage**: `(Base + Mod.DamageBonus) * (1 + Player.DamagePct) * Player.DamageMult`.
            *   **Speed**: `(Base + Mod.SpeedBonus) * (1 + Player.SpeedPct)`.
            *   **Cast Delay**: `Base + Mod.CastDelayAdd`.
        *   **Result**: The action is executed (projectile fired) with these final values.
        *   **Cumulative Tracking**: `manaSpent` and `projectileCount` are updated.

4.  **Cast Delay Calculation (Per Block)**:
    *   After all actions in a block are executed:
        *   **Block Cast Delay** = Sum of delays from all actions in the block.
        *   **Player Cast Speed** is applied: `BlockDelay / (1 + CastSpeed/100)`.
        *   **Overheat Penalty** is applied (if mana is negative):
            *   `DeficitRatio = Abs(CurrentMana) / MaxFlux`
            *   `PenaltyMult = 1 + (DeficitRatio * 5.0)`
            *   `BlockDelay = BlockDelay * PenaltyMult`
        *   This delay is accumulated across all blocks.

## 2. Cooldown Application (Global, After All Blocks)

The "Cooldown" prevents the wand from being used again. It is applied **once after ALL blocks are executed**.

1.  **Total Cast Delay**:
    *   Sum of all block delays (with cast speed and overheat penalties already applied per-block).

2.  **Recharge Time** (Applied Once):
    *   `RechargeTime` = Wand's base recharge time.
    *   **Cooldown Reduction (CDR)**: Reduces the recharge time.
        *   `FinalRecharge = RechargeTime * (1 - Player.CDR / 100)`

3.  **Final Cooldown**:
    *   `TotalCooldown = TotalCastDelay + FinalRecharge`
    *   `state.cooldownRemaining = TotalCooldown`
    *   The wand cannot fire again until this timer reaches 0.

## Summary

- **Card Stats**: Base values from assets.
- **Modifiers**: Additive bonuses applied to specific actions.
- **Player Stats**: Multipliers applied to final action values (Damage) or per-block timings (Cast Speed) or global timings (CDR).
- **Cast Delay**: Accumulated per-block with cast speed and overheat penalties applied to each block.
- **Recharge Time**: Applied once at the end after all blocks are exhausted.
- **Cooldown**: A single global timer = (Total Cast Delay) + (Recharge Time).
