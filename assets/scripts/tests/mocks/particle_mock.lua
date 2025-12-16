-- assets/scripts/tests/mocks/particle_mock.lua
local ParticleMock = {}

ParticleMock.calls = {}
ParticleMock.created_entities = {}
ParticleMock._next_entity_id = 1000

-- Mock RenderSpace enum
ParticleMock.RenderSpace = {
    WORLD = "World",
    SCREEN = "Screen"
}

-- Mock ParticleRenderType enum
ParticleMock.ParticleRenderType = {
    TEXTURE = 0,
    RECTANGLE_LINE = 1,
    RECTANGLE_FILLED = 2,
    CIRCLE_LINE = 3,
    CIRCLE_FILLED = 4,
    ELLIPSE = 5,
    LINE = 6,
    ELLIPSE_STRETCH = 7,
    LINE_FACING = 8
}

function ParticleMock.CreateParticle(location, size, opts, animConfig, tag)
    local entity = ParticleMock._next_entity_id
    ParticleMock._next_entity_id = ParticleMock._next_entity_id + 1

    table.insert(ParticleMock.calls, {
        fn = "CreateParticle",
        args = {
            location = location,
            size = size,
            opts = opts,
            animConfig = animConfig,
            tag = tag
        },
        returned = entity
    })

    ParticleMock.created_entities[entity] = {
        location = location,
        size = size,
        opts = opts,
        animConfig = animConfig,
        tag = tag
    }

    return entity
end

function ParticleMock.reset()
    ParticleMock.calls = {}
    ParticleMock.created_entities = {}
    ParticleMock._next_entity_id = 1000
end

function ParticleMock.get_last_call()
    return ParticleMock.calls[#ParticleMock.calls]
end

function ParticleMock.get_call_count()
    return #ParticleMock.calls
end

return ParticleMock
