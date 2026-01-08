
#include "tutorial_system_v2.hpp"

#include "../../util/common_headers.hpp"

#include "sol/sol.hpp"

#include "../../core/globals.hpp"
#include "../../core/system_registry.hpp"
#include "../../core/gui.hpp"
#include "../../core/graphics.hpp"

#include "../ai/ai_system.hpp"
#include "../event/event_system.hpp"
#include "../fade/fade_system.hpp"

#include "../../util/utilities.hpp"

#include "../../third_party/rlImGui/imgui.h"

#include "systems/scripting/binding_recorder.hpp"

#include <string>
#include <vector>
#include <map>

//TODO: redo this system to not use imgui

namespace tutorial_system_v2 {

    // ------------------------------------------------------------------------
    // Main tutorial system methods
    // ------------------------------------------------------------------------

    bool tutorialModeActive{true};
    float tutorialModeTickSeconds{0.5f}; // tutorial updates made every 0.5 seconds TODO: read from config
    sol::coroutine currentTutorialCoroutine;
    
    std::map<std::string, bool> tutorialWindowsMap; // map of tutorial windows and their visibility status
    std::map<std::string, std::string> tutorialTextMap; // map of tutorial windows and their text
    std::map<std::string, std::vector<std::string>> tutorialChoicesMap; // map of tutorial windows and their choices (buttons)

    auto init() -> void {
        // Initialize the tutorial system here

        // do this so after ai resets, the tutorial system is also reset
        event_system::Subscribe<ai_system::LuaStateResetEvent>([](const ai_system::LuaStateResetEvent &event, event_system::MyEmitter&) {
            tutorial_system_v2::resetTutorialSystem();
        });

        resetTutorialSystem();
    }

