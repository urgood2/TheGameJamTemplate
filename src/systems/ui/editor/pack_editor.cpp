#include "systems/ui/editor/pack_editor.hpp"
#include "third_party/rlImGui/rlImGui.h"
#include "util/common_headers.hpp"
#include "core/engine_context.hpp"
#include <fstream>
#include <filesystem>
#include <algorithm>
#include <cmath>

namespace ui::editor {

void initPackEditor(PackEditorState& state) {
    state.zoom = 1.0f;
    state.pan = {0, 0};
    state.selection = {};
    state.editCtx = {};
    state.statusMessage = "Ready";
}

void renderAtlasViewport(PackEditorState& state) {
    ImVec2 viewportSize = ImGui::GetContentRegionAvail();
    ImVec2 viewportPos = ImGui::GetCursorScreenPos();

    // Draw background
    ImDrawList* drawList = ImGui::GetWindowDrawList();
    drawList->AddRectFilled(viewportPos,
        ImVec2(viewportPos.x + viewportSize.x, viewportPos.y + viewportSize.y),
        IM_COL32(40, 40, 40, 255));

    if (!state.atlas || state.atlas->id == 0) {
        // Center the "No atlas loaded" text
        ImVec2 textSize = ImGui::CalcTextSize("No atlas loaded");
        ImGui::SetCursorScreenPos(ImVec2(
            viewportPos.x + (viewportSize.x - textSize.x) * 0.5f,
            viewportPos.y + (viewportSize.y - textSize.y) * 0.5f
        ));
        ImGui::Text("No atlas loaded");
        return;
    }

    // Create an invisible button to capture mouse interactions
    ImGui::SetCursorScreenPos(viewportPos);
    ImGui::InvisibleButton("viewport", viewportSize);
    bool isViewportHovered = ImGui::IsItemHovered();

    // Handle zoom with scroll wheel
    if (isViewportHovered && ImGui::IsWindowFocused()) {
        float wheel = ImGui::GetIO().MouseWheel;
        if (wheel != 0) {
            float oldZoom = state.zoom;
            state.zoom = std::clamp(state.zoom + wheel * 0.1f, 0.1f, 10.0f);

            // Zoom toward mouse position
            ImVec2 mousePos = ImGui::GetMousePos();
            ImVec2 relMouse = ImVec2(mousePos.x - viewportPos.x, mousePos.y - viewportPos.y);
            float zoomRatio = state.zoom / oldZoom;
            state.pan.x = relMouse.x - (relMouse.x - state.pan.x) * zoomRatio;
            state.pan.y = relMouse.y - (relMouse.y - state.pan.y) * zoomRatio;
        }

        // Handle pan with middle mouse
        if (ImGui::IsMouseDragging(ImGuiMouseButton_Middle)) {
            ImVec2 delta = ImGui::GetMouseDragDelta(ImGuiMouseButton_Middle);
            state.pan.x += delta.x;
            state.pan.y += delta.y;
            ImGui::ResetMouseDragDelta(ImGuiMouseButton_Middle);
        }

        // Handle selection with left mouse
        if (ImGui::IsMouseClicked(ImGuiMouseButton_Left)) {
            ImVec2 mousePos = ImGui::GetMousePos();
            state.selection.active = true;
            state.selection.start = {
                (mousePos.x - viewportPos.x - state.pan.x) / state.zoom,
                (mousePos.y - viewportPos.y - state.pan.y) / state.zoom
            };
            state.selection.end = state.selection.start;
        }

        if (ImGui::IsMouseDragging(ImGuiMouseButton_Left) && state.selection.active) {
            ImVec2 mousePos = ImGui::GetMousePos();
            state.selection.end = {
                (mousePos.x - viewportPos.x - state.pan.x) / state.zoom,
                (mousePos.y - viewportPos.y - state.pan.y) / state.zoom
            };
        }

        if (ImGui::IsMouseReleased(ImGuiMouseButton_Left)) {
            // Snap to pixel boundaries
            auto rect = state.selection.getRect();
            state.selection.start = {std::floor(rect.x), std::floor(rect.y)};
            state.selection.end = {
                std::floor(rect.x + rect.width),
                std::floor(rect.y + rect.height)
            };
        }
    }

    // Draw atlas texture
    float scaledW = state.atlas->width * state.zoom;
    float scaledH = state.atlas->height * state.zoom;

    ImVec2 atlasPos = ImVec2(viewportPos.x + state.pan.x, viewportPos.y + state.pan.y);

    // Set cursor position and draw texture using rlImGui
    ImGui::SetCursorScreenPos(atlasPos);
    rlImGuiImageRect(state.atlas,
        static_cast<int>(scaledW), static_cast<int>(scaledH),
        Rectangle{0, 0, static_cast<float>(state.atlas->width), static_cast<float>(state.atlas->height)});

    // Draw selection rectangle
    if (state.selection.active) {
        auto rect = state.selection.getRect();
        ImVec2 selStart = ImVec2(
            atlasPos.x + rect.x * state.zoom,
            atlasPos.y + rect.y * state.zoom
        );
        ImVec2 selEnd = ImVec2(
            atlasPos.x + (rect.x + rect.width) * state.zoom,
            atlasPos.y + (rect.y + rect.height) * state.zoom
        );
        drawList->AddRect(selStart, selEnd, IM_COL32(255, 255, 0, 255), 0, 0, 2.0f);

        // Draw 9-patch guides if enabled
        if (state.editCtx.useNinePatch) {
            auto& g = state.editCtx.guides;
            // Left guide (red vertical)
            drawList->AddLine(
                ImVec2(selStart.x + g.left * state.zoom, selStart.y),
                ImVec2(selStart.x + g.left * state.zoom, selEnd.y),
                IM_COL32(255, 100, 100, 200), 1.5f);
            // Right guide (red vertical)
            drawList->AddLine(
                ImVec2(selEnd.x - g.right * state.zoom, selStart.y),
                ImVec2(selEnd.x - g.right * state.zoom, selEnd.y),
                IM_COL32(255, 100, 100, 200), 1.5f);
            // Top guide (green horizontal)
            drawList->AddLine(
                ImVec2(selStart.x, selStart.y + g.top * state.zoom),
                ImVec2(selEnd.x, selStart.y + g.top * state.zoom),
                IM_COL32(100, 255, 100, 200), 1.5f);
            // Bottom guide (green horizontal)
            drawList->AddLine(
                ImVec2(selStart.x, selEnd.y - g.bottom * state.zoom),
                ImVec2(selEnd.x, selEnd.y - g.bottom * state.zoom),
                IM_COL32(100, 255, 100, 200), 1.5f);
        }
    }
}

void renderElementPanel(PackEditorState& state) {
    ImGui::Text("Element Properties");
    ImGui::Separator();

    // Element type selection
    const char* elementTypes[] = {"Panel", "Button", "Progress Bar", "Scrollbar", "Slider", "Input", "Icon"};
    int currentType = static_cast<int>(state.editCtx.elementType);
    if (ImGui::Combo("Element Type", &currentType, elementTypes, IM_ARRAYSIZE(elementTypes))) {
        state.editCtx.elementType = static_cast<PackElementType>(currentType);
    }

    // Variant name
    static char variantBuf[64] = "";
    if (ImGui::InputText("Variant Name", variantBuf, sizeof(variantBuf))) {
        state.editCtx.variantName = variantBuf;
    }

    // Button state (if button)
    if (state.editCtx.elementType == PackElementType::Button) {
        const char* buttonStates[] = {"Normal", "Hover", "Pressed", "Disabled"};
        int currentState = static_cast<int>(state.editCtx.buttonState);
        if (ImGui::Combo("Button State", &currentState, buttonStates, IM_ARRAYSIZE(buttonStates))) {
            state.editCtx.buttonState = static_cast<ButtonState>(currentState);
        }
    }

    ImGui::Separator();

    // 9-patch toggle
    ImGui::Checkbox("Use 9-Patch", &state.editCtx.useNinePatch);

    if (state.editCtx.useNinePatch) {
        ImGui::SliderInt("Left", &state.editCtx.guides.left, 0, 64);
        ImGui::SliderInt("Top", &state.editCtx.guides.top, 0, 64);
        ImGui::SliderInt("Right", &state.editCtx.guides.right, 0, 64);
        ImGui::SliderInt("Bottom", &state.editCtx.guides.bottom, 0, 64);
    } else {
        // Scale mode
        const char* scaleModes[] = {"Stretch", "Tile", "Fixed"};
        int currentMode = static_cast<int>(state.editCtx.scaleMode);
        if (ImGui::Combo("Scale Mode", &currentMode, scaleModes, IM_ARRAYSIZE(scaleModes))) {
            state.editCtx.scaleMode = static_cast<SpriteScaleMode>(currentMode);
        }
    }

    ImGui::Separator();

    // Selection info
    if (state.selection.active) {
        auto rect = state.selection.getRect();
        ImGui::Text("Selection:");
        ImGui::Text("  Pos: (%.0f, %.0f)", rect.x, rect.y);
        ImGui::Text("  Size: %.0fx%.0f", rect.width, rect.height);
    } else {
        ImGui::TextDisabled("No selection");
    }

    ImGui::Separator();

    // Add to pack button
    bool canAdd = !state.editCtx.variantName.empty() && state.selection.active;
    if (!canAdd) {
        ImGui::BeginDisabled();
    }

    if (ImGui::Button("Add to Pack", ImVec2(-1, 0))) {
        auto rect = state.selection.getRect();
        RegionDef region;
        region.region = rect;
        region.scaleMode = state.editCtx.scaleMode;

        if (state.editCtx.useNinePatch) {
            NPatchInfo info{};
            info.source = rect;
            info.left = state.editCtx.guides.left;
            info.top = state.editCtx.guides.top;
            info.right = state.editCtx.guides.right;
            info.bottom = state.editCtx.guides.bottom;
            info.layout = NPATCH_NINE_PATCH;
            region.ninePatch = info;
        }

        switch (state.editCtx.elementType) {
            case PackElementType::Panel:
                state.workingPack.panels[state.editCtx.variantName] = region;
                state.statusMessage = "Added panel: " + state.editCtx.variantName;
                break;
            case PackElementType::Icon:
                state.workingPack.icons[state.editCtx.variantName] = region;
                state.statusMessage = "Added icon: " + state.editCtx.variantName;
                break;
            case PackElementType::Button: {
                auto& btn = state.workingPack.buttons[state.editCtx.variantName];
                switch (state.editCtx.buttonState) {
                    case ButtonState::Normal:
                        btn.normal = region;
                        state.statusMessage = "Added button normal state: " + state.editCtx.variantName;
                        break;
                    case ButtonState::Hover:
                        btn.hover = region;
                        state.statusMessage = "Added button hover state: " + state.editCtx.variantName;
                        break;
                    case ButtonState::Pressed:
                        btn.pressed = region;
                        state.statusMessage = "Added button pressed state: " + state.editCtx.variantName;
                        break;
                    case ButtonState::Disabled:
                        btn.disabled = region;
                        state.statusMessage = "Added button disabled state: " + state.editCtx.variantName;
                        break;
                }
                break;
            }
            // TODO: Handle other element types (ProgressBar, Scrollbar, Slider, Input)
            default:
                state.statusMessage = "Element type not yet supported";
                break;
        }
    }

    if (!canAdd) {
        ImGui::EndDisabled();
    }

    if (!canAdd && ImGui::IsItemHovered(ImGuiHoveredFlags_AllowWhenDisabled)) {
        ImGui::BeginTooltip();
        if (state.editCtx.variantName.empty()) {
            ImGui::Text("Enter a variant name");
        }
        if (!state.selection.active) {
            ImGui::Text("Make a selection in the viewport");
        }
        ImGui::EndTooltip();
    }
}

void renderPackContents(PackEditorState& state) {
    ImGui::Text("Pack Contents");
    ImGui::Separator();

    int totalItems = 0;

    if (!state.workingPack.panels.empty()) {
        totalItems += state.workingPack.panels.size();
        if (ImGui::TreeNode("Panels", "Panels (%zu)", state.workingPack.panels.size())) {
            for (auto& [name, region] : state.workingPack.panels) {
                ImGui::BulletText("%s", name.c_str());
            }
            ImGui::TreePop();
        }
    }

    if (!state.workingPack.buttons.empty()) {
        totalItems += state.workingPack.buttons.size();
        if (ImGui::TreeNode("Buttons", "Buttons (%zu)", state.workingPack.buttons.size())) {
            for (auto& [name, btn] : state.workingPack.buttons) {
                int stateCount = 1 + (btn.hover ? 1 : 0) + (btn.pressed ? 1 : 0) + (btn.disabled ? 1 : 0);
                ImGui::BulletText("%s (%d states)", name.c_str(), stateCount);
            }
            ImGui::TreePop();
        }
    }

    if (!state.workingPack.icons.empty()) {
        totalItems += state.workingPack.icons.size();
        if (ImGui::TreeNode("Icons", "Icons (%zu)", state.workingPack.icons.size())) {
            for (auto& [name, region] : state.workingPack.icons) {
                ImGui::BulletText("%s", name.c_str());
            }
            ImGui::TreePop();
        }
    }

    if (!state.workingPack.progressBars.empty()) {
        totalItems += state.workingPack.progressBars.size();
        if (ImGui::TreeNode("Progress Bars", "Progress Bars (%zu)", state.workingPack.progressBars.size())) {
            for (auto& [name, bar] : state.workingPack.progressBars) {
                ImGui::BulletText("%s", name.c_str());
            }
            ImGui::TreePop();
        }
    }

    if (!state.workingPack.scrollbars.empty()) {
        totalItems += state.workingPack.scrollbars.size();
        if (ImGui::TreeNode("Scrollbars", "Scrollbars (%zu)", state.workingPack.scrollbars.size())) {
            for (auto& [name, scrollbar] : state.workingPack.scrollbars) {
                ImGui::BulletText("%s", name.c_str());
            }
            ImGui::TreePop();
        }
    }

    if (!state.workingPack.sliders.empty()) {
        totalItems += state.workingPack.sliders.size();
        if (ImGui::TreeNode("Sliders", "Sliders (%zu)", state.workingPack.sliders.size())) {
            for (auto& [name, slider] : state.workingPack.sliders) {
                ImGui::BulletText("%s", name.c_str());
            }
            ImGui::TreePop();
        }
    }

    if (!state.workingPack.inputs.empty()) {
        totalItems += state.workingPack.inputs.size();
        if (ImGui::TreeNode("Inputs", "Inputs (%zu)", state.workingPack.inputs.size())) {
            for (auto& [name, input] : state.workingPack.inputs) {
                int stateCount = 1 + (input.focus ? 1 : 0);
                ImGui::BulletText("%s (%d states)", name.c_str(), stateCount);
            }
            ImGui::TreePop();
        }
    }

    if (totalItems == 0) {
        ImGui::TextDisabled("(empty)");
    }
}

void renderPackEditor(PackEditorState& state) {
    if (!state.isOpen) return;

    ImGui::SetNextWindowSize(ImVec2(1000, 700), ImGuiCond_FirstUseEver);
    if (ImGui::Begin("UI Pack Editor", &state.isOpen, ImGuiWindowFlags_MenuBar)) {
        // Menu bar
        if (ImGui::BeginMenuBar()) {
            if (ImGui::BeginMenu("File")) {
                if (ImGui::MenuItem("New Pack")) {
                    initPackEditor(state);
                    state.workingPack = UIAssetPack{};
                    state.statusMessage = "Created new pack";
                }
                if (ImGui::MenuItem("Load Atlas...")) {
                    state.statusMessage = "File dialog not yet implemented";
                    // TODO: File dialog integration
                }
                if (ImGui::MenuItem("Save Pack...")) {
                    state.statusMessage = "File dialog not yet implemented";
                    // TODO: File dialog + savePackManifest
                }
                ImGui::Separator();
                if (ImGui::MenuItem("Close")) {
                    state.isOpen = false;
                }
                ImGui::EndMenu();
            }
            ImGui::EndMenuBar();
        }

        // Zoom controls
        ImGui::AlignTextToFramePadding();
        ImGui::Text("Zoom: %.0f%%", state.zoom * 100);
        ImGui::SameLine();
        if (ImGui::Button("+")) state.zoom = std::min(state.zoom + 0.25f, 10.0f);
        ImGui::SameLine();
        if (ImGui::Button("-")) state.zoom = std::max(state.zoom - 0.25f, 0.1f);
        ImGui::SameLine();
        if (ImGui::Button("Fit")) state.zoom = 1.0f;
        ImGui::SameLine();
        if (ImGui::Button("1:1")) {
            state.zoom = 1.0f;
            state.pan = {0, 0};
        }

        ImGui::Separator();

        // Main layout: viewport | sidebar
        float sidebarWidth = 300.0f;

        // Left: Atlas viewport
        ImGui::BeginChild("Viewport", ImVec2(ImGui::GetContentRegionAvail().x - sidebarWidth - 8, -30), true);
        renderAtlasViewport(state);
        ImGui::EndChild();

        ImGui::SameLine();

        // Right: Element panel + contents
        ImGui::BeginChild("Sidebar", ImVec2(sidebarWidth, -30), true);
        renderElementPanel(state);
        ImGui::Spacing();
        ImGui::Separator();
        ImGui::Spacing();
        renderPackContents(state);
        ImGui::EndChild();

        // Status bar
        ImGui::Separator();
        ImGui::Text("Status: %s", state.statusMessage.c_str());
    }
    ImGui::End();
}

bool savePackManifest(const PackEditorState& state, const std::string& path) {
    using json = nlohmann::json;

    json manifest;
    manifest["name"] = state.workingPack.name;
    manifest["version"] = "1.0";

    if (!state.atlasPath.empty()) {
        std::filesystem::path atlasRel = std::filesystem::relative(
            state.atlasPath,
            std::filesystem::path(path).parent_path()
        );
        manifest["atlas"] = atlasRel.string();
    }

    auto regionToJson = [](const RegionDef& r) -> json {
        json j;
        j["region"] = {r.region.x, r.region.y, r.region.width, r.region.height};
        if (r.ninePatch) {
            j["9patch"] = {r.ninePatch->left, r.ninePatch->top, r.ninePatch->right, r.ninePatch->bottom};
        }
        if (r.scaleMode != SpriteScaleMode::Stretch) {
            j["scale_mode"] = r.scaleMode == SpriteScaleMode::Tile ? "tile" : "fixed";
        }
        return j;
    };

    for (auto& [name, panel] : state.workingPack.panels) {
        manifest["panels"][name] = regionToJson(panel);
    }

    for (auto& [name, btn] : state.workingPack.buttons) {
        json btnJson;
        btnJson["normal"] = regionToJson(btn.normal);
        if (btn.hover) btnJson["hover"] = regionToJson(*btn.hover);
        if (btn.pressed) btnJson["pressed"] = regionToJson(*btn.pressed);
        if (btn.disabled) btnJson["disabled"] = regionToJson(*btn.disabled);
        manifest["buttons"][name] = btnJson;
    }

    for (auto& [name, icon] : state.workingPack.icons) {
        manifest["icons"][name] = regionToJson(icon);
    }

    for (auto& [name, bar] : state.workingPack.progressBars) {
        json barJson;
        barJson["background"] = regionToJson(bar.background);
        barJson["fill"] = regionToJson(bar.fill);
        manifest["progress_bars"][name] = barJson;
    }

    for (auto& [name, scrollbar] : state.workingPack.scrollbars) {
        json scrollbarJson;
        scrollbarJson["track"] = regionToJson(scrollbar.track);
        scrollbarJson["thumb"] = regionToJson(scrollbar.thumb);
        manifest["scrollbars"][name] = scrollbarJson;
    }

    for (auto& [name, slider] : state.workingPack.sliders) {
        json sliderJson;
        sliderJson["track"] = regionToJson(slider.track);
        sliderJson["thumb"] = regionToJson(slider.thumb);
        manifest["sliders"][name] = sliderJson;
    }

    for (auto& [name, input] : state.workingPack.inputs) {
        json inputJson;
        inputJson["normal"] = regionToJson(input.normal);
        if (input.focus) inputJson["focus"] = regionToJson(*input.focus);
        manifest["inputs"][name] = inputJson;
    }

    std::ofstream file(path);
    if (!file.is_open()) {
        SPDLOG_ERROR("Failed to open file for writing: {}", path);
        return false;
    }
    file << manifest.dump(2);
    SPDLOG_INFO("Saved UI pack manifest to {}", path);
    return true;
}

bool loadPackManifest(PackEditorState& state, const std::string& path) {
    // Reuse existing registerPack logic, then copy to workingPack
    if (registerPack("_editor_temp", path)) {
        auto* pack = getPack("_editor_temp");
        if (pack) {
            state.workingPack = *pack;
            state.atlasPath = pack->atlasPath;
            state.atlas = getAtlasTexture(pack->atlasPath);  // Look up atlas from path
            state.packName = pack->name;
            state.statusMessage = "Loaded pack: " + pack->name;
            SPDLOG_INFO("Loaded UI pack into editor: {}", pack->name);
            return true;
        }
    }
    SPDLOG_ERROR("Failed to load UI pack manifest: {}", path);
    return false;
}

} // namespace ui::editor
