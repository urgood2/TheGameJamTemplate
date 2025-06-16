local globals = require("init.globals")
require("registry")
local task = require("task.task")
require("ai.init") -- Read in ai scripts and populate the ai table
require("util.util")
local shader_prepass = require("shaders.prepass_example")

-- Represents game loop main module
main = {}


--------------------------------------------------------------------
-- 1. Define the script table that will live inside ScriptComponent
--------------------------------------------------------------------
local PlayerLogic = {
    -- Custom data carried by this table
    speed        = 150, -- pixels / second
    hp           = 10,

    -- Called once, right after the component is attached.
    init         = function(self)
        print("[player] init, entity-id =", self.id)
        self.x, self.y = 0, 0 -- give the table some state
    end,

    -- Called every frame by script_system_update()
    update       = function(self, dt)
        -- Simple movement example
        self.x = self.x + self.speed * dt
        -- print("[player] update; entity-id =", self.id, "position:", self.x, self.y)
        -- You still have full registry access through self.owner
        -- (e.g., self.owner:get(self.id, Transform).x = self.x)

        -- if not self._has_spawned_task then
        --     task.run_named_task(self, "blinker1", function()
        --         task.wait(5.0)
        --     end)

        --     task.run_named_task(self, "blinker2", function()
        --         task.wait(6.0)
        --     end)

        --     task.run_named_task(self, "blinker3", function()
        --         task.wait(7.0)
        --     end)

        --     self._has_spawned_task = true
        -- end

        -- if not self._spawned then
        --     for i, delay in ipairs({10, 20, 30}) do
        --       task.run_named_task(self, "t" .. i, function()
        --         print("▶︎ Task " .. i .. " start @ " .. tostring(os.clock()))
        --         --  os clock is imprecise, but the wait works as expected.
        --         task.wait(delay)
        --         print("✔︎ Task " .. i .. "  end @ " .. tostring(os.clock()))
        --       end)
        --     end
        --     self._spawned = true
        --   end
    end,

    on_collision = function(self, other)
        -- Called when this entity collides with another entity
        -- other is the other entity's id
        -- print("[player] on_collision; entity-id =", self.id, "collided with", other)
    end,

    -- Called just before the entity is destroyed
    destroy      = function(self)
        print("[player] destroy; final position:", self.x, self.y)
    end
}

-- Wraps v into the interval [−size, limit]
local function wrap(v, size, limit)
    if v > limit          then return -size end
    if v < -size           then return limit end
    return v
  end
  
