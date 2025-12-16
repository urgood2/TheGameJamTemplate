# Logging Console Improvements Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add checkbox-based log filtering by system/level, plus clickable entity IDs, bookmarks, and export.

**Architecture:** Extend csys::Item with tag field, add filter state to ImGuiConsole, route Lua log calls through tagged spdlog wrapper.

**Tech Stack:** C++20, ImGui, spdlog, Sol2 (Lua bindings)

---

## Task 1: Add Tag Field to csys::Item

**Files:**
- Modify: `src/third_party/imgui_console/csys/item.h:36-99`
- Modify: `src/third_party/imgui_console/csys/item.inl` (if exists) or `item.cpp`

**Step 1: Add m_Tag field to Item struct**

In `src/third_party/imgui_console/csys/item.h`, add the tag field:

```cpp
struct CSYS_API Item
{
    // ... existing constructors ...

    explicit Item(ItemType type = ItemType::LOG, std::string tag = "general");

    // ... existing methods ...

    ItemType m_Type;             //!< Console item type
    std::string m_Tag;           //!< System tag (e.g., "physics", "combat")
    std::string m_Data;          //!< Item string data
    unsigned int m_TimeStamp;    //!< Record timestamp
};
```

**Step 2: Update Item constructor**

Find the Item constructor implementation (likely in `item.inl` or `item.cpp`) and update:

```cpp
Item::Item(ItemType type, std::string tag)
    : m_Type(type)
    , m_Tag(std::move(tag))
    , m_TimeStamp(/* existing timestamp logic */)
{
}
```

**Step 3: Build to verify compilation**

```bash
cd /Users/joshuashin/Projects/TheGameJamTemplate/TheGameJamTemplate/.worktrees/logging-improvements
just build-debug 2>&1 | tail -20
```

Expected: Build succeeds (warnings OK, no errors)

**Step 4: Commit**

```bash
git add src/third_party/imgui_console/csys/item.h src/third_party/imgui_console/csys/item.inl
git commit -m "feat(console): add tag field to csys::Item"
```

---

## Task 2: Add Filter State to ImGuiConsole

**Files:**
- Modify: `src/third_party/imgui_console/imgui_console.h:42-102`

**Step 1: Add predefined tags enum and filter state**

In `imgui_console.h`, add after the `COLOR_PALETTE` enum:

```cpp
    // Log filtering
    enum LogLevel {
        LEVEL_ERROR = 0,
        LEVEL_WARNING,
        LEVEL_INFO,
        LEVEL_DEBUG,
        LEVEL_COUNT
    };

    // Predefined system tags
    static constexpr std::array<const char*, 9> SYSTEM_TAGS = {
        "physics", "combat", "ai", "ui", "input",
        "audio", "scripting", "render", "entity"
    };

    std::array<bool, LEVEL_COUNT> m_LevelFilters = {true, true, true, true};
    std::array<bool, 9> m_SystemTagFilters = {true, true, true, true, true, true, true, true, true};
    std::unordered_set<std::string> m_DynamicTags;           //!< Tags seen at runtime
    std::unordered_map<std::string, bool> m_DynamicTagFilters; //!< Filter state for dynamic tags
    bool m_ShowFilters = false;  //!< Collapsible filter section state
```

**Step 2: Add required includes**

At top of `imgui_console.h`:

```cpp
#include <unordered_set>
#include <unordered_map>
```

**Step 3: Build to verify**

```bash
just build-debug 2>&1 | tail -20
```

**Step 4: Commit**

```bash
git add src/third_party/imgui_console/imgui_console.h
git commit -m "feat(console): add filter state for levels and tags"
```

---

## Task 3: Update csys Sink to Pass Tag

**Files:**
- Modify: `src/third_party/imgui_console/csys_console_sink.cpp`
- Modify: `src/third_party/imgui_console/csys/system.h` (ItemLog::log signature)

**Step 1: Add LogWithTag method to csys::System**

First check `src/third_party/imgui_console/csys/system.h` for the Log method. Add overload:

```cpp
ItemLog& Log(ItemType type, const std::string& tag = "general");
```

