---@meta

---
--- Bindings for chugget's c++ code, for use with lua.
---
-- version: 0.1
---@class chugget.engine

---
--- Retrieves the ScriptComponent for a given entity ID.
---
---@param entity_id integer
---@return ScriptComponent
function get_script_component(...) end

---
--- Requests a full reset of the AI system state.
---
---@return nil
function hardReset(...) end

---
--- Subscribes a Lua listener to named C++ events.
---
---@param eventType 'player_jumped'|'player_died' # The C++ event name.
---@param listener CppEvent_PlayerJumped|CppEvent_PlayerDied # Lua callback. Signature depends on eventType.
---@return nil
function subscribeToCppEvent(...) end

---
--- Publishes a Lua table as a C++ event and records its occurrence.
---
---@param eventType string # The C++ event name.
---@param data table       # Payload fields as a Lua table.
---@return nil
function publishCppEvent(...) end

---
--- Subscribes a Lua listener to a Lua-defined event.
---
---@param eventType string # The Lua event name.
---@param listener LuaEventListener # Callback invoked when the event fires.
---@return nil
function subscribeToLuaEvent(...) end

---
--- Publishes a Lua-defined event with a data table.
---
---@param eventType string # The Lua event name.
---@param data table       # Payload table passed to listeners.
---@return nil
function publishLuaEvent(...) end

---
--- Publishes a Lua-defined event with no arguments.
---
---@param eventType string # The Lua event name.
---@return nil
function publishLuaEventNoArgs(...) end

---
--- Clears all listeners for the specified Lua-defined event.
---
---@param eventType string # The Lua event name.
---@return nil
function resetListenersForLuaEvent(...) end

---
--- Clears all listeners for the specified C++ event type.
---
---@param eventType string # The C++ event type name.
---@return nil
function resetListenersForCppEvent(...) end

---
--- Removes all registered event listeners (both C++ and Lua).
---
---@return nil
function clearAllListeners(...) end

---
--- Returns whether the given event has occurred and its data.
---
---@param eventType string # The event name.
---@return boolean occurred, table|nil payload # True if the event has fired, and its payload.
function getEventOccurred(...) end

---
--- Manually marks an event as occurred (or not).
---
---@param eventType string  # The event name.
---@param occurred boolean # Whether to mark it occurred or not.
---@return nil
function setEventOccurred(...) end

---
--- Enables or disables tutorial mode.
---
---@param active boolean # Whether to activate tutorial mode
---@return nil
function setTutorialModeActive(...) end

---
--- Resets the tutorial system to its initial state.
---
---@return nil
function resetTutorialSystem(...) end

---
--- Displays a tutorial window with the provided text.
---
---@param text string # Tutorial content text to display.
---@return nil
function showTutorialWindow(...) end

---
--- Displays a tutorial window with selectable options.
---
---@param text string # Tutorial content to display.
---@param options string[] # An array-style table of button labels.
---@return nil
function showTutorialWindowWithOptions(...) end

---
--- Begins the specified tutorial coroutine if it is defined.
---
---@param tutorialName string # The name of the tutorial coroutine to start.
---@return nil
function startTutorial(...) end

---
--- Locks player input controls.
---
---@return nil
function lockControls(...) end

---
--- Unlocks player input controls.
---
---@return nil
function unlockControls(...) end

---
--- Adds a new game announcement to the log.
---
---@param message string # The announcement message.
---@return nil
function addGameAnnouncement(...) end

---
--- Registers a tutorial to activate on a specific game event.
---
---@param eventType string # The event to listen for.
---@param tutorialName string # The name of the tutorial to trigger.
---@return nil
function registerTutorialToEvent(...) end

---
--- Moves the camera instantly to the specified position.
---
---@param x number # The target X position.
---@param y number # The target Y position.
---@return nil
function moveCameraTo(...) end

---
--- Moves the camera to center on the given entity.
---
---@param entity Entity # The entity to focus the camera on.
---@return nil
function moveCameraToEntity(...) end

---
--- Fades the screen to black over a specified duration.
---
---@param duration number # The duration of the fade in seconds.
---@return nil
function fadeOutScreen(...) end

---
--- Fades the screen in from black over a specified duration.
---
---@param duration number # The duration of the fade in seconds.
---@return nil
function fadeInScreen(...) end

---
--- Displays a visual indicator around the entity.
---
---@param entity Entity # The entity to display the indicator around.
---@return nil
function displayIndicatorAroundEntity(...) end

---
--- Displays a visual indicator of a specific type around the entity.
---
---@overload fun(entity: Entity, indicatorTypeID: string):nil
function displayIndicatorAroundEntity(...) end

---
--- Plays a sound effect from the specified category (default pitch = 1.0).
---
---@param category string # The category of the sound.
---@param soundName string # The name of the sound effect.
---@return nil
function playSoundEffect(...) end

---
--- Plays a sound effect with custom pitch (no Lua callback).
---
---@param category string # The category of the sound.
---@param soundName string # The name of the sound effect.
---@param pitch number # Playback pitch multiplier.
---@return nil
function playSoundEffect(...) end

---
--- Toggles a low-pass filter for the currently playing music.
---
---@param enabled boolean # Enables or disables a low-pass filter on the current music.
---@return nil
function toggleLowPassFilter(...) end

---
--- Toggles a delay effect (echo) for the currently playing music.
---
---@param enabled boolean # Enables or disables a delay effect on the current music.
---@return nil
function toggleDelayEffect(...) end

---
--- Resets the entire sound system, stopping all sounds and clearing loaded music (not sfx).
---
---@return nil
function resetSoundSystem(...) end

---
--- Smoothly transitions the low-pass filter toward the specified intensity.
---
---@param strength number # Target low-pass intensity (0.0 = off, 1.0 = max muffling)
---@return nil
function setLowPassTarget(...) end

---
--- Sets the speed at which the low-pass filter transitions between states.
---
---@param speed number # How fast the filter transitions per second.
---@return nil
function setLowPassSpeed(...) end

---
--- Plays a music track.
---
---@param musicName string # The name of the music track to play.
---@param loop? boolean # If the music should loop. Defaults to false.
---@return nil
function playMusic(...) end

---
--- Starts playing a playlist of tracks sequentially, with optional looping.
---
---@param tracks string[] # Ordered list of music track names to play.
---@param loop? boolean # Whether to loop the entire playlist. Defaults to false.
---@return nil
function playPlaylist(...) end

---
--- Stops and clears the current playlist (does not unload music assets).
---
---@return nil
function clearPlaylist(...) end

---
--- Stops and removes all currently playing music tracks immediately.
---
---@return nil
function stopAllMusic(...) end

---
--- Adds a music track to the queue to be played next.
---
---@param musicName string # The name of the music track to queue.
---@param loop? boolean # If the queued music should loop. Defaults to false.
---@return nil
function queueMusic(...) end

---
--- Sets the volume for a specific music track.
---
---@param name string # The name of the music track.
---@param vol number # The volume level for this track (0.0 to 1.0).
---@return nil
function setTrackVolume(...) end

---
--- Gets the volume for a specific music track.
---
---@param name string # The name of the music track.
---@return number # The current volume level for this track (0.0 to 1.0).
function getTrackVolume(...) end

---
--- Fades in and plays a music track over a duration.
---
---@param musicName string # The music track to fade in.
---@param duration number # The duration of the fade in seconds.
---@return nil
function fadeInMusic(...) end

---
--- Fades out the currently playing music.
---
---@param duration number # The duration of the fade in seconds.
---@return nil
function fadeOutMusic(...) end

---
--- Pauses the current music track.
---
---@param smooth? boolean # Whether to fade out when pausing. Defaults to false.
---@param fadeDuration? number # The fade duration if smooth is true. Defaults to 0.
---@return nil
function pauseMusic(...) end

---
--- Resumes the paused music track.
---
---@param smooth? boolean # Whether to fade in when resuming. Defaults to false.
---@param fadeDuration? number # The fade duration if smooth is true. Defaults to 0.
---@return nil
function resumeMusic(...) end

---
--- Sets the master audio volume.
---
---@param volume number # The master volume level (0.0 to 1.0).
---@return nil
function setVolume(...) end

---
--- Sets the volume for the music category only.
---
---@param volume number # The music volume level (0.0 to 1.0).
---@return nil
function setMusicVolume(...) end

---
--- Sets the volume for a specific sound effect category.
---
---@param category string # The name of the sound category.
---@param volume number # The volume for this category (0.0 to 1.0).
---@return nil
function setCategoryVolume(...) end

---
--- Sets the pitch for a specific sound. Note: This may not apply to currently playing instances.
---
---@param category string # The category of the sound.
---@param soundName string # The name of the sound effect.
---@param pitch number # The new pitch multiplier (1.0 is default).
---@return nil
function setSoundPitch(...) end

---
--- Retrieves an entity by its string alias.
---
---@param alias string
---@return Entity|nil
function getEntityByAlias(...) end

---
--- Assigns a string alias to an entity.
---
---@param alias string
---@param entity Entity
---@return nil
function setEntityAlias(...) end

---
--- Logs a debug message associated with an entity.
---
---@param entity Entity # The entity to associate the log with.
---@param message string # The message to log. Can be variadic arguments.
---@return nil
function log_debug(...) end

---
--- Logs a general debug message.
---
---@overload fun(message: string):nil
function log_debug(...) end

---
--- Logs an error message associated with an entity.
---
---@param entity Entity # The entity to associate the error with.
---@param message string # The error message. Can be variadic arguments.
---@return nil
function log_error(...) end

---
--- Logs a general error message.
---
---@overload fun(message: string):nil
function log_error(...) end

---
--- Sets a value in the entity's current world state.
---
---@param entity Entity
---@param key string
---@param value boolean
---@return nil
function setCurrentWorldStateValue(...) end

---
--- Gets a value from the entity's current world state.
---
---@param entity Entity
---@param key string
---@return boolean|nil
function getCurrentWorldStateValue(...) end

---
--- Clears the entity's current world state.
---
---@param entity Entity
---@return nil
function clearCurrentWorldState(...) end

---
--- Sets a value in the entity's goal world state.
---
---@param entity Entity
---@param key string
---@param value boolean
---@return nil
function setGoalWorldStateValue(...) end

---
--- Gets a value from the entity's goal world state.
---
---@param entity Entity
---@param key string
---@return boolean|nil
function getGoalWorldStateValue(...) end

---
--- Clears the entity's goal world state.
---
---@param entity Entity
---@return nil
function clearGoalWorldState(...) end

---
--- Sets a float value on an entity's blackboard.
---
---@param entity Entity
---@param key string
---@param value number
---@return nil
function setBlackboardFloat(...) end

---
--- Gets a float value from an entity's blackboard.
---
---@param entity Entity
---@param key string
---@return number
function getBlackboardFloat(...) end

---
--- Sets a Vector2 value on an entity's blackboard.
---
---@param entity Entity
---@param key string
---@param value Vector2
---@return nil
function setBlackboardVector2(...) end

---
--- Gets a Vector2 value from an entity's blackboard.
---
---@param entity Entity
---@param key string
---@return Vector2
function getBlackboardVector2(...) end

---
--- Sets a boolean value on an entity's blackboard.
---
---@param entity Entity
---@param key string
---@param value boolean
---@return nil
function setBlackboardBool(...) end

---
--- Gets a boolean value from an entity's blackboard.
---
---@param entity Entity
---@param key string
---@return boolean
function getBlackboardBool(...) end

---
--- Checks if the blackboard contains a specific key.
---
---@param entity Entity
---@param key string
---@return boolean
function blackboardContains(...) end

---
--- Sets an integer value on an entity's blackboard.
---
---@param entity Entity
---@param key string
---@param value integer
---@return nil
function setBlackboardInt(...) end

---
--- Gets an integer value from an entity's blackboard.
---
---@param entity Entity
---@param key string
---@return integer
function getBlackboardInt(...) end

---
--- Sets a string value on an entity's blackboard.
---
---@param entity Entity
---@param key string
---@param value string
---@return nil
function setBlackboardString(...) end

---
--- Gets a string value from an entity's blackboard.
---
---@param entity Entity
---@param key string
---@return string
function getBlackboardString(...) end

---
--- Checks if a specific keyboard key is currently pressed.
---
---@param key string
---@return boolean
function isKeyPressed(...) end

---
--- Pauses the game.
---
---@return nil
function pauseGame(...) end

---
--- Unpauses the game.
---
---@return nil
function unpauseGame(...) end

---
--- Recursively applies state effects to all elements in the specified UI box.
---
---@param uiBox Entity               # The UI box entity whose elements should have state effects applied
---@return nil
--- Recursively applies state effects to the given UI box and all its sub-elements based on their StateTag components and the global active states.
function propagate_state_effects_to_ui_box(...) end

---
--- Removes the default state tag from the specified entity, if it exists.
---
---@param entity Entity             # The entity whose 'default_state' tag should be removed
---@return nil
--- Removes the `'default_state'` tag from the entity’s StateTag list, if present.
function remove_default_state_tag(...) end

---
--- Checks whether any of the given tags or state names are active in the global ActiveStates instance.
---
---@overload fun(tag: StateTag): boolean
---@overload fun(names: string[]): boolean
---@return boolean
--- Returns `true` if **any** of the given state tags or names are currently active.
--- You can pass either a `StateTag` component or an array of strings.
--- Example:
--- ```lua
--- if hasAnyTag({ 'SHOP_STATE', 'PLANNING_STATE' }) then
--- print('At least one of these states is active.')
--- end
--- ```
function hasAnyTag(...) end

---
--- Checks whether all of the given tags or state names are active in the global ActiveStates instance.
---
---@overload fun(tag: StateTag): boolean
---@overload fun(names: string[]): boolean
---@return boolean
--- Returns `true` if **all** of the given state tags or names are currently active.
--- You can pass either a `StateTag` component or an array of strings.
--- Example:
--- ```lua
--- if hasAllTags({ 'ACTION_STATE', 'PLANNING_STATE' }) then
--- print('Both states are active at once.')
--- end
--- ```
function hasAllTags(...) end

---
--- Activates the given named state globally, using the shared ActiveStates instance.
---
---@param name string
---@return nil
--- Activates (enables) the given state name globally.
--- Equivalent to `active_states:activate(name)` on the singleton instance.
function activate_state(...) end

---
--- Checks whether the specified entity is active using the shared ActiveStates instance.
---
---@param entity Entity
---@return boolean
--- Checks whether the given entity is currently active based on its StateTag component and the global active states.
--- Returns `true` if the entity's StateTag is active in the global ActiveStates set.
function is_entity_active(...) end

---
--- Deactivates the given named state globally, using the shared ActiveStates instance.
---
---@param name string
---@return nil
--- Deactivates (disables) the given state name globally.
--- Equivalent to `active_states:deactivate(name)` on the singleton instance.
function deactivate_state(...) end

---
--- Clears all currently active global states in the shared ActiveStates instance.
---
---@return nil
--- Clears **all** currently active global states.
--- Equivalent to `active_states:clear()` on the singleton instance.
function clear_states(...) end

---
--- Checks whether a state tag or state name is active in the global ActiveStates instance.
---
---@overload fun(tag: StateTag): boolean
---@overload fun(name: string): boolean
---@return boolean
--- Checks whether a given state (by tag or name) is currently active.
--- Returns `true` if the state exists in the global ActiveStates set.
function is_state_active(...) end

---
--- Adds or replaces a StateTag component on the specified entity.
---
---@param entity Entity             # The entity to tag
---@param name string               # The name of the state tag
---@return nil
function add_state_tag(...) end

---
--- Removes a specific state tag from the StateTag component on the specified entity.
---
---@param entity Entity             # The entity from which to remove its state tag
---@param name string               # The name of the state tag to remove
---@return nil
function remove_state_tag(...) end

---
--- Clears any and all StateTag components from the specified entity.
---
---@param entity Entity             # The entity whose state tags you want to clear
---@return nil
function clear_state_tags(...) end

---
--- Fetches atlas texture + frame metadata for a sprite identifier.
---

---@param identifier string # Sprite UUID or raw identifier (e.g., filename)
---@return table|nil # { atlas=Texture2D, atlasUUID=string, frame={x,y,width,height}, gridRect=Vector4, imageSize=Vector2 } or nil on failure

function getSpriteFrameTextureInfo(...) end

---
--- Loads a palette texture from disk and uploads it to the shader's 'palette' uniform with point filtering.
---

---@param shaderName string # Name of the shader to receive the palette uniform
---@param filePath string   # Asset-relative or absolute path to the palette image
---@return boolean          # true if loaded and applied, false otherwise

function setPaletteTexture(...) end


---
---
---@class entt
entt = {
}


---
--- An iterable view over a set of entities that have all the given components.
---
---@class entt.runtime_view
entt.runtime_view = {
}

---
--- Returns an estimated number of entities in the view.
---
---@return integer
function entt.runtime_view:size_hint(...) end

---
--- Checks if an entity is present in the view.
---
---@param entity Entity
---@return boolean
function entt.runtime_view:contains(...) end

---
--- Iterates over all entities in the view and calls the provided function for each one.
---
---@param callback fun(entity: Entity)
---@return nil
function entt.runtime_view:each(...) end


---
--- The main container for all entities and components in the ECS world.
---
---@class entt.registry
entt.registry = {
}

---
--- Creates a new, empty registry instance.
---
---@return entt.registry
function entt.registry.new(...) end

---
--- Returns the number of entities created so far.
---
---@return integer
function entt.registry:size(...) end

---
--- Returns the number of living entities.
---
---@return integer
function entt.registry:alive(...) end

---
--- Checks if an entity handle is valid and still alive.
---
---@param entity Entity
---@return boolean
function entt.registry:valid(...) end

---
--- Returns the current version of an entity handle.
---
---@param entity Entity
---@return integer
function entt.registry:current(...) end

---
--- Creates a new entity and returns its handle.
---
---@return Entity
function entt.registry:create(...) end

---
--- Destroys an entity and all its components.
---
---@param entity Entity
---@return nil
function entt.registry:destroy(...) end

---
--- Adds and initializes a component for an entity using a Lua table.
---
---@param entity Entity
---@param component_table table # A Lua table representing the component, must contain a `__type` field.
---@return any # The newly created component instance.
function entt.registry:emplace(...) end

---
--- Attaches a script component to an entity, initializing it with the provided Lua table.
---
---@param entity Entity # The entity to attach the script to.
---@param script_table table # A Lua table containing the script's methods (init, update, etc.).
---@return nil
function entt.registry:add_script(...) end

---
--- Removes a component from an entity.
---
---@param entity Entity
---@param component_type ComponentType
---@return integer # The number of components removed (0 or 1).
function entt.registry:remove(...) end

---
--- Checks if an entity has a specific component.
---
---@param entity Entity
---@param component_type ComponentType
---@return boolean
function entt.registry:has(...) end

---
--- Checks if an entity has any of the specified components.
---
---@param entity Entity
---@param ... ComponentType
---@return boolean
function entt.registry:any_of(...) end

---
--- Retrieves a component from an entity.
---
---@param entity Entity
---@param component_type ComponentType
---@return any|nil # The component instance, or nil if not found.
function entt.registry:get(...) end

---
--- Destroys all entities and clears all component pools.
---
---@return nil
function entt.registry:clear(...) end

---
--- Removes all components of a given type from all entities.
---
---@overload fun(self, component_type: ComponentType):void
function entt.registry:clear(...) end

---
--- Destroys all entities that have no components.
---
---@return nil
function entt.registry:orphan(...) end

---
--- Creates and returns a view for iterating over entities that have all specified components.
---
---@param ... ComponentType
---@return entt.runtime_view
function entt.registry:runtime_view(...) end


---
--- The interface for a Lua script attached to an entity (like monobehavior). Your script table should implement these methods.
---
---@class ScriptComponent
ScriptComponent = {
    ---@type nil
    id = nil,  -- Entity: (Read-only) The entity handle this script is attached to. Injected by the system.
    ---@type nil
    owner = nil,  -- registry: (Read-only) A reference to the C++ registry. Injected by the system.
    ---@type nil
    init = nil,  -- function(): Optional function called once when the script is attached to an entity.
    ---@type nil
    update = nil,  -- function(dt: number): Function called every frame.
    ---@type nil
    destroy = nil  -- function(): Optional function called just before the entity is destroyed.
}

---
--- Adds a new coroutine to this script's task list.
---
---@param task coroutine
---@return nil
function ScriptComponent:add_task(...) end

---
--- Returns the number of active coroutines on this script.
---
---@return integer
function ScriptComponent:count_tasks(...) end


---
---
---@class ai
ai = {
}

---
--- This is useful for debugging or when you want to temporarily halt AI processing.
---
---Pauses the AI system, preventing any updates or actions from being processed.
function ai:pause_ai_system(...) end

---
--- This allows the AI system to continue processing updates and actions.
---
---Resumes the AI system after it has been paused.
function ai:resume_ai_system(...) end

---
--- Returns the mutable AI-definition table for the given entity.
---
---@param e Entity
---@return table # The Lua AI-definition table (with entity_types, actions, goal_selectors, etc.)
function ai:get_entity_ai_def(...) end

---
--- Sets a single world-state flag on the entity’s current state.
---
---@param e Entity
---@param key string
---@param value boolean
---@return nil
function ai:set_worldstate(...) end

---
--- Retrieves the value of a single world-state flag from the entity’s current state; returns nil if the flag is not set or is marked as 'don't care'.
---
---@param e Entity
---@param key string
---@return boolean|nil
function ai:get_worldstate(...) end

---
--- Clears existing goal and assigns new goal flags for the entity.
---
---@param e Entity
---@param goal table<string,boolean>
---@return nil
function ai:set_goal(...) end

---
--- Patches one world-state flag without resetting other flags.
---
---@param e Entity
---@param key string
---@param value boolean
---@return nil
function ai:patch_worldstate(...) end

---
--- Patches multiple goal flags without clearing the current goal.
---
---@param e Entity
---@param tbl table<string,boolean>
---@return nil
function ai:patch_goal(...) end

---
--- Returns the entity’s Blackboard component if present; nil otherwise.
---
---@param e Entity
---@return Blackboard|nil
function ai:get_blackboard(...) end

---
--- Creates a new GOAP entity of the given type, applying optional AI overrides.
---
---@param type string
---@param overrides table<string,any>?
---@return Entity
function ai:create_ai_entity(...) end

---
--- Immediately interrupts the entity’s current GOAP action.
---
---@param e Entity
---@return nil
function ai:force_interrupt(...) end

---
--- Returns a list of Lua script filenames (without extensions) from the specified directory.
---
---@param dir string
---@return string[]
function ai:list_lua_files(...) end

---
--- Sets a single world-state flag on the entity’s current state.
---
---@param e Entity
---@param key string
---@param value boolean
---@return nil
function ai:set_worldstate(...) end

---
--- Clears the existing goal and sets new goal flags for the entity.
---
---@param e Entity
---@param goal table<string,boolean>
---@return nil
function ai:set_goal(...) end

---
--- Patches one world-state flag without clearing other flags.
---
---@param e Entity
---@param key string
---@param value boolean
---@return nil
function ai:patch_worldstate(...) end

---
--- Patches multiple goal flags without clearing the existing goal.
---
---@param e Entity
---@param tbl table<string,boolean>
---@return nil
function ai:patch_goal(...) end

---
--- Returns the entity’s Blackboard component.
---
---@param e Entity
---@return Blackboard
function ai:get_blackboard(...) end

---
--- Immediately interrupts the entity’s current GOAP action.
---
---@param e Entity
---@return nil
function ai:force_interrupt(...) end

---
--- Lists all Lua files (no extension) in the given scripts directory.
---
---@param dir string
---@return string[]
function ai:list_lua_files(...) end


---
--- Task scheduler.
---
---@class scheduler
scheduler = {
}

---
--- Returns the number of processes in the scheduler.
---
---@return integer
function scheduler:size(...) end

---
--- Checks if the scheduler has no processes.
---
---@return boolean
function scheduler:empty(...) end

---
--- Clears all processes from the scheduler.
---
---@return nil
function scheduler:clear(...) end

---
--- Attaches a script process to the scheduler, optionally chaining child processes.
---
---@param process table # The Lua table representing the process.
---@param ... table # Optional child processes to chain.
function scheduler:attach(...) end

---
--- Updates all processes in the scheduler, passing the elapsed time and optional data.
---
---@param delta_time number # The time elapsed since the last update.
---@param data any # Optional data to pass to the process.
function scheduler:update(...) end

---
--- Aborts all processes in the scheduler. If `terminate` is true, it will terminate all processes immediately.
---
---@overload fun():void
---@overload fun(terminate: boolean):void
function scheduler:abort(...) end


---
--- Results of an action
---
---@class ActionResult
ActionResult = {
    SUCCESS = 0,  -- When succeeded
    FAILURE = 1,  -- When failed
    RUNNING = 2  -- When still running
}


---
--- Wraps an EnTT entity handle for Lua scripts.
---
---@class Entity
Entity = {
}


---
--- Userdata type for the controller navigation manager.
--- Use the global `controller_nav` table for live access.
---
---@class NavManagerUD
NavManagerUD = {
    update = nil,  -- ---@param dt number
    validate = nil,
    debug_print_state = nil,
    create_group = nil,  -- ---@param name string
    add_entity = nil,  -- ---@param group string
---@param e entt.entity
    remove_entity = nil,  -- ---@param group string
---@param e entt.entity
    clear_group = nil,  -- ---@param group string
    set_active = nil,  -- ---@param group string
---@param active boolean
    set_selected = nil,  -- ---@param group string
---@param index integer
    get_selected = nil,  -- ---@param group string
---@return entt.entity|nil
    set_entity_enabled = nil,  -- ---@param e entt.entity
---@param enabled boolean
    is_entity_enabled = nil,  -- ---@param e entt.entity
---@return boolean
    navigate = nil,  -- ---@param group string
---@param dir 'L'|'R'|'U'|'D'
    select_current = nil,  -- ---@param group string
    create_layer = nil,  -- ---@param name string
    add_group_to_layer = nil,  -- ---@param layer string
---@param group string
    set_active_layer = nil,  -- ---@param name string
    push_layer = nil,  -- ---@param name string
    pop_layer = nil,
    push_focus_group = nil,  -- ---@param name string
    pop_focus_group = nil,
    current_focus_group = nil  -- ---@return string
}


---
--- Controller navigation system entry point.
--- Manages layers, groups, and spatial/linear focus movement for UI and in-game entities.
---
---@class controller_nav
controller_nav = {
}


---
--- Container for all text‐system types
---
---@class TextSystem
TextSystem = {
    effectFunctions = {}  -- Map of effect names to C++ functions
}


---
--- Holds parsed arguments for text effects
---
---@class TextSystem.ParsedEffectArguments
TextSystem.ParsedEffectArguments = {
}

---
--- Returns the list of raw effect arguments
---
---@return std::vector<std::string> arguments # The parsed effect arguments
function TextSystem.ParsedEffectArguments:arguments(...) end


---
--- Represents one rendered character in the text system
---
---@class TextSystem.Character
TextSystem.Character = {
}

---
--- Gets the character value
---
---@return any value # character value
function TextSystem.Character:value(...) end

---
--- Gets the override codepoint
---
---@return any overrideCodepoint # override codepoint
function TextSystem.Character:overrideCodepoint(...) end

---
--- Gets the rotation angle
---
---@return any rotation # rotation angle
function TextSystem.Character:rotation(...) end

---
--- Gets the scale factor
---
---@return any scale # scale factor
function TextSystem.Character:scale(...) end

---
--- Gets the glyph size
---
---@return any size # glyph size
function TextSystem.Character:size(...) end

---
--- Gets the shadow displacement
---
---@return any shadowDisplacement # shadow displacement
function TextSystem.Character:shadowDisplacement(...) end

---
--- Gets the shadow height
---
---@return any shadowHeight # shadow height
function TextSystem.Character:shadowHeight(...) end

---
--- Gets the X-axis scale modifier
---
---@return any scaleXModifier # X-axis scale modifier
function TextSystem.Character:scaleXModifier(...) end

---
--- Gets the Y-axis scale modifier
---
---@return any scaleYModifier # Y-axis scale modifier
function TextSystem.Character:scaleYModifier(...) end

---
--- Gets the tint color
---
---@return any color # tint color
function TextSystem.Character:color(...) end

---
--- Gets the per-glyph offsets
---
---@return any offsets # per-glyph offsets
function TextSystem.Character:offsets(...) end

---
--- Gets the per-glyph shadow offsets
---
---@return any shadowDisplacementOffsets # per-glyph shadow offsets
function TextSystem.Character:shadowDisplacementOffsets(...) end

---
--- Gets the per-glyph scale modifiers
---
---@return any scaleModifiers # per-glyph scale modifiers
function TextSystem.Character:scaleModifiers(...) end

---
--- Gets the user-defined data
---
---@return any customData # user-defined data
function TextSystem.Character:customData(...) end

---
--- Gets the global offset
---
---@return any offset # global offset
function TextSystem.Character:offset(...) end

---
--- Gets the applied effects list
---
---@return any effects # applied effects list
function TextSystem.Character:effects(...) end

---
--- Gets the parsed effect arguments
---
---@return any parsedEffectArguments # parsed effect arguments
function TextSystem.Character:parsedEffectArguments(...) end

---
--- Gets the character index
---
---@return any index # character index
function TextSystem.Character:index(...) end

---
--- Gets the line number
---
---@return any lineNumber # line number
function TextSystem.Character:lineNumber(...) end

---
--- Gets the first frame timestamp
---
---@return any firstFrame # first frame timestamp
function TextSystem.Character:firstFrame(...) end

---
--- Gets the attached tags
---
---@return any tags # attached tags
function TextSystem.Character:tags(...) end

---
--- Gets the pop-in flag
---
---@return any pop_in # pop-in flag
function TextSystem.Character:pop_in(...) end

---
--- Gets the pop-in delay time
---
---@return any pop_in_delay # pop-in delay time
function TextSystem.Character:pop_in_delay(...) end

---
--- Gets the creation timestamp
---
---@return any createdTime # creation timestamp
function TextSystem.Character:createdTime(...) end

---
--- Gets the parent text object
---
---@return any parentText # parent text object
function TextSystem.Character:parentText(...) end

---
--- Gets the is final character in its text
---
---@return any isFinalCharacterInText # is final character in its text
function TextSystem.Character:isFinalCharacterInText(...) end

---
--- Gets the effect finished flag
---
---@return any effectFinished # effect finished flag
function TextSystem.Character:effectFinished(...) end

---
--- Gets the is an image glyph
---
---@return any isImage # is an image glyph
function TextSystem.Character:isImage(...) end

---
--- Gets the image shadow enabled
---
---@return any imageShadowEnabled # image shadow enabled
function TextSystem.Character:imageShadowEnabled(...) end

---
--- Gets the sprite UUID
---
---@return any spriteUUID # sprite UUID
function TextSystem.Character:spriteUUID(...) end

---
--- Gets the image scale factor
---
---@return any imageScale # image scale factor
function TextSystem.Character:imageScale(...) end

---
--- Gets the foreground tint
---
---@return any fgTint # foreground tint
function TextSystem.Character:fgTint(...) end

---
--- Gets the background tint
---
---@return any bgTint # background tint
function TextSystem.Character:bgTint(...) end


---
--- Main text object with content, layout, and effects
---
---@class TextSystem.Text
TextSystem.Text = {
}

---
--- Gets the raw get_value_callback
---
---@return any get_value_callback # raw value
function TextSystem.Text:get_value_callback(...) end

---
--- Gets the raw onStringContentUpdatedOrChangedViaCallback
---
---@return any onStringContentUpdatedOrChangedViaCallback # raw value
function TextSystem.Text:onStringContentUpdatedOrChangedViaCallback(...) end

---
--- Gets the raw effectStringsToApplyGloballyOnTextChange
---
---@return any effectStringsToApplyGloballyOnTextChange # raw value
function TextSystem.Text:effectStringsToApplyGloballyOnTextChange(...) end

---
--- Gets the raw onFinishedEffect
---
---@return any onFinishedEffect # raw value
function TextSystem.Text:onFinishedEffect(...) end

---
--- Gets the raw pop_in_enabled
---
---@return any pop_in_enabled # raw value
function TextSystem.Text:pop_in_enabled(...) end

---
--- Gets the raw shadow_enabled
---
---@return any shadow_enabled # raw value
function TextSystem.Text:shadow_enabled(...) end

---
--- Gets the raw width
---
---@return any width # raw value
function TextSystem.Text:width(...) end

---
--- Gets the raw height
---
---@return any height # raw value
function TextSystem.Text:height(...) end

---
--- Gets the raw rawText
---
---@return any rawText # raw value
function TextSystem.Text:rawText(...) end

---
--- Gets the raw characters
---
---@return any characters # raw value
function TextSystem.Text:characters(...) end

---
--- Gets the raw fontData
---
---@return any fontData # raw value
function TextSystem.Text:fontData(...) end

---
--- Gets the raw fontSize
---
---@return any fontSize # raw value
function TextSystem.Text:fontSize(...) end

---
--- Gets the raw wrapEnabled
---
---@return any wrapEnabled # raw value
function TextSystem.Text:wrapEnabled(...) end

