#include "ai_system.hpp"

#include "../../components/components.hpp"

#include "../../util/utilities.hpp"

#include "../../core/globals.hpp"

#include "../scripting/scripting_functions.hpp"

#include "../event/event_system.hpp"

#include "../../third_party/GPGOAP/goap.h"
#include "../../third_party/GPGOAP/astar.h"

#include "sol/sol.hpp"

#include <functional>
#include <queue>
#include <iostream>
#include <unordered_map>
#include <string>
#include <any>
#include <filesystem>

#include "../../util/common_headers.hpp"

namespace ai_system
{
    sol::state masterStateLua; // stores all scripts in one state

    std::map<std::string, std::map<std::string, bool>> allPostconditionsForEveryAction; // Contains all post-conditions for every action


    float aiUpdateTickInSeconds = 0.5f;
    float aiUpdateTickTotal = 0.0f; // running total of time passed since last tick

    bool goap_worldstate_match(actionplanner_t* ap, worldstate_t current_state, worldstate_t expected_state) {
        // Calculate the bits that we should care about (i.e., not "don't care" bits)
        bfield_t relevant_bits = ~expected_state.dontcare;

        // Check if the relevant bits in the current state match the expected state
        // This is done by applying a bitwise AND between the relevant bits and both states' values
        // Then compare the results to see if they match
        bool match = (current_state.values & relevant_bits) == (expected_state.values & relevant_bits);

        return match;
    }

    /*
    * @brief Clears the action planner by resetting atom and action counts and data.
    * This function resets the action planner's atoms, actions, and world states,
    * and frees any dynamically allocated memory. Must be called before exiting the program.
    */
    void goap_actionplanner_clear_memory( actionplanner_t* ap )
    {
        // Free atom names
        for ( int i=0; i < ap->numatoms; ++i ) 
        {
            free(&(ap->atm_names[i]));  // Free the memory allocated for each atom name
            ap->atm_names[i] = NULL; // Reset pointer to null after freeing
        }
        ap->numatoms = 0;   // Reset the number of atoms

        // Free action names
        for ( int i=0; i < ap->numactions; ++i )
        {
            free(&(ap->act_names[i]));  // Free the memory allocated for each action name
            ap->act_names[i] = NULL; // Reset pointer to null after freeing
            ap->act_costs[i] = 0;    // Reset all action costs
            goap_worldstate_clear( ap->act_pre+i ); // Clear preconditions for the action
            goap_worldstate_clear( ap->act_pst+i ); // Clear postconditions for the action
        }
        ap->numactions = 0; // Reset the number of actions
    }


    
    /**
     * Retrieves the value of a specific atom from the given world state.
     * Example usage:
     * 
     *     bool value;
     *     bool valid = goap_worldstate_get(&ap, ws, "alive", &value);
     * 
     * This will retrieve the value of the "alive" atom from the given world state.
     * If the atom is not found, valid will be false. 
     * Valid will only be true if the "value" variable is successfully set.
     *
     * @param ap The action planner.
     * @param ws The world state.
     * @param atomname The name of the atom to retrieve.
     * @param value A pointer to a boolean variable where the retrieved value will be stored.
     * @return True if the atom is found and its value is successfully retrieved, false otherwise.
     */
    bool goap_worldstate_get(actionplanner_t* ap, worldstate_t ws, const char* atomname, bool* value) {
        int idx = -1;
        
        // Find the index of the atom
        for (int i = 0; i < ap->numatoms; ++i) {
            if (strcmp(ap->atm_names[i], atomname) == 0) {
                idx = i;
                break;
            }
        }

        // If the atom is not found, return false (error)
        if (idx == -1) {
            return false;
        }

        // Check if this atom is a "don't care" bit
        if (ws.dontcare & (1LL << idx)) {
            return false;
        }

        // Retrieve the value of the atom
        *value = (ws.values & (1LL << idx)) != 0;
        return true;
    }
    
    /**
     * Checks if the given GOAPComponent structure is valid.
     * 
     * @param goapStruct The GOAPComponent structure to be checked.
     * @return True if the structure is valid, false otherwise.
     */
    bool goap_is_goapstruct_valid(GOAPComponent& goapStruct) {
        // If the number of plan is zero, the planner is empty
        return goapStruct.planSize == 0 || goapStruct.dirty == true;
    }

