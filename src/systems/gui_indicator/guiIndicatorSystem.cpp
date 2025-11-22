#include "guiIndicatorSystem.hpp"

#include "../../util/common_headers.hpp"

#include "../../components/components.hpp"

#include <vector>


/**
 * @brief Keeps track of NinePatchComponents.
 */
namespace ui_indicators {

    auto update(const float dt) -> void {

        std::vector<entt::entity> entitiesToDestroy{};
        auto& registry = globals::getRegistry();

        // update all indicators
        for (auto entity : registry.view<NinePatchComponent>()) {
            auto &nPatchComp = registry.get<NinePatchComponent>(entity);
            nPatchComp.timeAlive += dt;
            if (nPatchComp.timeAlive > nPatchComp.timeToLive) {
                entitiesToDestroy.push_back(entity);
            }

            // Update blink timer if blinking is enabled
            if (nPatchComp.blinkEnabled) {
                nPatchComp.blinkTimer += dt;
                if (nPatchComp.blinkTimer >= nPatchComp.blinkInterval) {
                    nPatchComp.isVisible = !nPatchComp.isVisible;
                    nPatchComp.blinkTimer = 0.0f;
                }
            }
        }

        // destroy component from entity
        for (auto entity : entitiesToDestroy) {
            registry.remove<NinePatchComponent>(entity);
        }
    }

    auto draw() -> void {
        auto& registry = globals::getRegistry();
        // draw all indicators
        for (auto entity : registry.view<NinePatchComponent>()) {
            auto &nPatchComp = registry.get<NinePatchComponent>(entity);
                if (nPatchComp.isVisible) { // Only draw if the component is visible
                    // SPDLOG_DEBUG("Drawing NinePatchComponent entity {}", static_cast<int>(entity));
                    DrawTextureNPatch(nPatchComp.texture, nPatchComp.nPatchInfo, nPatchComp.destRect, {0, 0}, 0.0f, WHITE);
                }
        }
    }
}
