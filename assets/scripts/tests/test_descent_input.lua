-- assets/scripts/tests/test_descent_input.lua
--[[
================================================================================
DESCENT INPUT AND MOVEMENT TESTS
================================================================================
Validates input handling, movement, bump attacks, and key repeat policy.

Acceptance criteria:
- Legal move consumes 1 turn
- Illegal move consumes 0 turns
- Bump attack consumes 1 turn
- Key repeat: 1 action per player turn
]]

local t = require("tests.test_runner")
local Input = require("descent.input")
local ActionsPlayer = require("descent.actions_player")
local Map = require("descent.map")
local Combat = require("descent.combat")

--------------------------------------------------------------------------------
-- Input Module Tests
--------------------------------------------------------------------------------

t.describe("Descent Input", function()
    t.before_each(function()
        Input.init()
    end)

    t.it("maps direction keys to actions", function()
        local action = Input.poll({ w = true })
        t.expect(action).to_not_be(nil)
        t.expect(action.type).to_be("move")
        t.expect(action.dy).to_be(-1)  -- north
        t.expect(action.dx).to_be(0)
    end)

    t.it("returns nil when no keys pressed", function()
        local action = Input.poll({})
        t.expect(action).to_be(nil)
    end)

    t.it("enforces key repeat prevention", function()
        -- First press returns action
        local action1 = Input.poll({ w = true })
        t.expect(action1).to_not_be(nil)
        
        -- Mark action consumed
        Input.consume_action()
        
        -- Same key press returns nil (consumed this turn)
        local action2 = Input.poll({ w = true })
        t.expect(action2).to_be(nil)
    end)

    t.it("resets action consumed on new turn", function()
        -- First action
        local action1 = Input.poll({ w = true })
        t.expect(action1).to_not_be(nil)
        Input.consume_action()
        
        -- Consumed this turn
        t.expect(Input.is_action_consumed()).to_be(true)
        
        -- New turn starts
        Input.on_turn_start(1)
        
        -- Action available again
        t.expect(Input.is_action_consumed()).to_be(false)
        Input.reset()  -- Reset key states for clean test
        Input.init()
        local action2 = Input.poll({ w = true })
        t.expect(action2).to_not_be(nil)
    end)

    t.it("detects key just pressed vs held", function()
        -- First check - not pressed
        t.expect(Input.is_key_just_pressed("w", true)).to_be(true)
        
        -- Update state
        Input.update_key_states({ w = true })
        
        -- Now it's held, not just pressed
        t.expect(Input.is_key_just_pressed("w", true)).to_be(false)
        
        -- Release and press again
        Input.update_key_states({ w = false })
        t.expect(Input.is_key_just_pressed("w", true)).to_be(true)
    end)

    t.it("maps wait key correctly", function()
        local action = Input.poll({ ["."] = true })
        t.expect(action).to_not_be(nil)
        t.expect(action.type).to_be("wait")
    end)

    t.it("maps pickup key correctly", function()
        local action = Input.poll({ g = true })
        t.expect(action).to_not_be(nil)
        t.expect(action.type).to_be("pickup")
    end)

    t.it("maps stairs keys correctly", function()
        Input.init()
        local action_down = Input.poll({ [">"] = true })
        t.expect(action_down).to_not_be(nil)
        t.expect(action_down.type).to_be("stairs")
        t.expect(action_down.direction).to_be("down")
        
        Input.init()
        local action_up = Input.poll({ ["<"] = true })
        t.expect(action_up).to_not_be(nil)
        t.expect(action_up.type).to_be("stairs")
        t.expect(action_up.direction).to_be("up")
    end)
end)

--------------------------------------------------------------------------------
-- Player Actions Tests
--------------------------------------------------------------------------------

t.describe("Descent Player Actions", function()
    local player, map, game_state

    t.before_each(function()
        Input.init()
        
        -- Create a simple test map
        map = Map.new(10, 10)
        for x = 1, 10 do
            for y = 1, 10 do
                Map.set_tile(map, x, y, Map.TILE.FLOOR)
            end
        end
        -- Add some walls
        Map.set_tile(map, 5, 5, Map.TILE.WALL)
        
        -- Create player
        player = {
            x = 3,
            y = 3,
            hp = 20,
            hp_max = 20,
            weapon_base = 5,
            str = 3,
            species_bonus = 0,
            dex = 10,
        }
        
        game_state = {
            player = player,
            map = map,
        }
        
        ActionsPlayer.init(player, Map)
    end)

    t.it("legal move consumes 1 turn", function()
        local action = { type = "move", dx = 1, dy = 0 }
        local result = ActionsPlayer.execute(action, game_state)
        
        t.expect(result.result).to_be("success")
        t.expect(result.turns).to_be(1)
        t.expect(player.x).to_be(4)
        t.expect(player.y).to_be(3)
    end)

    t.it("illegal move into wall consumes 0 turns", function()
        -- Move player next to wall
        player.x = 4
        player.y = 5
        
        local action = { type = "move", dx = 1, dy = 0 }  -- into wall at 5,5
        local result = ActionsPlayer.execute(action, game_state)
        
        t.expect(result.result).to_be("blocked")
        t.expect(result.turns).to_be(0)
        t.expect(player.x).to_be(4)  -- unchanged
        t.expect(player.y).to_be(5)
    end)

    t.it("move with zero delta is invalid", function()
        local action = { type = "move", dx = 0, dy = 0 }
        local result = ActionsPlayer.execute(action, game_state)
        
        t.expect(result.result).to_be("invalid")
        t.expect(result.turns).to_be(0)
    end)

    t.it("wait action consumes 1 turn", function()
        local action = { type = "wait" }
        local result = ActionsPlayer.execute(action, game_state)
        
        t.expect(result.result).to_be("success")
        t.expect(result.turns).to_be(1)
    end)

    t.it("can_move returns correct status", function()
        -- Clear tile
        local can, reason = ActionsPlayer.can_move(1, 0, game_state)
        t.expect(can).to_be(true)
        t.expect(reason).to_be("clear")
        
        -- Wall
        player.x = 4
        player.y = 5
        local can_wall, reason_wall = ActionsPlayer.can_move(1, 0, game_state)
        t.expect(can_wall).to_be(false)
        t.expect(reason_wall).to_be("unwalkable")
    end)

    t.it("get_action_at returns correct action type", function()
        local action_type = ActionsPlayer.get_action_at(1, 0, game_state)
        t.expect(action_type).to_be("move")
        
        player.x = 4
        player.y = 5
        local blocked_type = ActionsPlayer.get_action_at(1, 0, game_state)
        t.expect(blocked_type).to_be("blocked")
    end)
end)