    // takes a loaded-in json object and reads in the actions and their preconditions and postconditions
    void load_actions_from_json(const json& data, actionplanner_t& planner) {
        for (const auto& action : data["actions"]) {
            std::string name = action["name"];
            int cost = action["cost"].get<int>();

            // Debug log the action name and cost
            SPDLOG_DEBUG("Loading action: {}, Cost: {}", name, cost);

            goap_set_cost(&planner, name.c_str(), cost);

            // Debugging the preconditions
            // SPDLOG_DEBUG("  Preconditions:");
            for (const auto& precondition : action["preconditions"].items()) {
                const std::string pre_key = precondition.key();
                const bool pre_value = precondition.value().get<bool>();
                
                // Log the precondition
                // SPDLOG_DEBUG("    {}: {}", pre_key, pre_value ? "true" : "false");
                
                goap_set_pre(&planner, name.data(), pre_key.data(), pre_value);
                SPDLOG_DEBUG("goap_set_pre(&planner, {}, {}, {})", name, pre_key, pre_value);
            }

            // Debugging the postconditions
            // SPDLOG_DEBUG("  Postconditions:");
            for (const auto& postcondition : action["postconditions"].items()) {
                const std::string post_key = postcondition.key();
                const bool post_value = postcondition.value().get<bool>();

                // Log the postcondition
                // SPDLOG_DEBUG("    {}: {}", post_key, post_value ? "true" : "false");

                goap_set_pst(&planner, name.data(), post_key.data(), post_value);
                SPDLOG_DEBUG("goap_set_pst(&planner, {}, {}, {})", name, post_key, post_value);
                
                allPostconditionsForEveryAction[name][post_key] = post_value ;
            }
            
            SPDLOG_DEBUG("Planner state after loading action: {}", name);

            char desc[ 4096 ];
            goap_description( &planner, desc, sizeof(desc) );
            SPDLOG_INFO("{}", desc);
        }
    }

    void load_worldstate_from_json(const json& data, actionplanner_t& planner, worldstate_t& initialState, worldstate_t& goalState) {
        // Debugging initial state
        SPDLOG_DEBUG("Loading initial world state:");
        for (const auto& atom : data["initial_state"].items()) {
            const std::string& atom_key = atom.key();
            const bool atom_value = atom.value().get<bool>();

            // Log the initial state atom
            // SPDLOG_DEBUG("  {}: {}", atom_key, atom_value ? "true" : "false");

            goap_worldstate_set(&planner, &initialState, atom_key.c_str(), atom_value);
            SPDLOG_DEBUG("goap_worldstate_set(&planner, &initialState, {}, {})", atom_key.c_str(), atom_value);
        }

        // Debugging goal state
        SPDLOG_DEBUG("Loading goal world state:");
        for (const auto& atom : data["goal_state"].items()) {
            const std::string& atom_key = atom.key();
            const bool atom_value = atom.value().get<bool>();

            // Log the goal state atom
            // SPDLOG_DEBUG("  {}: {}", atom_key, atom_value ? "true" : "false");

            goap_worldstate_set(&planner, &goalState, atom_key.c_str(), atom_value);
            SPDLOG_DEBUG("goap_worldstate_set(&planner, &goalState, {}, {})", atom_key.c_str(), atom_value);
        }

        SPDLOG_DEBUG("Finished loading world state\n");
    }

    // Function to find a Lua function by key in a table
    sol::protected_function find_function_in_table(sol::table& tbl, const std::string& func_name) {
        sol::protected_function func = tbl[func_name];  // Try to fetch the function by name
        if (func.valid() && func.get_type() == sol::type::function) {
            SPDLOG_DEBUG("Function '{}' found in table.", func_name);
            return func;
        } else {
            SPDLOG_DEBUG("Function '{}' not found in table.", func_name );
            return sol::lua_nil; // sol::nil works fine in windows?
        }
    }

    // Function to debug the result of a Lua function call. 
    // If the result is invalid, it will log the error message.
    auto debugLuaProtectedFunctionResult(sol::protected_function_result &result, std::string functionName) -> void {
        if (!result.valid()) {
            sol::error err = result;
            SPDLOG_ERROR("Error calling Lua function: {}", err.what());
        } else {
            SPDLOG_DEBUG("Lua function call to '{}' successful.", functionName);
        }
    }

