#pragma once

// * Steps to follow if you wish to add a lua binding for a new method:
// * 1. Add the method declaration to this file
// * 2. Add the method definition to the cpp file
// * 3. Add the method binding in the initLuaStateWithAllObjectAndFunctionBindings method in this file
// * 4. Make sure the above method is called to initialize the lua state you plan to use
// * 5. Profit

#include "sol/sol.hpp"
#include "entt/fwd.hpp"
#include <vector>
#include <string>

namespace scripting {

    /**
     * ------------------------------------------------------
     * Master lua state initialization function - the master state contains all the bindings for running the ai system from the lua side
     * ------------------------------------------------------
     */

    extern auto initLuaMasterState(sol::state & stateToInit, std::vector<std::string> filenames) -> void;

    /**
     * ------------------------------------------------------
     * Convenience functions for logging from lua
     * ------------------------------------------------------
     */

    extern auto luaDebugLogWrapper(entt::entity entity, std::string message) -> void;
    extern auto luaErrorLogWrapper(entt::entity entity, std::string message) -> void;
    extern auto luaDebugLogWrapperNoEntity(std::string message) -> void;
    extern auto luaErrorLogWrapperNoEntity(std::string message) -> void;

    /**
     * ------------------------------------------------------
     * Access functions for keypress & event system events
     * ------------------------------------------------------
     */

    extern bool isKeyPressed(const std::string& key);

    /**
     * ------------------------------------------------------
     * Methods for game state access
     * ------------------------------------------------------
     */

    extern auto pauseGame() -> void;
    extern auto unpauseGame() -> void;
    /**
     * ------------------------------------------------------
     * Access functions for entt registry
     * ------------------------------------------------------
     */
    extern std::unordered_map<std::string, entt::entity> entity_aliases;

    extern auto getEntityByAlias(const std::string& name) -> entt::entity;
    extern auto setEntityAlias(const std::string& name, entt::entity entity) -> void;

    /**
     * ------------------------------------------------------
     * Methods for setting and getting values in a given blackboard
     * ------------------------------------------------------
     */

    extern auto setBlackboardFloat(entt::entity entity, std::string key, float valueToSet) -> void;
    extern auto getBlackboardFloat(entt::entity entity, std::string key) -> float;
    extern auto setBlackboardBool(entt::entity entity, std::string key, bool valueToSet) -> void;
    extern auto getBlackboardBool(entt::entity entity, std::string key) -> bool;
    extern auto setBlackboardInt(entt::entity entity, std::string key, int valueToSet) -> void;
    extern auto getBlackboardInt(entt::entity entity, std::string key) -> int;
    extern auto setBlackboardString(entt::entity entity, std::string key, std::string valueToSet) -> void;
    extern auto getBlackboardString(entt::entity entity, std::string key) -> std::string;

    /**
     * ------------------------------------------------------
     * Methods for world state access
     * ------------------------------------------------------
     */

    extern auto getCurrentWorldStateValue(entt::entity entity, std::string key) -> bool;
    extern auto setCurrentWorldStateValue(entt::entity entity, std::string key, bool value) -> void;
    extern auto clearCurrentWorldState(entt::entity entity) -> void ;

    extern auto setGoalWorldStateValue(entt::entity entity, std::string key, bool value) -> void;
    extern auto getGoalWorldStateValue(entt::entity entity, std::string key) -> bool;
    extern auto clearGoalWorldState(entt::entity entity) -> void;

    /**
        -- Lua script subscribing to an event
    EventDispatcher:subscribe("OnEnemyDefeated", function(enemy)
        print("Enemy defeated: " .. enemy.name)
        -- Additional Lua logic
    end)
    */
}