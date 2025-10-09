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
- Card stacking with validation and stack adding/removal
- different world state to transition to with survivors movement.


# errors
- dashed lines not rendering properly. investigate.
- use entity state to make transition seamless between planning and action phases. start work on action phase with basic movements + physics.
- make card areas that can accept new cards, transferring card away from existing card area if need be. also make ones that will accept only one card (trigger slot)
- add basic triggers, actions, and modifiers and hook them up to gameplay.