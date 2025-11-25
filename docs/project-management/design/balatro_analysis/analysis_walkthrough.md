# Balatro vs. Your Game: A Mechanics Deep Dive

This document analyzes Balatro's mechanics layer-by-layer, starting from the absolute bottom (Logic) and moving up, comparing them to your Wand-based system.

---

## Part 0: The Logic Layer (Hand Evaluation)

Before any scoring happens, the game must decide **"What did the player just do?"**

### 1. Balatro: Pattern Matching (`evaluate_poker_hand`)
*   **Source:** `functions/misc_functions.lua`
*   **Input:** A set of 5 cards.
*   **Logic:** **Combinatorial**. It looks for specific *patterns* in the data.
    *   *Is it a Flush?* (5 cards, same suit)
    *   *Is it a Straight?* (5 cards, sequential rank)
    *   *Is it 4-of-a-kind?* (4 cards, same rank)
*   **Output:** A specific **Hand Type** (e.g., "High Card", "Flush"). This "Type" is the key that unlocks the scoring rules.

### 2. Your Game: Sequential Execution (`simulate_wand`)
*   **Source:** `assets/scripts/core/card_eval_order_test.lua`
*   **Input:** A "Deck" of N cards in a Wand.
*   **Logic:** **Procedural / Interpreter**. It reads cards like code instructions.
    *   *Card 1 (Modifier):* "Add +10 Damage to next spell."
    *   *Card 2 (Modifier):* "Cast the next spell twice."
    *   *Card 3 (Action):* "Fire Projectile." -> **EXECUTE** (Apply mods, spawn 2 fireballs).
*   **Output:** A sequence of **Cast Blocks**.

### 3. The Comparison: "Identity" vs. "Instruction"
*   **Balatro** asks: *"What **is** this hand?"*
*   **Your Game** asks: *"What does this wand **do**?"*

This is the fundamental difference. Balatro players feel smart because they **assembled a recognized pattern**. Your players feel smart because they **programmed a complex machine**.

### 4. Bridging the Gap: "Synergy Detection"
To bring the "Balatro Feel" to your game, you need to **label** the Cast Blocks. The game should recognize what the player built.

**Proposal: The "Spell Type" System**
Just as Balatro detects a "Flush", your game could detect a "Cast Pattern" within a single Block.

| Balatro Hand | Wand Equivalent | Condition | Reward |
| :--- | :--- | :--- | :--- |
| **High Card** | **Simple Cast** | 1 Action, 0 Mods | Base Stats |
| **Pair** | **Twin Cast** | 1 Action, Multicast x2 | +10% Speed |
| **Two Pair** | **Dual Barrage** | 2 Different Actions, Multicast x2 | +10% Fire Rate |
| **Flush** | **Mono-Element** | 3+ Actions, Same Element (Fire/Void) | +20% Damage |
| **Straight** | **Combo Chain** | 3+ Actions, Different Types (Projectile -> Explosion -> Cloud) | +15% Mana Efficiency |
| **Full House** | **Heavy Barrage** | 3 of Action A, 2 of Action B | +1 Pierce |

#### Integration with Existing "Tag Synergy"
> **User Note:** "we should save it. I like this." (Referring to Artifact Bridge examples)

You already have a `TagEvaluator` (TFT-style) that counts tags across the *entire deck*.
*   **Tag Synergy (Existing):** Passive, Deck-Wide. "I am building a Fire Deck."
    *   *Effect:* +10% Burn Damage (Stat).
*   **Spell Type (Proposed):** Active, Per-Cast. "I just cast a Mono-Element spell."
    *   *Effect:* Triggers a specific event (e.g., "Mono-Element casts trigger an explosion").

**The Hook:** Your "Jokers" (Artifacts) can bridge them.
*   *Artifact:* "When you cast a **Mono-Element** spell (Spell Type), gain +5 Temporary **Fire Tags** (Tag Synergy)."

### 5. Visualization: The "Cast Feed"
> *"How would the cards look? Where on the screen should they go? How to handle instant casts?"*

**Design Proposal:**
*   **Location:** Bottom Center (Classic HUD spot) or floating near the Player (Dynamic).
*   **Style:** Minimalist Icons, not full cards.
    *   Full cards are for the Inventory/Shop.
    *   In combat, use **Glyphs** (e.g., a small "Fire" icon, a "x2" icon).
