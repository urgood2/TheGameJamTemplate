# Missing Framework Elements & Experimental Design Opportunities
## Comprehensive Analysis for Demo Spec Enhancement

**Date:** 2026-01-13
**Sources:** POA Research, SNKRX Research, Vampire Survivors Research, Roguelite Design Analysis (22 games + 9 experimental designs)

---

## Executive Summary

This analysis synthesizes research from Path of Achra, SNKRX, Vampire Survivors, and the comprehensive roguelite design framework to identify gaps in the current demo spec and evaluate experimental design opportunities. The key finding: **the demo spec leaves critical framework axes unspecified**, creating ambiguity that could lead to inconsistent player experiences. Additionally, several **underexplored design patterns** from the experimental analysis offer differentiation opportunities.

---

## Part 1: Missing Framework Elements Analysis

### 1.1 Pacing — "How long is a run? Wave timing?"

**Current Spec Status:** Partially defined
**Vertical Slice Plan:** "One 8–12 minute run: start → waves → shop → boss/elite → victory/defeat"

**Reference Game Comparison:**

| Game | Run Length | Wave/Level Timing |
|------|------------|-------------------|
| Vampire Survivors | 15-30 min | Continuous, density scales with time |
| SNKRX | 20-30 min | 25 levels, ~1 min each, boss every 6th |
| Brotato | 15-20 min | 20 waves, ~45-60 sec each |

**Gap Analysis:**

The demo spec defines total run length (8-12 min) but lacks:
- **Wave duration:** How long does each combat wave last? (SNKRX: ~1 min, Brotato: ~45-60 sec)
- **Wave count per stage:** How many waves before shop/boss? (SNKRX: 6 levels per boss)
- **Difficulty scaling formula:** How do enemy stats/spawns scale per wave?
- **Pacing triggers:** Fixed interval (XP-based) vs Event-triggered (room clears) vs Time-based (clock)

**Recommendation:**
```
Wave Structure:
- 3-4 waves per stage (45-60 sec each)
- Shop after each stage completion
- Boss/Elite every 3rd stage
- Total: ~6-8 stages × 3-4 waves = 18-32 waves per run
- Difficulty: Enemy HP +15%, spawn rate +10% per stage
```

**Framework Classification:**
- **Pacing:** Fixed interval (wave completion triggers choice) + Event-triggered (boss rewards)
- **Aligns with:** SNKRX, Brotato (hybrid pacing)

---

### 1.2 Negative Acquisition — "No curse/corruption system mentioned"

**Current Spec Status:** Undefined
**Reference Game Approaches:**

| Game | Negative Acquisition | Implementation |
|------|---------------------|----------------|
| Vampire Survivors | **None** | Pure power gain |
| SNKRX | **None** | Pure power gain |
| Path of Achra | **Optional** | Devil deals, cursed items with drawbacks |
| Hades | **Optional** | Chaos gates cost HP for temp debuff → perm buff |
| Curse of Dead Gods | **Forced** | Corruption accumulates regardless |
| Isaac | **Optional + Coupled** | Devil deals (choice), Soy Milk (item drawback) |

**Gap Analysis:**

The demo spec describes only positive acquisition (cards, modifiers, XP). Missing:
- Are there cursed/corrupted cards with powerful effects + drawbacks?
- Can the player opt into risk for reward?
- Does anything force negative acquisition (corruption timer, mandatory curses)?

**Experimental Design Insight:**
- **Traded negatives** appear in 5/9 experimental designs but **0/22 real games**
- This represents genuinely unexplored design space
- Example: "Sacrifice health permanently for artifact power"

**Recommendation (3 Options):**

**Option A: None (Vampire Survivors style)**
```
Pro: Simpler, accessible, pure power fantasy
Con: Less strategic depth, fewer interesting decisions
Best for: Casual demo audience
```

**Option B: Optional (Hades/Isaac style)**
```
Pro: Risk/reward decisions, build diversity
Con: Additional complexity
Implementation: "Cursed Cards" in shop - powerful but with conditions
Example: +50% damage but -20% HP, removes itself if you take damage 3x
```

