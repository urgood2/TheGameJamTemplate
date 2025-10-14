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
- add basic triggers, actions, and modifiers and hook them up to gameplay.

# errors
- card areas don't shift cards reliably when there are lots of cards in an area, and cards are dragged around inside -> probably a bug in the card area shifting logic.
- stacking cards misbehave in terms of z-order. Sometimes they move when clicked when they shouldn't.


# design questions
- should trigger slots only have one trigger, or multiple?
- what properties do triggers have? delay between activations? chance to activate?

# ui/ux questions
- should remove area only appear when player drags a card?
- should we show an overlay over an area if it isn't a valid drop target? How would we detect when to show it?
