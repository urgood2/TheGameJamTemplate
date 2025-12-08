--[[
================================================================================
CONTENT VALIDATOR
================================================================================
Validates content definitions (cards, jokers, projectiles, avatars) for:
- Required fields
- Valid enum values
- Known tag names
- ID consistency

Note: This validator does NOT enforce a strict schema for all field names to
allow for extensibility. Custom fields (e.g., new card behaviors, projectile
properties) are intentionally allowed. Only critical fields are validated.

Usage:
  Standalone: dofile("assets/scripts/tools/content_validator.lua")
  Runtime: require("tools.content_validator").validate_all(true) -- warnings only
]]

local ContentValidator = {}

-- Known valid values
local VALID_TAGS = {
    -- Elements
    "Fire", "Ice", "Lightning", "Poison", "Arcane", "Holy", "Void",
    -- Mechanics
    "Projectile", "AoE", "Hazard", "Summon", "Buff", "Debuff",
    -- Playstyle
    "Mobility", "Defense", "Brute",
}

local VALID_CARD_TYPES = { "action", "modifier", "trigger" }
local VALID_RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local VALID_MOVEMENT_TYPES = { "straight", "homing", "arc", "orbital", "custom" }
local VALID_COLLISION_TYPES = { "destroy", "pierce", "bounce", "explode", "pass_through", "chain" }
local VALID_DAMAGE_TYPES = { "physical", "fire", "ice", "lightning", "poison", "arcane", "holy", "void", "magic" }

-- Build lookup tables
local TAG_LOOKUP = {}
for _, tag in ipairs(VALID_TAGS) do TAG_LOOKUP[tag] = true end

local CARD_TYPE_LOOKUP = {}
for _, t in ipairs(VALID_CARD_TYPES) do CARD_TYPE_LOOKUP[t] = true end

local RARITY_LOOKUP = {}
for _, r in ipairs(VALID_RARITIES) do RARITY_LOOKUP[r] = true end

local MOVEMENT_LOOKUP = {}
for _, m in ipairs(VALID_MOVEMENT_TYPES) do MOVEMENT_LOOKUP[m] = true end

local COLLISION_LOOKUP = {}
for _, c in ipairs(VALID_COLLISION_TYPES) do COLLISION_LOOKUP[c] = true end

local DAMAGE_TYPE_LOOKUP = {}
for _, d in ipairs(VALID_DAMAGE_TYPES) do DAMAGE_TYPE_LOOKUP[d] = true end

-- Results accumulator
local results = {
    errors = {},
    warnings = {},
}

local function add_error(content_type, id, message)
    table.insert(results.errors, {
        type = content_type,
        id = id,
        message = message,
    })
end

local function add_warning(content_type, id, message)
    table.insert(results.warnings, {
        type = content_type,
        id = id,
        message = message,
    })
end

local function find_similar_tag(tag)
    local lower_tag = string.lower(tag)
    for _, valid in ipairs(VALID_TAGS) do
        if string.lower(valid) == lower_tag then
            return valid
        end
    end
    return nil
end

--===========================================================================
-- CARD VALIDATION
--===========================================================================
function ContentValidator.validate_card(key, card)
    local id = card.id or key

    -- Required fields
    if not card.id then
        add_error("Card", key, "missing required field 'id'")
    elseif card.id ~= key then
        add_warning("Card", key, string.format("id '%s' doesn't match table key '%s'", card.id, key))
    end

    if not card.type then
        add_error("Card", id, "missing required field 'type'")
    elseif not CARD_TYPE_LOOKUP[card.type] then
        add_error("Card", id, string.format("invalid type '%s' (expected: %s)", card.type, table.concat(VALID_CARD_TYPES, ", ")))
    end

    if card.mana_cost == nil then
        add_warning("Card", id, "missing 'mana_cost' field")
    end

    -- Tags validation
    if not card.tags then
        add_warning("Card", id, "missing 'tags' field (joker synergies won't work)")
    elseif type(card.tags) ~= "table" then
        add_error("Card", id, "'tags' must be a table")
    else
        -- Check for duplicate tags
        local seen_tags = {}
        for _, tag in ipairs(card.tags) do
            if seen_tags[tag] then
                add_warning("Card", id, string.format("duplicate tag '%s'", tag))
            end
            seen_tags[tag] = true

            if not TAG_LOOKUP[tag] then
                local similar = find_similar_tag(tag)
                if similar then
                    add_warning("Card", id, string.format("unknown tag '%s' (did you mean '%s'?)", tag, similar))
                else
                    add_warning("Card", id, string.format("unknown tag '%s'", tag))
                end
            end
        end
    end

    -- Damage type validation
    if card.damage_type and not DAMAGE_TYPE_LOOKUP[card.damage_type] then
        add_warning("Card", id, string.format("unknown damage_type '%s'", card.damage_type))
    end

    -- Type-specific validation
    if card.type == "action" then
        if card.damage and card.damage < 0 then
            add_warning("Card", id, "negative damage value")
        end
    elseif card.type == "modifier" then
        if card.damage and card.damage > 0 then
            add_warning("Card", id, "modifier has 'damage' field (use 'damage_modifier' instead)")
        end
    end
