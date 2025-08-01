#pragma once

#include "entt/fwd.hpp"
#include "particles.hpp"

namespace component {
    struct ParticleAttachmentComponent {
        particle_system::Emitter emitterData; // this is not the actual data stored in particle system, only a copy
        int emitterIndex{-1}; // index of emitter in particle system
        bool removeOnLifetimeEnd{false}; // remove the emitter when its lifetime ends
    };

}

namespace particle_attachment_system {
    
    extern auto update(float dt) -> void;

    extern auto resetEmitterLifetime(entt::entity entity) -> void;
    extern auto resetEmitter(entt::entity entity) -> void; 
    extern auto resetEmitterEmissionRate(entt::entity entity) -> void;
    extern auto attachEmitter(entt::registry &registry, entt::entity entity, particle_system::Emitter emitter, bool removeOnLifetimeEnd) -> void;
    extern auto removeEmitter(entt::registry &registry, entt::entity entity) -> void;
    extern auto addFreeEmitter(particle_system::Emitter emitter) -> void;
}