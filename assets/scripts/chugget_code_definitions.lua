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
--- Plays a music track.
---
---@param musicName string # The name of the music track to play.
---@param loop? boolean # If the music should loop. Defaults to false.
---@return nil
function playMusic(...) end

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
---@param message string # The error message.
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
--- Adds or replaces a StateTag component on the specified entity.
---
---@param entity Entity             # The entity to tag
---@param name string               # The name of the state tag
---@return nil
function add_state_tag(...) end

---
--- Removes the StateTag component from the specified entity.
---
---@param entity Entity             # The entity from which to remove its state tag
---@return nil
function remove_state_tag(...) end

---
--- Clears any and all StateTag components from the specified entity.
---
---@param entity Entity             # The entity whose state tags you want to clear
---@return nil
function clear_state_tags(...) end


---
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
---@overload fun---@overload fun(component_type: ComponentType):void
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
    id = nil, -- nil Entity: (Read-only) The entity handle this script is attached to. Injected by the system.
    owner = nil, -- nil registry: (Read-only) A reference to the C++ registry. Injected by the system.
    init = nil, -- nil function(): Optional function called once when the script is attached to an entity.
    update = nil, -- nil function(dt: number): Function called every frame.
    destroy = nil, -- nil function(): Optional function called just before the entity is destroyed.
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
---
---@class ai
ai = {
}

---
--- This is useful for debugging or when you want to temporarily halt AI processing.
---
Pauses the AI system, preventing any updates or actions from being processed.
function ai:pause_ai_system(...) end

---
--- This allows the AI system to continue processing updates and actions.
---
Resumes the AI system after it has been paused.
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
--- Returns a reference to the entity’s Blackboard component.
---
---@param e Entity
---@return Blackboard
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
- category = which tag-bits this collider *is*
- mask     = which category-bits this collider *collides with*
Default ctor sets both to 0xFFFFFFFF (collide with everything).
---
---@class CollisionFilter
CollisionFilter = {
    category = uint32,  -- Bitmask: what this entity *is* (e.g. Player, Enemy, Projectile).
    mask = uint32  -- Bitmask: which categories this entity *collides* with.
}


---
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
---
---@class Vector2
Vector2 = {
    x = number,  -- X component
    y = number  -- Y component
}


---
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
    shaderName = nil, -- string Name of the shader to use for this pass
    injectAtlasUniforms = nil, -- bool Whether to inject atlas UV uniforms into this pass
    enabled = nil, -- bool Whether this shader pass is enabled
    customPrePassFunction = nil, -- fun() Function to run before activating this pass
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
    inputSource = nil, -- OverlayInputSource Where to sample input from
    shaderName = nil, -- string Name of the overlay shader
    customPrePassFunction = nil, -- fun() Function to run before this overlay
    blendMode = nil, -- BlendMode Blend mode for this overlay
    enabled = nil, -- bool Whether this overlay is enabled
}


---
--- Holds a sequence of shader passes and overlays for full-scene rendering.
---
---@class shader_pipeline.ShaderPipelineComponent
shader_pipeline.ShaderPipelineComponent = {
    passes = nil, -- std::vector<ShaderPass> Ordered list of shader passes
    overlayDraws = nil, -- std::vector<ShaderOverlayDraw> Ordered list of overlays
    padding = nil, -- float Safe-area padding around overlays
}


---
--- Random number generation utilities and helper functions
---
---@class random_utils
random_utils = {
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
    zIndex = nil, -- integer Z sort order
}


---
--- Represents a drawing layer and its properties.
---
---@class layer.Layer
layer.Layer = {
    canvases = nil, -- table Map of canvas names to textures
    drawCommands = nil, -- table Command list
    fixed = nil, -- boolean Whether layer is fixed
    zIndex = nil, -- integer Z-index
    backgroundColor = nil, -- Color Background fill color
    commands = nil, -- table Draw commands list
    isSorted = nil, -- boolean True if layer is sorted
    postProcessShaders = nil, -- vector List of post-process shaders to run after drawing
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
    DrawTriangle = 45  -- Draw a triangle
}


---
--- 
---
---@class layer.CmdBeginDrawing
layer.CmdBeginDrawing = {
    dummy = nil, -- false Unused field
}


---
--- 
---
---@class layer.CmdEndDrawing
layer.CmdEndDrawing = {
    dummy = nil, -- false Unused field
}


---
--- 
---
---@class layer.CmdClearBackground
layer.CmdClearBackground = {
    color = nil, -- Color Background color
}


---
--- 
---
---@class layer.CmdBeginScissorMode
layer.CmdBeginScissorMode = {
    area = nil, -- Rectangle Scissor area rectangle
}


---
--- 
---
---@class layer.CmdEndScissorMode
layer.CmdEndScissorMode = {
    dummy = nil, -- false Unused field
}


---
--- 
---
---@class layer.CmdTranslate
layer.CmdTranslate = {
    x = nil, -- number X offset
    y = nil, -- number Y offset
}


---
--- 
---
---@class layer.CmdBeginStencilMode
layer.CmdBeginStencilMode = {
    dummy = nil, -- false Unused field
}


---
--- 
---
---@class layer.CmdEndStencilMode
layer.CmdEndStencilMode = {
    dummy = nil, -- false Unused field
}


---
--- 
---
---@class layer.CmdClearStencilBuffer
layer.CmdClearStencilBuffer = {
    dummy = nil, -- false Unused field
}


---
--- 
---
---@class layer.CmdBeginStencilMask
layer.CmdBeginStencilMask = {
    dummy = nil, -- false Unused field
}


---
--- 
---
---@class layer.CmdEndStencilMask
layer.CmdEndStencilMask = {
    dummy = nil, -- false Unused field
}


---
--- 
---
---@class layer.CmdDrawCenteredEllipse
layer.CmdDrawCenteredEllipse = {
    x = nil, -- number Center X
    y = nil, -- number Center Y
    rx = nil, -- number Radius X
    ry = nil, -- number Radius Y
    color = nil, -- Color Ellipse color
    lineWidth = nil, -- number|nil Line width for outline; nil for filled
}


---
--- 
---
---@class layer.CmdDrawRoundedLine
layer.CmdDrawRoundedLine = {
    x1 = nil, -- number Start X
    y1 = nil, -- number Start Y
    x2 = nil, -- number End X
    y2 = nil, -- number End Y
    color = nil, -- Color Line color
    lineWidth = nil, -- number Line width
}


---
--- 
---
---@class layer.CmdDrawPolyline
layer.CmdDrawPolyline = {
    points = nil, -- Vector2[] List of points
    color = nil, -- Color Line color
    lineWidth = nil, -- number Line width
}


---
--- 
---
---@class layer.CmdDrawArc
layer.CmdDrawArc = {
    type = nil, -- string Arc type (e.g., 'OPEN', 'CHORD', 'PIE')
    x = nil, -- number Center X
    y = nil, -- number Center Y
    r = nil, -- number Radius
    r1 = nil, -- number Inner radius (for ring arcs)
    r2 = nil, -- number Outer radius (for ring arcs)
    color = nil, -- Color Arc color
    lineWidth = nil, -- number Line width
    segments = nil, -- number Number of segments
}


---
--- 
---
---@class layer.CmdDrawTriangleEquilateral
layer.CmdDrawTriangleEquilateral = {
    x = nil, -- number Center X
    y = nil, -- number Center Y
    w = nil, -- number Width of the triangle
    color = nil, -- Color Triangle color
    lineWidth = nil, -- number|nil Line width for outline; nil for filled
}


---
--- 
---
---@class layer.CmdDrawCenteredFilledRoundedRect
layer.CmdDrawCenteredFilledRoundedRect = {
    x = nil, -- number Center X
    y = nil, -- number Center Y
    w = nil, -- number Width
    h = nil, -- number Height
    rx = nil, -- number|nil Corner radius X; nil for default
    ry = nil, -- number|nil Corner radius Y; nil for default
    color = nil, -- Color Fill color
    lineWidth = nil, -- number|nil Line width for outline; nil for filled
}


