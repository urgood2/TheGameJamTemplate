-- assets/scripts/bargain/deals/loader.lua

local catalog = require("bargain.data.deals.catalog")

local loader = {}

local ALLOWED_SINS = {
    wrath = true,
    pride = true,
    greed = true,
    sloth = true,
    envy = true,
    gluttony = true,
    lust = true,
}

local function validate_deal(deal)
    if type(deal) ~= "table" then
        return false, "deal_not_table"
    end
    if type(deal.id) ~= "string" then
        return false, "missing_id"
    end
    if type(deal.sin) ~= "string" or not ALLOWED_SINS[deal.sin] then
        return false, "invalid_sin"
    end
    if type(deal.name) ~= "string" then
        return false, "missing_name"
    end
    if type(deal.desc) ~= "string" then
        return false, "missing_desc"
    end
    if type(deal.tags) ~= "table" then
        return false, "missing_tags"
    end
    if type(deal.requires) ~= "table" then
        return false, "missing_requires"
    end
    if type(deal.offers_weight) ~= "number" then
        return false, "missing_offers_weight"
    end
    if type(deal.downside) ~= "table" then
        return false, "missing_downside"
    end
    return true
end

local function build_indexes(list)
    local by_id = {}
    local by_sin = {}
    for _, deal in ipairs(list) do
        by_sin[deal.sin] = by_sin[deal.sin] or {}
        table.insert(by_sin[deal.sin], deal)
        by_id[deal.id] = deal
    end
    return by_id, by_sin
end

function loader.load()
    local deals = {}
    local seen = {}

    for _, deal in ipairs(catalog) do
        local ok, err = validate_deal(deal)
        if not ok then
            error(string.format("invalid deal %s: %s", tostring(deal.id), err))
        end
        if seen[deal.id] then
            error("duplicate deal id: " .. deal.id)
        end
        seen[deal.id] = true
        deals[#deals + 1] = deal
    end

    local by_id, by_sin = build_indexes(deals)
    return {
        list = deals,
        by_id = by_id,
        by_sin = by_sin,
    }
end

return loader
