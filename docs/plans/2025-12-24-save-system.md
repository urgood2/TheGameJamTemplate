# Save System Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a robust, async save system for roguelike meta-progression.

**Architecture:** Lua-primary with C++ file I/O bindings. Collectors pattern for decoupled save logic. Sequential migrations for schema evolution. Async writes (threaded on desktop, IDBFS on web).

**Tech Stack:** C++20, Lua/Sol2, nlohmann/json, std::thread (desktop), Emscripten FS (web)

**Design Document:** `docs/plans/2025-12-24-save-system-design.md`

---

## Task 1: C++ File I/O - Header

**Files:**
- Create: `src/systems/save/save_file_io.hpp`

**Step 1: Create the header file**

```cpp
#pragma once

#include <functional>
#include <optional>
#include <string>

#include "sol/sol.hpp"

namespace save_io {

/// Synchronously load file content. Returns nullopt if file doesn't exist or read fails.
auto load_file(const std::string& path) -> std::optional<std::string>;

/// Check if file exists at path.
auto file_exists(const std::string& path) -> bool;

/// Delete file at path. Returns true if deleted or didn't exist.
auto delete_file(const std::string& path) -> bool;

/// Asynchronously save content to file with atomic write pattern.
/// Desktop: Background thread with atomic rename.
/// Web: MEMFS write + async IDBFS sync.
/// Callback receives success boolean.
void save_file_async(const std::string& path,
                     const std::string& content,
                     sol::function on_complete);

/// Process pending callbacks on main thread. Call once per frame.
void process_pending_callbacks();

/// Register Lua bindings for save_io module.
void register_lua_bindings(sol::state& lua);

} // namespace save_io
```

**Step 2: Commit**

```bash
git add src/systems/save/save_file_io.hpp
git commit -m "feat(save): add save_file_io header"
```

---

## Task 2: C++ File I/O - Implementation (Sync Operations)

**Files:**
- Create: `src/systems/save/save_file_io.cpp`

**Step 1: Implement synchronous operations**

```cpp
#include "save_file_io.hpp"

#include <filesystem>
#include <fstream>
#include <mutex>
#include <queue>
#include <sstream>

#include "spdlog/spdlog.h"

#if defined(__EMSCRIPTEN__)
#include <emscripten/emscripten.h>
#endif

namespace save_io {
namespace {

namespace fs = std::filesystem;

// Pending callbacks to run on main thread
struct PendingCallback {
    sol::function callback;
    bool success;
};

std::mutex g_callback_mutex;
std::queue<PendingCallback> g_pending_callbacks;

void queue_callback(sol::function callback, bool success) {
    if (!callback.valid()) return;
    std::lock_guard<std::mutex> lock(g_callback_mutex);
    g_pending_callbacks.push({std::move(callback), success});
}

} // anonymous namespace

auto load_file(const std::string& path) -> std::optional<std::string> {
    std::ifstream file(path, std::ios::binary);
    if (!file.is_open()) {
        SPDLOG_DEBUG("save_io::load_file - file not found: {}", path);
        return std::nullopt;
    }

    std::ostringstream ss;
    ss << file.rdbuf();

    if (file.fail() && !file.eof()) {
        SPDLOG_WARN("save_io::load_file - read error: {}", path);
        return std::nullopt;
    }

    return ss.str();
}

auto file_exists(const std::string& path) -> bool {
    std::error_code ec;
    return fs::exists(path, ec);
}

auto delete_file(const std::string& path) -> bool {
    std::error_code ec;
    if (!fs::exists(path, ec)) {
        return true; // Already doesn't exist
    }
    return fs::remove(path, ec);
}

void process_pending_callbacks() {
    std::queue<PendingCallback> to_process;
    {
        std::lock_guard<std::mutex> lock(g_callback_mutex);
        std::swap(to_process, g_pending_callbacks);
    }

    while (!to_process.empty()) {
        auto& pending = to_process.front();
        if (pending.callback.valid()) {
            auto result = pending.callback(pending.success);
            if (!result.valid()) {
                sol::error err = result;
                SPDLOG_WARN("save_io callback error: {}", err.what());
            }
        }
        to_process.pop();
    }
}

} // namespace save_io
```

