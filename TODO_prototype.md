local action_card_defs = 
        id = "fire_basic_bolt"
        id = "leave_spike_hazard",
        id = "temporary_strength_bonus"
trigger_card_defs
        id = "every_N_seconds"
        id = "on_pickup"
        id = "on_distance_moved"
modifier_card_defs 
        id = "double_effect"
        id = "summon_minion_wandering"
        id = "projectile_pierces_twice"
        id = "summons_targtes_detonate"
        id = "reduce trigger interval after this action"
        id = "duplicate action, but both are weakened."
        id = "enhance + damage or + duration"

# Non-stat values:
- player level.
    
# programming side
- maybe a few example character classes that focus on different stats or have specific set triggers/actions/mods they start with, in addition to having different starting stats, fixed bonuses that they only have, boons?
- link up the combat stat system with the traps and strength bonus action.
- make some basic enemies that wander toward player.
- add basic triggers, actions, and modifiers and hook them up to gameplay.
- mods projectile_pierces_twice and summon_minion_wandering not implemented. why is minion wandering a mod?
- apply card tag synergies: mobility, defense, hazard, brute
- think up and  apply card upgrades. e.g., bolt -> takes on an element -> pierces 3 times -> explodes on impact. We  need an upgrade resource, and an area where upgrades can be applied.
- make a general big area where cards can be kept. make cards not overlap unless they are stacked. (use colliders? how to disable when dragging so stacking still works?)
- make an arena to pan to when action phase starts, it traps enemies and player inside, ideally within the same screen area. lock camera movement, then make it follow the player slightly like in snkrx.
- also need a shop, and currency.

# errors
- card areas don't shift cards reliably when there are lots of cards in an area, and cards are dragged around inside -> probably a bug in the card area shifting logic.
- stacking cards misbehave in terms of z-order. Sometimes they move when clicked when they shouldn't.
- need a way to nudge colliders inward (or just center them) for better fit for player.

# design questions
- should trigger slots only have one trigger, or multiple?
- what properties do triggers have? delay between activations? chance to activate?
- should there be limits to how many actions and modifiers you can add to a card or area?

# ui/ux questions
- should remove area only appear when player drags a card?
- should we show an overlay over an area if it isn't a valid drop target? How would we detect when to show it?
