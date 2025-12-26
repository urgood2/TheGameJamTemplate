-- Minimal tests for AvatarSystem unlock flow

-- Add repository paths so requires work when running standalone
local thisFile = debug.getinfo(1, "S").source:match("^@(.+)$")
local scriptsRoot = thisFile:match("(.*/assets/scripts/)") or "./assets/scripts/"
package.path = table.concat({
    package.path,
    scriptsRoot .. "?.lua",
    scriptsRoot .. "?/init.lua",
    scriptsRoot .. "wand/?.lua",
    scriptsRoot .. "data/?.lua",
    scriptsRoot .. "ui/?.lua"
}, ";")

local AvatarSystem = require("wand.avatar_system")
local TagEvaluator = require("wand.tag_evaluator")

-- Prefer real message queue UI; fall back to stub in headless runs
local ok, MessageQueueUI = pcall(require, "ui.message_queue_ui")
if not ok or not MessageQueueUI then
    MessageQueueUI = { pending = {}, active = {}, isActive = false }
    function MessageQueueUI.init(opts)
        MessageQueueUI.pending = {}
        MessageQueueUI.active = {}
        MessageQueueUI.isActive = true
    end
    function MessageQueueUI.enqueue(text, opts)
        table.insert(MessageQueueUI.pending, { text = text, opts = opts })
    end
end
MessageQueueUI.init({ maxVisible = 10 })

-- stub signal to capture emits
local emitted = {}
local signal = {
    emit = function(event, payload)
        table.insert(emitted, { event = event, payload = payload })
        local text = event
        if payload and payload.avatar_id then
            text = text .. " avatar=" .. tostring(payload.avatar_id)
        end
        if payload and payload.spell_type then
            text = text .. " spell=" .. tostring(payload.spell_type)
        end
        MessageQueueUI.enqueue(text)
    end
}
package.loaded["external.hump.signal"] = signal

local function reset()
    emitted = {}
end

local function assert_true(cond, msg)
    if not cond then error(msg or "assert_true failed") end
end

local function assert_equals(a, b, msg)
    if a ~= b then
        error((msg or "assert_equals failed") .. string.format(" (got %s, expected %s)", tostring(a), tostring(b)))
    end
end

