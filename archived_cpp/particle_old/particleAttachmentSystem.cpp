


// when a particle attachment component is added to an entity, it gets assigned an emitter
// the emitter location will be updated with the entity's position.
// the emitter will be updated and drawn in the particle system updateAndDraw function
// The emitter lifetime can be reset by calling the reset function
#include "entt/fwd.hpp"
#include "particles.hpp"
#include "../../core/globals.hpp"

#include "particleAttachmentSystem.hpp"


// 
namespace particle_attachment_system {

    /**
     * Updates the particle attachment system.
     * If the entity has a mechanical tile component or a physics body, 
     * the emitter location is updated to match the entity's position.
     * 
     * @param dt The time elapsed since the last update.
     */
    //FIXME: needs to be updated to fit current map system.
    auto update(float dt) -> void {
        auto view = globals::registry.view<component::ParticleAttachmentComponent>();
        for (auto entity : view) {
            auto &comp = view.get<component::ParticleAttachmentComponent>(entity);

            // spdlog::debug("Updating emitter for entity {} with lifetime {}", static_cast<int>(entity), particle_system::getEmitterData(comp.emitterIndex).lifetime);
            
            // is the lifetime over and should it be removed?
            if (comp.removeOnLifetimeEnd && particle_system::getEmitterData(comp.emitterIndex).lifetime <= 0) {
                removeEmitter(globals::registry, entity);
                // spdlog::debug("Removing emitter from entity {} on lifetime end", static_cast<int>(entity));
                continue;
            }

            // update emitter location
            // get location component
            float x{0}, y{0};
            // does it have a tile_system::MechanicalTile component?
            // if (registry.any_of<tile_system::MechanicalTile>(entity)) {
            //     auto &mechanicalTile = registry.get<tile_system::MechanicalTile>(entity);
                
            //     x = (float)mechanicalTile.x;
            //     y = (float)mechanicalTile.y;
            //     float scale = 1.f; //FIXME: scale is placeholder, potentially?
            //     float drawX = static_cast<float>(x * tile_system::TILE_DRAW_SIZE + tile_system::TILE_DRAW_SIZE*scale/2);
            //     float drawY = static_cast<float>(y * tile_system::TILE_DRAW_SIZE + tile_system::TILE_DRAW_SIZE*scale/2);
                
            //     x = drawX;
            //     y = drawY;
            // } else if (registry.any_of<component::PhysicsBody>(entity)) {
            //     auto &physicsBody = registry.get<component::PhysicsBody>(entity);
            //     x = physicsBody.body->GetPosition().x * GameConstants::PhysicsWorldScale;
            //     y = physicsBody.body->GetPosition().y * GameConstants::PhysicsWorldScale;
            // } else {
            //     spdlog::error("Entity with particle attachment component does not have a location component");
            //     return; // no location comp
            // }


            // SPDLOG_DEBUG("Updating emitter location for entity {}", static_cast<int>(entity));
            particle_system::setEmitterLocation(comp.emitterIndex, {static_cast<float>(x), static_cast<float>(y), 0.0f});
        }
    }

    /**
     * Resets the emitter data for the given entity.
     * If the entity does not have a particle attachment component, an error message is logged and the function returns.
     *
     * @param entity The entity for which to reset the emitter data.
     */
    auto resetEmitter(entt::entity entity) -> void {
        
        if (!globals::registry.any_of<component::ParticleAttachmentComponent>(entity)) {
            spdlog::error("Entity does not have a particle attachment component");
            return;
        }

        auto &comp = globals::registry.get<component::ParticleAttachmentComponent>(entity);

        // spdlog::debug("Resetting emitter data for entity {}", static_cast<int>(entity));

        particle_system::setEmitterData(comp.emitterIndex, comp.emitterData); // resets the emitter data
    }

    /**
     * Resets the lifetime of the particle emitter attached to the specified entity.
     * If the entity does not have a particle attachment component, an error message is logged and the function returns.
     *
     * @param entity The entity whose particle emitter lifetime should be reset.
     */
    auto resetEmitterLifetime(entt::entity entity) -> void {
        if (!globals::registry.any_of<component::ParticleAttachmentComponent>(entity)) {
            spdlog::error("Entity does not have a particle attachment component");
            return;
        }

        auto &comp = globals::registry.get<component::ParticleAttachmentComponent>(entity);

        spdlog::debug("Resetting emitter lifetime for entity {} at index {}", static_cast<int>(entity), comp.emitterIndex);
        
        particle_system::setEmitterLifetime(comp.emitterIndex, comp.emitterData.lifetime); // resets the emitter lifetime
    }

    auto resetEmitterEmissionRate(entt::entity entity) -> void {
        #ifndef __EMSCRIPTEN__
        if (!globals::registry.any_of<component::ParticleAttachmentComponent>(entity)) {
            spdlog::error("Entity does not have a particle attachment component");
            return;
        }

        auto &comp = globals::registry.get<component::ParticleAttachmentComponent>(entity);

        // spdlog::debug("Resetting emitter emission rate for entity {}", static_cast<int>(entity));

        particle_system::setEmitterEmissionRate(comp.emitterIndex, comp.emitterData.emissionRate); // resets the emitter emission rate
        #endif
    }

    /**
     * Attaches a particle emitter to the specified entity.
     *
     * @param registry The entity registry.
     * @param entity The entity to which to attach the particle emitter.
     * @param emitter The emitter to attach.
     * @param removeOnLifetimeEnd Whether to remove the emitter component when its lifetime ends.
     */
    auto attachEmitter(entt::registry &registry, entt::entity entity, particle_system::Emitter emitter, bool removeOnLifetimeEnd) -> void{
    
        auto index = particle_system::addEmitter(emitter);

        if (index == -1) {
            spdlog::error("Failed to add emitter to particle system");
            return;
        }

        auto &comp = registry.emplace_or_replace<component::ParticleAttachmentComponent>(entity, emitter);
        comp.emitterIndex = index;
        comp.removeOnLifetimeEnd = removeOnLifetimeEnd;

        // spdlog::debug("Attached emitter to entity {} at index {}", static_cast<int>(entity), index);
    }

    /**
     * Removes the particle emitter attached to the specified entity.
     *
     * @param registry The entity registry.
     * @param entity The entity from which to remove the particle emitter.
     */
    auto removeEmitter(entt::registry &registry, entt::entity entity) -> void {
        

        particle_system::removeEmitter(registry.get<component::ParticleAttachmentComponent>(entity).emitterIndex);

        registry.remove<component::ParticleAttachmentComponent>(entity);
    }

    // adds an emitter without a specific parent entity. This emitter will stay in place only until its lifetime ends.
    auto addFreeEmitter(particle_system::Emitter emitter) -> void {
        particle_system::addEmitter(emitter);
    }
}