


- 10/10/2025
  - tweak CRT shader vignette intensity to be more subtle
  - add "Start Action Phase" button to UI (non-functional for now)
  - start fleshing out TODO_prototype.md with more specific tasks and note
  - Did some ideation for how to vary triggers, with activation chance for instance.
  - Tested entity state switching between planning and action phases. Seems to work fine.
  - Tweaked BASE_SHADOW_EXAGGERATION to 1.8 from 3
  
- 10/11/2025
  - Fixed bug in transform system where offset in AssignRole was not being applied correctly.
  - Added border color property to CardArea component to allow different colored borders for different card areas.
  - Added "Trigger Card" and "Action/Modifier Cards" labels above the respective card areas.
  - Moved trigger card area to y=150 to make space for the new label.
  - Updated TODO_prototype.md with more specific tasks and notes.
  - Added basic trigger, action, and modifier cards to the game (visual placeholders).
  - Implemented basic drag-and-drop functionality for cards between different card areas.
  
10/12/2025
  - nothing, too busy with checking work for weekend
  
10/13/2025
  - Card stacks can be moved to and from card areas and behave like normal cards.
  - Card stacks can be unstacked by dragging the root card into the "free card" field.
  - Timer trigger now pulses when placed in the trigger slot.
  - Added some basic triggers and actions and modifiers as data.
  - Only modifiers can stack on top of actions now.
  - Actions pulse when triggered.

10/14/2025
  - Added SFX for triggers & cards.
  - Added shoot bullet action.
  - Added strength bonus action.
  - Added trap action (stationary AoE damage zone).
  - Added basic enemies that spawn randomly in and move toward the player.
  - Added the "double_effect" modifier that makes actions happen twice.

10/16/2025
  - Got sidetracked with fixing ImGui integration with lua. It was a bit involved since I had to make sure that imgui could be called anywhere, even in the update loop, rather than just in the render loop.
  - changed player velocity setting to use physics.SetVelocity instead of changing transform directly. 
  - Made three clear game states and enabled switching between them. Have to figure out a way to display the cards active while in the action phase.
  
10/17/2025
  - Patched a fix for card dealing, making them not overlap.
  - Added a deal card sound.
  - Noted some bugs.
  - Refactored some code, redid the layout to allow multiple triggers.
  - Fixed a collision bug.
  - Got every trigger slot working.
  - Got camera to follow player.
  
10/18/2025
  - Tested slowing time.
  - Added animatino for death.
  - Added animation for shooting projectiles.
  
10/19/2025
  - Fixed main loop bug that caused stutter when slowing time.
  - Added lua script hot reloading system with ImGui interface.
  - Added "Reload Game from Scratch" button to lua hot reload ImGui window.
  - Need to finish reInitializeGame function to reset game state when reloading.
  
10/20/2025 
  - Added gradient rectangle drawing commands to layer system, for things like rotating highlights, loot drop indicators, etc.
  - Finished implementing reInitializeGame function to reset game state.
  - player-enemy collision detection working.
  - Added camera shake on hit, with slow & flash.
  - Added walls.
  - Debugging and tesing for collision detection with walls & enemies.
  - Got gradient rounded rect rendering working. Took way too long imo to debug this.
  
10/21/2025
  - Found a lot of potential and answers to my own design questions in Noita's wand system. I'm going to try to yoink it and adapt it to my game.
  - Prototyped a basic wand evaluation algorithm using Noita's wand system as reference.
  
10/22/2025
  - Continued prototyping wand evaluation system.
  - Added card weight property to influence evaluation order.
  - Updated card evaluation test script with weights for different card types.
  - Removed card stacking behavior for now.
  - Recursion & always cast flexibility added. Seems to be working as intended.
  
10/23/2025
  - Changed ui to facilitate wand building.
  - Chose which cards to implement for a vertical slice.
  - Tinkered with rendering a bit to clearly show debug info.
  - Need to now link up wand evaluation with gameplay.
  - Did some profiling. Removing imgui and making sure I don't give every lua object an update method that runs every frame seems to help performance a lot.
  
10/24/2025
  - Linked up stat system so enemies deal damage on bump.
  - Player can now gather orbs to level up.
  - Added HP and XP bars to UI.
  - Player can now dash.

10/25/2025
  - Integrated controller input, though there isn't any smart card selection or ui navigation yet. only movement & dashing.
  - Added board set cycling to allow for multiple triggers, and a dedicated trigger inventory.
  - Tooltips to indicate stats for hovered cards & wand.
  - Separated trigger cards to be their own thing.
  - Several more card defs so I can play around with them.
  - ran into some serious performance issues. tried moving timer and object updates to lua instead of c++. Not sure yet if it helped.
  
