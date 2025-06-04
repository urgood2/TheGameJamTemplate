#pragma once

#include "transform.hpp"

#include "entt/entt.hpp"

#include "systems/layer/layer.hpp"

#include "core/globals.hpp"

// event for before method and after method, configuration determines whether 
// default methods are called or not.
namespace transform
{
    extern inline auto InitializeSystem() -> void {
        // Initialize the transform system here if needed
        transform::registerDestroyListeners(globals::registry);
    }

    extern std::unordered_map<TransformMethod, std::any> transformFunctionsDefault, hooksToCallBeforeDefault, hooksToCallAfterDefault;
    
    //TODO: use this as public interface?
    //TODO: apply this within transform class, also hide the implementation details from public 
    /**
     * @brief Executes a registered transform function for a given entity, while also invoking 
     *        any registered "before" and "after" hooks.
     * 
     * @tparam Ret The return type of the function (typically `void` in this case).
     * @tparam Args The argument types expected by the transform method.
     * @param registry Reference to the EnTT registry containing entity-component data.
     * @param e The entity whose transform function is being executed.
     * @param method The transformation method to execute (e.g., `TransformMethod::UpdateTransform`).
     * @param args The arguments to be passed to the function (typically `dt` for delta time).
     * 
     * @note The function:
     *       - Ensures the requested method exists in `transformFunctions`.
     *       - Calls any registered "before" hooks.
     *       - Calls the actual transform function.
     *       - Calls any registered "after" hooks.
     * 
     * @warning If the requested function is not found in `transformFunctions`, an assertion failure occurs.
     * 
     * @example
     * ```
     * ExecuteCallsForTransformMethod<void>(registry, entity, TransformMethod::UpdateTransform, 0.16f);
     * ```
     */
    template <typename Ret, typename... Args>
    inline auto ExecuteCallsForTransformMethod(entt::registry& registry, entt::entity e, TransformMethod method, Args... args) -> void {

        // if e is null, use the default definitions for the methods (some methods don't work for a specific entity)
        std::unordered_map<TransformMethod, std::any>* transformFunctions, * hooksToCallBefore, * hooksToCallAfter;

        if (registry.valid(e)) {
            auto &gameObject = registry.get<GameObject>(e);
            transformFunctions = &gameObject.transformFunctions;
            hooksToCallBefore = &gameObject.hooksToCallBefore;
            hooksToCallAfter = &gameObject.hooksToCallAfter;
        }
        else {
            transformFunctions = &transformFunctionsDefault;
            hooksToCallBefore = &hooksToCallBeforeDefault;
            hooksToCallAfter = &hooksToCallAfterDefault;
        }

        // Ensure the default method exists
        AssertThat(transformFunctions->find(method) != transformFunctions->end(), Is().EqualTo(true));

        // Call before hooks
        if (hooksToCallBefore->find(method) != hooksToCallBefore->end()) {
            auto &hook = hooksToCallBefore->at(method);
            auto castHook = std::any_cast<std::function<Ret(Args...)>>(hook);
            castHook(args...);
        }

        // Call the default method
        auto &func = transformFunctions->at(method);
        auto castFunc = std::any_cast<std::function<Ret(Args...)>>(func);
        castFunc(args...);

        // Call after hooks
        if (hooksToCallAfter->find(method) != hooksToCallAfter->end()) {
            auto &hook = hooksToCallAfter->at(method);
            auto castHook = std::any_cast<std::function<Ret(Args...)>>(hook);
            castHook(args...);
        }
    }


    auto UpdateAllTransforms(entt::registry *registry, float dt) -> void;
    
    auto handleDefaultTransformDrag(entt::registry *registry, entt::entity e, std::optional<Vector2> offset = std::nullopt) -> void;

    /** 
     * creates an empty entity with a transform component, node component, and role component
     * container should be a root entity the size of the map
     */
    auto CreateOrEmplace(entt::registry *registry, entt::entity container, float x, float y, float w, float h, std::optional<entt::entity> entityToEmplaceTo = std::nullopt) -> entt::entity;

    auto CreateGameWorldContainerEntity(entt::registry *registry, float x, float y, float w, float h) -> entt::entity;

    /**
     * This method should be called every frame for a transform/node entity
     */
    auto UpdateTransformSmoothingFactors(entt::registry *registry, entt::entity e, float dt) -> void;

    /**
     * Align a child entity to its parent based on alignment and offset properties.
     */
    auto AlignToMaster(entt::registry *registry, entt::entity e, bool force = false) -> void;

    /**
     * Update the position of a child entity to move with its parent entity.
     * Handles both weak and strong bonds.
     */
    auto MoveWithMaster(entt::entity e, float dt, Transform &selfTransform, InheritedProperties &selfRole, GameObject &selfNode) -> void;

    /**
     * Update X and Y springs for smooth transformations.
     */
    auto UpdateLocation(entt::entity e, float dt, Transform &transform, spring::Spring &springX, spring::Spring &springY) -> void;

    /**
     * Update width and height springs for smooth size transformations.
     */
    auto UpdateSize(entt::entity e, float dt, Transform &transform, spring::Spring &springW, spring::Spring springH) -> void;

    /**
     * Update rotation spring for smooth rotation transformations.
     */
    auto UpdateRotation(entt::entity e, float dt, Transform &transform, spring::Spring &springR, spring::Spring &springX) -> void;


    /**
     * Update scale spring for smooth scaling transformations.
     */
    auto UpdateScale(entt::entity e, float dt, Transform &transform, spring::Spring &springS) -> void;

    /**
     * Retrieve the parent entity of the given entity.
     */
    auto GetMaster(entt::entity e, Transform &selfTransform, InheritedProperties &selfRole, GameObject &selfNode, Transform *parentTransform, InheritedProperties *parentRole) -> Transform::FrameCalculation::MasterCache;