**Step 2: Commit**

```bash
git add src/systems/save/save_file_io.cpp
git commit -m "feat(save): implement sync file operations"
```

---

## Task 3: C++ File I/O - Async Save (Desktop)

**Files:**
- Modify: `src/systems/save/save_file_io.cpp`

**Step 1: Add atomic write helper and async save**

Add after `delete_file` implementation, before `process_pending_callbacks`:

```cpp
namespace {

bool write_atomic(const std::string& path, const std::string& content) {
    const std::string temp_path = path + ".tmp";
    const std::string backup_path = path + ".bak";

    // Ensure parent directory exists
    std::error_code ec;
    fs::path parent = fs::path(path).parent_path();
    if (!parent.empty()) {
        fs::create_directories(parent, ec);
        if (ec) {
            SPDLOG_WARN("save_io::write_atomic - failed to create directory: {}", parent.string());
            return false;
        }
    }

    // Write to temp file
    {
        std::ofstream file(temp_path, std::ios::binary | std::ios::trunc);
        if (!file.is_open()) {
            SPDLOG_WARN("save_io::write_atomic - failed to open temp file: {}", temp_path);
            return false;
        }
        file << content;
        file.flush();
        if (file.fail()) {
            SPDLOG_WARN("save_io::write_atomic - write failed: {}", temp_path);
            return false;
        }
    }

    // Atomic rename temp -> target
    fs::rename(temp_path, path, ec);
    if (ec) {
        SPDLOG_WARN("save_io::write_atomic - rename failed: {} -> {}", temp_path, path);
        fs::remove(temp_path, ec);
        return false;
    }

    // Create backup (non-fatal if fails)
    fs::copy_file(path, backup_path, fs::copy_options::overwrite_existing, ec);
    if (ec) {
        SPDLOG_DEBUG("save_io::write_atomic - backup copy failed (non-fatal): {}", backup_path);
    }

    SPDLOG_DEBUG("save_io::write_atomic - saved successfully: {}", path);
    return true;
}

} // anonymous namespace
```

**Step 2: Add save_file_async implementation**

Add after `delete_file`:

```cpp
void save_file_async(const std::string& path,
                     const std::string& content,
                     sol::function on_complete) {
#if defined(__EMSCRIPTEN__)
    // Web: Write to MEMFS (sync), then async persist to IndexedDB
    bool success = write_atomic(path, content);

    if (success) {
        // Async sync to IndexedDB
        EM_ASM({
            if (typeof FS !== 'undefined' && FS.syncfs) {
                FS.syncfs(false, function(err) {
                    if (err) {
                        console.warn('IDBFS sync failed:', err);
                    }
                });
            }
        });
    }

    // Callback immediately - MEMFS write is what matters for gameplay
    queue_callback(std::move(on_complete), success);

#else
    // Desktop: Background thread
    // Copy callback to shared_ptr for thread safety
    auto callback_ptr = std::make_shared<sol::function>(std::move(on_complete));

    std::thread([path, content, callback_ptr]() {
        bool success = write_atomic(path, content);
        queue_callback(std::move(*callback_ptr), success);
    }).detach();
#endif
}
```

**Step 3: Add thread include at top**

```cpp
#include <thread>
```

**Step 4: Commit**

```bash
git add src/systems/save/save_file_io.cpp
git commit -m "feat(save): implement async save with atomic writes"
```

---

## Task 4: C++ File I/O - Lua Bindings

**Files:**
- Modify: `src/systems/save/save_file_io.cpp`

**Step 1: Add register_lua_bindings implementation**

Add at end of file, before closing `namespace save_io`:

