--[[
================================================================================
child_builder.lua - Fluent Child Entity Attachment API
================================================================================
Simplifies attaching child entities to parents with transform inheritance.
Wraps the existing transform.AssignRole() C++ binding.

Usage:
    local ChildBuilder = require("core.child_builder")
    
    -- Attach weapon to player
    ChildBuilder.for_entity(weapon)
        :attachTo(player)
        :offset(20, 0)
        :rotateWith()
        :apply()
    
    -- Animate child offset (weapon swing)
    ChildBuilder.animateOffset(weapon, {
        to = { x = -20, y = 30 },
        duration = 0.2,
        ease = "outQuad"
    })
    
    -- Orbit animation (circular swing)
    ChildBuilder.orbit(weapon, {
        radius = 30,
        startAngle = 0,
        endAngle = math.pi/2,
        duration = 0.2
    })

Dependencies:
    - transform.AssignRole (C++ binding)
    - InheritedPropertiesType, InheritedPropertiesSync (enums)
    - core.tween (for animations)
    - core.component_cache

See also:
    - docs/project-management/design/anchor-pattern-adoption.md
]]

if _G.__CHILD_BUILDER__ then return _G.__CHILD_BUILDER__ end

local ChildBuilder = {}
ChildBuilder.__index = ChildBuilder

local component_cache = require("core.component_cache")

-- Lazy-load tween to avoid circular dependencies
local _tween = nil
local function get_tween()
    if not _tween then
        _tween = require("core.tween")
    end
    return _tween
end

--------------------------------------------------------------------------------
-- Builder Instance
--------------------------------------------------------------------------------

--- Create a new ChildBuilder for the given entity.
--- @param entity number The child entity to configure
--- @return table ChildBuilder instance
function ChildBuilder.for_entity(entity)
    return setmetatable({
        _entity = entity,
        _parent = nil,
        _offset = { x = 0, y = 0 },
        _locationBond = nil,
        _sizeBond = nil,
        _rotationBond = nil,
        _scaleBond = nil,
        _roleType = InheritedPropertiesType.RoleInheritor,
        _name = nil,
        -- Anchor API fields (for alignment-based positioning)
        _alignment = 0,           -- bitmask: combination of AlignmentFlag values
        _alignInside = false,     -- whether to use ALIGN_TO_INNER_EDGES (default: false = outside)
        _gap = { x = 0, y = 0 },  -- extraAlignmentFinetuningOffset
    }, ChildBuilder)
end

--- Set the parent entity to attach to.
--- @param parent number The parent entity
--- @return self
function ChildBuilder:attachTo(parent)
    self._parent = parent
    return self
end

--- Set the offset from parent center.
--- @param x number X offset in pixels
--- @param y number|nil Y offset in pixels (default: 0)
--- @return self
function ChildBuilder:offset(x, y)
    self._offset = { x = x, y = y or 0 }
    return self
end

--------------------------------------------------------------------------------
-- Anchor API Methods
--------------------------------------------------------------------------------

-- Map string anchor names to AlignmentFlag values
local ANCHOR_MAP = {
    top = AlignmentFlag.VERTICAL_TOP,
    bottom = AlignmentFlag.VERTICAL_BOTTOM,
    left = AlignmentFlag.HORIZONTAL_LEFT,
    right = AlignmentFlag.HORIZONTAL_RIGHT,
    centerx = AlignmentFlag.HORIZONTAL_CENTER,
    centery = AlignmentFlag.VERTICAL_CENTER,
    center = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
}

--- Set anchor point(s) by string name.
--- @param ... string Anchor names: "top", "bottom", "left", "right", "centerx", "centery", "center"
--- @return self
function ChildBuilder:anchor(...)
    local args = {...}
    for _, arg in ipairs(args) do
        if type(arg) == "string" then
            local flag = ANCHOR_MAP[string.lower(arg)]
            if flag then
                self._alignment = bit.bor(self._alignment, flag)
            end
        end
    end
    return self
