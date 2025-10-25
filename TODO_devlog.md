


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
  - 