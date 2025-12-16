// Copyright (c) 2020 - present, Roland Munguia
// Distributed under the MIT License (http://opensource.org/licenses/MIT)

//#pragma once

#include <string>
#include <algorithm>
#include <regex>
#include "imgui_console.h"
#include "util/common_headers.hpp"
#include "third_party/rlImGui/imgui_internal.h"
#include "systems/event/event_system.hpp"
#include "systems/ai/ai_system.hpp"
#include <cstring>
#include <iomanip>
#include "sol/sol.hpp"

// The following three functions (InputTextCallback_UserData, InputTextCallback, InputText) are obtained from misc/cpp/imgui_stdlib.h
// Which are licensed under MIT License (https://github.com/ocornut/imgui/blob/master/LICENSE.txt)
namespace ImGui
{
    struct InputTextCallback_UserData
    {
        std::string *Str;
        ImGuiInputTextCallback ChainCallback;
        void *ChainCallbackUserData;
    };

    static int InputTextCallback(ImGuiInputTextCallbackData *data)
    {
        auto *user_data = (InputTextCallback_UserData *) data->UserData;
        if (data->EventFlag == ImGuiInputTextFlags_CallbackResize)
        {
            // Resize string callback
            // If for some reason we refuse the new length (BufTextLen) and/or capacity (BufSize) we need to set them back to what we want.
            std::string *str = user_data->Str;
            IM_ASSERT(data->Buf == str->c_str());
            str->resize(data->BufTextLen);
            data->Buf = (char *) str->c_str();
        }
        else if (user_data->ChainCallback)
        {
            // Forward to user callback, if any
            data->UserData = user_data->ChainCallbackUserData;
            return user_data->ChainCallback(data);
        }
        return 0;
    }

    bool InputText(const char *label, std::string *str, ImGuiInputTextFlags flags, ImGuiInputTextCallback callback, void *user_data)
    {
        IM_ASSERT((flags & ImGuiInputTextFlags_CallbackResize) == 0);
        flags |= ImGuiInputTextFlags_CallbackResize;

        InputTextCallback_UserData cb_user_data;
        cb_user_data.Str = str;
        cb_user_data.ChainCallback = callback;
        cb_user_data.ChainCallbackUserData = user_data;
        return InputText(label, (char *) str->c_str(), str->capacity() + 1, flags, InputTextCallback, &cb_user_data);
    }
}

ImGuiConsole::ImGuiConsole(std::string c_name, size_t inputBufferSize) : m_ConsoleName(std::move(c_name))
{
    // Set input buffer size.
    m_Buffer.resize(inputBufferSize);
    m_HistoryIndex = std::numeric_limits<size_t>::min();

    m_luaMode = false; // Initialize Lua mode to false

    // Specify custom data to be store/loaded from imgui.ini
    InitIniSettings();

    // subscribe to event when luastate is changed
    event_system::Subscribe<ai_system::LuaStateResetEvent>([this](const ai_system::LuaStateResetEvent &event, event_system::MyEmitter&) {
        SetLuaState(*event.masterStateLua);
        SPDLOG_DEBUG("Lua state reset in the ai system. Updating pointer.");
    });

    // Set Console ImGui default settings
    if (!m_LoadedFromIni)
    {
        DefaultSettings();
    }

    // Custom functions.
    RegisterConsoleCommands();
}

void ImGuiConsole::Draw()
{
    ///////////////////////////////////////////////////////////////////////////
    // Window and Settings ////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////

    // Begin Console Window.
    ImGui::PushStyleVar(ImGuiStyleVar_Alpha, m_WindowAlpha);
    if (!ImGui::Begin(m_ConsoleName.data(), nullptr, ImGuiWindowFlags_MenuBar))
    {
        ImGui::PopStyleVar();
        ImGui::End();
        return;
    }
    ImGui::PopStyleVar();

    ///////////////
    // Menu bar  //
    ///////////////
    MenuBar();

    ////////////////////
    // Filter section //
    ////////////////////
    FilterSection();

    ////////////////
    // Filter bar //
    ////////////////
    if (m_FilterBar)
    { FilterBar(); }

    //////////////////
    // Console Logs //
    //////////////////
    LogWindow();

    // Section off.
    ImGui::Separator();

    ///////////////////////////////////////////////////////////////////////////
    // Command-line ///////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////

    InputBar();

    ImGui::End();
}

