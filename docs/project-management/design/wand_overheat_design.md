# Design Proposal: Alternative Wand Resources ("No Mana")

The goal is to remove "mana management" as a hard stop resource while retaining a penalty for overloading wands. We keep the internal "mana" value (as "Load" or "Flux") but change how it affects the player.

## Core Concept: "Flux" & Overload
Instead of "Mana", the wand has **Flux Capacity**. Casting generates **Flux** (cost).
- **Under Capacity**: Wand functions normally.
- **Over Capacity**: Wand enters **Overload State**.

## Alternative Penalty Mechanics

### 1. The "Overheat" Mechanic (Recommended)
*Concept: Pushing the wand too hard makes it sluggish.*
- **Mechanism**: You can cast indefinitely, but exceeding Flux Capacity adds a massive multiplier to **Recharge Time** and **Cast Delay**.
- **Player Experience**: "I can fire this heavy nuke, but my wand will jam for 5 seconds afterwards."
- **Implementation**:
    - If `currentFlux > maxFlux`:
        - `cooldownMultiplier = 1 + (currentFlux - maxFlux) * penaltyFactor`
        - Apply to `totalCooldown`.

### 2. The "Instability" Mechanic
*Concept: Overloaded wands become wild and dangerous.*
- **Mechanism**: Exceeding capacity increases **Spread** and **Backfire Chance**.
- **Player Experience**: "Spamming this wand makes it spray wildly and might hurt me."
- **Implementation**:
    - `spreadAdded = (currentFlux / maxFlux) * 30 degrees`
    - `selfDamageChance = max(0, (currentFlux - maxFlux) / 100)`

### 3. The "Time Debt" Mechanic
*Concept: Borrowing time from the future.*
- **Mechanism**: Costs are paid in **Cooldown Seconds** directly, not a resource pool.
- **Player Experience**: "Every spell adds to a 'cooldown bar'. If the bar fills up, I'm silenced until it drains."
- **Implementation**:
    - Convert `mana_cost` to `time_cost` (e.g., 10 mana = 0.1s).
    - Add to `cooldownRemaining`.

## Recommendation
**Option 1 (Overheat)** aligns best with the request for "slow casting" and is easiest to implement with the current `WandExecutor` structure. We simply invert the "insufficient mana" check to a "penalty application" step.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