end

function ContentValidator.validate_cards()
    local ok, data = pcall(require, "data.cards")
    if not ok then
        add_error("Cards", "module", "failed to load data.cards: " .. tostring(data))
        return 0
    end

    local cards = data.Cards or data
    local count = 0

    for key, card in pairs(cards) do
        if type(card) == "table" then
            ContentValidator.validate_card(key, card)
            count = count + 1
        end
    end

    -- Also validate trigger cards if present
    if data.TriggerCards then
        for key, card in pairs(data.TriggerCards) do
            if type(card) == "table" then
                ContentValidator.validate_card(key, card)
                count = count + 1
            end
        end
    end

    return count
end

--===========================================================================
-- JOKER VALIDATION
--===========================================================================
function ContentValidator.validate_joker(key, joker)
    local id = joker.id or key

    -- Required fields
    if not joker.id then
        add_error("Joker", key, "missing required field 'id'")
    elseif joker.id ~= key then
        add_warning("Joker", key, string.format("id '%s' doesn't match table key '%s'", joker.id, key))
    end

    if not joker.name then
        add_error("Joker", id, "missing required field 'name'")
    end

    if not joker.description then
        add_warning("Joker", id, "missing 'description' field")
    end

    if not joker.calculate then
        add_error("Joker", id, "missing required 'calculate' function")
    elseif type(joker.calculate) ~= "function" then
        add_error("Joker", id, "'calculate' must be a function")
    end

    -- Rarity validation
    if joker.rarity and not RARITY_LOOKUP[joker.rarity] then
        add_warning("Joker", id, string.format("unknown rarity '%s' (expected: %s)", joker.rarity, table.concat(VALID_RARITIES, ", ")))
    end
end

function ContentValidator.validate_jokers()
    local ok, jokers = pcall(require, "data.jokers")
    if not ok then
        add_error("Jokers", "module", "failed to load data.jokers: " .. tostring(jokers))
        return 0
    end

    local count = 0
    for key, joker in pairs(jokers) do
        if type(joker) == "table" then
            ContentValidator.validate_joker(key, joker)
            count = count + 1
        end
    end

    return count
end

