#pragma once

#include "entt/entity/fwd.hpp"
#include "util/common_headers.hpp"
#include "util/utilities.hpp"

#include "systems/transform/transform.hpp"
#include "systems/transform/transform_functions.hpp"
#include "systems/layer/layer_command_buffer.hpp"
#include "systems/factory/factory.hpp"
#include "systems/main_loop_enhancement/main_loop.hpp"
#include "systems/collision/broad_phase.hpp"
#include "systems/ai/ai_system.hpp"
#include "systems/entity_gamestate_management/entity_gamestate_management.hpp"

#include "systems/scripting/binding_recorder.hpp"

#include "core/globals.hpp"
#include "core/init.hpp"

#include <optional>
#include <limits>

namespace particle
{

    const float defaultRotation = 0.0f;
    const float defaultRotationSpeed = 0.0f;
    const float defaultScale = 1.0f;
    const float defaultLifespan = 1.0f;
    const float defaultSpeed = 10.0f;

    const int defaultMaxParticles = 15;
    const float defaultEmissionRate = 0.1f;
    const float defaultParticleLifespan = 1.0f;
    const float defaultParticleSpeed = 10.0f;
    const bool defaultFillArea = false;
    const std::vector<Color> defaultColors = {WHITE, GRAY, LIGHTGRAY};

    // TODO: expose to lua
    enum class ParticleRenderType
    {
        TEXTURE,
        RECTANGLE_LINE,
        RECTANGLE_FILLED,
        CIRCLE_LINE,
        CIRCLE_FILLED
    };
    
    // tag component lives alongside Particle, only on entities you explicitly tag
    struct ParticleTag {
        std::string name;
    };

    struct Particle
    {
        ParticleRenderType renderType = ParticleRenderType::RECTANGLE_FILLED;

        std::optional<Vector2> velocity;
        std::optional<float> rotation;
        std::optional<float> rotationSpeed;
        std::optional<float> scale;
        std::optional<float> lifespan;
        std::optional<float> age = 0.0f;
        std::optional<Color> color;
        std::optional<float> gravity = 0.0f;
        std::optional<float> acceleration = 0.0f;
        std::optional<Color> startColor;
        std::optional<Color> endColor;
        
        std::function<void(Particle &, float)> onUpdateCallback;
    };

    struct ParticleEmitter
    {
        Vector2 size;
        float emissionRate = 0.1f;
        float lastEmitTime = 0.0f;
        float particleLifespan = 1.0f;
        float particleSpeed = 1.0f;
        bool fillArea = false;
        bool oneShot = false;
        float oneShotParticleCount = 10.f;
        bool prewarm = false;
        float prewarmParticleCount = 10.f;
        bool useGlobalCoords = false;
        float speedScale = 1.0f;
        float explosiveness = 0.0f;
        float randomness = 0.1f;
        float emissionSpread = 0.0f;
        float gravityStrength = 0.0f;
        Vector2 emissionDirection = {0, -1};
        float acceleration = 0.0f;
        BlendMode blendMode = BLEND_ALPHA;
        std::vector<Color> colors = {WHITE, GRAY, LIGHTGRAY};
    };

    struct ParticleAnimationConfig
    {
        bool loop = false;
        std::string animationName{};
    };

    inline entt::entity CreateParticle(entt::registry &registry, Vector2 location, Vector2 size, Particle particleData, std::optional<ParticleAnimationConfig> animationConfig = std::nullopt, const std::string &tag = ""        //<— new parameter
    )
    {
        auto particle = transform::CreateOrEmplace(&globals::registry, globals::gameWorldContainerEntity, location.x, location.y, 0, 0);
        auto &transform = registry.get<transform::Transform>(particle);
        
        // particles are world space entities by default

        transform.setActualW(size.x);
        transform.setActualH(size.y);
        transform.setVisualW(size.x);
        transform.setVisualH(size.y);

        auto &particleComp = registry.emplace<Particle>(particle, particleData);
        if (particleData.velocity && particleData.velocity->x == 0) {
            SPDLOG_DEBUG("Particle velocity is zero");
        }
        particleComp.velocity = particleData.velocity.value_or(Vector2(
            Random::get<float>(-defaultSpeed, defaultSpeed),
            Random::get<float>(-defaultSpeed, defaultSpeed)));
        particleComp.rotation = particleData.rotation.value_or(defaultRotation);
        particleComp.rotationSpeed = particleData.rotationSpeed.value_or(defaultRotationSpeed);
        particleComp.scale = particleData.scale.value_or(defaultScale);
        particleComp.lifespan = particleData.lifespan.value_or(defaultLifespan);
        if (particleComp.lifespan.value() <= 0.0f)
        {
            particleComp.lifespan.reset(); // make it live forever
        }
        particleComp.color = particleData.color.value_or(WHITE);
        particleComp.age = particleData.age.value_or(0.0f);
        particleComp.gravity = particleData.gravity.value_or(0.0f);
        particleComp.acceleration = particleData.acceleration.value_or(0.0f);

        if (animationConfig)
        {
            auto &anim = factory::emplaceAnimationQueue(globals::registry, particle);

            anim.defaultAnimation = init::getAnimationObject(animationConfig->animationName);
            if (animationConfig->loop == false)
            {
                anim.animationQueue.push_back(init::getAnimationObject(animationConfig->animationName));
                anim.onAnimationQueueCompleteCallback = [particle]()
                {
                    SPDLOG_DEBUG("Removing particle entity");
                    transform::RemoveEntity(&globals::registry, particle);
                };
                anim.useCallbackOnAnimationQueueComplete = true;
            }
            transform.setActualW(anim.defaultAnimation.animationList[0].first.spriteFrame->frame.width);
            transform.setActualH(anim.defaultAnimation.animationList[0].first.spriteFrame->frame.height);
        }
        
        // if the user provided a non-empty tag, attach the tag component
        if (!tag.empty()) {
            registry.emplace<ParticleTag>(particle, tag);
        }

        return particle;
    }

