#include "transform_functions.hpp"

#include "raylib.h"
#include <cmath>

#include "systems/main_loop_enhancement/main_loop.hpp"
#include "systems/layer/layer.hpp"
#include "systems/ui/util.hpp"
#include "systems/ui/element.hpp"
#include "systems/text/textVer2.hpp"
#include "systems/ui/box.hpp"

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
        {TransformMethod::MoveWithMaster, std::function<void(entt::registry *, entt::entity, float)>(MoveWithMaster)},
        {TransformMethod::UpdateLocation, std::function<void(entt::registry *, entt::entity, float)>(UpdateLocation)},
        {TransformMethod::UpdateSize, std::function<void(entt::registry *, entt::entity, float)>(UpdateSize)},
        {TransformMethod::UpdateRotation, std::function<void(entt::registry *, entt::entity, float)>(UpdateRotation)},
        {TransformMethod::UpdateScale, std::function<void(entt::registry *, entt::entity, float)>(UpdateScale)},
        {TransformMethod::GetMaster, std::function<Transform::FrameCalculation::MasterCache(entt::registry *, entt::entity)>(GetMaster)},
        {TransformMethod::SyncPerfectlyToMaster, std::function<void(entt::registry *, entt::entity, entt::entity)>(SyncPerfectlyToMaster)},
        {TransformMethod::UpdateDynamicMotion, std::function<void(entt::registry *, entt::entity, float)>(UpdateDynamicMotion)},
        {TransformMethod::InjectDynamicMotion, std::function<void(entt::registry *, entt::entity, float, float)>(InjectDynamicMotion)},
        {TransformMethod::UpdateParallaxCalculations, std::function<void(entt::registry *, entt::entity)>(UpdateParallaxCalculations)},
        {TransformMethod::ConfigureAlignment, std::function<void(entt::registry *, entt::entity, bool, entt::entity, std::optional<InheritedProperties::Sync>, std::optional<InheritedProperties::Sync>, std::optional<InheritedProperties::Sync>, std::optional<InheritedProperties::Sync>, std::optional<int>, std::optional<Vector2>)>(ConfigureAlignment)},
        {TransformMethod::AssignRole, std::function<void(entt::registry *, entt::entity, std::optional<InheritedProperties::Type>, entt::entity, std::optional<InheritedProperties::Sync>, std::optional<InheritedProperties::Sync>, std::optional<InheritedProperties::Sync>, std::optional<InheritedProperties::Sync>, std::optional<Vector2>)>(AssignRole)},
        {TransformMethod::UpdateTransform, std::function<void(entt::registry *, entt::entity, float)>(UpdateTransform)},
        {TransformMethod::SnapTransformValues, std::function<void(entt::registry *, entt::entity, float, float, float, float)>(SnapTransformValues)},
        {TransformMethod::SnapVisualTransformValues, std::function<void(entt::registry *, entt::entity)>(SnapVisualTransformValues)},
        {TransformMethod::DrawBoundingBoxAndDebugInfo, std::function<void(entt::registry *, entt::entity, std::shared_ptr<layer::Layer>)>(DrawBoundingBoxAndDebugInfo)},
        {TransformMethod::CalculateCursorPositionWithinFocus, std::function<Vector2(entt::registry *, entt::entity)>(CalculateCursorPositionWithinFocus)},
        {TransformMethod::CheckCollisionWithPoint, std::function<bool(entt::registry *, entt::entity, Vector2)>(CheckCollisionWithPoint)},
        {TransformMethod::HandleClick, std::function<void(entt::registry *, entt::entity)>(HandleClick)},
        {TransformMethod::HandleClickReleased, std::function<void(entt::registry *, entt::entity)>(HandleClickReleased)},
        {TransformMethod::SetClickOffset, std::function<void(entt::registry *, entt::entity, Vector2, bool)>(SetClickOffset)},
        {TransformMethod::GetObjectToDrag, std::function<std::optional<entt::entity>(entt::registry *, entt::entity)>(GetObjectToDrag)},
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
        auto &transform = registry->emplace_or_replace<Transform>(e, registry); 
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
        node.methods->onHover = [jiggleAmount](entt::registry &registry, entt::entity e) {
            transform::InjectDynamicMotion(&registry, e, jiggleAmount, 1.f);
        };
    }


    //EXPOSED publicly
    // creates a container the size of the map which will serve as the root entity for the game world
    auto CreateGameWorldContainerEntity(entt::registry *registry, float x, float y, float w, float h) -> entt::entity
    {
        //TODO: use create() method for this
        auto e = registry->create();
        auto &transform = registry->emplace<Transform>(e, registry);
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
        if (node.methods->onClick) {
            node.methods->onClick(*registry, e);
        }
    }
    
    //EXPOSED publicly
    auto HandleClickReleased(entt::registry *registry, entt::entity e) -> void
    {
        if (registry->valid(e) == false) return;
        
        auto &node = registry->get<transform::GameObject>(e);
        if (node.methods->onRelease) {
            node.methods->onRelease(*registry, e, entt::null);
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
                
                DrawBoundingBoxAndDebugInfo(registry, child, layer);
                auto &childNode = registry->get<GameObject>(child);
                if (childNode.state.visible  && childNode.state.visible && childNode.methods->draw) {
                    childNode.methods->draw(layer, *registry, child);
                }
                
            }
        }
        
        // custom drawing if there is any
        if (node.methods->draw) {
            node.methods->draw(layer, *registry, e);
        }
    }

    // not exposed publicly
    auto AlignToMaster(entt::registry *registry, entt::entity e, bool forceAlign) -> void
    {
        //TODO: this sshould probably take into account cases where parent has its own offset. (due to alignment)
        auto &role = registry->get<InheritedProperties>(e);
        auto &transform = registry->get<Transform>(e);

        // if alignment and offset unchanged
        if (role.flags->alignment == role.flags->prevAlignment && role.offset->x == role.prevOffset->x && role.offset->y == role.prevOffset->y && forceAlign == false)
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

    // not exposed
    auto MoveWithMaster(entt::registry *registry, entt::entity e, float dt) -> void
    {
        
        // debug break
        if (e == static_cast<entt::entity>(7))
        {
            // SPDLOG_DEBUG("Moving Text found in MoveWithMaster");

            auto &text = registry->get<TextSystem::Text>(e);

            // SPDLOG_DEBUG("Text: {}", text.rawText);
        }
        
        Vector2 tempRotatedOffset{};
        Vector2 tempIntermediateOffsets{};
        float tempAngleCos = 0.0f;
        float tempAngleSin = 0.0f;
        float tempWidth = 0.0f;
        float tempHeight = 0.0f;

        auto &selfRole = registry->get<InheritedProperties>(e);
        auto &selfTransform = registry->get<Transform>(e);

        if (registry->valid(selfRole.master) == false)
        {
            return; // no parent to move with
        }


        //REVIEW: getmaster allows multi-level master-slave trees.
        //FIXME: the offset it returns isn't used at the moment. Using it breaks the system for some reason
        auto parentRetVal = GetMaster(registry, e);
        auto parent = parentRetVal.master.value();
        auto *parentTransform = registry->try_get<Transform>(parent);
        auto *parentRole = registry->try_get<InheritedProperties>(parent);

        // FIXME: hacky fix: if this is a ui element's object, we need to use the immediate master
        bool isUIElementObject = registry->any_of<TextSystem::Text, AnimationQueueComponent>(e);

        if (isUIElementObject) //FIXME: is this enough?
        {
            parentTransform = registry->try_get<Transform>(selfRole.master);
            parentRole = registry->try_get<InheritedProperties>(selfRole.master);
        }

        // auto emptyRole = InheritedProperties{};
        // if (parent == parentRole->master)
        // {
        //     return;
        //     // point to an empty role
        //     parentRole = &emptyRole;
        // }

        //REVIEW: parentRole's offset is always zero. Why?
        //REVIEW: actual immediate parent (selfRole.master) is never the same as GetMaster's master.

        UpdateDynamicMotion(registry, e, dt);
        
        auto &parentNode = registry->get<GameObject>(parent);
        auto &selfNode = registry->get<GameObject>(e);
        Vector2 layeredDisplacement = selfNode.layerDisplacement.value_or(Vector2{0, 0});
        
        if (layeredDisplacement.x != 0 && layeredDisplacement.y != 0) {
            // SPDLOG_DEBUG("Layered displacement: x: {}, y: {}", layeredDisplacement.x, layeredDisplacement.y);
        }

        if (selfRole.location_bond == InheritedProperties::Sync::Weak)
        {
            tempRotatedOffset.x = selfRole.offset->x + (isUIElementObject ? 0 : parentRole->offset->x) + layeredDisplacement.x; // ignore the additional offset if this is a UI element object (REVIEW: not sure if this is correct)
            tempRotatedOffset.y = selfRole.offset->y + (isUIElementObject ? 0 : parentRole->offset->y) + layeredDisplacement.y;
        }
        else
        {
            if (parentTransform->getVisualR() < 0.0001f && parentTransform->getVisualR() > -0.0001f)
            {
                tempRotatedOffset.x = selfRole.offset->x + (isUIElementObject ? 0 : parentRole->offset->x) + layeredDisplacement.x; //TODO: selfRole.offset not initialized
                tempRotatedOffset.y = selfRole.offset->y + (isUIElementObject ? 0 : parentRole->offset->x) + layeredDisplacement.y;
            }
            else
            {
                tempAngleCos = cos(parentTransform->getVisualR());
                tempAngleSin = sin(parentTransform->getVisualR());
                tempWidth = -selfTransform.getActualW() / 2 + parentTransform->getActualW() / 2;
                tempHeight = -selfTransform.getActualH() / 2 + parentTransform->getActualH() / 2;
                tempIntermediateOffsets.x = selfRole.offset->x + (isUIElementObject ? 0 : parentRole->offset->x) + layeredDisplacement.x - tempWidth;
                tempIntermediateOffsets.y = selfRole.offset->y + (isUIElementObject ? 0 : parentRole->offset->x) + layeredDisplacement.y - tempHeight;
                tempRotatedOffset.x = tempIntermediateOffsets.x * tempAngleCos - tempIntermediateOffsets.y * tempAngleSin + tempWidth;
                tempRotatedOffset.y = tempIntermediateOffsets.x * tempAngleSin + tempIntermediateOffsets.y * tempAngleCos + tempHeight;
            }
        }
    
    
        //TODO: these two lines cause issues. why?
        selfTransform.getXSpring().targetValue = parentTransform->getXSpring().value + tempRotatedOffset.x;
        selfTransform.getYSpring().targetValue = parentTransform->getYSpring().value + tempRotatedOffset.y;
        // SPDLOG_DEBUG("Moving with master set to targets: x: {}, y: {}", selfTransform.getXSpring().targetValue, selfTransform.getYSpring().targetValue);

        if (selfRole.location_bond == InheritedProperties::Sync::Strong)
        {
            selfTransform.getXSpring().value = selfTransform.getXSpring().targetValue;
            selfTransform.getYSpring().value = selfTransform.getYSpring().targetValue;
        }
        else if (selfRole.location_bond == InheritedProperties::Sync::Weak)
        {
            UpdateLocation(registry, e, dt);
        }

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
            selfTransform.setVisualRotation(selfTransform.getActualRotation() + parentTransform->rotationOffset + (juiceFactor));
        }
        else if (selfRole.rotation_bond == InheritedProperties::Sync::Weak)
        {
            UpdateRotation(registry, e, dt);
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
            selfTransform.setVisualScale(selfTransform.getActualScale() * (parentTransform->getVisualScale() / parentTransform->getActualScale()) + juiceFactor);
        }
        else if (selfRole.scale_bond == InheritedProperties::Sync::Weak)
        {
            UpdateScale(registry, e, dt);
        }

        if (selfRole.size_bond == InheritedProperties::Sync::Strong)
        {
            selfTransform.setVisualX(selfTransform.getVisualX() + (0.5f * (1 - parentTransform->getVisualW() / parentTransform->getActualW()) * selfTransform.getActualW()));
            selfTransform.setVisualW(selfTransform.getActualW() * (parentTransform->getVisualW() / parentTransform->getActualW()));
            selfTransform.setVisualH(selfTransform.getActualH() * (parentTransform->getVisualH() / parentTransform->getActualH()));
        }
        else if (selfRole.size_bond == InheritedProperties::Sync::Weak)
        {
            UpdateSize(registry, e, dt);
        }

        UpdateParallaxCalculations(registry, e);
    }

    // not exposed
    auto UpdateLocation(entt::registry *registry, entt::entity e, float dt) -> void
    {
        // nothing to do here, springs will update on their own

        auto &transform = registry->get<Transform>(e);
        auto &springX = transform.getXSpring();
        auto &springY = transform.getYSpring();
        if (springX.velocity > 0.0001f || springY.velocity > 0.0001f)
        {
            transform.frameCalculation.stationary = false;
        }
    }

    // not exposed
    auto UpdateSize(entt::registry *registry, entt::entity e, float dt) -> void
    {
        // nothing to do here, springs will update on their own

        auto &transform = registry->get<Transform>(e);
        auto &springW = transform.getWSpring();
        auto &springH = transform.getHSpring();

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
    auto UpdateRotation(entt::registry *registry, entt::entity e, float dt) -> void
    {
        // nothing to do here, springs will update on their own

        auto &transform = registry->get<Transform>(e);
        auto &springR = transform.getRSpring();
        auto &springX = transform.getXSpring();

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

        // add dynamic motion
        transform.rotationOffset += dynamicMotionAddedR;

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
    auto UpdateScale(entt::registry *registry, entt::entity e, float dt) -> void
    {
        // nothing to do here, springs will update on their own
        auto &transform = registry->get<Transform>(e);
        auto &springScale = transform.getSSpring();
        if (springScale.velocity > 0.0001f)
        {
            transform.frameCalculation.stationary = false;
        }
    }

    //TODO: get master might be the problem
    // observation: this does not take container coordinates into account. Only node methods do.
    auto GetMaster(entt::registry *registry, entt::entity e) -> Transform::FrameCalculation::MasterCache
    {
        auto &selfRole = registry->get<InheritedProperties>(e);
        auto &selfTransform = registry->get<Transform>(e);
        auto &selfNode = registry->get<GameObject>(e);

        Transform::FrameCalculation::MasterCache toReturn{};
        toReturn.master = e;             // self is its own parent
        toReturn.offset = Vector2{0, 0}; // fallback values

        if (selfRole.master == globals::gameWorldContainerEntity)
        {
            SPDLOG_DEBUG("Master is game world container");
        }

        // checks
        if (selfRole.role_type == InheritedProperties::Type::RoleRoot)
        {
            return toReturn; // parents have no parent
        }

        if (selfRole.master == e)
        {
            return toReturn; // it is its own parent (prob shouldn't happen)
        }

        if (selfRole.location_bond == InheritedProperties::Sync::Weak && selfRole.rotation_bond == InheritedProperties::Sync::Weak)
        {
            return toReturn; // rotation and X must be strong, treat like no parent
        }

        // recalculate parent details and offsets
        if (!selfTransform.frameCalculation.currentMasterCache || globals::REFRESH_FRAME_MASTER_CACHE)
        {
            // reset parent cache if empty
            if (!selfTransform.frameCalculation.currentMasterCache)
            {
                selfTransform.frameCalculation.currentMasterCache = Transform::FrameCalculation::MasterCache{};
            }

            selfTransform.frameCalculation.tempOffsets = Vector2{0, 0};

            auto parentResults = GetMaster(registry, selfRole.master); // recursively get offsets, add them all

            selfTransform.frameCalculation.currentMasterCache->master = parentResults.master;
            selfTransform.frameCalculation.currentMasterCache->offset = parentResults.offset.value_or(selfTransform.frameCalculation.tempOffsets.value());
            selfTransform.frameCalculation.currentMasterCache->offset->x = parentResults.offset->x + selfRole.offset->x + selfNode.layerDisplacement->x;
            selfTransform.frameCalculation.currentMasterCache->offset->y = parentResults.offset->y + selfRole.offset->y + selfNode.layerDisplacement->y;
        }

        // save values in return value
        toReturn.master = selfTransform.frameCalculation.currentMasterCache->master;
        toReturn.offset = selfTransform.frameCalculation.currentMasterCache->offset;

        return toReturn;
    }

    auto SyncPerfectlyToMaster(entt::registry *registry, entt::entity e, entt::entity parent) -> void
    {
        auto &selfRole = registry->get<InheritedProperties>(e);
        auto &parentRole = registry->get<InheritedProperties>(parent);
        auto &selfTransform = registry->get<Transform>(e);
        auto &parentTransform = registry->get<Transform>(parent);

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


    auto UpdateDynamicMotion(entt::registry *registry, entt::entity e, float dt) -> void
    {

        auto &selfTransform = registry->get<Transform>(e);
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

    auto UpdateAllTransforms(entt::registry *registry, float dt) -> void
    {
        auto view = registry->view<Transform, InheritedProperties, GameObject>();
        for (auto e : view)
        {
            UpdateTransform(registry, e, dt);
        }
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
    auto UpdateTransform(entt::registry *registry, entt::entity e, float dt) -> void
    {
        // SPDLOG_DEBUG("Updating transform for entity {}", static_cast<int>(e));
        // debug break
        if (registry->any_of<ui::UIBoxComponent>(e))
        {
            // SPDLOG_DEBUG("UIBoxComponent found in UpdateTransform");
            
        }
        
        //  use main_loop::mainLoop.frame
        auto &transform = registry->get<Transform>(e);
        auto &role = registry->get<InheritedProperties>(e);
        auto &node = registry->get<GameObject>(e);

        if (transform.frameCalculation.lastUpdatedFrame >= main_loop::mainLoop.frame)
        {
            // SPDLOG_DEBUG("Transform already updated this frame");
            return; // already updated this frame
        }

        // cache some values here
        transform.frameCalculation.oldMasterCache = transform.frameCalculation.currentMasterCache;
        transform.frameCalculation.currentMasterCache.reset();
        transform.frameCalculation.lastUpdatedFrame = main_loop::mainLoop.frame; // save frame counter

        if (node.ignoresPause == false && globals::isGamePaused)
        {
            return; // don't move if paused
        }

        AlignToMaster(registry, e);

        node.debug.calculationsInProgress = false;

        if (role.role_type == InheritedProperties::Type::RoleCarbonCopy)
        {
            if (registry->valid(role.master))
            {
                SyncPerfectlyToMaster(registry, e, role.master);
            }
        }

        else if (role.role_type == InheritedProperties::Type::RoleInheritor)
        {
            
            if (registry->valid(role.master))
            {
                auto &parentTransform = registry->get<Transform>(role.master);
                // recursively move on parent
                if (parentTransform.frameCalculation.lastUpdatedFrame < main_loop::mainLoop.frame)
                {
                    UpdateTransform(registry, role.master, dt);
                }
                
                transform.frameCalculation.stationary = parentTransform.frameCalculation.stationary;

                if ((transform.frameCalculation.stationary == false) || (transform.frameCalculation.alignmentChanged) || (transform.dynamicMotion) || (role.location_bond == InheritedProperties::Sync::Weak) || (role.rotation_bond == InheritedProperties::Sync::Weak))
                {

                    node.debug.calculationsInProgress = true;
                    MoveWithMaster(registry, e, dt);
                }
            }
            
        }

        else if (role.role_type == InheritedProperties::Type::PermanentAttachment)
        {
            // ignore sync bonds
            auto &parentTransform = registry->get<Transform>(role.master);
            if (registry->valid(role.master))
            {
                // recursively move on parent
                if (parentTransform.frameCalculation.lastUpdatedFrame < main_loop::mainLoop.frame)
                {
                    UpdateTransform(registry, role.master, dt);
                }
            }

            // Fully inherit parent's stationary state
            transform.frameCalculation.stationary = parentTransform.frameCalculation.stationary;

            float parentRotationAngle = parentTransform.getVisualRWithDynamicMotionAndXLeaning();

            // convert to radians
            float angle = parentRotationAngle * DEG2RAD;

            // parent center
            float parentCenterX = parentTransform.getVisualX() + parentTransform.getVisualW() * 0.5;
            float parentCenterY = parentTransform.getVisualY() + parentTransform.getVisualH() * 0.5;

            // child's offset relative to the parent's center
            float childOffsetX = role.offset->x - parentTransform.getVisualW() * 0.5 + transform.getVisualW() * 0.5;
            float childOffsetY = role.offset->y - parentTransform.getVisualH() * 0.5 + transform.getVisualH() * 0.5;

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
            transform.frameCalculation.stationary = true;
            UpdateDynamicMotion(registry, e, dt);
            UpdateLocation(registry, e, dt);
            UpdateSize(registry, e, dt);
            UpdateRotation(registry, e, dt);
            UpdateScale(registry, e, dt);
            UpdateParallaxCalculations(registry, e);
        }

        // reset alignment change
        transform.frameCalculation.alignmentChanged = false;

        node.state.isColliding = false; // clear flag
        
        // call custom update function if it exists
        if (node.methods->update) node.methods->update(*registry, e, dt);
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

    auto DrawBoundingBoxAndDebugInfo(entt::registry *registry, entt::entity e, std::shared_ptr<layer::Layer> layer) -> void
    {

        if (debugMode == false)
            return;

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

        layer::AddPushMatrix(layer);

        layer::AddTranslate(layer, transform.getVisualX() + transform.getVisualW() * 0.5, transform.getVisualY() + transform.getVisualH() * 0.5);

        layer::AddScale(layer, transform.getVisualScaleWithHoverAndDynamicMotionReflected(), transform.getVisualScaleWithHoverAndDynamicMotionReflected());

        layer::AddRotate(layer, transform.getVisualR() + transform.rotationOffset);

        layer::AddTranslate(layer, -transform.getVisualW() * 0.5, -transform.getVisualH() * 0.5);

        // draw shadow based on shadow displacement
        // if (node.shadowDisplacement)
        // {
        //     float baseExaggeration = globals::BASE_SHADOW_EXAGGERATION;
        //     float heightFactor = 1.0f + node.shadowHeight.value_or(0.f); // Increase effect based on height

        //     // Adjust displacement using shadow height
        //     float shadowOffsetX = node.shadowDisplacement->x * baseExaggeration * heightFactor;
        //     float shadowOffsetY = node.shadowDisplacement->y * baseExaggeration * heightFactor;

        //     // Translate to shadow position
        //     layer::AddTranslate(layer, -shadowOffsetX, shadowOffsetY);

        //     // Draw shadow outline
        //     // layer::AddRectangleLinesPro(layer, 0, 0, Vector2{transform.getVisualW(), transform.getVisualH()}, lineWidth, BLACK);
        //     layer::AddRectanglePro(layer, 0, 0, Vector2{transform.getVisualW(), transform.getVisualH()}, Fade(BLACK, 0.7f));

        //     // Reset translation to original position
        //     layer::AddTranslate(layer, shadowOffsetX, -shadowOffsetY);
        // }
        auto scale = 1.0f;
        if (registry->any_of<ui::UIConfig>(e))
        {
            auto &uiConfig = registry->get<ui::UIConfig>(e);
            scale = uiConfig.scale.value_or(1.0f);
        }

        if (node.debug.debugText)
        {
            
            float textWidth = MeasureText(node.debug.debugText.value().c_str(), 15 * scale);
            layer::AddText(layer, node.debug.debugText.value(), GetFontDefault(), transform.getVisualW() / 2 - textWidth / 2, transform.getVisualH() * 0.05f, WHITE, 15 * scale);
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
            layer::AddText(layer, debugText, GetFontDefault(), transform.getVisualW() / 2 - textWidth / 2, transform.getVisualH() * 0.05f, WHITE, 15 * scale);
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

        layer::AddRectangleLinesPro(layer, 0, 0, Vector2{transform.getVisualW(), transform.getVisualH()}, lineWidth, lineColor);
        
        // draw emboss effect rect
        auto *uiConfig = registry->try_get<ui::UIConfig>(e);
        if (uiConfig && uiConfig->emboss)
        {
            float embossHeight = uiConfig->emboss.value() * uiConfig->scale.value();
            layer::AddRectanglePro(layer, 0, transform.getActualH(), Vector2{transform.getActualW(), embossHeight}, Fade(BLACK, 0.3f));
        }

        layer::AddPopMatrix(layer);
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
        if (node.methods->onDrag) {
            node.methods->onDrag(*registry, e);
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
        if (node.methods->getObjectToDrag)
        {
            return node.methods->getObjectToDrag(*registry, e);
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
        
        if (registry->any_of<ui::UIConfig>(e) == false)
        {
            return;
        }
        
        auto &node = registry->get<GameObject>(e);
        auto &uiConfig = registry->get<ui::UIConfig>(e);
        
        // drag pop-up (for controlller drag, for instance) exists
        if (node.children.find("d_popup") == node.children.end()) return;
        
        ui::box::Remove(*registry, node.children["d_popup"]);
        
        // erase
        node.children.erase("d_popup");
        // erase from vector as well
        auto it = std::remove(node.orderedChildren.begin(), node.orderedChildren.end(), node.children["d_popup"]);
        node.orderedChildren.erase(it, node.orderedChildren.end());
        
        // custom stop drag logic
        if (node.methods->onStopDrag) {
            node.methods->onStopDrag(*registry, e);
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
        if (node.methods->onHover) {
            node.methods->onHover(*registry, e);
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
        if (node.methods->onStopHover) {
            node.methods->onStopHover(*registry, e);
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

        layer::AddTranslate(layer, containerTransform.getActualW() * 0.5, containerTransform.getActualH() * 0.5);
        layer::AddRotate(layer, containerTransform.getActualRotation());
        layer::AddTranslate(layer, -containerTransform.getActualW() * 0.5 + containerTransform.getActualX(),
                            -containerTransform.getActualH() * 0.5 + containerTransform.getActualY());
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

}
