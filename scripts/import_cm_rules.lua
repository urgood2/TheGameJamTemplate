#!/usr/bin/env lua
-- scripts/import_cm_rules.lua
-- Idempotent cm playbook importer from planning/cm_rules_candidates.yaml

local function log(message)
    io.stdout:write("[CM-IMPORT] " .. tostring(message or "") .. "\n")
end

local function log_error(message)
    io.stderr:write("[CM-IMPORT] ERROR: " .. tostring(message or "") .. "\n")
end

local function shell_escape(value)
    local text = tostring(value or "")
    return "'" .. text:gsub("'", "'\\''") .. "'"
end

local function run_cmd_capture(cmd)
    local handle = io.popen(cmd, "r")
    if not handle then
        return nil, "popen_failed"
    end
    local output = handle:read("*all")
    local ok, _, code = handle:close()
    if not ok then
        return nil, "command_failed:" .. tostring(code)
    end
    return output, nil
end

local function run_cmd(cmd)
    local ok, _, code = os.execute(cmd)
    if ok == true or ok == 0 then
        return true
    end
    return false, code
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

local function normalize(text)
    local value = tostring(text or "")
    value = value:lower()
    value = value:gsub("%s+", " ")
    value = value:gsub("[^%w%s]", "")
    value = value:gsub("^%s+", ""):gsub("%s+$", "")
    return value
end

local function fingerprint(category, rule_text)
    return normalize(tostring(category or "") .. ":" .. tostring(rule_text or ""))
end

local function get_repo_root()
    local script_path = arg and arg[0] or "scripts/import_cm_rules.lua"
    local script_dir = script_path:match("(.+)/[^/]+$") or "."
    if script_dir == "" then
        script_dir = "."
    end
    return script_dir .. "/.."
end

local function load_json_module(repo_root)
    package.path = repo_root .. "/assets/scripts/?.lua;" .. repo_root .. "/assets/scripts/?/init.lua;" .. package.path
    local ok, json = pcall(require, "external.json")
    if not ok or not json or not json.decode then
        return nil, "json_module_missing"
    end
    return json, nil
end

local function load_candidates(repo_root, json)
    local path = repo_root .. "/planning/cm_rules_candidates.yaml"
    local python = "python3"
    local code = string.format(
        "import json,yaml; from pathlib import Path; data=yaml.safe_load(Path(%q).read_text()); print(json.dumps(data))",
        path
    )
    local cmd = python .. " -c " .. string.format("%q", code)
    local output, err = run_cmd_capture(cmd)
    if not output then
        return nil, "yaml_load_failed:" .. tostring(err)
    end
    local ok, data = pcall(json.decode, output)
    if not ok then
        return nil, "json_decode_failed"
    end
    return data, nil
end

local function get_existing_rules(json)
    local tmp = os.tmpname()
    local cmd = "cm playbook list --json > " .. shell_escape(tmp)
    local ok = run_cmd(cmd)
    if not ok then
        return nil, "cm_list_failed"
    end
    local output = read_file(tmp) or ""
    os.remove(tmp)
    local ok_decode, data = pcall(json.decode, output)
    if not ok_decode then
        return nil, "cm_list_parse_failed"
    end
    return data, nil
end

local function export_backup(repo_root)
    local path = repo_root .. "/planning/cm_rules_backup.json"
    local cmd = "cm playbook export --json > " .. shell_escape(path)
    local ok = run_cmd(cmd)
    if not ok then
        return false, "cm_export_failed"
    end
    return true, nil
end

local function format_rule_text(rule)
    local text = tostring(rule.rule_text or "")
    if rule.test_ref and rule.test_ref ~= "" then
        text = text .. " (Verified: Test: " .. tostring(rule.test_ref) .. ")"
    end
    return "[" .. tostring(rule.rule_id or "") .. "] " .. text
end

local function parse_args(argv)
    local opts = { dry_run = false, verbose = false }
    for _, value in ipairs(argv or {}) do
        if value == "--dry-run" then
            opts.dry_run = true
        elseif value == "--verbose" then
            opts.verbose = true
        elseif value == "--import" then
            opts.dry_run = false
        end
    end
    return opts
end

