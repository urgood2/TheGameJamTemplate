#include "goap_debug_window.hpp"
#include "ai_system.hpp"
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

static bool is_selected_valid() {
    if (selected_entity == entt::null) return false;
    auto& registry = globals::getRegistry();
    if (!registry.valid(selected_entity)) return false;
    return registry.all_of<GOAPComponent>(selected_entity);
}

static void render_worldstate(const char* label, const actionplanner_t& ap, const worldstate_t& ws) {
    ImGui::Text("%s:", label);
    ImGui::Indent();
    
    if (ap.numatoms == 0) {
        ImGui::TextColored(ImVec4(0.5f, 0.5f, 0.5f, 1.0f), "(no atoms defined)");
    } else {
        for (int i = 0; i < ap.numatoms; ++i) {
            const char* atomName = ap.atm_names[i];
            if (!atomName) continue;
            
            bool isDontcare = (ws.dontcare & (1LL << i)) != 0;
            bool value = (ws.values & (1LL << i)) != 0;
            
            if (isDontcare) {
                ImGui::TextColored(ImVec4(0.5f, 0.5f, 0.5f, 1.0f), "? %s", atomName);
            } else if (value) {
                ImGui::TextColored(ImVec4(0.2f, 0.8f, 0.2f, 1.0f), "✓ %s", atomName);
            } else {
                ImGui::TextColored(ImVec4(0.8f, 0.2f, 0.2f, 1.0f), "✗ %s", atomName);
            }
        }
    }
    ImGui::Unindent();
}

static std::string get_any_value_string(const Blackboard& bb, const std::string& key) {
    try { return std::to_string(bb.get<int>(key)); } catch (...) {}
    try { return std::to_string(bb.get<float>(key)); } catch (...) {}
    try { return std::to_string(bb.get<double>(key)); } catch (...) {}
    try { return bb.get<bool>(key) ? "true" : "false"; } catch (...) {}
    try { return "\"" + bb.get<std::string>(key) + "\""; } catch (...) {}
    try { return "entity:" + std::to_string(static_cast<uint32_t>(bb.get<entt::entity>(key))); } catch (...) {}
    try { return std::to_string(bb.get<uint32_t>(key)); } catch (...) {}
    try { return std::to_string(bb.get<int64_t>(key)); } catch (...) {}
    return "(unknown type)";
}

static std::string get_any_type_string(const Blackboard& bb, const std::string& key) {
    try { bb.get<int>(key); return "int"; } catch (...) {}
    try { bb.get<float>(key); return "float"; } catch (...) {}
    try { bb.get<double>(key); return "double"; } catch (...) {}
    try { bb.get<bool>(key); return "bool"; } catch (...) {}
    try { bb.get<std::string>(key); return "string"; } catch (...) {}
    try { bb.get<entt::entity>(key); return "entity"; } catch (...) {}
    try { bb.get<uint32_t>(key); return "uint32"; } catch (...) {}
    return "?";
}