--===========================================================================
-- PROJECTILE VALIDATION
--===========================================================================
function ContentValidator.validate_projectile(key, proj)
    local id = proj.id or key

    -- Required fields
    if not proj.id then
        add_error("Projectile", key, "missing required field 'id'")
    elseif proj.id ~= key then
        add_warning("Projectile", key, string.format("id '%s' doesn't match table key '%s'", proj.id, key))
    end

    if not proj.speed then
        add_error("Projectile", id, "missing required field 'speed'")
    end

    if not proj.movement then
        add_error("Projectile", id, "missing required field 'movement'")
    elseif not MOVEMENT_LOOKUP[proj.movement] then
        add_error("Projectile", id, string.format("invalid movement '%s' (expected: %s)", proj.movement, table.concat(VALID_MOVEMENT_TYPES, ", ")))
    end

    if not proj.collision then
        add_error("Projectile", id, "missing required field 'collision'")
    elseif not COLLISION_LOOKUP[proj.collision] then
        add_error("Projectile", id, string.format("invalid collision '%s' (expected: %s)", proj.collision, table.concat(VALID_COLLISION_TYPES, ", ")))
    end

    -- Lifetime warning
    if not proj.lifetime then
        add_warning("Projectile", id, "missing 'lifetime' field (projectile may never despawn)")
    end

    -- Movement-specific requirements
    if proj.movement == "homing" and not proj.homing_strength then
        add_warning("Projectile", id, "homing movement without 'homing_strength'")
    end

    if proj.movement == "arc" and not proj.gravity then
        add_warning("Projectile", id, "arc movement without 'gravity'")
    end

    if proj.movement == "orbital" and not proj.orbital_radius then
        add_warning("Projectile", id, "orbital movement without 'orbital_radius'")
    end

    -- Collision-specific requirements
    if proj.collision == "pierce" and not proj.pierce_count then
        add_warning("Projectile", id, "pierce collision without 'pierce_count'")
    end

    if proj.collision == "bounce" and not proj.bounce_count then
        add_warning("Projectile", id, "bounce collision without 'bounce_count'")
    end

    if proj.collision == "explode" and not proj.explosion_radius then
        add_warning("Projectile", id, "explode collision without 'explosion_radius'")
    end

    if proj.collision == "chain" and not proj.chain_count then
        add_warning("Projectile", id, "chain collision without 'chain_count'")
    end

    -- Tags validation
    if proj.tags then
        if type(proj.tags) ~= "table" then
            add_error("Projectile", id, "'tags' must be a table")
        else
            -- Check for duplicate tags
            local seen_tags = {}
            for _, tag in ipairs(proj.tags) do
                if seen_tags[tag] then
                    add_warning("Projectile", id, string.format("duplicate tag '%s'", tag))
                end
                seen_tags[tag] = true

                if not TAG_LOOKUP[tag] then
                    add_warning("Projectile", id, string.format("unknown tag '%s'", tag))
                end
            end
        end
    end

    -- Damage type validation
    if proj.damage_type and not DAMAGE_TYPE_LOOKUP[proj.damage_type] then
        add_warning("Projectile", id, string.format("unknown damage_type '%s'", proj.damage_type))
    end
end

function ContentValidator.validate_projectiles()
    local ok, projectiles = pcall(require, "data.projectiles")
    if not ok then
        add_error("Projectiles", "module", "failed to load data.projectiles: " .. tostring(projectiles))
        return 0
    end

    local count = 0
    for key, proj in pairs(projectiles) do
        if type(proj) == "table" then
            ContentValidator.validate_projectile(key, proj)
            count = count + 1
        end
    end

    return count
end

--===========================================================================
-- AVATAR VALIDATION
--===========================================================================
function ContentValidator.validate_avatar(key, avatar)
    local id = avatar.name or key

    -- Required fields
    if not avatar.name then
        add_error("Avatar", key, "missing required field 'name'")
    end

    if not avatar.unlock then
        add_error("Avatar", id, "missing required field 'unlock'")
    elseif type(avatar.unlock) ~= "table" then
        add_error("Avatar", id, "'unlock' must be a table")
    else
        -- Check unlock has at least one condition
        local has_condition = false
        for k, v in pairs(avatar.unlock) do
            has_condition = true
            break
        end
        if not has_condition then
            add_warning("Avatar", id, "'unlock' has no conditions")
        end
    end

    if not avatar.effects then
        add_error("Avatar", id, "missing required field 'effects'")
    elseif type(avatar.effects) ~= "table" then
        add_error("Avatar", id, "'effects' must be a table")
    elseif #avatar.effects == 0 then
        add_warning("Avatar", id, "'effects' is empty (avatar does nothing)")
    else
        -- Validate each effect
        for i, effect in ipairs(avatar.effects) do
            if not effect.type then
                add_warning("Avatar", id, string.format("effect[%d] missing 'type'", i))
            end
        end
    end

    if not avatar.description then
        add_warning("Avatar", id, "missing 'description' field")
    end
end

function ContentValidator.validate_avatars()
    local ok, avatars = pcall(require, "data.avatars")
    if not ok then
        add_error("Avatars", "module", "failed to load data.avatars: " .. tostring(avatars))
        return 0
    end

    local count = 0
    for key, avatar in pairs(avatars) do
        if type(avatar) == "table" then
            ContentValidator.validate_avatar(key, avatar)
            count = count + 1
        end
    end

    return count
end