    inline void EmitParticleHelper(entt::entity emitterEntity, entt::registry &registry);

    inline void EmitParticles(entt::registry &registry, entt::entity emitterEntity, float deltaTime)
    {
        auto &emitter = registry.get<ParticleEmitter>(emitterEntity);

        float randomFactor = 1.0f + (emitter.randomness * ((GetRandomValue(-100, 100) / 100.0f)));
        emitter.lastEmitTime += deltaTime * emitter.speedScale * randomFactor;

        if (emitter.oneShot)
        {
            if (emitter.lastEmitTime <= 0.0f)
            {
                for (int i = 0; i < emitter.oneShotParticleCount; i++)
                {
                    EmitParticleHelper(emitterEntity, registry);
                }
                emitter.lastEmitTime = std::numeric_limits<float>::max();
            }
            return;
        }

        int particlesToEmit = 1;
        if (emitter.explosiveness > 0.0f)
        {
            particlesToEmit = static_cast<int>(ceil(emitter.explosiveness * emitter.emissionRate * 10));
        }

        for (int i = 0; i < particlesToEmit; i++)
        {
            EmitParticleHelper(emitterEntity, registry);
        }
    }

    void EmitParticleHelper(entt::entity emitterEntity, entt::registry &registry)
    {
        auto &emitterTransform = registry.get<transform::Transform>(emitterEntity);
        auto &emitter = registry.get<ParticleEmitter>(emitterEntity);

        Vector2 spawnPosition = Vector2{emitterTransform.getActualX(), emitterTransform.getActualY()};

        if (emitter.fillArea)
        {
            spawnPosition.x += (GetRandomValue(0, 100) / 100.0f) * emitter.size.x - emitter.size.x / 2;
            spawnPosition.y += (GetRandomValue(0, 100) / 100.0f) * emitter.size.y - emitter.size.y / 2;
        }

        float baseAngle = GetRandomValue(0, 360);
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
        p.gravity = emitter.gravityStrength;
        p.acceleration = emitter.acceleration;
        p.startColor = emitter.colors[GetRandomValue(0, emitter.colors.size() - 1)];
        p.endColor = emitter.colors[GetRandomValue(0, emitter.colors.size() - 1)];
        p.color = p.startColor;

        CreateParticle(registry, spawnPosition, Vector2{10, 10}, p);
    }

    inline entt::entity CreateParticleEmitter(entt::registry &registry, Vector2 location, ParticleEmitter emitterData) 
    {
        auto emitterEntity = transform::CreateOrEmplace(&registry, globals::gameWorldContainerEntity, location.x, location.y, 0, 0);

        auto &emitter = registry.emplace<ParticleEmitter>(emitterEntity);

        emitter = emitterData;

        if (emitter.prewarm)
        {
            for (int i = 0; i < emitter.prewarmParticleCount; i++)
            {
                EmitParticles(registry, emitterEntity, emitter.particleLifespan);
            }
        }
        
        auto &transform = registry.get<transform::Transform>(emitterEntity);
        transform.setActualX(location.x);
        transform.setActualY(location.y);
        
        return emitterEntity;
    }

    inline void UpdateParticles(entt::registry &registry, float deltaTime)
    {
        auto view = registry.view<Particle, entity_gamestate_management::StateTag>();
        for (auto entity : view)
        {
            auto &stateTag = view.get<entity_gamestate_management::StateTag>(entity);
            if (!entity_gamestate_management::isActiveState(stateTag)) continue; // skip inactive particles
            
            auto &particle = view.get<Particle>(entity);
            auto &transform = registry.get<transform::Transform>(entity);
            particle.age = particle.age.value() + deltaTime;
     
            if (particle.lifespan && particle.age.value() >= particle.lifespan.value())
            {
                transform::RemoveEntity(&registry, entity);
                continue;
            }

            if (particle.acceleration.value() != 0.0f)
            {
                float speedIncrease = particle.acceleration.value() * deltaTime;
                float velocityAngle = atan2(particle.velocity->y, particle.velocity->x);
                particle.velocity->x += cos(velocityAngle) * speedIncrease;
                particle.velocity->y += sin(velocityAngle) * speedIncrease;
            }

            if (particle.gravity.value() != 0.0f)
            {
                particle.velocity->y += particle.gravity.value() * deltaTime;
            }

            transform.setActualX(transform.getActualX() + particle.velocity->x * deltaTime);
            transform.setVisualX(transform.getVisualX());
            transform.setActualY(transform.getActualY() + particle.velocity->y * deltaTime);
            transform.setVisualY(transform.getVisualY());
            transform.setActualRotation(transform.getActualRotation() + particle.rotationSpeed.value() * deltaTime);
            transform.setVisualRotation(transform.getActualRotation());
            
            transform.setActualScale(particle.scale.value());
            transform.setVisualScale(particle.scale.value());
            
            float lifespan = particle.lifespan.value_or(std::numeric_limits<float>::max());

            float lifeProgress = particle.age.value() / lifespan;
            // transform.setActualScale(particle.scale.value() * (1.0f - lifeProgress));
            // transform.setActualScale(particle.scale.value());
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
            
            if (particle.onUpdateCallback)
            {
                particle.onUpdateCallback(particle, deltaTime);
            }
        }
    }