```cpp
void register_lua_bindings(sol::state& lua) {
    sol::table save_io_table = lua.create_named_table("save_io");

    save_io_table.set_function("load_file", &load_file);
    save_io_table.set_function("file_exists", &file_exists);
    save_io_table.set_function("delete_file", &delete_file);
    save_io_table.set_function("save_file_async", &save_file_async);

    SPDLOG_DEBUG("save_io Lua bindings registered");
}
```

**Step 2: Commit**

```bash
git add src/systems/save/save_file_io.cpp
git commit -m "feat(save): add Lua bindings for save_io"
```

---

## Task 5: Integrate C++ into Build System

**Files:**
- Modify: `CMakeLists.txt` (add source file to main target)
- Modify: `src/systems/scripting/scripting_functions.cpp` (register bindings)

**Step 1: Find the main source list in CMakeLists.txt**

Search for where source files are listed (likely `add_executable` or `set(SOURCES ...)`).

Add to source list:
```cmake
src/systems/save/save_file_io.cpp
```

**Step 2: Add include and binding registration in scripting_functions.cpp**

Add include near other system includes:
```cpp
#include "systems/save/save_file_io.hpp"
```

Add binding registration in `initLuaMasterState`, after other `exposeToLua` calls:
```cpp
//---------------------------------------------------------
// methods from save/save_file_io.cpp. These can be called from lua
//---------------------------------------------------------
save_io::register_lua_bindings(stateToInit);
```

**Step 3: Add process_pending_callbacks to game loop**

In `src/core/game.cpp`, find the main update loop and add:
```cpp
#include "systems/save/save_file_io.hpp"

// In update loop:
save_io::process_pending_callbacks();
```

**Step 4: Build and verify**

```bash
just build-debug
```

**Step 5: Commit**

```bash
git add CMakeLists.txt src/systems/scripting/scripting_functions.cpp src/core/game.cpp
git commit -m "feat(save): integrate save_io into build and game loop"
```

---

## Task 6: Unit Tests for C++ File I/O

**Files:**
- Create: `tests/unit/test_save_file_io.cpp`
- Modify: `tests/CMakeLists.txt`

**Step 1: Create test file**

```cpp
#include <gtest/gtest.h>

#include <filesystem>
#include <fstream>
#include <thread>
#include <chrono>

#include "systems/save/save_file_io.hpp"

namespace fs = std::filesystem;

class SaveFileIOTest : public ::testing::Test {
protected:
    void SetUp() override {
        temp_dir = fs::temp_directory_path() / "save_file_io_test";
        fs::create_directories(temp_dir);
    }

    void TearDown() override {
        std::error_code ec;
        fs::remove_all(temp_dir, ec);
    }

    fs::path temp_dir;
};

TEST_F(SaveFileIOTest, LoadFileReturnsNulloptForMissingFile) {
    auto result = save_io::load_file((temp_dir / "nonexistent.json").string());
    EXPECT_FALSE(result.has_value());
}

TEST_F(SaveFileIOTest, LoadFileReturnsContentForExistingFile) {
    auto path = temp_dir / "test.json";
    {
        std::ofstream f(path);
        f << R"({"version": 1})";
    }

    auto result = save_io::load_file(path.string());
    ASSERT_TRUE(result.has_value());
    EXPECT_EQ(*result, R"({"version": 1})");
}

TEST_F(SaveFileIOTest, FileExistsReturnsFalseForMissing) {
    EXPECT_FALSE(save_io::file_exists((temp_dir / "nope.json").string()));
}

TEST_F(SaveFileIOTest, FileExistsReturnsTrueForExisting) {
    auto path = temp_dir / "exists.json";
    { std::ofstream f(path); f << "{}"; }
    EXPECT_TRUE(save_io::file_exists(path.string()));
}

TEST_F(SaveFileIOTest, DeleteFileRemovesFile) {
    auto path = temp_dir / "to_delete.json";
    { std::ofstream f(path); f << "{}"; }

    EXPECT_TRUE(fs::exists(path));
    EXPECT_TRUE(save_io::delete_file(path.string()));
    EXPECT_FALSE(fs::exists(path));
}

TEST_F(SaveFileIOTest, DeleteFileSucceedsForMissingFile) {
    EXPECT_TRUE(save_io::delete_file((temp_dir / "already_gone.json").string()));
}
```

