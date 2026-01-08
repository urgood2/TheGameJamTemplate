#include "perf_overlay.hpp"
#include "../third_party/rlImGui/imgui.h"
#include "../systems/layer/layer_optimized.hpp"
#include "../systems/main_loop_enhancement/main_loop.hpp"
#include "../systems/scripting/binding_recorder.hpp"
#include "../core/globals.hpp"
#include "raylib.h"

#include <algorithm>
#include <numeric>

// Forward declarations
namespace ai_system {
    extern sol::state masterStateLua;
}

namespace perf_overlay {

// Global state
Config g_config;
FrameMetrics g_currentMetrics;
std::array<float, FRAME_HISTORY_SIZE> g_frameTimeHistory = {};
int g_frameHistoryIndex = 0;

void init() {
    g_config = Config{};
    g_currentMetrics = FrameMetrics{};
    g_frameTimeHistory.fill(0.0f);
    g_frameHistoryIndex = 0;
}

void update(entt::registry& registry) {
    if (!g_config.enabled) return;

    // Frame timing
    g_currentMetrics.frameTimeMs = main_loop::mainLoop.smoothedDeltaTime * 1000.0f;
    g_currentMetrics.fps = static_cast<float>(main_loop::mainLoop.renderedFPS);

    // Store in history
    g_frameTimeHistory[g_frameHistoryIndex] = g_currentMetrics.frameTimeMs;
    g_frameHistoryIndex = (g_frameHistoryIndex + 1) % FRAME_HISTORY_SIZE;

    // Draw call stats from layer system
    const auto& stats = layer::g_drawCallStats;
    g_currentMetrics.drawCallsTotal = stats.total();
    g_currentMetrics.drawCallsSprites = stats.sprites;
    g_currentMetrics.drawCallsText = stats.text;
    g_currentMetrics.drawCallsShapes = stats.shapes;
    g_currentMetrics.drawCallsUI = stats.ui;
    g_currentMetrics.drawCallsState = stats.state;

    // Entity count from registry
    g_currentMetrics.entityCount = static_cast<int>(registry.storage<entt::entity>().in_use());

    // Lua memory (via collectgarbage("count")) - with proper state validation
    if (ai_system::masterStateLua.lua_state() != nullptr) {
        try {
            sol::protected_function_result result = ai_system::masterStateLua.script("return collectgarbage('count')");
            if (result.valid()) {
                g_currentMetrics.luaMemoryKB = result.get<float>();
            } else {
                g_currentMetrics.luaMemoryKB = 0.0f;
            }
        } catch (const std::exception& e) {
            // Log once per session, not every frame
            static bool logged = false;
            if (!logged) {
                SPDLOG_WARN("perf_overlay: Lua memory query failed: {}", e.what());
                logged = true;
            }
            g_currentMetrics.luaMemoryKB = 0.0f;
        }
    }
}

void render() {
    if (!g_config.enabled) return;

    // Position calculation
    float margin = 10.0f;
    float width = 280.0f;
    float height = 300.0f;
    float x = margin;
    float y = margin;

    int screenW = GetScreenWidth();
    int screenH = GetScreenHeight();

    switch (g_config.position) {
        case 1: x = screenW - width - margin; break;  // top-right
        case 2: y = screenH - height - margin; break;  // bottom-left
        case 3: x = screenW - width - margin; y = screenH - height - margin; break;  // bottom-right
    }

    ImGui::SetNextWindowPos(ImVec2(x, y), ImGuiCond_Always);
    ImGui::SetNextWindowSize(ImVec2(width, 0), ImGuiCond_Always);
    ImGui::SetNextWindowBgAlpha(g_config.opacity);

    ImGuiWindowFlags flags = ImGuiWindowFlags_NoTitleBar |
                             ImGuiWindowFlags_NoResize |
                             ImGuiWindowFlags_NoMove |
                             ImGuiWindowFlags_NoScrollbar |
                             ImGuiWindowFlags_NoSavedSettings |
                             ImGuiWindowFlags_NoFocusOnAppearing |
                             ImGuiWindowFlags_NoNav;

    if (ImGui::Begin("##PerfOverlay", nullptr, flags)) {
        // Header
        ImGui::TextColored(ImVec4(0.4f, 0.8f, 1.0f, 1.0f), "PERFORMANCE");
        ImGui::Separator();

        // FPS / Frame time
        ImVec4 fpsColor = g_currentMetrics.fps >= 55 ? ImVec4(0.2f, 1.0f, 0.2f, 1.0f) :
                          g_currentMetrics.fps >= 30 ? ImVec4(1.0f, 1.0f, 0.2f, 1.0f) :
                                                       ImVec4(1.0f, 0.3f, 0.3f, 1.0f);
        ImGui::TextColored(fpsColor, "FPS: %.0f (%.2fms)", g_currentMetrics.fps, g_currentMetrics.frameTimeMs);

        // Frame time graph
        if (g_config.showFrameGraph) {
            float maxTime = *std::max_element(g_frameTimeHistory.begin(), g_frameTimeHistory.end());
            maxTime = std::max(maxTime, 33.3f);  // At least 30fps scale

            // Reorder for display (oldest to newest)
            std::array<float, FRAME_HISTORY_SIZE> displayData;
            for (int i = 0; i < FRAME_HISTORY_SIZE; i++) {
                displayData[i] = g_frameTimeHistory[(g_frameHistoryIndex + i) % FRAME_HISTORY_SIZE];
            }

            ImGui::PlotLines("##FrameGraph", displayData.data(), FRAME_HISTORY_SIZE,
                            0, nullptr, 0.0f, maxTime, ImVec2(width - 20, 40));

            // P99 and average
            ImGui::Text("Avg: %.2fms | P99: %.2fms", getAverageFrameTime(), getFrameTimeP99());
        }

        ImGui::Separator();

        // Draw Calls
        if (g_config.showDrawCalls) {
            ImGui::TextColored(ImVec4(1.0f, 0.8f, 0.4f, 1.0f), "Draw Calls: %d", g_currentMetrics.drawCallsTotal);
            ImGui::Indent(10);
            ImGui::Text("Sprites: %d", g_currentMetrics.drawCallsSprites);
            ImGui::Text("Text: %d", g_currentMetrics.drawCallsText);
            ImGui::Text("Shapes: %d", g_currentMetrics.drawCallsShapes);
            ImGui::Text("UI: %d", g_currentMetrics.drawCallsUI);
            ImGui::Text("State: %d", g_currentMetrics.drawCallsState);
            ImGui::Unindent(10);
        }

        ImGui::Separator();

        // Entity count
        if (g_config.showEntityCount) {
            ImGui::Text("Entities: %d", g_currentMetrics.entityCount);
        }

        // Memory
        if (g_config.showMemory) {
            float memMB = g_currentMetrics.luaMemoryKB / 1024.0f;
            ImVec4 memColor = memMB < 50 ? ImVec4(0.2f, 1.0f, 0.2f, 1.0f) :
                              memMB < 100 ? ImVec4(1.0f, 1.0f, 0.2f, 1.0f) :
                                            ImVec4(1.0f, 0.3f, 0.3f, 1.0f);
            ImGui::TextColored(memColor, "Lua Mem: %.2f MB", memMB);
        }

        ImGui::Separator();
        ImGui::TextDisabled("F3 to toggle");
    }
    ImGui::End();
}

void toggle() {
    g_config.enabled = !g_config.enabled;
}

void setEnabled(bool enabled) {
    g_config.enabled = enabled;
}

bool isEnabled() {
    return g_config.enabled;
}

void setPosition(int pos) {
    g_config.position = pos % 4;
}

void setOpacity(float alpha) {
    g_config.opacity = std::clamp(alpha, 0.0f, 1.0f);
}

const FrameMetrics& getMetrics() {
    return g_currentMetrics;
}

float getAverageFrameTime() {
    float sum = std::accumulate(g_frameTimeHistory.begin(), g_frameTimeHistory.end(), 0.0f);
    return sum / FRAME_HISTORY_SIZE;
}

float getAverageFPS() {
    float avgTime = getAverageFrameTime();
    return avgTime > 0 ? 1000.0f / avgTime : 0.0f;
}

float getFrameTimeP99() {
    std::array<float, FRAME_HISTORY_SIZE> sorted = g_frameTimeHistory;
    std::sort(sorted.begin(), sorted.end());
    int p99Index = static_cast<int>(FRAME_HISTORY_SIZE * 0.99f);
    return sorted[p99Index];
}

void exposeToLua(sol::state& lua) {
    auto& rec = BindingRecorder::instance();

    lua["perf_overlay"] = lua.create_table();

    lua["perf_overlay"]["toggle"] = &toggle;
    lua["perf_overlay"]["show"] = []() { setEnabled(true); };
    lua["perf_overlay"]["hide"] = []() { setEnabled(false); };
    lua["perf_overlay"]["is_enabled"] = &isEnabled;
    lua["perf_overlay"]["set_position"] = &setPosition;
    lua["perf_overlay"]["set_opacity"] = &setOpacity;

    lua["perf_overlay"]["get_stats"] = [&lua]() -> sol::table {
        sol::table t = lua.create_table();
        t["fps"] = g_currentMetrics.fps;
        t["frame_time_ms"] = g_currentMetrics.frameTimeMs;
        t["avg_frame_time_ms"] = getAverageFrameTime();
        t["p99_frame_time_ms"] = getFrameTimeP99();
        t["draw_calls_total"] = g_currentMetrics.drawCallsTotal;
        t["draw_calls_sprites"] = g_currentMetrics.drawCallsSprites;
        t["draw_calls_text"] = g_currentMetrics.drawCallsText;
        t["draw_calls_shapes"] = g_currentMetrics.drawCallsShapes;
        t["draw_calls_ui"] = g_currentMetrics.drawCallsUI;
        t["draw_calls_state"] = g_currentMetrics.drawCallsState;
        t["entity_count"] = g_currentMetrics.entityCount;
        t["lua_memory_kb"] = g_currentMetrics.luaMemoryKB;
        t["lua_memory_mb"] = g_currentMetrics.luaMemoryKB / 1024.0f;
        return t;
    };

    // Documentation
    rec.record_property("perf_overlay", {"toggle", "function()", "Toggle performance overlay visibility"});
    rec.record_property("perf_overlay", {"show", "function()", "Show performance overlay"});
    rec.record_property("perf_overlay", {"hide", "function()", "Hide performance overlay"});
    rec.record_property("perf_overlay", {"is_enabled", "function(): boolean", "Check if overlay is visible"});
    rec.record_property("perf_overlay", {"set_position", "function(pos: int)", "Set corner: 0=TL, 1=TR, 2=BL, 3=BR"});
    rec.record_property("perf_overlay", {"set_opacity", "function(alpha: number)", "Set overlay opacity (0-1)"});
    rec.record_property("perf_overlay", {"get_stats", "function(): table", "Get all performance metrics as table"});
}

}  // namespace perf_overlay
