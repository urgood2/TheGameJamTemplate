- 3 triggers:

    Every N seconds

    On being hit

    On enemy death

- 3 actions:

    Fire Bolt

    Explosion

    Summon Minion

- 4 modifiers:

    Empower (+damage)

    Duplicate (second copy, weaker)

    Pass Through (pierce enemies)

    Detonate (summon explodes on death)
    
    
# programming side
- Card stacking with validation and stack adding/removal
    - action modifiers can stack on top of actions.
    - actions can't stack on top of other actions.
- make card areas that can accept new cards, transferring card away from existing card area if need be. also make ones that will accept only one card (trigger slot)
- add basic triggers, actions, and modifiers and hook them up to gameplay.
- make cards stackable only in the augment action area (only one action card can be in the action area, but multiple modifiers can be stacked on top of it in the augment area)

# errors
- card areas don't shift cards reliably when there are lots of cards in an area, and cards are dragged around inside.


# design questions
- should trigger slots only have one trigger, or multiple?
- what properties do triggers have? delay between activations? chance to activate?