csys::System &ImGuiConsole::System()
{ return m_ConsoleSystem; }

void ImGuiConsole::InitIniSettings()
{
    ImGuiContext &g = *ImGui::GetCurrentContext();

    // Load from .ini
    if (g.Initialized && !g.SettingsLoaded && !m_LoadedFromIni)
    {
        ImGuiSettingsHandler console_ini_handler;
        console_ini_handler.TypeName = "imgui-console";
        console_ini_handler.TypeHash = ImHashStr("imgui-console");
        console_ini_handler.ClearAllFn = SettingsHandler_ClearALl;
        console_ini_handler.ApplyAllFn = SettingsHandler_ApplyAll;
        console_ini_handler.ReadInitFn = SettingsHandler_ReadInit;
        console_ini_handler.ReadOpenFn = SettingsHandler_ReadOpen;
        console_ini_handler.ReadLineFn = SettingsHandler_ReadLine;
        console_ini_handler.WriteAllFn = SettingsHandler_WriteAll;
        console_ini_handler.UserData = this;
        g.SettingsHandlers.push_back(console_ini_handler);
    }
    // else Ini settings already loaded!
}

void ImGuiConsole::DefaultSettings()
{
    // Settings
    m_AutoScroll = true;
    m_ScrollToBottom = false;
    m_ColoredOutput = true;
    m_FilterBar = true;
    m_TimeStamps = true;

    // Log filters (default: show all)
    std::fill(m_LevelFilters.begin(), m_LevelFilters.end(), true);
    std::fill(m_SystemTagFilters.begin(), m_SystemTagFilters.end(), true);
    m_ShowFilters = false;

    // Style
    m_WindowAlpha = 1;
    m_ColorPalette[COL_COMMAND] = ImVec4(1.f, 1.f, 1.f, 1.f);
    m_ColorPalette[COL_LOG] = ImVec4(1.f, 1.f, 1.f, 0.5f);
    m_ColorPalette[COL_WARNING] = ImVec4(1.0f, 0.87f, 0.37f, 1.f);
    m_ColorPalette[COL_ERROR] = ImVec4(1.f, 0.365f, 0.365f, 1.f);
    m_ColorPalette[COL_INFO] = ImVec4(0.46f, 0.96f, 0.46f, 1.f);
    m_ColorPalette[COL_TIMESTAMP] = ImVec4(1.f, 1.f, 1.f, 0.5f);
}

