#include "transform_functions.hpp"

#include "raylib.h"
#include "raymath.h"
#include <cmath>
#include "systems/collision/broad_phase.hpp"
#include "systems/main_loop_enhancement/main_loop.hpp"
#include "systems/layer/layer.hpp"
#include "systems/layer/layer_command_buffer.hpp"
#include "systems/ui/util.hpp"
#include "systems/ui/element.hpp"
#include "systems/text/textVer2.hpp"
#include "systems/ui/box.hpp"
#include "systems/ui/inventory_ui.hpp"

#include "systems/scripting/binding_recorder.hpp"

#include "core/globals.hpp"

namespace transform
{

    std::unordered_map<TransformMethod, std::any> transformFunctionsDefault = {
        {TransformMethod::UpdateAllTransforms, std::function<void(entt::registry *, float)>(UpdateAllTransforms)},
        {TransformMethod::HandleDefaultTransformDrag, std::function<void(entt::registry *, entt::entity, std::optional<Vector2>)>(handleDefaultTransformDrag)},
        {TransformMethod::CreateOrEmplace, std::function<entt::entity(entt::registry *, entt::entity, float, float, float, float, std::optional<entt::entity>)>(CreateOrEmplace)},
        {TransformMethod::CreateGameWorldContainerEntity, std::function<entt::entity(entt::registry *, float, float, float, float)>(CreateGameWorldContainerEntity)},
        {TransformMethod::UpdateTransformSmoothingFactors, std::function<void(entt::registry *, entt::entity, float)>(UpdateTransformSmoothingFactors)},
        {TransformMethod::AlignToMaster, std::function<void(entt::registry *, entt::entity, bool)>(AlignToMaster)},
        {TransformMethod::MoveWithMaster, std::function<void(entt::entity, float, transform::Transform &, transform::InheritedProperties &, transform::GameObject &)>(MoveWithMaster)},
        {TransformMethod::UpdateLocation, std::function<void(entt::entity, float, Transform &, spring::Spring &, spring::Spring &)>(UpdateLocation)},
        {TransformMethod::UpdateRotation, std::function<void(entt::entity, float, Transform &, spring::Spring &, spring::Spring &)>(UpdateRotation)},
        {TransformMethod::UpdateScale, std::function<void(entt::entity, float, Transform &, spring::Spring &)>(UpdateScale)},
        {TransformMethod::GetMaster, std::function<Transform::FrameCalculation::MasterCache(entt::entity, Transform &, InheritedProperties &, GameObject &, Transform*&, InheritedProperties*& )>(GetMaster)},
        {TransformMethod::SyncPerfectlyToMaster, std::function<void( entt::entity, entt::entity, Transform &, InheritedProperties &, Transform &, InheritedProperties &)>(SyncPerfectlyToMaster)},
        {TransformMethod::UpdateDynamicMotion, std::function<void(entt::entity, float, Transform &)>(UpdateDynamicMotion)},
        {TransformMethod::InjectDynamicMotion, std::function<void(entt::registry *, entt::entity, float, float)>(InjectDynamicMotion)},
        {TransformMethod::UpdateParallaxCalculations, std::function<void(entt::registry *, entt::entity)>(UpdateParallaxCalculations)},
        {TransformMethod::ConfigureAlignment, std::function<void(entt::registry *, entt::entity, bool, entt::entity, std::optional<InheritedProperties::Sync>, std::optional<InheritedProperties::Sync>, std::optional<InheritedProperties::Sync>, std::optional<InheritedProperties::Sync>, std::optional<int>, std::optional<Vector2>)>(ConfigureAlignment)},
        {TransformMethod::AssignRole, std::function<void(entt::registry *, entt::entity, std::optional<InheritedProperties::Type>, entt::entity, std::optional<InheritedProperties::Sync>, std::optional<InheritedProperties::Sync>, std::optional<InheritedProperties::Sync>, std::optional<InheritedProperties::Sync>, std::optional<Vector2>)>(AssignRole)},
        {TransformMethod::UpdateTransform, std::function<void(entt::entity, float, Transform &, InheritedProperties &, GameObject &)>(UpdateTransform)},
        {TransformMethod::SnapTransformValues, std::function<void(entt::registry *, entt::entity, float, float, float, float)>(SnapTransformValues)},
        {TransformMethod::SnapVisualTransformValues, std::function<void(entt::registry *, entt::entity)>(SnapVisualTransformValues)},
        {TransformMethod::DrawBoundingBoxAndDebugInfo, std::function<void(entt::registry *, entt::entity, std::shared_ptr<layer::Layer>)>(DrawBoundingBoxAndDebugInfo)},
        {TransformMethod::CalculateCursorPositionWithinFocus, std::function<Vector2(entt::registry *, entt::entity)>(CalculateCursorPositionWithinFocus)},
        {TransformMethod::CheckCollisionWithPoint, std::function<bool(entt::registry *, entt::entity, Vector2)>(CheckCollisionWithPoint)},
        {TransformMethod::HandleClick, std::function<void(entt::registry *, entt::entity)>(HandleClick)},
        {TransformMethod::HandleClickReleased, std::function<void(entt::registry *, entt::entity)>(HandleClickReleased)},
        {TransformMethod::SetClickOffset, std::function<void(entt::registry *, entt::entity, Vector2, bool)>(SetClickOffset)},
        {TransformMethod::GetObjectToDrag, std::function<entt::entity(entt::registry *, entt::entity)>(GetObjectToDrag)},
        {TransformMethod::Draw, std::function<void(std::shared_ptr<layer::Layer>, entt::registry *, entt::entity)>(Draw)},
        {TransformMethod::StartDrag, std::function<void(entt::registry *, entt::entity, bool)>(StartDrag)},
        {TransformMethod::StopDragging, std::function<void(entt::registry *, entt::entity)>(StopDragging)},
        {TransformMethod::StartHover, std::function<void(entt::registry *, entt::entity)>(StartHover)},
        {TransformMethod::StopHover, std::function<void(entt::registry *, entt::entity)>(StopHover)},
        {TransformMethod::GetCursorOnFocus, std::function<Vector2(entt::registry *, entt::entity)>(GetCursorOnFocus)},
        {TransformMethod::ConfigureContainerForEntity, std::function<void(entt::registry *, entt::entity, entt::entity)>(ConfigureContainerForEntity)},
        {TransformMethod::ApplyTranslationFromEntityContainer, std::function<void(entt::registry *, entt::entity, std::shared_ptr<layer::Layer>)>(ApplyTranslationFromEntityContainer)},
        {TransformMethod::GetDistanceBetween, std::function<float(entt::registry *, entt::entity, entt::entity)>(GetDistanceBetween)},
        {TransformMethod::RemoveEntity, std::function<void(entt::registry *, entt::entity)>(RemoveEntity)}
    };
    
    std::unordered_map<TransformMethod, std::any> hooksToCallBeforeDefault{}, hooksToCallAfterDefault{};

    //EXPOSED publicly
    // creates an empty entity with a transform component, node component, and role component
    // container should be a root entity the size of the map
    // if entityToEmplaceTo exists, the new transform components will be emplaced to it instead
    auto CreateOrEmplace(entt::registry *registry, entt::entity container, float x, float y, float w, float h, std::optional<entt::entity> entityToEmplaceTo) -> entt::entity
    {
        auto &containerNode = registry->get<GameObject>(container);

        entt::entity e;
        if (entityToEmplaceTo)
        {
            e = entityToEmplaceTo.value();
        }
        else
        {
            e = registry->create();
        }
        auto &transform = registry->emplace_or_replace<Transform>(e); 
        transform.self = e;
        transform.middleEntityForAlignment = e; // self is the middle entity for alignment
        transform.setActualX(x);
        transform.setActualY(y);
        transform.setActualW(w);
        transform.setActualH(h);
        transform.setActualScale(1.0f);
        transform.setActualRotation(0.0f);
        transform.setVisualX(x);
        transform.setVisualY(y);
        transform.setVisualW(w);
        transform.setVisualH(h);
        transform.setVisualScale(1.0f);
        transform.setVisualRotation(0.0f);
        // const spring::Spring DEFAULT_SPRING_ZERO = {.value = 0, .stiffness = 200.f, .damping = 40.f, .targetValue = 0};
        // customize xy spring
        auto &xSpring = registry->get<Spring>(transform.x);
        xSpring.damping = 100.f;
        xSpring.stiffness = 1600.f;
        auto &ySpring = registry->get<Spring>(transform.y);
        ySpring.damping = 100.f;
        ySpring.stiffness = 1600.f;

        auto &scaleSpring = registry->get<Spring>(transform.s);
        scaleSpring.damping = 100.f;
        scaleSpring.stiffness = 1600.f;

        auto &role = registry->emplace<InheritedProperties>(e);

        auto &node = registry->emplace<GameObject>(e);
        node.container = container;
        if (globals::isGamePaused)
        {
            node.ignoresPause = true; // created on pause, so ignore pause
        }

        node.shadowHeight = 0.2f;
        node.layerDisplacement = {0, 0};
        node.shadowDisplacement = {0, -1.5f};

        node.transformFunctions =  transformFunctionsDefault;

        // example hover customization
        setJiggleOnHover(registry, e, 0.1f);

        UpdateParallaxCalculations(registry, e);

       // default handlers for release, click, update, animate, hover, stop_hover, drag, stop_drag, can_drag
 
        return e;
    }

    auto setJiggleOnHover(entt::registry *registry, entt::entity e, float jiggleAmount) -> void
    {
        auto &node = registry->get<GameObject>(e);
        node.methods.onHover = [jiggleAmount](entt::registry &registry, entt::entity e) {
            transform::InjectDynamicMotion(&registry, e, jiggleAmount, 1.f);
        };
    }


    //EXPOSED publicly
    // creates a container the size of the map which will serve as the root entity for the game world
    auto CreateGameWorldContainerEntity(entt::registry *registry, float x, float y, float w, float h) -> entt::entity
    {
        //TODO: use create() method for this
        auto e = registry->create();
        auto &transform = registry->emplace<Transform>(e);
        transform.middleEntityForAlignment = e; // self is the middle entity for alignment
        transform.setActualX(x);
        transform.setActualY(y);
        transform.setActualW(w);
        transform.setActualH(h);
        transform.setActualScale(1.0f);
        transform.setActualRotation(0.0f);
        transform.setVisualX(x);
        transform.setVisualY(y);
        transform.setVisualW(w);
        transform.setVisualH(h);
        transform.setVisualScale(1.0f);
        transform.setVisualRotation(0.0f);
        auto &role = registry->emplace<InheritedProperties>(e);
        auto &node = registry->emplace<GameObject>(e);
        node.ignoresPause = true; // ignore pause for the game world container
        return e;
    }
    
    //EXPOSED publicly
    auto HandleClick(entt::registry *registry, entt::entity e) -> void
    {
        if (registry->valid(e) == false) return; 
        
        auto &node = registry->get<transform::GameObject>(e);
        if (node.methods.onClick) {
            node.methods.onClick(*registry, e);
        }
    }
    
    //EXPOSED publicly
    auto HandleClickReleased(entt::registry *registry, entt::entity e) -> void
    {
        if (registry->valid(e) == false) return;
        
        auto &node = registry->get<transform::GameObject>(e);
        if (node.methods.onRelease) {
            node.methods.onRelease(*registry, e, entt::null);
        }
    }

    
    //EXPOSED publicly
    auto Draw(const std::shared_ptr<layer::Layer> &layer, entt::registry *registry, entt::entity e) -> void
    {
        DrawBoundingBoxAndDebugInfo(registry, e, layer);
        
        auto &node = registry->get<GameObject>(e);
        if (node.state.visible) {
            //children
            for (auto child : node.orderedChildren) {
                
                if (registry->valid(child) == false) continue;
                
                if (globals::drawDebugInfo)
                    DrawBoundingBoxAndDebugInfo(registry, child, layer);
                auto &childNode = registry->get<GameObject>(child);
                if (childNode.state.visible  && childNode.state.visible && childNode.methods.draw) {
                    childNode.methods.draw(layer, *registry, child);
                }
                
            }
        }
        
        // custom drawing if there is any
        if (node.methods.draw) {
            node.methods.draw(layer, *registry, e);
        }
    }

    // not exposed publicly
    auto AlignToMaster(entt::registry *registry, entt::entity e, bool forceAlign) -> void
    {
        
        // ZoneScopedN("AlignToMaster");
        //TODO: this sshould probably take into account cases where parent has its own offset. (due to alignment)
        auto &role = registry->get<InheritedProperties>(e);
        auto &transform = registry->get<Transform>(e);
        
        if (!role.flags) return; // no flags, no alignment

        // if alignment and offset unchanged
        if (role.flags->alignment == role.flags->prevAlignment && role.offset->x == role.prevOffset->x && role.offset->y == role.prevOffset->y && forceAlign == false && transform.frameCalculation.alignmentChanged == false)
        {
            // SPDLOG_DEBUG("Alignment and offset unchanged");
            return;
        }

        // if changed, update alignment
        if (role.flags->alignment != role.flags->prevAlignment)
        {
            role.flags->prevAlignment = role.flags->alignment;
        }

        // if alignment empty or no parent, return
        if (role.flags->alignment == InheritedProperties::Alignment::NONE || registry->valid(role.master) == false)
        {
            return;
        }
        // 

        if (role.master == globals::gameWorldContainerEntity)
            SPDLOG_DEBUG("Aligning to master (game world)");
        

        entt::entity midEntity = transform.middleEntityForAlignment.value();
        auto &midTransform = registry->get<Transform>(midEntity);

        transform.frameCalculation.alignmentChanged = true;

        entt::entity parent = role.master;
        auto &parentTransform = registry->get<Transform>(parent);
        
        if (!role.offset) role.offset = Vector2{};

        // horizontal center alignment
        if (role.flags->alignment & InheritedProperties::Alignment::HORIZONTAL_CENTER)
        {
            role.offset->x = 0.5 * parentTransform.getActualW() - 0.5 * midTransform.getActualW() + role.flags->extraAlignmentFinetuningOffset.x - transform.getActualX() + midTransform.getActualX();
        }

        // vertical center alignment
        if (role.flags->alignment & InheritedProperties::Alignment::VERTICAL_CENTER)
        {
            role.offset->y = 0.5 * parentTransform.getActualH() - 0.5 * midTransform.getActualH() + role.flags->extraAlignmentFinetuningOffset.y - transform.getActualY() + midTransform.getActualY();
        }

        // vertical bottom alignment
        if (role.flags->alignment & InheritedProperties::Alignment::VERTICAL_BOTTOM)
        {
            if (role.flags->alignment & InheritedProperties::Alignment::ALIGN_TO_INNER_EDGES)
            {
                role.offset->y = role.flags->extraAlignmentFinetuningOffset.y + parentTransform.getActualH() - transform.getActualH();
            }
            else
            {
                role.offset->y = role.flags->extraAlignmentFinetuningOffset.y + parentTransform.getActualH();
            }
        }

        // horizontal right alignment
        if (role.flags->alignment & InheritedProperties::Alignment::HORIZONTAL_RIGHT)
        {
            if (role.flags->alignment & InheritedProperties::Alignment::ALIGN_TO_INNER_EDGES)
            {
                role.offset->x = role.flags->extraAlignmentFinetuningOffset.x + parentTransform.getActualW() - transform.getActualW();
            }
            else
            {
                role.offset->x = role.flags->extraAlignmentFinetuningOffset.x + parentTransform.getActualW();
            }
        }

        // vertical top alignment
        if (role.flags->alignment & InheritedProperties::Alignment::VERTICAL_TOP)
        {
            if (role.flags->alignment & InheritedProperties::Alignment::ALIGN_TO_INNER_EDGES)
            {
                role.offset->y = role.flags->extraAlignmentFinetuningOffset.y;
            }
            else
            {
                role.offset->y = role.flags->extraAlignmentFinetuningOffset.y - transform.getActualH();
            }
        }

        // horizontal left alignment
        if (role.flags->alignment & InheritedProperties::Alignment::HORIZONTAL_LEFT)
        {
            if (role.flags->alignment & InheritedProperties::Alignment::ALIGN_TO_INNER_EDGES)
            {
                role.offset->x = role.flags->extraAlignmentFinetuningOffset.x; // REVIEW: what are the initial values of this?
            }
            else
            {
                role.offset->x = role.flags->extraAlignmentFinetuningOffset.x - transform.getActualW();
            }
        }

        if (!role.offset)
        {
            role.offset = Vector2();
            role.offset->x = 0;
            role.offset->y = 0; // REVIEW: or 0 - does it mean it needs to be unchanged?
        }

        auto &parentRole = registry->get<InheritedProperties>(parent);

        // parent is 43
        if (static_cast<int>(parent) == 36)
        {
            SPDLOG_DEBUG("Parent is UIBOX");
            if (parentRole.offset) SPDLOG_DEBUG("UIBOx offsets are: x: {}, y: {}", parentRole.offset->x, parentRole.offset->y);
        }

        // so this should cover cases where uibox, which is the master of a uiroot, has an actual offset. In which case, the uiroot will align its location to that offset and act as though its relative location to the master is actually 0,0 (making ui offset caculations for layout simpler)
        transform.getXSpring().targetValue = parentTransform.getXSpring().value + (parentRole.offset ? parentRole.offset->x : 0) + role.offset->x;
        transform.getYSpring().targetValue = parentTransform.getYSpring().value + (parentRole.offset ? parentRole.offset->y : 0) + role.offset->y;
        if (role.master == globals::gameWorldContainerEntity)
            SPDLOG_DEBUG("Aligning to master (game world) at values: x: {}, y: {}", transform.getXSpring().targetValue, transform.getYSpring().targetValue);

        //TODO: now where are these offsets used?

        if (!role.prevOffset)
        {
            role.prevOffset = Vector2();
        }
        role.prevOffset->x = role.offset->x;
        role.prevOffset->y = role.offset->y;
    }
    
