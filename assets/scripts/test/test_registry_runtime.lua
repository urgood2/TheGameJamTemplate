-- assets/scripts/test/test_registry.lua
-- Doc/test coverage registry (single source of truth).
--
-- Phase 1 (bd-12l.3): Enhanced with full schema support
--
-- Schema for doc_index entries:
--   doc_id: string (e.g., "binding:physics.segment_query")
--   test_id: string (e.g., "physics.segment_query.hit_entity")
--   test_file: string (e.g., "test_physics_bindings.lua")
--   status: "verified" | "unverified"
--   reason: string (only for unverified)
--   source_ref: string (e.g., "src/systems/physics/physics_lua_bindings.cpp:segment_query")
--   category: string (e.g., "physics")
--   tags: table (e.g., {"physics", "raycast"})
--   quirks_anchor: string (optional link to quirks.md section)
--
-- Deterministic iteration: all() and doc_index() return sorted by key.
-- Consolidation-owned: Parallel agents submit mappings via Agent Mail;
-- Phase 7 sync script consolidates.

-- Optional JSON encoder for write_manifest
local json = nil
pcall(function() json = require("test.json") end)
local GeneratedRegistry = nil
pcall(function() GeneratedRegistry = require("test.test_registry") end)

local TestRegistry = {
    _tests = {},
    _doc_index = {},
    _schema_version = "1.0",
    _generated_at = nil,
    _sources = nil,
}

local function copy_list(items)
    if not items then
        return {}
    end
    local out = {}
    for i, v in ipairs(items) do
        out[i] = v
    end
    return out
end

local function has_value(items, value)
    if not items then
        return false
    end
    for _, item in ipairs(items) do
        if item == value then
            return true
        end
    end
    return false
end

local function normalize_register_args(test_id, category_or_info, meta)
    if type(category_or_info) == "table" and meta == nil then
        return test_id, category_or_info
    end
    return test_id, {
        category = category_or_info,
        tags = meta and meta.tags or nil,
        doc_ids = meta and meta.doc_ids or nil,
        requires = meta and meta.requires or nil,
        display_name = meta and meta.display_name or nil,
        test_file = meta and meta.test_file or nil,
        source_ref = meta and meta.source_ref or nil,
        quirks_anchor = meta and meta.quirks_anchor or nil,
    }
end

local function get_iso8601()
    local now = os.date("!*t")
    return string.format(
        "%04d-%02d-%02dT%02d:%02d:%02dZ",
        now.year, now.month, now.day,
        now.hour, now.min, now.sec
    )
end

function TestRegistry.register(test_id, category_or_info, meta)
    if not test_id or test_id == "" then
        error("test_id required for registry")
    end
    local _, info = normalize_register_args(test_id, category_or_info, meta)
    info = info or {}
    local entry = {
        test_id = test_id,
        test_file = info.test_file or "unknown",
        category = info.category,
        tags = copy_list(info.tags),
        doc_ids = copy_list(info.doc_ids),
        requires = copy_list(info.requires),
        display_name = info.display_name,
        status = info.status or "verified",
        source_ref = info.source_ref,
        quirks_anchor = info.quirks_anchor,
    }
    TestRegistry._tests[test_id] = entry

    -- Index each doc_id with full metadata for coverage reports
    for _, doc_id in ipairs(entry.doc_ids) do
        TestRegistry._doc_index[doc_id] = {
            doc_id = doc_id,
            test_id = test_id,
            test_file = entry.test_file,
            status = "verified",
            source_ref = entry.source_ref,
            category = entry.category,
            tags = entry.tags,
            quirks_anchor = entry.quirks_anchor,
        }
    end

    return entry
end

function TestRegistry.register_unverified(doc_id, info)
    if not doc_id or doc_id == "" then
        error("doc_id required for registry")
    end
    info = info or {}
    TestRegistry._doc_index[doc_id] = {
        doc_id = doc_id,
        test_id = nil,
        test_file = nil,
        status = "unverified",
        reason = info.reason,
        source_ref = info.source_ref,
        category = info.category,
        tags = copy_list(info.tags),
        quirks_anchor = info.quirks_anchor,
    }
end

-- Load generated registry data if available.
if GeneratedRegistry and type(GeneratedRegistry) == "table" then
    if GeneratedRegistry.schema_version then
        TestRegistry._schema_version = GeneratedRegistry.schema_version
    end
    TestRegistry._generated_at = GeneratedRegistry.generated_at
    TestRegistry._sources = GeneratedRegistry.sources
    if GeneratedRegistry.tests then
        TestRegistry._tests = GeneratedRegistry.tests
    end
    if GeneratedRegistry.docs then
        TestRegistry._doc_index = GeneratedRegistry.docs
    end
end

function TestRegistry.all()
    local out = {}
    for _, entry in pairs(TestRegistry._tests) do
        table.insert(out, entry)
    end
    table.sort(out, function(a, b)
        return a.test_id < b.test_id
    end)
    return out
end

function TestRegistry.list()
    return TestRegistry.all()
end

