// Copyright (c) 2020 - present, Roland Munguia
// Distributed under the MIT License (http://opensource.org/licenses/MIT)

#ifndef IMGUI_CONSOLE_H
#define IMGUI_CONSOLE_H
#pragma once

#include "csys/system.h"
#include "third_party/rlImGui/imgui.h"
#include <array>
#include <memory>
#include <unordered_set>
#include <unordered_map>
#include "sol/sol.hpp"

struct ImGuiSettingsHandler;
class ImGuiConsole
{
public:

    /*!
     * \brief Construct an imgui console
     * \param c_name Name of the console
     * \param inputBufferSize Maximum input buffer size
     */
    explicit ImGuiConsole(std::string c_name = "imgui-console", size_t inputBufferSize = 256);

    /*!
     * \brief Render the Dear ImGui Console
     */
    void Draw();
    
    void PushScrollToBottom() { m_ScrollToBottom = true; }

    void SetLuaState(sol::state &luaState) { m_luaState = &luaState; }
    sol::state* GetLuaState() { return m_luaState; }

    /*!
     * \brief Console system which handles the console functionality (Logging, Commands, History, Scripts, etc).
     * \return System Obj
     */
    csys::System &System();

protected:

    // Console ////////////////////////////////////////////////////////////////

    csys::System m_ConsoleSystem;            //!< Main console system.
    size_t m_HistoryIndex;                   //!< Command history index.

    // Dear ImGui  ////////////////////////////////////////////////////////////

    // Main

    std::string m_Buffer;            //!< Input buffer.
    std::string m_ConsoleName;       //!< Console name string buffer.
    ImGuiTextFilter m_TextFilter;    //!< Logging filer.
    sol::state *m_luaState;          //!< Lua state.
    bool m_AutoScroll;               //!< Auto scroll flag.
    bool m_ColoredOutput;            //!< Colored output flag.
    bool m_ScrollToBottom;           //!< Scroll to bottom after is command is ran
    bool m_FilterBar;                //!< Filter bar flag.
    bool m_TimeStamps;                 //!< Display time stamps flag
    bool m_luaMode;                    //!< Lua mode flag

    void InitIniSettings();             //!< Initialize Ini Settings handler
    void DefaultSettings();             //!< Restore console default settings
    void RegisterConsoleCommands();     //!< Register built-in console commands
    void RunLuaCode(const std::string &code); //!< Run Lua code

    void MenuBar();                     //!< Console menu bar
    void FilterSection();               //!< Collapsible filter checkboxes
    void FilterBar();                 //!< Console filter bar
    void InputBar();                 //!< Console input bar
    void LogWindow();                 //!< Console log

    static void HelpMaker(const char *desc);

    // Window appearance.

    float m_WindowAlpha;             //!< Window transparency

    enum COLOR_PALETTE
    {
        // This four have to match the csys item type enum.

        COL_COMMAND = 0,    //!< Color for command logs
        COL_LOG,            //!< Color for in-command logs
        COL_WARNING,        //!< Color for warnings logs
        COL_ERROR,          //!< Color for error logs
        COL_INFO,            //!< Color for info logs

        COL_TIMESTAMP,      //!< Color for timestamps

        COL_COUNT            //!< For bookkeeping purposes
    };

    std::array<ImVec4, COL_COUNT> m_ColorPalette;                //!< Container for all available colors

    // Log filtering
    enum LogLevel {
        LEVEL_ERROR = 0,
        LEVEL_WARNING,
        LEVEL_INFO,
        LEVEL_DEBUG,
        LEVEL_COUNT
    };

    // Predefined system tags
    static constexpr size_t SYSTEM_TAG_COUNT = 9;
    static constexpr std::array<const char*, SYSTEM_TAG_COUNT> SYSTEM_TAGS = {
        "physics", "combat", "ai", "ui", "input",
        "audio", "scripting", "render", "entity"
    };

    std::array<bool, LEVEL_COUNT> m_LevelFilters{};      //!< Level filter state (default: all enabled)
    std::array<bool, SYSTEM_TAG_COUNT> m_SystemTagFilters{}; //!< System tag filter state (default: all enabled)
    std::unordered_set<std::string> m_DynamicTags;           //!< Tags seen at runtime
    std::unordered_map<std::string, bool> m_DynamicTagFilters; //!< Filter state for dynamic tags
    bool m_ShowFilters = false;  //!< Collapsible filter section state

    // ImGui Console Window.

    static int InputCallback(ImGuiInputTextCallbackData *data);    //!< Console input callback
    bool m_WasPrevFrameTabCompletion = false;                    //!< Flag to determine if previous input was a tab completion
    std::vector<std::string> m_CmdSuggestions;                    //!< Holds command suggestions from partial completion

    // Save data inside .ini

    bool m_LoadedFromIni = false;

    static void SettingsHandler_ClearALl(ImGuiContext *ctx, ImGuiSettingsHandler *handler);

    static void SettingsHandler_ReadInit(ImGuiContext *ctx, ImGuiSettingsHandler *handler);

    static void *SettingsHandler_ReadOpen(ImGuiContext *ctx, ImGuiSettingsHandler *handler, const char *name);

    static void SettingsHandler_ReadLine(ImGuiContext *ctx, ImGuiSettingsHandler *handler, void *entry, const char *line);

    static void SettingsHandler_ApplyAll(ImGuiContext *ctx, ImGuiSettingsHandler *handler);

    static void SettingsHandler_WriteAll(ImGuiContext *ctx, ImGuiSettingsHandler *handler, ImGuiTextBuffer *buf);

    ///////////////////////////////////////////////////////////////////////////
};

#endif //IMGUI_CONSOLE_H
