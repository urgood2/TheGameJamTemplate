# Styled Localization

Color-coded text in tooltips using localization strings.

## JSON Syntax

```json
{
  "tooltip": {
    "attack_desc": "Deal {damage|red} {element|fire} damage"
  }
}
```

Format: `{placeholder|color}`

## Lua Usage

```lua
-- Uses JSON default colors
local text = localization.getStyled("tooltip.attack_desc", {
  damage = 25,
  element = "Fire"
})
-- Result: "Deal [25](color=red) [Fire](color=fire) damage"

-- Override color at runtime
local text = localization.getStyled("tooltip.attack_desc", {
  damage = { value = 25, color = "gold" }
})
-- Result: "Deal [25](color=gold) [Fire](color=fire) damage"
```

## Tooltip Helper

```lua
local tooltip = makeLocalizedTooltip("tooltip.attack_desc", {
  damage = card.damage,
  element = card.element
}, { title = card.name })
```

## Named Colors

| Color | Usage |
|-------|-------|
| `red` | Damage, negative |
| `gold` | Currency, special |
| `green` | Healing, positive |
| `blue` | Mana, water |
| `cyan` | Info |
| `purple` | Rare, magic |
| `fire` | Fire element |
| `ice` | Ice element |
| `poison` | Poison element |
| `holy` | Holy element |
| `void` | Void element |
| `electric` | Lightning element |

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