end

--- Anchor to parent's top edge.
--- @return self
function ChildBuilder:anchorTop()
    self._alignment = bit.bor(self._alignment, AlignmentFlag.VERTICAL_TOP)
    return self
end

--- Anchor to parent's bottom edge.
--- @return self
function ChildBuilder:anchorBottom()
    self._alignment = bit.bor(self._alignment, AlignmentFlag.VERTICAL_BOTTOM)
    return self
end

--- Anchor to parent's left edge.
--- @return self
function ChildBuilder:anchorLeft()
    self._alignment = bit.bor(self._alignment, AlignmentFlag.HORIZONTAL_LEFT)
    return self
end

--- Anchor to parent's right edge.
--- @return self
function ChildBuilder:anchorRight()
    self._alignment = bit.bor(self._alignment, AlignmentFlag.HORIZONTAL_RIGHT)
    return self
end

--- Center horizontally relative to parent.
--- @return self
function ChildBuilder:anchorCenterX()
    self._alignment = bit.bor(self._alignment, AlignmentFlag.HORIZONTAL_CENTER)
    return self
end

--- Center vertically relative to parent.
--- @return self
function ChildBuilder:anchorCenterY()
    self._alignment = bit.bor(self._alignment, AlignmentFlag.VERTICAL_CENTER)
    return self
end

--- Center both horizontally and vertically relative to parent.
--- @return self
function ChildBuilder:anchorCenter()
    self._alignment = bit.bor(self._alignment, AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)
    return self
end

--- Position inside parent bounds (uses ALIGN_TO_INNER_EDGES).
--- @return self
function ChildBuilder:inside()
    self._alignInside = true
    return self
end

--- Position outside parent bounds (default).
--- @return self
function ChildBuilder:outside()
    self._alignInside = false
    return self
end

--- Set fine-tuning offset after alignment.
--- @param x number X offset
--- @param y number|nil Y offset (default: 0)
--- @return self
function ChildBuilder:gap(x, y)
    self._gap = { x = x or 0, y = y or 0 }
    return self
end

--- Set X fine-tuning offset after alignment.
--- @param x number X offset
--- @return self
function ChildBuilder:gapX(x)
    self._gap.x = x or 0
    return self
end

--- Set Y fine-tuning offset after alignment.
--- @param y number Y offset
--- @return self
function ChildBuilder:gapY(y)
    self._gap.y = y or 0
    return self
end

-- Convenience shorthand methods combining common anchor patterns

--- Anchor to top edge, centered horizontally.
--- @return self
function ChildBuilder:anchorTopCenter()
    return self:anchorTop():anchorCenterX()
end

--- Anchor to bottom edge, centered horizontally.
--- @return self
function ChildBuilder:anchorBottomCenter()
    return self:anchorBottom():anchorCenterX()
end

--- Anchor to left edge, centered vertically.
--- @return self
function ChildBuilder:anchorLeftCenter()
    return self:anchorLeft():anchorCenterY()
end

--- Anchor to right edge, centered vertically.
--- @return self
function ChildBuilder:anchorRightCenter()
    return self:anchorRight():anchorCenterY()
end

--- Anchor to top-left corner.
--- @return self
function ChildBuilder:anchorTopLeft()
    return self:anchorTop():anchorLeft()
end

--- Anchor to top-right corner.
--- @return self
function ChildBuilder:anchorTopRight()
    return self:anchorTop():anchorRight()
end

--- Anchor to bottom-left corner.
--- @return self
function ChildBuilder:anchorBottomLeft()
    return self:anchorBottom():anchorLeft()
end

--- Anchor to bottom-right corner.
--- @return self
function ChildBuilder:anchorBottomRight()
    return self:anchorBottom():anchorRight()
end

