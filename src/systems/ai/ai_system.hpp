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
    extern bool ai_system_paused; // global flag to pause the AI system, from lua
    
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
    
    extern auto init() -> void;
    extern auto cleanup() -> void;
    extern void bind_ai_utilities(sol::state& lua);
    extern void getLuaFilesFromDirectory(const std::string &actionsDir, std::vector<std::string> &luaFiles);
    extern auto updateHumanAI(entt::registry& registry, float deltaTime) -> void;
    extern auto updateHumanAI(float deltaTime) -> void;

    extern void replan(entt::entity entity);
    extern void on_interrupt(entt::entity entity);

    /**
     * Replan for an explicit goal without invoking goal selectors.
     *
     * This is used for hierarchical GOAP where subgoals need to be pushed
     * without triggering the normal goal selection process.
     *
     * @param entity The entity to replan for
     * @param explicit_goal The goal state to plan towards
     * @param merge_with_current If true, merge explicit_goal with current goal.
     *                           If false, replace current goal entirely.
     */
    extern void replan_to_goal(entt::entity entity, const worldstate_t& explicit_goal,
                               bool merge_with_current = false);

    extern void debugPrintGOAPStruct(GOAPComponent &goapStruct);

    void runWorldStateUpdaters(GOAPComponent &goapStruct, entt::entity &entity);
    extern auto resetAllGOAPComponentsAndScripting() -> void;

    extern void fill_action_queue_based_on_plan(entt::registry& registry, entt::entity e, const char** plan, int planSize);
    [[deprecated("Use fill_action_queue_based_on_plan(registry, e, plan, planSize) instead")]]
    extern void fill_action_queue_based_on_plan(entt::entity e, const char** plan, int planSize);
    
    extern void initGOAPComponent(entt::registry& registry, entt::entity entity,
                           const std::string &type,
                           sol::optional<sol::table> overrides = sol::nullopt);
    [[deprecated("Use initGOAPComponent(registry, entity, type, overrides) instead")]]
    extern void initGOAPComponent(entt::entity entity,
                           const std::string &type,
                           sol::optional<sol::table> overrides = sol::nullopt);
    extern auto requestAISystemReset() -> void;
    
    auto runBlackboardInitFunction(entt::registry& registry, entt::entity entity, const std::string &identifier) -> void;
    [[deprecated("Use runBlackboardInitFunction(registry, entity, identifier) instead")]]
    auto runBlackboardInitFunction(entt::entity entity, const std::string &identifier) -> void;
    extern bool goap_worldstate_get(actionplanner_t *ap, worldstate_t ws, const char *atomname, bool *value);
    extern bool goap_worldstate_match(actionplanner_t* ap, worldstate_t current_state, worldstate_t expected_state);
    extern std::map<std::string, bool> goap_worldstate_to_map(const actionplanner_t* ap, const worldstate_t* ws);
    extern void goap_actionplanner_clear_memory( actionplanner_t* ap );
    extern bool goap_is_goapstruct_valid(GOAPComponent& goapStruct);
    extern void select_goal(entt::registry& registry, entt::entity entity);
    [[deprecated("Use select_goal(registry, entity) instead")]]
    extern void select_goal(entt::entity entity);
    extern bool execute_current_action(entt::entity entity);
    extern void handle_no_plan(entt::registry& registry, entt::entity entity);
    [[deprecated("Use handle_no_plan(registry, entity) instead")]]
    extern void handle_no_plan(entt::entity entity);
    extern void checkAndSetGOAPDirty(GOAPComponent& goapStruct, int initialPlanBufferSize);
    extern void fill_action_queue_based_on_plan(entt::entity e, const char** plan, int planSize);
    extern std::optional<Action::Result> run_action_queue(entt::entity entity, float deltaTime);
} // namespace ai_system
