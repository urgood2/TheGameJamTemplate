#pragma once

#include "util/common_headers.hpp"
#include "util/utilities.hpp"

#include "systems/transform/transform.hpp"
#include "systems/transform/transform_functions.hpp"
#include "systems/layer/layer_command_buffer.hpp"
#include "systems/factory/factory.hpp"

#include "systems/scripting/binding_recorder.hpp"

#include "core/globals.hpp"
#include "core/init.hpp"

#include <optional>
#include <limits>

namespace particle {

    // Default values for particles
    const float defaultRotation = 0.0f;
    const float defaultRotationSpeed = 0.0f;
    const float defaultScale = 1.0f;
    const float defaultLifespan = 1.0f;
    const float defaultSpeed = 10.0f;

    // Default values for emitters
    const int defaultMaxParticles = 15;
    const float defaultEmissionRate = 0.1f;
    const float defaultParticleLifespan = 1.0f;
    const float defaultParticleSpeed = 10.0f;
    const bool defaultFillArea = false;
    const std::vector<Color> defaultColors = {WHITE, GRAY, LIGHTGRAY};

    enum class ParticleRenderType {
        TEXTURE,
        RECTANGLE,
        CIRCLE
    };

    struct Particle {
        ParticleRenderType renderType = ParticleRenderType::RECTANGLE;
        std::optional<Vector2> velocity;
        std::optional<float> rotation;
        std::optional<float> rotationSpeed;
        std::optional<float> scale;
        std::optional<float> lifespan;
        std::optional<float> age = 0.0f;
        std::optional<Color> color;
        std::optional<float> gravity = 0.0f; // New: Gravity effect on particle
        std::optional<float> acceleration = 0.0f; // New: Acceleration over time
        std::optional<Color> startColor; // New: Initial color of the particle
        std::optional<Color> endColor; // New: Final color of the particle

        //TODO: just use animation comp for animations, make it loop only once
    };

    struct ParticleEmitter {
        Vector2 size;
        float emissionRate = 0.1f;
        float lastEmitTime = 0.0f;
        float particleLifespan = 1.0f;
        float particleSpeed = 1.0f;
        // int maxParticles = 100;
        bool fillArea = false;
        bool oneShot = false;
        float oneShotParticleCount = 10.f;
        bool prewarm = false;
        float prewarmParticleCount = 10.f;
        bool useGlobalCoords = false;
        float speedScale = 1.0f;
        float explosiveness = 0.0f;
        float randomness = 0.1f;
        float emissionSpread = 0.0f; // New: Controls angular spread of emitted particles
        float gravityStrength = 0.0f; // New: Strength of gravity applied to particles
        Vector2 emissionDirection = {0, -1}; // New: Base direction of emitted particles (default upward)
        float acceleration = 0.0f; // New: Acceleration applied to particles
        BlendMode blendMode = BLEND_ALPHA;
        std::vector<Color> colors = {WHITE, GRAY, LIGHTGRAY};
    };

    struct ParticleAnimationConfig {
        bool loop = false;
        std::string animationName{};
    };
    

