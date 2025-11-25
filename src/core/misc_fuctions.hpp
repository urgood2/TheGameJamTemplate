#pragma once

#include "core/globals.hpp"
#include "util/common_headers.hpp"
#include "systems/transform/transform_functions.hpp"

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
        const bool debugWindowOpen = ImGui::Begin("DebugWindow");
        if (debugWindowOpen)
        {

            static const float uiScales[] = { 0.5f, 0.75f, 1.0f, 1.25f, 1.5f, 1.75f, 2.0f, 2.25f, 2.5f };
            static int currentScaleIndex = 2; // Default to 1.0f
            static int previousScaleIndex = currentScaleIndex;
            static int lastLoadingCountShown = 0;
            static float fakeProgress = 0.0f;

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
                ImGui::EndTabBar();
            }
        }

        ImGui::End();
    }

}
