#include "scripting_functions.hpp"

#include "../../util/common_headers.hpp"

#include "core/globals.hpp"
#include "raylib.h"
#include "sol/sol.hpp"
#include "sol_ImGui.h"
#include "../ai/ai_system.hpp"
#include "../event/event_system.hpp"
#include "../tutorial/tutorial_system_v2.hpp"
#include "../sound/sound_system.hpp" 
#include "../transform/transform_functions.hpp"
#include "../ui/ui.hpp"
#include "core/ui_definitions.hpp"
#include "../text/textVer2.hpp"
#include "../shaders/shader_system.hpp"
#include "../shaders/shader_pipeline.hpp"
#include "../shaders/shader_draw_commands.hpp"
#include "../localization/localization.hpp"
#include "util/error_handling.hpp"
#include "../particles/particle.hpp"
#include "../random/random.hpp"
#include "../timer/timer.hpp"
#include "../layer/layer_order_system.hpp"
#include "../collision/broad_phase.hpp"

#include "binding_recorder.hpp"

#include "../layer/layer.hpp"
#include "core/init.hpp"
#include "systems/palette/palette_quantizer.hpp"

#include "core/engine_context.hpp"
#include "spdlog/spdlog.h"
#include "systems/anim_system.hpp"

#include "systems/camera/camera_bindings.hpp"
#include "systems/entity_gamestate_management/entity_gamestate_management.hpp"
#include "systems/input/controller_nav.hpp"
#include "systems/ldtk_loader/ldtk_combined.hpp"
#include "systems/main_loop_enhancement/main_loop.hpp"
#include "systems/physics/physics_lua_bindings.hpp"
#include "systems/spring/spring_lua_bindings.hpp"
#include "systems/text/static_ui_text.hpp"
#include "util/utilities.hpp"

#include "lua_hot_reload.hpp"

#include "meta_helper.hpp"
#include "registry_bond.hpp"
#include "scripting_system.hpp"
#include "script_process.hpp"

#include "../../core/game.hpp"
#include <functional>