void ImGuiConsole::RegisterConsoleCommands()
{
    m_ConsoleSystem.RegisterCommand("clear", "Clear console log", [this]()
    {
        m_ConsoleSystem.Items().clear();
        m_Bookmarks.clear();
        m_CurrentBookmark = -1;
    });

    m_ConsoleSystem.RegisterCommand("filter", "Set screen filter", [this](const csys::String &filter)
    {
        // Reset filter buffer.
        std::memset(m_TextFilter.InputBuf, '\0', 256);

        // Copy filter input buffer from client.
        std::copy(filter.m_String.c_str(), filter.m_String.c_str() + std::min(static_cast<int>(filter.m_String.length()), 255), m_TextFilter.InputBuf);

        // Build text filter.
        m_TextFilter.Build();

    }, csys::Arg<csys::String>("filter_str"));

    m_ConsoleSystem.RegisterCommand("run", "Run given script", [this](const csys::String &filter)
    {
        // Logs command.
        m_ConsoleSystem.RunScript(filter.m_String);
    }, csys::Arg<csys::String>("script_name"));

    // New command to toggle Lua mode
    m_ConsoleSystem.RegisterCommand("lua_mode", "Toggle Lua mode", [this]()
    {
        m_luaMode = !m_luaMode;
        m_ConsoleSystem.Log(csys::LOG) << "Lua mode " << (m_luaMode ? "enabled" : "disabled") << csys::endl;
    });


}

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

        // Bookmark navigation
        ImGui::SameLine();
        if (ImGui::Button("<Prev") && !m_Bookmarks.empty()) {
            // Find previous bookmark
            std::vector<size_t> sortedBookmarks(m_Bookmarks.begin(), m_Bookmarks.end());
            std::sort(sortedBookmarks.begin(), sortedBookmarks.end());

            if (m_CurrentBookmark < 0) {
                m_CurrentBookmark = static_cast<int>(sortedBookmarks.back());
            } else {
                auto it = std::lower_bound(sortedBookmarks.begin(), sortedBookmarks.end(), m_CurrentBookmark);
                if (it != sortedBookmarks.begin()) {
                    --it;
                    m_CurrentBookmark = static_cast<int>(*it);
                } else {
                    m_CurrentBookmark = static_cast<int>(sortedBookmarks.back());
                }
            }
        }
        ImGui::SameLine();
        if (ImGui::Button("Next>") && !m_Bookmarks.empty()) {
            // Find next bookmark
            std::vector<size_t> sortedBookmarks(m_Bookmarks.begin(), m_Bookmarks.end());
            std::sort(sortedBookmarks.begin(), sortedBookmarks.end());

            if (m_CurrentBookmark < 0) {
                m_CurrentBookmark = static_cast<int>(sortedBookmarks.front());
            } else {
                auto it = std::upper_bound(sortedBookmarks.begin(), sortedBookmarks.end(), m_CurrentBookmark);
                if (it != sortedBookmarks.end()) {
                    m_CurrentBookmark = static_cast<int>(*it);
                } else {
                    m_CurrentBookmark = static_cast<int>(sortedBookmarks.front());
                }
            }
        }
        ImGui::SameLine();
        ImGui::Text("(%zu bookmarks)", m_Bookmarks.size());

        ImGui::Separator();
    }
    else
    {
        m_ShowFilters = false;
    }
}

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

    // Unknown tag - default to showing
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

std::vector<std::pair<size_t, size_t>> ImGuiConsole::FindEntityIds(const std::string& text) const
{
    std::vector<std::pair<size_t, size_t>> results;
    static const std::regex pattern(R"(entity\s+(\d+)|eid[:\s]+(\d+)|\[(\d+)\])", std::regex::icase);

    auto begin = std::sregex_iterator(text.begin(), text.end(), pattern);
    auto end = std::sregex_iterator();

    for (auto it = begin; it != end; ++it) {
        results.emplace_back(it->position(), it->length());
    }
    return results;
}

void ImGuiConsole::FilterBar()
{
    m_TextFilter.Draw("Filter", ImGui::GetWindowWidth() * 0.25f);
    ImGui::Separator();
}

