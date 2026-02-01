# bd-2qf.42: [Descent] G1 Shop system

## Implementation Summary

Created shop system for Descent roguelike mode with deterministic stock generation.

## Files Created

### `assets/scripts/descent/shop.lua`

**Key Features:**
- Shop on floor 1 per spec (configurable via `shop_floors`)
- Weighted item pool for stock generation
- Price variance using RNG for determinism
- Atomic purchases (gold deducted only on success)
- Reroll system with exponential cost increase

**Stock Generation:**
- `generate(floor, seed)` - Generate stock for floor
- Uses deterministic subseed: `seed + (floor * 1000) + 42`
- Weighted random selection from item pool
- 4-6 items per shop (configurable)

**Purchase System:**
- `purchase(player, item_index)` - Buy item
- Returns `INSUFFICIENT_GOLD` with 0 turn cost if can't afford
- Marks item as sold, deducts gold atomically
- Returns purchased item copy

**Reroll System:**
- `get_reroll_cost()` - Base 50, doubles each time
- `reroll(player)` - Regenerate stock (costs gold)
- Deterministic via incremented seed

**Public API:**
- `init(rng?, items?)` - Initialize with dependencies
- `generate(floor, seed)` - Generate shop for floor
- `is_open()` / `has_shop(floor)` - Query shop availability
- `get_stock()` / `get_available()` - Query stock
- `purchase(player, index)` - Buy item
- `reroll(player)` - Regenerate stock

## Acceptance Criteria

| Criterion | Status |
|-----------|--------|
| Shop on floor 1 per spec | ✅ `floor_has_shop()` checks |
| Stock deterministic per seed+floor | ✅ Subseed calculation |
| Purchase atomic | ✅ Gold deducted only on success |
| Insufficient gold = 0 turns | ✅ Returns 0 cost |
| Reroll cost enforced | ✅ Exponential cost increase |

## Usage

```lua
local shop = require("descent.shop")
shop.init()
shop.generate(1, 12345)  -- Floor 1, seed 12345

local stock = shop.get_available()
for i, entry in ipairs(stock) do
    print(entry.item.name, entry.price)
end

local result = shop.purchase(player, 1)
if result == shop.RESULT.INSUFFICIENT_GOLD then
    print("Not enough gold!")  -- 0 turns consumed
end
```

## Agent

- Agent: RedEagle (claude-code/opus-4.5)
- Date: 2026-02-01
