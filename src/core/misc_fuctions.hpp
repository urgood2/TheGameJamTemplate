#pragma once

#include "util/common_headers.hpp"

#include <string>
#include <unordered_map>

namespace game {
    void SetUpShaderUniforms(); 
    
    extern std::function<void()> OnUIScaleChanged;

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

