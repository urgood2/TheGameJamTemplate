--[[
    Procedural generation defaults / safety tests.

    Verifies the procgen APIs don't throw when callers forget to pass an RNG
    or context table. These were crashing before the guard rails were added.
]]

local procgen = require("core.procgen")

local test_procgen_defaults = {}

function test_procgen_defaults.test_loot_roll_without_rng()
    local loot = procgen.loot({
        { item = "gold", weight = 1, amount = 1 },
        picks = 1,
    })

    -- Should not error when ctx or rng is omitted
    local ok, result = pcall(function()
        local items = loot:roll({ player = {} }) -- rng omitted on purpose
        assert(#items >= 0, "loot roll should return a table")
    end)

    assert(ok, "loot:roll should not crash when rng is missing: " .. tostring(result))
    print("✓ loot roll without rng does not crash")
    return true
end

function test_procgen_defaults.test_layout_resolve_without_rng()
    local layout = procgen.layout({
        type = "rooms_and_corridors",
        rooms = { count = procgen.range(1, 1) }, -- requires rng if unguarded
    })

    local ok, result = pcall(function()
        local resolved = layout:resolve({}) -- rng omitted on purpose
        assert(resolved.type == "rooms_and_corridors", "layout type should pass through")
        assert(resolved.rooms.count == 1, "range should resolve with default rng")
    end)

    assert(ok, "layout:resolve should not crash without rng: " .. tostring(result))
    print("✓ layout resolve without rng does not crash")
    return true
end

function test_procgen_defaults.test_stats_generate_without_rng()
    local stats = procgen.stats({
        base = { health = procgen.range(5, 5), damage = 10 },
    })

    local ok, result = pcall(function()
        local generated = stats:generate({}) -- rng omitted on purpose
        assert(generated.health == 5, "health range should resolve deterministically")
        assert(generated.damage == 10, "numeric base should pass through")
    end)

    assert(ok, "stats:generate should not crash without rng: " .. tostring(result))
    print("✓ stats generate without rng does not crash")
    return true
end

function test_procgen_defaults.run_all()
    print("\n=== Running Procgen Default Guards Tests ===\n")

    local tests = {
        test_procgen_defaults.test_loot_roll_without_rng,
        test_procgen_defaults.test_layout_resolve_without_rng,
        test_procgen_defaults.test_stats_generate_without_rng,
    }

    local passed, failed = 0, 0
    for _, fn in ipairs(tests) do
        local ok, err = pcall(fn)
        if ok then
            passed = passed + 1
        else
            failed = failed + 1
            print("✗ Test failed: " .. tostring(err))
        end
    end

    print(string.format("\nResults: %d passed, %d failed\n", passed, failed))
    return failed == 0
end

if not pcall(debug.getlocal, 4, 1) then
    test_procgen_defaults.run_all()
end

return test_procgen_defaults