*   **The Flow:**
    1.  **Trigger:** Player presses Fire.
    2.  **Instant Feedback:** The projectile fires *immediately* (no lag).
    3.  **Visual Echo:** Simultaneously, the "Cast Feed" plays a rapid animation of the Glyphs merging.
        *   `[x2] + [Fire] -> [BIG FIRE ICON]`
    4.  **Juice:** If a "Spell Type" is detected, flash the text **"MONO-ELEMENT!"** above the player or on the HUD.

**Handling Instant Casts (e.g., On Bump):**
*   These are too fast for a feed.
*   **Solution:** Just flash the **Result Icon** or the **Spell Type Name** briefly near the impact point. "BUMP TRIGGER!"

---

## Deep Dive: Spell Types vs. Tag Synergy

The user asked to explore the interaction between these two systems. This section details the "Integration Matrix".

### 1. The Distinction
*   **Tag Synergy (The "Class"):** Defines *who* you are. (e.g., "I am a Pyromancer").
    *   *Source:* `tag_evaluator.lua`
    *   *Mechanism:* Counts tags in deck -> Passive Stat Buffs.
*   **Spell Type (The "Move"):** Defines *what* you do. (e.g., "I cast a Fireball Barrage").
    *   *Source:* `WandExecutor` (Proposed)
    *   *Mechanism:* Pattern Match on Cast Block -> Active Trigger Effects.

### 2. The Integration Matrix
How do they feed each other?

| Interaction | Description | Example |
| :--- | :--- | :--- |
| **Tags Buff Spells** | High Tag counts improve specific Spell Types. | *Fire Mastery (5 Tags):* "Your **Mono-Element (Fire)** spells deal double damage." |
| **Spells Feed Tags** | Casting specific Spell Types temporarily boosts Tag counts. | *Combustion Wand:* "Casting a **Twin Cast** grants +2 Temporary Fire Tags for 5s." |
| **Tags Unlock Spells** | You can't even *perform* certain Spell Types without enough Tags. | *Grand Ritual:* "Requires 7 Arcane Tags to activate **'Void Singularity'** (Special Spell Type)." |

### 3. The "Artifact Bridge" (Joker Equivalents)
In Balatro, Jokers often say *"If Hand contains a Flush..."*. In your game, Artifacts should bridge the gap.

**Example Artifacts:**
*   **The Prism (Artifact):** "If you cast a **Mono-Element** spell, convert all its damage to the element of your highest Tag count."
*   **Echo Chamber (Artifact):** "If you cast a **Twin Cast**, your next **Simple Cast** counts as a Twin Cast."
*   **Elemental Overload (Artifact):** "Gain +1% Damage for every Fire Tag you have, but only when casting **Heavy Barrage**."

### 4. Implementation Strategy
> **User Note:** "we should draft this in code, and test that it outputs."

1.  **Step 1:** Implement `SpellTypeEvaluator`.
    *   **Status:** [Implemented](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/docs/project-management/design/balatro_analysis/spell_type_evaluator.lua)
    *   **Test Harness:** [test_spell_types.lua](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/docs/project-management/design/balatro_analysis/test_spell_types.lua)
    *   Input: `CastBlock` (from `card_eval_order_test.lua` with: `cards`, `applied_modifiers`, etc.).
    *   Output: `SpellType` Enum (Simple, Twin, Mono, etc.).
2.  **Step 2:** Hook into `WandExecutor`.
    *   When a block executes, run `SpellTypeEvaluator`.
    *   Emit Event: `on_spell_cast(type, tags)`.
3.  **Step 3:** Create "Bridge" Artifacts.
    *   Listen for `on_spell_cast`.
    *   Check Player's `tag_counts`.
    *   Apply Effect.

---

## Deep Dive 2: Defining Spell Types & Ramifications

> *"What are the ramifications of this, considering that some wands have larger spell blocks? How do we know what spell types to define?"*

### 1. Composition vs. Order
> **User Note:** "so upgrading cast block size is a core consideration?"

Spell Types are defined by the **Composition** of a Cast Block, not just the order.
*   **Analogy:** A Poker Hand is a "Cast Block".
*   **Small Block (1-2 cards):** Like a 2-card hand. You can only make "High Card" or "Pair".
*   **Large Block (5+ cards):** Like a 7-card hand. You can make "Full House", "Flush", "Straight".