    /**
     * The string identfier given will be used to refer to a table and find a
     * blackboard initialization function in the lua master state. If nothing is found, a default blackboard initialization function will be used.
     * Also clears the blackboard before initializing it.
     */
    auto runBlackboardInitFunction(entt::entity entity, std::string identifier) -> void {

        auto &goapStruct = globals::registry.get<GOAPComponent>(entity);
        goapStruct.blackboard.clear();

        // search in the master state for the right blackboard init function. If there is no match, use the default blackboard init function
        sol::table initTable = masterStateLua[globals::aiConfigJSON["blackboardInitTableName"].get<std::string>()]; 
        auto func = find_function_in_table(initTable, identifier);

        // get the default blackboard init function
        sol::protected_function defaultInitializationFunc = find_function_in_table(initTable, globals::aiConfigJSON["blackboardInitDefaultFunctionName"].get<std::string>());
        if (defaultInitializationFunc.valid() == false) {
            SPDLOG_ERROR("Default blackboard init function not found in table '{}'.", globals::aiConfigJSON["blackboardInitTableName"].get<std::string>());
        }

        if (func.valid()) {
            SPDLOG_DEBUG("Blackboard init function found for identifier '{}'.", identifier);
            // Call the function with the entity as an argument
            sol::protected_function_result result = func(entity);
            debugLuaProtectedFunctionResult(result, identifier);
        } else {
            SPDLOG_ERROR("Blackboard init function not found for identifier '{}'. Using default blackboard init function.", identifier);
            // Call the default blackboard init function
            sol::protected_function_result result = defaultInitializationFunc(entity);
            debugLuaProtectedFunctionResult(result, globals::aiConfigJSON["blackboardInitDefaultFunctionName"].get<std::string>());
        }
    }
    
    
    auto initGOAPComponent(entt::entity entity) -> void
    {
        auto &goapStruct = globals::registry.get<GOAPComponent>(entity);
        // clear the action planner
        goap_actionplanner_clear(&goapStruct.ap);

        // output should be like this:

/*

    [2024-09-13 21:00:10.031] [info] [ai_system.cpp:534] Action planner description: 
    wander:
        wandering:=1
    scout:
        wandering==1
        enemyvisible:=1
    attack:
        enemyvisible==1
        canfight==1
        enemyalive:=0   
    eat:
        hungry==1
        hungry:=0

    [2024-09-13 21:00:10.032] [info] [ai_system.cpp:536] plancost = 3
    [2024-09-13 21:00:10.032] [info] [ai_system.cpp:538]                        wandering,enemyvisible,CANFIGHT,ENEMYALIVE,hungry,
    [2024-09-13 21:00:10.032] [info] [ai_system.cpp:541] 0: wander              WANDERING,enemyvisible,CANFIGHT,ENEMYALIVE,hungry,
    [2024-09-13 21:00:10.032] [info] [ai_system.cpp:541] 1: scout               WANDERING,ENEMYVISIBLE,CANFIGHT,ENEMYALIVE,hungry,
    [2024-09-13 21:00:10.032] [info] [ai_system.cpp:541] 2: attack              WANDERING,ENEMYVISIBLE,CANFIGHT,enemyalive,hungry,

*/



        // load in actions from json
        load_actions_from_json(globals::aiActionsJSON, goapStruct.ap);

        // Initialize the current world state & Initialize the goal state
        goap_worldstate_clear(&goapStruct.current_state);
        goap_worldstate_clear(&goapStruct.goal);
        //TODO: these should probably be for the specific entity, not global
        load_worldstate_from_json(globals::aiWorldstateJSON, goapStruct.ap, goapStruct.current_state, goapStruct.goal);

        // Optional: Ensure the AI stays alive
        // goap_worldstate_set(&goapStruct.ap, &goapStruct.goal, "alive", true);

        select_goal(entity);
    }

    auto onGOAPComponentDestroyed(entt::registry &reg, entt::entity entity) -> void {
        // clear memory of goap strings (c-style, needs manual memory management)
        goap_actionplanner_clear_memory(&reg.get<GOAPComponent>(entity).ap);
        SPDLOG_DEBUG("GOAPComponent for entity {} destroyed, cleared memory.", static_cast<int>(entity));
    }

    // TODO: each entity type (humans, animals, etc) should have custom blackboard initialization functions in lua
    
    // TODO: make human entity def file

    // creature tags should be globally avaiable to lua scripts
    
    // make auto-init of goap component possible
    auto onGOAPComponentCreated(entt::registry &reg, entt::entity entity) -> void {
        // init component automatically
        initGOAPComponent(entity);
    }

    bool resetGOAPAndLuaStateRequested{false};

