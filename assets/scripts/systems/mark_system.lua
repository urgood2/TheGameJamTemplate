--[[
================================================================================
MARK SYSTEM
================================================================================
Manages detonatable marks on entities - the "setup + payoff" combo system.

Marks are applied via cards/abilities and detonated when specific damage types hit.

Usage:
    local MarkSystem = require("systems.mark_system")
    MarkSystem.apply(entity, "static_charge", { stacks = 1, duration = 8 })
    local result = MarkSystem.checkDetonation(entity, "lightning", damage, source)
    -- result.bonus_damage, result.effects, etc.
]]

local signal = require("external.hump.signal")
local StatusEffects = require("data.status_effects")
local StatusIndicatorSystem = require("systems.status_indicator_system")

local MarkSystem = {
    -- { [entity_id] = { [mark_id] = mark_data } }
    active_marks = {},
}

--- Apply a mark to an entity
--- @param entity number Target entity ID
--- @param mark_id string Mark ID (from status_effects.lua)
--- @param opts table|nil { stacks = 1, duration = nil, source = nil }
--- @return boolean Success
function MarkSystem.apply(entity, mark_id, opts)
    opts = opts or {}
    local def = StatusEffects.get(mark_id)

    if not def or not def.is_mark then
        print("[MarkSystem] Not a valid mark:", mark_id)
        return false
    end

    if not entity or entity == entt_null or not registry:valid(entity) then
        return false
    end

    -- Initialize entity's mark table
    if not MarkSystem.active_marks[entity] then
        MarkSystem.active_marks[entity] = {}
    end

    local marks = MarkSystem.active_marks[entity]
    local stacks = opts.stacks or 1
    local duration = opts.duration or def.duration
    local max_stacks = def.max_stacks or 1

    if marks[mark_id] then
        -- Add stacks (up to max)
        local current = marks[mark_id]
        current.stacks = math.min(current.stacks + stacks, max_stacks)
        current.expires_at = duration and (os.clock() + duration) or nil
        current.uses = def.uses or -1

        -- Update indicator
        StatusIndicatorSystem.setStacks(entity, mark_id, current.stacks)
    else
        -- Create new mark
        marks[mark_id] = {
            mark_id = mark_id,
            stacks = math.min(stacks, max_stacks),
            source = opts.source,
            expires_at = duration and (os.clock() + duration) or nil,
            uses = def.uses or -1,
        }

        -- Show indicator
        StatusIndicatorSystem.show(entity, mark_id, duration, marks[mark_id].stacks)
    end

    print(string.format("[MarkSystem] ✅ Mark applied: %s to entity %d (stacks=%d, defensive=%s)",
        mark_id, entity, marks[mark_id].stacks, tostring(def.trigger == "on_damaged")))

    signal.emit("mark_applied", entity, mark_id, marks[mark_id].stacks)
    return true
end

--- Remove a mark from an entity
--- @param entity number Target entity ID
--- @param mark_id string Mark ID
function MarkSystem.remove(entity, mark_id)
    if not MarkSystem.active_marks[entity] then return end

    if MarkSystem.active_marks[entity][mark_id] then
        MarkSystem.active_marks[entity][mark_id] = nil
        StatusIndicatorSystem.hide(entity, mark_id)
        signal.emit("mark_removed", entity, mark_id)
    end

    -- Cleanup empty
    if next(MarkSystem.active_marks[entity]) == nil then
        MarkSystem.active_marks[entity] = nil
    end
end

--- Remove all marks from an entity
--- @param entity number Target entity ID
function MarkSystem.removeAll(entity)
    if not MarkSystem.active_marks[entity] then return end

    for mark_id, _ in pairs(MarkSystem.active_marks[entity]) do
        StatusIndicatorSystem.hide(entity, mark_id)
        signal.emit("mark_removed", entity, mark_id)
    end

    MarkSystem.active_marks[entity] = nil
end

--- Check if entity has a specific mark
--- @param entity number Target entity ID
--- @param mark_id string Mark ID
--- @return boolean
function MarkSystem.has(entity, mark_id)
    if not MarkSystem.active_marks[entity] then return false end
    return MarkSystem.active_marks[entity][mark_id] ~= nil
end

--- Get stacks of a mark on entity
--- @param entity number Target entity ID
--- @param mark_id string Mark ID
--- @return number Stack count (0 if not present)
function MarkSystem.getStacks(entity, mark_id)
    if not MarkSystem.active_marks[entity] then return 0 end
    local data = MarkSystem.active_marks[entity][mark_id]
    return data and data.stacks or 0
end

