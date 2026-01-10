-- All new tutorials should be registered to specific hooks
-- or events in the game so that they will be called at the right time.
-- Events should be configured in the game code, but more events can be created in the lua code as well.
-- Basic hooks (such as startGameTutorial for the basic tutorial, for example), should ideally be defined in game code.

tutorials = tutorials or {}


local sample_tutorial_enabled = os.getenv and os.getenv("ENABLE_SAMPLE_TUTORIAL") == "1"

-- This method will be called upon tutorial system initialization
function tutorials.register()
    -- Register the sample tutorial to the "startTutorial" event
    if sample_tutorial_enabled then
        print("[Tutorial] Sample tutorial enabled via ENABLE_SAMPLE_TUTORIAL=1")
        registerTutorialToEvent("sample", "startTutorial")
    else
        print("[Tutorial] Sample tutorial disabled (set ENABLE_SAMPLE_TUTORIAL=1 to enable)")
    end
    registerTutorialToEvent("start_main_menu", "main_menu_entered")
    registerTutorialToEvent("start_main_game", "main_game_entered")
end
