# bd-2qf.45: [Descent] G2 God system (Trog)

## Implementation Summary

### File Verified

**`assets/scripts/descent/god.lua`** (9 KB)

#### Features
- **Trog God**: Berserker god with piety, abilities, spell restriction
- **Altar System**: `floor_has_altar()` uses spec floors
- **Worship Persistence**: Stored on player object (player.god, player.piety)
- **Piety Management**: add_piety, decay_piety, on_kill
- **Abilities**: berserk, trog_hand with piety costs

### Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Altars per spec floors/odds | OK `floor_has_altar()` checks spec |
| Worship persists across floors | OK player.god/piety stored on player |
| Trog blocks spell cast with message | OK line 175 returns (false, msg, 0) |
| 0 turns for blocked spell | OK third return value is 0 |

### Key Functions

- `God.worship(player, god_id)` - Begin worship
- `God.can_cast_spell(player)` - Returns (can_cast, message, turn_cost)
- `God.floor_has_altar(floor_num)` - Check spec for altar
- `God.add_piety(player, amount)` - Modify piety
- `God.use_ability(player, ability_id)` - Use god ability

### Trog Restrictions

```lua
restrictions = {
    no_spells = true,  -- Cannot cast any spells
}

function God.can_cast_spell(player)
    if god.restrictions.no_spells then
        return false, god.name .. " forbids the use of magic!", 0
    end
end
```

## Agent

- **Agent**: FuchsiaFalcon
- **Date**: 2026-02-01