**Option C: Traded (Experimental)**
```
Pro: Unique differentiation, deeper strategy
Con: May confuse players, requires careful balancing
Implementation: Sacrifice system where permanent HP = artifact slots
Example: Give up 25 max HP → unlock one artifact slot
```

**Framework Classification Options:**
- **None:** Matches Vampire Survivors, SNKRX (survivor-like genre norm)
- **Optional:** Matches Hades, Isaac (action roguelite norm)
- **Traded:** Matches experimental designs (differentiation opportunity)

---

### 1.3 Reversibility — "Can cards be removed from wands? Can skills be refunded?"

**Current Spec Status:** Implied but undefined
**Current Mechanics (from demo-polish-features.md):**
- Cards can be added to wands (implied from shop)
- Cards "dissolve" when not chosen from packs (return to pool)

**Reference Game Approaches:**

| Game | Reversibility | Implementation |
|------|--------------|----------------|
| Vampire Survivors | **Permanent + Evolutionary** | Weapons evolve, can't remove |
| SNKRX | **Sellable + Swappable** | Sell units, rearrange snake |
| Noita | **Highly Swappable** | Rebuild wands anytime; perks permanent |
| Slay the Spire | **Removable + Transformable** | Card removal at shops/events |
| Dead Cells | **Swappable + Permanent** | Swap weapons, mutations locked per biome |

**Gap Analysis:**

Unspecified in demo:
- Can cards be removed from wands during a run?
- Can cards be sold for gold?
- Is there a card removal service (like Slay the Spire)?
- Can skill points (physique/cunning/spirit) be refunded?

**Recommendation:**

```
Card Reversibility: Swappable + Permanent
- Cards CAN be removed from wands at any time (drag off = return to hand)
- Cards CANNOT be sold (no gold recovery)
- Card removal service available in shop (pay gold to destroy a card)
- Unchosen pack cards dissolve (permanent loss from pool)

Skill Point Reversibility: Permanent
- Skill points (physique/cunning/spirit) cannot be refunded
- Commitment Weight: Medium (many small choices)
```

**Framework Classification:**
- **Reversibility:** Swappable (wand cards) + Permanent (skill points)
- **Commitment Weight:** Medium
- **Aligns with:** Noita (wands swappable, perks permanent) — thematically appropriate for wand-based game

---

### 1.4 Visibility — "Is there a map preview? Path forecasting?"

**Current Spec Status:** Undefined
**Reference Game Approaches:**

| Game | Visibility | Player Information |
|------|-----------|-------------------|
| Vampire Survivors | **Present** | See current options only |
| SNKRX | **Complete + Pool-visible** | See shop, know all units per tier |
| Hades | **Forecast** | Door symbols preview reward type and god |
| Slay the Spire | **Present + Complete + Forecast** | Map shows paths and node types |
| Into the Breach | **Complete** | Full enemy intent, all teams visible |

**Gap Analysis:**

Unspecified in demo:
- Do players see upcoming waves/stages before they happen?
- Is there a run map showing progression?
- Do players know what cards exist in the pool?
- Are enemy spawns telegraphed?

**Recommendation:**

```
Visibility: Present + Pool-visible

Present:
- See current wave enemies as they spawn
- See shop offerings when shop opens
- See pack contents when opened (sequential flip)

Pool-visible:
- Card collection screen shows ALL cards in game
- Locked cards show requirements to unlock
- Players know what's possible to find

NOT Forecast:
- No map preview of upcoming stages
- No preview of shop offerings before stage end
- Keeps moment-to-moment surprise

Enemy Telegraphs:
- Elite/Boss spawn warnings (3-second countdown like SNKRX)
- Attack telegraphs for dangerous attacks
```

**Framework Classification:**
- **Visibility:** Present + Pool-visible
- **Aligns with:** SNKRX, Super Auto Pets (know the pool, see current options)

---

### 1.5 Persistence — "What carries between runs? Unlocks? Meta-upgrades?"

**Current Spec Status:** Implied from "unlock characters" but undefined
**Reference Game Approaches:**