---
--- Gets the raw wrapWidth
---
---@return any wrapWidth # raw value
function TextSystem.Text:wrapWidth(...) end

---
--- Gets the raw prevRenderScale
---
---@return any prevRenderScale # raw value
function TextSystem.Text:prevRenderScale(...) end

---
--- Gets the raw renderScale
---
---@return any renderScale # raw value
function TextSystem.Text:renderScale(...) end

---
--- Gets the raw createdTime
---
---@return any createdTime # raw value
function TextSystem.Text:createdTime(...) end

---
--- Gets the raw effectStartTime
---
---@return any effectStartTime # raw value
function TextSystem.Text:effectStartTime(...) end

---
--- Gets the raw applyTransformRotationAndScale
---
---@return any applyTransformRotationAndScale # raw value
function TextSystem.Text:applyTransformRotationAndScale(...) end


---
--- Enum of text alignment values
---
---@class TextSystem.TextAlignment
TextSystem.TextAlignment = {
    LEFT = 0,  -- Left-aligned text
    CENTER = 1,  -- Centered text
    RIGHT = 2,  -- Right-aligned text
    JUSTIFIED = 3  -- Justified text
}


---
--- Enum of text wrap modes
---
---@class TextSystem.TextWrapMode
TextSystem.TextWrapMode = {
    WORD = 0,  -- Wrap on word boundaries
    CHARACTER = 1  -- Wrap on individual characters
}


---
---
---@class TextSystem.Builders
TextSystem.Builders = {
}


---
--- Fluent builder for creating TextSystem.Text objects
---
---@class TextSystem.Builders.TextBuilder
TextSystem.Builders.TextBuilder = {
}

---
--- Builder method setRawText
---
---@param v any # argument for setRawText
function TextSystem.Builders.TextBuilder:setRawText(...) end

---
--- Builder method setFontData
---
---@param v any # argument for setFontData
function TextSystem.Builders.TextBuilder:setFontData(...) end

---
--- Builder method setOnFinishedEffect
---
---@param v any # argument for setOnFinishedEffect
function TextSystem.Builders.TextBuilder:setOnFinishedEffect(...) end

---
--- Builder method setFontSize
---
---@param v any # argument for setFontSize
function TextSystem.Builders.TextBuilder:setFontSize(...) end

---
--- Builder method setWrapWidth
---
---@param v any # argument for setWrapWidth
function TextSystem.Builders.TextBuilder:setWrapWidth(...) end

---
--- Builder method setAlignment
---
---@param v any # argument for setAlignment
function TextSystem.Builders.TextBuilder:setAlignment(...) end

---
--- Builder method setWrapMode
---
---@param v any # argument for setWrapMode
function TextSystem.Builders.TextBuilder:setWrapMode(...) end

---
--- Builder method setCreatedTime
---
---@param v any # argument for setCreatedTime
function TextSystem.Builders.TextBuilder:setCreatedTime(...) end

---
--- Builder method setPopInEnabled
---
---@param v any # argument for setPopInEnabled
function TextSystem.Builders.TextBuilder:setPopInEnabled(...) end

---
--- Builder method build
---
---@param v any # argument for build
function TextSystem.Builders.TextBuilder:build(...) end


---
--- Container for text system utility functions
---
---@class TextSystem.Functions
TextSystem.Functions = {
}


---
--- Animation system functions
---
---@class animation_system
animation_system = {
}


---
--- Namespace for creating colliders and performing collision‐tests.
---
---@class collision
collision = {
}


---
--- Enum of supported collider shapes.
---
---@class ColliderType
ColliderType = {
    AABB = 0,  -- Axis-aligned bounding box.
    Circle = 1  -- Circle collider.
}


---
--- Component holding two 32-bit bitmasks:
--- -- category = which tag-bits this collider *is*
--- --- mask     = which category-bits this collider *collides with*
--- --Default ctor sets both to 0xFFFFFFFF (collide with everything).
---
---@class CollisionFilter
CollisionFilter = {
    category = uint32,  -- Bitmask: what this entity *is* (e.g. Player, Enemy, Projectile).
    mask = uint32  -- Bitmask: which categories this entity *collides* with.
}


---
---
---@class particle
particle = {
}


---
--- How particles should be rendered
---
---@class particle.ParticleRenderType
particle.ParticleRenderType = {
    TEXTURE = 0,  -- Use a sprite texture
    RECTANGLE_LINE = 1,  -- Draw a rectangle outline
    RECTANGLE_FILLED = 2,  -- Draw a filled rectangle
    CIRCLE_LINE = 3,  -- Draw a circle outline
    CIRCLE_FILLED = 4  -- Draw a filled circle
}


---
--- Where to draw particles
---
---@class particle.RenderSpace
particle.RenderSpace = {
    WORLD = 0,  -- Render in world space
    SCREEN = 1  -- Render in screen/UI space
}


---
--- Defines how particles are emitted
---
---@class particle.ParticleEmitter
particle.ParticleEmitter = {
    size = nil,  -- Vector2: The size of the emission area.
    emissionRate = nil,  -- number: Time in seconds between emissions.
    particleLifespan = nil,  -- number: How long each particle lives.
    particleSpeed = nil,  -- number: Initial speed of emitted particles.
    fillArea = nil,  -- boolean: If true, emit from anywhere within the size rect.
    oneShot = nil,  -- boolean: If true, emits a burst of particles once.
    oneShotParticleCount = nil,  -- number: Number of particles for a one-shot burst.
    prewarm = nil,  -- boolean: If true, simulates the system on creation.
    prewarmParticleCount = nil,  -- number: Number of particles for prewarming.
    useGlobalCoords = nil,  -- boolean: If true, particles operate in world space.
    emissionSpread = nil,  -- number: Angular spread of particle emissions in degrees.
    gravityStrength = nil,  -- number: Gravity applied to emitted particles.
    emissionDirection = nil,  -- Vector2: Base direction for particle emission.
    acceleration = nil,  -- number: Acceleration applied to particles.
    blendMode = nil,  -- BlendMode: The blend mode for rendering particles.
    defaultZ = nil,  -- integer?: Default z for emitted particles.
    defaultSpace = nil,  -- particle.RenderSpace?: Default space for emitted particles.
    colors = nil  -- Color[]: A table of possible colors for particles.
}


---
--- Configuration for animated particle appearance
---
---@class particle.ParticleAnimationConfig
particle.ParticleAnimationConfig = {
    loop = boolean,  -- Whether the particle's animation should loop.
    animationName = string  -- The name of the animation to play.
}


---
---
---@class Vector2
Vector2 = {
    x = number,  -- X component
    y = number  -- Y component
}


---
---
---@class Color
Color = {
    r = number,  -- Red channel (0–255)
    g = number,  -- Green channel (0–255)
    b = number,  -- Blue channel (0–255)
    a = number  -- Alpha channel (0–255)
}


---
--- Root table for shader pipeline helpers and types.
---
---@class shader_pipeline
shader_pipeline = {
}


---
--- Defines a single shader pass.
---
---@class shader_pipeline.ShaderPass
shader_pipeline.ShaderPass = {
    ---@type string
    shaderName = nil,  -- Name of the shader to use for this pass
    ---@type bool
    injectAtlasUniforms = nil,  -- Whether to inject atlas UV uniforms into this pass
    ---@type bool
    enabled = nil,  -- Whether this shader pass is enabled
    ---@type fun()
    customPrePassFunction = nil  -- Function to run before activating this pass
}


---
--- Source input for shader overlay drawing.
---
---@class shader_pipeline.OverlayInputSource
shader_pipeline.OverlayInputSource = {
    BaseSprite = 0,  -- Use the base sprite
    PostPassResult = 1  -- Use the result from previous passes
}


---
--- Defines a full-screen shader overlay pass.
---
---@class shader_pipeline.ShaderOverlayDraw
shader_pipeline.ShaderOverlayDraw = {
    ---@type OverlayInputSource
    inputSource = nil,  -- Where to sample input from
    ---@type string
    shaderName = nil,  -- Name of the overlay shader
    ---@type fun()
    customPrePassFunction = nil,  -- Function to run before this overlay
    ---@type BlendMode
    blendMode = nil,  -- Blend mode for this overlay
    ---@type bool
    enabled = nil  -- Whether this overlay is enabled
}


---
--- Holds a sequence of shader passes and overlays for full-scene rendering.
---
---@class shader_pipeline.ShaderPipelineComponent
shader_pipeline.ShaderPipelineComponent = {
    ---@type std::vector<ShaderPass>
    passes = nil,  -- Ordered list of shader passes
    ---@type std::vector<ShaderOverlayDraw>
    overlayDraws = nil,  -- Ordered list of overlays
    ---@type float
    padding = nil  -- Safe-area padding around overlays
}


---
--- Random number generation utilities and helper functions
---
---@class random_utils
random_utils = {
}


---
--- Raylib Rectangle (x,y,width,height)
---
---@class Rectangle
Rectangle = {
    ---@type number
    x = nil,  -- Top-left X
    ---@type number
    y = nil,  -- Top-left Y
    ---@type number
    width = nil,  -- Width
    ---@type number
    height = nil  -- Height
}


---
--- namespace for rendering & layer operations
---
---@class layer
layer = {
    layers = table  -- Global list of layers
}


---
--- Stores Z-index for layer sorting
---
---@class layer.LayerOrderComponent
layer.LayerOrderComponent = {
    ---@type integer
    zIndex = nil  -- Z sort order
}


---
--- Represents a drawing layer and its properties.
---
---@class layer.Layer
layer.Layer = {
    ---@type table
    canvases = nil,  -- Map of canvas names to textures
    ---@type table
    drawCommands = nil,  -- Command list
    ---@type boolean
    fixed = nil,  -- Whether layer is fixed
    ---@type integer
    zIndex = nil,  -- Z-index
    ---@type Color
    backgroundColor = nil,  -- Background fill color
    ---@type table
    commands = nil,  -- Draw commands list
    ---@type boolean
    isSorted = nil,  -- True if layer is sorted
    ---@type vector
    postProcessShaders = nil  -- List of post-process shaders to run after drawing
}


---
--- Drawing instruction types used by Layer system
---
---@class layer.DrawCommandType
layer.DrawCommandType = {
    BeginDrawing = 0,  -- Start drawing a layer frame
    EndDrawing = 1,  -- End drawing a layer frame
    ClearBackground = 2,  -- Clear background with color
    Translate = 3,  -- Translate coordinate system
    Scale = 4,  -- Scale coordinate system
    Rotate = 5,  -- Rotate coordinate system
    AddPush = 6,  -- Push transform matrix
    AddPop = 7,  -- Pop transform matrix
    PushMatrix = 8,  -- Explicit push matrix command
    PushObjectTransformsToMatrix = 100,  -- Push object's transform to matrix stack
    ScopedTransformCompositeRender = 101,  -- Scoped transform for composite rendering
    PopMatrix = 9,  -- Explicit pop matrix command
    DrawCircle = 10,  -- Draw a filled circle
    DrawRectangle = 11,  -- Draw a filled rectangle
    DrawRectanglePro = 12,  -- Draw a scaled and rotated rectangle
    DrawRectangleLinesPro = 13,  -- Draw rectangle outline
    DrawLine = 14,  -- Draw a line
    DrawDashedLine = 15,  -- Draw a dashed line
    DrawText = 16,  -- Draw plain text
    DrawTextCentered = 17,  -- Draw text centered
    TextPro = 18,  -- Draw stylized/proportional text
    DrawImage = 19,  -- Draw a texture/image
    TexturePro = 20,  -- Draw transformed texture
    DrawEntityAnimation = 21,  -- Draw animation of an entity
    DrawTransformEntityAnimation = 22,  -- Draw transform-aware animation
    DrawTransformEntityAnimationPipeline = 23,  -- Draw pipelined animation with transform
    SetShader = 24,  -- Set active shader
    ResetShader = 25,  -- Reset to default shader
    SetBlendMode = 26,  -- Set blend mode
    UnsetBlendMode = 27,  -- Reset blend mode
    SendUniformFloat = 28,  -- Send float uniform to shader
    SendUniformInt = 29,  -- Send int uniform to shader
    SendUniformVec2 = 30,  -- Send vec2 uniform to shader
    SendUniformVec3 = 31,  -- Send vec3 uniform to shader
    SendUniformVec4 = 32,  -- Send vec4 uniform to shader
    SendUniformFloatArray = 33,  -- Send float array uniform to shader
    SendUniformIntArray = 34,  -- Send int array uniform to shader
    Vertex = 35,  -- Draw raw vertex
    BeginOpenGLMode = 36,  -- Begin native OpenGL mode
    EndOpenGLMode = 37,  -- End native OpenGL mode
    SetColor = 38,  -- Set current draw color
    SetLineWidth = 39,  -- Set width of lines
    SetTexture = 40,  -- Bind texture to use
    RenderRectVerticesFilledLayer = 41,  -- Draw filled rects from vertex list
    RenderRectVerticesOutlineLayer = 42,  -- Draw outlined rects from vertex list
    DrawPolygon = 43,  -- Draw a polygon
    RenderNPatchRect = 44,  -- Draw a 9-patch rectangle
    DrawTriangle = 45,  -- Draw a triangle
    DrawGradientRectCentered = 46,  -- Draw a gradient rectangle centered
    DrawGradientRectRoundedCentered = 47  -- Draw a rounded gradient rectangle centered
}


---
---
---@class layer.CmdBeginDrawing
layer.CmdBeginDrawing = {
    ---@type false
    dummy = nil  -- Unused field
}


---
---
---@class layer.CmdEndDrawing
layer.CmdEndDrawing = {
    ---@type false
    dummy = nil  -- Unused field
}


---
---
---@class layer.CmdClearBackground
layer.CmdClearBackground = {
    ---@type Color
    color = nil  -- Background color
}


---
---
---@class layer.CmdBeginScissorMode
layer.CmdBeginScissorMode = {
    ---@type Rectangle
    area = nil  -- Scissor area rectangle
}


---
---
---@class layer.CmdEndScissorMode
layer.CmdEndScissorMode = {
    ---@type false
    dummy = nil  -- Unused field
}


---
---
---@class layer.CmdTranslate
layer.CmdTranslate = {
    ---@type number
    x = nil,  -- X offset
    ---@type number
    y = nil  -- Y offset
}


---
---
---@class layer.CmdRenderBatchFlush
layer.CmdRenderBatchFlush = {
}


---
---
---@class layer.CmdStencilOp
layer.CmdStencilOp = {
    ---@type number
    sfail = nil,  -- Stencil fail action
    ---@type number
    dpfail = nil,  -- Depth fail action
    ---@type number
    dppass = nil  -- Depth pass action
}


---
---
---@class layer.CmdAtomicStencilMask
layer.CmdAtomicStencilMask = {
    ---@type number
    mask = nil  -- Stencil mask value
}


---
---
---@class layer.CmdColorMask
layer.CmdColorMask = {
    ---@type boolean
    r = nil,  -- Red channel
    ---@type boolean
    g = nil,  -- Green channel
    ---@type boolean
    b = nil,  -- Blue channel
    ---@type boolean
    a = nil  -- Alpha channel
}


---
---
---@class layer.CmdStencilFunc
layer.CmdStencilFunc = {
    ---@type number
    func = nil,  -- Stencil function
    ---@type number
    ref = nil,  -- Reference value
    ---@type number
    mask = nil  -- Mask value
}


---
---
---@class layer.CmdBeginStencilMode
layer.CmdBeginStencilMode = {
    ---@type false
    dummy = nil  -- Unused field
}


---
---
---@class layer.CmdEndStencilMode
layer.CmdEndStencilMode = {
    ---@type false
    dummy = nil  -- Unused field
}


---
---
---@class layer.CmdClearStencilBuffer
layer.CmdClearStencilBuffer = {
    ---@type false
    dummy = nil  -- Unused field
}


---
---
---@class layer.CmdBeginStencilMask
layer.CmdBeginStencilMask = {
    ---@type false
    dummy = nil  -- Unused field
}


---
---
---@class layer.CmdEndStencilMask
layer.CmdEndStencilMask = {
    ---@type false
    dummy = nil  -- Unused field
}


---
---
---@class layer.CmdDrawCenteredEllipse
layer.CmdDrawCenteredEllipse = {
    ---@type number
    x = nil,  -- Center X
    ---@type number
    y = nil,  -- Center Y
    ---@type number
    rx = nil,  -- Radius X
    ---@type number
    ry = nil,  -- Radius Y
    ---@type Color
    color = nil,  -- Ellipse color
    ---@type number|nil
    lineWidth = nil  -- Line width for outline; nil for filled
}


---
---
---@class layer.CmdDrawRoundedLine
layer.CmdDrawRoundedLine = {
    ---@type number
    x1 = nil,  -- Start X
    ---@type number
    y1 = nil,  -- Start Y
    ---@type number
    x2 = nil,  -- End X
    ---@type number
    y2 = nil,  -- End Y
    ---@type Color
    color = nil,  -- Line color
    ---@type number
    lineWidth = nil  -- Line width
}


---
---
---@class layer.CmdDrawPolyline
layer.CmdDrawPolyline = {
    ---@type Vector2[]
    points = nil,  -- List of points
    ---@type Color
    color = nil,  -- Line color
    ---@type number
    lineWidth = nil  -- Line width
}


---
---
---@class layer.CmdDrawArc
layer.CmdDrawArc = {
    ---@type string
    type = nil,  -- Arc type (e.g., 'OPEN', 'CHORD', 'PIE')
    ---@type number
    x = nil,  -- Center X
    ---@type number
    y = nil,  -- Center Y
    ---@type number
    r = nil,  -- Radius
    ---@type number
    r1 = nil,  -- Inner radius (for ring arcs)
    ---@type number
    r2 = nil,  -- Outer radius (for ring arcs)
    ---@type Color
    color = nil,  -- Arc color
    ---@type number
    lineWidth = nil,  -- Line width
    ---@type number
    segments = nil  -- Number of segments
}


---
---
---@class layer.CmdDrawTriangleEquilateral
layer.CmdDrawTriangleEquilateral = {
    ---@type number
    x = nil,  -- Center X
    ---@type number
    y = nil,  -- Center Y
    ---@type number
    w = nil,  -- Width of the triangle
    ---@type Color
    color = nil,  -- Triangle color
    ---@type number|nil
    lineWidth = nil  -- Line width for outline; nil for filled
}


---
---
---@class layer.CmdDrawCenteredFilledRoundedRect
layer.CmdDrawCenteredFilledRoundedRect = {
    ---@type number
    x = nil,  -- Center X
    ---@type number
    y = nil,  -- Center Y
    ---@type number
    w = nil,  -- Width
    ---@type number
    h = nil,  -- Height
    ---@type number|nil
    rx = nil,  -- Corner radius X; nil for default
    ---@type number|nil
    ry = nil,  -- Corner radius Y; nil for default
    ---@type Color
    color = nil,  -- Fill color
    ---@type number|nil
    lineWidth = nil  -- Line width for outline; nil for filled
}


---
---
---@class layer.CmdDrawSpriteCentered
layer.CmdDrawSpriteCentered = {
    ---@type string
    spriteName = nil,  -- Name of the sprite
    ---@type number
    x = nil,  -- Center X
    ---@type number
    y = nil,  -- Center Y
    ---@type number|nil
    dstW = nil,  -- Destination width; nil for original width
    ---@type number|nil
    dstH = nil,  -- Destination height; nil for original height
    ---@type Color
    tint = nil  -- Tint color
}


---
---
---@class layer.CmdDrawSpriteTopLeft
layer.CmdDrawSpriteTopLeft = {
    ---@type string
    spriteName = nil,  -- Name of the sprite
    ---@type number
    x = nil,  -- Top-left X
    ---@type number
    y = nil,  -- Top-left Y
    ---@type number|nil
    dstW = nil,  -- Destination width; nil for original width
    ---@type number|nil
    dstH = nil,  -- Destination height; nil for original height
    ---@type Color
    tint = nil  -- Tint color
}


---
---
---@class layer.CmdDrawDashedCircle
layer.CmdDrawDashedCircle = {
    ---@type Vector2
    center = nil,  -- Center position
    ---@type number
    radius = nil,  -- Radius
    ---@type number
    dashLength = nil,  -- Length of each dash
    ---@type number
    gapLength = nil,  -- Length of gap between dashes
    ---@type number
    phase = nil,  -- Phase offset for dashes
    ---@type number
    segments = nil,  -- Number of segments to approximate the circle
    ---@type number
    thickness = nil,  -- Thickness of the dashes
    ---@type Color
    color = nil  -- Color of the dashes
}


---
---
---@class layer.CmdDrawDashedRoundedRect
layer.CmdDrawDashedRoundedRect = {
    ---@type Rectangle
    rec = nil,  -- Rectangle area
    ---@type number
    dashLen = nil,  -- Length of each dash
    ---@type number
    gapLen = nil,  -- Length of gap between dashes
    ---@type number
    phase = nil,  -- Phase offset for dashes
    ---@type number
    radius = nil,  -- Corner radius
    ---@type number
    arcSteps = nil,  -- Number of segments for corner arcs
    ---@type number
    thickness = nil,  -- Thickness of the dashes
    ---@type Color
    color = nil  -- Color of the dashes
}


---
---
---@class layer.CmdDrawGradientRectCentered
layer.CmdDrawGradientRectCentered = {
    ---@type number
    cx = nil,  -- Center X
    ---@type number
    cy = nil,  -- Center Y
    ---@type number
    width = nil,  -- Width
    ---@type number
    height = nil,  -- Height
    ---@type Color
    topLeft = nil,  -- Top-left color
    ---@type Color
    topRight = nil,  -- Top-right color
    ---@type Color
    bottomRight = nil,  -- Bottom-right color
    ---@type Color
    bottomLeft = nil  -- Bottom-left color
}


---
---
---@class layer.CmdDrawGradientRectRoundedCentered
layer.CmdDrawGradientRectRoundedCentered = {
    ---@type number
    cx = nil,  -- Center X
    ---@type number
    cy = nil,  -- Center Y
    ---@type number
    width = nil,  -- Width
    ---@type number
    height = nil,  -- Height
    ---@type number
    roundness = nil,  -- Corner roundness
    ---@type number
    segments = nil,  -- Number of segments for corners
    ---@type Color
    topLeft = nil,  -- Top-left color
    ---@type Color
    topRight = nil,  -- Top-right color
    ---@type Color
    bottomRight = nil,  -- Bottom-right color
    ---@type Color
    bottomLeft = nil  -- Bottom-left color
}


---
---
---@class layer.CmdDrawBatchedEntities
layer.CmdDrawBatchedEntities = {
    ---@type Registry
    registry = nil,  -- The entity registry
    ---@type Entity[]
    entities = nil,  -- Array of entities to batch render
    ---@type boolean
    autoOptimize = nil  -- Whether to automatically optimize shader batching (default: true)
}


---
---
---@class layer.CmdDrawDashedLine
layer.CmdDrawDashedLine = {
    ---@type Vector2
    start = nil,  -- Start position
    ---@type Vector2
    endPoint = nil,  -- End position
    ---@type number
    dashLength = nil,  -- Length of each dash
    ---@type number
    gapLength = nil,  -- Length of gap between dashes
    ---@type number
    phase = nil,  -- Phase offset for dashes
    ---@type number
    thickness = nil,  -- Thickness of the dashes
    ---@type Color
    color = nil,  -- Color of the dashes
    ---@type number
    x1 = nil,  -- Start X
    ---@type number
    y1 = nil,  -- Start Y
    ---@type number
    x2 = nil,  -- End X
    ---@type number
    y2 = nil,  -- End Y
    ---@type number
    dashSize = nil,  -- Dash size
    ---@type number
    gapSize = nil,  -- Gap size
    ---@type Color
    color = nil,  -- Color
    ---@type number
    lineWidth = nil  -- Line width
}


---
---
---@class layer.CmdScale
layer.CmdScale = {
    ---@type number
    scaleX = nil,  -- Scale in X
    ---@type number
    scaleY = nil  -- Scale in Y
}


---
---
---@class layer.CmdRotate
layer.CmdRotate = {
    ---@type number
    angle = nil  -- Rotation angle in degrees
}


---
---
---@class layer.CmdAddPush
layer.CmdAddPush = {
    ---@type table
    camera = nil  -- Camera parameters
}


---
---
---@class layer.CmdAddPop
layer.CmdAddPop = {
    ---@type false
    dummy = nil  -- Unused field
}


---
---
---@class layer.CmdPushMatrix
layer.CmdPushMatrix = {
    ---@type false
    dummy = nil  -- Unused field
}


---
---
---@class layer.CmdPushObjectTransformsToMatrix
layer.CmdPushObjectTransformsToMatrix = {
    ---@type Entity
    entity = nil  -- Entity to get transforms from
}


---
---
---@class layer.CmdScopedTransformCompositeRender
layer.CmdScopedTransformCompositeRender = {
    ---@type Entity
    entity = nil,  -- Entity to get transforms from
    ---@type vector
    payload = nil  -- Additional payload data
}


---
---
---@class layer.CmdPopMatrix
layer.CmdPopMatrix = {
    ---@type false
    dummy = nil  -- Unused field
}


---
---
---@class layer.CmdDrawCircleFilled
layer.CmdDrawCircleFilled = {
    ---@type number
    x = nil,  -- Center X
    ---@type number
    y = nil,  -- Center Y
    ---@type number
    radius = nil,  -- Radius
    ---@type Color
    color = nil  -- Fill color
}


---
---
---@class layer.CmdDrawCircleLine
layer.CmdDrawCircleLine = {
    ---@type number
    x = nil,  -- Center X
    ---@type number
    y = nil,  -- Center Y
    ---@type number
    innerRadius = nil,  -- Inner radius
    ---@type number
    outerRadius = nil,  -- Outer radius
    ---@type number
    startAngle = nil,  -- Start angle in degrees
    ---@type number
    endAngle = nil,  -- End angle in degrees
    ---@type number
    segments = nil,  -- Number of segments
    ---@type Color
    color = nil  -- Line color
}


---
---
---@class layer.CmdDrawRectangle
layer.CmdDrawRectangle = {
    ---@type number
    x = nil,  -- Top-left X
    ---@type number
    y = nil,  -- Top-left Y
    ---@type number
    width = nil,  -- Width
    ---@type number
    height = nil,  -- Height
    ---@type Color
    color = nil,  -- Fill color
    ---@type number
    lineWidth = nil  -- Line width
}


---
---
---@class layer.CmdDrawRectanglePro
layer.CmdDrawRectanglePro = {
    ---@type number
    offsetX = nil,  -- Offset X
    ---@type number
    offsetY = nil,  -- Offset Y
    ---@type Vector2
    size = nil,  -- Size
    ---@type Vector2
    rotationCenter = nil,  -- Rotation center
    ---@type number
    rotation = nil,  -- Rotation
    ---@type Color
    color = nil  -- Color
}


---
---
---@class layer.CmdDrawRectangleLinesPro
layer.CmdDrawRectangleLinesPro = {
    ---@type number
    offsetX = nil,  -- Offset X
    ---@type number
    offsetY = nil,  -- Offset Y
    ---@type Vector2
    size = nil,  -- Size
    ---@type number
    lineThickness = nil,  -- Line thickness
    ---@type Color
    color = nil  -- Color
}


---
---
---@class layer.CmdDrawLine
layer.CmdDrawLine = {
    ---@type number
    x1 = nil,  -- Start X
    ---@type number
    y1 = nil,  -- Start Y
    ---@type number
    x2 = nil,  -- End X
    ---@type number
    y2 = nil,  -- End Y
    ---@type Color
    color = nil,  -- Line color
    ---@type number
    lineWidth = nil  -- Line width
}


---
---
---@class layer.CmdDrawDashedLine
layer.CmdDrawDashedLine = {
}


---
---
---@class layer.CmdDrawText
layer.CmdDrawText = {
    ---@type string
    text = nil,  -- Text
    ---@type Font
    font = nil,  -- Font
    ---@type number
    x = nil,  -- X
    ---@type number
    y = nil,  -- Y
    ---@type Color
    color = nil,  -- Color
    ---@type number
    fontSize = nil  -- Font size
}


---
---
---@class layer.CmdDrawTextCentered
layer.CmdDrawTextCentered = {
    ---@type string
    text = nil,  -- Text
    ---@type Font
    font = nil,  -- Font
    ---@type number
    x = nil,  -- X
    ---@type number
    y = nil,  -- Y
    ---@type Color
    color = nil,  -- Color
    ---@type number
    fontSize = nil  -- Font size
}


---
---
---@class layer.CmdTextPro
layer.CmdTextPro = {
    ---@type string
    text = nil,  -- Text
    ---@type Font
    font = nil,  -- Font
    ---@type number
    x = nil,  -- X
    ---@type number
    y = nil,  -- Y
    ---@type Vector2
    origin = nil,  -- Origin
    ---@type number
    rotation = nil,  -- Rotation
    ---@type number
    fontSize = nil,  -- Font size
    ---@type number
    spacing = nil,  -- Spacing
    ---@type Color
    color = nil  -- Color
}


---
---
---@class layer.CmdDrawImage
layer.CmdDrawImage = {
    ---@type Texture2D
    image = nil,  -- Image
    ---@type number
    x = nil,  -- X
    ---@type number
    y = nil,  -- Y
    ---@type number
    rotation = nil,  -- Rotation
    ---@type number
    scaleX = nil,  -- Scale X
    ---@type number
    scaleY = nil,  -- Scale Y
    ---@type Color
    color = nil  -- Tint color
}


---
---
---@class layer.CmdTexturePro
layer.CmdTexturePro = {
    ---@type Texture2D
    texture = nil,  -- Texture
    ---@type Rectangle
    source = nil,  -- Source rect
    ---@type number
    offsetX = nil,  -- Offset X
    ---@type number
    offsetY = nil,  -- Offset Y
    ---@type Vector2
    size = nil,  -- Size
    ---@type Vector2
    rotationCenter = nil,  -- Rotation center
    ---@type number
    rotation = nil,  -- Rotation
    ---@type Color
    color = nil  -- Color
}


---
---
---@class layer.CmdDrawEntityAnimation
layer.CmdDrawEntityAnimation = {
    ---@type Entity
    e = nil,  -- entt::entity
    ---@type Registry
    registry = nil,  -- EnTT registry
    ---@type number
    x = nil,  -- X
    ---@type number
    y = nil  -- Y
}


---
---
---@class layer.CmdDrawTransformEntityAnimation
layer.CmdDrawTransformEntityAnimation = {
    ---@type Entity
    e = nil,  -- entt::entity
    ---@type Registry
    registry = nil  -- EnTT registry
}


---
---
---@class layer.CmdDrawTransformEntityAnimationPipeline
layer.CmdDrawTransformEntityAnimationPipeline = {
    ---@type Entity
    e = nil,  -- entt::entity
    ---@type Registry
    registry = nil  -- EnTT registry
}


---
---
---@class layer.CmdSetShader
layer.CmdSetShader = {
    ---@type Shader
    shader = nil  -- Shader object
}


---
---
---@class layer.CmdResetShader
layer.CmdResetShader = {
}


---
---
---@class layer.CmdSetBlendMode
layer.CmdSetBlendMode = {
    ---@type number
    blendMode = nil  -- Blend mode
}


---
---
---@class layer.CmdUnsetBlendMode
layer.CmdUnsetBlendMode = {
    ---@type false
    dummy = nil  -- Unused field
}


---
---
---@class layer.CmdSendUniformFloat
layer.CmdSendUniformFloat = {
    ---@type Shader
    shader = nil,  -- Shader
    ---@type string
    uniform = nil,  -- Uniform name
    ---@type number
    value = nil  -- Float value
}


---
---
---@class layer.CmdSendUniformInt
layer.CmdSendUniformInt = {
    ---@type Shader
    shader = nil,  -- Shader
    ---@type string
    uniform = nil,  -- Uniform name
    ---@type number
    value = nil  -- Int value
}


---
---
---@class layer.CmdSendUniformVec2
layer.CmdSendUniformVec2 = {
    ---@type Shader
    shader = nil,  -- Shader
    ---@type string
    uniform = nil,  -- Uniform name
    ---@type Vector2
    value = nil  -- Vec2 value
}


---
---
---@class layer.CmdSendUniformVec3
layer.CmdSendUniformVec3 = {
    ---@type Shader
    shader = nil,  -- Shader
    ---@type string
    uniform = nil,  -- Uniform name
    ---@type Vector3
    value = nil  -- Vec3 value
}


---
---
---@class layer.CmdSendUniformVec4
layer.CmdSendUniformVec4 = {
    ---@type Shader
    shader = nil,  -- Shader
    ---@type string
    uniform = nil,  -- Uniform name
    ---@type Vector4
    value = nil  -- Vec4 value
}


---
---
---@class layer.CmdSendUniformFloatArray
layer.CmdSendUniformFloatArray = {
    ---@type Shader
    shader = nil,  -- Shader
    ---@type string
    uniform = nil,  -- Uniform name
    ---@type table
    values = nil  -- Float array
}


---
---
---@class layer.CmdSendUniformIntArray
layer.CmdSendUniformIntArray = {
    ---@type Shader
    shader = nil,  -- Shader
    ---@type string
    uniform = nil,  -- Uniform name
    ---@type table
    values = nil  -- Int array
}


