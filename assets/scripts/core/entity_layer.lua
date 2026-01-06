local entity_layer = {}

local VALID_LAYERS = {
    sprites = true,
    ui = true,
    background = true,
}

local customLayerEntities = {}

function entity_layer.get(entity)
    if not entity or not registry:valid(entity) then
        return "sprites"
    end
    return customLayerEntities[entity] or "sprites"
end

function entity_layer.set(entity, layerName)
    if not VALID_LAYERS[layerName] then
        error("Invalid layer name: " .. tostring(layerName) .. ". Valid: sprites, ui, background")
    end
    
    if not entity or not registry:valid(entity) then
        return
    end
    
    local currentLayer = customLayerEntities[entity]
    
    if layerName == "sprites" then
        if currentLayer and currentLayer ~= "sprites" then
            if registry:has(entity, ObjectAttachedToUITag) then
                registry:remove(entity, ObjectAttachedToUITag)
            end
            customLayerEntities[entity] = nil
        end
        return
    end
    
    if not registry:has(entity, ObjectAttachedToUITag) then
        registry:emplace(entity, ObjectAttachedToUITag)
    end
    
    customLayerEntities[entity] = layerName
end

function entity_layer.draw()
    if not layers then return end
    
    for entity, layerName in pairs(customLayerEntities) do
        if registry:valid(entity) then
            local targetLayer = layers[layerName]
            if targetLayer and layer and layer.queueDrawTransformEntityAnimationPipeline then
                local loc = component_cache.get(entity, layer.LayerOrderComponent)
                local z = loc and loc.zIndex or 0
                
                layer.queueDrawTransformEntityAnimationPipeline(
                    targetLayer,
                    function(c)
                        c.e = entity
                        c.registry = registry
                    end,
                    z,
                    layer.DrawCommandSpace.World
                )
            end
        else
            customLayerEntities[entity] = nil
        end
    end
end

function entity_layer.cleanup(entity)
    if entity then
        customLayerEntities[entity] = nil
    end
end

function entity_layer.clear()
    customLayerEntities = {}
end

return entity_layer
