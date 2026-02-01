# Spells — Magicraft (POA Ultrawork Style)

> Primary source: [Magicraft Wiki](https://magicraft.fandom.com/wiki/Spells) (full catalog). Slots are lost on death; spells execute **left→right** per wand unless reversed/simultaneous by wand traits. Volley and Fuse alter execution (parallel vs immediate next-slot). All spells below are enumerated; no omissions.

---

## Executive Snapshot
- **Taxonomy**: Projectiles, Continuous Casting, Indiscriminate Damage, Summons, Boosts, Passives.
- **Core logic**: Arrange spells in wand slots; modifiers must sit immediately to the left of the target. Volley = parallel fire with mana discount; Fuse = triggers the next shooting spell upon completion.
- **Design insight**: Hit consistency > raw damage (Track/Homing + Serpent/Butterfly). Mana economy is per-wand; sustain (Mana Absorption) enables payload chains.

---

## Logic Patterns (pseudo-code)
- **Volley (parallel)**
```lua
for slot in volley_slots do
  fire(slot.spell) -- simultaneous; apply cost * discount^(count-1)
end
```
- **Fuse (instant next)**
```lua
on_projectile_end(current):
  next = first_shooting_spell_to_right()
  cast(next)
```

---

## Projectiles (discrete shots)
| Name | Rarity | Notes / Role | Upgrade/Interaction Highlights |
| :-- | :-- | :-- | :-- |
| Arcane Explosion | Normal | AOE burst; pairs with Fuse/Volley | On-kill spawns extra explosions (upgrades) |
| Arcane Nova | Epic | Large AOE payload; volley-friendly | Scales with Echo/Area Boost |
| Bing's Arrow | — | Arrow projectile | Pairs with Track/Precise Shot |
| Black Hole | Rare | Pulls enemies, growing radius | Great with Echo/Volley, sets up payloads |
| Boomerang Blade | Normal | Returning projectile | Benefits from Penetration/Reflection |
| Butterfly | Normal | Tracking-ish, fragile | High hit-rate poison applier |
| Condensed Water Bubble | — | Water projectile | Synergizes with Thunder (chain) |
| Enchanting Coin | — | Bounces/utility | Ricochet economy setups |
| Evil Slayer Sword | — | Projectile sword | Works with Penetration/Volley |
| Floating Wisp | Normal | Projectile that clusters | Self-replicates on upgrade |
| Fuse | Normal | Triggers first shooting spell to its right; cost x90% | Backbone for nested chains |
| Laser | Normal | Beam line; reflection on upgrade | Pair with Reflection/Ricochet |
| Magic Bullet | Normal | Starter projectile; debuff damage taken on hit | Early-game staple |
| Mana Absorption | Epic (functionally boost but listed under projectiles) | Restores MP on hit | Core sustain engine |
| Rainbow | — | Multi-element projectile | Works with random-color wands |
| Rock 'n' Ball | Normal | Tanky rolling projectile | Leaves elemental trails |
| Shadow Serpent | Normal | Segmented curved path | High tick-rate; ideal for Poison/Track |
| Shining Star Arrow | — | High base damage arrow | Payload for Volley |
| Supernova | — | Massive AOE | Endgame payload |
| Sword of Judgement | — | High-cost strike | Bossing payload |
| Thunderstorm | — | Chain lightning | Clear + status spread |

### Continuous Casting
| Name | Rarity | Notes |
| :-- | :-- | :-- |
| Fierce Dragon Breath | — | Cone/beam continuous | Fire DOT focus |
| High-pressure Stream | — | Water jet | Combos with Thunder cores |
| Lightning Dash | — | Movement + damage dash | Mobility builds |
| Ray of Disintegration | Rare | Piercing beam, unlimited penetration | Superior single-line DPS |

### Indiscriminate Damage
| Name | Rarity | Notes |
| :-- | :-- | :-- |
| Adava Keravda | — | Big AOE/chaos | High-risk rooms |
| Deceptive Mine | — | Mine/trap | Area denial |
| Meteor | — | High-cost slam | Post-slot/Volley payload |

---

## Summons
| Name | Rarity | Notes |
| :-- | :-- | :-- |
| Autonomous Grimoire | — | Autofire book | Core of “Grimoire Hive” |
| Giant Troll | — | Heavy summon | Tanking |
| Hand of the Cthulhu | — | Summoned hand | CC/damage |
| Pillar of Light | — | Stationary pillar | Orbiting shield builds |
| Pop | — | Spawns allies | Fusion fodder |
| Skull of the Cthulhu | — | Skulls; fusion increases tick rate | Summoner DPS |

---

## Boosts (modify spell to the right)
| Name | Rarity | Notes / Effect |
| :-- | :-- | :-- |
| Accelerator | — | Faster projectiles |
| Automatic Navigate | — | Auto-aiming |
| Cadaver Explosion | — | On-death explosion |
| Chain of Lightning | — | Adds chaining |
| Collapse Crystal | — | Collapse effect |
| Core of Flame | Epic | Adds burn/source-based fire |
| Core of Thunder | Epic | Adds shock/chain |
| Blast Surge | — | Explosion boost |
| Dazzling Fireworks | — | Visual/area multi-hit |
| DMG Enhanced | — | Damage boost |
| Duet | — | Twin projectiles |
| Echo | Rare | Recasts spell once |
| End Teleport | — | Teleport at end |
| Energy Saving Mode | — | MP discount |
| Enlarge Spell | — | Size boost |
| Essence of Soul | — | Soul effect |
| Fall | — | Gravity/impact |
| Free Revolution | — | Orbiting effect |
| Frost Crystal | — | Adds frost/slow |
| Fusion Summon | Epic | Merge identical summons (+100% stats) |
| Hover | — | Air float |
| Indomitability | Epic | Prevents summon one-shots |
| Magic Upgrade | — | Damage scaling |
| Mimicry Cube | — | Wildcard slot |
| Multi-Shot | — | Multiple projectiles |
| Orbit | — | Orbiting shots |
| Over Scatter | — | Increases scatter |
| Overload | — | High-output burst |
| Parasite | — | On-hit effect |
| Penetration | — | Adds pierce | 
| Precise Shot | — | Accuracy |
| Range Enhanced | — | Range up |
| Rebound | — | Bounce |
| Reflection | — | Reflect off surfaces |
| Self Tracking | — | Self-homing |
| Serial | — | Sequential chaining |
| Slime Crystal | — | Slow/trail |
| Split | — | Splits projectile |
| Strong Traction | — | Pull effect |
| Time Duration Enhanced | — | Longer duration |
| Track | — | Homing |
| Troll Serum | — | Buff to summons |
| Twine | — | Paired tether |
| Umbilical Cord | — | Link beams/others |
| Venom Crystal | — | Poison DoT |
| Volley | Normal (top-tier boost) | Parallel fire with mana discount |

---

## Passives (slot anywhere; global or trigger-based)
| Name | Notes |
| :-- | :-- |
| Arcane Barrier | Shielding |
| Area Boost | AOE increase |
| Bi'an Flying Sword | Passive effect sword |
| Boundary Stone – Cast/Move/Stand/Time | State-based buffs |
| Capacity Expansion Stone | Slot/resource expansion |
| Charge Mode | Charge-based casting |
| Forced Cooldown | Forces cooldown window |
| Magic Reservoir | MP capacity |
| Magic Vine | Vine effect |
| Prism Core | Prism splitting |
| Resonance Rune | Orbiting shield; build synergy |
| Rune Hammer | Hammer passive |
| Spell Prototype | Prototype scaling |
| Tranquil Bloom | Healing/regen |
| Uniform Scattering | Spread normalization |
| Wand Spirit | Global wand buff |

---

## Trigger Frequency (design note)
- **On Hit**: Mana Absorption, Parasite, Echo re-triggers on hits, etc. High frequency with Serpent/Butterfly/Beam.
- **On Kill**: Arcane Explosion (upgrade), some post-slot wands charge on kill; works well with AOE payloads.
- **On Cast**: Post-slot charge per cast (many wands), Mana cost reducers.

---

## Implementation Complexity (guidance)
- **Low**: Magic Bullet, Rock’n’Ball, Basic crystals, Track, Multi-Shot.
- **Medium**: Volley (parallel exec + discount), Fuse (event hook), Echo (replay), Summons (AI emitters).
- **High**: Black Hole (pull field), Ray of Disintegration (piercing beam), Fusion Summon (entity merge + stat doubling), Mimicry (wildcard resolution).

---

## Design Insights
- **Hit density drives scaling**: Poison/Frost/Slime benefit from multihit; Fire benefits from high base damage payloads.
- **Volley economics**: Pad with low-cost shots, end with expensive payload; discounts compound.
- **Fuse chaining**: Place Fuse before payload to bypass cast delay; nests with triggers.
- **Summon fusion**: Keep two identical summons alive; fusion doubles stats and can accelerate tick rates (Skull).

---

## Quick Build Hooks
- **Homing Serpent**: Track + Shadow Serpent + Venom Crystal + Mana Absorption.
- **Echo Nova Volley**: Volley + Echo + Area Boost + Arcane Nova (×2 for Stellar Drift).
- **Laser Reflector**: Laser/Ray → Reflection/Ricochet → Venom Crystal.
- **Summoner Fusion**: Pop/Grimoire ×2 + Fusion Summon + Indomitability.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