---
--- 
---
---@class layer.CmdDrawSpriteCentered
layer.CmdDrawSpriteCentered = {
    spriteName = nil, -- string Name of the sprite
    x = nil, -- number Center X
    y = nil, -- number Center Y
    dstW = nil, -- number|nil Destination width; nil for original width
    dstH = nil, -- number|nil Destination height; nil for original height
    tint = nil, -- Color Tint color
}


---
--- 
---
---@class layer.CmdDrawSpriteTopLeft
layer.CmdDrawSpriteTopLeft = {
    spriteName = nil, -- string Name of the sprite
    x = nil, -- number Top-left X
    y = nil, -- number Top-left Y
    dstW = nil, -- number|nil Destination width; nil for original width
    dstH = nil, -- number|nil Destination height; nil for original height
    tint = nil, -- Color Tint color
}


---
--- 
---
---@class layer.CmdDrawDashedCircle
layer.CmdDrawDashedCircle = {
    center = nil, -- Vector2 Center position
    radius = nil, -- number Radius
    dashLength = nil, -- number Length of each dash
    gapLength = nil, -- number Length of gap between dashes
    phase = nil, -- number Phase offset for dashes
    segments = nil, -- number Number of segments to approximate the circle
    thickness = nil, -- number Thickness of the dashes
    color = nil, -- Color Color of the dashes
}


---
--- 
---
---@class layer.CmdDrawDashedRoundedRect
layer.CmdDrawDashedRoundedRect = {
    rec = nil, -- Rectangle Rectangle area
    dashLen = nil, -- number Length of each dash
    gapLen = nil, -- number Length of gap between dashes
    phase = nil, -- number Phase offset for dashes
    radius = nil, -- number Corner radius
    arcSteps = nil, -- number Number of segments for corner arcs
    thickness = nil, -- number Thickness of the dashes
    color = nil, -- Color Color of the dashes
}


---
--- 
---
---@class layer.CmdDrawDashedLine
layer.CmdDrawDashedLine = {
    start = nil, -- Vector2 Start position
    end = nil, -- Vector2 End position
    dashLength = nil, -- number Length of each dash
    gapLength = nil, -- number Length of gap between dashes
    phase = nil, -- number Phase offset for dashes
    thickness = nil, -- number Thickness of the dashes
    color = nil, -- Color Color of the dashes
    x1 = nil, -- number Start X
    y1 = nil, -- number Start Y
    x2 = nil, -- number End X
    y2 = nil, -- number End Y
    dashSize = nil, -- number Dash size
    gapSize = nil, -- number Gap size
    color = nil, -- Color Color
    lineWidth = nil, -- number Line width
}


---
--- 
---
---@class layer.CmdScale
layer.CmdScale = {
    scaleX = nil, -- number Scale in X
    scaleY = nil, -- number Scale in Y
}


---
--- 
---
---@class layer.CmdRotate
layer.CmdRotate = {
    angle = nil, -- number Rotation angle in degrees
}


---
--- 
---
---@class layer.CmdAddPush
layer.CmdAddPush = {
    camera = nil, -- table Camera parameters
}


---
--- 
---
---@class layer.CmdAddPop
layer.CmdAddPop = {
    dummy = nil, -- false Unused field
}


---
--- 
---
---@class layer.CmdPushMatrix
layer.CmdPushMatrix = {
    dummy = nil, -- false Unused field
}


---
--- 
---
---@class layer.CmdPopMatrix
layer.CmdPopMatrix = {
    dummy = nil, -- false Unused field
}


---
--- 
---
---@class layer.CmdDrawCircleFilled
layer.CmdDrawCircleFilled = {
    x = nil, -- number Center X
    y = nil, -- number Center Y
    radius = nil, -- number Radius
    color = nil, -- Color Fill color
}


---
--- 
---
---@class layer.CmdDrawCircleLine
layer.CmdDrawCircleLine = {
    x = nil, -- number Center X
    y = nil, -- number Center Y
    innerRadius = nil, -- number Inner radius
    outerRadius = nil, -- number Outer radius
    startAngle = nil, -- number Start angle in degrees
    endAngle = nil, -- number End angle in degrees
    segments = nil, -- number Number of segments
    color = nil, -- Color Line color
}


---
--- 
---
---@class layer.CmdDrawRectangle
layer.CmdDrawRectangle = {
    x = nil, -- number Top-left X
    y = nil, -- number Top-left Y
    width = nil, -- number Width
    height = nil, -- number Height
    color = nil, -- Color Fill color
    lineWidth = nil, -- number Line width
}


---
--- 
---
---@class layer.CmdDrawRectanglePro
layer.CmdDrawRectanglePro = {
    offsetX = nil, -- number Offset X
    offsetY = nil, -- number Offset Y
    size = nil, -- Vector2 Size
    rotationCenter = nil, -- Vector2 Rotation center
    rotation = nil, -- number Rotation
    color = nil, -- Color Color
}


---
--- 
---
---@class layer.CmdDrawRectangleLinesPro
layer.CmdDrawRectangleLinesPro = {
    offsetX = nil, -- number Offset X
    offsetY = nil, -- number Offset Y
    size = nil, -- Vector2 Size
    lineThickness = nil, -- number Line thickness
    color = nil, -- Color Color
}


---
--- 
---
---@class layer.CmdDrawLine
layer.CmdDrawLine = {
    x1 = nil, -- number Start X
    y1 = nil, -- number Start Y
    x2 = nil, -- number End X
    y2 = nil, -- number End Y
    color = nil, -- Color Line color
    lineWidth = nil, -- number Line width
}


---
--- 
---
---@class layer.CmdDrawDashedLine
layer.CmdDrawDashedLine = {
}


---
--- 
---
---@class layer.CmdDrawText
layer.CmdDrawText = {
    text = nil, -- string Text
    font = nil, -- Font Font
    x = nil, -- number X
    y = nil, -- number Y
    color = nil, -- Color Color
    fontSize = nil, -- number Font size
}


---
--- 
---
---@class layer.CmdDrawTextCentered
layer.CmdDrawTextCentered = {
    text = nil, -- string Text
    font = nil, -- Font Font
    x = nil, -- number X
    y = nil, -- number Y
    color = nil, -- Color Color
    fontSize = nil, -- number Font size
}


---
--- 
---
---@class layer.CmdTextPro
layer.CmdTextPro = {
    text = nil, -- string Text
    font = nil, -- Font Font
    x = nil, -- number X
    y = nil, -- number Y
    origin = nil, -- Vector2 Origin
    rotation = nil, -- number Rotation
    fontSize = nil, -- number Font size
    spacing = nil, -- number Spacing
    color = nil, -- Color Color
}


---
--- 
---
---@class layer.CmdDrawImage
layer.CmdDrawImage = {
    image = nil, -- Texture2D Image
    x = nil, -- number X
    y = nil, -- number Y
    rotation = nil, -- number Rotation
    scaleX = nil, -- number Scale X
    scaleY = nil, -- number Scale Y
    color = nil, -- Color Tint color
}


---
--- 
---
---@class layer.CmdTexturePro
layer.CmdTexturePro = {
    texture = nil, -- Texture2D Texture
    source = nil, -- Rectangle Source rect
    offsetX = nil, -- number Offset X
    offsetY = nil, -- number Offset Y
    size = nil, -- Vector2 Size
    rotationCenter = nil, -- Vector2 Rotation center
    rotation = nil, -- number Rotation
    color = nil, -- Color Color
}


---
--- 
---
---@class layer.CmdDrawEntityAnimation
layer.CmdDrawEntityAnimation = {
    e = nil, -- Entity entt::entity
    registry = nil, -- Registry EnTT registry
    x = nil, -- number X
    y = nil, -- number Y
}


---
--- 
---
---@class layer.CmdDrawTransformEntityAnimation
layer.CmdDrawTransformEntityAnimation = {
    e = nil, -- Entity entt::entity
    registry = nil, -- Registry EnTT registry
}


---
--- 
---
---@class layer.CmdDrawTransformEntityAnimationPipeline
layer.CmdDrawTransformEntityAnimationPipeline = {
    e = nil, -- Entity entt::entity
    registry = nil, -- Registry EnTT registry
}