| Game | Persistence | Carries Between Runs |
|------|------------|---------------------|
| Vampire Survivors | **Unlocks + Upgrades** | Characters, weapons; permanent stat boosts (PowerUps) |
| SNKRX | **Unlocks** | Units, classes |
| Hades | **Unlocks + Upgrades** | Weapons, aspects; Mirror of Night permanent stats |
| Dead Cells | **Unlocks + Upgrades** | Weapons, mutations; Forge upgrades |
| Into the Breach | **Unlocks + Legacy** | Squads, pilots; one pilot survives |

**Gap Analysis:**

Unspecified in demo:
- Are there permanent stat upgrades (PowerUps)?
- What unlocks exist? (characters, cards, wand types?)
- Is there a meta-currency that persists?
- Does anything narrative persist?

**Recommendation:**

```
Persistence: Unlocks (demo scope) + Upgrades (post-demo expansion)

Demo Scope - Unlocks Only:
- Unlock additional cards by achieving milestones
- Unlock additional wand chassis (if multiple exist)
- NO permanent stat upgrades (keeps demo tight)

Post-Demo Expansion:
- Add PowerUp system (permanent +X% damage, etc.)
- Add meta-currency (essence/souls) from runs
- Add narrative persistence (god relationships, story progress)
```

**Framework Classification:**
- **Persistence:** Unlocks (demo), Unlocks + Upgrades (full game)
- **Aligns with:** SNKRX for demo (simple unlocks), Hades for full game (unlocks + upgrades)

---

### 1.6 Run Identity — "How does build failure manifest? What's the fail state?"

**Current Spec Status:** "victory/defeat" mentioned but undefined
**Reference Game Approaches:**

| Game | Run Identity | Fail State |
|------|-------------|-----------|
| Vampire Survivors | **Early-crystallizing** | Death (HP = 0), Death spawn at 30 min |
| SNKRX | **Emergent** | Snake dies (all units dead), fail to clear level |
| Hades | **Emergent + Influenced** | Death (HP = 0), return to House |
| Slay the Spire | **Emergent** | Death (HP = 0), fail to beat boss |
| Into the Breach | **Pre-determined** | Grid power = 0, mission failure |

**Gap Analysis:**

Unspecified in demo:
- What's the primary fail condition? (HP = 0? Timer? Objective failure?)
- Is there a "soft fail" (lose resources but continue)?
- When does build identity crystallize?
- Can a run be "unwinnable" before defeat?

**Recommendation:**

```
Run Identity: Emergent (early-mid run) → Crystallized (late run)

Fail State:
- Primary: Player HP reaches 0 (death)
- Secondary: Fail to clear wave within time limit (optional mode)
- NO soft fails in demo (death = run end)

Build Crystallization:
- Wand 1 setup defines early playstyle (first 2-3 stages)
- Wand 2/3 additions modify but don't override identity
- By stage 5+, build is largely crystallized
- "This became a fire build" or "I'm running turret spam"

Fail State UI:
- Show run stats on death (waves cleared, damage dealt, cards collected)
- Show what killed you (enemy type, damage source)
- Option to restart immediately or return to menu
```

**Framework Classification:**
- **Run Identity:** Emergent
- **Aligns with:** Hades, SNKRX, Slay the Spire (build emerges from offerings)

---

## Part 2: Experimental Design Opportunities

### Analysis Summary

From the Roguelite Design Analysis, 9 experimental games explore underused design space. Key patterns that differ from the 22 real games:

| Design Pattern | Real Games (22) | Experimental (9) | Opportunity |
|---------------|-----------------|------------------|-------------|
| **Traded Negatives** | 0/22 (0%) | 5/9 (56%) | HIGH |
| **Drought/Feast Scarcity** | 0/22 (0%) | 2/9 (22%) | HIGH |
| **Pre-run Determinism** | 4/22 (18%) | 5/9 (56%) | MEDIUM |
| **Plateau Growth** | 0/22 (0%) | 2/9 (22%) | MEDIUM |
| **Critical Commitment** | 1/22 (5%) | 4/9 (44%) | LOW (risky) |

---

### 2.1 Traded Negatives — "Sacrifice health permanently for artifact power"

**Why It's Underexplored:**
Zero real roguelites use traded negatives as a core mechanic. Optional negatives (devil deals) are common, but REQUIRED sacrifice for power is absent.