    // Fetch—or build and cache—a SpringBundle for entity 'e'
    SpringCacheBundle& getSpringBundleCached(entt::entity e, Transform &t) {
        auto it = globals::g_springCache.find(e);
        if ( it == globals::g_springCache.end() ) {
            // first time this frame → pull all six springs once
            SpringCacheBundle b {
                &t.getXSpring(),
                &t.getYSpring(),
                &t.getRSpring(),
                &t.getSSpring(),
                &t.getWSpring(),
                &t.getHSpring()
            };
            auto ins = globals::g_springCache.emplace(e, b);
            return ins.first->second;
        }
        return it->second;
    }

    
    auto MoveWithMaster(entt::entity e, float dt, Transform &selfTransform, InheritedProperties &selfRole, GameObject &selfNode) -> void
    {
        auto registry = &globals::registry;
        
        // ZoneScopedN("MoveWithMaster");
        Vector2 tempRotatedOffset{};
        Vector2 tempIntermediateOffsets{};
        float tempAngleCos = 0.0f;
        float tempAngleSin = 0.0f;
        float tempWidth = 0.0f;
        float tempHeight = 0.0f;

        if (registry->valid(selfRole.master) == false)
        {
            return; // no parent to move with
        }


        //REVIEW: getmaster allows multi-level master-slave trees.
        //FIXME: the offset it returns isn't used at the moment. Using it breaks the system for some reason
        
        Transform *parentTransform = nullptr;
        InheritedProperties *parentRole = nullptr;
        
        auto parentRetVal = GetMaster(e, selfTransform, selfRole, selfNode, parentTransform, parentRole);
        auto parent = parentRetVal.master.value();

        static auto fillParentTransformAndRole = [](entt::entity parent, Transform *&parentTransform, InheritedProperties *&parentRole)
        {
            auto &registry = globals::registry;
            auto it = globals::getMasterCacheEntityToParentCompMap.find(parent);

            if (it != globals::getMasterCacheEntityToParentCompMap.end())
            {
                auto &entry = it->second;

                if (entry.parentTransform == nullptr)
                    entry.parentTransform = registry.try_get<Transform>(parent);

                if (entry.parentRole == nullptr)
                    entry.parentRole = registry.try_get<InheritedProperties>(parent);

                parentTransform = entry.parentTransform;
                parentRole = entry.parentRole;
            }
            else
            {
                parentTransform = registry.try_get<Transform>(parent);
                parentRole = registry.try_get<InheritedProperties>(parent);
            }
        }; 

        fillParentTransformAndRole(parent, parentTransform, parentRole);

        // an object that is attached to a UI element (of type OBJECT) should use the immediate master
        bool isUIElementObject = registry->any_of<ui::ObjectAttachedToUITag>(e);
        if (isUIElementObject) 
        {
            // if this is a UI element object, we need to use the immediate master
            parent = selfRole.master;
            fillParentTransformAndRole(e, parentTransform, parentRole);
        }
        
        UpdateDynamicMotion(e, dt, selfTransform);
        
        Vector2 layeredDisplacement = selfNode.layerDisplacement.value_or(Vector2{0, 0});
        
        auto selfSprings = getSpringBundleCached(e, selfTransform);
        auto parentSprings = getSpringBundleCached(parent, *parentTransform);
        
        auto selfActualW = selfSprings.w->targetValue;
        auto selfActualH = selfSprings.h->targetValue;
        auto selfVisualX = selfSprings.x->value;
        auto selfVisualY = selfSprings.y->value;
        auto selfVisualW = selfSprings.w->value;
        auto selfVisualH = selfSprings.h->value;
        
        auto parentActualW = parentSprings.w->targetValue;
        auto parentActualH = parentSprings.h->targetValue;
        auto parentVisualX = parentSprings.x->value;
        auto parentVisualY = parentSprings.y->value;
        auto parentVisualW = parentSprings.w->value;
        auto parentVisualH = parentSprings.h->value;
        auto parentVisualR = parentSprings.r->value;

        if (selfRole.location_bond == InheritedProperties::Sync::Weak)
        {
            tempRotatedOffset.x = selfRole.offset->x + (isUIElementObject ? 0 : parentRole->offset->x) + layeredDisplacement.x; // ignore the additional offset if this is a UI element object (REVIEW: not sure if this is correct)
            tempRotatedOffset.y = selfRole.offset->y + (isUIElementObject ? 0 : parentRole->offset->y) + layeredDisplacement.y;
        }
        else
        {
            if (parentVisualR < 0.0001f && parentVisualR > -0.0001f)
            {
                tempRotatedOffset.x = selfRole.offset->x + (isUIElementObject ? 0 : parentRole->offset->x) + layeredDisplacement.x; //TODO: selfRole.offset not initialized
                tempRotatedOffset.y = selfRole.offset->y + (isUIElementObject ? 0 : parentRole->offset->x) + layeredDisplacement.y;
            }
            else
            {
                tempAngleCos = cos(parentVisualR);
                tempAngleSin = sin(parentVisualR);
                tempWidth = -selfActualW / 2 + parentActualW / 2;
                tempHeight = -selfActualH / 2 + parentActualH / 2;
                tempIntermediateOffsets.x = selfRole.offset->x + (isUIElementObject ? 0 : parentRole->offset->x) + layeredDisplacement.x - tempWidth;
                tempIntermediateOffsets.y = selfRole.offset->y + (isUIElementObject ? 0 : parentRole->offset->x) + layeredDisplacement.y - tempHeight;
                tempRotatedOffset.x = tempIntermediateOffsets.x * tempAngleCos - tempIntermediateOffsets.y * tempAngleSin + tempWidth;
                tempRotatedOffset.y = tempIntermediateOffsets.x * tempAngleSin + tempIntermediateOffsets.y * tempAngleCos + tempHeight;
            }
        }
        
        selfSprings.x->targetValue = parentSprings.x->value + tempRotatedOffset.x;
        selfSprings.y->targetValue = parentSprings.y->value + tempRotatedOffset.y;
        // SPDLOG_DEBUG("Moving with master set to targets: x: {}, y: {}", selfTransform.getXSpring().targetValue, selfTransform.getYSpring().targetValue);

        if (selfRole.location_bond == InheritedProperties::Sync::Strong)
        {
            selfSprings.x->value = selfSprings.x->targetValue;
            selfSprings.y->value = selfSprings.y->targetValue;
        }
        else if (selfRole.location_bond == InheritedProperties::Sync::Weak)
        {

            UpdateLocation(e, dt, selfTransform, *selfSprings.x, *selfSprings.y);
        }
        
        
        // force spring update
        // selfTransform.updateCachedValues( true);
        // selfTransform.updateCachedValues(*selfSprings.x, *selfSprings.y, *selfSprings.w, *selfSprings.h, *selfSprings.r, *selfSprings.s, true);
        // parentTransform->updateCachedValues(true);
        
        selfActualW = selfSprings.w->targetValue;
        selfActualH = selfSprings.h->targetValue;
        selfVisualX = selfSprings.x->value;
        selfVisualY = selfSprings.y->value;
        selfVisualW = selfSprings.w->value;
        selfVisualH = selfSprings.h->value;
        auto selfActualR = selfSprings.r->targetValue;
        auto selfVisualR = selfSprings.r->value;
        auto selfVisualS = selfSprings.s->value;
        auto selfActualS = selfSprings.s->targetValue;
        
        parentActualW = parentSprings.w->targetValue;
        parentActualH = parentSprings.h->targetValue;
        parentVisualX = parentSprings.x->value;
        parentVisualY = parentSprings.y->value;
        parentVisualW = parentSprings.w->value;
        parentVisualH = parentSprings.h->value;
        parentVisualR = parentSprings.r->value;
        auto parentActualS = parentSprings.s->targetValue;
        auto parentVisualS = parentSprings.s->value;
        
        auto setSelfVisualX = [&](float v) { selfSprings.x->value = v; };
        auto setSelfVisualY = [&](float v) { selfSprings.y->value = v; };
        auto setSelfVisualW = [&](float v) { selfSprings.w->value = v; };
        auto setSelfVisualH = [&](float v) { selfSprings.h->value = v; };
        auto setSelfVisualR = [&](float v) { selfSprings.r->value = v; };
        auto setSelfVisualS = [&](float v) { selfSprings.s->value = v; };

        if (selfRole.rotation_bond == InheritedProperties::Sync::Strong)
        {
            float juiceFactor = 0;
            if (selfTransform.dynamicMotion.has_value())
            {
                juiceFactor = selfTransform.dynamicMotion->rotation;
            }
            else
            {
                juiceFactor = 0;
            }
            setSelfVisualR(selfActualR + parentTransform->rotationOffset + (juiceFactor));
        }
        else if (selfRole.rotation_bond == InheritedProperties::Sync::Weak)
        {
            UpdateRotation(e, dt, selfTransform, *selfSprings.r, *selfSprings.x);
        }

        if (selfRole.scale_bond == InheritedProperties::Sync::Strong)
        {
            float juiceFactor = 0;
            if (selfTransform.dynamicMotion.has_value())
            {
                juiceFactor = selfTransform.dynamicMotion->scale;
            }
            else
            {
                juiceFactor = 0;
            }
            setSelfVisualS(selfActualS * (parentVisualS / parentActualS) + juiceFactor);
        }
        else if (selfRole.scale_bond == InheritedProperties::Sync::Weak)
        {
            UpdateScale(e, dt, selfTransform, *selfSprings.s);
        }

        if (selfRole.size_bond == InheritedProperties::Sync::Strong)
        {
            setSelfVisualX(selfVisualX + (0.5f * (1 - parentVisualW / parentActualW) * selfVisualW));
            setSelfVisualW(selfActualW * (parentVisualW / parentActualW));
            setSelfVisualH(selfActualH * (parentVisualH / parentActualH));
        }
        else if (selfRole.size_bond == InheritedProperties::Sync::Weak)
        {
            UpdateSize(e, dt, selfTransform, *selfSprings.w, *selfSprings.h);
        }

        UpdateParallaxCalculations(registry, e);
    }

    // not exposed
    auto UpdateLocation(entt::entity e, float dt, Transform &transform, spring::Spring &springX, spring::Spring &springY) -> void
    {
        // nothing to do here, springs will update on their own
        if (springX.velocity > 0.0001f || springY.velocity > 0.0001f)
        {
            transform.frameCalculation.stationary = false;
        }
    }

    // not exposed
    auto UpdateSize(entt::entity e, float dt, Transform &transform, spring::Spring &springW, spring::Spring springH) -> void
    {
        // nothing to do here, springs will update on their own

        // disable updates on the WH springs while pinch is active
        if (transform.reduceXToZero)
            springW.enabled = false;
        else
            springW.enabled = true;
        if (transform.reduceYToZero)
            springH.enabled = false;
        else
            springH.enabled = true;

        // Check if an update is needed based on T, VT, and pinch flags
        if (
            // (transform.getActualW() != transform.getVisualW() && !transform.reduceXToZero) ||
            // (transform.getActualH() != transform.getVisualH() && !transform.reduceYToZero) ||
            (transform.getVisualW() > 0 && transform.reduceXToZero) ||
            (transform.getVisualH() > 0 && transform.reduceYToZero))
        {

            transform.frameCalculation.stationary = false;

            // update width manually instead of using springs, since we are "pinching" values to 0
            auto widthAdd = (8.0f * dt) * (transform.reduceXToZero ? -1 : 1) * transform.getActualW();
            auto heightAdd = (8.0f * dt) * (transform.reduceYToZero ? -1 : 1) * transform.getActualH();

            transform.setVisualW(transform.getVisualW() + widthAdd);
            transform.setVisualH(transform.getVisualH() + heightAdd);

            // Clamp width and height to valid ranges
            auto finalVisualW = std::max(0.0f, std::min(transform.getActualW(), transform.getVisualW()));
            auto finalVisualH = std::max(0.0f, std::min(transform.getActualH(), transform.getVisualH()));

            transform.setVisualW(finalVisualW);
            transform.setVisualH(finalVisualH);
        }
        else
        {
            // springs will bounce back to target values if pinch disabled
        }
    }

    // not exposed
    auto UpdateRotation(entt::entity e, float dt, Transform &transform, spring::Spring &springR, spring::Spring &springX) -> void
    {
        // nothing to do here, springs will update on their own
        float dynamicMotionAddedR = 0;

        if (transform.dynamicMotion)
        {
            dynamicMotionAddedR += transform.dynamicMotion->rotation * 2.0f; // Add dynamicMotion-based rotation if applicable
        }

        // handle leaning (added rotation) based on x velocity
        float desiredAddedR = 0;

        // ---- NEW: Compute Leaning Offset Based on X-Velocity ----
        constexpr float leanFactor = 0.05f;   // Controls lean strength
        constexpr float smoothFactor = 50.0f; // Controls response speed
        constexpr float decayRate = 100.0f;   // Controls how fast leaning fades out

        // Calculate target lean offset from X velocity
        float targetOffset = springX.velocity * leanFactor;

        // Exponential smoothing: Move towards target offset
        transform.rotationOffset += (targetOffset - transform.rotationOffset) * (1.0f - std::exp(-dt * smoothFactor));

        // Apply decay when velocity is low (smooth return to `T.r`)
        if (std::abs(springX.velocity) < 0.01f)
        {
            transform.rotationOffset *= std::exp(-dt * decayRate);
        }

        // Clamp the rotation offset from leaning to ±30 degrees
        transform.rotationOffset = std::clamp(transform.rotationOffset, -30.0f, 30.0f);
        
        // ignore the above if the rotation is not enabled
        if (transform.ignoreXLeaning)
        {
            transform.rotationOffset = 0.0f; // reset rotation offset if ignoring leaning
        }
        
        if (!transform.ignoreDynamicMotion)
        {
            
            transform.rotationOffset += dynamicMotionAddedR;
        }
        

        // Check if there is significant rotational difference or velocity
        if (std::abs(transform.rotationOffset - transform.getVisualR()) > 0.001f || std::abs(springR.velocity) > 0.001f)
        {
            transform.frameCalculation.stationary = false;
        }

        // snap to target rotation if close enough
        if (std::abs(transform.getVisualR() - transform.getActualRotation()) < 0.001f && std::abs(springR.velocity) < 0.001f)
        {
            transform.setVisualRotation(transform.getActualRotation());
            springR.velocity = 0;
        }
    }

    // not exposed
    auto UpdateScale(entt::entity e, float dt, Transform &transform, spring::Spring &springS) -> void
    {
        // nothing to do here, springs will update on their own
        if (springS.velocity > 0.0001f)
        {
            transform.frameCalculation.stationary = false;
        }
    }

    auto GetMaster(entt::entity selfEntity, Transform &selfTransform, InheritedProperties &selfRole, GameObject &selfNode, Transform*& parentTransformStorage, InheritedProperties*& parentRoleStorage) -> Transform::FrameCalculation::MasterCache
    {
        // Check the global cache first
        auto it = globals::getMasterCacheEntityToParentCompMap.find(selfEntity);
        if (it != globals::getMasterCacheEntityToParentCompMap.end())
        {
            const auto &entry = it->second;

            // SPDLOG_DEBUG("CACHE HIT for entity {}: parentTransform={}, parentRole={}",
                        // static_cast<int>(selfEntity),
                        // (void*)entry.parentTransform,
                        // (void*)entry.parentRole);

            Transform::FrameCalculation::MasterCache toReturn;
            toReturn.master = entry.master;
            toReturn.offset = entry.offset;

            parentTransformStorage = entry.parentTransform;
            parentRoleStorage = entry.parentRole;

            return toReturn;
        }

        // Default fallback
        Transform::FrameCalculation::MasterCache toReturn;
        toReturn.master = selfEntity;
        toReturn.offset = Vector2{0, 0};

        if (selfRole.master == globals::gameWorldContainerEntity || selfRole.role_type == InheritedProperties::Type::RoleRoot || selfRole.master == selfEntity)
        {
            // SPDLOG_DEBUG("NO PARENT for entity {}: storing null parentTransform and parentRole",
            //             static_cast<int>(selfEntity));

            globals::getMasterCacheEntityToParentCompMap[selfEntity] = {selfEntity, toReturn.offset.value(), nullptr, nullptr};
            return toReturn;
        }

        if (selfRole.location_bond == InheritedProperties::Sync::Weak && selfRole.rotation_bond == InheritedProperties::Sync::Weak)
        {
            // SPDLOG_DEBUG("WEAK BOND for entity {}: storing null parentTransform and parentRole",
            //             static_cast<int>(selfEntity));

            globals::getMasterCacheEntityToParentCompMap[selfEntity] = {selfEntity, toReturn.offset.value(), nullptr, nullptr};
            return toReturn;
        }

        // Recurse to parent
        parentTransformStorage = globals::registry.try_get<Transform>(selfRole.master);
        parentRoleStorage = globals::registry.try_get<InheritedProperties>(selfRole.master);
        auto parentNode = globals::registry.try_get<GameObject>(selfRole.master);

        if (!parentTransformStorage || !parentRoleStorage)
        {
            // SPDLOG_WARN("WARNING: entity {}'s parent {} has missing components (parentTransform={}, parentRole={})",
            //             static_cast<int>(selfEntity),
            //             static_cast<int>(selfRole.master),
            //             (void*)parentTransformStorage,
            //             (void*)parentRoleStorage);
        }

        Transform *parentOfParentTransform = nullptr;
        InheritedProperties *parentOfParentRole = nullptr;
        auto parentResults = GetMaster(selfRole.master, *parentTransformStorage, *parentRoleStorage, *parentNode, parentOfParentTransform, parentOfParentRole);

        // Compute new offset
        Vector2 offset{};
        if (parentResults.offset.has_value())
        {
            offset.x = parentResults.offset->x + selfRole.offset->x + selfNode.layerDisplacement->x;
            offset.y = parentResults.offset->y + selfRole.offset->y + selfNode.layerDisplacement->y;
        }

        // Store in cache
        globals::getMasterCacheEntityToParentCompMap[selfEntity] = {parentResults.master.value(), offset, parentTransformStorage, parentRoleStorage};

        // SPDLOG_DEBUG("CACHE STORE for entity {}: parentEntity={}, parentTransform={}, parentRole={}",
        //             static_cast<int>(selfEntity),
        //             static_cast<int>(selfRole.master),
        //             (void*)parentTransformStorage,
        //             (void*)parentRoleStorage);

        // Fill return
        toReturn.master = parentResults.master;
        toReturn.offset = offset;

        return toReturn;
    }


