--[[
================================================================================
SHOWCASE VERIFIER
================================================================================
Validates data integrity for the Feature Showcase UI.
Runs validation rules for each category and returns badge data.
Caches results for fast repeated UI opens.
================================================================================
]]

local ShowcaseVerifier = {}

-- Cached results
local _cachedResults = nil

-- Expected items from design doc (ordered lists for showcase)
local EXPECTED_GODS_CLASSES = { "pyra", "frost", "storm", "void", "warrior", "mage", "rogue" }
local EXPECTED_SKILLS = {
    "kindle",
    "pyrokinesis",
    "fire_healing",
    "combustion",
    "flame_familiar",
    "roil",
    "scorch_master",
    "fire_form",
    "frostbite",
    "cryokinesis",
    "ice_armor",
    "shatter_synergy",
    "frost_familiar",
    "frost_turret",
    "freeze_master",
    "ice_form",
    "spark",
    "electrokinesis",
    "chain_lightning",
    "surge",
    "storm_familiar",
    "amplify_pain",
    "charge_master",
    "storm_form",
    "entropy",
    "necrokinesis",
    "cursed_flesh",
    "grave_summon",
    "doom_mark",
    "anchor_of_doom",
    "doom_master",
    "void_form",
}
local EXPECTED_ARTIFACTS = { "ember_heart", "inferno_lens", "frost_core", "glacial_ward", "storm_core", "static_field", "void_heart", "entropy_shard", "battle_trophy", "desperate_power" }
local EXPECTED_WANDS = { "RAGE_FIST", "STORM_WALKER", "FROST_ANCHOR", "SOUL_SIPHON", "PAIN_ECHO", "EMBER_PULSE" }
local EXPECTED_STATUS_EFFECTS = { "arcane_charge", "focused", "fireform", "iceform", "stormform", "voidform" }

--------------------------------------------------------------------------------
-- DATA LOADERS (with safe require)
--------------------------------------------------------------------------------

local function safeRequire(modulePath)
    local ok, module = pcall(require, modulePath)
    if ok then
        return module
    end
    return nil
end

local function loadAvatars()
    return safeRequire("data.avatars")
end

local function loadSkills()
    return safeRequire("data.skills")
end

local function loadArtifacts()
    return safeRequire("data.artifacts")
end

local function loadStatusEffects()
    return safeRequire("data.status_effects")
end

local function loadWands()
    -- Wands are defined in card_eval_order_test.lua
    -- They expose WandTemplates as part of the module
    local ok, module = pcall(require, "core.card_eval_order_test")
    if ok and module then
        -- The module returns a table; wands may be exported as wand_defs or similar
        if module.WandTemplates then
            return module.WandTemplates
        end
        if module.wand_defs then
            return module.wand_defs
        end
    end
    -- Try accessing global wand_defs if module doesn't export properly
    if _G.wand_defs then
        return _G.wand_defs
    end
    return nil
end

--------------------------------------------------------------------------------
-- VALIDATION RULES
--------------------------------------------------------------------------------

--- Validate a god or class entry
--- Rules: entry exists, type is "god" or "class", has at least one effects entry
--- For gods: at least one effects entry with type == "blessing"
local function validateGodOrClass(id, def)
    if not def then
        return false, "Entry not found"
    end
    if type(def) ~= "table" then
        return false, "Entry is not a table"
    end
    if def.type ~= "god" and def.type ~= "class" then
        return false, "Type must be 'god' or 'class'"
    end
    if not def.effects or type(def.effects) ~= "table" or #def.effects == 0 then
        return false, "Must have at least one effect"
    end
    -- Gods must have a blessing
    if def.type == "god" then
        local hasBlessing = false
        for _, eff in ipairs(def.effects) do
            if eff.type == "blessing" then
                hasBlessing = true
                break
            end
        end
        if not hasBlessing then
            return false, "God must have at least one blessing effect"
        end
    end
    return true, nil
end

--- Validate a skill entry
--- Rules: entry exists with id, name, element, and effects table
local function validateSkill(id, def)
    if not def then
        return false, "Entry not found"
    end
    if type(def) ~= "table" then
        return false, "Entry is not a table"
    end
    if not def.id then
        return false, "Missing id field"
    end
    if not def.name then
        return false, "Missing name field"
    end
    if not def.element then
        return false, "Missing element field"
    end
    if not def.effects or type(def.effects) ~= "table" then
        return false, "Missing or invalid effects table"
    end
    return true, nil
end

--- Validate an artifact entry
--- Rules: entry exists, has rarity, and a calculate function
local function validateArtifact(id, def)
    if not def then
        return false, "Entry not found"
    end
    if type(def) ~= "table" then
        return false, "Entry is not a table"
    end
    if not def.rarity then
        return false, "Missing rarity field"
    end
    if type(def.calculate) ~= "function" then
        return false, "Missing calculate function"
    end
    return true, nil
end

--- Validate a wand entry
--- Rules: entry exists with id, trigger_type, mana_max
local function validateWand(id, def)
    if not def then
        return false, "Entry not found"
    end
    if type(def) ~= "table" then
        return false, "Entry is not a table"
    end
    if not def.id then
        return false, "Missing id field"
    end
    if not def.trigger_type then
        return false, "Missing trigger_type field"
    end
    if not def.mana_max then
        return false, "Missing mana_max field"
    end
    return true, nil