// #define TRACY_NO_CALLSTACK 1
// #define TRACY_CALLSTACK 8 // fixed depth for callstack, fix lua errors.
#include "third_party/tracy-master/public/tracy/TracyLua.hpp"



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
    auto initLuaMasterState(sol::state& stateToInit, const std::vector<std::string> scriptFilesToRead, EngineContext* ctx) -> void {
        
        
        auto& rec = BindingRecorder::instance();
        
        // basic lua state initialization
        stateToInit.open_libraries(sol::lib::base, sol::lib::package, sol::lib::table, sol::lib::coroutine, sol::lib::os, sol::lib::string, sol::lib::math, sol::lib::debug, sol::lib::io, sol::lib::bit32);
        #if defined(LUAJIT_VERSION)
        stateToInit.open_libraries(sol::lib::ffi, sol::lib::jit);
        #endif
        
        std::string base1 = util::getRawAssetPathNoUUID("scripts/");
        std::string base2 = util::getRawAssetPathNoUUID("scripts/core");
        std::string base3 = util::getRawAssetPathNoUUID("scripts/init");
        std::string base4 = util::getRawAssetPathNoUUID("scripts/monobehavior");
        std::string base5 = util::getRawAssetPathNoUUID("scripts/external");
        
        std::string lua_path_cmd =
            "package.path = '"
            + base1 + "?.lua;" + base1 + "?/?.lua;" + base1 + "?/?/?.lua;"
            + base2 + "?.lua;"
            + base3 + "?.lua;"
            + base5 + "?.lua;"
            + base4 + "?.lua;scripts/?/?.lua"
            + "' .. package.path"; // <- correctly attached
            
        // set the lua path to include the scripts directory
        stateToInit.script(lua_path_cmd, [](lua_State*, sol::protected_function_result pfr) {
            // pfr will contain things that went wrong, for either loading or executing the script
            // Can throw your own custom error
            // You can also just return it, and let the call-site handle the error if necessary.
            SPDLOG_ERROR("Error setting lua path: {}", pfr.get<sol::error>().what());
            return pfr;
        });
        SPDLOG_DEBUG("Lua path set to: {}", lua_path_cmd);
        
        
        
        
        
        //---------------------------------------------------------
        // methods from ai_system.cpp. These can be called from lua,
        // binding before anything else because it is used in the init function
        //---------------------------------------------------------
        stateToInit.set_function("hardReset", []() {
            ai_system::requestAISystemReset();
        });
        rec.record_free_function({}, {"hardReset", "---@return nil", "Requests a full reset of the AI system state.", true, false});
        ai_system::bind_ai_utilities(stateToInit);
        
        // ------------------------------------------------------
        // methods for coroutine scheduling
        // ------------------------------------------------------
        coroutine_scheduler::open_scheduler(stateToInit);
        stateToInit["scheduler"] = std::ref(ai_system::masterScheduler);
        

        // 1) Module‐level banner
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
        
        
        // add entt::null
        
        stateToInit["entt_null"] = static_cast<entt::entity>(entt::null);
        
        
        // allow tracy support
        // tracy::LuaRegister( stateToInit.lua_state() );
        // lua_sethook(stateToInit, tracy::LuaHook, LUA_MASKCALL | LUA_MASKRET, 0);
        
        // dummy tracy table
        // sol::table tracyTable = stateToInit.create_table();
        // stateToInit["tracy"] = tracyTable;
        // stateToInit["tracy"]["ZoneBeginNS"] = []() {
        //     // dummy
        // };
        // stateToInit["tracy"]["ZoneEnd"] = []() {
        //     // dummy
        // };

        //---------------------------------------------------------
        // methods from event_system.cpp. These can be called from lua✅ 
        //---------------------------------------------------------
        event_system::exposeEventSystemToLua(stateToInit);
        
        //---------------------------------------------------------
        // methods from controller_nav.cpp. These can be called from lua✅
        //---------------------------------------------------------
        controller_nav::exposeToLua(stateToInit, ctx);

        //---------------------------------------------------------
        // methods from textVer2.cpp. These can be called from lua✅ 
        //---------------------------------------------------------
        TextSystem::exposeToLua(stateToInit);

        //---------------------------------------------------------
        // methods from anim_system.cpp. These can be called from lua✅ 
        //---------------------------------------------------------
        animation_system::exposeToLua(stateToInit);
        
        //------------------------------------------------------
        // methods from broad_phase.hpp. These can be called from lua ✅
        //------------------------------------------------------
        collision::exposeToLua(stateToInit, ctx);

        // ------------------------------------------------------
        // methods from tutorial_system_v2.cpp. These can be called from lua ✅
        // ------------------------------------------------------
        tutorial_system_v2::exposeToLua(stateToInit);

        //---------------------------------------------------------
        // methods from particle system. These can be called from lua✅ 
        //---------------------------------------------------------
        particle::exposeToLua(stateToInit);

        //---------------------------------------------------------
        // methods from shader_pipeline.cpp. These can be called from lua✅ TODO: type registration not done properly
        //---------------------------------------------------------
        shader_pipeline::exposeToLua(stateToInit, ctx);

        //---------------------------------------------------------
        // methods from random.cpp. These can be called from lua✅
        //---------------------------------------------------------
        random_utils::exposeToLua(stateToInit, ctx);

        //---------------------------------------------------------
        // methods from system/layer folder. These can be called from lua✅ 
        //---------------------------------------------------------
        layer::exposeToLua(stateToInit, ctx);

        //---------------------------------------------------------
        // methods from shader_system.cpp. These can be called from lua✅
        //---------------------------------------------------------
        shaders::exposeToLua(stateToInit, ctx);

        //---------------------------------------------------------
        // methods from shader_draw_commands.cpp. These can be called from lua✅
        //---------------------------------------------------------
        shader_draw_commands::exposeToLua(stateToInit);

        // ---------------------------------------------------------
        // methods from localization.cpp. These can be called from lua✅
        //---------------------------------------------------------
        localization::exposeToLua(stateToInit, ctx);

        // ---------------------------------------------------------
        // methods from timer.cpp. These can be called from lua✅ 
        //---------------------------------------------------------
        // timer::exposeToLua(stateToInit);

        

        //---------------------------------------------------------
        // methods from sound_system.cpp. These can be called from lua✅
        //---------------------------------------------------------
        sound_system::ExposeToLua(stateToInit);

        //---------------------------------------------------------
        // methods from utilities.cpp. These can be called from lua✅
        //---------------------------------------------------------
        util::exposeToLua(stateToInit);

        //---------------------------------------------------------
        // LDtk helpers (config-driven, entity iteration)
        //---------------------------------------------------------
        {
            sol::table ldtk = stateToInit.create_table();

            ldtk.set_function("load_config", [](const std::string& cfgPath) {
                // cfgPath is relative to assets/ (same convention as other loaders)
                ldtk_loader::ReloadProject(cfgPath);
                ldtk_loader::SetRegistry(globals::getRegistry());
            });

            ldtk.set_function("spawn_entities", [](const std::string& levelName, sol::function cb) {
                ldtk_loader::SetRegistry(globals::getRegistry());
                ldtk_loader::ForEachEntity(levelName, [cb](const ldtk_loader::EntitySpawnInfo& info) {
                    if (cb.valid()) {
                        cb(info.name, info.position.x, info.position.y, info.layer, info.grid.x, info.grid.y);
                    }
                });
            });

            ldtk.set_function("prefab_for", [](const std::string& entityName) {
                return ldtk_loader::PrefabForEntity(entityName);
            });

            ldtk.set_function("set_spawner", [](sol::function fn) {
                static sol::function stored;
                stored = fn;
                ldtk_loader::SetEntitySpawner([fn](const ldtk::Entity& ent, entt::registry& /*R*/) {
                    if (!fn.valid()) return;
                    const auto pos  = ent.getPosition();
                    const auto grid = ent.getGridPosition();
                    const auto& tags = ent.getTags();
                    fn(ent.getName(), (float)pos.x, (float)pos.y, ent.layer->getName(), grid.x, grid.y, sol::as_table(tags));
                });
                ldtk_loader::SetRegistry(globals::getRegistry());
            });

            ldtk.set_function("each_intgrid", [](const std::string& levelName, const std::string& layerName, sol::function cb) {
                ldtk_loader::ForEachIntGrid(levelName, layerName, [cb](int x, int y, int value) {
                    if (cb.valid()) cb(x, y, value);
                });
            });

            ldtk.set_function("collider_layers", []() {
                return ldtk_loader::ColliderLayers();
            });

            ldtk.set_function("build_colliders", [](const std::string& levelName, const std::string& worldName, sol::optional<std::string> tag) {
                ldtk_loader::BuildCollidersForLevel(levelName, worldName, tag.value_or("WORLD"));
            });

            ldtk.set_function("clear_colliders", [](const std::string& levelName, const std::string& worldName) {
                ldtk_loader::ClearCollidersForLevel(levelName, worldName);
            });

            ldtk.set_function("set_active_level", [](const std::string& levelName, const std::string& worldName,
                                                     sol::optional<bool> rebuildColliders,
                                                     sol::optional<bool> spawnEntities,
                                                     sol::optional<std::string> tag) {
                ldtk_loader::SetActiveLevel(
                    levelName,
                    worldName,
                    rebuildColliders.value_or(true),
                    spawnEntities.value_or(true),
                    tag.value_or("WORLD"));
            });

            ldtk.set_function("active_level", []() { return ldtk_loader::GetActiveLevel(); });
            ldtk.set_function("has_active_level", []() { return ldtk_loader::HasActiveLevel(); });

            stateToInit["ldtk"] = ldtk;
            rec.record_property("ldtk", {"load_config", "", "Load and bind an LDtk project via JSON config (project_path, asset_dir, collider_layers, entity_prefabs)."});
            rec.record_property("ldtk", {"spawn_entities", "", "Iterate entities in a level and invoke the provided Lua callback."});
            rec.record_property("ldtk", {"each_intgrid", "", "Iterate intgrid values in a level layer."});
            rec.record_property("ldtk", {"prefab_for", "", "Look up a prefab id for an LDtk entity name from config."});
            rec.record_property("ldtk", {"collider_layers", "", "List collider layers declared in the active LDtk config."});
            rec.record_property("ldtk", {"build_colliders", "", "Generate static colliders for the configured collider layers into a physics world."});
            rec.record_property("ldtk", {"clear_colliders", "", "Remove generated colliders for a level from a physics world."});
            rec.record_property("ldtk", {"set_spawner", "", "Register a Lua callback invoked per LDtk entity (name, px, py, layer, gx, gy, tagsTable)."});
            rec.record_property("ldtk", {"set_active_level", "", "Set the active LDtk level, optionally rebuilding colliders and spawning entities."});
            rec.record_property("ldtk", {"active_level", "", "Returns the current active LDtk level name (or empty)." });
            rec.record_property("ldtk", {"has_active_level", "", "True if an active LDtk level is set."});
        }


        
        //---------------------------------------------------------
        // methods and data from transform system. These can be called from lua ✅
        //---------------------------------------------------------
        transform::exposeToLua(stateToInit, ctx);
        
        //---------------------------------------------------------
        // methods from ui system. These can be called from lua ✅
        //---------------------------------------------------------
        ui::exposeToLua(stateToInit);

        ui_defs::exposeToLua(stateToInit);
        
        //---------------------------------------------------------
        // spring
        //---------------------------------------------------------
        bind::bind_spring(stateToInit);
        

        // ------------------------------------------------------
        // methods for entity registry access
        // ------------------------------------------------------
        stateToInit.set_function("getEntityByAlias", getEntityByAlias);
        stateToInit.set_function("setEntityAlias", setEntityAlias);
        rec.record_free_function({}, {"getEntityByAlias", "---@param alias string\n---@return Entity|nil", "Retrieves an entity by its string alias.", true, false});
        rec.record_free_function({}, {"setEntityAlias", "---@param alias string\n---@param entity Entity\n---@return nil", "Assigns a string alias to an entity.", true, false});

        //---------------------------------------------------------
        // methods from scripting_functions.cpp. These can be called from lua
        //---------------------------------------------------------
        // --- Logging Functions ---
        // stateToInit.set_function("debug", sol::overload(
        //     static_cast<void(*)(entt::entity, std::string)>(&luaDebugLogWrapper),
        //     static_cast<void(*)(std::string)>(&luaDebugLogWrapperNoEntity)
        // ));

        // In your Sol2 init (after registering luaDebugLogWrapper*):
        stateToInit.set_function("log_debug",
        [](sol::this_state ts, sol::variadic_args va) {
            sol::state_view L{ts};
            std::ostringstream oss;

            // Check if first arg is an entity
            auto it = va.begin();
            bool hasEntity = false;
            entt::entity e = entt::null;
            if (it != va.end() && it->get_type() == sol::type::number) {
            // Sol2 represents entt::entity as integer
            e = static_cast<entt::entity>(it->as<int>());
            hasEntity = true;
            ++it;
            }

            // Concatenate the rest
            bool first = true;
            for (; it != va.end(); ++it) {
            if (!first) oss << ' ';
            first = false;

            // Convert any Lua value to string via tostring()
            sol::object obj = *it;
            sol::function tostr = L["tostring"];
            std::string s = tostr(obj);
            oss << s;
            }

            // Dispatch to the correct backend
            if (hasEntity) {
            luaDebugLogWrapper(e, oss.str());
            } else {
            luaDebugLogWrapperNoEntity(oss.str());
            }
        }
        );

        // Main signature
        rec.record_free_function({}, {"log_debug",
            "---@param entity Entity # The entity to associate the log with.\n"
            "---@param message string # The message to log. Can be variadic arguments.\n"
            "---@return nil",
            "Logs a debug message associated with an entity.", true, false});
        // Overload for no entity
        rec.record_free_function({}, {"log_debug",
            "---@overload fun(message: string):nil",
            "Logs a general debug message.", true, true});


        stateToInit.set_function("log_error",
        [](sol::this_state ts, sol::variadic_args va) {
            sol::state_view L{ts};
            std::ostringstream oss;

            // Check if first arg is an entity
            auto it = va.begin();
            bool hasEntity = false;
            entt::entity e = entt::null;
            if (it != va.end() && it->get_type() == sol::type::number) {
            // Sol2 represents entt::entity as integer
            e = static_cast<entt::entity>(it->as<int>());
            hasEntity = true;
            ++it;
            }

            // Concatenate the rest
            bool first = true;
            for (; it != va.end(); ++it) {
            if (!first) oss << ' ';
            first = false;

            // Convert any Lua value to string via tostring()
            sol::object obj = *it;
            sol::function tostr = L["tostring"];
            std::string s = tostr(obj);
            oss << s;
            }

            // Dispatch to the correct backend
            if (hasEntity) {
            luaErrorLogWrapper(e, oss.str());
            } else {
            luaErrorLogWrapperNoEntity(oss.str());
            }
        }
        );

        // Main signature
        rec.record_free_function({}, {"log_error",
            "---@param entity Entity # The entity to associate the error with.\n"
            "---@param message string # The error message. Can be variadic arguments.\n"
            "---@return nil",
            "Logs an error message associated with an entity.", true, false});
        // Overload for no entity
        rec.record_free_function({}, {"log_error",
            "---@overload fun(message: string):nil",
            "Logs a general error message.", true, true});


        // --- Current World State ---
        stateToInit.set_function("setCurrentWorldStateValue", setCurrentWorldStateValue);
        stateToInit.set_function("getCurrentWorldStateValue", getCurrentWorldStateValue);
        stateToInit.set_function("clearCurrentWorldState", clearCurrentWorldState);

        rec.record_free_function({}, {"setCurrentWorldStateValue",
            "---@param entity Entity\n"
            "---@param key string\n"
            "---@param value boolean\n" // Changed from 'any' to 'boolean'
            "---@return nil",
            "Sets a value in the entity's current world state.", true, false});

        rec.record_free_function({}, {"getCurrentWorldStateValue",
            "---@param entity Entity\n"
            "---@param key string\n"
            "---@return boolean|nil", // Changed from 'any' to 'boolean'
            "Gets a value from the entity's current world state.", true, false});

        rec.record_free_function({}, {"clearCurrentWorldState",
            "---@param entity Entity\n" // Added missing entity parameter
            "---@return nil",
            "Clears the entity's current world state.", true, false});


        // --- Goal World State ---
        stateToInit.set_function("setGoalWorldStateValue", setGoalWorldStateValue);
        stateToInit.set_function("getGoalWorldStateValue", getGoalWorldStateValue);
        stateToInit.set_function("clearGoalWorldState", clearGoalWorldState);

        rec.record_free_function({}, {"setGoalWorldStateValue",
            "---@param entity Entity\n" // Added missing entity parameter
            "---@param key string\n"
            "---@param value boolean\n" // Changed from 'any' to 'boolean'
            "---@return nil",
            "Sets a value in the entity's goal world state.", true, false});

        rec.record_free_function({}, {"getGoalWorldStateValue",
            "---@param entity Entity\n" // Added missing entity parameter
            "---@param key string\n"
            "---@return boolean|nil", // Changed from 'any' to 'boolean'
            "Gets a value from the entity's goal world state.", true, false});

        rec.record_free_function({}, {"clearGoalWorldState",
            "---@param entity Entity\n" // Added missing entity parameter
            "---@return nil",
            "Clears the entity's goal world state.", true, false});


        // --- Blackboard Functions (your existing ones were correct) ---
        stateToInit.set_function("setBlackboardFloat", setBlackboardFloat);
        stateToInit.set_function("getBlackboardFloat", getBlackboardFloat);
        rec.record_free_function({}, {"setBlackboardFloat", "---@param entity Entity\n---@param key string\n---@param value number\n---@return nil", "Sets a float value on an entity's blackboard.", true, false});
        rec.record_free_function({}, {"getBlackboardFloat", "---@param entity Entity\n---@param key string\n---@return number", "Gets a float value from an entity's blackboard.", true, false});
        
        stateToInit.set_function("setBlackboardVector2", setBlackBoardVector2);
        stateToInit.set_function("getBlackboardVector2", getBlackBoardVector2);
        rec.record_free_function({}, {"setBlackboardVector2", "---@param entity Entity\n---@param key string\n---@param value Vector2\n---@return nil", "Sets a Vector2 value on an entity's blackboard.", true, false});
        rec.record_free_function({}, {"getBlackboardVector2", "---@param entity Entity\n---@param key string\n---@return Vector2", "Gets a Vector2 value from an entity's blackboard.", true, false});

        stateToInit.set_function("setBlackboardBool", setBlackboardBool);
        stateToInit.set_function("getBlackboardBool", getBlackboardBool);
        rec.record_free_function({}, {"setBlackboardBool", "---@param entity Entity\n---@param key string\n---@param value boolean\n---@return nil", "Sets a boolean value on an entity's blackboard.", true, false});
        rec.record_free_function({}, {"getBlackboardBool", "---@param entity Entity\n---@param key string\n---@return boolean", "Gets a boolean value from an entity's blackboard.", true, false});
        
        stateToInit.set_function("blackboardContains", [] (entt::entity entity, const std::string& key) {
            auto& blackboard = globals::getRegistry().get<GOAPComponent>(entity).blackboard;
            return blackboard.contains(key);
        });
        rec.record_free_function({}, {"blackboardContains", "---@param entity Entity\n---@param key string\n---@return boolean", "Checks if the blackboard contains a specific key.", true, false});
        

        stateToInit.set_function("setBlackboardInt", setBlackboardInt);
        stateToInit.set_function("getBlackboardInt", getBlackboardInt);
        rec.record_free_function({}, {"setBlackboardInt", "---@param entity Entity\n---@param key string\n---@param value integer\n---@return nil", "Sets an integer value on an entity's blackboard.", true, false});
        rec.record_free_function({}, {"getBlackboardInt", "---@param entity Entity\n---@param key string\n---@return integer", "Gets an integer value from an entity's blackboard.", true, false});

        stateToInit.set_function("setBlackboardString", setBlackboardString);
        stateToInit.set_function("getBlackboardString", getBlackboardString);
        rec.record_free_function({}, {"setBlackboardString", "---@param entity Entity\n---@param key string\n---@param value string\n---@return nil", "Sets a string value on an entity's blackboard.", true, false});
        rec.record_free_function({}, {"getBlackboardString", "---@param entity Entity\n---@param key string\n---@return string", "Gets a string value from an entity's blackboard.", true, false});


        // --- Input ---
        stateToInit.set_function("isKeyPressed", isKeyPressed);
        rec.record_free_function({}, {"isKeyPressed", "---@param key string\n---@return boolean", "Checks if a specific keyboard key is currently pressed.", true, false});
        
        stateToInit.set_function("pauseGame", pauseGame);
        stateToInit.set_function("unpauseGame", unpauseGame);
        rec.record_free_function({}, {"pauseGame", "---@return nil", "Pauses the game.", true, false});
        rec.record_free_function({}, {"unpauseGame", "---@return nil", "Unpauses the game.", true, false});
        
        // ------------------------------------------------------
        // game.cpp variables and functions
        // ------------------------------------------------------
        // wherever you bind your scripting API:
        // game::exposeToLua(stateToInit);
        
        stateToInit.set_function("add_fullscreen_shader", game::add_fullscreen_shader);
        stateToInit.set_function("remove_fullscreen_shader", game::remove_fullscreen_shader);
        
        rec.record_free_function({""}, {"add_fullscreen_shader",
            "---@param shaderName string\n",
            "Adds a fullscreen shader to the game.", true, false});
        rec.record_free_function({""}, {"remove_fullscreen_shader",
            "---@param shaderName string\n",
            "Removes a fullscreen shader from the game.", true, false});
            
        // ------------------------------------------------------
        // quad tree
        // ------------------------------------------------------
        game::luaqt::bind_quadtrees_lua(stateToInit, globals::quadtreeWorld, globals::quadtreeUI);
        
        // ------------------------------------------------------
        // static ui text functions
        // ------------------------------------------------------
        static_ui_text_system::exposeToLua(stateToInit);
        
        // ------------------------------------------------------
        // lua physics bindings
        // ------------------------------------------------------
        physics::expose_physics_to_lua(stateToInit, ctx);   
        physics::expose_steering_to_lua(stateToInit, ctx);
        physics::expose_physics_manager_to_lua(stateToInit, *globals::physicsManager);
        
        // ------------------------------------------------------
        // camera manager & camera bindings
        // ------------------------------------------------------
        camera_bindings::expose_camera_to_lua(stateToInit);

        // Also expose your globalShaderUniforms so Lua can call
        //   globalShaderUniforms.set(shaderName, uniformName, value)

        // expose imgui to lua
        sol_ImGui::Init(stateToInit);
        
        // main loop settings
        main_loop::exposeToLua(stateToInit);
        
        // ------------------------------------------------------
        // input functions
        // ------------------------------------------------------
        input::exposeToLua(stateToInit, ctx);
        
        // -------------------------------------------------------
        // layer order functions
        // --------------------------------------------------------
        layer::layer_order_system::exposeToLua(stateToInit);
        
        // ------------------------------------------------------
        // game state management functions (for entity gamestate management)
        // ------------------------------------------------------
        entity_gamestate_management::exposeToLua(stateToInit);

        // ------------------------------------------------------
        // Expose global variables to Lua
        // ------------------------------------------------------
        exposeGlobalsToLua(stateToInit);
        
        
        // intialize ai directories
        // Call require to load and cache ai.init
        // TODO: access results later with "ai" in lua
        // sol::table ai_module = stateToInit.require("ai.init");
        
        
        // read all the script files and load them into the lua state
        for (auto &filename : scriptFilesToRead) {
            // stateToInit.script_file(filename);
            lua_hot_reload::track(filename);
            
            auto code_valid_result = util::safeLuaCall(stateToInit, "safe_script_file", filename);
            SPDLOG_DEBUG("Loading file {}...", filename);
            if (code_valid_result.isErr() || !code_valid_result.value().valid()) {
                const char* errMsg = code_valid_result.isErr()
                    ? code_valid_result.error().c_str()
                    : code_valid_result.value().get<sol::error>().what();
                SPDLOG_ERROR("Lua loading failed: {}", errMsg);
                throw std::runtime_error("Lua script file loading failed.");
            } else {
                SPDLOG_DEBUG("Lua script file loading success.");
            }
        }
        
        stateToInit.script("require(\"ai.init\")", [](lua_State*, sol::protected_function_result pfr) {
            // pfr will contain things that went wrong, for either loading or executing the script
            // Can throw your own custom error
            // You can also just return it, and let the call-site handle the error if necessary.
            return pfr;
        });
        stateToInit.script("require(\"util.util\")", [](lua_State*, sol::protected_function_result pfr) {
            // pfr will contain things that went wrong, for either loading or executing the script
            // Can throw your own custom error
            // You can also just return it, and let the call-site handle the error if necessary.
            return pfr;
        });
        
        
        // 5) Finally dump out your definitions:
        rec.dump_lua_defs(util::getRawAssetPathNoUUID("scripts/chugget_code_definitions.lua")); 
    }

    auto exposeGlobalsToLua(sol::state &lua) -> void{
        auto &rec = BindingRecorder::instance();
        // 1) create the root table (or get it if it already exists)
        
        // bind the OpenURL(const char *url) method
        lua.set_function("OpenURL", [](const std::string &url) {
            OpenURL(url.c_str());
        });
        
        lua["globals"].get_or_create<sol::table>();

        // 2) simple bools / ints / floats
        lua["globals"]["isGamePaused"]  = &globals::getIsGamePaused();
        lua["globals"]["screenWipe"]    = &globals::getScreenWipe();
        lua["globals"]["screenWidth"]   = [](){ return globals::VIRTUAL_WIDTH; };
        lua["globals"]["screenHeight"]  = [](){ return globals::VIRTUAL_HEIGHT; };
        lua["globals"]["currentGameState"] = &globals::getCurrentGameState();
        
        auto& inputStateRef = globals::getInputState();
        lua["globals"]["inputState"] = &inputStateRef;

        // Lightweight constructors for Raylib vector types (accept table {x=,y=} or positional floats).
        lua.set_function("Vector2", [](sol::object a, sol::object b) -> Vector2 {
            if (a.is<sol::table>()) {
                auto t = a.as<sol::table>();
                return Vector2{ t.get_or("x", 0.0f), t.get_or("y", 0.0f) };
            }
            float x = a.is<float>() ? a.as<float>() : 0.0f;
            float y = b.is<float>() ? b.as<float>() : 0.0f;
            return Vector2{ x, y };
        });
        lua.set_function("Vector3", [](sol::object a, sol::object b, sol::object c) -> Vector3 {
            if (a.is<sol::table>()) {
                auto t = a.as<sol::table>();
                return Vector3{ t.get_or("x", 0.0f), t.get_or("y", 0.0f), t.get_or("z", 0.0f) };
            }
            float x = a.is<float>() ? a.as<float>() : 0.0f;
            float y = b.is<float>() ? b.as<float>() : 0.0f;
            float z = c.is<float>() ? c.as<float>() : 0.0f;
            return Vector3{ x, y, z };
        });
        lua.set_function("Vector4", [](sol::object a, sol::object b, sol::object c, sol::object d) -> Vector4 {
            if (a.is<sol::table>()) {
                auto t = a.as<sol::table>();
                return Vector4{ t.get_or("x", 0.0f), t.get_or("y", 0.0f), t.get_or("z", 0.0f), t.get_or("w", 0.0f) };
            }
            float x = a.is<float>() ? a.as<float>() : 0.0f;
            float y = b.is<float>() ? b.as<float>() : 0.0f;
            float z = c.is<float>() ? c.as<float>() : 0.0f;
            float w = d.is<float>() ? d.as<float>() : 0.0f;
            return Vector4{ x, y, z, w };
        });
        
        /*
                Camera2D, defines position/orientation in 2d space
        typedef struct Camera2D {
            Vector2 offset;         // Camera offset (displacement from target)
            Vector2 target;         // Camera target (rotation and zoom origin)
            float rotation;         // Camera rotation in degrees
            float zoom;             // Camera zoom (scaling), should be 1.0f by default
        } Camera2D;
        */
        
        // lua usertype binding for Camera2D
        // lua.new_usertype<Vector2>(
        //     "Vector2",
        //     "x", &Vector2::x,
        //     "y", &Vector2::y
        // );
        lua.new_usertype<Camera2D>("Camera2D",
            "offset", &Camera2D::offset,
            "target", &Camera2D::target,
            "rotation", &Camera2D::rotation,
            "zoom", &Camera2D::zoom
        );
        
        //FIXME: remove this static camera2D object, and use the camera manager isntead
        static Camera2D camera2D{}; // create a static camera2D object to use as a global
        lua["globals"]["camera"] = []() -> Camera2D& {
            return std::ref(camera2D);
        };
        
        lua["GetFrameTime"] = []() -> float {
            // Get the time elapsed since the last frame
            return main_loop::mainLoop.smoothedDeltaTime;
        };
        
        lua["GetTime"] = []() -> float {
            // Get the time elapsed since the last frame
            return main_loop::getTime();
        };
        
        lua["GetScreenWidth"] = []() -> int {
            return globals::VIRTUAL_WIDTH;
        };
        lua["GetScreenHeight"] = []() -> int {
            return globals::VIRTUAL_HEIGHT;
        };
        lua["GetWorldToScreen2D"] = [](Vector2 position, Camera2D camera) -> Vector2 {
            // Convert the position from world coordinates to screen coordinates
            return GetWorldToScreen2D(position, camera);
        };
        lua["GetScreenToWorld2D"] = [](Vector2 position, Camera2D camera) -> Vector2 {
            // Convert the position from screen coordinates to world coordinates
            return GetScreenToWorld2D(position, camera);
        };
        
        rec.record_property("globals", {"camera", "nil", "Camera2D object used for rendering the game world."});

        // 3) entt::entity
        lua["globals"]["gameWorldContainerEntity"] = []() -> entt::entity {
            return globals::getGameWorldContainer();
        };
        lua["globals"]["cursor"]                   = []() -> entt::entity {
            return globals::getCursorEntity();
        };
        lua["globalShaderUniforms"] = std::ref(globals::getGlobalShaderUniforms());
        
        rec.record_property("", {"globalShaderUniforms", "nil", "global ShaderUniformComponent object, used to set shader uniforms globally."});

        // Sprite frame + atlas helper for Lua (used by shader uniform setup)
        rec.bind_function(lua, {}, "getSpriteFrameTextureInfo",
            [&lua](const std::string& identifier) -> sol::optional<sol::table> {
                auto frame = init::getSpriteFrame(identifier, globals::g_ctx);
                Texture2D* atlasTex = getAtlasTexture(frame.atlasUUID);
                if (!atlasTex) {
                    SPDLOG_ERROR("getSpriteFrameTextureInfo: atlas '{}' not found for '{}'", frame.atlasUUID, identifier);
                    return sol::nullopt;
                }

                sol::state_view sv(lua.lua_state());
                sol::table t = sv.create_table();
                t["atlas"] = *atlasTex;
                t["atlasUUID"] = frame.atlasUUID;
                t["frame"] = sv.create_table_with(
                    "x", frame.frame.x,
                    "y", frame.frame.y,
                    "width", frame.frame.width,
                    "height", frame.frame.height);
                t["gridRect"] = Vector4{frame.frame.x, frame.frame.y, frame.frame.width, frame.frame.height};
                t["imageSize"] = Vector2{static_cast<float>(atlasTex->width), static_cast<float>(atlasTex->height)};
                return t;
            },
            R"lua(
        ---@param identifier string # Sprite UUID or raw identifier (e.g., filename)
        ---@return table|nil # { atlas=Texture2D, atlasUUID=string, frame={x,y,width,height}, gridRect=Vector4, imageSize=Vector2 } or nil on failure
        )lua",
            "Fetches atlas texture + frame metadata for a sprite identifier.");

        // Palette loader for shader uniforms
        rec.bind_function(lua, {}, "setPaletteTexture",
            [](const std::string& shaderName, const std::string& filePath) -> bool {
                // Try resolving relative paths via the asset helper first.
                const std::string resolved = util::getRawAssetPathNoUUID(filePath);
                if (palette_quantizer::setPaletteTexture(shaderName, resolved)) {
                    return true;
                }
                // Fallback: use the provided path directly (e.g., already absolute).
                return palette_quantizer::setPaletteTexture(shaderName, filePath);
            },
            R"lua(
        ---@param shaderName string # Name of the shader to receive the palette uniform
        ---@param filePath string   # Asset-relative or absolute path to the palette image
        ---@return boolean          # true if loaded and applied, false otherwise
        )lua",
            "Loads a palette texture from disk and uploads it to the shader's 'palette' uniform with point filtering.");

        // 4) expose your Layer pointers under a sub-table "game"
        // lua.create_named_table("game")[
        //     "background"   ] = game::background;
        // lua["game"]["sprites"]       = game::sprites;
        // lua["game"]["ui_layer"]      = game::ui_layer;
        // lua["game"]["finalOutput"]   = game::finalOutput;
        // lua["game"]["background"  ] = game::GetLayer("background");
        // lua["game"]["sprites"]       = game::GetLayer("sprites");
        // lua["game"]["ui_layer"]      = game::GetLayer("ui_layer");
        // lua["game"]["finalOutput"]   = game::GetLayer("finalOutput");
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
        if (globals::getRegistry().valid(entity) == false) {
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
        auto &goapComponent = globals::getRegistry().get<GOAPComponent>(entity);
        goap_worldstate_set(&goapComponent.ap, &goapComponent.current_state, key.c_str(), value);
        SPDLOG_DEBUG("{}: Setting current world state \"{}\" to {}", static_cast<int>(entity), key, value);
    }

    auto getCurrentWorldStateValue(entt::entity entity, std::string key) -> bool {
        auto &goapComponent = globals::getRegistry().get<GOAPComponent>(entity);
        bool value = false;
        bool successful = ai_system::goap_worldstate_get(&goapComponent.ap, goapComponent.current_state, key.c_str(), &value);
        if (!successful) {
            SPDLOG_ERROR("{}: Could not get current world state \"{}\": does not exist. Defaulting to false", static_cast<int>(entity), key);
        }
        return value;
    }

    auto clearCurrentWorldState(entt::entity entity) -> void {
        auto &goapComponent = globals::getRegistry().get<GOAPComponent>(entity);
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
        auto &goapComponent = globals::getRegistry().get<GOAPComponent>(entity);
        goap_worldstate_set(&goapComponent.ap, &goapComponent.goal, key.c_str(), value);
        SPDLOG_DEBUG("{}: Setting goal world state \"{}\" to {}", static_cast<int>(entity), key, value);
    }

    auto getGoalWorldStateValue(entt::entity entity, std::string key) -> bool {
        auto &goapComponent = globals::getRegistry().get<GOAPComponent>(entity);
        bool value = false;
        bool successful = ai_system::goap_worldstate_get(&goapComponent.ap, goapComponent.current_state, key.c_str(), &value);
        if (!successful) {
            SPDLOG_ERROR("{}: Could not get goal world state \"{}\": does not exist. Defaulting to false", static_cast<int>(entity), key);
        }
        return value;
    }

    auto clearGoalWorldState(entt::entity entity) -> void {
        auto &goapComponent = globals::getRegistry().get<GOAPComponent>(entity);
        goap_worldstate_clear(&goapComponent.goal);
        SPDLOG_DEBUG("{}: Cleared goal world state", static_cast<int>(entity));
    }

    /**
     * ------------------------------------------------------
     * Convenience functions for dealing with std::any blackboard
     * ------------------------------------------------------
     */
     
    auto setBlackBoardVector2(entt::entity entity, std::string key, Vector2 valueToSet) -> void {
        if (!globals::getRegistry().valid(entity) || entity == entt::null) { 
            SPDLOG_ERROR("Entity {} is not valid, cannot set blackboard vector2", static_cast<int>(entity));
            return;
        }
        auto& blackboard = globals::getRegistry().get<GOAPComponent>(entity).blackboard;
        blackboard.set(key, valueToSet);
        // SPDLOG_DEBUG("{}: Setting blackboard vector2 \"{}\" to ({}, {})", static_cast<int>(entity), key, valueToSet.x, valueToSet.y);
    }
    
    auto getBlackBoardVector2(entt::entity entity, std::string key) -> std::optional<Vector2> {
        if (!globals::getRegistry().valid(entity) || entity == entt::null) {
            SPDLOG_ERROR("Entity {} is not valid, cannot get blackboard vector2", static_cast<int>(entity));
            return Vector2{0.f, 0.f}; // or some other default value
        }
        auto& blackboard = globals::getRegistry().get<GOAPComponent>(entity).blackboard;
        
        if (!blackboard.contains(key)) {
            return std::nullopt;
        }
        
        auto value = blackboard.get<Vector2>(key);
        // SPDLOG_DEBUG("{}: Getting blackboard vector2 \"{}\": ({}, {})", static_cast<int>(entity), key, value.x, value.y);
        return value;
    }

    auto setBlackboardFloat(entt::entity entity, std::string key, float valueToSet) -> void {
        if (!globals::getRegistry().valid(entity) || entity == entt::null) {
            SPDLOG_ERROR("Entity {} is not valid, cannot set blackboard float", static_cast<int>(entity));
            return;
        }
        auto& blackboard = globals::getRegistry().get<GOAPComponent>(entity).blackboard;
        blackboard.set(key, valueToSet);
        
        // SPDLOG_DEBUG("{}: Setting blackboard float \"{}\" to {}", static_cast<int>(entity), key, valueToSet);
    }

    auto getBlackboardFloat(entt::entity entity, std::string key) -> std::optional<float> {
        if (!globals::getRegistry().valid(entity) || entity == entt::null) {
            SPDLOG_ERROR("Entity {} is not valid, cannot get blackboard float", static_cast<int>(entity));
            return -1.f; // or some other default value
        }
        auto& blackboard = globals::getRegistry().get<GOAPComponent>(entity).blackboard;
        
        if (!blackboard.contains(key)) {
            return std::nullopt;
        }
        
        auto value = blackboard.get<float>(key);
        // SPDLOG_DEBUG("{}: Getting blackboard float \"{}\": {}", static_cast<int>(entity), key, value);
        return value;
    }

    auto setBlackboardBool(entt::entity entity, std::string key, bool valueToSet) -> void {
        if (!globals::getRegistry().valid(entity) || entity == entt::null) {
            SPDLOG_ERROR("Entity {} is not valid, cannot set blackboard bool", static_cast<int>(entity));
            return;
        }
        auto& blackboard = globals::getRegistry().get<GOAPComponent>(entity).blackboard;
        blackboard.set(key, valueToSet);
        // SPDLOG_DEBUG("{}: Setting blackboard bool \"{}\" to {}", static_cast<int>(entity), key, valueToSet);
    }

    auto getBlackboardBool(entt::entity entity, std::string key) -> std::optional<bool> {
        if (!globals::getRegistry().valid(entity) || entity == entt::null) {
            SPDLOG_ERROR("Entity {} is not valid, cannot get blackboard bool", static_cast<int>(entity));
            return false; // or some other default value
        }
        auto& blackboard = globals::getRegistry().get<GOAPComponent>(entity).blackboard;
        if (!blackboard.contains(key)) {
            return std::nullopt;
        }
        auto value = blackboard.get<bool>(key);
        // SPDLOG_DEBUG("{}: Getting blackboard bool \"{}\": {}", static_cast<int>(entity), key, value);
        return value;
    }

    auto setBlackboardInt(entt::entity entity, std::string key, int valueToSet) -> void {
        if (!globals::getRegistry().valid(entity) || entity == entt::null) {
            SPDLOG_ERROR("Entity {} is not valid, cannot set blackboard int", static_cast<int>(entity));
            return;
        }
        auto& blackboard = globals::getRegistry().get<GOAPComponent>(entity).blackboard;
        blackboard.set(key, valueToSet);
        // SPDLOG_DEBUG("{}: Setting blackboard int \"{}\" to {}", static_cast<int>(entity), key, valueToSet);
    }

    auto getBlackboardInt(entt::entity entity, std::string key) -> std::optional<int> {
        if (!globals::getRegistry().valid(entity) || entity == entt::null) {
            SPDLOG_ERROR("Entity {} is not valid, cannot get blackboard int", static_cast<int>(entity));
            return -1; // or some other default value
        }
        auto& blackboard = globals::getRegistry().get<GOAPComponent>(entity).blackboard;
        
        if (!blackboard.contains(key)) {
            return std::nullopt;
        }
        auto value = blackboard.get<int>(key);
        // SPDLOG_DEBUG("{}: Getting blackboard int \"{}\": {}", static_cast<int>(entity), key, value);
        return value;
    }

    auto setBlackboardString(entt::entity entity, std::string key, std::string valueToSet) -> void {
        if (!globals::getRegistry().valid(entity) || entity == entt::null) {
            SPDLOG_ERROR("Entity {} is not valid, cannot set blackboard string", static_cast<int>(entity));
            return;
        }
        auto& blackboard = globals::getRegistry().get<GOAPComponent>(entity).blackboard;
        blackboard.set(key, valueToSet);
        // SPDLOG_DEBUG("{}: Setting blackboard string \"{}\" to {}", static_cast<int>(entity), key, valueToSet);
    }

    auto getBlackboardString(entt::entity entity, std::string key) -> std::optional<std::string> {
        if (!globals::getRegistry().valid(entity) || entity == entt::null) {
            SPDLOG_ERROR("Entity {} is not valid, cannot get blackboard string", static_cast<int>(entity));
            return ""; // or some other default value
        }
        auto& blackboard = globals::getRegistry().get<GOAPComponent>(entity).blackboard;
        
        if (!blackboard.contains(key)) {
            return std::nullopt;
        }
        auto value = blackboard.get<std::string>(key);
        // SPDLOG_DEBUG("{}: Getting blackboard string \"{}\": {}", static_cast<int>(entity), key, value);
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
        auto result = util::safeLuaCall(pfg, "print_filtered_globals");
        if (result.isErr()) {
            spdlog::error("Error running print_filtered_globals: {}", result.error());
            return;
        }
    
        // 5) Extract the returned string
        std::string capture = result.value().get<std::string>();
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
