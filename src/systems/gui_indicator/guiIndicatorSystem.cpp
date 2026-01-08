#include "guiIndicatorSystem.hpp"

#include "../../util/common_headers.hpp"

#include "../../components/components.hpp"

#include <vector>


namespace ui_indicators {

    auto update(entt::registry& registry, const float dt) -> void {
        std::vector<entt::entity> entitiesToDestroy{};
        auto view = registry.view<NinePatchComponent>();
        for (auto entity : view) {
            auto &nPatchComp = view.get<NinePatchComponent>(entity);
            nPatchComp.timeAlive += dt;
            if (nPatchComp.timeAlive > nPatchComp.timeToLive) {
                entitiesToDestroy.push_back(entity);
            }
            if (nPatchComp.blinkEnabled) {
                nPatchComp.blinkTimer += dt;
                if (nPatchComp.blinkTimer >= nPatchComp.blinkInterval) {
                    nPatchComp.isVisible = !nPatchComp.isVisible;
                    nPatchComp.blinkTimer = 0.0f;
                }
            }
        }
        for (auto entity : entitiesToDestroy) {
            registry.remove<NinePatchComponent>(entity);
        }
    }

    auto draw(entt::registry& registry) -> void {
        auto view = registry.view<NinePatchComponent>();
        for (auto entity : view) {
            auto &nPatchComp = view.get<NinePatchComponent>(entity);
            if (nPatchComp.isVisible) {
                DrawTextureNPatch(nPatchComp.texture, nPatchComp.nPatchInfo, nPatchComp.destRect, {0, 0}, 0.0f, WHITE);
            }
        }
    }

    auto update(const float dt) -> void {
        update(globals::getRegistry(), dt);
    }

    auto draw() -> void {
        draw(globals::getRegistry());
    }
}
