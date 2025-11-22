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
        if (!ImGui::Begin("DebugWindow"))
            return;

        static const float uiScales[] = { 0.5f, 0.75f, 1.0f, 1.25f, 1.5f, 1.75f, 2.0f, 2.25f, 2.5f };
        static int currentScaleIndex = 2; // Default to 1.0f
        static int previousScaleIndex = currentScaleIndex;

        if (ImGui::BeginTabBar("Debug variables")) {
            if (ImGui::BeginTabItem("Flags")) {
                ImGui::Checkbox("Show Bounding Boxes & Debug Info", &globals::drawDebugInfo);
                ImGui::Checkbox("Show physics debug draw", &globals::drawPhysicsDebug);

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
                    globals::globalUIScaleFactor = uiScales[currentScaleIndex];
                    OnUIScaleChanged(); // ✅ Call your method here
                }

                ImGui::EndTabItem();
            }
            ImGui::EndTabBar();
        }

        ImGui::End();
    }


}

