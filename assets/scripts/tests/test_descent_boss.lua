local t = require("tests.test_runner")

local spec = require("descent.spec")
local Floor5 = require("descent.floor5")
local Boss = require("descent.boss")


t.describe("Descent Boss Floor", function()
  t.it("generates arena with boss and guards", function()
    local floor = Floor5.generate(123)
    t.expect(floor).to_be_truthy()
    t.expect(floor.map.w).to_be(spec.floors.floors[spec.boss.floor].width)
    t.expect(floor.map.h).to_be(spec.floors.floors[spec.boss.floor].height)
    t.expect(floor.placements.stairs_up).to_be_truthy()
    t.expect(floor.placements.boss).to_be_truthy()
    t.expect(#(floor.placements.guards or {})).to_be(spec.boss.guards)
  end)

  t.it("boss phase thresholds follow spec", function()
    local boss = Boss.create()

    boss.hp = boss.hp_max
    boss:update_phase()
    t.expect(boss.phase).to_be(1)

    boss.hp = boss.hp_max * 0.5
    boss:update_phase()
    t.expect(boss.phase).to_be(1)

    boss.hp = boss.hp_max * 0.49
    boss:update_phase()
    t.expect(boss.phase).to_be(2)

    boss.hp = boss.hp_max * 0.25
    boss:update_phase()
    t.expect(boss.phase).to_be(2)

    boss.hp = boss.hp_max * 0.24
    boss:update_phase()
    t.expect(boss.phase).to_be(3)
    t.expect(boss.damage_multiplier).to_be(spec.boss.phases[3].damage_multiplier)
  end)

  t.it("victory triggers when boss is dead", function()
    local floor = Floor5.generate(1)
    local called = false
    Floor5.on_victory(function()
      called = true
    end)
    local state = { boss = floor.boss }
    state.boss.hp = 0
    local ok = Floor5.check_victory(state)
    t.expect(ok).to_be(true)
    t.expect(called).to_be(true)
  end)

  t.it("safe_call routes errors to handler", function()
    local err_called = false
    Floor5.on_error(function()
      err_called = true
    end)
    local ok = Floor5.safe_call(function()
      error("boom")
    end)
    t.expect(ok).to_be(false)
    t.expect(err_called).to_be(true)
  end)
end)