    inline entt::entity CreateParticle(entt::registry& registry, Vector2 location, Vector2 size, Particle particleData, std::optional<ParticleAnimationConfig> animationConfig = std::nullopt) {
        auto particle = transform::CreateOrEmplace(&globals::registry, globals::gameWorldContainerEntity, location.x, location.y, 0, 0);
        auto& transform = registry.get<transform::Transform>(particle);

        transform.setActualW(size.x);
        transform.setActualH(size.y);

        auto& particleComp = registry.emplace<Particle>(particle);
        particleComp.velocity = particleData.velocity.value_or(Vector2(
            Random::get<float>(-defaultSpeed, defaultSpeed), 
            Random::get<float>(-defaultSpeed, defaultSpeed)
        ));
        particleComp.rotation = particleData.rotation.value_or(defaultRotation);
        particleComp.rotationSpeed = particleData.rotationSpeed.value_or(defaultRotationSpeed);
        particleComp.scale = particleData.scale.value_or(defaultScale);
        particleComp.lifespan = particleData.lifespan.value_or(defaultLifespan);
        particleComp.color = particleData.color.value_or(WHITE);

        if (animationConfig) {
            auto &anim = factory::emplaceAnimationQueue(globals::registry, particle);
            // anim.defaultAnimation = loading::getAnimationObject(animationConfig->animationName);
            
            anim.defaultAnimation = init::getAnimationObject(animationConfig->animationName);
            if (animationConfig->loop == false) {
                // no loop, add to queue and set up callback to remove entity
                anim.animationQueue.push_back(init::getAnimationObject(animationConfig->animationName));
                anim.onAnimationQueueCompleteCallback = [particle]() {
                    SPDLOG_DEBUG("Removing particle entity");
                    transform::RemoveEntity(&globals::registry, particle);
                };
                anim.useCallbackOnAnimationQueueComplete = true;
            }
            // override size
            transform.setActualW(anim.defaultAnimation.animationList[0].first.spriteFrame->frame.width);
            transform.setActualH(anim.defaultAnimation.animationList[0].first.spriteFrame->frame.height);
        }

        return particle;
    }

    inline void EmitParticleHelper(entt::entity emitterEntity, entt::registry &registry);

    inline void EmitParticles(entt::registry &registry, entt::entity emitterEntity, float deltaTime)
    {
        auto& emitter = registry.get<ParticleEmitter>(emitterEntity);

        // Modify emission timing using randomness
        float randomFactor = 1.0f + (emitter.randomness * ((GetRandomValue(-100, 100) / 100.0f))); 
        emitter.lastEmitTime += deltaTime * emitter.speedScale * randomFactor;

        // If the emitter is a one-shot, emit all particles at once and stop emitting
        if (emitter.oneShot) {  
            if (emitter.lastEmitTime <= 0.0f) {
                for (int i = 0; i < emitter.oneShotParticleCount; i++) {
                    EmitParticleHelper(emitterEntity, registry);
                }
                emitter.lastEmitTime = std::numeric_limits<float>::max(); // Prevent further emissions
            }
            return;
        }

        // Determine how many particles to emit based on explosiveness
        int particlesToEmit = 1;
        if (emitter.explosiveness > 0.0f) {
            particlesToEmit = static_cast<int>(ceil(emitter.explosiveness * emitter.emissionRate * 10));
        }

        for (int i = 0; i < particlesToEmit; i++) {
            EmitParticleHelper(emitterEntity, registry);
        }
    }

    void EmitParticleHelper(entt::entity emitterEntity, entt::registry &registry)
    {
        // Vector2 spawnPosition = emitter.useGlobalCoords ? Vector2{0, 0} : emitter.size;
        // TODO: offfset
        auto &emitterTransform = registry.get<transform::Transform>(emitterEntity);
        auto &emitter = registry.get<ParticleEmitter>(emitterEntity);

        Vector2 spawnPosition = Vector2{emitterTransform.getActualX(), emitterTransform.getActualY()};

        if (emitter.fillArea)
        {
            spawnPosition.x += (GetRandomValue(0, 100) / 100.0f) * emitter.size.x - emitter.size.x / 2;
            spawnPosition.y += (GetRandomValue(0, 100) / 100.0f) * emitter.size.y - emitter.size.y / 2;
        }

        // Adjust emission angle based on spread
        float baseAngle = GetRandomValue(0, 360); // Default full-range emission
        float angleOffset = (GetRandomValue(-100, 100) / 100.0f) * (emitter.emissionSpread * 180.0f);
        float emissionAngle = baseAngle + angleOffset;

        Particle p{};
        p.velocity = Vector2(
            cos(emissionAngle * DEG2RAD) * emitter.particleSpeed,
            sin(emissionAngle * DEG2RAD) * emitter.particleSpeed);
        p.rotation = GetRandomValue(0, 360);
        p.rotationSpeed = GetRandomValue(-10, 10) / 10.0f * 0.2f;
        p.scale = GetRandomValue(1, 5) / 10.0f * 2.0f;
        p.lifespan = emitter.particleLifespan;
        p.color = emitter.colors[GetRandomValue(0, emitter.colors.size() - 1)];
        p.gravity = emitter.gravityStrength; // Assign emitter gravity to particle
        p.acceleration = emitter.acceleration; // Assign acceleration
        p.startColor = emitter.colors[GetRandomValue(0, emitter.colors.size() - 1)];
        p.endColor = emitter.colors[GetRandomValue(0, emitter.colors.size() - 1)]; // Random transition color
        p.color = p.startColor; // Start at initial color

        CreateParticle(registry, spawnPosition, Vector2{10, 10}, p);
    }

