#include "scripting_functions.hpp"

#include "../../util/common_headers.hpp"

#include "sol/sol.hpp"
#include "../ai/ai_system.hpp"
#include "../event/event_system.hpp"
#include "../tutorial/tutorial_system_v2.hpp"
#include "../sound/sound_system.hpp" 

#include "../../core/game.hpp"

/*
    TODO: Register my ui & transform components & event queue system bindings in lua
    e.g.,

    void register_transform(sol::state &lua) {
        lua.new_usertype<Transform>("Transform",
            "type_id", &entt::type_hash<Transform>::value,

            sol::call_constructor,
            sol::factories([](int x, int y) {
            return Transform{ x, y };
            }),
            "x", &Transform::x,
            "y", &Transform::y,

            sol::meta_function::to_string, &Transform::to_string
        );
    }
    

    TODO: Set up registry bond


    register_meta_component<Transform>();

    sol::state lua{};
    lua.open_libraries(sol::lib::base, sol::lib::package, sol::lib::string);
    lua.require("registry", sol::c_call<AUTO_ARG(&open_registry)>, false);
    register_transform(lua); // Make Transform struct available to Lua

    entt::registry registry{};
    lua["registry"] = std::ref(registry); // Make the registry available to Lua

    lua.do_file("lua/registry_simple.lua");

    const auto bowser = lua["bowser"].get<entt::entity>();
    const auto *xf = registry.try_get<Transform>(bowser);
    assert(xf != nullptr);
    const Transform &transform = lua["transform"];
    assert(xf->x == transform.x && xf->y == transform.y);

    lua.do_file("lua/iterate_entities.lua");
    assert(registry.orphan(bowser) && "The only component (Transform) should  "
                                      "be removed by the script");
    
    TODO: script hookups should be done as follows:

    auto behavior_script = lua.load_file("lua/behavior_script.lua");
    ...
    registry.emplace<ScriptComponent>(e, behavior_script.call());


*/


// * Steps to follow if you wish to add a lua binding for a new method:
// * 1. Add the method declaration to this file
// * 2. Add the method definition to the cpp file
// * 3. Add the method binding in the initLuaStateWithAllObjectAndFunctionBindings method in this file
// * 4. Make sure the above method is called to initialize the lua state you plan to use
// * 5. Profit

namespace scripting {