    auto draw() -> void {
        // Draw all tutorial elements here
        // This function should be called from the main game loop

        // TODO: needs redo that doesn't use imgui

        // for (auto &[tutorialWindowName, show] : tutorialWindowsMap) {
        //     if (show == false) continue;
            
        //     // get the tweening data for the window
        //     auto tweeningData = gui::guiTweeningDataMap[tutorialWindowName].first;
        //     auto boundingRect = gui::guiTweeningDataMap[tutorialWindowName].second;

        //     // draw the window based on the data 
        //     ImGui::SetNextWindowPos({(float)tweeningData.currentX, (float)tweeningData.currentY});
        //     ImGui::SetNextWindowSize({(float)boundingRect.width, (float)boundingRect.height});
        //     ImGui::SetNextWindowBgAlpha(0.f);// set to 0 for now

            

        //     if (ImGui::Begin(tutorialWindowName.c_str(), &show, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoTitleBar)) {
                
                
        //         // draw the window contents here
        //         // if there is text, draw it
        //         if (tutorialTextMap.find(tutorialWindowName) != tutorialTextMap.end()) {
        //             // SPDLOG_DEBUG("Drawing tutorial window with text: {}", tutorialTextMap[tutorialWindowName]);

        //             // are there options available? if so, reduce child region size
        //             int childHeightSubtract = 2;
        //             if (tutorialChoicesMap.find(tutorialWindowName) != tutorialChoicesMap.end()) {
        //                 childHeightSubtract = tutorialChoicesMap[tutorialWindowName].size() + 1;
        //             }
                    
        //             // create transparent child region the size of the window
        //             ImGui::SetNextWindowBgAlpha(0.0f); // Set transparency to 50%

        //             ImGui::BeginChild("tutorial_window_child", ImVec2(0, boundingRect.height - ImGui::CalcTextSize("Test").y - ImGui::GetFrameHeight() * childHeightSubtract), ImGuiChildFlags_None);
                    
        //             util::drawColorCodedTextUnformatted(tutorialTextMap[tutorialWindowName]);
                    
        //             ImGui::EndChild();
        //         }
                
        //         // gui::drawNinePatch(ninePatchDataMap["tutorial_window"], boundingRect, tweeningData.currentAlpha);
        //         gui::drawNinePatchWindowBackground("tutorial_window", boundingRect, tweeningData.currentAlpha, 0.0f, util::getColorImVec("KONSOLE_BREEZE_FOREGROUND_WHITE"), util::getColorImVec("KONSOLE_BREEZE_DARK_SLATE_GRAY"));

            
        //         //TODO: try using global scale for gui elements, read in fron config
        //         // add a button that will set the window to false
        //         // center the button in the window  
        //         // Get the button size
                
                

        //         // apply transparency to button and text, maintaining current color
        //         // make buttons tranparent
        //         // make button darken slightly transparent on hover
        //         ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.3f, 0.3f, 0.3f, 0.1f));
        //         ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4(0.f, 0.f, 0.f, 0.f));
        //         ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.f, 0.f, 0.f, 0.f));

        //         int buttonWidth = ImGui::GetWindowWidth() * 0.8f;;
        //         int buttonHeight = ImGui::GetTextLineHeightWithSpacing();

        //         auto &ninePatchData = ninePatchDataMap["button_border"];

        //         // SPDLOG_DEBUG("Option count: {}", tutorialChoicesMap[tutorialWindowName].size());
        //         // check if options are available
        //         if (tutorialChoicesMap.find(tutorialWindowName) != tutorialChoicesMap.end() && tutorialChoicesMap[tutorialWindowName].size() > 0) {
        //             // draw buttons for each option
                    
        //             // depending on the number of options, adjust the y cursor position so the buttons align bottom
        //             ImGui::SetCursorPosY(boundingRect.height - (buttonHeight + ImGui::GetStyle().ItemSpacing.y * 2 + ninePatchData.top + ninePatchData.bottom) * tutorialChoicesMap[tutorialWindowName].size());
                    
        //             for (auto &option : tutorialChoicesMap[tutorialWindowName]) {
        //                 // center each button
        //                 ImGui::SetCursorPosX(boundingRect.width / 2 - buttonWidth / 2);

        //                 Rectangle buttonRect = {ImGui::GetWindowPos().x + ImGui::GetCursorPosX(), ImGui::GetWindowPos().y + ImGui::GetCursorPosY(), (float)buttonWidth, (float)buttonHeight};

        //                 ImDrawList *drawList = ImGui::GetWindowDrawList();
        //                 // drawList->AddCallback(gui::customShaderDrawCallbackStart, nullptr);

        //                 gui::drawNinePatchButton("close_button", buttonRect, "button_border", option.c_str(), tweeningData.currentAlpha, "KONSOLE_BREEZE_FOREGROUND_WHITE", "KONSOLE_BREEZE_DARK_SLATE_GRAY", [&show, option]() {
        //                     show = false;
        //                     // fire off a lua event that says "tutorial_window_option_selected"
        //                     sol::table newTable = ai_system::masterStateLua.create_table();
        //                     newTable[1] = option; // lua tables are 1-indexed
        //                     event_system::publishLuaEvent("tutorial_window_option_selected", newTable);
        //                 });

        //                 // drawList->AddCallback(gui::customShaderDrawCallbackEnd, nullptr);

        //                 // Adjust cursor position, but only by a small value for padding
        //                 ImGui::SetCursorPosY(ImGui::GetCursorPosY() + ImGui::GetStyle().ItemSpacing.y + ninePatchData.top + ninePatchData.bottom);
                        
        //             }
        //         }
        //         else {
        //             // center  button
        //             ImGui::SetCursorPosX(boundingRect.width / 2 - buttonWidth / 2);
        //             ImGui::SetCursorPosY(boundingRect.height - (buttonHeight + ImGui::GetStyle().ItemSpacing.y * 2 + ninePatchData.top + ninePatchData.bottom) * 1); // only one button from bottom

        //             // SPDLOG_DEBUG("Drawing close button at cursor x: {}, y: {}", ImGui::GetCursorPosX(), ImGui::GetCursorPosY());

        //             Rectangle buttonRect = {ImGui::GetWindowPos().x + ImGui::GetCursorPosX(), ImGui::GetWindowPos().y + ImGui::GetCursorPosY(), (float)buttonWidth, (float)buttonHeight};
                    
        //             ImDrawList *drawList = ImGui::GetWindowDrawList();
        //             // drawList->AddCallback(gui::customShaderDrawCallbackStart, nullptr);

        //             gui::drawNinePatchButton("close_button", buttonRect, "button_border", "Close", tweeningData.currentAlpha, "KONSOLE_BREEZE_FOREGROUND_WHITE", "KONSOLE_BREEZE_DARK_SLATE_GRAY", [&show]() {
        //                 show = false;
        //                 // fire off a lua event that says "tutorial_window_closed"
        //                 event_system::publishLuaEvent("tutorial_window_closed", sol::lua_nil);
        //             });

        //             // drawList->AddCallback(gui::customShaderDrawCallbackEnd, nullptr);
        //         }

        //         ImGui::PopStyleColor(3); // reset button and text transparency
        //         // ImGui::PopStyleVar(); // reset frame padding for button
                
        //         // prevent input from going through the window
                
        //         ImGui::End();
        //     }
        // }
    }

    


