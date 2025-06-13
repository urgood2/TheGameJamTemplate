#include "scripting_functions.hpp"

#include "../../util/common_headers.hpp"

#include "sol/sol.hpp"
#include "../ai/ai_system.hpp"
#include "../event/event_system.hpp"
#include "../tutorial/tutorial_system_v2.hpp"
#include "../sound/sound_system.hpp" 
#include "../transform/transform_functions.hpp"
#include "../ui/ui.hpp"
#include "../text/textVer2.hpp"
#include "../shaders/shader_system.hpp"
#include "../shaders/shader_pipeline.hpp"
#include "../localization/localization.hpp"
#include "../particles/particle.hpp"
#include "../random/random.hpp"
#include "../timer/timer.hpp"

#include "binding_recorder.hpp"

#include "../layer/layer.hpp"

#include "systems/anim_system.hpp"

#include "util/utilities.hpp"

#include "meta_helper.hpp"
#include "registry_bond.hpp"
#include "scripting_system.hpp"

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

    auto behavior_script = lua.load_file("scripts/behavior_script.lua");
    ...
    registry.emplace<scripting::ScriptComponent>(e, behavior_script.call());


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

        // 1) Module‐level banner
        auto& rec = BindingRecorder::instance();
        rec.set_module_name("chugget.engine");
        rec.set_module_version("0.1");
        rec.set_module_doc("Bindings for chugget's c++ code, for use with lua.");
        
        //---------------------------------------------------------
        // initialize lua state with custom object bindings✅
        //---------------------------------------------------------
        stateToInit.new_enum("ActionResult",
            "SUCCESS", Action::Result::SUCCESS,
            "FAILURE", Action::Result::FAILURE,
            "RUNNING", Action::Result::RUNNING
        );
        // 3) Record it as a class with constant fields
        //    (so dump_lua_defs will emit @class + @field for each value)
        rec.add_type("ActionResult").doc = "Results of an action";
        rec.record_property("ActionResult", { "SUCCESS", "0", "When succeeded" });
        rec.record_property("ActionResult", { "FAILURE", "1", "When failed" });
        rec.record_property("ActionResult", { "RUNNING", "2", "When still running" });
        
        // stateToInit.new_usertype<entt::entity>("Entity");
        // 3) Bind & record the Entity usertype
        rec.bind_usertype<entt::entity>(
            stateToInit,
            "Entity",
            /*version=*/"0.1",
            /*doc=*/"Wraps an EnTT entity handle for Lua scripts."
        );


        //---------------------------------------------------------
        // methods from event_system.cpp. These can be called from lua✅
        //---------------------------------------------------------
        event_system::exposeEventSystemToLua(stateToInit);

        //---------------------------------------------------------
        // methods from textVer2.cpp. These can be called from lua✅
        //---------------------------------------------------------
        TextSystem::exposeToLua(stateToInit);

        //---------------------------------------------------------
        // methods from anim_system.cpp. These can be called from lua✅
        //---------------------------------------------------------
        animation_system::exposeToLua(stateToInit);

        // ------------------------------------------------------
        // methods from tutorial_system_v2.cpp. These can be called from lua ✅
        // ------------------------------------------------------
        tutorial_system_v2::exposeToLua(stateToInit);

        //---------------------------------------------------------
        // methods from particle system. These can be called from lua✅
        //---------------------------------------------------------
        particle::exposeToLua(stateToInit);

        //---------------------------------------------------------
        // methods from shader_pipeline.cpp. These can be called from lua✅
        //---------------------------------------------------------
        shader_pipeline::exposeToLua(stateToInit);

        //---------------------------------------------------------
        // methods from random.cpp. These can be called from lua✅
        //---------------------------------------------------------
        random_utils::exposeToLua(stateToInit);

        //---------------------------------------------------------
        // methods from system/layer folder. These can be called from lua✅
        //---------------------------------------------------------
        layer::exposeToLua(stateToInit);

        //---------------------------------------------------------
        // methods from shader_system.cpp. These can be called from lua✅
        //---------------------------------------------------------
        shaders::exposeToLua(stateToInit);

        // ---------------------------------------------------------
        // methods from localization.cpp. These can be called from lua✅
        //---------------------------------------------------------
        localization::exposeToLua(stateToInit);

        // ---------------------------------------------------------
        // methods from timer.cpp. These can be called from lua✅
        //---------------------------------------------------------
        timer::exposeToLua(stateToInit);

        

        //---------------------------------------------------------
        // methods from sound_system.cpp. These can be called from lua
        //---------------------------------------------------------
        sound_system::ExposeToLua(stateToInit);

        //---------------------------------------------------------
        // methods from utilities.cpp. These can be called from lua
        //---------------------------------------------------------
        util::exposeToLua(stateToInit);


        
        //---------------------------------------------------------
        // methods and data from transform system. These can be called from lua
        //---------------------------------------------------------
        transform::exposeToLua(stateToInit);
        
        //---------------------------------------------------------
        // methods from ui system. These can be called from lua
        //---------------------------------------------------------
        ui::exposeToLua(stateToInit);


        //---------------------------------------------------------
        // methods from ai_system.cpp. These can be called from lua
        //---------------------------------------------------------
        stateToInit.set_function("hardReset", []() {
            ai_system::requestAISystemReset();
        });
        rec.record_free_function({}, {"hardReset", "---@return nil", "Requests a full reset of the AI system state.", true, false});

        // ------------------------------------------------------
        // methods for entity registry access
        // ------------------------------------------------------
        stateToInit.set_function("getEntityByAlias", getEntityByAlias);
        stateToInit.set_function("setEntityAlias", setEntityAlias);
        rec.record_free_function({}, {"getEntityByAlias", "---@param alias string\n---@return Entity|nil", "Retrieves an entity by its string alias.", true, false});
        rec.record_free_function({}, {"setEntityAlias", "---@param entity Entity\n---@param alias string\n---@return nil", "Assigns a string alias to an entity.", true, false});

        //---------------------------------------------------------
        // methods from scripting_functions.cpp. These can be called from lua
        //---------------------------------------------------------
        stateToInit.set_function("debug", sol::overload(
            static_cast<void(*)(entt::entity, std::string)>(&luaDebugLogWrapper),
            static_cast<void(*)(std::string)>(&luaDebugLogWrapperNoEntity)
        ));
        rec.record_free_function({}, {"debug", "---@param entity Entity\n---@param message string\n---@return nil", "Logs a debug message associated with an entity.", true, false});
        rec.record_free_function({}, {"debug", "(message: string):nil", "Logs a general debug message.", true, true});

        stateToInit.set_function("error", sol::overload(
            static_cast<void(*)(entt::entity, std::string)>(&luaErrorLogWrapper),
            static_cast<void(*)(std::string)>(&luaErrorLogWrapperNoEntity)
        ));
        rec.record_free_function({}, {"error", "---@param entity Entity\n---@param message string\n---@return nil", "Logs an error message associated with an entity.", true, false});
        rec.record_free_function({}, {"error", "(message: string):nil", "Logs a general error message.", true, true});

        stateToInit.set_function("setCurrentWorldStateValue", setCurrentWorldStateValue);
        stateToInit.set_function("getCurrentWorldStateValue", getCurrentWorldStateValue);
        stateToInit.set_function("clearCurrentWorldState", clearCurrentWorldState);
        rec.record_free_function({}, {"setCurrentWorldStateValue", "---@param key string\n---@param value any\n---@return nil", "Sets a value in the current world state.", true, false});
        rec.record_free_function({}, {"getCurrentWorldStateValue", "---@param key string\n---@return any|nil", "Gets a value from the current world state.", true, false});
        rec.record_free_function({}, {"clearCurrentWorldState", "---@return nil", "Clears the current world state.", true, false});
        
        stateToInit.set_function("setGoalWorldStateValue", setGoalWorldStateValue);
        stateToInit.set_function("getGoalWorldStateValue", getGoalWorldStateValue);
        stateToInit.set_function("clearGoalWorldState", clearGoalWorldState);
        rec.record_free_function({}, {"setGoalWorldStateValue", "---@param key string\n---@param value any\n---@return nil", "Sets a value in the goal world state.", true, false});
        rec.record_free_function({}, {"getGoalWorldStateValue", "---@param key string\n---@return any|nil", "Gets a value from the goal world state.", true, false});
        rec.record_free_function({}, {"clearGoalWorldState", "---@return nil", "Clears the goal world state.", true, false});

        stateToInit.set_function("setBlackboardFloat", setBlackboardFloat);
        stateToInit.set_function("getBlackboardFloat", getBlackboardFloat);
        rec.record_free_function({}, {"setBlackboardFloat", "---@param entity Entity\n---@param key string\n---@param value number\n---@return nil", "Sets a float value on an entity's blackboard.", true, false});
        rec.record_free_function({}, {"getBlackboardFloat", "---@param entity Entity\n---@param key string\n---@return number", "Gets a float value from an entity's blackboard.", true, false});

        stateToInit.set_function("setBlackboardBool", setBlackboardBool);
        stateToInit.set_function("getBlackboardBool", getBlackboardBool);
        rec.record_free_function({}, {"setBlackboardBool", "---@param entity Entity\n---@param key string\n---@param value boolean\n---@return nil", "Sets a boolean value on an entity's blackboard.", true, false});
        rec.record_free_function({}, {"getBlackboardBool", "---@param entity Entity\n---@param key string\n---@return boolean", "Gets a boolean value from an entity's blackboard.", true, false});

        stateToInit.set_function("setBlackboardInt", setBlackboardInt);
        stateToInit.set_function("getBlackboardInt", getBlackboardInt);
        rec.record_free_function({}, {"setBlackboardInt", "---@param entity Entity\n---@param key string\n---@param value integer\n---@return nil", "Sets an integer value on an entity's blackboard.", true, false});
        rec.record_free_function({}, {"getBlackboardInt", "---@param entity Entity\n---@param key string\n---@return integer", "Gets an integer value from an entity's blackboard.", true, false});
        
        stateToInit.set_function("setBlackboardString", setBlackboardString);
        stateToInit.set_function("getBlackboardString", getBlackboardString);
        rec.record_free_function({}, {"setBlackboardString", "---@param entity Entity\n---@param key string\n---@param value string\n---@return nil", "Sets a string value on an entity's blackboard.", true, false});
        rec.record_free_function({}, {"getBlackboardString", "---@param entity Entity\n---@param key string\n---@return string", "Gets a string value from an entity's blackboard.", true, false});

        stateToInit.set_function("isKeyPressed", isKeyPressed);
        rec.record_free_function({}, {"isKeyPressed", "---@param key string\n---@return boolean", "Checks if a specific keyboard key is currently pressed.", true, false});
        
        stateToInit.set_function("pauseGame", pauseGame);
        stateToInit.set_function("unpauseGame", unpauseGame);
        rec.record_free_function({}, {"pauseGame", "---@return nil", "Pauses the game.", true, false});
        rec.record_free_function({}, {"unpauseGame", "---@return nil", "Unpauses the game.", true, false});

        // 5) Finally dump out your definitions:
        rec.dump_lua_defs(util::getRawAssetPathNoUUID("scripts/chugget.lua_defs")); 
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

    /**
     * ------------------------------------------------------
     * Utility functions
     * ------------------------------------------------------
     */
    #include <fstream>
    #include <string>

    void dump_lua_globals(sol::state& lua, std::string const& out_path) {
        // 1) Open exactly the libraries we need
        lua.open_libraries(sol::lib::base,
                           sol::lib::package,
                           sol::lib::table,
                           sol::lib::string);
    
        // 2) Define print_filtered_globals in Lua,
        //    making it RETURN the result string instead of printing it.
        lua.script(R"(
            local excluded = {
              table=true, package=true, string=true, ipairs=true, pairs=true,
              assert=true, error=true, load=true, dofile=true, _VERSION=true,
              coroutine=true, collectgarbage=true, rawget=true, rawset=true,
              -- add any sol.* entries you want to skip here…
            }
          
            local function get_sorted_keys(tbl)
              local keys = {}
              for k in pairs(tbl) do table.insert(keys, k) end
              table.sort(keys, function(a,b) return tostring(a) < tostring(b) end)
              return keys
            end
          
            local function dump_table(tbl, indent, seen)
              indent = indent or 0
              seen   = seen   or {}
          
              -- avoid infinite loops
              if seen[tbl] then
                return string.rep("  ", indent) .. "*<cycle>*\n"
              end
              seen[tbl] = true
          
              local out = ""
              local pad = string.rep("  ", indent)
          
              -- First dump any *own* keys
              for _, k in ipairs(get_sorted_keys(tbl)) do
                if not excluded[k] then
                  local v = tbl[k]
                  local keytxt = ("%q"):format(k)
                  if type(v) == "table" then
                    out = out .. pad.. "["..keytxt.."] = {\n"
                    out = out .. dump_table(v, indent+1, seen)
                    out = out .. pad.. "}\n"
                  else
                    out = out .. pad.. "["..keytxt.."] = "..tostring(v).."\n"
                  end
                end
              end
          
              -- Now, if there's a metatable, and it has an __index table, dump *that* too
              local mt = debug.getmetatable(tbl)
              if mt and type(mt.__index) == "table" then
                out = out .. pad.. "[metatable.__index] = {\n"
                out = out .. dump_table(mt.__index, indent+1, seen)
                out = out .. pad.. "}\n"
              end
          
              return out
            end
          
            function print_filtered_globals()
              return dump_table(_G, 0, {})
            end
          )");
          
          
    
        // 3) Grab the function as a protected_function
        sol::protected_function pfg = lua["print_filtered_globals"];
        if (!pfg.valid()) {
            spdlog::error("print_filtered_globals is not defined or not a function!");
            return;
        }
    
        // 4) Call it, catching any Lua errors
        sol::protected_function_result result = pfg();
        if (!result.valid()) {
            sol::error err = result;
            spdlog::error("Error running print_filtered_globals: {}", err.what());
            return;
        }
    
        // 5) Extract the returned string
        std::string capture = result;
        // (if you want to preserve your old hook, you could still munge `capture` here)
    
        // 6) Write it out
        std::ofstream out(out_path, std::ios::trunc);
        if (!out) {
            spdlog::error("Could not open {} for writing", out_path);
            return;
        }
        out << capture;
        spdlog::info("Lua globals dumped to {}", out_path);
    }
    

    
}