    /**
     * ------------------------------------------------------
     * Master lua state initialization function - the master state contains all the bindings for running the ai system from the lua side
     * ------------------------------------------------------
     */
    auto initLuaMasterState(sol::state& stateToInit, const std::vector<std::string> scriptFilesToRead) -> void {
        
        // basic lua state initialization
        stateToInit.open_libraries(sol::lib::base, sol::lib::package, sol::lib::table, sol::lib::coroutine, sol::lib::os, sol::lib::string);
        
        // read all the script files and load them into the lua state
        for (auto &filename : scriptFilesToRead) {
            stateToInit.script_file(filename);
            
            auto code_valid_result = stateToInit.script_file(filename, [](lua_State*, sol::protected_function_result pfr) {
                // pfr will contain things that went wrong, for either loading or executing the script
                // Can throw your own custom error
                // You can also just return it, and let the call-site handle the error if necessary.
                return pfr;
            });
            SPDLOG_DEBUG("Loading file {}...", filename);
            if (code_valid_result.valid() == false) {
                SPDLOG_ERROR("Lua loading failed. Check script file for errors.");
                SPDLOG_ERROR("Error: {}", code_valid_result.get<sol::error>().what());
            } else
            {
                SPDLOG_DEBUG("Lua script file loading success.");
            }
        }
        
        //---------------------------------------------------------
        // initialize lua state with custom object bindings
        //---------------------------------------------------------

        stateToInit.new_enum("ActionResult",
            "SUCCESS", Action::Result::SUCCESS,
            "FAILURE", Action::Result::FAILURE,
            "RUNNING", Action::Result::RUNNING
        );
        
        stateToInit.new_usertype<entt::entity>("Entity");

        //---------------------------------------------------------
        // methods from event_system.cpp. These can be called from lua
        //---------------------------------------------------------
        event_system::exposeEventSystemToLua(stateToInit);

        // ------------------------------------------------------
        // methods from tutorial_system_v2.cpp. These can be called from lua
        // ------------------------------------------------------
        tutorial_system_v2::exposeToLua(stateToInit);

        //---------------------------------------------------------
        // methods from ai_system.cpp. These can be called from lua
        //---------------------------------------------------------
        stateToInit.set_function("hardReset", []() {
            ai_system::requestAISystemReset();
        });

        //---------------------------------------------------------
        // methods from sound_system.cpp. These can be called from lua
        //---------------------------------------------------------
        sound_system::ExposeToLua(stateToInit);

        // ------------------------------------------------------
        // methods for entity registry access
        // ------------------------------------------------------
        stateToInit.set_function("getEntityByAlias", getEntityByAlias);
        stateToInit.set_function("setEntityAlias", setEntityAlias);
        
        //---------------------------------------------------------
        // methods from scripting_functions.cpp. These can be called from lua
        //---------------------------------------------------------
        stateToInit.set_function("debug", sol::overload(
            static_cast<void(*)(entt::entity, std::string)>(&luaDebugLogWrapper),
            static_cast<void(*)(std::string)>(&luaDebugLogWrapperNoEntity)
        ));
        stateToInit.set_function("error", sol::overload(
            static_cast<void(*)(entt::entity, std::string)>(&luaErrorLogWrapper),
            static_cast<void(*)(std::string)>(&luaErrorLogWrapperNoEntity)
        ));
        // stateToInit.set_function("debug", luaDebugLogWrapper);
        // stateToInit.set_function("error", luaErrorLogWrapper);

        stateToInit.set_function("setCurrentWorldStateValue", setCurrentWorldStateValue);
        stateToInit.set_function("getCurrentWorldStateValue", getCurrentWorldStateValue);
        stateToInit.set_function("clearCurrentWorldState", clearCurrentWorldState);
        stateToInit.set_function("setGoalWorldStateValue", setGoalWorldStateValue);
        stateToInit.set_function("getGoalWorldStateValue", getGoalWorldStateValue);
        stateToInit.set_function("clearGoalWorldState", clearGoalWorldState);

        stateToInit.set_function("setBlackboardFloat", setBlackboardFloat);
        stateToInit.set_function("getBlackboardFloat", getBlackboardFloat);
        stateToInit.set_function("setBlackboardBool", setBlackboardBool);
        stateToInit.set_function("getBlackboardBool", getBlackboardBool);
        stateToInit.set_function("setBlackboardInt", setBlackboardInt);
        stateToInit.set_function("getBlackboardInt", getBlackboardInt);
        stateToInit.set_function("setBlackboardString", setBlackboardString);
        stateToInit.set_function("getBlackboardString", getBlackboardString);

        stateToInit.set_function("isKeyPressed", isKeyPressed);

        stateToInit.set_function("pauseGame", pauseGame);
        stateToInit.set_function("unpauseGame", unpauseGame);
        
    }



    /**
     * ------------------------------------------------------
     * Convenience functions for logging from lua
     * ------------------------------------------------------
     */

    auto luaDebugLogWrapper(entt::entity entity, std::string message) -> void {
        spdlog::default_logger()->debug("[LUA] {}: {}", static_cast<int>(entity), message);
    }

    auto luaErrorLogWrapper(entt::entity entity, std::string message) -> void {
        spdlog::default_logger()->error("[LUA] {}: {}", static_cast<int>(entity), message);
    }

    auto luaDebugLogWrapperNoEntity(std::string message) -> void {
        spdlog::default_logger()->debug("[LUA]: {}", message);
    }

    auto luaErrorLogWrapperNoEntity(std::string message) -> void {
        spdlog::default_logger()->error("[LUA]: {}", message);
    }

