-- assets/scripts/combat/wave_generators.lua
-- Generate waves from configuration

local generators = {}

--============================================
-- NORMALIZE WAVE FORMAT
--============================================

-- Ensure wave is in standard format: { "type", "type", ... } or { enemies = {...}, delay_between = N }
function generators.normalize_wave(wave)
    if not wave then return {} end

    -- Already a table with enemies key
    if wave.enemies then
        return wave
    end

    -- Simple list of enemy names
    local enemies = {}
    local delay_between = nil

    for k, v in pairs(wave) do
        if type(k) == "number" then
            table.insert(enemies, v)
        elseif k == "delay_between" then
            delay_between = v
        end
    end

    return {
        enemies = enemies,
        delay_between = delay_between
    }
end

--============================================
-- BUDGET-BASED GENERATION
--============================================

function generators.from_budget(config)
    local waves = {}
    local count = config.count or 3
    local pool = config.enemy_pool or {}
    local budget_config = config.budget or { base = 5, per_wave = 2 }
    local min_enemies = config.min_enemies or 2
    local max_enemies = config.max_enemies or 10
    local guaranteed = config.guaranteed or {}

    -- Build weighted selection table
    local total_weight = 0
    for _, entry in ipairs(pool) do
        total_weight = total_weight + (entry.weight or 1)
    end

    local function pick_enemy()
        local roll = math.random() * total_weight
        local cumulative = 0
        for _, entry in ipairs(pool) do
            cumulative = cumulative + (entry.weight or 1)
            if roll <= cumulative then
                return entry.type, entry.cost or 1
            end
        end
        return pool[1].type, pool[1].cost or 1
    end

    for wave_num = 1, count do
        -- Calculate budget for this wave
        local budget
        if type(budget_config) == "table" then
            if budget_config[wave_num] then
                budget = budget_config[wave_num]
            else
                budget = (budget_config.base or 5) + (wave_num - 1) * (budget_config.per_wave or 2)
            end
        elseif type(budget_config) == "function" then
            budget = budget_config(wave_num)
        else
            budget = budget_config
        end

        local enemies = {}
        local remaining = budget

        -- Add guaranteed enemies first
        if guaranteed[wave_num] then
            for _, enemy_type in ipairs(guaranteed[wave_num]) do
                table.insert(enemies, enemy_type)
                -- Deduct cost
                for _, entry in ipairs(pool) do
                    if entry.type == enemy_type then
                        remaining = remaining - (entry.cost or 1)
                        break
                    end
                end
            end
        end

        -- Fill remaining budget
        local safety = 100
        while remaining > 0 and #enemies < max_enemies and safety > 0 do
            safety = safety - 1
            local enemy_type, cost = pick_enemy()
            if cost <= remaining then
                table.insert(enemies, enemy_type)
                remaining = remaining - cost
            else
                -- Try to find cheaper enemy
                local found = false
                for _, entry in ipairs(pool) do
                    if (entry.cost or 1) <= remaining then
                        table.insert(enemies, entry.type)
                        remaining = remaining - (entry.cost or 1)
                        found = true
                        break
                    end
                end
                if not found then break end
            end
        end

        -- Ensure minimum enemies
        while #enemies < min_enemies do
            local enemy_type = pick_enemy()
            table.insert(enemies, enemy_type)
        end

        table.insert(waves, { enemies = enemies })
    end

    return waves
end

--============================================
-- SHORTHAND GENERATORS
--============================================

-- Quick escalating waves
function generators.escalating(config)
    local enemies = config.enemies or { "goblin" }
    local start = config.start or 3
    local add = config.add or 1
    local count = config.count or 4

    local waves = {}
    for wave_num = 1, count do
        local wave_enemies = {}
        local enemy_count = start + (wave_num - 1) * add

        for i = 1, enemy_count do
            local enemy_type = enemies[math.random(1, #enemies)]
            table.insert(wave_enemies, enemy_type)
        end

        table.insert(waves, { enemies = wave_enemies })
    end

    return waves
end

-- Budget shorthand with simpler config
function generators.budget(config)
    local pool_input = config.pool or { goblin = 1 }
    local budget_input = config.budget or "5+2n"
    local count = config.count or 4

    -- Convert pool format: { goblin = 3, archer = 2 } -> standard format
    local pool = {}
    for enemy_type, weight in pairs(pool_input) do
        table.insert(pool, { type = enemy_type, weight = weight, cost = 1 })
    end

    -- Parse budget string like "5+2n"
    local budget_config
    if type(budget_input) == "string" then
        local base, per = budget_input:match("(%d+)%+(%d+)n")
        if base and per then
            budget_config = { base = tonumber(base), per_wave = tonumber(per) }
        else
            budget_config = { base = tonumber(budget_input) or 5, per_wave = 0 }
        end
    elseif type(budget_input) == "table" then
        budget_config = budget_input
    else
        budget_config = { base = budget_input, per_wave = 0 }
    end

    return generators.from_budget({
        count = count,
        enemy_pool = pool,
        budget = budget_config,
    })
end

return generators