---
---
---@class layer.CmdVertex
layer.CmdVertex = {
    ---@type Vector3
    v = nil,  -- Position
    ---@type Color
    color = nil  -- Vertex color
}


---
---
---@class layer.CmdBeginOpenGLMode
layer.CmdBeginOpenGLMode = {
    ---@type number
    mode = nil  -- GL mode enum
}


---
---
---@class layer.CmdEndOpenGLMode
layer.CmdEndOpenGLMode = {
    ---@type false
    dummy = nil  -- Unused field
}


---
---
---@class layer.CmdSetColor
layer.CmdSetColor = {
    ---@type Color
    color = nil  -- Draw color
}


---
---
---@class layer.CmdSetLineWidth
layer.CmdSetLineWidth = {
    ---@type number
    lineWidth = nil  -- Line width
}


---
---
---@class layer.CmdSetTexture
layer.CmdSetTexture = {
    ---@type Texture2D
    texture = nil  -- Texture to bind
}


---
---
---@class layer.CmdRenderRectVerticesFilledLayer
layer.CmdRenderRectVerticesFilledLayer = {
    ---@type Rectangle
    outerRec = nil,  -- Outer rectangle
    ---@type bool
    progressOrFullBackground = nil,  -- Mode
    ---@type table
    cache = nil,  -- Vertex cache
    ---@type Color
    color = nil  -- Fill color
}


---
---
---@class layer.CmdRenderRectVerticesOutlineLayer
layer.CmdRenderRectVerticesOutlineLayer = {
    ---@type table
    cache = nil,  -- Vertex cache
    ---@type Color
    color = nil,  -- Outline color
    ---@type bool
    useFullVertices = nil  -- Use full vertices
}


---
---
---@class layer.CmdDrawPolygon
layer.CmdDrawPolygon = {
    ---@type table
    vertices = nil,  -- Vertex array
    ---@type Color
    color = nil,  -- Polygon color
    ---@type number
    lineWidth = nil  -- Line width
}


---
---
---@class layer.CmdRenderNPatchRect
layer.CmdRenderNPatchRect = {
    ---@type Texture2D
    sourceTexture = nil,  -- Source texture
    ---@type NPatchInfo
    info = nil,  -- Nine-patch info
    ---@type Rectangle
    dest = nil,  -- Destination
    ---@type Vector2
    origin = nil,  -- Origin
    ---@type number
    rotation = nil,  -- Rotation
    ---@type Color
    tint = nil  -- Tint color
}


---
---
---@class layer.CmdDrawTriangle
layer.CmdDrawTriangle = {
    ---@type Vector2
    p1 = nil,  -- Point 1
    ---@type Vector2
    p2 = nil,  -- Point 2
    ---@type Vector2
    p3 = nil,  -- Point 3
    ---@type Color
    color = nil  -- Triangle color
}


---
--- A single draw command with type, data payload, and z-order.
---
---@class layer.DrawCommandV2
layer.DrawCommandV2 = {
    ---@type number
    type = nil,  -- The draw command type enum
    ---@type any
    data = nil,  -- The actual command data (CmdX struct)
    ---@type number
    z = nil  -- Z-order depth value for sorting
}


---
---
---@class layer.DrawCommandSpace
layer.DrawCommandSpace = {
    ---@type number
    Screen = nil,  -- Screen space draw commands
    ---@type number
    World = nil  -- World space draw commands
}


---
---
---@class command_buffer
command_buffer = {
}


---
--- OpenGL enum GL_KEEP
---
---@class GL_KEEP
GL_KEEP = {
}


---
--- OpenGL enum GL_ZERO
---
---@class GL_ZERO
GL_ZERO = {
}


---
--- OpenGL enum GL_REPLACE
---
---@class GL_REPLACE
GL_REPLACE = {
}


---
--- OpenGL enum GL_ALWAYS
---
---@class GL_ALWAYS
GL_ALWAYS = {
}


---
--- OpenGL enum GL_EQUAL
---
---@class GL_EQUAL
GL_EQUAL = {
}


---
--- OpenGL enum GL_FALSE
---
---@class GL_FALSE
GL_FALSE = {
}


---
--- Manages shaders, their uniforms, and rendering modes.
---
---@class shaders
shaders = {
}


---
--- A collection of uniform values to be applied to a shader.
---
---@class shaders.ShaderUniformSet
shaders.ShaderUniformSet = {
}

---
--- Sets or updates a uniform value by name within the set.
---
---@param name string # The name of the uniform to set.
---@param value any # The value to set (e.g., number, boolean, Vector2, Texture2D, etc.).
function shaders.ShaderUniformSet:set(...) end

---
--- Gets a uniform's value by its name.
---
---@param name string # The name of the uniform to retrieve.
---@return any|nil # The value of the uniform, or nil if not found.
function shaders.ShaderUniformSet:get(...) end


---
--- An entity component for managing per-entity shader uniforms.
---
---@class shaders.ShaderUniformComponent
shaders.ShaderUniformComponent = {
}

---
--- Sets a static uniform value for a specific shader within this component.
---
---@param shaderName string # The name of the shader this uniform belongs to.
---@param uniformName string # The name of the uniform to set.
---@param value any # The value to assign to the uniform.
function shaders.ShaderUniformComponent:set(...) end

---
--- Registers a callback to dynamically compute and apply uniforms for an entity.
---
---@param shaderName string # The shader this callback applies to.
---@param callback fun(shader: Shader, entity: Entity) # A function called just before rendering the entity.
function shaders.ShaderUniformComponent:registerEntityUniformCallback(...) end

---
--- Returns the underlying ShaderUniformSet for a specific shader, or nil if not found.
---
---@param shaderName string # The name of the shader.
---@return shaders.ShaderUniformSet|nil
function shaders.ShaderUniformComponent:getSet(...) end

---
--- Applies this component's static uniforms and executes its dynamic callbacks for a given entity.
---
---@param shader Shader # The target shader.
---@param shaderName string # The name of the shader configuration to apply.
---@param entity Entity # The entity to source dynamic uniform values from.
function shaders.ShaderUniformComponent:applyToShaderForEntity(...) end


---
--- Draw command batching system for optimized shader rendering.
---
---@class shader_draw_commands
shader_draw_commands = {
}


---
--- Types of draw commands that can be batched.
---
---@class shader_draw_commands.DrawCommandType
shader_draw_commands.DrawCommandType = {
}


---
--- Manages a batch of draw commands for optimized rendering.
---
---@class shader_draw_commands.DrawCommandBatch
shader_draw_commands.DrawCommandBatch = {
}

---
--- Start recording draw commands into the batch.
---
---@return nil
function shader_draw_commands.DrawCommandBatch:beginRecording(...) end

---
--- Stop recording draw commands.
---
---@return nil
function shader_draw_commands.DrawCommandBatch:endRecording(...) end

---
--- Check if currently recording commands.
---
---@return boolean
function shader_draw_commands.DrawCommandBatch:recording(...) end

---
--- Add a command to begin using a shader.
---
---@param shaderName string
---@return nil
function shader_draw_commands.DrawCommandBatch:addBeginShader(...) end

---
--- Add a command to end the current shader.
---
---@return nil
function shader_draw_commands.DrawCommandBatch:addEndShader(...) end

---
--- Add a command to draw a texture.
---
---@param texture Texture2D
---@param sourceRect Rectangle
---@param position Vector2
---@param tint? Color
---@return nil
function shader_draw_commands.DrawCommandBatch:addDrawTexture(...) end

---
--- Add a command to draw text.
---
---@param text string
---@param position Vector2
---@param fontSize number
---@param spacing number
---@param color? Color
---@param font? Font
---@return nil
function shader_draw_commands.DrawCommandBatch:addDrawText(...) end

---
--- Add a custom command function to execute.
---
---@param func fun()
---@return nil
function shader_draw_commands.DrawCommandBatch:addCustomCommand(...) end

---
--- Execute all recorded commands in order.
---
---@return nil
function shader_draw_commands.DrawCommandBatch:execute(...) end

---
--- Optimize command order to minimize shader state changes.
---
---@return nil
function shader_draw_commands.DrawCommandBatch:optimize(...) end

---
--- Clear all commands from the batch.
---
---@return nil
function shader_draw_commands.DrawCommandBatch:clear(...) end

---
--- Get the number of commands in the batch.
---
---@return integer
function shader_draw_commands.DrawCommandBatch:size(...) end


---
--- Structure containing font data for localization.
---
---@class FontData
FontData = {
}


---
--- namespace for localization functions
---
---@class localization
localization = {
}


---
--- General-purpose utility functions.
---
---@class util
util = {
}


---
--- Telemetry event helpers.
---
---@class telemetry
telemetry = {
}


---
--- Manages an entity's position, size, rotation, and scale, with spring dynamics for smooth visual updates.
---
---@class Transform
Transform = {
    ---@type number
    actualX = nil,  -- The logical X position.
    ---@type number
    visualX = nil,  -- The visual (spring-interpolated) X position.
    ---@type number
    actualY = nil,  -- The logical Y position.
    ---@type number
    visualY = nil,  -- The visual (spring-interpolated) Y position.
    ---@type number
    actualW = nil,  -- The logical width.
    ---@type number
    visualW = nil,  -- The visual width.
    ---@type number
    actualH = nil,  -- The logical height.
    ---@type number
    visualH = nil,  -- The visual height.
    ---@type number
    rotation = nil,  -- The logical rotation in degrees.
    ---@type number
    scale = nil  -- The logical scale multiplier.
}

---
--- Updates cached transform values.
---
---@overload fun(self, force:boolean)
---@overload fun(self, x:Spring, y:Spring, w:Spring, h:Spring, r:Spring, s:Spring, force:boolean)
function Transform:updateCachedValues(...) end

---
--- Gets the visual rotation.
---
---@return number
function Transform:visualR(...) end

---
--- Gets the visual rotation including dynamic motion.
---
---@return number
function Transform:visualRWithMotion(...) end

---
--- Gets the visual scale.
---
---@return number
function Transform:visualS(...) end

---
--- Gets the visual scale including dynamic motion.
---
---@return number
function Transform:visualSWithMotion(...) end

---
--- Gets the X position spring.
---
---@return Spring
function Transform:xSpring(...) end

---
--- Gets the Y position spring.
---
---@return Spring
function Transform:ySpring(...) end

---
--- Gets the width spring.
---
---@return Spring
function Transform:wSpring(...) end

---
--- Gets the height spring.
---
---@return Spring
function Transform:hSpring(...) end

---
--- Gets the rotation spring.
---
---@return Spring
function Transform:rSpring(...) end

---
--- Gets the scale spring.
---
---@return Spring
function Transform:sSpring(...) end

---
--- Gets the X-axis hover buffer.
---
---@return number
function Transform:hoverBufferX(...) end

---
--- Gets the Y-axis hover buffer.
---
---@return number
function Transform:hoverBufferY(...) end


---
--- Defines how an entity relates to its master in the transform hierarchy.
---
---@class InheritedPropertiesType
InheritedPropertiesType = {
    RoleRoot = 0,  -- A root object that is not influenced by a master.
    RoleInheritor = 1,  -- Inherits transformations from a master.
    RoleCarbonCopy = 2,  -- Perfectly mirrors its master's transformations.
    PermanentAttachment = 3  -- A permanent, non-detachable inheritor.
}


---
--- Defines the strength of a transform bond.
---
---@class InheritedPropertiesSync
InheritedPropertiesSync = {
    Strong = 0,  -- The property is directly copied from the master.
    Weak = 1  -- The property is influenced by but not locked to the master.
}


---
--- Bitmask flags for aligning an entity to its master.
---
---@class AlignmentFlag
AlignmentFlag = {
    NONE = 0,  -- No alignment.
    HORIZONTAL_LEFT = 1,  -- Align left edges.
    HORIZONTAL_CENTER = 2,  -- Align horizontal centers.
    HORIZONTAL_RIGHT = 4,  -- Align right edges.
    VERTICAL_TOP = 8,  -- Align top edges.
    VERTICAL_CENTER = 16,  -- Align vertical centers.
    VERTICAL_BOTTOM = 32,  -- Align bottom edges.
    ALIGN_TO_INNER_EDGES = 64  -- Align to inner instead of outer edges.
}


---
--- Optional Lua-defined immediate draw override for entities. Allows custom drawing inside the entity's transform, optionally disabling the default sprite rendering.
---
---@class RenderImmediateCallback
RenderImmediateCallback = {
    fn = Lua function (width:number, height:number),  -- The Lua drawing function. Called centered on the entity transform.
    disableSpriteRendering = boolean  -- If true, disables the default sprite or animation rendering for this entity.
}


---
--- Stores alignment flags and offsets for an inherited property.
---
---@class Alignment
Alignment = {
    ---@type integer
    alignment = nil,  -- The raw bitmask of alignment flags.
    ---@type Vector2
    extraOffset = nil,  -- Additional fine-tuning offset.
    ---@type Vector2
    prevExtraOffset = nil  -- Previous frame's fine-tuning offset.
}

---
--- Checks if a specific alignment flag is set.
---
---@param flag AlignmentFlag
---@return boolean
function Alignment:hasFlag(...) end

---
--- Adds an alignment flag.
---
---@param flag AlignmentFlag
---@return nil
function Alignment:addFlag(...) end

---
--- Removes an alignment flag.
---
---@param flag AlignmentFlag
---@return nil
function Alignment:removeFlag(...) end

---
--- Toggles an alignment flag.
---
---@param flag AlignmentFlag
---@return nil
function Alignment:toggleFlag(...) end


---
--- Defines how an entity inherits transform properties from a master entity.
---
---@class InheritedProperties
InheritedProperties = {
    ---@type InheritedPropertiesType
    role_type = nil,  -- The role of this entity in the hierarchy.
    ---@type Entity
    master = nil,  -- The master entity this entity inherits from.
    ---@type Vector2
    offset = nil,  -- The current offset from the master.
    ---@type Vector2
    prevOffset = nil,  -- The previous frame's offset.
    ---@type InheritedPropertiesSync|nil
    location_bond = nil,  -- The sync bond for location.
    ---@type InheritedPropertiesSync|nil
    size_bond = nil,  -- The sync bond for size.
    ---@type InheritedPropertiesSync|nil
    rotation_bond = nil,  -- The sync bond for rotation.
    ---@type Vector2
    extraAlignmentFinetuningOffset = nil,  -- An additional fine-tuning offset for alignment.
    ---@type InheritedPropertiesSync|nil
    scale_bond = nil,  -- The sync bond for scale.
    ---@type Alignment|nil
    flags = nil  -- Alignment flags and data.
}


---
--- A fluent builder for creating InheritedProperties components.
---
---@class InheritedPropertiesBuilder
InheritedPropertiesBuilder = {
}

---
--- Sets the role type.
---
---@param type InheritedPropertiesType
---@return self
function InheritedPropertiesBuilder:addRoleType(...) end

---
--- Sets the master entity.
---
---@param master Entity
---@return self
function InheritedPropertiesBuilder:addMaster(...) end

---
--- Sets the offset.
---
---@param offset Vector2
---@return self
function InheritedPropertiesBuilder:addOffset(...) end

---
--- Sets the location bond.
---
---@param bond InheritedPropertiesSync
---@return self
function InheritedPropertiesBuilder:addLocationBond(...) end

---
--- Sets the size bond.
---
---@param bond InheritedPropertiesSync
---@return self
function InheritedPropertiesBuilder:addSizeBond(...) end

---
--- Sets the rotation bond.
---
---@param bond InheritedPropertiesSync
---@return self
function InheritedPropertiesBuilder:addRotationBond(...) end

---
--- Sets the scale bond.
---
---@param bond InheritedPropertiesSync
---@return self
function InheritedPropertiesBuilder:addScaleBond(...) end

---
--- Sets the alignment flags.
---
---@param flags AlignmentFlag
---@return self
function InheritedPropertiesBuilder:addAlignment(...) end

---
--- Sets the alignment offset.
---
---@param offset Vector2
---@return self
function InheritedPropertiesBuilder:addAlignmentOffset(...) end

---
--- Constructs the final InheritedProperties object.
---
---@return InheritedProperties
function InheritedPropertiesBuilder:build(...) end


---
--- A table of optional script-defined callback methods for a GameObject.
---
---@class GameObjectMethods
GameObjectMethods = {
    ---@type function|nil
    getObjectToDrag = nil,  -- Returns the entity that should be dragged.
    ---@type function|nil
    update = nil,  -- Called every frame.
    ---@type function|nil
    draw = nil,  -- Called every frame for drawing.
    ---@type function|nil
    onClick = nil,  -- Called on click.
    ---@type function|nil
    onRelease = nil,  -- Called on click release.
    ---@type function|nil
    onHover = nil,  -- Called when hover starts.
    ---@type function|nil
    onStopHover = nil,  -- Called when hover ends.
    ---@type function|nil
    onDrag = nil,  -- Called while dragging.
    ---@type function|nil
    onStopDrag = nil  -- Called when dragging stops.
}


---
--- A collection of boolean flags representing the current state of a GameObject.
---
---@class GameObjectState
GameObjectState = {
    ---@type boolean
    visible = nil,
    ---@type boolean
    collisionEnabled = nil,
    ---@type boolean
    isColliding = nil,
    ---@type boolean
    focusEnabled = nil,
    ---@type boolean
    isBeingFocused = nil,
    ---@type boolean
    hoverEnabled = nil,
    ---@type boolean
    isBeingHovered = nil,
    ---@type boolean
    enlargeOnHover = nil,
    ---@type boolean
    enlargeOnDrag = nil,
    ---@type boolean
    clickEnabled = nil,
    ---@type boolean
    isBeingClicked = nil,
    ---@type boolean
    dragEnabled = nil,
    ---@type boolean
    isBeingDragged = nil,
    ---@type boolean
    triggerOnReleaseEnabled = nil,
    ---@type boolean
    isTriggeringOnRelease = nil,
    ---@type boolean
    isUnderOverlay = nil
}


---
--- The core component for a scene entity, managing hierarchy, state, and scriptable logic.
---
---@class GameObject
GameObject = {
    ---@type Entity|nil
    parent = nil,
    ---@type table<Entity, boolean>
    children = nil,
    ---@type table<integer, Entity>
    orderedChildren = nil,
    ---@type boolean
    ignoresPause = nil,
    ---@type Entity|nil
    container = nil,
    ---@type Transform|nil
    collisionTransform = nil,
    ---@type number
    clickTimeout = nil,
    ---@type GameObjectMethods|nil
    methods = nil,
    ---@type function|nil
    updateFunction = nil,
    ---@type function|nil
    drawFunction = nil,
    ---@type GameObjectState
    state = nil,
    ---@type Vector2
    dragOffset = nil,
    ---@type Vector2
    clickOffset = nil,
    ---@type Vector2
    hoverOffset = nil,
    ---@type Vector2
    shadowDisplacement = nil,
    ---@type Vector2
    layerDisplacement = nil,
    ---@type Vector2
    layerDisplacementPrev = nil,
    ---@type number
    shadowHeight = nil
}


---
--- Contains information about an entity's render and collision order.
---
---@class CollisionOrderInfo
CollisionOrderInfo = {
    ---@type boolean
    hasCollisionOrder = nil,
    ---@type Rectangle
    parentBox = nil,
    ---@type integer
    treeOrder = nil,
    ---@type integer
    layerOrder = nil
}


---
--- A simple component storing an entity's tree order for sorting.
---
---@class TreeOrderComponent
TreeOrderComponent = {
    ---@type integer
    order = nil
}


---
--- A global system for creating and managing all Transforms and GameObjects.
---
---@class transform
transform = {
}


---
--- Attach a per-entity Lua drawing callback that renders in local space. Use for custom shapes, outlines, meters, or HUD overlays. Local (0,0) is top-left of the content rectangle.
---
---@class transform.RenderLocalCallback
transform.RenderLocalCallback = {
}


---
--- A tag component indicating an entity is attached to a UI element.
---
---@class ObjectAttachedToUITag
ObjectAttachedToUITag = {
}


---
--- Defines the fundamental type or behavior of a UI element.
---
---@class UITypeEnum
UITypeEnum = {
    NONE = 0,  -- No specific UI type.
    ROOT = 1,  -- The root of a UI tree.
    VERTICAL_CONTAINER = 2,  -- Arranges children vertically.
    HORIZONTAL_CONTAINER = 3,  -- Arranges children horizontally.
    SCROLL_PANE = 4,  -- A scrollable panel for content.
    SLIDER_UI = 5,  -- A slider UI element.
    INPUT_TEXT = 6,  -- A text input UI element.
    RECT_SHAPE = 7,  -- A rectangular shape UI element.
    TEXT = 8,  -- A simple text UI element.
    OBJECT = 9  -- A game object UI element.
}


---
--- Core component for a UI element, linking its type, root, and configuration.
---
---@class UIElementComponent
UIElementComponent = {
    ---@type UITypeEnum
    UIT = nil,  -- The type of this UI element.
    ---@type Entity
    uiBox = nil,  -- The root entity of the UI box this element belongs to.
    ---@type UIConfig
    config = nil  -- The configuration settings for this element.
}


---
--- Component for managing the state of a text input UI element.
---
---@class TextInput
TextInput = {
    ---@type string
    text = nil,  -- The current text content.
    ---@type integer
    cursorPos = nil,  -- The position of the text cursor.
    ---@type integer
    maxLength = nil,  -- The maximum allowed length of the text.
    ---@type boolean
    allCaps = nil,  -- If true, all input is converted to uppercase.
    ---@type function|nil
    callback = nil  -- A callback function triggered on text change.
}


---
--- A component that hooks global text input to a specific text input entity.
---
---@class TextInputHook
TextInputHook = {
    ---@type Entity
    hookedEntity = nil  -- The entity that currently has text input focus.
}


---
--- Defines a root of a UI tree, managing its draw layers.
---
---@class UIBoxComponent
UIBoxComponent = {
    ---@type Entity
    uiRoot = nil,  -- The root entity of this UI tree.
    ---@type table
    drawLayers = nil,  -- A map of layers used for drawing the UI.
    ---@type function|nil
    onBoxResize = nil  -- A callback function triggered when the box is resized.
}


---
--- Holds dynamic state information for a UI element.
---
---@class UIState
UIState = {
    ---@type Vector2
    contentDimensions = nil,  -- The calculated dimensions of the element's content.
    ---@type TextDrawable
    textDrawable = nil,  -- The drawable text object.
    ---@type Entity
    last_clicked = nil,  -- The last entity that was clicked within this UI context.
    ---@type number
    object_focus_timer = nil,  -- Timer for object focus events.
    ---@type number
    focus_timer = nil  -- General purpose focus timer.
}


---
--- Represents a tooltip with a title and descriptive text.
---
---@class Tooltip
Tooltip = {
    ---@type string
    title = nil,  -- The title of the tooltip.
    ---@type string
    text = nil  -- The main body text of the tooltip.
}


---
--- Arguments for configuring focus and navigation behavior.
---
---@class FocusArgs
FocusArgs = {
    ---@type GamepadButton
    button = nil,  -- The gamepad button associated with this focus.
    ---@type boolean
    snap_to = nil,  -- If the view should snap to this element when focused.
    ---@type boolean
    registered = nil,  -- Whether this focus is registered with the focus system.
    ---@type string
    type = nil,  -- The type of focus.
    ---@type table<string, Entity>
    claim_focus_from = nil,  -- Entities this element can claim focus from.
    ---@type Entity|nil
    redirect_focus_to = nil,  -- Redirect focus to another entity.
    ---@type table<string, Entity>
    nav = nil,  -- Navigation map (e.g., nav.up = otherEntity).
    ---@type boolean
    no_loop = nil  -- Disables navigation looping.
}


---
--- Data for a UI slider element.
---
---@class SliderComponent
SliderComponent = {
    ---@type string
    color = nil,
    ---@type string
    text = nil,
    ---@type number
    min = nil,
    ---@type number
    max = nil,
    ---@type number
    value = nil,
    ---@type integer
    decimal_places = nil,
    ---@type number
    w = nil,
    ---@type number
    h = nil
}


---
--- Represents a tile in an inventory grid, potentially holding an item.
---
---@class InventoryGridTileComponent
InventoryGridTileComponent = {
    ---@type Entity|nil
    item = nil  -- The item entity occupying this tile.
}


---
--- Defines how a UI element's background is styled.
---
---@class UIStylingType
UIStylingType = {
    RoundedRectangle = 0,  -- A simple rounded rectangle.
    NinePatchBorders = 1  -- A 9-patch texture for scalable borders.
}


---
--- A comprehensive configuration component for defining all aspects of a UI element.
---
---@class UIConfig
UIConfig = {
    ---@type UIStylingType|nil
    stylingType = nil,  -- The visual style of the element.
    ---@type NPatchInfo|nil
    nPatchInfo = nil,  -- 9-patch slicing information.
    ---@type string|nil
    nPatchSourceTexture = nil,  -- Texture path for the 9-patch.
    ---@type string|nil
    id = nil,  -- Unique identifier for this UI element.
    ---@type string|nil
    instanceType = nil,  -- A specific instance type for categorization.
    ---@type UITypeEnum|nil
    uiType = nil,  -- The fundamental type of the UI element.
    ---@type string|nil
    drawLayer = nil,  -- The layer on which this element is drawn.
    ---@type string|nil
    group = nil,  -- The focus group this element belongs to.
    ---@type string|nil
    groupParent = nil,  -- The parent focus group.
    ---@type InheritedPropertiesSync|nil
    location_bond = nil,  -- Bonding strength for location.
    ---@type InheritedPropertiesSync|nil
    rotation_bond = nil,  -- Bonding strength for rotation.
    ---@type InheritedPropertiesSync|nil
    size_bond = nil,  -- Bonding strength for size.
    ---@type InheritedPropertiesSync|nil
    scale_bond = nil,  -- Bonding strength for scale.
    ---@type Vector2|nil
    offset = nil,  -- Offset from the parent/aligned position.
    ---@type number|nil
    scale = nil,  -- Scale multiplier.
    ---@type number|nil
    textSpacing = nil,  -- Spacing for text characters.
    ---@type boolean|nil
    focusWithObject = nil,  -- Whether focus is tied to a game object.
    ---@type boolean|nil
    refreshMovement = nil,  -- Force movement refresh.
    ---@type boolean|nil
    no_recalc = nil,  -- Prevents recalculation of transform.
    ---@type boolean|nil
    non_recalc = nil,  -- Alias for no_recalc.
    ---@type boolean|nil
    noMovementWhenDragged = nil,  -- Prevents movement while being dragged.
    ---@type string|nil
    master = nil,  -- ID of the master element.
    ---@type string|nil
    parent = nil,  -- ID of the parent element.
    ---@type Entity|nil
    object = nil,  -- The game object associated with this UI element.
    ---@type boolean|nil
    objectRecalculate = nil,  -- Force recalculation based on the object.
    ---@type integer|nil
    alignmentFlags = nil,  -- Bitmask of alignment flags.
    ---@type number|nil
    width = nil,  -- Explicit width.
    ---@type number|nil
    height = nil,  -- Explicit height.
    ---@type number|nil
    maxWidth = nil,  -- Maximum width.
    ---@type number|nil
    maxHeight = nil,  -- Maximum height.
    ---@type number|nil
    minWidth = nil,  -- Minimum width.
    ---@type number|nil
    minHeight = nil,  -- Minimum height.
    ---@type number|nil
    padding = nil,  -- Padding around the content.
    ---@type string|nil
    color = nil,  -- Background color.
    ---@type string|nil
    outlineColor = nil,  -- Outline color.
    ---@type number|nil
    outlineThickness = nil,  -- Outline thickness in pixels.
    ---@type boolean|nil
    makeMovementDynamic = nil,  -- Enables springy movement.
    ---@type Vector2|nil
    shadow = nil,  -- Offset for the shadow.
    ---@type Vector2|nil
    outlineShadow = nil,  -- Offset for the outline shadow.
    ---@type string|nil
    shadowColor = nil,  -- Color of the shadow.
    ---@type boolean|nil
    noFill = nil,  -- If true, the background is not filled.
    ---@type boolean|nil
    pixelatedRectangle = nil,  -- Use pixel-perfect rectangle drawing.
    ---@type boolean|nil
    canCollide = nil,  -- Whether collision is possible.
    ---@type boolean|nil
    collideable = nil,  -- Alias for canCollide.
    ---@type boolean|nil
    forceCollision = nil,  -- Forces collision checks.
    ---@type boolean|nil
    button_UIE = nil,  -- Behaves as a button.
    ---@type boolean|nil
    disable_button = nil,  -- Disables button functionality.
    ---@type function|nil
    progressBarFetchValueLambda = nil,  -- Function to get the progress bar's current value.
    ---@type boolean|nil
    progressBar = nil,  -- If this element is a progress bar.
    ---@type string|nil
    progressBarEmptyColor = nil,  -- Color of the empty part of the progress bar.
    ---@type string|nil
    progressBarFullColor = nil,  -- Color of the filled part of the progress bar.
    ---@type number|nil
    progressBarMaxValue = nil,  -- The maximum value of the progress bar.
    ---@type string|nil
    progressBarValueComponentName = nil,  -- Component name to fetch progress value from.
    ---@type string|nil
    progressBarValueFieldName = nil,  -- Field name to fetch progress value from.
    ---@type boolean|nil
    ui_object_updated = nil,  -- Flag indicating the UI object was updated.
    ---@type boolean|nil
    buttonDelayStart = nil,  -- Flag for button delay start.
    ---@type number|nil
    buttonDelay = nil,  -- Delay for button actions.
    ---@type number|nil
    buttonDelayProgress = nil,  -- Progress of the button delay.
    ---@type boolean|nil
    buttonDelayEnd = nil,  -- Flag for button delay end.
    ---@type boolean|nil
    buttonClicked = nil,  -- True if the button was clicked this frame.
    ---@type number|nil
    buttonDistance = nil,  -- Distance for button press effect.
    ---@type string|nil
    tooltip = nil,  -- Simple tooltip text.
    ---@type Tooltip|nil
    detailedTooltip = nil,  -- A detailed tooltip object.
    ---@type function|nil
    onDemandTooltip = nil,  -- A function that returns a tooltip.
    ---@type boolean|nil
    hover = nil,  -- Flag indicating if the element is being hovered.
    ---@type boolean|nil
    force_focus = nil,  -- Forces this element to take focus.
    ---@type boolean|nil
    dynamicMotion = nil,  -- Enables dynamic motion effects.
    ---@type boolean|nil
    choice = nil,  -- Marks this as a choice in a selection.
    ---@type boolean|nil
    chosen = nil,  -- True if this choice is currently selected.
    ---@type boolean|nil
    one_press = nil,  -- Button can only be pressed once.
    ---@type boolean|nil
    chosen_vert = nil,  -- Indicates a vertical choice selection.
    ---@type boolean|nil
    draw_after = nil,  -- Draw this element after its children.
    ---@type FocusArgs|nil
    focusArgs = nil,  -- Arguments for focus behavior.
    ---@type function|nil
    updateFunc = nil,  -- Custom update function.
    ---@type function|nil
    initFunc = nil,  -- Custom initialization function.
    ---@type function|nil
    onUIResizeFunc = nil,  -- Callback for when the UI is resized.
    ---@type function|nil
    onUIScalingResetToOne = nil,  -- Callback for when UI scaling resets.
    ---@type function|nil
    instaFunc = nil,  -- A function to be executed instantly.
    ---@type function|nil
    buttonCallback = nil,  -- Callback for button presses.
    ---@type boolean|nil
    buttonTemp = nil,  -- Temporary button flag.
    ---@type function|nil
    textGetter = nil,  -- Function to dynamically get text content.
    ---@type Entity|nil
    ref_entity = nil,  -- A referenced entity.
    ---@type string|nil
    ref_component = nil,  -- Name of a referenced component.
    ---@type any|nil
    ref_value = nil,  -- A referenced value.
    ---@type any|nil
    prev_ref_value = nil,  -- The previous referenced value.
    ---@type string|nil
    text = nil,  -- Static text content.
    ---@type string|nil
    language = nil,  -- Language key for localization.
    ---@type boolean|nil
    verticalText = nil,  -- If true, text is rendered vertically.
    ---@type boolean|nil
    hPopup = nil,  -- Is a horizontal popup.
    ---@type boolean|nil
    dPopup = nil,  -- Is a detailed popup.
    ---@type UIConfig|nil
    hPopupConfig = nil,  -- Configuration for the horizontal popup.
    ---@type UIConfig|nil
    dPopupConfig = nil,  -- Configuration for the detailed popup.
    ---@type boolean|nil
    extend_up = nil,  -- If the element extends upwards.
    ---@type Vector2|nil
    resolution = nil,  -- Resolution context for this element.
    ---@type boolean|nil
    emboss = nil,  -- Apply an emboss effect.
    ---@type boolean|nil
    line_emboss = nil,  -- Apply a line emboss effect.
    ---@type boolean|nil
    mid = nil,  -- A miscellaneous flag.
    ---@type boolean|nil
    noRole = nil,  -- This element has no inherited properties role.
    ---@type InheritedProperties|nil
    role = nil  -- The inherited properties role.
}