    auto SyncPerfectlyToMaster(entt::entity e, entt::entity parent, Transform &selfTransform, InheritedProperties &selfRole, Transform &parentTransform, InheritedProperties &parentRole) -> void
    {
        auto registry = &globals::registry;
        
        // ZoneScopedN("SyncPerfectlyToMaster");

        // copy all actual values from parent
        selfTransform.setActualX(parentTransform.getActualX());
        selfTransform.setActualY(parentTransform.getActualY());
        selfTransform.setActualW(parentTransform.getActualW());
        selfTransform.setActualH(parentTransform.getActualH());
        selfTransform.setActualRotation(parentTransform.getActualRotation());
        selfTransform.setActualScale(parentTransform.getActualScale());

        // copy visual values, taking width and height into account
        selfTransform.setVisualX(
            parentTransform.getVisualX() + (0.5f * (1 - parentTransform.getVisualW() / parentTransform.getActualW()) * selfTransform.getActualW()));
        selfTransform.setVisualY(parentTransform.getVisualY());
        selfTransform.setVisualW(parentTransform.getVisualW());
        selfTransform.setVisualH(parentTransform.getVisualH());
        selfTransform.setVisualRotation(parentTransform.getVisualR());
        selfTransform.setVisualScale(parentTransform.getVisualScale());

        selfTransform.reduceXToZero = parentTransform.reduceXToZero;
        selfTransform.reduceYToZero = parentTransform.reduceYToZero;
    }

    
// Function to generate a smoothly ramped, exponentially tapered oscillation with reversed time progression
double taperedOscillation(double t, double T, double A, double freq, double D) {
    double timeRemaining = T - t; // Reverse time
    double ramp = std::sin(PI * timeRemaining / T);  // Smooth ramp from 1 to 0
    double decay = std::exp(-D * (timeRemaining / T)); // Exponential tapering
    return A * ramp * decay * std::sin(2 * PI * freq * timeRemaining);
}


    auto UpdateDynamicMotion(entt::entity e, float dt, Transform &selfTransform) -> void
    {

        auto &dynamicMotion = selfTransform.dynamicMotion;

        if (!selfTransform.dynamicMotion) // LATER: handle no updating if dynamicMotion is not active? Selective disabling for children, for example
            return;

        if (dynamicMotion->endTime < GetTime())
        {
            // SPDLOG_DEBUG("Dynamic motion ended");
            dynamicMotion = std::nullopt;
            return;
        }

        auto amplitude = dynamicMotion->scaleAmount;
        auto oscillation = sin(51.2 * (GetTime() - dynamicMotion->startTime));
        float easing = pow(std::max(0.0, ((dynamicMotion->endTime - GetTime()) / (dynamicMotion->endTime - dynamicMotion->startTime))), 2.8f);

        dynamicMotion->scale = amplitude * oscillation * easing;

        amplitude = dynamicMotion->rotationAmount;
        oscillation = sin(46.3 * (GetTime() - dynamicMotion->startTime));
        // Use a higher exponent for rotation, making it even snappier
        easing = pow(std::max(0.0, ((dynamicMotion->endTime - GetTime()) / (dynamicMotion->endTime - dynamicMotion->startTime))), 2.1f);
        dynamicMotion->rotation = amplitude * oscillation * easing;
    }
     

    /**
     *  amount controls how much the object shrinks initially and how strongly it oscillates in size over time. 
        Higher amount means more exaggerated size and rotation motion.
        Motion gradually fades within 0.4 seconds.

        If amount = 1, the object will fluctuate strongly.
        If amount = 0.5, the object will fluctuate moderately.
        If amount = 0, the object won't fluctuate at all.

        rotationAmount (which is auto-set to ±32 * amount if 0) controls the maximum rotation oscillation.
        If rotationAmount is not explicitly provided (i.e., 0), it is randomly assigned either positive or negative.
        The magnitude is scaled by amount, which represents the overall intensity of the dynamic motion.

        When amount = 0:
            rotationAmount can be 0 (no rotation at all).

        When amount = 1:
            rotationAmount can be randomly -34 or 34. (degrees)

        If the function is called with an explicit rotationAmount (not 0), then it can be any float value, but it is assumed that reasonable values fall within [-34, 34].
     */
    auto InjectDynamicMotion(entt::registry *registry, entt::entity e, float amount, float rotationAmount) -> void
    {
        SPDLOG_DEBUG("Injecting dynamic motion for entity {} with amount: {}, rotationAmount: {}", static_cast<int>(e), amount, rotationAmount);
        AssertThat(amount >= 0 && amount <= 1, Is().EqualTo(true));
        
        float startTime = GetTime();
        float endTime = startTime + 0.4f; // 0.4 seconds

        auto &selfTransform = registry->get<Transform>(e);
        auto &dynamicMotion = selfTransform.dynamicMotion;

        if (rotationAmount == 0)
        {
            if (GetRandomValue(0, 1) == 0)
            {
                rotationAmount = 34.f * amount; // rotation in degrees
            }
            else
            {
                rotationAmount = -34.f * amount;
            }
        }

        if (dynamicMotion)
        {
            dynamicMotion->startTime = startTime;
            dynamicMotion->endTime = endTime;
            dynamicMotion->scaleAmount = amount;
            dynamicMotion->rotationAmount = rotationAmount;
        }
        else
        {
            dynamicMotion = Transform::DynamicMotion{.startTime = startTime, .endTime = endTime, .scaleAmount = amount, .rotationAmount = rotationAmount};
        }
        selfTransform.setVisualScale(1 - 0.7 * amount);
    }

    // Computes shadow offset based on the entity's X-position in relation to the center of the room.
    auto UpdateParallaxCalculations(entt::registry *registry, entt::entity e) -> void
    {

        if (!registry->valid(globals::gameWorldContainerEntity))
        {
            return;
        }
        auto &gameWorldTransform = registry->get<Transform>(globals::gameWorldContainerEntity);

        auto &node = registry->get<GameObject>(e);
        auto &transform = registry->get<Transform>(e);

        node.shadowDisplacement->x = ((transform.getActualX() + transform.getActualW() / 2) - (gameWorldTransform.getActualX() + gameWorldTransform.getActualW() / 2)) / (gameWorldTransform.getActualW() / 2) * 1.5f;
    }

    auto ConfigureAlignment(entt::registry *registry, entt::entity e, bool isChild, entt::entity parent, std::optional<InheritedProperties::Sync> xy, std::optional<InheritedProperties::Sync> wh, std::optional<InheritedProperties::Sync> rotation, std::optional<InheritedProperties::Sync> scale, std::optional<int> alignment, std::optional<Vector2> offset) -> void
    {

        auto &role = registry->get<InheritedProperties>(e);
        auto &transform = registry->get<Transform>(e);

        if (isChild)
        {
            auto roleParam = InheritedProperties::Type::RoleInheritor;
            auto xyBond = xy.value_or(InheritedProperties::Sync::Weak);
            auto whBond = wh.value_or(role.size_bond.value_or(InheritedProperties::Sync::Weak));
            auto rBond = rotation.value_or(role.rotation_bond.value_or(InheritedProperties::Sync::Weak));
            auto scaleBond = scale.value_or(role.scale_bond.value_or(InheritedProperties::Sync::Weak));

            AssignRole(registry, e, roleParam, parent, xyBond, whBond, rBond, scaleBond);
        }

        if (alignment)
        {
            role.flags->alignment = alignment.value();
        }

        if (offset)
        {
            role.flags->extraAlignmentFinetuningOffset = offset.value();
        }
    }

    auto AssignRole(entt::registry *registry, entt::entity e, std::optional<InheritedProperties::Type> roleType, entt::entity parent, std::optional<InheritedProperties::Sync> xy, std::optional<InheritedProperties::Sync> wh, std::optional<InheritedProperties::Sync> rotation, std::optional<InheritedProperties::Sync> scale, std::optional<Vector2> offset) -> void
    {

        // AssertThat(registry->valid(parent), Is().EqualTo(true));
        // AssertThat(registry.any_of<InheritedProperties>(parent), Is().EqualTo(true));

        auto &role = registry->get<InheritedProperties>(e);
        auto &transform = registry->get<Transform>(e);

        if (roleType)
        {
            role.role_type = roleType.value();
        }
        if (offset)
        {
            SPDLOG_DEBUG("AssignRole called for entity {} with offset x: {}, y: {}", static_cast<int>(e), offset->x, offset->y);
            role.offset = offset.value();
        }

        role.master = parent;

        if (xy)
        {
            role.location_bond = xy.value();
        }
        if (wh)
        {
            role.size_bond = wh.value();
        }
        if (rotation)
        {
            role.rotation_bond = rotation.value();
        }
        if (scale)
        {
            role.scale_bond = scale.value();
        }

        if (role.role_type == InheritedProperties::Type::RoleRoot)
        {
            role.master = entt::null;
        }
    }
    
    // // store in full-owning group for efficiency
    // static auto transformSpringGroup = globals::registry.group<Spring>();
    
    // auto GetActualX(decltype(transformSpringGroup) &group, Transform &transform) -> float
    // {
    //     auto actualX = group.get<Spring>(transform.x).targetValue;
        
    //     return actualX;
    // }

    auto UpdateAllTransforms(entt::registry *registry, float dt) -> void
    {
        // ZoneScopedN("Update all transforms");
        
        // updateTransformCacheForAllTransforms();
        
        static auto group = registry->group<InheritedProperties>(entt::get<Transform, GameObject>);
        
        group.each([dt](entt::entity e, InheritedProperties &role, Transform &transform, GameObject &node) {
            UpdateTransform(e, dt, transform, role, node);
        });
        
        
        // auto test = GetActualX(transformSpringGroup, registry->get<Transform>(globals::gameWorldContainerEntity));
        // SPDLOG_DEBUG("Game world container actual X: {}", test);
    }

    // // these are used in frame calculations to determine if the transform needs to be updated
    // struct FrameCalculation {
    //     int lastUpdatedFrame = 0; // the last frame the transform was updated on (FRAME.MOVE)
    //     entt::entity oldParent = entt::null;
    //     Vector2 oldParentOffset = {0, 0}; // FRAME.OLD_MAJOR.offset
    //     entt::entity currentParent = entt::null;
    //     Vector2 currentParentOffset = {0, 0}; // FRAME.MAJOR.offset
    //     bool stationary = false; // if true, the transform will not move
    //     bool alignmentChanged = false; // if true, the alignment has changed
    // };
    auto UpdateTransform(entt::entity e, float dt, Transform &transform, InheritedProperties &role, GameObject &node) -> void
    {
        // ZoneScopedN("UpdateTransform");
        
        auto registry = &globals::registry;

        if (transform.frameCalculation.lastUpdatedFrame >= main_loop::mainLoop.frame && transform.frameCalculation.alignmentChanged == false)
        {
            // SPDLOG_DEBUG("Transform already updated this frame");
            return; // already updated this frame
        }

        // cache some values here
        transform.frameCalculation.oldMasterCache = transform.frameCalculation.currentMasterCache;
        transform.frameCalculation.currentMasterCache.reset();
        transform.frameCalculation.lastUpdatedFrame = main_loop::mainLoop.frame; // save frame counter

        //FIXME: this is a hacky fix
        // if (node.ignoresPause == false && globals::isGamePaused)
        // {
        //     return; // don't move if paused
        // }
        
        auto [parentTransform, parentRole, parentNode] = registry->try_get<Transform, InheritedProperties, GameObject>(role.master);
        
        auto selfXSpring = transform.getXSpring();
        auto selfYSpring = transform.getYSpring();
        auto selfRSpring = transform.getRSpring();
        auto selfSSpring = transform.getSSpring();
        auto selfWSpring = transform.getWSpring();
        auto selfHSpring = transform.getHSpring();

        AlignToMaster(registry, e);

        node.debug.calculationsInProgress = false;

        if (role.role_type == InheritedProperties::Type::RoleCarbonCopy)
        {
            // ZoneScopedN("RoleCarbonCopy");
            if (registry->valid(role.master))
            {
                SyncPerfectlyToMaster(e, role.master, transform, role, *parentTransform, *parentRole);
            }
        }

        else if (role.role_type == InheritedProperties::Type::RoleInheritor)
        {
            // ZoneScopedN("RoleInheritor");
            if (registry->valid(role.master) && e != role.master) // don't move with self please
            {
                
                // recursively move on parent
                if (parentTransform->frameCalculation.lastUpdatedFrame < main_loop::mainLoop.frame ||transform.frameCalculation.alignmentChanged == true)
                {
                    UpdateTransform(role.master, dt, *parentTransform, *parentRole, *parentNode);
                }
                
                
                
                transform.frameCalculation.stationary = parentTransform->frameCalculation.stationary;
                
                // if layered displacement is different, update it, set stationary to false
                if (node.layerDisplacement &&
                    !Vector2Equals(node.layerDisplacement.value(), node.layerDisplacementPrev.value_or(Vector2{0, 0})))

                {
                    node.layerDisplacementPrev = node.layerDisplacement;
                    transform.frameCalculation.stationary = false;
                }
                

                if ((transform.frameCalculation.stationary == false) || (transform.frameCalculation.alignmentChanged) || (transform.dynamicMotion) || (role.location_bond == InheritedProperties::Sync::Weak) || (role.rotation_bond == InheritedProperties::Sync::Weak))
                {

                    node.debug.calculationsInProgress = true; 

                    MoveWithMaster(e, dt, transform, role, node);
                }
            }
            
        }

        else if (role.role_type == InheritedProperties::Type::PermanentAttachment)
        {
            // ZoneScopedN("RolePermanentAttachment");
            // ignore sync bonds
            
            if (registry->valid(role.master))
            {
                // recursively move on parent
                if (parentTransform->frameCalculation.lastUpdatedFrame < main_loop::mainLoop.frame)
                {
                    UpdateTransform(role.master, dt, *parentTransform, *parentRole, *parentNode);
                }
            }

            // Fully inherit parent's stationary state
            transform.frameCalculation.stationary = parentTransform->frameCalculation.stationary;

            float parentRotationAngle = parentTransform->getVisualRWithDynamicMotionAndXLeaning();

            // convert to radians
            float angle = parentRotationAngle * DEG2RAD;

            // parent center
            float parentCenterX = parentTransform->getVisualX() + parentTransform->getVisualW() * 0.5;
            float parentCenterY = parentTransform->getVisualY() + parentTransform->getVisualH() * 0.5;

            // child's offset relative to the parent's center
            float childOffsetX = role.offset->x - parentTransform->getVisualW() * 0.5 + transform.getVisualW() * 0.5;
            float childOffsetY = role.offset->y - parentTransform->getVisualH() * 0.5 + transform.getVisualH() * 0.5;

            // apply rotation around the parent's center
            float rotatedX = childOffsetX * cos(angle) - childOffsetY * sin(angle);
            float rotatedY = childOffsetX * sin(angle) + childOffsetY * cos(angle);

            // convert back to absolute coordinates
            float absoluteX = parentCenterX + rotatedX;
            float absoluteY = parentCenterY + rotatedY;

            // adjust for child's size
            absoluteX -= transform.getVisualW() * 0.5;
            absoluteY -= transform.getVisualH() * 0.5;

            // child inherits parent's rotation
            transform.setVisualRotation(parentRotationAngle);
            transform.setActualRotation(parentRotationAngle);

            transform.setVisualX(absoluteX);
            transform.setVisualY(absoluteY);
            transform.setActualX(absoluteX);
            transform.setActualY(absoluteY);
        }

        else if (role.role_type == InheritedProperties::Type::RoleRoot)
        {
            // ZoneScopedN("RoleRoot");
            transform.frameCalculation.stationary = true;
            UpdateDynamicMotion(e, dt, transform);
            
            
            UpdateLocation(e, dt, transform, selfXSpring, selfYSpring);
            UpdateSize(e, dt, transform, selfWSpring, selfHSpring);
            
            UpdateRotation(e, dt, transform, selfRSpring, selfXSpring);
            UpdateScale(e, dt, transform, selfSSpring);
            UpdateParallaxCalculations(registry, e);
        }

        // reset alignment change
        transform.frameCalculation.alignmentChanged = false;

        node.state.isColliding = false; // clear flag
        
        // call custom update function if it exists
        if (node.methods.update) node.methods.update(*registry, e, dt);
    }

    auto SnapTransformValues(entt::registry *registry, entt::entity e, float x, float y, float w, float h) -> void
    {
        auto &transform = registry->get<Transform>(e);
        auto &springX = transform.getXSpring();
        auto &springY = transform.getYSpring();
        auto &springW = transform.getWSpring();
        auto &springH = transform.getHSpring();
        auto &springR = transform.getRSpring();
        auto &springS = transform.getSSpring();

        springX.targetValue = x;
        springY.targetValue = y;
        springW.targetValue = w;
        springH.targetValue = h;

        springX.value = x;
        springY.value = y;
        springW.value = w;
        springH.value = h;

        springX.velocity = 0;
        springY.velocity = 0;
        springR.velocity = 0;
        springS.velocity = 0;

        springR.targetValue = transform.getActualRotation();
        springS.targetValue = transform.getActualScale();

        UpdateParallaxCalculations(registry, e);
    }