**Demo Spec Application:**

```lua
-- Artifact Slot System (Traded Negatives)
-- Sacrifice permanent HP to unlock artifact slots

ArtifactSystem = {
    base_max_hp = 100,
    artifact_slots = 0,
    hp_per_slot = 25,  -- Sacrifice 25 HP per slot

    -- Player can sacrifice HP at shrines
    sacrifice_for_slot = function(self)
        if self.base_max_hp - self.hp_per_slot >= 25 then  -- Min 25 HP
            self.base_max_hp = self.base_max_hp - self.hp_per_slot
            self.artifact_slots = self.artifact_slots + 1
            return true
        end
        return false
    end,
}

-- Artifacts are powerful permanent effects:
Artifacts = {
    BLOOD_PACT = { effect = "+50% damage", slot_cost = 1 },
    SOUL_BOND = { effect = "Summons persist between waves", slot_cost = 1 },
    VOID_HEART = { effect = "Immune to first lethal hit per stage", slot_cost = 2 },
}
```

**Risk Assessment:**
- **Pro:** Unique differentiation, deep strategic layer
- **Con:** May feel punishing to new players
- **Mitigation:** Make shrines optional, place in late-run only

---

### 2.2 Drought/Feast Scarcity — "Boss waves grant massive skill points, normal waves grant none"

**Why It's Underexplored:**
Zero real roguelites use alternating scarcity. Most use moderate or abundant scarcity with steady drip of upgrades.

**Demo Spec Application:**

```lua
-- Tide System (Drought/Feast Scarcity)
-- Power comes in waves, not constant stream

TideSystem = {
    tide_gauge = 0,
    tide_max = 100,

    -- Gauge fills during combat
    on_enemy_kill = function(self, enemy_value)
        self.tide_gauge = math.min(self.tide_gauge + enemy_value, self.tide_max)
    end,

    -- Release tide for upgrade burst
    release_tide = function(self)
        local quality_multiplier = self.tide_gauge / self.tide_max
        local upgrade_count = math.floor(3 + 7 * quality_multiplier)  -- 3-10 upgrades

        -- Show upgrade_count card choices in rapid succession
        -- 30-second window to choose
        self.tide_gauge = 0
        return upgrade_count
    end,
}

-- Wave Rewards:
-- Normal waves: +10 tide gauge, NO immediate upgrades
-- Elite waves: +30 tide gauge, minor upgrade
-- Boss waves: Mandatory tide release + bonus drops
```

**Risk Assessment:**
- **Pro:** Creates dramatic pacing highs/lows, unique rhythm
- **Con:** May feel frustrating during drought phases
- **Mitigation:** Ensure drought phases are short (2-3 waves max)

**Hybrid Implementation (Lower Risk):**
```
Standard: Small upgrades every wave (XP → level → choice)
Tide Bonus: Additional burst upgrades from tide system
Result: Base game feels normal, tide adds bonus layer
```

---

### 2.3 Pre-run Determinism — "Expand loadout selection pre-run"

**Why It's Underexplored:**
Most roguelites use character/class choice (character-varied) but limited loadout customization. Only 4/22 real games have significant pre-run loadout selection.

**Current Demo Spec:**
- God choice (implied)
- Class choice (implied from "1 hero kit")
- No loadout customization mentioned

**Expansion Opportunity:**

```lua
-- Pre-Run Loadout System
-- God + Class + Starting Cards + Wand Type

PreRunLoadout = {
    -- God: Defines passive blessing + card pool bias
    god = "Zeus",  -- Options: Zeus, Hades, Poseidon, etc.

    -- Class: Defines stats + active ability
    class = "Battlemage",  -- Options: Battlemage, Summoner, etc.

    -- Starting Cards: Choose 3 from unlocked pool
    starting_cards = { "SPARK_BOLT", "FIRE_BASIC", "SHIELD_BUFF" },

    -- Wand Type: Defines trigger behavior
    wand_type = "Rapid",  -- Options: Rapid, Heavy, Burst
}

-- This creates Pre-run choice timing + Loadout-varied starting variance
-- Aligns with: Hades (keepsakes, weapons), Into the Breach (team selection)
```