    inline void CreateParticleEmitter(entt::registry& registry, Vector2 location, ParticleEmitter emitterData) {
        auto emitterEntity = transform::CreateOrEmplace(&registry, globals::gameWorldContainerEntity, location.x, location.y, 0, 0);
        
        auto& emitter = registry.emplace<ParticleEmitter>(emitterEntity);

        emitter = emitterData;

        if (emitter.prewarm) {
            for (int i = 0; i < emitter.prewarmParticleCount; i++) {
                EmitParticles(registry, emitterEntity, emitter.particleLifespan);
            }
        }

        //TODO: emitter attachment using tranform:: role
    }

    inline void UpdateParticles(entt::registry &registry, float deltaTime)
    {
        ZoneScopedN("UpdateParticles"); // custom label
        auto view = registry.view<Particle>();
        for (auto entity : view)
        {
            auto &particle = view.get<Particle>(entity);
            auto &transform = registry.get<transform::Transform>(entity);
            particle.age = particle.age.value() + deltaTime;

            if (particle.age.value() >= particle.lifespan.value())
            {
                transform::RemoveEntity(&registry, entity);
                continue;
            }

            // Apply acceleration to velocity over time
            if (particle.acceleration.value() != 0.0f)
            {
                float speedIncrease = particle.acceleration.value() * deltaTime;
                float velocityAngle = atan2(particle.velocity->y, particle.velocity->x);
                particle.velocity->x += cos(velocityAngle) * speedIncrease;
                particle.velocity->y += sin(velocityAngle) * speedIncrease;
            }

            // Apply gravity to velocity
            if (particle.gravity.value() != 0.0f)
            {
                particle.velocity->y += particle.gravity.value() * deltaTime;
            }

            transform.setActualX(transform.getActualX() + particle.velocity->x * deltaTime);
            transform.setActualY(transform.getActualY() + particle.velocity->y * deltaTime);
            transform.setActualRotation(transform.getActualRotation() + particle.rotationSpeed.value() * deltaTime);

            float lifeProgress = particle.age.value() / particle.lifespan.value();
            transform.setActualScale(particle.scale.value() * (1.0f - lifeProgress));

            // Apply color transition based on lifespan
            if (particle.startColor.has_value() && particle.endColor.has_value())
            {
                Color start = particle.startColor.value();
                Color end = particle.endColor.value();

                particle.color = Color{
                    (unsigned char)(start.r + (end.r - start.r) * lifeProgress),
                    (unsigned char)(start.g + (end.g - start.g) * lifeProgress),
                    (unsigned char)(start.b + (end.b - start.b) * lifeProgress),
                    (unsigned char)(start.a + (end.a - start.a) * lifeProgress)};
            }
        }
    }


    inline void DrawParticles(entt::registry& registry, std::shared_ptr<layer::Layer> layerPtr) {
        auto view = registry.view<Particle>();

        for (auto entity : view) {
            auto& particle = view.get<Particle>(entity);
            auto& transform = registry.get<transform::Transform>(entity);

            //TODO: blending mode

            float alpha = 255 * (1.0f - (particle.age.value() / particle.lifespan.value()));
            Color drawColor = particle.color.value();
            drawColor.a = (unsigned char)alpha;
            
            layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](layer::CmdPushMatrix *cmd) {});
            
