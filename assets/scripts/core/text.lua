-- assets/scripts/core/text.lua
--[[
================================================================================
TEXT BUILDER - Fluent API for Game Text
================================================================================
Particle-style API for text rendering with three layers:
- Recipe: Immutable text definition
- Spawner: Position configuration
- Handle: Lifecycle control

Usage:
    local Text = require("core.text")

    local recipe = Text.define()
        :content("[%d](color=red)")
        :size(20)
        :fade()
        :lifespan(0.8)

    recipe:spawn(25):above(enemy, 10)

    -- In game loop:
    Text.update(dt)
]]

-- Singleton guard
if _G.__TEXT_BUILDER__ then
    return _G.__TEXT_BUILDER__
end

local Text = {}

-- Active handles list (managed by Text.update)
Text._activeHandles = {}

--------------------------------------------------------------------------------
-- FORWARD DECLARATIONS
--------------------------------------------------------------------------------

local RecipeMethods = {}
local SpawnerMethods = {}
local HandleMethods = {}

--------------------------------------------------------------------------------
-- RECIPE
--------------------------------------------------------------------------------

RecipeMethods.__index = RecipeMethods

--- Set text content (template string, literal, or callback)
--- @param contentOrFn string|function Content template or callback
--- @return self
function RecipeMethods:content(contentOrFn)
    self._config.content = contentOrFn
    return self
end

--- Set font size
--- @param fontSize number Font size in pixels
--- @return self
function RecipeMethods:size(fontSize)
    self._config.size = fontSize
    return self
end

--- Set base color
--- @param colorName string Color name or Color object
--- @return self
function RecipeMethods:color(colorName)
    self._config.color = colorName
    return self
end

--- Set default effects for all characters
--- @param effectStr string Effect string (e.g., "shake=2;float")
--- @return self
function RecipeMethods:effects(effectStr)
    self._config.effects = effectStr
    return self
end

--- Enable alpha fade over lifespan
--- @return self
function RecipeMethods:fade()
    self._config.fade = true
    return self
end

--- Set fade-in percentage
--- @param pct number Percentage of lifespan for fade-in (0-1)
--- @return self
function RecipeMethods:fadeIn(pct)
    self._config.fadeInPct = pct
    return self
end

--- Set auto-destroy lifespan
--- @param minOrFixed number Lifespan in seconds, or min if max provided
--- @param max number? Max lifespan for random range
--- @return self
function RecipeMethods:lifespan(minOrFixed, max)
    self._config.lifespanMin = minOrFixed
    self._config.lifespanMax = max or minOrFixed
    return self
end

--- Set wrap width for multi-line text
--- @param w number Width in pixels
--- @return self
function RecipeMethods:width(w)
    self._config.width = w
    return self
end

--- Set anchor mode
--- @param mode string "center" | "topleft"
--- @return self
function RecipeMethods:anchor(mode)
    self._config.anchor = mode
    return self
end

--- Set text alignment
--- @param align string "left" | "center" | "right" | "justify"
--- @return self
function RecipeMethods:align(align)
    self._config.align = align
    return self
end

--- Set render layer
--- @param layerObj any Layer object
--- @return self
function RecipeMethods:layer(layerObj)
    self._config.layer = layerObj
    return self
end

--- Set z-index
--- @param zIndex number Z-index for draw order
--- @return self
function RecipeMethods:z(zIndex)
    self._config.z = zIndex
    return self
end

--- Set render space
--- @param spaceName string "screen" | "world"
--- @return self
function RecipeMethods:space(spaceName)
    self._config.space = spaceName
    return self
end

--- Set custom font
--- @param fontObj any Font object
--- @return self
function RecipeMethods:font(fontObj)
    self._config.font = fontObj
    return self
end

--- Create a spawner for this recipe
--- @param value any? Value for template substitution
--- @return Spawner
function RecipeMethods:spawn(value)
    local spawner = setmetatable({}, SpawnerMethods)
    spawner._recipe = self
    spawner._value = value
    spawner._position = nil
    spawner._followEntity = nil
    spawner._followOffset = nil
    spawner._attachedEntity = nil
    spawner._asEntity = false
    spawner._shaders = nil
    spawner._richEffects = false
    spawner._tag = nil
    return spawner
end

--------------------------------------------------------------------------------
-- SPAWNER
--------------------------------------------------------------------------------

SpawnerMethods.__index = SpawnerMethods

