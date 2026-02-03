-- assets/scripts/test/test_coverage_report.lua
-- Generate doc/test coverage report from registry + executed tests.

local TestUtils = require("test.test_utils")
local TestRegistry = require("test.test_registry_runtime")

local CoverageReport = {}

local function log(message)
    TestUtils.log("[COVERAGE] " .. tostring(message or ""))
end

local function escape_md(value)
    local text = tostring(value or "")
    text = text:gsub("|", "\\|")
    text = text:gsub("\n", " ")
    return text
end

local function format_percent(numerator, denominator)
    if denominator <= 0 then
        return "0%"
    end
    local value = (numerator / denominator) * 100
    local formatted = string.format("%.1f", value)
    if formatted:sub(-2) == ".0" then
        formatted = formatted:sub(1, -3)
    end
    return formatted .. "%"
end

local function read_file(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local content = file:read("*all")
    file:close()
    return content
end

local function load_results(path)
    local ok, json = pcall(require, "external.json")
    if not ok or not json or not json.decode then
        return nil, "json_decode_unavailable"
    end
    local content = read_file(path)
    if not content then
        return nil, "results_missing"
    end
    local parsed_ok, data = pcall(json.decode, content)
    if not parsed_ok then
        return nil, "results_parse_failed"
    end
    return data, nil
end

local function normalize_test_id(entry)
    if type(entry) ~= "table" then
        return nil
    end
    if entry.name and entry.name ~= "" then
        return entry.name
    end
    if entry.test_id and entry.test_id ~= "" then
        local trimmed = entry.test_id:match("::(.+)$")
        if trimmed and trimmed ~= "" then
            return trimmed
        end
        return entry.test_id
    end
    return nil
end

local function build_executed_tests(results)
    local list = {}
    local seen = {}
    if not results or type(results.tests) ~= "table" then
        return list
    end
    for _, entry in ipairs(results.tests) do
        local test_id = normalize_test_id(entry)
        if test_id and not seen[test_id] then
            seen[test_id] = true
            table.insert(list, { id = test_id, raw = entry })
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function file_size(path)
    local file = io.open(path, "rb")
    if not file then
        return 0
    end
    local size = file:seek("end") or 0
    file:close()
    return size
end

function CoverageReport.generate(results_path, output_path)
    results_path = results_path or "test_output/results.json"
    output_path = output_path or "test_output/coverage_report.md"

    log("=== Coverage Report Generation ===")
    log("Loading test_registry.lua...")

    local doc_entries = TestRegistry.doc_index()
    local verified_entries = {}
    local unverified_entries = {}
    local by_category = {}

    for _, entry in ipairs(doc_entries) do
        local category = entry.category or "unknown"
        by_category[category] = by_category[category] or { covered = 0, uncovered = 0 }
        if entry.status == "verified" then
            by_category[category].covered = by_category[category].covered + 1
            table.insert(verified_entries, entry)
        else
            by_category[category].uncovered = by_category[category].uncovered + 1
            table.insert(unverified_entries, entry)
        end
    end

    local total_doc_ids = #doc_entries
    local verified_count = #verified_entries
    local unverified_count = #unverified_entries

    log("doc_ids: " .. total_doc_ids)
    log("Loading " .. results_path .. "...")

    local results, err = load_results(results_path)
    if not results then
        log("ERROR: Failed to load results (" .. tostring(err) .. ")")
        return false
    end

    local executed_tests = build_executed_tests(results)
    log("tests: " .. #executed_tests)

    log("Computing coverage...")
    log(string.format("  Verified: %d (%s)", verified_count, format_percent(verified_count, total_doc_ids)))
    log(string.format("  Unverified: %d (%s)", unverified_count, format_percent(unverified_count, total_doc_ids)))

    log("By category:")
    local categories = {}
    for category, counts in pairs(by_category) do
        table.insert(categories, {
            category = category,
            covered = counts.covered,
            uncovered = counts.uncovered,
        })
    end
    table.sort(categories, function(a, b) return a.category < b.category end)
    for _, entry in ipairs(categories) do
        local total = entry.covered + entry.uncovered
        log(string.format("  %s: %s (%d/%d)",
            entry.category,
            format_percent(entry.covered, total),
            entry.covered,
            total
        ))
    end

    local tests_without_docs = {}
    for _, item in ipairs(executed_tests) do
        local test_id = item.id
        local registry_entry = TestRegistry.get_test(test_id)
        local doc_ids = nil
        if type(item.raw.doc_ids) == "table" then
            doc_ids = item.raw.doc_ids
        elseif registry_entry and type(registry_entry.doc_ids) == "table" then
            doc_ids = registry_entry.doc_ids
        else
            doc_ids = {}
        end
        if #doc_ids == 0 then
            table.insert(tests_without_docs, test_id)
        end
    end

    log("Tests without doc_ids: " .. #tests_without_docs)
    log("Writing " .. output_path .. "...")

    local lines = {}
    table.insert(lines, "## Coverage Summary")
    table.insert(lines, string.format("- Total doc_ids: %d", total_doc_ids))
    table.insert(lines, string.format("- Verified: %d (%s)", verified_count, format_percent(verified_count, total_doc_ids)))
    table.insert(lines, string.format("- Unverified: %d (%s)", unverified_count, format_percent(unverified_count, total_doc_ids)))
    table.insert(lines, "")

    table.insert(lines, "## Coverage by Category")
    table.insert(lines, "| Category | Verified | Unverified | Coverage |")
    table.insert(lines, "|----------|----------|------------|----------|")
    if #categories == 0 then
        table.insert(lines, "| _none_ | 0/0 | 0 | 0% |")
    else
        for _, entry in ipairs(categories) do
            local total = entry.covered + entry.uncovered
            table.insert(lines, string.format(
                "| %s | %d/%d | %d | %s |",
                escape_md(entry.category),
                entry.covered,
                total,
                entry.uncovered,
                format_percent(entry.covered, total)
            ))
        end
    end
    table.insert(lines, "")

    table.insert(lines, "## Verified Docs")
    table.insert(lines, "| doc_id | Test | Category |")
    table.insert(lines, "|--------|------|----------|")
    if #verified_entries == 0 then
        table.insert(lines, "| _none_ | - | - |")
    else
        for _, entry in ipairs(verified_entries) do
            local test_label = "-"
            if entry.test_id then
                if entry.test_file and entry.test_file ~= "" and entry.test_file ~= "unknown" then
                    test_label = entry.test_file .. "::" .. entry.test_id
                else
                    test_label = entry.test_id
                end
            end
            table.insert(lines, string.format(
                "| %s | %s | %s |",
                escape_md(entry.doc_id),
                escape_md(test_label),
                escape_md(entry.category or "unknown")
            ))
        end
    end
    table.insert(lines, "")

    table.insert(lines, "## Unverified Docs")
    table.insert(lines, "| doc_id | Reason | Source |")
    table.insert(lines, "|--------|--------|--------|")
    if #unverified_entries == 0 then
        table.insert(lines, "| _none_ | - | - |")
    else
        for _, entry in ipairs(unverified_entries) do
            table.insert(lines, string.format(
                "| %s | %s | %s |",
                escape_md(entry.doc_id),
                escape_md(entry.reason or "Unverified"),
                escape_md(entry.source_ref or "-")
            ))
        end
    end
    table.insert(lines, "")

    table.insert(lines, "## Tests Without Doc Coverage")
    if #tests_without_docs == 0 then
        table.insert(lines, "All executed tests include doc_id links.")
    else
        table.insert(lines, "These tests need doc_id links added:")
        for _, test_id in ipairs(tests_without_docs) do
            table.insert(lines, "- " .. escape_md(test_id) .. " (no doc_ids)")
        end
    end

    local ok = TestUtils.write_file(output_path, table.concat(lines, "\n"), true)
    if not ok then
        log("ERROR: Failed to write coverage report")
        return false
    end

    log(string.format("Report written (%d bytes)", file_size(output_path)))
    return true
end

return CoverageReport
