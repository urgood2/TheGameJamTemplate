# Wand Cumulative State & Player Stats Integration Plan

## Goal Description
Implement the requirements from `wand_cumulative_state_plan.md` to track cumulative wand state (per cycle and per block) and integrate external player stats into the wand execution flow. This will ensure that gameplay systems (buffs, status effects) correctly influence wand behavior.

## User Review Required
> [!IMPORTANT]
> **Player Stats Schema**: I am assuming a simple additive/multiplicative schema for player stats (e.g., `damage_mult`, `speed_add`, `cast_delay_mult`). Please confirm if there is an existing component I should align with, otherwise I will define a standard table structure.

## Proposed Changes

### Wand System

#### [MODIFY] [wand_modifiers.lua](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/wand/wand_modifiers.lua)
- Add `WandModifiers.mergePlayerStats(aggregate, playerStats)`:
    - Merges external player stats into the modifier aggregate.
    - Handles damage multipliers, speed modifiers, spread reductions, etc.
- Update `applyToAction` to respect merged stats if not already covered.

#### [MODIFY] [wand_executor.lua](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/wand/wand_executor.lua)
- Update `createExecutionContext`:
    - Fetch `playerStats` (mocked or from component) and include in context.
- Update `executeCastBlock`:
    - Call `WandModifiers.mergePlayerStats` after aggregating block modifiers.
    - Pass the merged modifiers to `WandActions.execute`.
- Update `execute`:
    - Track cumulative stats per cycle (total mana spent, total projectiles, etc.).
    - Store `lastExecutionState` in `wandState` for debugging/telemetry.

### Testing

#### [NEW] [wand_cumulative_test.lua](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/assets/scripts/tests/wand_cumulative_test.lua)
- A headless Lua test harness (similar to `card_eval_order_test.lua`) that:
    - Constructs a wand and deck.
    - Defines synthetic `playerStats` (e.g., double damage, half cast delay).
    - Runs `simulate_wand` and then a mock execution loop.
    - Asserts that final action properties reflect both card modifiers and player stats.
    - Asserts that cumulative state (e.g., total cast delay) is correctly tracked.

## Verification Plan

### Automated Tests
- Run the new `wand_cumulative_test.lua` using the Lua interpreter.
    - Command: `lua assets/scripts/tests/wand_cumulative_test.lua` (Note: requires setting up package path correctly or running from project root with appropriate environment).
    - *Alternative*: If `lua` command is not available or lacks dependencies, I will run it via the game engine's test runner if available, or just rely on `card_eval_order_test.lua` style execution.

### Manual Verification
- Since I cannot run the full game engine, I will rely heavily on the `wand_cumulative_test.lua` output which prints the resolved properties of actions.
- I will verify:
    - Base damage vs. Resolved damage (with player stats).
    - Cast delay modifications.
    - Cumulative counters.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