    auto SnapVisualTransformValues(entt::registry *registry, entt::entity e) -> void
    {
        auto &transform = registry->get<Transform>(e);
        auto &springX = transform.getXSpring();
        auto &springY = transform.getYSpring();
        auto &springW = transform.getWSpring();
        auto &springH = transform.getHSpring();
        auto &springR = transform.getRSpring();
        auto &springS = transform.getSSpring();

        springX.value = springX.targetValue;
        springY.value = springY.targetValue;
        springW.value = springW.targetValue;
        springH.value = springH.targetValue;

        springX.velocity = 0;
        springY.velocity = 0;
        springW.velocity = 0;
        springH.velocity = 0;
    }
    
    // Call this  method every update loop to keep transform values updated.
    void updateTransformCacheForAllTransforms() {
        
        auto view = globals::registry.view<Transform>();
        
        // owning group of springs
        
        for (auto e : view) {
            auto &transform = globals::registry.get<Transform>(e);
            
            auto &springX = globals::registry.get<Spring>(transform.x);
            auto &springY = globals::registry.get<Spring>(transform.y);
            auto &springW = globals::registry.get<Spring>(transform.w);
            auto &springH = globals::registry.get<Spring>(transform.h);
            auto &springR = globals::registry.get<Spring>(transform.r);
            auto &springS = globals::registry.get<Spring>(transform.s);
            
            transform.cachedActualX = springX.targetValue;
            transform.cachedActualY = springY.targetValue;
            transform.cachedActualW = springW.targetValue;
            transform.cachedActualH = springH.targetValue;
            transform.cachedActualR = springR.targetValue;
            transform.cachedActualS = springS.targetValue;
            
            transform.cachedVisualX = springX.value;
            transform.cachedVisualY = springY.value;
            transform.cachedVisualW = springW.value;
            transform.cachedVisualH = springH.value;
            transform.cachedVisualRWithDynamicMotionAndXLeaning = springR.value + transform.rotationOffset;
            transform.cachedVisualS = springS.value;
            transform.cachedVisualR = springR.value;
            
            
            // cachedVisualSWithHoverAndDynamicMotionReflected
            float base = transform.cachedVisualS;
            if (globals::registry.any_of<GameObject>(e))
            {
                auto &gameObj = globals::registry.get<GameObject>(e);
                if (gameObj.state.isBeingHovered && gameObj.state.enlargeOnHover)
                {
                    base *= 1.f + COLLISION_BUFFER_ON_HOVER_PERCENTAGE; // increase scale when hovered
                }
                if (gameObj.state.isBeingDragged && gameObj.state.enlargeOnDrag)
                {
                    base += COLLISION_BUFFER_ON_HOVER_PERCENTAGE * 2; // increase scale when dragged
                }
            }

            float added = (transform.dynamicMotion ? transform.dynamicMotion->scale : 0);

            transform.cachedVisualSWithHoverAndDynamicMotionReflected =  base + added;
            
        }
            
    }
    

    auto DrawBoundingBoxAndDebugInfo(entt::registry *registry, entt::entity e, std::shared_ptr<layer::Layer> layer) -> void
    {
        // ZoneScopedN("DrawBoundingBoxAndDebugInfo");
        // if (debugMode == false)
        //     return;

        auto &node = registry->get<GameObject>(e);
        node.state.isUnderOverlay = globals::under_overlay; // LATER: not sure why this is here. move elsewhere?

        float currentScreenWidth = GetScreenWidth() * 1.0f;
        float currentScreenHeight = GetScreenHeight() * 1.0f;

        auto &transform = registry->get<Transform>(e);
        auto &role = registry->get<InheritedProperties>(e);
        auto &springX = transform.getXSpring();
        auto &springY = transform.getYSpring();
        auto &springW = transform.getWSpring();
        auto &springH = transform.getHSpring();
        auto &springR = transform.getRSpring();
        auto &springS = transform.getSSpring();
        
        // check if buffer is full and if so, flush batch
        
        if (node.debug.debugText)
        {
            // does debug text contain "uibox"?
            // if (node.debug.debugText.value().find("UIBox") != std::string::npos)
            // {
            //     SPDLOG_DEBUG("Debug text contains 'uibox' for entity {}", static_cast<int>(e));
            //     SPDLOG_DEBUG("UIbox location: x: {}, y: {}, w: {}, h: {}", 
            //                 transform.getVisualX(), 
            //                 transform.getVisualY(), 
            //                 transform.getVisualW(), 
            //                 transform.getVisualH());
                            
            // }
        }

        layer::QueueCommand<layer::CmdPushMatrix>(layer, [](layer::CmdPushMatrix *cmd) {
            // Push the current matrix onto the stack
        }, 100); // always on top of the stack


        layer::QueueCommand<layer::CmdTranslate>(layer, [x = transform.getVisualX() + transform.getVisualW() * 0.5, y = transform.getVisualY() + transform.getVisualH() * 0.5](layer::CmdTranslate *cmd) {
            cmd->x = x;
            cmd->y = y;
        }, 100);

        layer::QueueCommand<layer::CmdScale>(layer, [scaleX = transform.getVisualScaleWithHoverAndDynamicMotionReflected(), scaleY = transform.getVisualScaleWithHoverAndDynamicMotionReflected()](layer::CmdScale *cmd) {
            cmd->scaleX = scaleX;
            cmd->scaleY = scaleY;
        }, 100);

        layer::QueueCommand<layer::CmdRotate>(layer, [rotation = transform.getVisualR() + transform.rotationOffset](layer::CmdRotate *cmd) {
            cmd->angle = rotation;
        }, 100);

        layer::QueueCommand<layer::CmdTranslate>(layer, [x = -transform.getVisualW() * 0.5, y = -transform.getVisualH() * 0.5](layer::CmdTranslate *cmd) {
            cmd->x = x;
            cmd->y = y;
        }, 100);

        auto scale = 1.0f;
        if (registry->any_of<ui::UIConfig>(e))
        {
            auto &uiConfig = registry->get<ui::UIConfig>(e);
            scale = uiConfig.scale.value_or(1.0f);
        }

        if (node.debug.debugText)
        {
            bool bumpTextUp = false;
            // does debug text contain "uibox"?
            if (registry->any_of<ui::UIBoxComponent>(e))
            {
                // if so, bump text up
                bumpTextUp = true;
            }
            float textWidth = MeasureText(node.debug.debugText.value().c_str(), 15 * scale);
            layer::QueueCommand<layer::CmdTextPro>(layer, [text = node.debug.debugText.value(), font = GetFontDefault(), textWidth, scale, visualW = transform.getVisualW(), visualH = transform.getVisualH(), bumpTextUp](layer::CmdTextPro *cmd) {
                cmd->text = text.c_str();
                cmd->font = font;
                cmd->x = visualW / 2 - textWidth / 2;
                cmd->y = bumpTextUp? - visualH * 0.1f : - visualH * 0.05f;
                cmd->origin = {0, 0};
                cmd->rotation = 0;
                cmd->fontSize = 15 * scale;
                cmd->spacing = 1.0f;
                cmd->color = WHITE;
            }, 100);
        }
        else {
            // If ui, get ui type + entity number
            // if not ui, just use "entity X"
            std::string debugText = "Entity " + std::to_string(static_cast<int>(e));
            if (registry->any_of<ui::UIConfig>(e))
            {
                auto &uiConfig = registry->get<ui::UIConfig>(e);
                debugText = fmt::format("{} {}", magic_enum::enum_name<ui::UITypeEnum>(uiConfig.uiType.value_or(ui::UITypeEnum::NONE)), debugText);
            }
            float textWidth = MeasureText(debugText.c_str(), 15 * scale);
            layer::QueueCommand<layer::CmdTextPro>(layer, [debugText, textWidth, scale, visualW = transform.getVisualW(), visualH = transform.getVisualH()](layer::CmdTextPro *cmd) {
                cmd->text = debugText.c_str();
                cmd->font = GetFontDefault();
                cmd->x = visualW / 2 - textWidth / 2;
                cmd->y = - visualH * 0.05f;
                cmd->origin = {0, 0};
                cmd->rotation = 0;
                cmd->fontSize = 15 * scale;
                cmd->spacing = 1.0f;
                cmd->color = WHITE;
            }, 100);
        }

        float lineWidth = 1;
        if (node.state.isBeingFocused)
        {
            lineWidth = 3;
        }

        Color lineColor = RED;
        if (node.state.isColliding)
        {
            lineColor = GREEN;
        }
        else
        {
            lineColor = RED;
        }

        if (node.state.isBeingFocused)
        {
            lineColor = GOLD;
            lineWidth = 10;
        }

        // if (node.debug.calculationsInProgress)
        // {
        //     lineColor = BLUE;
        //     lineWidth = 15;
        // }
        layer::QueueCommand<layer::CmdDrawRectangleLinesPro>(layer, [width = transform.getVisualW(), height = transform.getVisualH(), lineThickness = lineWidth, color = lineColor](layer::CmdDrawRectangleLinesPro *cmd) {
            cmd->offsetX = 0;
            cmd->offsetY = 0;
            cmd->size = Vector2{width, height};
            cmd->lineThickness = lineThickness;
            cmd->color = color;
        }, 100);
        
        
        // draw emboss effect rect
        auto *uiConfig = registry->try_get<ui::UIConfig>(e);
        if (uiConfig && uiConfig->emboss)
        {
            float embossHeight = uiConfig->emboss.value() * uiConfig->scale.value();
            layer::QueueCommand<layer::CmdDrawRectanglePro>(layer, [x = 0, y = transform.getActualH(), width = transform.getActualW(), height = embossHeight](layer::CmdDrawRectanglePro *cmd) {
                cmd->offsetX = x;
                cmd->offsetY = y;
                cmd->size = Vector2{width, height};
                cmd->color = Fade(BLACK, 0.3f);
            }, 100);
        }

        layer::QueueCommand<layer::CmdPopMatrix>(layer, [](layer::CmdPopMatrix *cmd) {}, 100);
    }

    auto CalculateCursorPositionWithinFocus(entt::registry *registry, entt::entity e) -> Vector2
    {
        auto &transform = registry->get<Transform>(e);
        auto &role = registry->get<InheritedProperties>(e);
        auto &node = registry->get<GameObject>(e);

        if (registry->valid(node.container) == false)
        {
            return Vector2{0, 0};
        }

        auto &containerTransform = registry->get<Transform>(node.container);

        return Vector2{(float)(transform.getActualX() + transform.getActualW() * 0.5 + containerTransform.getActualX()), (float)(transform.getActualY() + transform.getActualH() * 0.5 + containerTransform.getActualY())};
    }

    auto CheckCollisionWithPoint(entt::registry *registry, entt::entity e, const Vector2 &point) -> bool
    {

        // spdlog::debug("Checking collision for entity: {}", static_cast<int>(e));
        // spdlog::debug("Point: ({}, {})", point.x, point.y);

        auto &role = registry->get<InheritedProperties>(e);
        auto &node = registry->get<GameObject>(e);

        Transform *transform;

        if (node.collisionTransform)
        {
            transform = &registry->get<Transform>(node.collisionTransform.value());
            // spdlog::debug("Using collision transform for entity {}.", static_cast<int>(e));
        }
        else
        {
            transform = &registry->get<Transform>(e);
            // spdlog::debug("Using default transform for entity {}.", static_cast<int>(e));
        }

        // spdlog::debug("Transform -> X: {}, Y: {}, W: {}, H: {}, R: {}",
        //               transform->getActualX(), transform->getActualY(),
        //               transform->getActualW(), transform->getActualH(),
        //               transform->getActualR());

        // Collision only if node has a valid container
        if (!registry->valid(node.container))
        {
            // spdlog::debug("Entity {} has no valid container. Collision check aborted.", static_cast<int>(e));
            return false;
        }

        Vector2 tempPoint{};
        Vector2 tempTranslation{};
        float tempRotationCos{};
        float tempRotationSin{};

        float collisionBufferX = 0,
                collisionBufferY = 0;
        if (node.state.isBeingHovered)
        {
            // let collision be a little forgiving when hovered, so hovered state ends later than usual
            collisionBufferX = transform->getHoverCollisionBufferX();
            collisionBufferY = transform->getHoverCollisionBufferY();
            // spdlog::debug("Entity {} is hovered. Applying collision buffer: {}", static_cast<int>(e), collisionBuffer);
        }
        if (node.state.isBeingDragged) {
            collisionBufferX += transform->getHoverCollisionBufferX();
            collisionBufferY += transform->getHoverCollisionBufferY();
        }

        tempPoint.x = point.x;
        tempPoint.y = point.y;

        // Valid container that is not self
        if (registry->valid(node.container) && node.container != e)
        {
            auto &containerTransform = registry->get<Transform>(node.container);
            // spdlog::debug("Container Transform -> X: {}, Y: {}, W: {}, H: {}, R: {}",
            //               containerTransform.getActualX(), containerTransform.getActualY(),
            //               containerTransform.getActualW(), containerTransform.getActualH(),
            //               containerTransform.getActualR());

            // Negligible rotation for container
            if (containerTransform.getActualRotation() < 0.0001f && containerTransform.getActualRotation() > -0.0001f)
            {
                // spdlog::debug("Container rotation is negligible.");
                tempTranslation.x = -containerTransform.getActualW() * 0.5;
                tempTranslation.y = -containerTransform.getActualH() * 0.5;

                ui::util::pointTranslate(tempPoint, tempTranslation);
                ui::util::pointRotate(tempPoint, containerTransform.getActualRotation());

                tempTranslation.x = containerTransform.getActualW() * 0.5 - containerTransform.getActualX();
                tempTranslation.y = containerTransform.getActualH() * 0.5 - containerTransform.getActualY();

                ui::util::pointTranslate(tempPoint, tempTranslation);
                // spdlog::debug("Translated point after container adjustments: ({}, {})", tempPoint.x, tempPoint.y);
            }
            else
            {
                // Significant rotation for container
                tempTranslation.x = containerTransform.getActualX();
                tempTranslation.y = containerTransform.getActualY();
                ui::util::pointTranslate(tempPoint, tempTranslation);
                // spdlog::debug("Applied translation for rotated container. Point now at: ({}, {})", tempPoint.x, tempPoint.y);
            }
        }

        if (std::abs(transform->getActualRotation()) < 0.1)
        {
            // spdlog::debug("Non-significant rotation detected for entity {}. Applying rotation checks.", static_cast<int>(e));

            if (tempPoint.x >= transform->getActualX() - collisionBufferX && tempPoint.y >= transform->getActualY() - collisionBufferY && tempPoint.x <= transform->getActualX() + transform->getActualW() + collisionBufferX && tempPoint.y <= transform->getActualY() + transform->getActualH() + collisionBufferY)
            {
                // spdlog::debug("Point is inside non-rotated bounding box. Collision detected.");
                return true;
            }
            else
            {
                // spdlog::debug("Point is outside non-rotated bounding box. No collision.");
                return false;
            }
        }

        // Rotation is significant. We need to rotate the point for accurate collision checking
        tempRotationCos = std::cos(transform->getActualRotation() + PI / 2);
        tempRotationSin = std::sin(transform->getActualRotation() + PI / 2);

        tempPoint.x = tempPoint.x - (transform->getActualX() + 0.5 * transform->getActualW());
        tempPoint.y = tempPoint.y - (transform->getActualY() + 0.5 * transform->getActualH());

        tempTranslation.x = tempPoint.y * tempRotationCos - tempPoint.x * tempRotationSin;
        tempTranslation.y = tempPoint.y * tempRotationSin + tempPoint.x * tempRotationCos;

        tempPoint.x = tempTranslation.x + (transform->getActualX() + 0.5 * transform->getActualW());
        tempPoint.y = tempTranslation.y + (transform->getActualY() + 0.5 * transform->getActualH());

        // spdlog::debug("Rotated Point -> X: {}, Y: {}", tempPoint.x, tempPoint.y);

        if (tempPoint.x >= transform->getActualX() - collisionBufferX && tempPoint.y >= transform->getActualY() - collisionBufferY && tempPoint.x <= transform->getActualX() + transform->getActualW() + collisionBufferX && tempPoint.y <= transform->getActualY() + transform->getActualH() + collisionBufferY)
        {
            // spdlog::debug("Point is inside rotated bounding box. Collision detected.");
            return true;
        }
        else
        {
            // spdlog::debug("Point is outside rotated bounding box. No collision.");
            return false;
        }
    }
    
