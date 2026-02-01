local t = require("tests.test_runner")
local Map = require("descent.map")
local Spec = require("descent.spec")

t.describe("Descent map grid", function()
  t.it("creates floor maps with spec sizes", function()
    for floor = 1, Spec.floors.total do
      local map = Map.new_for_floor(floor, Spec)
      local floor_spec = Spec.floors.floors[floor]
      t.expect(map.w).to_be(floor_spec.width)
      t.expect(map.h).to_be(floor_spec.height)
    end
  end)

  t.it("index conversion is deterministic and bounds-safe", function()
    local map = Map.new(5, 4)
    t.expect(Map.to_index(map, 3, 2)).to_be(8)

    local x, y = Map.from_index(map, 8)
    t.expect(x).to_be(3)
    t.expect(y).to_be(2)

    t.expect(Map.to_index(map, 0, 1)).to_be_nil()
    t.expect(Map.to_index(map, 6, 1)).to_be_nil()

    local out_x, out_y = Map.from_index(map, 0)
    t.expect(out_x).to_be_nil()
    t.expect(out_y).to_be_nil()
  end)

  t.it("grid/world conversions are deterministic and bounds-safe", function()
    local map = Map.new(5, 5)
    local wx, wy = Map.grid_to_world(map, 2, 2, 16, 0, 0)
    t.expect(wx).to_be(24)
    t.expect(wy).to_be(24)

    local gx, gy = Map.world_to_grid(map, wx, wy, 16, 0, 0)
    t.expect(gx).to_be(2)
    t.expect(gy).to_be(2)

    local out_gx, out_gy = Map.world_to_grid(map, -10, -10, 16, 0, 0)
    t.expect(out_gx).to_be_nil()
    t.expect(out_gy).to_be_nil()
  end)

  t.it("prevents occupancy overlaps", function()
    local map = Map.new(3, 3)
    t.expect(Map.place(map, "player", 2, 2)).to_be(true)
    t.expect(Map.is_occupied(map, 2, 2)).to_be(true)
    t.expect(Map.place(map, "enemy", 2, 2)).to_be(false)
    t.expect(Map.place(map, "item", 2, 2)).to_be(false)

    t.expect(Map.remove(map, 2, 2, "player")).to_be(true)
    t.expect(Map.is_occupied(map, 2, 2)).to_be(false)

    t.expect(Map.place(map, "stairs_down", 2, 2)).to_be(true)
    t.expect(Map.place(map, "player", 2, 2)).to_be(false)

    t.expect(Map.place(map, "player", 0, 0)).to_be(false)
    t.expect(Map.is_occupied(map, 0, 0)).to_be_nil()
  end)
end)
