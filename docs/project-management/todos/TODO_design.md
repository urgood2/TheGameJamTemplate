# Card Tags (with 3/5/7/9 bonuses)

* **Fire**

  * 3: Burn tick damage +10%
  * 5: Burn tick rate +15%
  * 7: Burn explosions on kill (small AoE, ICD 1s)
  * 9: Burn spreads once to nearby target (50% strength)

* **Ice**

  * 3: Slow potency +10%
  * 5: First hit on chilled enemy deals +15% bonus damage (consumes chill)
  * 7: Shatter effect: killing a chilled enemy deals AoE cold burst (20% damage)
  * 9: Frozen enemies take +25% damage from all sources

* **Buff**

    * 3: Buff duration +25%
    * 5: Buffs apply to allies in radius (small AoE)
    * 7: Buffs duration +50%
    * 9: Buffs grant +50% bonus effect (e.g. damage, speed, etc)

* **Arcane**

  * 3: Actions chain +1 target
  * 5: Chained hits restore 10% cooldown (ICD 1s)
  * 7: Chain ricochets bounce back once at 50% power
  * 9: Final chain hit creates an arcane nova (small AoE)

* **Mobility**

  * 3: On-move procs +50% frequency
  * 5: Gain +12% move speed during any on-move cooldown
  * 7: Every 4th on-move proc emits a small spray (25% power)
  * 9: Moving triggers grant 1s evade buff (10% DR)

* **Defense**

  * 3: Flat DR +6%
  * 5: On block/parry, gain barrier for 6% max HP (ICD 1.2s)
  * 7: Thorns pulse on block (40% AoE)
  * 9: Barrier refreshes 20% faster

* **Poison**

  * 3: Max poison stacks +25%
  * 5: Poison ramps +1% damage per stack/sec (cap +20%)
  * 7: On kill, 1 spore bolt (30%) seeks a new target (ICD 0.5s)
  * 9: Poison spreads on enemy death in radius (small AoE)

* **Summon**

  * 3: +12% minion HP
  * 5: +12% minion damage; deaths leave a hazard (30% for 2s)
  * 7: Every 10s, nearest minion is empowered (+25%/5s, ICD per minion)
  * 9: Summons persist +1 wave/round longer

* **Hazard**

  * 3: Hazard radius +10%
  * 5: Hazards snapshot +10% damage if you’re stationary 1s
  * 7: Hazards chain-ignite: entering hazard applies a 20% instant hit (ICD 1.5s)
  * 9: Hazards persist +2s longer after source ends

* **Brute**

  * 3: Melee damage +10%
  * 5: Melee attacks cleave nearby foes (25% damage)
  * 7: Gain +8% DR while attacking in melee
  * 9: Melee crit chance +15%

* **Fatty**

  * 3: Max HP +10%
  * 5: Gain regen 1% HP/sec while under 50% HP
  * 7: On taking lethal damage, survive at 1 HP (ICD 90s)
  * 9: Nearby allies gain +5% HP buff

---

# Action Cards (tag suggestions)

* fire a bolt forward (Fire, Arcane, Projectile)
* circular explosion around target point/self (Fire, Hazard, Arcane)
* short-range directional spray (Poison, Spray, Brute)
* short movement burst + some kind of damage (Mobility, Brute)
* temporary HP or damage absorb (Defense, Fatty)
* restore small % of HP (Defense, Fatty)
* leave persistent hazard on the ground (Hazard, Poison)
* temporary stat bonus (Defense, Summon, Buff)
* homing spray of ranged projectiles (Arcane, Poison, Projectile)
* piercing line shot (Projectile, Brute)
* shield wall (Defense, Fatty)
* toxic cloud AoE (Poison, Hazard)
* frost nova (Ice, Hazard)
* dash-through strike (Mobility, Brute)
* summon turret (Summon, Projectile)
* healing zone (Defense, Hazard)
* summon minion (Summon, Brute)
* buff allies in radius (Defense, Buff)


# Action Modifiers (tag suggestions)

* empower (+damage, +HP for summons, etc.) (Summon, Buff)
* duplicate projectile/summon, weaker each (Arcane, Summon)
* projectile bounces to new target (Arcane)
* projectile passes through enemies (Arcane, Brute)
* summons/targets detonate (Summon, Hazard)
* unit persists between waves (Summon, Defense)
* reduce trigger interval for this action (Arcane, Mobility)
* buffs allies or debuffs enemies nearby (Defense, Summon)
* double-cast next card in stack (Arcane)
* Conditional: If HP < X%, do Y instead (Defense, Fatty)
* summon a unit that auto-attacks (Summon, Brute)
* ignite on contact (Fire)
* chill on contact (Ice)
* poison on contact (Brute, Poison)
* lifesteal conversion on contact (Defense, Brute)
* aura buff allies (Summon, Defense)

+ * Shuffle: if present, all Action Modifiers are shuffled on stack use (Arcane)
+ * Loop: if present, all cards up to and including this one are repeated once (Arcane)
+ * Diminish cooldown: reduces the tag's cooldown by 30% (Arcane, Mobility)
+ * Echo: repeats the previous action card after a short delay (Arcane)
+ * Retarget: changes the target of the next action card to a random enemy within range (Arcane, Summon)
+ * Terrain Link: expands a hazard if the next action touches an existing hazard (Hazard, Defense)
+ * Blood Price: next action costs % HP and has 70% reduced cooldown (Brute, Fatty)
+ * Overcharge: next action deals 120% more damage but has double cooldown (Fire, Arcane)
+ * Gamble: next action has a 50% chance to either double its effect or fail completely (Arcane, Brute)
+ * Link: if next action cancels for any reason, also cancel the following action (Arcane, Defense)

# Trigger Types
* Trigger properties: max card capacity, action card limit per cast, cast speed (cooldown) some triggers have permanent cards that must stay in it.

* every N seconds
* when enemy dies
* every distance moved threshold, or per tile
* on successful block/parry
* on being hit
* on pickup loot/gold/health orb
* when action rolls crit

# Card execution rules
* Cards are played in order from top to bottom of a stack
    * Action cards fire
    * Modifiers apply to the next valid action
    * Conditionals insert branch logic (HP check, crit check, etc).
<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