    // just resets the current coroutine for now
    auto resetTutorialSystem() -> void {
        currentTutorialCoroutine = sol::lua_nil;


        // FIXME: testing, remove later
        currentTutorialCoroutine = ai_system::masterStateLua["tutorials"]["sample"];
        setTutorialModeActive(true);
    }

    /** 
     * Note that the ai_system's lua state must be initialized before this function is called.
     * This method just enables whatever tutorial coroutine is currently set.
     * The tutorial coroutines should ideally be set in lua, via events or other triggers.
     */
    auto update(const float dt) -> void {
        if (tutorialModeActive == false) return;

        // check validity of the current tutorial coroutine
        if (!currentTutorialCoroutine.valid()) {
            // SPDLOG_ERROR("Current tutorial coroutine is not valid");
            return;
        }

        auto result = currentTutorialCoroutine(dt);
        if (result.status() == sol::call_status::ok) {
            // coroutine completed successfully
            SPDLOG_DEBUG("Tutorial coroutine completed successfully");
            // turn off tutorial mode
            setTutorialModeActive(false);
        } else if (result.status() == sol::call_status::yielded) {
            // coroutine yielded
            // SPDLOG_DEBUG("Tutorial coroutine yielded");
        } else {
            // Coroutine errored
            sol::error err = result;  // Extract the error from the result
            SPDLOG_ERROR("Tutorial coroutine errored: {}", err.what());  // Log the error message
            setTutorialModeActive(false);  // Turn off tutorial mode

            // Reset the current tutorial coroutine
            currentTutorialCoroutine = sol::lua_nil;

        }
    }

    // this will be called from the main game loop. 
    // It will activate the tutorial mode, which will mean selected tutorial coroutines will be run every frame until completed.
    // If there is not any tutorial coroutine selected, nothing will happen.
    auto setTutorialModeActive(bool active) -> void {
        tutorialModeActive = active;
        SPDLOG_DEBUG("Tutorial mode is now {}", active ? "active" : "inactive");
    }

    //TODO: need a feature to show available tutorials in console

    // TODO: add delayed timed event functionality to event system + test


