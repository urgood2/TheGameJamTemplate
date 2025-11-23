#include "gui.hpp"
#include "../components/components.hpp"
#include "../third_party/rlImGui/imgui.h"
#include "../third_party/imgui_console/imgui_console.h"
#include "../third_party/imgui_console/csys_console_sink.hpp"
#include "../systems/ai/ai_system.hpp"
#include "../systems/shaders/shader_system.hpp"
#include "../systems/spring/spring.hpp"
#include "../util/utilities.hpp"
#include "game.hpp"
#include "../util/crash_reporter.hpp"

#include "spdlog/sinks/stdout_color_sinks.h"

#include <map>
// #include <boost/regex.hpp>

#include "rlgl.h"

namespace gui
{

    std::unique_ptr<ImGuiConsole> consolePtr{};

    auto showGUI() -> void
    {
    }

    // A helper function to convert degrees to radians
    inline float DegToRad(float deg)
    {
        return deg * 3.14159265359f / 180.0f;
    }
    
    // A helper to linearly interpolate between two colors (in ImU32 RGBA format)
static ImU32 LerpColor(ImU32 c1, ImU32 c2, float t) {
    unsigned char c1r = (c1 >> IM_COL32_R_SHIFT) & 0xFF;
    unsigned char c1g = (c1 >> IM_COL32_G_SHIFT) & 0xFF;
    unsigned char c1b = (c1 >> IM_COL32_B_SHIFT) & 0xFF;
    unsigned char c1a = (c1 >> IM_COL32_A_SHIFT) & 0xFF;

    unsigned char c2r = (c2 >> IM_COL32_R_SHIFT) & 0xFF;
    unsigned char c2g = (c2 >> IM_COL32_G_SHIFT) & 0xFF;
    unsigned char c2b = (c2 >> IM_COL32_B_SHIFT) & 0xFF;
    unsigned char c2a = (c2 >> IM_COL32_A_SHIFT) & 0xFF;

    unsigned char r = (unsigned char)(c1r + (c2r - c1r) * t);
    unsigned char g = (unsigned char)(c1g + (c2g - c1g) * t);
    unsigned char b = (unsigned char)(c1b + (c2b - c1b) * t);
    unsigned char a = (unsigned char)(c1a + (c2a - c1a) * t);

    return IM_COL32(r, g, b, a);
}