--- Get all marks on an entity
--- @param entity number Target entity ID
--- @return table { [mark_id] = { stacks, source, ... } }
function MarkSystem.getAll(entity)
    return MarkSystem.active_marks[entity] or {}
end

--- Check and process mark detonation when damage is dealt
--- @param entity number Target entity that was hit
--- @param damage_type string Type of damage dealt
--- @param base_damage number Original damage amount
--- @param source number|nil Source entity
--- @param tags table|nil Tags from damage source
--- @return table { bonus_damage, effects, detonated_marks }
function MarkSystem.checkDetonation(entity, damage_type, base_damage, source, tags)
    local result = {
        bonus_damage = 0,
        damage_mult = 1.0,
        effects = {},
        detonated_marks = {},
    }

    if not MarkSystem.active_marks[entity] then
        return result
    end

    local marks = MarkSystem.active_marks[entity]
    local to_consume = {}

    for mark_id, mark_data in pairs(marks) do
        local def = StatusEffects.get(mark_id)
        if def and StatusEffects.shouldTrigger(def, damage_type, tags) then
            local stacks = mark_data.stacks
            print(string.format("[MarkSystem] ⚡ DETONATION! %s x%d on entity %d (damage_type=%s, bonus=%d)",
                mark_id, stacks, entity, damage_type, (def.damage or 0) * stacks))

            -- Apply vulnerable (damage taken multiplier)
            if def.vulnerable then
                result.damage_mult = result.damage_mult * (1 + def.vulnerable / 100)
            end

            -- Apply bonus damage
            if def.damage then
                result.bonus_damage = result.bonus_damage + (def.damage * stacks)
            end

            -- Collect effects to apply
            if def.stun and def.stun > 0 then
                table.insert(result.effects, { type = "stun", duration = def.stun })
            end
            if def.apply then
                table.insert(result.effects, { type = "apply_status", status = def.apply })
            end
            if def.chain and def.chain > 0 then
                table.insert(result.effects, { type = "chain_to_marked", range = def.chain, mark_id = mark_id })
            end
            if def.radius and def.radius > 0 then
                table.insert(result.effects, { type = "aoe", radius = def.radius })
            end

            -- Run custom callback
            if def.on_pop then
                local custom_result = def.on_pop(entity, stacks, source, {
                    damage_type = damage_type,
                    base_damage = base_damage,
                    tags = tags,
                })
                if custom_result then
                    if custom_result.bonus_damage then
                        result.bonus_damage = result.bonus_damage + custom_result.bonus_damage
                    end
                    if custom_result.effects then
                        for _, eff in ipairs(custom_result.effects) do
                            table.insert(result.effects, eff)
                        end
                    end
                end
            end

            -- Track detonation
            table.insert(result.detonated_marks, { mark_id = mark_id, stacks = stacks })

            -- Handle uses
            if mark_data.uses > 0 then
                mark_data.uses = mark_data.uses - 1
                if mark_data.uses <= 0 then
                    table.insert(to_consume, mark_id)
                end
            elseif mark_data.uses == -1 then
                -- Unlimited uses, don't consume
            else
                -- uses == 0 means consume on first trigger
                table.insert(to_consume, mark_id)
            end

            signal.emit("mark_detonated", entity, mark_id, stacks, source)
        end
    end

    -- Consume marks that should be removed
    for _, mark_id in ipairs(to_consume) do
        MarkSystem.remove(entity, mark_id)
    end

    return result
end

