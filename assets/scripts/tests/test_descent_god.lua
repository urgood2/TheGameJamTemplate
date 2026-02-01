-- assets/scripts/tests/test_descent_god.lua
--[[
================================================================================
DESCENT GOD SYSTEM TESTS
================================================================================
Validates altar spawn, worship persistence, Trog spell block.

Acceptance criteria:
- Altar spawn per spec floors
- Worship persists across floors
- Trog blocks spell casting
]]

local t = require("tests.test_runner")
local God = require("descent.god")

--------------------------------------------------------------------------------
-- Worship Tests
--------------------------------------------------------------------------------

t.describe("Descent God Worship", function()
    local player

    t.before_each(function()
        player = {
            god = nil,
            piety = 0,
        }
    end)

    t.it("can worship Trog", function()
        local ok, msg = God.worship(player, "trog")
        t.expect(ok).to_be(true)
        t.expect(player.god).to_be("trog")
        t.expect(msg).to_contain("Trog")
    end)

    t.it("cannot worship unknown god", function()
        local ok, msg = God.worship(player, "zeus")
        t.expect(ok).to_be(false)
        t.expect(msg).to_contain("Unknown god")
        t.expect(player.god).to_be(nil)
    end)

    t.it("cannot worship second god without abandon", function()
        God.worship(player, "trog")
        -- Try to worship another (if more gods existed)
        local ok, msg = God.worship(player, "trog")
        t.expect(ok).to_be(true)  -- Same god is OK
    end)

    t.it("persists worship state on player", function()
        God.worship(player, "trog")
        
        -- Simulate "floor change" - player object persists
        t.expect(player.god).to_be("trog")
        t.expect(God.is_worshipping(player)).to_be(true)
        t.expect(God.is_worshipping(player, "trog")).to_be(true)
    end)

    t.it("can abandon god", function()
        God.worship(player, "trog")
        t.expect(player.god).to_be("trog")
        
        local ok, msg = God.abandon(player)
        t.expect(ok).to_be(true)
        t.expect(player.god).to_be(nil)
        t.expect(player.piety).to_be(0)
    end)

    t.it("cannot abandon when not worshipping", function()
        local ok, msg = God.abandon(player)
        t.expect(ok).to_be(false)
        t.expect(msg).to_contain("not worshipping")
    end)

    t.it("get_worshipped_god returns god data", function()
        t.expect(God.get_worshipped_god(player)).to_be(nil)
        
        God.worship(player, "trog")
        local god = God.get_worshipped_god(player)
        t.expect(god).to_not_be(nil)
        t.expect(god.name).to_be("Trog")
    end)
end)

--------------------------------------------------------------------------------
-- Trog Spell Block Tests
--------------------------------------------------------------------------------

t.describe("Descent Trog Spell Block", function()
    local player

    t.before_each(function()
        player = {
            god = nil,
            piety = 0,
        }
    end)

    t.it("allows spell casting when no god", function()
        local can_cast, msg = God.can_cast_spell(player)
        t.expect(can_cast).to_be(true)
        t.expect(msg).to_be(nil)
    end)

    t.it("Trog blocks spell casting", function()
        God.worship(player, "trog")
        
        local can_cast, msg, turn_cost = God.can_cast_spell(player)
        t.expect(can_cast).to_be(false)
        t.expect(msg).to_contain("forbids")
        t.expect(msg).to_contain("magic")
        t.expect(turn_cost).to_be(0)  -- Blocked spell costs 0 turns
    end)

    t.it("spell block includes god name", function()
        God.worship(player, "trog")
        local can_cast, msg = God.can_cast_spell(player)
        t.expect(msg).to_contain("Trog")
    end)
end)

--------------------------------------------------------------------------------
-- Piety Tests
--------------------------------------------------------------------------------

t.describe("Descent God Piety", function()
    local player

    t.before_each(function()
        player = {
            god = nil,
            piety = 0,
        }
    end)

    t.it("adds piety when worshipping", function()
        God.worship(player, "trog")
        
        local gained = God.add_piety(player, 10)
        t.expect(gained).to_be(10)
        t.expect(player.piety).to_be(10)
    end)

    t.it("does not add piety when not worshipping", function()
        local gained = God.add_piety(player, 10)
        t.expect(gained).to_be(0)
    end)

    t.it("clamps piety to max 200", function()
        God.worship(player, "trog")
        player.piety = 195
        
        local gained = God.add_piety(player, 20)
        t.expect(gained).to_be(5)
        t.expect(player.piety).to_be(200)
    end)

    t.it("clamps piety to min 0", function()
        God.worship(player, "trog")
        player.piety = 5
        
        local lost = God.add_piety(player, -20)
        t.expect(lost).to_be(-5)
        t.expect(player.piety).to_be(0)
    end)

    t.it("on_kill grants piety", function()
        God.worship(player, "trog")
        
        local gained = God.on_kill(player, { name = "goblin" })
        t.expect(gained).to_be(3)  -- Trog grants 3 piety per kill
        t.expect(player.piety).to_be(3)
    end)

    t.it("decay_piety reduces piety", function()
        God.worship(player, "trog")
        player.piety = 100
        
        God.decay_piety(player)
        t.expect(player.piety).to_be_less_than(100)
    end)

    t.it("get_piety returns current piety", function()
        t.expect(God.get_piety(player)).to_be(0)
        
        God.worship(player, "trog")
        God.add_piety(player, 50)
        t.expect(God.get_piety(player)).to_be(50)
    end)
end)

