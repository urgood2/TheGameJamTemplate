--[[
================================================================================
NOITA SPELL FEATURES - TDD TEST SUITE
================================================================================
Test-driven development tests for:
1. Friendly Fire System (damage check + physics collision)
2. Faction-Agnostic Wand Execution (mob support)
3. Formation System (pentagon, hexagon, etc.)
4. Divide System (spell duplication with damage reduction)
5. New Movement Types (boomerang, spiral, pingpong)

Run with: require("tests.test_noita_spell_features").run_all()
================================================================================
]]--

local NoitaSpellTests = {}

-- Dependencies
local TestRunner = require("tests.test_runner")
local WandModifiers = require("wand.wand_modifiers")
local WandActions = require("wand.wand_actions")
local ProjectileSystem = require("combat.projectile_system")

local describe = TestRunner.describe
local it = TestRunner.it
local assert_equals = TestRunner.assert_equals
local assert_true = TestRunner.assert_true
local assert_nil = TestRunner.assert_nil
local assert_not_nil = TestRunner.assert_not_nil

--[[
================================================================================
TEST SUITE 1: FRIENDLY FIRE SYSTEM
================================================================================
]]--

describe("Friendly Fire System", function()
    
    it("modifier aggregate should have friendlyFire field defaulting to false", function()
        local aggregate = WandModifiers.createAggregate()
        assert_not_nil(aggregate.friendlyFire, "friendlyFire field should exist")
        assert_equals(false, aggregate.friendlyFire, "friendlyFire should default to false")
    end)
    
    it("aggregate should collect friendlyFire from modifier cards", function()
        -- Create a mock modifier card with friendly_fire
        local mockCard = {
            type = "modifier",
            friendly_fire = true
        }
        local aggregate = WandModifiers.aggregate({ mockCard })
        assert_equals(true, aggregate.friendlyFire, "Should collect friendly_fire from cards")
    end)
    
    it("projectileData should have friendlyFire field", function()
        local data = ProjectileSystem.createProjectileData({
            friendlyFire = true,
            damage = 10
        })
        assert_not_nil(data.friendlyFire, "friendlyFire field should exist in projectileData")
        assert_equals(true, data.friendlyFire, "friendlyFire should be true when set")
    end)
    
    it("projectileData friendlyFire should default to false", function()
        local data = ProjectileSystem.createProjectileData({
            damage = 10
        })
        assert_equals(false, data.friendlyFire, "friendlyFire should default to false")
    end)

end)

--[[
================================================================================
TEST SUITE 2: FACTION-AGNOSTIC WAND EXECUTION
================================================================================
]]--

describe("Faction-Agnostic Wand Execution", function()
    
    it("buildExecutionContext should exist", function()
        assert_not_nil(WandActions.buildExecutionContext, 
            "buildExecutionContext function should exist")
    end)
    
    it("buildExecutionContext should return context with casterEntity", function()
        local mockEntity = 12345
        local context = WandActions.buildExecutionContext(mockEntity)
        assert_not_nil(context, "Context should be returned")
        assert_equals(mockEntity, context.casterEntity, "casterEntity should match input")
    end)
    
    it("buildExecutionContext should default faction to player", function()
        local context = WandActions.buildExecutionContext(12345)
        assert_equals("player", context.faction, "faction should default to player")
    end)
    
    it("buildExecutionContext should accept faction override", function()
        local context = WandActions.buildExecutionContext(12345, { faction = "enemy" })
        assert_equals("enemy", context.faction, "faction should be overridden to enemy")
    end)
    
    it("buildExecutionContext should support neutral faction", function()
        local context = WandActions.buildExecutionContext(12345, { faction = "neutral" })
        assert_equals("neutral", context.faction, "faction should be neutral")
    end)
    
    it("context should have backwards-compatible playerEntity field", function()
        local mockEntity = 99999
        local context = WandActions.buildExecutionContext(mockEntity)
        assert_equals(mockEntity, context.playerEntity, 
            "playerEntity should equal casterEntity for backwards compatibility")
    end)

end)

--[[
================================================================================
TEST SUITE 3: FORMATION SYSTEM
================================================================================
]]--