    /**
     * This must be called to expose the tutorial system to Lua.
     */
    auto exposeToLua(sol::state &lua) -> void {
        
        auto& rec = BindingRecorder::instance();

        auto tutorialPath = std::vector<std::string>{}; // global-level bindings

        rec.bind_function(
            lua,
            tutorialPath,
            "setTutorialModeActive",
            &setTutorialModeActive,
            "---@param active boolean # Whether to activate tutorial mode\n---@return nil",
            "Enables or disables tutorial mode."
        );

        rec.bind_function(
            lua,
            tutorialPath,
            "resetTutorialSystem",
            &resetTutorialSystem,
            "---@return nil",
            "Resets the tutorial system to its initial state."
        );

        rec.bind_function(
            lua,
            tutorialPath,
            "showTutorialWindow",
            [](const std::string& tutorialText) {
                setShowTutorialWindow("Tutorial window", tutorialText, true);
            },
            "---@param text string # Tutorial content text to display.\n"
            "---@return nil",
            "Displays a tutorial window with the provided text."
        );

        rec.bind_function(
            lua,
            tutorialPath,
            "showTutorialWindowWithOptions",
            [](const std::string& tutorialText, sol::table options) {
                std::vector<std::string> optionsVector;
                for (auto& option : options) {
                    optionsVector.push_back(option.second.as<std::string>());
                    SPDLOG_DEBUG("Option: {}", option.second.as<std::string>());
                }
                setShowTutorialWindowWithOptions("Tutorial window", tutorialText, optionsVector, true);
            },
            "---@param text string # Tutorial content to display.\n"
            "---@param options string[] # An array-style table of button labels.\n"
            "---@return nil",
            "Displays a tutorial window with selectable options."
        );

        rec.bind_function(
            lua,
            tutorialPath,
            "startTutorial",
            [](const std::string& tutorialName) {
                if (ai_system::masterStateLua["tutorials"][tutorialName] == sol::lua_nil) {
                    SPDLOG_ERROR("Tutorial name {} is not valid", tutorialName);
                    return;
                }
                currentTutorialCoroutine = ai_system::masterStateLua["tutorials"][tutorialName];
                setTutorialModeActive(true);
            },
            "---@param tutorialName string # The name of the tutorial coroutine to start.\n"
            "---@return nil",
            "Begins the specified tutorial coroutine if it is defined."
        );

        rec.bind_function(
            lua,
            tutorialPath,
            "lockControls",
            &lockControls,
            "---@return nil",
            "Locks player input controls."
        );

        rec.bind_function(
            lua,
            tutorialPath,
            "unlockControls",
            &unlockControls,
            "---@return nil",
            "Unlocks player input controls."
        );

        rec.bind_function(
            lua,
            tutorialPath,
            "addGameAnnouncement",
            &addGameAnnouncement,
            "---@param message string # The announcement message.\n"
            "---@return nil",
            "Adds a new game announcement to the log."
        );

        rec.bind_function(
            lua,
            tutorialPath,
            "registerTutorialToEvent",
            &registerTutorialToEvent,
            "---@param eventType string # The event to listen for.\n"
            "---@param tutorialName string # The name of the tutorial to trigger.\n"
            "---@return nil",
            "Registers a tutorial to activate on a specific game event."
        );

        rec.bind_function(
            lua,
            tutorialPath,
            "moveCameraTo",
            &moveCameraTo,
            "---@param x number # The target X position.\n"
            "---@param y number # The target Y position.\n"
            "---@return nil",
            "Moves the camera instantly to the specified position."
        );

        rec.bind_function(
            lua,
            tutorialPath,
            "moveCameraToEntity",
            static_cast<void(*)(entt::entity)>(&moveCameraToEntity),
            "---@param entity Entity # The entity to focus the camera on.\n"
            "---@return nil",
            "Moves the camera to center on the given entity."
        );

        rec.bind_function(
            lua,
            tutorialPath,
            "fadeOutScreen",
            &fadeOutScreen,
            "---@param duration number # The duration of the fade in seconds.\n"
            "---@return nil",
            "Fades the screen to black over a specified duration."
        );

        rec.bind_function(
            lua,
            tutorialPath,
            "fadeInScreen",
            &fadeInScreen,
            "---@param duration number # The duration of the fade in seconds.\n"
            "---@return nil",
            "Fades the screen in from black over a specified duration."
        );

        // Base function signature for displayIndicatorAroundEntity
        rec.bind_function(
            lua,
            tutorialPath,
            "displayIndicatorAroundEntity",
            static_cast<void(*)(entt::entity)>(&displayIndicatorAroundEntity),
            "---@param entity Entity # The entity to display the indicator around.\n"
            "---@return nil",
            "Displays a visual indicator around the entity.",
            /*is_overload=*/false // This is the base function
        );

        // Overloaded version with indicatorTypeID
        rec.bind_function(
            lua,
            tutorialPath,
            "displayIndicatorAroundEntity",
            static_cast<void(*)(entt::entity, std::string)>(&displayIndicatorAroundEntity),
            "---@overload fun(entity: Entity, indicatorTypeID: string):nil",
            "Displays a visual indicator of a specific type around the entity.",
            /*is_overload=*/true // This is the overload
        );

        // Run tutorials.register() if it exists
        if (lua["tutorials"]["register"] != sol::lua_nil) {
            lua.script("tutorials.register()");
        }
    }


    // ------------------------------------------------------------------------
    // Tutorial System methods that can be called from Lua
    // ------------------------------------------------------------------------

