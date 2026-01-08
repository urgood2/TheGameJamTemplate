#include <optional>
#include <variant>
#include <string>
#include <functional>

#include "systems/main_loop_enhancement/main_loop.hpp"
#include "sol/sol.hpp"
#include "third_party/rlImGui/imgui.h"
#include "systems/transform/transform.hpp"
#include "systems/transform/transform_functions.hpp"
#include "systems/physics/physics_components.hpp"
#include "systems/physics/transform_physics_hook.hpp"
#include "systems/physics/physics_manager.hpp"
#include "systems/ui/element.hpp"
#include "systems/ui/box.hpp"
#include "systems/ui/editor/pack_editor.hpp"
#include "systems/timer/timer.hpp"
#include "third_party/navmesh/source/path_finder.h"

#undef SPDLOG_ACTIVE_LEVEL

// Minimal definitions to satisfy globals when linking tests.
namespace main_loop {
    Data mainLoop{};

    void initMainLoopData(std::optional<int>, std::optional<int>) {}
} // namespace main_loop

// ImGui stubs for functions used by misc_fuctions.hpp inline functions
namespace ImGui {
    bool BeginChild(const char*, const ImVec2&, int, int) { return true; }
    void BulletText(const char*, ...) {}
    void TextWrapped(const char*, ...) {}
    void EndChild() {}
    bool InputInt(const char*, int*, int, int, int) { return false; }
    void SameLine(float, float) {}
}

namespace ui {
namespace element {
    void ApplyHover(entt::registry&, entt::entity) {}
    void Click(entt::registry&, entt::entity) {}
    void Release(entt::registry&, entt::entity, entt::entity) {}
    void StopHover(entt::registry&, entt::entity) {}
}
namespace editor {
    void renderPackEditor(PackEditorState&) {}
}
} // namespace ui

// Stub timer system used in input_functions.
namespace timer {
namespace TimerSystem {
    void timer_after(std::variant<float, std::pair<float, float>>, const std::function<void(std::optional<float>)>& cb, const std::string&, const std::string&) {
        if (cb) cb(std::nullopt);
    }
}
} // namespace timer

// Stub transform helpers used by input_functions.
namespace transform {
    entt::entity CreateGameWorldContainerEntity(entt::registry* R, float, float, float, float) {
        return R->create();
    }
    entt::entity CreateOrEmplace(entt::registry* R, entt::entity container, float x, float y, float w, float h, std::optional<entt::entity>) {
        return CreateGameWorldContainerEntity(R, x, y, w, h);
    }
    void SetClickOffset(entt::registry*, entt::entity, Vector2 const&, bool) {}
    void StartDrag(entt::registry*, entt::entity, bool) {}
    void StopDragging(entt::registry*, entt::entity) {}
    Vector2 GetCursorOnFocus(entt::registry*, entt::entity) { return {0, 0}; }
    std::vector<entt::entity> FindAllEntitiesAtPoint(const Vector2&, Camera2D*) { return {}; }
    bool CheckCollisionWithPoint(entt::registry*, entt::entity, Vector2 const&) { return false; }
}

namespace physics {
    void SetBodyRotationLocked(entt::registry&, entt::entity, bool) {}
}

// Stub navmesh pieces to avoid pulling full navmesh lib in tests.
namespace NavMesh {
    Polygon::Polygon() = default;
    Polygon::Polygon(const Polygon&) = default;
    Polygon::Polygon(Polygon&&) = default;
    Polygon::~Polygon() = default;
    Polygon& Polygon::operator=(const Polygon&) = default;
    Polygon& Polygon::operator=(Polygon&&) = default;
    void Polygon::AddPoint(int, int) {}

    void PathFinder::AddPolygons(const std::vector<Polygon>&, int) {}
    void PathFinder::AddExternalPoints(const std::vector<Point>&) {}
    std::vector<NavMesh::Point> PathFinder::GetPath(const Point&, const Point&) { return {}; }
}

// Stub master Lua state used by scripting_system to avoid pulling the full AI system into unit tests.
namespace ai_system {
    sol::state masterStateLua{};
}

// Stub GC pause tracking used by misc_fuctions.hpp ShowDebugUI.
namespace game {
    double g_maxGcPauseMs{0.0};
    double g_avgGcPauseMs{0.0};
    std::unordered_map<std::string, std::shared_ptr<layer::Layer>> s_layers{};
}

namespace layer {
namespace layer_order_system {
    int newZIndex{0};
}
}

namespace TextSystem {
namespace Functions {
    void resetTextScaleAndLayout(entt::entity) {}
}
}

namespace animation_system {
    void resetAnimationUIRenderScale(entt::entity) {}
}

namespace ui {
namespace util {
    void AddInstanceToRegistry(entt::registry&, entt::entity, const std::string&) {}
    void RemoveAll(entt::registry&, entt::entity) {}
}
}

namespace ui {
namespace element {
    entt::entity Initialize(entt::registry& reg, entt::entity, entt::entity, ui::UITypeEnum, std::optional<ui::UIConfig>) { return reg.create(); }
    void SetAlignments(entt::registry&, entt::entity, std::optional<Vector2>, bool) {}
    void ApplyAlignment(entt::registry&, entt::entity, float, float) {}
    std::string DebugPrintTree(entt::registry&, entt::entity, int) { return ""; }
    void buildUIDrawList(entt::registry&, entt::entity, std::vector<ui::UIDrawListItem>&, int) {}
    void InitializeVisualTransform(entt::registry&, entt::entity) {}
    void UpdateUIObjectScalingAndRecnter(entt::registry&, ui::UIConfig*, float, transform::Transform*) {}
    void UpdateUIObjectScalingAndRecnter(ui::UIConfig*, float, transform::Transform*) {}
    void ApplyScalingFactorToSizesInSubtree(entt::registry&, entt::entity, float) {}
    std::pair<float, float> SetWH(entt::registry&, entt::entity) { return {0.0f, 0.0f}; }
    void Remove(entt::registry&, entt::entity) {}
    void DrawSelf(entt::registry&, std::shared_ptr<layer::Layer>, entt::entity, ui::UIElementComponent&, ui::UIConfig&, ui::UIState&, transform::GameObject&, transform::Transform&, const int&) {}
    void DrawSelf(std::shared_ptr<layer::Layer>, entt::entity, ui::UIElementComponent&, ui::UIConfig&, ui::UIState&, transform::GameObject&, transform::Transform&, const int&) {}
    void SetValues(entt::registry&, entt::entity, const ui::LocalTransform&, bool) {}
}
}

namespace transform {
    void AssignRole(entt::registry*, entt::entity, std::optional<transform::InheritedProperties::Type>, entt::entity, std::optional<transform::InheritedProperties::Sync>, std::optional<transform::InheritedProperties::Sync>, std::optional<transform::InheritedProperties::Sync>, std::optional<transform::InheritedProperties::Sync>, std::optional<Vector2>) {}
    void RemoveEntity(entt::registry*, entt::entity) {}
    void AlignToMaster(entt::registry*, entt::entity, bool) {}
    void ConfigureAlignment(entt::registry*, entt::entity, bool, entt::entity, std::optional<transform::InheritedProperties::Sync>, std::optional<transform::InheritedProperties::Sync>, std::optional<transform::InheritedProperties::Sync>, std::optional<transform::InheritedProperties::Sync>, std::optional<int>, std::optional<Vector2>) {}
    void ConfigureContainerForEntity(entt::registry*, entt::entity, entt::entity) {}
    void DrawBoundingBoxAndDebugInfo(entt::registry*, entt::entity, std::shared_ptr<layer::Layer>) {}
}
