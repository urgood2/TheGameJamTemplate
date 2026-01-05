Analysis by Claude (Opus 4.5), direction by a327ex

---

# Roguelite Design Analysis

## Contents

1. [The Framework](#the-framework) — 17 axes across 6 categories
2. [Game Classifications](#game-classifications) — 22 games analyzed
3. [Frequency Analysis](#frequency-analysis) — what's common, what's rare
4. [Hypothetical Designs](#hypothetical-designs) — 12 imaginary games exploring design space
5. [Experimental Analysis](#experimental-games-frequency-analysis) — patterns in the hypothetical designs
6. [Summary](#summary-design-space-for-new-roguelites) — what the experimental designs reveal

---

## The Framework

[Framework](#the-framework) | [Games](#game-classifications) | [Frequency](#frequency-analysis) | [Designs](#hypothetical-designs) | [Experimental](#experimental-games-frequency-analysis)

The axes are organized into categories: **Acquisition**, **Management**, **Information**, **Progression**, **Meta**, and **Experience**.

---

## ACQUISITION AXES

These govern HOW and WHEN you get power.

### 1. Choice Timing
*When do you make decisions about what powers to pursue?*

| Value | Description | Example |
|-------|-------------|---------|
| **Pre-run** | Before the run starts (loadout, character, draft) | Into the Breach team selection |
| **Early-run** | Concentrated in opening phase | Slice & Dice party draft |
| **Distributed** | Spread throughout the run | Hades boon choices |
| **Milestone** | At specific progression points | Monster Train champion upgrades |
| **Reactive** | In response to situations (find, then decide) | FTL event choices |
| **Continuous** | Constant stream of micro-decisions | TFT shop every round |

#### Pacing
*What triggers upgrade opportunities?*

| Value | Description | Example |
|-------|-------------|---------|
| **Fixed interval** | Every N rooms/waves/minutes | Vampire Survivors level-ups |
| **Performance-based** | Better play = more upgrades | Skill-gated rewards |
| **Resource-gated** | Spend currency to upgrade | Shops, FTL scrap |
| **Event-triggered** | Tied to specific encounters | Boss rewards |
| **Player-controlled** | Choose when to upgrade | Strategic timing of purchases |
| **Continuous** | Constant small increments | Idle game mechanics |

### 2. Distribution Timing
*When do powers become available to use?*

| Value | Description | Example |
|-------|-------------|---------|
| **Immediate** | Get it, use it now | Most action roguelites |
| **Delayed-Random** | Acquired but randomly accessible | Deckbuilder card draw |
| **Delayed-Sequential** | Acquired but unlocks over time | Skill trees with prerequisites |
| **Conditional** | Available when conditions met | Isaac's activated items (charge) |
| **Frontloaded** | Have everything from the start | Into the Breach mechs |
| **Partitioned** | Power segmented; only one segment accessible at a time | Stance systems, form switching |

### 3. Agency
*How much control over WHAT you get?*

| Value | Description | Example |
|-------|-------------|---------|
| **Deterministic** | Choose exactly what you want | Shop with fixed inventory |
| **Curated** | Choose from limited options | Pick 1 of 3 |
| **Influenced** | Affect the pool/probabilities | Class filters available items |
| **Serendipitous** | Find what you find | FTL random events |
| **Predetermined** | Fixed for this run, no choice | Daily challenge seeds |

### 4. Negative Acquisition
*Do you gain negatives alongside positives?*

| Value | Description | Example |
|-------|-------------|---------|
| **None** | Pure power growth | Vampire Survivors |
| **Optional** | Can choose to take risks | Devil deals in Isaac |
| **Coupled** | Positives come with negatives | Parasites in Returnal |
| **Forced** | Negatives accumulate regardless | Corruption in Curse of the Dead Gods |
| **Traded** | Must sacrifice to gain | Darkest Dungeon stress |

### 5. Scarcity
*How abundant or rare are power options?*

| Value | Description | Example |
|-------|-------------|---------|
| **Abundant** | Constant stream of options, more than you can take | Vampire Survivors (frequent level-ups) |
| **Moderate** | Enough options but meaningful constraints | Slay the Spire (can't take everything) |
| **Scarce** | Limited resources, must prioritize carefully | FTL (limited scrap) |
| **Competitive** | Shared pool, taking denies others | TFT (other players reduce availability) |
| **Drought/Feast** | Alternating periods of scarcity and abundance | Some games with resource cycles |
| **Time-pressured** | Spending time to acquire power increases difficulty/cost | Risk of Rain (difficulty timer) |

---

## MANAGEMENT AXES

These govern how you HANDLE power once acquired.

### 6. Reversibility
*Can you undo or change power choices?*

| Value | Description | Example |
|-------|-------------|---------|
| **Permanent** | Locked in forever | Isaac passive items |
| **Transformable** | Can evolve/upgrade but not remove | Card upgrades in Slay the Spire |
| **Removable** | Can discard/destroy | Card removal events |
| **Swappable** | Equip/unequip, limited slots | Dead Cells weapon slots |
| **Sellable** | Trade back for resources | Super Auto Pets selling units |
| **Fluid** | Continuous reorganization | Backpack Hero spatial arrangement |

#### Commitment Weight
*How heavy does each choice feel?*

| Value | Description | Example |
|-------|-------------|---------|
| **Light** | Easy to undo or replace, low stakes per choice | Super Auto Pets (can sell immediately) |
| **Medium** | Permanent but many opportunities to choose | Hades (permanent but frequent choices) |
| **Heavy** | Few choices, each shapes the run significantly | Monster Train champion path |
| **Critical** | One or two choices determine everything | Into the Breach team choice |

### 7. Capacity
*How many powers can you have?*

| Value | Description | Example |
|-------|-------------|---------|
| **Unlimited** | Stack everything | Risk of Rain 2 item stacking |
| **Soft cap** | Diminishing returns or dilution | Deckbuilders (bigger deck = less consistency) |
| **Hard cap** | Fixed slots | Vampire Survivors (6 weapons, 6 passives) |
| **Contextual** | Different limits for different types | Isaac (unlimited passives, 1-2 actives) |
| **Dynamic** | Capacity itself can change | Backpack size upgrades |

### 8. Interaction
*How do powers relate to each other?*

| Value | Description | Example |
|-------|-------------|---------|
| **Independent** | Each stands alone | Simple stat boosts |
| **Synergistic** | Combinations provide bonuses | Isaac item synergies |
| **Exclusive** | Some lock out others | Devil/Angel room exclusivity |
| **Hierarchical** | Prerequisites, skill trees | Traditional RPG skill trees |
| **Competitive** | Powers vie for limited resource | Mana/energy allocation |
| **Systemic** | Complex emergent interactions | Noita spell combinations |

### 9. Upgrade Depth
*How much can individual powers grow?*

| Value | Description | Example |
|-------|-------------|---------|
| **Flat** | Acquired at full power | Most Isaac items |
| **Linear** | Can upgrade incrementally | Hades boon levels |
| **Branching** | Choose upgrade path | Monster Train champion paths |
| **Infinite** | Keep stacking/improving | Risk of Rain 2 item stacking |
| **Evolutionary** | Transforms into something else | Vampire Survivors weapon evolutions |

### 10. Power Source Diversity
*Where does power come from?*

| Value | Description | Example |
|-------|-------------|---------|
| **Single source** | One system provides all power | Vampire Survivors (just upgrades) |
| **Dual source** | Two distinct systems contribute | Hades (boons + weapon aspects) |
| **Multi-source** | Several independent power systems | Isaac (items + pills + cards + trinkets + stats) |
| **Interconnected** | Multiple systems that affect each other | Darkest Dungeon (heroes + trinkets + skills + provisions + stress) |

---

## INFORMATION AXES

These govern what you KNOW about power.

### 11. Visibility
*What can you see about available powers?*

| Value | Description | Example |
|-------|-------------|---------|
| **Complete** | See all possibilities in the game | Into the Breach (all teams visible) |
| **Pool-visible** | See what's possible this run | TFT (know the unit pool) |
| **Forecast** | See upcoming options | Hades door previews, Curse of the Dead Gods paths |
| **Present** | See current options only | Standard pick 1 of 3 |
| **Obscured** | Some information hidden | Unknown item effects until used |
| **Progressive** | Revealed through exploration/proximity | Fog-of-war maps, gradually revealed skill trees |
| **Blind** | No information | Gacha pulls, mystery boxes |

### 12. Comprehension
*Do you understand what powers do?*

| Value | Description | Example |
|-------|-------------|---------|
| **Transparent** | Clear, predictable effects | Hades boon descriptions |
| **Calculable** | Effects clear but require math | Balatro multiplier calculations |
| **Learnable** | Must discover through experience | Isaac (hundreds of items, complex interactions) |
| **Opaque** | Hard to evaluate even with knowledge | Noita wand mechanics |
| **Unknown** | Must discover what it even does | Unidentified items, Isaac pills |

---

## PROGRESSION AXES

These govern how power CHANGES over time.

### 13. Growth Pattern
*How does total power change through the run?*

| Value | Description | Example |
|-------|-------------|---------|
| **Additive** | Monotonically gaining | Most roguelites |
| **Multiplicative** | Exponential scaling | Risk of Rain 2 late-game |
| **Subtractive** | Losing over time | Stress/permadeath in Darkest Dungeon |
| **Transformative** | Changing form, not necessarily growing | Build pivots in TFT |
| **Oscillating** | Power ebbs and flows | Loop Hero (stronger each loop, but so is world) |
| **Plateau** | Diminishing returns, power cap | Some balanced roguelites |

---

## META AXES

These govern persistence and starting conditions.

### 14. Persistence
*What carries between runs?*

| Value | Description | Example |
|-------|-------------|---------|
| **Nothing** | Pure roguelike | Traditional roguelikes |
| **Unlocks** | New options become available | Most roguelites |
| **Upgrades** | Permanent stat increases | Hades Mirror |
| **Resources** | Currency/materials carry over | Darkest Dungeon gold |
| **Progress** | Story/world changes | Hades story, Cult of the Lamb cult |
| **Legacy** | Previous runs affect future runs | Some elements in Rogue Legacy |

### 15. Starting Variance
*How different are run starts?*

| Value | Description | Example |
|-------|-------------|---------|
| **Identical** | Always same start | Pure starting position |
| **Character-varied** | Different characters/classes | Most roguelites |
| **Loadout-varied** | Choose starting gear | Hades keepsakes, weapons |
| **Random-varied** | Random starting conditions | Random starting items |
| **Seeded** | Deterministic based on seed | Daily challenges |
| **Inherited** | Based on previous run | Rogue Legacy traits |

### 16. Run Identity
*When does a run's "build" crystallize?*

| Value | Description | Example |
|-------|-------------|---------|
| **Pre-determined** | Identity set before run | Character choice is everything |
| **Early-crystallizing** | First few choices define run | Monster Train champion path |
| **Emergent** | Identity emerges from opportunities | Isaac "became a poison build" |
| **Fluid** | Can pivot throughout | TFT reroll compositions |
| **Convergent** | All runs approach similar end state | Limited viable builds |

---

## EXPERIENCE AXES

These govern how the player ENGAGES with power decisions.

### 17. Skill vs Build Ratio
*What matters more for success?*

| Value | Description | Example |
|-------|-------------|---------|
| **Execution-dominant** | Player skill matters most, build is secondary | Spelunky (items help but skill dominates) |
| **Build-dominant** | Right build matters most, execution is secondary | Vampire Survivors (right build plays itself) |
| **Balanced** | Both contribute meaningfully | Hades, Slay the Spire |
| **Knowledge-dominant** | Knowing interactions/mechanics matters most | Isaac (knowing item interactions matters most) |

---

## Game Classifications

[Framework](#the-framework) | [Games](#game-classifications) | [Frequency](#frequency-analysis) | [Designs](#hypothetical-designs) | [Experimental](#experimental-games-frequency-analysis)

### The Binding of Isaac (Repentance)

**1. Choice Timing:** Distributed + Reactive
- You make choices throughout the run, but often in response to what appears
- **Pacing:** Event-triggered (room clears, boss kills) + Resource-gated (shops require coins)

**2. Distribution Timing:** Immediate + Conditional
- Most items work instantly when picked up
- Active items require charges (Conditional)

**3. Agency:** Serendipitous + Curated + Influenced
- Room drops are random (Serendipitous)
- Shops, devil/angel rooms offer choices (Curated)
- Some items affect item pools (Influenced)

**4. Negative Acquisition:** Optional + Coupled + Forced
- Devil deals cost HP (Optional)
- Some items have downsides (Coupled - e.g., Soy Milk)
- Curses can be forced (Forced)

**5. Scarcity:** Moderate
- Enough items to build around, but can't take everything; key/coin constraints

**6. Reversibility:** Permanent + Transformable
- Most items are permanent once taken
- Reroll machines and D6 allow transformation
- **Commitment Weight:** Medium to Heavy — permanent choices, but many opportunities per run

**7. Capacity:** Contextual
- Unlimited passive items
- 1-2 active item slots (depending on items like Schoolbag)
- Limited consumable slots (cards, pills, runes)

**8. Interaction:** Highly Synergistic + Exclusive
- Items combo in complex, sometimes unexpected ways
- Devil/Angel exclusivity (taking devil deals locks angel rooms)

**9. Upgrade Depth:** Flat + some Transformable
- Most items are at full power when acquired
- Birthright can transform character-specific items
- Some items upgrade others (e.g., BFFS! affects familiars)

**10. Power Source Diversity:** Multi-source
- Passive items, active items, pills, cards, runes, trinkets, character stats, tainted character mechanics

**11. Visibility:** Present + Obscured
- See what's in the current room
- Secret rooms hidden; item effects not shown for new players (unless you use external resources)

**12. Comprehension:** Learnable + Unknown
- Hundreds of items requiring experience to understand
- Pills are unknown until identified each run
- Complex interactions not documented in-game

**13. Growth Pattern:** Additive + Transformative
- Generally gaining power throughout
- Some builds fundamentally transform how you play (Brimstone, Epic Fetus, etc.)

**14. Persistence:** Unlocks
- New items, characters, challenges, endings unlocked through achievements
- No permanent stat upgrades

**15. Starting Variance:** Character-varied + Random-varied
- Each character has different starting items/stats
- Eden has random starting items/stats
- Tainted characters add another layer

**16. Run Identity:** Emergent
- Builds emerge from what you find; "I became a Guppy run" or "this became a tear build"

**17. Skill vs Build Ratio:** Knowledge-dominant + Balanced
- Knowing item interactions is crucial (what to take, what to avoid, what combos)
- Execution still matters for dodging and positioning

---

### Hades

**1. Choice Timing:** Distributed
- Boon choices after most rooms
- **Pacing:** Event-triggered (room clears) + Resource-gated (shops with obols, wells with keys)

**2. Distribution Timing:** Immediate
- Boons work as soon as selected

**3. Agency:** Curated + Influenced
- Pick 1 of 3 boons (Curated)
- Keepsakes guarantee which god appears first (Influenced)
- Some boons affect future offerings (Influenced)

**4. Negative Acquisition:** Optional
- Chaos gates cost HP upfront for temporary debuff, then permanent buff
- No forced negatives in normal play

**5. Scarcity:** Moderate to Abundant
- Regular boon offerings, but can't take everything
- Enough gold to buy most shop items if you find shops

**6. Reversibility:** Permanent + Sellable
- Boons stay for the run
- Can sell boons at Wells of Charon
- **Commitment Weight:** Medium — permanent but frequent opportunities, selling is possible

**7. Capacity:** Unlimited + Contextual
- Can stack many boons
- Limited Cast slots (starts at 1, can increase)
- One Call at a time

**8. Interaction:** Synergistic
- Duo boons require specific prerequisites
- Legendary boons require specific god boons
- Status curse combos (e.g., Privileged Status)

**9. Upgrade Depth:** Linear + Evolutionary
- Boons can be upgraded with Poms of Power
- Duo and Legendary boons transform builds

**10. Power Source Diversity:** Multi-source
- Boons, Daedalus Hammers (weapon upgrades), Keepsakes, Mirror of Night (meta), Weapon Aspects

**11. Visibility:** Forecast + Present
- Door symbols preview reward type and which god
- See boon options when they appear

**12. Comprehension:** Transparent
- Boon descriptions clearly explain effects
- Numbers are visible

**13. Growth Pattern:** Additive

**14. Persistence:** Unlocks + Upgrades
- Unlock weapons, aspects, keepsakes (Unlocks)
- Mirror of Night provides permanent stat increases (Upgrades)

**15. Starting Variance:** Loadout-varied
- Choose weapon, aspect, and keepsake before each run
- Significantly affects playstyle

**16. Run Identity:** Emergent + Influenced
- Builds emerge from god offerings
- Keepsake choice influences early direction but doesn't guarantee anything

**17. Skill vs Build Ratio:** Balanced
- Combat execution matters (dodging, timing)
- Build matters (synergies, boon choices)
- Both contribute meaningfully to success

---

### Dead Cells

**1. Choice Timing:** Distributed + Pre-run
- Weapon/gear drops throughout
- Mutations selected at start of each biome
- **Pacing:** Event-triggered (room drops, challenge rooms) + Resource-gated (shops)

**2. Distribution Timing:** Immediate

**3. Agency:** Serendipitous + Curated
- Weapon drops are mostly random (Serendipitous)
- Mutations are chosen (Curated)
- Shops offer choices (Curated)

**4. Negative Acquisition:** Optional + Forced (higher difficulties)
- Cursed chests (Optional)
- Malaise in higher Boss Cells (Forced)

**5. Scarcity:** Abundant
- Lots of gear drops; main constraint is deciding what to keep

**6. Reversibility:** Swappable + Permanent
- 2 weapon slots, can swap anytime (Swappable)
- Mutations are locked until next biome (Permanent within biome)
- **Commitment Weight:** Light (weapons) to Medium (mutations)

**7. Capacity:** Hard cap
- 2 weapons, 2 skills, limited mutation slots (increases with BSC)

**8. Interaction:** Synergistic
- Affixes synergize (bleed, poison, burning)
- Mutations combo with weapon types (Brutality/Tactics/Survival)

**9. Upgrade Depth:** Linear (meta) + Flat (within run)
- Forge upgrades permanently improve gear quality (meta)
- Within a run, gear is what you find

**10. Power Source Diversity:** Multi-source
- Weapons, skills, mutations, scrolls (stat points), outfits (minor effects)

**11. Visibility:** Present + Forecast
- See current options
- Biome choice visible at transitions

**12. Comprehension:** Transparent
- Clear weapon/mutation descriptions

**13. Growth Pattern:** Additive

**14. Persistence:** Unlocks + Upgrades
- Unlock weapons, mutations, outfits, runes (permanent movement abilities)
- Forge upgrades persist

**15. Starting Variance:** Loadout-varied + Character-varied
- Choose starting gear
- DLC adds different characters with unique mechanics

**16. Run Identity:** Emergent + Influenced
- Build emerges from what you find
- Starting loadout and mutation path influence direction

**17. Skill vs Build Ratio:** Balanced to Execution-dominant
- Combat execution is demanding (parrying, dodging, timing)
- Build matters but won't carry you if you can't play

---

### Enter the Gungeon

**1. Choice Timing:** Distributed + Reactive
- Choices throughout, often reacting to what drops
- **Pacing:** Event-triggered (room clears, boss drops) + Resource-gated (shops)

**2. Distribution Timing:** Immediate

**3. Agency:** Serendipitous + Curated
- Chest drops are random (Serendipitous)
- Shops offer choices (Curated)

**4. Negative Acquisition:** Optional
- Cursed items exist but are optional
- Some shrines have risks

**5. Scarcity:** Moderate
- Limited keys (can't open every chest)
- Limited money
- Keys create genuine tension about which chests to open

**6. Reversibility:** Permanent + Swappable (rarely useful)
- Items are permanent
- Can technically drop guns but rarely want to
- **Commitment Weight:** Medium

**7. Capacity:** Unlimited (guns) + Contextual (active items)
- Can carry many guns (but ammo is a concern)
- 1 active item at a time (2 with backpack)

**8. Interaction:** Synergistic
- Gun/item synergies are explicit (shown in Ammonomicon)
- Certain item combinations create new effects

**9. Upgrade Depth:** Flat
- Items are at full power when acquired

**10. Power Source Diversity:** Multi-source
- Guns, passive items, active items

**11. Visibility:** Present

**12. Comprehension:** Learnable
- Many items to learn
- Synergies discoverable through play or external resources

**13. Growth Pattern:** Additive

**14. Persistence:** Unlocks
- Guns, items, characters, shortcuts
- No permanent power upgrades

**15. Starting Variance:** Character-varied
- Each Gungeoneer has unique starting loadout and passive ability

**16. Run Identity:** Emergent
- Builds emerge from drops

**17. Skill vs Build Ratio:** Balanced to Execution-dominant
- Dodge-rolling and shooting skill matter enormously
- Build helps but can't replace skill
- Boss fights especially test execution

---

### Noita

**1. Choice Timing:** Reactive
- Find wands and spells, then decide how to configure them
- **Pacing:** Event-triggered (exploration, Holy Mountain between zones)

**2. Distribution Timing:** Immediate

**3. Agency:** Serendipitous + Deterministic
- What wands/spells you find is random (Serendipitous)
- How you build wands is entirely player-controlled (Deterministic)

**4. Negative Acquisition:** Coupled + Optional
- Some perks have significant downsides (Coupled)
- Can choose to skip risky perks (Optional)

**5. Scarcity:** Moderate to Scarce
- Good wands/spells can be hard to find
- Holy Mountains are limited

**6. Reversibility:** Highly Swappable + Permanent
- Wands can be completely rebuilt at any time (Swappable)
- Perks are permanent
- **Commitment Weight:** Light (wands) to Heavy (perks)

**7. Capacity:** Hard cap
- 4 wand slots
- Limited spell slots per wand (varies by wand)

**8. Interaction:** Systemic
- Spells combine in emergent, complex ways
- Physics interactions with environment, liquids, materials
- Emergent chaos is the core appeal

**9. Upgrade Depth:** Transformative
- Wand building transforms base spells into entirely different behaviors
- Trigger spells, modifiers, etc. create new effects

**10. Power Source Diversity:** Multi-source
- Wands, spells, perks, flasks/potions, world interactions (kicking, throwing, physics)

**11. Visibility:** Present + Obscured
- See current options
- Many secrets, hidden spells, obscure interactions

**12. Comprehension:** Opaque + Learnable
- Wand mechanics (cast delay, recharge, mana drain) are complex and not fully explained in-game
- Can learn over time but wiki is almost required

**13. Growth Pattern:** Additive + Transformative
- Generally gaining power
- "God wands" can transform the game completely

**14. Persistence:** Unlocks (minimal)
- Some spells/perks unlock through achievements
- Much less meta-progression than other roguelites

**15. Starting Variance:** Minimal + Random-varied
- Always start in same place with same base equipment
- Starting wands have slight variance

**16. Run Identity:** Emergent
- Heavily dependent on what wands/spells you find
- A good wand changes everything

**17. Skill vs Build Ratio:** Knowledge-dominant + Balanced
- Understanding wand mechanics is crucial
- Execution matters for dodging in a physics-based environment
- Knowing secrets/tricks provides huge advantages

---

### Nuclear Throne

**1. Choice Timing:** Distributed
- Mutations after each level
- **Pacing:** Fixed interval (level completion triggers mutation choice)

**2. Distribution Timing:** Immediate

**3. Agency:** Curated + Serendipitous
- Choose 1 of 4 mutations (Curated)
- Weapon drops are random (Serendipitous)

**4. Negative Acquisition:** None
- Mutations are pure positives
- Some characters have built-in trade-offs (e.g., Melting has low HP)

**5. Scarcity:** Moderate
- Weapons drop frequently but can only carry 2
- Ammo can be scarce for certain weapon types

**6. Reversibility:** Permanent + Swappable
- Mutations are permanent
- 2 weapon slots, can swap by picking up new weapons
- **Commitment Weight:** Medium

**7. Capacity:** Hard cap
- 2 weapons
- Mutations soft cap around 9-10 (depending on ultra mutations)

**8. Interaction:** Synergistic
- Mutations combo with weapon types (e.g., Bolt Marrow with bolt weapons)
- Character abilities synergize with certain builds

**9. Upgrade Depth:** Flat
- Mutations are at full power when selected

**10. Power Source Diversity:** Dual source + Character abilities
- Weapons, mutations
- Character unique abilities (actives and passives)

**11. Visibility:** Present

**12. Comprehension:** Transparent
- Mutation descriptions are clear
- Weapon behavior is learnable through use

**13. Growth Pattern:** Additive

**14. Persistence:** Unlocks
- Characters, golden weapons (starting weapons), crowns (modifiers)
- No permanent power upgrades

**15. Starting Variance:** Character-varied
- Each character plays very differently (Fish can roll, Eyes can telekinesis, Crystal can shield, etc.)

**16. Run Identity:** Emergent + Influenced by character
- Build emerges from mutations and weapon finds
- Character choice influences what works

**17. Skill vs Build Ratio:** Execution-dominant
- Extremely twitchy, fast-paced shooter
- Reflexes and movement matter most
- Build helps but won't save poor execution

---

### Vampire Survivors

**1. Choice Timing:** Distributed
- Level-up choices throughout
- **Pacing:** Fixed interval (XP-based level-ups, very frequent early, slows down later)

**2. Distribution Timing:** Immediate

**3. Agency:** Curated
- Choose 1 of 3-4 options per level-up

**4. Negative Acquisition:** None
- Pure power gain

**5. Scarcity:** Abundant
- Constant stream of level-ups
- More options than you can take

**6. Reversibility:** Permanent + Evolutionary
- Choices are permanent
- Weapons evolve with correct passive item
- **Commitment Weight:** Medium (permanent but frequent choices)

**7. Capacity:** Hard cap
- 6 weapon slots
- 6 passive item slots

**8. Interaction:** Synergistic
- Evolution requirements (specific weapon + specific passive)
- Passives affect weapons (e.g., Spinach affects all damage)

**9. Upgrade Depth:** Linear + Evolutionary
- Weapons level up incrementally (8 levels)
- Final evolution transforms weapon

**10. Power Source Diversity:** Single source + Character
- Primarily just the upgrade system
- Character choice adds starting weapon/passive

**11. Visibility:** Present

**12. Comprehension:** Transparent
- Clear what everything does

**13. Growth Pattern:** Additive (exponential in practice)
- Power snowballs dramatically

**14. Persistence:** Unlocks + Upgrades
- Unlock characters, stages, weapons (Unlocks)
- PowerUps provide permanent stat boosts (Upgrades)

**15. Starting Variance:** Character-varied + Loadout-varied
- Different characters have different starting weapons and stats
- Some characters let you choose starting weapon

**16. Run Identity:** Early-crystallizing
- First few weapon choices largely define the run
- Hard to pivot once committed

**17. Skill vs Build Ratio:** Build-dominant
- Right build plays itself
- Positioning matters but is secondary
- Some execution in dodging gaps, but mostly automatic

---

### Brotato

**1. Choice Timing:** Distributed
- Shop between waves
- **Pacing:** Fixed interval (wave completion)

**2. Distribution Timing:** Immediate

**3. Agency:** Curated + Influenced
- Shop offers random items, you choose what to buy (Curated)
- Can reroll shop (Influenced)

**4. Negative Acquisition:** Optional + Character-based
- Some items have stat penalties (Optional)
- Some characters have built-in negatives (e.g., can't move, limited slots)

**5. Scarcity:** Moderate
- Limited gold per wave
- Must prioritize purchases

**6. Reversibility:** Swappable + Permanent
- Weapons can be sold (recover some gold)
- Stats from items are permanent for the run
- **Commitment Weight:** Light to Medium

**7. Capacity:** Hard cap
- 6 weapon slots
- Some characters modify this

**8. Interaction:** Synergistic
- Stats scale together (e.g., crit + crit damage)
- Weapon types benefit from specific stats

**9. Upgrade Depth:** Linear
- Weapons can be upgraded/tiered up in shop

**10. Power Source Diversity:** Dual source
- Weapons, items (which give stats)

**11. Visibility:** Complete
- See entire shop
- Know what items exist

**12. Comprehension:** Transparent
- Clear stat effects

**13. Growth Pattern:** Additive

**14. Persistence:** Unlocks
- Characters, items, weapons

**15. Starting Variance:** Character-varied
- Each character has unique restrictions/bonuses
- Wide variety of playstyles (melee only, ranged only, one weapon, etc.)

**16. Run Identity:** Emergent + Influenced by character
- Build emerges from shop offerings
- Character choice heavily constrains options

**17. Skill vs Build Ratio:** Build-dominant + some Execution
- Build matters most
- Movement and positioning help but aren't primary

---

### SNKRX

**1. Choice Timing:** Distributed
- Shop between rounds
- **Pacing:** Fixed interval (round completion)

**2. Distribution Timing:** Immediate

**3. Agency:** Curated + Influenced
- Shop offers random units (Curated)
- Can reroll (Influenced)
- Later rounds unlock higher tier units

**4. Negative Acquisition:** None

**5. Scarcity:** Moderate
- Limited gold per round

**6. Reversibility:** Sellable + Swappable
- Can sell units
- Can rearrange snake order
- **Commitment Weight:** Light

**7. Capacity:** Hard cap
- Snake length limit (increases as you progress)

**8. Interaction:** Synergistic
- Class synergies (like auto-battlers)
- Units trigger off each other

**9. Upgrade Depth:** Linear
- Units upgrade by buying duplicates (3 to level up, like auto-battlers)

**10. Power Source Diversity:** Single source
- Just units with class bonuses

**11. Visibility:** Complete + Pool-visible
- See shop
- Know what units exist per tier

**12. Comprehension:** Transparent
- Clear ability descriptions

**13. Growth Pattern:** Additive

**14. Persistence:** Unlocks
- Units, classes

**15. Starting Variance:** Character-varied
- Different starting "leader" units with different passives

**16. Run Identity:** Emergent
- Based on what synergies you find/can build

**17. Skill vs Build Ratio:** Build-dominant + some Execution
- Auto-battler core (build matters most)
- Snake movement requires some skill/attention

---

### 20 Minutes Till Dawn

**1. Choice Timing:** Distributed
- Level-up choices throughout
- **Pacing:** Fixed interval (XP-based, frequent)

**2. Distribution Timing:** Immediate

**3. Agency:** Curated
- Choose 1 of 3-4 options

**4. Negative Acquisition:** None (or minimal)

**5. Scarcity:** Abundant
- Frequent level-ups

**6. Reversibility:** Permanent
- **Commitment Weight:** Medium

**7. Capacity:** Soft cap
- Many upgrade slots, but some upgrades max out

**8. Interaction:** Synergistic
- Upgrade combos (summons, bullets, elemental effects)

**9. Upgrade Depth:** Linear
- Upgrades can level up

**10. Power Source Diversity:** Dual source
- Weapon choice (selected at start) + upgrades

**11. Visibility:** Present

**12. Comprehension:** Transparent

**13. Growth Pattern:** Additive

**14. Persistence:** Unlocks
- Characters, weapons

**15. Starting Variance:** Character-varied + Loadout-varied
- Different characters have different abilities
- Weapon choice at start affects available upgrades

**16. Run Identity:** Emergent + Influenced by starting weapon
- Weapon choice matters (e.g., shotgun vs sniper build around different upgrades)

**17. Skill vs Build Ratio:** Balanced
- More aiming skill required than Vampire Survivors
- Build still matters

---

### Slay the Spire

**1. Choice Timing:** Distributed
- Card rewards, events, shops throughout
- **Pacing:** Event-triggered (combat rewards) + Resource-gated (shops, card removal)

**2. Distribution Timing:** Immediate + Delayed-Random
- Cards added to deck immediately
- Cards accessed randomly when drawn in combat

**3. Agency:** Curated + Influenced
- Choose 1 of 3 cards (or skip) — Curated
- Card removal, transform events affect deck composition (Influenced)
- Potions can be saved for when needed

**4. Negative Acquisition:** Optional
- Curses from events, relics, bosses (can often be avoided)
- Some relics have downsides

**5. Scarcity:** Moderate
- Can't take everything (gold limited)
- Skipping cards is often correct

**6. Reversibility:** Removable + Transformable
- Card removal at shops and events
- Card upgrades at rest sites
- **Commitment Weight:** Medium (cards are permanent additions, but removal is possible)

**7. Capacity:** Soft cap
- Bigger deck = less consistent draws
- Thin decks are often stronger

**8. Interaction:** Synergistic
- Deck archetypes (Shiv deck, Strength deck, Block deck, etc.)
- Card combos (Catalyst + Poison, Limit Break + Strength)

**9. Upgrade Depth:** Linear
- Cards can be upgraded once

**10. Power Source Diversity:** Multi-source
- Cards, relics, potions

**11. Visibility:** Present + Complete + Forecast
- See card reward options
- Can view deck/relics anytime (Complete)
- Map shows paths and node types (Forecast)

**12. Comprehension:** Transparent
- Card effects clearly described

**13. Growth Pattern:** Additive + strategic Subtractive
- Generally gaining power
- Removing bad cards is often as important as adding good ones

**14. Persistence:** Unlocks
- Cards, relics unlocked per character through play

**15. Starting Variance:** Character-varied
- 4 characters with completely different card pools and mechanics

**16. Run Identity:** Emergent
- Deck archetype emerges from early card choices and offerings
- "This became an exhaust deck" or "I'm going infinite"

**17. Skill vs Build Ratio:** Balanced
- Deckbuilding decisions crucial
- In-combat play (card sequencing, math) also crucial

---

### Balatro

**1. Choice Timing:** Distributed
- Shop between blinds
- **Pacing:** Fixed interval (after each blind)

**2. Distribution Timing:** Immediate + Delayed-Random
- Jokers work immediately
- Cards in deck are drawn randomly

**3. Agency:** Curated + Influenced
- Shop offers options (Curated)
- Vouchers affect shop
- Tags at start of ante affect options (Influenced)

**4. Negative Acquisition:** Optional
- Debuff cards can appear but can be avoided or removed

**5. Scarcity:** Moderate
- Limited money
- Careful spending needed

**6. Reversibility:** Sellable + Removable + Transformable
- Jokers can be sold
- Cards can be destroyed or sold
- Cards can gain enhancements, editions, seals
- **Commitment Weight:** Light to Medium (lots of flexibility)

**7. Capacity:** Hard cap
- Joker slots (starts at 5, can increase)
- Consumable slots

**8. Interaction:** Highly Synergistic
- Joker combos are the core game
- Mult + Chips + Mult again chains

**9. Upgrade Depth:** Transformable
- Cards gain enhancements (mult, chips, etc.)
- Cards gain editions (foil, holo, polychrome)
- Cards gain seals (special effects)

**10. Power Source Diversity:** Multi-source
- Jokers, deck modifications, vouchers, consumables (tarots, planets, spectrals)

**11. Visibility:** Present + Complete
- See shop
- See deck and jokers anytime

**12. Comprehension:** Calculable + Transparent
- Effects are clear
- Need to calculate mult chains (which the game shows)

**13. Growth Pattern:** Multiplicative
- Exponential scaling is the explicit goal
- Run ends if you can't hit increasing score thresholds

**14. Persistence:** Unlocks
- Jokers, decks, vouchers, etc.

**15. Starting Variance:** Loadout-varied
- Deck choice significantly affects strategy (e.g., Plasma Deck, Abandoned Deck)

**16. Run Identity:** Early-crystallizing + can be Fluid
- First jokers often define the run
- Can sometimes pivot if you find a stronger option

**17. Skill vs Build Ratio:** Build-dominant + Knowledge-dominant
- Right joker combo wins
- Understanding synergies is crucial
- Some execution in hand selection but mostly build

---

### Peglin

**1. Choice Timing:** Distributed
- After battles
- **Pacing:** Event-triggered (battle completion)

**2. Distribution Timing:** Immediate + Delayed-Random
- Orbs added to pouch immediately
- Orbs drawn randomly in combat

**3. Agency:** Curated
- Choose 1 of 3 orbs typically

**4. Negative Acquisition:** Optional
- Some events/choices can add negative orbs

**5. Scarcity:** Moderate
- Enough choices but can't take everything

**6. Reversibility:** Removable + Transformable
- Can discard orbs
- Can upgrade orbs
- **Commitment Weight:** Medium

**7. Capacity:** Soft cap
- Pouch size matters (more orbs = less consistency per orb, like a deck)

**8. Interaction:** Synergistic
- Orb effects combo
- Relic synergies

**9. Upgrade Depth:** Linear
- Orbs can be upgraded (typically 3 levels)

**10. Power Source Diversity:** Dual source
- Orbs, relics

**11. Visibility:** Present + Complete
- See options
- See entire pouch

**12. Comprehension:** Transparent
- Clear effect descriptions

**13. Growth Pattern:** Additive

**14. Persistence:** Unlocks
- Orbs, relics, characters

**15. Starting Variance:** Character-varied
- Different characters have different starting orbs and abilities

**16. Run Identity:** Emergent
- Build emerges from orb choices

**17. Skill vs Build Ratio:** Balanced + Execution
- Build matters
- Aiming the peglin shot has skill (where you aim, what pegs you hit)
- Some RNG in bounces

---

### Super Auto Pets

**1. Choice Timing:** Continuous
- Shop every single round
- **Pacing:** Fixed interval (between each battle)

**2. Distribution Timing:** Immediate

**3. Agency:** Curated + Influenced
- Shop offers options (Curated)
- Rerolls (Influenced)
- Tier unlocks based on turns (automatic progression)

**4. Negative Acquisition:** None

**5. Scarcity:** Moderate
- Limited gold per turn (10)
- Can't buy everything

**6. Reversibility:** Sellable + Swappable
- Pets can be sold (returns 1 gold)
- Team can be fully reorganized
- **Commitment Weight:** Light (very flexible, pivoting is core skill)

**7. Capacity:** Hard cap
- 5 team slots
- Bench for holding pets

**8. Interaction:** Highly Synergistic
- Pet abilities trigger off each other
- Order matters (abilities trigger front to back or on specific events)

**9. Upgrade Depth:** Linear
- Pets level up by combining duplicates (3 copies → level 2, etc.)

**10. Power Source Diversity:** Dual source
- Pets, food items

**11. Visibility:** Complete + Pool-visible
- See shop
- Know what pets exist in each tier

**12. Comprehension:** Transparent
- Ability descriptions are clear

**13. Growth Pattern:** Additive + Transformative
- Power grows
- Can transform build entirely by selling and pivoting

**14. Persistence:** Unlocks
- Pets, packs (different pet pools)

**15. Starting Variance:** Identical + Loadout-varied
- Everyone starts with 10 gold, empty team
- Pack selection varies the available pet pool

**16. Run Identity:** Fluid
- Can pivot throughout
- Adapting to what you're offered is key skill

**17. Skill vs Build Ratio:** Build-dominant + Knowledge-dominant
- Team composition is everything
- Knowing combos and meta is crucial
- No execution during battles (auto-battler)

---

### Teamfight Tactics (TFT)

**1. Choice Timing:** Continuous
- Shop every round
- Carousel rounds at intervals
- **Pacing:** Fixed interval (between rounds) + Event-triggered (carousel, special rounds)

**2. Distribution Timing:** Immediate

**3. Agency:** Curated + Influenced + Competitive
- Shop offers options (Curated)
- Rerolls, leveling affects pool (Influenced)
- Shared pool with 7 other players (Competitive)

**4. Negative Acquisition:** None directly
- Falling behind is implicit punishment, not explicit negatives

**5. Scarcity:** Competitive + Resource-gated
- 8 players share the unit pool
- Gold economy (interest, streaks)

**6. Reversibility:** Sellable + Swappable
- Units can be sold (full refund)
- Board positioning fully changeable
- **Commitment Weight:** Light (can pivot), becoming Heavy if you've invested deeply in a comp

**7. Capacity:** Hard cap
- Board slots (based on level)
- Bench slots

**8. Interaction:** Systemic
- Traits provide bonuses at thresholds
- Items combine into completed items
- Positioning matters for abilities
- Augments add another layer

**9. Upgrade Depth:** Linear
- 3-star upgrades (3 copies → 2-star, 9 copies → 3-star)

**10. Power Source Diversity:** Multi-source
- Champions, items, augments (in current sets), traits, positioning

**11. Visibility:** Pool-visible + Forecast
- Know the unit pool and what others are taking
- See upcoming carousel

**12. Comprehension:** Learnable
- Complex trait interactions
- Meta knowledge matters

**13. Growth Pattern:** Oscillating
- Win streaks / loss streaks
- Power spikes at key upgrades (2-star, 3-star, hitting trait threshold)

**14. Persistence:** Nothing within game
- Ranked progression outside of individual games

**15. Starting Variance:** Varied
- Different augment choices
- Different item drops from PvE rounds
- Carousel picks

**16. Run Identity:** Fluid + can Early-crystallize
- Pivoting is core skill
- Sometimes you commit early to a comp

**17. Skill vs Build Ratio:** Build-dominant + Knowledge-dominant
- Knowing meta comps crucial
- Knowing when to pivot crucial
- Economy management matters
- No execution (auto-battler)

---

### Dota Underlords

Very similar to TFT. Key differences noted:

**1. Choice Timing:** Continuous
- **Pacing:** Fixed interval

**2. Distribution Timing:** Immediate

**3. Agency:** Curated + Influenced + Competitive

**4. Negative Acquisition:** None

**5. Scarcity:** Competitive

**6. Reversibility:** Sellable + Swappable
- **Commitment Weight:** Light to Medium

**7. Capacity:** Hard cap

**8. Interaction:** Systemic
- Alliances instead of traits (but same concept)

**9. Upgrade Depth:** Linear (star upgrades)

**10. Power Source Diversity:** Multi-source
- Heroes, items, Underlords (unique to this game)

**11. Visibility:** Pool-visible

**12. Comprehension:** Learnable

**13. Growth Pattern:** Oscillating

**14. Persistence:** Nothing (ranked outside)

**15. Starting Variance:** Varied

**16. Run Identity:** Fluid

**17. Skill vs Build Ratio:** Build-dominant + Knowledge-dominant

---

### Into the Breach

**1. Choice Timing:** Pre-run + Milestone
- Team selected before run
- Pilot recruitment and reactor upgrades during run
- **Pacing:** Milestone (island completion) + Resource-gated (reputation spending)

**2. Distribution Timing:** Frontloaded + Distributed
- Team is set from start (Frontloaded)
- Pilots and reactor cores acquired during run (Distributed)

**3. Agency:** Deterministic + Curated
- Team selection is exact choice (Deterministic)
- Pilot recruitment from options (Curated)

**4. Negative Acquisition:** None

**5. Scarcity:** Scarce
- Reputation is limited
- Must prioritize upgrades carefully
- Can't max everything

**6. Reversibility:** Permanent + Swappable
- Team choice is permanent for the run
- Pilots can be reassigned between mechs
- **Commitment Weight:** Critical (team choice defines everything)

**7. Capacity:** Hard cap
- 3 mechs
- Limited weapon slots per mech
- Limited reactor cores to distribute

**8. Interaction:** Highly Synergistic
- Team composition matters
- Positioning interactions (pushing enemies into each other, into water, etc.)

**9. Upgrade Depth:** Linear
- Weapons can be powered up with reactor cores

**10. Power Source Diversity:** Multi-source
- Mechs, pilots, reactor upgrades, grid power (defensive resource)

**11. Visibility:** Complete + Transparent
- All teams visible from start
- Enemy intent shown (perfect information during combat)

**12. Comprehension:** Transparent
- Complete information game
- All effects clearly shown

**13. Growth Pattern:** Additive (small increments)
- Power gains are modest
- Mostly about making existing tools better

**14. Persistence:** Unlocks + Legacy
- Unlock squads, pilots
- One pilot survives to next run (carries over XP and can be used)

**15. Starting Variance:** Loadout-varied
- Team selection is the primary variance

**16. Run Identity:** Pre-determined
- Team choice defines the entire run
- You play to your team's strengths

**17. Skill vs Build Ratio:** Execution-dominant
- Puzzle-like tactical execution is primary
- Team choice (Build) determines what tools you have
- Within a run, it's all about using those tools perfectly

---

### FTL: Faster Than Light

**1. Choice Timing:** Reactive + Distributed
- Events offer choices based on situation
- Shops when you find them
- **Pacing:** Event-triggered (beacon jumps) + Resource-gated (scrap for purchases)

**2. Distribution Timing:** Immediate

**3. Agency:** Serendipitous + Curated
- Events are random (Serendipitous)
- Some events offer choices; shops let you choose (Curated)

**4. Negative Acquisition:** Forced + Optional
- Blue options require specific setup (Forced to have equipment to access good outcomes)
- Some events risk crew or ship damage (Optional)

**5. Scarcity:** Scarce
- Scrap is limited
- Must prioritize carefully
- Can't buy everything you want

**6. Reversibility:** Permanent + Sellable + Swappable
- System upgrades permanent
- Weapons/drones can be sold
- Weapon loadout can be rearranged within slots
- **Commitment Weight:** Heavy (scrap is precious)

**7. Capacity:** Hard cap
- Weapon slots (varies by ship)
- Drone slots
- Augment slots (3)
- System slots (some optional systems compete for same slot)

**8. Interaction:** Systemic
- Weapons synergize (e.g., ion weapons + beam weapons)
- Systems interact (cloak timing, doors + O2)
- Crew abilities interact with ship
- Ship design as holistic system

**9. Upgrade Depth:** Linear
- Systems can be upgraded with scrap (up to max level)

**10. Power Source Diversity:** Multi-source
- Weapons, drones, systems, augments, crew

**11. Visibility:** Forecast + Present
- Sector map shows beacon paths (Forecast)
- See current options

**12. Comprehension:** Transparent
- Clear descriptions

**13. Growth Pattern:** Additive

**14. Persistence:** Unlocks
- Ships, ship layouts

**15. Starting Variance:** Character-varied
- Ships play very differently (e.g., Stealth ship vs Boarding ship vs Artillery ship)

**16. Run Identity:** Emergent + Influenced by ship
- Build emerges from what you find
- Ship choice constrains and enables certain strategies

**17. Skill vs Build Ratio:** Balanced
- Tactical combat decisions matter (weapon timing, power management, targeting)
- Ship build matters (having the right tools for the final boss)
- Route decisions matter

---

### Spelunky 1/2

**1. Choice Timing:** Reactive
- Find items, decide whether to pick up
- **Pacing:** Event-triggered (exploration, shops, crates)

**2. Distribution Timing:** Immediate

**3. Agency:** Serendipitous + Curated
- Find what you find (Serendipitous)
- Shops let you buy specific items (Curated)

**4. Negative Acquisition:** Optional + Coupled
- Cursed pots in Spelunky 2 (Optional to break)
- Some items have drawbacks (e.g., Teleporter risk) — (Coupled)

**5. Scarcity:** Scarce
- Items are rare
- Money is limited
- Most runs you have very few items

**6. Reversibility:** Swappable + Consumable
- One held item at a time, swap by picking up new one (Swappable)
- Bombs and ropes are consumable (Consumable)
- **Commitment Weight:** Light (held items) to Heavy (consumables are permanent loss)

**7. Capacity:** Hard cap
- 1 held item (2 with powerpack in Spelunky 2)
- Limited back item slot in Spelunky 2

**8. Interaction:** Systemic
- Physics interactions with environment
- Items interact with world (e.g., pitcher's mitt + rocks)
- Emergent chaos

**9. Upgrade Depth:** Flat
- Items are what they are, no upgrading

**10. Power Source Diversity:** Multi-source
- Held items, back items (S2), consumables (bombs, ropes), shortcuts knowledge

**11. Visibility:** Present

**12. Comprehension:** Learnable
- Many interactions to discover
- Some items have non-obvious uses

**13. Growth Pattern:** Minimal
- Small power gains
- Mostly flat — you don't really "power up"

**14. Persistence:** Unlocks + minimal
- Shortcuts, characters
- No power persistence

**15. Starting Variance:** Character-varied (minor) + Identical
- Character differences are minor
- Core gameplay starts same every run

**16. Run Identity:** Minimal
- Not really "builds" in traditional sense
- Runs are defined by execution and adaptation, not accumulated power

**17. Skill vs Build Ratio:** Execution-dominant
- Player skill is almost everything
- Items help but can't carry you
- Knowing the game helps (Knowledge) but execution is king

---

### Rogue Legacy (Early Game / Fresh Save)

**1. Choice Timing:** Pre-run + Distributed
- Heir selection with traits
- Some gear found in castle
- **Pacing:** Pre-run (heir choice) + Event-triggered (finding gear)

**2. Distribution Timing:** Immediate

**3. Agency:** Curated + Serendipitous
- Choose from 3 heirs (Curated)
- Gear found in castle is random (Serendipitous)

**4. Negative Acquisition:** Forced + Optional
- Traits can be negative (Forced — heirs come with traits)
- Can choose heir with fewer/better traits (Optional)

**5. Scarcity:** Scarce
- Gold is limited
- Manor upgrades are expensive
- Progress is slow

**6. Reversibility:** Permanent + Swappable
- Manor upgrades permanent
- Gear can be swapped
- **Commitment Weight:** Heavy (gold is precious, each choice matters)

**7. Capacity:** Hard cap
- Equipment slots

**8. Interaction:** Synergistic
- Class abilities + gear + traits can combo
- Runes affect gameplay

**9. Upgrade Depth:** Linear
- Manor upgrades

**10. Power Source Diversity:** Multi-source
- Manor upgrades, gear, runes, class abilities, traits

**11. Visibility:** Present

**12. Comprehension:** Transparent

**13. Growth Pattern:** Additive (meta-progression focused)
- Within-run growth is minimal
- Primary progression is between runs

**14. Persistence:** Upgrades + Resources
- Manor is permanent
- Gold carries over (minus Charon tax)

**15. Starting Variance:** Character-varied
- Class + traits make each heir different

**16. Run Identity:** Pre-determined by heir + accumulated upgrades

**17. Skill vs Build Ratio:** Balanced
- Skill matters because you're weak
- Build (manor upgrades) slowly shifts the balance
- Need skill to survive and earn gold

---

### Rogue Legacy (Late Game / Full Manor)

**1. Choice Timing:** Pre-run
- Heir selection
- **Pacing:** Pre-run (already have everything)

**2. Distribution Timing:** Frontloaded
- Start with full manor benefits

**3. Agency:** Curated
- Heir choice from 3 options

**4. Negative Acquisition:** Forced
- Traits still random, but often neutral or beneficial at this point

**5. Scarcity:** Abundant
- Already powerful from start
- Gold abundant (more than needed)

**6. Reversibility:** Permanent
- **Commitment Weight:** Medium (heir choice matters but runs are easier)

**7. Capacity:** Hard cap

**8. Interaction:** Synergistic

**9. Upgrade Depth:** Maxed (completed progression)

**10. Power Source Diversity:** Multi-source

**11. Visibility:** Present

**12. Comprehension:** Transparent

**13. Growth Pattern:** Minimal within run
- Already at high power
- Run is about using that power

**14. Persistence:** Maxed

**15. Starting Variance:** Character-varied

**16. Run Identity:** Pre-determined
- Class/traits define the run experience

**17. Skill vs Build Ratio:** Build-dominant (normal play) + Execution-dominant (NG+ difficulties)
- Manor makes you powerful
- NG+ and beyond require execution again

---

### Risk of Rain 1

**1. Choice Timing:** Reactive
- Find items in chests, limited choice beyond that
- **Pacing:** Event-triggered (chests, bosses) + Resource-gated (gold for chests) + Time-scaled (difficulty increases constantly)

**2. Distribution Timing:** Immediate

**3. Agency:** Serendipitous + Curated (minor)
- Chest items are random (Serendipitous)
- Shrines offer some choices (Curated)
- Can choose which chests to open

**4. Negative Acquisition:** Optional
- Some items have trade-offs (e.g., Shaped Glass — double damage, half HP)

**5. Scarcity:** Time-pressured
- Spending time to find items increases difficulty
- Creates urgency — unique scarcity model

**6. Reversibility:** Permanent
- Items cannot be removed
- **Commitment Weight:** Medium (permanent but not chosen)

**7. Capacity:** Unlimited
- Can stack items infinitely
- Stacking is the goal

**8. Interaction:** Synergistic + Multiplicative
- Items combo
- Stacking creates exponential effects

**9. Upgrade Depth:** Infinite
- Stacking same item multiple times

**10. Power Source Diversity:** Dual source
- Items, character abilities

**11. Visibility:** Present

**12. Comprehension:** Transparent to Learnable
- Item descriptions clear
- Some interactions require learning

**13. Growth Pattern:** Multiplicative / Exponential
- Stacking leads to massive power
- Goes from struggling to godlike

**14. Persistence:** Unlocks
- Items, characters, artifacts

**15. Starting Variance:** Character-varied
- Each survivor plays differently (Commando vs Engineer vs Mercenary, etc.)

**16. Run Identity:** Emergent + can become Convergent
- Build emerges from finds
- Optimal stacking can make runs similar (stack Soldier's Syringes, etc.)

**17. Skill vs Build Ratio:** Balanced
- Execution matters early (before power spike)
- Build dominates late (become unkillable)

---

### Risk of Rain 2

Similar to RoR1, adapted to 3D:

**1. Choice Timing:** Reactive
- **Pacing:** Event-triggered + Resource-gated + Time-scaled (difficulty timer)

**2. Distribution Timing:** Immediate

**3. Agency:** Serendipitous + Influenced
- Chest items random (Serendipitous)
- 3D Printers let you trade items (Influenced)
- Scrappers let you convert to scrap (Influenced)

**4. Negative Acquisition:** Optional
- Lunar items have trade-offs
- Shaped Glass, etc.

**5. Scarcity:** Time-pressured
- Difficulty scales with time
- Fast runs vs thorough runs is a real tension

**6. Reversibility:** Permanent + Transformable
- Items permanent
- 3D Printers and Scrappers allow transformation
- **Commitment Weight:** Medium

**7. Capacity:** Unlimited

**8. Interaction:** Synergistic + Multiplicative

**9. Upgrade Depth:** Infinite (stacking)

**10. Power Source Diversity:** Multi-source
- Items (white/green/red), equipment (active), lunar items, character abilities, alternate skills

**11. Visibility:** Present

**12. Comprehension:** Transparent
- Item descriptions are clear

**13. Growth Pattern:** Multiplicative / Exponential

**14. Persistence:** Unlocks
- Items, characters, artifacts, alternate skills

**15. Starting Variance:** Character-varied + Loadout-varied
- Survivors play very differently
- Equipment choice
- Alternate skills

**16. Run Identity:** Emergent + can Convergent (when looping)

**17. Skill vs Build Ratio:** Balanced
- 3D movement skill matters more than 2D
- Build still dominates late-game

---

## Frequency Analysis

[Framework](#the-framework) | [Games](#game-classifications) | [Frequency](#frequency-analysis) | [Designs](#hypothetical-designs) | [Experimental](#experimental-games-frequency-analysis)

Based on 22 game classifications (including Rogue Legacy Early/Late as separate entries).

### 1. Choice Timing
- Distributed (14): Isaac, Hades, Dead Cells, Gungeon, Nuclear Throne, Vampire Survivors, Brotato, SNKRX, 20 Minutes Till Dawn, Slay the Spire, Balatro, Peglin, FTL, Rogue Legacy Early
- Reactive (7): Isaac, Gungeon, Noita, FTL, Spelunky, Risk of Rain 1, Risk of Rain 2
- Pre-run (4): Dead Cells, Into the Breach, Rogue Legacy Early, Rogue Legacy Late
- Continuous (3): Super Auto Pets, TFT, Underlords
- Milestone (1): Into the Breach
- Early-run (0): None

#### Pacing
- Event-triggered (13): Isaac, Hades, Dead Cells, Gungeon, Noita, Slay the Spire, Peglin, TFT, FTL, Spelunky, Rogue Legacy Early, Risk of Rain 1, Risk of Rain 2
- Resource-gated (9): Isaac, Hades, Dead Cells, Gungeon, Slay the Spire, Into the Breach, FTL, Risk of Rain 1, Risk of Rain 2
- Fixed interval (9): Nuclear Throne, Vampire Survivors, Brotato, SNKRX, 20 Minutes Till Dawn, Balatro, Super Auto Pets, TFT, Underlords
- Pre-run (2): Rogue Legacy Early, Rogue Legacy Late
- Time-scaled (2): Risk of Rain 1, Risk of Rain 2
- Milestone (1): Into the Breach
- Performance-based (0), Player-controlled (0), Continuous (0): None

### 2. Distribution Timing
- Immediate (21): Almost all games
- Delayed-Random (3): Slay the Spire, Balatro, Peglin
- Frontloaded (2): Into the Breach, Rogue Legacy Late
- Conditional (1): Isaac
- Distributed (1): Into the Breach
- Delayed-Sequential (0): None

### 3. Agency
- Curated (20): Almost all games
- Serendipitous (10): Isaac, Dead Cells, Gungeon, Noita, Nuclear Throne, FTL, Spelunky, Rogue Legacy Early, Risk of Rain 1, Risk of Rain 2
- Influenced (10): Isaac, Hades, Brotato, SNKRX, Slay the Spire, Balatro, Super Auto Pets, TFT, Underlords, Risk of Rain 2
- Deterministic (2): Noita, Into the Breach
- Competitive (2): TFT, Underlords
- Predetermined (0): None

### 4. Negative Acquisition
- Optional (14): Isaac, Hades, Dead Cells, Gungeon, Noita, Brotato, Slay the Spire, Balatro, Peglin, FTL, Spelunky, Rogue Legacy Early, Risk of Rain 1, Risk of Rain 2
- None (8): Nuclear Throne, Vampire Survivors, SNKRX, 20 Minutes Till Dawn, Super Auto Pets, TFT, Underlords, Into the Breach
- Forced (5): Isaac, Dead Cells, FTL, Rogue Legacy Early, Rogue Legacy Late
- Coupled (3): Isaac, Noita, Spelunky
- Traded (0): None

### 5. Scarcity
- Moderate (~11): Isaac, Gungeon, Nuclear Throne, Brotato, SNKRX, Slay the Spire, Balatro, Peglin, Super Auto Pets (+ Hades, Noita partial)
- Abundant (~5): Dead Cells, Vampire Survivors, 20 Minutes Till Dawn, Rogue Legacy Late (+ Hades partial)
- Scarce (~5): Into the Breach, FTL, Spelunky, Rogue Legacy Early (+ Noita partial)
- Competitive (2): TFT, Underlords
- Time-pressured (2): Risk of Rain 1, Risk of Rain 2
- Drought/Feast (0): None

### 6. Reversibility
- Permanent (15): Isaac, Hades, Dead Cells, Gungeon, Noita, Nuclear Throne, Vampire Survivors, Brotato, 20 Minutes Till Dawn, Into the Breach, FTL, Rogue Legacy Early, Rogue Legacy Late, Risk of Rain 1, Risk of Rain 2
- Swappable (13): Dead Cells, Gungeon, Noita, Nuclear Throne, Brotato, SNKRX, Super Auto Pets, TFT, Underlords, Into the Breach, FTL, Spelunky, Rogue Legacy Early
- Sellable (7): Hades, SNKRX, Balatro, Super Auto Pets, TFT, Underlords, FTL
- Transformable (5): Isaac, Slay the Spire, Balatro, Peglin, Risk of Rain 2
- Removable (3): Slay the Spire, Balatro, Peglin
- Evolutionary (1): Vampire Survivors
- Fluid (0): None

#### Commitment Weight
- Medium (10+): Hades, Gungeon, Nuclear Throne, Vampire Survivors, 20 Minutes Till Dawn, Slay the Spire, Peglin, Rogue Legacy Late, Risk of Rain 1, Risk of Rain 2
- Light (~2 pure + 6 partial): SNKRX, Super Auto Pets
- Heavy (2 pure + partials): FTL, Rogue Legacy Early
- Critical (1): Into the Breach

### 7. Capacity
- Hard cap (15): Dead Cells, Noita, Nuclear Throne, Vampire Survivors, Brotato, SNKRX, Balatro, Super Auto Pets, TFT, Underlords, Into the Breach, FTL, Spelunky, Rogue Legacy Early, Rogue Legacy Late
- Unlimited (4): Hades, Gungeon, Risk of Rain 1, Risk of Rain 2
- Soft cap (3): 20 Minutes Till Dawn, Slay the Spire, Peglin
- Contextual (3): Isaac, Hades, Gungeon
- Dynamic (0): None

### 8. Interaction
- Synergistic (14): Hades, Dead Cells, Gungeon, Nuclear Throne, Vampire Survivors, Brotato, SNKRX, 20 Minutes Till Dawn, Slay the Spire, Peglin, Rogue Legacy Early, Rogue Legacy Late, Risk of Rain 1, Risk of Rain 2
- Systemic (5): Noita, TFT, Underlords, FTL, Spelunky
- Highly Synergistic (4): Isaac, Balatro, Super Auto Pets, Into the Breach
- Multiplicative (2): Risk of Rain 1, Risk of Rain 2
- Exclusive (1): Isaac
- Independent (0), Hierarchical (0), Competitive (0): None

### 9. Upgrade Depth
- Linear (14): Hades, Dead Cells, Vampire Survivors, Brotato, SNKRX, 20 Minutes Till Dawn, Slay the Spire, Peglin, Super Auto Pets, TFT, Underlords, Into the Breach, FTL, Rogue Legacy Early
- Flat (5): Isaac, Dead Cells, Gungeon, Nuclear Throne, Spelunky
- Infinite (2): Risk of Rain 1, Risk of Rain 2
- Evolutionary (2): Hades, Vampire Survivors
- Transformable (2): Isaac, Balatro
- Transformative (1): Noita
- Maxed (1): Rogue Legacy Late
- Branching (0): None

### 10. Power Source Diversity
- Multi-source (15): Isaac, Hades, Dead Cells, Gungeon, Noita, Slay the Spire, Balatro, TFT, Underlords, Into the Breach, FTL, Spelunky, Rogue Legacy Early, Rogue Legacy Late, Risk of Rain 2
- Dual source (6): Nuclear Throne, Brotato, 20 Minutes Till Dawn, Peglin, Super Auto Pets, Risk of Rain 1
- Single source (2): Vampire Survivors, SNKRX
- Interconnected (0): None

### 11. Visibility
- Present (17): Isaac, Hades, Dead Cells, Gungeon, Noita, Nuclear Throne, Vampire Survivors, 20 Minutes Till Dawn, Slay the Spire, Balatro, Peglin, FTL, Spelunky, Rogue Legacy Early, Rogue Legacy Late, Risk of Rain 1, Risk of Rain 2
- Complete (7): Brotato, SNKRX, Slay the Spire, Balatro, Peglin, Super Auto Pets, Into the Breach
- Forecast (5): Hades, Dead Cells, Slay the Spire, TFT, FTL
- Pool-visible (4): SNKRX, Super Auto Pets, TFT, Underlords
- Obscured (2): Isaac, Noita
- Blind (0): None

### 12. Comprehension
- Transparent (17): Hades, Dead Cells, Nuclear Throne, Vampire Survivors, Brotato, SNKRX, 20 Minutes Till Dawn, Slay the Spire, Balatro, Peglin, Super Auto Pets, Into the Breach, FTL, Rogue Legacy Early, Rogue Legacy Late, Risk of Rain 1, Risk of Rain 2
- Learnable (7): Isaac, Gungeon, Noita, TFT, Underlords, Spelunky, Risk of Rain 1
- Calculable (1): Balatro
- Opaque (1): Noita
- Unknown (1): Isaac

### 13. Growth Pattern
- Additive (16): Isaac, Hades, Dead Cells, Gungeon, Noita, Nuclear Throne, Vampire Survivors, Brotato, SNKRX, 20 Minutes Till Dawn, Slay the Spire, Peglin, Super Auto Pets, Into the Breach, FTL, Rogue Legacy Early
- Multiplicative (3): Balatro, Risk of Rain 1, Risk of Rain 2
- Transformative (3): Isaac, Noita, Super Auto Pets
- Oscillating (2): TFT, Underlords
- Minimal (2): Spelunky, Rogue Legacy Late
- Subtractive (1): Slay the Spire
- Plateau (0): None

### 14. Persistence
- Unlocks (19): Isaac, Hades, Dead Cells, Gungeon, Noita, Nuclear Throne, Vampire Survivors, Brotato, SNKRX, 20 Minutes Till Dawn, Slay the Spire, Balatro, Peglin, Super Auto Pets, Into the Breach, FTL, Spelunky, Risk of Rain 1, Risk of Rain 2
- Upgrades (4): Hades, Dead Cells, Vampire Survivors, Rogue Legacy Early
- Nothing (2): TFT, Underlords
- Legacy (1): Into the Breach
- Resources (1): Rogue Legacy Early
- Progress (0): None

### 15. Starting Variance
- Character-varied (17): Isaac, Dead Cells, Gungeon, Noita, Nuclear Throne, Vampire Survivors, Brotato, SNKRX, 20 Minutes Till Dawn, Slay the Spire, Peglin, FTL, Spelunky, Rogue Legacy Early, Rogue Legacy Late, Risk of Rain 1, Risk of Rain 2
- Loadout-varied (8): Hades, Dead Cells, Vampire Survivors, 20 Minutes Till Dawn, Balatro, Super Auto Pets, Into the Breach, Risk of Rain 2
- Identical (2): Super Auto Pets, Spelunky
- Random-varied (2): Isaac, Noita
- Varied (2): TFT, Underlords
- Seeded (0), Inherited (0): None

### 16. Run Identity
- Emergent (14): Isaac, Hades, Dead Cells, Gungeon, Noita, Nuclear Throne, Brotato, SNKRX, 20 Minutes Till Dawn, Slay the Spire, Peglin, FTL, Risk of Rain 1, Risk of Rain 2
- Influenced (6): Hades, Dead Cells, Nuclear Throne, Brotato, 20 Minutes Till Dawn, FTL
- Fluid (4): Super Auto Pets, TFT, Underlords, Balatro
- Pre-determined (3): Into the Breach, Rogue Legacy Early, Rogue Legacy Late
- Early-crystallizing (3): Vampire Survivors, Balatro, TFT
- Convergent (2): Risk of Rain 1, Risk of Rain 2
- Minimal (1): Spelunky

### 17. Skill vs Build Ratio
- Balanced (12): Isaac, Hades, Dead Cells, Gungeon, Noita, 20 Minutes Till Dawn, Slay the Spire, Peglin, FTL, Rogue Legacy Early, Risk of Rain 1, Risk of Rain 2
- Build-dominant (8): Vampire Survivors, Brotato, SNKRX, Balatro, Super Auto Pets, TFT, Underlords, Rogue Legacy Late
- Knowledge-dominant (6): Isaac, Noita, Balatro, Super Auto Pets, TFT, Underlords
- Execution-dominant (4): Nuclear Throne, Into the Breach, Spelunky, Rogue Legacy Late (NG+)

---

## Hypothetical Designs

[Framework](#the-framework) | [Games](#game-classifications) | [Frequency](#frequency-analysis) | [Designs](#hypothetical-designs) | [Experimental](#experimental-games-frequency-analysis)

These are imaginary roguelite designs that explore the taxonomy's design space. The first three are **archetypal** — they use common options and resemble existing successful games. The remaining nine are **experimental** — they deliberately explore underused design space.

---

### Archetypal Game 1: "Dungeon Cascade"
*The Standard Action Roguelite*

A room-clearing action roguelite where you fight through procedural dungeons, collecting items and abilities as you go. Combat is real-time with dodging, attacking, and ability usage. Think Hades meets Gungeon — the platonic ideal of the genre. Each floor contains combat rooms, treasure rooms, shops, and a boss. Clear a room, choose a reward from three options, move to the next. The formula works because it provides constant meaningful choices without overwhelming the player, and the real-time combat keeps moment-to-moment gameplay engaging even when the build is suboptimal.

**1. Choice Timing: Distributed**
After clearing rooms, you're offered a choice of rewards. Boss rooms guarantee powerful items, while regular rooms offer smaller upgrades. The run is a constant stream of decisions from start to finish.

**2. Pacing: Event-triggered + Resource-gated**
Upgrades appear after room clears (event-triggered) and in shops where you spend gold (resource-gated). You can't grind — progression is tied to advancement through the dungeon.

**3. Distribution Timing: Immediate**
Every item works the moment you pick it up. No delayed unlocks, no cards to draw later — power is instant.

**4. Agency: Curated + Serendipitous**
Room rewards let you pick 1 of 3 options (curated), but what appears in chests is random (serendipitous). Shops offer curated choices within a random inventory.

**5. Negative Acquisition: Optional**
Cursed shrines offer powerful bonuses at a cost — take more damage, move slower, etc. These are always optional; you can ignore them entirely.

**6. Scarcity: Moderate**
Enough upgrades to build something coherent, but not so many that every run feels the same. Gold and keys create meaningful resource tension.

**7. Reversibility: Permanent**
Items cannot be removed or changed once taken. Choose carefully. **Commitment Weight: Medium** — permanent choices, but you make many of them.

**8. Capacity: Hard cap**
You have limited active ability slots (3) and weapon slots (2). Passive items are unlimited but naturally constrained by what you find.

**9. Interaction: Synergistic**
Items explicitly combo — the flaming sword deals bonus damage to oiled enemies, poison stacks with bleed, etc. Finding synergies is the core satisfaction.

**10. Upgrade Depth: Linear**
Items can be upgraded at altars — +1, +2, +3 versions of each item. Simple numerical scaling.

**11. Power Source Diversity: Multi-source**
Weapons, passive items, active abilities, character skills, and consumables all contribute to your build.

**12. Visibility: Present**
You see what's in front of you — the three options after a room, the shop inventory, the chest contents when opened.

**13. Comprehension: Transparent**
All items clearly describe their effects with exact numbers. No hidden mechanics.

**14. Growth Pattern: Additive**
You get stronger throughout the run in a roughly linear fashion. No power loss, no major transformations.

**15. Persistence: Unlocks**
Beating bosses and completing challenges unlocks new items, characters, and starting loadouts for future runs.

**16. Starting Variance: Character-varied**
Six characters with different starting weapons, abilities, and stats. Each encourages different build paths.

**17. Run Identity: Emergent**
Builds emerge from what you find. "This became a fire build" or "I'm doing a tank run" — identity crystallizes mid-run based on offerings.

**Skill vs Build Ratio: Balanced**
Combat skill matters — dodging, positioning, timing. But build also matters — the right synergies make hard content manageable.

---

### Archetypal Game 2: "Horde Breaker"
*The Standard Survivors-like*

A top-down auto-attacking survival game where you fight endless waves of monsters. You move, enemies come, your weapons fire automatically. Level up frequently, choose upgrades, survive 20 minutes. The genius of this formula is that it separates the "build" layer (choosing upgrades) from the "execution" layer (movement and positioning), letting players focus on one at a time. The constant stream of level-ups creates dopamine hits every few seconds, while the auto-attacking reduces mechanical demands and makes the game accessible to casual players while still rewarding optimization.

**1. Choice Timing: Distributed**
Every level-up presents a choice of upgrades. You'll make 30-50 decisions per run, constantly shaping your build.

**2. Pacing: Fixed interval**
XP fills a bar, bar fills = level up = choice. Early levels come fast (every 10 seconds), later levels take longer. Pure fixed interval based on XP accumulation.

**3. Distribution Timing: Immediate**
Choose an upgrade, it works now. No delay, no conditions.

**4. Agency: Curated**
Pick 1 of 3-4 options each level. Rerolls available but limited. You can't force specific builds, but you can shape probability through smart choices.

**5. Negative Acquisition: None**
Pure power gain. No curses, no drawbacks. The only "negative" is opportunity cost.

**6. Scarcity: Abundant**
Constant stream of upgrades. You'll max out multiple weapons and passives per run. The constraint is slots, not availability.

**7. Reversibility: Permanent + Transformable**
Weapons can't be removed, but they evolve when paired with the right passive item. Evolution transforms a weapon into a stronger version. **Commitment Weight: Medium** — early choices shape evolution options.

**8. Capacity: Hard cap**
6 weapon slots, 6 passive slots. Strict limits force build decisions.

**9. Interaction: Synergistic**
Passives affect weapons (area buffs weapon size, might buffs damage). Evolution requires specific weapon + passive pairs. Synergy is explicit and documented.

**10. Upgrade Depth: Linear + Evolutionary**
Weapons level up 8 times, then evolve into final forms. Clear progression path per weapon.

**11. Power Source Diversity: Single source**
Almost everything comes from the level-up system. Character choice adds starting weapon and passive bonuses, but the run is about the unified upgrade pool.

**12. Visibility: Present**
See your current options. See your weapons and passives. Simple and clear.

**13. Comprehension: Transparent**
"+10% damage" means +10% damage. Evolution requirements are listed. No mystery.

**14. Growth Pattern: Additive (exponential in practice)**
Power scales dramatically. You go from struggling at minute 5 to annihilating everything at minute 15. The curve is steep but additive in structure.

**15. Persistence: Unlocks + Upgrades**
Unlock new characters and weapons through achievements. Spend collected gold on permanent stat upgrades (PowerUps).

**16. Starting Variance: Character-varied + Loadout-varied**
Different characters have different starting weapons and stats. Some characters let you choose starting weapon.

**17. Run Identity: Early-crystallizing**
Your first 3-4 weapon choices largely define the run. Hard to pivot once you've committed slots.

**Skill vs Build Ratio: Build-dominant**
Movement and positioning help, but the right build essentially plays itself. Build decisions are 80% of success.

---

### Archetypal Game 3: "Spell & Steel"
*The Standard Deckbuilder*

A turn-based deckbuilding roguelite. You have a deck of cards representing attacks, defenses, and skills. Each combat, draw cards, play cards, defeat enemies. Between combats, add cards to your deck, remove cards, upgrade cards. The deckbuilder formula works because it creates two distinct skill expressions: strategic (building a coherent deck) and tactical (playing the hand you're dealt optimally). The delayed-random distribution timing means you must build for consistency, not just power. Thin decks that see their best cards every turn often outperform fat decks with more raw power but less reliability.

**1. Choice Timing: Distributed**
After each combat, choose a card reward. Shops and events offer more choices. Decisions spread throughout the run.

**2. Pacing: Event-triggered + Resource-gated**
Combat rewards (event-triggered) and shops/removal services (resource-gated with gold). Rest sites offer upgrade or heal choices.

**3. Distribution Timing: Immediate + Delayed-Random**
Cards enter your deck immediately, but you access them through random draw during combat. The delay between acquisition and use is core to deckbuilding.

**4. Agency: Curated + Influenced**
Pick 1 of 3 cards after combat (curated). Skip if nothing fits. Transform and removal events let you shape your deck (influenced). Some relics affect card pools.

**5. Negative Acquisition: Optional**
Curses can be added through events, relics, or enemy effects. Always avoidable with careful play or choosing not to take risky rewards.

**6. Scarcity: Moderate**
Can't take every card. Gold limits shop purchases. Removal costs resources. Must prioritize — thin decks often beat fat decks.

**7. Reversibility: Removable + Transformable**
Cards can be removed at shops or events. Transform events change cards randomly. **Commitment Weight: Medium** — cards are permanent additions but removal is possible.

**8. Capacity: Soft cap**
No hard limit on deck size, but larger decks dilute your draws. The implicit cap is "how consistent do you need to be?"

**9. Interaction: Synergistic**
Cards combo within archetypes — poison cards feed Catalyst, strength cards feed Heavy Blade, etc. Building around synergies is the core skill.

**10. Upgrade Depth: Linear**
Each card can be upgraded once at rest sites. Upgrades improve numbers or add effects.

**11. Power Source Diversity: Multi-source**
Cards, relics (passive effects), potions (consumables). Three distinct power systems that interact.

**12. Visibility: Present + Complete + Forecast**
See card rewards when offered. View your deck and relics anytime. Map shows upcoming node types (elite, shop, rest, boss).

**13. Comprehension: Transparent**
Card text is precise. "Deal 6 damage" means 6 damage. Keyword glossary available.

**14. Growth Pattern: Additive + strategic Subtractive**
Generally gaining power, but smart removal of bad cards (Strikes, Defends) is often more valuable than adding cards.

**15. Persistence: Unlocks**
Winning and completing challenges unlocks new cards and relics for future runs.

**16. Starting Variance: Character-varied**
Four characters with completely different card pools, mechanics, and strategies. The Warrior plays nothing like the Rogue.

**17. Run Identity: Emergent**
"This became an exhaust deck" or "I'm going infinite with draw loops." Build identity emerges from early card choices and relic finds.

**Skill vs Build Ratio: Balanced**
Deckbuilding decisions are crucial. In-combat card sequencing and math are equally crucial. Both matter for high-level play.

---

### Experimental Game 1: "Loadout"
*The All-Upfront Tactical Roguelite*

Before each mission, you have 5 minutes to build your entire loadout: weapons, gadgets, skills, consumables. Then you deploy into a 15-minute mission with NO upgrades during play. Success depends entirely on preparation. Think XCOM loadout phase meets roguelite mission structure. The key insight is that most roguelites spread decisions across the run, but this game frontloads everything. You're essentially solving a puzzle: "Given these mission parameters and this equipment, what's the optimal loadout?" The mission itself becomes execution of your plan, not adaptation to new choices.

**1. Choice Timing: Pre-run**
All choices happen before the mission. Once deployed, you have what you brought. The entire decision layer is frontloaded.

**2. Pacing: Player-controlled**
No upgrade opportunities during missions. You control when the loadout phase ends by choosing to deploy.

**3. Distribution Timing: Frontloaded**
Full power available from mission start. No power curve within the mission — you're at 100% from second one.

**4. Agency: Deterministic**
You choose exactly what you bring. No randomness in loadout — if you own it, you can equip it. The randomness is in what missions offer and what enemies appear.

**5. Negative Acquisition: Traded**
Equipment has weight. Bringing heavy weapons means less gadget space. Bringing more consumables means fewer passives. Every choice trades against something.

**6. Scarcity: Moderate**
Enough equipment to build many loadouts, but weight limits mean you can't bring everything. Meaningful constraints force specialization.

**7. Reversibility: Permanent**
Within a mission, equipment is fixed. Between missions, full loadout restructuring. **Commitment Weight: Critical** — your loadout IS the run. Wrong loadout = failed mission.

**8. Capacity: Hard cap**
Weight limit creates a hard ceiling. 100 weight units, items cost 5-30 each. Math puzzle of fitting the best combination.

**9. Interaction: Synergistic**
Equipment designed to combo. Stealth suit + silenced weapons + motion sensors. Heavy armor + shield + minigun. Synergies are explicit and planned.

**10. Upgrade Depth: Flat (within run) + Linear (meta)**
No upgrades during missions. Between campaigns, equipment can be upgraded with collected resources.

**11. Power Source Diversity: Multi-source**
Weapons, armor, gadgets, consumables, character skills. Many systems to balance in loadout construction.

**12. Visibility: Complete**
Full visibility of your inventory, mission parameters, and enemy compositions before deploying. Information is power.

**13. Comprehension: Transparent**
Equipment stats clearly listed. Mission parameters explicit. Plan with complete information.

**14. Growth Pattern: Plateau**
No power growth during mission. You're as strong at the end as the start. Challenge comes from depleting resources (ammo, consumables) not gaining power.

**15. Persistence: Unlocks + Resources**
Complete missions to unlock new equipment. Collect resources to upgrade existing gear. Strong meta-progression.

**16. Starting Variance: Loadout-varied**
Your loadout IS your starting variance. Two players with identical unlocks could bring completely different builds.

**17. Run Identity: Pre-determined**
Identity is set before the mission starts. "I'm doing a stealth run" or "I'm going loud" — decided in loadout, not discovered.

**Skill vs Build Ratio: Balanced**
Loadout construction is a puzzle. Mission execution requires tactical skill. Bad loadout can't be saved by skill; bad skill wastes a good loadout.

---

### Experimental Game 2: "Tide Runner"
*The Resource Wave Roguelite*

Resources come in waves. After drought periods with nothing, abundance floods in — more upgrades than you can hold. You must choose quickly during abundance, then survive the drought. Timing your upgrades to the resource tide is the core skill. The drought/feast pattern creates a fundamentally different emotional rhythm than most roguelites. During drought, you're focused purely on survival with what you have. During tide, you're making rapid decisions under time pressure. The contrast keeps both phases feeling distinct and meaningful.

**1. Choice Timing: Milestone**
Upgrades only available during "tide" phases (every 3-4 areas). Between tides, no upgrade opportunities at all.

**2. Pacing: Player-controlled + Milestone**
During tides, YOU decide when to stop and which upgrades to take. Tides last 60 seconds — grab what you can. Between tides, pure survival.

**3. Distribution Timing: Immediate**
Whatever you grab during the tide works immediately. No delays.

**4. Agency: Serendipitous + Influenced**
Tides wash up random items (serendipitous). Tide totems placed pre-run influence what categories appear (influenced) — place fire totem for more fire items.

**5. Negative Acquisition: Coupled**
Some tide items are "cursed flotsam" — powerful but with drawbacks. Appears mixed with good items, must evaluate quickly during tide timer.

**6. Scarcity: Drought/Feast**
Core mechanic. Drought phases have NO upgrades. Feast phases have MORE than you can process. Average is "moderate" but distribution is extreme.

**7. Reversibility: Swappable**
Can drop items to pick up others during tide. Dropped items wash away. **Commitment Weight: Medium** — light during tide windows, heavy after they end.

**8. Capacity: Hard cap**
8 item slots. During tide, must decide what to keep vs what to swap. Hard choices when tide brings 20 items and you can hold 8.

**9. Interaction: Synergistic**
Items combo. Tides that bring matching items feel amazing. Tides that bring mismatched items force hard choices.

**10. Upgrade Depth: Flat**
Items are what they are. No upgrade system — just finding better versions during tides.

**11. Power Source Diversity: Single source**
Just items from tides. No shops, no events, no alt systems. All power from the same source.

**12. Visibility: Present (chaotic)**
During tides, items appear everywhere — on the ground, floating by. You see them but can't process everything. Deliberate information overload.

**13. Comprehension: Transparent**
Items clearly labeled. Challenge isn't understanding — it's deciding fast enough.

**14. Growth Pattern: Oscillating**
Power spikes during tides, then plateaus (or effectively decreases relative to scaling enemies) during droughts. Wave pattern of relative power.

**15. Persistence: Unlocks**
Unlock new tide pools (different item categories), new totems (tide manipulation), new characters.

**16. Starting Variance: Character-varied + Loadout-varied**
Characters start with different base abilities. Totem loadout affects tide composition.

**17. Run Identity: Emergent**
What the tides bring defines your build. Plan for fire, but if tides bring ice, you adapt.

**Skill vs Build Ratio: Balanced**
Tide navigation skill (quick evaluation, fast decisions). Drought survival skill (combat with limited power). Build quality depends on tide luck AND tide navigation skill.

---

### Experimental Game 3: "The Branching Path"
*The Skill Tree Roguelite*

Instead of collecting items, you invest in a massive procedurally-generated skill tree. Each node unlocks adjacent nodes. Deep investment in one branch locks out distant branches. Your build is a path through possibility space. The key difference from normal skill trees: the tree is different every run. You can't memorize optimal paths. Instead, you must evaluate each tree fresh, reading its structure to find powerful node clusters and synergy chains. Deep investment in one branch yields stronger effects than shallow investment across many.

**1. Choice Timing: Distributed**
Earn skill points throughout the run. Spend them anytime by opening the tree.

**2. Pacing: Performance-based + Resource-gated**
Better combat performance = more XP = more skill points. Points are the resource; spending is player-controlled.

**3. Distribution Timing: Immediate**
Unlock a node, gain its benefit now.

**4. Agency: Deterministic**
You choose exactly which nodes to unlock. No randomness in the spending — only in tree generation at run start.

**5. Negative Acquisition: None (Exclusive by structure)**
Nodes aren't negative, but taking some paths means not taking others. The tree structure creates implicit exclusion without explicit negatives.

**6. Scarcity: Moderate**
Enough points to go deep in 2-3 branches, or shallow in many. Can't unlock everything.

**7. Reversibility: Permanent**
Points spent are spent. No refunds. **Commitment Weight: Heavy** — each point commits you further to a path.

**8. Capacity: Contextual**
No hard cap on how many nodes, but point economy limits total unlocks. Go wide and shallow or narrow and deep.

**9. Interaction: Hierarchical + Exclusive**
Nodes deeper in tree are strictly stronger than shallow nodes. Tree branches are mutually exclusive in practice — can't reach both fire mastery and ice mastery in one run.

**10. Upgrade Depth: Branching**
Core mechanic. Each node leads to multiple further nodes. Branches diverge and rarely reconnect.

**11. Power Source Diversity: Single source**
Just the skill tree. All power comes from one unified system.

**12. Visibility: Complete**
Full tree visible from start. Can plan your entire path. Deep knowledge rewards strategic planning.

**13. Comprehension: Transparent**
All node effects clearly described. Optimal paths are calculable by theorycrafters.

**14. Growth Pattern: Additive**
Steady upward progression as you invest more points. Later nodes are more powerful.

**15. Persistence: Unlocks**
Unlock new "seed" trees — different tree structures for variety. Unlock starting positions deeper in trees.

**16. Starting Variance: Random-varied**
Each run generates a new tree. Same meta-structure, different node arrangements and values.

**17. Run Identity: Emergent**
You might plan a path, but tree generation might make that path weak. Identity emerges from adapting your plan to the generated tree.

**Skill vs Build Ratio: Balanced**
Combat skill determines XP gain rate. Tree navigation skill (picking optimal paths) determines build quality. Both feed into final power.

---

### Experimental Game 4: "The Expedition"
*Route Planning + Resource Packing*

Before each expedition, you see the full branching map: paths, encounters, rewards, and dangers. You plan your exact route AND pack supplies for that specific journey. Once you depart, the route is locked — you can only use what you brought. The strategy is matching preparation to plan. This combines the puzzle-like satisfaction of logistics planning with roguelite exploration. Seeing the full map beforehand transforms the game from reactive adaptation to proactive optimization. The challenge isn't dealing with surprises — it's solving the puzzle of "what's the optimal path through this specific dungeon, and what do I need to walk that path?"

**1. Choice Timing: Pre-run (planning) + Milestone (resupply camps)**
Two phases: extensive pre-run planning, then rare resupply opportunities at camps along your chosen route. 90% of decisions happen before departure.

**2. Pacing: Player-controlled + Event-triggered**
The loadout/route phase has no timer — think as long as you want. During expedition, resupply camps appear at planned milestones (every 3-4 nodes on your path).

**3. Distribution Timing: Frontloaded + Distributed (supplies)**
Your build is frontloaded — you have it all from the start. But supplies (consumables, limited-use items) distribute as you consume them. Packing 10 health potions means distributing healing across the run.

**4. Agency: Deterministic**
You see the entire map. You choose your exact path. You choose your exact loadout. Zero randomness in what you bring or where you go. Randomness only in combat execution.

**5. Negative Acquisition: Traded**
Weight limits force tradeoffs. Every healing item is a damage item you didn't bring. Every utility tool is combat power you sacrificed. The pack has finite space.

**6. Scarcity: Moderate**
You choose your scarcity level. Pack light and move fast but have less margin for error. Pack heavy and have resources but move slow (more encounters before resupply). Scarcity is a strategic variable you set.

**7. Reversibility: Permanent**
Route cannot be changed once departed. Supplies are consumed as used. **Commitment Weight: Critical** — route and pack define everything. Bad planning = failed expedition.

**8. Capacity: Hard cap (weight)**
Weight limit creates hard packing constraints. Different items have different weight-to-power ratios. Optimization puzzle in packing phase.

**9. Interaction: Synergistic (planned)**
Items synergize, and you can plan synergies perfectly since you control what you bring. "I'm bringing the ice sword AND the freeze-shatter passive because I planned this combo."

**10. Upgrade Depth: Flat (within expedition) + Linear (meta)**
No upgrades during expedition — you have what you packed. Between expeditions, equipment can be upgraded with collected resources.

**11. Power Source Diversity: Multi-source**
Weapons, armor, consumables, tools, character abilities. Many systems to balance in packing.

**12. Visibility: Complete (pre-run) + Present (during)**
Full map visible before departure. During expedition, see immediate surroundings and your remaining supplies.

**13. Comprehension: Transparent**
All items, enemies, and path rewards clearly documented. Perfect information enables perfect planning.

**14. Growth Pattern: Subtractive (within expedition)**
You start at full power (full supplies) and deplete over the expedition. Resource management is watching your power decrease and making it last.

**15. Persistence: Unlocks + Resources**
Complete expeditions to unlock new equipment, routes, and characters. Collect resources for meta-upgrades.

**16. Starting Variance: Loadout-varied**
Every expedition differs by what you bring and where you go. Even with same equipment, different routes create different experiences.

**17. Run Identity: Pre-determined**
Identity is set before departure. "This is a speed-run with minimal supplies" or "This is a full-clear with heavy combat loadout" — decided in planning.

**Skill vs Build Ratio: Balanced**
80% of success is the planning phase — route selection and packing optimization. 20% is combat execution and resource timing during the expedition.

---

### Experimental Game 5: "Stance Dancer"
*Multiple Loadouts, Tactical Swapping*

Before combat, you build three complete "stances" — different equipment sets, abilities, and playstyles. During combat, you can swap stances with a cooldown. One stance tanks, one deals damage, one provides utility. Mastering the dance between stances is the core skill. This creates a unique rhythm where you're constantly asking "which stance do I need right now?" The pre-built stances mean you've already made the build decisions; the skill expression is in reading situations and swapping at the right moments. It also triples the equipment you interact with per run, creating more complex build puzzles.

**1. Choice Timing: Pre-run (stance building) + Reactive (stance swapping)**
Build all three stances before the run. During combat, reactively swap stances based on the situation. Both layers are critical.

**2. Pacing: Player-controlled**
Stance building is unpaced (take your time). Stance swapping is player-controlled with a cooldown — you decide when to switch, but can't spam it.

**3. Distribution Timing: Frontloaded + Partitioned**
All three stances exist from run start (frontloaded). But only one is active at a time — power is segmented across stances, and you swap between them (partitioned).

**4. Agency: Deterministic (building) + Curated (during run)**
You choose exactly what goes in each stance. During runs, new items drop that you must assign to a stance — curated choices about where new power goes.

**5. Negative Acquisition: Traded (between stances)**
Each item can only be in ONE stance. Putting the best sword in Stance A means Stances B and C don't have it. Trade-offs between stances.

**6. Scarcity: Moderate**
Total power is moderate, but it's split three ways. Each individual stance feels scarce; the totality is abundant.

**7. Reversibility: Swappable + Permanent**
Can reassign items between stances between runs. During a run, stance composition is locked. **Commitment Weight: Medium** — locked per run but flexible between runs.

**8. Capacity: Hard cap per stance**
Each stance has limited slots: 2 weapons, 3 abilities, 4 passives. Total of 27 slots across all stances. Must distribute items strategically.

**9. Interaction: Synergistic**
Items synergize within a stance. Stances complement each other — Tank stance protects while Damage stance is cooling down. The three-stance system should cover all situations.

**10. Upgrade Depth: Linear**
Items upgrade through use. Items in your active stance when you gain XP level faster. Creates incentive to use all stances.

**11. Power Source Diversity: Multi-source (unified by stance)**
Weapons, abilities, passives — but organized into three coherent packages rather than one pile.

**12. Visibility: Complete (stances) + Present (combat)**
Full visibility of all three stances anytime. Combat visibility is standard.

**13. Comprehension: Transparent**
Clear item effects. Clear stance swap cooldowns. The complexity is in stance composition, not hidden mechanics.

**14. Growth Pattern: Additive (overall) + Oscillating (moment-to-moment)**
Overall power grows as items upgrade. Moment-to-moment power oscillates as you swap between stronger/weaker stances for different situations.

**15. Persistence: Unlocks**
Unlock new items, new stance slots, new characters with different stance mechanics (some have 2 stances, some have 4).

**16. Starting Variance: Loadout-varied (x3)**
Three loadouts means triple the starting variance. Huge build diversity.

**17. Run Identity: Emergent**
Stance archetypes are pre-determined (Tank/Damage/Utility). But which stance dominates emerges from combat needs and item drops.

**Skill vs Build Ratio: Balanced**
Stance building is deep (build skill). Stance swapping is reactive (execution skill). Combat within stances requires normal action game skill. All three layers matter.

---

### Experimental Game 6: "Tide Caller"
*Controlled Abundance Timing*

You have a "Tide Gauge" that fills slowly during combat. At any time, you can release it to trigger an Abundance Phase — a 30-second window where upgrades rain down. But the longer you wait, the fuller the gauge, and the better the Abundance. The core tension: release early for safety, or hold for greater reward? This inverts the normal relationship between player and power acquisition. Instead of power coming TO you, you control WHEN power comes. The greed/safety tension creates dramatic moments: you're at 10% HP with a full gauge, knowing that if you can just survive 30 more seconds, you'll get amazing upgrades, but releasing now would be safer...

**1. Choice Timing: Milestone + Distributed**
YOU decide when tide milestones occur by releasing the gauge. During abundance, standard distributed choices (pick 1 of 3, repeatedly).

**2. Pacing: Player-controlled + Event-triggered**
Tide release is entirely player-controlled. Once released, abundance lasts 30 seconds — frantic decision-making under time pressure.

**3. Distribution Timing: Immediate**
Upgrades grabbed during abundance work instantly.

**4. Agency: Curated + Influenced**
Choose 1 of 3 during abundance (curated). Higher gauge = more options per choice (3 becomes 4 becomes 5). Gauge level influences quality.

**5. Negative Acquisition: Coupled (tide risk)**
If you die while holding a full gauge, you lose significant progress. The "negative" is the risk of holding too long. Greed is punished.

**6. Scarcity: Drought/Feast**
You control when abundance happens. Wait longer = more abundance when it comes. But waiting means surviving without upgrades. Scarcity is self-imposed through timing.

**7. Reversibility: Permanent**
Upgrades grabbed during abundance are permanent. **Commitment Weight: Medium** — permanent choices but many of them during each abundance.

**8. Capacity: Soft cap**
No hard limit, but upgrade pools have limited synergies. Eventually more upgrades provide diminishing returns.

**9. Interaction: Synergistic**
Standard synergies. Finding combos during abundance is exciting — "yes, the synergy piece I needed appeared!"

**10. Upgrade Depth: Linear**
Upgrades can level up. During abundance, existing upgrades can appear again to level.

**11. Power Source Diversity: Single source**
All power from abundance phases. No shops, no events, no alternative sources. The tide is everything.

**12. Visibility: Present + Forecast**
Standard combat visibility. Tide gauge always visible, forecasting expected abundance quality — information for decisions.

**13. Comprehension: Transparent + Calculable**
Upgrade effects are clear. Gauge-to-quality relationship is calculable (X% gauge = Y expected quality).

**14. Growth Pattern: Additive**
Flat between abundances, sharp spike during each. Power graph looks like stairs. Longer holds = taller steps.

**15. Persistence: Unlocks**
Unlock new upgrade pools, new characters with different gauge mechanics, new abundance modifiers.

**16. Starting Variance: Character-varied**
Different characters have different gauge speeds, abundance durations, and starting tide levels.

**17. Run Identity: Emergent**
Build emerges from abundance choices. Early abundant runs differ from late abundant runs — timing shapes identity.

**Skill vs Build Ratio: Balanced**
Combat skill (survive while holding gauge). Timing skill (when to release). Build skill (choices during abundance). Three distinct skill types.

---

### Experimental Game 7: "Labyrinth of Choices"
*The Skill Tree IS the Dungeon*

The map is a massive branching skill tree. Each node is an encounter: combat, event, or treasure. Completing a node unlocks its bonus AND unlocks adjacent nodes. Your "build" is literally your path through the labyrinth. Going left precludes going right. The dungeon and character build are unified. This collapses the distinction between exploration and character building. In most roguelites, you explore a dungeon AND build a character — two parallel progressions. Here, they're identical. Every step you take is a build decision; every build decision is a navigation choice. This creates incredibly tight design where spatial reasoning and build planning become the same skill.

**1. Choice Timing: Distributed (every node)**
Each node is a choice — complete it to gain its power and access its branches. Constant decision-making.

**2. Pacing: Player-controlled**
You decide which node to attempt next. No forced pacing — explore at your own speed.

**3. Distribution Timing: Immediate**
Complete a node, gain its power immediately.

**4. Agency: Deterministic (pathing) + Serendipitous (loot within nodes)**
You choose which nodes to complete. What drops within combat nodes has randomness. Path is deterministic; loot is serendipitous.

**5. Negative Acquisition: None**
Every step away from a branch makes it harder to reach later (more nodes between you and it). Deep branches become inaccessible. "Negatives" are opportunity costs enforced by geometry, not actual negative acquisition.

**6. Scarcity: Moderate (forced by geometry)**
Can't complete every node — branches diverge, time is limited, some paths lock others. Geometry enforces scarcity.

**7. Reversibility: Permanent (pathing)**
Can't un-complete a node or return to skipped branches (one-way paths). **Commitment Weight: Heavy** — each node commits you further down a branch.

**8. Capacity: Unlimited (but geometry-limited)**
No hard cap on node bonuses, but you can only reach so many nodes. Practical limit from labyrinth structure.

**9. Interaction: Hierarchical + Synergistic**
Deeper nodes are strictly stronger than shallow nodes (hierarchical). Nodes in the same branch synergize (synergistic within paths).

**10. Upgrade Depth: Branching (literally)**
The entire upgrade system IS branching. Deeper nodes are upgraded versions of the branch's theme.

**11. Power Source Diversity: Single source (unified)**
All power from node completion. The labyrinth is the only system.

**12. Visibility: Complete + Progressive**
See the full map structure. Unvisited nodes show their type but not exact rewards — details revealed as you get closer.

**13. Comprehension: Transparent**
Node rewards clearly shown when adjacent. No hidden mechanics.

**14. Growth Pattern: Multiplicative**
Power grows as you complete nodes. Deeper nodes give more power — late-run growth accelerates exponentially.

**15. Persistence: Unlocks**
Unlock new labyrinth "seeds" — different branch structures. Unlock starting positions deeper in labyrinths.

**16. Starting Variance: Seeded**
Each run uses a labyrinth seed. Same seed = same layout. Different seeds = different strategic puzzles.

**17. Run Identity: Emergent**
Your path IS your build. "I went fire branch into AoE" is both your route and your character identity. Unified.

**Skill vs Build Ratio: Balanced**
Reading the labyrinth and choosing optimal paths is 60%. Combat execution within nodes is 40%. Strategic pathing matters most.

---

### Experimental Game 8: "The Bloodline Labyrinth"
*Generational Skill Tree Navigation*

The skill tree IS your family tree — ancestors' choices determine your starting position, and your choices become your descendants' inheritance. Each run you play the latest heir of a dungeon-delving dynasty. Unlike Rogue Legacy where traits are random, here inheritance is deterministic and strategic. You're not just playing one run — you're cultivating a bloodline across many generations. Early generations sacrifice themselves to develop branches that later generations will benefit from. The multi-generational perspective creates unique long-term planning where a "bad" run can still be strategically valuable for the dynasty.

**1. Choice Timing: Pre-run (lineage selection) + Distributed (skill unlocks)**
Before each run, choose which ancestor to descend from (different inherited skills). During the run, earn points and unlock nodes like a standard skill tree.

**2. Pacing: Milestone (generational) + Performance-based (within run)**
Major decisions happen between generations (which line to continue, which skills to "master"). Within a run, skill point acquisition is performance-based — better combat yields more points.

**3. Distribution Timing: Frontloaded + Immediate**
Some power is inherited at run start (frontloaded from lineage). Additional power is gained immediately as you unlock nodes during the run.

**4. Agency: Deterministic (both layers)**
You choose which ancestor to descend from. You choose which nodes to unlock. No randomness in the skill tree itself — only in dungeon encounters.

**5. Negative Acquisition: Traded**
Choosing one ancestor means not choosing another. Investing in fire mastery across generations makes it harder to develop ice mastery — your bloodline is specialized by its history.

**6. Scarcity: Abundant**
Within a run, skill points feel abundant because your ancestors invested in this tree. That abundance was built through many generations of careful investment.

**7. Reversibility: Permanent (generationally)**
Skills mastered at death become permanent additions to the family tree. You can't un-master a skill, can't prune branches. **Commitment Weight: Critical** — mastery choices affect many future descendants.

**8. Capacity: Dynamic**
Capacity grows across generations. A first-generation character has few options. A hundredth-generation character starts with an elaborate tree of ancestral investments.

**9. Interaction: Hierarchical + Synergistic**
Deeper nodes require parent nodes (hierarchical). Inherited traits from different ancestors might synergize in unexpected ways — grandmother's fire affinity with grandfather's area effects.

**10. Upgrade Depth: Evolutionary**
Traits evolve across generations. A weak fire affinity becomes strong after five fire-focused generations. The tree deepens through sustained investment.

**11. Power Source Diversity: Single source (family tree)**
All power from the family skill tree. The tree is the only system — but it's shaped by generational history.

**12. Visibility: Complete (historical)**
Full tree visible including ancestor choices, undeveloped branches, and potential paths. Family history is fully transparent.

**13. Comprehension: Transparent + Learnable**
Node effects are clear. But inheritance to descendants has probability — a child MIGHT inherit a mastered skill. Learning inheritance odds takes time.

**14. Growth Pattern: Additive + Multiplicative**
Normal additive growth during a run. Bloodlines trend upward across generations through accumulated inheritance — multiplicative effects compound over many generations.

**15. Persistence: Legacy**
The game IS persistence. Everything feeds the bloodline. Previous runs directly affect future runs through inheritance — true progress is generational. Individual runs are chapters in a dynasty's story.

**16. Starting Variance: Inherited**
Starting position depends entirely on your chosen ancestor. Two players at the same generation could have wildly different bloodlines based on their ancestors' choices.

**17. Run Identity: Pre-determined**
Individual runs emerge from skill choices, but overall identity is shaped by bloodline. A fire-focused bloodline character is predisposed toward fire builds before the run even starts — identity is pre-determined by ancestry.

**Skill vs Build Ratio: Balanced**
Combat skill matters each generation. Eugenics skill (planning optimal bloodlines across generations) matters for long-term success. Both contribute — immediate and generational.

---

### Experimental Game 9: "The Gambler's Dungeon"
*Bet-Based Build Construction*

Before each run, you place bets on your own performance at the betting house. Bet on killing 50 enemies? You get damage equipment but lose everything if you fail. Your bets shape your build, and your build must fulfill your bets. This creates a fascinating self-assessment loop: you must accurately judge your own capabilities to bet optimally. Overconfident bets give great equipment but doom you to failure. Underconfident bets are safe but leave power on the table. Learning to bet accurately IS learning to play the game. The betting house becomes a mirror reflecting your skill level.

**1. Choice Timing: Pre-run**
All bets are placed before the run. During the run, you have no new choices — only performance toward fulfilling bets. The build IS the bets.

**2. Pacing: Event-triggered**
The run is punctuated by bet checkpoints. "Kill 10 enemies by Room 3" creates event-triggered pacing where specific moments must deliver results.

**3. Distribution Timing: Frontloaded (bet-provided equipment)**
All equipment is received before entry based on your bets. Bet on speedrunning? You get speed equipment immediately. No mid-run rewards.

**4. Agency: Deterministic (betting)**
You choose exactly what bets to place. Bet conditions are explicit, equipment provided is clear. No randomness in the build — only in dungeon encounters.

**5. Negative Acquisition: Traded (risk ↔ reward)**
You trade safety for power. Each bet increases potential reward but also potential loss. Conservative bets give modest equipment; aggressive bets give powerful equipment with harder conditions.

**6. Scarcity: Moderate**
Conservative bets = scarcity. Aggressive bets = abundance with risk. Average out to moderate scarcity overall — you choose your position on the spectrum through bet ambition.

**7. Reversibility: Permanent (bet-locked)**
Bets cannot be canceled. Equipment cannot be returned. Fail a bet, lose everything. **Commitment Weight: Critical** — bets are life-or-death commitments.

**8. Capacity: Dynamic**
More aggressive bets provide more equipment slots. Conservative betting limits your capacity. The ceiling is how much you dare to wager — capacity is dynamic based on betting choices.

**9. Interaction: Synergistic (bet combos)**
Certain bets synergize. "Kill quickly" + "Take no damage" provide equipment that combos into glass cannon builds. Parlay bets combine conditions for multiplicative rewards.

**10. Upgrade Depth: Flat (within run)**
No upgrades during the run — you have what your bets provided. The "depth" is in bet selection before running.

**11. Power Source Diversity: Single source (bets)**
All power from bet-provided equipment. No shops, no drops, no alternative sources. Your bets are your entire build.

**12. Visibility: Complete**
Bet conditions fully disclosed. Equipment provided fully visible. Win/lose conditions clear. No hidden information — the gamble is in your execution, not hidden rules.

**13. Comprehension: Transparent**
Exact numbers visible for all bets and equipment. Perfect information for calculating risk/reward ratios.

**14. Growth Pattern: Plateau**
No power growth during the run. You're as strong at minute one as minute ten — you start at full power and plateau there. The "growth" is fulfilling bet conditions, not gaining power.

**15. Persistence: Unlocks + Resources**
Successful bets unlock new bet types and equipment. But winnings can also be wagered on future runs — bet your accumulated resources for bigger rewards, lose them if you fail.

**16. Starting Variance: Loadout-varied**
Every run differs by what you bet — bets determine your equipment loadout. Two players with identical unlocks could place completely different bets and have completely different starting loadouts.

**17. Run Identity: Pre-determined (by bets)**
Identity is set at the betting house. "I'm doing a speed run" or "I'm doing a no-damage run" — your bets define who you are before entering.

**Skill vs Build Ratio: Balanced**
Knowing your capabilities and betting accurately is 50%. Executing to fulfill those bets is 50%. Overconfident bets doom you; underconfident bets limit you.

---

## Experimental Games Frequency Analysis

[Framework](#the-framework) | [Games](#game-classifications) | [Frequency](#frequency-analysis) | [Designs](#hypothetical-designs) | [Experimental](#experimental-games-frequency-analysis)

Based on 9 experimental game designs (excluding the 3 archetypal games).

### 1. Choice Timing
- Pre-run (5): Loadout, Expedition, Stance Dancer, Bloodline, Gambler's Dungeon
- Distributed (3): Branching Path, Tide Caller, Bloodline
- Milestone (3): Tide Runner, Expedition, Tide Caller
- Reactive (1): Stance Dancer

#### Pacing
- Player-controlled (6): Loadout, Tide Runner, Branching Path, Expedition, Stance Dancer, Labyrinth
- Event-triggered (3): Expedition, Tide Caller, Gambler's Dungeon
- Milestone (2): Tide Runner, Bloodline
- Performance-based (2): Branching Path, Bloodline
- Resource-gated (1): Branching Path
- Fixed interval (0): None

### 2. Distribution Timing
- Frontloaded (5): Loadout, Expedition, Stance Dancer, Bloodline, Gambler's Dungeon
- Immediate (5): Tide Runner, Branching Path, Tide Caller, Labyrinth, Bloodline
- Partitioned (1): Stance Dancer
- Distributed (1): Expedition
- Delayed-Random (0), Delayed-Sequential (0), Conditional (0): None

### 3. Agency
- Deterministic (7): Loadout, Branching Path, Expedition, Stance Dancer, Labyrinth, Bloodline, Gambler's Dungeon
- Curated (2): Stance Dancer, Tide Caller
- Serendipitous (2): Tide Runner, Labyrinth
- Influenced (2): Tide Runner, Tide Caller
- Predetermined (0): None

### 4. Negative Acquisition
- Traded (5): Loadout, Expedition, Stance Dancer, Bloodline, Gambler's Dungeon
- None (2): Branching Path, Labyrinth
- Coupled (2): Tide Runner, Tide Caller
- Optional (0), Forced (0): None

### 5. Scarcity
- Moderate (5): Loadout, Branching Path, Expedition, Stance Dancer, Gambler's Dungeon
- Drought/Feast (2): Tide Runner, Tide Caller
- Abundant (1): Bloodline
- Scarce (0), Competitive (0), Time-pressured (0): None

### 6. Reversibility
- Permanent (8): Loadout, Branching Path, Expedition, Stance Dancer, Tide Caller, Labyrinth, Bloodline, Gambler's Dungeon
- Swappable (2): Tide Runner, Stance Dancer
- Transformable (0), Removable (0), Sellable (0), Fluid (0): None

#### Commitment Weight
- Critical (4): Loadout, Expedition, Bloodline, Gambler's Dungeon
- Heavy (2): Branching Path, Labyrinth
- Medium (2): Tide Runner, Tide Caller
- Light (0): None

### 7. Capacity
- Hard cap (4): Loadout, Tide Runner, Expedition, Stance Dancer
- Dynamic (2): Bloodline, Gambler's Dungeon
- Soft cap (1): Tide Caller
- Contextual (1): Branching Path
- Unlimited (1): Labyrinth

### 8. Interaction
- Synergistic (7): Loadout, Tide Runner, Expedition, Stance Dancer, Tide Caller, Labyrinth, Gambler's Dungeon
- Hierarchical (3): Branching Path, Labyrinth, Bloodline
- Exclusive (1): Branching Path
- Independent (0), Competitive (0), Systemic (0): None

### 9. Upgrade Depth
- Flat (4): Loadout, Tide Runner, Expedition, Gambler's Dungeon
- Linear (4): Loadout, Expedition, Stance Dancer, Tide Caller
- Branching (2): Branching Path, Labyrinth
- Evolutionary (1): Bloodline
- Infinite (0): None

### 10. Power Source Diversity
- Single source (6): Tide Runner, Branching Path, Tide Caller, Labyrinth, Bloodline, Gambler's Dungeon
- Multi-source (3): Loadout, Expedition, Stance Dancer
- Dual source (0), Interconnected (0): None

### 11. Visibility
- Complete (7): Loadout, Branching Path, Expedition, Stance Dancer, Labyrinth, Bloodline, Gambler's Dungeon
- Present (4): Tide Runner, Expedition, Stance Dancer, Tide Caller
- Forecast (1): Tide Caller
- Progressive (1): Labyrinth
- Pool-visible (0), Obscured (0), Blind (0): None

### 12. Comprehension
- Transparent (9): All experimental games
- Calculable (1): Tide Caller
- Learnable (1): Bloodline
- Opaque (0), Unknown (0): None

### 13. Growth Pattern
- Additive (4): Branching Path, Stance Dancer, Tide Caller, Bloodline
- Plateau (2): Loadout, Gambler's Dungeon
- Oscillating (2): Tide Runner, Stance Dancer
- Multiplicative (2): Labyrinth, Bloodline
- Subtractive (1): Expedition
- Transformative (0): None

### 14. Persistence
- Unlocks (8): Loadout, Tide Runner, Branching Path, Expedition, Stance Dancer, Tide Caller, Labyrinth, Gambler's Dungeon
- Resources (3): Loadout, Expedition, Gambler's Dungeon
- Legacy (1): Bloodline
- Nothing (0), Upgrades (0), Progress (0): None

### 15. Starting Variance
- Loadout-varied (5): Loadout, Tide Runner, Expedition, Stance Dancer, Gambler's Dungeon
- Character-varied (2): Tide Runner, Tide Caller
- Random-varied (1): Branching Path
- Seeded (1): Labyrinth
- Inherited (1): Bloodline
- Identical (0): None

### 16. Run Identity
- Emergent (5): Tide Runner, Branching Path, Stance Dancer, Tide Caller, Labyrinth
- Pre-determined (4): Loadout, Expedition, Bloodline, Gambler's Dungeon
- Early-crystallizing (0), Fluid (0), Convergent (0): None

### 17. Skill vs Build Ratio
- Balanced (9): All experimental games
- Execution-dominant (0), Build-dominant (0), Knowledge-dominant (0): None

### Notable Patterns

**Compared to the 22 real games:**

- **Pre-run heavy**: 5/9 experimental games use Pre-run choice timing vs 4/22 real games. The experimental designs lean toward frontloaded decision-making.

- **Deterministic dominant**: 7/9 use Deterministic agency vs 2/22 real games. Experimental designs favor player control over randomness.

- **Traded negatives**: 5/9 use Traded negative acquisition vs 0/22 real games. This option was completely unused in real games but common in experimental designs exploring trade-off mechanics.

- **Single source preference**: 6/9 use Single source power diversity vs 2/22 real games. Experimental designs tend toward unified systems rather than multiple interlocking systems.

- **Complete visibility**: 7/9 use Complete visibility vs 7/22 real games. Proportionally much higher — experimental designs favor full information.

- **Critical commitment**: 4/9 use Critical commitment weight vs 1/22 real games. Experimental designs explore high-stakes, defining choices.

- **Plateau growth**: 2/9 use Plateau growth pattern vs 0/22 real games. This previously unused option appears in designs with frontloaded power.

- **Drought/Feast scarcity**: 2/9 use Drought/Feast vs 0/22 real games. Another previously unused option explored in experimental designs.

- **All Balanced**: Every experimental game uses Balanced skill/build ratio — no extreme designs in either direction.

---

## Summary: Design Space for New Roguelites

The experimental designs reveal a consistent pattern: they trade randomness for player control. Where real roguelites typically use Curated or Serendipitous agency (letting RNG shape runs), the experimental games overwhelmingly favor Deterministic agency — the player decides exactly what they get. This represents a fundamental shift from "adapt to what you find" toward "plan and execute." The trade-off is clear: deterministic systems offer deeper strategic planning but sacrifice the surprise and adaptability that define traditional roguelike appeal. Developers exploring this space should consider hybrid approaches like Labyrinth of Choices, which uses deterministic pathing but serendipitous loot within nodes.

The experimental games also cluster around frontloaded decision-making with critical commitment weight. Five of nine games use Pre-run choice timing, and four use Critical commitment weight — meaning a small number of choices define the entire run. Real games rarely do this (Into the Breach being the notable exception). This creates a different emotional arc: instead of gradually discovering your build, you architect it upfront and then test your design. The satisfaction shifts from "look what emerged" to "my plan worked." For developers, this suggests an underexplored design space: roguelites where the run is won or lost in the planning phase, with execution serving as validation rather than adaptation.

Several framework options went completely unused in the 22 real games but appear in experimental designs: Traded negative acquisition, Drought/Feast scarcity, Plateau growth pattern, and Dynamic capacity. These represent genuinely unexplored territory. Traded negatives (where gaining power requires sacrificing something) appeared in five experimental games but zero real ones — a striking gap given how common trade-off mechanics are in other genres. Drought/Feast scarcity, where resources alternate between absence and overwhelming abundance, creates a rhythm fundamentally different from the steady drip of most roguelites. Developers looking to differentiate should examine these unused options as starting points.

The experimental games also show a strong preference for Single source power diversity (6/9) compared to real games (2/22). This suggests that innovative roguelites might benefit from committing fully to one unified system rather than layering multiple semi-independent systems. When power comes from a single source — whether it's a skill tree, a betting mechanic, or a tide gauge — that system can be deeper and more mechanically distinctive. The complexity comes from the system's internal richness rather than from juggling multiple systems. This is the opposite of the "more systems = more depth" assumption that drives many roguelite designs.

Finally, the complete absence of Build-dominant or Execution-dominant designs in the experimental games is notable. Every experimental game targets Balanced skill/build ratio. This may reflect a design philosophy that interesting new mechanics should matter for both planning and execution, rather than tilting heavily toward either. It may also represent a blind spot — perhaps the most innovative unexplored designs are ones that go fully Build-dominant (the game plays itself once properly constructed) or fully Execution-dominant (moment-to-moment skill matters far more than build choices). The space at the extremes remains largely uncharted.
