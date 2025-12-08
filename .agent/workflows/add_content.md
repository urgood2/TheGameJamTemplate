---
description: How to add new Cards, Jokers, and Projectiles
---

# Adding Content

This workflow guides you through adding new content to the game using the data-driven system.

## 1. Adding a New Card (Action or Modifier)

1.  Open `assets/scripts/data/cards.lua`.
2.  Add a new entry to the `Cards` table.
    *   **ID**: Unique string identifier (e.g., `Cards.MY_NEW_CARD`).
    *   **Type**: "action" or "modifier".
    *   **Properties**: Define mana cost, damage, sprite, etc.
3.  (Optional) If it's a projectile, you can reference a preset from `assets/scripts/data/projectiles.lua` (once fully implemented) or define properties inline.

**Example:**
```lua
Cards.ACTION_FIREBALL = {
    id = "ACTION_FIREBALL",
    type = "action",
    mana_cost = 10,
    damage = 20,
    damage_type = "fire",
    projectile_speed = 600,
    test_label = "ACTION\nfireball"
}
```

## 2. Adding a New Joker

1.  Open `assets/scripts/data/jokers.lua`.
2.  Add a new entry to the `Jokers` table.
    *   **ID**: Unique string identifier.
    *   **Calculate Function**: Implement the `calculate(self, context)` function to define behavior.

**Example:**
```lua
my_joker = {
    id = "my_joker",
    name = "My Joker",
    description = "+10 Damage.",
    rarity = "Common",
    calculate = function(self, context)
        if context.event == "on_spell_cast" then
            return { damage_mod = 10 }
        end
    end
}
```

## 3. Adding a New Avatar

1.  Open `assets/scripts/data/avatars.lua`.
2.  Add a new entry defining the avatar's stats and unlock conditions.

## 4. Verification

1.  Run the game.
2.  Open the console (if available) or check the Cast Feed to ensure your new content appears.
3.  Use `assets/scripts/core/card_eval_order_test.lua` to simulate wand execution with your new card.
