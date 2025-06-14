#pragma once

/***
 * Contains an ai system that will tick human's ai's and update their behavior tree
*/

#include "entt/fwd.hpp"

#include "third_party/GPGOAP/goap.h"
#include "../../components/components.hpp"

#include "sol/sol.hpp"

#include <nlohmann/json.hpp>
using json = nlohmann::json;

namespace ai_system
{
    
    using fsec = std::chrono::duration<float>;
    using scheduler = entt::basic_scheduler<fsec>;
    extern scheduler masterScheduler; // master scheduler for AI processes

    // this event is used to update pointers to the master lua state in other systems
    struct LuaStateResetEvent {
        sol::state* masterStateLua;
    };

    extern sol::state masterStateLua; // stores all scripts in one state
    extern float aiUpdateTickInSeconds;
    extern float aiUpdateTickTotal; // running total of time passed since last tick
    extern bool resetGOAPAndLuaStateRequested;
    
    // init must be called after json configs are loaded
    extern auto init() -> void;
    extern void bind_ai_utilities(sol::state& lua);
    extern void getLuaFilesFromDirectory(const std::string &actionsDir, std::vector<std::string> &luaFiles);
    extern auto updateHumanAI(float deltaTime) -> void;

    extern void replan(entt::entity entity);

    extern void debugPrintGOAPStruct(GOAPComponent &goapStruct);

    void runWorldStateUpdaters(entt::entity &entity);
    extern auto resetAllGOAPComponentsAndScripting() -> void;

    // goap methodse
    extern void fill_action_queue_based_on_plan(entt::entity e, const char** plan, int planSize);
    extern auto initGOAPComponent(entt::entity entity) -> void;
    extern auto requestAISystemReset() -> void;
    extern auto runBlackboardInitFunction(entt::entity entity, std::string identifier) -> void;
    extern void load_worldstate_from_json(const json& data, actionplanner_t& planner, worldstate_t& initialState, worldstate_t& goalState);
    extern void load_actions_from_json(const json& data, actionplanner_t& planner);
    extern bool goap_worldstate_get(actionplanner_t *ap, worldstate_t ws, const char *atomname, bool *value);
    extern bool goap_worldstate_match(actionplanner_t* ap, worldstate_t current_state, worldstate_t expected_state);
    extern std::map<std::string, bool> goap_worldstate_to_map(const actionplanner_t* ap, const worldstate_t* ws);
    extern void goap_actionplanner_clear_memory( actionplanner_t* ap );
    extern bool goap_is_goapstruct_valid(GOAPComponent& goapStruct);
    extern void select_goal(entt::entity entity);
    extern bool execute_current_action(entt::entity entity);
    extern void handle_no_plan(entt::entity entity);
    extern void checkAndSetGOAPDirty(GOAPComponent& goapStruct, int initialPlanBufferSize);
    extern void fill_action_queue_based_on_plan(entt::entity e, const char** plan, int planSize);
    extern std::optional<Action::Result> run_action_queue(entt::entity entity, float deltaTime);
} // namespace ai_system