void ImGuiConsole::LogWindow()
{
    const float footerHeightToReserve = ImGui::GetStyle().ItemSpacing.y + ImGui::GetFrameHeightWithSpacing();
    if (ImGui::BeginChild("ScrollRegion##", ImVec2(0, -footerHeightToReserve), false, 0))
    {
        // Display colored command output.
        static const float timestamp_width = ImGui::CalcTextSize("00:00:00:0000").x;    // Timestamp.
        int count = 0;                                                                       // Item count.

        // Wrap items.
        ImGui::PushTextWrapPos();

        // Display items.
        for (const auto &item : m_ConsoleSystem.Items())
        {
            // Register any new dynamic tags
            if (!item.m_Tag.empty()) {
                RegisterDynamicTag(item.m_Tag);
            }

            // Exit if word is filtered by text filter
            if (!m_TextFilter.PassFilter(item.Get().c_str()))
                continue;

            // Exit if filtered by level/tag checkboxes
            if (!PassesFilters(item))
                continue;

            // Spacing between commands.
            if (item.m_Type == csys::COMMAND)
            {
                if (m_TimeStamps) ImGui::PushTextWrapPos(ImGui::GetColumnWidth() - timestamp_width);    // Wrap before timestamps start.
                if (count++ != 0) ImGui::Dummy(ImVec2(-1, ImGui::GetFontSize()));                            // No space for the first command.
            }

            // Items.
            // Build display text with tag prefix if available
            std::string displayText;
            if (!item.m_Tag.empty() && item.m_Tag != "general") {
                displayText = "[" + item.m_Tag + "] " + item.Get();
            } else {
                displayText = item.Get();
            }

            // Check if log contains entity IDs
            auto entityPositions = FindEntityIds(displayText);

            if (m_ColoredOutput)
            {
                if (!entityPositions.empty()) {
                    // Has entity IDs - use cyan highlight for entire line as MVP
                    ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.4f, 0.8f, 1.0f, 1.0f));
                    ImGui::TextUnformatted(displayText.c_str());
                    ImGui::PopStyleColor();
                } else {
                    ImGui::PushStyleColor(ImGuiCol_Text, m_ColorPalette[item.m_Type]);
                    ImGui::TextUnformatted(displayText.c_str());
                    ImGui::PopStyleColor();
                }
            }
            else
            {
                ImGui::TextUnformatted(displayText.c_str());
            }

            // Get item index for bookmarking
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


            // Time stamp.
            if (item.m_Type == csys::COMMAND && m_TimeStamps)
            {
                // No wrap for timestamps
                ImGui::PopTextWrapPos();

                // Right align.
                ImGui::SameLine(ImGui::GetColumnWidth(-1) - timestamp_width);

                // Draw time stamp.
                ImGui::PushStyleColor(ImGuiCol_Text, m_ColorPalette[COL_TIMESTAMP]);
                ImGui::Text("%02d:%02d:%02d:%04d", ((item.m_TimeStamp / 1000 / 3600) % 24), ((item.m_TimeStamp / 1000 / 60) % 60),
                            ((item.m_TimeStamp / 1000) % 60), item.m_TimeStamp % 1000);
                ImGui::PopStyleColor();

            }
        }

        // Stop wrapping since we are done displaying console items.
        ImGui::PopTextWrapPos();

        // Auto-scroll logs.
        if ((m_ScrollToBottom && (ImGui::GetScrollY() >= ImGui::GetScrollMaxY() || m_AutoScroll)))
            ImGui::SetScrollHereY(1.0f);
        m_ScrollToBottom = false;

        // Loop through command string vector.
        ImGui::EndChild();
    }
}

// New method to run Lua code using Sol2
void ImGuiConsole::RunLuaCode(const std::string &code)
{
    try {
        sol::protected_function_result result = m_luaState->script(code, sol::script_pass_on_error);
        if (!result.valid())
        {
            sol::error err = result;
            m_ConsoleSystem.Log(csys::ERROR) << "Lua error: " << err.what() << csys::endl;
        }
        else
        {
            m_ConsoleSystem.Log(csys::LOG) << "Lua executed successfully" << csys::endl;
        }
    }
    catch (const std::exception &e)
    {
        m_ConsoleSystem.Log(csys::ERROR) << "Lua exception: " << e.what() << csys::endl;
    }
}

