#pragma once

#include "raylib.h"

namespace particle_system {

    // Emitter structure
    struct Emitter
    {
        Vector3 position;
        float lifetime{0.3f};
        float particleLifetime{0.5f};
        float emissionRate{100000};
        bool useGravity;
        int textureIndex{1};
        float startSpeed{5};
        float startAcceleration{1.5f};
        Color startColor{GREEN};
        Color endColor{WHITE};
        float startAlpha{1.0f};
        float endAlpha{0.0f};
        bool valid{false};
        float timer;

        // New properties
        float startScale{1.0f};          // Starting scale of particles
        float endScale{5.0f};            // Ending scale of particles
        float emissionAngleMin{0.0f};    // Minimum emission angle in degrees - 0 degrees is right on the X axis
        float emissionAngleMax{360.0f};  // Maximum emission angle in degrees - 0 degrees is right on the X axis
        float rotationSpeedMin{0.0f};    // Minimum rotation speed in degrees 
        float rotationSpeedMax{0.0f};    // Maximum rotation speed in degrees
    };

    struct Particle
    {
        Vector3 position;
        Vector3 velocity;
        Vector3 acceleration; // For gravity or other accelerations
        Color color;          // Particle color
        Color startColor{GREEN};
        Color endColor{WHITE};
        float life;           // Particle life
        float age;            // Current age of the particle
        int textureIndex;     // Index of the texture to use
        float startAlpha;     // Starting alpha
        float endAlpha;       // Ending alpha

        // New properties
        float startScale{1.0f};          // Starting scale of particles
        float endScale{5.0f};            // Ending scale of particles
        float scale{1.f};          // Current scale of the particle
        float rotation{0.f};       // Current rotation angle of the particle
        float rotationSpeed{0.f};  // Speed of rotation
    };

    extern int addEmitter(Emitter newEmitter);
    extern void removeEmitter(int index);
    extern Emitter getEmitterData(int index);
    extern void clearAllEmitters();
    extern void clearAllParticles();
    extern void setEmitterData(int index, Emitter newEmitter);
    extern void setEmitterEmissionRate(int index, float newEmissionRate);
    extern void setEmitterLocation(int index, Vector3 newPosition);
    extern void setEmitterLifetime(int index, float newLifetime);

    extern auto init() -> void;


    extern auto updateAndDraw(float dt) -> void;


    extern auto unload() -> void ;
} // namespace 