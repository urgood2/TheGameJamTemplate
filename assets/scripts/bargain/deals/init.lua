-- assets/scripts/bargain/deals/init.lua

local deals = {}

deals.loader = require("bargain.deals.loader")
deals.offers = require("bargain.deals.offers")
deals.apply = require("bargain.deals.apply")

deals.load = deals.loader.load

deals.generate_offers = deals.offers.generate
deals.create_pending_offer = deals.offers.create_pending_offer

deals.apply_deal = deals.apply.apply_deal

return deals
