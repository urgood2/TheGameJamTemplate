#pragma once

#include "core/globals.hpp"
#include "core/game.hpp"
#include "util/common_headers.hpp"
#include "util/error_handling.hpp"
#include "systems/transform/transform_functions.hpp"
#include "systems/ui/editor/pack_editor.hpp"
#include "systems/layer/layer_optimized.hpp"
#include "systems/layer/layer_command_buffer.hpp"
#include "systems/save/save_file_io.hpp"
#include "systems/ai/ai_system.hpp"

#include <string>
#include <unordered_map>

namespace game {
    void SetUpShaderUniforms(); 
    
    extern std::function<void()> OnUIScaleChanged;
    
    inline void centerInventoryItemOnTargetUI(entt::entity itemEntity, entt::entity targetUIElement)
    {
        auto &itemTransform = globals::getRegistry().get<transform::Transform>(itemEntity);
        auto &itemRole = globals::getRegistry().get<transform::InheritedProperties>(itemEntity);
        auto &targetTransform = globals::getRegistry().get<transform::Transform>(targetUIElement);
        
        float targetWidth = targetTransform.getActualW();
        float targetHeight = targetTransform.getActualH();
        float itemW = itemTransform.getActualW();
        float itemH = itemTransform.getActualH();
        
        //TODO: cook in dynamic object resizing later if item needs to change size while in ui, but not ouside of it?
        
        // prevent jerkiness
        
        
        itemRole.offset->x = (targetWidth - itemW) / 2.0f;
        itemRole.offset->y = (targetHeight - itemH) / 2.0f;
        
        itemTransform.setActualX(targetTransform.getActualX() + itemRole.offset->x);
        itemTransform.setActualY(targetTransform.getActualY() + itemRole.offset->y);
    }