--- Enable rotation inheritance (child rotates with parent).
--- @param enabled boolean|nil Enable rotation sync (default: true)
--- @return self
function ChildBuilder:rotateWith(enabled)
    if enabled == false then
        self._rotationBond = nil
    else
        self._rotationBond = InheritedPropertiesSync.Strong
    end
    return self
end

--- Enable scale inheritance (child scales with parent).
--- @param enabled boolean|nil Enable scale sync (default: true)
--- @return self
function ChildBuilder:scaleWith(enabled)
    if enabled == false then
        self._scaleBond = nil
    else
        self._scaleBond = InheritedPropertiesSync.Strong
    end
    return self
end

--- Use eased (smooth) position following instead of instant snap.
--- @return self
function ChildBuilder:eased()
    self._locationBond = InheritedPropertiesSync.Weak
    return self
end

--- Use instant position snap (default).
--- @return self
function ChildBuilder:instant()
    self._locationBond = InheritedPropertiesSync.Strong
    return self
end

--- Set a name for this child (for lookup via parent).
--- @param name string The child name
--- @return self
function ChildBuilder:named(name)
    self._name = name
    return self
end

--- Set role type to PermanentAttachment (persists after parent death).
--- @return self
function ChildBuilder:permanent()
    self._roleType = InheritedPropertiesType.PermanentAttachment
    return self
end

--- Set role type to CarbonCopy (exact position copy, no offset).
--- @return self
function ChildBuilder:carbonCopy()
    self._roleType = InheritedPropertiesType.RoleCarbonCopy
    return self
end

