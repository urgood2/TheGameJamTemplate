-- assets/scripts/combat/stage_providers.lua
-- Stage providers: sequence, endless, hybrid

local generators = require("combat.wave_generators")

local providers = {}

--============================================
-- SEQUENCE PROVIDER (hand-crafted stages)
--============================================

function providers.sequence(stages)
    local index = 0

    return {
        next = function()
            index = index + 1
            return stages[index]
        end,

        get = function(id)
            for _, stage in ipairs(stages) do
                if stage.id == id then return stage end
            end
            return nil
        end,

        reset = function()
            index = 0
        end,

        current_index = function()
            return index
        end,

        peek = function()
            return stages[index + 1]
        end,
    }
end

--============================================
-- ENDLESS PROVIDER (procedural generation)
--============================================

function providers.endless(config)
    local stage_num = 0

    -- Defaults
    local cfg = {
        base_waves = config.base_waves or 3,
        wave_scaling = config.wave_scaling or function(n) return 3 + math.floor(n / 3) end,
        elite_every = config.elite_every or 3,
        shop_every = config.shop_every or 1,
        reward_every = config.reward_every or 5,

        enemy_pool = config.enemy_pool or {
            { type = "goblin", weight = 5, cost = 1 },
            { type = "archer", weight = 3, cost = 2 },
            { type = "dasher", weight = 2, cost = 3 },
        },

        budget_base = config.budget_base or 8,
        budget_per_stage = config.budget_per_stage or 3,
        budget_per_wave = config.budget_per_wave or 2,

        elite_pool = config.elite_pool or { "goblin", "archer", "dasher" },
        elite_modifier_count = config.elite_modifier_count or 2,

        spawn = config.spawn or "around_player",
    }

    return {
        next = function()
            stage_num = stage_num + 1

            local wave_count = cfg.wave_scaling(stage_num)
            local has_elite = (stage_num % cfg.elite_every == 0)
            local goes_to_shop = (stage_num % cfg.shop_every == 0)
            local shows_reward = (stage_num % cfg.reward_every == 0)

            -- Generate waves
            local stage_budget = cfg.budget_base + (stage_num - 1) * cfg.budget_per_stage

            local waves = generators.from_budget({
                count = wave_count,
                enemy_pool = cfg.enemy_pool,
                budget = {
                    base = stage_budget,
                    per_wave = cfg.budget_per_wave,
                },
            })

            -- Build stage config
            local stage = {
                id = "endless_" .. stage_num,
                waves = waves,
                spawn = cfg.spawn,
                difficulty_scale = 1.0 + (stage_num - 1) * 0.1,
            }

            -- Elite?
            if has_elite then
                local elite_base = cfg.elite_pool[math.random(#cfg.elite_pool)]
                local elite_modifiers = require("data.elite_modifiers")
                stage.elite = {
                    base = elite_base,
                    modifiers = elite_modifiers.roll_random(cfg.elite_modifier_count),
                }
            end

            -- Transition
            if shows_reward then
                stage.show_reward = true
            end

            if goes_to_shop then
                stage.next = "shop"
            end

            return stage
        end,

        get = function(id)
            return nil -- endless doesn't support random access
        end,

        reset = function()
            stage_num = 0
        end,

        current_index = function()
            return stage_num
        end,

        peek = function()
            return nil -- can't peek endless
        end,
    }
end

--============================================
-- HYBRID PROVIDER (hand-crafted then endless)
--============================================

function providers.hybrid(crafted_stages, endless_config)
    local sequence = providers.sequence(crafted_stages)
    local endless = providers.endless(endless_config)
    local in_endless = false

    return {
        next = function()
            if not in_endless then
                local stage = sequence.next()
                if stage then
                    return stage
                else
                    in_endless = true
                end
            end
            return endless.next()
        end,

        get = function(id)
            return sequence.get(id)
        end,

        reset = function()
            in_endless = false
            sequence.reset()
            endless.reset()
        end,

        current_index = function()
            if in_endless then
                return #crafted_stages + endless.current_index()
            end
            return sequence.current_index()
        end,

        is_endless = function()
            return in_endless
        end,
    }
end

return providers