    /** 
     * Issues a LuaStateResetEvent to all systems when this takes place.
     */
    auto requestAISystemReset() -> void {
        SPDLOG_DEBUG("Requesting a reset of the AI system.");
        resetGOAPAndLuaStateRequested = true;
    }


    // Note that this should not be called from lua state, it will cause a crash. Operations like this should be queued and done later.
    auto resetAllGOAPComponentsAndScripting() -> void {


        SPDLOG_DEBUG("Resetting all GOAP components and reinitializing them.");
        // iterate over all entities with GOAPComponent and reset them
        std::vector<entt::entity> entitiesWithGOAP{};
        auto view = globals::registry.view<GOAPComponent>();
        for (auto entity : view) {
            // remove the goap component
            globals::registry.remove<GOAPComponent>(entity);
            entitiesWithGOAP.push_back(entity);
        }

        // now reset lua master state and initialize it again
        SPDLOG_DEBUG("Resetting Lua master state and re-loading scripts from disk.");
        masterStateLua = sol::state{};
        init();
        // re-init all the goap components
        for (auto entity : entitiesWithGOAP) {
            globals::registry.emplace<GOAPComponent>(entity);
        }

        event_system::Publish<LuaStateResetEvent>({&masterStateLua}); // this will update any other systems that need the master lua state
    }

    auto init() -> void
    {
        // debug message indicating that ai_system::init() was called
        SPDLOG_DEBUG("ai_system::init() called - doing nothing (goap inits on individual basis)");
        
        // get value of ai_tick_rate_seconds from config json and store it in aiUpdateTickInSeconds
        aiUpdateTickInSeconds = globals::configJSON["global_tick_settings"]["ai_tick_rate_seconds"];

        globals::registry.on_construct<GOAPComponent>().connect<&onGOAPComponentCreated>();
        globals::registry.on_destroy<GOAPComponent>().connect<&onGOAPComponentDestroyed>();

        // read in master lua state 
        std::string actionsDir = util::getAssetPathUUIDVersion(fmt::format("scripts/{}", globals::aiConfigJSON["actionsDirectory"].get<std::string>()));
        std::string worldstatesDir = util::getAssetPathUUIDVersion(fmt::format("scripts/{}", globals::aiConfigJSON["conditionsDirectory"].get<std::string>()));
        std::string logicDir = util::getAssetPathUUIDVersion(fmt::format("scripts/{}", globals::aiConfigJSON["logicDirectory"].get<std::string>()));
        std::string initBlackboardDir = util::getAssetPathUUIDVersion(fmt::format("scripts/{}", globals::aiConfigJSON["blackboardInitDirectory"].get<std::string>()));
        std::string tutorialDir = util::getAssetPathUUIDVersion(fmt::format("scripts/{}", globals::aiConfigJSON["tutorialDirectory"].get<std::string>()));

        std::vector<std::string> luaFiles{};

        // Iterate over all files in the directories
        getLuaFilesFromDirectory(actionsDir, luaFiles);
        getLuaFilesFromDirectory(worldstatesDir, luaFiles);
        getLuaFilesFromDirectory(logicDir, luaFiles);
        getLuaFilesFromDirectory(initBlackboardDir, luaFiles);
        getLuaFilesFromDirectory(tutorialDir, luaFiles);

        // run default initialization function
        initLuaMasterState(masterStateLua, luaFiles);

    }

void getLuaFilesFromDirectory(const std::string &actionsDir, std::vector<std::string> &luaFiles)
{
    for (const auto &entry : std::filesystem::directory_iterator(actionsDir))
    {
        std::string file_path = entry.path().string();
        // Check if the file has a .lua extension
        if (entry.path().extension() == ".lua")
        {
            // Normalize the path to use forward slashes
            std::replace(file_path.begin(), file_path.end(), '\\', '/');
            
            SPDLOG_DEBUG("Found Lua file: {}", file_path);
            // Add the Lua file to the list
            luaFiles.push_back(file_path);
        }
    }
}

    /**
     * Call this method after using astar_plan().
     * Checks if the GOAPComponent is dirty by comparing its current plan size with the initial plan buffer size. If there is a match or the plan size is zero,
     * the struct is considered not properly initialized.
     */
    void checkAndSetGOAPDirty(GOAPComponent& goapStruct, int initialPlanBufferSize) {
        if (goapStruct.planSize == 0 || goapStruct.planSize == initialPlanBufferSize || goapStruct.planCost == -1) { // -1 means not initialized
            goapStruct.dirty = true;
        } else {
            goapStruct.dirty = false;
        }
    }

