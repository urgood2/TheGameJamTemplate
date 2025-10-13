


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