    /**
     * @brief Finds all entities at a specific point in the world.
     * 
     * This function performs a broadphase query using a quadtree to find candidate entities
     * near the specified point. It then filters the results by checking precise collision
     * with the point. The resulting entities are sorted by their zIndex, if they have a 
     * LayerOrderComponent, with entities lacking a zIndex placed at the end.
     * 
     * @param point The point in world coordinates to search for entities.
     * @return A sorted vector of entities at the specified point, from lowest to highest zIndex.
     *         Entities without a zIndex are placed after those with a zIndex.
     */
    std::vector<entt::entity> FindAllEntitiesAtPoint(const Vector2& mouseScreen, Camera2D * camera)
    {
        using namespace quadtree;
        constexpr float pointBoxSize = 1.0f;

        // ——— 1) UI pass (screen-space) ———
        // Build a tiny AABB around the mouse in screen coords
        Box<float> uiQuery{
            { mouseScreen.x - 0.5f * pointBoxSize,
            mouseScreen.y - 0.5f * pointBoxSize },
            { pointBoxSize, pointBoxSize }
        };

        std::vector<entt::entity> hits;
        hits.reserve(32);

        // Only query if inside screen bounds (you can adjust this check if needed)
        if (globals::uiBounds.contains(uiQuery))
        {
            auto uiCands = globals::quadtreeUI.query(uiQuery);
            for (auto e : uiCands)
            {
                // cursor is never in the UI quadtree, but if you store it for some reason:
                if (e == globals::cursor) continue;

                // precise, rotated‐AABB / SAT test in screen‐space
                if (transform::CheckCollisionWithPoint(&globals::registry, e, mouseScreen))
                    hits.push_back(e);
            }
        }

        // ——— 2) World pass (world-space) ———
        // Convert the screen‐space mouse to world‐space
        ::Vector2 mouseWorld = camera ? GetScreenToWorld2D(mouseScreen, *camera) : mouseScreen;
        Box<float> worldQuery{
            { mouseWorld.x - 0.5f * pointBoxSize,
            mouseWorld.y - 0.5f * pointBoxSize },
            { pointBoxSize, pointBoxSize }
        };

        if (globals::worldBounds.contains(worldQuery))
        {
            auto worldCands = globals::quadtreeWorld.query(worldQuery);
            for (auto e : worldCands)
            {
                // again, cursor is not in quadtreeWorld
                // but if you ever put it there, you can skip it:
                if (e == globals::cursor) continue;

                if (transform::CheckCollisionWithPoint(&globals::registry, e, mouseWorld))
                    hits.push_back(e);
            }
        }

        // ——— 3) Sort by your existing layer/tree order ———
        struct OrderInfo {
            bool hasOrder = false;
            entt::entity parentBox = entt::null;
            int treeOrder  = 0;
            int layerOrder = 0;
        };
        auto getInfo = [&](entt::entity e){
            OrderInfo info;
            auto &r = globals::registry;
            if (!r.valid(e)) return info;
            if (!r.all_of<transform::GameObject, transform::InheritedProperties>(e))
                return info;

            // detect UI or world by presence of UIElementComponent
            auto uiElem = r.try_get<ui::UIElementComponent>(e);
            bool hasSortComp = r.any_of<transform::TreeOrderComponent, layer::LayerOrderComponent>(e);
            if (!hasSortComp) return info;

            info.hasOrder = true;
            if (uiElem) info.parentBox = uiElem->uiBox;
            if (!r.valid(info.parentBox)) return info;

            if (auto toc = r.try_get<transform::TreeOrderComponent>(e))
                info.treeOrder = toc->order;
            if (auto loc = r.try_get<layer::LayerOrderComponent>(info.parentBox))
                info.layerOrder = loc->zIndex;

            return info;
        };

        // cache OrderInfo for each hit
        std::unordered_map<entt::entity, OrderInfo> infoMap;
        infoMap.reserve(hits.size());
        for (auto e : hits) {
            infoMap.emplace(e, getInfo(e));
        }

        // final sort
        std::sort(hits.begin(), hits.end(),
            [&](entt::entity a, entt::entity b) {
                auto &ia = infoMap[a];
                auto &ib = infoMap[b];

                // entities without any sorting info go last
                if (ia.hasOrder != ib.hasOrder)
                    return ia.hasOrder;

                // then by layerOrder
                if (ia.layerOrder != ib.layerOrder)
                    return ia.layerOrder < ib.layerOrder;

                // then by treeOrder
                return ia.treeOrder < ib.treeOrder;
            }
        );

        return hits;
    }
    
    auto GetCollisionOrderInfo(entt::registry& registry, entt::entity e) -> CollisionOrderInfo {
        CollisionOrderInfo info{};
    
        if (!registry.valid(e)) return info;
    
        if (!registry.all_of<transform::GameObject, transform::InheritedProperties>(e)) return info;
    
        // const auto& node = registry.get<transform::GameObject>(e);
        // const auto& role = registry.get<transform::InheritedProperties>(e);
        // auto collisionOrderComponent = registry.try_get<transform::TreeOrderComponent>(e);
        auto uiElementComponent = registry.try_get<ui::UIElementComponent>(e);
        
        if (registry.any_of<transform::TreeOrderComponent, layer::LayerOrderComponent>(e)) {
            info.hasCollisionOrder = true;
        } else {
            info.hasCollisionOrder = false;
        }
        if (!info.hasCollisionOrder) return info;
    
        info.parentBox = entt::null;
        if (uiElementComponent) {
            info.parentBox = uiElementComponent->uiBox;
        }
        if (!registry.valid(info.parentBox)) return info;
    
        // Get tree order from TreeOrderComponent
        if (registry.all_of<TreeOrderComponent>(e)) {
            info.treeOrder = registry.get<TreeOrderComponent>(e).order;
        }
    
        // Get layer order from parent box
        if (registry.all_of<layer::LayerOrderComponent>(info.parentBox)) {
            info.layerOrder = registry.get<layer::LayerOrderComponent>(info.parentBox).zIndex;
        }
    
        return info;
    }
    
    
    /**
     * @brief Finds the topmost entity at a given point in the world.
     *
     * This function queries the quadtree for entities near the specified point
     * and determines the topmost entity based on layer order and collision checks.
     *
     * @param point The point in world coordinates to check for entities.
     * @return An optional containing the topmost entity at the point, or std::nullopt
     *         if no entity is found or the point is out of bounds.
     *
     * The function performs the following steps:
     * 1. Creates a small bounding box around the point for querying the quadtree.
     * 2. Checks if the point is within the world bounds; returns std::nullopt if not.
     * 3. Queries the quadtree for entities within the bounding box.
     * 4. Sorts the entities by their layer order, with topmost entities last.
     * 5. Traverses the sorted entities from topmost to bottommost, checking for
     *    collision with the point.
     * 6. Returns the first entity that collides with the point, skipping the cursor entity.
     */
    std::optional<entt::entity> FindTopEntityAtPoint(const Vector2& point) {
        using namespace quadtree;
        // Make a tiny AABB around the point for the quadtree query
        constexpr float pointBoxSize = 1.0f;
        Box<float> queryBox = {
            {point.x - pointBoxSize * 0.5f, point.y - pointBoxSize * 0.5f},
            {pointBoxSize, pointBoxSize}
        };
    
        // Skip query if point is out of bounds
        if (!globals::worldBounds.contains(queryBox)) {
            return std::nullopt;
        }
    
        // Query quadtree for potential candidates
        auto results = globals::quadtreeWorld.query(queryBox);
    
        // Sort by layer order (topmost last)
        std::sort(results.begin(), results.end(), [](entt::entity a, entt::entity b) {
            bool hasA = globals::registry.any_of<layer::LayerOrderComponent>(a);
            bool hasB = globals::registry.any_of<layer::LayerOrderComponent>(b);
    
            if (hasA && hasB) {
                return globals::registry.get<layer::LayerOrderComponent>(a).zIndex <
                       globals::registry.get<layer::LayerOrderComponent>(b).zIndex;
            }
            return hasA < hasB; // Entities without LayerOrderComponent go first
        });
    
        // Traverse from topmost entity downward
        for (auto it = results.rbegin(); it != results.rend(); ++it) {
            entt::entity e = *it;
    
            if (e == globals::cursor) continue;
    
            if (transform::CheckCollisionWithPoint(&globals::registry, e, point)) {
                return e; // First topmost entity that matches
            }
        }
    
        return std::nullopt;
    }
    

    auto SetClickOffset(entt::registry *registry, entt::entity e, const Vector2 &point, bool trueForClickFalseForHover) -> void
    {
        Vector2 tempOffsetPoint{};
        Vector2 tempOffsetTranslation{};

        if (trueForClickFalseForHover == true)
        {
            // SPDLOG_DEBUG("Setting click offset for entity {}", static_cast<int>(e));
        }
        else
        {
            // SPDLOG_DEBUG("Setting hover offset for entity {}", static_cast<int>(e));
        }

        auto &transform = registry->get<Transform>(e);
        auto &role = registry->get<InheritedProperties>(e);
        auto &node = registry->get<GameObject>(e);

        auto &containerTransform = registry->get<Transform>(node.container);

        tempOffsetPoint.x = point.x;
        tempOffsetPoint.y = point.y;

        // Translate to the Middle of the Container
        tempOffsetTranslation.x = -containerTransform.getActualW() * 0.5;
        tempOffsetTranslation.y = -containerTransform.getActualH() * 0.5;
        ui::util::pointTranslate(tempOffsetPoint, tempOffsetTranslation);

        // Rotate Around the Container’s Center
        ui::util::pointRotate(tempOffsetPoint, containerTransform.getActualRotation());

        // Translate Back to Container Space
        tempOffsetTranslation.x = containerTransform.getActualW() * 0.5 - containerTransform.getActualX();
        tempOffsetTranslation.y = containerTransform.getActualH() * 0.5 - containerTransform.getActualY();
        ui::util::pointTranslate(tempOffsetPoint, tempOffsetTranslation);

        if (trueForClickFalseForHover == true)
        { // click
            node.clickOffset.x = tempOffsetPoint.x - transform.getActualX();
            node.clickOffset.y = tempOffsetPoint.y - transform.getActualY();
            SPDLOG_DEBUG("Click offset set to: ({}, {}) for entity {}", node.clickOffset.x, node.clickOffset.y, static_cast<int>(e));
        }
        else
        { // hover

            node.hoverOffset.x = tempOffsetPoint.x - transform.getActualX();
            node.hoverOffset.y = tempOffsetPoint.y - transform.getActualY();
            // SPDLOG_DEBUG("Hover offset set to: ({}, {}) for entity {}", node.hoverOffset.x, node.hoverOffset.y, static_cast<int>(e));
        }
    }

    // offset will be click offset set by click handler unless specified otherwise
    // transform must be set to draggable for this to work
    auto handleDefaultTransformDrag(entt::registry *registry, entt::entity e, std::optional<Vector2> offset) -> void
    {
        // TODO: some ui stuff like a pop-up that appears when you drag a node, shoudl handle in ui pass I make later, for node

        auto &node = registry->get<GameObject>(e);
        if (node.state.dragEnabled == false && offset.has_value() == false)
        {
            return;
        }

        auto &myContainerTransform = registry->get<Transform>(node.container);

        auto &cursorTransform = registry->get<Transform>(globals::cursor);

        Vector2 dragCursorTransform{};
        Vector2 dragCursorTranslation{};

        dragCursorTransform.x = cursorTransform.getActualX();
        dragCursorTransform.y = cursorTransform.getActualY();

        dragCursorTranslation.x = -myContainerTransform.getActualW() * 0.5;
        dragCursorTranslation.y = -myContainerTransform.getActualH() * 0.5;

        ui::util::pointTranslate(dragCursorTransform, dragCursorTranslation);

        ui::util::pointRotate(dragCursorTransform, myContainerTransform.getActualRotation());

        dragCursorTranslation.x = myContainerTransform.getActualW() * 0.5 - myContainerTransform.getActualX();
        dragCursorTranslation.y = myContainerTransform.getActualH() * 0.5 - myContainerTransform.getActualY();

        ui::util::pointTranslate(dragCursorTransform, dragCursorTranslation);

        if (!offset)
        {
            offset = node.clickOffset;
        }

        // SPDLOG_DEBUG("Handling drag. Drag offset: ({}, {})", offset->x, offset->y);

        // if it's ui and has a "drag but no drag move" feature enabled, don't move the transform
        if (registry->any_of<ui::UIConfig>(e))
        {
            auto &uiConfig = registry->get<ui::UIConfig>(e);
            if (uiConfig.noMovementWhenDragged)
            {
                return;
            }
        }

        auto &selfTransform = registry->get<Transform>(e);
        selfTransform.setActualX(dragCursorTransform.x - offset->x);
        selfTransform.setActualY(dragCursorTransform.y - offset->y);
        // REVIEW: new_alignment?
        selfTransform.frameCalculation.alignmentChanged = true;
        for (auto child : node.orderedChildren)
        {
            handleDefaultTransformDrag(registry, child, offset);
        }
        
        // custom drag logic
        if (node.methods.onDrag) {
            node.methods.onDrag(*registry, e);
        }
    }
    
    auto StartDrag(entt::registry *registry, entt::entity e, bool applyDefaultTransformBehavior) -> void
    {
        if (registry->valid(e) == false)
        {
            return;
        }
        
        if (applyDefaultTransformBehavior)
        {
            handleDefaultTransformDrag(registry, e);
        }
        
        if (registry->any_of<ui::UIConfig>(e) == false) return;
        
        auto &node = registry->get<GameObject>(e);
        auto &uiConfig = registry->get<ui::UIConfig>(e);
        
        if (!uiConfig.dPopup) return;
        
        // drag pop-up (for controlller drag, for instance) 
        if (node.children.find("d_popup") != node.children.end()) return;
        
        //TODO: generate and attach new UIbox for the pop-up, add as child, use dPopupConfig and the dPopup definition to create the uibox
        //TODO: in ui element's hover method, call the creaate tooltip method to generate the definition
        
    }
    
    // returns the right entity to apply drag to. FOr complex hierarchies, this method might return a parent. Redefine the method in the node component if you want that to be used.
    auto GetObjectToDrag(entt::registry *registry, entt::entity e) -> entt::entity
    {
        if (registry->valid(e) == false)
        {
            return entt::null;
        }
        
        auto &node = registry->get<GameObject>(e);
        
        // use handler if it exists
        if (node.methods.getObjectToDrag)
        {
            return node.methods.getObjectToDrag(*registry, e);
        }
        
        if (node.state.dragEnabled) return e;
        else return entt::null;
    }

    auto StopDragging(entt::registry *registry, entt::entity e) -> void
    {
        if (registry->valid(e) == false)
        {
            return;
        }
        
        // if (registry->any_of<ui::UIConfig>(e) == false)
        // {
        //     return;
        // }
        
        auto &node = registry->get<GameObject>(e);
        
        // drag pop-up (for controlller drag, for instance) exists
        // if (node.children.find("d_popup") == node.children.end()) return;
        
        // ui::box::Remove(*registry, node.children["d_popup"]);
        
        // // erase
        // node.children.erase("d_popup");
        // // erase from vector as well
        // auto it = std::remove(node.orderedChildren.begin(), node.orderedChildren.end(), node.children["d_popup"]);
        // node.orderedChildren.erase(it, node.orderedChildren.end());
        
        // custom stop drag logic
        if (node.methods.onStopDrag) {
            node.methods.onStopDrag(*registry, e);
        }
    }

    auto StartHover(entt::registry *registry, entt::entity e) -> void
    {
        
        if (registry->valid(e) == false)
        {
            return;
        }
        
        if (registry->any_of<ui::UIConfig>(e) == false)
        {
            return;
        }
        
        auto &node = registry->get<GameObject>(e);
        auto &uiConfig = registry->get<ui::UIConfig>(e);
        
        // config demands hover popup
        if (!uiConfig.hPopup) return;
        
        // doesn't already exist
        if (node.children.find("h_popup") != node.children.end()) return;
        
        // TODO: make a new UIbox for the pop-up, add as child

        //TODO: generate and attach new UIbox for the pop-up, add as child, use hPopupConfig and the hPopup definition to create the uibox
        //TODO: in ui element's hover method, call the creaate tooltip method to generate the definition

        
        
        // custom start hover logic
        if (node.methods.onHover) {
            node.methods.onHover(*registry, e);
        }
    }

    auto StopHover(entt::registry *registry, entt::entity e) -> void
    {
        if (registry->valid(e) == false)
        {
            return;
        }
        
        if (registry->any_of<ui::UIConfig>(e) == false)
        {
            return;
        }
        
        // hoverPopup exists, remove it
        auto &node = registry->get<GameObject>(e);
        auto &uiConfig = registry->get<ui::UIConfig>(e);
        
        if (node.children.find("h_popup") == node.children.end()) return;
        
        ui::box::Remove(*registry, node.children["h_popup"]);
        
        // erase
        node.children.erase("h_popup");
        
        // custom stop hover logic
        if (node.methods.onStopHover) {
            node.methods.onStopHover(*registry, e);
        }
        
    }

    // determines where the cursor should be when focused on a node
    auto GetCursorOnFocus(entt::registry *registry, entt::entity e) -> Vector2
    {
        auto &transform = registry->get<Transform>(e);
        auto &role = registry->get<InheritedProperties>(e);
        auto &node = registry->get<GameObject>(e);

        AssertThat(registry->valid(node.container), Is().EqualTo(true));

        auto &containerTransform = registry->get<Transform>(node.container);

        auto x = (float)(transform.getActualX() + transform.getActualW() * 0.5 + containerTransform.getActualX());
        auto y = (float)(transform.getActualY() + transform.getActualH() * 0.5 + containerTransform.getActualY());

        return Vector2{x, y};
    }

    // set container for node and all child nodes
    auto ConfigureContainerForEntity(entt::registry *registry, entt::entity e, entt::entity container) -> void
    {
        AssertThat(registry->valid(e), Is().EqualTo(true));
        AssertThat(registry->valid(container), Is().EqualTo(true));

        auto &node = registry->get<GameObject>(e);
        auto &role = registry->get<InheritedProperties>(e);

        if (node.children.size() == 0)
            return;

        for (auto childEntry : node.orderedChildren)
        {
            ConfigureContainerForEntity(registry, childEntry, container);
        }

        node.container = container;
    }