---
--- A fluent builder for creating UIConfig components.
---
---@class UIConfigBuilder
UIConfigBuilder = {
}

---
--- Creates a new builder instance with an ID.
---
---@param id string
---@return self
function UIConfigBuilder.create(...) end

---
--- Sets the ID.
---
---@param id string
---@return self
function UIConfigBuilder:addId(...) end

---
--- Sets a function to dynamically retrieve text.
---
---@param func function
---@return self
function UIConfigBuilder:addTextGetter(...) end

---
--- Sets the instance type.
---
---@param type string
---@return self
function UIConfigBuilder:addInstanceType(...) end

---
--- Sets the UI type.
---
---@param type UITypeEnum
---@return self
function UIConfigBuilder:addUiType(...) end

---
--- Sets the drawing layer.
---
---@param layer string
---@return self
function UIConfigBuilder:addDrawLayer(...) end

---
--- Sets the focus group.
---
---@param group string
---@return self
function UIConfigBuilder:addGroup(...) end

---
--- Sets the location bond.
---
---@param bond InheritedPropertiesSync
---@return self
function UIConfigBuilder:addLocationBond(...) end

---
--- Sets the rotation bond.
---
---@param bond InheritedPropertiesSync
---@return self
function UIConfigBuilder:addRotationBond(...) end

---
--- Sets the size bond.
---
---@param bond InheritedPropertiesSync
---@return self
function UIConfigBuilder:addSizeBond(...) end

---
--- Sets the scale bond.
---
---@param bond InheritedPropertiesSync
---@return self
function UIConfigBuilder:addScaleBond(...) end

---
--- Sets the transform offset.
---
---@param offset Vector2
---@return self
function UIConfigBuilder:addOffset(...) end

---
--- Sets the scale.
---
---@param scale number
---@return self
function UIConfigBuilder:addScale(...) end

---
--- Sets text character spacing.
---
---@param spacing number
---@return self
function UIConfigBuilder:addTextSpacing(...) end

---
--- Sets if focus is tied to the game object.
---
---@param focus boolean
---@return self
function UIConfigBuilder:addFocusWithObject(...) end

---
--- Sets if movement should be refreshed.
---
---@param refresh boolean
---@return self
function UIConfigBuilder:addRefreshMovement(...) end

---
--- Prevents movement while dragged.
---
---@param noMove boolean
---@return self
function UIConfigBuilder:addNoMovementWhenDragged(...) end

---
--- Prevents transform recalculation.
---
---@param noRecalc boolean
---@return self
function UIConfigBuilder:addNoRecalc(...) end

---
--- Alias for addNoRecalc.
---
---@param nonRecalc boolean
---@return self
function UIConfigBuilder:addNonRecalc(...) end

---
--- Enables dynamic (springy) movement.
---
---@param dynamic boolean
---@return self
function UIConfigBuilder:addMakeMovementDynamic(...) end

---
--- Sets the master UI element by ID.
---
---@param id string
---@return self
function UIConfigBuilder:addMaster(...) end

---
--- Sets the parent UI element by ID.
---
---@param id string
---@return self
function UIConfigBuilder:addParent(...) end

---
--- Attaches a game object.
---
---@param entity Entity
---@return self
function UIConfigBuilder:addObject(...) end

---
--- Sets the alignment flags.
---
---@param flags integer
---@return self
function UIConfigBuilder:addAlign(...) end

---
--- Sets the width.
---
---@param width number
---@return self
function UIConfigBuilder:addWidth(...) end

---
--- Sets the height.
---
---@param height number
---@return self
function UIConfigBuilder:addHeight(...) end

---
--- Sets the max width.
---
---@param maxWidth number
---@return self
function UIConfigBuilder:addMaxWidth(...) end

---
--- Sets the max height.
---
---@param maxHeight number
---@return self
function UIConfigBuilder:addMaxHeight(...) end

---
--- Sets the min width.
---
---@param minWidth number
---@return self
function UIConfigBuilder:addMinWidth(...) end

---
--- Sets the min height.
---
---@param minHeight number
---@return self
function UIConfigBuilder:addMinHeight(...) end

---
--- Sets the padding.
---
---@param padding number
---@return self
function UIConfigBuilder:addPadding(...) end

---
--- Sets the background color.
---
---@param color string
---@return self
function UIConfigBuilder:addColor(...) end

---
--- Sets the outline color.
---
---@param color string
---@return self
function UIConfigBuilder:addOutlineColor(...) end

---
--- Sets the outline thickness.
---
---@param thickness number
---@return self
function UIConfigBuilder:addOutlineThickness(...) end

---
--- Adds a shadow with an offset.
---
---@param offset Vector2
---@return self
function UIConfigBuilder:addShadow(...) end

---
--- Sets the shadow color.
---
---@param color string
---@return self
function UIConfigBuilder:addShadowColor(...) end

---
--- Sets if the background should be transparent.
---
---@param noFill boolean
---@return self
function UIConfigBuilder:addNoFill(...) end

---
--- Sets if the rectangle should be drawn pixel-perfect.
---
---@param pixelated boolean
---@return self
function UIConfigBuilder:addPixelatedRectangle(...) end

---
--- Sets if collision is enabled.
---
---@param canCollide boolean
---@return self
function UIConfigBuilder:addCanCollide(...) end

---
--- Alias for addCanCollide.
---
---@param collideable boolean
---@return self
function UIConfigBuilder:addCollideable(...) end

---
--- Forces collision checks.
---
---@param force boolean
---@return self
function UIConfigBuilder:addForceCollision(...) end

---
--- Marks this element as a button.
---
---@param isButton boolean
---@return self
function UIConfigBuilder:addButtonUIE(...) end

---
--- Disables the button functionality.
---
---@param disabled boolean
---@return self
function UIConfigBuilder:addDisableButton(...) end

---
--- Sets a function to get progress bar value.
---
---@param func function
---@return self
function UIConfigBuilder:addProgressBarFetchValueLamnda(...) end

---
--- Marks this as a progress bar.
---
---@param isProgressBar boolean
---@return self
function UIConfigBuilder:addProgressBar(...) end

---
--- Sets the progress bar's empty color.
---
---@param color string
---@return self
function UIConfigBuilder:addProgressBarEmptyColor(...) end

---
--- Sets the progress bar's full color.
---
---@param color string
---@return self
function UIConfigBuilder:addProgressBarFullColor(...) end

---
--- Sets the progress bar's max value.
---
---@param maxVal number
---@return self
function UIConfigBuilder:addProgressBarMaxValue(...) end

---
--- Sets the component name for progress value.
---
---@param name string
---@return self
function UIConfigBuilder:addProgressBarValueComponentName(...) end

---
--- Sets the field name for progress value.
---
---@param name string
---@return self
function UIConfigBuilder:addProgressBarValueFieldName(...) end

---
--- Sets the UI object updated flag.
---
---@param updated boolean
---@return self
function UIConfigBuilder:addUIObjectUpdated(...) end

---
--- Sets button delay start flag.
---
---@param delay boolean
---@return self
function UIConfigBuilder:addButtonDelayStart(...) end

---
--- Sets button press delay.
---
---@param delay number
---@return self
function UIConfigBuilder:addButtonDelay(...) end

---
--- Sets button delay progress.
---
---@param progress number
---@return self
function UIConfigBuilder:addButtonDelayProgress(...) end

---
--- Sets button delay end flag.
---
---@param ended boolean
---@return self
function UIConfigBuilder:addButtonDelayEnd(...) end

---
--- Sets the button clicked flag.
---
---@param clicked boolean
---@return self
function UIConfigBuilder:addButtonClicked(...) end

---
--- Sets button press visual distance.
---
---@param distance number
---@return self
function UIConfigBuilder:addButtonDistance(...) end

---
--- Sets the tooltip text.
---
---@param text string
---@return self
function UIConfigBuilder:addTooltip(...) end

---
--- Sets a detailed tooltip.
---
---@param tooltip Tooltip
---@return self
function UIConfigBuilder:addDetailedTooltip(...) end

---
--- Sets a function to generate a tooltip.
---
---@param func function
---@return self
function UIConfigBuilder:addOnDemandTooltip(...) end

---
--- Sets the hover state.
---
---@param hover boolean
---@return self
function UIConfigBuilder:addHover(...) end

---
--- Forces this element to take focus.
---
---@param force boolean
---@return self
function UIConfigBuilder:addForceFocus(...) end

---
--- Enables dynamic motion.
---
---@param dynamic boolean
---@return self
function UIConfigBuilder:addDynamicMotion(...) end

---
--- Marks this as a choice element.
---
---@param isChoice boolean
---@return self
function UIConfigBuilder:addChoice(...) end

---
--- Sets the chosen state.
---
---@param isChosen boolean
---@return self
function UIConfigBuilder:addChosen(...) end

---
--- Makes the button a one-time press.
---
---@param onePress boolean
---@return self
function UIConfigBuilder:addOnePress(...) end

---
--- Sets if choice navigation is vertical.
---
---@param isVert boolean
---@return self
function UIConfigBuilder:addChosenVert(...) end

---
--- Draws this element after its children.
---
---@param drawAfter boolean
---@return self
function UIConfigBuilder:addDrawAfter(...) end

---
--- Sets the focus arguments.
---
---@param args FocusArgs
---@return self
function UIConfigBuilder:addFocusArgs(...) end

---
--- Sets a custom update function.
---
---@param func function
---@return self
function UIConfigBuilder:addUpdateFunc(...) end

---
--- Sets a custom init function.
---
---@param func function
---@return self
function UIConfigBuilder:addInitFunc(...) end

---
--- Sets a resize callback.
---
---@param func function
---@return self
function UIConfigBuilder:addOnUIResizeFunc(...) end

---
--- Sets a scale reset callback.
---
---@param func function
---@return self
function UIConfigBuilder:addOnUIScalingResetToOne(...) end

---
--- Sets an instant-execution function.
---
---@param func function
---@return self
function UIConfigBuilder:addInstaFunc(...) end

---
--- Sets a button press callback.
---
---@param func function
---@return self
function UIConfigBuilder:addButtonCallback(...) end

---
--- Sets a temporary button flag.
---
---@param temp boolean
---@return self
function UIConfigBuilder:addButtonTemp(...) end

---
--- Sets a referenced entity.
---
---@param entity Entity
---@return self
function UIConfigBuilder:addRefEntity(...) end

---
--- Sets a referenced component name.
---
---@param name string
---@return self
function UIConfigBuilder:addRefComponent(...) end

---
--- Sets a referenced value.
---
---@param val any
---@return self
function UIConfigBuilder:addRefValue(...) end

---
--- Sets the previous referenced value.
---
---@param val any
---@return self
function UIConfigBuilder:addPrevRefValue(...) end

---
--- Sets the static text.
---
---@param text string
---@return self
function UIConfigBuilder:addText(...) end

---
--- Sets the language key.
---
---@param lang string
---@return self
function UIConfigBuilder:addLanguage(...) end

---
--- Enables vertical text.
---
---@param vertical boolean
---@return self
function UIConfigBuilder:addVerticalText(...) end

---
--- Marks as a horizontal popup.
---
---@param isPopup boolean
---@return self
function UIConfigBuilder:addHPopup(...) end

---
--- Sets the horizontal popup config.
---
---@param config UIConfig
---@return self
function UIConfigBuilder:addHPopupConfig(...) end

---
--- Marks as a detailed popup.
---
---@param isPopup boolean
---@return self
function UIConfigBuilder:addDPopup(...) end

---
--- Sets the detailed popup config.
---
---@param config UIConfig
---@return self
function UIConfigBuilder:addDPopupConfig(...) end

---
--- Sets if the element extends upwards.
---
---@param extendUp boolean
---@return self
function UIConfigBuilder:addExtendUp(...) end

---
--- Sets the resolution context.
---
---@param res Vector2
---@return self
function UIConfigBuilder:addResolution(...) end

---
--- Enables emboss effect.
---
---@param emboss boolean
---@return self
function UIConfigBuilder:addEmboss(...) end

---
--- Enables line emboss effect.
---
---@param emboss boolean
---@return self
function UIConfigBuilder:addLineEmboss(...) end

---
--- Sets the 'mid' flag.
---
---@param mid boolean
---@return self
function UIConfigBuilder:addMid(...) end

---
--- Disables the inherited properties role.
---
---@param noRole boolean
---@return self
function UIConfigBuilder:addNoRole(...) end

---
--- Sets the inherited properties role.
---
---@param role InheritedProperties
---@return self
function UIConfigBuilder:addRole(...) end

---
--- Sets the styling type.
---
---@param type UIStylingType
---@return self
function UIConfigBuilder:addStylingType(...) end

---
--- Sets the 9-patch info.
---
---@param info NPatchInfo
---@return self
function UIConfigBuilder:addNPatchInfo(...) end

---
--- Sets the 9-patch texture.
---
---@param texture string
---@return self
function UIConfigBuilder:addNPatchSourceTexture(...) end

---
--- Constructs the final UIConfig object.
---
---@return UIConfig
function UIConfigBuilder:build(...) end


---
--- A node in a UI template, defining an element's type, config, and children.
---
---@class UIElementTemplateNode
UIElementTemplateNode = {
    ---@type UITypeEnum
    type = nil,
    ---@type UIConfig
    config = nil,
    ---@type table<integer, UIElementTemplateNode>
    children = nil
}


---
--- A fluent builder for creating UI template trees.
---
---@class UIElementTemplateNodeBuilder
UIElementTemplateNodeBuilder = {
}

---
--- Creates a new builder instance.
---
---@return self
function UIElementTemplateNodeBuilder.create(...) end

---
--- Sets the node's UI type.
---
---@param type UITypeEnum
---@return self
function UIElementTemplateNodeBuilder:addType(...) end

---
--- Sets the node's config.
---
---@param config UIConfig
---@return self
function UIElementTemplateNodeBuilder:addConfig(...) end

---
--- Adds a child template node.
---
---@param child UIElementTemplateNode
---@return self
function UIElementTemplateNodeBuilder:addChild(...) end

---
--- Adds multiple child template nodes from a Lua table.
---
---@param children table<integer, UIElementTemplateNode>
---@return self
function UIElementTemplateNodeBuilder:addChildren(...) end

---
--- Builds the final template node.
---
---@return UIElementTemplateNode
function UIElementTemplateNodeBuilder:build(...) end


---
--- Top-level namespace for the UI system.
---
---@class ui
ui = {
}


---
--- Functions for creating and managing UI elements.
---
---@class ui.element
ui.element = {
}


---
--- Functions for managing and laying out entire UI trees (boxes).
---
---@class ui.box
ui.box = {
}


---
---
---@class ui.definitions
ui.definitions = {
}


---
--- Spring module: component, factories, and update helpers.
---
---@class spring
spring = {
}

---
--- Create entity, attach Spring, return both.
---
---(entity, Spring) make(Registry, number value, number k, number d, table? opts)
function spring:make(...) end

---
--- Get existing Spring on entity, or create and attach if missing.
---
---Spring get_or_make(Registry, entity, number value, number k, number d, table? opts)
function spring:get_or_make(...) end

---
--- Get existing Spring on entity; errors if missing.
---
---Spring get(Registry, entity)
function spring:get(...) end

---
--- Attach or replace Spring on an existing entity.
---
---Spring attach(Registry, entity, number value, number k, number d, table? opts)
function spring:attach(...) end

---
--- Update all Spring components in the registry.
---
---void(Registry, number dt)
function spring:update_all(...) end

---
--- Update a single Spring.
---
---void(Spring, number dt)
function spring:update(...) end

---
--- Set target without touching k/d.
---
---void(Spring, number target)
function spring:set_target(...) end


---
--- Critically damped transform-friendly spring component. Use fields for direct control; call methods for pulls/animations.
---
---@class Spring
Spring = {
    value = number,  -- Current value.
    targetValue = number,  -- Current target value.
    velocity = number,  -- Current velocity.
    stiffness = number,  -- Hooke coefficient (k).
    damping = number,  -- Damping factor (c).
    enabled = boolean,  -- If false, update() is skipped.
    usingForTransforms = boolean,  -- Use transform-safe update path.
    preventOvershoot = boolean,  -- Clamp crossing to avoid overshoot.
    maxVelocity = number|nil,  -- Optional velocity clamp.
    smoothingFactor = number|nil,  -- 0..1, scales integration step.
    timeToTarget = number|nil  -- If set, animate_to_time controls k/d over time.
}

---
--- Impulse-like tug on current value.
---
---void(number force, number? k, number? d)
function Spring:pull(...) end

---
--- Move anchor with spring params.
---
---void(number target, number k, number d)
function Spring:animate_to(...) end

---
--- Time-based targeting with easing.
---
---void(number target, number T, function? easing, number? k0, number? d0)
function Spring:animate_to_time(...) end

---
--- Enable updates.
---
---void()
function Spring:enable(...) end

---
--- Disable updates.
---
---void()
function Spring:disable(...) end

---
--- Snap value to target; zero velocity.
---
---void()
function Spring:snap_to_target(...) end


---
---
---@class WorldQuadtree
WorldQuadtree = {
}

---
--- Removes all entities from the quadtree.
---
---@return nil
function WorldQuadtree:clear(...) end

---
--- Inserts the entity into the quadtree (entity must have a known AABB).
---
---@param e Entity
---@return nil
function WorldQuadtree:add(...) end

---
--- Removes the entity from the quadtree if present.
---
---@param e Entity
---@return nil
function WorldQuadtree:remove(...) end

---
--- Returns all entities whose AABBs intersect the given box.
---
---@param box Box
---@return Entity[]
function WorldQuadtree:query(...) end

---
--- Returns a list of intersecting pairs as 2-element arrays {a, b}.
---
---@return Entity[][]
function WorldQuadtree:find_all_intersections(...) end

---
--- Returns the overall bounds of the quadtree space.
---
---@return Box
function WorldQuadtree:get_bounds(...) end


---
---
---@class Box
Box = {
    left = number,  -- Left (x) position
    top = number,  -- Top (y) position
    width = number,  -- Width
    height = number  -- Height
}


---
---
---@class quadtree
quadtree = {
}

---
--- Creates a Box from numbers or from a table with {left, top, width, height}.
---
---@overload fun(left:number, top:number, width:number, height:number): Box
---@overload fun(tbl:Box): Box
---@return Box
function quadtree:box(...) end


---
---
---@class ui.text
ui.text = {
}


---
---
---@class TextUIHandle
TextUIHandle = {
    size = integer,  -- Number of ids in the handle.
    has = nil, --[fun(id:string):boolean]--,  -- Check if id exists in the handle.
    get = nil, --[fun(id:string):Entity|nil]--  -- Fetch entity by id, or nil if not found.
}


---
--- Physics namespace (Chipmunk2D). Create worlds, set tags/masks, raycast, query areas, and attach colliders to entities.
---
---@class physics
physics = {
}


---
--- Result of a raycast. Fields:
--- - shape: lightuserdata @ cpShape*
--- - point: {x:number, y:number}
--- - normal: {x:number, y:number}
--- - fraction: number (0..1) distance fraction along the segment
---
---@class physics.RaycastHit
physics.RaycastHit = {
}


---
--- Collision event with contact info. Fields:
--- - objectA, objectB: lightuserdata (internally mapped to entt.entity)
--- - x1, y1 (point on A), x2, y2 (point on B), nx, ny (contact normal)
---
---@class physics.CollisionEvent
physics.CollisionEvent = {
}


---
--- Enum of supported collider shapes:
--- - Rectangle, Circle, Polygon, Chain
---
---@class physics.ColliderShapeType
physics.ColliderShapeType = {
}


---
--- Owns a Chipmunk cpSpace, manages collision/trigger tags, and buffers of collision/trigger events.
--- Construct with (registry*, meter:number, gravityX:number, gravityY:number). Call Update(dt) each frame and PostUpdate() after consuming event buffers.
---
---@class physics.PhysicsWorld
physics.PhysicsWorld = {
}


---
--- Enum:
--- - AuthoritativePhysics
--- - AuthoritativeTransform
--- - FollowVisual
--- - FrozenWhileDesynced
---
---@class physics.PhysicsSyncMode
physics.PhysicsSyncMode = {
}


---
--- Enum:
--- - TransformFixed_PhysicsFollows (lock body rotation; Transform angle is authority)
--- - PhysicsFree_TransformFollows (body rotates; Transform copies body angle)
---
---@class physics.RotationSyncMode
physics.RotationSyncMode = {
}


---
--- --- Wrapper over cpArbiter* passed to collision callbacks.
--- --- Fields/methods:
--- --- ptr: lightuserdata (arbiter pointer)
--- --- entities(): returns {entityA, entityB}
--- --- tags(world): returns {tagA, tagB}
--- --- normal: {x,y}
--- --- total_impulse: {x,y}
--- --- total_impulse_length: number
--- --- is_first_contact(): boolean
--- --- is_removal(): boolean
--- --- set_friction(f), set_elasticity(e), set_surface_velocity(vx,vy), ignore()  (preSolve only)
---
---@class physics.Arbiter
physics.Arbiter = {
}


---
--- Steering behaviors (seek/flee/wander/boids/path) that push forces into Chipmunk bodies.
---
---@class steering
steering = {
}


---
--- Actual userdata type for the PhysicsManager class. Use the global `physics_manager` to access the live instance.
--- Methods mirror the helpers on the `PhysicsManager` table.
---
---@class PhysicsManagerUD
PhysicsManagerUD = {
    get_world = nil,  -- ---@param name string
---@return PhysicsWorld|nil
    has_world = nil,  -- ---@param name string
---@return boolean
    is_world_active = nil,  -- ---@param name string
---@return boolean
    add_world = nil,  -- ---@param name string
---@param world PhysicsWorld
---@param bindsToState string|nil
    enable_step = nil,  -- ---@param name string
---@param on boolean
    enable_debug_draw = nil,  -- ---@param name string
---@param on boolean
    step_all = nil,  -- ---@param dt number
    draw_all = nil,
    move_entity_to_world = nil,  -- ---@param e entt.entity
---@param dst string
    get_nav_config = nil,  -- ---@param world string
---@return table { default_inflate_px: integer }
    set_nav_config = nil,  -- ---@param world string
---@param cfg table { default_inflate_px: integer|nil }
    mark_navmesh_dirty = nil,  -- ---@param world string
    rebuild_navmesh = nil,  -- ---@param world string
    find_path = nil,  -- ---@param world string
---@param sx number
---@param sy number
---@param dx number
---@param dy number
---@return table<number,{x:integer,y:integer}>
    vision_fan = nil,  -- ---@param world string
---@param sx number
---@param sy number
---@param radius number
---@return table<number,{x:integer,y:integer}>
    set_nav_obstacle = nil  -- ---@param e entt.entity
---@param include boolean
}


---
--- Physics manager utilities: manage physics worlds, debug toggles, navmesh (pathfinding / vision), and safe world migration for entities.
---
---@class PhysicsManager
PhysicsManager = {
}


---
--- Camera namespace. Create named cameras, update them, and use them for rendering.
---
---@class camera
camera = {
}


---
--- Camera follow modes.
---
---@class camera.FollowStyle
camera.FollowStyle = {
    LOCKON = 0,  -- Always center target.
    PLATFORMER = 1,  -- Platformer-style deadzone.
    TOPDOWN = 2,  -- Loose top-down deadzone.
    TOPDOWN_TIGHT = 3,  -- Tighter top-down deadzone.
    SCREEN_BY_SCREEN = 4,  -- Move by screen pages.
    NONE = 5  -- No automatic follow.
}


---
--- Smooth 2D camera with springs, follow modes, bounds, shake, and flash/fade.
--- Actual* setters target the spring (smoothed) values; Visual* setters apply immediately.
---
---@class GameCamera
GameCamera = {
}

---
--- Enter 2D mode using this camera.
---
---@return nil
function GameCamera:Begin(...) end

---
--- End 2D mode for this camera.
---
---@return nil
function GameCamera:End(...) end

---
--- Instantly move the camera’s actual position to (x, y), skipping smoothing.
--- Resets spring values/velocities, clears shakes, and suppresses follow logic for a couple frames.
--- Use when teleporting or hard-setting camera position.
---
---@param x number
---@param y number
---@return nil
function GameCamera:SnapActualTo(...) end

---
--- End 2D mode, then draw an overlay using the given Layer.
---
---@overload fun(layer:Layer):nil
function GameCamera:End(...) end

---
--- Single-call smooth move to (x, y). Zeroes velocity, boosts damping briefly to prevent jitter on big jumps,
--- and suppresses follow/deadzone for a few frames. Restores tuning automatically.
---
---@param x number
---@param y number
---@param frames integer @frames of boosted damping (default 8)
---@param kBoost number @temporary stiffness (default 2000)
---@param dBoost number @temporary damping (default 200)
---@param jumpThreshold number @world distance to trigger boosted settle; <=0 means always (default 0)
---@return nil
function GameCamera:SetActualTargetSmooth(...) end

---
--- Nudge the camera target immediately by (dx, dy).
---
---@param dx number
---@param dy number
---@return nil
function GameCamera:Move(...) end

---
--- Nudge the camera target by a vector.
---
---@overload fun(delta:Vector2):nil
function GameCamera:Move(...) end

---
--- Set the world-space follow target (enables deadzone logic).
---
---@param worldPos Vector2
---@return nil
function GameCamera:Follow(...) end

---
--- Set or clear the deadzone rectangle (world units).
---
---@param rect Rectangle|nil # nil disables deadzone
---@return nil
function GameCamera:SetDeadzone(...) end

---
--- Choose the follow behavior.
---
---@param style integer|camera.FollowStyle
---@return nil
function GameCamera:SetFollowStyle(...) end

---
--- Higher t snaps faster; lower t is smoother.
---
---@param t number # 0..1 smoothing toward follow target
---@return nil
function GameCamera:SetFollowLerp(...) end

---
--- Lead the camera ahead of movement.
---
---@param lead Vector2
---@return nil
function GameCamera:SetFollowLead(...) end

---
--- Lead the camera by components.
---
---@overload fun(x:number, y:number):nil
function GameCamera:SetFollowLead(...) end

---
--- Fullscreen flash of the given color.
---
---@param duration number
---@param color Color
---@return nil
function GameCamera:Flash(...) end

---
--- Fade to color; optional callback invoked when fade completes.
---
---@param duration number
---@param color Color
---@param cb? fun():nil
---@return nil
function GameCamera:Fade(...) end

---
--- Noise-based screenshake.
---
---@param amplitude number
---@param duration number
---@param frequency? number
---@return nil
function GameCamera:Shake(...) end

---
--- Kick the offset spring system with an impulse.
---
---@param intensity number
---@param angle number # radians
---@param stiffness number
---@param damping number
---@return nil
function GameCamera:SpringShake(...) end

---
--- Set spring-target zoom (smoothed).
---
---@param z number
---@return nil
function GameCamera:SetActualZoom(...) end

---
--- Set immediate zoom (unsmoothed).
---
---@param z number
---@return nil
function GameCamera:SetVisualZoom(...) end

---
--- Current spring-target zoom.
---
---@return number
function GameCamera:GetActualZoom(...) end

---
--- Current immediate zoom.
---
---@return number
function GameCamera:GetVisualZoom(...) end

---
--- Set spring-target rotation (radians).
---
---@param radians number
---@return nil
function GameCamera:SetActualRotation(...) end

---
--- Set immediate rotation (radians).
---
---@param radians number
---@return nil
function GameCamera:SetVisualRotation(...) end

---
--- Current spring-target rotation (radians).
---
---@return number
function GameCamera:GetActualRotation(...) end

---
--- Current immediate rotation (radians).
---
---@return number
function GameCamera:GetVisualRotation(...) end

---
--- Set spring-target offset.
---
---@param offset Vector2
---@return nil
function GameCamera:SetActualOffset(...) end

---
--- Set spring-target offset by components.
---
---@overload fun(x:number, y:number):nil
function GameCamera:SetActualOffset(...) end

---
--- Set immediate offset.
---
---@param offset Vector2
---@return nil
function GameCamera:SetVisualOffset(...) end

---
--- Set immediate offset by components.
---
---@overload fun(x:number, y:number):nil
function GameCamera:SetVisualOffset(...) end

---
--- Current spring-target offset.
---
---@return Vector2
function GameCamera:GetActualOffset(...) end

---
--- Current immediate offset.
---
---@return Vector2
function GameCamera:GetVisualOffset(...) end

---
--- Set spring-target position.
---
---@param world Vector2
---@return nil
function GameCamera:SetActualTarget(...) end

---
--- Set spring-target position by components.
---
---@overload fun(x:number, y:number):nil
function GameCamera:SetActualTarget(...) end

---
--- Set immediate position.
---
---@param world Vector2
---@return nil
function GameCamera:SetVisualTarget(...) end

---
--- Set immediate position by components.
---
---@overload fun(x:number, y:number):nil
function GameCamera:SetVisualTarget(...) end

---
--- Current spring-target position.
---
---@return Vector2
function GameCamera:GetActualTarget(...) end

---
--- Current immediate position.
---
---@return Vector2
function GameCamera:GetVisualTarget(...) end

---
--- Set world-space clamp rectangle or disable when nil.
---
---@param rect Rectangle|nil # nil disables clamping
---@return nil
function GameCamera:SetBounds(...) end

---
--- Allow a little slack when clamping bounds (useful when bounds equal the viewport).
---
---@param padding number # extra screen-space leeway in pixels
---@return nil
function GameCamera:SetBoundsPadding(...) end

---
--- Enable/disable damping on the offset spring.
---
---@param enabled boolean
---@return nil
function GameCamera:SetOffsetDampingEnabled(...) end

---
--- Whether offset damping is enabled.
---
---@return boolean
function GameCamera:IsOffsetDampingEnabled(...) end

---
--- Enable/disable strafe tilt effect.
---
---@param enabled boolean
---@return nil
function GameCamera:SetStrafeTiltEnabled(...) end

---
--- Whether strafe tilt is enabled.
---
---@return boolean
function GameCamera:IsStrafeTiltEnabled(...) end

---
--- Mouse position in world space using this camera.
---
---@return Vector2
function GameCamera:GetMouseWorld(...) end

---
--- Advance springs, effects, follow, and bounds by dt seconds.
---
---@param dt number
---@return nil
function GameCamera:Update(...) end


---
--- Holds timing, frame rate, and delta-time state for the main game loop.
---
---@class MainLoopData
MainLoopData = {
    smoothedDeltaTime = float,  -- Smoothed delta time for the current frame.
    realtimeTimer = float,  -- Real-time timer since game start (unscaled).
    totaltimeTimer = float,  -- Total accumulated in-game time excluding pauses.
    timescale = float,  -- Scaling factor applied to delta time (1.0 = normal speed).
    rate = float,  -- Fixed timestep in seconds (default 1/60).
    lag = float,  -- Accumulated lag between fixed updates.
    maxFrameSkip = float,  -- Maximum number of fixed updates processed per frame.
    frame = int,  -- Frame counter since start of the game.
    framerate = float,  -- Target rendering frame rate.
    sleepTime = float,  -- Sleep duration per frame to prevent CPU hogging.
    updates = int,  -- Number of logic updates in the current second.
    renderedUPS = int,  -- Smoothed updates per second (running average).
    renderedFPS = int,  -- Smoothed frames per second (running average).
    updateTimer = float  -- Timer used to compute UPS over time.
}