function TestRegistry.doc_index()
    local out = {}
    for _, entry in pairs(TestRegistry._doc_index) do
        table.insert(out, entry)
    end
    table.sort(out, function(a, b)
        return a.doc_id < b.doc_id
    end)
    return out
end

function TestRegistry.coverage_summary()
    local covered = {}
    local uncovered = {}
    local by_category = {}

    for _, entry in pairs(TestRegistry._doc_index) do
        local category = entry.category or "unknown"
        by_category[category] = by_category[category] or { covered = 0, uncovered = 0 }

        if entry.status == "verified" then
            covered[entry.doc_id] = true
            by_category[category].covered = by_category[category].covered + 1
        else
            uncovered[entry.doc_id] = true
            by_category[category].uncovered = by_category[category].uncovered + 1
        end
    end

    local covered_count = 0
    for _ in pairs(covered) do
        covered_count = covered_count + 1
    end

    local uncovered_list = {}
    for doc_id in pairs(uncovered) do
        if not covered[doc_id] then
            table.insert(uncovered_list, doc_id)
        end
    end
    table.sort(uncovered_list)

    -- Count total unique tests
    local test_count = 0
    for _ in pairs(TestRegistry._tests) do
        test_count = test_count + 1
    end

    -- Sort category summary deterministically
    local category_list = {}
    for cat, counts in pairs(by_category) do
        table.insert(category_list, {
            category = cat,
            covered = counts.covered,
            uncovered = counts.uncovered,
        })
    end
    table.sort(category_list, function(a, b) return a.category < b.category end)

    return {
        schema_version = TestRegistry._schema_version,
        total_tests = test_count,
        total_doc_ids = covered_count + #uncovered_list,
        doc_ids_covered = covered_count,
        doc_ids_uncovered = uncovered_list,
        uncovered_count = #uncovered_list,
        by_category = category_list,
    }
end

function TestRegistry.has_tag(test_id, tag)
    local entry = TestRegistry._tests[test_id]
    if not entry then
        return false
    end
    return has_value(entry.tags, tag)
end

--- Get the schema version.
function TestRegistry.schema_version()
    return TestRegistry._schema_version
end

--- Clear all entries (for testing).
function TestRegistry.clear()
    TestRegistry._tests = {}
    TestRegistry._doc_index = {}
end

--- Get a specific test entry by test_id.
function TestRegistry.get_test(test_id)
    return TestRegistry._tests[test_id]
end

--- Get a specific doc_index entry by doc_id.
function TestRegistry.get_doc(doc_id)
    return TestRegistry._doc_index[doc_id]
end

--- Export the full registry as a table for JSON serialization.
-- Returns deterministically sorted structure.
function TestRegistry.export()
    local docs = {}
    local sorted_doc_ids = {}
    for doc_id in pairs(TestRegistry._doc_index) do
        table.insert(sorted_doc_ids, doc_id)
    end
    table.sort(sorted_doc_ids)

    for _, doc_id in ipairs(sorted_doc_ids) do
        docs[doc_id] = TestRegistry._doc_index[doc_id]
    end

    local tests = {}
    local sorted_test_ids = {}
    for test_id in pairs(TestRegistry._tests) do
        table.insert(sorted_test_ids, test_id)
    end
    table.sort(sorted_test_ids)

    for _, test_id in ipairs(sorted_test_ids) do
        tests[test_id] = TestRegistry._tests[test_id]
    end

    return {
        schema_version = TestRegistry._schema_version,
        docs = docs,
        tests = tests,
    }
end

--- Count tests by category (deterministic).
function TestRegistry.tests_by_category()
    local by_cat = {}
    for _, entry in pairs(TestRegistry._tests) do
        local cat = entry.category or "unknown"
        by_cat[cat] = (by_cat[cat] or 0) + 1
    end

    local result = {}
    for cat, count in pairs(by_cat) do
        table.insert(result, { category = cat, count = count })
    end
    table.sort(result, function(a, b) return a.category < b.category end)
    return result
end

--- Build test manifest payload matching planning/schemas/test_manifest.schema.json.
function TestRegistry.build_manifest()
    return {
        schema_version = TestRegistry._schema_version,
        generated_at = get_iso8601(),
        tests = TestRegistry.all(),
        coverage_summary = TestRegistry.coverage_summary(),
    }
end

--- Write test_manifest.json with deterministic ordering.
-- Requires test.json module to be available.
-- @param path string Output path for the manifest file
-- @return boolean True if successful
function TestRegistry.write_manifest(path)
    if not json or not json.encode then
        print("[REGISTRY] ERROR: json module not available for write_manifest")
        return false
    end

    local manifest = TestRegistry.build_manifest()
    local payload = json.encode(manifest, true)

    local dir = path:match("^(.*)/")
    if dir and dir ~= "" then
        os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
        os.execute('mkdir "' .. dir:gsub("/", "\\") .. '" 2>NUL')
    end

    local file = io.open(path, "w")
    if not file then
        return false
    end
    file:write(payload)
    file:close()
    return true
end

return TestRegistry