--===========================================================================
-- MAIN VALIDATION
--===========================================================================
function ContentValidator.validate_all(warnings_only)
    -- Reset results
    results.errors = {}
    results.warnings = {}

    -- Validate all content types
    local card_count = ContentValidator.validate_cards()
    local joker_count = ContentValidator.validate_jokers()
    local projectile_count = ContentValidator.validate_projectiles()
    local avatar_count = ContentValidator.validate_avatars()

    return {
        counts = {
            cards = card_count,
            jokers = joker_count,
            projectiles = projectile_count,
            avatars = avatar_count,
        },
        errors = results.errors,
        warnings = results.warnings,
    }
end

function ContentValidator.print_report()
    local result = ContentValidator.validate_all()

    print("=== CONTENT VALIDATION REPORT ===")
    print("")

    -- Cards
    print(string.format("CARDS (%d checked)", result.counts.cards))
    local card_issues = 0
    for _, err in ipairs(result.errors) do
        if err.type == "Card" then
            print(string.format("  [ERR] %s: %s", err.id, err.message))
            card_issues = card_issues + 1
        end
    end
    for _, warn in ipairs(result.warnings) do
        if warn.type == "Card" then
            print(string.format("  [WARN] %s: %s", warn.id, warn.message))
            card_issues = card_issues + 1
        end
    end
    if card_issues == 0 then
        print("  [OK] All cards valid")
    end
    print("")

    -- Jokers
    print(string.format("JOKERS (%d checked)", result.counts.jokers))
    local joker_issues = 0
    for _, err in ipairs(result.errors) do
        if err.type == "Joker" then
            print(string.format("  [ERR] %s: %s", err.id, err.message))
            joker_issues = joker_issues + 1
        end
    end
    for _, warn in ipairs(result.warnings) do
        if warn.type == "Joker" then
            print(string.format("  [WARN] %s: %s", warn.id, warn.message))
            joker_issues = joker_issues + 1
        end
    end
    if joker_issues == 0 then
        print("  [OK] All jokers valid")
    end
    print("")

    -- Projectiles
    print(string.format("PROJECTILES (%d checked)", result.counts.projectiles))
    local proj_issues = 0
    for _, err in ipairs(result.errors) do
        if err.type == "Projectile" then
            print(string.format("  [ERR] %s: %s", err.id, err.message))
            proj_issues = proj_issues + 1
        end
    end
    for _, warn in ipairs(result.warnings) do
        if warn.type == "Projectile" then
            print(string.format("  [WARN] %s: %s", warn.id, warn.message))
            proj_issues = proj_issues + 1
        end
    end
    if proj_issues == 0 then
        print("  [OK] All projectiles valid")
    end
    print("")

    -- Avatars
    print(string.format("AVATARS (%d checked)", result.counts.avatars))
    local avatar_issues = 0
    for _, err in ipairs(result.errors) do
        if err.type == "Avatar" then
            print(string.format("  [ERR] %s: %s", err.id, err.message))
            avatar_issues = avatar_issues + 1
        end
    end
    for _, warn in ipairs(result.warnings) do
        if warn.type == "Avatar" then
            print(string.format("  [WARN] %s: %s", warn.id, warn.message))
            avatar_issues = avatar_issues + 1
        end
    end
    if avatar_issues == 0 then
        print("  [OK] All avatars valid")
    end
    print("")

    -- Summary
    print("=== SUMMARY ===")
    print(string.format("Errors: %d", #result.errors))
    print(string.format("Warnings: %d", #result.warnings))

    if #result.errors == 0 and #result.warnings == 0 then
        print("\nAll content is valid!")
    end

    return result
end

-- Runtime validation (called on game init)
function ContentValidator.runtime_check()
    local result = ContentValidator.validate_all()

    -- Only print errors and warnings, not full report
    for _, err in ipairs(result.errors) do
        print(string.format("[ContentValidator] ERR: %s '%s' %s", err.type, err.id, err.message))
    end

    for _, warn in ipairs(result.warnings) do
        print(string.format("[ContentValidator] WARN: %s '%s' %s", warn.type, warn.id, warn.message))
    end

    if #result.errors > 0 or #result.warnings > 0 then
        print(string.format("[ContentValidator] Found %d errors, %d warnings", #result.errors, #result.warnings))
    end

    return #result.errors == 0
end

-- Auto-run if executed directly (dofile)
if not ... then
    ContentValidator.print_report()
end

return ContentValidator
