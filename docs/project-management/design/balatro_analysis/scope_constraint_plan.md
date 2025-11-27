# Game Design Scope Analysis & Constraint Plan

## Goal Description
The user is concerned about "overscoping" for their first Steam release. This analysis evaluates the current implementation of the "Balatro-like" systems (Spell Types, Artifacts/Jokers, Cast Feed) against the design goals and proposes a plan to **constrain content scope** while keeping the implemented systems.

## Current Status Analysis
**Good News:** The "Overscoped" systems are **already built**.
- **Logic:** `SpellTypeEvaluator`, `JokerSystem`, and `WandExecutor` integration are fully implemented.
- **UI:** `CastFeedUI` is implemented and wired to events.
- **Architecture:** The "Bridge" between Wands (Action) and Balatro (Pattern Matching) exists.

**The Risk:** The risk is no longer "Can I build this system?", but **"Can I fill this system with content?"**
- A Balatro-like system requires dozens of Jokers to feel "infinite".
- A Wand system requires dozens of Cards to feel "creative".
- Doing *both* creates a massive content/balancing burden.

## Proposed Constraints (The "Scope Box")
To avoid overscoping, we will strictly limit the **Content Volume** for the initial release, while keeping the **System Depth**.

### 1. Artifact (Joker) Constraints
Instead of 150 Jokers (like Balatro), aim for **20 High-Impact Artifacts**.
- **5 Archetype Enablers:** (e.g., Pyromaniac, Speed Demon) - *Define the build.*
- **5 Generic Scalers:** (e.g., Tag Master, Economy) - *Support any build.*
- **5 Spell Type Payoffs:** (e.g., Shotgun King) - *Reward specific playstyles.*
- **5 "Wildcards":** (e.g., Copycat, RNG) - *Create "wow" moments.*

**Rule:** If an Artifact doesn't fundamentally change how you play, cut it. No "+5% damage" filler.

### 2. Spell Type Constraints
Stick to the **Core 5** patterns that are visually distinct.
1.  **Simple Cast:** (Baseline)
2.  **Twin/Multicast:** (Visual: More projectiles)
3.  **Scatter/Shotgun:** (Visual: Spread)
4.  **Rapid Fire:** (Visual: Stream)
5.  **Mono-Element:** (Visual: Color uniformity)

**Cut:** "Combo Chain", "Heavy Barrage", "Chaos Cast" (unless they emerge naturally). Don't write special logic for them yet.

### 3. Wand Constraints
Limit to **3 Distinct Wand Frames** that encourage different playstyles.
1.  **The Pistol:** Low Capacity, Fast Recharge. (Encourages Rapid Fire / Simple Casts).
2.  **The Staff:** High Capacity, Slow Recharge. (Encourages Big Combos / Mono-Element).
3.  **The Prism:** Balanced, High Mana. (Encourages Multicast / Scatter).

## Implementation Plan (Cleanup & Focus)

### Phase 1: Verification (The "Vertical Slice")
Verify that the *existing* loop works before adding ANY new content.
- [ ] **Run the Game:** Ensure `WandExecutor` correctly triggers `SpellTypeEvaluator`.
- [ ] **Check UI:** Ensure `CastFeedUI` displays the detected patterns.
- [ ] **Test Artifacts:** Ensure the 3-4 existing Artifacts (`Pyromaniac`, `Echo Chamber`) actually modify damage/behavior.

### Phase 2: Content Pruning
- [ ] **Review `JokerSystem.lua`:** Comment out or remove any "Idea" Jokers that aren't implemented or are too complex.
- [ ] **Review `SpellTypeEvaluator.lua`:** Ensure logic is robust for the Core 5.

### Phase 3: The "Fun" Test
- [ ] Play a session.
- [ ] **Question:** Does getting a "Twin Cast" feel good?
- [ ] **Question:** Does the "Cast Feed" make me feel smart?
- [ ] **Adjustment:** Tune the *visuals* (UI animations, text pop-ups) rather than adding more mechanics.

## Verification Plan
### Automated Tests
- Run `test_jokers.lua` to verify the artifact logic.
- Run `test_spell_types.lua` to verify pattern recognition.

### Manual Verification
- **Launch Game:**
    - Equip a Wand with 2 Action Cards.
    - Add a "Multicast" modifier.
    - Fire.
    - **Expectation:**
        - Projectiles fire.
        - `CastFeedUI` shows "TWIN CAST" (Cyan).
        - If `Echo Chamber` artifact is owned, verify double execution (4 projectiles).
