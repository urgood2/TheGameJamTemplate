# Core Mechanics — Systems Reference (POA Ultrawork Style)

## Resources
- **Per-wand MP**: Separate pools; regen, cast interval, cooldown, scatter per wand. Swap to recharge.
- **Cost modifiers**: MP cost multipliers on wands (e.g., Venomous Bite ×80%, Stellar Drift ×200%).

## Execution Order
- **Left→Right** default; **Reverse** on Defiant Nature/Restless Heart.
- **Simultaneous** on Harmonic Resonance, Stellar Drift, Trident, Shapeshifter, Expanding Container (and others with Simultaneous Firing >1).
- **Volley**: Parallel cast + discount; use homing/area to land hits.
- **Fuse**: Projectile-end hook to cast first shooting spell to the right at reduced cost.

## Post-Slot System
- Post-slots do not fire in the main loop; they accumulate **energy** from actions (cast/hit/move/kill/damage). When threshold reached, they trigger stored spell or passive.
- Charge sources by wand (examples): 777 (per hit), Frenzy (per cast), Rusty Blaster (per damage dealt), Book of Tranquility (per second still), Conch Whistle (per meter moved), Vow of Honor (per damage taken).

## Damage Model (practical)
`Damage = Base × Boosts × Passives × Crit` with element/status overlays. Volley discount reduces mana burden, not damage.

## Elements (hooks)
- Poison/Venom = tick-rate; Fire = source-based; Thunder = chain; Frost/Slime = control. Apply via crystals/cores.

## Safety & Control
- Open with Frost/Slime for survivability; bridge long CD volley wands with a cheap control wand.
- Use homing on any wide-spread volley setup.

## Pseudo-code Skeleton
```lua
function cast_wand(wand)
  local slots = wand:ordered_slots()
  if wand.reverse then slots = reverse(slots) end
  if wand.simul_count > 1 then
    fire_simultaneous(slots)
  else
    for s in slots do
      cast_spell(s)
      handle_fuse(s)
      wand:charge_post_slot(event)
    end
  end
end

function charge_post_slot(wand, event)
  wand.charge = wand.charge + gain_from(event)
  if wand.charge >= threshold then
    fire_post_slot_spell()
    wand.charge = 0
  end
end
```

## Verification Checklist
- Reverse flag correctly inverts traversal.
- Simultaneous fire respects scatter and cost multipliers.
- Post-slot triggers respond to correct events (cast/hit/move/kill/damage).
- Volley discount applied once per parallel batch.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