            layer::QueueCommand<layer::CmdTranslate>(layerPtr, [x = transform.getVisualX() + transform.getVisualW() * 0.5, y = transform.getVisualY() + transform.getVisualH() * 0.5](layer::CmdTranslate *cmd) {
                cmd->x = x;
                cmd->y = y;
            });

            layer::QueueCommand<layer::CmdScale>(layerPtr, [scaleX = transform.getVisualScaleWithHoverAndDynamicMotionReflected(), scaleY = transform.getVisualScaleWithHoverAndDynamicMotionReflected()](layer::CmdScale *cmd) {
                cmd->scaleX = scaleX;
                cmd->scaleY = scaleY;
            });

            layer::QueueCommand<layer::CmdRotate>(layerPtr, [rotation = transform.getVisualR() + transform.rotationOffset](layer::CmdRotate *cmd) {
                cmd->angle = rotation;
            });

            layer::QueueCommand<layer::CmdTranslate>(layerPtr, [x = -transform.getVisualW() * 0.5, y = -transform.getVisualH() * 0.5](layer::CmdTranslate *cmd) {
                cmd->x = x;
                cmd->y = y;
            });

            // does it have animation?
            if (registry.any_of<AnimationQueueComponent>(entity)) {
                layer::QueueCommand<layer::CmdDrawEntityAnimation>(layerPtr, [entity = entity](layer::CmdDrawEntityAnimation *cmd) {
                    cmd->e = entity;
                    cmd->registry = &globals::registry;
                    cmd->x = 0;
                    cmd->y = 0;
                }, 0);
            } else {
                // just draw rect
                layer::QueueCommand<layer::CmdDrawRectangle>(layerPtr, [width = transform.getVisualW(), height = transform.getVisualH(), color = drawColor](layer::CmdDrawRectangle *cmd) {
                    cmd->x = 0;
                    cmd->y = 0;
                    cmd->width = width;
                    cmd->height = height;
                    cmd->color = color;
                }, 0);
            }

            layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](layer::CmdPopMatrix *cmd) {});
        }
    }

    inline void exposeToLua(sol::state &lua) {

        auto& rec = BindingRecorder::instance();
        auto particlePath = std::vector<std::string>{ "particle" };

        // 1) particle table
        sol::table p = lua["particle"].get_or_create<sol::table>();
        if (!p.valid()) {
            p = lua.create_table();
            lua["particle"] = p;
        }

        rec.add_type("particle");

        // 2) ParticleRenderType enum
        p["ParticleRenderType"] = lua.create_table_with(
            "TEXTURE",   particle::ParticleRenderType::TEXTURE,
            "RECTANGLE", particle::ParticleRenderType::RECTANGLE,
            "CIRCLE",    particle::ParticleRenderType::CIRCLE
        );

        // 2b) Record enum as class with fields
        auto& renderTypeDef = rec.add_type("particle.ParticleRenderType");
        renderTypeDef.doc = "How particles should be rendered";
        rec.record_property("particle.ParticleRenderType", { "TEXTURE",   std::to_string(static_cast<int>(particle::ParticleRenderType::TEXTURE)),   "Use a sprite texture" });
        rec.record_property("particle.ParticleRenderType", { "RECTANGLE", std::to_string(static_cast<int>(particle::ParticleRenderType::RECTANGLE)), "Draw as a rectangle" });
        rec.record_property("particle.ParticleRenderType", { "CIRCLE",    std::to_string(static_cast<int>(particle::ParticleRenderType::CIRCLE)),    "Draw as a circle" });

        // 3) Particle usertype
        p.new_usertype<particle::Particle>("Particle",
            sol::constructors<>(),
            "renderType",    &particle::Particle::renderType,
            "velocity",      &particle::Particle::velocity,
            "rotation",      &particle::Particle::rotation,
            "rotationSpeed", &particle::Particle::rotationSpeed,
            "scale",         &particle::Particle::scale,
            "lifespan",      &particle::Particle::lifespan,
            "age",           &particle::Particle::age,
            "color",         &particle::Particle::color,
            "gravity",       &particle::Particle::gravity,
            "acceleration",  &particle::Particle::acceleration,
            "startColor",    &particle::Particle::startColor,
            "endColor",      &particle::Particle::endColor,
            "type_id", []() { return entt::type_hash<particle::Particle>::value(); }
        );
        rec.bind_usertype<particle::Particle>(lua, "particle.Particle", "0.1", "Single particle instance");
        // Let's create a data class definition for Particle so Lua users get good tooltips
        rec.record_property("particle.Particle", {"renderType",    "nil", "particle.ParticleRenderType: How the particle is drawn."});
        rec.record_property("particle.Particle", {"velocity",      "nil", "Vector2?: The particle's current velocity."});
        rec.record_property("particle.Particle", {"rotation",      "nil", "number?: The particle's current rotation in degrees."});
        rec.record_property("particle.Particle", {"rotationSpeed", "nil", "number?: How fast the particle rotates."});
        rec.record_property("particle.Particle", {"scale",         "nil", "number?: The particle's current scale."});
        rec.record_property("particle.Particle", {"lifespan",      "nil", "number?: How long the particle exists in seconds."});
        rec.record_property("particle.Particle", {"age",           "nil", "number?: The current age of the particle in seconds."});
        rec.record_property("particle.Particle", {"color",         "nil", "Color?: The current color of the particle."});
        rec.record_property("particle.Particle", {"gravity",       "nil", "number?: Gravity strength applied to the particle."});
        rec.record_property("particle.Particle", {"acceleration",  "nil", "number?: Acceleration applied over the particle's lifetime."});
        rec.record_property("particle.Particle", {"startColor",    "nil", "Color?: The color the particle starts with."});
        rec.record_property("particle.Particle", {"endColor",      "nil", "Color?: The color the particle fades to over its life."});




        // 4) ParticleEmitter usertype
        p.new_usertype<particle::ParticleEmitter>("ParticleEmitter",
            sol::constructors<>(),
            "size",                  &particle::ParticleEmitter::size,
            "emissionRate",          &particle::ParticleEmitter::emissionRate,
            "lastEmitTime",          &particle::ParticleEmitter::lastEmitTime,
            "particleLifespan",      &particle::ParticleEmitter::particleLifespan,
            "particleSpeed",         &particle::ParticleEmitter::particleSpeed,
            "fillArea",              &particle::ParticleEmitter::fillArea,
            "oneShot",               &particle::ParticleEmitter::oneShot,
            "oneShotParticleCount",  &particle::ParticleEmitter::oneShotParticleCount,
            "prewarm",               &particle::ParticleEmitter::prewarm,
            "prewarmParticleCount",  &particle::ParticleEmitter::prewarmParticleCount,
            "useGlobalCoords",       &particle::ParticleEmitter::useGlobalCoords,
            "speedScale",            &particle::ParticleEmitter::speedScale,
            "explosiveness",         &particle::ParticleEmitter::explosiveness,
            "randomness",            &particle::ParticleEmitter::randomness,
            "emissionSpread",        &particle::ParticleEmitter::emissionSpread,
            "gravityStrength",       &particle::ParticleEmitter::gravityStrength,
            "emissionDirection",     &particle::ParticleEmitter::emissionDirection,
            "acceleration",          &particle::ParticleEmitter::acceleration,
            "blendMode",             &particle::ParticleEmitter::blendMode,
            "colors",                &particle::ParticleEmitter::colors,
            "type_id", []() { return entt::type_hash<particle::ParticleEmitter>::value(); }
        );
        rec.bind_usertype<particle::ParticleEmitter>(lua, "particle.ParticleEmitter", "0.1", "Defines how particles are emitted");
        // Create a data class definition for ParticleEmitter
        rec.record_property("particle.ParticleEmitter", {"size",                 "nil", "Vector2: The size of the emission area."});
        rec.record_property("particle.ParticleEmitter", {"emissionRate",         "nil", "number: Time in seconds between emissions."});
        rec.record_property("particle.ParticleEmitter", {"particleLifespan",     "nil", "number: How long each particle lives."});
        rec.record_property("particle.ParticleEmitter", {"particleSpeed",        "nil", "number: Initial speed of emitted particles."});
        rec.record_property("particle.ParticleEmitter", {"fillArea",             "nil", "boolean: If true, emit from anywhere within the size rect."});
        rec.record_property("particle.ParticleEmitter", {"oneShot",              "nil", "boolean: If true, emits a burst of particles once."});
        rec.record_property("particle.ParticleEmitter", {"oneShotParticleCount", "nil", "number: Number of particles for a one-shot burst."});
        rec.record_property("particle.ParticleEmitter", {"prewarm",              "nil", "boolean: If true, simulates the system on creation."});
        rec.record_property("particle.ParticleEmitter", {"prewarmParticleCount", "nil", "number: Number of particles for prewarming."});
        rec.record_property("particle.ParticleEmitter", {"useGlobalCoords",      "nil", "boolean: If true, particles operate in world space."});
        rec.record_property("particle.ParticleEmitter", {"emissionSpread",       "nil", "number: Angular spread of particle emissions in degrees."});
        rec.record_property("particle.ParticleEmitter", {"gravityStrength",      "nil", "number: Gravity applied to emitted particles."});
        rec.record_property("particle.ParticleEmitter", {"emissionDirection",    "nil", "Vector2: Base direction for particle emission."});
        rec.record_property("particle.ParticleEmitter", {"acceleration",         "nil", "number: Acceleration applied to particles."});
        rec.record_property("particle.ParticleEmitter", {"blendMode",            "nil", "BlendMode: The blend mode for rendering particles."});
        rec.record_property("particle.ParticleEmitter", {"colors",               "nil", "Color[]: A table of possible colors for particles."});




        // 5) ParticleAnimationConfig
        p.new_usertype<particle::ParticleAnimationConfig>("ParticleAnimationConfig",
            sol::constructors<>(),
            "loop",          &particle::ParticleAnimationConfig::loop,
            "animationName", &particle::ParticleAnimationConfig::animationName,
            "type_id", []() { return entt::type_hash<particle::ParticleAnimationConfig>::value(); }
        );
        rec.bind_usertype<particle::ParticleAnimationConfig>(lua, "particle.ParticleAnimationConfig", "0.1", "Configuration for animated particle appearance");
        rec.record_property("particle.ParticleAnimationConfig", {"loop", "boolean", "Whether the particle's animation should loop."});
        rec.record_property("particle.ParticleAnimationConfig", {"animationName", "string", "The name of the animation to play."});


        // 6) Free functions
        rec.bind_function(
            lua,
            particlePath,
            "CreateParticle",
            &particle::CreateParticle, // Note: This likely wraps a different C++ function than the header's CreateParticle.
            "---@param entity Entity # The entity to attach the particle system to.\n"
            "---@param emitter ParticleEmitter # A pre-configured particle emitter data object.\n"
            "---@return nil",
            "Creates and attaches a particle system to an entity using an emitter's properties."
        );

        rec.bind_function(
            lua,
            particlePath,
            "EmitParticles", // Note: This is a burst emission, unlike the C++ version.
            &particle::EmitParticles,
            "---@param emitterEntity Entity # The entity that has the particle emitter component.\n"
            "---@param count integer # The number of particles to emit in a single burst.\n"
            "---@return nil",
            "Emits a burst of particles from the specified emitter entity."
        );

        rec.bind_function(
            lua,
            particlePath,
            "CreateParticleEmitter",
            &particle::CreateParticleEmitter,
            "---@return ParticleEmitter # A new ParticleEmitter data object.",
            "Creates and returns a new ParticleEmitter data object with default values."
        );

        rec.bind_function(
            lua,
            particlePath,
            "UpdateParticles",
            &particle::UpdateParticles,
            "---@param dt number # The delta time since the last frame.\n"
            "---@return nil",
            "Updates all active particle systems."
        );

        rec.bind_function(
            lua,
            particlePath,
            "DrawParticles",
            &particle::DrawParticles,
            "---@param layerPtr Layer # The layer to draw the particles on.\n"
            "---@return nil",
            "Draws all active particles."
        );

    }
}
