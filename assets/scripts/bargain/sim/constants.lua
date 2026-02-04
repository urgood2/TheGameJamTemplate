-- assets/scripts/bargain/sim/constants.lua

local constants = {}

constants.PHASES = {
    DEAL_CHOICE = "DEAL_CHOICE",
    PLAYER_INPUT = "PLAYER_INPUT",
    PLAYER_ACTION = "PLAYER_ACTION",
    ENEMY_ACTIONS = "ENEMY_ACTIONS",
    END_TURN = "END_TURN",
}

constants.RUN_STATES = {
    RUNNING = "running",
    VICTORY = "victory",
    DEATH = "death",
}

constants.MAX_INTERNAL_TRANSITIONS = 64
constants.MAX_STEPS_PER_RUN = 5000
constants.DIGEST_VERSION = "bargain.v1"

return constants