---
---
---@class InputState
InputState = {
    ---@type Entity
    cursor_clicked_target = nil,  -- Entity clicked this frame
    ---@type Entity
    cursor_prev_clicked_target = nil,  -- Entity clicked in previous frame
    ---@type Entity
    cursor_focused_target = nil,  -- Entity under cursor focus now
    ---@type Entity
    cursor_prev_focused_target = nil,  -- Entity under cursor focus last frame
    ---@type Rectangle
    cursor_focused_target_area = nil,  -- Bounds of the focused target
    ---@type Entity
    cursor_dragging_target = nil,  -- Entity currently being dragged
    ---@type Entity
    cursor_prev_dragging_target = nil,  -- Entity dragged last frame
    ---@type Entity
    cursor_prev_released_on_target = nil,  -- Entity released on target last frame
    ---@type Entity
    cursor_released_on_target = nil,  -- Entity released on target this frame
    ---@type Entity
    current_designated_hover_target = nil,  -- Entity designated for hover handling
    ---@type Entity
    prev_designated_hover_target = nil,  -- Previously designated hover target
    ---@type Entity
    cursor_hovering_target = nil,  -- Entity being hovered now
    ---@type Entity
    cursor_prev_hovering_target = nil,  -- Entity hovered last frame
    ---@type bool
    cursor_hovering_handled = nil,  -- Whether hover was already handled
    ---@type std::vector<Entity>
    collision_list = nil,  -- All entities colliding with cursor
    ---@type std::vector<NodeData>
    nodes_at_cursor = nil,  -- All UI nodes under cursor
    ---@type Vector2
    cursor_position = nil,  -- Current cursor position
    ---@type Vector2
    cursor_down_position = nil,  -- Position where cursor was pressed
    ---@type Vector2
    cursor_up_position = nil,  -- Position where cursor was released
    ---@type Vector2
    focus_cursor_pos = nil,  -- Cursor pos used for gamepad/keyboard focus
    ---@type float
    cursor_down_time = nil,  -- Time of last cursor press
    ---@type float
    cursor_up_time = nil,  -- Time of last cursor release
    ---@type bool
    cursor_down_handled = nil,  -- Down event handled flag
    ---@type Entity
    cursor_down_target = nil,  -- Entity pressed down on
    ---@type float
    cursor_down_target_click_timeout = nil,  -- Click timeout interval
    ---@type bool
    cursor_up_handled = nil,  -- Up event handled flag
    ---@type Entity
    cursor_up_target = nil,  -- Entity released on
    ---@type bool
    cursor_released_on_handled = nil,  -- Release handled flag
    ---@type bool
    cursor_click_handled = nil,  -- Click handled flag
    ---@type bool
    is_cursor_down = nil,  -- Is cursor currently down?
    ---@type std::vector<InputButton>
    frame_buttonpress = nil,  -- Buttons pressed this frame
    ---@type std::unordered_map<InputButton,float>
    repress_timer = nil,  -- Cooldown per button
    ---@type bool
    no_holdcap = nil,  -- Disable repeated hold events
    ---@type std::function<void(int)>
    text_input_hook = nil,  -- Callback for text input events
    ---@type bool
    capslock = nil,  -- Is caps-lock active
    ---@type bool
    coyote_focus = nil,  -- Allow focus grace period
    ---@type Transform
    cursor_hover_transform = nil,  -- Transform under cursor
    ---@type float
    cursor_hover_time = nil,  -- Hover duration
    ---@type std::deque<Entity>
    L_cursor_queue = nil,  -- Recent cursor targets queue
    ---@type std::vector<KeyboardKey>
    keysPressedThisFrame = nil,  -- Keys pressed this frame
    ---@type std::vector<KeyboardKey>
    keysHeldThisFrame = nil,  -- Keys held down
    ---@type std::unordered_map<KeyboardKey,float>
    heldKeyDurations = nil,  -- Hold durations per key
    ---@type std::vector<KeyboardKey>
    keysReleasedThisFrame = nil,  -- Keys released this frame
    ---@type std::vector<GamepadButton>
    gamepadButtonsPressedThisFrame = nil,  -- Gamepad buttons pressed this frame
    ---@type std::vector<GamepadButton>
    gamepadButtonsHeldThisFrame = nil,  -- Held gamepad buttons
    ---@type std::unordered_map<GamepadButton,float>
    gamepadHeldButtonDurations = nil,  -- Hold durations per button
    ---@type std::vector<GamepadButton>
    gamepadButtonsReleasedThisFrame = nil,  -- Released gamepad buttons
    ---@type bool
    focus_interrupt = nil,  -- Interrupt focus navigation
    ---@type std::vector<InputLock>
    activeInputLocks = nil,  -- Currently active input locks
    ---@type bool
    inputLocked = nil,  -- Is global input locked
    ---@type std::unordered_map<GamepadAxis,AxisButtonState>
    axis_buttons = nil,  -- Axis-as-button states
    ---@type float
    axis_cursor_speed = nil,  -- Cursor speed from gamepad axis
    ---@type ButtonRegistry
    button_registry = nil,  -- Action-to-button mapping
    ---@type SnapTarget
    snap_cursor_to = nil,  -- Cursor snap target
    ---@type CursorContext
    cursor_context = nil,  -- Nested cursor focus contexts
    ---@type HIDFlags
    hid = nil,  -- Current HID flags
    ---@type GamepadState
    gamepad = nil,  -- Latest gamepad info
    ---@type float
    overlay_menu_active_timer = nil,  -- Overlay menu timer
    ---@type bool
    overlay_menu_active = nil,  -- Is overlay menu active
    ---@type ScreenKeyboard
    screen_keyboard = nil  -- On-screen keyboard state
}


---
--- Per-frame snapshot of cursor, keyboard, mouse, and gamepad state.
---
---@class InputState
InputState = {
}


---
---
---@class KeyboardKey
KeyboardKey = {
    KEY_NULL = 0,  -- Keyboard key enum
    KEY_APOSTROPHE = 39,  -- Keyboard key enum
    KEY_COMMA = 44,  -- Keyboard key enum
    KEY_MINUS = 45,  -- Keyboard key enum
    KEY_PERIOD = 46,  -- Keyboard key enum
    KEY_SLASH = 47,  -- Keyboard key enum
    KEY_ZERO = 48,  -- Keyboard key enum
    KEY_ONE = 49,  -- Keyboard key enum
    KEY_TWO = 50,  -- Keyboard key enum
    KEY_THREE = 51,  -- Keyboard key enum
    KEY_FOUR = 52,  -- Keyboard key enum
    KEY_FIVE = 53,  -- Keyboard key enum
    KEY_SIX = 54,  -- Keyboard key enum
    KEY_SEVEN = 55,  -- Keyboard key enum
    KEY_EIGHT = 56,  -- Keyboard key enum
    KEY_NINE = 57,  -- Keyboard key enum
    KEY_SEMICOLON = 59,  -- Keyboard key enum
    KEY_EQUAL = 61,  -- Keyboard key enum
    KEY_A = 65,  -- Keyboard key enum
    KEY_B = 66,  -- Keyboard key enum
    KEY_C = 67,  -- Keyboard key enum
    KEY_D = 68,  -- Keyboard key enum
    KEY_E = 69,  -- Keyboard key enum
    KEY_F = 70,  -- Keyboard key enum
    KEY_G = 71,  -- Keyboard key enum
    KEY_H = 72,  -- Keyboard key enum
    KEY_I = 73,  -- Keyboard key enum
    KEY_J = 74,  -- Keyboard key enum
    KEY_K = 75,  -- Keyboard key enum
    KEY_L = 76,  -- Keyboard key enum
    KEY_M = 77,  -- Keyboard key enum
    KEY_N = 78,  -- Keyboard key enum
    KEY_O = 79,  -- Keyboard key enum
    KEY_P = 80,  -- Keyboard key enum
    KEY_Q = 81,  -- Keyboard key enum
    KEY_R = 82,  -- Keyboard key enum
    KEY_S = 83,  -- Keyboard key enum
    KEY_T = 84,  -- Keyboard key enum
    KEY_U = 85,  -- Keyboard key enum
    KEY_V = 86,  -- Keyboard key enum
    KEY_W = 87,  -- Keyboard key enum
    KEY_X = 88,  -- Keyboard key enum
    KEY_Y = 89,  -- Keyboard key enum
    KEY_Z = 90,  -- Keyboard key enum
    KEY_LEFT_BRACKET = 91,  -- Keyboard key enum
    KEY_BACKSLASH = 92,  -- Keyboard key enum
    KEY_RIGHT_BRACKET = 93,  -- Keyboard key enum
    KEY_GRAVE = 96,  -- Keyboard key enum
    KEY_SPACE = 32,  -- Keyboard key enum
    KEY_ESCAPE = 256,  -- Keyboard key enum
    KEY_ENTER = 257,  -- Keyboard key enum
    KEY_TAB = 258,  -- Keyboard key enum
    KEY_BACKSPACE = 259,  -- Keyboard key enum
    KEY_INSERT = 260,  -- Keyboard key enum
    KEY_DELETE = 261,  -- Keyboard key enum
    KEY_RIGHT = 262,  -- Keyboard key enum
    KEY_LEFT = 263,  -- Keyboard key enum
    KEY_DOWN = 264,  -- Keyboard key enum
    KEY_UP = 265,  -- Keyboard key enum
    KEY_PAGE_UP = 266,  -- Keyboard key enum
    KEY_PAGE_DOWN = 267,  -- Keyboard key enum
    KEY_HOME = 268,  -- Keyboard key enum
    KEY_END = 269,  -- Keyboard key enum
    KEY_CAPS_LOCK = 280,  -- Keyboard key enum
    KEY_SCROLL_LOCK = 281,  -- Keyboard key enum
    KEY_NUM_LOCK = 282,  -- Keyboard key enum
    KEY_PRINT_SCREEN = 283,  -- Keyboard key enum
    KEY_PAUSE = 284,  -- Keyboard key enum
    KEY_F1 = 290,  -- Keyboard key enum
    KEY_F2 = 291,  -- Keyboard key enum
    KEY_F3 = 292,  -- Keyboard key enum
    KEY_F4 = 293,  -- Keyboard key enum
    KEY_F5 = 294,  -- Keyboard key enum
    KEY_F6 = 295,  -- Keyboard key enum
    KEY_F7 = 296,  -- Keyboard key enum
    KEY_F8 = 297,  -- Keyboard key enum
    KEY_F9 = 298,  -- Keyboard key enum
    KEY_F10 = 299,  -- Keyboard key enum
    KEY_F11 = 300,  -- Keyboard key enum
    KEY_F12 = 301,  -- Keyboard key enum
    KEY_LEFT_SHIFT = 340,  -- Keyboard key enum
    KEY_LEFT_CONTROL = 341,  -- Keyboard key enum
    KEY_LEFT_ALT = 342,  -- Keyboard key enum
    KEY_LEFT_SUPER = 343,  -- Keyboard key enum
    KEY_RIGHT_SHIFT = 344,  -- Keyboard key enum
    KEY_RIGHT_CONTROL = 345,  -- Keyboard key enum
    KEY_RIGHT_ALT = 346,  -- Keyboard key enum
    KEY_RIGHT_SUPER = 347,  -- Keyboard key enum
    KEY_KB_MENU = 348  -- Keyboard key enum
}


---
--- Raylib keyboard key codes
---
---@class KeyboardKey
KeyboardKey = {
}


---
---
---@class MouseButton
MouseButton = {
    MOUSE_BUTTON_LEFT = 0,  -- Left mouse button
    MOUSE_BUTTON_RIGHT = 1,  -- Right mouse button
    MOUSE_BUTTON_MIDDLE = 2,  -- Middle mouse button
    MOUSE_BUTTON_SIDE = 3,  -- Side mouse button
    MOUSE_BUTTON_EXTRA = 4,  -- Extra mouse button
    MOUSE_BUTTON_FORWARD = 5,  -- Forward mouse button
    MOUSE_BUTTON_BACK = 6  -- Back mouse button
}


---
---
---@class GamepadButton
GamepadButton = {
    GAMEPAD_BUTTON_UNKNOWN = 0,  -- Gamepad button enum
    GAMEPAD_BUTTON_LEFT_FACE_UP = 1,  -- Gamepad button enum
    GAMEPAD_BUTTON_LEFT_FACE_RIGHT = 2,  -- Gamepad button enum
    GAMEPAD_BUTTON_LEFT_FACE_DOWN = 3,  -- Gamepad button enum
    GAMEPAD_BUTTON_LEFT_FACE_LEFT = 4,  -- Gamepad button enum
    GAMEPAD_BUTTON_RIGHT_FACE_UP = 5,  -- Gamepad button enum
    GAMEPAD_BUTTON_RIGHT_FACE_RIGHT = 6,  -- Gamepad button enum
    GAMEPAD_BUTTON_RIGHT_FACE_DOWN = 7,  -- Gamepad button enum
    GAMEPAD_BUTTON_RIGHT_FACE_LEFT = 8,  -- Gamepad button enum
    GAMEPAD_BUTTON_LEFT_TRIGGER_1 = 9,  -- Gamepad button enum
    GAMEPAD_BUTTON_LEFT_TRIGGER_2 = 10,  -- Gamepad button enum
    GAMEPAD_BUTTON_RIGHT_TRIGGER_1 = 11,  -- Gamepad button enum
    GAMEPAD_BUTTON_RIGHT_TRIGGER_2 = 12,  -- Gamepad button enum
    GAMEPAD_BUTTON_MIDDLE_LEFT = 13,  -- Gamepad button enum
    GAMEPAD_BUTTON_MIDDLE = 14,  -- Gamepad button enum
    GAMEPAD_BUTTON_MIDDLE_RIGHT = 15,  -- Gamepad button enum
    GAMEPAD_BUTTON_LEFT_THUMB = 16,  -- Gamepad button enum
    GAMEPAD_BUTTON_RIGHT_THUMB = 17  -- Gamepad button enum
}


---
---
---@class GamepadAxis
GamepadAxis = {
    GAMEPAD_AXIS_LEFT_X = 0,  -- Gamepad axis enum
    GAMEPAD_AXIS_LEFT_Y = 1,  -- Gamepad axis enum
    GAMEPAD_AXIS_RIGHT_X = 2,  -- Gamepad axis enum
    GAMEPAD_AXIS_RIGHT_Y = 3,  -- Gamepad axis enum
    GAMEPAD_AXIS_LEFT_TRIGGER = 4,  -- Gamepad axis enum
    GAMEPAD_AXIS_RIGHT_TRIGGER = 5  -- Gamepad axis enum
}


---
---
---@class InputDeviceInputCategory
InputDeviceInputCategory = {
    NONE = 0,  -- No input category
    GAMEPAD_AXIS_CURSOR = 1,  -- Axis-driven cursor category
    GAMEPAD_AXIS = 2,  -- Gamepad axis category
    GAMEPAD_BUTTON = 3,  -- Gamepad button category
    MOUSE = 4,  -- Mouse input category
    TOUCH = 5  -- Touch input category
}


---
---
---@class AxisButtonState
AxisButtonState = {
    current = bool,  -- Is axis beyond threshold this frame?
    previous = bool  -- Was axis beyond threshold last frame?
}


---
---
---@class NodeData
NodeData = {
    node = Entity,  -- UI node entity
    click = bool,  -- Was node clicked?
    menu = bool,  -- Is menu open on node?
    under_overlay = bool  -- Is node under overlay?
}


---
---
---@class SnapTarget
SnapTarget = {
    node = Entity,  -- Target entity to snap cursor to
    transform = Transform,  -- Target’s transform
    type = SnapType  -- Snap behavior type
}


---
---
---@class CursorContext::CursorLayer
CursorContext::CursorLayer = {
    cursor_focused_target = Entity,  -- Layer’s focused target entity
    cursor_position = Vector2,  -- Layer’s cursor position
    focus_interrupt = bool  -- Interrupt flag for this layer
}


---
---
---@class CursorContext
CursorContext = {
    ---@type CursorContext::CursorLayer
    layer = nil,  -- Current layer
    ---@type std::vector<CursorContext::CursorLayer>
    stack = nil  -- Layer stack
}


---
---
---@class GamepadState
GamepadState = {
    ---@type GamepadObject
    object = nil,  -- Raw gamepad object
    ---@type GamepadMapping
    mapping = nil,  -- Button/axis mapping
    ---@type std::string
    name = nil,  -- Gamepad name
    ---@type bool
    console = nil,  -- Is console gamepad?
    ---@type int
    id = nil  -- System device ID
}


---
---
---@class HIDFlags
HIDFlags = {
    last_type = InputDeviceInputCategory,  -- Last HID type used
    dpad_enabled = bool,  -- D-pad navigation enabled
    pointer_enabled = bool,  -- Pointer input enabled
    touch_enabled = bool,  -- Touch input enabled
    controller_enabled = bool,  -- Controller navigation enabled
    mouse_enabled = bool,  -- Mouse navigation enabled
    axis_cursor_enabled = bool  -- Axis-as-cursor enabled
}

---
--- Creates a new transform entity with default parameters.
---
---@return Entity
function create_transform_entity(...) end

---
--- Adds a fullscreen shader to the game.
---
---@param shaderName string
function add_fullscreen_shader(...) end

---
--- Removes a fullscreen shader from the game.
---
---@param shaderName string
function remove_fullscreen_shader(...) end

---
--- Return the PhysicsWorld registered under name, or nil if missing.
---
---@param name string
---@return PhysicsWorld|nil
function PhysicsManager.get_world(...) end

---
--- True if a world with this name exists.
---
---@param name string
---@return boolean
function PhysicsManager.has_world(...) end

---
--- True if the world's step toggle is on and its bound game-state (if any) is active.
---
---@param name string
---@return boolean
function PhysicsManager.is_world_active(...) end

---
--- Register a PhysicsWorld under a name. Optionally bind to a game-state string.
---
---@param name string
---@param world PhysicsWorld
---@param bindsToState string|nil
---@return void
function PhysicsManager.add_world(...) end

---
--- Enable or disable stepping for a world.
---
---@param name string
---@param on boolean
---@return void
function PhysicsManager.enable_step(...) end

---
--- Enable or disable debug draw for a world.
---
---@param name string
---@param on boolean
---@return void
function PhysicsManager.enable_debug_draw(...) end

---
--- Step all active worlds (honors per-world toggle and game-state binding).
---
---@param dt number
---@return void
function PhysicsManager.step_all(...) end

---
--- Debug-draw all worlds that are active and have debug draw enabled.
---
---@return void
function PhysicsManager.draw_all(...) end

---
--- Move an entity's body/shape to another registered world (safe migration).
---
---@param e entt.entity
---@param dst string
---@return void
function PhysicsManager.move_entity_to_world(...) end

---
--- Return the navmesh config table for a world.
---
---@param world string
---@return table { default_inflate_px: integer }
function PhysicsManager.get_nav_config(...) end

---
--- Patch navmesh config for a world; marks the navmesh dirty.
---
---@param world string
---@param cfg table { default_inflate_px: integer|nil }
---@return void
function PhysicsManager.set_nav_config(...) end

---
--- Mark a world's navmesh dirty (will rebuild on next query or when forced).
---
---@param world string
---@return void
function PhysicsManager.mark_navmesh_dirty(...) end

---
--- Force an immediate navmesh rebuild for a world.
---
---@param world string
---@return void
function PhysicsManager.rebuild_navmesh(...) end

---
--- Find a path on the world's navmesh. Returns an array of {x,y} points.
---
---@param world string
---@param sx number
---@param sy number
---@param dx number
---@param dy number
---@return table<number,{x:integer,y:integer}>
function PhysicsManager.find_path(...) end

---
--- Compute a visibility polygon (fan) from a point and radius against world obstacles.
---
---@param world string
---@param sx number
---@param sy number
---@param radius number
---@return table<number,{x:integer,y:integer}>
function PhysicsManager.vision_fan(...) end

---
--- Tag/untag an entity as a navmesh obstacle and mark its world's navmesh dirty.
---
---@param e entt.entity
---@param include boolean
---@return void
function PhysicsManager.set_nav_obstacle(...) end

---
--- Adjusts text alignment based on calculated line widths.
---
---@param textEntity Entity # The text entity to adjust.
---@return nil
function TextSystem.Functions.adjustAlignment(...) end

---
--- Splits a combined effect string into segments.
---
---@param effects string # The combined effect string (e.g., '{shake}{color=red}').
---@return table # A structured table of parsed effect arguments.
function TextSystem.Functions.splitEffects(...) end

---
--- Creates a new text entity in the world.  If you pass a table of callbacks—
--- each value must be a function that returns true when its wait condition is met—
--- they will be stored in the Text component under txt.luaWaiters[alias].
---
---@param text TextSystem.Text                # The text configuration object.
---@param x number                            # The initial x-position.
---@param y number                            # The initial y-position.
---@param[opt] waiters table<string,function> # Optional map of wait-callbacks by alias.
---@return Entity                             # The newly created text entity.
function TextSystem.Functions.createTextEntity(...) end

---
--- Calculates the text's bounding box.
---
---@param textEntity Entity # The text entity to measure.
---@return Vector2 # The calculated bounding box (width, height).
function TextSystem.Functions.calculateBoundingBox(...) end

---
--- Converts a codepoint to a UTF-8 string.
---
---@param codepoint integer # The Unicode codepoint.
---@return string
function TextSystem.Functions.CodepointToString(...) end

---
--- Parses the raw string of a text entity into characters and applies effects.
---
---@param textEntity Entity # The entity whose text component should be parsed.
---@return nil
function TextSystem.Functions.parseText(...) end

---
--- Handles a single effect segment during parsing.
---
---@param e Entity
---@param lineWidths table
---@param cx? any
---@param cy? any
---@return nil
function TextSystem.Functions.handleEffectSegment(...) end

---
--- Updates text state (e.g., for animated effects).
---
---@param textEntity Entity
---@param dt number # Delta time.
---@return nil
function TextSystem.Functions.updateText(...) end

---
--- Renders text to the screen.
---
---@param textEntity Entity # The text entity to render.
---@param layerPtr Layer # The rendering layer.
---@param debug? boolean # Optionally draw debug info.
---@return nil
function TextSystem.Functions.renderText(...) end

---
--- Clears all effects on a text entity.
---
---@param textEntity Entity
---@return nil
function TextSystem.Functions.clearAllEffects(...) end

---
--- Applies global effects to text.
---
---@param textEntity Entity
---@param effectString string # The effect string to apply to all characters.
---@return nil
function TextSystem.Functions.applyGlobalEffects(...) end

---
--- Prints internal debug info for a text entity.
---
---@param textEntity Entity
---@return nil
function TextSystem.Functions.debugPrintText(...) end

---
--- Resizes text to fit its container.
---
---@param textEntity Entity
---@param targetWidth number
---@param targetHeight number
---@param centerLaterally? boolean
---@param centerVertically? boolean
---@return nil
function TextSystem.Functions.resizeTextToFit(...) end

---
--- Sets text scale and recenters its origin.
---
---@param textEntity Entity
---@param renderScale number
---@param targetWidth number
---@param targetHeight number
---@param centerLaterally boolean
---@param centerVertically boolean
---@return nil
function TextSystem.Functions.setTextScaleAndRecenter(...) end

---
--- Resets text scale and layout to its original parsed state.
---
---@param textEntity Entity
---@return nil
function TextSystem.Functions.resetTextScaleAndLayout(...) end

---
--- Updates the raw text string and reparses the entity.
---
---@param textEntity Entity # The entity to modify.
---@param newText string # The new raw text string.
---@return nil
function TextSystem.Functions.setText(...) end

---
---
---@param e entt.entity # Target entity
---@param flip boolean # Whether to flip horizontally
---@return nil
--- Flips all animations for the entity horizontally
function animation_system.set_horizontal_flip(...) end

---
--- Advances all animations by dt
---
---@param dt number # Delta time in seconds
---@return nil
function animation_system.update(...) end

---
--- Returns nine-patch border info and texture
---
---@param uuid_or_raw_identifier string # N-patch identifier or raw key
---@return NPatchInfo info # Border slicing information
---@return Texture2D texture # Associated texture
function animation_system.getNinepatchUIBorderInfo(...) end

---
--- Sets the foreground color for all animation objects in an entity
---
---@param e entt.entity # Target entity
---@param fgColor Color # Foreground color to set
--- Sets the foreground color for all animation objects in an entity
function animation_system.setFGColorForAllAnimationObjects(...) end

---
--- Creates an animated object with a transform
---
---@param defaultAnimationIDOrSpriteUUID string # Animation ID or sprite UUID
---@param generateNewAnimFromSprite boolean? # Create a new anim from sprite? Default false
---@param x number? # Initial X position. Default 0
---@param y number? # Initial Y position. Default 0
---@param shaderPassConfigFunc fun(entt_entity: entt.entity)? # Optional shader setup callback
---@param shadowEnabled boolean? # Enable shadow? Default true
---@return entt.entity entity # Created animation entity
function animation_system.createAnimatedObjectWithTransform(...) end

---
--- Replaces the animated object on an entity, optionally regenerating it from a sprite UUID and applying shader‐pass & shadow settings
---
---@param e entt.entity                                             # Entity to replace animated object on
---@param defaultAnimationIDOrSpriteUUID string                      # Animation ID or sprite UUID
---@param generateNewAnimFromSprite boolean?                         # Regenerate animation from sprite? Default false
---@param shaderPassConfigFunc fun(entt_entity: entt.entity)?        # Optional shader pass configuration callback
---@param shadowEnabled boolean?                                    # Enable shadow? Default true
---@return entt.entity                                             # Entity whose animated object was replaced
function animation_system.replaceAnimatedObjectOnEntity(...) end

---
--- Configures an existing entity with Transform, AnimationQueueComponent, and optional shader‐pass + shadow settings
---

---@param e entt.entity                        # The existing entity to configure
---@param defaultAnimationIDOrSpriteUUID string # Animation ID or sprite UUID
---@param generateNewAnimFromSprite boolean?    # Create a new anim from sprite? Default false
---@param shaderPassConfigFunc fun(entt.entity)? # Optional shader setup callback
---@param shadowEnabled boolean?                # Enable shadow? Default true
---@return nil

function animation_system.setupAnimatedObjectOnEntity(...) end

---
---
---@param e entt.entity
---@param flipH boolean
---@param flipV boolean
---@return nil
--- Sets the horizontal/vertical flip flags on all animations of an entity
function animation_system.set_flip(...) end

---
---
---@param e entt.entity
---@return nil
--- Toggles horizontal flip for the entity's current animation
function animation_system.toggle_flip(...) end

---
--- Creates a still animation from a sprite UUID
---
---@param spriteUUID string # Sprite UUID to use
---@param fg Color? # Optional foreground tint
---@param bg Color? # Optional background tint
---@return AnimationObject animObj # New still animation object
function animation_system.createStillAnimationFromSpriteUUID(...) end

---
--- Resizes all animation objects in an entity to fit
---
---@param e entt.entity # Target entity
---@param targetWidth number # Desired width
---@param targetHeight number # Desired height
---@return nil
function animation_system.resizeAnimationObjectsInEntityToFit(...) end

---
--- Resizes and centers all animation objects in an entity
---
---@param e entt.entity # Target entity
---@param targetWidth number # Desired width
---@param targetHeight number # Desired height
---@param centerLaterally boolean? # Center horizontally? Default true
---@param centerVertically boolean? # Center vertically? Default true
---@return nil
function animation_system.resizeAnimationObjectsInEntityToFitAndCenterUI(...) end

---
--- Resets UI render scale for an entity’s animations
---
---@param e entt.entity # Target entity
---@return nil
function animation_system.resetAnimationUIRenderScale(...) end

---
--- Resizes a single animation object to fit
---
---@param animObj AnimationObject # Animation object reference
---@param targetWidth number # Desired width
---@param targetHeight number # Desired height
---@return nil
function animation_system.resizeAnimationObjectToFit(...) end

---
---
---@param name string               # Unique camera name
---@param registry entt.registry*   # Pointer to your ECS registry
--- Create or overwrite a named GameCamera.
function camera.Create(...) end

---
---
---@param name string
---@return boolean
--- Check whether a named camera exists.
function camera.Exists(...) end

---
---
---@param name string
--- Remove (destroy) a named camera.
function camera.Remove(...) end

---
---
---@param name string
---@return GameCamera  # Borrowed pointer (owned by manager)
--- Fetch a camera by name.
function camera.Get(...) end

---
---
---@param name string
---@param dt number
--- Update a single camera.
function camera.Update(...) end

---
---
---@param dt number
--- Update all cameras.
function camera.UpdateAll(...) end

---
---
---@overload fun(name:string)
---@overload fun(cam:Camera2D*)
--- Enter 2D mode with a named camera (or raw Camera2D).
function camera.Begin(...) end

---
---
--- End the current camera (handles nesting).
function camera.End(...) end

---
---
---@param name string
---@param fn fun()
--- Run fn inside Begin/End for the named camera.
function camera.with(...) end

---
--- Creates a child entity under `master` with a Transform, GameObject (collision enabled),
--- and a ColliderComponent of the given `type`, applying all provided offsets, sizes, rotation,
--- scale and alignment flags.
---
---@param master entt.entity               # Parent entity to attach collider to
---@param type collision.ColliderType       # Shape of the new collider
---@param t table                           # Config table:
--- #   offsetX?, offsetY?, width?, height?, rotation?, scale?
--- #   alignment? (bitmask), alignOffset { x?, y? }
---@return entt.entity                      # Newly created collider entity
function collision.create_collider_for_entity(...) end

---
--- Runs a Separating Axis Theorem (SAT) test—or AABB test if both are unrotated—
--- on entities `a` and `b`, returning whether they intersect based on their ColliderComponents
--- and Transforms.
---
---@param registry entt.registry*           # Pointer to your entity registry
---@param a entt.entity                      # First entity to test
---@param b entt.entity                      # Second entity to test
---@return boolean                           # True if their collider OBBs/AABBs overlap
function collision.CheckCollisionBetweenTransforms(...) end

---
---
---@param e entt.entity               # Entity whose filter to modify
---@param tag string                   # Name of the tag to add
---| Adds the given tag bit to this entity’s filter.category, so it *is* also that tag.
function collision.setCollisionCategory(...) end

---
---
---@param e entt.entity               # Entity whose filter to modify
---@param ... string                   # One or more tag names
---| Replaces the entity’s filter.mask with the OR of all specified tags.
function collision.setCollisionMask(...) end

---
---
---@param e entt.entity               # Entity whose filter to reset
---@param tag string                   # The sole tag name
---| Clears all category bits, then sets only this one.
function collision.resetCollisionCategory(...) end

---
--- Pushes the transform components of an entity onto the layer's matrix stack as draw commands.
---
---@param registry Registry
---@param e Entity
---@param layer Layer
---@param zOrder number
---@return void
function command_buffer.pushEntityTransformsToMatrix(...) end

---
--- Queues layer.CmdBeginDrawing into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdBeginDrawing)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueBeginDrawing(...) end

---
--- Executes layer.CmdBeginDrawing immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdBeginDrawing)
---@return void
function command_buffer.executeBeginDrawing(...) end

---
--- Queues layer.CmdEndDrawing into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdEndDrawing)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueEndDrawing(...) end

---
--- Executes layer.CmdEndDrawing immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdEndDrawing)
---@return void
function command_buffer.executeEndDrawing(...) end

---
--- Queues layer.CmdClearBackground into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdClearBackground)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueClearBackground(...) end

---
--- Executes layer.CmdClearBackground immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdClearBackground)
---@return void
function command_buffer.executeClearBackground(...) end

---
--- Queues layer.CmdTranslate into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdTranslate)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueTranslate(...) end

---
--- Executes layer.CmdTranslate immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdTranslate)
---@return void
function command_buffer.executeTranslate(...) end

---
--- Queues layer.CmdScale into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdScale)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueScale(...) end

---
--- Executes layer.CmdScale immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdScale)
---@return void
function command_buffer.executeScale(...) end

---
--- Queues layer.CmdRotate into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdRotate)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueRotate(...) end

---
--- Executes layer.CmdRotate immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdRotate)
---@return void
function command_buffer.executeRotate(...) end

---
--- Queues layer.CmdAddPush into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdAddPush)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueAddPush(...) end

---
--- Executes layer.CmdAddPush immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdAddPush)
---@return void
function command_buffer.executeAddPush(...) end

---
--- Queues layer.CmdAddPop into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdAddPop)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueAddPop(...) end

---
--- Executes layer.CmdAddPop immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdAddPop)
---@return void
function command_buffer.executeAddPop(...) end

---
--- Queues layer.CmdPushMatrix into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdPushMatrix)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queuePushMatrix(...) end

---
--- Executes layer.CmdPushMatrix immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdPushMatrix)
---@return void
function command_buffer.executePushMatrix(...) end

---
--- Queues layer.CmdPopMatrix into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdPopMatrix)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queuePopMatrix(...) end

---
--- Executes layer.CmdPopMatrix immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdPopMatrix)
---@return void
function command_buffer.executePopMatrix(...) end

---
--- Queues layer.CmdPushObjectTransformsToMatrix into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdPushObjectTransformsToMatrix)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queuePushObjectTransformsToMatrix(...) end

---
--- Executes layer.CmdPushObjectTransformsToMatrix immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdPushObjectTransformsToMatrix)
---@return void
function command_buffer.executePushObjectTransformsToMatrix(...) end

---
--- Queues layer.CmdScopedTransformCompositeRender into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdScopedTransformCompositeRender)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueScopedTransformCompositeRender(...) end

---
--- Executes layer.CmdScopedTransformCompositeRender immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdScopedTransformCompositeRender)
---@return void
function command_buffer.executeScopedTransformCompositeRender(...) end

---
--- Queues layer.CmdDrawCircleFilled into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawCircleFilled)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawCircleFilled(...) end

---
--- Executes layer.CmdDrawCircleFilled immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawCircleFilled)
---@return void
function command_buffer.executeDrawCircleFilled(...) end

---
--- Queues layer.CmdDrawCircleLine into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawCircleLine)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawCircleLine(...) end

---
--- Executes layer.CmdDrawCircleLine immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawCircleLine)
---@return void
function command_buffer.executeDrawCircleLine(...) end

---
--- Queues layer.CmdDrawRectangle into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawRectangle)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawRectangle(...) end

---
--- Executes layer.CmdDrawRectangle immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawRectangle)
---@return void
function command_buffer.executeDrawRectangle(...) end

---
--- Queues layer.CmdDrawRectanglePro into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawRectanglePro)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawRectanglePro(...) end

---
--- Executes layer.CmdDrawRectanglePro immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawRectanglePro)
---@return void
function command_buffer.executeDrawRectanglePro(...) end

---
--- Queues layer.CmdDrawRectangleLinesPro into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawRectangleLinesPro)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawRectangleLinesPro(...) end

---
--- Executes layer.CmdDrawRectangleLinesPro immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawRectangleLinesPro)
---@return void
function command_buffer.executeDrawRectangleLinesPro(...) end