--- Set absolute position and trigger spawn
--- @param x number X position
--- @param y number Y position
--- @return Handle
function SpawnerMethods:at(x, y)
    self._position = { x = x, y = y }
    return self:_spawn()
end

--- Position above entity (triggers spawn)
--- @param entity any Entity to position relative to
--- @param offset number? Pixels above entity (default: 0)
--- @return Handle
function SpawnerMethods:above(entity, offset)
    offset = offset or 0
    self._followEntity = entity
    self._followMode = "above"
    self._followOffset = offset
    self._position = self:_calculateEntityPosition()
    return self:_spawn()
end

--- Position below entity (triggers spawn)
--- @param entity any Entity to position relative to
--- @param offset number? Pixels below entity (default: 0)
--- @return Handle
function SpawnerMethods:below(entity, offset)
    offset = offset or 0
    self._followEntity = entity
    self._followMode = "below"
    self._followOffset = offset
    self._position = self:_calculateEntityPosition()
    return self:_spawn()
end

--- Position at entity center (triggers spawn)
--- @param entity any Entity to center on
--- @return Handle
function SpawnerMethods:center(entity)
    self._followEntity = entity
    self._followMode = "center"
    self._followOffset = 0
    self._position = self:_calculateEntityPosition()
    return self:_spawn()
end

--- Position left of entity (triggers spawn)
--- @param entity any Entity to position relative to
--- @param offset number? Pixels left of entity (default: 0)
--- @return Handle
function SpawnerMethods:left(entity, offset)
    offset = offset or 0
    self._followEntity = entity
    self._followMode = "left"
    self._followOffset = offset
    self._position = self:_calculateEntityPosition()
    return self:_spawn()
end

--- Position right of entity (triggers spawn)
--- @param entity any Entity to position relative to
--- @param offset number? Pixels right of entity (default: 0)
--- @return Handle
function SpawnerMethods:right(entity, offset)
    offset = offset or 0
    self._followEntity = entity
    self._followMode = "right"
    self._followOffset = offset
    self._position = self:_calculateEntityPosition()
    return self:_spawn()
end

--- Enable position following (call before :at/:above/etc)
--- @return self
function SpawnerMethods:follow()
    self._shouldFollow = true
    return self
end

--- Tag this text for bulk operations
--- @param tagName string Tag name
--- @return self
function SpawnerMethods:tag(tagName)
    self._tag = tagName
    return self
end

--- Attach lifecycle to entity (text dies when entity dies)
--- @param entity any Entity to attach to
--- @return self
function SpawnerMethods:attachTo(entity)
    self._attachedEntity = entity
    return self
end

--- Enable entity mode (creates ECS entity with Transform)
--- @return self
function SpawnerMethods:asEntity()
    self._asEntity = true
    return self
end

--- Set shaders for entity mode
--- @param shaderList table List of shader names
--- @return self
function SpawnerMethods:withShaders(shaderList)
    self._shaders = shaderList
    return self
end

--- Enable per-character effects in entity mode (expensive)
--- @return self
function SpawnerMethods:richEffects()
    self._richEffects = true
    return self
end

--- Internal: Calculate position from entity
function SpawnerMethods:_calculateEntityPosition()
    local entity_cache = _G.entity_cache or require("core.entity_cache")
    local component_cache = _G.component_cache or require("core.component_cache")
    local Transform = _G.Transform

    if not self._followEntity or not entity_cache.valid(self._followEntity) then
        return { x = 0, y = 0 }
    end

    local t = component_cache.get(self._followEntity, Transform)
    if not t then return { x = 0, y = 0 } end

    local centerX = (t.actualX or 0) + (t.actualW or 0) * 0.5
    local centerY = (t.actualY or 0) + (t.actualH or 0) * 0.5
    local offset = self._followOffset or 0

    if self._followMode == "above" then
        return { x = centerX, y = (t.actualY or 0) - offset }
    elseif self._followMode == "below" then
        return { x = centerX, y = (t.actualY or 0) + (t.actualH or 0) + offset }
    elseif self._followMode == "left" then
        return { x = (t.actualX or 0) - offset, y = centerY }
    elseif self._followMode == "right" then
        return { x = (t.actualX or 0) + (t.actualW or 0) + offset, y = centerY }
    else -- center
        return { x = centerX, y = centerY }
    end
end