void render() {
    if (!show_window) return;

    ImGui::SetNextWindowSize(ImVec2(450, 500), ImGuiCond_FirstUseEver);

    if (ImGui::Begin("GOAP Debug", &show_window)) {
        auto& registry = globals::getRegistry();
        auto view = registry.view<GOAPComponent>();
        
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

        if (selected_entity != entt::null && !is_selected_valid()) {
            selected_entity = entt::null;
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
                if (!is_selected_valid()) {
                    ImGui::TextColored(ImVec4(1.0f, 0.6f, 0.2f, 1.0f), "Select an entity first");
                } else {
                    auto& goap = registry.get<GOAPComponent>(selected_entity);
                    
                    ImGui::Text("Entity %u [%s]", static_cast<uint32_t>(selected_entity), goap.type.c_str());
                    ImGui::Separator();
                    
                    render_worldstate("Current State", goap.ap, goap.current_state);
                    
                    ImGui::Spacing();
                    ImGui::Separator();
                    ImGui::Spacing();
                    
                    render_worldstate("Goal", goap.ap, goap.goal);
                }
                ImGui::EndTabItem();
            }

            if (ImGui::BeginTabItem("Plan")) {
                if (!is_selected_valid()) {
                    ImGui::TextColored(ImVec4(1.0f, 0.6f, 0.2f, 1.0f), "Select an entity first");
                } else {
                    auto& goap = registry.get<GOAPComponent>(selected_entity);
                    
                    ImGui::Text("Entity %u [%s]", static_cast<uint32_t>(selected_entity), goap.type.c_str());
                    ImGui::Separator();
                    
                    ImGui::Text("Plan Size: %d  |  Current Action: %d  |  Cost: %d", 
                                goap.planSize, goap.current_action, goap.planCost);
                    
                    if (goap.dirty) {
                        ImGui::SameLine();
                        ImGui::TextColored(ImVec4(1.0f, 0.6f, 0.2f, 1.0f), "[DIRTY]");
                    }
                    
                    ImGui::Separator();
                    
                    if (goap.planSize == 0) {
                        ImGui::TextColored(ImVec4(0.5f, 0.5f, 0.5f, 1.0f), "(no plan)");
                    } else {
                        for (int i = 0; i < goap.planSize; ++i) {
                            const char* actionName = goap.plan[i] ? goap.plan[i] : "(null)";
                            
                            if (i == goap.current_action) {
                                ImGui::TextColored(ImVec4(0.2f, 0.8f, 1.0f, 1.0f), "→ %d: %s", i + 1, actionName);
                            } else if (i < goap.current_action) {
                                ImGui::TextColored(ImVec4(0.5f, 0.5f, 0.5f, 1.0f), "  %d: %s ✓", i + 1, actionName);
                            } else {
                                ImGui::Text("  %d: %s", i + 1, actionName);
                            }
                        }
                    }
                    
                    ImGui::Spacing();
                    ImGui::Separator();
                    ImGui::Text("Action Queue Size: %zu", goap.actionQueue.size());
                    ImGui::Text("Retries: %d / %d", goap.retries, goap.max_retries);
                    
                    ImGui::Spacing();
                    ImGui::Separator();
                    if (ImGui::Button("Force Replan")) {
                        ai_system::on_interrupt(selected_entity);
                    }
                    if (ImGui::IsItemHovered()) {
                        ImGui::SetTooltip("Clears current plan and triggers goal selection");
                    }
                }
                ImGui::EndTabItem();
            }

            if (ImGui::BeginTabItem("Blackboard")) {
                if (!is_selected_valid()) {
                    ImGui::TextColored(ImVec4(1.0f, 0.6f, 0.2f, 1.0f), "Select an entity first");
                } else {
                    auto& goap = registry.get<GOAPComponent>(selected_entity);
                    
                    ImGui::Text("Entity %u [%s]", static_cast<uint32_t>(selected_entity), goap.type.c_str());
                    ImGui::Separator();
                    
                    const auto& bb = goap.blackboard;
                    auto keys = bb.getKeys();
                    
                    if (keys.empty()) {
                        ImGui::TextColored(ImVec4(0.5f, 0.5f, 0.5f, 1.0f), "(blackboard empty)");
                    } else {
                        ImGui::Text("Entries: %zu", keys.size());
                        ImGui::Separator();
                        
                        ImGui::Columns(3, "blackboard_cols");
                        ImGui::Text("Key"); ImGui::NextColumn();
                        ImGui::Text("Type"); ImGui::NextColumn();
                        ImGui::Text("Value"); ImGui::NextColumn();
                        ImGui::Separator();
                        
                        for (const auto& key : keys) {
                            ImGui::Text("%s", key.c_str()); ImGui::NextColumn();
                            ImGui::TextColored(ImVec4(0.6f, 0.8f, 0.6f, 1.0f), "%s", get_any_type_string(bb, key).c_str()); 
                            ImGui::NextColumn();
                            ImGui::Text("%s", get_any_value_string(bb, key).c_str()); 
                            ImGui::NextColumn();
                        }
                        
                        ImGui::Columns(1);
                    }
                }
                ImGui::EndTabItem();
            }

            ImGui::EndTabBar();
        }
    }
    ImGui::End();
}

}