    /**
     * Takes the name of a coroutine function in the tutorial lua state and links it to an event in the event system.
     * 
     */
    auto registerTutorialToEvent(const std::string &tutorialName, const std::string &eventName) -> void{

        // tutorial.(tutorialName) is the location of the tutorial coroutine in the lua state

        // check that the name is valid
        if (ai_system::masterStateLua["tutorials"][tutorialName] == sol::lua_nil) {
            SPDLOG_ERROR("Tutorial name {} is not valid", tutorialName);
            return;
        }

        event_system::subscribeToLuaEvent(eventName, [tutorialName](sol::table data) {
            currentTutorialCoroutine = ai_system::masterStateLua["tutorials"][tutorialName];
            setTutorialModeActive(true);
        });
    }
    
    auto addGameAnnouncement(const std::string &announcementText) -> void {
        // gui::announcements.push_back(announcementText);
    }
    


    //LATER: customize with no button, close button, and multiple buttons

    auto setShowTutorialWindow(const std::string &tutorialWindowName, const std::string &tutorialText, const bool show) -> void {
        setShowTutorialWindowWithOptions(tutorialWindowName, tutorialText, {}, show);
    }

    auto setShowTutorialWindowWithOptions(const std::string &tutorialWindowName, const std::string &tutorialText, const std::vector<std::string> &options, const bool show) -> void {
        // // use gui::createTweeningData() on the first frame
        // tutorialWindowsMap[tutorialWindowName] = show;
        // tutorialTextMap[tutorialWindowName] = tutorialText;
        // tutorialChoicesMap[tutorialWindowName] = options;

        // // reinitialize tweening data for the window
        // // TODO: these values should come from a script or json.
        // float windowWidth = globals::VIRTUAL_WIDTH * 0.7;
        // float windowHeight = globals::VIRTUAL_HEIGHT * 0.5;
        // float windowX = globals::VIRTUAL_WIDTH / 2 - windowWidth / 2;
        // float windowY = globals::VIRTUAL_HEIGHT / 2 - windowHeight / 2; // center window
        // float windowStartY = windowY + 200; // slide from bottom
        // float windowAlphaStart = 0.0f; // start invisible
        // float tweenDuration = 1.0f; // 1 second tweening duration
        // gui::guiTweeningDataMap[tutorialWindowName] = gui::createTweeningData(windowX, windowStartY, windowX, windowY, windowWidth, windowHeight, windowAlphaStart, 1.0f, tweenDuration);

        // now this tweening data will be updated automatically in the gui system
        //TODO: add ninepatch for buttons
        //TODO: how to configure keyboard navigation for buttons?
        //TODO: show fixed-width buttons in a row, with text centered
    }
    

    //TODO: get async loading working

    //TODO: dithering needs to be configured via config file

    //TODO: need to redo main menu

    //TODO: figure out how to layer sprites on the same square for pretty effects, try which ones look good


    //TODO: later highlight multiple objects of specific types, like enemies, items, etc.
    //Highlights a specific object on the screen, guiding the player’s attention.
    auto highlightObject(const std::string &objectName) {
        // only highlight one thing at a time (keep variable for highlighted object)
        // drawing should be done in the draw method

        // TODO: make a rectangle out of tiles that show an indicator.
        // left side arrow : 62
        // right side arrow: 60
        // top side: 25
        // bottom: 24

        // use VFXComponent, with optional callback to delete itself? Maybe listen to a key event? like any_key

        // maybe make a ninepatch component that can be removed after a set time

        // TODO: make a temporary vfx object for each of these arrows, place them on the map around the object in question
        // REVIEW: how to access entity ids from lua? keep entity alias list accessible from lua
    }

