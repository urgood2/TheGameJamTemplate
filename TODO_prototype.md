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

- Card area with outline & drag and drop
    - how do we remove cards from an area? by dragging outside it, or some other means (pop-up button?) -> implement simplest way
    - How do we unstack cards? Dragging sufficiently far away from stack? -> implement simplest way
- Card stacking with validation and stack adding/removal
    - action modifiers can stack on top of actions.
    - actions can't stack on top of other actions.
- different world state to transition to with survivors movement.


# errors
- stacks need debugging.
- make card areas that can accept new cards, transferring card away from existing card area if need be. also make ones that will accept only one card (trigger slot)
- add basic triggers, actions, and modifiers and hook them up to gameplay.