---
--- Queues layer.CmdDrawLine into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawLine)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawLine(...) end

---
--- Executes layer.CmdDrawLine immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawLine)
---@return void
function command_buffer.executeDrawLine(...) end

---
--- Queues layer.CmdDrawText into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawText)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawText(...) end

---
--- Executes layer.CmdDrawText immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawText)
---@return void
function command_buffer.executeDrawText(...) end

---
--- Queues layer.CmdDrawTextCentered into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawTextCentered)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawTextCentered(...) end

---
--- Executes layer.CmdDrawTextCentered immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawTextCentered)
---@return void
function command_buffer.executeDrawTextCentered(...) end

---
--- Queues layer.CmdTextPro into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdTextPro)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueTextPro(...) end

---
--- Executes layer.CmdTextPro immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdTextPro)
---@return void
function command_buffer.executeTextPro(...) end

---
--- Queues layer.CmdDrawImage into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawImage)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawImage(...) end

---
--- Executes layer.CmdDrawImage immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawImage)
---@return void
function command_buffer.executeDrawImage(...) end

---
--- Queues layer.CmdTexturePro into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdTexturePro)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueTexturePro(...) end

---
--- Executes layer.CmdTexturePro immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdTexturePro)
---@return void
function command_buffer.executeTexturePro(...) end

---
--- Queues layer.CmdDrawEntityAnimation into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawEntityAnimation)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawEntityAnimation(...) end

---
--- Executes layer.CmdDrawEntityAnimation immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawEntityAnimation)
---@return void
function command_buffer.executeDrawEntityAnimation(...) end

---
--- Queues layer.CmdDrawTransformEntityAnimation into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawTransformEntityAnimation)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawTransformEntityAnimation(...) end

---
--- Executes layer.CmdDrawTransformEntityAnimation immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawTransformEntityAnimation)
---@return void
function command_buffer.executeDrawTransformEntityAnimation(...) end

---
--- Queues layer.CmdDrawTransformEntityAnimationPipeline into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawTransformEntityAnimationPipeline)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawTransformEntityAnimationPipeline(...) end

---
--- Executes layer.CmdDrawTransformEntityAnimationPipeline immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawTransformEntityAnimationPipeline)
---@return void
function command_buffer.executeDrawTransformEntityAnimationPipeline(...) end

---
--- Queues layer.CmdSetShader into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSetShader)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueSetShader(...) end

---
--- Executes layer.CmdSetShader immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSetShader)
---@return void
function command_buffer.executeSetShader(...) end

---
--- Queues layer.CmdResetShader into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdResetShader)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueResetShader(...) end

---
--- Executes layer.CmdResetShader immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdResetShader)
---@return void
function command_buffer.executeResetShader(...) end

---
--- Queues layer.CmdSetBlendMode into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSetBlendMode)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueSetBlendMode(...) end

---
--- Executes layer.CmdSetBlendMode immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSetBlendMode)
---@return void
function command_buffer.executeSetBlendMode(...) end

---
--- Queues layer.CmdUnsetBlendMode into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdUnsetBlendMode)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueUnsetBlendMode(...) end

---
--- Executes layer.CmdUnsetBlendMode immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdUnsetBlendMode)
---@return void
function command_buffer.executeUnsetBlendMode(...) end

---
--- Queues layer.CmdSendUniformFloat into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSendUniformFloat)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueSendUniformFloat(...) end

---
--- Executes layer.CmdSendUniformFloat immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSendUniformFloat)
---@return void
function command_buffer.executeSendUniformFloat(...) end

---
--- Queues layer.CmdSendUniformInt into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSendUniformInt)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueSendUniformInt(...) end

---
--- Executes layer.CmdSendUniformInt immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSendUniformInt)
---@return void
function command_buffer.executeSendUniformInt(...) end

---
--- Queues layer.CmdSendUniformVec2 into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSendUniformVec2)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueSendUniformVec2(...) end

---
--- Executes layer.CmdSendUniformVec2 immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSendUniformVec2)
---@return void
function command_buffer.executeSendUniformVec2(...) end

---
--- Queues layer.CmdSendUniformVec3 into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSendUniformVec3)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueSendUniformVec3(...) end

---
--- Executes layer.CmdSendUniformVec3 immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSendUniformVec3)
---@return void
function command_buffer.executeSendUniformVec3(...) end

---
--- Queues layer.CmdSendUniformVec4 into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSendUniformVec4)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueSendUniformVec4(...) end

---
--- Executes layer.CmdSendUniformVec4 immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSendUniformVec4)
---@return void
function command_buffer.executeSendUniformVec4(...) end

---
--- Queues layer.CmdSendUniformFloatArray into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSendUniformFloatArray)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueSendUniformFloatArray(...) end

---
--- Executes layer.CmdSendUniformFloatArray immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSendUniformFloatArray)
---@return void
function command_buffer.executeSendUniformFloatArray(...) end

---
--- Queues layer.CmdSendUniformIntArray into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSendUniformIntArray)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueSendUniformIntArray(...) end

---
--- Executes layer.CmdSendUniformIntArray immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSendUniformIntArray)
---@return void
function command_buffer.executeSendUniformIntArray(...) end

---
--- Queues layer.CmdVertex into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdVertex)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueVertex(...) end

---
--- Executes layer.CmdVertex immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdVertex)
---@return void
function command_buffer.executeVertex(...) end

---
--- Queues layer.CmdBeginOpenGLMode into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdBeginOpenGLMode)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueBeginOpenGLMode(...) end

---
--- Executes layer.CmdBeginOpenGLMode immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdBeginOpenGLMode)
---@return void
function command_buffer.executeBeginOpenGLMode(...) end

---
--- Queues layer.CmdEndOpenGLMode into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdEndOpenGLMode)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueEndOpenGLMode(...) end

---
--- Executes layer.CmdEndOpenGLMode immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdEndOpenGLMode)
---@return void
function command_buffer.executeEndOpenGLMode(...) end

---
--- Queues layer.CmdSetColor into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSetColor)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueSetColor(...) end

---
--- Executes layer.CmdSetColor immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSetColor)
---@return void
function command_buffer.executeSetColor(...) end

---
--- Queues layer.CmdSetLineWidth into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSetLineWidth)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueSetLineWidth(...) end

---
--- Executes layer.CmdSetLineWidth immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSetLineWidth)
---@return void
function command_buffer.executeSetLineWidth(...) end

---
--- Queues layer.CmdSetTexture into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSetTexture)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueSetTexture(...) end

---
--- Executes layer.CmdSetTexture immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdSetTexture)
---@return void
function command_buffer.executeSetTexture(...) end

---
--- Queues layer.CmdRenderRectVerticesFilledLayer into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdRenderRectVerticesFilledLayer)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueRenderRectVerticesFilledLayer(...) end

---
--- Executes layer.CmdRenderRectVerticesFilledLayer immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdRenderRectVerticesFilledLayer)
---@return void
function command_buffer.executeRenderRectVerticesFilledLayer(...) end

---
--- Queues layer.CmdRenderRectVerticesOutlineLayer into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdRenderRectVerticesOutlineLayer)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueRenderRectVerticesOutlineLayer(...) end

---
--- Executes layer.CmdRenderRectVerticesOutlineLayer immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdRenderRectVerticesOutlineLayer)
---@return void
function command_buffer.executeRenderRectVerticesOutlineLayer(...) end

---
--- Queues layer.CmdDrawPolygon into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawPolygon)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawPolygon(...) end

---
--- Executes layer.CmdDrawPolygon immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawPolygon)
---@return void
function command_buffer.executeDrawPolygon(...) end

---
--- Queues layer.CmdRenderNPatchRect into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdRenderNPatchRect)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueRenderNPatchRect(...) end

---
--- Executes layer.CmdRenderNPatchRect immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdRenderNPatchRect)
---@return void
function command_buffer.executeRenderNPatchRect(...) end

---
--- Queues layer.CmdDrawTriangle into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawTriangle)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawTriangle(...) end

---
--- Executes layer.CmdDrawTriangle immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawTriangle)
---@return void
function command_buffer.executeDrawTriangle(...) end

---
--- Queues layer.CmdBeginStencilMode into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdBeginStencilMode)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueBeginStencilMode(...) end

---
--- Executes layer.CmdBeginStencilMode immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdBeginStencilMode)
---@return void
function command_buffer.executeBeginStencilMode(...) end

---
--- Queues layer.CmdStencilOp into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdStencilOp)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueStencilOp(...) end

---
--- Executes layer.CmdStencilOp immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdStencilOp)
---@return void
function command_buffer.executeStencilOp(...) end

---
--- Queues layer.CmdRenderBatchFlush into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdRenderBatchFlush)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueRenderBatchFlush(...) end

---
--- Executes layer.CmdRenderBatchFlush immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdRenderBatchFlush)
---@return void
function command_buffer.executeRenderBatchFlush(...) end

---
--- Queues layer.CmdAtomicStencilMask into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdAtomicStencilMask)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueAtomicStencilMask(...) end

---
--- Executes layer.CmdAtomicStencilMask immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdAtomicStencilMask)
---@return void
function command_buffer.executeAtomicStencilMask(...) end

---
--- Queues layer.CmdColorMask into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdColorMask)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueColorMask(...) end

---
--- Executes layer.CmdColorMask immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdColorMask)
---@return void
function command_buffer.executeColorMask(...) end

---
--- Queues layer.CmdStencilFunc into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdStencilFunc)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueStencilFunc(...) end

---
--- Executes layer.CmdStencilFunc immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdStencilFunc)
---@return void
function command_buffer.executeStencilFunc(...) end

---
--- Queues layer.CmdEndStencilMode into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdEndStencilMode)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueEndStencilMode(...) end

---
--- Executes layer.CmdEndStencilMode immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdEndStencilMode)
---@return void
function command_buffer.executeEndStencilMode(...) end

---
--- Queues layer.CmdClearStencilBuffer into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdClearStencilBuffer)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueClearStencilBuffer(...) end

---
--- Executes layer.CmdClearStencilBuffer immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdClearStencilBuffer)
---@return void
function command_buffer.executeClearStencilBuffer(...) end

---
--- Queues layer.CmdBeginStencilMask into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdBeginStencilMask)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueBeginStencilMask(...) end

---
--- Executes layer.CmdBeginStencilMask immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdBeginStencilMask)
---@return void
function command_buffer.executeBeginStencilMask(...) end

---
--- Queues layer.CmdEndStencilMask into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdEndStencilMask)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueEndStencilMask(...) end

---
--- Executes layer.CmdEndStencilMask immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdEndStencilMask)
---@return void
function command_buffer.executeEndStencilMask(...) end

---
--- Queues layer.CmdDrawCenteredEllipse into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawCenteredEllipse)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawCenteredEllipse(...) end

---
--- Executes layer.CmdDrawCenteredEllipse immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawCenteredEllipse)
---@return void
function command_buffer.executeDrawCenteredEllipse(...) end

---
--- Queues layer.CmdDrawRoundedLine into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawRoundedLine)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawRoundedLine(...) end

---
--- Executes layer.CmdDrawRoundedLine immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawRoundedLine)
---@return void
function command_buffer.executeDrawRoundedLine(...) end

---
--- Queues layer.CmdDrawPolyline into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawPolyline)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawPolyline(...) end

---
--- Executes layer.CmdDrawPolyline immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawPolyline)
---@return void
function command_buffer.executeDrawPolyline(...) end

---
--- Queues layer.CmdDrawArc into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawArc)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawArc(...) end

---
--- Executes layer.CmdDrawArc immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawArc)
---@return void
function command_buffer.executeDrawArc(...) end

---
--- Queues layer.CmdDrawTriangleEquilateral into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawTriangleEquilateral)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawTriangleEquilateral(...) end

---
--- Executes layer.CmdDrawTriangleEquilateral immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawTriangleEquilateral)
---@return void
function command_buffer.executeDrawTriangleEquilateral(...) end

---
--- Queues layer.CmdDrawCenteredFilledRoundedRect into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawCenteredFilledRoundedRect)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawCenteredFilledRoundedRect(...) end

---
--- Executes layer.CmdDrawCenteredFilledRoundedRect immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawCenteredFilledRoundedRect)
---@return void
function command_buffer.executeDrawCenteredFilledRoundedRect(...) end

---
--- Queues layer.CmdDrawSpriteCentered into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawSpriteCentered)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawSpriteCentered(...) end

---
--- Executes layer.CmdDrawSpriteCentered immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawSpriteCentered)
---@return void
function command_buffer.executeDrawSpriteCentered(...) end

---
--- Queues layer.CmdDrawSpriteTopLeft into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawSpriteTopLeft)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawSpriteTopLeft(...) end

---
--- Executes layer.CmdDrawSpriteTopLeft immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawSpriteTopLeft)
---@return void
function command_buffer.executeDrawSpriteTopLeft(...) end

---
--- Queues layer.CmdDrawDashedCircle into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawDashedCircle)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawDashedCircle(...) end

---
--- Executes layer.CmdDrawDashedCircle immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawDashedCircle)
---@return void
function command_buffer.executeDrawDashedCircle(...) end

---
--- Queues layer.CmdDrawDashedRoundedRect into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawDashedRoundedRect)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawDashedRoundedRect(...) end

---
--- Executes layer.CmdDrawDashedRoundedRect immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawDashedRoundedRect)
---@return void
function command_buffer.executeDrawDashedRoundedRect(...) end

---
--- Queues layer.CmdDrawDashedLine into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawDashedLine)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawDashedLine(...) end

---
--- Executes layer.CmdDrawDashedLine immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawDashedLine)
---@return void
function command_buffer.executeDrawDashedLine(...) end

---
--- Queues layer.CmdDrawGradientRectCentered into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawGradientRectCentered)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawGradientRectCentered(...) end

---
--- Executes layer.CmdDrawGradientRectCentered immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawGradientRectCentered)
---@return void
function command_buffer.executeDrawGradientRectCentered(...) end

---
--- Queues layer.CmdDrawGradientRectRoundedCentered into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawGradientRectRoundedCentered)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawGradientRectRoundedCentered(...) end

---
--- Executes layer.CmdDrawGradientRectRoundedCentered immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawGradientRectRoundedCentered)
---@return void
function command_buffer.executeDrawGradientRectRoundedCentered(...) end

---
--- Queues layer.CmdDrawBatchedEntities into a layer via command_buffer (World or Screen space).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawBatchedEntities)
---@param z integer
---@param renderSpace? layer.DrawCommandSpace
---@return void
function command_buffer.queueDrawBatchedEntities(...) end

---
--- Executes layer.CmdDrawBatchedEntities immediately (bypasses the command queue).
---
---@param layer Layer
---@param init_fn fun(c: layer.CmdDrawBatchedEntities)
---@return void
function command_buffer.executeDrawBatchedEntities(...) end

---
--- Create a navigation group.
---
---@param name string
function controller_nav.create_group(...) end

---
--- Create a navigation layer.
---
---@param name string
function controller_nav.create_layer(...) end

---
--- Attach an existing group to a layer.
---
---@param layer string
---@param group string
function controller_nav.add_group_to_layer(...) end

---
--- Navigate within or across groups.
---
---@param group string
---@param dir 'L'|'R'|'U'|'D'
function controller_nav.navigate(...) end

---
--- Trigger the select callback for the currently focused entity.
---
---@param group string
function controller_nav.select_current(...) end

---
--- Enable or disable a specific entity for navigation.
---
---@param e entt.entity
---@param enabled boolean
function controller_nav.set_entity_enabled(...) end

---
--- Print debug info on groups/layers.
---
function controller_nav.debug_print_state(...) end

---
--- Validate layer/group configuration.
---
function controller_nav.validate(...) end

---
--- Return the currently focused group.
---
---@return string
function controller_nav.current_focus_group(...) end

---
--- Set Lua callbacks for a specific navigation group.
---
---@param group string
---@param tbl table {on_focus:function|nil, on_unfocus:function|nil, on_select:function|nil}
function controller_nav.set_group_callbacks(...) end

---
--- Link a group's navigation directions to other groups.
---
---@param from string
---@param dirs table {up:string|nil, down:string|nil, left:string|nil, right:string|nil}
function controller_nav.link_groups(...) end

---
--- Toggle navigation mode for the group.
---
---@param group string
---@param mode 'spatial'|'linear'
function controller_nav.set_group_mode(...) end

---
--- Enable or disable wrap-around navigation.
---
---@param group string
---@param wrap boolean
function controller_nav.set_wrap(...) end

---
--- Force cursor focus to a specific entity. Note that this does not affect the navigation state, and may be overridden on next navigation action.
---
---@param e entt.entity
function controller_nav.focus_entity(...) end

---
--- Update cursor focus based on current input state.
---
---@return nil
function input.updateCursorFocus(...) end

---
--- Bind an action to a device code with a trigger.
---
---@param action string
---@param cfg {device:string, key?:integer, mouse?:integer, button?:integer, axis?:integer, trigger?:string, threshold?:number, modifiers?:integer[], context?:string}
---@return nil
function input.bind(...) end

---
--- Clear all bindings for an action.
---
---@param action string
---@return nil
function input.clear(...) end

---
--- True on the frame the action is pressed.
---
---@param action string
---@return boolean
function input.action_pressed(...) end

---
--- True on the frame the action is released.
---
---@param action string
---@return boolean
function input.action_released(...) end

---
--- True while the action is held.
---
---@param action string
---@return boolean
function input.action_down(...) end

---
--- Analog value for axis-type actions.
---
---@param action string
---@return number
function input.action_value(...) end

---
--- Set the active input context.
---
---@param ctx string
---@return nil
function input.set_context(...) end

---
--- Capture the next input event and pass it to callback as a binding table.
---
---@param action string
---@param cb fun(ok:boolean,binding:table)
---@return nil
function input.start_rebind(...) end

---
--- Sorts all layers by their Z-index.
---
---@return nil
function layer.SortLayers(...) end

---
--- Updates the Z-index of a layer and resorts the layer list.
---
---@param layer layer.Layer
---@param newZIndex integer
---@return nil
function layer.UpdateLayerZIndex(...) end

---
--- Creates a new layer with a default-sized main canvas and returns it.
---
---@return layer.Layer
function layer.CreateLayer(...) end

---
--- Creates a layer with a main canvas of a specified size.
---
---@param width integer
---@param height integer
---@return layer.Layer
function layer.CreateLayerWithSize(...) end

---
--- Applies scaling transformation to the current layer, immeidately (does not queue).
---
---@param x number # Scale factor in X direction
---@param y number # Scale factor in Y direction
---@return nil
function layer.ExecuteScale(...) end

---
--- Applies translation transformation to the current layer, immeidately (does not queue).
---
---@param x number # Translation in X direction
---@param y number # Translation in Y direction
---@return nil
function layer.ExecuteTranslate(...) end

---
--- Removes a layer and unloads its canvases.
---
---@param layer layer.Layer
---@return nil
function layer.RemoveLayerFromCanvas(...) end

---
--- Resizes a specific canvas within a layer.
---
---@param layer layer.Layer
---@param canvasName string
---@param newWidth integer
---@param newHeight integer
---@return nil
function layer.ResizeCanvasInLayer(...) end

---
--- Adds a canvas to the layer, matching the layer's default size.
---
---@param layer layer.Layer
---@param canvasName string
---@return nil
function layer.AddCanvasToLayer(...) end

---
--- Adds a canvas of a specific size to the layer.
---
---@overload fun(layer: layer.Layer, canvasName: string, width: integer, height: integer):nil
function layer.AddCanvasToLayer(...) end

---
--- Removes a canvas by name from a specific layer.
---
---@param layer layer.Layer
---@param canvasName string
---@return nil
function layer.RemoveCanvas(...) end

---
--- Destroys all layers and their contents.
---
---@return nil
function layer.UnloadAllLayers(...) end

---
--- Clears draw commands for a specific layer.
---
---@param layer layer.Layer
---@return nil
function layer.ClearDrawCommands(...) end

---
--- Clears all draw commands from all layers.
---
---@return nil
function layer.ClearAllDrawCommands(...) end

---
--- Begins drawing to all canvases. (Calls BeginTextureMode on all).
---
---@return nil
function layer.Begin(...) end

---
--- Ends drawing to all canvases. (Calls EndTextureMode on all).
---
---@return nil
function layer.End(...) end

---
--- Renders all layers to the current render target.
---
---@param camera? Camera2D # Optional camera for rendering.
---@return nil
function layer.RenderAllLayersToCurrentRenderTarget(...) end

---
--- Draws a layer's queued commands to a specific canvas within that layer.
---
---@param layer layer.Layer
---@param canvasName string
---@param camera Camera2D # The camera to use for rendering.
---@return nil
function layer.DrawLayerCommandsToSpecificCanvas(...) end

---
--- Draws a canvas to the current render target with transform, color, and an optional shader.
---
---@param layer layer.Layer
---@param canvasName string
---@param x? number
---@param y? number
---@param rotation? number
---@param scaleX? number
---@param scaleY? number
---@param color? Color
---@param shader? Shader
---@param flat? boolean
---@return nil
function layer.DrawCanvasToCurrentRenderTargetWithTransform(...) end

---
--- Draws a canvas from one layer onto a canvas in another layer.
---
---@param sourceLayer layer.Layer
---@param sourceCanvasName string
---@param destLayer layer.Layer
---@param destCanvasName string
---@param x number
---@param y number
---@param rotation number
---@param scaleX number
---@param scaleY number
---@param tint Color
---@return nil
function layer.DrawCanvasOntoOtherLayer(...) end

---
--- Draws a canvas from one layer onto another with a shader.
---
---@param sourceLayer layer.Layer
---@param sourceCanvasName string
---@param destLayer layer.Layer
---@param destCanvasName string
---@param x number
---@param y number
---@param rotation number
---@param scaleX number
---@param scaleY number
---@param tint Color
---@param shader Shader
---@return nil
function layer.DrawCanvasOntoOtherLayerWithShader(...) end

---
--- Draws a canvas to the current render target, fitting it to a destination rectangle.
---
---@param layer layer.Layer
---@param canvasName string
---@param destRect Rectangle
---@param color Color
---@param shader Shader
---@return nil
function layer.DrawCanvasToCurrentRenderTargetWithDestRect(...) end

---
--- Executes a custom drawing function that renders to a specific canvas.
---
---@param layer layer.Layer
---@param canvasName? string
---@param drawActions fun():void
---@return nil
function layer.DrawCustomLamdaToSpecificCanvas(...) end

---
--- Draws an entity with a Transform and Animation component directly.
---
---@param registry Registry
---@param entity Entity
---@return nil
function layer.DrawTransformEntityWithAnimation(...) end

---
--- Draws an entity with a Transform and Animation component using the rendering pipeline.
---
---@param registry Registry
---@param entity Entity
---@return nil
function layer.DrawTransformEntityWithAnimationWithPipeline(...) end

---
--- Queues a CmdBeginDrawing into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdBeginDrawing) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueBeginDrawing(...) end

---
--- Queues a CmdClearStencilBuffer into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdClearStencilBuffer) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueClearStencilBuffer(...) end

---
--- Queues a CmdColorMask into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdColorMask) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueColorMask(...) end

---
--- Queues a CmdStencilOp into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdStencilOp) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueStencilOp(...) end

---
--- Queues a CmdRenderBatchFlush into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdRenderBatchFlush) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueRenderBatchFlush(...) end

---
--- Queues a CmdAtomicStencilMask into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdAtomicStencilMask) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueAtomicStencilMask(...) end

---
--- Queues a CmdStencilFunc into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdStencilFunc) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueStencilFunc(...) end

---
--- Queues a CmdBeginStencilMode into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdBeginStencilMode) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueBeginStencilMode(...) end

---
--- Queues a CmdEndStencilMode into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdEndStencilMode) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueEndStencilMode(...) end

---
--- Queues a CmdBeginStencilMask into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdBeginStencilMask) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueBeginStencilMask(...) end

---
--- Queues a CmdEndStencilMask into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdEndStencilMask) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueEndStencilMask(...) end

---
--- Queues a CmdDrawCenteredEllipse into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawCenteredEllipse) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawCenteredEllipse(...) end

---
--- Queues a CmdDrawRoundedLine into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawRoundedLine) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawRoundedLine(...) end

---
--- Queues a CmdDrawPolyline into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawPolyline) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawPolyline(...) end

---
--- Queues a CmdDrawArc into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawArc) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawArc(...) end

---
--- Queues a CmdDrawTriangleEquilateral into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawTriangleEquilateral) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawTriangleEquilateral(...) end

---
--- Queues a CmdDrawCenteredFilledRoundedRect into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawCenteredFilledRoundedRect) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawCenteredFilledRoundedRect(...) end

---
--- Queues a CmdDrawSpriteCentered into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawSpriteCentered) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawSpriteCentered(...) end

---
--- Queues a CmdDrawSpriteTopLeft into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawSpriteTopLeft) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawSpriteTopLeft(...) end

---
--- Queues a CmdDrawDashedCircle into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawDashedCircle) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawDashedCircle(...) end

---
--- Queues a CmdDrawDashedRoundedRect into the layer draw list. Executes init    _fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawDashedRoundedRect) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawDashedRoundedRect(...) end

---
--- Queues a CmdDrawDashedLine into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawDashedLine) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawDashedLine(...) end

---
--- Queues a CmdDrawGradientRectCentered into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawGradientRectCentered) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawGradientRectCentered(...) end

---
--- Queues a CmdDrawGradientRectRoundedCentered into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawGradientRectRoundedCentered) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawGradientRectRoundedCentered(...) end

---
--- Queues a CmdDrawBatchedEntities into the layer draw list. This command batches multiple entities for optimized shader rendering, avoiding Lua execution during the render phase. The entities vector and registry are captured when queued and executed during rendering with automatic shader batching.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawBatchedEntities) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawBatchedEntities(...) end

---
--- Queues a CmdEndDrawing into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdEndDrawing) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueEndDrawing(...) end

---
--- Queues a CmdClearBackground into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdClearBackground) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueClearBackground(...) end

---
--- Queues a CmdBeginScissorMode into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdBeginScissorMode) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueBeginScissorMode(...) end

---
--- Queues a CmdEndScissorMode into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdEndScissorMode) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueEndScissorMode(...) end

---
--- Queues a CmdTranslate into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdTranslate) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueTranslate(...) end

---
--- Queues a CmdScale into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdScale) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueScale(...) end

---
--- Queues a CmdRotate into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdRotate) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueRotate(...) end

---
--- Queues a CmdAddPush into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdAddPush) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueAddPush(...) end

---
--- Queues a CmdAddPop into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdAddPop) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueAddPop(...) end

---
--- Queues a CmdPushObjectTransformsToMatrix into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order. Use with popMatrix()
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdPushObjectTransformsToMatrix) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queuePushObjectTransformsToMatrix(...) end

---
--- Queues a CmdScopedTransformCompositeRender into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order. Use with popMatrix()
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdScopedTransformCompositeRender) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueScopedTransformCompositeRender(...) end

---
--- Queues a CmdPushMatrix into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdPushMatrix) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queuePushMatrix(...) end

---
--- Queues a CmdPopMatrix into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdPopMatrix) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queuePopMatrix(...) end

---
--- Queues a CmdDrawCircleFilled into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawCircleFilled) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawCircle(...) end

---
--- Queues a CmdDrawRectangle into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawRectangle) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawRectangle(...) end

---
--- Queues a CmdDrawRectanglePro into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawRectanglePro) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawRectanglePro(...) end

---
--- Queues a CmdDrawRectangleLinesPro into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawRectangleLinesPro) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawRectangleLinesPro(...) end

---
--- Queues a CmdDrawLine into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawLine) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawLine(...) end

---
--- Queues a CmdDrawDashedLine into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawDashedLine) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawDashedLine(...) end

---
--- Queues a CmdDrawText into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawText) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawText(...) end

---
--- Queues a CmdDrawTextCentered into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawTextCentered) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawTextCentered(...) end

---
--- Queues a CmdTextPro into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdTextPro) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueTextPro(...) end

---
--- Queues a CmdDrawImage into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawImage) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawImage(...) end

---
--- Queues a CmdTexturePro into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdTexturePro) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueTexturePro(...) end

---
--- Queues a CmdDrawEntityAnimation into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawEntityAnimation) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawEntityAnimation(...) end

---
--- Queues a CmdDrawTransformEntityAnimation into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawTransformEntityAnimation) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawTransformEntityAnimation(...) end

---
--- Queues a CmdDrawTransformEntityAnimationPipeline into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawTransformEntityAnimationPipeline) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawTransformEntityAnimationPipeline(...) end

---
--- Queues a CmdSetShader into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdSetShader) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueSetShader(...) end

---
--- Queues a CmdResetShader into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdResetShader) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueResetShader(...) end

---
--- Queues a CmdSetBlendMode into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdSetBlendMode) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueSetBlendMode(...) end

---
--- Queues a CmdUnsetBlendMode into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdUnsetBlendMode) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueUnsetBlendMode(...) end

---
--- Queues a CmdSendUniformFloat into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdSendUniformFloat) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueSendUniformFloat(...) end

---
--- Queues a CmdSendUniformInt into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdSendUniformInt) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueSendUniformInt(...) end

---
--- Queues a CmdSendUniformVec2 into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdSendUniformVec2) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueSendUniformVec2(...) end

---
--- Queues a CmdSendUniformVec3 into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdSendUniformVec3) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueSendUniformVec3(...) end

---
--- Queues a CmdSendUniformVec4 into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdSendUniformVec4) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueSendUniformVec4(...) end

---
--- Queues a CmdSendUniformFloatArray into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdSendUniformFloatArray) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueSendUniformFloatArray(...) end

---
--- Queues a CmdSendUniformIntArray into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdSendUniformIntArray) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueSendUniformIntArray(...) end

---
--- Queues a CmdVertex into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdVertex) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueVertex(...) end

---
--- Queues a CmdBeginOpenGLMode into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdBeginOpenGLMode) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueBeginOpenGLMode(...) end

---
--- Queues a CmdEndOpenGLMode into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdEndOpenGLMode) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueEndOpenGLMode(...) end

---
--- Queues a CmdSetColor into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdSetColor) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueSetColor(...) end

---
--- Queues a CmdSetLineWidth into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdSetLineWidth) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueSetLineWidth(...) end

---
--- Queues a CmdSetTexture into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdSetTexture) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueSetTexture(...) end

---
--- Queues a CmdRenderRectVerticesFilledLayer into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdRenderRectVerticesFilledLayer) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueRenderRectVerticesFilledLayer(...) end

---
--- Queues a CmdRenderRectVerticesOutlineLayer into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdRenderRectVerticesOutlineLayer) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueRenderRectVerticesOutlineLayer(...) end

---
--- Queues a CmdDrawPolygon into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawPolygon) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawPolygon(...) end

---
--- Queues a CmdRenderNPatchRect into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdRenderNPatchRect) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueRenderNPatchRect(...) end

---
--- Queues a CmdDrawTriangle into the layer draw list. Executes init_fn with a command instance and inserts it at the specified z-order.
---
---@param layer Layer # Target layer to queue into
---@param init_fn fun(c: layer.CmdDrawTriangle) # Function to initialize the command
---@param z number # Z-order depth to queue at
---@param renderSpace layer.DrawCommandSpace # Draw command space (default: Screen)
---@return void
function layer.queueDrawTriangle(...) end

---
--- Removes a post-process shader from the layer by name.
---
---@param layer Layer # Target layer
---@param shader_name string # Name of the shader to remove
---@return void
function layer.Layer.removePostProcessShader(...) end

---
--- Adds a post-process shader to the layer.
---
---@param layer Layer # Target layer
---@param shader_name string # Name of the shader to add
---@param shader Shader # Shader instance to add
---@return void
function layer.Layer.addPostProcessShader(...) end

---
--- Removes all post-process shaders from the layer.
---
---@param layer Layer # Target layer
---@return void
function layer.Layer.clearPostProcessShaders(...) end

---
--- Assigns the given entity the current top Z-index and increments the counter.
---
---@param e Entity
---@param incrementIndexAfterwards boolean Defaults to true
---@return nil
function layer_order_system.setToTopZIndex(...) end

---
--- Ensures entity a’s zIndex is at least one above b’s.
---
---@param a Entity The entity to move above b
---@param b Entity The reference entity
---@return nil
function layer_order_system.putAOverB(...) end

---
--- Walks all UIBoxComponents without a LayerOrderComponent and pushes them to the top Z-stack.
---
---@return nil
function layer_order_system.updateLayerZIndexesAsNecessary(...) end

---
---
---@param e Entity
---@return integer zIndex
--- Returns the current zIndex of the given entity, assigning one if missing.
function layer_order_system.getZIndex(...) end

---
--- Resets the global Z-index counter back to zero.
---
---@return nil
function layer_order_system.resetRunningZIndex(...) end

