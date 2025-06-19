

function spawnCircularBurstParticles(x, y, count, seconds) 
    
end
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
    gameObjectMethods.onClick = function(registry, e)
        
        debug("whale dust clicked")
        -- spawn a growing circle particle
        spawnCircularBurstParticles(x, y, 10, 1.0)
        
        debug("whale dust motion injected")
        -- jiggle
        transform.InjectDynamicMotion(e, 1, 50)
        
        local transformComp = registry:get(e, Transform)
        transformComp.scale = 3
        
        debug("whale dust remove timer added")
        -- remove some time later
        timer.after(0.5, function()
            registry:destroy(e)
        end,
        "whale_dust_remove")
    end
end


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