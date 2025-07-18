# immediate todos
- structure placement & functionality
- relic purchasing & shop randomization & functionality
- gold digger & healer behavior
- use script component's script (store in lua) to make blackboard accessing easier and more sustainable performance wise
- ui window reordering
- deduct gold at end of day for healers & damage cushions, add game over state for negative currency

 - [ ]  Same challenges, but different strategies - 
 - [ ]  weather events of increasing damage spring (acid), summer (sunburn), rare golden season (gold falls from sky, does some damage) - pace these to happen every 2 days, each season is 3 weather events, there is only summer and winter, 
 - [ ] Increasing damage, damage frequency, different damage types. Each year increases base damage done by 3. 
 - [ ] Different strategies - relics, copy minions, structures
 - [ ] Relics - rare, can only buy 1 per shop at end of day: resist damage, absorb damage, give chance based healing, 
    -- global resist acid damage by 1/3/5
    -- global resist cold damage by 1/3/5
    -- grant 10%/20%/30% dodge chance during weather event
    -- on a colonist being damaged, 50% chance to grant 2 hp to a random colonist
    -- on dodge, grant 2 hp to a random colonist
    -- damage taken X2, but all gold doubled at the end of the day
    -- gold diggers dig 2/4/6 more gold each time
    -- healers heal 2/4/6 times as much
    -- damage cushions gain 10/40/70 hp
 
 - [ ] Copy  (cheap but can die, produce at any time) - healer minion, damage cushion minion, gold digger minion
    -- gold digger 3830-TheRoguelike_1_10_alpha_623.png
        -- costs nothing but dies very easily
    -- healer 3868-TheRoguelike_1_10_alpha_661.png
        -- costs 1 gold each turn to maintain
    -- damage cushion 3846-TheRoguelike_1_10_alpha_639.png  
        -- costs 2 gold each turn to maintain
    
 - [ ] Structures (expensive but permanent): mass umbrella (absolute orotection, but cootime of 5 days), gold generator (2 gold per minion, but subtracts health from 2 random minions per day), weather deflector (chance to swap an incoming weather to something else)
    -- mass protector 3703-TheRoguelike_1_10_alpha_496.png
    -- gold generator 3435-TheRoguelike_1_10_alpha_228.png
    -- 3530-TheRoguelike_1_10_alpha_323.png
 
 - [ ] Ending a stage without taking damage or by not losing a minion grants bonus
 - [ ] 


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
- add a basic weather event which occurs every other day (lightning storm)
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
 - [ ] Different font for title and body in tooltip
 - [ ] How to make ui element float from its  the indow (like hover effect, but with y axis?)
 - [ ] Reduce crt noise to make text more readable
 - [ ] large bar across screen + announcement text
 - [ ] Really need to make use of the layer order thing. To show stuff on top
 - [ ] Customizinf transform shadows to have a bottom shadow instead
 - [ ] Damage flash shader (customizable color)
- dedicated Alignment callback for windows on resize
- text updating wrong. not easy to configure updates with on update method for some reason.
- renew alignment needs to cache so it can be called every frame
- add chain funcionality to timer?
- maybe a text log of sorts, with scroll?
- bug whre fine tuning offset not respected at render time, ui box aligns correctly, but not the root for ui box 
- is there a way to make blackboard a lua table that can be reliably fetched from lua?
- ui box aligned to a transform with extrafintuning goes haywire when trasnform's rotation changes
- some way to hook up lua table state, easily retriveable, through lua code, with entt entities
- sprite order sorting so what's behind somehting can properly go behind, etc.
- erase blackboard value, check if value exists in blackboard
- make get/set blackboard methods return lua nil if invalid instead of throwing error
- cancel_self() function which will queue a cancel for the current timer after loop finishes to avoid triggering errors
- dynamic text entity will reset its alignment and set to center on its master entity when updated via setText