    auto displayIndicatorAroundEntity(entt::registry& registry, entt::entity entity, std::string indicatorTypeID) -> void {
        if (globals::ninePatchDataMap.find(indicatorTypeID) == globals::ninePatchDataMap.end()) {
            SPDLOG_ERROR("Indicator type ID {} is not valid", indicatorTypeID);
            return;
        }

        if (registry.any_of<LocationComponent>(entity) == false) {
            SPDLOG_ERROR("Entity {} does not have a location component. Cannot display arrow.", static_cast<int>(entity));
            return;
        }

        if (registry.any_of<AnimationQueueComponent>(entity) == false) {
            SPDLOG_ERROR("Entity {} does not have an animation queue component. Cannot display arrow.", static_cast<int>(entity));
            return;
        }

        auto &loc = registry.get<LocationComponent>(entity);
        auto &animComp = registry.get<AnimationQueueComponent>(entity);

        float renderX = loc.x * 32;
        float renderY = loc.y * 32;

        float spriteW = animComp.defaultAnimation.animationList.at(0).first.spriteData.frame.width;
        float spriteH = animComp.defaultAnimation.animationList.at(0).first.spriteData.frame.height;

        auto &ninePatchData = globals::ninePatchDataMap[indicatorTypeID];

        NPatchInfo nPatchInfo = {
            .source = ninePatchData.source,
            .left = ninePatchData.left,
            .top = ninePatchData.top,
            .right = ninePatchData.right,
            .bottom = ninePatchData.bottom,
            .layout = NPatchLayout::NPATCH_NINE_PATCH
        };

        Rectangle destRect = {
            .x = renderX - ninePatchData.left,
            .y = renderY - ninePatchData.top,
            .width = spriteW + ninePatchData.left + ninePatchData.right,
            .height = spriteH + ninePatchData.top + ninePatchData.bottom
        };

        auto &nPatchComp = registry.emplace_or_replace<NinePatchComponent>(entity);
        nPatchComp.nPatchInfo = nPatchInfo;
        nPatchComp.destRect = destRect;
        nPatchComp.texture = ninePatchData.texture;
        nPatchComp.timeToLive = 10.0f;
    }

    auto displayIndicatorAroundEntity(entt::entity entity, std::string indicatorTypeID) -> void {
        displayIndicatorAroundEntity(globals::getRegistry(), entity, indicatorTypeID);
    }

    auto displayIndicatorAroundEntity(entt::registry& registry, entt::entity entity) -> void {
        displayIndicatorAroundEntity(registry, entity, "ui_indicator");
    }

    auto displayIndicatorAroundEntity(entt::entity entity) -> void {
        displayIndicatorAroundEntity(globals::getRegistry(), entity, "ui_indicator");
    }


    // locks out player movement and inputs?
    auto lockControls() -> void{
        // input_processing::isInGameInputLocked = true;
        // SPDLOG_DEBUG("In-game controls locked");
    }

    auto unlockControls() -> void{
        // input_processing::isInGameInputLocked = false;
        // SPDLOG_DEBUG("In-game controls unlocked");
    }

    auto showTutorialBoxWithGIF(const std::string &tutorialBoxName, const std::string &gifPath) {
        // TODO: implement later, non-essential
    }

    // pans camera to a specific location
    auto moveCameraTo(float x, float y) -> void {
        graphics::setNextCameraTarget({x, y});
    }

    auto moveCameraToEntity(entt::registry& registry, entt::entity entity) -> void {
        if (registry.any_of<LocationComponent>(entity) == false) {
            SPDLOG_ERROR("Entity {} does not have a location component. Cannot move camera to entity.", static_cast<int>(entity));
            return;
        }
        graphics::centerCameraOnEntity(registry, entity);
    }

    auto moveCameraToEntity(entt::entity entity) -> void {
        moveCameraToEntity(globals::getRegistry(), entity);
    }
    
    //TODO: import wait functions from lua as well
    // wait(seconds)

    // fades the screen to black in a certain amount of time
    auto fadeOutScreen(float seconds) -> void {
        fade_system::setFade(fade_system::FadeState::FADE_OUT, seconds);
    }

    auto fadeInScreen(float seconds) -> void{
        fade_system::setFade(fade_system::FadeState::FADE_IN, seconds);
    }

    // draw a GUI indicator on the screen around the bounding rectangle (window or button) using nine patch
    // Also show some text on the indicator, assuming it is not empty
    auto drawGUIIndicator(const Rectangle boundingRectangle, const std::string &text) {
        //TODO: implement this
        //TODO: use imgui foreground draw list
    }
}

REGISTER_SYSTEM(tutorial_system, 600,
    [](float dt) { tutorial_system_v2::update(dt); },
    []() { tutorial_system_v2::init(); },
    [](float dt) { tutorial_system_v2::draw(); }
)
