-- assets/scripts/tests/test_descent_enemy_turn.lua
--[[
================================================================================
DESCENT ENEMY TURN TESTS
================================================================================
Validates enemy turn execution: no occupied moves, no overlaps, stable iteration.

Acceptance criteria:
- No moves into occupied tiles
- No overlaps after enemy phase
- Stable iteration order
- Nil path handling (enemy idles)
]]

local t = require("tests.test_runner")
local Map = require("descent.map")
local Enemy = require("descent.enemy")
local ActionsEnemy = require("descent.actions_enemy")

local function make_open_map(w, h)
    local map = Map.new(w, h, { default_tile = Map.TILE.FLOOR })
    for y = 1, h do
        for x = 1, w do
            Map.set_tile(map, x, y, Map.TILE.FLOOR)
        end
    end
    return map
end

--------------------------------------------------------------------------------
-- Occupied Move Prevention Tests
--------------------------------------------------------------------------------

t.describe("Descent Enemy Turn - Occupied Prevention", function()
    t.it("enemy cannot move into player tile", function()
        local map = make_open_map(5, 5)
        local player = { x = 3, y = 2 }
        
        local enemy = Enemy.create("goblin", 2, 2)
        enemy.alive = true
        
        ActionsEnemy.init(player, Enemy, nil, map)
        ActionsEnemy.begin_enemy_phase()
        
        -- Enemy would want to move to 3,2 (player position)
        local decision = { action = "move", next_tile = { x = 3, y = 2 } }
        
        -- The action execution should block this
        local result = ActionsEnemy.decide_action(enemy)
        
        -- Adjacent to player should trigger attack, not move
        t.expect(result.action).to_be("attack")
    end)

    t.it("enemy cannot move into another enemy tile", function()
        local map = make_open_map(5, 5)
        local player = { x = 5, y = 5 }
        
        local enemy1 = Enemy.create("goblin", 2, 2)
        enemy1.alive = true
        enemy1.instance_id = 1
        
        local enemy2 = Enemy.create("goblin", 3, 2)
        enemy2.alive = true
        enemy2.instance_id = 2
        
        -- Mock enemy module
        local mock_enemies = {
            get_all = function() return { enemy1, enemy2 } end,
            decide = function(e, gs)
                if e.instance_id == 1 then
                    return { action = "move", next_tile = { x = 3, y = 2 } }  -- Into enemy2
                end
                return { action = "idle", reason = "no_target" }
            end,
        }
        
        ActionsEnemy.init(player, mock_enemies, nil, map)
        ActionsEnemy.begin_enemy_phase()
        
        local result = ActionsEnemy.decide_action(enemy1)
        
        -- Should be blocked
        t.expect(result.result).to_be(ActionsEnemy.RESULT.BLOCKED)
        t.expect(enemy1.x).to_be(2)  -- Position unchanged
    end)
end)

--------------------------------------------------------------------------------
-- No Overlaps Tests
--------------------------------------------------------------------------------

t.describe("Descent Enemy Turn - No Overlaps", function()
    t.it("end_enemy_phase detects no overlaps in clean state", function()
        local map = make_open_map(5, 5)
        local player = { x = 5, y = 5 }
        
        local enemy1 = Enemy.create("goblin", 2, 2)
        enemy1.alive = true
        
        local enemy2 = Enemy.create("goblin", 3, 3)
        enemy2.alive = true
        
        local mock_enemies = {
            get_all = function() return { enemy1, enemy2 } end,
        }
        
        ActionsEnemy.init(player, mock_enemies, nil, map)
        
        local no_overlaps = ActionsEnemy.end_enemy_phase()
        t.expect(no_overlaps).to_be(true)
    end)

    t.it("end_enemy_phase detects overlaps", function()
        local map = make_open_map(5, 5)
        local player = { x = 5, y = 5 }
        
        local enemy1 = Enemy.create("goblin", 2, 2)
        enemy1.alive = true
        
        local enemy2 = Enemy.create("goblin", 2, 2)  -- Same position!
        enemy2.alive = true
        
        local mock_enemies = {
            get_all = function() return { enemy1, enemy2 } end,
        }
        
        ActionsEnemy.init(player, mock_enemies, nil, map)
        
        local no_overlaps = ActionsEnemy.end_enemy_phase()
        t.expect(no_overlaps).to_be(false)  -- Overlap detected
    end)
end)

--------------------------------------------------------------------------------
-- Stable Iteration Order Tests
--------------------------------------------------------------------------------

