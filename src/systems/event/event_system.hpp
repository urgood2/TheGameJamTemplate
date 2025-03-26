#pragma once

#include "entt/entt.hpp"
#include <sol/sol.hpp>
#include <unordered_map>
#include <string>
#include <iostream>
#include <vector>

// Usage in C++:
// event_system::Subscribe<event_system::PlayerJumped>([](const event_system::PlayerJumped& event) {
//     // do something
// });
// event_system::Publish(event_system::PlayerJumped{});
// event_system::ResetListenersForSpecificEvent<event_system::PlayerJumped>();
// event_system::ClearAllListeners();

namespace event_system {

    class MyEmitter : public entt::emitter<MyEmitter> {
    };

    extern MyEmitter emitter;

    // Basic event definition for PlayerJumped (C++-defined event)
    struct PlayerJumped {
        std::string player_name;
    };

    // Add additional event definitions here as needed (C++-defined events)
    struct PlayerDied {
        std::string player_name;
        std::string cause_of_death;
    };

    // Map to link Lua event names to C++ event types
    extern std::unordered_map<std::string, std::function<void(sol::table)>> lua_to_cpp_event_map;

    // Map to handle Lua-defined events: string-based event names to a vector of Lua functions
    extern std::unordered_map<std::string, std::vector<sol::function>> luaEventListeners;

    
    // Map to handle C++ listeners for Lua-defined events
    extern std::unordered_map<std::string, std::vector<std::function<void(sol::table)>>> cppEventListenersToLuaEvents;

    // Subscribe to C++ events using lambdas. 

    /**
     * @brief Subscribe to a specific event type using a lambda function.
     * Sample usage:
     * ```
     * event_system::Subscribe<ai_system::LuaStateResetEvent>([this](const ai_system::LuaStateResetEvent &event, event_system::MyEmitter&) {
            tutorial_system_v2::resetTutorialSystem();
        });
     * ```
     */
    template <typename Event, typename Listener>
    void Subscribe(Listener&& listener) {
        emitter.template on<Event>(std::forward<Listener>(listener));
    }

    // Publish C++ events
    template <typename Event>
    void Publish(Event&& event) {
        emitter.template publish<Event>(std::forward<Event>(event));
    }

    // Reset listeners for a specific event type
    template <typename Event>
    void ResetListenersForSpecificEvent() {
        emitter.template erase<Event>();
    }

    // Clear all listeners
    inline void ClearAllListeners() {
        emitter.clear();
        luaEventListeners.clear();  // Also clear Lua-defined event listeners
        cppEventListenersToLuaEvents.clear();  // Clear C++ listeners for Lua-defined events
    }
    
    extern void initializeEventMap(sol::state& lua);
    extern void exposeEventSystemToLua(sol::state& lua);
    extern void subscribeToLuaEvent(const std::string& eventType, std::function<void(sol::table)> callback);
    extern void publishLuaEvent(const std::string& event_type, sol::table data);
    extern void resetListenersForLuaEvent(const std::string& eventType);
    extern void markEventAsOccurred(const std::string& eventName, sol::table payload);
    extern std::tuple<bool, sol::table> getEventOccurred(const std::string& eventName);
    extern void setEventOccurred(const std::string& eventName, bool status);
}

/**
 *  Lua Custom Events Usage Example:
 *
 *  In Lua, you can create custom events and handle them using the following functions:
 *
 *  1. **subscribe_to_lua_event**:
 *     - This function allows you to define a custom event and attach a listener to it.
 *     - The listener is a Lua function that will be called whenever the event is published.
 *
 *     Example usage:
 *     ```lua
 *     -- Subscribe to a custom Lua event "enemy_defeated"
 *     subscribe_to_lua_event("enemy_defeated", function(data)
 *         print("Enemy defeated: " .. data.enemy_name .. " by " .. data.player_name)
 *     end)
 *     ```
 *
 *  2. **publish_lua_event**:
 *     - This function allows you to publish a custom Lua event and pass data (as a table) to the listeners.
 *     - All listeners that subscribed to the event will be called.
 *
 *     Example usage:
 *     ```lua
 *     -- Publish the "enemy_defeated" event with event data
 *     publish_lua_event("enemy_defeated", { enemy_name = "Orc", player_name = "Hero" })
 *     ```
 *
 *  3. **subscribe_to_cpp_event**:
 *     - You can also subscribe to events that are defined in C++ and respond to them in Lua.
 *     - Use the `subscribe_to_cpp_event` function to attach a Lua function to a C++ event.
 *
 *     Example usage:
 *     ```lua
 *     -- Subscribe to the "player_jumped" event (C++ event)
 *     subscribe_to_cpp_event("player_jumped", function(player_name)
 *         print("Player jumped: " .. player_name)
 *     end)
 *     ```
 *
 *  4. **publish_cpp_event**:
 *     - Similarly, you can publish C++ events from Lua using `publish_cpp_event`.
 *     - You need to pass the event type and the data for the event as a Lua table.
 *
 *     Example usage:
 *     ```lua
 *     -- Publish the "player_jumped" event from Lua
 *     publish_cpp_event("player_jumped", { player_name = "John Doe" })
 *     ```
 *
 *  5. **reset_listeners_for_cpp_event**:
 *     - This function resets all listeners for a specific C++ event.
 *
 *     Example usage:
 *     ```lua
 *     -- Reset listeners for the "player_jumped" event
 *     reset_listeners_for_cpp_event("player_jumped")
 *     ```
 *
 *  6. **clear_all_listeners**:
 *     - You can clear all listeners for both Lua-defined and C++ events using this function.
 *
 *     Example usage:
 *     ```lua
 *     -- Clear all listeners for both Lua-defined and C++ events
 *     clear_all_listeners()
 *     ```
 */
