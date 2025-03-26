#include "event_system.hpp"
#include "../../util/common_headers.hpp"

namespace event_system {

    MyEmitter emitter{};
    
    // Map to link Lua event names to C++ event types
    std::unordered_map<std::string, std::function<void(sol::table)>> luaToCppEventMap{};

    // Map to handle Lua-defined events: string-based event names to a vector of Lua functions
    std::unordered_map<std::string, std::vector<sol::function>> luaEventListeners{};

    // Map to handle C++ listeners for Lua-defined events
    std::unordered_map<std::string, std::vector<std::function<void(sol::table)>>> cppEventListenersToLuaEvents{};

    // Event tracking map
    std::unordered_map<std::string, bool> eventOccurredMap{};

    // Event tracking payload map (for lua events)
    std::unordered_map<std::string, sol::table> eventOccurredPayloadMap{};


    // Mark an event as having occurred. This will be cleared lua-side after being polled
    void markEventAsOccurred(const std::string& eventName, sol::table payload) {
        eventOccurredMap[eventName] = true;  // This could be done via sol::state if necessary
        eventOccurredPayloadMap[eventName] = payload;
        SPDLOG_DEBUG("Marked event {} as occurred with payload", eventName);

    }
    
    // REVIEW: event flags are cleared after being polled via lua
    // Getter function for accessing the eventOccurredMap from Lua
    std::tuple<bool, sol::table> getEventOccurred(const std::string& eventName) {
        
        if (eventOccurredMap.find(eventName) == eventOccurredMap.end()) 
        {
            // SPDLOG_DEBUG("getEventOccurred: Event {} not found", eventName);
            return {false, sol::lua_nil};  // Return false if the event is not found
            
        }

        if (eventOccurredMap[eventName] == false) {
            // SPDLOG_DEBUG("getEventOccurred: Event {} has not occurred", eventName);
            return {false, sol::lua_nil};  // Return false if the event has not occurred
            
        }

        if (eventOccurredPayloadMap.find(eventName) != eventOccurredPayloadMap.end()) {
            // SPDLOG_DEBUG("getEventOccurred: Event {} has occurred with payload", eventName);
            return {true, eventOccurredPayloadMap[eventName]};  // Return the payload if the event is found
        
        }
        // SPDLOG_DEBUG("getEventOccurred: Event {} has occurred with no payload", eventName);        
        return {true, sol::lua_nil};  // Return true if the event has occurred, no payload
    }

    // Setter function for modifying the eventOccurredMap from Lua
    void setEventOccurred(const std::string& eventName, bool status) {
        eventOccurredMap[eventName] = status;

        // if status is false, clear the payload
        if (status == false) {
            eventOccurredPayloadMap.erase(eventName);
        }
    }
    
    // Initialize event map: maps Lua event names to C++ event handlers TODO: turn this into fully configurable system
    void initializeEventMap(sol::state& lua) {
        luaToCppEventMap["player_jumped"] = [](sol::table data) {
            PlayerJumped event{
                data["player_name"]
            };
            Publish(event);  // Publish C++ event
        };

        luaToCppEventMap["player_died"] = [](sol::table data) {
            PlayerDied event{
                data["player_name"],
                data["cause_of_death"]
            };
            Publish(event);  // Publish C++ event
        };

        // To add new events:
        // 1. Define the C++ struct for the event.
        // 2. Map the Lua event string to a lambda here.
        // 3. The lambda converts Lua data to a C++ event and publishes it.
    }

    void subscribeToLuaEvent(const std::string& eventType, std::function<void(sol::table)> callback) {
        cppEventListenersToLuaEvents[eventType].push_back(callback);
    }

    // Publish a Lua-defined event: Loops through all listeners and calls them
    void publishLuaEvent(const std::string& eventType, sol::table data) {
        if (luaEventListeners.find(eventType) != luaEventListeners.end()) {
            for (auto& listener : luaEventListeners[eventType]) {
                listener(data);  // Call each listener with the event data
            }
        } else {
            SPDLOG_DEBUG("No lua listeners for Lua event: {}", eventType);
        }


        //TODO: unit test this function and the subscribe function
        // Notify C++ listeners
        if (cppEventListenersToLuaEvents.find(eventType) != cppEventListenersToLuaEvents.end()) {
            for (auto& listener : cppEventListenersToLuaEvents[eventType]) {
                listener(data);  // Call each C++ listener with the event data
            }
        } else {
            SPDLOG_DEBUG("No C++ listeners for Lua event: {}", eventType);
        }
        
        markEventAsOccurred(eventType, data);
    }