--- Create handle without triggering spawn (deferred positioning)
--- @return Handle
function SpawnerMethods:stream()
    local handle = Text._createHandle(self)
    handle._streamed = true
    -- Don't add to active list yet
    return handle
end

--- Internal: Create the text handle
--- @return Handle
function SpawnerMethods:_spawn()
    local handle = Text._createHandle(self)
    table.insert(Text._activeHandles, handle)
    return handle
end

--------------------------------------------------------------------------------
-- HANDLE
--------------------------------------------------------------------------------

HandleMethods.__index = HandleMethods

--- Check if handle is still active
--- @return boolean
function HandleMethods:isActive()
    return self._active
end

--- Stop and remove this text
function HandleMethods:stop()
    self._active = false
end

--- Enable position following (can be called after spawn)
--- @return self
function HandleMethods:follow()
    self._shouldFollow = true
    return self
end

--- Attach lifecycle to entity (text dies when entity dies)
--- @param entity any Entity to attach to
--- @return self
function HandleMethods:attachTo(entity)
    self._attachedEntity = entity
    return self
end

--- Tag this handle (can be called after spawn)
--- @param tagName string Tag name
--- @return self
function HandleMethods:tag(tagName)
    self._tag = tagName
    return self
end

--- Update content using template with new value
--- @param newValue any Value for template substitution
function HandleMethods:setText(newValue)
    local content = self._config.content or ""
    if type(content) == "string" and newValue ~= nil then
        self._content = string.format(content, newValue)
    elseif type(content) == "function" then
        self._content = content()
    end
    if self._textRenderer and self._textRenderer.set_text then
        self._textRenderer:set_text(self._content)
    end
end

--- Replace entire content string
--- @param newContent string New content string
function HandleMethods:setContent(newContent)
    self._content = newContent
    if self._textRenderer and self._textRenderer.set_text then
        self._textRenderer:set_text(self._content)
    end
end

--- Move to absolute position
--- @param x number X position
--- @param y number Y position
function HandleMethods:moveTo(x, y)
    self._position = { x = x, y = y }
    if self._textRenderer then
        self._textRenderer.x = x
        self._textRenderer.y = y
    end
end

--- Move by relative offset
--- @param dx number X offset
--- @param dy number Y offset
function HandleMethods:moveBy(dx, dy)
    self._position.x = self._position.x + dx
    self._position.y = self._position.y + dy
    if self._textRenderer then
        self._textRenderer.x = self._position.x
        self._textRenderer.y = self._position.y
    end
end

--- Get current position
--- @return table { x, y }
function HandleMethods:getPosition()
    return { x = self._position.x, y = self._position.y }
end

--- Set position (for streamed handles)
--- @param x number X position
--- @param y number Y position
--- @return self
function HandleMethods:at(x, y)
    self._position = { x = x, y = y }
    if self._textRenderer then
        self._textRenderer.x = x
        self._textRenderer.y = y
    end
    -- Add to active list if streamed
    if self._streamed and self._active then
        table.insert(Text._activeHandles, self)
        self._streamed = false
    end
    return self
end