10/26/2025
  - Explored some performance optimizations. Also, full day of work, so not much progress.
  
10/27/2025
  - Added tracy to lua, allowing profiling of lua code.
  - Robust controller navigation system added, allowing seamless navigation of UI with controller.
- Controller navigation system exposed to lua for easy integration with lua-based UIs.
  - Lua profiling doesn't work with tracy, so I added a different one.
  - Figureing out some main loop structure issuse that might be causing performance issues.
  
10/28/2025
  - Fixed main loop structure issues causing performance problems.
  - Also, strange rubber banding with physics and dashing. I fixed it by changing only the velocity of the player during dash, not resetting it to 0 manually, and also not altering damping during it.
  
10/29/2025
  - Started putting controller navigation into use. Cards can now be selected.
  - Added visual indicators for selected cards.
  - Some debugging and polish.
  
10/30/2025
  - Added some basic music to battle scene & planning scene.
  - Some sound effects, ironing out controller navigation bugs.
  - Added a transition effect I can reuse.
  
10/31/2025
  - UI syntax sugar to make defining UIs in lua easier.
  - Added font offset and spacing support from json.
  - State management broken.
  - Updated particles to be easier to use from lua.
  
11/1/2025
  - Full day of work.
  - Got some more assets, sound and art. Maybe I'll use some of them.
  
11/2 - 11/4/2025
  - Trip, almost no work, but did organize assets (sound and graphics), worked on some bugs.
  
11/5/2025
  - Fixed UI state management bugs.
  - Fixed jerky player movement, but not sure if it's perfect yet.
  
11/6/2025
  - Stuck in... optimization hell?
  
11/7/2025
  - More optimization work.
  - Got spawn markers working again.
  - Added more sfx.
  - Tweaked some particle effects.
  - Tweaked tooltips.
  
11/8-9/2025
  - Weekend, little work, lots of translation work.
  
11/10/2025
  - Added some new sfx.
  - Added a scrolling background.
  - Tweaked some particle effects.
  - New particle effect: circle with expanding center.
  - Got started using stencils for a new particle effect, bug fixing almost done.
  - Stencil fixed, textures did not have stencil buffer.
  - Elongated ellipses that are radial and point outwards.
  
11/11/2025
  - Added direction-facing line particle effect.
  - Added circle outline vfx with dots that twirl inward. Needs some fine tuning later.
  - Added rectantle area that wipes in the direction it is going.
  - Added crecent particle effect that faces the direction it is going.
  - Added cross diamond shaped streaks for impact that thin out over time.
  - Added method that adds trail to entity over x duration.
  - circle area with dashed rotating border
  - beam attack with pulsating circles on either end
  - Added player stretch/squash when dashing.
  
11/12/2025
  - I was despairing about performance, but RelWithDebugInfo and LuaJIT just did some magic. Okay... feeling pretty good .
  - Added in SMILETRON music as a tester.
  - Added low-pass.
  - Luajit works, but right now it causes some subtle bugs in the graphics for some reason.
  
11/13/2025
  - Started working on web build automation with github actions. Cache service is down, so I'll continue later.
  - Pickups now gravitate to player when in range.

11/14/2025
  - Updated shader system to accept integer uniforms.
  - Sol integrated into files, isntead of using cmake to fetch it.
  - Working on web build automation again... brain numbing.
  
11/15/2025
  - Web build automation mostly working. Need to test more, but hitting rate limits?
  - Juice for exp and hp bars. 
  - Made enemies blink when entering the map.

11/16/2025
  - Web build works now. Automation hits some snags with usage, but on PC I can build fine. Just some wee errors and shaders to work out on web.
  - Added fullscreen/window resizing while maintaining collision accuracy
  - Started work on card eval analysis.

11/17/2025
  - Mysterious lua crash?
  - Added drop shadows instead of the usual sprite shadows. > reverted because of crash 
  - Added indiviudal layer setting to ui boxes, option to disable deceleration for steering, worked on letter boxing being broken > reverted because of crash.
  - Encountering various crashes for some reason when using texture pipeline.
  - all kinds of memory errors happening, and I have no idea why. Turning on pipeline rendering seems to be the root of it.

11/18/2025
  - Stability issues & crashing is fixed, but there are some quirks to work out that have been introduced into the rendering. (sometimes camera stops working, and entities no longer match their collision boxes (I need to know when that happens, but how?). Player still doesn't show up when using pipeline, only when 1 shader pass is added. Also player will sometimes render in completely the wrong position for some reason.)