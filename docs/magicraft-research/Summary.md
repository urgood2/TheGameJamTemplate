# Magicraft Research Summary (POA Ultrawork Style)

## Executive Snapshot
Magicraft is a wand-driven roguelike where **per-wand mana**, **left→right slot execution**, and **parallel casting (Volley)** define power. **Fuse** enables instant next-slot logic; **Post-Slot** channels store energy for passive bursts. Elements are applied via crystals/cores; builds hinge on hit density (Poison), base damage (Fire payloads), or chain coverage (Thunder).

## Core Design Philosophy
- **Per-Wand Resources**: Each wand has its own MP, regen, cast interval, and cooldown; wand swapping is resource rotation.
- **Deterministic Ordering**: Slots execute strictly left→right unless reversed (Defiant Nature) or parallelized (Stellar Drift/Harmonic Resonance).
- **Parallel Economics**: Volley discounts stack with simultaneous casts; pad with cheap shots before expensive payloads.
- **Event Hooks**: on_cast, on_hit, on_kill, on_charge (post-slot). Fuse hooks into projectile end to branch.

## Implementation Roadmap
- **Phase 1: Wand Pipeline**
  - Data: mp_max, mp_regen, cast_interval, cooldown, scatter, simul_count, post_slot rules, flags (reverse, cost multipliers).
  - Systems: post-slot charge accumulator; reverse order traversal; simultaneous fire execution.
- **Phase 2: Spell Logic**
  - Implement Volley (parallel + discount), Fuse (call-next on end), Echo (replay), Track (homing), Split/Multi-Shot (projectile fan), penetration/reflection.
  - Element injection via crystals/cores with status application hooks.
- **Phase 3: Synergy Layer**
  - Fusion Summon (merge entities + stat doubling), Mimicry Cube (wildcard resolution), Mana Absorption (per-hit resource return), Indomitability (summon invuln window), post-slot burst emitters.

## Resource/Stat Trade-offs (Design Insight)
| Stat | Effect | Risk | Mitigation |
| :-- | :-- | :-- | :-- |
| MP Max | Allows larger payloads | Long recharge if drained | Two-wand rotation, Mana Absorption |
| MP Regen | Sustains spam | Low burst ceiling | Pair with Volley discount |
| Cast Interval | Controls fire rate | Can overrun MP | Add Energy Saving / Absorption |
| Cooldown (CD) | Downtime after chain | Vulnerable windows | Control wand to bridge CD |
| Scatter | Accuracy loss | Missed damage | Track/Homing, Precise Shot |

## Event Loop (pseudo-code)
```lua
for slot in ordered_slots(wand) do
  cast(slot.spell)
  if spell.triggers_next_on_end then schedule(next_slot)
end

on_hit(event):
  apply_elements(); mana_absorb(); post_slot.charge(event)

post_slot.update(dt):
  if charge >= threshold then fire(post_slot_spell)
```

## Elements (micro)
- Poison (Venom): tick-rate scaling; best with multihit (Serpent/Butterfly/Beam).
- Fire (Core of Flame): source-based burn; best on high-base payloads (Meteor/Star Arrow).
- Thunder: chain; best in dense rooms with ricochet/Volley.
- Frost/Slime: control; slot early for safety.

## Build Hooks
- **Volley Payload (Stellar Drift)**: Volley + Echo + Area Boost + Arcane Nova x2; Track required.
- **Homing Serpent**: Track + Shadow Serpent + Venom Crystal + Mana Absorption (Swiftcaster).
- **Grimoire Hive**: Autonomous Grimoire ×2 + Fusion Summon + Energy Saving + Indomitability.
- **Laser Reflector**: Laser/Ray + Reflection/Ricochet + Venom; room lattice.
- **Area Boost Mimicry**: Area Boost + Mimicry Cube + Meteor.

## Testing/Verification Checklist
- [ ] Volley executes parallel and applies discount correctly.
- [ ] Fuse triggers the first shooting spell to the right on projectile end.
- [ ] Reverse order flag inverts traversal (Defiant Nature) without breaking triggers.
- [ ] Post-slot charge hooks (on cast/hit/move/kill/damage) fire stored spell at threshold.
- [ ] Element/status application aligns with crystals/cores.