    /**
     * Handles the situation when no plan can be found for the given GOAP component.
     * 
     * This function allows you to implement a strategy for when no plan can be found.
     * It provides an example of setting a fallback goal (e.g., wandering) and finding a plan using A* search algorithm.
     * If no plan is found, it suggests entering an idle state or default action.
     * 
     * @param goapStruct The GOAP component structure.
     */
    void handle_no_plan(entt::entity entity) {
        auto &goapStruct = globals::registry.get<GOAPComponent>(entity);
        
        // Implement your strategy for when no plan can be found

        // Example 1: Set a fallback goal (e.g., wandering)
        goap_worldstate_clear(&goapStruct.goal);
        goap_worldstate_set(&goapStruct.ap, &goapStruct.goal, "wandering", true);
        SPDLOG_DEBUG("No valid plan found, setting goal to wander and replanning.");
        replan(entity);

        if (goapStruct.planSize == 0) {
            // Still no plan found, perhaps enter an idle state or default action
            // Example: Log the error or set the creature to an idle state
            SPDLOG_DEBUG("- No valid plan found after attempting to enter wandering state.");
            // You can implement an idle behavior or log the issue here.
        }
    }


    /**
     * Selects a goal for the AI system based on the current state of the GOAPComponent.
     * If the creature is hungry, the goal is set to eat.
     * If an enemy is visible, the goal is set to attack the enemy.
     * If none of the above conditions are met, the default goal is set to wander.
     * After selecting the goal, a new plan is generated based on the selected goal.
     *
     * @param goapStruct A pointer to the GOAPComponent containing the current state and goal.
     */
    void select_goal(entt::entity entity) {
        
        auto table = masterStateLua[globals::aiConfigJSON["goalSelectionLogicTableName"].get<std::string>()];
        sol::protected_function selectGoal = table[globals::aiConfigJSON["goalSelectionLogicFunctionName"].get<std::string>()];

        sol::protected_function_result result = selectGoal(entity);

        if (!result.valid()) {
            sol::error err = result;
            SPDLOG_ERROR("{}: Error selecting goal: {}", static_cast<int>(entity), err.what());
            return;
        }

        // Generate a new plan based on the selected goal
        replan(entity);
    }

    // Execute the current action in the plan 
    // returns false if a replan is required
    bool execute_current_action(entt::entity entity) {
        // just call update on action queue, assuming nothing has changed in the world state
        auto result = run_action_queue(entity, aiUpdateTickInSeconds); // std::optional value

        // if this value is failure, it may mean the action is being retried. 
        // std::nullopt is the only indicator of replan required

        if (!result) { // std::nullopt means replan is required
            return false; // replan required
        }

        return true; // actions are running as intended
    }

    //LATER: make it possible for lua functions to be coroutines

