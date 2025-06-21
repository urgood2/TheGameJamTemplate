require("init.globals")
require("registry")
local task = require("task.task")
require("ai.init") -- Read in ai scripts and populate the ai table
require("util.util")
local shader_prepass = require("shaders.prepass_example")
require("core.entity_factory")
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
    
    -- Add black hole to the center of the screen
    black_hole = create_ai_entity("kobold")
    
    animation_system.setupAnimatedObjectOnEntity(
        black_hole,
        "black_hole_anim", -- Default animation ID
        false,             -- ? generate a new still animation from sprite, don't set to true, causes bug
        nil,               -- shader_prepass, -- Optional shader pass config function
        true               -- Enable shadow
    )
    
    blackholePipeline = registry:emplace(black_hole, shader_pipeline.ShaderPipelineComponent)
    blackHoleAnimPass = blackholePipeline:addPass("random_displacement_anim", true)-- inject atlas uniforms into the shader pass to allow it to be atlas aware
    
    -- make it spin
    timer.every(
        0.1, -- every 0.1 seconds
        function()
            local transform = registry:get(black_hole, Transform)
            transform.rotation = transform.rotation + 10 -- rotate by 10 degrees
        end,
        0, -- infinite repetitions
        true, -- start immediately
        nil, -- no "after" callback
        "black_hole_spin"
    )
    
    black_hole_transform = registry:get(black_hole, Transform)
    black_hole_transform.actualX = globals.screenWidth() / 2 - black_hole_transform.actualW / 2
    black_hole_transform.actualY = globals.screenHeight() / 2 - black_hole_transform.actualH / 2
    
    
    -- TODO: not working, need to debug why texture particle not showing
    -- local black_hole_particle = particle.CreateParticle(
    --     Vec2(black_hole_transform.actualX,black_hole_transform.actualY),             -- world position
    --     Vec2(300,300),                 -- render size
    --     {
    --         renderType = particle.ParticleRenderType.RECTANGLE_LINE,
    --         velocity   = Vec2(0,0),
    --         acceleration = 0, 
    --         lifespan   = -1, -- lives forever
    --         color = util.getColor("WHITE"),
    --         rotationSpeed = 360,
    --         onUpdateCallback = function(particleComp, dt)
    --             -- make the rotation speed undulate over time
    --             local frequency = 2.0 -- controls how fast the undulation happens
    --             local amplitude = 50  -- controls the range of speed variation
    --             particleComp.rotationSpeed = 360 + math.sin(os.clock() * frequency) * amplitude
    --             particleComp.scale = 1.0 + math.sin(os.clock() * frequency) * 0.1 -- make it pulse
                
    --         end,
    --     },
    --     {animationName = "black_hole_particle_anim"} -- optional animation info
    -- )
    
    -- -- create whale
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

        globals.krill_list[#globals.krill_list+1] = kr -- add to the global krill list
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
        
        -- kril shaders
        shaderPipelineComp = registry:emplace(kr, shader_pipeline.ShaderPipelineComponent)
    
        shaderPipelineComp:addPass("random_displacement_anim")

        -- 3) Randomize its start position
        local tr = registry:get(kr, Transform)
        tr.actualX = random_utils.random_int(200, globals.screenWidth() - 200)
        tr.actualY = random_utils.random_int(200, globals.screenHeight() - 200)

        -- 4) Schedule its own movement timer, with a tag unique to this instance
        timer.every(
            random_utils.random_float(0.5, 1.5), -- randomize the delay between 0.5 and 1.5 seconds
            function()
                -- make the krill move a litlte toward the whale
                local whaleTransform = registry:get(bowser, Transform)
                local krillTransform = registry:get(kr, Transform)
                local directionX = whaleTransform.actualX - krillTransform.actualX
                local directionY = whaleTransform.actualY - krillTransform.actualY
                -- normalize manually with x and y comps
                local length = math.sqrt(directionX^2 + directionX^2)
                if length > 0 then
                    directionX = directionX / length
                    directionY = directionY / length
                end
                -- move the krill towards the whale
                krillTransform.actualX = krillTransform.actualX + directionX * 10 -- move 10 pixels towards the whale
                krillTransform.actualY = krillTransform.actualY + directionY * 10 -- move 10 pixels towards the whale
                
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
    add_fullscreen_shader("tile_grid_overlay") -- to show tile grid
    

    -- add shader to specific layer

    debug(layers)
    debug(layers.sprites)
    
    -- layers.sprites:addPostProcessShader("flash")

    -- shader uniform manipulation example
    debug(globals.gravityWaveSeconds)
    timer.every(globals.gravityWaveSeconds, function()
        globals.timeUntilNextGravityWave = globals.gravityWaveSeconds -- reset the timer for the next gravity wave
        -- spawn a new timer that tweens the shader uniform
        -- Example 1: fixed 2-second tween
        globalShaderUniforms:set("shockwave", "radius", 0)
        timer.tween(
            5,      -- duration in seconds
            function() return globalShaderUniforms:get("shockwave", "radius") end, -- getter
            function(v) globalShaderUniforms:set("shockwave", "radius", v) end,    -- setter
            2, -- target_value
            "shockwave_tween_radius" -- unique tag for this tween
        )
        
        -- 4 seconds later, call the whale's onclick method
        timer.after(
            4.0, -- delay in seconds
            function()
                
                
                --TODO: add flash pass to the whale, remove it 4 seconds later
                local whaleShaderPipeline = registry:get(bowser, shader_pipeline.ShaderPipelineComponent)
                whaleShaderPipeline:addPass("flash") -- add the shockwave pass to the whale
                
                -- run something 3 times in a row
                timer.after(
                    0.5, -- delay in seconds
                    function()
                        -- call the whale's onclick method
                        local whaleGameObject = registry:get(bowser, GameObject)
                        if whaleGameObject.methods.onClick then
                            whaleGameObject.methods.onClick(registry, bowser)
                        end
                    end
                )
                timer.after(
                    1.0, -- delay in seconds
                    function()
                        local whaleGameObject = registry:get(bowser, GameObject)
                        if whaleGameObject.methods.onClick then
                            whaleGameObject.methods.onClick(registry, bowser)
                        end
                    end
                )
                timer.after(
                    1.9, -- delay in seconds
                    function()
                        local whaleGameObject = registry:get(bowser, GameObject)
                        if whaleGameObject.methods.onClick then
                            whaleGameObject.methods.onClick(registry, bowser)
                        end
                    end
                )
                
                timer.after(
                    6.0, -- delay in seconds
                    function()
                        local whaleShaderPipeline = registry:get(bowser, shader_pipeline.ShaderPipelineComponent)
                        whaleShaderPipeline:removePass("flash") -- remove the shockwave pass from the whale
                    end,
                    "whale_flash_after"
                )
            end,
            "whale_on_click_after"
        )
    end, 0, true, nil, "shockwave_uniform_tween")
    
    local p = particle.CreateParticle(
        Vec2(200,200),             -- world position
        Vec2(30,30),                 -- render size
        {
            renderType = particle.ParticleRenderType.RECTANGLE_FILLED,
            -- velocity   = Vec2(0,-10), random
            acceleration = 3.0, -- gravity effect
            lifespan   = 30.0,
            startColor = util.getColor("BLUE"),
            endColor   = util.getColor("RED"),
            rotationSpeed = 360,
            onUpdateCallback = function(particleComp, dt)
                
                --  make size smaller over time
                particleComp.scale = particleComp.scale - (dt * 0.1)
                
                if particleComp.scale < 0.1 then
                    particleComp.scale = 0.0 -- prevent it from going too small
                end
                
                -- debug("particleComp.scale = ", particleComp.scale)
                
                -- spin faster over time
                particleComp.rotationSpeed = particleComp.rotationSpeed + (dt * 20)
                
            end,
        },
        nil -- optional animation info
    )
    
    -- ui
    
    globals.currencyIconForText = animation_system.createAnimatedObjectWithTransform(
        "whale_dust_anim", -- animation ID
        false             -- use animation, not sprite id
    )
    
    local currencyIconDef = ui.definitions.wrapEntityInsideObjectElement(
        globals.currencyIconForText)
    
    local sliderTextMoving = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.currency_text"),  -- initial text
        16.0,                                 -- font size
        nil,                                  -- no style override
        "pulse=0.9,1.1"                       -- animation spec
    )
    
    sliderTextMoving.config.initFunc = function(registry, entity)
        localization.onLanguageChanged(function(newLang)
            TextSystem.Functions.setText(entity, localization.get("ui.currency_text", {currency = math.floor(globals.whale_dust_amount)}))
        end)
    end
    sliderTextMoving.config.updateFunc = function(r, entity, dt)
        local elementUIConfig = registry:get(entity, UIConfig)
        local objectEntity = elementUIConfig.object
        if not registry:valid(objectEntity) then
            return
        end
        
        local objectTextComp = registry:get(objectEntity, TextSystem.Text)
        
        
        local text = localization.get("ui.currency_text", {currency = math.floor(globals.whale_dust_amount)})
        
        if (objectTextComp.rawText ~= text) then
            TextSystem.Functions.setText(objectEntity, text)
        end
    end
    
    local sliderTemplate = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("GRAY"))
            
            :addNoMovementWhenDragged(true)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(currencyIconDef)
    :addChild(sliderTextMoving)
    :build()
    
    local newRoot =  UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.ROOT)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("BLACK"))
            :addMinHeight(50)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(sliderTemplate)
    :build()
    
    
    -- dump(ui.box)
    debug(ui)
    debug(ui.element)
    -- dump(newRoot)
    
    local newUIBox = ui.box.Initialize({x = globals.screenWidth() - 400, y = 10}, newRoot)
    
    local newUIBoxTransform = registry:get(newUIBox, Transform)
    local uiBoxComp = registry:get(newUIBox, UIBoxComponent)
    debug(newUIBox)
    debug(uiBoxComp)
    -- anchor to the top right corner of the screen
    newUIBoxTransform.actualX = globals.screenWidth() - newUIBoxTransform.actualW -- 10 pixels from the right edge
    newUIBoxTransform.actualY = 10 -- 10 pixels from the top edge
    
    -- TODO: test aligning to the inside of the game world container with a delay to let the update run
    timer.after(
        1.0, -- delay in seconds
        function()
            -- debug("Aligning newUIBox to the game world container")
            -- align the new UI box to the game world container
            --TODO: debug this, we need to get it working
            -- local uiBoxRole = registry:get(newUIBox, InheritedProperties)
            -- local uiBoxTransform = registry:get(newUIBox, Transform)
            -- transform.AssignRole(registry, newUIBox, InheritedPropertiesType.RoleInheritor, globals.gameWorldContainerEntity());

            -- local gameWorldContainerTransform = registry:get(globals.gameWorldContainerEntity(), Transform)
            -- debug("uiBox width = ", uiBoxTransform.actualW, "uiBox height = ", uiBoxTransform.actualH)
            -- debug("gameWorldContainer width = ", gameWorldContainerTransform.actualW, "gameWorldContainer height = ", gameWorldContainerTransform.actualH)
            -- uiBoxRole.flags = AlignmentFlag.HORIZONTAL_RIGHT | AlignmentFlag.ALIGN_TO_INNER_EDGES | AlignmentFlag.VERTICAL_TOP
        end
    )
    
    
    -- prestige button
    local prestigeButtonText = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.prestige_button"),  -- initial text
        20.0,                                 -- font size
        nil,                                  -- no style override
        "bump"                       -- animation spec
    )
    

    local prestigeButtonDef = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("GRAY"))
            -- :addShadow(true)
            :addEmboss(4.0)
            :addHover(true) -- needed for button effect
            :addButtonCallback(function()
                -- button click callback
                debug("Prestige button clicked!")
                local uibox_transform = registry:get(globals.ui.prestige_uibox, Transform)

                -- uibox_transform.actualY = uibox_transform.actualY + 300

                if globals.ui.prestige_window_open then
                    -- close the prestige window
                    globals.ui.prestige_window_open = false                    
                    uibox_transform.actualY = globals.screenHeight()
                else
                    -- open the prestige window
                    globals.ui.prestige_window_open = true
                    uibox_transform.actualY = globals.screenHeight() / 2 - uibox_transform.actualH / 2

                end
            end)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(prestigeButtonText)
    :build()

    local prestigeButtonRoot =  UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.ROOT)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("BLACK"))
            :addMinHeight(50)
            :addShadow(true)
            :addMaxWidth(300)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(prestigeButtonDef)
    :build()
    -- create a new UI box for the prestige button
    local prestigeButtonUIBox = ui.box.Initialize({x = globals.screenWidth() - 300, y = 450}, prestigeButtonRoot)
    
    -- right-align the prestige button UI box
    local prestigeButtonTransform = registry:get(prestigeButtonUIBox, Transform)
    prestigeButtonTransform.actualX = globals.screenWidth() - prestigeButtonTransform.actualW -- 10 pixels from the right edge
    


    -- prestige upgrades window
    
    local function makePrestigeWindowUpgradeButton(text, func)
        -- make new button text
        local buttonText = ui.definitions.getNewDynamicTextEntry(
            text,  -- initial text
            20.0,                                 -- font size
            nil,                                  -- no style override
            "pulse=0.9,1.1"                       -- animation spec
        )
        -- make new button template
        local buttonTemplate = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("GRAY"))
                :addEmboss(2.0)
                :addShadow(true)
                :addHover(true) -- needed for button effect
                :addButtonCallback(func)
                :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
                :addInitFunc(function(registry, entity)
                    -- something init-related here
                end)
                :build()
        )

        :addChild(buttonText)
        :build()

        return buttonTemplate
    end
    
    -- make a red X button 
    local closeButtonText = ui.definitions.getNewDynamicTextEntry(
        "Close",  -- initial text
        15.0,                                 -- font size
        nil,                                  -- no style override
        "pulse=0.9,1.1"                       -- animation spec
    )
    -- make a new close button template
    local closeButtonTemplate = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("RED"))
            :addEmboss(2.0)
            :addShadow(true)
            :addHover(true) -- needed for button effect
            :addButtonCallback(function()
                -- close the prestige window
                debug("Prestige window close button clicked!")
                globals.ui.prestige_window_open = false
                local uibox_transform = registry:get(globals.ui.prestige_uibox, Transform)
                uibox_transform.actualY = globals.screenHeight()  -- move it out of the screen
            end)
            :addAlign(AlignmentFlag.HORIZONTAL_RIGHT | AlignmentFlag.VERTICAL_TOP)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(closeButtonText)
    :build()
    
    
    -- vertical container for the prestige upgrades
    local prestigeUpgradesContainer = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.VERTICAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("BLACK"))
            :addMinWidth(300)
            :addMinHeight(400)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(makePrestigeWindowUpgradeButton(
        localization.get("ui.prestige_upgrade_1"),  -- initial text
        function(registry, entity)
        end
    ))
    :addChild(makePrestigeWindowUpgradeButton(
        localization.get("ui.prestige_upgrade_2"),  -- initial text
        function(registry, entity)
            debug("Prestige upgrade 2 clicked!")
        end
    ))
    :addChild(makePrestigeWindowUpgradeButton(
        localization.get("ui.prestige_upgrade_3"),  -- initial text
        function(registry, entity)
            debug("Prestige upgrade 3 clicked!")
        end
    ))
    :addChild(closeButtonTemplate)
    :build()

    -- uibox for the prestige upgrades
    local prestigeUpgradesContainerRoot = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.ROOT)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("GRAY"))
            :addMinHeight(400)
            :addMinWidth(300)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(prestigeUpgradesContainer)
    :build()

    -- create a new UI box for the prestige upgrades
    globals.ui.prestige_uibox = ui.box.Initialize({x = 350, y = globals.screenHeight()}, prestigeUpgradesContainerRoot)
    
    -- center the ui box X-axi
    local prestigeUiboxTransform = registry:get(globals.ui.prestige_uibox, Transform)
    prestigeUiboxTransform.actualX = globals.screenWidth() / 2 - prestigeUiboxTransform.actualW / 2
    
    -- ui for the buildings
    local buildingText = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.building_text"),  -- initial text
        20.0,                                 -- font size
        nil,                                  -- no style override
        "float"                       -- animation spec
    )
    
    local buildingTextGameObject = registry:get(buildingText.config.object, GameObject)
    -- set onhover & stop hover callbacks to show tooltip
    buildingTextGameObject.methods.onHover = function()
        debug("Building text entity hovered!")
        showTooltip(localization.get("ui.grav_wave_title"), localization.get("ui.grav_wave_desc"))
    end
    buildingTextGameObject.methods.onStopHover = function()
        debug("Building text entity stopped hovering!")
        hideTooltip()
    end
    -- make hoverable
    buildingTextGameObject.state.hoverEnabled = true
    buildingTextGameObject.state.collisionEnabled = true -- enable collision for the hover to work
    
    
    local buildingTextTemplate = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
    UIConfigBuilder.create()
        :addColor(util.getColor("GRAY"))
        :addMinHeight(50)
        :addProgressBar(true) -- enable progress bar effect
        :addProgressBarFullColor(util.getColor("BLUE"))
        :addProgressBarEmptyColor(util.getColor("WHITE"))
        :addProgressBarFetchValueLamnda(function(entity)
            -- return the timer value for the gravity wave thing
            -- debug("Fetching gravity wave seconds for entity: ", timer.get_delay("shockwave_uniform_tween"))
            return (globals.gravityWaveSeconds - globals.timeUntilNextGravityWave) / (timer.get_delay("shockwave_uniform_tween") or globals.gravityWaveSeconds)
        end)

        :addNoMovementWhenDragged(true)
        :addMinWidth(500)
        :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
        :addInitFunc(function(registry, entity)
            -- something init-related here
        end)
        :build()
    )
    :addChild(buildingText)
    :build()
    
    local buildingTextRoot =  UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.ROOT)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("BLACK"))
            :addMinHeight(50)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(buildingTextTemplate)
    :build()
    
    -- create a new UI box for the gravity wave progress bar
    local buildingTextUIBox = ui.box.Initialize({x = globals.screenWidth() - 400, y = 600}, buildingTextRoot)
    
    -- align top of the screen, centered
    local buildingTextTransform = registry:get(buildingTextUIBox, Transform)
    buildingTextTransform.actualX = globals.screenWidth() / 2 - buildingTextTransform.actualW / 2
    buildingTextTransform.actualY = 10 -- 10 pixels from the top edge
    
    
    
    
    
    
    
    
    
    -- Make a bottom UI box that will hold the purchase ui
    
    
    -- first upgrade ui (buildings)
    globals.building_upgrade_defs = {
        {
          id = "basic_dust_collector", -- the id of the building
          required = {},
          cost = {
            whale_dust = 30  -- cost in whale dust
          },
          unlocked = true,
          anim = "resonance_beacon_anim",
          ui_text_title = "ui.dust_collector_name", -- the ui text for the building
          ui_text_body = "ui.dust_collector_desc", -- the ui text for the building
        
          animation_entity = nil -- 
        },
        {
          id = "MK2_dust_collector", -- the id of the building
          required = {"basic_dust_collector"},
          cost = {
            whale_dust = 100  -- cost in whale dust
          },
          unlocked = false,
          anim = "gathererMK2Anim", -- the animation for the building
            ui_text_title = "ui.MK2_dust_collector_name", -- the ui text for the building
            ui_text_body = "ui.MK2_dust_collector_desc", -- the ui text for the building
          animation_entity = nil -- 
          
        },
        {
          id = "krill_home", -- the id of the building
          required = {},
          cost = {
            whale_dust = 50  -- cost in whale dust
          },
          unlocked = false,
          anim = "krillHomeSmallAnim", -- the animation for the building
          ui_text_title = "ui.krill_home_name", -- the ui text for the building
          ui_text_body = "ui.krill_home_desc", -- the ui text for the building
          animation_entity = nil -- 
        },
        {
          id = "krill_farm", -- the id of the building
          required = {"krill_home"},
          cost = {
            whale_dust = 400  -- cost in whale dust
          },
          unlocked = false,
          anim = "krillHomeLargeAnim", -- the animation for the building
          ui_text_title = "ui.krill_farm_name", -- the ui text for the building
          ui_text_body = "ui.krill_farm_desc", -- the ui text for the building
          animation_entity = nil -- 
        },
        {
          id = "whale_song_gatherer", -- the id of the building
          required = {"krill_farm", "basic_dust_collector", "MK2_dust_collector"},
          cost = {
            whale_dust = 1000  -- cost in whale dust
          },
          unlocked = false,
          anim = "dream_weaver_antenna_anim", -- the animation for the building,
          ui_text_title = "ui.whale_song_gatherer_name", -- the ui text for the building
            ui_text_body = "ui.whale_song_gatherer_desc", -- the ui text for the building
          animation_entity = nil -- 
        }
      }
      
    globals.selectedBuildingIndex = 1 -- the index of the currently selected building in the upgrade list
    
    -- "left" button
    local leftButtonText = ui.definitions.getNewDynamicTextEntry(
        "<",  -- initial text
        20.0,                                 -- font size
        nil,                                  -- no style override
        "pulse=0.9,1.1"                       -- animation spec
    )
    -- make new button template
    local leftButtonTemplate = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("GRAY"))
            -- :addShadow(true)
            :addEmboss(4.0)
            :addHover(true) -- needed for button effect
            :addButtonCallback(function()
                cycleBuilding(-1) -- decrement the selected building index
                -- debug("Left button clicked! Current building index: ", globals.selectedBuildingIndex)
            end)
            :addAlign(AlignmentFlag.HORIZONTAL_LEFT | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(leftButtonText)
    :build()
    
    -- middle text 
    --TODO: customize this based on update data
    globals.building_ui_animation_entity = animation_system.createAnimatedObjectWithTransform(
        globals.building_upgrade_defs[1].anim, -- animation ID
        false             -- use animation, not sprite id
    )
    local middleTextElement = ui.definitions.wrapEntityInsideObjectElement(globals.building_ui_animation_entity) -- wrap the text in an object element
    cycleBuilding(0) -- initialize the building UI with the first building
    
    -- make animatino hoverable
    local buildingUIAnimGameObject = registry:get(globals.building_ui_animation_entity, GameObject)
    buildingUIAnimGameObject.state.dragEnabled = false
    buildingUIAnimGameObject.state.hoverEnabled = true
    buildingUIAnimGameObject.state.clickEnabled = false
    buildingUIAnimGameObject.state.collisionEnabled = true
    
    
    
    -- right button
    local rightButtonText = ui.definitions.getNewDynamicTextEntry(
        ">",  -- initial text
        20.0,                                 -- font size
        nil,                                  -- no style override
        "pulse=0.9,1.1"                       -- animation spec
    )
    -- make new button template
    local rightButtonTemplate = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("GRAY"))
            -- :addShadow(true)
            :addEmboss(4.0)
            :addHover(true) -- needed for button effect
            :addButtonCallback(function()
                cycleBuilding(1) -- increment the selected building index
            end)
            :addAlign(AlignmentFlag.HORIZONTAL_RIGHT | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(rightButtonText)
    :build()
    
    
    -- buy button
    local buyButtonText = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.buy_button"),  -- initial text
        20.0,                                 -- font size
        nil,                                  -- no style override
        "rainbow"                       -- animation spec
    )
    -- make new button template
    local buyButtonTemplate = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("GRAY"))
            -- :addShadow(true)
            :addEmboss(4.0)
            :addHover(true) -- needed for button effect
            :addButtonCallback(function()
                -- button click callback
                debug("Buy button clicked!")
            end)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(buyButtonText)
    :build()
    
    
    -- second upgrade ui (converters)
    
    globals.converter_ui_animation_entity = nil
    globals.converter_defs = {
        { -- converts dust to crystal
          id = "dust_to_crystal", -- the id of the converter
          required_building = {"whale_song_gatherer"},
          required_converter = {},
          cost = {
            song_essence = 100  -- the stuff gathered by the whale song gatherer
          },
          unlocked = false,
          anim = "dust_to_crystal_converterAnim", -- the animation for the converter
          ui_text_title = "ui.dust_to_crystal_converter_name", -- the text to display in the ui for this converter
          ui_text_body = "ui.dust_to_crystal_converter_description" -- the text to display in the ui for this converter
        },
        { -- converts crystal to water
          id = "crystal_to_wafer", -- the id of the converter
          required_building = {"whale_song_gatherer"},
          required_converter = {"dust_to_crystal"},
          cost = {
            crystal = 100  -- the stuff gathered by dust_to_crystal converter
          },
          unlocked = false,
          anim = "3972-TheRoguelike_1_10_alpha_765.png", -- the animation for the converter
          ui_text_title = "ui.crystal_to_wafer_converter_name", -- the text to display in the ui for this converter
          ui_text_body = "ui.crystal_to_wafer_converter_description" -- the text to display in the ui for this converter
        },
        { -- converts water to krill
          id = "wafer_to_chip", -- the id of the converter
          required_building = {"whale_song_gatherer"},
          required_converter = {"crystal_to_wafer"},
          cost = {
            wafer = 100  -- the stuff gathered by  crystal_to_wafer converter
          },
          unlocked = false, 
          anim = "wafer_to_chip_converterAnim", -- the animation for the converter
          ui_text_title = "ui.wafer_to_chip_converter_name", -- the text to display in the ui for this converter
          ui_text_body = "ui.wafer_to_chip_converter_description" -- the text to display in the ui for this converter
        }
      }
      
    
    globals.selectedConverterIndex = 1 -- the index of the currently selected building in the upgrade list
    
    -- "left" button
    local leftButtonTextConverter = ui.definitions.getNewDynamicTextEntry(
        "<",  -- initial text
        20.0,                                 -- font size
        nil,                                  -- no style override
        "pulse=0.9,1.1"                       -- animation spec
    )
    -- make new button template
    local leftButtonTemplateConverter = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("GRAY"))
            -- :addShadow(true)
            :addEmboss(4.0)
            :addHover(true) -- needed for button effect
            :addButtonCallback(function()
                cycleConverter(-1)
            end)
            :addAlign(AlignmentFlag.HORIZONTAL_LEFT | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(leftButtonTextConverter)
    :build()
    
    -- middle text 
    --TODO: customize this based on update data
    globals.converter_ui_animation_entity = animation_system.createAnimatedObjectWithTransform(
        "locked_upgrade_anim", -- animation ID
        false             -- use animation, not sprite id
    )
    
    -- make globals.converter_ui_animation_entity hoverable
    local converterGameObject = registry:get(globals.converter_ui_animation_entity, GameObject)
    converterGameObject.state.dragEnabled = false
    converterGameObject.state.clickEnabled = false
    converterGameObject.state.hoverEnabled = true
    converterGameObject.state.collisionEnabled = true
    
    local middleTextElementConverter = ui.definitions.wrapEntityInsideObjectElement(globals.converter_ui_animation_entity) -- wrap the text in an object element
    
    cycleConverter(0) -- cycle to the first converter
    
    
    -- right button
    local rightButtonTextConverter = ui.definitions.getNewDynamicTextEntry(
        ">",  -- initial text
        20.0,                                 -- font size
        nil,                                  -- no style override
        "pulse=0.9,1.1"                       -- animation spec
    )
    -- make new button template
    local rightButtonTemplateConverter = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("GRAY"))
            -- :addShadow(true)
            :addEmboss(4.0)
            :addHover(true) -- needed for button effect
            :addButtonCallback(function()
                -- button click callback
                debug("Right button clicked!")
                cycleConverter(1)
            end)
            :addAlign(AlignmentFlag.HORIZONTAL_RIGHT | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(rightButtonTextConverter)
    :build()
    
    
    -- buy button
    local buyButtonTextConverter = ui.definitions.getNewDynamicTextEntry(
        localization.get("ui.buy_button"),  -- initial text
        20.0,                                 -- font size
        nil,                                  -- no style override
        "rainbow"                       -- animation spec
    )
    -- make new button template
    local buyButtonTemplateConverter = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("GRAY"))
            -- :addShadow(true)
            :addEmboss(4.0)
            :addHover(true) -- needed for button effect
            :addButtonCallback(function()
                -- button click callback
                debug("Buy button clicked!")
                
                -- create a new example converter entity
                local exampleConverter = create_ai_entity("kobold")
                
                animation_system.setupAnimatedObjectOnEntity(
                    exampleConverter,
                    "dust_to_crystal_converterAnim", -- Default animation ID
                    false,             -- ? generate a new still animation from sprite, don't set to true, causes bug
                    nil,               -- shader_prepass, -- Optional shader pass config function
                    true               -- Enable shadow
                )
                
                animation_system.resizeAnimationObjectsInEntityToFit(
                    exampleConverter,
                    60, -- width
                    60  -- height
                )
                
                -- make the object draggable
                local gameObjectState = registry:get(exampleConverter, GameObject).state
                gameObjectState.dragEnabled = true
                gameObjectState.clickEnabled = true
                gameObjectState.hoverEnabled = true
                gameObjectState.collisionEnabled = true
                
                -- create a new text entity
                local infoText = ui.definitions.getNewDynamicTextEntry(
                    "Drag me",  -- initial text
                    15.0,                                 -- font size
                    nil,                                  -- no style override
                    "bump"                       -- animation spec
                ).config.object
                
                -- make the text entity follow the converter entity
                transform.AssignRole(registry, infoText, InheritedPropertiesType.RoleInheritor, exampleConverter,
                InheritedPropertiesSync.Strong,
                InheritedPropertiesSync.Strong,
                InheritedPropertiesSync.Strong,
                InheritedPropertiesSync.Strong,
                Vec2(0, -20) -- offset the text above the converter
                );
                
                -- local textRole = registry:get(infoText, InheritedProperties)
                -- textRole.flags = AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_TOP
                
                
                -- now locate the converter entity in the game world
                local transformComp = registry:get(exampleConverter, Transform)
                transformComp.actualX = globals.screenWidth() / 2 - transformComp.actualW / 2 -- center it horizontally
                transformComp.actualY = globals.screenHeight()  - 300
                
                
                -- add onstopdrag method to the converter entity
                local gameObjectComp = registry:get(exampleConverter, GameObject)
                gameObjectComp.methods.onHover = function()
                    debug("Converter entity hovered! WHy not drag?")
                    
                end
                gameObjectComp.methods.onStopDrag = function()
                    debug("Converter entity stopped dragging!")
                    local gameObjectComp = registry:get(exampleConverter, GameObject)
                    -- get the grid that it's in, grid is 64 pixels wide
                    local gridX = math.floor(transformComp.actualX / 64)
                    local gridY = math.floor(transformComp.actualY / 64)
                    debug("Converter entity is in grid: ", gridX, gridY)
                    -- snap the entity to the grid, but center it in the grid cell
                    local magic_padding = 2
                    transformComp.actualX = gridX * 64 + 32 - transformComp.actualW / 2 + magic_padding-- center it in the grid cell
                    transformComp.actualY = gridY * 64 + 32 - transformComp.actualH / 2 + magic_padding -- center it in the grid cell
                    -- make the entity no longer draggable
                    gameObjectState.dragEnabled = false
                    gameObjectState.clickEnabled = false
                    gameObjectState.hoverEnabled = false
                    gameObjectState.collisionEnabled = false
                    -- remove the text entity
                    registry:destroy(infoText)
                    -- spawn particles at the converter's position center
                    spawnCircularBurstParticles(
                        transformComp.actualX + transformComp.actualW / 2,
                        transformComp.actualY + transformComp.actualH / 2,
                        20, -- number of particles
                        0.5 -- particle size
                    )
                    transform.InjectDynamicMotion(exampleConverter, 1.0, 1)
                    
                    
                end
                
            end)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(buyButtonTextConverter)
    :build()

    -- make a horizontal container for all upgrade ui
    local upgradeUIContainer = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.HORIZONTAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("BLACK"))
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(leftButtonTemplate)
    :addChild(middleTextElement)
    :addChild(rightButtonTemplate)
    :addChild(buyButtonTemplate)
    :addChild(leftButtonTemplateConverter)
    :addChild(middleTextElementConverter)
    :addChild(rightButtonTemplateConverter)
    :addChild(buyButtonTemplateConverter)
    :build()
    
    -- make a new upgrade UI root
    local upgradeUIRoot =  UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.ROOT)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("GRAY"))
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(upgradeUIContainer)
    :build()
    
    -- create a new UI box for the upgrade UI
    globals.ui.upgradeUIBox = ui.box.Initialize({x = 0, y = globals.screenHeight() - 50}, upgradeUIRoot)
    
    -- align the upgrade UI box to the bottom of the screen
    local upgradeUIBoxTransform = registry:get(globals.ui.upgradeUIBox, Transform)
    upgradeUIBoxTransform.actualX = globals.screenWidth() / 2 - upgradeUIBoxTransform.actualW / 2 -- center it horizontally
    upgradeUIBoxTransform.actualY = globals.screenHeight() - upgradeUIBoxTransform.actualH -- align to the bottom of the screen
    
    
    -- tooltip ui box that will follow the mouse cursor
    local tooltipTitleText = ui.definitions.getNewDynamicTextEntry(
        localization.get("sample tooltip title"),  -- initial text
        18.0,                                 -- font size
        nil,                                  -- no style override
        "rainbow"                       -- animation spec
    )
    globals.ui.tooltipTitleText = tooltipTitleText.config.object
    local tooltipBodyText = ui.definitions.getNewDynamicTextEntry(
        localization.get("Sample tooltip body text"),  -- initial text
        15.0,                                 -- font size
        nil,                                  -- no style override
        ""                       -- animation spec
    )
    globals.ui.tooltipBodyText = tooltipBodyText.config.object
    
    -- make vertical container for the tooltip
    local tooltipContainer = UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.VERTICAL_CONTAINER)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("GRAY"))
            :addMinHeight(50)
            :addMinWidth(200)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(tooltipTitleText)
    :addChild(tooltipBodyText)
    :build()
    -- make a new tooltip root
    local tooltipRoot =  UIElementTemplateNodeBuilder.create()
    :addType(UITypeEnum.ROOT)
    :addConfig(
        UIConfigBuilder.create()
            :addColor(util.getColor("BLACK"))
            :addMinHeight(50)
            :addAlign(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_CENTER)
            :addInitFunc(function(registry, entity)
                -- something init-related here
            end)
            :build()
    )
    :addChild(tooltipContainer)
    :build()
    -- create a new UI box for the tooltip
    
    globals.ui.tooltipUIBox = ui.box.Initialize({x = 300, y = globals.screenHeight()}, tooltipRoot)
    
    
    
    
    -- manipulate the transformComp
    transformComp = registry:get(bowser, Transform)
    nodeComp = registry:get(bowser, GameObject)
    
    gameObjectState = nodeComp.state
    gameObjectState.clickEnabled = true
    gameObjectState.hoverEnabled = true
    -- gameObjectState.dragEnabled = true
    gameObjectState.collisionEnabled = true
    
    local methods = nodeComp.methods
    
    debug (methods)
    
    methods.onHover = function()
        -- debug("whale hovered!")
        showTooltip(
            localization.get("ui.whale_title"), 
            localization.get("ui.whale_body")
        )
        
    end
    methods.onStopHover = function()
        -- debug("whale stopped hovering!")
        -- reset the tooltip text
        
        -- hide the tooltip UI box
        
        hideTooltip()
    end
    methods.onClick = function(registry, e) 
        debug("whale clicked!")
        
        transform.InjectDynamicMotion(e, 0.4, 15) -- add dynamic motion to the whale
        
        local transformComp = registry:get(e, Transform)
        
        spawnWhaleDust(transformComp.actualX + random_utils.random_int(50, 100),
                        transformComp.actualY + random_utils.random_int(50, 100))
    end

    shaderPipelineComp = registry:emplace(bowser, shader_pipeline.ShaderPipelineComponent)
    
    -- shaderPipelineComp:addPass("flash")
    -- shaderPipelineComp:addPass("random_displacement_anim")
    -- shaderPipelineComp:addPass("negative_shine")

    transformComp.actualX = 800
    transformComp.actualY = 800
    -- transformComp.actualW = 100
    -- transformComp.actualH = 100
    
    -- ===================================================================
