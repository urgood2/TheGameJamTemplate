-- All new tutorials should be registered to specific hooks
-- or events in the game so that they will be called at the right time.
-- Events should be configured in the game code, but more events can be created in the lua code as well.
-- Basic hooks (such as startGameTutorial for the basic tutorial, for example), should ideally be defined in game code.

tutorials = tutorials or {}


-- This method will be called upon tutorial system initialization
function tutorials.register()
    -- Register the sample tutorial to the "startTutorial" event
    registerTutorialToEvent("sample", "startTutorial")
    registerTutorialToEvent("start_main_menu", "main_menu_entered")
    registerTutorialToEvent("start_main_game", "main_game_entered")
end