end

--- Validate a status effect entry
--- Rules: entry exists with buff_type or dot_type or is_mark, and duration field
local function validateStatusEffect(id, def)
    if not def then
        return false, "Entry not found"
    end
    if type(def) ~= "table" then
        return false, "Entry is not a table"
    end
    -- Must have some effect type indicator
    if not def.buff_type and not def.dot_type and not def.is_mark then
        return false, "Must have buff_type, dot_type, or is_mark"
    end
    -- Duration can be 0 (permanent) but must exist
    if def.duration == nil then
        return false, "Missing duration field"
    end
    return true, nil
end

--------------------------------------------------------------------------------
-- CATEGORY VALIDATION
--------------------------------------------------------------------------------

local function validateGodsClasses(avatars)
    local results = { pass = 0, total = 0, items = {} }

    for _, id in ipairs(EXPECTED_GODS_CLASSES) do
        results.total = results.total + 1
        local def = avatars and avatars[id]
        local ok, err = validateGodOrClass(id, def)
        results.items[id] = { ok = ok, error = err }
        if ok then
            results.pass = results.pass + 1
        end
    end

    return results
end

local function validateSkillsCategory(skills)
    local results = { pass = 0, total = 0, items = {} }

    for _, id in ipairs(EXPECTED_SKILLS) do
        results.total = results.total + 1
        local def = skills and skills[id]
        local ok, err = validateSkill(id, def)
        results.items[id] = { ok = ok, error = err }
        if ok then
            results.pass = results.pass + 1
        end
    end

    return results
end

local function validateArtifactsCategory(artifacts)
    local results = { pass = 0, total = 0, items = {} }

    for _, id in ipairs(EXPECTED_ARTIFACTS) do
        results.total = results.total + 1
        local def = artifacts and artifacts[id]
        local ok, err = validateArtifact(id, def)
        results.items[id] = { ok = ok, error = err }
        if ok then
            results.pass = results.pass + 1
        end
    end

    return results
end

local function validateWandsCategory(wands)
    local results = { pass = 0, total = 0, items = {} }

    -- Wands are stored as an array with id field
    local wandsById = {}
    if wands then
        for _, wand in ipairs(wands) do
            if wand.id then
                wandsById[wand.id] = wand
            end
        end
    end

    for _, id in ipairs(EXPECTED_WANDS) do
        results.total = results.total + 1
        local def = wandsById[id]
        local ok, err = validateWand(id, def)
        results.items[id] = { ok = ok, error = err }
        if ok then
            results.pass = results.pass + 1
        end
    end

    return results
end

local function validateStatusEffectsCategory(statusEffects)
    local results = { pass = 0, total = 0, items = {} }

    for _, id in ipairs(EXPECTED_STATUS_EFFECTS) do
        results.total = results.total + 1
        local def = statusEffects and statusEffects[id]
        local ok, err = validateStatusEffect(id, def)
        results.items[id] = { ok = ok, error = err }
        if ok then
            results.pass = results.pass + 1
        end
    end

    return results
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Run all validations and return results
--- @return table Results with categories and optional errors
function ShowcaseVerifier.runAll()
    -- Return cached results if available
    if _cachedResults then
        return _cachedResults
    end

    local errors = {}

    -- Load all data sources
    local avatars = loadAvatars()
    local skills = loadSkills()
    local artifacts = loadArtifacts()
    local statusEffects = loadStatusEffects()
    local wands = loadWands()

    -- Track loading errors
    if not avatars then
        errors[#errors + 1] = "Failed to load avatars data"
    end
    if not skills then
        errors[#errors + 1] = "Failed to load skills data"
    end
    if not artifacts then
        errors[#errors + 1] = "Failed to load artifacts data"
    end
    if not statusEffects then
        errors[#errors + 1] = "Failed to load status_effects data"
    end
    if not wands then
        errors[#errors + 1] = "Failed to load wands data"
    end

    -- Run validations
    local results = {
        categories = {
            gods_classes = validateGodsClasses(avatars),
            skills = validateSkillsCategory(skills),
            artifacts = validateArtifactsCategory(artifacts),
            wands = validateWandsCategory(wands),
            status_effects = validateStatusEffectsCategory(statusEffects),
        },
        errors = #errors > 0 and errors or nil,
    }

    -- Cache results
    _cachedResults = results

    return results
end

--- Invalidate cached results (for testing or data refresh)
function ShowcaseVerifier.invalidate()
    _cachedResults = nil
end

--- Get ordered list of items for a category (for UI rendering)
--- @param category string Category name
--- @return table Array of item IDs in display order
function ShowcaseVerifier.getOrderedItems(category)
    if category == "gods_classes" then
        return EXPECTED_GODS_CLASSES
    elseif category == "skills" then
        return EXPECTED_SKILLS
    elseif category == "artifacts" then
        return EXPECTED_ARTIFACTS
    elseif category == "wands" then
        return EXPECTED_WANDS
    elseif category == "status_effects" then
        return EXPECTED_STATUS_EFFECTS
    end
    return {}
end

return ShowcaseVerifier