**Step 2: Add to tests/CMakeLists.txt**

Add to the `add_executable(unit_tests ...)` list:
```cmake
unit/test_save_file_io.cpp
${CMAKE_SOURCE_DIR}/src/systems/save/save_file_io.cpp
```

**Step 3: Run tests**

```bash
just test
```

Expected: All tests pass.

**Step 4: Commit**

```bash
git add tests/unit/test_save_file_io.cpp tests/CMakeLists.txt
git commit -m "test(save): add unit tests for save_file_io"
```

---

## Task 7: Lua JSON Library

**Files:**
- Create: `assets/scripts/external/json.lua`

**Step 1: Add a minimal JSON encoder/decoder**

Use the well-tested `dkjson` library or similar. For brevity, here's a minimal implementation:

```lua
--
-- json.lua - Simple JSON encoder/decoder for Lua
-- Based on public domain code
--

local json = { _version = "1.0.0" }

local encode

local escape_char_map = {
    ["\\"] = "\\\\", ["\""] = "\\\"", ["\b"] = "\\b",
    ["\f"] = "\\f", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t",
}

local function escape_char(c)
    return escape_char_map[c] or string.format("\\u%04x", c:byte())
end

local function encode_string(val)
    return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end

local function encode_number(val)
    if val ~= val or val <= -math.huge or val >= math.huge then
        error("unexpected number value '" .. tostring(val) .. "'")
    end
    return string.format("%.14g", val)
end

local type_encode_funcs = {
    ["nil"] = function() return "null" end,
    ["boolean"] = function(val) return val and "true" or "false" end,
    ["number"] = encode_number,
    ["string"] = encode_string,
    ["table"] = function(val, stack)
        local res = {}
        stack = stack or {}

        if stack[val] then error("circular reference") end
        stack[val] = true

        if rawget(val, 1) ~= nil or next(val) == nil then
            -- Array
            local n = 0
            for k in pairs(val) do
                if type(k) ~= "number" then
                    n = -1
                    break
                end
                n = math.max(n, k)
            end
            if n >= 0 then
                for i = 1, n do
                    res[i] = encode(val[i], stack)
                end
                stack[val] = nil
                return "[" .. table.concat(res, ",") .. "]"
            end
        end

        -- Object
        for k, v in pairs(val) do
            if type(k) ~= "string" then
                error("invalid key type '" .. type(k) .. "'")
            end
            res[#res + 1] = encode_string(k) .. ":" .. encode(v, stack)
        end
        stack[val] = nil
        return "{" .. table.concat(res, ",") .. "}"
    end,
}

encode = function(val, stack)
    local t = type(val)
    local f = type_encode_funcs[t]
    if f then
        return f(val, stack)
    end
    error("unexpected type '" .. t .. "'")
end

function json.encode(val)
    return encode(val)
end

-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local parse

local literal_map = {
    ["true"] = true, ["false"] = false, ["null"] = nil,
}

local function create_set(...)
    local res = {}
    for i = 1, select("#", ...) do
        res[select(i, ...)] = true
    end
    return res
end

local space_chars = create_set(" ", "\t", "\r", "\n")
local delim_chars = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local escape_char_map_inv = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/",
    ["b"] = "\b", ["f"] = "\f", ["n"] = "\n", ["r"] = "\r", ["t"] = "\t" }

local function next_char(str, idx, set, negate)
    for i = idx, #str do
        if set[str:sub(i, i)] ~= negate then
            return i
        end
    end
    return #str + 1
end

local function decode_error(str, idx, msg)
    local line_count = 1
    local col_count = 1
    for i = 1, idx - 1 do
        col_count = col_count + 1
        if str:sub(i, i) == "\n" then
            line_count = line_count + 1
            col_count = 1
        end
    end
    error(string.format("%s at line %d col %d", msg, line_count, col_count))
end

local function parse_unicode_escape(s)
    local n = tonumber(s, 16)
    if not n then return nil end
    return string.char(n)
end

local function parse_string(str, i)
    local res = ""
    local j = i + 1
    local k = j
    while j <= #str do
        local x = str:byte(j)
        if x < 32 then
            decode_error(str, j, "control character in string")
        elseif x == 92 then -- backslash
            res = res .. str:sub(k, j - 1)
            j = j + 1
            local c = str:sub(j, j)
            if c == "u" then
                local hex = str:match("^[dD][89telefonAaBb]%x%x\\u%x%x%x%x", j + 1)
                        or str:match("^%x%x%x%x", j + 1)
                if not hex then
                    decode_error(str, j, "invalid unicode escape in string")
                end
                res = res .. parse_unicode_escape(hex:sub(1, 4))
                j = j + 4
            else
                if not escape_chars[c] then
                    decode_error(str, j, "invalid escape char '" .. c .. "' in string")
                end
                res = res .. escape_char_map_inv[c]
            end
            k = j + 1
        elseif x == 34 then -- quote
            res = res .. str:sub(k, j - 1)
            return res, j + 1
        end
        j = j + 1
    end
    decode_error(str, i, "expected closing quote for string")
end

local function parse_number(str, i)
    local x = next_char(str, i, delim_chars)
    local s = str:sub(i, x - 1)
    local n = tonumber(s)
    if not n then
        decode_error(str, i, "invalid number '" .. s .. "'")
    end
    return n, x
end

local function parse_literal(str, i)
    local x = next_char(str, i, delim_chars)
    local word = str:sub(i, x - 1)
    if literal_map[word] == nil and word ~= "null" then
        decode_error(str, i, "invalid literal '" .. word .. "'")
    end
    return literal_map[word], x
end

local function parse_array(str, i)
    local res = {}
    local n = 1
    i = i + 1
    while true do
        local x
        i = next_char(str, i, space_chars, true)
        if str:sub(i, i) == "]" then
            i = i + 1
            break
        end
        x, i = parse(str, i)
        res[n] = x
        n = n + 1
        i = next_char(str, i, space_chars, true)
        local chr = str:sub(i, i)
        i = i + 1
        if chr == "]" then break end
        if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
    end
    return res, i
end

local function parse_object(str, i)
    local res = {}
    i = i + 1
    while true do
        local key, val
        i = next_char(str, i, space_chars, true)
        if str:sub(i, i) == "}" then
            i = i + 1
            break
        end
        if str:sub(i, i) ~= '"' then
            decode_error(str, i, "expected string for key")
        end
        key, i = parse_string(str, i)
        i = next_char(str, i, space_chars, true)
        if str:sub(i, i) ~= ":" then
            decode_error(str, i, "expected ':' after key")
        end
        i = next_char(str, i + 1, space_chars, true)
        val, i = parse(str, i)
        res[key] = val
        i = next_char(str, i, space_chars, true)
        local chr = str:sub(i, i)
        i = i + 1
        if chr == "}" then break end
        if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
    end
    return res, i
end

local char_parse_funcs = {
    ['"'] = parse_string,
    ["0"] = parse_number, ["1"] = parse_number, ["2"] = parse_number,
    ["3"] = parse_number, ["4"] = parse_number, ["5"] = parse_number,
    ["6"] = parse_number, ["7"] = parse_number, ["8"] = parse_number,
    ["9"] = parse_number, ["-"] = parse_number,
    ["t"] = parse_literal, ["f"] = parse_literal, ["n"] = parse_literal,
    ["["] = parse_array,
    ["{"] = parse_object,
}

parse = function(str, idx)
    local chr = str:sub(idx, idx)
    local f = char_parse_funcs[chr]
    if f then
        return f(str, idx)
    end
    decode_error(str, idx, "unexpected character '" .. chr .. "'")
end

function json.decode(str)
    if type(str) ~= "string" then
        error("expected argument of type string, got " .. type(str))
    end
    local res, idx = parse(str, next_char(str, 1, space_chars, true))
    idx = next_char(str, idx, space_chars, true)
    if idx <= #str then
        decode_error(str, idx, "trailing garbage")
    end
    return res
end

return json
```

