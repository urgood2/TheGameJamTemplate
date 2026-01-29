#include "goap_debug_window.hpp"
#include "../../third_party/rlImGui/imgui.h"
#include "../../core/globals.hpp"
#include "../../components/components.hpp"
#include <entt/entt.hpp>

namespace goap_debug {

static bool show_window = false;
static entt::entity selected_entity = entt::null;

void toggle() {
    show_window = !show_window;
}

bool is_visible() {
    return show_window;
}

void render() {
    if (!show_window) return;

    ImGui::SetNextWindowSize(ImVec2(450, 400), ImGuiCond_FirstUseEver);

    if (ImGui::Begin("GOAP Debug", &show_window)) {
        auto& registry = globals::getRegistry();
        auto view = registry.view<GOAPComponent>();
        
        // Check if view is empty by iterating
        bool has_entities = false;
        for ([[maybe_unused]] auto _ : view) {
            has_entities = true;
            break;
        }
        
        if (!has_entities) {
            ImGui::TextColored(ImVec4(1.0f, 0.6f, 0.2f, 1.0f), "No GOAP entities");
            ImGui::End();
            return;
        }

        if (ImGui::BeginTabBar("##goap_tabs", ImGuiTabBarFlags_None)) {
            if (ImGui::BeginTabItem("Entities")) {
                ImGui::Text("Select an entity to inspect:");
                ImGui::Separator();

                for (auto entity : view) {
                    auto entity_id = static_cast<uint32_t>(entity);
                    auto& goap = view.get<GOAPComponent>(entity);
                    
                    bool is_selected = (selected_entity == entity);
                    char label[64];
                    snprintf(label, sizeof(label), "Entity %u [%s]", entity_id, goap.type.c_str());
                    
                    if (ImGui::Selectable(label, is_selected)) {
                        selected_entity = entity;
                    }
                }
                ImGui::EndTabItem();
            }

            if (ImGui::BeginTabItem("WorldState")) {
                ImGui::Text("WorldState content here");
                ImGui::EndTabItem();
            }

            if (ImGui::BeginTabItem("Plan")) {
                ImGui::Text("Plan content here");
                ImGui::EndTabItem();
            }

            if (ImGui::BeginTabItem("Blackboard")) {
                ImGui::Text("Blackboard content here");
                ImGui::EndTabItem();
            }

            ImGui::EndTabBar();
        }
    }
    ImGui::End();
}

}  // namespace goap_debug