    // Translation function used before any draw calls, translates this node according to the transform of the container node. Note: does not call push or pop maxtrix()
    auto ApplyTranslationFromEntityContainer(entt::registry *registry, entt::entity e, std::shared_ptr<layer::Layer> layer) -> void
    {
        auto &transform = registry->get<Transform>(e);
        auto &role = registry->get<InheritedProperties>(e);
        auto &node = registry->get<GameObject>(e);

        if (registry->valid(node.container) == false || node.container == e)
        {
            SPDLOG_DEBUG("Container is invalid");
            return;
        }

        auto &containerTransform = registry->get<Transform>(node.container);

        layer::QueueCommand<layer::CmdTranslate>(layer, [x = containerTransform.getActualW() * 0.5, y = containerTransform.getActualH() * 0.5](layer::CmdTranslate *cmd) {
            cmd->x = x;
            cmd->y = y;
        });
        layer::QueueCommand<layer::CmdRotate>(layer, [rotation = containerTransform.getActualRotation()](layer::CmdRotate *cmd) {
            cmd->angle = rotation;
        });
        layer::QueueCommand<layer::CmdTranslate>(layer, [x = -containerTransform.getActualW() * 0.5 + containerTransform.getActualX(),
                                 y = -containerTransform.getActualH() * 0.5 + containerTransform.getActualY()](layer::CmdTranslate *cmd) {
            cmd->x = x;
            cmd->y = y;
        });
    }

    // this method should be called every frame for a transform/node entity
    auto UpdateTransformSmoothingFactors(entt::registry *registry, entt::entity e, float dt) -> void
    {
        // customizing the smoothing factors for the transform based on delta time
        auto &transform = registry->get<Transform>(e);

        auto &springX = transform.getXSpring();
        auto &springY = transform.getYSpring();
        auto &springS = transform.getWSpring();
        auto &springR = transform.getRSpring();

        // At 60 FPS, self.real_dt (delta time) is approximately 1 / 60 = 0.0167 seconds.

        // higher smoothing factor means slower response to changes (between 0 and 1, where 1 is no slowing of velocity)
        springX.smoothingFactor = exp(-50 * dt);  // for 60 fps, this is 0.434
        springY.smoothingFactor = exp(-50 * dt);  // for 60 fps, this is 0.434
        springS.smoothingFactor = exp(-60 * dt);  // for 60 fps, this is 0.367
        springR.smoothingFactor = exp(-190 * dt); // for 60 fps, this is 0.042

        // max vel only for xy
        float move_dt = std::min(1.0f / 20.f, dt); // cap dt at 20 fps at the slowest when moving
        springX.maxVelocity = 70 * move_dt;
        springY.maxVelocity = 70 * move_dt;
    }

    // Returns the squared (fast) distance in game units from the center of one node to the center of another node
    auto GetDistanceBetween(entt::registry *registry, entt::entity e1, entt::entity e2) -> float
    {
        auto &transform1 = registry->get<Transform>(e1);
        auto &transform2 = registry->get<Transform>(e2);

        float dx = (transform2.getActualX() + 0.5f * transform2.getActualW()) - (transform1.getActualX() + 0.5f * transform1.getActualW());
        float dy = (transform2.getActualY() + 0.5f * transform2.getActualH()) - (transform1.getActualY() + 0.5f * transform1.getActualH());

        return std::sqrt(dx * dx + dy * dy); // Compute the Euclidean distance FIXME: this isn't fast...?
    }

    auto RemoveEntity(entt::registry *registry, entt::entity e) -> void
    {
        auto &node = registry->get<GameObject>(e);
        auto &role = registry->get<InheritedProperties>(e);

        // node hierarchy is separate from transform parent/child hierarchy
        if (node.children.size() > 0)
        {
            for (auto &entry : node.children)
            {
                RemoveEntity(registry, entry.second);
            }
        }
        // remove the node
        registry->destroy(e);
    }
    