--- Get ECS entity (only valid if :asEntity() was used)
--- @return any|nil Entity ID or nil
function HandleMethods:getEntity()
    return self._entityId
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Internal: Create ECS entity with Transform and optional shaders
--- Uses animation_system to create a renderable entity so shader pipeline executes.
--- @param handle Handle Handle to associate with entity
--- @param shaders table|nil List of shader names to apply
--- @return userdata Entity ID
function Text._createShaderEntity(handle, shaders)
    local animation_system = _G.animation_system
    local component_cache = _G.component_cache or require("core.component_cache")
    local Transform = _G.Transform
    local ShaderBuilder = require("core.shader_builder")

    -- Verify animation_system is available
    if not animation_system or not animation_system.createAnimatedObjectWithTransform then
        print("[TEXT ERROR] animation_system not available!")
        return nil
    end

    -- Create entity with animation_system so it has AnimationQueueComponent
    -- This makes it part of the render system, enabling shader pipeline execution.
    -- Using "sample_card.png" as placeholder (known to exist and work with shaders)
    -- The sprite will be made invisible; local commands provide the actual visuals.
    local ok, entity = pcall(function()
        return animation_system.createAnimatedObjectWithTransform(
            "sample_card.png",  -- valid sprite that exists (used by cards)
            true                -- use as animation ID
        )
    end)

    if not ok then
        print("[TEXT ERROR] Failed to create animated entity: " .. tostring(entity))
        return nil
    end

    if not entity then
        print("[TEXT ERROR] createAnimatedObjectWithTransform returned nil!")
        return nil
    end

    print(string.format("[TEXT] Entity created: %s", tostring(entity)))

    -- Get transform and set position
    local t = component_cache.get(entity, Transform)
    if t then
        local pos = handle._position or { x = 0, y = 0 }
        t.actualX = pos.x
        t.actualY = pos.y
        -- Set reasonable bounds for text (shader pipeline uses entity bounds)
        t.actualW = handle._config.width or 200
        t.actualH = handle._config.size or 16
    end

    -- Ensure it renders through shader pipeline, not legacy
    local AnimationQueueComponent = _G.AnimationQueueComponent
    if AnimationQueueComponent then
        local animComp = component_cache.get(entity, AnimationQueueComponent)
        if animComp then
            pcall(function() animComp.drawWithLegacyPipeline = false end)
        end
    end

    -- Apply shaders if specified
    if shaders and #shaders > 0 then
        local shader_ok, shader_err = pcall(function()
            local builder = ShaderBuilder.for_entity(entity)
            for _, shaderName in ipairs(shaders) do
                builder:add(shaderName)
            end
            builder:apply()
        end)
        if not shader_ok then
            print("[TEXT ERROR] Shader application failed: " .. tostring(shader_err))
        else
            print(string.format("[TEXT] Shaders applied: %s", table.concat(shaders, ", ")))
            -- Hide the base sprite (sample_card.png) while keeping shader pipeline active
            -- setSkipBaseSprite must be called AFTER shaders are applied (ShaderPipelineComponent exists)
            if setSkipBaseSprite then
                setSkipBaseSprite(registry, entity, true)
                print("[TEXT] Base sprite hidden via skipBaseSprite")
            end
        end
    end

    print(string.format("[TEXT] Shader entity complete: %s", tostring(entity)))

    return entity
end

--- Internal: Create handle from spawner config
--- @param spawner Spawner
--- @return Handle
function Text._createHandle(spawner)
    local config = spawner._recipe._config
    local handle = setmetatable({}, HandleMethods)

    handle._active = true
    handle._spawner = spawner
    handle._config = config
    handle._position = spawner._position or { x = 0, y = 0 }
    handle._elapsed = 0
    handle._lifespan = nil

    -- Calculate lifespan if set
    if config.lifespanMin then
        if config.lifespanMin == config.lifespanMax then
            handle._lifespan = config.lifespanMin
        else
            handle._lifespan = config.lifespanMin +
                math.random() * (config.lifespanMax - config.lifespanMin)
        end
    end

    -- Store follow info
    handle._followEntity = spawner._followEntity
    handle._followMode = spawner._followMode
    handle._followOffset = spawner._followOffset
    handle._shouldFollow = spawner._shouldFollow

    -- Store attached entity
    handle._attachedEntity = spawner._attachedEntity

    -- Store tag
    handle._tag = spawner._tag

    -- Store entity mode flags
    handle._asEntity = spawner._asEntity
    handle._shaders = spawner._shaders
    handle._richEffects = spawner._richEffects

    -- Create real ECS entity if in entity mode (enables shader support)
    if spawner._asEntity then
        print(string.format("[TEXT] Creating shader entity with shaders: %s",
            spawner._shaders and table.concat(spawner._shaders, ", ") or "nil"))
        local entity = Text._createShaderEntity(handle, spawner._shaders)
        handle._entityId = entity
        print(string.format("[TEXT] Created shader entity: %s", tostring(entity)))
    else
        handle._entityId = nil
    end

    -- Resolve content
    local content = config.content or ""
    if type(content) == "function" then
        content = content()
    elseif spawner._value ~= nil and type(content) == "string" then
        content = string.format(content, spawner._value)
    end
    handle._content = content

    -- Create CommandBufferText (or mock)
    local CBT = _G._MockCommandBufferText or require("ui.command_buffer_text")
    local layer = config.layer or (_G.layers and _G.layers.ui)

    -- Convert string space to DrawCommandSpace enum
    local renderSpace = nil
    if layer and layer.DrawCommandSpace then
        if config.space == "world" then
            renderSpace = layer.DrawCommandSpace.World
        else
            renderSpace = layer.DrawCommandSpace.Screen
        end
    end

    handle._textRenderer = CBT({
        text = handle._content,
        w = config.width or 200,
        x = handle._position.x,
        y = handle._position.y,
        font_size = config.size or 16,
        font = config.font,
        anchor = config.anchor or "center",
        alignment = config.align,
        color = config.color,
        effects = config.effects,
        layer = layer,
        z = config.z or 0,
        render_space = renderSpace,
        -- Pass entity for shader pipeline rendering
        shader_entity = handle._entityId,
    })

    return handle