---
--- Force-sets an entity’s zIndex to the given value.
---
---@param e Entity
---@param zIndex number The exact zIndex to assign
---@return nil
function layer_order_system.assignZIndexToEntity(...) end

---
--- Loads a language file for the given language code from a specific path.
---
---@param languageCode string # The language to load (e.g., 'en_US').
---@param path string # The filepath to the language JSON file.
---@return nil
function localization.loadLanguage(...) end

---
--- Sets a fallback language if a key isn't found in the current one.
---
---@param languageCode string # The language code to use as a fallback (e.g., 'en_US').
---@return nil
function localization.setFallbackLanguage(...) end

---
--- Returns the currently active language code.
---
---@return string # The currently active language code.
---Gets the currently active language code. This is useful for checking which language is currently set.
function localization.getCurrentLanguage(...) end

---
--- Retrieves a localized string by key, formatting it with an optional Lua table of named parameters.
---
---@param key string                 # Localization key
---@param args table<string,any>?    # Optional named formatting args
---@return string                    # Localized & formatted text
function localization.get(...) end

---
--- Gets the raw string from the language file, using fallbacks if necessary.
---
---@param key string # The localization key.
---@return string # The raw, untransformed string or a '[MISSING: key]' message.
function localization.getRaw(...) end

---
--- Retrieves font data associated with the current language.
---
---@return FontData # A handle to the font data for the current language.
function localization.getFontData(...) end

---
--- Gets the font data for the current language.
---
---@return FontData # The font for the current language.
function localization.getFont(...) end

---
--- Gets the rendered width of a text string using the current language's font.
---
---@param text string # The text to measure.
---@param fontSize number # The font size to use when measuring.
---@param spacing number # The spacing between characters.
---@return number # The width of the text when rendered with the current language's font.
function localization.getTextWidthWithCurrentFont(...) end

---
--- Loads font data from the specified path.
---
---@param path string # The file path to the font data JSON.
---@return nil
function localization.loadFontData(...) end

---
--- Registers a callback that executes after the current language changes.
---
---@param callback fun(newLanguageCode: string) # A function to call when the language changes.
---@return nil
function localization.onLanguageChanged(...) end

---
--- Sets the current language and notifies all listeners.
---
---@param languageCode string # The language code to make active.
---@return boolean # True if the language was set successfully, false otherwise.
function localization.setCurrentLanguage(...) end

---
--- Emits a burst of particles from the specified emitter entity.
---
---@param emitterEntity Entity # The entity that has the particle emitter component.
---@param count integer # The number of particles to emit in a single burst.
---@return nil
function particle.EmitParticles(...) end

---
--- Attaches an existing emitter to another entity, with optional offset.
---
---@param emitter entt::entity---@param target entt::entity---@param opts table? # { offset = Vector2 }
function particle.AttachEmitter(...) end

---
--- Destroys all live particles.
---
---@return void
---Destroys every live particle in the registry.
function particle.WipeAll(...) end

---
--- Destroys all particles with the given string tag.
---
---@param tag string # The tag to match
---@return void
---Destroys only those particles whose ParticleTag.name == tag.
function particle.WipeTagged(...) end

---
--- Creates a ParticleEmitter; pass a table to override any defaults.
---
---@overload fun():ParticleEmitter
---@param opts table? # Optional overrides for any emitter field
---@field opts.size Vector2
---@field opts.emissionRate number
---@field opts.colors Color[]
---@return ParticleEmitter
function particle.CreateParticleEmitter(...) end

---
--- Creates a Particle from Lua, applies optional animation, sprite, color tinting, and tag.
---
---@param location Vector2                        # world-space spawn position
---@param size     Vector2                        # initial width/height of the particle
---@param opts     table?                         # optional config table with any of:
--- -- renderType        ParticleRenderType         # TEXTURE, RECTANGLE_LINE, RECTANGLE_FILLED, etc.
--- -- velocity          Vector2                    # initial (vx,vy)
--- -- rotation          number                     # starting rotation in degrees
--- -- rotationSpeed     number                     # degrees/sec
--- -- scale             number                     # uniform scale multiplier
--- -- lifespan          number                     # seconds until auto-destroy (≤0 = infinite)
--- -- age               number                     # initial age in seconds
--- -- color             Color                      # immediately applied tint
--- -- gravity           number                     # downward acceleration per second
--- -- acceleration      number                     # acceleration along velocity vector
--- -- startColor        Color                      # tint at birth
--- -- endColor          Color                      # tint at death
--- -- onUpdateCallback  function(particle,dt)       # run each frame
--- -- shadow            boolean                    # draw or disable shadow (default = true)
---@param animCfg  table?                         # optional animation config:
--- -- loop              boolean                    # whether to loop the animation
--- -- animationName     string                     # animation name or sprite UUID
--- -- useSpriteNotAnimation boolean                # use a single static sprite instead of animation
--- -- fg                Color?                     # optional foreground tint override
--- -- bg                Color?                     # optional background tint override
---@param tag      string?                        # optional tag to attach to the particle
---@return entt::entity                            # newly created particle entity
function particle.CreateParticle(...) end

---
--- Defines ordered collision tags (also initializes trigger tags, categories, and type ids).
---
---@param world physics.PhysicsWorld
---@param tags string[]
function physics.set_collision_tags(...) end

---
--- Enables collision between tagA and each tag in tags.
---
---@param world physics.PhysicsWorld
---@param tagA string
---@param tags string[]
function physics.enable_collision_between_many(...) end

---
--- Disables collision between tagA and each tag in tags.
---
---@param world physics.PhysicsWorld
---@param tagA string
---@param tags string[]
function physics.disable_collision_between_many(...) end

---
--- Enable collision for a single pair or a list in one call.
---
---@param world physics.PhysicsWorld
---@param tagA string
---@param tagB_or_list string|string[]
function physics.enable_collision_between(...) end

---
--- Disable collision for a single pair or a list in one call.
---
---@param world physics.PhysicsWorld
---@param tagA string
---@param tagB_or_list string|string[]
function physics.disable_collision_between(...) end

---
--- Marks pairs (tagA, tag) as triggers (sensors) so they do not resolve collisions.
---
---@param world physics.PhysicsWorld
---@param tagA string
---@param tags string[]
function physics.enable_trigger_between_many(...) end

---
--- Unmarks triggers for each (tagA, tag).
---
---@param world physics.PhysicsWorld
---@param tagA string
---@param tags string[]
function physics.disable_trigger_between_many(...) end

---
--- Enable triggers for a single pair or a list in one call.
---
---@param world physics.PhysicsWorld
---@param tagA string
---@param tagB_or_list string|string[]
function physics.enable_trigger_between(...) end

---
--- Disable triggers for a single pair or a list in one call.
---
---@param world physics.PhysicsWorld
---@param tagA string
---@param tagB_or_list string|string[]
function physics.disable_trigger_between(...) end

---
--- Rewrites the mask list for one tag and reapplies filters to existing shapes of that category.
---
---@param world physics.PhysicsWorld
---@param tag string
---@param collidable_tags string[]
function physics.update_collision_masks_for(...) end

---
--- Re-applies collision filters to all shapes based on their current tags.
---
---@param world physics.PhysicsWorld
function physics.reapply_all_filters(...) end

---
--- Converts a lightuserdata (internally an entity id) to entt.entity.
---
---@param p lightuserdata
---@return entt.entity
function physics.entity_from_ptr(...) end

---
--- Returns entt.entity stored in body->userData or entt.null.
---
---@param body lightuserdata @ cpBody*
---@return entt.entity
function physics.GetEntityFromBody(...) end

---
--- Buffered collision-begin events for the pair (type1, type2) since last PostUpdate().
---
---@param world physics.PhysicsWorld
---@param type1 string
---@param type2 string
---@return {a:entt.entity, b:entt.entity, x1:number, y1:number, x2:number, y2:number, nx:number, ny:number}[]
function physics.GetCollisionEnter(...) end

---
--- Buffered trigger-begin hits for (type1, type2) since last PostUpdate(). Returns entity handles.
---
---@param world physics.PhysicsWorld
---@param type1 string
---@param type2 string
---@return entt.entity[]
function physics.GetTriggerEnter(...) end

---
--- Segment raycast through the physics space (nearest-first).
---
---@param world physics.PhysicsWorld
---@param x1 number @ ray start X (Chipmunk units)
---@param y1 number @ ray start Y (Chipmunk units)
---@param x2 number @ ray end X (Chipmunk units)
---@param y2 number @ ray end Y (Chipmunk units)
---@return physics.RaycastHit[]
function physics.Raycast(...) end

---
--- Returns entities for all shapes intersecting the rectangle [x1,y1]-[x2,y2].
---
---@param world physics.PhysicsWorld
---@param x1 number @ rect minX
---@param y1 number @ rect minY
---@param x2 number @ rect maxX
---@param y2 number @ rect maxY
---@return entt.entity[] @ entities whose shapes intersect the AABB
function physics.GetObjectsInArea(...) end

---
--- Stores an entity ID in shape->userData.
---
---@param shape lightuserdata @ cpShape*
---@param e entt.entity
function physics.SetEntityToShape(...) end

---
--- Stores an entity ID in body->userData.
---
---@param body lightuserdata @ cpBody*
---@param e entt.entity
function physics.SetEntityToBody(...) end

---
--- Creates cpBody + cpShape for entity, applies tag filter + collisionType, and adds to space.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param tag string @ collision tag/category
---@param shapeType 'rectangle'|'circle'|'polygon'|'chain'
---@param a number @ rectangle: width | circle: radius
---@param b number @ rectangle: height
---@param c number @ unused (polygon/chain use points)
---@param d number @ unused (polygon/chain use points)
---@param isSensor boolean
---@param points { {x:number,y:number} } | nil @ optional polygon/chain vertices (overrides a–d)
---@return nil
function physics.AddCollider(...) end

---
--- Adds an extra shape to an existing entity body (or creates a body if missing).
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param tag string
---@param shapeType 'rectangle'|'circle'|'polygon'|'chain'
---@param a number
---@param b number
---@param c number
---@param d number
---@param isSensor boolean
---@param points { {x:number,y:number} } | nil
---@return nil
function physics.add_shape_to_entity(...) end

---
--- Removes the shape at index (0 removes the primary). Returns true if removed.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param index integer @ 0=primary, >=1 extra
---@return boolean
function physics.remove_shape_at(...) end

---
--- Removes the primary and all extra shapes from the entity.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@return nil
function physics.clear_all_shapes(...) end

---
--- Returns the total number of shapes on the entity (primary + extras).
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@return integer
function physics.get_shape_count(...) end

---
--- Returns the AABB (cpBB) of the shape at index.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param index integer
---@return {l:number,b:number,r:number,t:number}
function physics.get_shape_bb(...) end

---
--- Sets linear velocity on the entity's body.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param vx number
---@param vy number
function physics.SetVelocity(...) end

---
--- Returns true if the entity's body is sleeping.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@return boolean
function physics.IsSleeping(...) end

---
--- Sets the cpSpace sleep time threshold.
---
---@param world physics.PhysicsWorld
---@param t number
function physics.SetSleepTimeThreshold(...) end

---
--- Gets the cpSpace sleep time threshold.
---
---@param world physics.PhysicsWorld
---@return number
function physics.GetSleepTimeThreshold(...) end

---
--- Returns the body's linear velocity.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@return {x:number,y:number}
function physics.GetVelocity(...) end

---
--- Sets angular velocity on the entity's body.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param av number @ radians/sec
function physics.SetAngularVelocity(...) end

---
--- Applies a force at the body's current position.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param fx number
---@param fy number
function physics.ApplyForce(...) end

---
--- Applies an angular impulse to the body's current angular velocity.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param angularImpulse number
function physics.ApplyAngularImpulse(...) end

---
--- Applies an impulse at the body's current position.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param ix number
---@param iy number
function physics.ApplyImpulse(...) end

---
--- Applies a simple 2-point torque pair to spin the body.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param torque number
function physics.ApplyTorque(...) end

---
--- Scales current velocity by (1 - linear). Simple linear damping helper.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param linear number
function physics.SetDamping(...) end

---
--- Sets cpSpace global damping.
---
---@param world physics.PhysicsWorld
---@param damping number
function physics.SetGlobalDamping(...) end

---
--- Enable/disable arrival deceleration logic.
--- When true, SeekPoint ignores decel and moves full speed all the way.
---
---@param r entt.registry&
---@param e entt.entity
---@param disable boolean
---@return nil
function physics.set_disable_arrival(...) end

---
--- Sets arrival deceleration radius (ignored if disableArrival=true).
---
---@param r entt.registry&
---@param e entt.entity
---@param radius number @distance at which arrival deceleration begins
---@return nil
function physics.set_arrive_radius(...) end

---
--- Returns the body's position.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@return {x:number,y:number}
function physics.GetPosition(...) end

---
--- Sets the body's position directly.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param x number
---@param y number
function physics.SetPosition(...) end

---
--- Returns the body's angle (radians).
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@return number @ radians
function physics.GetAngle(...) end

---
--- Sets the body's angle (radians).
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param radians number
function physics.SetAngle(...) end

---
--- Sets elasticity on ALL shapes owned by this entity (primary + extras).
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param restitution number
function physics.SetRestitution(...) end

---
--- Sets friction on ALL shapes owned by this entity (primary + extras).
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param friction number
function physics.SetFriction(...) end

---
--- Wakes or sleeps the body.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param awake boolean
function physics.SetAwake(...) end

---
--- Returns body mass.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@return number
function physics.GetMass(...) end

---
--- Sets body mass.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param mass number
function physics.SetMass(...) end

---
--- Enables high-iteration + slop tuning on the world and custom velocity update for the body.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param isBullet boolean
function physics.SetBullet(...) end

---
--- If true, sets the moment to INFINITY (lock rotation).
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param fixed boolean
function physics.SetFixedRotation(...) end

---
--- Sets the body's moment of inertia.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param moment number
function physics.SetMoment(...) end

---
--- Switch the Chipmunk body type for the entity.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param bodyType 'static'|'kinematic'|'dynamic'
function physics.SetBodyType(...) end

---
--- Attach a transient number to an arbiter for the duration of contact.
---
---@param world physics.PhysicsWorld
---@param arb lightuserdata @ cpArbiter*
---@param key string
---@param value number
function physics.arb_set_number(...) end

---
--- Get a number previously set on this arbiter (or default/0).
---
---@param world physics.PhysicsWorld
---@param arb lightuserdata @ cpArbiter*
---@param key string
---@param default number|nil
---@return number
function physics.arb_get_number(...) end

---
--- Attach a transient boolean to an arbiter.
---
---@param world physics.PhysicsWorld
---@param arb lightuserdata @ cpArbiter*
---@param key string
---@param value boolean
function physics.arb_set_bool(...) end

---
--- Get a boolean previously set on this arbiter (or default/false).
---
---@param world physics.PhysicsWorld
---@param arb lightuserdata @ cpArbiter*
---@param key string
---@param default boolean|nil
---@return boolean
function physics.arb_get_bool(...) end

---
--- Attach a transient pointer (lightuserdata) to an arbiter.
---
---@param world physics.PhysicsWorld
---@param arb lightuserdata @ cpArbiter*
---@param key string
---@param value lightuserdata
function physics.arb_set_ptr(...) end

---
--- Get a pointer previously set on this arbiter (or nil).
---
---@param world physics.PhysicsWorld
---@param arb lightuserdata @ cpArbiter*
---@param key string
---@return lightuserdata|nil
function physics.arb_get_ptr(...) end

---
--- Clears all PhysicsWorld instances and their data (for shutdown) using the global physics manager.
---
---@return nil
function physics.clear_all_worlds(...) end

---
--- Registers a begin callback for the pair (tagA, tagB). Return false to reject contact.
---
---@param world physics.PhysicsWorld
---@param tagA string
---@param tagB string
---@param fn fun(arb:lightuserdata):boolean|nil
function physics.on_pair_begin(...) end

---
--- Registers a separate callback for the pair (tagA, tagB).
---
---@param world physics.PhysicsWorld
---@param tagA string
---@param tagB string
---@param fn fun(arb:lightuserdata)
function physics.on_pair_separate(...) end

---
--- Registers a begin wildcard callback for a single tag (fires for any counterpart).
---
---@param world physics.PhysicsWorld
---@param tag string
---@param fn fun(arb:lightuserdata):boolean|nil
function physics.on_wildcard_begin(...) end

---
--- Registers a separate wildcard callback for a single tag (fires for any counterpart).
---
---@param world physics.PhysicsWorld
---@param tag string
---@param fn fun(arb:lightuserdata)
function physics.on_wildcard_separate(...) end

---
--- Registers a pre-solve callback for the pair (tagA, tagB). Return false to reject contact.
---
---@param world physics.PhysicsWorld
---@param tagA string
---@param tagB string
---@param fn fun(arb:lightuserdata):boolean|nil
function physics.on_pair_presolve(...) end

---
--- Registers a post-solve callback for the pair (tagA, tagB).
---
---@param world physics.PhysicsWorld
---@param tagA string
---@param tagB string
---@param fn fun(arb:lightuserdata)
function physics.on_pair_postsolve(...) end

---
--- Registers a pre-solve wildcard callback for a single tag (fires for any counterpart).
---
---@param world physics.PhysicsWorld
---@param tag string
---@param fn fun(arb:lightuserdata):boolean|nil
function physics.on_wildcard_presolve(...) end

---
--- Registers a post-solve wildcard callback for a single tag (fires for any counterpart).
---
---@param world physics.PhysicsWorld
---@param tag string
---@param fn fun(arb:lightuserdata)
function physics.on_wildcard_postsolve(...) end

---
--- Clears registered Lua pre/postsolve for that pair.
---
---@param world physics.PhysicsWorld
---@param tagA string
---@param tagB string
function physics.clear_pair_handlers(...) end

---
--- Clears registered Lua pre/postsolve for that tag wildcard.
---
---@param world physics.PhysicsWorld
---@param tag string
function physics.clear_wildcard_handlers(...) end

---
--- Creates cpBody+cpShape from Transform ACTUAL size in the entity's referenced world.
---
---@param R entt.registry&
---@param PM PhysicsManager&
---@param e entt.entity
---@param cfg table @ {shape?:string, tag?:string, sensor?:boolean, density?:number}
---@return nil
function physics.create_physics_for_transform(...) end

---
--- Re-applies current RotationSyncMode immediately (locks/unlocks and snaps angle if needed).
---
---@param R entt.registry
---@param e entt.entity
---@return nil
function physics.enforce_rotation_policy(...) end

---
--- Lock body rotation; Transform’s angle is authority.
---
---@param R entt.registry
---@param e entt.entity
---@return nil
function physics.use_transform_fixed_rotation(...) end

---
--- Let physics rotate the body; Transform copies body angle.
---
---@param R entt.registry
---@param e entt.entity
---@return nil
function physics.use_physics_free_rotation(...) end

---
--- Sets PhysicsSyncConfig.mode on the entity.
---
---@param R entt.registry
---@param e entt.entity
---@param mode integer|string
---@return nil
function physics.set_sync_mode(...) end

---
--- Returns PhysicsSyncConfig.mode (enum int).
---
---@param R entt.registry
---@param e entt.entity
---@return integer
function physics.get_sync_mode(...) end

---
--- Sets sensor state on all shapes owned by the entity.
---
---@param e entt.entity
---@param isSensor boolean
---@return nil
function physics.set_sensor(...) end

---
--- Sets PhysicsSyncConfig.rotMode on the entity.
---
---@param R entt.registry
---@param e entt.entity
---@param rot_mode integer|string
---@return nil
function physics.set_rotation_mode(...) end

---
--- Returns PhysicsSyncConfig.rotMode (enum int).
---
---@param R entt.registry
---@param e entt.entity
---@return integer
function physics.get_rotation_mode(...) end

---
--- Creates physics for an entity in the given world; supports signed inflate in pixels and optional world-ref set.
---
---@param R entt.registry
---@param PM PhysicsManager
---@param e entt.entity
---@param world string @ name of physics world
---@param cfg table @ {shape?:string, tag?:string, sensor?:boolean, density?:number, inflate_px?:number, set_world_ref?:boolean}
---@return nil
function physics.create_physics_for_transform(...) end

---
--- Registers a fluid config for a collision tag (density, drag).
---
---@param world physics.PhysicsWorld
---@param tag string
---@param density number
---@param drag number
---@return nil
function physics.register_fluid_volume(...) end

---
--- Adds an axis-aligned sensor box that uses the fluid config for 'tag'.
---
---@param world physics.PhysicsWorld
---@param left number
---@param bottom number
---@param right number
---@param top number
---@param tag string
---@return nil
function physics.add_fluid_sensor_aabb(...) end

---
--- Adds a static one-way platform segment. Entities pass from back side.
---
---@param world physics.PhysicsWorld
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param thickness number
---@param tag string|nil
---@param n {x:number,y:number}|nil @ platform outward normal (default {0,1})
---@return entt.entity
function physics.add_one_way_platform(...) end

---
--- When collision impulse exceeds threshold, creates temporary pivot joints between shapes.
---
---@param world physics.PhysicsWorld
---@param tagA string
---@param tagB string
---@param impulse_threshold number
---@param max_force number
---@return nil
function physics.enable_sticky_between(...) end

---
--- Stops glue creation for the pair.
---
---@param world physics.PhysicsWorld
---@param tagA string
---@param tagB string
---@return nil
function physics.disable_sticky_between(...) end

---
--- Creates a kinematic-friendly box with custom velocity update for platforming.
---
---@param world physics.PhysicsWorld
---@param pos {x:number,y:number}
---@param w number
---@param h number
---@param tag string
---@return entt.entity
function physics.create_platformer_player(...) end

---
--- Feeds input each frame to the platformer controller.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param move_x number @ [-1..1]
---@param jump_held boolean
---@return nil
function physics.set_platformer_input(...) end

---
--- Attaches a top-down controller (pivot constraint) to the entity's body.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param max_bias number
---@param max_force number
---@return nil
function physics.create_topdown_controller(...) end

---
--- Adds a kinematic control body + constraints; call command_tank_to() and update_tanks(dt).
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param drive_speed number|nil
---@param stop_radius number|nil
---@param pivot_max_force number|nil
---@param gear_max_force number|nil
---@param gear_max_bias number|nil
---@return nil
function physics.enable_tank_controller(...) end

---
--- Removes physics body and shapes from the entity; optionally removes PhysicsComponent too.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param remove_component boolean|nil
---@return nil
function physics.remove_physics(...) end

---
--- Sets the tank's target point.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param target {x:number,y:number}
---@return nil
function physics.command_tank_to(...) end

---
--- Updates all tank controllers for dt.
---
---@param world physics.PhysicsWorld
---@param dt number
---@return nil
function physics.update_tanks(...) end

---
--- Replaces velocity integration with inverse-square gravity toward a fixed point.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param point {x:number,y:number}
---@param GM number
---@return nil
function physics.enable_inverse_square_gravity_to_point(...) end

---
--- Inverse-square gravity toward another body's center.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param center entt.entity
---@param GM number
---@return nil
function physics.enable_inverse_square_gravity_to_body(...) end

---
--- Restores default velocity integration for the body.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@return nil
function physics.disable_custom_gravity(...) end

---
--- Creates a kinematic spinning circle body as a 'planet'.
---
---@param world physics.PhysicsWorld
---@param radius number
---@param spin number @ rad/s
---@param tag string|nil
---@param pos {x:number,y:number}|nil
---@return entt.entity
function physics.create_planet(...) end

---
--- Spawns a dynamic box with initial circular orbit and inverse-square gravity toward the center.
---
---@param world physics.PhysicsWorld
---@param start_pos {x:number,y:number}
---@param half_size number
---@param mass number
---@param GM number
---@param gravity_center {x:number,y:number}
---@return entt.entity
function physics.spawn_orbiting_box(...) end

---
--- Sets the satellite body's velocity for a circular orbit around the center body.
---
---@param world physics.PhysicsWorld
---@param satellite entt.entity
---@param center entt.entity
---@param GM number
---@return nil
function physics.set_circular_orbit_velocity(...) end

---
--- Closest segment hit with optional fat radius.
---
---@param world physics.PhysicsWorld
---@param start {x:number,y:number}
---@param finish {x:number,y:number}
---@param radius number|nil
---@return table @ {hit:boolean, shape:lightuserdata|nil, point={x,y}|nil, normal={x,y}|nil, alpha:number}
function physics.segment_query_first(...) end

---
--- Nearest shape to a point (distance < 0 means inside).
---
---@param world physics.PhysicsWorld
---@param p {x:number,y:number}
---@param max_distance number|nil
---@return table @ {hit:boolean, shape:lightuserdata|nil, point={x,y}|nil, distance:number|nil}
function physics.point_query_nearest(...) end

---
--- Voronoi-shatters the nearest polygon shape around (x,y).
---
---@param world physics.PhysicsWorld
---@param x number
---@param y number
---@param grid_div number|nil @ cells across AABB (>= 3 is sensible)
---@return boolean
function physics.shatter_nearest(...) end

---
--- Slices the first polygon hit by segment AB into two bodies (returns true if sliced).
---
---@param world physics.PhysicsWorld
---@param A {x:number,y:number}
---@param B {x:number,y:number}
---@param density number
---@param min_area number
---@return boolean
function physics.slice_first_hit(...) end

---
--- Adds a static chain of segments with smoothed neighbor normals.
---
---@param world physics.PhysicsWorld
---@param pts { {x:number,y:number}, ... }
---@param radius number
---@param tag string
---@return entt.entity
function physics.add_smooth_segment_chain(...) end

---
--- Creates a dynamic slender rod body with a segment collider.
---
---@param world physics.PhysicsWorld
---@param a {x:number,y:number}
---@param b {x:number,y:number}
---@param thickness number
---@param tag string
---@param group integer|nil @ same non-zero group never collide with each other
---@return entt.entity
function physics.add_bar_segment(...) end

---
--- Adds four static walls (segment shapes) as a box boundary.
---
---@param world physics.PhysicsWorld
---@param xMin number
---@param yMin number
---@param xMax number
---@param yMax number
---@param thickness number
---@param tag string
---@return nil
function physics.add_screen_bounds(...) end

---
--- Destroys entities with bodies completely outside the given AABB.
---
---@param world physics.PhysicsWorld
---@param xMin number
---@param yMin number
---@param xMax number
---@param yMax number
---@return nil
function physics.cull_entities_outside_bounds(...) end

---
--- Generates static segments following the outline of solid cells.
---
---@param world physics.PhysicsWorld
---@param grid boolean[][] @ grid[x][y]
---@param tile_size number
---@param segment_radius number
---@return nil
function physics.create_tilemap_colliders(...) end

---
--- Returns entities currently touching e (via arbiters).
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@return entt.entity[]
function physics.touching_entities(...) end

---
--- Sum of contact impulses / dt on the body this step.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param dt number
---@return number
function physics.total_force_on(...) end

---
--- Projection of force along gravity / |g| (i.e., perceived weight).
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param dt number
---@return number
function physics.weight_on(...) end

---
--- Crush metric ~ (sum|J| - |sum J|) * dt.
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param dt number
---@return table @ {touching_count:integer, crush:number}
function physics.crush_on(...) end

---
--- Begins dragging nearest body at (x,y).
---
---@param world physics.PhysicsWorld
---@param x number
---@param y number
---@return nil
function physics.start_mouse_drag(...) end

---
--- Updates mouse drag anchor.
---
---@param world physics.PhysicsWorld
---@param x number
---@param y number
---@return nil
function physics.update_mouse_drag(...) end

---
--- Ends mouse dragging.
---
---@param world physics.PhysicsWorld
---@return nil
function physics.end_mouse_drag(...) end

---
--- Adds a pin joint between two bodies (local anchors).
---
---@param world physics.PhysicsWorld
---@param ea entt.entity
---@param a_local {x:number,y:number}
---@param eb entt.entity
---@param b_local {x:number,y:number}
---@return lightuserdata @ cpConstraint*
function physics.add_pin_joint(...) end

---
--- Adds a slide joint.
---
---@param world physics.PhysicsWorld
---@param ea entt.entity
---@param a_local {x:number,y:number}
---@param eb entt.entity
---@param b_local {x:number,y:number}
---@param min_d number
---@param max_d number
---@return lightuserdata @ cpConstraint*
function physics.add_slide_joint(...) end

---
--- Adds a pivot joint defined in world space.
---
---@param world physics.PhysicsWorld
---@param ea entt.entity
---@param eb entt.entity
---@param world_anchor {x:number,y:number}
---@return lightuserdata @ cpConstraint*
function physics.add_pivot_joint_world(...) end

---
--- Adds a linear damped spring.
---
---@param world physics.PhysicsWorld
---@param ea entt.entity
---@param a_local {x:number,y:number}
---@param eb entt.entity
---@param b_local {x:number,y:number}
---@param rest number
---@param k number
---@param damping number
---@return lightuserdata @ cpConstraint*
function physics.add_damped_spring(...) end

---
--- Adds a rotary damped spring.
---
---@param world physics.PhysicsWorld
---@param ea entt.entity
---@param eb entt.entity
---@param rest_angle number
---@param k number
---@param damping number
---@return lightuserdata @ cpConstraint*
function physics.add_damped_rotary_spring(...) end

---
--- Convenience to set cpConstraint maxForce/maxBias (pass nil to keep).
---
---@param world physics.PhysicsWorld
---@param c lightuserdata @ cpConstraint*
---@param max_force number|nil
---@param max_bias number|nil
---@return nil
function physics.set_constraint_limits(...) end

---
--- Keeps a body upright (rotary spring to static body).
---
---@param world physics.PhysicsWorld
---@param e entt.entity
---@param stiffness number
---@param damping number
---@return nil
function physics.add_upright_spring(...) end

---
--- Creates a slide joint that breaks under force/fatigue.
---
---@param world physics.PhysicsWorld
---@param ea entt.entity
---@param eb entt.entity
---@param a_local {x:number,y:number}
---@param b_local {x:number,y:number}
---@param min_d number
---@param max_d number
---@param breaking_force number
---@param trigger_ratio number
---@param collide_bodies boolean
---@param use_fatigue boolean
---@param fatigue_rate number
---@return lightuserdata @ cpConstraint*
function physics.make_breakable_slide_joint(...) end

---
--- Attaches breakable behavior to an existing constraint.
---
---@param world physics.PhysicsWorld
---@param c lightuserdata @ cpConstraint*
---@param breaking_force number
---@param trigger_ratio number
---@param use_fatigue boolean
---@param fatigue_rate number
---@return nil
function physics.make_constraint_breakable(...) end

---
--- Groups bodies that collide with same-type contacts; when a group's count >= threshold, callback in C++ runs.
---
---@param world physics.PhysicsWorld
---@param min_type integer
---@param max_type integer
---@param threshold integer
---@return nil
function physics.enable_collision_grouping(...) end

---
--- The live PhysicsManager instance (userdata). Methods mirror the PhysicsManager table.
---
---@type PhysicsManagerUD
function physics_manager.instance(...) end

---
--- Sets the seed for deterministic random behavior.
---
---@param seed integer # The seed for the random number generator.
---@return nil
function random_utils.set_seed(...) end

---
--- Returns a random boolean value, with an optional probability.
---
---@param chance? number # Optional: A percentage chance (0-100) for the result to be true. Defaults to 50.
---@return boolean
function random_utils.random_bool(...) end

---
--- Returns a random float between min and max.
---
---@param min? number # The minimum value (inclusive). Defaults to 0.0.
---@param max? number # The maximum value (inclusive). Defaults to 1.0.
---@return number
function random_utils.random_float(...) end

---
--- Returns a random integer within a range.
---
---@param min? integer # The minimum value (inclusive). Defaults to 0.
---@param max? integer # The maximum value (inclusive). Defaults to 1.
---@return integer
function random_utils.random_int(...) end

---
--- Returns a float sampled from a normal (Gaussian) distribution.
---
---@param mean number # The mean of the distribution.
---@param stdev number # The standard deviation of the distribution.
---@return number
function random_utils.random_normal(...) end

---
--- Returns +1 or -1 randomly, with an optional probability.
---
---@param chance? number # Optional: A percentage chance (0-100) for the result to be +1. Defaults to 50.
---@return integer # Either +1 or -1.
function random_utils.random_sign(...) end

---
--- Generates a random unique integer ID.
---
---@return integer # A random unique integer ID.
function random_utils.random_uid(...) end

---
--- Returns a random angle in radians.
---
---@return number # A random angle in radians (0 to 2*pi).
function random_utils.random_angle(...) end

---
--- Returns a biased random float between 0 and 1.
---
---@param biasFactor number # A factor to skew the result. <1.0 favors higher values, >1.0 favors lower values.
---@return number
function random_utils.random_biased(...) end

---
--- Returns a random delay in milliseconds.
---
---@param minMs integer # The minimum delay in milliseconds.
---@param maxMs integer # The maximum delay in milliseconds.
---@return number
function random_utils.random_delay(...) end

---
--- Returns a random, normalized 2D vector.
---
---@return Vector2
function random_utils.random_unit_vector_2D(...) end

---
--- Returns a random, normalized 3D vector.
---
---@return Vector3
function random_utils.random_unit_vector_3D(...) end