**Step 2: Commit**

```bash
git add assets/scripts/external/json.lua
git commit -m "feat(save): add Lua JSON library"
```

---

## Task 8: Lua SaveManager - Core Structure

**Files:**
- Create: `assets/scripts/core/save_manager.lua`

**Step 1: Create SaveManager with core structure**

```lua
---@class SaveManager
---@field private collectors table<string, Collector>
---@field private cache table
---@field private save_in_progress boolean
---@field private pending_save table|nil

local json = require("external.json")

local SaveManager = {
    SAVE_VERSION = 1,
    SAVE_PATH = "saves/profile.json",
    BACKUP_PATH = "saves/profile.json.bak",

    collectors = {},
    cache = {},
    save_in_progress = false,
    pending_save = nil,
}

---@class Collector
---@field collect fun(): table
---@field distribute fun(data: table): nil

--- Register a collector for a save data section
---@param key string The key in the save file
---@param collector Collector The collector with collect/distribute functions
function SaveManager.register(key, collector)
    if not collector.collect or not collector.distribute then
        error("SaveManager.register: collector must have 'collect' and 'distribute' functions")
    end
    SaveManager.collectors[key] = collector
    SPDLOG_DEBUG("SaveManager: registered collector '%s'", key)
end

--- Collect all data from registered collectors
---@return table
function SaveManager.collect_all()
    local data = {
        version = SaveManager.SAVE_VERSION,
        saved_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }

    for key, collector in pairs(SaveManager.collectors) do
        local success, result = pcall(collector.collect)
        if success then
            data[key] = result
        else
            SPDLOG_WARN("SaveManager: collector '%s' failed: %s", key, tostring(result))
        end
    end

    return data
end

--- Distribute loaded data to all registered collectors
---@param data table
function SaveManager.distribute_all(data)
    for key, collector in pairs(SaveManager.collectors) do
        if data[key] then
            local success, err = pcall(collector.distribute, data[key])
            if not success then
                SPDLOG_WARN("SaveManager: distributor '%s' failed: %s", key, tostring(err))
            end
        end
    end
    SaveManager.cache = data
end

return SaveManager
```