**Demo Scope Recommendation:**
```
Demo: God + Class choice only (keep simple)
Full Game: Add starting cards + wand type customization
```

---

### 2.4 Plateau Growth Pattern — "Planning phase with frontloaded power"

**Why It's Underexplored:**
Zero real roguelites use plateau growth (start strong, stay strong). All use additive or multiplicative growth curves.

**Experimental Application:**

This pattern pairs naturally with pre-run determinism. The "Loadout" experimental game uses this:
- Build entire loadout pre-run
- No upgrades during run
- Challenge is execution of plan, not adaptation

**Demo Spec Application (Partial Plateau):**

```lua
-- God Power System (Frontloaded Plateau)
-- God blessing is maximum power from wave 1
-- Levels UP the god, not the player

GodPower = {
    -- Start at full god power
    blessing_level = 3,  -- Max from start
    blessing_effect = "Lightning strikes enemies every 5 seconds",

    -- Player power still grows (additive)
    -- But god power is plateau

    -- Meta-progression: Unlock higher starting blessing levels
    -- "Start at blessing level 4" unlocked after 10 wins
}
```

**Risk Assessment:**
- **Pro:** Clear identity from wave 1, reduces early-game weakness
- **Con:** May reduce progression satisfaction
- **Mitigation:** Apply plateau to ONE system (god), keep additive for others (cards, stats)

---

## Part 3: Integration Recommendations

### Recommended Framework Configuration

Based on analysis, here's the recommended complete framework classification for the demo:

```
ACQUISITION AXES
├── Choice Timing: Distributed (wave completion → shop → level up)
│   └── Pacing: Fixed interval (wave completion) + Event-triggered (boss rewards)
├── Distribution Timing: Immediate (all power works instantly)
├── Agency: Curated (pick 1 of 3 cards) + Influenced (god affects pool)
├── Negative Acquisition: Optional (cursed cards available, not required)
└── Scarcity: Moderate (enough to build, can't take everything)

MANAGEMENT AXES
├── Reversibility: Swappable (wand cards) + Permanent (skill points)
│   └── Commitment Weight: Medium
├── Capacity: Hard cap (wand slots, card hand limit)
├── Interaction: Synergistic (cards combo with triggers and elements)
└── Upgrade Depth: Linear (card levels) + Evolutionary (card evolutions TBD)

INFORMATION AXES
├── Visibility: Present + Pool-visible (see current options, know card pool)
└── Comprehension: Transparent (clear card descriptions)

PROGRESSION AXES
└── Growth Pattern: Additive (monotonic power gain)

META AXES
├── Persistence: Unlocks (demo), Unlocks + Upgrades (full game)
├── Starting Variance: Character-varied (god + class choice)
└── Run Identity: Emergent (build emerges from offerings)

EXPERIENCE AXES
└── Skill vs Build Ratio: Balanced (build decisions + execution both matter)
```

### Experimental Features Priority

| Feature | Risk | Differentiation | Demo Scope | Recommendation |
|---------|------|-----------------|------------|----------------|
| Traded Negatives | Medium | High | Optional | Add as late-game shrine system |
| Drought/Feast | High | High | Not recommended | Save for expansion |
| Pre-run Loadout | Low | Medium | God + Class only | Include in demo |
| Plateau Growth | Medium | Medium | God blessing only | Include as god power system |

---

## Part 4: Reference Data Summaries

### Path of Achra Key Insights

**Core Design Philosophy:**
- **Event-Driven Everything:** Almost no abilities are directly activated; all trigger based on game events
- **Stat Synergy Chains:** Speed → Movement triggers → Extra attacks → Kill triggers → Heal/buff
- **Three-Layer Character Building:** Class + Culture + Religion

**Relevant Mechanics for Demo:**
1. **Trigger System:** `on_hit`, `on_kill`, `on_attack`, `on_being_attacked` — aligns with demo's trigger card system
2. **Status Effect Stacking:** Inflame, Poise, Meditate — stack-based buffs for build depth
3. **Transformation System:** Drakeform, Batform — temporary power modes (could inspire god powers)

