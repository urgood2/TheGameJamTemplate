#pragma once

#include "core/globals.hpp"
#include "core/game.hpp"
#include "util/common_headers.hpp"
#include "util/error_handling.hpp"
#include "systems/transform/transform_functions.hpp"
#include "systems/ui/editor/pack_editor.hpp"
#include "systems/layer/layer_optimized.hpp"
#include "systems/layer/layer_command_buffer.hpp"

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
                    ImGui::Text("FPS: %d", GetFPS());
                    ImGui::Text("Frame time: %.2f ms", GetFrameTime() * 1000.0f);

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
                ImGui::EndTabBar();
            }
        }

        ImGui::End();

        // Render the UI Pack Editor window (outside the debug window)
        ui::editor::renderPackEditor(packEditorState);
    }

}