**Step 2: Commit**

```bash
git add assets/scripts/core/save_manager.lua
git commit -m "feat(save): add SaveManager core structure"
```

---

## Task 9: Lua SaveManager - Save/Load Operations

**Files:**
- Modify: `assets/scripts/core/save_manager.lua`

**Step 1: Add migrations require and import**

At top after json require:
```lua
local migrations = require("core.save_migrations")
```

**Step 2: Add migrate function after distribute_all**

```lua
--- Run migrations on old save data
---@param data table
---@return table
local function migrate(data)
    local save_version = data.version or 1

    while save_version < SaveManager.SAVE_VERSION do
        local next_version = save_version + 1
        local migration = migrations[next_version]

        if migration then
            SPDLOG_INFO("SaveManager: migrating v%d → v%d", save_version, next_version)
            local success, result = pcall(migration, data)
            if success then
                data = result
                data.version = next_version
            else
                SPDLOG_ERROR("SaveManager: migration to v%d failed: %s", next_version, tostring(result))
                break
            end
        end

        save_version = next_version
    end

    return data
end
```

**Step 3: Add save/load functions after migrate**

```lua
--- Trigger an async save
---@param callback? fun(success: boolean)
function SaveManager.save(callback)
    local data = SaveManager.collect_all()

    if SaveManager.save_in_progress then
        -- Queue this save for later
        SaveManager.pending_save = { data = data, callback = callback }
        SPDLOG_DEBUG("SaveManager: save queued (another in progress)")
        return
    end

    SaveManager.save_in_progress = true
    local content = json.encode(data)

    save_io.save_file_async(SaveManager.SAVE_PATH, content, function(success)
        SaveManager.save_in_progress = false

        if callback then
            callback(success)
        end

        if success then
            SaveManager.cache = data
            SPDLOG_DEBUG("SaveManager: save complete")
        else
            SPDLOG_WARN("SaveManager: save failed")
        end

        -- Process queued save if any
        if SaveManager.pending_save then
            local queued = SaveManager.pending_save
            SaveManager.pending_save = nil
            SaveManager.save(queued.callback)
        end
    end)
end

--- Load save data and distribute to collectors
function SaveManager.load()
    -- Try main save
    local content = save_io.load_file(SaveManager.SAVE_PATH)

    if content then
        local success, data = pcall(json.decode, content)
        if success and type(data) == "table" then
            local old_version = data.version or 1

            -- Migrate if needed
            if old_version < SaveManager.SAVE_VERSION then
                data = migrate(data)
                -- Save migrated data immediately
                SaveManager.save()
            end

            SaveManager.distribute_all(data)
            SPDLOG_INFO("SaveManager: loaded save (v%d)", data.version or 1)
            return
        end
        SPDLOG_WARN("SaveManager: main save corrupted, trying backup")
    end

    -- Try backup
    local backup = save_io.load_file(SaveManager.BACKUP_PATH)
    if backup then
        local success, data = pcall(json.decode, backup)
        if success and type(data) == "table" then
            data = migrate(data)
            SaveManager.distribute_all(data)
            SaveManager.save() -- Repair main save
            SPDLOG_INFO("SaveManager: restored from backup")
            return
        end
        SPDLOG_WARN("SaveManager: backup also corrupted")
    end

    -- Fresh start
    SPDLOG_INFO("SaveManager: no valid save found, starting fresh")
    SaveManager.create_new()
end

--- Create a fresh save with defaults
function SaveManager.create_new()
    SaveManager.cache = {
        version = SaveManager.SAVE_VERSION,
        saved_at = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }
    SaveManager.distribute_all(SaveManager.cache)
end

--- Check if a save file exists
---@return boolean
function SaveManager.has_save()
    return save_io.file_exists(SaveManager.SAVE_PATH)
end

--- Delete all save data
function SaveManager.delete_save()
    save_io.delete_file(SaveManager.SAVE_PATH)
    save_io.delete_file(SaveManager.BACKUP_PATH)
    SaveManager.cache = {}
    SPDLOG_INFO("SaveManager: save deleted")
end

--- Get cached data for a key without loading
---@param key string
---@return table|nil
function SaveManager.peek(key)
    return SaveManager.cache[key]
end

--- Initialize the save system (call early in startup)
function SaveManager.init()
    SPDLOG_INFO("SaveManager: initializing")
    SaveManager.load()
end
```

