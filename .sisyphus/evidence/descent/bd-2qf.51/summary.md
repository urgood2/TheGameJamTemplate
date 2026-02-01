# bd-2qf.51: [Descent] G3-2 Spell: Heal

## Implementation Summary

Heal spell was already implemented in `assets/scripts/descent/spells.lua` as part of the base spells module (bd-2qf.48).

## Implementation Details

### In `assets/scripts/descent/spells.lua`

**Spell Definition (lines 29-36):**
```lua
heal = {
    id = "heal",
    name = "Heal",
    mp_cost = 3,
    range = 0,           -- Self-target
    requires_los = false,
    heal_amount = 6,
    type = "heal",
}
```

**Cast Logic (lines 158-169):**
- Receiver = target or caster (self-target)
- Restores 6 HP capped at hp_max
- Returns { success, type="heal", amount, cost }

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Self-target | ✅ range=0, receiver defaults to caster |
| HP restore | ✅ heal_amount=6 |
| MP cost per spec | ✅ mp_cost=3 |
| Capped at max HP | ✅ min(max_hp, before + heal) |

## Agent

- Agent: RedEagle (claude-code/opus-4.5)
- Date: 2026-02-01
- Note: Implementation verified, was part of G3 base module
