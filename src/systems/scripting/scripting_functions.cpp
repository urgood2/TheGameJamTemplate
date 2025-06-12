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

        //---------------------------------------------------------
        // methods from textVer2.cpp. These can be called from lua
        //---------------------------------------------------------
        TextSystem::exposeToLua(stateToInit);

        //---------------------------------------------------------
        // methods from anim_system.cpp. These can be called from lua
        //---------------------------------------------------------
        animation_system::exposeToLua(stateToInit);

        // ------------------------------------------------------
        // methods from tutorial_system_v2.cpp. These can be called from lua
        // ------------------------------------------------------
        tutorial_system_v2::exposeToLua(stateToInit);

        //---------------------------------------------------------
        // methods from particle system. These can be called from lua
        //---------------------------------------------------------
        particle::exposeToLua(stateToInit);

        //---------------------------------------------------------
        // methods from shader_pipeline.cpp. These can be called from lua
        //---------------------------------------------------------
        shader_pipeline::exposeToLua(stateToInit);

        //---------------------------------------------------------
        // methods from random.cpp. These can be called from lua
        //---------------------------------------------------------
        random_utils::exposeToLua(stateToInit);

        //---------------------------------------------------------
        // methods from system/layer folder. These can be called from lua
        //---------------------------------------------------------
        layer::exposeToLua(stateToInit);

        //---------------------------------------------------------
        // methods from shader_system.cpp. These can be called from lua
        //---------------------------------------------------------
        shaders::exposeToLua(stateToInit);

        // ---------------------------------------------------------
        // methods from localization.cpp. These can be called from lua
        //---------------------------------------------------------
        localization::exposeToLua(stateToInit);

        // ---------------------------------------------------------
        // methods from timer.cpp. These can be called from lua
        //---------------------------------------------------------
        timer::exposeToLua(stateToInit);

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

    /**
     * ------------------------------------------------------
     * Utility functions
     * ------------------------------------------------------
     */
    #include <fstream>
    #include <string>

    void dump_lua_globals(sol::state& lua, std::string const& out_path) {

        lua.open_libraries(sol::lib::base,
                     sol::lib::package,
                     sol::lib::table,
                     sol::lib::string);

        // 2) Capture all debug() calls into a C++ std::string
        std::string capture;

        // 1) install your capture hook under a fresh name
        lua["capture_debug"] = [&](std::string s) {
        capture += s + "\n";
        };

        // 1) Load your helper chunk (either from a file or from a raw string)
        //    Here I'm using your raw string literal:
        static char const* chunk = R"(

                -- alias the real `debug` name *inside* this chunk
                local debug = capture_debug
                -- Helper function to get sorted keys
                local function get_sorted_keys(tbl)
                    local keys = {}
                    for k in pairs(tbl) do
                        table.insert(keys, k)
                    end
                    table.sort(keys, function(a, b)
                        return tostring(a) < tostring(b)  -- Ensure keys are compared as strings
                    end)
                    return keys
                end

                function print_filtered_globals()
                    -- Define a set of excluded keys (tables and functions you want to ignore)
                    local excluded_keys = {
                        ["sol.entt::entity.♻"] = true,
                        ["table"] = true,
                        ["getEventOccurred"] = true,
                        ["ipairs"] = true,
                        ["next"] = true,
                        ["assert"] = true,
                        ["tostring"] = true,
                        ["getmetatable"] = true,
                        ["dofile"] = true,
                        ["rawget"] = true,
                        ["select"] = true,
                        ["os"] = true,
                        ["ActionResult"] = true,
                        ["rawequal"] = true,
                        ["warn"] = true,
                        ["wait"] = true,
                        ["pairs"] = true,
                        ["Entity"] = true,
                        ["sol.☢☢"] = true,
                        ["logic"] = true,
                        ["rawset"] = true,
                        ["collectgarbage"] = true,
                        ["load"] = true,
                        ["_VERSION"] = true,
                        ["rawlen"] = true,
                        ["pcall"] = true,
                        ["package"] = true,
                        ["_G"] = true,
                        ["conditions"] = true,
                        ["require"] = true,
                        ["xpcall"] = true,
                        ["base"] = true,
                        ["print_table"] = true,
                        ["coroutine"] = true,
                        ["loadfile"] = true,
                        ["setmetatable"] = true,
                        ["sol.🔩"] = true,
                        ["string"] = true,
                        ["tonumber"] = true,
                        ["type"] = true
                    }

                    -- Helper function to accumulate functions inside tables into a string
                    local function accumulate_functions_in_table(tbl, table_name, result_str)
                        for k, v in pairs(tbl) do
                            if type(v) == 'function' then
                                local key_str = (type(k) == 'number') and tostring(k) or '"'..tostring(k)..'"'
                                result_str = result_str .. '  ['..table_name..'.'..key_str..'] = function: ' .. tostring(v) .. '\n'
                            end
                        end
                        return result_str
                    end

                    -- Initialize an empty string to accumulate the output
                    local result_str = ""

                    -- Get sorted top-level keys
                    local sorted_keys = get_sorted_keys(_G)

                    -- Loop through the global environment (_G) using sorted keys
                    for _, k in ipairs(sorted_keys) do
                        local v = _G[k]
                        -- Convert key to string (quote it if it's not a number)
                        local key_str = (type(k) == 'number') and tostring(k) or '"'..tostring(k)..'"'

                        -- Check if the key is in the excluded set
                        if not excluded_keys[k] then
                            -- Convert value to string
                            if type(v) == 'table' then
                                result_str = result_str .. '['..key_str..'] = {...}\n'  -- Indicate it's a table
                                -- Check if the table contains any functions and accumulate them
                                result_str = accumulate_functions_in_table(v, key_str, result_str)
                            else
                                local value_str = tostring(v)  -- Convert non-table types to string
                                result_str = result_str .. '['..key_str..'] = ' .. value_str .. '\n'
                            end
                        end
                    end

                    -- Print the accumulated result as a block of text
                    debug(result_str)
                end

                function print_flat_globals()
                    -- Initialize an empty string to accumulate the output
                    local result_str = ""

                    -- Get sorted top-level keys
                    local sorted_keys = get_sorted_keys(_G)

                    for _, k in ipairs(sorted_keys) do
                        local v = _G[k]
                        -- Convert key to string (quote it if it's not a number)
                        local key_str = (type(k) == 'number') and tostring(k) or '"'..tostring(k)..'"'

                        -- Convert value to string
                        local value_str
                        if type(v) == 'table' then
                            value_str = '{...}'  -- Indicate it's a table without printing its contents
                        else
                            value_str = tostring(v)  -- Convert other types to string
                        end

                        -- Accumulate the key-value pair in the result string
                        result_str = result_str .. '['..key_str..'] = ' .. value_str .. '\n'
                    end

                    -- Print the accumulated result as a block of text
                    print(result_str)
                end

                -- Helper function to avoid infinite recursion and accumulate table content
                function accumulate_table(tbl, indent, visited, result_str)
                    indent = indent or 0
                    local indent_str = string.rep("  ", indent)
                    visited = visited or {}

                    if visited[tbl] then
                        result_str = result_str .. indent_str .. "*recursion detected*\n"
                        return result_str
                    end

                    visited[tbl] = true  -- Mark this table as visited

                    -- Get sorted keys for the table
                    local sorted_keys = get_sorted_keys(tbl)

                    for _, key in ipairs(sorted_keys) do
                        local value = tbl[key]
                        if type(value) == "table" then
                            if key ~= "_G" then  -- Avoid infinite recursion on _G
                                result_str = result_str .. indent_str .. key .. ": table\n"
                                result_str = accumulate_table(value, indent + 1, visited, result_str)
                            end
                        else
                            result_str = result_str .. indent_str .. key .. ": " .. type(value) .. '\n'
                        end
                    end
                    return result_str
                end

                -- Function to print all globals with accumulated output and sorted top-level keys
                function print_globals()
                    local result_str = accumulate_table(_G, 0, {}, "")
                    debug(result_str)
                end

            )";

        auto load_result = lua.load(chunk, "print_globals_chunk");
        if (!load_result.valid()) {
            sol::error err = load_result;
            spdlog::error("Failed to load globals‐dump chunk: {}", err.what());
            return;
        }
        // execute it, defining the functions in the global table
        load_result(); 




        // 3) Call the printer
        lua["print_filtered_globals"]();

        // 5) Write out to a file
        std::ofstream out(out_path, std::ios::trunc);
        if (!out) {
            spdlog::error("Could not open {} for writing", out_path);
            return;
        }
        out << capture;
        spdlog::info("Lua globals dumped to {}", out_path);


    }

    
}