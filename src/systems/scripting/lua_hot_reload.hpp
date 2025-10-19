#include <filesystem>
#include <unordered_map>
#include <string>
#include <vector>
#include "sol/sol.hpp"
#include "raylib.h"
#include "spdlog/spdlog.h"
#include "third_party/rlImGui/imgui.h"
#include "types.hpp"

namespace lua_hot_reload {

    struct LuaFile {
        std::string path;
        std::string moduleName; // derived from path
        std::filesystem::file_time_type lastWriteTime;
    };

    extern std::unordered_map<std::string, LuaFile> trackedFiles;
    extern std::vector<std::string> changedFiles;
    inline bool autoReload = false;
    
    // ------------------------------------------------------------
    // Helper: derive module name (e.g. "scripts/ai/init.lua" → "ai.init")
    // ------------------------------------------------------------
    inline std::string to_module_name(const std::string& filepath) {
        std::filesystem::path p = filepath;

        // Normalize and remove everything before "scripts/"
        std::string pathStr = p.generic_string();
        auto pos = pathStr.find("scripts/");
        if (pos != std::string::npos)
            pathStr = pathStr.substr(pos + 8); // skip "scripts/"
        else
            SPDLOG_WARN("to_module_name: couldn't find 'scripts/' in path {}", pathStr);

        // Strip extension
        if (pathStr.ends_with(".lua"))
            pathStr.erase(pathStr.size() - 4);

        // Convert slashes to dots
        std::replace(pathStr.begin(), pathStr.end(), '/', '.');
        std::replace(pathStr.begin(), pathStr.end(), '\\', '.');

        return pathStr;
    }


    inline void track(const std::string& path) {
        if (std::filesystem::exists(path)) {
            trackedFiles[path] = {
                path,
                to_module_name(path),
                std::filesystem::last_write_time(path)
            };
        }
    }

    inline void scan_for_changes() {
        // Don't clear changedFiles here — we want it to persist.
        for (auto& [path, info] : trackedFiles) {
            if (std::filesystem::exists(path)) {
                auto newTime = std::filesystem::last_write_time(path);

                // Use > instead of != to avoid precision loss issues
                if (newTime > info.lastWriteTime) {
                    // If not already marked changed, add it
                    if (std::find(changedFiles.begin(), changedFiles.end(), path) == changedFiles.end()) {
                        changedFiles.push_back(path);
                    }
                    info.lastWriteTime = newTime;
                }
            }
        }
    }

    inline const std::vector<std::string>& get_changed_files() {
        return changedFiles;
    }

    inline void reload(sol::state& lua, const std::string& file) {
        auto it = trackedFiles.find(file);
        if (it == trackedFiles.end()) return;
        const std::string& mod = it->second.moduleName;

        try {
            lua["package"]["loaded"][mod] = sol::lua_nil;
            lua.script("require('" + mod + "')");

            // Lua-side on_reload support
            lua.script(R"(
                local ok, m = pcall(require, ')" + mod + R"(')
                if ok and type(m) == 'table' and m.on_reload then
                    m.on_reload()
                end
            )");

            TraceLog(LOG_INFO, TextFormat("✅ Reloaded module %s (%s)", mod.c_str(), file.c_str()));

            // ✅ remove from changed list now that it’s reloaded
            changedFiles.erase(
                std::remove(changedFiles.begin(), changedFiles.end(), file),
                changedFiles.end()
            );

        } catch (const sol::error& e) {
            TraceLog(LOG_ERROR, TextFormat("❌ Reload failed for %s: %s", mod.c_str(), e.what()));
        }
    }


    inline void draw_imgui(sol::state& lua) {
        static double lastScan = 0.0;
        if (GetTime() - lastScan > 1.0) { // every second
            scan_for_changes();
            lastScan = GetTime();
        }

        if (ImGui::Begin("Lua Hot Reload")) {
            static bool autoReload = false;
            ImGui::Checkbox("Auto Reload Changed Files", &autoReload);
            if (autoReload) {
                for (auto& file : changedFiles)
                    reload(lua, file);
            }
            if (changedFiles.empty()) {
                ImGui::TextDisabled("No modified files detected.");
            } else {
                ImGui::Text("Changed Lua Files:");
                for (const auto& file : changedFiles) {
                    ImGui::PushID(file.c_str());

                    if (ImGui::Button("Reload")) {
                        reload(lua, file);
                    }

                    ImGui::SameLine();

                    // 🔶 Highlight the changed filename in yellow
                    ImGui::TextColored(ImVec4(1.0f, 1.0f, 0.0f, 1.0f), "%s", file.c_str());

                    ImGui::PopID();
                }
            }
        }
        ImGui::End();
    }

}
