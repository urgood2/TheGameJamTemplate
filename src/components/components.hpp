// File for general-purpose components.

#pragma once

#include "raylib.h"
#include "entt/entt.hpp" // ECS

#include "../third_party/GPGOAP/goap.h"

#include "sol/sol.hpp"

#include <string>
#include <vector>
#include <map>
#include <functional>
#include <queue>
#include <iostream>
#include <unordered_map>
#include <any>

// ! component usage index
/*
 * Tile :
 *   TileComponent, SpriteComponentASCII, LocationComponent
 * Humans:
 *   SpriteComponentASCII, LocationComponent  
    
 * 
*/

// used by lua classs ported over to c++
struct TransformCustom {
	float x = 0.0f;    // X position of the Node
	float y = 0.0f;    // Y position of the Node
	float w = 1.0f;    // Width of the Node
	float h = 1.0f;    // Height of the Node
	float r = 0.0f;    // Rotation angle of the Node (in radians)
	float scale = 1.0f; // Scale of the Node, for effects like pulsing
};


// --------------------------------------------------------
// ------------------ GOAP AI COMPONENTS ------------------
// --------------------------------------------------------
struct GOAPComponent;

// Used to store variables between actions for separate entities with a string identifier
class Blackboard {
public:
    // Set a value in the blackboard
    template<typename T>
    void set(const std::string& key, const T& value) {
        data[key] = value;
    }

    // Get a value from the blackboard (returns std::any)
    template<typename T>
    T get(const std::string& key) const {
        if (data.find(key) != data.end()) {
            return std::any_cast<T>(data.at(key));
        }
        throw std::runtime_error("Key not found");
    }

    // Check if a key exists in the blackboard
    bool contains(const std::string& key) const {
        return data.find(key) != data.end();
    }

    // Check the number of items in the blackboard
    std::size_t size() const {
        return data.size();
    }

    // Check if the blackboard is empty
    bool isEmpty() const {
        return data.empty();
    }

    // Clear all items from the blackboard
    void clear() {
        data.clear();
    }

private:
    std::unordered_map<std::string, std::any> data;  // Key-value store for variables
};

// holds the modular "actions" that the AI can take
struct Action {
    enum class Result { // contains the result of the action
        SUCCESS,
        FAILURE,
        RUNNING
    };
    
    sol::function start; // Function to run when the action starts
    sol::function update; // Function to run every frame until action is complete - SUCCESS if action is complete
    sol::function finish; // Function to run when the action ends
    
    bool is_running = false;
};

struct GOAPComponent
{
    actionplanner_t ap;
    worldstate_t cached_current_state; // for keeping track of the current state & any changes made to it
    worldstate_t current_state;
    worldstate_t goal;
    const char* plan[64];
    worldstate_t states[64];
    int planSize;
    int planCost;
    int current_action;
    int retries; // Number of retries for the current action
    int max_retries = 3; // Maximum number of retries before re-planning
    bool dirty = true; // If the plan is dirty/unintialized and needs to be re-planned

    Blackboard blackboard;

    // queue created from a goap plan
    std::queue<Action> actionQueue;
    
    // New field to store the current action's update() coroutine
    sol::coroutine currentUpdateCoroutine;
};

// --------------------------------------------------------
// ------------------ END GOAP AI COMPONENTS --------------
// --------------------------------------------------------

struct TileComponent
{
    /* Tile-specific data */
    std::string tileID{}; //  from environment.json
    bool isImpassable{false}; //  from environment.json
    bool blocksLight{false}; //  TODO: add to environment.json
    std::vector<entt::entity> entitiesOnTile{}; // maintained list of entities on the tile. When entities are added to the registry or their lcoation component is updated (via replace), a listener will remove/add to the list of the relevant tiles and fire off entity moved off tile/entered tile listeners (this to be implemented later). This will help keep entity lists in each tile up to date, and entity queries efficient
    std::vector<entt::entity> liquidsOnTile{}; // separate list for liquids, such as blood
    std::vector<entt::entity> taskDoingEntitiesOnTile{}; // entities that can do tasks are maintained in a separate list for visibility
    std::string replacementOnDestroy{}; // environment.json
    bool isDestructible{false}; // environment.json
    bool canBeMadeIntoMulch{false}; // environment.json

    entt::entity taskDoingEntityTransition{entt::null}; // contains an animation queue component for transitioning between task doing entities

    const float taskDoingEntityDrawCycleTime{3.0f}; // time in seconds to cycle through task doing entities on the tile
    bool isDisplayingTaskDoingEntityTransition{false}; // if true, the tile will show an animation transitioning between task doing entities
    float taskDoingEntityDrawCycleTimer{0}; // used to cycle through task doing entities on the tile
    int taskDoingEntityDrawIndex{0}; // used to determine which task doing entity on the tile should be drawn (if there are any, it will cycle through them)

    const float itemOnTileDrawCycleTime{2.0f}; // time in seconds to cycle through items on the tile
    float itemOnTileDrawCycleTimer{0}; // used to cycle through items on the tile
    int itemDrawIndex{0}; // used to determine which item on the tile should be drawn (if there are any, it will cycle through them)

    const float liquidOnTileDrawCycleTime{2.0f}; // time in seconds to cycle through liquids on the tile
    float liquidOnTileDrawCycleTimer{0}; // used to cycle through liquids on the tile
    int liquidDrawIndex{0}; // used to determine which liquid on the tile should be drawn (if there are any, it will cycle through them)
};

struct LocationComponent
{
    float x{}, y{};
    std::string regionIdentifier{}; // "hill of vanishing," etc
    float prevX{}, prevY{}; // keep track of previous position for when location is changed (for tile updating)
};

struct NinePatchComponent 
{
    Texture2D texture{};
    NPatchInfo nPatchInfo{};
    float alpha{1.0f};
    Color fgColor{};
    Color bgColor{};
    Rectangle destRect{};

    float timeToLive{0}; // if this is set to a value greater than 0, the ninepatch will be destroyed after this time
    float timeAlive{0}; // time the ninepatch has been alive

    // Blinking properties
    bool blinkEnabled = true;
    float blinkInterval = 0.5f; // Time interval for blinking (in seconds)
    float blinkTimer = 0.0f;
    bool isVisible = true;
};

struct ContainerComponent
{
    std::vector<entt::entity> items{};
};

// contains id, name, desc
struct InfoComponent
{
    std::string id{}, name{}, desc{};
};


struct VFXComponent
{
};