void ImGuiConsole::InputBar()
{
    // Variables.
    ImGuiInputTextFlags inputTextFlags =
            ImGuiInputTextFlags_CallbackHistory | ImGuiInputTextFlags_CallbackCharFilter | ImGuiInputTextFlags_CallbackCompletion |
            ImGuiInputTextFlags_EnterReturnsTrue | ImGuiInputTextFlags_CallbackAlways;

    // Only reclaim after enter key is pressed!
    bool reclaimFocus = false;

    // Input widget. (Width an always fixed width)
    ImGui::PushItemWidth(-ImGui::GetStyle().ItemSpacing.x * 5.f);
    if (ImGui::InputText("Input", &m_Buffer, inputTextFlags, InputCallback, this))
    {
        // Validate.
        if (!m_Buffer.empty())
        {
            // Check if Lua mode is enabled
            if (m_luaMode)
            {
                // if the text contains "lua_mode", run the command
                if (m_Buffer.find("lua_mode") != std::string::npos)
                {
                    m_ConsoleSystem.RunCommand(m_Buffer);
                }
                else
                {
                     // Log command.
                    m_ConsoleSystem.Log(csys::ItemType::COMMAND) << m_Buffer << csys::endl;
                    // Run Lua code.
                    RunLuaCode(m_Buffer);
                }
            }
            else
            {
                // Run command line input.
                m_ConsoleSystem.RunCommand(m_Buffer);
            }

            // Scroll to bottom after its ran.
            m_ScrollToBottom = true;
        }

        // Keep focus.
        reclaimFocus = true;

        // Clear command line.
        m_Buffer.clear();
    }
    ImGui::PopItemWidth();

    // Reset suggestions when client provides char input.
    if (ImGui::IsItemEdited() && !m_WasPrevFrameTabCompletion)
    {
        m_CmdSuggestions.clear();
    }
    m_WasPrevFrameTabCompletion = false;

    // Auto-focus on window apparition
    ImGui::SetItemDefaultFocus();
    if (reclaimFocus)
        ImGui::SetKeyboardFocusHere(-1); // Focus on command line after clearing.
}

void ImGuiConsole::MenuBar()
{
    if (ImGui::BeginMenuBar())
    {
        // Settings menu.
        if (ImGui::BeginMenu("Settings"))
        {
            // Colored output
            ImGui::Checkbox("Colored Output", &m_ColoredOutput);
            ImGui::SameLine();
            HelpMaker("Enable colored command output");

            // Auto Scroll
            ImGui::Checkbox("Auto Scroll", &m_AutoScroll);
            ImGui::SameLine();
            HelpMaker("Automatically scroll to bottom of console log");

            // Filter bar
            ImGui::Checkbox("Filter Bar", &m_FilterBar);
            ImGui::SameLine();
            HelpMaker("Enable console filter bar");

            // Time stamp
            ImGui::Checkbox("Time Stamps", &m_TimeStamps);
            ImGui::SameLine();
            HelpMaker("Display command execution timestamps");

            // Reset to default settings
            if (ImGui::Button("Reset settings", ImVec2(ImGui::GetColumnWidth(), 0)))
                ImGui::OpenPopup("Reset Settings?");

            // Confirmation
            if (ImGui::BeginPopupModal("Reset Settings?", nullptr, ImGuiWindowFlags_AlwaysAutoResize))
            {
                ImGui::Text("All settings will be reset to default.\nThis operation cannot be undone!\n\n");
                ImGui::Separator();

                if (ImGui::Button("Reset", ImVec2(120, 0)))
                {
                    DefaultSettings();
                    ImGui::CloseCurrentPopup();
                }

                ImGui::SetItemDefaultFocus();
                ImGui::SameLine();
                if (ImGui::Button("Cancel", ImVec2(120, 0)))
                { ImGui::CloseCurrentPopup(); }
                ImGui::EndPopup();
            }

            ImGui::EndMenu();
        }

        // View settings.
        if (ImGui::BeginMenu("Appearance"))
        {
            // Logging Colors
            ImGuiColorEditFlags flags =
                    ImGuiColorEditFlags_Float | ImGuiColorEditFlags_AlphaPreview | ImGuiColorEditFlags_NoInputs | ImGuiColorEditFlags_AlphaBar;

            ImGui::TextUnformatted("Color Palette");
            ImGui::Indent();
            ImGui::ColorEdit4("Command##", (float *) &m_ColorPalette[COL_COMMAND], flags);
            ImGui::ColorEdit4("Log##", (float *) &m_ColorPalette[COL_LOG], flags);
            ImGui::ColorEdit4("Warning##", (float *) &m_ColorPalette[COL_WARNING], flags);
            ImGui::ColorEdit4("Error##", (float *) &m_ColorPalette[COL_ERROR], flags);
            ImGui::ColorEdit4("Info##", (float *) &m_ColorPalette[COL_INFO], flags);
            ImGui::ColorEdit4("Time Stamp##", (float *) &m_ColorPalette[COL_TIMESTAMP], flags);
            ImGui::Unindent();

            ImGui::Separator();

            // Window transparency.
            ImGui::TextUnformatted("Background");
            ImGui::SliderFloat("Transparency##", &m_WindowAlpha, 0.1f, 1.f);

            ImGui::EndMenu();
        }

        // All scripts.
        if (ImGui::BeginMenu("Scripts"))
        {
            // Show registered scripts.
            for (const auto &scr_pair : m_ConsoleSystem.Scripts())
            {
                if (ImGui::MenuItem(scr_pair.first.c_str()))
                {
                    m_ConsoleSystem.RunScript(scr_pair.first);
                    m_ScrollToBottom = true;
                }
            }

            // Reload scripts.
            ImGui::Separator();
            if (ImGui::Button("Reload Scripts", ImVec2(ImGui::GetColumnWidth(), 0)))
            {
                for (const auto &scr_pair : m_ConsoleSystem.Scripts())
                {
                    scr_pair.second->Reload();
                }
            }
            ImGui::EndMenu();
        }

        ImGui::EndMenuBar();
    }
}

