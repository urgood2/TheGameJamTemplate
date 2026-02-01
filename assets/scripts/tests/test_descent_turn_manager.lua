-- assets/scripts/tests/test_descent_turn_manager.lua
--[[
================================================================================
DESCENT TURN MANAGER TESTS
================================================================================
Validates FSM transitions, invalid input handling, and dt independence.

Acceptance criteria:
- FSM transitions correctly between phases
- Invalid input consumes 0 turns
- No-op frames don't advance turns (dt independent)
- Callbacks fire correctly
]]

local t = require("tests.test_runner")
local TurnManager = require("descent.turn_manager")

--------------------------------------------------------------------------------
-- FSM Transition Tests
--------------------------------------------------------------------------------

t.describe("Descent Turn Manager FSM", function()
    t.before_each(function()
        TurnManager.reset()
        TurnManager.init()
    end)

    t.it("starts in player turn phase", function()
        t.expect(TurnManager.get_phase()).to_be(TurnManager.PHASE.PLAYER_TURN)
    end)

    t.it("starts at turn 0", function()
        t.expect(TurnManager.get_turn_count()).to_be(0)
    end)

    t.it("is_player_turn returns true initially", function()
        t.expect(TurnManager.is_player_turn()).to_be(true)
        t.expect(TurnManager.is_enemy_turn()).to_be(false)
    end)

    t.it("transitions to enemy turn after valid action", function()
        local ok = TurnManager.submit_action({ type = "wait" })
        t.expect(ok).to_be(true)
        
        TurnManager.update()
        
        t.expect(TurnManager.get_phase()).to_be(TurnManager.PHASE.ENEMY_TURN)
    end)

    t.it("returns to player turn after enemy phase", function()
        TurnManager.submit_action({ type = "wait" })
        TurnManager.update()  -- Process player action -> enemy turn
        
        -- Process enemy phase (no enemies)
        TurnManager.update()
        
        t.expect(TurnManager.get_phase()).to_be(TurnManager.PHASE.PLAYER_TURN)
        t.expect(TurnManager.get_turn_count()).to_be(1)
    end)

    t.it("advance_turns manually advances turn counter", function()
        t.expect(TurnManager.get_turn_count()).to_be(0)
        
        TurnManager.advance_turns(3)
        
        t.expect(TurnManager.get_turn_count()).to_be(3)
        t.expect(TurnManager.get_phase()).to_be(TurnManager.PHASE.PLAYER_TURN)
    end)

    t.it("pause and resume work correctly", function()
        TurnManager.pause()
        t.expect(TurnManager.get_phase()).to_be(TurnManager.PHASE.IDLE)
        
        TurnManager.resume()
        t.expect(TurnManager.get_phase()).to_be(TurnManager.PHASE.PLAYER_TURN)
    end)
end)

--------------------------------------------------------------------------------
-- Invalid Input Tests
--------------------------------------------------------------------------------

t.describe("Descent Turn Manager Invalid Input", function()
    t.before_each(function()
        TurnManager.reset()
        TurnManager.init()
    end)

    t.it("rejects nil action", function()
        local ok, err = TurnManager.submit_action(nil)
        t.expect(ok).to_be(false)
        t.expect(err).to_contain("No action")
    end)

    t.it("rejects action without type", function()
        local ok, err = TurnManager.submit_action({ dx = 1, dy = 0 })
        t.expect(ok).to_be(false)
        t.expect(err).to_contain("missing type")
    end)

    t.it("rejects move with zero delta", function()
        local ok, err = TurnManager.submit_action({ type = "move", dx = 0, dy = 0 })
        t.expect(ok).to_be(false)
        t.expect(err).to_contain("no-op")
    end)

    t.it("rejects move without dx/dy", function()
        local ok, err = TurnManager.submit_action({ type = "move" })
        t.expect(ok).to_be(false)
        t.expect(err).to_contain("dx/dy")
    end)

    t.it("rejects attack without target", function()
        local ok, err = TurnManager.submit_action({ type = "attack" })
        t.expect(ok).to_be(false)
        t.expect(err).to_contain("target")
    end)

    t.it("rejects use_item without item_id", function()
        local ok, err = TurnManager.submit_action({ type = "use_item" })
        t.expect(ok).to_be(false)
        t.expect(err).to_contain("item_id")
    end)

    t.it("rejects drop without item_id", function()
        local ok, err = TurnManager.submit_action({ type = "drop" })
        t.expect(ok).to_be(false)
        t.expect(err).to_contain("item_id")
    end)

    t.it("rejects unknown action type", function()
        local ok, err = TurnManager.submit_action({ type = "dance" })
        t.expect(ok).to_be(false)
        t.expect(err).to_contain("Unknown action type")
    end)

    t.it("rejects action during enemy turn", function()
        TurnManager.submit_action({ type = "wait" })
        TurnManager.update()  -- Now enemy turn
        
        local ok, err = TurnManager.submit_action({ type = "wait" })
        t.expect(ok).to_be(false)
        t.expect(err).to_contain("Not player turn")
    end)

    t.it("invalid action does not change turn count", function()
        local initial_turn = TurnManager.get_turn_count()
        
        TurnManager.submit_action(nil)
        TurnManager.submit_action({})
        TurnManager.submit_action({ type = "invalid" })
        
        t.expect(TurnManager.get_turn_count()).to_be(initial_turn)
    end)
end)

--------------------------------------------------------------------------------
-- DT Independence Tests
--------------------------------------------------------------------------------