    inline void ShowDebugUI()
    {
        static const float uiScales[] = { 0.5f, 0.75f, 1.0f, 1.25f, 1.5f, 1.75f, 2.0f, 2.25f, 2.5f };
        static int currentScaleIndex = 2; // Default to 1.0f
        static int previousScaleIndex = currentScaleIndex;
        static int lastLoadingCountShown = 0;
        static float fakeProgress = 0.0f;
        static ui::editor::PackEditorState packEditorState;

        const bool debugWindowOpen = ImGui::Begin("DebugWindow");
        if (debugWindowOpen)
        {

            if (ImGui::BeginTabBar("Debug variables")) {
                if (ImGui::BeginTabItem("Flags")) {
                    bool debugDraw = globals::getDrawDebugInfo();
                    if (ImGui::Checkbox("Show Bounding Boxes & Debug Info", &debugDraw)) {
                        globals::setDrawDebugInfo(debugDraw);
                    }
                    bool physicsDebug = globals::getDrawPhysicsDebug();
                    if (ImGui::Checkbox("Show physics debug draw", &physicsDebug)) {
                        globals::setDrawPhysicsDebug(physicsDebug);
                    }

                    ImGui::Text("UI Scale:");
                    if (ImGui::BeginCombo("##uiScaleCombo", std::to_string(uiScales[currentScaleIndex]).c_str())) {
                        for (int i = 0; i < IM_ARRAYSIZE(uiScales); ++i) {
                            bool isSelected = (i == currentScaleIndex);
                            if (ImGui::Selectable(std::to_string(uiScales[i]).c_str(), isSelected)) {
                                currentScaleIndex = i;
                            }
                            if (isSelected)
                                ImGui::SetItemDefaultFocus();
                        }
                        ImGui::EndCombo();
                    }

                    if (currentScaleIndex != previousScaleIndex) {
                        previousScaleIndex = currentScaleIndex;
                        globals::setGlobalUIScaleFactor(uiScales[currentScaleIndex]);
                        OnUIScaleChanged(); // ✅ Call your method here
                    }

                    ImGui::EndTabItem();
                }
                if (ImGui::BeginTabItem("Performance")) {
                    ImGui::Text("Draw calls this frame: %d", layer::g_drawCallsThisFrame);

                    // Draw call breakdown by source
                    ImGui::Separator();
                    ImGui::Text("Draw Call Breakdown:");
                    ImGui::Indent();
                    ImGui::Text("Sprites/Animations: %u", layer::g_drawCallStats.sprites);
                    ImGui::Text("Text: %u", layer::g_drawCallStats.text);
                    ImGui::Text("Shapes: %u", layer::g_drawCallStats.shapes);
                    ImGui::Text("UI: %u", layer::g_drawCallStats.ui);
                    ImGui::Text("State Changes: %u", layer::g_drawCallStats.state);
                    ImGui::Text("Other: %u", layer::g_drawCallStats.other);
                    ImGui::Unindent();

                    ImGui::Separator();
                    ImGui::Text("FPS: %d", GetFPS());
                    ImGui::Text("Frame time: %.2f ms", GetFrameTime() * 1000.0f);

                    ImGui::Separator();
                    ImGui::Text("Lua GC Statistics:");
                    ImGui::Indent();
                    ImGui::Text("Last GC pause: %.3f ms", game::g_lastGcPauseMs);
                    ImGui::Text("Max GC pause: %.3f ms", game::g_maxGcPauseMs);
                    ImGui::Text("Avg GC pause: %.3f ms", game::g_avgGcPauseMs);
                    if (game::g_lastGcPauseMs > 5.0) {
                        ImGui::TextColored(ImVec4(1.0f, 0.3f, 0.3f, 1.0f), "WARNING: Last GC pause exceeded 5ms!");
                    }
                    ImGui::Unindent();

#ifndef UNIT_TESTS
                    ImGui::Separator();
                    ImGui::Text("Rendering Optimizations:");
                    if (ImGui::Checkbox("Enable state batching", &layer::layer_command_buffer::g_enableStateBatching)) {
                        // Invalidate all layer sort flags to force re-sort with new setting
                        for (auto& [name, layer] : game::s_layers) {
                            if (layer) layer->isSorted = false;
                        }
                        if (layer::layer_command_buffer::g_enableStateBatching) {
                            SPDLOG_INFO("State batching enabled - commands will be sorted by space within z-levels");
                        } else {
                            SPDLOG_INFO("State batching disabled - using z-only sorting");
                        }
                    }
                    if (ImGui::IsItemHovered()) {
                        ImGui::SetTooltip("Sort commands by space (World/Screen) within same z-level\nReduces camera mode toggles during rendering");
                    }
                    ImGui::TextColored(ImVec4(1.0f, 0.9f, 0.4f, 1.0f), "Note:");
                    ImGui::SameLine();
                    ImGui::TextWrapped("May affect visual order for commands at same z-level. Use distinct z-levels for UI vs World.");
#endif

                    ImGui::EndTabItem();
                }
                if (ImGui::BeginTabItem("Events")) {
                    // Loading progress bar (debug-only).
                    int stagesComplete = globals::loadingStateIndex;
                    float progress = std::min(1.0f, stagesComplete / 10.0f); // heuristic until a real total is known
                    if (stagesComplete != lastLoadingCountShown) {
                        fakeProgress = progress;
                        lastLoadingCountShown = stagesComplete;
                    } else {
                        fakeProgress = std::min(1.0f, fakeProgress + 0.02f); // creep forward visually
                    }
                    ImGui::Text("Loading progress");
                    ImGui::ProgressBar(fakeProgress, ImVec2(0.0f, 0.0f));

                    ImGui::Text("Last loading stage: %s (%s)",
                                globals::getLastLoadingStage().empty() ? "<none>" : globals::getLastLoadingStage().c_str(),
                                globals::getLastLoadingStageSuccess() ? "ok" : "failed");
                    ImGui::Text("Last UI focus: %d", static_cast<int>(globals::getLastUIFocus()));
                    ImGui::Text("Last UI button: %d", static_cast<int>(globals::getLastUIButtonActivated()));
                    ImGui::Text("Last collision: A=%d B=%d",
                                static_cast<int>(globals::getLastCollisionA()),
                                static_cast<int>(globals::getLastCollisionB()));
                    ImGui::EndTabItem();
                }
                if (ImGui::BeginTabItem("UI Pack Editor")) {
                    if (ImGui::Button("Open UI Pack Editor")) {
                        packEditorState.isOpen = true;
                    }
                    ImGui::Text("Use this tool to create and edit UI asset packs");
                    ImGui::EndTabItem();
                }
                if (ImGui::BeginTabItem("Save System")) {
                    // Platform info
#if defined(__EMSCRIPTEN__)
                    ImGui::TextColored(ImVec4(0.4f, 0.8f, 1.0f, 1.0f), "Platform: Web (Emscripten)");
                    ImGui::Text("Storage: IndexedDB via IDBFS");
#else
                    ImGui::TextColored(ImVec4(0.4f, 1.0f, 0.4f, 1.0f), "Platform: Desktop");
                    ImGui::Text("Storage: Local filesystem");
#endif
                    ImGui::Separator();

                    // Save file status
                    static const std::string savePath = "saves/profile.json";
                    static const std::string backupPath = "saves/profile.json.bak";
                    bool saveExists = save_io::file_exists(savePath);
                    bool backupExists = save_io::file_exists(backupPath);

                    ImGui::Text("Save Path: %s", savePath.c_str());
                    if (saveExists) {
                        ImGui::TextColored(ImVec4(0.4f, 1.0f, 0.4f, 1.0f), "  Status: EXISTS");
                        // Show file contents preview
                        static std::string lastContent;
                        static bool showContent = false;
                        if (ImGui::Button("Preview Save File")) {
                            auto content = save_io::load_file(savePath);
                            lastContent = content.value_or("<failed to load>");
                            showContent = true;
                        }
                        if (showContent && !lastContent.empty()) {
                            ImGui::SameLine();
                            if (ImGui::Button("Hide")) {
                                showContent = false;
                            }
                            ImGui::BeginChild("SavePreview", ImVec2(0, 150), true);
                            ImGui::TextWrapped("%s", lastContent.c_str());
                            ImGui::EndChild();
                        }
                    } else {
                        ImGui::TextColored(ImVec4(1.0f, 0.5f, 0.0f, 1.0f), "  Status: NO SAVE FILE");
                    }

                    ImGui::Text("Backup: %s", backupPath.c_str());
                    if (backupExists) {
                        ImGui::TextColored(ImVec4(0.4f, 1.0f, 0.4f, 1.0f), "  Status: EXISTS");
                    } else {
                        ImGui::TextColored(ImVec4(0.6f, 0.6f, 0.6f, 1.0f), "  Status: No backup");
                    }

                    ImGui::Separator();
                    ImGui::Text("Actions:");

                    // Call SaveManager.save() via Lua
                    if (ImGui::Button("Save Now")) {
                        try {
                            sol::table saveManager = ai_system::masterStateLua["SaveManager"];
                            if (saveManager.valid()) {
                                sol::function saveFn = saveManager["save"];
                                if (saveFn.valid()) {
                                    saveFn();
                                    SPDLOG_INFO("[DebugUI] Triggered SaveManager.save()");
                                }
                            }
                        } catch (const std::exception& e) {
                            SPDLOG_WARN("[DebugUI] Failed to call SaveManager.save(): {}", e.what());
                        }
                    }

                    ImGui::SameLine();

                    // Call SaveManager.load() via Lua
                    if (ImGui::Button("Reload Save")) {
                        try {
                            sol::table saveManager = ai_system::masterStateLua["SaveManager"];
                            if (saveManager.valid()) {
                                sol::function loadFn = saveManager["load"];
                                if (loadFn.valid()) {
                                    loadFn();
                                    SPDLOG_INFO("[DebugUI] Triggered SaveManager.load()");
                                }
                            }
                        } catch (const std::exception& e) {
                            SPDLOG_WARN("[DebugUI] Failed to call SaveManager.load(): {}", e.what());
                        }
                    }

                    ImGui::SameLine();

                    // Delete save with confirmation
                    static bool confirmDelete = false;
                    if (!confirmDelete) {
                        if (ImGui::Button("Delete Save")) {
                            confirmDelete = true;
                        }
                    } else {
                        ImGui::TextColored(ImVec4(1.0f, 0.3f, 0.3f, 1.0f), "Confirm delete?");
                        ImGui::SameLine();
                        if (ImGui::Button("Yes, Delete")) {
                            try {
                                sol::table saveManager = ai_system::masterStateLua["SaveManager"];
                                if (saveManager.valid()) {
                                    sol::function deleteFn = saveManager["delete_save"];
                                    if (deleteFn.valid()) {
                                        deleteFn();
                                        SPDLOG_INFO("[DebugUI] Triggered SaveManager.delete_save()");
                                    }
                                }
                            } catch (const std::exception& e) {
                                SPDLOG_WARN("[DebugUI] Failed to call SaveManager.delete_save(): {}", e.what());
                            }
                            confirmDelete = false;
                        }
                        ImGui::SameLine();
                        if (ImGui::Button("Cancel")) {
                            confirmDelete = false;
                        }
                    }

                    ImGui::Separator();

                    // Show registered collectors (from Lua)
                    ImGui::Text("Registered Collectors:");
                    try {
                        sol::table saveManager = ai_system::masterStateLua["SaveManager"];
                        if (saveManager.valid()) {
                            sol::table collectors = saveManager["collectors"];
                            if (collectors.valid()) {
                                int count = 0;
                                for (auto& [key, value] : collectors) {
                                    ImGui::BulletText("%s", key.as<std::string>().c_str());
                                    count++;
                                }
                                if (count == 0) {
                                    ImGui::TextColored(ImVec4(0.6f, 0.6f, 0.6f, 1.0f), "  (none registered)");
                                }
                            }
                        }
                    } catch (const std::exception& e) {
                        ImGui::TextColored(ImVec4(1.0f, 0.3f, 0.3f, 1.0f), "Error: %s", e.what());
                    }

                    ImGui::Separator();

                    // Live Statistics Editor
                    ImGui::Text("Statistics (Live Edit):");
                    try {
                        sol::table stats = ai_system::masterStateLua["Statistics"];
                        if (stats.valid()) {
                            static int runs = 0, wave = 0, kills = 0, gold = 0;
                            static bool initialized = false;

                            // Read current values
                            if (!initialized || ImGui::Button("Refresh")) {
                                runs = stats.get_or("runs_completed", 0);
                                wave = stats.get_or("highest_wave", 0);
                                kills = stats.get_or("total_kills", 0);
                                gold = stats.get_or("total_gold_earned", 0);
                                initialized = true;
                            }

                            ImGui::InputInt("Runs Completed", &runs);
                            ImGui::InputInt("Highest Wave", &wave);
                            ImGui::InputInt("Total Kills", &kills);
                            ImGui::InputInt("Total Gold", &gold);

                            if (ImGui::Button("Apply Changes")) {
                                stats["runs_completed"] = runs;
                                stats["highest_wave"] = wave;
                                stats["total_kills"] = kills;
                                stats["total_gold_earned"] = gold;
                                SPDLOG_INFO("[DebugUI] Applied Statistics changes");
                            }
                            ImGui::SameLine();
                            if (ImGui::Button("Apply & Save")) {
                                stats["runs_completed"] = runs;
                                stats["highest_wave"] = wave;
                                stats["total_kills"] = kills;
                                stats["total_gold_earned"] = gold;

                                sol::table saveManager = ai_system::masterStateLua["SaveManager"];
                                if (saveManager.valid()) {
                                    sol::function saveFn = saveManager["save"];
                                    if (saveFn.valid()) {
                                        saveFn();
                                        SPDLOG_INFO("[DebugUI] Applied Statistics and triggered save");
                                    }
                                }
                            }
                        } else {
                            ImGui::TextColored(ImVec4(0.6f, 0.6f, 0.6f, 1.0f), "Statistics module not loaded");
                        }
                    } catch (const std::exception& e) {
                        ImGui::TextColored(ImVec4(1.0f, 0.3f, 0.3f, 1.0f), "Error: %s", e.what());
                    }

                    ImGui::EndTabItem();
                }
                ImGui::EndTabBar();
            }
        }

        ImGui::End();

        // Render the UI Pack Editor window (outside the debug window)
        ui::editor::renderPackEditor(packEditorState);
    }

}
