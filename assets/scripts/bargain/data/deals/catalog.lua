-- assets/scripts/bargain/data/deals/catalog.lua

local wrath = require("bargain.data.deals.wrath")
local pride = require("bargain.data.deals.pride")
local greed = require("bargain.data.deals.greed")
local sloth = require("bargain.data.deals.sloth")
local envy = require("bargain.data.deals.envy")
local gluttony = require("bargain.data.deals.gluttony")
local lust = require("bargain.data.deals.lust")

local deals = {}

local function append(list)
    for i = 1, #list do
        deals[#deals + 1] = list[i]
    end
end

append(wrath)
append(pride)
append(greed)
append(sloth)
append(envy)
append(gluttony)
append(lust)

return deals
