# Game Design Context (Load for Gameplay Questions)

Central tenet: **Do as little work as possible while maximizing gameplay depth and breadth.** Bias toward systemic leverage, reuse, and small shippable slices that combine into surprising outcomes.

## Default Decision Filters
- **Depth per hour:** Prefer changes that unlock many interactions (systems, combinators, content templates) over bespoke content.
- **Reuse first:** Extend existing systems (combat triggers, statuses, targeting, AI GOAP, UI helpers) before adding new bespoke mechanics.
- **Scope guardrails:** Aim for the smallest prototype that proves the loop; cut anything that does not create new decisions for the player.
- **Player choice density:** Prioritize knobs that multiply (risk/reward, positioning, timing, drafting) instead of raw stats or linear upgrades.
- **Maintainability:** Favour declarative data/Lua over C++ when possible; keep interfaces minimal and composable.

## Fast Patterns to Reach Depth
- **Trigger/effect stacking:** Compose existing events (`OnCast`, `OnHitResolved`, `OnTick`) with combinators (`seq`, `chance`, `scale_by_stat`) to create emergent builds.
- **Statuses over bespoke rules:** Implement new mechanics as timed statuses with stack modes (`replace`, `time_extend`, `count`) instead of new subsystems.
- **Targeting variety:** Add depth by varying targeters (random, cones, chains, proximity) rather than new effect atoms.
- **Economy of content:** Ship a small set of well-differentiated spells/items with clear roles; iterate via modifiers and mutators.
- **Difficulty tuning:** Adjust encounter pacing, cooldowns, and resource regen before adding new enemy types.

## Gameplay Programming Defaults
- **Lua-first:** Prototype in Lua; only move to C++ for perf or engine-level hooks.
- **Data > logic:** Prefer data tables/configs (spells, items, AI goals) over hardcoded logic.
- **Observability:** Add debug prints, Tracy zones, and small test harnesses when adding new interactions.
- **Interfaces:** Keep functions small, pure when possible, and driven by context (`ctx`) plus data arguments.

## When Asked for Ideas or Plans
1. Start from the central tenet: find the smallest change that creates new decisions.
2. Propose 2–3 options ordered by depth-per-work ratio.
3. Call out reuse points (existing statuses, event triggers, targeting helpers, UI components).
4. Suggest a test/proof step (quick Lua prototype, combat sim, or scripted encounter).

## Pointers to Detailed Docs
- Combat system: `docs/systems/combat/README.md` (+ triggers/effects/targeters/statuses).
- AI/behavior: `docs/systems/ai-behavior/AI_README.md`, `AI_CAVEATS.md`, `nodemap_README.md`.
- Rendering/UI helpers: `docs/api/ui_helper_reference.md`, `guides/examples/cheatsheet.md`.
- Testing/profiling: `TESTING_CHECKLIST.md`, `USING_TRACY.md`, `tools/DEBUGGING_LUA.md`.

Last updated: 2026-03-26