    /**
     * Glue a child entity to its parent, forcing alignment of all transformations.
     */
    auto SyncPerfectlyToMaster(entt::entity e, entt::entity parent, Transform &selfTransform, InheritedProperties &selfRole, Transform &parentTransform, InheritedProperties &parentRole) -> void;

    /**
     * Update the "dynamicMotion" effect for an entity, applying springy animations.
     */
    auto UpdateDynamicMotion(entt::entity e, float dt, Transform &selfTransform) -> void;

    /**
     * Apply a "dynamicMotion" animation to an entity with specified intensity and rotation.
     */
    auto InjectDynamicMotion(entt::registry *registry, entt::entity e, float amount = 1.f, float rotationAmount = 34.f) -> void;

    auto UpdateParallaxCalculations(entt::registry *registry, entt::entity e) -> void;

    /**
     * Set alignment and bonding for a child entity.
     */
    auto ConfigureAlignment(entt::registry *registry, entt::entity e, bool isChild, entt::entity parent = entt::null,
                      std::optional<InheritedProperties::Sync> xy = std::nullopt, std::optional<InheritedProperties::Sync> wh = std::nullopt,
                      std::optional<InheritedProperties::Sync> rotation = std::nullopt, std::optional<InheritedProperties::Sync> scale = std::nullopt,
                      std::optional<int> alignment = std::nullopt, std::optional<Vector2> offset = std::nullopt) -> void;

    /**
     * Configure the role and bonding properties of an entity.
     */
    auto AssignRole(entt::registry *registry, entt::entity e, std::optional<InheritedProperties::Type> roleType,
                 entt::entity parent, std::optional<InheritedProperties::Sync> xy = std::nullopt, std::optional<InheritedProperties::Sync> wh = std::nullopt,
                 std::optional<InheritedProperties::Sync> rotation = std::nullopt, std::optional<InheritedProperties::Sync> scale = std::nullopt,
                 std::optional<Vector2> offset = std::nullopt) -> void;

    /**
     * Move the entity based on its role and parent-child relationship.
     */
    auto UpdateTransform(entt::entity e, float dt, Transform &transform, InheritedProperties &role, GameObject &node) -> void;

    /**
     * Hard-set the transform of an entity to specific values.
     */
    auto SnapTransformValues(entt::registry *registry, entt::entity e, float x, float y, float w, float h) -> void;

    /**
     * Hard-set the visual transform of an entity.
     */
    auto SnapVisualTransformValues(entt::registry *registry, entt::entity e) -> void;

    /**
     * Draw the bounding rectangle of an entity for debugging purposes.
     */
    auto DrawBoundingBoxAndDebugInfo(entt::registry *registry, entt::entity e, std::shared_ptr<layer::Layer> layer) -> void;

    /**
     * Get the cursor's location when focused on an entity.
     */
    auto CalculateCursorPositionWithinFocus(entt::registry *registry, entt::entity e) -> Vector2;

    /**
     * Check if an entity collides with a given point.
     */
    auto CheckCollisionWithPoint(entt::registry *registry, entt::entity e, const Vector2 &point) -> bool;
    
    extern std::optional<entt::entity> FindTopEntityAtPoint(const Vector2& point);    
    
    extern std::vector<entt::entity> FindAllEntitiesAtPoint(const Vector2& point);    
    
    extern auto GetCollisionOrderInfo(entt::registry& registry, entt::entity e) -> CollisionOrderInfo;
    
    auto HandleClick(entt::registry *registry, entt::entity e) -> void;
    
    auto HandleClickReleased(entt::registry *registry, entt::entity e) -> void;
    
    auto updateTransformCacheForAllTransforms() -> void;
    
    /**
     * Set the offset for click or hover handling.
     */
    auto SetClickOffset(entt::registry *registry, entt::entity e, const Vector2 &point, bool trueForClickFalseForHover) -> void;

    auto GetObjectToDrag(entt::registry *registry, entt::entity e) -> entt::entity;
    
    auto Draw(const std::shared_ptr<layer::Layer> &layer, entt::registry *registry, entt::entity e) -> void;
    
    auto StartDrag(entt::registry *registry, entt::entity e, bool applyDefaultTransformBehavior) -> void;
    
    /**
     * Stop dragging an entity.
     */
    auto StopDragging(entt::registry *registry, entt::entity e) -> void;

    /**
     * Hover over an entity (placeholder for UI).
     */
    auto StartHover(entt::registry *registry, entt::entity e) -> void;

    /**
     * Stop hovering over an entity.
     */
    auto StopHover(entt::registry *registry, entt::entity e) -> void;

    /**
     * Determine the cursor position for focusing on a node.
     */
    auto GetCursorOnFocus(entt::registry *registry, entt::entity e) -> Vector2;

    /**
     * Set the container for an entity and all its child nodes.
     */
    auto ConfigureContainerForEntity(entt::registry *registry, entt::entity e, entt::entity container) -> void;

    /**
     * Translate an entity's position for its container before drawing.
     */
    auto ApplyTranslationFromEntityContainer(entt::registry *registry, entt::entity e, std::shared_ptr<layer::Layer> layer) -> void;

    /**
     * Calculate the squared (fast) distance between the centers of two entities.
     */
    auto GetDistanceBetween(entt::registry *registry, entt::entity e1, entt::entity e2) -> float;

    /**
     * Remove an entity and its children from the registry.
     */
    auto RemoveEntity(entt::registry *registry, entt::entity e) -> void;

    auto setJiggleOnHover(entt::registry *registry, entt::entity e, float jiggleAmount) -> void;
    
    
    

} // namespace transform