    void fill_action_queue_based_on_plan(entt::entity e, const char** plan, int planSize) {
        auto &goapComponent = globals::registry.get<GOAPComponent>(e);
        
        // Clear the previous action queue
        while (!goapComponent.actionQueue.empty()) {
            goapComponent.actionQueue = std::queue<Action>();
        }
        
        // get the action name 
        // get the corresponding name of the lua file
        // read it in, store action sol::functions

        // Add actions to the queue using lua functions defined in ai_actions.json
        
        for (int i = 0; i < planSize; i++) {
            std::string actionName = plan[i];
            
            if (masterStateLua[actionName].valid() && masterStateLua[actionName].get_type() == sol::type::table) {
                // The table exists and is valid
            } else {
                // The table does not exist or is not a table
                SPDLOG_ERROR("Action {} not found in master state lua", actionName);
                continue;
            }
            
            sol::table action_table = masterStateLua[actionName]; // get the lua table for the action, defined in action_name.lua
            
            Action action{};
            
            // Define the start behavior
            action.start = action_table["start"];
            action.update = action_table["update"];
            action.finish = action_table["finish"];

            action.is_running = false;

            // Push the action into the queue
            goapComponent.actionQueue.push(action);
        }

        // Start the first action if the queue is not empty
        if (!goapComponent.actionQueue.empty()) {
            goapComponent.actionQueue.front().start(e);
            goapComponent.actionQueue.front().is_running = true;
        }
    }

    
    /**
     * Updates the current action in the GOAPComponent.
     * 
     * @param goapComponent The GOAPComponent containing the action queue.
     * @param deltaTime The time elapsed since the last update.
     * @return The result of the action. Empty if action queue is invalid or only start() was called, otherwise the result of the action from running the update() method. Empty return (std::nullopt) indicates that the plan must be re-planned.
     */
    std::optional<Action::Result> run_action_queue(entt::entity entity, float deltaTime) {
        auto &goapComponent = globals::registry.get<GOAPComponent>(entity);
        
        if (goapComponent.actionQueue.empty()) {
            SPDLOG_DEBUG("Action queue is empty");
            return std::nullopt;
        }

        Action& currentAction = goapComponent.actionQueue.front();
        if (!currentAction.is_running) {
            SPDLOG_DEBUG("Current action is not running");
            return std::nullopt;
        }
        
        // turn into isolated coroutine
        goapComponent.currentUpdateCoroutine = currentAction.update;
        
        // we run update() as a coroutine to let it call methods like wait(i)
        sol::coroutine &updateCoroutine = goapComponent.currentUpdateCoroutine;
        
        // coroutine can return an action result or simply yield.
        auto luaResult = updateCoroutine(entity, deltaTime);
        if (luaResult.valid() == false ) {
            // An error has occured
            sol::error err = luaResult;
            std::string what = err.what();
            SPDLOG_ERROR("Return value error in action update: {}", what);
        }
        
        // if the coroutine has yielded, return running
        if (luaResult.status() == sol::call_status::yielded) {
            SPDLOG_DEBUG("Action {} is still running (yielded)", goapComponent.plan[goapComponent.current_action]);
            return Action::Result::RUNNING;
        }
        
        // coroutine has not yielded, get result value
        
        Action::Result result = luaResult.get<Action::Result>();

        // move on to next action if current action is successful
        if (result == Action::Result::SUCCESS) {
            SPDLOG_DEBUG("Action {} completed, calling start() on next action", goapComponent.plan[goapComponent.current_action]);

            currentAction.finish(entity);
            goapComponent.actionQueue.pop();

            // Reset retries on success
            goapComponent.retries = 0;

            // set postconditions
            auto postConditions = allPostconditionsForEveryAction[goapComponent.plan[goapComponent.current_action]];
            for (const auto& postCondition : postConditions) {
                const std::string post_key = postCondition.first;
                const bool post_value = postCondition.second;
                goap_worldstate_set(&goapComponent.ap, &goapComponent.current_state, post_key.c_str(), post_value);
                SPDLOG_DEBUG("Automatically setting postcondition {} to {}", post_key, post_value);
            }

            // Move to the next action
            goapComponent.current_action++;

            // run next action start if available
            if (!goapComponent.actionQueue.empty()) {
                goapComponent.actionQueue.front().start(entity);
                goapComponent.actionQueue.front().is_running = true;
            }
            else {
                SPDLOG_DEBUG("Action queue is now empty");
            }
        } 
        // upon failure, retry X number of times by calling start() again
        else if (result == Action::Result::FAILURE) {
            goapComponent.retries++;
            if (goapComponent.retries >= goapComponent.max_retries) {
                // If retries exceed max_retries, re-plan
                SPDLOG_DEBUG("Maximum retries exceeded, re-planning...");
                return std::nullopt; // this will force caller to replan
            }
            SPDLOG_DEBUG("Action {} failed, retrying", goapComponent.plan[goapComponent.current_action]);
            // reset blackboard and rerun start REVIEW: re-attempting an action shouldn't reset the blackboard, right?
            // goapComponent.blackboard.clear();
            // goapComponent.blackboardInit(goapComponent.blackboard);
            goapComponent.actionQueue.front().start(entity);
        }
        else {
            SPDLOG_DEBUG("Action {} is still running", goapComponent.plan[goapComponent.current_action]);
        }
        // let caller know the result of the action too
        return result;
    }

    // called when an entity's action is interrupted, replans the action queue
    // LATER: This should also be triggered (with replan) by events that interrupt the entities, after world state is also updated. When  an entity is interrupted, it should wait for a bit before replanning, for instance
    void on_interrupt(entt::entity entity) {
        auto &goapComponent = globals::registry.get<GOAPComponent>(entity);
        
        // clear the action queue
        while (!goapComponent.actionQueue.empty()) {
            goapComponent.actionQueue.pop();
        }

        // clear the blackboard
        runBlackboardInitFunction(entity, "creature_kobold"); //FIXME: placeholder value, these should come from the entity type (file)
        
        //LATER: take whatever interruption it was into account - how?
        
        // select new goal
        select_goal(entity);
    }
    