t.describe("Descent Enemy Turn - Stable Iteration", function()
    t.it("process_all_enemies maintains deterministic order", function()
        local map = make_open_map(10, 10)
        local player = { x = 10, y = 10 }
        
        local enemies = {}
        for i = 1, 5 do
            local e = Enemy.create("goblin", i, 1)
            e.alive = true
            e.instance_id = i
            table.insert(enemies, e)
        end
        
        local process_order = {}
        local mock_enemies = {
            get_all = function() return enemies end,
            decide = function(e, gs)
                table.insert(process_order, e.instance_id)
                return { action = "idle", reason = "test" }
            end,
        }
        
        ActionsEnemy.init(player, mock_enemies, nil, map)
        ActionsEnemy.process_all_enemies()
        
        -- Should process in spawn order (instance_id order)
        t.expect(#process_order).to_be(5)
        for i = 1, 5 do
            t.expect(process_order[i]).to_be(i)
        end
    end)

    t.it("dead enemies are skipped", function()
        local map = make_open_map(5, 5)
        local player = { x = 5, y = 5 }
        
        local enemy1 = Enemy.create("goblin", 2, 2)
        enemy1.alive = true
        enemy1.instance_id = 1
        
        local enemy2 = Enemy.create("goblin", 3, 3)
        enemy2.alive = false  -- Dead
        enemy2.instance_id = 2
        
        local processed = {}
        local mock_enemies = {
            get_all = function() return { enemy1, enemy2 } end,
            decide = function(e, gs)
                table.insert(processed, e.instance_id)
                return { action = "idle", reason = "test" }
            end,
        }
        
        ActionsEnemy.init(player, mock_enemies, nil, map)
        local results = ActionsEnemy.process_all_enemies()
        
        -- Only enemy1 should be processed
        t.expect(#results).to_be(1)
        t.expect(results[1].enemy.instance_id).to_be(1)
    end)
end)

--------------------------------------------------------------------------------
-- Nil Path Handling Tests
--------------------------------------------------------------------------------

t.describe("Descent Enemy Turn - Nil Path Handling", function()
    t.it("enemy idles when pathfinding returns nil", function()
        local map = make_open_map(3, 3)
        -- Block all paths from enemy to player
        Map.set_tile(map, 2, 1, Map.TILE.WALL)
        Map.set_tile(map, 2, 2, Map.TILE.WALL)
        Map.set_tile(map, 2, 3, Map.TILE.WALL)
        
        local player = { x = 3, y = 2 }
        local enemy = Enemy.create("goblin", 1, 2)
        enemy.alive = true
        
        local game_state = {
            player = player,
            map = map,
            fov = { is_visible = function() return true end },
        }
        
        local decision = Enemy.decide(enemy, game_state)
        t.expect(decision.type).to_be(Enemy.DECISION.IDLE)
    end)

    t.it("enemy idles when no player reference", function()
        local enemy = Enemy.create("goblin", 2, 2)
        enemy.alive = true
        
        ActionsEnemy.init(nil, nil, nil, nil)  -- No player
        
        local result = ActionsEnemy.decide_action(enemy)
        t.expect(result.result).to_be(ActionsEnemy.RESULT.NO_TARGET)
    end)

    t.it("dead enemy returns idle result", function()
        local enemy = Enemy.create("goblin", 2, 2)
        enemy.alive = false
        
        local player = { x = 5, y = 5 }
        ActionsEnemy.init(player, Enemy, nil, nil)
        
        local result = ActionsEnemy.decide_action(enemy)
        t.expect(result.result).to_be(ActionsEnemy.RESULT.IDLE)
    end)
end)

--------------------------------------------------------------------------------
-- Adjacent Enemy Detection Tests
--------------------------------------------------------------------------------

t.describe("Descent Enemy Turn - Adjacent Detection", function()
    t.it("get_adjacent_enemy finds adjacent enemy", function()
        local player = { x = 3, y = 3 }
        
        local enemy1 = Enemy.create("goblin", 4, 3)  -- Adjacent
        enemy1.alive = true
        
        local enemy2 = Enemy.create("goblin", 5, 5)  -- Not adjacent
        enemy2.alive = true
        
        local mock_enemies = {
            get_all = function() return { enemy1, enemy2 } end,
        }
        
        ActionsEnemy.init(player, mock_enemies, nil, nil)
        
        local adjacent = ActionsEnemy.get_adjacent_enemy()
        t.expect(adjacent).to_not_be(nil)
        t.expect(adjacent.x).to_be(4)
    end)

    t.it("get_adjacent_enemy returns nil when none adjacent", function()
        local player = { x = 3, y = 3 }
        
        local enemy = Enemy.create("goblin", 5, 5)  -- Not adjacent
        enemy.alive = true
        
        local mock_enemies = {
            get_all = function() return { enemy } end,
        }
        
        ActionsEnemy.init(player, mock_enemies, nil, nil)
        
        local adjacent = ActionsEnemy.get_adjacent_enemy()
        t.expect(adjacent).to_be(nil)
    end)
end)