local function run_tests()
    -- Test 1: tag-based unlock (wildfire uses OR_fire_tags = 7)
    reset()
    local player = {}
    TagEvaluator.evaluate_and_apply(player, { cards = {
        { tags = { "Fire" } }, { tags = { "Fire" } }, { tags = { "Fire" } },
        { tags = { "Fire" } }, { tags = { "Fire" } }, { tags = { "Fire" } },
        { tags = { "Fire" } },
    } })
    assert_true(player.avatar_state.unlocked.wildfire, "wildfire should unlock via tag count")

    local avatarSig = nil
    for _, e in ipairs(emitted) do
        if e.event == "avatar_unlocked" then avatarSig = e.payload end
    end
    assert_true(avatarSig ~= nil, "should emit avatar_unlocked signal")
    assert_equals(avatarSig.avatar_id, "wildfire", "payload should include avatar id")

    -- Test 2: metric-based unlock (citadel uses damage_blocked = 5000)
    reset()
    local player2 = {}
    AvatarSystem.record_progress(player2, "damage_blocked", 5000)
    assert_true(player2.avatar_state.unlocked.citadel, "citadel should unlock via damage_blocked metric")
    local avatarSig2 = nil
    for _, e in ipairs(emitted) do
        if e.event == "avatar_unlocked" then avatarSig2 = e.payload end
    end
    assert_true(avatarSig2 ~= nil, "should emit avatar_unlocked for citadel")
    assert_equals(avatarSig2.avatar_id, "citadel")

    -- Test 3: equip only unlocked
    local ok, err = AvatarSystem.equip(player2, "citadel")
    assert_true(ok, "equip should succeed for unlocked avatar")
    assert_equals(player2.avatar_state.equipped, "citadel")

    local ok2, err2 = AvatarSystem.equip(player2, "voidwalker")
    assert_true(not ok2 and err2 == "avatar_locked", "equip should fail for locked avatar")

    -- Test 4: incremental metric feed with queue output (kills_with_fire)
    reset()
    local player3 = {}
    for _ = 1, 4 do
        AvatarSystem.record_progress(player3, "kills_with_fire", 25)
    end
    assert_true(player3.avatar_state.unlocked.wildfire, "wildfire should unlock after 100 fire kills metric")

    -- Print queued messages for visibility
    for i, item in ipairs(MessageQueueUI.pending) do
        print(string.format("[QUEUE %d] %s", i, item.text))
    end

    -- Test 5: has_rule() helper function
    print("\n-- Testing has_rule helper --")
    local player5 = { avatar_state = { unlocked = { stormlord = true }, equipped = "stormlord" } }
    assert_true(AvatarSystem.has_rule(player5, "crit_chains"),
        "stormlord should have crit_chains rule")
    assert_true(not AvatarSystem.has_rule(player5, "multicast_loops"),
        "stormlord should NOT have multicast_loops rule")
    print("✓ has_rule correctly identifies avatar rules")

    -- Test 6: has_rule with no equipped avatar
    local player6 = { avatar_state = { unlocked = {}, equipped = nil } }
    assert_true(not AvatarSystem.has_rule(player6, "crit_chains"),
        "no equipped avatar should return false for any rule")
    print("✓ has_rule handles no equipped avatar")

    -- Test 7: apply_stat_buffs stores pending when no combatTable
    print("\n-- Testing stat_buff application --")
    local player7 = { avatar_state = { unlocked = { stormlord = true }, equipped = nil } }
    -- No combatTable, so buffs should be marked as pending
    local applied = AvatarSystem.apply_stat_buffs(player7, "stormlord")
    assert_true(applied, "apply_stat_buffs should return true even without combatTable")
    assert_equals(player7._pending_avatar_buffs, "stormlord",
        "should store pending avatar buffs when no combat stats available")
    print("✓ stat_buff application handles missing combatTable gracefully")

    -- Test 8: Mock stats object to verify stat application
    local mockStats = {
        _values = {},
        add_add_pct = function(self, stat, value)
            self._values[stat] = (self._values[stat] or 0) + value
        end,
        recompute = function(self) end
    }
    local player8 = {
        combatTable = { stats = mockStats },
        avatar_state = { unlocked = { stormlord = true }, equipped = nil }
    }
    AvatarSystem.apply_stat_buffs(player8, "stormlord")
    assert_equals(mockStats._values.cast_speed, 0.5,
        "stormlord should apply +0.5 cast_speed to stats")
    print("✓ stat_buff correctly applies to combat stats")

    -- Test 9: remove_stat_buffs reverses applied buffs
    AvatarSystem.remove_stat_buffs(player8)
    assert_equals(mockStats._values.cast_speed, 0,
        "remove_stat_buffs should reverse applied buffs")
    print("✓ remove_stat_buffs correctly reverses applied buffs")

    -- Test 10: unequip removes stat buffs
    local mockStats2 = {
        _values = {},
        add_add_pct = function(self, stat, value)
            self._values[stat] = (self._values[stat] or 0) + value
        end,
        recompute = function(self) end
    }
    local player10 = {
        combatTable = { stats = mockStats2 },
        avatar_state = { unlocked = { wildfire = true }, equipped = nil }
    }
    AvatarSystem.equip(player10, "wildfire")
    assert_equals(mockStats2._values.hazard_tick_rate_pct, 100,
        "equip should apply wildfire's hazard_tick_rate_pct buff")
    AvatarSystem.unequip(player10)
    assert_equals(mockStats2._values.hazard_tick_rate_pct, 0,
        "unequip should remove hazard_tick_rate_pct buff")
    assert_equals(player10.avatar_state.equipped, nil,
        "unequip should clear equipped avatar")
    print("✓ unequip removes stat buffs and clears equipped")

    print("-- stat_buff and rule tests passed --\n")
end

run_tests()

print("All avatar tests passed.")
