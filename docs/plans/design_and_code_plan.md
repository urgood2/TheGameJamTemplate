# Design Content Plan

1. Content pipeline documentation audit (docs already exist)
   - Subtasks:
     - Review `docs/content-creation/` guides (`ADDING_*`, `CONTENT_OVERVIEW.md`) for drift against current data files; note any field changes or missing templates.
     - Update `docs/README.md` cross-links if new guides were added elsewhere.
     - Add a short changelog section to each guide to track revisions.
   - Prompt: “Diff `ADDING_CARDS.md` against current `assets/scripts/data/cards.lua` fields; list mismatches and propose minimal edits. Do not rewrite the guide unless fields changed.”
2. Card/tag consistency check (tags already present)
   - Subtasks:
     - Run an automated pass to list all tags used in `assets/scripts/data/cards.lua` and compare to the approved vocabulary; flag outliers.
     - Sample 10 cards per tag family to ensure bonuses in `docs/project-management/todos/TODO_design.md` are represented in data (note gaps, don’t retag everything).
     - Capture findings in a short report for future balance work.
   - Prompt: “Generate a tag frequency table from `cards.lua` and highlight any tag not in {Fire, Ice, Lightning, Poison, Arcane, Holy, Void, Projectile, AoE, Hazard, Summon, Buff, Debuff, Mobility, Defense, Brute}.”
3. Projectile preset verification (presets already exist)
   - Subtasks:
     - Audit `assets/scripts/data/projectiles.lua` to ensure the 12 planned presets exist and include required fields/tags.
     - Note any missing behavior coverage versus the plan (homing, bouncing, gravity, special) and log as gaps instead of redoing the file.
     - Sync `ADDING_PROJECTILES.md` examples if field names differ.
   - Prompt: “List which of the planned preset archetypes are missing or incomplete (basic/elemental/behavior/special) based on `projectiles.lua`; don’t duplicate existing entries.”
4. Joker and tag UX
   - Subtasks:
     - Inventory existing signals/UI surfaces for tag analysis and Jokers; identify where discovery feedback currently appears.
     - Write a designer how-to for wiring a new tag reaction and verifying it, referencing current signal names.
     - Draft tooltip copy guidance; avoid re-implementing systems already present.
   - Prompt: “Document the current signal names emitted for tag analysis and where they surface in UI; provide a minimal recipe to subscribe and test a new Joker reaction.”
5. Design-side testing guidance
   - Subtasks:
     - Extend `docs/project-management/design/TESTING_PLAN.md` with a concise checklist (spawn cards, view tag counts, trigger Jokers, capture telemetry, take screenshots) using existing debug panels (`ui/content_debug_panel.lua`).
     - Include commands/menus already available; no new tools.
   - Prompt: “Write a 10-step checklist designers can follow today to validate a new card end-to-end using current debug panels and commands.”
6. Visual direction notes
   - Subtasks:
     - Review current UI pack assets and shader presets to extract existing palette/icon/motion conventions; turn into guardrails.
     - Add guidance on pairing shaders with UI packs without requesting new art.
   - Prompt: “Summarize the existing UI pack’s palette, icon line weight, and hover motion, and state 6 do/don’t rules to maintain consistency when adding assets.”

# Code Implementation Plan

1. Close wand runtime gaps
   - Subtasks:
     - Implement target helper and facing logic (`findNearestEnemy`, homing fallback).
     - Standardize trigger emission (`on_player_attack`, `on_low_health`, choose signal vs direct calls) and document order.
     - Enforce overheat/resource penalties on parent and child casts; wire meta cards like `add_mana_amount`.
     - Call `TagEvaluator.evaluate_and_apply` on deck/board changes and wand load.
     - Add Lua smoke tests covering triggers, homing, overheat branch.
   - Prompt: “Add homing support by filling `findNearestEnemy` with distance/visibility checks and update facing; verify with a Lua test that a homing projectile retargets when the closest enemy changes.”
2. Non-projectile and on-hit actions
   - Subtasks:
     - Implement hazard creation, summons, teleport, knockback, chain lightning, AOE heal/shield, meta-resource hooks using `combat/action_api.lua`.
     - Add a scripted scenario per action type to validate (spawn enemies, trigger action, assert outcome).
   - Prompt: “Wire `chain_lightning` action to select up to N nearby enemies with diminishing damage; add a Lua scenario that spawns 3 dummies and asserts all are hit.”
3. Content validator and debug panel (already present)
   - Subtasks:
     - Review `assets/scripts/tools/content_validator.lua` and `ui/content_debug_panel.lua` for coverage against current schemas; add missing checks only if gaps are found.
     - Ensure gameplay init still invokes the validator in warning mode; add/adjust unit or smoke tests to cover any new rules.
   - Prompt: “List the current validation rules in `content_validator.lua`; propose only the missing ones (if any) needed for new fields introduced since the last update.”
4. UI asset pack system (implemented)
   - Subtasks:
     - Audit `systems/ui/ui_pack*.{hpp,cpp}` and `ui_pack_lua.cpp` to confirm they match the design doc; log discrepancies rather than rewriting.
     - Review the ImGui pack editor (`systems/ui/editor/pack_editor.*`) for usability gaps; note any missing features from the design doc.
     - Update docs/examples if API shape changed.
   - Prompt: “Compare the shipped UI pack API against the design doc; list any missing features (e.g., scale modes, editor affordances) without duplicating existing code.”
5. Shader preset lifecycle (implemented)
   - Subtasks:
     - Verify `assets/scripts/data/shader_presets.lua` contents and registry loading; ensure atlas uniform detection matches current shaders.
     - Extend `tests/unit/test_shader_presets.cpp` only if new preset behaviors are added; otherwise, document current coverage.
   - Prompt: “Run through the shader preset load/override flow and note any mismatches between doc and code; add a test only if a missing case is identified.”
6. Telemetry polish
   - Subtasks:
     - Review telemetry defaults in `assets/config.json` and current env override behavior in `telemetry.cpp`.
     - Add (or confirm) a Lua smoke script to call `telemetry.record` in native and web; ensure web debug overlay toggles still work.
     - Add a small test for disabled-path behavior if not already present.
   - Prompt: “Document the current telemetry configuration precedence (env vs config vs defaults) and propose a minimal test to ensure disabled mode remains a no-op.”