    auto exposeToLua(sol::state &lua) -> void {
        // BindingRecorder instance
        auto& rec = BindingRecorder::instance();

        //=========================================================
        // Part 1: Transform Component
        //=========================================================
        lua.new_usertype<Transform>("Transform",
            sol::constructors<Transform()>(),
            "updateCachedValues", sol::overload(
                static_cast<void(Transform::*)(bool)>(&Transform::updateCachedValues),
                static_cast<void(Transform::*)(const Spring&, const Spring&, const Spring&, const Spring&, const Spring&, const Spring&, bool)>(&Transform::updateCachedValues)
            ),
            "ignoreDynamicMotion", &Transform::ignoreDynamicMotion,
            "ignoreXLeaning", &Transform::ignoreXLeaning,
            "actualX",  sol::property(&Transform::getActualX, &Transform::setActualX),
            "visualX",  sol::property(&Transform::getVisualX, &Transform::setVisualX),
            "actualY",  sol::property(&Transform::getActualY, &Transform::setActualY),
            "visualY",  sol::property(&Transform::getVisualY, &Transform::setVisualY),
            "actualW",  sol::property(&Transform::getActualW, &Transform::setActualW),
            "visualW",  sol::property(&Transform::getVisualW, &Transform::setVisualW),
            "actualH",  sol::property(&Transform::getActualH, &Transform::setActualH),
            "actualR",  sol::property(&Transform::getActualRotation, &Transform::setActualRotation),
            "visualH",  sol::property(&Transform::getVisualH, &Transform::setVisualH),
            "rotation", sol::property(&Transform::getActualRotation, &Transform::setActualRotation),
            "visualR",  &Transform::getVisualR,
            "visualRWithMotion", &Transform::getVisualRWithDynamicMotionAndXLeaning,
            "scale",    sol::property(&Transform::getActualScale, &Transform::setActualScale),
            "visualS",  &Transform::getVisualScale,
            "visualSWithMotion", &Transform::getVisualScaleWithHoverAndDynamicMotionReflected,
            "xSpring", &Transform::getXSpring,
            "ySpring", &Transform::getYSpring,
            "wSpring", &Transform::getWSpring,
            "hSpring", &Transform::getHSpring,
            "rSpring", &Transform::getRSpring,
            "sSpring", &Transform::getSSpring,
            "hoverBufferX", &Transform::getHoverCollisionBufferX,
            "hoverBufferY", &Transform::getHoverCollisionBufferY,
            sol::meta_function::to_string, [](Transform& t) {
                std::ostringstream o;
                o << "Transform{ x=" << t.getActualX() << ", y="  << t.getActualY() << ", scale=" << t.getActualScale() << " }";
                return o.str();
            },
            "type_id", []() { return entt::type_hash<transform::Transform>::value(); }
            
        );
        // Recorder: Transform
        auto& tDef = rec.add_type("Transform", /*is_data_class=*/true);
        tDef.doc = "Manages an entity's position, size, rotation, and scale, with spring dynamics for smooth visual updates.";
        rec.record_method("Transform", {"updateCachedValues", "---@overload fun(self, force:boolean)\n---@overload fun(self, x:Spring, y:Spring, w:Spring, h:Spring, r:Spring, s:Spring, force:boolean)", "Updates cached transform values.", false, false});
        rec.record_property("Transform", {"actualX", "number", "The logical X position."});
        rec.record_property("Transform", {"visualX", "number", "The visual (spring-interpolated) X position."});
        rec.record_property("Transform", {"actualY", "number", "The logical Y position."});
        rec.record_property("Transform", {"visualY", "number", "The visual (spring-interpolated) Y position."});
        rec.record_property("Transform", {"actualW", "number", "The logical width."});
        rec.record_property("Transform", {"visualW", "number", "The visual width."});
        rec.record_property("Transform", {"actualH", "number", "The logical height."});
        rec.record_property("Transform", {"visualH", "number", "The visual height."});
        rec.record_property("Transform", {"rotation", "number", "The logical rotation in degrees."});
        rec.record_method("Transform", {"visualR", "---@return number", "Gets the visual rotation.", false, false});
        rec.record_method("Transform", {"visualRWithMotion", "---@return number", "Gets the visual rotation including dynamic motion.", false, false});
        rec.record_property("Transform", {"scale", "number", "The logical scale multiplier."});
        rec.record_method("Transform", {"visualS", "---@return number", "Gets the visual scale.", false, false});
        rec.record_method("Transform", {"visualSWithMotion", "---@return number", "Gets the visual scale including dynamic motion.", false, false});
        rec.record_method("Transform", {"xSpring", "---@return Spring", "Gets the X position spring.", false, false});
        rec.record_method("Transform", {"ySpring", "---@return Spring", "Gets the Y position spring.", false, false});
        rec.record_method("Transform", {"wSpring", "---@return Spring", "Gets the width spring.", false, false});
        rec.record_method("Transform", {"hSpring", "---@return Spring", "Gets the height spring.", false, false});
        rec.record_method("Transform", {"rSpring", "---@return Spring", "Gets the rotation spring.", false, false});
        rec.record_method("Transform", {"sSpring", "---@return Spring", "Gets the scale spring.", false, false});
        rec.record_method("Transform", {"hoverBufferX", "---@return number", "Gets the X-axis hover buffer.", false, false});
        rec.record_method("Transform", {"hoverBufferY", "---@return number", "Gets the Y-axis hover buffer.", false, false});


        //=========================================================
        // Part 2: InheritedProperties & Related Types
        //=========================================================
        // 2a) Enums
        lua.new_enum<InheritedProperties::Type>("InheritedPropertiesType", {
            {"RoleRoot",           InheritedProperties::Type::RoleRoot},
            {"RoleInheritor",      InheritedProperties::Type::RoleInheritor},
            {"RoleCarbonCopy",     InheritedProperties::Type::RoleCarbonCopy},
            {"PermanentAttachment",InheritedProperties::Type::PermanentAttachment}
        });
        auto& ipType = rec.add_type("InheritedPropertiesType");
        ipType.doc = "Defines how an entity relates to its master in the transform hierarchy.";
        rec.record_property("InheritedPropertiesType", {"RoleRoot", "0", "A root object that is not influenced by a master."});
        rec.record_property("InheritedPropertiesType", {"RoleInheritor", "1", "Inherits transformations from a master."});
        rec.record_property("InheritedPropertiesType", {"RoleCarbonCopy", "2", "Perfectly mirrors its master's transformations."});
        rec.record_property("InheritedPropertiesType", {"PermanentAttachment", "3", "A permanent, non-detachable inheritor."});

        lua.new_enum<InheritedProperties::Sync>("InheritedPropertiesSync", {
            {"Strong", InheritedProperties::Sync::Strong},
            {"Weak",   InheritedProperties::Sync::Weak}
        });
        auto& ipSync = rec.add_type("InheritedPropertiesSync");
        ipSync.doc = "Defines the strength of a transform bond.";
        rec.record_property("InheritedPropertiesSync", {"Strong", "0", "The property is directly copied from the master."});
        rec.record_property("InheritedPropertiesSync", {"Weak", "1", "The property is influenced by but not locked to the master."});

        // 2b) Alignment Flags as a constant table
        lua["AlignmentFlag"] = lua.create_table_with(
            "NONE",                InheritedProperties::Alignment::NONE,
            "HORIZONTAL_LEFT",     InheritedProperties::Alignment::HORIZONTAL_LEFT,
            "HORIZONTAL_CENTER",   InheritedProperties::Alignment::HORIZONTAL_CENTER,
            "HORIZONTAL_RIGHT",    InheritedProperties::Alignment::HORIZONTAL_RIGHT,
            "VERTICAL_TOP",        InheritedProperties::Alignment::VERTICAL_TOP,
            "VERTICAL_CENTER",     InheritedProperties::Alignment::VERTICAL_CENTER,
            "VERTICAL_BOTTOM",     InheritedProperties::Alignment::VERTICAL_BOTTOM,
            "ALIGN_TO_INNER_EDGES",InheritedProperties::Alignment::ALIGN_TO_INNER_EDGES
        );
        auto& alignFlag = rec.add_type("AlignmentFlag");
        alignFlag.doc = "Bitmask flags for aligning an entity to its master.";
        rec.record_property("AlignmentFlag", {"NONE", std::to_string(InheritedProperties::Alignment::NONE), "No alignment."});
        rec.record_property("AlignmentFlag", {"HORIZONTAL_LEFT", std::to_string(InheritedProperties::Alignment::HORIZONTAL_LEFT), "Align left edges."});
        rec.record_property("AlignmentFlag", {"HORIZONTAL_CENTER", std::to_string(InheritedProperties::Alignment::HORIZONTAL_CENTER), "Align horizontal centers."});
        rec.record_property("AlignmentFlag", {"HORIZONTAL_RIGHT", std::to_string(InheritedProperties::Alignment::HORIZONTAL_RIGHT), "Align right edges."});
        rec.record_property("AlignmentFlag", {"VERTICAL_TOP", std::to_string(InheritedProperties::Alignment::VERTICAL_TOP), "Align top edges."});
        rec.record_property("AlignmentFlag", {"VERTICAL_CENTER", std::to_string(InheritedProperties::Alignment::VERTICAL_CENTER), "Align vertical centers."});
        rec.record_property("AlignmentFlag", {"VERTICAL_BOTTOM", std::to_string(InheritedProperties::Alignment::VERTICAL_BOTTOM), "Align bottom edges."});
        rec.record_property("AlignmentFlag", {"ALIGN_TO_INNER_EDGES", std::to_string(InheritedProperties::Alignment::ALIGN_TO_INNER_EDGES), "Align to inner instead of outer edges."});

        // 2c) Alignment struct
        lua.new_usertype<InheritedProperties::Alignment>("Alignment",
            "alignment",       &InheritedProperties::Alignment::alignment,
            "extraOffset",     &InheritedProperties::Alignment::extraAlignmentFinetuningOffset,
            "prevExtraOffset", &InheritedProperties::Alignment::prevExtraAlignmentFinetuningOffset,
            "hasFlag", [](InheritedProperties::Alignment& a, int flag) { return InheritedProperties::Alignment::hasFlag(a.alignment, flag); },
            "addFlag", [](InheritedProperties::Alignment& a, int flag) { InheritedProperties::Alignment::addFlag(a.alignment, flag); },
            "removeFlag", [](InheritedProperties::Alignment& a, int flag) { InheritedProperties::Alignment::removeFlag(a.alignment, flag); },
            "toggleFlag", [](InheritedProperties::Alignment& a, int flag) { InheritedProperties::Alignment::toggleFlag(a.alignment, flag); },
            "type_id", []() { return entt::type_hash<InheritedProperties::Alignment>::value(); }
        );
        auto& alignDef = rec.add_type("Alignment", /*is_data_class=*/true);
        alignDef.doc = "Stores alignment flags and offsets for an inherited property.";
        rec.record_property("Alignment", {"alignment", "integer", "The raw bitmask of alignment flags."});
        rec.record_property("Alignment", {"extraOffset", "Vector2", "Additional fine-tuning offset."});
        rec.record_property("Alignment", {"prevExtraOffset", "Vector2", "Previous frame's fine-tuning offset."});
        rec.record_method("Alignment", {"hasFlag", "---@param flag AlignmentFlag\n---@return boolean", "Checks if a specific alignment flag is set.", false, false});
    rec.record_method("Alignment", {"addFlag", "---@param flag AlignmentFlag\n---@return nil", "Adds an alignment flag.", false, false});
    rec.record_method("Alignment", {"removeFlag", "---@param flag AlignmentFlag\n---@return nil", "Removes an alignment flag.", false, false});
    rec.record_method("Alignment", {"toggleFlag", "---@param flag AlignmentFlag\n---@return nil", "Toggles an alignment flag.", false, false});

    // 2d) Main InheritedProperties struct
    lua.new_usertype<InheritedProperties>("InheritedProperties",
        sol::constructors<>(),
        "role_type",       &InheritedProperties::role_type,
        "master",          &InheritedProperties::master,
        "offset",          &InheritedProperties::offset,
        "prevOffset",      &InheritedProperties::prevOffset,
        "location_bond",   &InheritedProperties::location_bond,
        "size_bond",       &InheritedProperties::size_bond,
        "rotation_bond",   &InheritedProperties::rotation_bond,
        "scale_bond",      &InheritedProperties::scale_bond,
        "flags", sol::property(
            // getter: default-construct if needed, then return ref
            [](InheritedProperties &p)->InheritedProperties::Alignment& {
                if (!p.flags) p.flags.emplace();
                return *p.flags;
            },
            // setter: replace the entire Alignment
            [](InheritedProperties &p, InheritedProperties::Alignment v) {
                p.flags = v;
            }
        ),
        "type_id",         []() { return entt::type_hash<InheritedProperties>::value(); }
    );
    auto& ipDef = rec.add_type("InheritedProperties", /*is_data_class=*/true);
    ipDef.doc = "Defines how an entity inherits transform properties from a master entity.";
    rec.record_property("InheritedProperties", {"role_type", "InheritedPropertiesType", "The role of this entity in the hierarchy."});
    rec.record_property("InheritedProperties", {"master", "Entity", "The master entity this entity inherits from."});
    rec.record_property("InheritedProperties", {"offset", "Vector2", "The current offset from the master."});
    rec.record_property("InheritedProperties", {"prevOffset", "Vector2", "The previous frame's offset."});
    rec.record_property("InheritedProperties", {"location_bond", "InheritedPropertiesSync|nil", "The sync bond for location."});
    rec.record_property("InheritedProperties", {"size_bond", "InheritedPropertiesSync|nil", "The sync bond for size."});
    rec.record_property("InheritedProperties", {"rotation_bond", "InheritedPropertiesSync|nil", "The sync bond for rotation."});
    rec.record_property("InheritedProperties", {"scale_bond", "InheritedPropertiesSync|nil", "The sync bond for scale."});
    rec.record_property("InheritedProperties", {"flags", "Alignment|nil", "Alignment flags and data."});

    // 2e) Builder
    lua.new_usertype<InheritedProperties::Builder>("InheritedPropertiesBuilder",
        sol::constructors<>(),
        "addRoleType",        &InheritedProperties::Builder::addRoleType,
        "addMaster",          &InheritedProperties::Builder::addMaster,
        "addOffset",          &InheritedProperties::Builder::addOffset,
        "addLocationBond",    &InheritedProperties::Builder::addLocationBond,
        "addSizeBond",        &InheritedProperties::Builder::addSizeBond,
        "addRotationBond",    &InheritedProperties::Builder::addRotationBond,
        "addScaleBond",       &InheritedProperties::Builder::addScaleBond,
        "addAlignment",       &InheritedProperties::Builder::addAlignment,
        "addAlignmentOffset", &InheritedProperties::Builder::addAlignmentOffset,
        "build",              &InheritedProperties::Builder::build
    );
    auto& ipBuilder = rec.add_type("InheritedPropertiesBuilder");
    ipBuilder.doc = "A fluent builder for creating InheritedProperties components.";
    rec.record_method("InheritedPropertiesBuilder", {"addRoleType", "---@param type InheritedPropertiesType\n---@return self", "Sets the role type.", false, false});
    rec.record_method("InheritedPropertiesBuilder", {"addMaster", "---@param master Entity\n---@return self", "Sets the master entity.", false, false});
    rec.record_method("InheritedPropertiesBuilder", {"addOffset", "---@param offset Vector2\n---@return self", "Sets the offset.", false, false});
    rec.record_method("InheritedPropertiesBuilder", {"addLocationBond", "---@param bond InheritedPropertiesSync\n---@return self", "Sets the location bond.", false, false});
    rec.record_method("InheritedPropertiesBuilder", {"addSizeBond", "---@param bond InheritedPropertiesSync\n---@return self", "Sets the size bond.", false, false});
    rec.record_method("InheritedPropertiesBuilder", {"addRotationBond", "---@param bond InheritedPropertiesSync\n---@return self", "Sets the rotation bond.", false, false});
    rec.record_method("InheritedPropertiesBuilder", {"addScaleBond", "---@param bond InheritedPropertiesSync\n---@return self", "Sets the scale bond.", false, false});
    rec.record_method("InheritedPropertiesBuilder", {"addAlignment", "---@param flags AlignmentFlag\n---@return self", "Sets the alignment flags.", false, false});
    rec.record_method("InheritedPropertiesBuilder", {"addAlignmentOffset", "---@param offset Vector2\n---@return self", "Sets the alignment offset.", false, false});
    rec.record_method("InheritedPropertiesBuilder", {"build", "---@return InheritedProperties", "Constructs the final InheritedProperties object.", false, false});


    //=========================================================
    // Part 3: GameObject & Related Types
    //=========================================================
    // 3a) GameObject.Methods
    lua.new_usertype<GameObject::Methods>("GameObjectMethods",
        sol::constructors<>(),
        "getObjectToDrag", &GameObject::Methods::getObjectToDrag,
        "update",          &GameObject::Methods::update,
        "draw",            &GameObject::Methods::draw,
        "onClick",         &GameObject::Methods::onClick,
        "onRelease",       &GameObject::Methods::onRelease,
        "onHover",         &GameObject::Methods::onHover,
        "onStopHover",     &GameObject::Methods::onStopHover,
        "onDrag",          &GameObject::Methods::onDrag,
        "onStopDrag",      &GameObject::Methods::onStopDrag
    );
    auto& goMethods = rec.add_type("GameObjectMethods", /*is_data_class=*/true);
    goMethods.doc = "A table of optional script-defined callback methods for a GameObject.";
    rec.record_property("GameObjectMethods", {"getObjectToDrag", "function|nil", "Returns the entity that should be dragged."});
    rec.record_property("GameObjectMethods", {"update", "function|nil", "Called every frame."});
    rec.record_property("GameObjectMethods", {"draw", "function|nil", "Called every frame for drawing."});
    rec.record_property("GameObjectMethods", {"onClick", "function|nil", "Called on click."});
    rec.record_property("GameObjectMethods", {"onRelease", "function|nil", "Called on click release."});
    rec.record_property("GameObjectMethods", {"onHover", "function|nil", "Called when hover starts."});
    rec.record_property("GameObjectMethods", {"onStopHover", "function|nil", "Called when hover ends."});
    rec.record_property("GameObjectMethods", {"onDrag", "function|nil", "Called while dragging."});
    rec.record_property("GameObjectMethods", {"onStopDrag", "function|nil", "Called when dragging stops."});

    // 3b) GameObject.State
    lua.new_usertype<GameObject::State>("GameObjectState",
        sol::constructors<>(),
        "visible",                 &GameObject::State::visible,
        "collisionEnabled",        &GameObject::State::collisionEnabled,
        "isColliding",             &GameObject::State::isColliding,
        "focusEnabled",            &GameObject::State::focusEnabled,
        "isBeingFocused",          &GameObject::State::isBeingFocused,
        "hoverEnabled",            &GameObject::State::hoverEnabled,
        "isBeingHovered",          &GameObject::State::isBeingHovered,
        "enlargeOnHover",          &GameObject::State::enlargeOnHover,
        "enlargeOnDrag",           &GameObject::State::enlargeOnDrag,
        "clickEnabled",            &GameObject::State::clickEnabled,
        "isBeingClicked",          &GameObject::State::isBeingClicked,
        "dragEnabled",             &GameObject::State::dragEnabled,
        "isBeingDragged",          &GameObject::State::isBeingDragged,
        "triggerOnReleaseEnabled", &GameObject::State::triggerOnReleaseEnabled,
        "isTriggeringOnRelease",   &GameObject::State::isTriggeringOnRelease,
        "isUnderOverlay",          &GameObject::State::isUnderOverlay
    );
    auto& goState = rec.add_type("GameObjectState", /*is_data_class=*/true);
    goState.doc = "A collection of boolean flags representing the current state of a GameObject.";
    rec.record_property("GameObjectState", {"visible", "boolean"});
    rec.record_property("GameObjectState", {"collisionEnabled", "boolean"});
    rec.record_property("GameObjectState", {"isColliding", "boolean"});
    rec.record_property("GameObjectState", {"focusEnabled", "boolean"});
    rec.record_property("GameObjectState", {"isBeingFocused", "boolean"});
    rec.record_property("GameObjectState", {"hoverEnabled", "boolean"});
    rec.record_property("GameObjectState", {"isBeingHovered", "boolean"});
    rec.record_property("GameObjectState", {"enlargeOnHover", "boolean"});
    rec.record_property("GameObjectState", {"enlargeOnDrag", "boolean"});
    rec.record_property("GameObjectState", {"clickEnabled", "boolean"});
    rec.record_property("GameObjectState", {"isBeingClicked", "boolean"});
    rec.record_property("GameObjectState", {"dragEnabled", "boolean"});
    rec.record_property("GameObjectState", {"isBeingDragged", "boolean"});
    rec.record_property("GameObjectState", {"triggerOnReleaseEnabled", "boolean"});
    rec.record_property("GameObjectState", {"isTriggeringOnRelease", "boolean"});
    rec.record_property("GameObjectState", {"isUnderOverlay", "boolean"});

    // 3c) Main GameObject
    lua.new_usertype<GameObject>("GameObject",
        sol::constructors<>(),
        "parent",               &GameObject::parent,
        "children",             &GameObject::children,
        "orderedChildren",      &GameObject::orderedChildren,
        "ignoresPause",         &GameObject::ignoresPause,
        "container",            &GameObject::container,
        "collisionTransform",   &GameObject::collisionTransform,
        "clickTimeout",         &GameObject::clickTimeout,
        "methods",              &GameObject::methods,
        "updateFunction",       &GameObject::updateFunction,
        "drawFunction",         &GameObject::drawFunction,
        "state",                &GameObject::state,
        "dragOffset",           &GameObject::dragOffset,
        "clickOffset",          &GameObject::clickOffset,
        "hoverOffset",          &GameObject::hoverOffset,
        "shadowDisplacement",   &GameObject::shadowDisplacement,
        "layerDisplacement",    &GameObject::layerDisplacement,
        "layerDisplacementPrev",&GameObject::layerDisplacementPrev,
        "shadowHeight",         &GameObject::shadowHeight,
        "type_id",              []() { return entt::type_hash<GameObject>::value(); }
    );
    auto& goDef = rec.add_type("GameObject", /*is_data_class=*/true);
    goDef.doc = "The core component for a scene entity, managing hierarchy, state, and scriptable logic.";
    rec.record_property("GameObject", {"parent", "Entity|nil"});
    rec.record_property("GameObject", {"children", "table<Entity, boolean>"});
    rec.record_property("GameObject", {"orderedChildren", "table<integer, Entity>"});
    rec.record_property("GameObject", {"ignoresPause", "boolean"});
    rec.record_property("GameObject", {"container", "Entity|nil"});
    rec.record_property("GameObject", {"collisionTransform", "Transform|nil"});
    rec.record_property("GameObject", {"clickTimeout", "number"});
    rec.record_property("GameObject", {"methods", "GameObjectMethods|nil"});
    rec.record_property("GameObject", {"updateFunction", "function|nil"});
    rec.record_property("GameObject", {"drawFunction", "function|nil"});
    rec.record_property("GameObject", {"state", "GameObjectState"});
    rec.record_property("GameObject", {"dragOffset", "Vector2"});
    rec.record_property("GameObject", {"clickOffset", "Vector2"});
    rec.record_property("GameObject", {"hoverOffset", "Vector2"});
    rec.record_property("GameObject", {"shadowDisplacement", "Vector2"});
    rec.record_property("GameObject", {"layerDisplacement", "Vector2"});
    rec.record_property("GameObject", {"layerDisplacementPrev", "Vector2"});
    rec.record_property("GameObject", {"shadowHeight", "number"});
    
    // 3d) Collision-ordering structs
    lua.new_usertype<CollisionOrderInfo>("CollisionOrderInfo",
        sol::constructors<>(),
        "hasCollisionOrder", &CollisionOrderInfo::hasCollisionOrder,
        "parentBox",         &CollisionOrderInfo::parentBox,
        "treeOrder",         &CollisionOrderInfo::treeOrder,
        "layerOrder",        &CollisionOrderInfo::layerOrder,
        "type_id",           []() { return entt::type_hash<CollisionOrderInfo>::value(); }
    );
    auto& coiDef = rec.add_type("CollisionOrderInfo", /*is_data_class=*/true);
    coiDef.doc = "Contains information about an entity's render and collision order.";
    rec.record_property("CollisionOrderInfo", {"hasCollisionOrder", "boolean"});
    rec.record_property("CollisionOrderInfo", {"parentBox", "Rectangle"});
    rec.record_property("CollisionOrderInfo", {"treeOrder", "integer"});
    rec.record_property("CollisionOrderInfo", {"layerOrder", "integer"});
    
    lua.new_usertype<TreeOrderComponent>("TreeOrderComponent",
        sol::constructors<>(),
        "order", &TreeOrderComponent::order,
        "type_id", []() { return entt::type_hash<TreeOrderComponent>::value(); }
    );
    auto& tocDef = rec.add_type("TreeOrderComponent", /*is_data_class=*/true);
    tocDef.doc = "A simple component storing an entity's tree order for sorting.";
    rec.record_property("TreeOrderComponent", {"order", "integer"});


    //=========================================================
    // Part 4: Global `transform` system functions
    //=========================================================
    sol::table transform_tbl = lua.create_named_table("transform");
    rec.add_type("transform").doc = "A global system for creating and managing all Transforms and GameObjects.";

    transform_tbl.set_function("InitializeSystem", &transform::InitializeSystem);
    rec.record_free_function({"transform"}, {"InitializeSystem", "---@return nil", "Initializes the transform system.", true, false});

    transform_tbl.set_function("UpdateAllTransforms", &transform::UpdateAllTransforms);
    rec.record_free_function({"transform"}, {"UpdateAllTransforms", "---@param registry registry\n---@param dt number\n---@return nil", "Updates all transforms in the registry.", true, false});
    
    transform_tbl.set_function("CreateOrEmplace", &transform::CreateOrEmplace);
    rec.record_free_function({"transform"}, {"CreateOrEmplace", "---@param registry registry\n---@param container Entity\n---@param x number\n---@param y number\n---@param w number\n---@param h number\n---@param entityToEmplaceTo? Entity\n---@return Entity", "Creates or emplaces an entity with core components.", true, false});
    
    transform_tbl.set_function("CreateGameWorldContainerEntity", &transform::CreateGameWorldContainerEntity);
    rec.record_free_function({"transform"}, {"CreateGameWorldContainerEntity", "---@param registry registry\n---@param x number\n---@param y number\n---@param w number\n---@param h number\n---@return Entity", "Creates a root container entity for the game world.", true, false});

    transform_tbl.set_function("UpdateTransformSmoothingFactors", &transform::UpdateTransformSmoothingFactors);
    rec.record_free_function({"transform"}, {"UpdateTransformSmoothingFactors", "---@param registry registry\n---@param e Entity\n---@param dt number\n---@return nil", "Updates spring smoothing factors for a transform.", true, false});
    
    transform_tbl.set_function("InjectDynamicMotion", 
        [](entt::entity e, float amount, float rotationAmount) {
            transform::InjectDynamicMotion(&globals::registry, e, amount, rotationAmount);
        }
    );
    transform_tbl.set_function("InjectDynamicMotionDefault", 
        [](entt::entity e) {
            transform::InjectDynamicMotion(&globals::registry, e, 1.0f, 0.0f);
        }
    );
    rec.record_free_function({"transform"}, {"InjectDynamicMotion", "---@param e Entity\n---@param amount number\n---@param rotationAmount number\n---@return nil", "Injects dynamic motion into a transform's springs.", true, false});
    rec.record_free_function({"transform"}, {"InjectDynamicMotionDefault", "---@param e Entity\n---@return nil", "Injects default dynamic motion into a transform's springs.", true, false});

    transform_tbl.set_function("AlignToMaster", &transform::AlignToMaster);
    rec.record_free_function({"transform"}, {"AlignToMaster", "---@param registry registry\n---@param e Entity\n---@param force? boolean\n---@return nil", "Aligns an entity to its master.", true, false});
    
    transform_tbl.set_function("AssignRole", 
        [](entt::registry *registry, entt::entity e, InheritedProperties::Type roleType, entt::entity parent, sol::optional<InheritedProperties::Sync> xy, sol::optional<InheritedProperties::Sync> wh, sol::optional<InheritedProperties::Sync> rotation, sol::optional<InheritedProperties::Sync> scale, sol::optional<Vector2> offset) {
            std::optional<InheritedProperties::Sync> xySync = xy.value_or(InheritedProperties::Sync::Strong);
            std::optional<InheritedProperties::Sync> whSync = wh.value_or(InheritedProperties::Sync::Strong);
            std::optional<InheritedProperties::Sync> rotationSync = rotation.value_or(InheritedProperties::Sync::Strong);
            std::optional<InheritedProperties::Sync> scaleSync = scale.value_or(InheritedProperties::Sync::Strong);
            std::optional<Vector2> offsetValue = offset.value_or(Vector2(0.0f, 0.0f));
            transform::AssignRole(registry, e, roleType, parent, xySync, whSync, rotationSync, scaleSync, offsetValue);
        }
    );
    
    rec.record_free_function({"transform"}, {"AssignRole", "---@param registry registry\n---@param e Entity\n---@param roleType? InheritedPropertiesType\n---@param parent? Entity\n---@param xy? InheritedPropertiesSync\n---@param wh? InheritedPropertiesSync\n---@param rotation? InheritedPropertiesSync\n---@param scale? InheritedPropertiesSync\n---@param offset? Vector2\n---@return nil", "Assigns an inherited properties role to an entity.", true, false});    

    transform_tbl.set_function("MoveWithMaster", &transform::MoveWithMaster);
    rec.record_free_function({"transform"}, {"MoveWithMaster", "---@param e Entity\n---@param dt number\n---@param selfTransform Transform\n---@param selfRole InheritedProperties\n---@param selfNode GameObject\n---@return nil", "Updates an entity's position based on its master's movement.", true, false});

    transform_tbl.set_function("GetMaster", 
        [](entt::entity e, Transform& selfT, InheritedProperties& selfR, GameObject& selfN) {
            Transform* parentT = nullptr;
            InheritedProperties* parentR = nullptr;
            auto cache = transform::GetMaster(e, selfT, selfR, selfN, parentT, parentR);
            return std::make_tuple(cache, parentT, parentR);
        }
    );
    rec.record_free_function({"transform"}, {"GetMaster", "---@param e Entity\n---@param selfT Transform\n---@param selfR InheritedProperties\n---@param selfN GameObject\n---@return MasterCache, Transform|nil, InheritedProperties|nil", "Gets the master components for a given entity.", true, false});

    transform_tbl.set_function("SyncPerfectlyToMaster", &transform::SyncPerfectlyToMaster);
    rec.record_free_function({"transform"}, {"SyncPerfectlyToMaster", "---@param e Entity\n---@param parent Entity\n---@param selfT Transform\n---@param selfR InheritedProperties\n---@param parentT Transform\n---@param parentR InheritedProperties\n---@return nil", "Instantly snaps an entity's transform to its master's.", true, false});

    transform_tbl.set_function("ConfigureAlignment", &transform::ConfigureAlignment);
    rec.record_free_function({"transform"}, {"ConfigureAlignment", "---@param registry registry\n---@param e Entity\n---@param isChild boolean\n---@param parent? Entity\n---@param xy? InheritedPropertiesSync\n---@param wh? InheritedPropertiesSync\n---@param rotation? InheritedPropertiesSync\n---@param scale? InheritedPropertiesSync\n---@param alignment? AlignmentFlag\n---@param offset? Vector2\n---@return nil", "Configures all alignment and bonding properties for an entity.", true, false});
    
    transform_tbl.set_function("DrawBoundingBoxAndDebugInfo", &transform::DrawBoundingBoxAndDebugInfo);
    rec.record_free_function({"transform"}, {"DrawBoundingBoxAndDebugInfo", "---@param registry registry\n---@param e Entity\n---@param layer Layer\n---@return nil", "Draws debug visuals for a transform.", true, false});
    
    transform_tbl.set_function("FindTopEntityAtPoint", &transform::FindTopEntityAtPoint);
    rec.record_free_function({"transform"}, {"FindTopEntityAtPoint", "---@param point Vector2\n---@return Entity|nil", "Finds the top-most interactable entity at a screen point.", true, false});

    transform_tbl.set_function("FindAllEntitiesAtPoint", &transform::FindAllEntitiesAtPoint);
    rec.record_free_function({"transform"}, {"FindAllEntitiesAtPoint", "---@param point Vector2\n---@return Entity[]", "Finds all interactable entities at a screen point.", true, false});
    
    transform_tbl.set_function("RemoveEntity", &transform::RemoveEntity);
    rec.record_free_function({"transform"}, {"RemoveEntity", "---@param registry registry\n---@param e Entity\n---@return nil", "Removes an entity and its children from the game.", true, false});

    transform_tbl.set_function("setJiggleOnHover", &transform::setJiggleOnHover);
    rec.record_free_function({"transform"}, {"setJiggleOnHover", "---@param registry registry\n---@param e Entity\n---@param jiggleAmount number\n---@return nil", "Configures a jiggle animation on hover.", true, false});

        // // Register the Transform usertype
        // lua.new_usertype<Transform>("Transform",
        //     // Bind the constructor that takes a registry*
        //     sol::constructors<Transform(entt::registry*)>(),
            
        //     // 3) Expose the cache‐updater (with both overloads if you like)
        //     "updateCachedValues", sol::overload(
        //         static_cast<void(Transform::*)(bool)>(&Transform::updateCachedValues),
        //         static_cast<void(Transform::*)(const Spring&, const Spring&, const Spring&, const Spring&, const Spring&, const Spring&, bool)>(&Transform::updateCachedValues)
        //     ),

        //     // 4) Position getters & setters as properties
        //     "actualX",   sol::property(&Transform::getActualX, &Transform::setActualX),
        //     "visualX",   sol::property(&Transform::getVisualX, &Transform::setVisualX),
        //     "actualY",   sol::property(&Transform::getActualY, &Transform::setActualY),
        //     "visualY",   sol::property(&Transform::getVisualY, &Transform::setVisualY),

        //     // 5) Size
        //     "actualW",   sol::property(&Transform::getActualW, &Transform::setActualW),
        //     "visualW",   sol::property(&Transform::getVisualW, &Transform::setVisualW),
        //     "actualH",   sol::property(&Transform::getActualH, &Transform::setActualH),
        //     "visualH",   sol::property(&Transform::getVisualH, &Transform::setVisualH),

        //     // 6) Rotation
        //     "rotation",  sol::property(&Transform::getActualRotation, &Transform::setActualRotation),
        //     "visualR",   &Transform::getVisualR,
        //     "visualRWithMotion", &Transform::getVisualRWithDynamicMotionAndXLeaning,

        //     // 7) Scale
        //     "scale",     sol::property(&Transform::getActualScale, &Transform::setActualScale),
        //     "visualS",   &Transform::getVisualScale,
        //     "visualSWithMotion", &Transform::getVisualScaleWithHoverAndDynamicMotionReflected,

        //     // 8) Expose spring accessors if you need them
        //     "xSpring",  &Transform::getXSpring,
        //     "ySpring",  &Transform::getYSpring,
        //     "wSpring",  &Transform::getWSpring,
        //     "hSpring",  &Transform::getHSpring,
        //     "rSpring",  &Transform::getRSpring,
        //     "sSpring",  &Transform::getSSpring,

        //     // 9) Handy utilities
        //     "hoverBufferX", &Transform::getHoverCollisionBufferX,
        //     "hoverBufferY", &Transform::getHoverCollisionBufferY,

        //     // 10) A __tostring metamethod
        //     sol::meta_function::to_string, [](Transform& t) {
        //         std::ostringstream o;
        //         o << "Transform{ x=" << t.getActualX()
        //         << ", y="  << t.getActualY()
        //         << ", scale=" << t.getActualScale() << " }";
        //         return o.str();
        //     }
        // );
        
        // // 1) Register the nested enums
        // lua.new_enum<InheritedProperties::Type>("InheritedPropertiesType", {
        //     {"RoleRoot",          InheritedProperties::Type::RoleRoot},
        //     {"RoleInheritor",     InheritedProperties::Type::RoleInheritor},
        //     {"RoleCarbonCopy",    InheritedProperties::Type::RoleCarbonCopy},
        //     {"PermanentAttachment", InheritedProperties::Type::PermanentAttachment}
        // });

        // lua.new_enum<InheritedProperties::Sync>("InheritedPropertiesSync", {
        //     {"Strong", InheritedProperties::Sync::Strong},
        //     {"Weak",   InheritedProperties::Sync::Weak}
        // });

        // // 2) Register the Alignment‐flag constants so you can do bitmasks in Lua
        // lua["AlignmentFlag"] = lua.create_table_with(
        //     "NONE",                   InheritedProperties::Alignment::NONE,
        //     "HORIZONTAL_LEFT",        InheritedProperties::Alignment::HORIZONTAL_LEFT,
        //     "HORIZONTAL_CENTER",      InheritedProperties::Alignment::HORIZONTAL_CENTER,
        //     "HORIZONTAL_RIGHT",       InheritedProperties::Alignment::HORIZONTAL_RIGHT,
        //     "VERTICAL_TOP",           InheritedProperties::Alignment::VERTICAL_TOP,
        //     "VERTICAL_CENTER",        InheritedProperties::Alignment::VERTICAL_CENTER,
        //     "VERTICAL_BOTTOM",        InheritedProperties::Alignment::VERTICAL_BOTTOM,
        //     "ALIGN_TO_INNER_EDGES",   InheritedProperties::Alignment::ALIGN_TO_INNER_EDGES
        // );

        // // 3) Expose the Alignment struct
        // lua.new_usertype<InheritedProperties::Alignment>("Alignment",
        //     // raw data
        //     "alignment",      &InheritedProperties::Alignment::alignment,
        //     "extraOffset",    &InheritedProperties::Alignment::extraAlignmentFinetuningOffset,
        //     "prevExtraOffset",&InheritedProperties::Alignment::prevExtraAlignmentFinetuningOffset,
        
        //     // instance methods via lambdas
        //     "hasFlag", [](InheritedProperties::Alignment& a, int flag) {
        //         return InheritedProperties::Alignment::hasFlag(a.alignment, flag);
        //     },
        //     "addFlag", [](InheritedProperties::Alignment& a, int flag) {
        //         InheritedProperties::Alignment::addFlag(a.alignment, flag);
        //     },
        //     "removeFlag", [](InheritedProperties::Alignment& a, int flag) {
        //         InheritedProperties::Alignment::removeFlag(a.alignment, flag);
        //     },
        //     "toggleFlag", [](InheritedProperties::Alignment& a, int flag) {
        //         InheritedProperties::Alignment::toggleFlag(a.alignment, flag);
        //     }
        // );

        // // 4) Expose the main InheritedProperties struct
        // lua.new_usertype<InheritedProperties>("InheritedProperties",
        //     sol::constructors<>(),   // default‐constructible

        //     // basic fields
        //     "role_type",             &InheritedProperties::role_type,
        //     "master",                &InheritedProperties::master,
        //     "offset",                &InheritedProperties::offset,
        //     "prevOffset",            &InheritedProperties::prevOffset,

        //     // optional bonds (std::optional<Sync>)
        //     "location_bond",         &InheritedProperties::location_bond,
        //     "size_bond",             &InheritedProperties::size_bond,
        //     "rotation_bond",         &InheritedProperties::rotation_bond,
        //     "scale_bond",            &InheritedProperties::scale_bond,

        //     // optional Alignment
        //     "flags",                 &InheritedProperties::flags
        // );

        // // 5) Expose the Builder for fluent construction
        // lua.new_usertype<InheritedProperties::Builder>("InheritedPropertiesBuilder",
        //     sol::constructors<>(),

        //     "addRoleType",            &InheritedProperties::Builder::addRoleType,
        //     "addMaster",              &InheritedProperties::Builder::addMaster,
        //     "addOffset",              &InheritedProperties::Builder::addOffset,
        //     "addLocationBond",        &InheritedProperties::Builder::addLocationBond,
        //     "addSizeBond",            &InheritedProperties::Builder::addSizeBond,
        //     "addRotationBond",        &InheritedProperties::Builder::addRotationBond,
        //     "addScaleBond",           &InheritedProperties::Builder::addScaleBond,
        //     "addAlignment",           &InheritedProperties::Builder::addAlignment,
        //     "addAlignmentOffset",     &InheritedProperties::Builder::addAlignmentOffset,
        //     "build",                  &InheritedProperties::Builder::build
        // );
        
        
        // //
        // // 1) Nested Methods
        // //
        // lua.new_usertype<GameObject::Methods>("GameObjectMethods",
        //     sol::constructors<>(),
        //     "getObjectToDrag", &GameObject::Methods::getObjectToDrag,
        //     "update",          &GameObject::Methods::update,
        //     "draw",            &GameObject::Methods::draw,
        //     "onClick",         &GameObject::Methods::onClick,
        //     "onRelease",       &GameObject::Methods::onRelease,
        //     "onHover",         &GameObject::Methods::onHover,
        //     "onStopHover",     &GameObject::Methods::onStopHover,
        //     "onDrag",          &GameObject::Methods::onDrag,
        //     "onStopDrag",      &GameObject::Methods::onStopDrag
        // );

        // //
        // // 2) Nested State
        // //
        // lua.new_usertype<GameObject::State>("GameObjectState",
        //     sol::constructors<>(),
        //     "visible",                   &GameObject::State::visible,
        //     "collisionEnabled",          &GameObject::State::collisionEnabled,
        //     "isColliding",               &GameObject::State::isColliding,
        //     "focusEnabled",              &GameObject::State::focusEnabled,
        //     "isBeingFocused",            &GameObject::State::isBeingFocused,
        //     "hoverEnabled",              &GameObject::State::hoverEnabled,
        //     "isBeingHovered",            &GameObject::State::isBeingHovered,
        //     "enlargeOnHover",            &GameObject::State::enlargeOnHover,
        //     "enlargeOnDrag",             &GameObject::State::enlargeOnDrag,
        //     "clickEnabled",              &GameObject::State::clickEnabled,
        //     "isBeingClicked",            &GameObject::State::isBeingClicked,
        //     "dragEnabled",               &GameObject::State::dragEnabled,
        //     "isBeingDragged",            &GameObject::State::isBeingDragged,
        //     "triggerOnReleaseEnabled",   &GameObject::State::triggerOnReleaseEnabled,
        //     "isTriggeringOnRelease",     &GameObject::State::isTriggeringOnRelease,
        //     "isUnderOverlay",            &GameObject::State::isUnderOverlay
        // );

        // //
        // // 3) The main GameObject
        // //
        // lua.new_usertype<GameObject>("GameObject",
        //     sol::constructors<>(),  // default constructor

        //     // basic hierarchy & containers
        //     "parent",               &GameObject::parent,
        //     "children",             &GameObject::children,
        //     "orderedChildren",      &GameObject::orderedChildren,
        //     "ignoresPause",         &GameObject::ignoresPause,
        //     "container",            &GameObject::container,
        //     "collisionTransform",   &GameObject::collisionTransform,
        //     "clickTimeout",         &GameObject::clickTimeout,

        //     // optional custom Methods table
        //     "methods",              &GameObject::methods,

        //     // script‐driven hooks
        //     "updateFunction",       &GameObject::updateFunction,
        //     "drawFunction",         &GameObject::drawFunction,

        //     // mutable state and offsets
        //     "state",                &GameObject::state,
        //     "dragOffset",           &GameObject::dragOffset,
        //     "clickOffset",          &GameObject::clickOffset,
        //     "hoverOffset",          &GameObject::hoverOffset,

        //     // parallax/shadow
        //     "shadowDisplacement",    &GameObject::shadowDisplacement,
        //     "layerDisplacement",     &GameObject::layerDisplacement,
        //     "layerDisplacementPrev", &GameObject::layerDisplacementPrev,
        //     "shadowHeight",          &GameObject::shadowHeight
        // );

        // //
        // // 4) Collision‐ordering structs
        // //
        // lua.new_usertype<CollisionOrderInfo>("CollisionOrderInfo",
        //     sol::constructors<>(),
        //     "hasCollisionOrder", &CollisionOrderInfo::hasCollisionOrder,
        //     "parentBox",         &CollisionOrderInfo::parentBox,
        //     "treeOrder",         &CollisionOrderInfo::treeOrder,
        //     "layerOrder",        &CollisionOrderInfo::layerOrder
        // );

        // lua.new_usertype<TreeOrderComponent>("TreeOrderComponent",
        //     sol::constructors<>(),
        //     "order",             &TreeOrderComponent::order
        // );
        
        
        // // 1) Initialization
        // lua.set_function("InitializeTransformSystem", &transform::InitializeSystem);

        // // 2) Bulk update & creation
        // lua.set_function("UpdateAllTransforms",            &transform::UpdateAllTransforms);
        // lua.set_function("CreateOrEmplace",                &transform::CreateOrEmplace);
        // lua.set_function("CreateGameWorldContainerEntity", &transform::CreateGameWorldContainerEntity);

        // // 3) Per‐entity updates & alignment
        // lua.set_function("UpdateTransformSmoothingFactors", &transform::UpdateTransformSmoothingFactors);
        // lua.set_function("AlignToMaster",                   &transform::AlignToMaster);
        // lua.set_function("MoveWithMaster",                  &transform::MoveWithMaster);
        // lua.set_function("UpdateLocation",                  &transform::UpdateLocation);
        // lua.set_function("UpdateSize",                      &transform::UpdateSize);
        // lua.set_function("UpdateRotation",                  &transform::UpdateRotation);
        // lua.set_function("UpdateScale",                     &transform::UpdateScale);

        // // 4) Master‐child management
        // lua.set_function("GetMaster", 
        //     [](entt::entity e,
        //        Transform& selfT,
        //        InheritedProperties& selfR,
        //        GameObject& selfN)
        //     {
        //         // these will be filled by your real function:
        //         Transform*              parentT = nullptr;
        //         InheritedProperties*    parentR = nullptr;
        
        //         auto cache = transform::GetMaster(
        //           e, selfT, selfR, selfN,
        //           parentT,      // passed by reference
        //           parentR       // passed by reference
        //         );
        
        //         // return three values: cache, parentT, parentR
        //         return std::make_tuple(cache, parentT, parentR);
        //     }
        // );
        // lua.set_function("SyncPerfectlyToMaster",&transform::SyncPerfectlyToMaster);

        // // 5) Dynamic‐motion & parallax
        // lua.set_function("UpdateDynamicMotion",      &transform::UpdateDynamicMotion);
        // lua.set_function("InjectDynamicMotion",      &transform::InjectDynamicMotion);
        // lua.set_function("UpdateParallaxCalculations",&transform::UpdateParallaxCalculations);

        // // 6) Convenience & configuration
        // lua.set_function("ConfigureAlignment", &transform::ConfigureAlignment);
        // lua.set_function("AssignRole",         &transform::AssignRole);
        // lua.set_function("SnapTransformValues",       &transform::SnapTransformValues);
        // lua.set_function("SnapVisualTransformValues", &transform::SnapVisualTransformValues);

        // // 7) Drawing & debug
        // lua.set_function("DrawBoundingBoxAndDebugInfo", &transform::DrawBoundingBoxAndDebugInfo);

        // // 8) Cursor & collision helpers
        // lua.set_function("CalculateCursorPositionWithinFocus", &transform::CalculateCursorPositionWithinFocus);
        // lua.set_function("CheckCollisionWithPoint",            &transform::CheckCollisionWithPoint);
        // lua.set_function("FindTopEntityAtPoint",               &transform::FindTopEntityAtPoint);
        // lua.set_function("FindAllEntitiesAtPoint",             &transform::FindAllEntitiesAtPoint);
        // lua.set_function("GetCollisionOrderInfo",              &transform::GetCollisionOrderInfo);

        // // 9) Input handlers
        // lua.set_function("HandleClick",         &transform::HandleClick);
        // lua.set_function("HandleClickReleased", &transform::HandleClickReleased);
        // lua.set_function("StartDrag",           &transform::StartDrag);
        // lua.set_function("StopDragging",        &transform::StopDragging);
        // lua.set_function("StartHover",          &transform::StartHover);
        // lua.set_function("StopHover",           &transform::StopHover);
        // lua.set_function("GetCursorOnFocus",    &transform::GetCursorOnFocus);

        // // 10) Container & translation helpers
        // lua.set_function("ConfigureContainerForEntity",     &transform::ConfigureContainerForEntity);
        // lua.set_function("ApplyTranslationFromEntityContainer", &transform::ApplyTranslationFromEntityContainer);

        // // 11) Utility & cleanup
        // lua.set_function("GetDistanceBetween",  &transform::GetDistanceBetween);
        // lua.set_function("RemoveEntity",        &transform::RemoveEntity);
        // lua.set_function("SetClickOffset",      &transform::SetClickOffset);
        // lua.set_function("GetObjectToDrag",     &transform::GetObjectToDrag);
        // lua.set_function("Draw",                &transform::Draw);
        // lua.set_function("updateTransformCacheForAllTransforms", &transform::updateTransformCacheForAllTransforms);
        // lua.set_function("setJiggleOnHover",    &transform::setJiggleOnHover);
    }

}