function main.init()
    -- -- entity creation example
    bowser = create_ai_entity("kobold")      -- Create a new entity of ai type kobold

    registry:add_script(bowser, PlayerLogic) -- Attach the script to the entity

    animation_system.setupAnimatedObjectOnEntity(
        bowser,
        "blue_whale_anim", -- Default animation ID
        false,             -- ? generate a new still animation from sprite, don't set to true, causes bug
        nil,               -- shader_prepass, -- Optional shader pass config function
        true               -- Enable shadow
    )

    animation_system.resizeAnimationObjectsInEntityToFit(
        bowser,
        120, -- Width
        120  -- Height
    )

    -- create some krill entities
    local num_krill = 10
    local krill_entities = {}

    for i = 1, num_krill do
        -- 1) Spawn a new kobold AI entity
        local kr = create_ai_entity("kobold")
        krill_entities[#krill_entities + 1] = kr

        local anim = random_utils.random_element_string({
            "krill_1_anim",
            "krill_2_anim",
            "krill_3_anim",
            "krill_4_anim"
        })

        -- 2) Set up its animation & sizing
        animation_system.setupAnimatedObjectOnEntity(
            kr,
            anim,
            false,
            nil,
            true
        )
        animation_system.resizeAnimationObjectsInEntityToFit(
            kr,
            30,
            30
        )

        -- 3) Randomize its start position
        local tr = registry:get(kr, Transform)
        tr.actualX = random_utils.random_int(200, 800)
        tr.actualY = random_utils.random_int(200, 800)

        -- 4) Schedule its own movement timer, with a tag unique to this instance
        timer.every(
            random_utils.random_float(0.5, 1.5), -- randomize the delay between 0.5 and 1.5 seconds
            function()
                -- re-grab its transform each tick (in case component moved or was removed)
                local t = registry:get(kr, Transform)
                t.actualX = t.actualX + random_utils.random_int(-30, 30)
                t.actualY = t.actualY + random_utils.random_int(-30, 30)
            end,
            0,               -- infinite repetitions
            true,            -- start immediately
            nil,             -- no “after” callback
            "krill_move_timer_" .. i -- unique tag per krill
        )
    end



    -- add optional fullscreen shader which will be applied to the whole screen, can be removed later
    -- add_fullscreen_shader("flash")
    add_fullscreen_shader("shockwave")

    -- shader uniform manipulation example
    assert(globalShaderUniforms, "globalShaderUniforms not registered!")
    globalShaderUniforms:set("flash", "randomUniform", 0.5) -- Set a nonexistant uniform for the flash shader)

    timer.every(5.0, function()
        -- spawn a new timer that tweens the shader uniform
        -- Example 1: fixed 2-second tween
        globalShaderUniforms:set("shockwave", "radius", 0)
        timer.tween(
            5,                                                                     -- duration in seconds
            function() return globalShaderUniforms:get("shockwave", "radius") end, -- getter
            function(v) globalShaderUniforms:set("shockwave", "radius", v) end,    -- setter
            2.0                                                                    -- target_value
        )
    end, 0, true, nil, "shockwave_uniform_tween")

    -- manipulate the transformComp
    transformComp = registry:get(bowser, Transform)

    transformComp.actualX = 600
    transformComp.actualY = 800
    -- transformComp.actualW = 100
    -- transformComp.actualH = 100

    -- use a timer to update the position of Bowser every second
    timer.every(0.3, function()
        transformComp.actualX = transformComp.actualX + random_utils.random_int(-10, 10)
        transformComp.actualY = transformComp.actualY + random_utils.random_int(-10, 10)
        print("Bowser position = " .. transformComp.actualX .. ', ' .. transformComp.actualY)
        print("Bowser size = " .. transformComp.actualW .. ', ' .. transformComp.actualH)
        
        -- wrap X
        transformComp.actualX = wrap(
            transformComp.actualX,
            transformComp.actualW,  -- use width for horizontal wrap
            globals.screenWidth  -- use screen width from globals
        )
        -- wrap Y
        transformComp.actualY = wrap(
            transformComp.actualY,
            transformComp.actualH,  -- use height for vertical wrap
            globals.screenHeight -- use screen height from globals
        )
        
    end, 0, true, nil, "bowser_timer")

    -- add a task to the scheduler that will fade out the screen for 5 seconds
    local p1 = {
        update = function(self, dt)
            debug("Fade out screen")
            fadeOutScreen(1)
            task.wait(5.0)
        end
    }

    local p2 = {
        update = function(self, dt)
            fadeInScreen(1)
        end
    }

    scheduler:attach(p1, p2)


    -- assert(registry:has(bowser, Transform))


    -- assert(not registry:any_of(bowser, -1, -2))

    -- transform = registry:get(bowser, Transform)
    -- transform.actualX = 10
    -- print('Bowser position = ' .. transform.actualX .. ', ' .. transform.actualY)

    -- testing


    dump(ai)

    -- print("DEBUG: ActionResult.SUCCESS is", type(ActionResult.SUCCESS), ActionResult.SUCCESS)


    -- scheduler example

    local p1 = {
        update = function(self, dt)
            debug("Task 1 Start")
            task.wait(5.0)
            debug("Task 1 End after 5s")
        end
    }

    local p2 = {
        update = function(self, dt)
            debug("Task 2 Start")
            task.wait(5.0)
            debug("Task 2 End after 5s")
        end
    }

    local p3 = {
        update = function(self, dt)
            debug("Task 3 Start")
            task.wait(10.0)
            debug("Task 3 End after 10s")
        end
    }
    scheduler:attach(p1, p2, p3)
end

function main.update(dt)
    -- entity iteration example
    -- local view = registry:runtime_view(Transform)
    -- assert(view:size_hint() > 0)

    -- -- local koopa = registry:create()
    -- registry:emplace(koopa, Transform(100, -200))
    -- transform = registry:get(koopa, Transform)
    -- print('Koopa position = ' .. tostring(transform))

    -- assert(view:size_hint() == 2)

    -- view:each(function(entity)
    --     print('Iterating Transform entity: ' .. entity)
    --     -- registry:remove(entity, Transform)
    -- end)

    -- -- assert(view:size_hint() == 0)
    -- print ('All Transform entities processed, view size: ' .. view:size_hint())
end

function main.draw(dt)
    -- This is where you would handle rendering logic
    -- For now, we just print a message
    -- print("Drawing frame with dt: " .. dt)
end
