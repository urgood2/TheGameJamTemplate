require("core.globals")
require("registry")
local task = require("task.task")
require("ai.init") -- Read in ai scripts and populate the ai table
require("util.util")
require("ui.ui_defs")
local shader_prepass = require("shaders.prepass_example")
require("core.entity_factory")
-- Represents game loop main module
main = {}

GAMESTATE = {
    MAIN_MENU = 0,
    IN_GAME = 1
}

globals.currentGameState = GAMESTATE.MAIN_MENU -- Set the initial game state to IN_GAME

function initMainMenu()
    globals.currentGameState = GAMESTATE.MAIN_MENU -- Set the game state to MAIN_MENU
    setCategoryVolume("effects", 0.2) -- Set the effects volume to 0.5
    
    
    --TESTING BELOW
    local kr = create_ai_entity("kobold")
    
    -- 2) Set up its animation & sizing
    animation_system.setupAnimatedObjectOnEntity(
        kr,
        "blue_whale_anim",
        false,
        nil,
        true
    )
    animation_system.resizeAnimationObjectsInEntityToFit(
        kr,
        200,
        200
    )
    
    -- make them hoverable
    local gameObject = registry:get(kr, GameObject)
    gameObject.state.dragEnabled = true
    gameObject.state.hoverEnabled = true
    gameObject.state.collisionEnabled = true
    gameObject.state.clickEnabled = true
    
    -- kril shaders
    shaderPipelineComp = registry:emplace(kr, shader_pipeline.ShaderPipelineComponent)

    -- shaderPipelineComp:addPass("random_displacement_anim")
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
  
function main.init()
    changeGameState(GAMESTATE.MAIN_MENU) -- Initialize the game in the IN_GAME state
end

function main.update(dt)
    
end

function main.draw(dt)
   
end