    /**
     * ------------------------------------------------------
     * Access functions for entt registry
     * ------------------------------------------------------
     */

    // C++ side: Map aliases to entities
    std::unordered_map<std::string, entt::entity> entity_aliases;

    // Used to communicate entity handles with lua
    auto getEntityByAlias(const std::string& name) -> entt::entity {
        // if it exists, return the entity
        if (entity_aliases.find(name) != entity_aliases.end()) {
            return entity_aliases[name];
        }
        // otherwise, return null
        return entt::null;
    }

    // Used to communicate entity handles with lua
    auto setEntityAlias(const std::string& name, entt::entity entity) -> void {
        // check that entity is valid first
        if (entity == entt::null) {
            SPDLOG_ERROR("Cannot set alias for null entity");
            return;
        }
        if (globals::registry.valid(entity) == false) {
            SPDLOG_ERROR("Cannot set alias for invalid entity");
            return;
        }
        entity_aliases[name] = entity;
    }

    /**
     * ------------------------------------------------------
     * Methods for access to game state (pause, etc)
     * ------------------------------------------------------
     */
    auto pauseGame() -> void {
        game::isPaused = true;
        SPDLOG_INFO("Game paused.");
    }

    auto unpauseGame() -> void {
        game::isPaused = false;
        SPDLOG_INFO("Game unpaused.");
    }

    //TODO: add component-level access for the most commonly used components, probably on a need-to-use basis

    /**
     * ------------------------------------------------------
     * Access functions for keypress & event system events
     * ------------------------------------------------------
     */

    bool isKeyPressed(const std::string& key) {
        // Convert string key to enum value
        auto keyEnumOpt = magic_enum::enum_cast<KeyboardKey>(key, magic_enum::case_insensitive); // ignore case
        if (!keyEnumOpt.has_value()) {
            SPDLOG_ERROR("Key {} not found in enum", key); // Log an error if the key is not found
            return false;
        }

        // Check if the key is pressed using IsKeyPressed (assuming it accepts KeyboardKey)
        return IsKeyPressed(keyEnumOpt.value());
    }

    /**
     * ------------------------------------------------------
     * Convenience functions for GOAP world state access
     * ------------------------------------------------------
     */

    auto setCurrentWorldStateValue(entt::entity entity, std::string key, bool value) -> void {
        auto &goapComponent = globals::registry.get<GOAPComponent>(entity);
        goap_worldstate_set(&goapComponent.ap, &goapComponent.current_state, key.c_str(), value);
        SPDLOG_DEBUG("{}: Setting current world state \"{}\" to {}", static_cast<int>(entity), key, value);
    }

    auto getCurrentWorldStateValue(entt::entity entity, std::string key) -> bool {
        auto &goapComponent = globals::registry.get<GOAPComponent>(entity);
        bool value = false;
        bool successful = ai_system::goap_worldstate_get(&goapComponent.ap, goapComponent.current_state, key.c_str(), &value);
        if (!successful) {
            SPDLOG_ERROR("{}: Could not get current world state \"{}\": does not exist. Defaulting to false", static_cast<int>(entity), key);
        }
        return value;
    }

    auto clearCurrentWorldState(entt::entity entity) -> void {
        auto &goapComponent = globals::registry.get<GOAPComponent>(entity);
        goap_worldstate_clear( &goapComponent.current_state);
        SPDLOG_DEBUG("{}: Cleared current world state", static_cast<int>(entity));
    }


    /**
     * ------------------------------------------------------
     * Convenience functions for GOAP "goal" world state access
     * (as opposed to the current world state)
     * ------------------------------------------------------
     */

    auto setGoalWorldStateValue(entt::entity entity, std::string key, bool value) -> void {
        auto &goapComponent = globals::registry.get<GOAPComponent>(entity);
        goap_worldstate_set(&goapComponent.ap, &goapComponent.goal, key.c_str(), value);
        SPDLOG_DEBUG("{}: Setting goal world state \"{}\" to {}", static_cast<int>(entity), key, value);
    }

