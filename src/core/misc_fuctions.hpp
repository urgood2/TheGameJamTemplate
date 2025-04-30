#pragma once

#include "util/common_headers.hpp"

#include <string>
#include <unordered_map>

namespace game {
    void SetUpShaderUniforms(); 

    inline void ShowDebugUI() {
        if (!ImGui::Begin("DebugWindow")) return;
    
        if (ImGui::BeginTabBar("Debug variables")) {
            if (ImGui::BeginTabItem("Flags")) {
                ImGui::Checkbox("Show Bounding Boxes & Debug Info", &globals::drawDebugInfo);
                ImGui::EndTabItem();
            }
            ImGui::EndTabBar();
        }
    
        ImGui::End();
    }
}

