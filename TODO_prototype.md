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
    - How do we unstack cards? Dragging sufficiently far away from stack? -> implement simplest way
- Card stacking with validation and stack adding/removal
    - action modifiers can stack on top of actions.
    - actions can't stack on top of other actions.
- make card areas that can accept new cards, transferring card away from existing card area if need be. also make ones that will accept only one card (trigger slot)
- add basic triggers, actions, and modifiers and hook them up to gameplay.
- make cards stackable only in the augment action area (only one action card can be in the action area, but multiple modifiers can be stacked on top of it in the augment area)

# errors
- card areas don't shift cards reliably when there are lots of cards in an area, and cards are dragged around inside.
- stacks need debugging. stack only on bottom card. also deal with card movement error when dragging stacked cards which are not the bottom card.
- Hover can't be enabled on world container, it overrides everything. need a way to make it so cards can still be removed from a card area somehow.