# Fusions, Volley, and Chain Logic (POA Ultrawork Style)

> Source: Magicraft Wiki (Fuse, Fusion Summon, Volley). Focus on damage economics and chaining.

---

## Damage & Cost Model
`Total Damage = (Base Spell Damage × Boosts × Passives) × Crit`
`Volley Cost = base_cost * discount^(casts-1)` (discount per parallel shot)

Design Insight: Pad volleys with cheap shots, finish with expensive payloads (Nova/Meteor/Star Arrow). Ensure homing to convert discount into hits.

---

## Fuse
- **Behavior**: On projectile end, immediately casts the first shooting spell to the right; base cost x90% (upgrade lowers further).
- **Usage**: Back-load payloads without waiting on cast interval; nest inside chains for deterministic timing.

## Fusion Summon
- **Effect**: Merge two identical summons into one with **+100% attributes**; for Skull of the Cthulhu, fusion boosts tick rate (2× first, 3× second).
- **Pattern**: Keep two summons alive; fuse to consolidate DPS/tankiness; pair with Indomitability to avoid one-shots.

## Volley (Parallel Casting)
- **Mechanic**: Fires multiple slots simultaneously; used with simultaneous-fire wands (Harmonic Resonance, Stellar Drift).
- **Economy**: Strongest MP discount in game; mandatory homing/area control to avoid whiffs.

---

## Templates
- **Volley Payload**: [Volley] [Echo] [Area Boost] → [Arcane Nova] → [Arcane Nova/Star Arrow]
- **Fuse Payload**: [Cheap hit] → [Fuse] → [Meteor/Star Arrow]
- **Fusion Army**: [Summon] [Summon] [Fusion Summon] [Indomitability] [Energy Saving]
- **Post-Slot Burst**: Fill charge via low-cost casts (777/Frenzy) → store payload in post-slot → detonate when charged

---

## Risks & Mitigations
| Risk | Mitigation |
| :-- | :-- |
| Mana crash on Volley | Mana Absorption, two-wand rotation |
| Misses with high scatter | Track/Homing; Precise Shot |
| Reverse-order wands | Visually reverse slot plan (Defiant Nature) |
| Charge desync | Align Fuse triggers with post-slot thresholds |
