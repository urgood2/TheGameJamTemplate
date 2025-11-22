#include <optional>
#include <variant>
#include <string>
#include <functional>

#include "systems/main_loop_enhancement/main_loop.hpp"
#include "third_party/rlImGui/imgui.h"
#include "systems/transform/transform.hpp"
#include "systems/transform/transform_functions.hpp"
#include "systems/physics/physics_components.hpp"
#include "systems/physics/transform_physics_hook.hpp"
#include "systems/physics/physics_manager.hpp"
#include "systems/ui/element.hpp"
#include "systems/ui/box.hpp"
#include "systems/timer/timer.hpp"
#include "third_party/navmesh/source/path_finder.h"

#undef SPDLOG_ACTIVE_LEVEL

// Minimal definitions to satisfy globals when linking tests.
namespace main_loop {
    Data mainLoop{};

    void initMainLoopData(std::optional<int>, std::optional<int>) {}
} // namespace main_loop

// Stub out minimal ImGui functions referenced by utilities during tests.
namespace ImGui {
    void Image(void*, const ImVec2&, const ImVec2&, const ImVec2&, const ImVec4&, const ImVec4&) {}
    void MemFree(void*) {}
} // namespace ImGui

// Stub out UI traversal/interaction hooks used by input_functions.
namespace ui {
namespace box {
    void TraverseUITreeBottomUp(entt::registry&, entt::entity, std::function<void(entt::entity)>, bool) {}
}
namespace element {
    void ApplyHover(entt::registry&, entt::entity) {}
    void Click(entt::registry&, entt::entity) {}
    void Release(entt::registry&, entt::entity, entt::entity) {}
    void StopHover(entt::registry&, entt::entity) {}
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
