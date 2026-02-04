#pragma once

#include "raylib.h"
#include <functional>
#include <map>
#include <memory>
#include <string>
#include <vector>

#include "../systems/spring/spring.hpp"
#include "../third_party/rlImGui/imgui.h"
#include "entt/fwd.hpp"

struct ImTextCustomization;

namespace util {
struct TextLogEntry;

}

class ImGuiConsole; // forward declaration
struct ImVec4;

namespace gui {

// Struct to hold NinePatch data
struct NinePatchData {
  Texture2D texture;
  Rectangle source;
  int left;
  int top;
  int right;
  int bottom;
};

// ---------------------------------------------------------
// debugging console
// ---------------------------------------------------------

enum class LogMessageType { SYSTEM, NORMAL, TIP };

#if ENABLE_IMGUI_CONSOLE
extern std::unique_ptr<ImGuiConsole> consolePtr;
extern bool showConsole;

extern auto initConsole() -> void;
#else
inline constexpr bool showConsole = false;
inline auto initConsole() -> void {}
#endif

extern bool showTutorial;

// ---------------------------------------------------------
// NinePatch
// ---------------------------------------------------------

extern auto drawNinePatchWindowBackground(std::string ninepatchName,
                                          Rectangle boundingRect, float alpha,
                                          float titleBarHeight, ImVec4 fgColor,
                                          ImVec4 bgColor) -> void;
auto drawNinePatchButton(const std::string &buttonNameID, Rectangle buttonRect,
                         const std::string &ninePatchRegion,
                         const std::string &buttonText, float alpha,
                         const std::string &fgColor, const std::string &bgColor,
                         std::function<void()> onClick) -> void;
void drawImGuiNinepatch(Rectangle &boundingRect,
                        gui::NinePatchData &ninePatchData, ImVec4 &fgColor,
                        float alpha, ImVec4 &bgColor, ImDrawList *drawList,
                        ImTextureID textureID);

} // namespace gui