    inline void DrawParticles(entt::registry &registry, std::shared_ptr<layer::Layer> layerPtr)
    {
        auto view = registry.view<Particle>();

        for (auto entity : view)
        {
            auto &particle = view.get<Particle>(entity);
            auto &transform = registry.get<transform::Transform>(entity);
            auto &gameObject = registry.get<transform::GameObject>(entity);
            auto drawCommandSpace = registry.any_of<collision::ScreenSpaceCollisionMarker>(entity)
                                        ? layer::DrawCommandSpace::Screen
                                        : layer::DrawCommandSpace::World;
            bool shadowEnabled = false;
            float shadowDisplacementX{}, shadowDisplacementY{};
            // half-alpha black

            if (gameObject.shadowDisplacement)
            {
                float baseExaggeration = globals::BASE_SHADOW_EXAGGERATION;
                float heightFactor = 1.0f + gameObject.shadowHeight.value_or(0.f); // Increase effect based on height
                
                shadowDisplacementX = gameObject.shadowDisplacement->x * baseExaggeration * heightFactor;
                shadowDisplacementY = gameObject.shadowDisplacement->y * baseExaggeration * heightFactor;
                shadowEnabled = true;
            }

            // float alpha = 255 * (1.0f - (particle.age.value() / particle.lifespan.value()));
            //FIXME: removing alpha for now
            float alpha = 255.f;
            Color drawColor = particle.color.value();
            drawColor.a = (unsigned char)alpha;

            Color shadowColor = {0, 0, 0, static_cast<unsigned char>(alpha * 1.0f)};
            
            static const float CIRCLE_LINE_WIDTH = 3.0f;
            float visualX = transform.getVisualX();
            float visualY = transform.getVisualY();
            float visualW = transform.getVisualW();
            float visualH = transform.getVisualH();
            float visualR = transform.getVisualRWithDynamicMotionAndXLeaning(); // Or getActualRotation() to fix swerving
            float visualScale = transform.getVisualScaleWithHoverAndDynamicMotionReflected();

            // --- 1. DRAW SHADOW PASS ---
            if (gameObject.shadowDisplacement)
            {
                float baseExaggeration = globals::BASE_SHADOW_EXAGGERATION;
                float heightFactor = 1.0f + gameObject.shadowHeight.value_or(0.f);
                float shadowDisplacementX = gameObject.shadowDisplacement->x * baseExaggeration * heightFactor;
                float shadowDisplacementY = gameObject.shadowDisplacement->y * baseExaggeration * heightFactor;
                Color shadowColor = {0, 0, 0, 128}; // Half-alpha black

                // Set up the entire transform for the shadow
                layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](auto *cmd) {}, 0, drawCommandSpace);

                // Move to the SHADOW's position FIRST
                layer::QueueCommand<layer::CmdTranslate>(layerPtr, [x = visualX + visualW * 0.5 - shadowDisplacementX, y = visualY + visualH * 0.5 + shadowDisplacementY](auto *cmd) {
                    cmd->x = x;
                    cmd->y = y;
                }, 0, drawCommandSpace);
                
                // Then rotate and scale around the shadow's pivot
                layer::QueueCommand<layer::CmdScale>(layerPtr, [visualScale](auto *cmd) {
                    cmd->scaleX = visualScale;
                    cmd->scaleY = visualScale;
                }, 0, drawCommandSpace);
                layer::QueueCommand<layer::CmdRotate>(layerPtr, [visualR](auto *cmd) {
                    cmd->angle = visualR;
                }, 0, drawCommandSpace);
                
                // Offset by pivot for drawing
                layer::QueueCommand<layer::CmdTranslate>(layerPtr, [w = -visualW * 0.5, h = -visualH * 0.5](auto *cmd) {
                    cmd->x = w;
                    cmd->y = h;
                }, 0, drawCommandSpace);
                
                switch (particle.renderType)
                {
                case ParticleRenderType::RECTANGLE_FILLED:
                    layer::QueueCommand<layer::CmdDrawRectanglePro>(layerPtr, [shadowDisplacementX, shadowDisplacementY, width = transform.getVisualW(), height = transform.getVisualH(), shadowColor](auto *cmd)
                                                                 {
                            cmd->offsetX      = 0;
                            cmd->offsetY      = 0;
                            cmd->size.x  = width;
                            cmd->size.y = height;
                            cmd->color  = shadowColor; 
                        }, 0, drawCommandSpace);
                    break;
                    
                case ParticleRenderType::RECTANGLE_LINE:
                    layer::QueueCommand<layer::CmdDrawRectangleLinesPro>(layerPtr, [shadowDisplacementX, shadowDisplacementY, width = transform.getVisualW(), height = transform.getVisualH(), shadowColor](auto *cmd)
                                                                      {
                            cmd->offsetX      = 0;
                            cmd->offsetY      = 0;
                            cmd->size.x  = width;
                            cmd->size.y = height;
                            cmd->color  = shadowColor; 
                            cmd->lineThickness = CIRCLE_LINE_WIDTH;  // Set line thickness for rectangle line shadow
                        }, 0, drawCommandSpace);
                    break;
                case ParticleRenderType::CIRCLE_FILLED:
                    layer::QueueCommand<layer::CmdDrawCircleFilled>(layerPtr, [shadowDisplacementX, shadowDisplacementY, radius = std::max(transform.getVisualW(), transform.getVisualH()), shadowColor](auto *cmd)
                                                              {
                            cmd->x      = radius/2;
                            cmd->y      = radius/2;
                            cmd->radius = radius;
                            cmd->color  = shadowColor; 
                                                                
                        }, 0, drawCommandSpace);
                    break;
                case ParticleRenderType::CIRCLE_LINE:
                    layer::QueueCommand<layer::CmdDrawCircleLine>(layerPtr, [shadowDisplacementX, shadowDisplacementY, radius = std::max(transform.getVisualW(), transform.getVisualH()), shadowColor](auto *cmd)
                                                                   {
                            cmd->x      = radius/2;
                            cmd->y      = radius/2;
                            cmd->innerRadius = radius - CIRCLE_LINE_WIDTH; // Inner radius for line circle
                            cmd->outerRadius = radius;
                            cmd->startAngle = 0.0f; // Start angle in radians
                            cmd->endAngle = 360; // Full circle
                            cmd->segments = 32; // Number of segments for the circle line
                            cmd->color = shadowColor; }, 0, drawCommandSpace);
                    break;
                default:
                    break; // no shadow for TEXTURE or unknown
                }

                layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](auto *cmd) {}, 0, drawCommandSpace);
            }
            
            // precompute once per-particle:
            
            layer::QueueCommand<layer::CmdPushMatrix>(layerPtr, [](layer::CmdPushMatrix *cmd) {}, 0, drawCommandSpace);
            
            layer::QueueCommand<layer::CmdTranslate>(layerPtr, [x = transform.getVisualX() + transform.getVisualW() * 0.5, y = transform.getVisualY() + transform.getVisualH() * 0.5](layer::CmdTranslate *cmd) {
                cmd->x = x;
                cmd->y = y;
            }, 0, drawCommandSpace);

            layer::QueueCommand<layer::CmdScale>(layerPtr, [scaleX = transform.getVisualScaleWithHoverAndDynamicMotionReflected(), scaleY = transform.getVisualScaleWithHoverAndDynamicMotionReflected()](layer::CmdScale *cmd) {
                cmd->scaleX = scaleX;
                cmd->scaleY = scaleY;
            }, 0, drawCommandSpace);

            layer::QueueCommand<layer::CmdRotate>(layerPtr, [rotation = transform.getVisualR()](layer::CmdRotate *cmd) {
                cmd->angle = rotation;
            }, 0, drawCommandSpace);

            layer::QueueCommand<layer::CmdTranslate>(layerPtr, [x = -transform.getVisualW() * 0.5, y = -transform.getVisualH() * 0.5](layer::CmdTranslate *cmd) {
                cmd->x = x;
                cmd->y = y;
            }, 0, drawCommandSpace);

                
            // static const float CIRCLE_LINE_WIDTH = 3.0f; // Width of the circle line
            
            

            // 1) DRAW SHADOW PASS
            // if (shadowEnabled)
            // {
            //     layer::QueueCommand<layer::CmdTranslate>(layerPtr, [shadowDisplacementX, shadowDisplacementY](layer::CmdTranslate *cmd)
            //     {
            //         cmd->x = -shadowDisplacementX;
            //         cmd->y = shadowDisplacementY;
            //     });
            //     switch (particle.renderType)
            //     {
            //     case ParticleRenderType::RECTANGLE_FILLED:
            //         layer::QueueCommand<layer::CmdDrawRectanglePro>(layerPtr, [shadowDisplacementX, shadowDisplacementY, width = transform.getVisualW(), height = transform.getVisualH(), shadowColor](auto *cmd)
            //                                                      {
            //                 cmd->offsetX      = 0;
            //                 cmd->offsetY      = 0;
            //                 cmd->size.x  = width;
            //                 cmd->size.y = height;
            //                 cmd->color  = shadowColor; 
            //             }, 0);
            //         break;
                    
            //     case ParticleRenderType::RECTANGLE_LINE:
            //         layer::QueueCommand<layer::CmdDrawRectangleLinesPro>(layerPtr, [shadowDisplacementX, shadowDisplacementY, width = transform.getVisualW(), height = transform.getVisualH(), shadowColor](auto *cmd)
            //                                                           {
            //                 cmd->offsetX      = shadowDisplacementX;
            //                 cmd->offsetY      = shadowDisplacementY;
            //                 cmd->size.x  = width;
            //                 cmd->size.y = height;
            //                 cmd->color  = shadowColor; 
            //                 cmd->lineThickness = CIRCLE_LINE_WIDTH;  // Set line thickness for rectangle line shadow
            //             }, 0);
            //         break;
            //     case ParticleRenderType::CIRCLE_FILLED:
            //         layer::QueueCommand<layer::CmdDrawCircleFilled>(layerPtr, [shadowDisplacementX, shadowDisplacementY, radius = std::max(transform.getVisualW(), transform.getVisualH()) / 2.0f, shadowColor](auto *cmd)
            //                                                   {
            //                 cmd->x      = shadowDisplacementX;
            //                 cmd->y      = shadowDisplacementY;
            //                 cmd->radius = radius;
            //                 cmd->color  = shadowColor; 
                                                                
            //             }, 0);
            //         break;
            //     case ParticleRenderType::CIRCLE_LINE:
            //         layer::QueueCommand<layer::CmdDrawCircleLine>(layerPtr, [shadowDisplacementX, shadowDisplacementY, radius = std::max(transform.getVisualW(), transform.getVisualH()) / 2.0f, shadowColor](auto *cmd)
            //                                                        {
            //                 cmd->x      = shadowDisplacementX;
            //                 cmd->y      = shadowDisplacementY;
            //                 cmd->innerRadius = radius - CIRCLE_LINE_WIDTH; // Inner radius for line circle
            //                 cmd->outerRadius = radius;
            //                 cmd->startAngle = 0.0f; // Start angle in radians
            //                 cmd->endAngle = 360; // Full circle
            //                 cmd->segments = 32; // Number of segments for the circle line
            //                 cmd->color = shadowColor; }, 0);
            //         break;
            //     default:
            //         break; // no shadow for TEXTURE or unknown
            //     }
            //     layer::QueueCommand<layer::CmdTranslate>(layerPtr, [shadowDisplacementX, shadowDisplacementY](layer::CmdTranslate *cmd)
            //     {
            //         cmd->x = shadowDisplacementX;
            //         cmd->y = -shadowDisplacementY;
            //     });
            // }

            // main pass
            switch (particle.renderType)
            {
            case ParticleRenderType::TEXTURE:
            {
                if (registry.any_of<AnimationQueueComponent>(entity))
                {
                    layer::QueueCommand<layer::CmdDrawEntityAnimation>(layerPtr, [entity = entity](layer::CmdDrawEntityAnimation *cmd)
                                                                       {
                            cmd->e = entity;
                            cmd->registry = &globals::registry;
                            cmd->x = 0;
                            cmd->y = 0; }, 0, drawCommandSpace);
                }
                else
                {
                    SPDLOG_ERROR("Particle entity {} has render type TEXTURE but no AnimationQueueComponent found..", (int)(entity));
                }
                break;
            }
            case ParticleRenderType::RECTANGLE_FILLED:
            {
                layer::QueueCommand<layer::CmdDrawRectanglePro>(layerPtr, [width = transform.getVisualW(), height = transform.getVisualH(), color = drawColor](layer::CmdDrawRectanglePro *cmd)
                                                             {
                                                                cmd->offsetX      = 0;
                                                                cmd->offsetY      = 0;
                                                                cmd->size.x  = width;
                                                                cmd->size.y = height;
                                                                cmd->color  = color; }, 0, drawCommandSpace);
                break;
            }
            case ParticleRenderType::RECTANGLE_LINE:
            {
                
                layer::QueueCommand<layer::CmdDrawRectangleLinesPro>(layerPtr, [width = transform.getVisualW(), height = transform.getVisualH(), color = drawColor](layer::CmdDrawRectangleLinesPro *cmd)
                                                                  {
                        cmd->offsetX = 0;
                        cmd->offsetY = 0;
                        cmd->size.x = width;
                        cmd->size.y = height;
                        cmd->color = color; }, 0, drawCommandSpace);
                break;
            }
            case ParticleRenderType::CIRCLE_FILLED:
            {
                layer::QueueCommand<layer::CmdDrawCircleFilled>(layerPtr, [radius = std::max(transform.getVisualW(), transform.getVisualH()), color = drawColor](layer::CmdDrawCircleFilled *cmd)
                                                          {
                        cmd->x = radius/2;
                        cmd->y = radius/2;
                        cmd->radius = radius;
                        cmd->color = color; }, 0, drawCommandSpace);
                break;
            }
            case ParticleRenderType::CIRCLE_LINE:
            {
                layer::QueueCommand<layer::CmdDrawCircleLine>(layerPtr, [radius = std::max(transform.getVisualW(), transform.getVisualH()), color = drawColor](layer::CmdDrawCircleLine *cmd)
                                                               {
                        cmd->x = radius/2;
                        cmd->y = radius/2;
                        cmd->innerRadius = radius - CIRCLE_LINE_WIDTH; // Inner radius for line circle
                        cmd->outerRadius = radius;
                        cmd->startAngle = 0.0f; // Start angle in radians
                        cmd->endAngle = 360; // Full circle
                        cmd->segments = 32; // Number of segments for the circle line
                        cmd->color = color; }, 0, drawCommandSpace);
                break;
            }
            default:
                SPDLOG_WARN("Unknown particle render type: {}", static_cast<int>(particle.renderType));
                break;
            }

            layer::QueueCommand<layer::CmdPopMatrix>(layerPtr, [](layer::CmdPopMatrix *cmd) {}, 0, drawCommandSpace);
        }
    }
    
    // destroys every live particle
    inline void WipeAll() {
        auto view = globals::registry.view<Particle>();
        for (auto e : view) {
            globals::registry.destroy(e);
        }
    }

    // destroys only those particles whose ParticleTag.name == tag
    inline void WipeTagged(const std::string &tag) {
        auto view = globals::registry.view<Particle, ParticleTag>();
        for (auto [e, p, t] : view.each()) {
            if (t.name == tag) {
                globals::registry.destroy(e);
            }
        }
    }

    inline void exposeToLua(sol::state &lua)
    {

        auto &rec = BindingRecorder::instance();
        auto particlePath = std::vector<std::string>{"particle"};

        sol::table p = lua["particle"].get_or_create<sol::table>();
        if (!p.valid())
        {
            p = lua.create_table();
            lua["particle"] = p;
        }

        rec.add_type("particle");

        p["ParticleRenderType"] = lua.create_table_with(
            "TEXTURE", particle::ParticleRenderType::TEXTURE,
            "RECTANGLE_LINE", particle::ParticleRenderType::RECTANGLE_LINE,
            "RECTANGLE_FILLED", particle::ParticleRenderType::RECTANGLE_FILLED,
            "CIRCLE_LINE", particle::ParticleRenderType::CIRCLE_LINE,
            "CIRCLE_FILLED", particle::ParticleRenderType::CIRCLE_FILLED);

        auto &renderTypeDef = rec.add_type("particle.ParticleRenderType");
        renderTypeDef.doc = "How particles should be rendered";
        rec.record_property("particle.ParticleRenderType", {"TEXTURE", std::to_string(static_cast<int>(particle::ParticleRenderType::TEXTURE)), "Use a sprite texture"});
        rec.record_property("particle.ParticleRenderType", {"RECTANGLE_LINE", std::to_string(static_cast<int>(particle::ParticleRenderType::RECTANGLE_LINE)), "Draw a rectangle outline"});
        rec.record_property("particle.ParticleRenderType", {"RECTANGLE_FILLED", std::to_string(static_cast<int>(particle::ParticleRenderType::RECTANGLE_FILLED)), "Draw a filled rectangle"});
        rec.record_property("particle.ParticleRenderType", {"CIRCLE_LINE", std::to_string(static_cast<int>(particle::ParticleRenderType::CIRCLE_LINE)), "Draw a circle outline"});

        rec.record_property("particle.ParticleRenderType", {"CIRCLE_FILLED", std::to_string(static_cast<int>(particle::ParticleRenderType::CIRCLE_FILLED)), "Draw a filled circle"});

        lua.new_usertype<particle::Particle>("Particle",
            sol::constructors<particle::Particle()>(),
            "renderType", &particle::Particle::renderType,
            "velocity", &particle::Particle::velocity,
            "rotation", &particle::Particle::rotation,
            "rotationSpeed", &particle::Particle::rotationSpeed,
            "scale", &particle::Particle::scale,
            "lifespan", &particle::Particle::lifespan,
            "age", &particle::Particle::age,
            "color", &particle::Particle::color,
            "gravity", &particle::Particle::gravity,
            "acceleration", &particle::Particle::acceleration,
            "startColor", &particle::Particle::startColor,
            "endColor", &particle::Particle::endColor,
            sol::meta_function::to_string, [](particle::Particle const &p){
                std::ostringstream ss;
                ss 
                  << "Particle{vel=(" << p.velocity->x << "," << p.velocity->y << ") ";
                return ss.str();
            },
            "onUpdateCallback", &particle::Particle::onUpdateCallback,   // <-- Add this
            "type_id", []()
            { return entt::type_hash<particle::Particle>::value(); });
        // rec.bind_usertype<particle::Particle>(lua, "Particle", "0.1", "Single particle instance");
        rec.record_property("Particle", {"renderType", "nil", "particle.ParticleRenderType: How the particle is drawn."});
        rec.record_property("Particle", {"velocity", "nil", "Vector2?: The particle's current velocity."});
        rec.record_property("Particle", {"rotation", "nil", "number?: The particle's current rotation in degrees."});
        rec.record_property("Particle", {"rotationSpeed", "nil", "number?: How fast the particle rotates."});
        rec.record_property("Particle", {"scale", "nil", "number?: The particle's current scale."});
        rec.record_property("Particle", {"lifespan", "nil", "number?: How long the particle exists in seconds."});
        rec.record_property("Particle", {"age", "nil", "number?: The current age of the particle in seconds."});
        rec.record_property("Particle", {"color", "nil", "Color?: The current color of the particle."});
        rec.record_property("Particle", {"gravity", "nil", "number?: Gravity strength applied to the particle."});
        rec.record_property("Particle", {"acceleration", "nil", "number?: Acceleration applied over the particle's lifetime."});
        rec.record_property("Particle", {"startColor", "nil", "Color?: The color the particle starts with."});
        rec.record_property("Particle", {"endColor", "nil", "Color?: The color the particle fades to over its life."});
        rec.record_property("Particle", {"onUpdateCallback",
            "function(self: Particle, dt: number)",
            "Optional callback, called every frame with (particle, deltaTime)."});

        p.new_usertype<particle::ParticleEmitter>("ParticleEmitter",
                                                  sol::constructors<>(),
                                                  "size", &particle::ParticleEmitter::size,
                                                  "emissionRate", &particle::ParticleEmitter::emissionRate,
                                                  "lastEmitTime", &particle::ParticleEmitter::lastEmitTime,
                                                  "particleLifespan", &particle::ParticleEmitter::particleLifespan,
                                                  "particleSpeed", &particle::ParticleEmitter::particleSpeed,
                                                  "fillArea", &particle::ParticleEmitter::fillArea,
                                                  "oneShot", &particle::ParticleEmitter::oneShot,
                                                  "oneShotParticleCount", &particle::ParticleEmitter::oneShotParticleCount,
                                                  "prewarm", &particle::ParticleEmitter::prewarm,
                                                  "prewarmParticleCount", &particle::ParticleEmitter::prewarmParticleCount,
                                                  "useGlobalCoords", &particle::ParticleEmitter::useGlobalCoords,
                                                  "speedScale", &particle::ParticleEmitter::speedScale,
                                                  "explosiveness", &particle::ParticleEmitter::explosiveness,
                                                  "randomness", &particle::ParticleEmitter::randomness,
                                                  "emissionSpread", &particle::ParticleEmitter::emissionSpread,
                                                  "gravityStrength", &particle::ParticleEmitter::gravityStrength,
                                                  "emissionDirection", &particle::ParticleEmitter::emissionDirection,
                                                  "acceleration", &particle::ParticleEmitter::acceleration,
                                                  "blendMode", &particle::ParticleEmitter::blendMode,
                                                  "colors", &particle::ParticleEmitter::colors,
                                                  "type_id", []()
                                                  { return entt::type_hash<particle::ParticleEmitter>::value(); });
        rec.bind_usertype<particle::ParticleEmitter>(lua, "particle.ParticleEmitter", "0.1", "Defines how particles are emitted");
        rec.record_property("particle.ParticleEmitter", {"size", "nil", "Vector2: The size of the emission area."});
        rec.record_property("particle.ParticleEmitter", {"emissionRate", "nil", "number: Time in seconds between emissions."});
        rec.record_property("particle.ParticleEmitter", {"particleLifespan", "nil", "number: How long each particle lives."});
        rec.record_property("particle.ParticleEmitter", {"particleSpeed", "nil", "number: Initial speed of emitted particles."});
        rec.record_property("particle.ParticleEmitter", {"fillArea", "nil", "boolean: If true, emit from anywhere within the size rect."});
        rec.record_property("particle.ParticleEmitter", {"oneShot", "nil", "boolean: If true, emits a burst of particles once."});
        rec.record_property("particle.ParticleEmitter", {"oneShotParticleCount", "nil", "number: Number of particles for a one-shot burst."});
        rec.record_property("particle.ParticleEmitter", {"prewarm", "nil", "boolean: If true, simulates the system on creation."});
        rec.record_property("particle.ParticleEmitter", {"prewarmParticleCount", "nil", "number: Number of particles for prewarming."});
        rec.record_property("particle.ParticleEmitter", {"useGlobalCoords", "nil", "boolean: If true, particles operate in world space."});
        rec.record_property("particle.ParticleEmitter", {"emissionSpread", "nil", "number: Angular spread of particle emissions in degrees."});
        rec.record_property("particle.ParticleEmitter", {"gravityStrength", "nil", "number: Gravity applied to emitted particles."});
        rec.record_property("particle.ParticleEmitter", {"emissionDirection", "nil", "Vector2: Base direction for particle emission."});
        rec.record_property("particle.ParticleEmitter", {"acceleration", "nil", "number: Acceleration applied to particles."});
        rec.record_property("particle.ParticleEmitter", {"blendMode", "nil", "BlendMode: The blend mode for rendering particles."});
        rec.record_property("particle.ParticleEmitter", {"colors", "nil", "Color[]: A table of possible colors for particles."});

        p.new_usertype<particle::ParticleAnimationConfig>("ParticleAnimationConfig",
                                                          sol::constructors<>(),
                                                          "loop", &particle::ParticleAnimationConfig::loop,
                                                          "animationName", &particle::ParticleAnimationConfig::animationName,
                                                          "type_id", []()
                                                          { return entt::type_hash<particle::ParticleAnimationConfig>::value(); });
        rec.bind_usertype<particle::ParticleAnimationConfig>(lua, "particle.ParticleAnimationConfig", "0.1", "Configuration for animated particle appearance");
        rec.record_property("particle.ParticleAnimationConfig", {"loop", "boolean", "Whether the particle's animation should loop."});
        rec.record_property("particle.ParticleAnimationConfig", {"animationName", "string", "The name of the animation to play."});

        rec.bind_function(
            lua,
            particlePath,
            "EmitParticles",
            &particle::EmitParticles,
            "---@param emitterEntity Entity # The entity that has the particle emitter component.\n"
            "---@param count integer # The number of particles to emit in a single burst.\n"
            "---@return nil",
            "Emits a burst of particles from the specified emitter entity.");

        auto tableDrivenCreateParticleEmitter = [](Vector2 location,
            sol::table opts) -> entt::entity
        {
            auto e = ParticleEmitter{};
            // for each field: if opts has it, use it; otherwise keep default
            e.size = opts.get_or("size", e.size);
            e.emissionRate = opts.get_or("emissionRate", e.emissionRate);
            e.particleLifespan = opts.get_or("particleLifespan", e.particleLifespan);
            e.particleSpeed = opts.get_or("particleSpeed", e.particleSpeed);
            e.fillArea = opts.get_or("fillArea", e.fillArea);
            e.oneShot = opts.get_or("oneShot", e.oneShot);
            e.oneShotParticleCount = opts.get_or("oneShotParticleCount", e.oneShotParticleCount);
            e.prewarm = opts.get_or("prewarm", e.prewarm);
            e.prewarmParticleCount = opts.get_or("prewarmParticleCount", e.prewarmParticleCount);
            e.useGlobalCoords = opts.get_or("useGlobalCoords", e.useGlobalCoords);
            e.speedScale = opts.get_or("speedScale", e.speedScale);
            e.explosiveness = opts.get_or("explosiveness", e.explosiveness);
            e.randomness = opts.get_or("randomness", e.randomness);
            e.emissionSpread = opts.get_or("emissionSpread", e.emissionSpread);
            e.gravityStrength = opts.get_or("gravityStrength", e.gravityStrength);
            e.emissionDirection = opts.get_or("emissionDirection", e.emissionDirection);
            e.acceleration = opts.get_or("acceleration", e.acceleration);
            e.blendMode = opts.get_or("blendMode", e.blendMode);
            e.colors = opts.get_or("colors", e.colors);
            return CreateParticleEmitter(globals::registry, location, e);
        };
        
        // clone whatever function is passed in to the main Lua state, so we won't have issues with lua threads going out of scope (if timers are called from a coroutine)
        auto clone_to_main = [](sol::function thread_fn) {
            // 1) get a view of your real, main-state Lua
            sol::state_view main_sv{ ai_system::masterStateLua };
        
            // 2) stash the passed-in function into a temporary global
            main_sv.set("__timer_import", thread_fn);
        
            // 3) pull it back out — now it’s bound to the main-state lua_State*
            sol::function main_fn = main_sv.get<sol::function>("__timer_import");
        
            // 4) clean up the temp
            main_sv["__timer_import"] = sol::lua_nil;
        
            return main_fn;
        };
        
        
        // 4) Attach-emitter helper that sets `attachedTo` + `attachOffset`:
        auto luaAttachParticleEmitter = [](
            entt::entity emitterEntity,
            entt::entity targetEntity,
            sol::table opts) -> void
        {
            // fetch the component
            
            std::optional<Vector2> offset = std::nullopt;
            sol::optional<Vector2> luaPos = opts["offset"];
            if (luaPos)
            {
                offset = *luaPos;
            }
            else
            {
                offset = std::nullopt;
            }
            
            transform::AssignRole(&globals::registry, emitterEntity, transform::InheritedProperties::Type::RoleInheritor, targetEntity, transform::InheritedProperties::Sync::Strong, transform::InheritedProperties::Sync::Strong, transform::InheritedProperties::Sync::Strong, transform::InheritedProperties::Sync::Strong, offset);
        
        };
        
        // 5) Binder for attachment:
        rec.bind_function(
            lua,
            particlePath,
            "AttachEmitter",
            luaAttachParticleEmitter,
            // docstring for Lua
            "---@param emitter entt::entity" 
            "---@param target entt::entity"
            "---@param opts table? # { offset = Vector2 }",
            "Attaches an existing emitter to another entity, with optional offset."
        );
        
        rec.bind_function(
            lua,
            particlePath,
            "WipeAll",
            &particle::WipeAll,
            // docstring for Lua
            "---@return void\n"
            "---Destroys every live particle in the registry.",
            "Destroys all live particles."
        );
        
        rec.bind_function(
            lua,
            particlePath,
            "WipeTagged",
            &particle::WipeTagged,
            // docstring for Lua
            "---@param tag string # The tag to match\n"
            "---@return void\n"
            "---Destroys only those particles whose ParticleTag.name == tag.",
            "Destroys all particles with the given string tag."
        );        


        // 1) overload CreateParticleEmitter to take an options-table
        rec.bind_function(lua, particlePath, "CreateParticleEmitter",
                          sol::overload(
                              // existing zero-arg version
                              &particle::CreateParticleEmitter,
                              // new table-driven version
                              tableDrivenCreateParticleEmitter),
                          "---@overload fun():ParticleEmitter\n"
                          "---@param opts table? # Optional overrides for any emitter field\n"
                          "---@field opts.size Vector2\n"
                          "---@field opts.emissionRate number\n"
                          "---@field opts.colors Color[]\n"
                          "---@return ParticleEmitter",
                          "Creates a ParticleEmitter; pass a table to override any defaults.");

        // 2) Table→Particle converter (unchanged)
        static auto tableDrivenParticleMaker = [clone_to_main](sol::table opts) -> particle::Particle {
            particle::Particle p;
            p.renderType    = opts.get_or("renderType",    p.renderType);
            p.velocity      = opts.get_or("velocity",      p.velocity);
            p.rotation      = opts.get_or("rotation",      p.rotation);
            p.rotationSpeed = opts.get_or("rotationSpeed", p.rotationSpeed);
            p.scale         = opts.get_or("scale",         p.scale);
            p.lifespan      = opts.get_or("lifespan",      p.lifespan);
            p.age           = opts.get_or("age",           p.age);
            p.color         = opts.get_or("color",         p.color);
            p.gravity       = opts.get_or("gravity",       p.gravity);
            p.acceleration  = opts.get_or("acceleration",  p.acceleration);
            p.startColor    = opts.get_or("startColor",    p.startColor);
            p.endColor      = opts.get_or("endColor",      p.endColor);
            sol::object obj = opts["onUpdateCallback"];
            if (obj.valid()) {
                // key exists and isn’t nil
                p.onUpdateCallback = clone_to_main(obj.as<sol::function>());
            }
            return p;
        };

        // 3) New Lua-facing maker that calls CreateParticle with optional animation
        static auto luaCreateParticle = [](
                                    Vector2 location,
                                    Vector2 size,
                                    sol::table opts,
                                    sol::optional<sol::table> animOpts,
                                    sol::optional<std::string> tag = std::nullopt
                                ) -> entt::entity
        {
            // build the Particle
            particle::Particle p = tableDrivenParticleMaker(opts);
            
            bool shadow = opts.get_or("shadow", true);

            // build optional animation config
            std::optional<particle::ParticleAnimationConfig> cfg = std::nullopt;
            if (animOpts && animOpts->valid()) {
                particle::ParticleAnimationConfig a;
                a.loop          = (*animOpts).get_or("loop",          a.loop);
                a.animationName = (*animOpts).get_or("animationName", a.animationName);
                cfg = a;
                p.renderType = particle::ParticleRenderType::TEXTURE; // force TEXTURE for animation
            }
            // call your function
            auto e =  CreateParticle(globals::registry, location, size, p, cfg, tag.value_or(""));
            
            auto &gameObject = globals::registry.get<transform::GameObject>(e);
            if (shadow == false) {
                // disable shadow displacement, thereby removing shadow
                gameObject.shadowDisplacement.reset();
            }

            return e;
        };

        // 4) Bind it
        rec.bind_function(
            lua,
            particlePath,
            "CreateParticle",
            luaCreateParticle,
            // detailed EmmyLua docstring
            "---@param location Vector2                        # world-space spawn position\n"
            "---@param size     Vector2                        # initial width/height of the particle\n"
            "---@param opts     table?                         # optional config table with any of:\n"
            " -- renderType        ParticleRenderType        # TEXTURE, RECTANGLE_LINE, RECTANGLE_FILLED, etc.\n"
            " -- velocity          Vector2                   # initial (vx,vy)\n"
            " -- rotation          number                    # starting rotation in degrees\n"
            " -- rotationSpeed     number                    # degrees/sec\n"
            " -- scale             number                    # uniform scale multiplier\n"
            " -- lifespan          number                    # seconds until auto-destroy (≤0 = infinite)\n"
            " -- age               number                    # initial age in seconds\n"
            " -- color             Color                     # immediately applied tint\n"
            " -- gravity           number                    # downward acceleration per second\n"
            " -- acceleration      number                    # acceleration along velocity vector\n"
            " -- startColor        Color                     # tint at birth\n"
            " -- endColor          Color                     # tint at death\n"
            " -- onUpdateCallback  function(particle,dt)      # run each frame\n"
            " -- shadow            boolean                   # draw or disable shadow (default = true)\n"
            "---@param animCfg  table?                         # optional animation config:\n"
            " -- loop              boolean                   # whether to loop the animation\n"
            " -- animationName     string                    # which animation to play\n"
            "---@param tag      string?                        # optional string tag to attach to this particle\n"
            "---@return entt::entity                            # the newly created particle entity",
            "Creates a Particle from Lua, applies optional animation & tag."
        );
        
        
        // 1) Create a new usertype for Vector2
        lua.new_usertype<Vector2>(
            "Vector2",
            // allow `Vector2()` → (0,0) and `Vector2(x,y)`
            sol::constructors<Vector2(), Vector2(float, float)>(),
            // expose fields
            "x", &Vector2::x,
            "y", &Vector2::y
        );

        // 2) (Optional) make it easier to construct
        lua.set_function("Vec2", [](float x, float y) { return Vector2{ x, y }; });

        // 3) If you’re using your BindingRecorder for docs:
        rec.add_type("Vector2");
        rec.record_property("Vector2", { "x", "number", "X component" });
        rec.record_property("Vector2", { "y", "number", "Y component" });
        
        // 1) Bind the Color struct
        lua.new_usertype<Color>(
            "Color",
            // ctors: default (white {255,255,255,255}) and full RGBA
            sol::constructors<
                Color(), 
                Color(unsigned char, unsigned char, unsigned char, unsigned char)
            >(),
            // fields
            "r", &Color::r,
            "g", &Color::g,
            "b", &Color::b,
            "a", &Color::a
        );

        // 2) Optional helper for convenience
        lua.set_function("Col", [](int r, int g, int b, sol::optional<int> a){
            return Color{
                static_cast<unsigned char>(r),
                static_cast<unsigned char>(g),
                static_cast<unsigned char>(b),
                static_cast<unsigned char>(a.value_or(255))
            };
        });

        // 3) (If using BindingRecorder)
        rec.add_type("Color");
        rec.record_property("Color", {"r", "number", "Red channel (0–255)"});
        rec.record_property("Color", {"g", "number", "Green channel (0–255)"});
        rec.record_property("Color", {"b", "number", "Blue channel (0–255)"});
        rec.record_property("Color", {"a", "number", "Alpha channel (0–255)"});

    }
}