    auto getGoalWorldStateValue(entt::entity entity, std::string key) -> bool {
        auto &goapComponent = globals::registry.get<GOAPComponent>(entity);
        bool value = false;
        bool successful = ai_system::goap_worldstate_get(&goapComponent.ap, goapComponent.current_state, key.c_str(), &value);
        if (!successful) {
            SPDLOG_ERROR("{}: Could not get goal world state \"{}\": does not exist. Defaulting to false", static_cast<int>(entity), key);
        }
        return value;
    }

    auto clearGoalWorldState(entt::entity entity) -> void {
        auto &goapComponent = globals::registry.get<GOAPComponent>(entity);
        goap_worldstate_clear(&goapComponent.goal);
        SPDLOG_DEBUG("{}: Cleared goal world state", static_cast<int>(entity));
    }

    /**
     * ------------------------------------------------------
     * Convenience functions for dealing with std::any blackboard
     * ------------------------------------------------------
     */

    auto setBlackboardFloat(entt::entity entity, std::string key, float valueToSet) -> void {
        auto& blackboard = globals::registry.get<GOAPComponent>(entity).blackboard;
        blackboard.set(key, valueToSet);
        SPDLOG_DEBUG("{}: Setting blackboard float \"{}\" to {}", static_cast<int>(entity), key, valueToSet);
    }

    auto getBlackboardFloat(entt::entity entity, std::string key) -> float {
        auto& blackboard = globals::registry.get<GOAPComponent>(entity).blackboard;
        auto value = blackboard.get<float>(key);
        SPDLOG_DEBUG("{}: Getting blackboard float \"{}\": {}", static_cast<int>(entity), key, value);
        return value;
    }

    auto setBlackboardBool(entt::entity entity, std::string key, bool valueToSet) -> void {
        auto& blackboard = globals::registry.get<GOAPComponent>(entity).blackboard;
        blackboard.set(key, valueToSet);
        SPDLOG_DEBUG("{}: Setting blackboard bool \"{}\" to {}", static_cast<int>(entity), key, valueToSet);
    }

    auto getBlackboardBool(entt::entity entity, std::string key) -> bool {
        auto& blackboard = globals::registry.get<GOAPComponent>(entity).blackboard;
        auto value = blackboard.get<bool>(key);
        SPDLOG_DEBUG("{}: Getting blackboard bool \"{}\": {}", static_cast<int>(entity), key, value);
        return value;
    }

    auto setBlackboardInt(entt::entity entity, std::string key, int valueToSet) -> void {
        auto& blackboard = globals::registry.get<GOAPComponent>(entity).blackboard;
        blackboard.set(key, valueToSet);
        SPDLOG_DEBUG("{}: Setting blackboard int \"{}\" to {}", static_cast<int>(entity), key, valueToSet);
    }

    auto getBlackboardInt(entt::entity entity, std::string key) -> int {
        auto& blackboard = globals::registry.get<GOAPComponent>(entity).blackboard;
        auto value = blackboard.get<int>(key);
        SPDLOG_DEBUG("{}: Getting blackboard int \"{}\": {}", static_cast<int>(entity), key, value);
        return value;
    }

    auto setBlackboardString(entt::entity entity, std::string key, std::string valueToSet) -> void {
        auto& blackboard = globals::registry.get<GOAPComponent>(entity).blackboard;
        blackboard.set(key, valueToSet);
        SPDLOG_DEBUG("{}: Setting blackboard string \"{}\" to {}", static_cast<int>(entity), key, valueToSet);
    }

    auto getBlackboardString(entt::entity entity, std::string key) -> std::string {
        auto& blackboard = globals::registry.get<GOAPComponent>(entity).blackboard;
        auto value = blackboard.get<std::string>(key);
        SPDLOG_DEBUG("{}: Getting blackboard string \"{}\": {}", static_cast<int>(entity), key, value);
        return value;
    }
}