-- 1. Configuration Parameters (Tweak these to change the effect!)
-- ===================================================================

    -- Define the center of the orbit (e.g., the center of the screen)
    -- NOTE: Replace 800 and 600 with your actual screen dimensions!
    local centerX = globals.screenWidth() / 2
    local centerY = globals.screenHeight() / 2

    -- Orbit properties
    local orbitRadius = 300.0  -- How far from the center to orbit, in pixels.
    local baseSpeed = 0.1      -- The average speed of the orbit (in radians per second).

    -- Speed fluctuation properties
    local speedFluctuationAmount = 0.5 -- How much the speed varies. 0 is constant, 1 is drastic.
    local speedFluctuationFrequency = 1.0 -- How quickly the speed oscillates. Higher is faster.

    -- ===================================================================
    -- 2. State Variables (Do not change these)
    -- ===================================================================
    -- We define these outside the timer's function so they "remember" their
    -- values between each call.
    local orbitAngle = 0.0     -- The current angle on the circle, in radians.
    local elapsedTime = 0.0    -- A simple clock to drive the speed fluctuation.
    local currentSpeed = baseSpeed
    
    local loopDelta = 0.01 -- How often to update the position, in seconds.
    -- use a timer to update the position of Bowser every second
    timer.every(loopDelta, function()
        
        local transformComp = registry:get(bowser, Transform)
       
        -- Step A: Update the total elapsed time for this effect
        elapsedTime = elapsedTime + loopDelta

        -- Step B: Calculate the speed fluctuation using a sine wave
        -- This creates a smooth "breathing" or "pulsing" effect for the speed.
        local speedModifier = math.sin(elapsedTime * speedFluctuationFrequency)
        currentSpeed = baseSpeed + (speedFluctuationAmount * speedModifier)
        
        -- Step C: Update the orbit angle based on the current speed
        -- We multiply by dt to ensure the speed is consistent regardless of the timer interval.
        orbitAngle = orbitAngle + (currentSpeed * loopDelta)
        
        -- Step D: Calculate the new X and Y position on the circle using trigonometry
        local newX = centerX + orbitRadius * math.cos(orbitAngle)
        local newY = centerY + orbitRadius * math.sin(orbitAngle)
        
        -- Step E: Apply the new position directly to the transform component
        transformComp.actualX = newX
        transformComp.actualY = newY        
        end, 0, true, nil, "bowser_timer")
    
    -- every now and then, make the whale sing.
    
    timer.every(
    --TODO: the dealy should be configurable 
        random_utils.random_float(20, 30),
        function()
            
            -- timer after to rotate the whale
            timer.after(
                0.5, -- delay in seconds
                function()
                    local transform = registry:get(bowser, Transform)
                    transform.rotation = transform.rotation - 30
                end,
                "whale_rotate_after"
            )
            
            timer.after(
                0.8, -- delay in seconds
                function()
                    
                    
                    -- spawn particles 
                    timer.after(
                        0.1, -- delay in seconds
                        function()
                            local transform = registry:get(bowser, Transform)
                            -- spawn particles 
                            spawnCircularBurstParticles(
                                transform.actualX +transform.actualW / 2 ,
                                transform.actualY + transform.actualH / 2 ,
                                40, -- number of particles
                                1 
                            )
                        end,
                        nil
                    )
                    
                    timer.after(
                        0.2, -- delay in seconds
                        function()
                            local transform = registry:get(bowser, Transform)
                            -- spawn particles 
                            spawnCircularBurstParticles(
                                transform.actualX + transform.actualW / 2 ,
                                transform.actualY + transform.actualH / 2 ,
                                40, -- number of particles
                                0.3 
                            )
                        end,
                        nil
                    )
                    
                    timer.after(
                        0.3, -- delay in seconds
                        function()
                            local transform = registry:get(bowser, Transform)
                            -- spawn particles 
                            spawnCircularBurstParticles(
                                transform.actualX + transform.actualW / 2 ,
                                transform.actualY + transform.actualH / 2 ,
                                40, -- number of particles
                                1.5 
                            )
                        end,
                        nil
                    )
                    
                    timer.after(
                        0.4, -- delay in seconds
                        function()
                            local transform = registry:get(bowser, Transform)
                            -- spawn particles 
                            spawnGrowingCircleParticle(
                                transform.actualX,
                                transform.actualY,
                                100, -- width
                                100, -- height
                                1 -- seconds to grow
                            )
                        end,
                        nil
                    )
                end,
                "whale_particles"
            )
            
            timer.after(
                2.0, -- delay in seconds
                function()
                    local transform = registry:get(bowser, Transform)
                    transform.rotation = 0 -- reset rotation
                end,
                "whale_rotate_after_particles"
            )
            
            -- tween volume of whale sound
            -- TODO:
        end,
        0,               -- infinite repetitions
        true,            -- start immediately
        nil,             -- no “after” callback
        "whale_move_timer" -- unique tag per krill
    )

    -- add a task to the scheduler that will fade out the screen for 5 seconds
    local p1 = {
        update = function(self, dt)
            debug("Fade out screen")
            -- fadeOutScreen(0.1)
            add_fullscreen_shader("screen_tone_transition") -- Add the fade out shader
            globalShaderUniforms:set("screen_tone_transition", "position", 0) -- Set initial value to 1.0 (dark)
            -- timer tween
            timer.tween(
                2.0, -- duration in seconds
                function() return globalShaderUniforms:get("screen_tone_transition", "position") end, -- getter
                function(v) globalShaderUniforms:set("screen_tone_transition", "position", v) end, -- setter
                1.0 -- target value
            )
            task.wait(5.0)
        end
    }

    local p2 = {
        update = function(self, dt)
            -- fadeInScreen(1)
            remove_fullscreen_shader("screen_tone_transition") -- Remove the fade out shader
        end
    }

    scheduler:attach(p1, p2)


    -- assert(registry:has(bowser, Transform))


    -- assert(not registry:any_of(bowser, -1, -2))

    -- transform = registry:get(bowser, Transform)
    -- transform.actualX = 10
    -- print('Bowser position = ' .. transform.actualX .. ', ' .. transform.actualY)

    -- testing


    -- dump(ai)

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
    globals.timeUntilNextGravityWave = globals.timeUntilNextGravityWave - dt
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