end

--- Create a new text recipe
--- @return Recipe
function Text.define()
    local recipe = setmetatable({}, RecipeMethods)
    recipe._config = {
        size = 16,
        color = "white",
        anchor = "center",
        space = "screen",
        z = 0,
    }
    return recipe
end

--- Update all active text handles (call once per frame)
--- @param dt number Delta time in seconds
function Text.update(dt)
    -- Iterate backwards for safe removal
    for i = #Text._activeHandles, 1, -1 do
        local handle = Text._activeHandles[i]

        -- Check if still active
        if not handle._active then
            table.remove(Text._activeHandles, i)
        else
            -- Check attached entity
            if handle._attachedEntity then
                local entity_cache = _G.entity_cache or require("core.entity_cache")
                if not entity_cache.valid(handle._attachedEntity) then
                    handle._active = false
                    table.remove(Text._activeHandles, i)
                    goto continue
                end
            end

            -- Update elapsed time
            handle._elapsed = handle._elapsed + dt

            -- Check lifespan
            if handle._lifespan and handle._elapsed >= handle._lifespan then
                handle._active = false
                table.remove(Text._activeHandles, i)
            else
                -- Update following position
                if handle._shouldFollow and handle._followEntity then
                    local entity_cache = _G.entity_cache or require("core.entity_cache")
                    local component_cache = _G.component_cache or require("core.component_cache")
                    local Transform = _G.Transform

                    if entity_cache.valid(handle._followEntity) then
                        local t = component_cache.get(handle._followEntity, Transform)
                        if t then
                            local centerX = (t.actualX or 0) + (t.actualW or 0) * 0.5
                            local centerY = (t.actualY or 0) + (t.actualH or 0) * 0.5
                            local offset = handle._followOffset or 0

                            if handle._followMode == "above" then
                                handle._position = { x = centerX, y = (t.actualY or 0) - offset }
                            elseif handle._followMode == "below" then
                                handle._position = { x = centerX, y = (t.actualY or 0) + (t.actualH or 0) + offset }
                            elseif handle._followMode == "left" then
                                handle._position = { x = (t.actualX or 0) - offset, y = centerY }
                            elseif handle._followMode == "right" then
                                handle._position = { x = (t.actualX or 0) + (t.actualW or 0) + offset, y = centerY }
                            else
                                handle._position = { x = centerX, y = centerY }
                            end

                            -- Update renderer position
                            if handle._textRenderer then
                                handle._textRenderer.x = handle._position.x
                                handle._textRenderer.y = handle._position.y
                            end

                            -- Update shader entity Transform (for queueScopedTransformCompositeRender)
                            if handle._entityId and entity_cache.valid(handle._entityId) then
                                local et = component_cache.get(handle._entityId, Transform)
                                if et then
                                    et.actualX = handle._position.x
                                    et.actualY = handle._position.y
                                end
                            end
                        end
                    end
                end

                -- Update renderer
                if handle._textRenderer and handle._textRenderer.update then
                    handle._textRenderer:update(dt)
                end
            end
        end
        ::continue::
    end
end

--- Get count of active text handles
--- @return number
function Text.getActiveCount()
    return #Text._activeHandles
end

--- Get copy of active handles list (for debugging)
--- @return table
function Text.getActiveHandles()
    local copy = {}
    for i, h in ipairs(Text._activeHandles) do
        copy[i] = h
    end
    return copy
end

--- Stop and remove all active text
function Text.stopAll()
    for _, handle in ipairs(Text._activeHandles) do
        handle._active = false
    end
    Text._activeHandles = {}
end

--- Stop all text with a specific tag
--- @param tagName string Tag to match
function Text.stopByTag(tagName)
    for _, handle in ipairs(Text._activeHandles) do
        if handle._tag == tagName then
            handle._active = false
        end
    end
end

_G.__TEXT_BUILDER__ = Text
return Text