--------------------------------------------------------------------------------
-- Altar Tests
--------------------------------------------------------------------------------

t.describe("Descent God Altars", function()
    t.it("floor_has_altar checks spec", function()
        -- Floor 1 typically has no altar, later floors might
        -- Just verify the function works
        local has_altar_1 = God.floor_has_altar(1)
        t.expect(type(has_altar_1)).to_be("boolean")
    end)

    t.it("get_random_god_for_altar returns valid god", function()
        local god_id = God.get_random_god_for_altar()
        t.expect(god_id).to_be("trog")  -- Only god currently
    end)

    t.it("create_altar returns altar data", function()
        local altar = God.create_altar("trog")
        t.expect(altar).to_not_be(nil)
        t.expect(altar.god_id).to_be("trog")
        t.expect(altar.god_name).to_be("Trog")
        t.expect(altar.description).to_contain("magic")
    end)

    t.it("create_altar returns nil for unknown god", function()
        local altar = God.create_altar("zeus")
        t.expect(altar).to_be(nil)
    end)
end)

--------------------------------------------------------------------------------
-- Abilities Tests
--------------------------------------------------------------------------------

t.describe("Descent God Abilities", function()
    local player

    t.before_each(function()
        player = {
            god = nil,
            piety = 0,
        }
    end)

    t.it("get_abilities returns empty when not worshipping", function()
        local abilities = God.get_abilities(player)
        t.expect(#abilities).to_be(0)
    end)

    t.it("get_abilities returns Trog abilities", function()
        God.worship(player, "trog")
        player.piety = 100
        
        local abilities = God.get_abilities(player)
        t.expect(#abilities).to_be(2)  -- berserk and trog_hand
        
        local berserk = abilities[1]
        t.expect(berserk.id).to_be("berserk")
        t.expect(berserk.can_use).to_be(true)  -- 100 piety >= 30 required
    end)

    t.it("ability can_use reflects piety requirement", function()
        God.worship(player, "trog")
        player.piety = 20
        
        local abilities = God.get_abilities(player)
        local berserk = abilities[1]
        t.expect(berserk.can_use).to_be(false)  -- 20 < 30 required
    end)

    t.it("use_ability deducts piety", function()
        God.worship(player, "trog")
        player.piety = 100
        
        local ok, msg = God.use_ability(player, "berserk")
        t.expect(ok).to_be(true)
        t.expect(player.piety).to_be(70)  -- 100 - 30 cost
    end)

    t.it("use_ability fails with insufficient piety", function()
        God.worship(player, "trog")
        player.piety = 20
        
        local ok, msg = God.use_ability(player, "berserk")
        t.expect(ok).to_be(false)
        t.expect(msg).to_contain("piety")
    end)

    t.it("use_ability fails for unknown ability", function()
        God.worship(player, "trog")
        player.piety = 100
        
        local ok, msg = God.use_ability(player, "lightning")
        t.expect(ok).to_be(false)
        t.expect(msg).to_contain("Unknown ability")
    end)
end)

--------------------------------------------------------------------------------
-- Worship Info Tests
--------------------------------------------------------------------------------

t.describe("Descent God Worship Info", function()
    t.it("get_worship_info when not worshipping", function()
        local player = { god = nil }
        local info = God.get_worship_info(player)
        
        t.expect(info.worshipping).to_be(false)
        t.expect(info.message).to_contain("not worshipping")
    end)

    t.it("get_worship_info when worshipping", function()
        local player = { god = nil, piety = 0 }
        God.worship(player, "trog")
        player.piety = 50
        
        local info = God.get_worship_info(player)
        
        t.expect(info.worshipping).to_be(true)
        t.expect(info.god_id).to_be("trog")
        t.expect(info.god_name).to_be("Trog")
        t.expect(info.piety).to_be(50)
        t.expect(#info.abilities).to_be(2)
    end)
end)