**Implementation Priority from POA:**
```
Phase 1: Event bus with core triggers (on_hit, on_kill, on_attack)
Phase 2: Status effects with stacking (buff system)
Phase 3: Transformation modes (god blessing activations)
```

---

### SNKRX Key Insights

**Core Design Philosophy:**
- **Snake as Party:** Your party IS the snake — each unit is a segment
- **Auto-Attack Combat:** Units attack automatically, player controls movement only
- **Economy Depth:** Interest system rewards saving gold (+1 per 5 gold, max +5)

**Relevant Mechanics for Demo:**
1. **Synergy Thresholds:** 3/6 for Tier 1 classes, 2/4 for Tier 2 — clear breakpoints
2. **Unit Upgrade System:** Combine duplicates (3 copies → level up)
3. **Position-Based Effects:** Head takes damage, position items (+30% damage at position 4)

**Economy Formula from SNKRX:**
```lua
-- Interest system
interest = math.floor(gold / 5)  -- Max 5 (or 10 with Merchant Lv3)

-- Shop tier odds by level
-- Level 1-3: 70% T1, 25% T2, 5% T3, 0% T4
-- Level 22-25: 10% T1, 20% T2, 35% T3, 35% T4
```

---

### Vampire Survivors Key Insights

**Core Design Philosophy:**
- **Auto-Attack Simplicity:** Player only controls movement
- **Exponential Power Scaling:** Multiplicative stats + evolutions
- **Risk/Reward via Curse:** Increase difficulty for more rewards

**Relevant Mechanics for Demo:**
1. **Weapon Evolution:** Weapon Lv8 + specific passive → evolution (clear goal)
2. **Hard Caps:** 6 weapons, 6 passives — forces meaningful choices
3. **Death Timer:** 30-minute hard cap creates urgency

**Stat System from VS:**
```lua
-- Multiplicative bonuses
final_stat = base_stat * (1 + sum(multipliers))

-- Example: Damage
base_damage = 10
might_bonus = 0.5  -- +50% from Spinach
total_damage = 10 * (1 + 0.5) = 15
```

---

## Conclusion

The demo spec has a solid foundation but requires specification of:
1. **Pacing:** Wave count, duration, and scaling formula
2. **Negative Acquisition:** Decision between None/Optional/Traded
3. **Reversibility:** Card removal/refund mechanics
4. **Visibility:** Information available to players
5. **Persistence:** Unlock system details
6. **Run Identity:** Fail states and build crystallization

**Experimental opportunities** worth exploring:
- **Traded Negatives:** Artifact slot system (medium risk, high differentiation)
- **Pre-run Loadout:** God + Class + starting cards (low risk, medium differentiation)
- **Partial Plateau:** God blessing at full power from start (medium risk, medium differentiation)

**NOT recommended for demo:**
- Drought/Feast scarcity (too experimental, high risk)
- Critical commitment weight (Into the Breach style — wrong genre)
- Single source power diversity (needs multiple systems for depth)

---

## Appendix: Framework Axis Quick Reference

| Axis | Demo Recommendation | Rationale |
|------|---------------------|-----------|
| Choice Timing | Distributed | Constant stream of decisions |
| Pacing | Fixed interval + Event-triggered | Wave completion + boss rewards |
| Distribution Timing | Immediate | All power works now |
| Agency | Curated + Influenced | Pick 1 of 3, god affects pool |
| Negative Acquisition | Optional | Risk/reward without forcing |
| Scarcity | Moderate | Meaningful constraints |
| Reversibility | Swappable + Permanent | Wands flexible, skills locked |
| Commitment Weight | Medium | Many choices, each matters |
| Capacity | Hard cap | Forces decisions |
| Interaction | Synergistic | Cards combo explicitly |
| Upgrade Depth | Linear | Clear progression |
| Power Source Diversity | Multi-source | Cards + skills + god + class |
| Visibility | Present + Pool-visible | Know what's possible |
| Comprehension | Transparent | Clear descriptions |
| Growth Pattern | Additive | Steady power increase |
| Persistence | Unlocks | Simple for demo |
| Starting Variance | Character-varied | God + class choice |
| Run Identity | Emergent | Build from offerings |
| Skill vs Build Ratio | Balanced | Both matter |

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