--------------------------------------------------------------------------------
-- Bump Attack Tests
--------------------------------------------------------------------------------

t.describe("Descent Bump Attack", function()
    local player, enemy, map, game_state, mock_enemy_module

    t.before_each(function()
        Input.init()
        
        -- Create test map
        map = Map.new(10, 10)
        for x = 1, 10 do
            for y = 1, 10 do
                Map.set_tile(map, x, y, Map.TILE.FLOOR)
            end
        end
        
        -- Create player
        player = {
            x = 3,
            y = 3,
            hp = 20,
            hp_max = 20,
            weapon_base = 10,
            str = 5,
            species_bonus = 0,
            dex = 10,
        }
        
        -- Create enemy
        enemy = {
            x = 4,
            y = 3,
            hp = 10,
            hp_max = 10,
            armor = 2,
            evasion = 0,
            alive = true,
            name = "test_enemy",
        }
        
        -- Mock enemy module
        mock_enemy_module = {
            get_all = function()
                return { enemy }
            end,
            get = function(id)
                return enemy
            end,
        }
        
        game_state = {
            player = player,
            map = map,
            rng = Combat.scripted_rng({ 1 }),  -- Always hit
        }
        
        ActionsPlayer.init(player, Map, Combat)
        ActionsPlayer.set_enemy(mock_enemy_module)
    end)

    t.it("bump attack consumes 1 turn", function()
        local action = { type = "move", dx = 1, dy = 0 }  -- into enemy
        local result = ActionsPlayer.execute(action, game_state)
        
        t.expect(result.result).to_be("success")
        t.expect(result.action).to_be("attack")
        t.expect(result.turns).to_be(1)
    end)

    t.it("bump attack deals damage to enemy", function()
        local initial_hp = enemy.hp
        local action = { type = "move", dx = 1, dy = 0 }
        local result = ActionsPlayer.execute(action, game_state)
        
        t.expect(result.hit).to_be(true)
        t.expect(result.damage).to_be_greater_than(0)
        t.expect(enemy.hp).to_be_less_than(initial_hp)
    end)

    t.it("bump attack marks killed enemy as dead", function()
        enemy.hp = 1  -- Low HP
        local action = { type = "move", dx = 1, dy = 0 }
        local result = ActionsPlayer.execute(action, game_state)
        
        t.expect(enemy.hp).to_be_less_than_or_equal(0)
        t.expect(enemy.alive).to_be(false)
        t.expect(result.killed).to_be(true)
    end)

    t.it("get_action_at returns attack for enemy tile", function()
        local action_type = ActionsPlayer.get_action_at(1, 0, game_state)
        t.expect(action_type).to_be("attack")
    end)

    t.it("can_move returns true with bump_attack reason for enemy", function()
        local can, reason = ActionsPlayer.can_move(1, 0, game_state)
        t.expect(can).to_be(true)
        t.expect(reason).to_be("bump_attack")
    end)
end)

--------------------------------------------------------------------------------
-- Key Repeat Across Frames Tests
--------------------------------------------------------------------------------

t.describe("Descent Key Repeat Policy", function()
    t.before_each(function()
        Input.init()
    end)

    t.it("held key only triggers once until released", function()
        -- Frame 1: Press W
        local action1 = Input.poll({ w = true })
        t.expect(action1).to_not_be(nil)
        t.expect(action1.type).to_be("move")
        
        -- Frame 2: W still held - should return nil (same key state)
        local action2 = Input.poll({ w = true })
        t.expect(action2).to_be(nil)
        
        -- Frame 3: Release W
        Input.update_key_states({ w = false })
        local action3 = Input.poll({})
        t.expect(action3).to_be(nil)
        
        -- Frame 4: Press W again
        local action4 = Input.poll({ w = true })
        t.expect(action4).to_not_be(nil)
        t.expect(action4.type).to_be("move")
    end)

    t.it("different keys can trigger actions", function()
        -- Press W
        local action1 = Input.poll({ w = true })
        t.expect(action1).to_not_be(nil)
        Input.consume_action()
        Input.on_turn_start(1)  -- New turn
        
        -- Press D (different key)
        Input.init()
        local action2 = Input.poll({ d = true })
        t.expect(action2).to_not_be(nil)
        t.expect(action2.dx).to_be(1)  -- east
    end)

    t.it("no action when action already consumed this turn", function()
        -- First action
        local action1 = Input.poll({ w = true })
        t.expect(action1).to_not_be(nil)
        Input.consume_action()
        
        -- Different key pressed same turn
        Input.update_key_states({ w = false })
        local action2 = Input.poll({ d = true })
        t.expect(action2).to_be(nil)  -- Blocked by action consumption
    end)
end)
