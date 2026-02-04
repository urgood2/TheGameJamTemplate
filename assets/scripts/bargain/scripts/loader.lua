-- assets/scripts/bargain/scripts/loader.lua

local loader = {}

function loader.load_all()
    local scripts = {
        (require("bargain.scripts.s1")),
        (require("bargain.scripts.s2")),
        (require("bargain.scripts.s3")),
    }

    local by_id = {}
    for _, script in ipairs(scripts) do
        by_id[script.id] = script
    end

    return {
        list = scripts,
        by_id = by_id,
    }
end

return loader
