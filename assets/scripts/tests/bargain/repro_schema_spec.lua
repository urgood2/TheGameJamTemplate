-- assets/scripts/tests/bargain/repro_schema_spec.lua

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local repro = require("tests.bargain.repro_util")

t.describe("Bargain repro schema", function()
    t.it("emits exactly one JSON line with required fields", function()
        local state = repro.default_state()
        local calls = 0
        local last_line = nil
        local original_print = print

        local ok, err = pcall(function()
            print = function(line)
                calls = calls + 1
                last_line = tostring(line)
            end
            repro.emit_repro(state, { seed = 42, run_state = "death" })
        end)

        print = original_print
        if not ok then
            error(err)
        end

        t.expect(calls).to_be(1)
        t.expect(last_line).to_be_type("string")
        t.expect(last_line:sub(1, 1)).to_be("{")
        t.expect(last_line:sub(-1)).to_be("}")
        t.expect(last_line:find("\n")).to_be_nil()

        local required = {
            '"seed"',
            '"script_id"',
            '"floor_num"',
            '"turn"',
            '"phase"',
            '"run_state"',
            '"last_input"',
            '"pending_offer"',
            '"last_events"',
            '"digest"',
            '"digest_version"',
            '"caps_hit"',
        }

        for _, key in ipairs(required) do
            t.expect(last_line:find(key)).to_be_truthy()
        end

        t.expect(last_line:find("error_message")).to_be_nil()
    end)
end)