// From imgui_demo.cpp
void ImGuiConsole::HelpMaker(const char *desc)
{
    ImGui::TextDisabled("(?)");
    if (ImGui::IsItemHovered())
    {
        ImGui::BeginTooltip();
        ImGui::PushTextWrapPos(ImGui::GetFontSize() * 35.0f);
        ImGui::TextUnformatted(desc);
        ImGui::PopTextWrapPos();
        ImGui::EndTooltip();
    }
}

int ImGuiConsole::InputCallback(ImGuiInputTextCallbackData *data)
{

    // Exit if no buffer.
    if (data->BufTextLen == 0 && (data->EventFlag != ImGuiInputTextFlags_CallbackHistory))
        return 0;

    // Get input string and console.
    std::string input_str = data->Buf;
    std::string trim_str;
    auto console = static_cast<ImGuiConsole *>(data->UserData);

    // Optimize by only using positions.
    // Trim start and end spaces.
    size_t startPos = console->m_Buffer.find_first_not_of(' ');
    size_t endPos = console->m_Buffer.find_last_not_of(' ');

    // Get trimmed string.
    if (startPos != std::string::npos && endPos != std::string::npos)
        trim_str = console->m_Buffer.substr(startPos, endPos + 1);
    else
        trim_str = console->m_Buffer;

    switch (data->EventFlag)
    {
        case ImGuiInputTextFlags_CallbackCompletion:
        {
            // Find last word.
            size_t startSubtrPos = trim_str.find_last_of(' ');
            csys::AutoComplete *console_autocomplete;

            // Command line is an entire word/string (No whitespace)
            // Determine which autocomplete tree to use.
            if (startSubtrPos == std::string::npos)
            {
                startSubtrPos = 0;
                console_autocomplete = &console->m_ConsoleSystem.CmdAutocomplete();
            }
            else
            {
                startSubtrPos += 1;
                console_autocomplete = &console->m_ConsoleSystem.VarAutocomplete();
            }

            // Validate str
            if (!trim_str.empty())
            {
                // Display suggestions on console.
                if (!console->m_CmdSuggestions.empty())
                {
                    console->m_ConsoleSystem.Log(csys::COMMAND) << "Suggestions: " << csys::endl;

                    for (const auto &suggestion : console->m_CmdSuggestions)
                        console->m_ConsoleSystem.Log(csys::LOG) << suggestion << csys::endl;

                    console->m_CmdSuggestions.clear();
                }

                // Get partial completion and suggestions.
                std::string partial = console_autocomplete->Suggestions(trim_str.substr(startSubtrPos, endPos + 1), console->m_CmdSuggestions);

                // Autocomplete only when one work is available.
                if (!console->m_CmdSuggestions.empty() && console->m_CmdSuggestions.size() == 1)
                {
                    data->DeleteChars(static_cast<int>(startSubtrPos), static_cast<int>(data->BufTextLen - startSubtrPos));
                    data->InsertChars(static_cast<int>(startSubtrPos), console->m_CmdSuggestions[0].data());
                    console->m_CmdSuggestions.clear();
                }
                else
                {
                    // Partially complete word.
                    if (!partial.empty())
                    {
                        data->DeleteChars(static_cast<int>(startSubtrPos), static_cast<int>(data->BufTextLen - startSubtrPos));
                        data->InsertChars(static_cast<int>(startSubtrPos), partial.data());
                    }
                }
            }

            // We have performed the completion event.
            console->m_WasPrevFrameTabCompletion = true;
        }
            break;

        case ImGuiInputTextFlags_CallbackHistory:
        {
            // Clear buffer.
            data->DeleteChars(0, data->BufTextLen);

            // Init history index
            if (console->m_HistoryIndex == std::numeric_limits<size_t>::min())
                console->m_HistoryIndex = console->m_ConsoleSystem.History().GetNewIndex();

            // Traverse history.
            if (data->EventKey == ImGuiKey_UpArrow)
            {
                if (console->m_HistoryIndex) --(console->m_HistoryIndex);
            }
            else
            {
                if (console->m_HistoryIndex < console->m_ConsoleSystem.History().Size()) ++(console->m_HistoryIndex);
            }

            // Get history.
            std::string prevCommand = console->m_ConsoleSystem.History()[console->m_HistoryIndex];

            // Insert commands.
            data->InsertChars(data->CursorPos, prevCommand.data());
        }
            break;

        case ImGuiInputTextFlags_CallbackCharFilter:
        case ImGuiInputTextFlags_CallbackAlways:
        default:
            break;
    }
    return 0;
}