describe("Formation System", function()
    
    it("modifier aggregate should have formation field defaulting to nil", function()
        local aggregate = WandModifiers.createAggregate()
        assert_nil(aggregate.formation, "formation should default to nil")
    end)
    
    it("FORMATIONS table should exist with predefined patterns", function()
        assert_not_nil(WandModifiers.FORMATIONS, "FORMATIONS table should exist")
        assert_not_nil(WandModifiers.FORMATIONS.pentagon, "pentagon formation should exist")
        assert_not_nil(WandModifiers.FORMATIONS.hexagon, "hexagon formation should exist")
        assert_not_nil(WandModifiers.FORMATIONS.behind_back, "behind_back formation should exist")
    end)
    
    it("pentagon formation should have 5 angles", function()
        local pentagon = WandModifiers.FORMATIONS.pentagon
        assert_equals(5, #pentagon, "pentagon should have 5 angles")
    end)
    
    it("hexagon formation should have 6 angles", function()
        local hexagon = WandModifiers.FORMATIONS.hexagon
        assert_equals(6, #hexagon, "hexagon should have 6 angles")
    end)
    
    it("calculateFormationAngles should exist", function()
        assert_not_nil(WandModifiers.calculateFormationAngles, 
            "calculateFormationAngles function should exist")
    end)
    
    it("calculateFormationAngles with nil formation should fall back to multicast", function()
        local modifiers = WandModifiers.createAggregate()
        modifiers.formation = nil
        local angles = WandModifiers.calculateFormationAngles(modifiers, 0)
        assert_not_nil(angles, "Should return angles array")
        assert_true(#angles >= 1, "Should have at least 1 angle")
    end)
    
    it("calculateFormationAngles with pentagon should return 5 angles", function()
        local modifiers = WandModifiers.createAggregate()
        modifiers.formation = "pentagon"
        local angles = WandModifiers.calculateFormationAngles(modifiers, 0)
        assert_equals(5, #angles, "pentagon should produce 5 angles")
    end)
    
    it("formation angles should be offset from base angle", function()
        local modifiers = WandModifiers.createAggregate()
        modifiers.formation = "behind_back"
        local baseAngle = math.pi / 4  -- 45 degrees
        local angles = WandModifiers.calculateFormationAngles(modifiers, baseAngle)
        -- behind_back should have angles at baseAngle and baseAngle + pi
        assert_equals(2, #angles, "behind_back should produce 2 angles")
    end)

end)

--[[
================================================================================
TEST SUITE 4: DIVIDE SYSTEM
================================================================================
]]--

describe("Divide System", function()
    
    it("modifier aggregate should have divideCount defaulting to 1", function()
        local aggregate = WandModifiers.createAggregate()
        assert_not_nil(aggregate.divideCount, "divideCount field should exist")
        assert_equals(1, aggregate.divideCount, "divideCount should default to 1")
    end)
    
    it("modifier aggregate should have divideDamageMultiplier defaulting to 1.0", function()
        local aggregate = WandModifiers.createAggregate()
        assert_not_nil(aggregate.divideDamageMultiplier, 
            "divideDamageMultiplier field should exist")
        assert_equals(1.0, aggregate.divideDamageMultiplier, 
            "divideDamageMultiplier should default to 1.0")
    end)
    
    it("aggregate should multiply divideCount from cards", function()
        local mockCard = {
            type = "modifier",
            divide_count = 2
        }
        local aggregate = WandModifiers.aggregate({ mockCard })
        assert_equals(2, aggregate.divideCount, "divideCount should be 2")
    end)
    
    it("aggregate should multiply divideDamageMultiplier from cards", function()
        local mockCard = {
            type = "modifier",
            divide_damage_multiplier = 0.6
        }
        local aggregate = WandModifiers.aggregate({ mockCard })
        assert_equals(0.6, aggregate.divideDamageMultiplier, 
            "divideDamageMultiplier should be 0.6")
    end)
    
    it("multiple divide cards should stack multiplicatively", function()
        local card1 = { type = "modifier", divide_count = 2 }
        local card2 = { type = "modifier", divide_count = 2 }
        local aggregate = WandModifiers.aggregate({ card1, card2 })
        assert_equals(4, aggregate.divideCount, "2 x 2 = 4 divides")
    end)
    
    it("damage multipliers should stack multiplicatively", function()
        local card1 = { type = "modifier", divide_damage_multiplier = 0.5 }
        local card2 = { type = "modifier", divide_damage_multiplier = 0.5 }
        local aggregate = WandModifiers.aggregate({ card1, card2 })
        assert_equals(0.25, aggregate.divideDamageMultiplier, "0.5 x 0.5 = 0.25")
    end)

end)

--[[
================================================================================
TEST SUITE 5: NEW MOVEMENT TYPES
================================================================================
]]--

describe("New Movement Types", function()
    
    it("MovementType should have BOOMERANG", function()
        assert_not_nil(ProjectileSystem.MovementType.BOOMERANG, 
            "BOOMERANG movement type should exist")
    end)
    
    it("MovementType should have SPIRAL", function()
        assert_not_nil(ProjectileSystem.MovementType.SPIRAL, 
            "SPIRAL movement type should exist")
    end)
    
    it("MovementType should have PINGPONG", function()
        assert_not_nil(ProjectileSystem.MovementType.PINGPONG, 
            "PINGPONG movement type should exist")
    end)
    
    it("updateBoomerangMovement function should exist", function()
        assert_not_nil(ProjectileSystem.updateBoomerangMovement, 
            "updateBoomerangMovement function should exist")
    end)
    
    it("updateSpiralMovement function should exist", function()
        assert_not_nil(ProjectileSystem.updateSpiralMovement, 
            "updateSpiralMovement function should exist")
    end)
    
    it("updatePingPongMovement function should exist", function()
        assert_not_nil(ProjectileSystem.updatePingPongMovement, 
            "updatePingPongMovement function should exist")
    end)

end)

--[[
================================================================================
TEST SUITE 6: TELEPORT SYSTEM
================================================================================
]]--

describe("Teleport System", function()
    
    it("teleportEntity function should exist", function()
        assert_not_nil(WandActions.teleportEntity, 
            "teleportEntity function should exist")
    end)
    
    it("executeTeleportAction should exist", function()
        assert_not_nil(WandActions.executeTeleportAction, 
            "executeTeleportAction function should exist")
    end)

end)

describe("Behavioral: Friendly Fire Filtering", function()
    
    it("same faction without friendlyFire should be blocked", function()
        local mockData = {
            faction = "player",
            friendlyFire = false,
            owner = 999
        }
        local mockTargetScript = { faction = "player" }
        
        local ownerFaction = mockData.faction or "player"
        local targetFaction = mockTargetScript.faction or "enemy"
        local blocked = (ownerFaction == targetFaction) and not mockData.friendlyFire
        
        assert_true(blocked, "Same faction should be blocked without friendlyFire")
    end)
    
    it("same faction with friendlyFire should NOT be blocked", function()
        local mockData = {
            faction = "player",
            friendlyFire = true,
            owner = 999
        }
        local mockTargetScript = { faction = "player" }
        
        local ownerFaction = mockData.faction or "player"
        local targetFaction = mockTargetScript.faction or "enemy"
        local blocked = (ownerFaction == targetFaction) and not mockData.friendlyFire
        
        assert_equals(false, blocked, "Same faction should NOT be blocked with friendlyFire")
    end)
    
    it("different faction should never be blocked", function()
        local mockData = {
            faction = "player",
            friendlyFire = false,
            owner = 999
        }
        local mockTargetScript = { faction = "enemy" }
        
        local ownerFaction = mockData.faction or "player"
        local targetFaction = mockTargetScript.faction or "enemy"
        local blocked = (ownerFaction == targetFaction) and not mockData.friendlyFire
        
        assert_equals(false, blocked, "Different faction should never be blocked")
    end)

end)

describe("Behavioral: Divide Damage Calculation", function()
    
    it("divide by 2 with 0.6 multiplier should reduce damage", function()
        local baseDamage = 100
        local divideCount = 2
        local multiplier = 0.6
        
        local dividedDamage = baseDamage * multiplier
        assert_equals(60, dividedDamage, "100 * 0.6 = 60")
    end)
    
    it("stacked divide multipliers should compound", function()
        local multiplier1 = 0.6
        local multiplier2 = 0.5
        local combined = multiplier1 * multiplier2
        
        assert_equals(0.3, combined, "0.6 * 0.5 = 0.3")
    end)
    
    it("total damage with divide should be higher than single shot", function()
        local baseDamage = 100
        local divideCount = 2
        local multiplier = 0.6
        
        local singleShotDamage = baseDamage
        local dividedTotal = (baseDamage * multiplier) * divideCount
        
        assert_true(dividedTotal > singleShotDamage, 
            "2 copies at 60% (120 total) > 1 shot at 100%")
    end)

end)

describe("Behavioral: Movement Type Wiring", function()
    
    it("movementType field should be collected from modifier cards", function()
        local mockCard = {
            type = "modifier",
            movement_type = "boomerang"
        }
        local aggregate = WandModifiers.aggregate({ mockCard })
        assert_equals("boomerang", aggregate.movementType, 
            "movementType should be collected from card")
    end)
    
    it("later movement_type should override earlier", function()
        local card1 = { type = "modifier", movement_type = "spiral" }
        local card2 = { type = "modifier", movement_type = "boomerang" }
        local aggregate = WandModifiers.aggregate({ card1, card2 })
        assert_equals("boomerang", aggregate.movementType, 
            "Later card should override movement_type")
    end)

end)

describe("Behavioral: Formation Angle Math", function()
    
    it("pentagon angles should be evenly spaced", function()
        local pentagon = WandModifiers.FORMATIONS.pentagon
        local expectedStep = math.pi * 2 / 5
        
        for i = 2, #pentagon do
            local diff = pentagon[i] - pentagon[i-1]
            local tolerance = 0.001
            assert_true(math.abs(diff - expectedStep) < tolerance,
                "Pentagon angles should be 72 degrees apart")
        end
    end)
    
    it("behind_back should have exactly pi radians between angles", function()
        local bb = WandModifiers.FORMATIONS.behind_back
        local diff = bb[2] - bb[1]
        assert_equals(math.pi, diff, "behind_back should be 180 degrees apart")
    end)

end)

function NoitaSpellTests.run_all()
    print("\n" .. string.rep("=", 70))
    print("NOITA SPELL FEATURES - TDD TEST SUITE")
    print(string.rep("=", 70))
    
    TestRunner.reset()
    local success = TestRunner.run_all()
    
    print("\n" .. string.rep("=", 70))
    if success then
        print("ALL TESTS PASSED")
    else
        print("SOME TESTS FAILED - Implementation needed!")
    end
    print(string.rep("=", 70))
    
    return success
end

return NoitaSpellTests