**Ramification:**
*   **Wand Capacity Matters:** A Wand with `cast_block_size = 1` is a "Pistol". It can *never* cast a "Flush" (Mono-Element Barrage). It is limited to simple, reliable spells.
*   **Progression:** Upgrading a Wand's `cast_block_size` is a huge power spike because it **unlocks higher-tier Spell Types**.

### 2. How to Define Spell Types?
> **User Note:** "I like this idea." (Referring to Shotgun/Sniper definitions)

We define them by **"What feels distinct to the player?"**
*   **The Shotgun:** Many projectiles at once. -> **"Scatter Cast"** (1 Action, High Multicast, Spread Mod).
*   **The Sniper:** One big, fast hit. -> **"Precision Cast"** (1 Action, Speed/Damage Mod, No Spread).
*   **The Machine Gun:** Rapid fire. -> **"Rapid Fire"** (Low Delay, Repeat Cast).
*   **The Combo:** A -> B -> C. -> **"Chain Cast"** (Action A triggers Action B triggers Action C).

**Rule of Thumb:** If it looks different on screen, it deserves a Name.

### 3. Visualization Timing: "Decoupled Feedback"
> **User Note:** "still not clear on how this would look, will have to test."
> *"I'm wondering if this means there should be a delay to most triggers?"*

**NO DELAY.** Gameplay must be instant.
*   **The "Kill Feed" Solution:** In Call of Duty, you shoot instantly. The "+100 KILL" text pops up 100ms later. It doesn't block you.
*   **The "Fighting Game" Solution:** You punch instantly. The "3x COMBO" counter updates on the side.

**The Cast Feed Implementation:**
1.  **Player Clicks:** `WandExecutor` fires immediately.
2.  **Event Emitted:** `on_cast_block_executed(block_data)`.
3.  **UI Listener:** The UI catches this event.
    *   It sees: `[Double Cast] + [Fireball]`.
    *   It plays a **fast** animation (200ms) in the HUD: `Icon -> Icon -> FLASH`.
    *   If the player casts again before it finishes, the new icons **queue up** or **stack** (like Tetris damage).

**Result:** The game feels snappy (instant fire), but the "Brain Juice" (recognizing the pattern) follows a split-second later, confirming your genius.

---

## Part 2: The Modifier Layer (Jokers vs. Wands/Artifacts)

Now that we know *what* was played (Hand/Spell Type), how do we modify the output?

### 1. Balatro: The "Global Observer" (`calculate_joker`)
*   **Source:** `functions/state_events.lua` (inside `evaluate_play`)
*   **Mechanism:**
    1.  The game calculates the base score of the Hand.
    2.  It iterates through **every Joker**.
    3.  Each Joker checks the state (`if hand == "Flush"`) and modifies the global variables (`mult`, `chips`).
*   **Key Trait:** Jokers are **Passive & Reactive**. They don't "do" anything until *you* play a hand. They sit in the sky and judge you.

### 2. Your Game: The "Sequential Instruction" (`WandExecutor`)
*   **Source:** `assets/scripts/core/card_eval_order_test.lua`
*   **Mechanism:**
    1.  The Wand reads Card 1 (Modifier).
    2.  It applies the mod to a temporary context (`next_cast_damage += 10`).
    3.  It reads Card 2 (Action).
    4.  It executes the Action using that context.
*   **Key Trait:** Wand Modifiers are **Active & Local**. They are part of the assembly line.

### 3. The Gap: Missing "Global Modifiers"
Your game currently lacks a true equivalent to the **Passive Joker**.
*   **Prayers (`prayers.lua`):** Currently, these are **Active Skills** with cooldowns (e.g., "Cast to freeze enemies"). They are not passive buffs.
*   **Wand Modifiers:** These are consumed on use.

**The Problem:** You cannot currently make an item like: *"All Fire Spells deal +10 Damage."*
*   If you put it in a Wand, it's a one-time consumable modifier.
*   If you make it a Prayer, it's an active skill.