    //TODO: some method ideas: showTutorialMessageBox(), showTutorialHighlightCircle()

    // Update the GOAP logic within the game loop
    void update_goap(entt::entity entity) {

        // check if reset of all GOAP components and lua state is requested
        if (resetGOAPAndLuaStateRequested) {
            resetAllGOAPComponentsAndScripting();
            resetGOAPAndLuaStateRequested = false;
        }
        
        auto &goapStruct = globals::registry.get<GOAPComponent>(entity);

        // Execute the current action and check if it succeeded
        bool plan_is_running_valid = execute_current_action(entity);
        bool is_goap_info_valid = goap_is_goapstruct_valid(goapStruct);

        runWorldStateUpdaters(entity);

        //TODO: custom intial state for each entity type?

        //TODO: use some commibnation of lua and json to dynamically initialize entities?
        
        //TODO: string identifier for entity type from json file, use this to custom init blackboard + worldstate + goalstate

        //TODO: make a demo for creature init
        
        // Check if re-planning is necessary based on action failure or mismatch with expected state / plan is empty
        if (is_goap_info_valid == false && plan_is_running_valid == false) { // plan might be running one action, but plan can be empty otherwise
            SPDLOG_DEBUG("GOAP plan is empty, re-selecting goal...");
            select_goal(entity);
        }
        // if plan is running, but the world state has changed since the plan was made, then replan
        else if ((plan_is_running_valid && goapStruct.current_action < goapStruct.planSize)) {
            if (!goap_worldstate_match(&goapStruct.ap, goapStruct.current_state, goapStruct.cached_current_state)) {
                SPDLOG_DEBUG("World state has changed, re-planning required...");
                // print current state
                char desc[ 4096 ];
                goap_worldstate_description(&goapStruct.ap, &goapStruct.current_state, desc, sizeof(desc));
                SPDLOG_DEBUG("Current world state: {}", desc);
                // compare to next state
                goap_worldstate_description(&goapStruct.ap, &goapStruct.cached_current_state, desc, sizeof(desc));
                SPDLOG_DEBUG("Cached current state: {}", desc);
                select_goal(entity); 
            }
        }
        // the plan is no longer valid (running actions encountered an error)
        else if (plan_is_running_valid == false) {
            // If the plan is not running, re-plan
            SPDLOG_DEBUG("Plan is not running properly, re-planning...");
            select_goal(entity);
        }

        // update cached state
        goapStruct.cached_current_state = goapStruct.current_state; 
        
        // debug output of current plan and world state
        debugPrintGOAPStruct(goapStruct);
    }

    void runWorldStateUpdaters(entt::entity &entity)
    {
        // update world state using the condition updaters
        std::string updateFunctionTable = globals::aiConfigJSON["worldstateUpdaterTable"].get<std::string>();

        sol::table worldstateUpdaterTable = masterStateLua[updateFunctionTable];

        // Iterate through the table and invoke each and every function
        for (auto &pair : worldstateUpdaterTable)
        {
            sol::object key = pair.first;    // key
            sol::object value = pair.second; // value (which should be a function)

            if (value.is<sol::function>() == false)
                continue;

            SPDLOG_DEBUG("Executing worldstate update function: {}", key.as<std::string>());
            sol::protected_function func = value.as<sol::function>();
            // Call the function in a protected manner
            sol::protected_function_result result = func(entity, aiUpdateTickInSeconds); // Call the Lua function
            // Check if the function call resulted in an error

            if (result.valid())
                continue;

            // Capture the error message
            sol::error err = result;
            std::string error_message = err.what();
            SPDLOG_DEBUG("Error executing worldstate update function: {}", error_message);
        }
    }

    void debugPrintGOAPStruct(GOAPComponent &goapStruct)
    {
        char desc[4096];
        SPDLOG_DEBUG("(UPPERCASE=true, lowercase=false; default action cost=1)");
        SPDLOG_DEBUG("plancost = {}", goapStruct.planCost);
        goap_worldstate_description(&goapStruct.ap, &goapStruct.current_state, desc, sizeof(desc));
        SPDLOG_DEBUG("Initial worldstate {:<23}{}", "", desc);
        if (goapStruct.planSize == 0)
        {
            SPDLOG_DEBUG("No plan found");
            return;
        }
        SPDLOG_DEBUG("==PLAN START==");
        // output plan (if there is none, nothing will print)
        for (int i = 0; i < goapStruct.planSize && i < 16; ++i)
        {
            goap_worldstate_description(&goapStruct.ap, &goapStruct.states[i], desc, sizeof(desc));
            SPDLOG_DEBUG("{}: {:<20}{}", i, goapStruct.plan[i], desc);
        }
        SPDLOG_DEBUG("==PLAN END==");
    }