--- Apply the configuration and attach child to parent.
--- @return number The child entity
function ChildBuilder:apply()
    if not self._parent then
        error("ChildBuilder: must call :attachTo(parent) before :apply()")
    end
    
    if not registry:valid(self._parent) then
        error("ChildBuilder: parent entity is not valid")
    end
    
    if not registry:valid(self._entity) then
        error("ChildBuilder: child entity is not valid")
    end
    
    local existingParent = ChildBuilder.getParent(self._entity)
    if existingParent and existingParent ~= self._parent and registry:valid(existingParent) then
        ChildBuilder.detach(self._entity)
    end

    -- Warn if both offset and anchor are set (they are mutually exclusive)
    if self._alignment ~= 0 and (self._offset.x ~= 0 or self._offset.y ~= 0) then
        print("[ChildBuilder] Warning: Both :offset() and anchor methods used. Anchor mode takes precedence; use :gap() for fine-tuning instead of :offset().")
    end

    -- Check if alignment-based positioning is requested
    if self._alignment ~= 0 then
        local useDefaultRole = self._roleType == InheritedPropertiesType.RoleInheritor

        if not useDefaultRole then
            -- Preserve custom role types by assigning first, then applying alignment only.
            transform.AssignRole(
                registry,
                self._entity,
                self._roleType,
                self._parent,
                self._locationBond or InheritedPropertiesSync.Strong,
                self._sizeBond,
                self._rotationBond,
                self._scaleBond,
                nil
            )
        end

        -- Build final alignment flags
        local finalAlignment = self._alignment
        if self._alignInside then
            finalAlignment = bit.bor(finalAlignment, AlignmentFlag.ALIGN_TO_INNER_EDGES)
        end

        -- Use ConfigureAlignment for anchor-based positioning
        transform.ConfigureAlignment(
            registry,
            self._entity,
            useDefaultRole, -- isChild (avoid overriding custom role types)
            self._parent,
            self._locationBond or InheritedPropertiesSync.Strong,
            self._sizeBond,
            self._rotationBond,
            self._scaleBond,
            finalAlignment,
            Vector2 { x = self._gap.x, y = self._gap.y }
        )
    else
        -- Fall back to AssignRole for backward compatibility (offset-only)
        transform.AssignRole(
            registry,
            self._entity,
            self._roleType,
            self._parent,
            self._locationBond or InheritedPropertiesSync.Strong,
            self._sizeBond,
            self._rotationBond,
            self._scaleBond,
            Vector2 { x = self._offset.x, y = self._offset.y }
        )
    end

    local ip = component_cache.get(self._entity, InheritedProperties)
    if ip then
        if self._alignment ~= 0 then
            -- For alignment mode, use gap as offset
            ip.offset = Vector2 { x = self._gap.x, y = self._gap.y }
        else
            ip.offset = Vector2 { x = self._offset.x, y = self._offset.y }
        end
        if self._rotationBond == nil then
            ip.rotation_bond = nil
        end
        if self._scaleBond == nil then
            ip.scale_bond = nil
        end
    end
    
    local parentGO = component_cache.get(self._parent, GameObject)
    if parentGO then
        local childKey = self._name or tostring(self._entity)
        parentGO.children[childKey] = self._entity
        
        local found = false
        for _, child in ipairs(parentGO.orderedChildren) do
            if child == self._entity then
                found = true
                break
            end
        end
        if not found then
            -- LuaJIT compatibility: Sol2 vectors are userdata, not tables
            -- Use index assignment instead of table.insert
            parentGO.orderedChildren[#parentGO.orderedChildren + 1] = self._entity
        end
    end
    
    return self._entity
end

--------------------------------------------------------------------------------
-- Static Anchor Helpers
--------------------------------------------------------------------------------

--- Re-anchor an existing attached entity.
--- @param entity number The child entity
--- @param anchor string|table The anchor position ("top", "bottom", etc.) or table {"top", "center"}
--- @param inside boolean|nil Whether to anchor inside parent bounds (default: false)
--- @param gap table|nil Optional {x, y} gap offset
--- @return number The entity
function ChildBuilder.setAnchor(entity, anchor, inside, gap)
    local ip = component_cache.get(entity, InheritedProperties)
    if not ip or not ip.flags then
        print(string.format("[ChildBuilder] Warning: entity %s has no InheritedProperties. setAnchor() has no effect.", tostring(entity)))
        return entity
    end

    -- Clear existing alignment
    ip.flags.alignment = 0

    -- Parse anchor argument
    local anchors = type(anchor) == "table" and anchor or { anchor }
    for _, a in ipairs(anchors) do
        if type(a) == "string" then
            local flag = ANCHOR_MAP[string.lower(a)]
            if flag then
                ip.flags.alignment = bit.bor(ip.flags.alignment, flag)
            end
        end
    end

    -- Apply inside/outside
    if inside then
        ip.flags.alignment = bit.bor(ip.flags.alignment, AlignmentFlag.ALIGN_TO_INNER_EDGES)
    end

    -- Apply gap
    if gap then
        ip.flags.extraAlignmentFinetuningOffset = Vector2 { x = gap.x or 0, y = gap.y or 0 }
    end

    return entity
end

--------------------------------------------------------------------------------
-- Static Animation Helpers
--------------------------------------------------------------------------------

--- Animate a child entity's offset.
--- @param entity number The child entity
--- @param opts table Options: { from, to, duration, ease, onComplete }
--- @return number The entity
function ChildBuilder.animateOffset(entity, opts)
    local ip = component_cache.get(entity, InheritedProperties)
    if not ip then
        print("[ChildBuilder] Warning: entity has no InheritedProperties")
        return entity
    end
    
    if not ip.offset then
        ip.offset = Vector2 { x = 0, y = 0 }
    end
    
    local from = opts.from or { x = ip.offset.x, y = ip.offset.y }
    local to = opts.to or { x = 0, y = 0 }
    local duration = opts.duration or 0.2
    local ease = opts.ease or "linear"
    local onComplete = opts.onComplete
    
    local Tween = get_tween()
    
    Tween.value(0, 1, duration, function(t)
        if not registry:valid(entity) then return end
        local currentIP = component_cache.get(entity, InheritedProperties)
        if currentIP and currentIP.offset then
            currentIP.offset.x = from.x + (to.x - from.x) * t
            currentIP.offset.y = from.y + (to.y - from.y) * t
        end
    end)
        :ease(ease)
        :onComplete(function()
            if onComplete then onComplete() end
        end)
    
    return entity
end

--- Animate a child entity in an orbital/arc path.
--- @param entity number The child entity
--- @param opts table Options: { radius, startAngle, endAngle, duration, ease, baseOffset, onComplete }
--- @return number The entity
function ChildBuilder.orbit(entity, opts)
    local ip = component_cache.get(entity, InheritedProperties)
    if not ip then
        print("[ChildBuilder] Warning: entity has no InheritedProperties")
        return entity
    end
    
    if not ip.offset then
        ip.offset = Vector2 { x = 0, y = 0 }
    end
    
    local radius = opts.radius or 30
    local startAngle = opts.startAngle or 0
    local endAngle = opts.endAngle or math.pi * 2
    local duration = opts.duration or 0.5
    local ease = opts.ease or "linear"
    local baseOffset = opts.baseOffset or { x = 0, y = 0 }
    local onComplete = opts.onComplete
    
    local Tween = get_tween()
    
    Tween.value(startAngle, endAngle, duration, function(angle)
        if not registry:valid(entity) then return end
        local currentIP = component_cache.get(entity, InheritedProperties)
        if currentIP and currentIP.offset then
            currentIP.offset.x = baseOffset.x + math.cos(angle) * radius
            currentIP.offset.y = baseOffset.y + math.sin(angle) * radius
        end
    end)
        :ease(ease)
        :onComplete(function()
            if onComplete then onComplete() end
        end)
    
    return entity
end

--- Set a child entity's offset immediately (no animation).
--- @param entity number The child entity
--- @param x number X offset
--- @param y number Y offset
--- @return number The entity
function ChildBuilder.setOffset(entity, x, y)
    local ip = component_cache.get(entity, InheritedProperties)
    if not ip then
        print("[ChildBuilder] Warning: entity has no InheritedProperties")
        return entity
    end
    
    if not ip.offset then
        ip.offset = Vector2 { x = 0, y = 0 }
    end
    
    ip.offset.x = x
    ip.offset.y = y
    
    return entity
end

--- Get a child entity's current offset.
--- @param entity number The child entity
--- @return table|nil { x, y } or nil if no InheritedProperties
function ChildBuilder.getOffset(entity)
    local ip = component_cache.get(entity, InheritedProperties)
    if not ip or not ip.offset then
        return nil
    end
    return { x = ip.offset.x, y = ip.offset.y }
end

--- Get a child entity's parent (master) entity.
--- @param entity number The child entity
--- @return number|nil Parent entity or nil
function ChildBuilder.getParent(entity)
    local ip = component_cache.get(entity, InheritedProperties)
    if not ip then
        return nil
    end
    return ip.master
end

--- Detach a child from its parent.
--- @param entity number The child entity
--- @return number The entity
function ChildBuilder.detach(entity)
    local ip = component_cache.get(entity, InheritedProperties)
    if not ip then
        return entity
    end
    
    local parent = ip.master
    if parent and parent ~= entt_null and registry:valid(parent) then
        local parentGO = component_cache.get(parent, GameObject)
        if parentGO then
            for name, child in pairs(parentGO.children) do
                if child == entity then
                    parentGO.children[name] = nil
                    break
                end
            end
            for i, child in ipairs(parentGO.orderedChildren) do
                if child == entity then
                    table.remove(parentGO.orderedChildren, i)
                    break
                end
            end
        end
    end
    
    transform.AssignRole(
        registry,
        entity,
        InheritedPropertiesType.RoleRoot,
        entt_null,
        nil,
        nil,
        nil,
        nil,
        nil
    )
    
    return entity
end

--------------------------------------------------------------------------------
-- Module Export
--------------------------------------------------------------------------------

_G.__CHILD_BUILDER__ = ChildBuilder
return ChildBuilder