**Step 4: Commit**

```bash
git add assets/scripts/core/save_manager.lua
git commit -m "feat(save): add SaveManager save/load operations"
```

---

## Task 10: Lua Migrations File

**Files:**
- Create: `assets/scripts/core/save_migrations.lua`

**Step 1: Create migrations file**

```lua
---@type table<number, fun(data: table): table>
local migrations = {}

-- Example migration (commented out - add real ones as needed):
-- migrations[2] = function(data)
--     data.statistics = data.statistics or {
--         runs_completed = 0,
--         highest_wave = 0,
--         total_kills = 0,
--     }
--     return data
-- end

return migrations
```

**Step 2: Commit**

```bash
git add assets/scripts/core/save_migrations.lua
git commit -m "feat(save): add save migrations scaffold"
```

---

## Task 11: Integration - Add Example Collector

**Files:**
- Create: `assets/scripts/core/statistics.lua` (or modify existing if present)

**Step 1: Create a statistics module with SaveManager integration**

```lua
local SaveManager = require("core.save_manager")

local Statistics = {
    runs_completed = 0,
    highest_wave = 0,
    total_kills = 0,
    total_gold_earned = 0,
    playtime_seconds = 0,
}

-- Register with SaveManager
SaveManager.register("statistics", {
    collect = function()
        return {
            runs_completed = Statistics.runs_completed,
            highest_wave = Statistics.highest_wave,
            total_kills = Statistics.total_kills,
            total_gold_earned = Statistics.total_gold_earned,
            playtime_seconds = Statistics.playtime_seconds,
        }
    end,

    distribute = function(data)
        Statistics.runs_completed = data.runs_completed or 0
        Statistics.highest_wave = data.highest_wave or 0
        Statistics.total_kills = data.total_kills or 0
        Statistics.total_gold_earned = data.total_gold_earned or 0
        Statistics.playtime_seconds = data.playtime_seconds or 0
    end
})

--- Increment a statistic and trigger save
---@param stat string
---@param amount? number
function Statistics.increment(stat, amount)
    amount = amount or 1
    if Statistics[stat] ~= nil then
        Statistics[stat] = Statistics[stat] + amount
        SaveManager.save()
    end
end

--- Set a statistic if new value is higher
---@param stat string
---@param value number
function Statistics.set_high(stat, value)
    if Statistics[stat] ~= nil and value > Statistics[stat] then
        Statistics[stat] = value
        SaveManager.save()
    end
end

return Statistics
```