--- Check and process defensive marks when entity takes damage
--- @param entity number Entity that was damaged
--- @param damage_type string Type of damage taken
--- @param incoming_damage number Damage amount before mitigation
--- @param attacker number|nil Attacker entity
--- @return table { block, reflect, counter_damage, effects }
function MarkSystem.checkDefensiveMarks(entity, damage_type, incoming_damage, attacker)
    local result = {
        block = 0,
        reflect = 0,
        counter_damage = 0,
        absorb_to_mana = 0,
        effects = {},
    }

    -- Debug: log what entity is being checked
    local has_marks = MarkSystem.active_marks[entity] ~= nil
    print(string.format("[MarkSystem] checkDefensiveMarks called: entity=%s, has_marks=%s, damage_type=%s",
        tostring(entity), tostring(has_marks), tostring(damage_type)))

    -- Debug: show all entities with marks
    if not has_marks then
        local marked_entities = {}
        for e, _ in pairs(MarkSystem.active_marks) do
            table.insert(marked_entities, tostring(e))
        end
        if #marked_entities > 0 then
            print(string.format("[MarkSystem] Entities with marks: %s", table.concat(marked_entities, ", ")))
        end
    end

    if not MarkSystem.active_marks[entity] then
        return result
    end

    local marks = MarkSystem.active_marks[entity]
    local to_consume = {}

    for mark_id, mark_data in pairs(marks) do
        local def = StatusEffects.get(mark_id)
        if def and StatusEffects.isDefensiveMark(def) then
            local stacks = mark_data.stacks
            print(string.format("[MarkSystem] 🛡️ DEFENSIVE TRIGGER! %s on entity %d (block=%d, counter=%d, uses_left=%d)",
                mark_id, entity, def.block or 0, (def.damage or 0) * stacks, mark_data.uses))

            -- Block damage
            if def.block then
                result.block = result.block + def.block
            end

            -- Reflect damage
            if def.reflect then
                result.reflect = result.reflect + (incoming_damage * def.reflect / 100)
            end

            -- Counter-attack damage
            if def.damage then
                result.counter_damage = result.counter_damage + (def.damage * stacks)
            end

            -- Absorb to mana
            if def.absorb_to_mana then
                result.absorb_to_mana = result.absorb_to_mana + def.absorb_to_mana
            end

            -- Chain counter
            if def.chain and def.chain > 0 then
                table.insert(result.effects, { type = "chain", range = def.chain, damage = def.damage or 0 })
            end

            -- Apply mark to attacker
            if def.apply and attacker then
                table.insert(result.effects, { type = "apply_to_attacker", status = def.apply, target = attacker })
            end

            -- Handle uses
            if mark_data.uses > 0 then
                mark_data.uses = mark_data.uses - 1
                StatusIndicatorSystem.show(entity, mark_id, nil, mark_data.uses)  -- Update visual
                if mark_data.uses <= 0 then
                    table.insert(to_consume, mark_id)
                end
            end

            signal.emit("defensive_mark_triggered", entity, mark_id, stacks, attacker)
        end
    end

    -- Consume expired marks
    for _, mark_id in ipairs(to_consume) do
        MarkSystem.remove(entity, mark_id)
    end

    return result
end

--- Count total stacks of a specific mark across all enemies
--- @param mark_id string Mark ID to count
--- @return number Total stacks
function MarkSystem.countAllStacks(mark_id)
    local total = 0
    for entity, marks in pairs(MarkSystem.active_marks) do
        if marks[mark_id] then
            total = total + marks[mark_id].stacks
        end
    end
    return total
end

--- Find all entities with a specific mark in range
--- @param center_x number Center X position
--- @param center_y number Center Y position
--- @param range number Search radius
--- @param mark_id string Mark ID to find
--- @param exclude table|nil Entities to exclude
--- @return table Array of { entity, stacks, x, y, distance }
function MarkSystem.findMarkedInRange(center_x, center_y, range, mark_id, exclude)
    local results = {}
    exclude = exclude or {}

    for entity, marks in pairs(MarkSystem.active_marks) do
        if marks[mark_id] and not exclude[entity] then
            local transform = component_cache.get(entity, Transform)
            if transform then
                local ex = transform.actualX + (transform.actualW or 0) * 0.5
                local ey = transform.actualY + (transform.actualH or 0) * 0.5
                local dx, dy = ex - center_x, ey - center_y
                local dist = math.sqrt(dx * dx + dy * dy)

                if dist <= range then
                    table.insert(results, {
                        entity = entity,
                        stacks = marks[mark_id].stacks,
                        x = ex,
                        y = ey,
                        distance = dist,
                    })
                end
            end
        end
    end

    -- Sort by distance
    table.sort(results, function(a, b) return a.distance < b.distance end)
    return results
end

--- Update - check expirations
--- @param dt number Delta time
function MarkSystem.update(dt)
    local now = os.clock()
    local to_remove = {}

    for entity, marks in pairs(MarkSystem.active_marks) do
        if not registry:valid(entity) then
            table.insert(to_remove, { entity = entity })
        else
            for mark_id, data in pairs(marks) do
                if data.expires_at and now >= data.expires_at then
                    table.insert(to_remove, { entity = entity, mark_id = mark_id })
                end
            end
        end
    end

    for _, removal in ipairs(to_remove) do
        if removal.mark_id then
            MarkSystem.remove(removal.entity, removal.mark_id)
        else
            MarkSystem.removeAll(removal.entity)
        end
    end
end

--- Cleanup all marks
function MarkSystem.cleanup()
    for entity, _ in pairs(MarkSystem.active_marks) do
        MarkSystem.removeAll(entity)
    end
    MarkSystem.active_marks = {}
end

-- Register for entity destruction
signal.register("entity_destroyed", function(entity)
    MarkSystem.removeAll(entity)
end)

return MarkSystem