---
--- Returns a randomly generated color.
---
---@return Color
function random_utils.random_color(...) end

---
--- Selects a random element from a table of integers.
---
---@param items integer[] # A table of integers.
---@return integer
function random_utils.random_element_int(...) end

---
--- Selects a random element from a table of numbers.
---
---@param items number[] # A table of numbers.
---@return number
function random_utils.random_element_double(...) end

---
--- Selects a random element from a table of strings.
---
---@param items string[] # A Lua table (array) of strings.
---@return string       # One random element from the list.
function random_utils.random_element_string(...) end

---
--- Selects a random element from a table of Colors.
---
---@param items Color[] # A table of Colors.
---@return Color
function random_utils.random_element_color(...) end

---
--- Selects a random element from a table of Vector2s.
---
---@param items Vector2[] # A table of Vector2s.
---@return Vector2
function random_utils.random_element_vec2(...) end

---
--- Selects a random element from a table of Entities.
---
---@param items Entity[] # A table of Entities.
---@return Entity
function random_utils.random_element_entity(...) end

---
--- Selects, removes, and returns a random element from a table of integers.
---
---@param items integer[] # The table to modify.
---@return integer
function random_utils.random_element_remove_int(...) end

---
--- Selects, removes, and returns a random element from a table of numbers.
---
---@param items number[] # The table to modify.
---@return number
function random_utils.random_element_remove_double(...) end

---
--- Selects, removes, and returns a random element from a table of strings.
---
---@param items string[] # The table to modify.
---@return string
function random_utils.random_element_remove_string(...) end

---
--- Selects, removes, and returns a random element from a table of Colors.
---
---@param items Color[] # The table to modify.
---@return Color
function random_utils.random_element_remove_color(...) end

---
--- Selects, removes, and returns a random element from a table of Vector2s.
---
---@param items Vector2[] # The table to modify.
---@return Vector2
function random_utils.random_element_remove_vec2(...) end

---
--- Selects, removes, and returns a random element from a table of Entities.
---
---@param items Entity[] # The table to modify.
---@return Entity
function random_utils.random_element_remove_entity(...) end

---
--- Performs a weighted random pick and returns the chosen index.
---
---@param weights number[] # A table of weights.
---@return integer # A 1-based index corresponding to the chosen weight.
function random_utils.random_weighted_pick_int(...) end

---
--- Performs a weighted random pick from a table of strings.
---
---@param values string[] # A table of string values.
---@param weights number[] # A table of corresponding weights.
---@return string
function random_utils.random_weighted_pick_string(...) end

---
--- Performs a weighted random pick from a table of Colors.
---
---@param values Color[] # A table of Color values.
---@param weights number[] # A table of corresponding weights.
---@return Color
function random_utils.random_weighted_pick_color(...) end

---
--- Performs a weighted random pick from a table of Vector2s.
---
---@param values Vector2[] # A table of Vector2 values.
---@param weights number[] # A table of corresponding weights.
---@return Vector2
function random_utils.random_weighted_pick_vec2(...) end

---
--- Performs a weighted random pick from a table of Entities.
---
---@param values Entity[] # A table of Entity values.
---@param weights number[] # A table of corresponding weights.
---@return Entity
function random_utils.random_weighted_pick_entity(...) end

---
--- Execute an entity's shader pipeline using draw command batching.
---
---@param registry Registry
---@param entity Entity
---@param batch DrawCommandBatch
---@param autoOptimize? boolean
---@return nil
function shader_draw_commands.executeEntityPipelineWithCommands(...) end

---
--- Unloads the pipeline's internal render textures.
---
---@return nil
function shader_pipeline.ShaderPipelineUnload(...) end

---
--- Initializes or re-initializes the pipeline's render textures to a new size.
---
---@param width integer
---@param height integer
---@return nil
function shader_pipeline.ShaderPipelineInit(...) end

---
--- Resizes the pipeline's render textures if the new dimensions are different.
---
---@param newWidth integer
---@param newHeight integer
---@return nil
function shader_pipeline.Resize(...) end

---
--- Clears the pipeline's internal textures to a specific color (defaults to transparent).
---
---@param color? Color
---@return nil
function shader_pipeline.ClearTextures(...) end

---
--- Draws the current 'front' render texture for debugging purposes.
---
---@param x? integer
---@param y? integer
---@return nil
function shader_pipeline.DebugDrawFront(...) end

---
--- Swaps the internal 'ping' and 'pong' render textures.
---
---@return nil
function shader_pipeline.Swap(...) end

---
--- Internal helper to track the last used render target.
---
---@param texture RenderTexture2D
---@return nil
function shader_pipeline.SetLastRenderTarget(...) end

---
--- Internal helper to retrieve the last used render target.
---
---@return RenderTexture2D|nil
function shader_pipeline.GetLastRenderTarget(...) end

---
--- Internal helper to track the last rendered rectangle area.
---
---@param rect Rectangle
---@return nil
function shader_pipeline.SetLastRenderRect(...) end

---
--- Internal helper to retrieve the last rendered rectangle area.
---
---@return Rectangle
function shader_pipeline.GetLastRenderRect(...) end

---
---
---@param src ShaderOverlayInputSource    # where the overlay samples from
---@param name string                      # your overlay’s name
---@param blend BlendMode?                 # optional blend mode (default BLEND_ALPHA)
---@return ShaderOverlayDraw               # the newly-added overlay draw
function shader_pipeline.ShaderPipelineComponent.addOverlay(...) end

---
--- Add a new pass at the end
---
---@param name string
---@return nil
function shader_pipeline.ShaderPipelineComponent.addPass(...) end

---
--- Remove a pass by name
---
---@param name string
---@return boolean
function shader_pipeline.ShaderPipelineComponent.removePass(...) end

---
--- Toggle a pass enabled/disabled
---
---@param name string
---@return boolean
function shader_pipeline.ShaderPipelineComponent.togglePass(...) end

---
--- Add a new overlay; blend mode is optional
---
---@param src OverlayInputSource
---@param name string
---@param blend? BlendMode
---@return nil
function shader_pipeline.ShaderPipelineComponent.addOverlay(...) end

---
--- Remove an overlay by name
---
---@param name string
---@return boolean
function shader_pipeline.ShaderPipelineComponent.removeOverlay(...) end

---
--- Toggle an overlay on/off
---
---@param name string
---@return boolean
function shader_pipeline.ShaderPipelineComponent.toggleOverlay(...) end

---
--- Clear both passes and overlays
---
---@return nil
function shader_pipeline.ShaderPipelineComponent.clearAll(...) end

---
--- Applies a set of uniforms to a specific shader instance.
---
---@param shader Shader
---@param uniforms shaders.ShaderUniformSet # A table of uniform names to values.
---@return nil
function shaders.ApplyUniformsToShader(...) end

---
--- Loads and compiles shaders from a JSON file.
---
---@param path string # Filepath to the JSON definition file.
---@return nil
function shaders.loadShadersFromJSON(...) end

---
--- Unloads all shaders, freeing their GPU resources.
---
---@return nil
function shaders.unloadShaders(...) end

---
--- Globally forces all shader effects off or on, overriding individual settings.
---
---@param disabled boolean # True to disable all shaders, false to re-enable them.
---@return nil
function shaders.disableAllShadersViaOverride(...) end

---
--- Checks all loaded shaders for changes on disk and reloads them if necessary.
---
---@return nil
function shaders.hotReloadShaders(...) end

---
--- Begins a full-screen shader mode, e.g., for post-processing effects.
---
---@param shaderName string # The name of the shader to begin as a full-screen effect.
---@return nil
function shaders.setShaderMode(...) end

---
--- Ends the current full-screen shader mode.
---
---@return nil
function shaders.unsetShaderMode(...) end

---
--- Retrieves a loaded shader by its unique name.
---
---@param name string # The unique name of the shader.
---@return Shader|nil # The shader object, or nil if not found.
function shaders.getShader(...) end

---
--- Registers a global callback to update a specific uniform's value across all shaders that use it.
---
---@param uniformName string # The uniform to target (e.g., 'time').
---@param callback fun():any # A function that returns the latest value for the uniform.
---@return nil
function shaders.registerUniformUpdate(...) end

---
--- Invokes all registered global uniform update callbacks immediately.
---
---@return nil
function shaders.updateAllShaderUniforms(...) end

---
--- Updates internal shader state, such as timers for built-in 'time' uniforms.
---
---@param dt number # Delta time since the last frame.
---@return nil
function shaders.updateShaders(...) end

---
--- Displays the ImGui-based shader editor window for real-time debugging and uniform tweaking.
---
---@return nil
function shaders.ShowShaderEditorUI(...) end

---
--- If the component has a uniform set registered under shaderName, applies those uniforms to shader
---

---@param shader Shader                    # The target Shader handle
---@param component ShaderUniformComponent # Holds named uniform‐sets
---@param shaderName string                 # Key of the uniform set to apply
---@return nil

function shaders.TryApplyUniforms(...) end

---
--- Attach and initialize a SteerableComponent with speed/force/turn caps.
---
---@param r entt.registry& @Registry reference
---@param e entt.entity
---@param maxSpeed number
---@param maxForce number
---@param maxTurnRate number @radians/sec (default 2π)
---@param turnMul number @turn responsiveness multiplier (default 2.0)
function steering.make_steerable(...) end

---
--- Seek a world point (Chipmunk coords) with adjustable deceleration and blend weight.
---
---@param r entt.registry&
---@param e entt.entity
---@param target {x:number,y:number}|(number,number)
---@param decel number @arrival deceleration factor
---@param weight number @blend weight
function steering.seek_point(...) end

---
--- Flee from a point if within panicDist (Chipmunk coords).
---
---@param r entt.registry&
---@param e entt.entity
---@param threat {x:number,y:number}
---@param panicDist number @only flee if within this distance
---@param weight number @blend weight
function steering.flee_point(...) end

---
--- Classic wander on a projected circle (Chipmunk/world coordinates).
---
---@param r entt.registry&
---@param e entt.entity
---@param jitter number @per-step target jitter
---@param radius number @wander circle radius
---@param distance number @circle forward distance
---@param weight number @blend weight
function steering.wander(...) end

---
--- Repulsive boids term; pushes away when too close.
---
---@param r entt.registry&
---@param e entt.entity
---@param separationRadius number
---@param neighbors entt.entity[] @Lua array/table of entities
---@param weight number @blend weight
function steering.separate(...) end

---
--- Boids alignment (match headings of nearby agents).
---
---@param r entt.registry&
---@param e entt.entity
---@param neighbors entt.entity[] @Lua array/table of entities
---@param alignRadius number
---@param weight number @blend weight
function steering.align(...) end

---
--- Boids cohesion (seek the local group center).
---
---@param r entt.registry&
---@param e entt.entity
---@param neighbors entt.entity[] @Lua array/table of entities
---@param cohesionRadius number
---@param weight number @blend weight
function steering.cohesion(...) end

---
--- Predict target future position and seek it (pursuit).
---
---@param r entt.registry&
---@param e entt.entity
---@param target entt.entity @entity to predict and chase
---@param weight number @blend weight
function steering.pursuit(...) end

---
--- Predict pursuer future position and flee it (evade).
---
---@param r entt.registry&
---@param e entt.entity
---@param pursuer entt.entity @entity to predict and flee from
---@param weight number @blend weight
function steering.evade(...) end

---
--- Define waypoints to follow and an arrival radius.
---
---@param r entt.registry&
---@param e entt.entity
---@param points { {x:number,y:number}, ... } @Lua array of waypoints (Chipmunk coords)
---@param arriveRadius number @advance when within this radius
function steering.set_path(...) end

---
--- Seek current waypoint; auto-advance when within arriveRadius.
---
---@param r entt.registry&
---@param e entt.entity
---@param decel number @arrival deceleration factor
---@param weight number @blend weight
function steering.path_follow(...) end

---
--- Apply a world-space force that linearly decays to zero over <seconds>.
---
---@param r entt.registry&
---@param e entt.entity
---@param f number @force magnitude (world units)
---@param radians number @direction in radians
---@param seconds number @duration seconds
function steering.apply_force(...) end

---
--- Apply a constant per-frame impulse (f / sec) for <seconds> in world space.
---
---@param r entt.registry&
---@param e entt.entity
---@param f number @impulse-per-second magnitude
---@param radians number @direction in radians
---@param seconds number @duration seconds
function steering.apply_impulse(...) end

---
--- Enqueues a telemetry event if telemetry is enabled.
---
---@param name string # Event name
---@param props table|nil # Key/value properties (string/number/bool)
---@return nil
function telemetry.record(...) end

---
--- Returns the current telemetry session id (generated on startup).
---
---@return string # Current session id
function telemetry.session_id(...) end

---
--- Install or replace a local render callback on an entity.
--- Positional overload.
---
---@param e Entity
---@param fn fun(width:number, height:number, isShadow:boolean)
---@param after boolean @ draw after shader pipeline if true
---@param width number  @ content width when no sprite drives size
---@param height number @ content height when no sprite drives size
---@return nil
function transform.install_local_callback(...) end

---
--- Install or replace a local render callback on an entity.
--- Table overload: (e, fn, { after?, width?, height? }).
---
---@param e Entity
---@param fn fun(width:number, height:number, isShadow:boolean)
---@param opts table|nil @ { after?:boolean=false, width?:number=64, height?:number=64 }
---@return nil
function transform.install_local_callback(...) end

---
--- Remove the installed local render callback for the entity (no-op if none).
---
---@param e Entity
---@return nil
function transform.remove_local_callback(...) end

---
--- Returns true if the entity has a local render callback.
---
---@param e Entity
---@return boolean
function transform.has_local_callback(...) end

---
--- Return info for the local render callback or nil if none.
---
---@param e Entity
---@return table|nil @ { width:number, height:number, after:boolean }
function transform.get_local_callback_info(...) end

---
--- Update content width/height used when no sprite dictates size.
---
---@param e Entity
---@param width number
---@param height number
---@return nil
function transform.set_local_callback_size(...) end

---
--- Toggle drawing after the shader pipeline (true) or before (false).
---
---@param e Entity
---@param after boolean
---@return nil
function transform.set_local_callback_after_pipeline(...) end

---
--- Returns 'world' or 'screen' depending on whether the entity has ScreenSpaceCollisionMarker.
---
---@param e Entity
---@return string @ 'world' | 'screen'
function transform.get_space(...) end

---
--- Returns true if entity has ScreenSpaceCollisionMarker (UI-space).
---
---@param e Entity
---@return boolean
function transform.is_screen_space(...) end

---
--- Sets entity space to 'world' or 'screen'. Optional third arg (convert_coords) is accepted but ignored.
---
---@param e Entity
---@param space string @ 'world' | 'screen'
---@param convert_coords? boolean @ currently ignored
---@return void
function transform.set_space(...) end

---
--- Initializes the transform system.
---
---@return nil
function transform.InitializeSystem(...) end

---
--- Updates all transforms in the registry.
---
---@param registry registry
---@param dt number
---@return nil
function transform.UpdateAllTransforms(...) end

---
--- Creates or emplaces an entity with core components.
---
---@param registry registry
---@param container Entity
---@param x number
---@param y number
---@param w number
---@param h number
---@param entityToEmplaceTo? Entity
---@return Entity
function transform.CreateOrEmplace(...) end

---
--- Creates a root container entity for the game world.
---
---@param registry registry
---@param x number
---@param y number
---@param w number
---@param h number
---@return Entity
function transform.CreateGameWorldContainerEntity(...) end

---
--- Updates spring smoothing factors for a transform.
---
---@param registry registry
---@param e Entity
---@param dt number
---@return nil
function transform.UpdateTransformSmoothingFactors(...) end

---
--- Injects dynamic motion into a transform's springs.
---
---@param e Entity
---@param amount number
---@param rotationAmount number
---@return nil
function transform.InjectDynamicMotion(...) end

---
--- Injects default dynamic motion into a transform's springs.
---
---@param e Entity
---@return nil
function transform.InjectDynamicMotionDefault(...) end

---
--- Aligns an entity to its master.
---
---@param registry registry
---@param e Entity
---@param force? boolean
---@return nil
function transform.AlignToMaster(...) end

---
--- Assigns an inherited properties role to an entity.
---
---@param registry registry
---@param e Entity
---@param roleType? InheritedPropertiesType
---@param parent? Entity
---@param xy? InheritedPropertiesSync
---@param wh? InheritedPropertiesSync
---@param rotation? InheritedPropertiesSync
---@param scale? InheritedPropertiesSync
---@param offset? Vector2
---@return nil
function transform.AssignRole(...) end

---
--- Updates an entity's position based on its master's movement.
---
---@param e Entity
---@param dt number
---@param selfTransform Transform
---@param selfRole InheritedProperties
---@param selfNode GameObject
---@return nil
function transform.MoveWithMaster(...) end

---
--- Gets the master components for a given entity.
---
---@param e Entity
---@param selfT Transform
---@param selfR InheritedProperties
---@param selfN GameObject
---@return MasterCache, Transform|nil, InheritedProperties|nil
function transform.GetMaster(...) end

---
--- Instantly snaps an entity's transform to its master's.
---
---@param e Entity
---@param parent Entity
---@param selfT Transform
---@param selfR InheritedProperties
---@param parentT Transform
---@param parentR InheritedProperties
---@return nil
function transform.SyncPerfectlyToMaster(...) end

---
--- Configures all alignment and bonding properties for an entity.
---
---@param registry registry
---@param e Entity
---@param isChild boolean
---@param parent? Entity
---@param xy? InheritedPropertiesSync
---@param wh? InheritedPropertiesSync
---@param rotation? InheritedPropertiesSync
---@param scale? InheritedPropertiesSync
---@param alignment? AlignmentFlag
---@param offset? Vector2
---@return nil
function transform.ConfigureAlignment(...) end

---
--- Draws debug visuals for a transform.
---
---@param registry registry
---@param e Entity
---@param layer Layer
---@return nil
function transform.DrawBoundingBoxAndDebugInfo(...) end

---
--- Finds the top-most interactable entity at a screen point.
---
---@param point Vector2
---@return Entity|nil
function transform.FindTopEntityAtPoint(...) end

---
--- Finds all interactable entities at a screen point.
---
---@param point Vector2
---@return Entity[]
function transform.FindAllEntitiesAtPoint(...) end

---
--- Removes an entity and its children from the game.
---
---@param registry registry
---@param e Entity
---@return nil
function transform.RemoveEntity(...) end

---
--- Configures a jiggle animation on hover.
---
---@param registry registry
---@param e Entity
---@param jiggleAmount number
---@return nil
function transform.setJiggleOnHover(...) end

---
--- Handles alignment for an entire UI tree.
---
---@param registry registry
---@param root Entity
---@return nil
function ui.box.handleAlignment(...) end

---
--- Builds a UI tree from a template definition.
---
---@param registry registry
---@param uiBoxEntity Entity
---@param uiElementDef UIElementTemplateNode
---@param uiElementParent Entity
---@return nil
function ui.box.BuildUIElementTree(...) end

---
--- Sets the draw layer for a UI box.
---
---@param uiBox Entity
---@param name string
---@return nil
function ui.box.set_draw_layer(...) end

---
--- Assigns state tags to all elements in a UI box.
---
---@param registry registry
---@param uiBox Entity
---@param stateName string
---@return nil
function ui.box.AssignStateTagsToUIBox(...) end

---
--- Adds a state tag to all elements in a UI box.
---
---@param uiBox Entity
---@param tagToAdd string
---@return nil
function ui.box.AddStateTagToUIBox(...) end

---
--- Clears state tags from all elements in a UI box.
---
---@param uiBox Entity
---@return nil
function ui.box.ClearStateTagsFromUIBox(...) end

---
--- Initializes a new UI box from a definition.
---
---@param registry registry
---@param transformData table
---@param definition UIElementTemplateNode
---@param config? UIConfig
---@return Entity
function ui.box.Initialize(...) end

---
--- Recursively places UI elements within a layout.
---
---@param registry registry
---@param uiElement Entity
---@param runningTransform table
---@param parentType UITypeEnum
---@param parent Entity
---@return nil
function ui.box.placeUIElementsRecursively(...) end

---
--- Places a single non-container element within its parent.
---
---@param role InheritedProperties
---@param runningTransform table
---@param uiElement Entity
---@param parentType UITypeEnum
---@param uiState UIState
---@param uiConfig UIConfig
---@return nil
function ui.box.placeNonContainerUIE(...) end

---
--- Clamps the calculated transform dimensions to the configured minimums.
---
---@param uiConfig UIConfig
---@param calcTransform table
---@return nil
function ui.box.ClampDimensionsToMinimumsIfPresent(...) end

---
--- Calculates the sizes for an entire UI tree.
---
---@param registry registry
---@param uiElement Entity
---@param parentUINodeRect table
---@param forceRecalculateLayout? boolean
---@param scale? number
---@return number, number
function ui.box.CalcTreeSizes(...) end

---
--- Calculates the size for a non-container sub-element.
---
---@param registry registry
---@param uiElement Entity
---@param parentUINodeRect table
---@param forceRecalculateLayout boolean
---@param scale? number
---@param calcCurrentNodeTransform table
---@return Vector2
function ui.box.TreeCalcSubNonContainer(...) end

---
--- Renews the alignment for an entity.
---
---@param registry registry
---@param self Entity
---@return nil
function ui.box.RenewAlignment(...) end

---
--- Adds a template definition to a UI box.
---
---@param registry registry
---@param uiBoxEntity Entity
---@param templateDef UIElementTemplateNode
---@param maybeParent Entity|nil
---@return nil
function ui.box.AddTemplateToUIBox(...) end

---
--- Calculates the size for a container sub-element.
---
---@param registry registry
---@param uiElement Entity
---@param parentUINodeRect table
---@param forceRecalculateLayout boolean
---@param scale? number
---@param calcCurrentNodeTransform table
---@param contentSizes table
---@return Vector2
function ui.box.TreeCalcSubContainer(...) end

---
--- Sub-routine for calculating a container's size based on its children.
---
---@param calcCurrentNodeTransform table
---@param parentUINodeRect table
---@param uiConfig UIConfig
---@param calcChildTransform table
---@param padding number
---@param node GameObject
---@param registry registry
---@param factor number
---@param contentSizes table
---@return nil
function ui.box.SubCalculateContainerSize(...) end

---
--- Gets a UI element by its ID, searching from a specific node.
---
---@param registry registry
---@param node Entity
---@param id string
---@return Entity|nil
function ui.box.GetUIEByID(...) end

---
--- Gets a UI element by its ID, searching globally.
---

---@param registry registry
---@param id string
---@return Entity|nil

function ui.box.GetUIEByID(...) end

---
--- Removes all UI elements belonging to a specific group.
---
---@param registry registry
---@param entity Entity
---@param group string
---@return boolean
function ui.box.RemoveGroup(...) end

---
--- Gets all UI elements belonging to a specific group.
---
---@param registry registry
---@param entity Entity
---@param group string
---@return Entity[]
function ui.box.GetGroup(...) end

---
--- Removes a UI box and all its elements.
---
---@param registry registry
---@param entity Entity
---@return nil
function ui.box.Remove(...) end

---
--- Forces a full recalculation of a UI box's layout.
---
---@param registry registry
---@param entity Entity
---@return nil
function ui.box.Recalculate(...) end

---
--- Assigns tree order components for collision and input processing.
---
---@param registry registry
---@param rootUIElement Entity
---@return nil
function ui.box.AssignTreeOrderComponents(...) end

---
--- Assigns layer order components for drawing.
---
---@param registry registry
---@param uiBox Entity
---@return nil
function ui.box.AssignLayerOrderComponents(...) end

---
--- Updates the movement and spring physics for a UI box.
---
---@param registry registry
---@param self Entity
---@param dt number
---@return nil
function ui.box.Move(...) end

---
--- Handles dragging logic for a UI box.
---
---@param registry registry
---@param self Entity
---@param offset Vector2
---@param dt number
---@return nil
function ui.box.Drag(...) end

---
--- Adds a new child element to a UI box or container.
---
---@param registry registry
---@param uiBox Entity
---@param uiElementDef UIElementTemplateNode
---@param parent Entity
---@return nil
function ui.box.AddChild(...) end

---
--- Sets the container for a UI box.
---
---@param registry registry
---@param self Entity
---@param container Entity
---@return nil
function ui.box.SetContainer(...) end

---
--- Returns a string representation of the UI box tree for debugging.
---
---@param registry registry
---@param self Entity
---@param indent? integer
---@return string
function ui.box.DebugPrint(...) end

---
--- Traverses the UI tree from the leaves up to the root, calling the visitor function on each element.
---
---@param registry registry
---@param rootUIElement Entity
---@param visitor fun(entity: Entity)
---@return nil
function ui.box.TraverseUITreeBottomUp(...) end

---
--- Draws all UI boxes in the registry.
---
---@param registry registry
---@param layerPtr Layer
---@return nil
function ui.box.drawAllBoxes(...) end

---
--- Builds a sorted list of all drawable elements within a UI box.
---
---@param registry registry
---@param boxEntity Entity
---@param out_list table
---@return nil
function ui.box.buildUIBoxDrawList(...) end

---
--- Clamps the calculated transform dimensions to the configured minimums.
---
---@param uiConfig UIConfig
---@param calcTransform table
---@return nil
function ui.box.ClampDimensionsToMinimumsIfPresent(...) end

---
--- Create a static text‐entry node, with optional entity/component/value refs.
---

---@overload fun(text:string):UIElementTemplateNode
---@overload fun(text:string, refEntity:Entity):UIElementTemplateNode
---@overload fun(text:string, refEntity:Entity, refComponent:string):UIElementTemplateNode
---@param text string
---@param refEntity? Entity
---@param refComponent? string
---@param refValue? string
---@return UIElementTemplateNode

function ui.definitions.getNewTextEntry(...) end

---
--- Create a text‐entry node with dynamic effects (wrapping, pulse, etc.) and optional refs.
---

---@param localizedStringGetter fun(langCode:string):string
---@param fontSize number
---@param textEffect? string
---@param updateOnLanguageChange? boolean, defaults to true
---@param wrapWidth? number
---@param refEntity? Entity
---@param refComponent? string
---@param refValue? string
---@return UIElementTemplateNode

function ui.definitions.getNewDynamicTextEntry(...) end

---
--- Wrap a raw string into a UI text node.
---
---@param text string
---@return UIElementTemplateNode
function ui.definitions.getTextFromString(...) end

---
--- Embed text between divider markers (for code‐style blocks).
---
---@param text string
---@param divider string
---@return UIElementTemplateNode
function ui.definitions.putCodedTextBetweenDividers(...) end

---
--- Turn an existing entity into a UI object‐element node.
---
---@param entity Entity
---@return UIElementTemplateNode
function ui.definitions.wrapEntityInsideObjectElement(...) end

---
--- Initializes a new UI element.
---
---@param registry registry
---@param parent Entity
---@param uiBox Entity
---@param type UITypeEnum
---@param config? UIConfig
---@return Entity
function ui.element.Initialize(...) end

---
--- Applies a scaling factor to all elements in a UI subtree.
---
---@param registry registry
---@param rootEntity Entity
---@param scaling number
---@return nil
function ui.element.ApplyScalingToSubtree(...) end

---
--- Updates the scaling of a UI object and recenters it.
---
---@param uiConfig UIConfig
---@param newScale number
---@param transform Transform
---@return nil
function ui.element.UpdateUIObjectScalingAndRecenter(...) end

---
--- Sets local transform values for a UI element.
---
---@param registry registry
---@param entity Entity
---@param _T table
---@param recalculate boolean
---@return nil
function ui.element.SetValues(...) end

---
--- Returns a string representation of the UI tree for debugging.
---
---@param registry registry
---@param entity Entity
---@param indent integer
---@return string
function ui.element.DebugPrintTree(...) end

---
--- Initializes the visual transform properties (e.g., springs) for an element.
---
---@param registry registry
---@param entity Entity
---@return nil
function ui.element.InitializeVisualTransform(...) end

---
--- Applies a 'juice' animation (dynamic motion) to an element.
---
---@param registry registry
---@param entity Entity
---@param amount number
---@param rot_amt number
---@return nil
function ui.element.JuiceUp(...) end

---
--- Checks if the element can be dragged and returns the draggable entity if so.
---
---@param registry registry
---@param entity Entity
---@return Entity|nil
function ui.element.CanBeDragged(...) end

---
--- Sets the width and height of an element based on its content and configuration.
---
---@param registry registry
---@param entity Entity
---@return number, number
function ui.element.SetWH(...) end

---
--- Applies alignment logic to position an element.
---
---@param registry registry
---@param entity Entity
---@param x number
---@param y number
---@return nil
function ui.element.ApplyAlignment(...) end

---
--- Sets all alignments for an element within its UI box.
---
---@param registry registry
---@param entity Entity
---@param uiBoxOffset? Vector2
---@param rootEntity? boolean
---@return nil
function ui.element.SetAlignments(...) end

---
--- Updates the text content and drawable for a text element.
---
---@param registry registry
---@param entity Entity
---@param config UIConfig
---@param state UIState
---@return nil
function ui.element.UpdateText(...) end

---
--- Updates a UI element that represents a game object.
---
---@param registry registry
---@param entity Entity
---@param elementConfig UIConfig
---@param elementNode GameObject
---@param objectConfig UIConfig
---@param objTransform Transform
---@param objectRole InheritedProperties
---@param objectNode GameObject
---@return nil
function ui.element.UpdateObject(...) end

---
--- Draws a single UI element.
---
---@param layerPtr Layer
---@param entity Entity
---@param uiElementComp UIElementComponent
---@param configComp UIConfig
---@param stateComp UIState
---@param nodeComp GameObject
---@param transformComp Transform
---@param zIndex? integer
---@return nil
function ui.element.DrawSelf(...) end

---
--- Performs a full update cycle for a UI element.
---
---@param registry registry
---@param entity Entity
---@param dt number
---@param uiConfig UIConfig
---@param transform Transform
---@param uiElement UIElementComponent
---@param node GameObject
---@return nil
function ui.element.Update(...) end

---
--- Checks if a UI element collides with a given point.
---
---@param registry registry
---@param entity Entity
---@param cursorPosition Vector2
---@return boolean
function ui.element.CollidesWithPoint(...) end

---
--- Gets the ideal position for a cursor when focusing this element.
---
---@param registry registry
---@param entity Entity
---@return Vector2
function ui.element.PutFocusedCursor(...) end

---
--- Removes a UI element and its children.
---
---@param registry registry
---@param entity Entity
---@return nil
function ui.element.Remove(...) end

---
--- Triggers a click event on a UI element.
---
---@param registry registry
---@param entity Entity
---@return nil
function ui.element.Click(...) end

---
--- Triggers a release event on a UI element.
---
---@param registry registry
---@param entity Entity
---@param objectBeingDragged Entity
---@return nil
function ui.element.Release(...) end

---
--- Applies hover state and effects to a UI element.
---
---@param registry registry
---@param entity Entity
---@return nil
function ui.element.ApplyHover(...) end

---
--- Removes hover state and effects from a UI element.
---
---@param registry registry
---@param entity Entity
---@return nil
function ui.element.StopHover(...) end

---
--- Populates a table with a sorted list of UI entities to be drawn.
---
---@param registry registry
---@param root Entity
---@param out_list table
---@return nil
function ui.element.BuildUIDrawList(...) end

---
--- Build an id→entity map starting at root, using transform::GameObject.orderedChildren by default.
---

---@param root Entity
---@return TextUIHandle

function ui.text.buildIdMapDefault(...) end

---
--- Fetch an entity by id (O(1)).
---
---@param handle TextUIHandle
---@param id string
---@return Entity|nil
function ui.text.getNode(...) end

---
--- Return all ids in the handle.
---
---@param handle TextUIHandle
---@return string[]
function ui.text.keys(...) end

---
--- Number of ids.
---
---@param handle TextUIHandle
---@return integer
function ui.text.size(...) end

---
--- Convenience: set UIConfig.color by id.
---

---@param handle TextUIHandle
---@param id string
---@param colorName string
---@return boolean  -- false if id/entity not found

function ui.text.setColor(...) end

---
--- Parse and log segment/wrapper ids for a raw text string.
---
---@param text string
---@return nil
function ui.text.debugDumpIdsFromString(...) end

---
--- Constructs a raw asset path without a UUID.
---
---@param assetName string # The name of the asset.
---@return string
function util.getRawAssetPathNoUUID(...) end

---
--- Retrieves a pre-defined Color object by its name.
---
---@param colorName string # The name of the color (e.g., "red").
---@return Color
function util.getColor(...) end

---
--- Gets the UUID version of an asset path.
---
---@param path_uuid_or_raw_identifier string # The asset identifier.
---@return string
function util.getAssetPathUUIDVersion(...) end

---
--- Converts a Raylib Color to an ImGui ImVec4.
---
---@param c Color # The Raylib Color object.
---@return ImVec4
function util.raylibColorToImVec(...) end

---
--- Returns a random synonym for the given word.
---
---@param word string # The word to find a synonym for.
---@return string
function util.getRandomSynonymFor(...) end

---
--- Converts a string to its unsigned char representation.
---
---@param value string # The string to convert.
---@return integer
function util.toUnsignedChar(...) end