---
--- 
---
---@class layer.CmdSetShader
layer.CmdSetShader = {
    shader = nil, -- Shader Shader object
}


---
--- 
---
---@class layer.CmdResetShader
layer.CmdResetShader = {
}


---
--- 
---
---@class layer.CmdSetBlendMode
layer.CmdSetBlendMode = {
    blendMode = nil, -- number Blend mode
}


---
--- 
---
---@class layer.CmdUnsetBlendMode
layer.CmdUnsetBlendMode = {
    dummy = nil, -- false Unused field
}


---
--- 
---
---@class layer.CmdSendUniformFloat
layer.CmdSendUniformFloat = {
    shader = nil, -- Shader Shader
    uniform = nil, -- string Uniform name
    value = nil, -- number Float value
}


---
--- 
---
---@class layer.CmdSendUniformInt
layer.CmdSendUniformInt = {
    shader = nil, -- Shader Shader
    uniform = nil, -- string Uniform name
    value = nil, -- number Int value
}


---
--- 
---
---@class layer.CmdSendUniformVec2
layer.CmdSendUniformVec2 = {
    shader = nil, -- Shader Shader
    uniform = nil, -- string Uniform name
    value = nil, -- Vector2 Vec2 value
}


---
--- 
---
---@class layer.CmdSendUniformVec3
layer.CmdSendUniformVec3 = {
    shader = nil, -- Shader Shader
    uniform = nil, -- string Uniform name
    value = nil, -- Vector3 Vec3 value
}


---
--- 
---
---@class layer.CmdSendUniformVec4
layer.CmdSendUniformVec4 = {
    shader = nil, -- Shader Shader
    uniform = nil, -- string Uniform name
    value = nil, -- Vector4 Vec4 value
}


---
--- 
---
---@class layer.CmdSendUniformFloatArray
layer.CmdSendUniformFloatArray = {
    shader = nil, -- Shader Shader
    uniform = nil, -- string Uniform name
    values = nil, -- table Float array
}


---
--- 
---
---@class layer.CmdSendUniformIntArray
layer.CmdSendUniformIntArray = {
    shader = nil, -- Shader Shader
    uniform = nil, -- string Uniform name
    values = nil, -- table Int array
}


---
--- 
---
---@class layer.CmdVertex
layer.CmdVertex = {
    v = nil, -- Vector3 Position
    color = nil, -- Color Vertex color
}


---
--- 
---
---@class layer.CmdBeginOpenGLMode
layer.CmdBeginOpenGLMode = {
    mode = nil, -- number GL mode enum
}


---
--- 
---
---@class layer.CmdEndOpenGLMode
layer.CmdEndOpenGLMode = {
    dummy = nil, -- false Unused field
}


---
--- 
---
---@class layer.CmdSetColor
layer.CmdSetColor = {
    color = nil, -- Color Draw color
}


---
--- 
---
---@class layer.CmdSetLineWidth
layer.CmdSetLineWidth = {
    lineWidth = nil, -- number Line width
}


---
--- 
---
---@class layer.CmdSetTexture
layer.CmdSetTexture = {
    texture = nil, -- Texture2D Texture to bind
}


---
--- 
---
---@class layer.CmdRenderRectVerticesFilledLayer
layer.CmdRenderRectVerticesFilledLayer = {
    outerRec = nil, -- Rectangle Outer rectangle
    progressOrFullBackground = nil, -- bool Mode
    cache = nil, -- table Vertex cache
    color = nil, -- Color Fill color
}


---
--- 
---
---@class layer.CmdRenderRectVerticesOutlineLayer
layer.CmdRenderRectVerticesOutlineLayer = {
    cache = nil, -- table Vertex cache
    color = nil, -- Color Outline color
    useFullVertices = nil, -- bool Use full vertices
}


---
--- 
---
---@class layer.CmdDrawPolygon
layer.CmdDrawPolygon = {
    vertices = nil, -- table Vertex array
    color = nil, -- Color Polygon color
    lineWidth = nil, -- number Line width
}


---
--- 
---
---@class layer.CmdRenderNPatchRect
layer.CmdRenderNPatchRect = {
    sourceTexture = nil, -- Texture2D Source texture
    info = nil, -- NPatchInfo Nine-patch info
    dest = nil, -- Rectangle Destination
    origin = nil, -- Vector2 Origin
    rotation = nil, -- number Rotation
    tint = nil, -- Color Tint color
}


---
--- 
---
---@class layer.CmdDrawTriangle
layer.CmdDrawTriangle = {
    p1 = nil, -- Vector2 Point 1
    p2 = nil, -- Vector2 Point 2
    p3 = nil, -- Vector2 Point 3
    color = nil, -- Color Triangle color
}


---
--- A single draw command with type, data payload, and z-order.
---
---@class layer.DrawCommandV2
layer.DrawCommandV2 = {
    type = nil, -- number The draw command type enum
    data = nil, -- any The actual command data (CmdX struct)
    z = nil, -- number Z-order depth value for sorting
}


---
--- 
---
---@class layer.DrawCommandSpace
layer.DrawCommandSpace = {
    Screen = nil, -- number Screen space draw commands
    World = nil, -- number World space draw commands
}


