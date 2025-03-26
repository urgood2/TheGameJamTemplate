-- All scripts are read in automatically from this directory. They will not be triggered
-- unless they are registered first from the registration script.


tutorials = tutorials or {}

function tutorials.sample(deltaTime)
    addGameAnnouncement("[color:KONSOLE_BREEZE_NEON_GREEN]Welcome to the tutorial![/color]") -- TODO: should be showwindow method instead
    addGameAnnouncement("Wait for 3 seconds...")
    
    wait(3) -- Wait for 3 seconds
    
    addGameAnnouncement("Now press the [color:KONSOLE_BREEZE_WARM_BROWN_ORANGE]'A'[/color] key.")
    waitForKeyPress("KEY_A") -- Wait for the 'A' key press
    debug("'A' key pressed!")

    
    -- show a color coded message in a window and wait for a tutorial window closed event
    -- If the window contained multiple buttons, there will be a table payload to indicate which button was pressed

    -- |||||||||||| tutorial window w/o options ||||||||||||
    showTutorialWindow("You have [color:KONSOLE_BREEZE_TEAL_GREEN]completed[/color] the tutorial!")
    -- ||||||||||||||||||||||||||||||||||||||||||||||||||||

    -- |||||||||||| tutorial window with options ||||||||||||
    -- options = {"OK", "Cancel"}
    -- showTutorialWindowWithOptions("You have [color:KONSOLE_BREEZE_TEAL_GREEN]completed[/color] the tutorial!", options)
    -- ||||||||||||||||||||||||||||||||||||||||||||||||||||||
    
    pauseGame() -- Pause the game before locking the controls
    lockControls() -- Lock the controls except gui

    -- |||||||||||| for tutorial window w/o options ||||||||||||
    waitForEvent("tutorial_window_closed") -- Wait for a specific in-game event
    -- |||||||||||||||||||||||||||||||||||||||||||||||||||||||||

    -- |||||||||||| for tutorial window with options ||||||||||||
    -- payload = waitForEvent("tutorial_window_option_selected") 
    -- if payload then
    --     -- Print all keys and values in the table to see what the structure is
    --     print("Payload received!")
    --     for k, v in pairs(payload) do
    --         print("\tKey:", k, "Value:", v)
    --     end
    --     -- print the first value of the array
    --     addGameAnnouncement("You chose "..payload[1])
    -- else
    --     print("No payload received!")
    -- end
    -- ||||||||||||||||||||||||||||||||||||||||||||||||||||||

    unlockControls() -- Unlock the controls
    unpauseGame() -- Unpause the game

    addGameAnnouncement("Screen fade test.")
    fadeOutScreen(10) -- Fade out the screen in 1 second
    wait(10) 
    fadeInScreen(1) -- Fade in the screen in 1 second
    
    addGameAnnouncement("[color:KONSOLE_BREEZE_NEON_GREEN]Tutorial completed![/color]")
    
end