**Step 2: Commit**

```bash
git add assets/scripts/core/statistics.lua
git commit -m "feat(save): add Statistics module with SaveManager integration"
```

---

## Task 12: Integration - Initialize in main.lua

**Files:**
- Modify: `assets/scripts/core/main.lua`

**Step 1: Add SaveManager initialization**

Find the `main.init()` function. Add early (before other systems that need saved data):

```lua
-- At top with other requires:
local SaveManager = require("core.save_manager")

-- In main.init(), early:
SaveManager.init()

-- Require modules that register collectors:
require("core.statistics")
```

**Step 2: Commit**

```bash
git add assets/scripts/core/main.lua
git commit -m "feat(save): integrate SaveManager into main init"
```

---

## Task 13: Manual Testing

**Steps:**

1. Build the game:
```bash
just build-debug
```

2. Run the game and verify in logs:
- "SaveManager: initializing"
- "SaveManager: no valid save found, starting fresh" (first run)

3. In Lua console or debug, call:
```lua
local Stats = require("core.statistics")
Stats.increment("runs_completed")
Stats.increment("total_kills", 10)
```

4. Check that `saves/profile.json` was created with correct structure.

5. Restart the game and verify:
- "SaveManager: loaded save (v1)"
- Stats values are restored

6. Test backup recovery:
- Corrupt `saves/profile.json` (add garbage)
- Restart game
- Verify "restored from backup" message

**Step: Commit any fixes**

```bash
git add -A
git commit -m "fix(save): address issues from manual testing"
```

---

## Task 14: Web Build Verification

**Steps:**

1. Build for web:
```bash
just build-web
```

2. Serve locally and test in browser

3. Verify:
- Save creates without errors
- Data persists after page refresh (IDBFS works)
- No console errors about FS or syncfs

**Step: Commit any web-specific fixes**

```bash
git add -A
git commit -m "fix(save): ensure web build compatibility"
```

---

## Summary

After completing all tasks, you'll have:

1. **C++ layer** (`src/systems/save/`)
   - Atomic writes with temp file + rename
   - Backup on every save
   - Async saves (threaded on desktop, IDBFS on web)
   - Lua bindings for file I/O

2. **Lua layer** (`assets/scripts/core/`)
   - `save_manager.lua` - Central API
   - `save_migrations.lua` - Version migrations
   - `statistics.lua` - Example collector

3. **Tests**
   - Unit tests for C++ file I/O
   - Manual integration tests

**Total new code:** ~400 lines as estimated.
