require("core.globals")
require("registry")
require("ai.init") -- Read in ai scripts and populate the ai table
require("util.util")
require("ui.ui_defs")
require("core.entity_factory")

local shader_prepass = require("shaders.prepass_example")
local task = require("task.task")


-- Represents game loop main module
main = {}

-- Game state (used only in lua)
GAMESTATE = {
    MAIN_MENU = 0,
    IN_GAME = 1
}

-- Set the initial game state
globals.currentGameState = GAMESTATE.MAIN_MENU 

function initMainMenu()
    globals.currentGameState = GAMESTATE.MAIN_MENU -- Set the game state to MAIN_MENU
    setCategoryVolume("effects", 0.2) -- Set the effects volume to 0.5
    
    
    --TESTING BELOW
    local kr = create_ai_entity("kobold")
    
    -- 2) Set up its animation & sizing
    animation_system.setupAnimatedObjectOnEntity(
        kr,
        "krill_1_anim",
        false, -- true if this is just an image rather than an animation
        nil,
        false -- shadow?
    )
    animation_system.resizeAnimationObjectsInEntityToFit(
        kr,
        32,
        32
    )
    
    -- make them hoverable
    local gameObject = registry:get(kr, GameObject)
    gameObject.state.dragEnabled = true
    gameObject.state.hoverEnabled = true
    gameObject.state.collisionEnabled = true
    gameObject.state.clickEnabled = true
    
    -- kril shaders
    shaderPipelineComp = registry:emplace(kr, shader_pipeline.ShaderPipelineComponent)
    shaderPipelineComp:addPass("random_displacement_anim")
    -- shaderPipelineComp:addPass("flash")
    
    -- try overlay over base sprite
    shaderPipelineComp:addOverlay(shader_pipeline.OverlayInputSource.PostPassResult, "custom_polychrome")
    -- shaderPipelineComp:addOverlay(shader_pipeline.OverlayInputSource.BaseSprite, "foil")
    
    -- every frame
    shaders.registerUniformUpdate("custom_polychrome", function ()
        globalShaderUniforms:set("custom_polychrome", "time", os.clock())
    end)
    
    -- test layer shaders
    -- add_fullscreen_shader("random_displacement_anim")
    -- add_fullscreen_shader("palette_quantize")
    -- add_fullscreen_shader("flash")
    add_fullscreen_shader("spotlight")
    -- layers.finalOutput:addPostProcessShader("palette_quantize")
    -- layers.finalOutput:addPostProcessShader("flash")
    
    
    -- -- make second krill
    -- local kr2 = create_ai_entity("kobold")
    -- -- 2) Set up its animation & sizing
    -- animation_system.setupAnimatedObjectOnEntity(
        
    --     kr2,
    --     "krill_2_anim",
    --     false,
    --     nil,
    --     true
    -- )
    -- animation_system.resizeAnimationObjectsInEntityToFit(
    --     kr2,
    --     200,
    --     200
    -- )
    
    -- transform.AssignRole(registry, kr2, InheritedPropertiesType.RoleInheritor, kr, InheritedPropertiesSync.Strong, InheritedPropertiesSync.Strong, InheritedPropertiesSync.Strong, InheritedPropertiesSync.Strong)
    
    -- debug("Created second krill entity with role inheritor, id:", kr2) -- Debug message to confirm creation of second krill
    
    -- kr2Role = registry:get(kr2, InheritedProperties)
    
    -- debug("krill 2 role flags before assignment:", kr2Role.flags.alignment) -- Debug message to check initial flags
    
    -- kr2Role.flags:addFlag(AlignmentFlag.HORIZONTAL_CENTER | AlignmentFlag.VERTICAL_TOP | AlignmentFlag.ALIGN_TO_INNER_EDGES)
    
    -- debug("krill 2 role flags after assignment:", kr2Role.flags.alignment) -- Debug message to check flags after assignment
end

function initMainGame()
    debug("Initializing main game...") -- Debug message to indicate the game is starting
    globals.currentGameState = GAMESTATE.IN_GAME -- Set the game state to IN_GAME
end

function changeGameState(newState)
    -- Check if the new state is different from the current state
    if newState == GAMESTATE.MAIN_MENU then
        initMainMenu()
    elseif newState == GAMESTATE.IN_GAME then
        initMainGame()
    else
        error("Invalid game state: " .. tostring(newState))
    end
    globals.currentGameState = newState -- Update the current game state
end
  
-- Main function to initialize the game. Called at the start of the game.
function main.init()
    
    -- create a timer that checks for open tooltips
    timer.every(1, function()
        if registry:valid(globals.inputState.cursor_hovering_target) == false or globals.inputState.cursor_hovering_target == globals.gameWorldContainerEntity()  then
            hideTooltip() -- Hide the tooltip if the cursor is not hovering over any target
        end
    end,
    0, -- start immediately)
    true,
    nil, -- no "after" callback
    "tooltip_hide_timer" -- unique tag for this timer
    )
    
    changeGameState(GAMESTATE.MAIN_MENU) -- Initialize the game in the IN_GAME state
end

function main.update(dt)
    
end

function main.draw(dt)
   
end
