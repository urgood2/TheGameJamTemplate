

function spawnWhaleDust(x, y)
    e = animation_system.createAnimatedObjectWithTransform(
        "whale_dust_anim",
        false,
        x, 
        y, 
        nil, -- shader pass
        true -- shadow
    )
    
    -- jigglle on spawn
    transform.InjectDynamicMotionDefault(e)
    
    nodeComp = registry:get(e, GameObject)
    
    gameObjectState = nodeComp.state
    gameObjectState.clickEnabled = true
    gameObjectState.hoverEnabled = true
    gameObjectState.collisionEnabled = true
    
    gameObjectMethods = nodeComp.methods
    gameObjectMethods.onClick = function()
        
        -- spawn a growing circle particle
        spawnGrowingCircleParticle(x, y, 100, 100, 2.0)
        
        -- play sound effect
        audio.playSound("whale_dust")
        
        -- remove the whale dust entity
        entity_system.removeEntity(e)
    end
end

function 

function spawnGrowingCircleParticle(x, y, w, h, seconds)
    local p = particle.CreateParticle(
        Vec2(x,y),             -- world position
        Vec2(w,h),                 -- render size
        {
            renderType = particle.ParticleRenderType.CIRCLE_LINE,
            velocity   = Vec2(0,0), 
            acceleration = 3.0, -- gravity effect
            lifespan   = seconds,
            startColor = util.getColor("BLUE"),
            endColor   = util.getColor("RED"),
            rotationSpeed = 0,
            onUpdateCallback = function(particleComp, dt)
                
                -- make size grow exponentially over time
                particleComp.scale = particleComp.scale * math.exp(-dt * 0.5)  
                
                
            end,
        },
        nil -- optional animation info
    )
end