t.describe("Descent Turn Manager DT Independence", function()
    t.before_each(function()
        TurnManager.reset()
        TurnManager.init()
    end)

    t.it("update returns false when no pending action", function()
        local processed = TurnManager.update()
        t.expect(processed).to_be(false)
    end)

    t.it("multiple updates without input don't advance turns", function()
        local initial_turn = TurnManager.get_turn_count()
        
        -- Simulate many frames without input
        for _ = 1, 100 do
            TurnManager.update()
        end
        
        t.expect(TurnManager.get_turn_count()).to_be(initial_turn)
        t.expect(TurnManager.get_phase()).to_be(TurnManager.PHASE.PLAYER_TURN)
    end)

    t.it("turn advances only on valid action submission", function()
        t.expect(TurnManager.get_turn_count()).to_be(0)
        
        -- Many updates without action
        for _ = 1, 50 do
            TurnManager.update()
        end
        t.expect(TurnManager.get_turn_count()).to_be(0)
        
        -- Submit valid action
        TurnManager.submit_action({ type = "wait" })
        TurnManager.update()  -- Player -> Enemy
        TurnManager.update()  -- Enemy -> Player (turn 1)
        
        t.expect(TurnManager.get_turn_count()).to_be(1)
    end)

    t.it("update returns false when not initialized", function()
        TurnManager.reset()
        local processed = TurnManager.update()
        t.expect(processed).to_be(false)
    end)
end)

--------------------------------------------------------------------------------
-- Callback Tests
--------------------------------------------------------------------------------

t.describe("Descent Turn Manager Callbacks", function()
    local callback_log

    t.before_each(function()
        TurnManager.reset()
        callback_log = {}
    end)

    t.it("fires on_turn_start on init", function()
        TurnManager.on("on_turn_start", function(turn)
            table.insert(callback_log, { event = "turn_start", turn = turn })
        end)
        
        TurnManager.init()
        
        t.expect(#callback_log).to_be(1)
        t.expect(callback_log[1].event).to_be("turn_start")
        t.expect(callback_log[1].turn).to_be(0)
    end)

    t.it("fires on_phase_change during transitions", function()
        TurnManager.init()
        
        TurnManager.on("on_phase_change", function(new_phase, old_phase)
            table.insert(callback_log, {
                event = "phase_change",
                new = new_phase,
                old = old_phase
            })
        end)
        
        TurnManager.submit_action({ type = "wait" })
        TurnManager.update()
        
        t.expect(#callback_log).to_be(1)
        t.expect(callback_log[1].new).to_be(TurnManager.PHASE.ENEMY_TURN)
        t.expect(callback_log[1].old).to_be(TurnManager.PHASE.PLAYER_TURN)
    end)

    t.it("fires on_player_action when action executed", function()
        TurnManager.init()
        
        TurnManager.on("on_player_action", function(action)
            table.insert(callback_log, { event = "player_action", action = action })
        end)
        
        TurnManager.submit_action({ type = "wait" })
        TurnManager.update()
        
        t.expect(#callback_log).to_be(1)
        t.expect(callback_log[1].action.type).to_be("wait")
    end)

    t.it("fires on_turn_end and on_turn_start on turn completion", function()
        TurnManager.init()
        
        TurnManager.on("on_turn_end", function(turn)
            table.insert(callback_log, { event = "turn_end", turn = turn })
        end)
        TurnManager.on("on_turn_start", function(turn)
            table.insert(callback_log, { event = "turn_start", turn = turn })
        end)
        
        TurnManager.submit_action({ type = "wait" })
        TurnManager.update()  -- Player action
        TurnManager.update()  -- Enemy phase completes
        
        -- Should have turn_end(0), turn_start(1)
        local end_event = nil
        local start_event = nil
        for _, e in ipairs(callback_log) do
            if e.event == "turn_end" and e.turn == 0 then end_event = e end
            if e.event == "turn_start" and e.turn == 1 then start_event = e end
        end
        
        t.expect(end_event).to_not_be(nil)
        t.expect(start_event).to_not_be(nil)
    end)

    t.it("off removes callback", function()
        TurnManager.init()
        
        local callback = function(turn)
            table.insert(callback_log, { turn = turn })
        end
        
        TurnManager.on("on_turn_start", callback)
        TurnManager.advance_turns(1)
        t.expect(#callback_log).to_be(1)
        
        TurnManager.off("on_turn_start", callback)
        TurnManager.advance_turns(1)
        t.expect(#callback_log).to_be(1)  -- No new entries
    end)
end)

--------------------------------------------------------------------------------
-- State Snapshot Tests
--------------------------------------------------------------------------------

t.describe("Descent Turn Manager State", function()
    t.before_each(function()
        TurnManager.reset()
        TurnManager.init()
    end)

    t.it("get_state returns correct snapshot", function()
        local state = TurnManager.get_state()
        
        t.expect(state.phase).to_be(TurnManager.PHASE.PLAYER_TURN)
        t.expect(state.turn_count).to_be(0)
        t.expect(state.has_pending_action).to_be(false)
        t.expect(state.initialized).to_be(true)
    end)

    t.it("get_state reflects pending action", function()
        TurnManager.submit_action({ type = "wait" })
        local state = TurnManager.get_state()
        
        t.expect(state.has_pending_action).to_be(true)
    end)

    t.it("reset clears all state", function()
        TurnManager.submit_action({ type = "wait" })
        TurnManager.update()
        TurnManager.reset()
        
        local state = TurnManager.get_state()
        t.expect(state.initialized).to_be(false)
        t.expect(state.turn_count).to_be(0)
        t.expect(state.phase).to_be(TurnManager.PHASE.IDLE)
    end)
end)