local function main()
    local repo_root = get_repo_root()
    local opts = parse_args(arg)
    local json, json_err = load_json_module(repo_root)
    if not json then
        log_error(json_err)
        return 2
    end

    log("=== cm Rules Import ===")
    log("Loading planning/cm_rules_candidates.yaml...")
    local candidates, cand_err = load_candidates(repo_root, json)
    if not candidates then
        log_error(cand_err)
        return 2
    end

    local rules = candidates.rules or {}
    table.sort(rules, function(a, b)
        return tostring(a.rule_id or "") < tostring(b.rule_id or "")
    end)

    local counts = { verified = 0, unverified = 0, pending = 0, proposed = 0, deprecated = 0 }
    for _, rule in ipairs(rules) do
        local status = tostring(rule.status or "")
        if status == "verified" then
            counts.verified = counts.verified + 1
        elseif status == "unverified" then
            counts.unverified = counts.unverified + 1
        elseif status == "pending" then
            counts.pending = counts.pending + 1
        elseif status == "proposed" then
            counts.proposed = counts.proposed + 1
        elseif status == "deprecated" then
            counts.deprecated = counts.deprecated + 1
        else
            counts.unverified = counts.unverified + 1
        end
    end

    log(string.format("Found %d rule candidates", #rules))
    log(string.format("  Verified: %d", counts.verified))
    log(string.format("  Unverified: %d (will skip)", counts.unverified))
    if counts.pending > 0 then
        log(string.format("  Pending: %d (will skip)", counts.pending))
    end
    if counts.proposed > 0 then
        log(string.format("  Proposed: %d (will skip)", counts.proposed))
    end

    if not opts.dry_run then
        log("Exporting backup to planning/cm_rules_backup.json...")
        local ok, err = export_backup(repo_root)
        if not ok then
            log_error(err)
            return 2
        end
    end

    local existing, existing_err = get_existing_rules(json)
    if not existing then
        log_error(existing_err)
        return 2
    end

    local existing_by_rule_id = {}
    for _, bullet in ipairs(existing.bullets or {}) do
        local content = tostring(bullet.content or "")
        local rule_id = content:match("^%[([^%]]+)%]%s")
        if rule_id and rule_id ~= "" then
            existing_by_rule_id[rule_id] = bullet
        end
    end

    local seen_fingerprints = {}
    local stats = { added = 0, updated = 0, skipped_unverified = 0, skipped_dupe = 0, unchanged = 0 }

    log("Importing verified rules...")
    for _, rule in ipairs(rules) do
        local skip = false

        if tostring(rule.status or "") ~= "verified" then
            log(string.format("  %s: SKIP (not verified)", tostring(rule.rule_id)))
            stats.skipped_unverified = stats.skipped_unverified + 1
            skip = true
        end

        local fp = nil
        if not skip then
            fp = fingerprint(rule.category, rule.rule_text)
            if seen_fingerprints[fp] then
                log(string.format("  %s: SKIP (duplicate fingerprint)", tostring(rule.rule_id)))
                stats.skipped_dupe = stats.skipped_dupe + 1
                skip = true
            else
                seen_fingerprints[fp] = true
            end
        end

        local content = nil
        local existing_rule = nil
        if not skip then
            content = format_rule_text(rule)
            existing_rule = existing_by_rule_id[rule.rule_id]
            if existing_rule and existing_rule.content == content and existing_rule.category == rule.category then
                log(string.format("  %s: SKIP (unchanged)", tostring(rule.rule_id)))
                stats.unchanged = stats.unchanged + 1
                skip = true
            end
        end

        if not skip and opts.dry_run then
            if existing_rule then
                log(string.format("  %s: would update in %s", tostring(rule.rule_id), tostring(rule.category)))
                stats.updated = stats.updated + 1
            else
                log(string.format("  %s: would add to %s", tostring(rule.rule_id), tostring(rule.category)))
                stats.added = stats.added + 1
            end
            skip = true
        end

        if not skip then
            if existing_rule then
                local remove_ok = run_cmd("cm playbook remove " .. tostring(existing_rule.id))
                if not remove_ok then
                    log_error("Failed to remove existing rule: " .. tostring(rule.rule_id))
                    return 2
                end
            end

            local cmd = string.format(
                "cm playbook add %s --category %s",
                shell_escape(content),
                shell_escape(rule.category)
            )
            local add_ok = run_cmd(cmd)
            if not add_ok then
                log_error("Failed to add rule: " .. tostring(rule.rule_id))
                return 2
            end

            if existing_rule then
                stats.updated = stats.updated + 1
                log(string.format("  %s: updated in %s", tostring(rule.rule_id), tostring(rule.category)))
            else
                stats.added = stats.added + 1
                log(string.format("  %s: added to %s", tostring(rule.rule_id), tostring(rule.category)))
            end
        end
    end

    log("=== SUMMARY ===")
    log(string.format("Added: %d", stats.added))
    log(string.format("Updated: %d", stats.updated))
    log(string.format("Skipped (duplicate): %d", stats.skipped_dupe))
    log(string.format("Skipped (not verified): %d", stats.skipped_unverified))

    return 0
end

os.exit(main())