    /*
    * @brief Generates a map where the key is the atom name (string) and the value is its boolean state.
    * This function returns a std::map<std::string, bool> that describes the current world state.
    */
    std::map<std::string, bool> goap_worldstate_to_map(const actionplanner_t* ap, const worldstate_t* ws)
    {
        std::map<std::string, bool> result;  // Map to store atom name and its boolean value

        for (int i = 0; i < MAXATOMS; ++i)
        {
            // If we care about this atom (dontcare flag is not set)
            if ((ws->dontcare & (1LL << i)) == 0LL)
            {
                const char* atomname = ap->atm_names[i];
                if (atomname == NULL) continue; // Skip if atomname is null

                // Check if the value in the world state is set (true or false)
                bool value = (ws->values & (1LL << i)) != 0LL;

                // Insert the atom name and its value into the map
                result[atomname] = value;
            }
        }

        return result;  // Return the map of atom names and their boolean values
    }

    /**
     * Replans the actions for the given GOAPComponent.
     *
     * @param goapStruct The GOAPComponent to replan.
     */
    void replan(entt::entity entity)
    {
        auto &goapStruct = globals::registry.get<GOAPComponent>(entity);
        
        goapStruct.planSize = globals::MAX_ACTIONS;
        goapStruct.planCost = astar_plan(&goapStruct.ap, goapStruct.current_state, goapStruct.goal, goapStruct.plan, goapStruct.states, &goapStruct.planSize);
        char desc[ 4096 ];
        goap_description( &goapStruct.ap, desc, sizeof(desc) );
        SPDLOG_DEBUG("replan() called for entity {}", static_cast<int>(entity));
        // SPDLOG_INFO("Action planner description: {}", desc);

        // SPDLOG_INFO("plancost = {}", goapStruct.planCost);
        // goap_worldstate_description(&goapStruct.ap, &goapStruct.current_state, desc, sizeof(desc));
        // SPDLOG_INFO("{:<23}{}", "", desc);
        // for (int i = 0; i < goapStruct.planSize && i < 16; ++i) {
        //     goap_worldstate_description(&goapStruct.ap, &goapStruct.states[i], desc, sizeof(desc));
        //     SPDLOG_INFO("{}: {:<20}{}", i, goapStruct.plan[i], desc);
        // }
        
        goapStruct.current_action = 0;
        goapStruct.retries = 0; // Reset retries after re-planning
        checkAndSetGOAPDirty(goapStruct, globals::MAX_ACTIONS);
        if (goapStruct.dirty == false) {
            // clear and reinit the blackboard
            runBlackboardInitFunction(entity, "creature_kobold"); //FIXME: placeholder value, these should come from the entity type (file)

            fill_action_queue_based_on_plan(entity, goapStruct.plan, goapStruct.planSize);

            // update cached state
            goapStruct.cached_current_state = goapStruct.current_state;
        }
        else {
            SPDLOG_ERROR("Call to replan() produced no plan... There are no actions to take.");

            handle_no_plan(entity);  // Call a function to handle this scenario
        }

    }

    auto updateHumanAI(float deltaTime) -> void
    {
        
        // add deltaTime to aiUpdateTickTotal
        aiUpdateTickTotal += deltaTime;
        
        // if aiUpdateTickTotal is greater than aiUpdateTickInSeconds
        // then we need to tick the ai
        if (aiUpdateTickTotal < aiUpdateTickInSeconds) return;

        SPDLOG_DEBUG("---------- ai_system:: new goap ai tick ------------------");
        // reset aiUpdateTickTotal
        aiUpdateTickTotal = 0.0f;
        
        // get all humans
        auto view = globals::registry.view<GOAPComponent>();
        
        for (auto entity : view)
        {
            // get the human entity
            auto& goapStruct = view.get<GOAPComponent>(entity);
            
            SPDLOG_DEBUG("Updating AI for entity: {}", static_cast<int>(entity)); 

            // update the goap logic
            update_goap(entity);
        }

    }
}