    // Function to reset listeners for a specific Lua event
    void resetListenersForLuaEvent(const std::string& eventType) {
        // Clear Lua listeners for the specified event
        if (luaEventListeners.find(eventType) != luaEventListeners.end()) {
            luaEventListeners.erase(eventType);
            SPDLOG_DEBUG("Lua listeners reset for event: {}", eventType);
        } else {
            SPDLOG_DEBUG("No Lua listeners found for event: {}", eventType);
        }

        // Clear C++ listeners for the specified event
        if (cppEventListenersToLuaEvents.find(eventType) != cppEventListenersToLuaEvents.end()) {
            cppEventListenersToLuaEvents.erase(eventType);
            SPDLOG_DEBUG("C++ listeners reset for event: {}", eventType);
        } else {
            SPDLOG_DEBUG("No C++ listeners found for event: {}", eventType);
        }
    }
    

    // Function to expose event system to Lua
    // Note that additional event types from C++ side must be added here manually as well
    void exposeEventSystemToLua(sol::state& lua) {
        // Subscribe to C++ events from Lua
        lua.set_function("subscribeToCppEvent", [](const std::string& eventType, sol::function listener) {
            if (eventType == "player_jumped") {
                Subscribe<PlayerJumped>(
                    [listener](const PlayerJumped& event, MyEmitter&) {
                        listener(event.player_name);  // Call Lua listener
                    }
                );
            } else if (eventType == "player_died") {
                Subscribe<PlayerDied>(
                    [listener](const PlayerDied& event, MyEmitter&) {
                        listener(event.player_name, event.cause_of_death);  // Call Lua listener
                    }
                );
            }
        });

        // Publish C++ events from Lua
        lua.set_function("publishCppEvent", [](const std::string& eventType, sol::table data) {
            if (luaToCppEventMap.find(eventType) != luaToCppEventMap.end()) {
                luaToCppEventMap[eventType](data);  // Publish mapped C++ event
                markEventAsOccurred(eventType, data);
            } else {
                SPDLOG_DEBUG("Unknown C++ event type: {}", eventType);
            }
        });

        //TODO: unit test this
        // Expose function for Lua-defined events
        lua.set_function("subscribeToLuaEvent", [](const std::string& eventType, sol::function listener) {
            luaEventListeners[eventType].push_back(listener);
        });

        // Publish Lua-defined events
        lua.set_function("publishLuaEvent", [](const std::string& eventType, sol::table data) {
            publishLuaEvent(eventType, data);  // Call all listeners for this Lua-defined event
        });
        
        // Wrapper for publish lua event but with no arguments (for console)
        lua.set_function("publishLuaEventNoArgs", [](const std::string& eventType) {
            sol::table data = sol::lua_nil;
            publishLuaEvent(eventType, data);  // Call all listeners for this Lua-defined event
        });

        lua.set_function("resetListenersForLuaEvent", &resetListenersForLuaEvent);

        // Reset listeners for a specific C++ event type (from Lua)
        lua.set_function("resetListenersForCppEvent", [](const std::string& eventType) {
            if (eventType == "player_jumped") {
                ResetListenersForSpecificEvent<PlayerJumped>();
            } else if (eventType == "player_died") {
                ResetListenersForSpecificEvent<PlayerDied>();
            }
            // Add reset for other C++ event types as necessary
        });

        // Clear all listeners (from Lua)
        lua.set_function("clearAllListeners", []() {
            ClearAllListeners();
        });

        // Getter for eventOccurredMap
        lua.set_function("getEventOccurred", &getEventOccurred);

        // Setter for eventOccurredMap
        lua.set_function("setEventOccurred", &setEventOccurred);
    }
}