    // ---------------------------------------------------------
    // ImGUI Console
    // ---------------------------------------------------------
    // redirect the output of the console to the game log
    // This is not perfect, and it changes the default logger in the middle of everything so i don't know if it's a good idea
    auto initConsole() -> void
    {

        consolePtr = std::make_unique<ImGuiConsole>("debugging console");

        consolePtr->SetLuaState(ai_system::masterStateLua);

        // Setup csys console and other initializations...
        consolePtr->System().Log(csys::ItemType::INFO) << "Initializing logging system..." << csys::endl;

        // Create an spdlog sink that logs to the csys console
        auto csys_sink = std::make_shared<csys_console_sink<std::mutex>>(consolePtr->System());

        // Combine the csys sink with spdlog's default sink (console output)
        auto stdout_sink = std::make_shared<spdlog::sinks::stdout_color_sink_mt>();

        // Create a logger with both sinks
        auto combined_logger = std::make_shared<spdlog::logger>("combined", spdlog::sinks_init_list{stdout_sink, csys_sink});
        crash_reporter::AttachSinkToLogger(combined_logger);

        // Set the global logger
        spdlog::set_default_logger(combined_logger);

        // Set the log level (optional)
        spdlog::set_level(spdlog::level::trace); // Log everything

        // Log messages
        spdlog::info("This is an info message.");
        spdlog::warn("This is a warning message.");
        spdlog::error("This is an error message.");

        // ------------------------------
        // Register console commands
        // ------------------------------
        // Register a command to run Lua code
        consolePtr->System().RegisterCommand("lua", "Executes a line of Lua code. Use single quotes instead of double quotes.", [](const std::string &lua_code)
                                             {
            
            try {
                auto result = ai_system::masterStateLua.script(lua_code);
                consolePtr->System().Log(csys::ItemType::INFO) << "Executed Lua code: " << lua_code << csys::endl;
                
                if (!result.valid()) {
                    sol::error err = result;
                    consolePtr->System().Log(csys::ItemType::ERROR) << "Lua Error: " << err.what() << csys::endl;
                }
            } catch (const std::exception &e) {
                consolePtr->System().Log(csys::ItemType::ERROR) << "Lua Error: " << e.what() << csys::endl;
            } }, csys::Arg<csys::String>("lua_code"));

        consolePtr->System().RegisterCommand("luadump", "Prints out all user functions registered with the lua master state.", []()
                                             {
            game::isPaused = true;
            consolePtr->System().Log(csys::ItemType::INFO) << "Game paused." << csys::endl;

            ai_system::masterStateLua.script(R"(
                -- Helper function to get sorted keys
                local function get_sorted_keys(tbl)
                    local keys = {}
                    for k in pairs(tbl) do
                        table.insert(keys, k)
                    end
                    table.sort(keys, function(a, b)
                        return tostring(a) < tostring(b)  -- Ensure keys are compared as strings
                    end)
                    return keys
                end

                function print_filtered_globals()
                    -- Define a set of excluded keys (tables and functions you want to ignore)
                    local excluded_keys = {
                        ["sol.entt::entity.♻"] = true,
                        ["table"] = true,
                        ["getEventOccurred"] = true,
                        ["ipairs"] = true,
                        ["next"] = true,
                        ["assert"] = true,
                        ["tostring"] = true,
                        ["getmetatable"] = true,
                        ["dofile"] = true,
                        ["rawget"] = true,
                        ["select"] = true,
                        ["os"] = true,
                        ["ActionResult"] = true,
                        ["rawequal"] = true,
                        ["warn"] = true,
                        ["wait"] = true,
                        ["pairs"] = true,
                        ["Entity"] = true,
                        ["sol.☢☢"] = true,
                        ["logic"] = true,
                        ["rawset"] = true,
                        ["collectgarbage"] = true,
                        ["load"] = true,
                        ["_VERSION"] = true,
                        ["rawlen"] = true,
                        ["pcall"] = true,
                        ["package"] = true,
                        ["_G"] = true,
                        ["conditions"] = true,
                        ["require"] = true,
                        ["xpcall"] = true,
                        ["base"] = true,
                        ["print_table"] = true,
                        ["coroutine"] = true,
                        ["loadfile"] = true,
                        ["setmetatable"] = true,
                        ["sol.🔩"] = true,
                        ["string"] = true,
                        ["tonumber"] = true,
                        ["type"] = true
                    }

                    -- Helper function to accumulate functions inside tables into a string
                    local function accumulate_functions_in_table(tbl, table_name, result_str)
                        for k, v in pairs(tbl) do
                            if type(v) == 'function' then
                                local key_str = (type(k) == 'number') and tostring(k) or '"'..tostring(k)..'"'
                                result_str = result_str .. '  ['..table_name..'.'..key_str..'] = function: ' .. tostring(v) .. '\n'
                            end
                        end
                        return result_str
                    end

                    -- Initialize an empty string to accumulate the output
                    local result_str = ""

                    -- Get sorted top-level keys
                    local sorted_keys = get_sorted_keys(_G)

                    -- Loop through the global environment (_G) using sorted keys
                    for _, k in ipairs(sorted_keys) do
                        local v = _G[k]
                        -- Convert key to string (quote it if it's not a number)
                        local key_str = (type(k) == 'number') and tostring(k) or '"'..tostring(k)..'"'

                        -- Check if the key is in the excluded set
                        if not excluded_keys[k] then
                            -- Convert value to string
                            if type(v) == 'table' then
                                result_str = result_str .. '['..key_str..'] = {...}\n'  -- Indicate it's a table
                                -- Check if the table contains any functions and accumulate them
                                result_str = accumulate_functions_in_table(v, key_str, result_str)
                            else
                                local value_str = tostring(v)  -- Convert non-table types to string
                                result_str = result_str .. '['..key_str..'] = ' .. value_str .. '\n'
                            end
                        end
                    end

                    -- Print the accumulated result as a block of text
                    debug(result_str)
                end

                function print_flat_globals()
                    -- Initialize an empty string to accumulate the output
                    local result_str = ""

                    -- Get sorted top-level keys
                    local sorted_keys = get_sorted_keys(_G)

                    for _, k in ipairs(sorted_keys) do
                        local v = _G[k]
                        -- Convert key to string (quote it if it's not a number)
                        local key_str = (type(k) == 'number') and tostring(k) or '"'..tostring(k)..'"'

                        -- Convert value to string
                        local value_str
                        if type(v) == 'table' then
                            value_str = '{...}'  -- Indicate it's a table without printing its contents
                        else
                            value_str = tostring(v)  -- Convert other types to string
                        end

                        -- Accumulate the key-value pair in the result string
                        result_str = result_str .. '['..key_str..'] = ' .. value_str .. '\n'
                    end

                    -- Print the accumulated result as a block of text
                    print(result_str)
                end

                -- Helper function to avoid infinite recursion and accumulate table content
                function accumulate_table(tbl, indent, visited, result_str)
                    indent = indent or 0
                    local indent_str = string.rep("  ", indent)
                    visited = visited or {}

                    if visited[tbl] then
                        result_str = result_str .. indent_str .. "*recursion detected*\n"
                        return result_str
                    end

                    visited[tbl] = true  -- Mark this table as visited

                    -- Get sorted keys for the table
                    local sorted_keys = get_sorted_keys(tbl)

                    for _, key in ipairs(sorted_keys) do
                        local value = tbl[key]
                        if type(value) == "table" then
                            if key ~= "_G" then  -- Avoid infinite recursion on _G
                                result_str = result_str .. indent_str .. key .. ": table\n"
                                result_str = accumulate_table(value, indent + 1, visited, result_str)
                            end
                        else
                            result_str = result_str .. indent_str .. key .. ": " .. type(value) .. '\n'
                        end
                    end
                    return result_str
                end

                -- Function to print all globals with accumulated output and sorted top-level keys
                function print_globals()
                    local result_str = accumulate_table(_G, 0, {}, "")
                    debug(result_str)
                end

            )");
            auto result = ai_system::masterStateLua.script(R"(
                print_filtered_globals()
            )");

            if (!result.valid()) {
                sol::error err = result;
                consolePtr->System().Log(csys::ItemType::ERROR) << "Lua Error: " << err.what() << csys::endl;
            } });
    }

    // ---------------------------------------------------------
    // End ImGUI Console
    // ---------------------------------------------------------

    // ---------------------------------------------------------
    // NinePatch
    // ---------------------------------------------------------
    auto drawNinePatch(NinePatchData &ninePatchData, Rectangle destRect, float alpha) -> void
    {
        // TODO: are sprites being loaded being destroyed?
        NPatchInfo nPatchInfo = {ninePatchData.source, ninePatchData.left, ninePatchData.top, ninePatchData.right, ninePatchData.bottom, NPatchLayout::NPATCH_NINE_PATCH};
        DrawTextureNPatch(ninePatchData.texture, nPatchInfo, destRect, {0, 0}, 0.0f, WHITE);
    }

    void drawNinePatchUIIndicator(std::string ninepatchName, Rectangle boundingRect, float padding, float alpha, ImVec4 fgColor, ImVec4 bgColor)
    {
        ImDrawList *drawList = ImGui::GetForegroundDrawList();

        auto &ninePatchData = globals::ninePatchDataMap[ninepatchName];
        ImTextureID textureID = (ImTextureID)(&(ninePatchData.texture));

        // Check if textureID is valid
        if (textureID == nullptr)
        {
            SPDLOG_ERROR("drawNinePatchWindowBackground - textureID is null");
            return;
        }

        // by default, the bounding rect will be the content region of the ninepatch (center piece)
        drawImGuiNinepatch(boundingRect, ninePatchData, fgColor, alpha, bgColor, drawList, textureID);
    }

    // for the button rectangle, just get cursor position in imgui and set the width and height
    auto drawNinePatchButton(const std::string &buttonNameID, Rectangle buttonRect, const std::string &ninePatchRegion, const std::string &buttonText, float alpha, const std::string &fgColor, const std::string &bgColor, std::function<void()> onClick) -> void
    {

        ImDrawList *drawList = ImGui::GetWindowDrawList();

        // callback before button render

        // drawList->AddCallback(customShaderDrawCallbackStart, nullptr);

        // cursor location must be set beforehan

        gui::drawNinePatchWindowBackground(ninePatchRegion, buttonRect, alpha, 0.0f, util::getColorImVec(fgColor), util::getColorImVec(bgColor));

        if (ImGui::Button(buttonText.c_str(), ImVec2(buttonRect.width, buttonRect.height)))
        {
            onClick();
        }

        // callback after button render
        // drawList->AddCallback(customShaderDrawCallbackEnd, nullptr);

        // parameter: button rect
        // parameter: name of ninepatch region
        // parameter: button text
        // parameter: alpha
        // parameter: fg color, bg color
        // function to call when button is clicked
    }

    void drawNinePatchWindowBackground(std::string ninepatchName, Rectangle boundingRect, float alpha, float titleBarHeight, ImVec4 fgColor, ImVec4 bgColor)
    {
        ImDrawList *drawList = ImGui::GetWindowDrawList();

        auto &ninePatchData = globals::ninePatchDataMap[ninepatchName];
        ImTextureID textureID = (ImTextureID)(&(ninePatchData.texture));

        // Check if textureID is valid
        if (textureID == nullptr)
        {
            SPDLOG_ERROR("drawNinePatchWindowBackground - textureID is null");
            return;
        }

        drawImGuiNinepatch(boundingRect, ninePatchData, fgColor, alpha, bgColor, drawList, textureID);
    }

    void drawImGuiNinepatch(Rectangle &boundingRect, gui::NinePatchData &ninePatchData, ImVec4 &fgColor, float alpha, ImVec4 &bgColor, ImDrawList *drawList, ImTextureID textureID)
    {

        ImVec2 windowPos = {boundingRect.x, boundingRect.y};
        ImVec2 windowSize = {boundingRect.width, boundingRect.height};

        // Adjust the boundingRect so that the inner rectangle matches the ImGui window size
        boundingRect.x -= ninePatchData.left;
        boundingRect.y -= ninePatchData.top;
        boundingRect.width += ninePatchData.left + ninePatchData.right;
        boundingRect.height += ninePatchData.top + ninePatchData.bottom;

        ImVec2 adjustedWindowPos = {boundingRect.x, boundingRect.y};
        ImVec2 adjustedWindowSize = {boundingRect.width, boundingRect.height};

        int sourceRectWidth = ninePatchData.source.width;
        int sourceRectHeight = ninePatchData.source.height;

        ImU32 colorWithAlpha = ImGui::ColorConvertFloat4ToU32(ImVec4(fgColor.x, fgColor.y, fgColor.z, alpha));

        // Convert bgColor to ImU32 (with transparency)
        ImU32 bgColorWithAlpha = ImGui::ColorConvertFloat4ToU32(ImVec4(bgColor.x, bgColor.y, bgColor.z, bgColor.w * alpha));

        // Calculate edge dimensions
        ImVec2 edgeLeftDimensions = ImVec2(ninePatchData.left, adjustedWindowSize.y - ninePatchData.top - ninePatchData.bottom);
        ImVec2 edgeRightDimensions = ImVec2(ninePatchData.right, adjustedWindowSize.y - ninePatchData.top - ninePatchData.bottom);
        ImVec2 edgeTopDimensions = ImVec2(adjustedWindowSize.x - ninePatchData.left - ninePatchData.right, ninePatchData.top);
        ImVec2 edgeBottomDimensions = ImVec2(adjustedWindowSize.x - ninePatchData.left - ninePatchData.right, ninePatchData.bottom);

        float innerEdgeLeft = (float)ninePatchData.left / sourceRectWidth;
        float innerEdgeRight = ((float)sourceRectWidth - ninePatchData.right) / sourceRectWidth;
        float innerEdgeTop = (float)ninePatchData.top / sourceRectHeight;
        float innerEdgeBottom = ((float)sourceRectHeight - ninePatchData.bottom) / sourceRectHeight;

        ImVec2 topLeft(adjustedWindowPos.x, adjustedWindowPos.y);
        ImVec2 topRight(adjustedWindowPos.x + adjustedWindowSize.x, adjustedWindowPos.y);
        ImVec2 bottomLeft(adjustedWindowPos.x, adjustedWindowPos.y + adjustedWindowSize.y);
        ImVec2 bottomRight(adjustedWindowPos.x + adjustedWindowSize.x, adjustedWindowPos.y + adjustedWindowSize.y);

        ImVec2 leftEdge = ImVec2(adjustedWindowPos.x, adjustedWindowPos.y + ninePatchData.top);
        ImVec2 rightEdge = ImVec2(adjustedWindowPos.x + adjustedWindowSize.x - ninePatchData.right, adjustedWindowPos.y + ninePatchData.top);
        ImVec2 topEdge = ImVec2(adjustedWindowPos.x + ninePatchData.left, adjustedWindowPos.y);
        ImVec2 bottomEdge = ImVec2(adjustedWindowPos.x + ninePatchData.left, adjustedWindowPos.y + adjustedWindowSize.y - ninePatchData.bottom);
        ImVec2 center = ImVec2(adjustedWindowPos.x + ninePatchData.left, adjustedWindowPos.y + ninePatchData.top);
        ImVec2 centerPieceDimensions = ImVec2(adjustedWindowSize.x - ninePatchData.left - ninePatchData.right, adjustedWindowSize.y - ninePatchData.top - ninePatchData.bottom);

        // disable clip rectable for window drawlist temporarily to allow border drawing
        drawList->PushClipRectFullScreen();

        // drawList->AddCallback(customShaderDrawCallbackStart, nullptr);

        // Draw background color behind the NinePatch
        drawList->AddRectFilled(adjustedWindowPos, adjustedWindowPos + adjustedWindowSize, bgColorWithAlpha);

        // Draw NinePatch sections
        drawList->AddImage(textureID, topLeft, topLeft + ImVec2(ninePatchData.left, ninePatchData.top), ImVec2(0, 0), ImVec2(innerEdgeLeft, innerEdgeTop), colorWithAlpha);                            // Top-left corner
        drawList->AddImage(textureID, topRight - ImVec2(ninePatchData.right, 0), topRight + ImVec2(0, ninePatchData.top), ImVec2(innerEdgeRight, 0), ImVec2(1, innerEdgeTop), colorWithAlpha);         // Top-right corner
        drawList->AddImage(textureID, bottomLeft - ImVec2(0, ninePatchData.bottom), bottomLeft + ImVec2(ninePatchData.left, 0), ImVec2(0, innerEdgeBottom), ImVec2(innerEdgeLeft, 1), colorWithAlpha); // Bottom-left corner
        drawList->AddImage(textureID, bottomRight - ImVec2(ninePatchData.right, ninePatchData.bottom), bottomRight, ImVec2(innerEdgeRight, innerEdgeBottom), ImVec2(1, 1), colorWithAlpha);            // Bottom-right corner

        // Draw edges
        drawList->AddImage(textureID, leftEdge, leftEdge + edgeLeftDimensions, ImVec2(0, innerEdgeTop), ImVec2(innerEdgeLeft, innerEdgeBottom), colorWithAlpha);         // Left edge
        drawList->AddImage(textureID, rightEdge, rightEdge + edgeRightDimensions, ImVec2(innerEdgeRight, innerEdgeTop), ImVec2(1, innerEdgeBottom), colorWithAlpha);     // Right edge
        drawList->AddImage(textureID, topEdge, topEdge + edgeTopDimensions, ImVec2(innerEdgeLeft, 0), ImVec2(innerEdgeRight, innerEdgeTop), colorWithAlpha);             // Top edge
        drawList->AddImage(textureID, bottomEdge, bottomEdge + edgeBottomDimensions, ImVec2(innerEdgeLeft, innerEdgeBottom), ImVec2(innerEdgeRight, 1), colorWithAlpha); // Bottom edge

        // Draw center
        drawList->AddImage(textureID, center, center + centerPieceDimensions, ImVec2(innerEdgeLeft, innerEdgeTop), ImVec2(innerEdgeRight, innerEdgeBottom), colorWithAlpha); // Center

        // drawList->AddCallback(customShaderDrawCallbackEnd, nullptr);
        // drawList->AddCallback(ImDrawCallback_ResetRenderState, nullptr);

        // Restore clip rectangle
        drawList->PopClipRect();
    }

    // ---------------------------------------------------------
    // End NinePatch
    // ---------------------------------------------------------

}