**Step 2: Implement LogWithTag**

In the implementation file, ensure the new Item gets the tag:

```cpp
ItemLog& System::Log(ItemType type, const std::string& tag) {
    m_ItemLog.log(type);
    if (!m_ItemLog.Items().empty()) {
        m_ItemLog.Items().back().m_Tag = tag;
    }
    return m_ItemLog;
}
```

**Step 3: Extract tag from spdlog message**

In `csys_console_sink.cpp`, parse tag from message format `[tag] message`:

```cpp
template <typename Mutex>
void csys_console_sink<Mutex>::sink_it_(const spdlog::details::log_msg& msg)
{
    spdlog::memory_buf_t formatted;
    this->formatter_->format(msg, formatted);
    std::string log_message = fmt::to_string(formatted);

    // Extract tag if present: "[tag] message" format
    std::string tag = "general";
    if (log_message.size() > 2 && log_message[0] == '[') {
        auto close_bracket = log_message.find(']');
        if (close_bracket != std::string::npos && close_bracket > 1) {
            tag = log_message.substr(1, close_bracket - 1);
            log_message = log_message.substr(close_bracket + 2); // Skip "] "
        }
    }

    csys::ItemType log_type = csys::ItemType::INFO;
    switch (msg.level) {
        case spdlog::level::err:
        case spdlog::level::critical:
            log_type = csys::ItemType::ERROR;
            break;
        case spdlog::level::warn:
            log_type = csys::ItemType::WARNING;
            break;
        case spdlog::level::info:
        case spdlog::level::debug:
        default:
            log_type = csys::ItemType::INFO;
            break;
    }

    console_system.Log(log_type, tag) << log_message << csys::endl;
    gui::consolePtr->PushScrollToBottom();
}
```

**Step 4: Build and verify**

```bash
just build-debug 2>&1 | tail -20
```

**Step 5: Commit**

```bash
git add src/third_party/imgui_console/csys_console_sink.cpp src/third_party/imgui_console/csys/system.h
git commit -m "feat(console): pass tag through spdlog sink to csys"
```

---

## Task 4: Add Filter UI (Collapsible Header)

**Files:**
- Modify: `src/third_party/imgui_console/imgui_console.cpp`

**Step 1: Add FilterSection method declaration**

In `imgui_console.h`, add in protected section:

```cpp
void FilterSection();  //!< Collapsible filter checkboxes
```

**Step 2: Implement FilterSection**

In `imgui_console.cpp`, add after `FilterBar()`:

```cpp
void ImGuiConsole::FilterSection()
{
    if (ImGui::CollapsingHeader("Filters", m_ShowFilters ? ImGuiTreeNodeFlags_DefaultOpen : 0))
    {
        m_ShowFilters = true;

        // Level filters
        ImGui::Text("Levels:");
        ImGui::SameLine();
        ImGui::Checkbox("Error", &m_LevelFilters[LEVEL_ERROR]);
        ImGui::SameLine();
        ImGui::Checkbox("Warn", &m_LevelFilters[LEVEL_WARNING]);
        ImGui::SameLine();
        ImGui::Checkbox("Info", &m_LevelFilters[LEVEL_INFO]);
        ImGui::SameLine();
        ImGui::Checkbox("Debug", &m_LevelFilters[LEVEL_DEBUG]);

        // System tag filters
        ImGui::Text("Systems:");
        for (size_t i = 0; i < SYSTEM_TAGS.size(); ++i) {
            if (i > 0 && i % 4 != 0) ImGui::SameLine();
            ImGui::Checkbox(SYSTEM_TAGS[i], &m_SystemTagFilters[i]);
        }

        // Dynamic tags (Other section)
        if (!m_DynamicTags.empty()) {
            ImGui::Text("Other:");
            int count = 0;
            for (const auto& tag : m_DynamicTags) {
                if (count > 0 && count % 4 != 0) ImGui::SameLine();
                bool& enabled = m_DynamicTagFilters[tag];
                ImGui::Checkbox(tag.c_str(), &enabled);
                ++count;
            }
        }

        // Quick toggle buttons
        ImGui::Spacing();
        if (ImGui::Button("All")) {
            std::fill(m_LevelFilters.begin(), m_LevelFilters.end(), true);
            std::fill(m_SystemTagFilters.begin(), m_SystemTagFilters.end(), true);
            for (auto& [_, v] : m_DynamicTagFilters) v = true;
        }
        ImGui::SameLine();
        if (ImGui::Button("None")) {
            std::fill(m_LevelFilters.begin(), m_LevelFilters.end(), false);
            std::fill(m_SystemTagFilters.begin(), m_SystemTagFilters.end(), false);
            for (auto& [_, v] : m_DynamicTagFilters) v = false;
        }
        ImGui::SameLine();
        if (ImGui::Button("Invert")) {
            for (auto& f : m_LevelFilters) f = !f;
            for (auto& f : m_SystemTagFilters) f = !f;
            for (auto& [_, v] : m_DynamicTagFilters) v = !v;
        }

        ImGui::Separator();
    }
    else
    {
        m_ShowFilters = false;
    }
}
```