void ImGuiConsole::SettingsHandler_ClearALl(ImGuiContext *ctx, ImGuiSettingsHandler *handler)
{
}

void ImGuiConsole::SettingsHandler_ReadInit(ImGuiContext *ctx, ImGuiSettingsHandler *handler)
{
}

void *ImGuiConsole::SettingsHandler_ReadOpen(ImGuiContext *ctx, ImGuiSettingsHandler *handler, const char *name)
{
    if (!handler->UserData)
        return nullptr;

    auto console = static_cast<ImGuiConsole *>(handler->UserData);

    if (strcmp(name, console->m_ConsoleName.c_str()) != 0)
        return nullptr;
    return (void *) 1;
}

void ImGuiConsole::SettingsHandler_ReadLine(ImGuiContext *ctx, ImGuiSettingsHandler *handler, void *entry, const char *line)
{
    if (!handler->UserData)
        return;

    // Get console.
    auto console = static_cast<ImGuiConsole *>(handler->UserData);

    // Ensure console doesn't reset variables.
    console->m_LoadedFromIni = true;

// Disable warning regarding sscanf when using MVSC
#pragma warning( push )
#pragma warning( disable:4996 )

#define INI_CONSOLE_LOAD_COLOR(type) (std::sscanf(line, #type"=%i,%i,%i,%i", &r, &g, &b, &a) == 4) { console->m_ColorPalette[type] = ImColor(r, g, b, a); }
#define INI_CONSOLE_LOAD_FLOAT(var) (std::sscanf(line, #var"=%f", &f) == 1) { console->var = f; }
#define INI_CONSOLE_LOAD_BOOL(var) (std::sscanf(line, #var"=%i", &b) == 1) {console->var = b == 1;}

    float f;
    int r, g, b, a;
    int value;
    size_t idx;
    char tagName[64];

    // Window style/visuals
    if INI_CONSOLE_LOAD_COLOR(COL_COMMAND)
    else if INI_CONSOLE_LOAD_COLOR(COL_LOG)
    else if INI_CONSOLE_LOAD_COLOR(COL_WARNING)
    else if INI_CONSOLE_LOAD_COLOR(COL_ERROR)
    else if INI_CONSOLE_LOAD_COLOR(COL_INFO)
    else if INI_CONSOLE_LOAD_COLOR(COL_TIMESTAMP)
    else if INI_CONSOLE_LOAD_FLOAT(m_WindowAlpha)

        // Window settings
    else if INI_CONSOLE_LOAD_BOOL(m_AutoScroll)
    else if INI_CONSOLE_LOAD_BOOL(m_ScrollToBottom)
    else if INI_CONSOLE_LOAD_BOOL(m_ColoredOutput)
    else if INI_CONSOLE_LOAD_BOOL(m_FilterBar)
    else if INI_CONSOLE_LOAD_BOOL(m_TimeStamps)

        // Filter states
    else if (sscanf(line, "LevelFilter%zu=%d", &idx, &value) == 2 && idx < LEVEL_COUNT) {
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

#pragma warning( pop )
}

void ImGuiConsole::SettingsHandler_ApplyAll(ImGuiContext *ctx, ImGuiSettingsHandler *handler)
{
    if (!handler->UserData)
        return;
}

void ImGuiConsole::SettingsHandler_WriteAll(ImGuiContext *ctx, ImGuiSettingsHandler *handler, ImGuiTextBuffer *buf)
{
    if (!handler->UserData)
        return;

    // Get console.
    auto console = static_cast<ImGuiConsole *>(handler->UserData);

#define INI_CONSOLE_SAVE_COLOR(type) buf->appendf(#type"=%i,%i,%i,%i\n", (int)(console->m_ColorPalette[type].x * 255),\
                                                                         (int)(console->m_ColorPalette[type].y * 255),\
                                                                         (int)(console->m_ColorPalette[type].z * 255),\
                                                                         (int)(console->m_ColorPalette[type].w * 255))

#define INI_CONSOLE_SAVE_FLOAT(var) buf->appendf(#var"=%.3f\n", console->var)
#define INI_CONSOLE_SAVE_BOOL(var) buf->appendf(#var"=%i\n", console->var)

    // Set header for CONSOLE Console.
    buf->appendf("[%s][%s]\n", handler->TypeName, console->m_ConsoleName.data());

    // Window settings.
    INI_CONSOLE_SAVE_BOOL(m_AutoScroll);
    INI_CONSOLE_SAVE_BOOL(m_ScrollToBottom);
    INI_CONSOLE_SAVE_BOOL(m_ColoredOutput);
    INI_CONSOLE_SAVE_BOOL(m_FilterBar);
    INI_CONSOLE_SAVE_BOOL(m_TimeStamps);

    // Window style/visuals
    INI_CONSOLE_SAVE_FLOAT(m_WindowAlpha);
    INI_CONSOLE_SAVE_COLOR(COL_COMMAND);
    INI_CONSOLE_SAVE_COLOR(COL_LOG);
    INI_CONSOLE_SAVE_COLOR(COL_WARNING);
    INI_CONSOLE_SAVE_COLOR(COL_ERROR);
    INI_CONSOLE_SAVE_COLOR(COL_INFO);
    INI_CONSOLE_SAVE_COLOR(COL_TIMESTAMP);

    // Filter states
    for (size_t i = 0; i < ImGuiConsole::LEVEL_COUNT; ++i) {
        buf->appendf("LevelFilter%zu=%d\n", i, console->m_LevelFilters[i] ? 1 : 0);
    }
    for (size_t i = 0; i < console->SYSTEM_TAGS.size(); ++i) {
        buf->appendf("TagFilter_%s=%d\n", console->SYSTEM_TAGS[i],
                     console->m_SystemTagFilters[i] ? 1 : 0);
    }
    buf->appendf("ShowFilters=%d\n", console->m_ShowFilters ? 1 : 0);

    // End saving.
    buf->append("\n");
}
