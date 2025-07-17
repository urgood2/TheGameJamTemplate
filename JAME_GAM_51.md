- progress bar doesn't render properly when inside a uibox and given alginment - only renders at the inner top. why?

- end of day- bring up shop screen
- close button for shop
- building placement
- trigger interaction 
- cost overlay (maybe attachment?) to buttons
- camera with right mouse


- A day loop where one day ends, you go to a shop screen.
- How would we manuever entities away from the rain?
- There should be a mechanic that gives a reward for the risk of entering the rain. Maybe the rain/storm should be deterministic instead of random, in that case?
- Triggers: on getting wet, on one walk step, on evading rain, on attacking a colonist who has been "corrupted" by the rain - these triggers could do something. - Maybe we can base relics on them and sell them in the shop. Which begs the question, where does the currency come from? Maybe rained-on colonist produce coin for some negative consequence in return.

- [ ] #to-process 23:06 copy station where units will go to be copied, random umbrella effects/ always reduces health
- [ ] Currency: gold start with 5
- [ ] Copy station is 5 gold
- [ ] Homes produce 1 colonist, 1 gold every 2 days
- [ ] Buy weather events (thunderstrom, snowstorm, firedtorm, rain) which will impact colonists differently based on their umbrella tags, always damages them

- copy station where units will go to be copied, random umbrella effects/ always reduces health
- Currency: gold start with 5
- Homes produce 1 colonist, 1 gold every 2 days
- colonists can do gather jobs which also result in gold at the end of the day
- gold can be spent on getting more colonists, duplicators, or weather events, or umbrellas (relics) in shop
- weather events will bring on dangerous rain, etc. which damages colonists but gives some kind of reward
- If colonists have umbrellas (which  have random properties) they will interact with the weather events in some way (got to think this out, ideas welcome)


# ideas to implement next
- movement based on goap rather than crude timer, also make them mine resources, and move continously rather than in jerks, add walking animation as well. also make them go and find & eat food when they are hungry
- use a text indicator to show hunger and health
- next up weather window which shows the events queued, and how many days off it is
- hook up duplicator and allow mutant creation behavior - go to duplicator, disappear & activate, half max health
    - duplicators produce:
        - slimes, which are very degenerate, but can suck up weather events like a shield for other colonists
        - proto-humans with no mining ability, but they don't need food to survive. They also unlock a special class of relics.
        - reduced hp normal colonists
- currency generation through homes at the end of the day
- randomized relic selection from the shop menu
    - think of relic ideas, which also involve triggers
        - three types: protohuman, slime, human
        - basic umbrella - gives 1 reduction to all damage for all units
- trigger brainstorming ( use signals)
    - on start weather event
    - on end weather event
    - on new colonist birth
    - on colonist death
    - on start of day 
    - on end of day 
    - on entity death 
    - on relic purchase
    - on new structure built
    - every x hours during the day/night
    - on hit by weather event 
    - on damage of type acid, cold, heat, or death
- effect brainstorming 
    - grant x gold
    - grant x hp 
    - grant damage reduction
    - grant avoidance chance
    - grant mining speed increase
    - chance to generate gold
    - chance to spawn a new duplicator
    - chance to spawn a new home
    - chance to apease hunger by x
- weather event brainstorming 
    - acid rain 
        - form of damage: acid 
        - shape of damage: random damage rects 
    - snow event
        - form of damage: cold 
        - shape of damage: grid of damage rects to show snow?
    - sunny event
        - form of damage: heat 
        - shape of damage: direct damage to colonists
    - death event
        - form of damage: death 
        - shape of damage: direct damage to colonists 
- there needs to be a baseline challenge which arrives every x days
- how to make each day more interesting? resource mining plus selling that?
- use rectangle queuing, etc for drawing 

# outstanding bugs
- web displacement shader not compiling
- the pause button not resetting at auto-pause at the end of the day


# polish
- color palette shader
- pixelate shader
- change font


# later todos
- dedicated Alignment callback for windows on resize
- text updating wrong. not easy to configure updates with on update method for some reason.
- renew alignment needs to cache so it can be called every frame
- add chain funcionality to timer?
- maybe a text log of sorts, with scroll?
- bug whre fine tuning offset not respected at render time, ui box aligns correctly, but not the root for ui box 
- is there a way to make blackboard a lua table that can be reliably fetched from lua?
- ui box aligned to a transform with extrafintuning goes haywire when trasnform's rotation changes