**Step 3: Call FilterSection in Draw()**

Find the `Draw()` method and add `FilterSection()` call before `FilterBar()`:

```cpp
void ImGuiConsole::Draw()
{
    // ... existing window begin code ...

    MenuBar();
    FilterSection();  // NEW: Add this line
    FilterBar();
    LogWindow();
    InputBar();

    // ... existing window end code ...
}
```

**Step 4: Build and verify**

```bash
just build-debug 2>&1 | tail -20
```

**Step 5: Commit**

```bash
git add src/third_party/imgui_console/imgui_console.cpp src/third_party/imgui_console/imgui_console.h
git commit -m "feat(console): add collapsible filter UI with checkboxes"
```

---

## Task 5: Implement Filter Logic in LogWindow

**Files:**
- Modify: `src/third_party/imgui_console/imgui_console.cpp` (LogWindow method)

**Step 1: Add helper to check if item passes filters**

Add private method in `imgui_console.h`:

```cpp
bool PassesFilters(const csys::Item& item) const;
void RegisterDynamicTag(const std::string& tag);
```

**Step 2: Implement PassesFilters**

In `imgui_console.cpp`:

```cpp
bool ImGuiConsole::PassesFilters(const csys::Item& item) const
{
    // Check level filter
    LogLevel level;
    switch (item.m_Type) {
        case csys::ERROR: level = LEVEL_ERROR; break;
        case csys::WARNING: level = LEVEL_WARNING; break;
        case csys::INFO: level = LEVEL_INFO; break;
        case csys::LOG: level = LEVEL_DEBUG; break;
        default: level = LEVEL_DEBUG; break;
    }
    if (!m_LevelFilters[level]) return false;

    // Check tag filter
    const std::string& tag = item.m_Tag;

    // Check predefined tags
    for (size_t i = 0; i < SYSTEM_TAGS.size(); ++i) {
        if (tag == SYSTEM_TAGS[i]) {
            return m_SystemTagFilters[i];
        }
    }

    // Check dynamic tags
    auto it = m_DynamicTagFilters.find(tag);
    if (it != m_DynamicTagFilters.end()) {
        return it->second;
    }

    // Unknown tag - default to showing (and register it)
    return true;
}

void ImGuiConsole::RegisterDynamicTag(const std::string& tag)
{
    // Skip if it's a predefined tag
    for (const auto& sysTag : SYSTEM_TAGS) {
        if (tag == sysTag) return;
    }

    if (m_DynamicTags.find(tag) == m_DynamicTags.end()) {
        m_DynamicTags.insert(tag);
        m_DynamicTagFilters[tag] = true;  // Default to enabled
    }
}
```

**Step 3: Update LogWindow to use filters**

In `LogWindow()`, find the display loop and add filter check:

```cpp
for (const auto &item : m_ConsoleSystem.Items())
{
    // Register any new dynamic tags
    if (!item.m_Tag.empty()) {
        const_cast<ImGuiConsole*>(this)->RegisterDynamicTag(item.m_Tag);
    }

    // Exit if word is filtered by text filter
    if (!m_TextFilter.PassFilter(item.Get().c_str()))
        continue;

    // Exit if filtered by level/tag checkboxes
    if (!PassesFilters(item))
        continue;

    // ... rest of existing display code ...
}
```

**Step 4: Build and test**

```bash
just build-debug 2>&1 | tail -20
```

**Step 5: Commit**

```bash
git add src/third_party/imgui_console/imgui_console.cpp src/third_party/imgui_console/imgui_console.h
git commit -m "feat(console): implement level and tag filtering in log display"
```

---

## Task 6: Add Tag-Based Lua Logging Functions

**Files:**
- Modify: `src/systems/scripting/scripting_functions.cpp`

**Step 1: Add log_info and log_warn functions**

Find where `log_debug` is defined (~line 1197) and add after `log_error`:

```cpp
// log_info with tag support
stateToInit.set_function(
    "log_info", [](sol::this_state ts, sol::variadic_args va) {
        if (va.size() == 0) {
            SPDLOG_WARN("[log_info] Called with no arguments");
            return;
        }

        auto it = va.begin();
        std::string tag = "general";

        // Check if first arg is a string tag (not entity)
        if (it->is<std::string>() && va.size() >= 2) {
            // Could be tag + message, or just messages
            std::string first = it->as<std::string>();
            // Simple heuristic: short lowercase = tag
            if (first.size() <= 20 && std::all_of(first.begin(), first.end(),
                [](char c) { return std::islower(c) || c == '_'; })) {
                tag = first;
                ++it;
            }
        }

        std::ostringstream oss;
        for (; it != va.end(); ++it) {
            if (it->is<std::string>()) {
                oss << it->as<std::string>();
            } else if (it->is<int>()) {
                oss << it->as<int>();
            } else if (it->is<double>()) {
                oss << it->as<double>();
            } else if (it->is<bool>()) {
                oss << (it->as<bool>() ? "true" : "false");
            } else {
                oss << "[?]";
            }
            oss << " ";
        }

        spdlog::info("[{}] {}", tag, oss.str());
    });

// log_warn with tag support
stateToInit.set_function(
    "log_warn", [](sol::this_state ts, sol::variadic_args va) {
        if (va.size() == 0) {
            SPDLOG_WARN("[log_warn] Called with no arguments");
            return;
        }

        auto it = va.begin();
        std::string tag = "general";

        if (it->is<std::string>() && va.size() >= 2) {
            std::string first = it->as<std::string>();
            if (first.size() <= 20 && std::all_of(first.begin(), first.end(),
                [](char c) { return std::islower(c) || c == '_'; })) {
                tag = first;
                ++it;
            }
        }

        std::ostringstream oss;
        for (; it != va.end(); ++it) {
            if (it->is<std::string>()) {
                oss << it->as<std::string>();
            } else if (it->is<int>()) {
                oss << it->as<int>();
            } else if (it->is<double>()) {
                oss << it->as<double>();
            } else if (it->is<bool>()) {
                oss << (it->as<bool>() ? "true" : "false");
            } else {
                oss << "[?]";
            }
            oss << " ";
        }

        spdlog::warn("[{}] {}", tag, oss.str());
    });
```

**Step 2: Add LuaLS annotations**

Add to the function recorder section:

```cpp
rec.record_free_function(
    {}, {"log_info",
         "---@param tag string # System tag (e.g., 'physics', 'combat')\n"
         "---@param ... any # Message parts to log",
         "Logs an info message with system tag.", true, false});
rec.record_free_function(
    {}, {"log_info",
         "---@overload fun(message: string):nil",
         "Logs a general info message.", true, true});

rec.record_free_function(
    {}, {"log_warn",
         "---@param tag string # System tag\n"
         "---@param ... any # Message parts",
         "Logs a warning with system tag.", true, false});
rec.record_free_function(
    {}, {"log_warn",
         "---@overload fun(message: string):nil",
         "Logs a general warning.", true, true});
```

**Step 3: Update existing log_debug and log_error for tag support**

