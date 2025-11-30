-- Minimal tests for AvatarSystem unlock flow

-- Add repository paths so requires work when running standalone
local thisFile = debug.getinfo(1, "S").source:match("^@(.+)$")
local scriptsRoot = thisFile:match("(.*/assets/scripts/)") or "./assets/scripts/"
package.path = table.concat({
    package.path,
    scriptsRoot .. "?.lua",
    scriptsRoot .. "?/init.lua",
    scriptsRoot .. "wand/?.lua",
    scriptsRoot .. "data/?.lua"
}, ";")

local AvatarSystem = require("wand.avatar_system")
local TagEvaluator = require("wand.tag_evaluator")

-- stub signal to capture emits
local emitted = {}
local signal = {
    emit = function(event, payload)
        table.insert(emitted, { event = event, payload = payload })
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
end

run_tests()

print("All avatar tests passed.")
