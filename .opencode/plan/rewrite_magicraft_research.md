# Plan: Rewrite Magicraft Research Files (POA Style)

**Objective**: Rewrite the existing `docs/magicraft-research/*.md` files to match the "Path of Achra (POA) Ultrawork" style found in `docs/poa_research/`. The goal is to transform loose research notes into high-density, actionable design documents with tables, statistical analysis, and implementation roadmaps.

## 1. Style Guidelines (POA Ultrawork)

Based on `docs/poa_research/Summary.md`, the target style includes:
*   **Executive Summary**: "Executive Snapshot" and "Quick Cheat Sheet" (already present, keep but refine).
*   **Data Density**: Heavy use of Markdown tables for taxonomy, comparisons, and distribution analysis.
*   **Design Insights**: Explicit callouts ("**Design Insight**", "**Why This Matters**") explaining *why* a mechanic exists.
*   **Implementation Focus**: "Implementation Roadmap" sections broken into Phases (Core, Combat, Polish).
*   **Code/Logic Snippets**: Pseudo-code for event loops, trigger chains, or complex logic.
*   **Archetype Analysis**: Concrete build examples with "Key Stats" and "Playstyle".

## 2. Research Requirements (Wiki)

Before rewriting, data must be gathered/verified from the [Magicraft Wiki](https://magicraft.fandom.com/).

| Topic | Wiki Page(s) | Data Needed |
| :--- | :--- | :--- |
| **Spells** | [Spells](https://magicraft.fandom.com/wiki/Spells) | Damage scaling, mana cost ranges, cooldowns, tags (Projectile, Summon, etc.). |
| **Wands** | [Wands](https://magicraft.fandom.com/wiki/Wands) | Slot counts, Mana Max, Mana Regen, Cast Delay, Recharge Time distributions. |
| **Relics** | [Relics](https://magicraft.fandom.com/wiki/Relics) | Stat bonuses, trigger effects, rarity distribution. |
| **Elements** | [Status Effects](https://magicraft.fandom.com/wiki/Status_Effects) | Tick rates, duration, removal conditions, interaction rules (e.g., Wet + Cold). |

## 3. File-by-File Rewrite Plan

### A. `docs/magicraft-research/Summary.md`
*   **Current**: High-level snapshot, setup checklist.
*   **New Sections**:
    *   **Core Design Philosophy**: Deep dive into "Per-Wand Mana", "Left-to-Right Execution", "Volley/Fuse Logic".
    *   **Stat/Resource Analysis**: Table showing Mana vs. Cooldown trade-offs.
    *   **Implementation Roadmap**:
        *   Phase 1: Wand Pipeline (Slots, Mana, Regen).
        *   Phase 2: Projectile Logic (Volley, Fuse, Homing).
        *   Phase 3: Synergies (Fusion, Passives).
    *   **Event Bus Definition**: Pseudo-code for the `on_cast`, `on_hit`, `on_mana_drain` loop.

### B. `docs/magicraft-research/Spells.md`
*   **Current**: Taxonomy list, key payloads.
*   **New Sections**:
    *   **Spell Taxonomy Table**: Columns for `Name | Type | Cost | Scale | Tags | Implementation Complexity`.
    *   **Logic Patterns**: Pseudo-code for `Volley` (parallel execution) and `Fuse` (instant next-slot).
    *   **Trigger Frequency Analysis**: Table of `On Hit` vs `On Kill` vs `On Cast` prevalence.

### C. `docs/magicraft-research/Wands.md`
*   **Current**: (Assumed basic list).
*   **New Sections**:
    *   **Wand Archetypes**: Table comparing `Starter`, `Machine Gun` (Low delay, low mana), `Nuke` (High mana, slow), `Utility` (High slots).
    *   **Progression Curve**: Graph/Table of Slot count vs Rarity.
    *   **Mechanic: Recharge vs Delay**: Detailed breakdown of how the two cooldowns interact.

### D. `docs/magicraft-research/Elements.md`
*   **Current**: List of elements.
*   **New Sections**:
    *   **Status Effect Taxonomy**: Table with `Effect | Element | Behavior (DoT/CC) | Stack Limit | Removal`.
    *   **Reaction Matrix**: Table showing interactions (e.g., Poison + Venom, Fire + Oil).

### E. `docs/magicraft-research/Build_Archetypes.md`
*   **Current**: List of builds.
*   **New Sections**:
    *   **Structured Build Analysis**: Standardized format for each build:
        *   **Core Loop**: (The code/logic flow).
        *   **Key Components**: (Spells/Wands/Relics).
        *   **Stat Priorities**: (Mana Regen vs Damage vs Cooldown).
        *   **Weaknesses**: (e.g., "Prone to OOM", "Bad vs Bosses").

## 4. Execution Order

1.  **Gather Data**: Scrape/read Wiki for hard numbers (Stats, Costs).
2.  **Draft Summary**: Establish the "Design Philosophy" first.
3.  **Draft Spells & Wands**: These are the core mechanics.
4.  **Draft Elements & Archetypes**: Dependent on Spells/Wands.
5.  **Review**: Compare against `docs/poa_research/Summary.md` for tone and density.

## 5. Verification Checklist

*   [ ] Does `Summary.md` have an "Implementation Roadmap"?
*   [ ] Do tables exist for Stats, Spells, and Elements?
*   [ ] Are "Design Insights" explicitly called out?
*   [ ] Is there pseudo-code for complex logic (Volley/Fuse)?