Modify the existing `log_debug` lambda to detect tag as first argument (same pattern as log_info).

**Step 4: Build and test**

```bash
just build-debug 2>&1 | tail -20
```

**Step 5: Commit**

```bash
git add src/systems/scripting/scripting_functions.cpp
git commit -m "feat(lua): add log_info and log_warn with tag support"
```

---

## Task 7: Update LuaLS Definitions

**Files:**
- Modify: `assets/scripts/chugget_code_definitions.lua`

**Step 1: Add log_info and log_warn definitions**

Find the log_debug/log_error section (~line 385) and add:

```lua
---Log an info message with optional system tag
---@param tag string # System tag (e.g., "physics", "combat", "ui")
---@param ... any # Message parts to concatenate
---@overload fun(message: string):nil
function log_info(...) end

---Log a warning message with optional system tag
---@param tag string # System tag (e.g., "physics", "combat", "ui")
---@param ... any # Message parts to concatenate
---@overload fun(message: string):nil
function log_warn(...) end
```

**Step 2: Update log_debug and log_error docs to mention tag**

```lua
---Log a debug message with optional system tag
---@param tag_or_entity string|Entity # System tag or entity
---@param ... any # Message parts
---@overload fun(message: string):nil
function log_debug(...) end

---Log an error message with optional system tag
---@param tag_or_entity string|Entity # System tag or entity
---@param ... any # Message parts
---@overload fun(message: string):nil
function log_error(...) end
```

**Step 3: Commit**

```bash
git add assets/scripts/chugget_code_definitions.lua
git commit -m "docs(lua): add LuaLS annotations for log_info, log_warn"
```

---

## Task 8: Persist Filter State to INI

**Files:**
- Modify: `src/third_party/imgui_console/imgui_console.cpp` (settings handlers)

**Step 1: Update SettingsHandler_WriteAll**

Find `SettingsHandler_WriteAll` and add filter state:

```cpp
// After existing settings writes:
for (size_t i = 0; i < ImGuiConsole::LEVEL_COUNT; ++i) {
    buf->appendf("LevelFilter%zu=%d\n", i, console->m_LevelFilters[i] ? 1 : 0);
}
for (size_t i = 0; i < console->SYSTEM_TAGS.size(); ++i) {
    buf->appendf("TagFilter_%s=%d\n", console->SYSTEM_TAGS[i],
                 console->m_SystemTagFilters[i] ? 1 : 0);
}
buf->appendf("ShowFilters=%d\n", console->m_ShowFilters ? 1 : 0);
```

**Step 2: Update SettingsHandler_ReadLine**

Add parsing for new settings:

```cpp
int value;
size_t idx;
char tagName[64];

if (sscanf(line, "LevelFilter%zu=%d", &idx, &value) == 2 && idx < LEVEL_COUNT) {
    console->m_LevelFilters[idx] = value != 0;
}
else if (sscanf(line, "TagFilter_%63[^=]=%d", tagName, &value) == 2) {
    for (size_t i = 0; i < console->SYSTEM_TAGS.size(); ++i) {
        if (strcmp(tagName, console->SYSTEM_TAGS[i]) == 0) {
            console->m_SystemTagFilters[i] = value != 0;
            break;
        }
    }
}
else if (sscanf(line, "ShowFilters=%d", &value) == 1) {
    console->m_ShowFilters = value != 0;
}
```

**Step 3: Build and test**

```bash
just build-debug 2>&1 | tail -20
```

**Step 4: Commit**

```bash
git add src/third_party/imgui_console/imgui_console.cpp
git commit -m "feat(console): persist filter state to imgui.ini"
```

---

## Task 9: Display Tag in Log Output

**Files:**
- Modify: `src/third_party/imgui_console/imgui_console.cpp` (LogWindow)

**Step 1: Show tag prefix in log lines**

In the LogWindow display loop, modify the text display to show tag:

```cpp
// Before displaying item text, prepend tag
std::string displayText;
if (!item.m_Tag.empty() && item.m_Tag != "general") {
    displayText = "[" + item.m_Tag + "] " + item.Get();
} else {
    displayText = item.Get();
}

if (m_ColoredOutput)
{
    ImGui::PushStyleColor(ImGuiCol_Text, m_ColorPalette[item.m_Type]);
    ImGui::TextUnformatted(displayText.c_str());
    ImGui::PopStyleColor();
}
else
{
    ImGui::TextUnformatted(displayText.c_str());
}
```

**Step 2: Build and manual test**

```bash
just build-debug && ./build/raylib-cpp-cmake-template
```

Test: Open console, check filter checkboxes work, log messages show tags.

**Step 3: Commit**

```bash
git add src/third_party/imgui_console/imgui_console.cpp
git commit -m "feat(console): display system tag prefix in log lines"
```

---

## Task 10: Add Copy Filtered Logs Button

**Files:**
- Modify: `src/third_party/imgui_console/imgui_console.cpp`

**Step 1: Add Copy button to filter section**

In `FilterSection()`, after the Invert button:

```cpp
ImGui::SameLine();
ImGui::Spacing();
ImGui::SameLine();
if (ImGui::Button("Copy Filtered")) {
    std::ostringstream oss;
    for (const auto& item : m_ConsoleSystem.Items()) {
        if (!m_TextFilter.PassFilter(item.Get().c_str())) continue;
        if (!PassesFilters(item)) continue;

        // Format: [HH:MM:SS] [tag] message
        unsigned int ts = item.m_TimeStamp;
        unsigned int hours = (ts / 3600000) % 24;
        unsigned int mins = (ts / 60000) % 60;
        unsigned int secs = (ts / 1000) % 60;

        oss << "[" << std::setfill('0') << std::setw(2) << hours
            << ":" << std::setw(2) << mins
            << ":" << std::setw(2) << secs << "] ";

        if (!item.m_Tag.empty()) {
            oss << "[" << item.m_Tag << "] ";
        }
        oss << item.Get() << "\n";
    }
    ImGui::SetClipboardText(oss.str().c_str());
}
```

**Step 2: Add include for iomanip**

At top of file:
```cpp
#include <iomanip>
```

**Step 3: Build and test**

```bash
just build-debug 2>&1 | tail -20
```

**Step 4: Commit**

```bash
git add src/third_party/imgui_console/imgui_console.cpp
git commit -m "feat(console): add Copy Filtered button to export logs"
```

---

## Task 11: Add Bookmark Support

**Files:**
- Modify: `src/third_party/imgui_console/imgui_console.h`
- Modify: `src/third_party/imgui_console/imgui_console.cpp`

**Step 1: Add bookmark state**

In `imgui_console.h`:

```cpp
std::unordered_set<size_t> m_Bookmarks;  //!< Indices of bookmarked items
int m_CurrentBookmark = -1;               //!< Current bookmark for navigation
```

**Step 2: Add bookmark toggle in LogWindow**

In the display loop, add right-click context menu:

```cpp
size_t itemIndex = &item - &m_ConsoleSystem.Items()[0];

// Right-click context menu
if (ImGui::BeginPopupContextItem(std::to_string(itemIndex).c_str())) {
    bool isBookmarked = m_Bookmarks.count(itemIndex) > 0;
    if (ImGui::MenuItem(isBookmarked ? "Remove Bookmark" : "Add Bookmark")) {
        if (isBookmarked) {
            m_Bookmarks.erase(itemIndex);
        } else {
            m_Bookmarks.insert(itemIndex);
        }
    }
    if (ImGui::MenuItem("Copy Line")) {
        ImGui::SetClipboardText(item.Get().c_str());
    }
    ImGui::EndPopup();
}

// Show bookmark indicator
if (m_Bookmarks.count(itemIndex) > 0) {
    ImGui::SameLine(0, 0);
    ImGui::TextColored(ImVec4(1.0f, 0.87f, 0.0f, 1.0f), " *");
}
```

**Step 3: Add navigation buttons**

In `FilterSection()`:

```cpp
ImGui::SameLine();
if (ImGui::Button("<Prev") && !m_Bookmarks.empty()) {
    // Navigate to previous bookmark
    // ... navigation logic
}
ImGui::SameLine();
if (ImGui::Button("Next>") && !m_Bookmarks.empty()) {
    // Navigate to next bookmark
    // ... navigation logic
}
```

**Step 4: Build and test**

```bash
just build-debug 2>&1 | tail -20
```

**Step 5: Commit**

```bash
git add src/third_party/imgui_console/imgui_console.h src/third_party/imgui_console/imgui_console.cpp
git commit -m "feat(console): add bookmark support with navigation"
```

---

## Task 12: Add Clickable Entity IDs (Basic)

**Files:**
- Modify: `src/third_party/imgui_console/imgui_console.cpp`

**Step 1: Add entity ID detection regex**

Add helper method:

```cpp
// In header:
std::vector<std::pair<size_t, size_t>> FindEntityIds(const std::string& text) const;

// In cpp:
std::vector<std::pair<size_t, size_t>> ImGuiConsole::FindEntityIds(const std::string& text) const
{
    std::vector<std::pair<size_t, size_t>> results;
    std::regex pattern(R"(entity\s+(\d+)|eid[:\s]+(\d+)|\[(\d+)\])", std::regex::icase);

    auto begin = std::sregex_iterator(text.begin(), text.end(), pattern);
    auto end = std::sregex_iterator();

    for (auto it = begin; it != end; ++it) {
        results.emplace_back(it->position(), it->length());
    }
    return results;
}
```

**Step 2: Render clickable entity IDs**

This is complex - for now, just detect and highlight. Full click handling requires integration with entity inspector which can be a follow-up task.

```cpp
// In LogWindow, when rendering text:
auto entityPositions = FindEntityIds(displayText);
if (entityPositions.empty()) {
    // Normal render
    ImGui::TextUnformatted(displayText.c_str());
} else {
    // Highlight entity IDs with different color
    // For MVP: just render with underline style
    ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.4f, 0.8f, 1.0f, 1.0f));
    ImGui::TextUnformatted(displayText.c_str());
    ImGui::PopStyleColor();
}
```

**Step 3: Add regex include**

```cpp
#include <regex>
```

**Step 4: Build and test**

```bash
just build-debug 2>&1 | tail -20
```

**Step 5: Commit**

```bash
git add src/third_party/imgui_console/imgui_console.cpp src/third_party/imgui_console/imgui_console.h
git commit -m "feat(console): detect and highlight entity IDs in logs"
```

---

## Task 13: Final Integration Test

**Step 1: Run full build**

```bash
just build-debug
```

**Step 2: Manual test checklist**

Run the game and test:
- [ ] Console shows filter section (collapsed by default)
- [ ] Level checkboxes filter by error/warn/info/debug
- [ ] System tag checkboxes filter by tag
- [ ] Dynamic tags appear in "Other" section
- [ ] "All/None/Invert" buttons work
- [ ] Filter state persists after restart
- [ ] Copy Filtered copies visible logs
- [ ] Right-click shows bookmark option
- [ ] Tags display as `[tag] message`

**Step 3: Test from Lua**

```lua
log_info("physics", "Body created")
log_warn("combat", "Low mana")
log_debug("ai", "Pathfinding started")
log_error("ui", "Sprite not found")
```

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat(console): complete logging improvements implementation"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Add tag field to csys::Item | item.h |
| 2 | Add filter state to ImGuiConsole | imgui_console.h |
| 3 | Update sink to pass tag | csys_console_sink.cpp |
| 4 | Add filter UI | imgui_console.cpp |
| 5 | Implement filter logic | imgui_console.cpp |
| 6 | Add Lua log functions | scripting_functions.cpp |
| 7 | Update LuaLS definitions | chugget_code_definitions.lua |
| 8 | Persist filter state | imgui_console.cpp |
| 9 | Display tag in output | imgui_console.cpp |
| 10 | Add Copy button | imgui_console.cpp |
| 11 | Add bookmarks | imgui_console.cpp/h |
| 12 | Highlight entity IDs | imgui_console.cpp |
| 13 | Integration test | - |