---
--- 
---
---@class command_buffer
command_buffer = {
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
--- namespace for localization functions
---
---@class localization
localization = {
}


---
--- A system for creating, managing, and updating timers.
---
---@class timer
timer = {
}


---
--- Mathematical utility functions for timers.
---
---@class timer.math
timer.math = {
}


---
--- Specifies the behavior of a timer.
---
---@class timer.TimerType
timer.TimerType = {
    RUN = 0,  -- Runs once immediately.
    AFTER = 1,  -- Runs once after a delay.
    COOLDOWN = 2,  -- A resettable one-shot timer.
    EVERY = 3,  -- Runs repeatedly at an interval.
    EVERY_STEP = 4,  -- Runs repeatedly every N frames.
    FOR = 5,  -- Runs every frame for a duration.
    TWEEN = 6  -- Interpolates a value over a duration.
}


---
--- A system for managing and processing sequential and timed events.
---
---@class EventQueueSystem
EventQueueSystem = {
}


---
--- Collection of easing functions for tweening.
---
---@class EventQueueSystem.EaseType
EventQueueSystem.EaseType = {
    LERP = 0,  -- Linear interpolation.
    ELASTIC_IN = 1,  -- Elastic in.
    ELASTIC_OUT = 2,  -- Elastic out.
    QUAD_IN = 3,  -- Quadratic in.
    QUAD_OUT = 4  -- Quadratic out.
}


---
--- Defines when an event in the queue should be triggered.
---
---@class EventQueueSystem.TriggerType
EventQueueSystem.TriggerType = {
    IMMEDIATE = 0,  -- Triggers immediately.
    AFTER = 1,  -- Triggers after a delay.
    BEFORE = 2,  -- Triggers before a delay.
    EASE = 3,  -- Triggers as part of an ease/tween.
    CONDITION = 4  -- Triggers when a condition is met.
}


---
--- Defines which clock an event timer uses.
---
---@class EventQueueSystem.TimerType
EventQueueSystem.TimerType = {
    REAL_TIME = 0,  -- Uses the real-world clock, unaffected by game pause.
    TOTAL_TIME_EXCLUDING_PAUSE = 1  -- Uses the game clock, which may be paused.
}


---
--- Data for an easing/tweening operation.
---
---@class EventQueueSystem.EaseData
EventQueueSystem.EaseData = {
    type = nil, -- EventQueueSystem.EaseType The easing function to use.
    startValue = nil, -- number The starting value of the tween.
    endValue = nil, -- number The ending value of the tween.
    startTime = nil, -- number The start time of the tween.
    endTime = nil, -- number The end time of the tween.
    setValueCallback = nil, -- fun(value:number) Callback to apply the tweened value.
    getValueCallback = nil, -- fun():number Callback to get the current value.
}


---
--- A condition that must be met for an event to trigger.
---
---@class EventQueueSystem.ConditionData
EventQueueSystem.ConditionData = {
    check = nil, -- fun():boolean A function that returns true when the condition is met.
}


---
--- A single event in the event queue.
---
---@class EventQueueSystem.Event
EventQueueSystem.Event = {
    eventTrigger = nil, -- EventQueueSystem.TriggerType When the event should trigger.
    blocksQueue = nil, -- boolean If true, no other events will process until this one completes.
    canBeBlocked = nil, -- boolean If true, this event can be blocked by another.
    complete = nil, -- boolean True if the event has finished processing.
    timerStarted = nil, -- boolean Internal flag for timed events.
    delaySeconds = nil, -- number The delay in seconds for 'AFTER' triggers.
    retainAfterCompletion = nil, -- boolean If true, the event remains in the queue after completion.
    createdWhilePaused = nil, -- boolean If true, the event was created while the game was paused.
    func = nil, -- function The callback function to execute.
    timerType = nil, -- EventQueueSystem.TimerType The clock type to use for this event's timer.
    time = nil, -- number Internal time tracking for the event.
    ease = nil, -- EventQueueSystem.EaseData Easing data for tweening events.
    condition = nil, -- EventQueueSystem.ConditionData Condition data for conditional events.
    tag = nil, -- string An optional tag for finding the event later.
    debugID = nil, -- string A debug identifier for the event.
    deleteNextCycleImmediately = nil, -- boolean If true, deletes the event on the next update cycle.
}


---
--- A builder for creating EaseData objects.
---
---@class EventQueueSystem.EaseDataBuilder
EventQueueSystem.EaseDataBuilder = {
}

---
--- Sets the ease type.
---
---@param type EventQueueSystem.EaseType
---@return EventQueueSystem.EaseDataBuilder
function EventQueueSystem.EaseDataBuilder:Type(...) end

---
--- Sets the starting value.
---
---@param value number
---@return EventQueueSystem.EaseDataBuilder
function EventQueueSystem.EaseDataBuilder:StartValue(...) end

---
--- Sets the ending value.
---
---@param value number
---@return EventQueueSystem.EaseDataBuilder
function EventQueueSystem.EaseDataBuilder:EndValue(...) end

---
--- Sets the start time.
---
---@param time number
---@return EventQueueSystem.EaseDataBuilder
function EventQueueSystem.EaseDataBuilder:StartTime(...) end

---
--- Sets the end time.
---
---@param time number
---@return EventQueueSystem.EaseDataBuilder
function EventQueueSystem.EaseDataBuilder:EndTime(...) end

---
--- Sets the 'set value' callback.
---
---@param cb fun(value:number)
---@return EventQueueSystem.EaseDataBuilder
function EventQueueSystem.EaseDataBuilder:SetCallback(...) end

---
--- Sets the 'get value' callback.
---
---@param cb fun():number
---@return EventQueueSystem.EaseDataBuilder
function EventQueueSystem.EaseDataBuilder:GetCallback(...) end

---
--- Builds the final EaseData object.
---
---@return EventQueueSystem.EaseData
function EventQueueSystem.EaseDataBuilder:Build(...) end


---
--- A builder for creating and queuing events.
---
---@class EventQueueSystem.EventBuilder
EventQueueSystem.EventBuilder = {
}

---
--- Sets the event trigger type.
---
---@param type EventQueueSystem.TriggerType
---@return EventQueueSystem.EventBuilder
function EventQueueSystem.EventBuilder:Trigger(...) end

---
--- Sets if the event blocks the queue.
---
---@param blocks boolean
---@return EventQueueSystem.EventBuilder
function EventQueueSystem.EventBuilder:BlocksQueue(...) end

---
--- Sets if the event can be blocked.
---
---@param can_be_blocked boolean
---@return EventQueueSystem.EventBuilder
function EventQueueSystem.EventBuilder:CanBeBlocked(...) end

---
--- Sets the delay for an 'AFTER' trigger.
---
---@param seconds number
---@return EventQueueSystem.EventBuilder
function EventQueueSystem.EventBuilder:Delay(...) end

---
--- Sets the main callback function.
---
---@param cb function
---@return EventQueueSystem.EventBuilder
function EventQueueSystem.EventBuilder:Func(...) end

---
--- Attaches ease data to the event.
---
---@param easeData EventQueueSystem.EaseData
---@return EventQueueSystem.EventBuilder
function EventQueueSystem.EventBuilder:Ease(...) end

---
--- Attaches a condition to the event.
---
---@param condData EventQueueSystem.ConditionData
---@return EventQueueSystem.EventBuilder
function EventQueueSystem.EventBuilder:Condition(...) end

---
--- Assigns a string tag to the event.
---
---@param tag string
---@return EventQueueSystem.EventBuilder
function EventQueueSystem.EventBuilder:Tag(...) end

---
--- Assigns a debug ID to the event.
---
---@param id string
---@return EventQueueSystem.EventBuilder
function EventQueueSystem.EventBuilder:DebugID(...) end

---
--- Sets if the event is kept after completion.
---
---@param retain boolean
---@return EventQueueSystem.EventBuilder
function EventQueueSystem.EventBuilder:RetainAfterCompletion(...) end

---
--- Marks the event as created while paused.
---
---@param was_paused boolean
---@return EventQueueSystem.EventBuilder
function EventQueueSystem.EventBuilder:CreatedWhilePaused(...) end

---
--- Sets the timer clock type for the event.
---
---@param type EventQueueSystem.TimerType
---@return EventQueueSystem.EventBuilder
function EventQueueSystem.EventBuilder:TimerType(...) end

---
--- Starts the timer immediately.
---
---@return EventQueueSystem.EventBuilder
function EventQueueSystem.EventBuilder:StartTimer(...) end

---
--- Flags the event for deletion on the next cycle.
---
---@param delete_next boolean
---@return EventQueueSystem.EventBuilder
function EventQueueSystem.EventBuilder:DeleteNextCycleImmediately(...) end

---
--- Builds the final Event object.
---
---@return EventQueueSystem.Event
function EventQueueSystem.EventBuilder:Build(...) end

---
--- Builds the event and adds it directly to the queue.
---
---@return nil
function EventQueueSystem.EventBuilder:AddToQueue(...) end


---
--- General-purpose utility functions.
---
---@class util
util = {
}


---
--- Manages an entity's position, size, rotation, and scale, with spring dynamics for smooth visual updates.
---
---@class Transform
Transform = {
    actualX = nil, -- number The logical X position.
    visualX = nil, -- number The visual (spring-interpolated) X position.
    actualY = nil, -- number The logical Y position.
    visualY = nil, -- number The visual (spring-interpolated) Y position.
    actualW = nil, -- number The logical width.
    visualW = nil, -- number The visual width.
    actualH = nil, -- number The logical height.
    visualH = nil, -- number The visual height.
    rotation = nil, -- number The logical rotation in degrees.
    scale = nil, -- number The logical scale multiplier.
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
--- Stores alignment flags and offsets for an inherited property.
---
---@class Alignment
Alignment = {
    alignment = nil, -- integer The raw bitmask of alignment flags.
    extraOffset = nil, -- Vector2 Additional fine-tuning offset.
    prevExtraOffset = nil, -- Vector2 Previous frame's fine-tuning offset.
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
    role_type = nil, -- InheritedPropertiesType The role of this entity in the hierarchy.
    master = nil, -- Entity The master entity this entity inherits from.
    offset = nil, -- Vector2 The current offset from the master.
    prevOffset = nil, -- Vector2 The previous frame's offset.
    location_bond = nil, -- InheritedPropertiesSync|nil The sync bond for location.
    size_bond = nil, -- InheritedPropertiesSync|nil The sync bond for size.
    rotation_bond = nil, -- InheritedPropertiesSync|nil The sync bond for rotation.
    extraAlignmentFinetuningOffset = nil, -- Vector2 An additional fine-tuning offset for alignment.
    scale_bond = nil, -- InheritedPropertiesSync|nil The sync bond for scale.
    flags = nil, -- Alignment|nil Alignment flags and data.
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
    getObjectToDrag = nil, -- function|nil Returns the entity that should be dragged.
    update = nil, -- function|nil Called every frame.
    draw = nil, -- function|nil Called every frame for drawing.
    onClick = nil, -- function|nil Called on click.
    onRelease = nil, -- function|nil Called on click release.
    onHover = nil, -- function|nil Called when hover starts.
    onStopHover = nil, -- function|nil Called when hover ends.
    onDrag = nil, -- function|nil Called while dragging.
    onStopDrag = nil, -- function|nil Called when dragging stops.
}


---
--- A collection of boolean flags representing the current state of a GameObject.
---
---@class GameObjectState
GameObjectState = {
    visible = nil, -- boolean
    collisionEnabled = nil, -- boolean
    isColliding = nil, -- boolean
    focusEnabled = nil, -- boolean
    isBeingFocused = nil, -- boolean
    hoverEnabled = nil, -- boolean
    isBeingHovered = nil, -- boolean
    enlargeOnHover = nil, -- boolean
    enlargeOnDrag = nil, -- boolean
    clickEnabled = nil, -- boolean
    isBeingClicked = nil, -- boolean
    dragEnabled = nil, -- boolean
    isBeingDragged = nil, -- boolean
    triggerOnReleaseEnabled = nil, -- boolean
    isTriggeringOnRelease = nil, -- boolean
    isUnderOverlay = nil, -- boolean
}


---
--- The core component for a scene entity, managing hierarchy, state, and scriptable logic.
---
---@class GameObject
GameObject = {
    parent = nil, -- Entity|nil
    children = nil, -- table<Entity, boolean>
    orderedChildren = nil, -- table<integer, Entity>
    ignoresPause = nil, -- boolean
    container = nil, -- Entity|nil
    collisionTransform = nil, -- Transform|nil
    clickTimeout = nil, -- number
    methods = nil, -- GameObjectMethods|nil
    updateFunction = nil, -- function|nil
    drawFunction = nil, -- function|nil
    state = nil, -- GameObjectState
    dragOffset = nil, -- Vector2
    clickOffset = nil, -- Vector2
    hoverOffset = nil, -- Vector2
    shadowDisplacement = nil, -- Vector2
    layerDisplacement = nil, -- Vector2
    layerDisplacementPrev = nil, -- Vector2
    shadowHeight = nil, -- number
}


---
--- Contains information about an entity's render and collision order.
---
---@class CollisionOrderInfo
CollisionOrderInfo = {
    hasCollisionOrder = nil, -- boolean
    parentBox = nil, -- Rectangle
    treeOrder = nil, -- integer
    layerOrder = nil, -- integer
}


---
--- A simple component storing an entity's tree order for sorting.
---
---@class TreeOrderComponent
TreeOrderComponent = {
    order = nil, -- integer
}


---
--- A global system for creating and managing all Transforms and GameObjects.
---
---@class transform
transform = {
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
    UIT = nil, -- UITypeEnum The type of this UI element.
    uiBox = nil, -- Entity The root entity of the UI box this element belongs to.
    config = nil, -- UIConfig The configuration settings for this element.
}


---
--- Component for managing the state of a text input UI element.
---
---@class TextInput
TextInput = {
    text = nil, -- string The current text content.
    cursorPos = nil, -- integer The position of the text cursor.
    maxLength = nil, -- integer The maximum allowed length of the text.
    allCaps = nil, -- boolean If true, all input is converted to uppercase.
    callback = nil, -- function|nil A callback function triggered on text change.
}


---
--- A component that hooks global text input to a specific text input entity.
---
---@class TextInputHook
TextInputHook = {
    hookedEntity = nil, -- Entity The entity that currently has text input focus.
}


---
--- Defines a root of a UI tree, managing its draw layers.
---
---@class UIBoxComponent
UIBoxComponent = {
    uiRoot = nil, -- Entity The root entity of this UI tree.
    drawLayers = nil, -- table A map of layers used for drawing the UI.
}


---
--- Holds dynamic state information for a UI element.
---
---@class UIState
UIState = {
    contentDimensions = nil, -- Vector2 The calculated dimensions of the element's content.
    textDrawable = nil, -- TextDrawable The drawable text object.
    last_clicked = nil, -- Entity The last entity that was clicked within this UI context.
    object_focus_timer = nil, -- number Timer for object focus events.
    focus_timer = nil, -- number General purpose focus timer.
}


---
--- Represents a tooltip with a title and descriptive text.
---
---@class Tooltip
Tooltip = {
    title = nil, -- string The title of the tooltip.
    text = nil, -- string The main body text of the tooltip.
}


---
--- Arguments for configuring focus and navigation behavior.
---
---@class FocusArgs
FocusArgs = {
    button = nil, -- GamepadButton The gamepad button associated with this focus.
    snap_to = nil, -- boolean If the view should snap to this element when focused.
    registered = nil, -- boolean Whether this focus is registered with the focus system.
    type = nil, -- string The type of focus.
    claim_focus_from = nil, -- table<string, Entity> Entities this element can claim focus from.
    redirect_focus_to = nil, -- Entity|nil Redirect focus to another entity.
    nav = nil, -- table<string, Entity> Navigation map (e.g., nav.up = otherEntity).
    no_loop = nil, -- boolean Disables navigation looping.
}


---
--- Data for a UI slider element.
---
---@class SliderComponent
SliderComponent = {
    color = nil, -- string
    text = nil, -- string
    min = nil, -- number
    max = nil, -- number
    value = nil, -- number
    decimal_places = nil, -- integer
    w = nil, -- number
    h = nil, -- number
}


---
--- Represents a tile in an inventory grid, potentially holding an item.
---
---@class InventoryGridTileComponent
InventoryGridTileComponent = {
    item = nil, -- Entity|nil The item entity occupying this tile.
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
    stylingType = nil, -- UIStylingType|nil The visual style of the element.
    nPatchInfo = nil, -- NPatchInfo|nil 9-patch slicing information.
    nPatchSourceTexture = nil, -- string|nil Texture path for the 9-patch.
    id = nil, -- string|nil Unique identifier for this UI element.
    instanceType = nil, -- string|nil A specific instance type for categorization.
    uiType = nil, -- UITypeEnum|nil The fundamental type of the UI element.
    drawLayer = nil, -- string|nil The layer on which this element is drawn.
    group = nil, -- string|nil The focus group this element belongs to.
    groupParent = nil, -- string|nil The parent focus group.
    location_bond = nil, -- InheritedPropertiesSync|nil Bonding strength for location.
    rotation_bond = nil, -- InheritedPropertiesSync|nil Bonding strength for rotation.
    size_bond = nil, -- InheritedPropertiesSync|nil Bonding strength for size.
    scale_bond = nil, -- InheritedPropertiesSync|nil Bonding strength for scale.
    offset = nil, -- Vector2|nil Offset from the parent/aligned position.
    scale = nil, -- number|nil Scale multiplier.
    textSpacing = nil, -- number|nil Spacing for text characters.
    focusWithObject = nil, -- boolean|nil Whether focus is tied to a game object.
    refreshMovement = nil, -- boolean|nil Force movement refresh.
    no_recalc = nil, -- boolean|nil Prevents recalculation of transform.
    non_recalc = nil, -- boolean|nil Alias for no_recalc.
    noMovementWhenDragged = nil, -- boolean|nil Prevents movement while being dragged.
    master = nil, -- string|nil ID of the master element.
    parent = nil, -- string|nil ID of the parent element.
    object = nil, -- Entity|nil The game object associated with this UI element.
    objectRecalculate = nil, -- boolean|nil Force recalculation based on the object.
    alignmentFlags = nil, -- integer|nil Bitmask of alignment flags.
    width = nil, -- number|nil Explicit width.
    height = nil, -- number|nil Explicit height.
    maxWidth = nil, -- number|nil Maximum width.
    maxHeight = nil, -- number|nil Maximum height.
    minWidth = nil, -- number|nil Minimum width.
    minHeight = nil, -- number|nil Minimum height.
    padding = nil, -- number|nil Padding around the content.
    color = nil, -- string|nil Background color.
    outlineColor = nil, -- string|nil Outline color.
    outlineThickness = nil, -- number|nil Outline thickness in pixels.
    makeMovementDynamic = nil, -- boolean|nil Enables springy movement.
    shadow = nil, -- Vector2|nil Offset for the shadow.
    outlineShadow = nil, -- Vector2|nil Offset for the outline shadow.
    shadowColor = nil, -- string|nil Color of the shadow.
    noFill = nil, -- boolean|nil If true, the background is not filled.
    pixelatedRectangle = nil, -- boolean|nil Use pixel-perfect rectangle drawing.
    canCollide = nil, -- boolean|nil Whether collision is possible.
    collideable = nil, -- boolean|nil Alias for canCollide.
    forceCollision = nil, -- boolean|nil Forces collision checks.
    button_UIE = nil, -- boolean|nil Behaves as a button.
    disable_button = nil, -- boolean|nil Disables button functionality.
    progressBarFetchValueLambda = nil, -- function|nil Function to get the progress bar's current value.
    progressBar = nil, -- boolean|nil If this element is a progress bar.
    progressBarEmptyColor = nil, -- string|nil Color of the empty part of the progress bar.
    progressBarFullColor = nil, -- string|nil Color of the filled part of the progress bar.
    progressBarMaxValue = nil, -- number|nil The maximum value of the progress bar.
    progressBarValueComponentName = nil, -- string|nil Component name to fetch progress value from.
    progressBarValueFieldName = nil, -- string|nil Field name to fetch progress value from.
    ui_object_updated = nil, -- boolean|nil Flag indicating the UI object was updated.
    buttonDelayStart = nil, -- boolean|nil Flag for button delay start.
    buttonDelay = nil, -- number|nil Delay for button actions.
    buttonDelayProgress = nil, -- number|nil Progress of the button delay.
    buttonDelayEnd = nil, -- boolean|nil Flag for button delay end.
    buttonClicked = nil, -- boolean|nil True if the button was clicked this frame.
    buttonDistance = nil, -- number|nil Distance for button press effect.
    tooltip = nil, -- string|nil Simple tooltip text.
    detailedTooltip = nil, -- Tooltip|nil A detailed tooltip object.
    onDemandTooltip = nil, -- function|nil A function that returns a tooltip.
    hover = nil, -- boolean|nil Flag indicating if the element is being hovered.
    force_focus = nil, -- boolean|nil Forces this element to take focus.
    dynamicMotion = nil, -- boolean|nil Enables dynamic motion effects.
    choice = nil, -- boolean|nil Marks this as a choice in a selection.
    chosen = nil, -- boolean|nil True if this choice is currently selected.
    one_press = nil, -- boolean|nil Button can only be pressed once.
    chosen_vert = nil, -- boolean|nil Indicates a vertical choice selection.
    draw_after = nil, -- boolean|nil Draw this element after its children.
    focusArgs = nil, -- FocusArgs|nil Arguments for focus behavior.
    updateFunc = nil, -- function|nil Custom update function.
    initFunc = nil, -- function|nil Custom initialization function.
    onUIResizeFunc = nil, -- function|nil Callback for when the UI is resized.
    onUIScalingResetToOne = nil, -- function|nil Callback for when UI scaling resets.
    instaFunc = nil, -- function|nil A function to be executed instantly.
    buttonCallback = nil, -- function|nil Callback for button presses.
    buttonTemp = nil, -- boolean|nil Temporary button flag.
    textGetter = nil, -- function|nil Function to dynamically get text content.
    ref_entity = nil, -- Entity|nil A referenced entity.
    ref_component = nil, -- string|nil Name of a referenced component.
    ref_value = nil, -- any|nil A referenced value.
    prev_ref_value = nil, -- any|nil The previous referenced value.
    text = nil, -- string|nil Static text content.
    language = nil, -- string|nil Language key for localization.
    verticalText = nil, -- boolean|nil If true, text is rendered vertically.
    hPopup = nil, -- boolean|nil Is a horizontal popup.
    dPopup = nil, -- boolean|nil Is a detailed popup.
    hPopupConfig = nil, -- UIConfig|nil Configuration for the horizontal popup.
    dPopupConfig = nil, -- UIConfig|nil Configuration for the detailed popup.
    extend_up = nil, -- boolean|nil If the element extends upwards.
    resolution = nil, -- Vector2|nil Resolution context for this element.
    emboss = nil, -- boolean|nil Apply an emboss effect.
    line_emboss = nil, -- boolean|nil Apply a line emboss effect.
    mid = nil, -- boolean|nil A miscellaneous flag.
    noRole = nil, -- boolean|nil This element has no inherited properties role.
    role = nil, -- InheritedProperties|nil The inherited properties role.
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
    type = nil, -- UITypeEnum
    config = nil, -- UIConfig
    children = nil, -- table<integer, UIElementTemplateNode>
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
---
---@class ui.definitions
ui.definitions = {
}


---
--- 
---
---@class InputState
InputState = {
    cursor_clicked_target = Entity,  -- Entity clicked this frame
    cursor_prev_clicked_target = Entity,  -- Entity clicked in previous frame
    cursor_focused_target = Entity,  -- Entity under cursor focus now
    cursor_prev_focused_target = Entity,  -- Entity under cursor focus last frame
    cursor_focused_target_area = Rectangle,  -- Bounds of the focused target
    cursor_dragging_target = Entity,  -- Entity currently being dragged
    cursor_prev_dragging_target = Entity,  -- Entity dragged last frame
    cursor_prev_released_on_target = Entity,  -- Entity released on target last frame
    cursor_released_on_target = Entity,  -- Entity released on target this frame
    current_designated_hover_target = Entity,  -- Entity designated for hover handling
    prev_designated_hover_target = Entity,  -- Previously designated hover target
    cursor_hovering_target = Entity,  -- Entity being hovered now
    cursor_prev_hovering_target = Entity,  -- Entity hovered last frame
    cursor_hovering_handled = bool,  -- Whether hover was already handled
    collision_list = std::vector<Entity>,  -- All entities colliding with cursor
    nodes_at_cursor = std::vector<NodeData>,  -- All UI nodes under cursor
    cursor_position = Vector2,  -- Current cursor position
    cursor_down_position = Vector2,  -- Position where cursor was pressed
    cursor_up_position = Vector2,  -- Position where cursor was released
    focus_cursor_pos = Vector2,  -- Cursor pos used for gamepad/keyboard focus
    cursor_down_time = float,  -- Time of last cursor press
    cursor_up_time = float,  -- Time of last cursor release
    cursor_down_handled = bool,  -- Down event handled flag
    cursor_down_target = Entity,  -- Entity pressed down on
    cursor_down_target_click_timeout = float,  -- Click timeout interval
    cursor_up_handled = bool,  -- Up event handled flag
    cursor_up_target = Entity,  -- Entity released on
    cursor_released_on_handled = bool,  -- Release handled flag
    cursor_click_handled = bool,  -- Click handled flag
    is_cursor_down = bool,  -- Is cursor currently down?
    frame_buttonpress = std::vector<InputButton>,  -- Buttons pressed this frame
    repress_timer = std::unordered_map<InputButton,float>,  -- Cooldown per button
    no_holdcap = bool,  -- Disable repeated hold events
    text_input_hook = std::function<void(int)>,  -- Callback for text input events
    capslock = bool,  -- Is caps-lock active
    coyote_focus = bool,  -- Allow focus grace period
    cursor_hover_transform = Transform,  -- Transform under cursor
    cursor_hover_time = float,  -- Hover duration
    L_cursor_queue = std::deque<Entity>,  -- Recent cursor targets queue
    keysPressedThisFrame = std::vector<KeyboardKey>,  -- Keys pressed this frame
    keysHeldThisFrame = std::vector<KeyboardKey>,  -- Keys held down
    heldKeyDurations = std::unordered_map<KeyboardKey,float>,  -- Hold durations per key
    keysReleasedThisFrame = std::vector<KeyboardKey>,  -- Keys released this frame
    gamepadButtonsPressedThisFrame = std::vector<GamepadButton>,  -- Gamepad buttons pressed this frame
    gamepadButtonsHeldThisFrame = std::vector<GamepadButton>,  -- Held gamepad buttons
    gamepadHeldButtonDurations = std::unordered_map<GamepadButton,float>,  -- Hold durations per button
    gamepadButtonsReleasedThisFrame = std::vector<GamepadButton>,  -- Released gamepad buttons
    focus_interrupt = bool,  -- Interrupt focus navigation
    activeInputLocks = std::vector<InputLock>,  -- Currently active input locks
    inputLocked = bool,  -- Is global input locked
    axis_buttons = std::unordered_map<GamepadAxis,AxisButtonState>,  -- Axis-as-button states
    axis_cursor_speed = float,  -- Cursor speed from gamepad axis
    button_registry = ButtonRegistry,  -- Action-to-button mapping
    snap_cursor_to = SnapTarget,  -- Cursor snap target
    cursor_context = CursorContext,  -- Nested cursor focus contexts
    hid = HIDFlags,  -- Current HID flags
    gamepad = GamepadState,  -- Latest gamepad info
    overlay_menu_active_timer = float,  -- Overlay menu timer
    overlay_menu_active = bool,  -- Is overlay menu active
    screen_keyboard = ScreenKeyboard  -- On-screen keyboard state
}


---
--- Per-frame snapshot of cursor, keyboard, mouse, and gamepad state.
---
---@class InputState
InputState = {
}


---
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
---
---@class AxisButtonState
AxisButtonState = {
    current = bool,  -- Is axis beyond threshold this frame?
    previous = bool  -- Was axis beyond threshold last frame?
}


---
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
---
---@class SnapTarget
SnapTarget = {
    node = Entity,  -- Target entity to snap cursor to
    transform = Transform,  -- Target’s transform
    type = SnapType  -- Snap behavior type
}


---
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
---
---@class CursorContext
CursorContext = {
    layer = CursorContext::CursorLayer,  -- Current layer
    stack = std::vector<CursorContext::CursorLayer>  -- Layer stack
}


---
--- 
---
---@class GamepadState
GamepadState = {
    object = GamepadObject,  -- Raw gamepad object
    mapping = GamepadMapping,  -- Button/axis mapping
    name = std::string,  -- Gamepad name
    console = bool,  -- Is console gamepad?
    id = int  -- System device ID
}


---
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
function .create_transform_entity(...) end

---
--- Adds a fullscreen shader to the game.
---
---@param shaderName string

function .add_fullscreen_shader(...) end

---
--- Removes a fullscreen shader from the game.
---
---@param shaderName string

function .remove_fullscreen_shader(...) end

---
--- Adds a pre-built event to the queue.
---
---@param event EventQueueSystem.Event
---@param queue? string # Optional: The name of the queue to add to (defaults to 'base').
---@param front? boolean # Optional: If true, adds the event to the front of the queue.
---@return nil
function EventQueueSystem.add_event(...) end

---
--- Finds an active event by its tag.
---
---@param tag string # The tag of the event to find.
---@param queue? string # Optional: The specific queue to search in. Searches all if omitted.
---@return EventQueueSystem.Event|nil
function EventQueueSystem.get_event_by_tag(...) end

---
--- Removes all events from one or all queues.
---
---@param queue? string # Optional: The queue to clear. Clears all if omitted.
---@return nil
function EventQueueSystem.clear_queue(...) end

---
--- Updates the event queue, processing active events.
---
---@param forced? boolean # Optional: If true, forces an update step.
---@return nil
function EventQueueSystem.update(...) end

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
each value must be a function that returns true when its wait condition is met—
they will be stored in the Text component under txt.luaWaiters[alias].
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
Sets the foreground color for all animation objects in an entity
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
--- Creates a child entity under `master` with a Transform, GameObject (collision enabled),
and a ColliderComponent of the given `type`, applying all provided offsets, sizes, rotation,
scale and alignment flags.
---
---@param master entt.entity               # Parent entity to attach collider to
---@param type collision.ColliderType       # Shape of the new collider
---@param t table                           # Config table:
                                          #   offsetX?, offsetY?, width?, height?, rotation?, scale?
                                          #   alignment? (bitmask), alignOffset { x?, y? }
---@return entt.entity                      # Newly created collider entity
function collision.create_collider_for_entity(...) end

---
--- Runs a Separating Axis Theorem (SAT) test—or AABB test if both are unrotated—
on entities `a` and `b`, returning whether they intersect based on their ColliderComponents
and Transforms.
---
---@param registry entt.registry*           # Pointer to your entity registry
---@param a entt.entity                      # First entity to test
---@param b entt.entity                      # Second entity to test
---@return boolean                           # True if their collider OBBs/AABBs overlap
function collision.CheckCollisionBetweenTransforms(...) end

---
--- 
---
---@param e entt.entity               # Entity whose filter to modify
---@param tag string                   # Name of the tag to add
---| Adds the given tag bit to this entity’s filter.category, so it *is* also that tag.
function collision.setCollisionCategory(...) end

---
--- 
---
---@param e entt.entity               # Entity whose filter to modify
---@param ... string                   # One or more tag names
---| Replaces the entity’s filter.mask with the OR of all specified tags.
function collision.setCollisionMask(...) end

---
--- 
---
---@param e entt.entity               # Entity whose filter to reset
---@param tag string                   # The sole tag name
---| Clears all category bits, then sets only this one.
function collision.resetCollisionCategory(...) end

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
---@param registry registry
---@param e Entity
---@param incrementIndexAfterwards boolean Defaults to true
---@return nil
function layer_order_system.setToTopZIndex(...) end

---
--- Ensures entity a’s zIndex is at least one above b’s.
---
---@param registry registry
---@param a Entity The entity to move above b
---@param b Entity The reference entity
---@return nil
function layer_order_system.putAOverB(...) end

---
--- Walks all UIBoxComponents without a LayerOrderComponent and pushes them to the top Z-stack.
---
---@param registry registry
---@return nil
function layer_order_system.updateLayerZIndexesAsNecessary(...) end

---
--- Resets the global Z-index counter back to zero.
---
---@return nil
function layer_order_system.resetRunningZIndex(...) end

---
--- Force-sets an entity’s zIndex to the given value.
---
---@param registry registry
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
Gets the currently active language code. This is useful for checking which language is currently set.
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
--- Creates a Particle from Lua, applies optional animation & tag.
---
---@param location Vector2                        # world-space spawn position
---@param size     Vector2                        # initial width/height of the particle
---@param opts     table?                         # optional config table with any of:
 -- renderType        ParticleRenderType        # TEXTURE, RECTANGLE_LINE, RECTANGLE_FILLED, etc.
 -- velocity          Vector2                   # initial (vx,vy)
 -- rotation          number                    # starting rotation in degrees
 -- rotationSpeed     number                    # degrees/sec
 -- scale             number                    # uniform scale multiplier
 -- lifespan          number                    # seconds until auto-destroy (≤0 = infinite)
 -- age               number                    # initial age in seconds
 -- color             Color                     # immediately applied tint
 -- gravity           number                    # downward acceleration per second
 -- acceleration      number                    # acceleration along velocity vector
 -- startColor        Color                     # tint at birth
 -- endColor          Color                     # tint at death
 -- onUpdateCallback  function(particle,dt)      # run each frame
 -- shadow            boolean                   # draw or disable shadow (default = true)
---@param animCfg  table?                         # optional animation config:
 -- loop              boolean                   # whether to loop the animation
 -- animationName     string                    # which animation to play
---@param tag      string?                        # optional string tag to attach to this particle
---@return entt::entity                            # the newly created particle entity
function particle.CreateParticle(...) end

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
--- Cancels and destroys an active timer.
---
---@param timerHandle integer # The handle of the timer to cancel.
---@return nil
function timer.cancel(...) end

---
--- Gets the current invocation count for an 'every' timer.
---
---@param timerHandle integer # The handle of an 'every' timer.
---@return integer|nil # The current invocation count, or nil if not found.
function timer.get_every_index(...) end

---
--- Resets a timer's elapsed time, such as for a 'cooldown'.
---
---@param timerHandle integer # The handle of the timer to reset.
---@return nil
function timer.reset(...) end

---
--- Gets the configured delay time for a timer.
---
---@param timerHandle integer # The handle of the timer.
---@return number|nil # The timer's current delay, or nil if not found.
function timer.get_delay(...) end

---
--- Sets the global speed multiplier for all timers.
---
---@param multiplier number # The new global speed multiplier.
---@return nil
function timer.set_multiplier(...) end

---
--- Gets the global timer speed multiplier.
---
---@return number
function timer.get_multiplier(...) end

---
--- Gets the elapsed time for a 'for' timer.
---
---@param timerHandle integer # The handle of a 'for' timer.
---@return number|nil # The normalized elapsed time (0.0 to 1.0), or nil if not found.
function timer.get_for_elapsed(...) end

---
--- Returns the timer object's elapsed time and its configured delay.
---
---@param timerHandle integer # The handle of the timer.
---@return number, number # Returns two values: the elapsed time and the total delay. Returns a single nil if not found.
function timer.get_timer_and_delay(...) end

---
--- Updates all active timers, should be called once per frame.
---
---@param dt number # Delta time.
---@return nil
function timer.update(...) end

---
--- Creates a timer that runs an action once immediately.
---
---@param action fun()
---@param after? fun()
---@param tag? string
---@param group? string # Optional group to assign this timer to.
---@return integer # timerHandle
function timer.run(...) end

---
--- Creates a timer that runs an action once after a delay.
---
---@param delay number|{number, number} # A fixed delay or a {min, max} range in seconds.
---@param action fun()
---@param tag? string
---@param group? string # Optional group to assign this timer to.
---@return integer # timerHandle
function timer.after(...) end

---
--- Creates a resettable timer that fires an action when a condition is met after a cooldown.
---
---@param delay number|{number, number} # Cooldown duration in seconds or a {min, max} range.
---@param condition fun():boolean # A function that must return true for the action to fire.
---@param action fun()
---@param times? integer # Number of times to run. 0 for infinite.
---@param after? fun()
---@param tag? string
---@param group? string # Optional group to assign this timer to.
---@return integer # timerHandle
function timer.cooldown(...) end

---
--- Creates a timer that runs an action repeatedly at a given interval.
---
---@param interval number|{number, number} # Interval in seconds or a {min, max} range.
---@param action fun()
---@param times? integer # Number of times to run. 0 for infinite.
---@param immediate? boolean # If true, the action runs immediately on creation.
---@param after? fun()
---@param tag? string
---@param group? string # Optional group to assign this timer to.
---@return integer # timerHandle
function timer.every(...) end

---
--- Creates a timer that runs for a set number of steps, interpolating the delay between a start and end value.
---
---@param start_delay number
---@param end_delay number
---@param times integer # Total number of steps.
---@param action fun()
---@param immediate? boolean
---@param step_method? fun(t:number):number # Easing function for delay interpolation.
---@param after? fun()
---@param tag? string
---@param group? string # Optional group to assign this timer to.
---@return integer # timerHandle
function timer.every_step(...) end

---
--- Creates a timer that runs an action every frame for a set duration, passing delta time to the action.
---
---@param duration number|{number, number} # Total duration in seconds or a {min, max} range.
---@param action fun(dt:number)
---@param after? fun()
---@param tag? string
---@param group? string # Optional group to assign this timer to.
---@return integer # timerHandle
function timer.for_time(...) end

---
--- Creates a timer that interpolates a value towards a target over a duration.
---
---@param duration number|{number, number} # Duration of the tween in seconds or a {min, max} range.
---@param getter fun():number # Function to get the current value.
---@param setter fun(value:number) # Function to set the new value.
---@param target_value number # The final value for the tween.
---@param easing_method? fun(t:number):number # Optional easing function (0.0-1.0).
---@param after? fun()
---@param tag? string
---@param group? string # Optional group to assign this timer to.
---@return integer # timerHandle
function timer.tween(...) end

---
--- Tween multiple numeric fields on a Lua table with a single timer (progress 0→1). Captures start values at creation; one tag/after for the whole batch. Default easing: linear.
---
---@param duration number|{number, number} # Seconds or {min,max} range (randomized at start).
---@param target table # Table/object whose numeric fields will be tweened.
---@param source table<string, number> # Map of field -> target value (e.g., { sx=0, sy=0 }).
---@param method? fun(t:number):number # Easing function; default is linear (t).
---@param after? fun() # Called once when all fields reach targets.
---@param tag? string # Cancels existing tweens with the same tag.
---@param group? string # Optional group bucket for management.
---@return integer # timerHandle
function timer.tween(...) end

---
--- Tween multiple engine-backed values (get/set pairs) with a single timer. Each track defines get(), set(v), to, and optional from. Captures starts at creation; one tag/after for the whole batch. Default easing: linear.
---
---@param duration number|{number, number} # Seconds or {min,max} range (randomized at start).
---@param tracks { {get:fun():number, set:fun(value:number), to:number, from?:number}[] }|table # Array-like table of descriptors.
---@param method? fun(t:number):number # Easing function; default is linear (t).
---@param after? fun() # Called once when all tracks reach targets.
---@param tag? string # Cancels existing tweens with the same tag.
---@param group? string # Optional group bucket for management.
---@return integer # timerHandle
function timer.tween(...) end

---
--- Pauses the timer with the given tag.
---
---@param tag string # The tag/handle of the timer to pause.
---@return nil
function timer.pause(...) end

---
--- Resumes a previously paused timer.
---
---@param tag string # The tag/handle of the timer to resume.
---@return nil
function timer.resume(...) end

---
--- Cancels (removes) all timers in the specified group.
---
---@param group string # The name of the timer group to cancel.
---@return nil
function timer.kill_group(...) end

---
--- Pauses all timers in the specified group.
---
---@param group string # The name of the timer group to pause.
---@return nil
function timer.pause_group(...) end

---
--- Resumes all timers in the specified group.
---
---@param group string # The name of the timer group to resume.
---@return nil
function timer.resume_group(...) end

---
--- Cancels and destroys an active timer.
---
---@param timerHandle integer # The handle of the timer to cancel.
---@return nil
function timer.cancel(...) end

---
--- Gets the current invocation count for an 'every' timer.
---
---@param timerHandle integer # The handle of an 'every' timer.
---@return integer|nil # The current invocation count, or nil if not found.
function timer.get_every_index(...) end

---
--- Resets a timer's elapsed time, such as for a 'cooldown'.
---
---@param timerHandle integer # The handle of the timer to reset.
---@return nil
function timer.reset(...) end

---
--- Gets the configured delay time for a timer.
---
---@param timerHandle integer # The handle of the timer.
---@return number|nil # The timer's current delay, or nil if not found.
function timer.get_delay(...) end

---
--- Sets the global speed multiplier for all timers.
---
---@param multiplier number # The new global speed multiplier.
---@return nil
function timer.set_multiplier(...) end

---
--- Gets the global timer speed multiplier.
---
---@return number
function timer.get_multiplier(...) end

---
--- Gets the elapsed time for a 'for' timer.
---
---@param timerHandle integer # The handle of a 'for' timer.
---@return number|nil # The normalized elapsed time (0.0 to 1.0), or nil if not found.
function timer.get_for_elapsed(...) end

---
--- Returns the timer object's elapsed time and its configured delay.
---
---@param timerHandle integer # The handle of the timer.
---@return number, number # Returns two values: the elapsed time and the total delay. Returns a single nil if not found.
function timer.get_timer_and_delay(...) end

---
--- Re-maps a number from one range to another.
---
---@param value number
---@param from1 number
---@param to1 number
---@param from2 number
---@param to2 number
---@return number
function timer.math.remap(...) end

---
--- Linearly interpolates between two points.
---
---@param a number
---@param b number
---@param t number
---@return number
function timer.math.lerp(...) end

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