### 4. Proposal: The "Passive Artifact" System
> **User Note:** "let' smake this ready to use, keeping it as simple and accessilbe as possible, and test it. we should also name it jokers, not add it to prayers."
> **User Note:** "yes, I agree." (Referring to separate slot)

To achieve Balatro-level depth, you need **Passive Artifacts** (Jokers) that sit outside the wands.

| Feature | Wand Modifier | Passive Artifact (Joker) |
| :--- | :--- | :--- |
| **Location** | Inside the Wand Deck | In a separate "Artifact Slots" inventory |
| **Trigger** | When drawn/executed | **Global Event Listener** (`on_spell_cast`) |
| **Consumption** | Consumed on use (reshuffled) | **Permanent** (until sold/removed) |
| **Example** | "Double the *next* spell's damage." | "Double damage of *all* Fire spells." |

**Implementation Plan:**
1.  **Extend Prayers:** Allow `prayers.lua` to define `passive_effects`.
2.  **Event Hooks:**
    *   **Status:** [JokerSystem Implemented](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/docs/project-management/design/balatro_analysis/joker_system.lua)
    *   **Test Harness:** [test_jokers.lua](file:///Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/docs/project-management/design/balatro_analysis/test_jokers.lua)
    *   In `WandExecutor`, emit `get_global_modifiers(spell_type, tags)`.
    *   The Artifact System responds with buffs.
3.  **The Loop:**
    *   `Final Damage = (Base Wand Dmg * Wand Mods) * Global Artifact Mods`

**Design Note:** This completes the "Balatro Formula" for your game.
*   **Hand:** Cast Block (User assembled).
*   **Deck:** Wand (User built).
*   **Jokers:** Artifacts (User collected).

---

## Part 3: The Meta Layer (Economy/Shop/Progression)

The "Meta Layer" is everything *between* runs or rounds: buying, selling, upgrading, and synergies.

### 1. Balatro: The Shop Loop
*   **Shop Phase:** Between rounds, players can:
    1.  Buy Jokers (Passive Modifiers)
    2.  Buy Playing Cards (to improve their deck)
    3.  Buy Consumables (Tarots, Planets, Spectrals)
    4.  Reroll the shop (costs $5, increases each time)
    5.  Sell Jokers/Cards for cash

*   **Currency:** Dollars (`$`).
    *   Earned by playing hands (some Jokers give `+$` per hand).
    *   Earned by selling cards.
    *   Used to buy items.

*   **Progression:**
    *   **Antes (Rounds):** Each ante has 3 blinds (Small, Big, Boss).
    *   **Scaling:** Chip requirements increase exponentially.
    *   **Unlocks:** Defeat bosses to unlock new Jokers, Decks, Challenges.

### 2. Your Game: The Shop System
*   **Source:** `docs/project-management/design/shop_stat_systems_walkthrough.md`
*   **Your Shop Has:**
    1.  **Card Offerings:** Triggers, Modifiers, Actions (with rarity).
    2.  **Interest System:** Earn interest on unspent gold.
    3.  **Lock System:** Lock cards to keep them in the shop.
    4.  **Reroll Costs:** Escalating cost to refresh the shop.
    5.  **Card Upgrades:** Cards can level up (1 → 2 → 3) with custom behaviors.
    6.  **Card Synergies:** Tag-based bonuses (e.g., 3 Fire cards = +10% Burn Damage).

*   **Currency:** Gold.
*   **Progression:** Run-based, similar to Slay the Spire.

### 3. The Comparison: "Build vs. Discover"

| Feature | Balatro | Your Game |
|:---|:---|:---|
| **Shop Items** | Jokers (Passive), Playing Cards, Consumables | Cards (Actions/Mods/Triggers), Artifacts (Proposed) |
| **Reroll Cost** | $5, increases each time | Escalating cost |
| **Lock System** | ❌ No | ✅ Yes |
| **Interest System** | ❌ No | ✅ Yes (Earn interest on unspent gold) |
| **Card Upgrades** | ❌ No (Cards are fixed) | ✅ Yes (Level 1 → 3) |
| **Synergies** | Via Jokers only | Via Tags + Jokers (Proposed) |
| **Scaling** | Exponential chip requirement | Run-based difficulty |

**Key Insight:** Your shop system is **already more complex** than Balatro's. You have:
*   **Interest** (economic strategy)
*   **Locks** (selective rerolling)
*   **Upgrades** (card progression)
*   **Tag Synergies** (deck-wide bonuses)

Balatro's strength is **simplicity + depth**. Your strength is **flexibility + customization**.

### 4. What You Can Learn from Balatro

#### A. Simplify the Shop UI
Balatro's shop is **instant clarity**:
*   3 Jokers (max)
*   2 Consumables (max)
*   2 Booster Packs (max)
*   1 Voucher (max)

**No scrolling. No clutter. Everything fits on one screen.**

**Recommendation:** Cap your shop offerings:
*   3 Trigger Cards
*   3 Modifier Cards
*   3 Action Cards
*   2 Artifacts (Jokers)

If you have more variety, use **Rarity** to filter (e.g., "Rare Shop" vs. "Common Shop").

#### B. "Free Rerolls" as a Reward
Balatro Jokers often give:
*   *"Free reroll per blind"* (Chaos the Clown)
*   *"Reset reroll cost after buying a Joker"*

This creates **agency**: "Do I spend $5 to reroll, or do I buy this cheap Joker to reset the cost?"

**Recommendation:** Add Artifacts that reduce/reset reroll costs.

#### C. "Volatile" Jokers (Risk/Reward)
Balatro has Jokers like:
*   **Blueprint:** "Copies ability of Joker to the right."
*   **Brainstorm:** "Copies ability of leftmost Joker."

These create **emergent combos** because the effect changes based on *what you bought previously*.

**Recommendation:** Add Artifacts that scale with:
*   Number of Fire Tags
*   Number of Artifacts owned
*   Player's current gold

---

## Part 4: Final Synthesis

### The "Balatro Formula" Applied to Your Game

Balatro's magic is:
1.  **Pattern Recognition** (Poker Hands) → **"I built a Flush!"**
2.  **Passive Modifiers** (Jokers) → **"My Flush triggers 3 different effects!"**
3.  **Emergent Combos** (Jokers interact) → **"This Joker copies that Joker, which buffs this hand type!"**

Your game can achieve the same **using the systems we've built**:

1.  **Pattern Recognition** ✅ Implemented
    *   `SpellTypeEvaluator` identifies "Mono-Element", "Twin Cast", etc.
    *   Players see: *"I built a Shotgun! I built a Combo Chain!"*

2.  **Passive Modifiers** ✅ Implemented
    *   `JokerSystem` stores global Artifacts.
    *   Players collect: *"Pyromaniac (+10 Fire Damage)", "Echo Chamber (Twin Casts trigger twice)"*.

3.  **Emergent Combos** ✅ Designed (via Integration Matrix)
    *   Spell Types trigger Joker effects.
    *   Tags buff Spell Types.
    *   Jokers scale with Tags.
    *   **Example:** *"I have 5 Fire Tags. My 'Pyromaniac' Joker gives +10 Damage to Mono-Element spells. When I cast a Mono-Element (Fire) spell, I deal massive damage!"*

### The Missing Pieces (Next Steps)

1.  **Integrate SpellTypeEvaluator into WandExecutor**
    *   After a cast block executes, call `SpellTypeEvaluator.evaluate(block)`.
    *   Emit event: `on_spell_cast(spell_type, tags)`.

2.  **Create Artifact Shop**
    *   Add 2-3 Artifact slots in the shop.
    *   Use Rarity (Common/Rare/Epic) like Jokers.

3.  **Implement "Cast Feed" UI**
    *   Show mini-icons of cards used in the Cast Block.
    *   Flash the Spell Type name when recognized.

4.  **Design 10-15 "Core" Artifacts**
    *   3-5 that buff specific Spell Types (e.g., "Shotgun King": +20% Scatter Damage).
    *   3-5 that scale with Tags (e.g., "Elemental Master": +1% Damage per element tag).
    *   3-5 with unique mechanics (e.g., "Time Dilation": Slow down time when casting Heavy Barrage).

5.  **Playtest & Iterate**
    *   Test if players notice the Spell Type recognition.
    *   Test if Artifacts feel impactful.
    *   Adjust numbers (damage, costs, thresholds).

---

**END OF ANALYSIS**

We have completed the bottom-up analysis of Balatro's mechanics and designed systems to bring that "feel" to your game. The implementations are ready for integration.
