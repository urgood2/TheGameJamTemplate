#pragma once

#include "../spring/spring.hpp"

#include "core/globals.hpp"

#include "entt/entt.hpp"
#include "util/common_headers.hpp"

#include "systems/layer/layer.hpp"
#include "systems/main_loop_enhancement/main_loop.hpp"

#include <vector>
#include <optional>

#include "raylib.h"

// Containers: used for ui
namespace transform
{
    struct GameObject;
    
    struct CollisionOrderInfo {
        bool hasCollisionOrder;
        entt::entity parentBox;       // UIBox container (if any)
        int treeOrder;                // Index among siblings in parent box
        int layerOrder;               // zIndex of the parent box
    };
    
    
    // for ui elements, helps with collision ordering
    struct TreeOrderComponent {
        int order = -1;
    };
    

    enum class TransformMethod
    {
        UpdateAllTransforms,
        HandleDefaultTransformDrag,
        CreateOrEmplace,
        CreateGameWorldContainerEntity,
        UpdateTransformSmoothingFactors,
        AlignToMaster,
        MoveWithMaster,
        UpdateLocation,
        UpdateSize,
        UpdateRotation,
        UpdateScale,
        GetMaster,
        SyncPerfectlyToMaster,
        UpdateDynamicMotion,
        InjectDynamicMotion,
        UpdateParallaxCalculations,
        ConfigureAlignment,
        AssignRole,
        UpdateTransform,
        SnapTransformValues,
        SnapVisualTransformValues,
        DrawBoundingBoxAndDebugInfo,
        CalculateCursorPositionWithinFocus,
        CheckCollisionWithPoint,
        HandleClick,
        HandleClickReleased,
        SetClickOffset,
        GetObjectToDrag,
        Draw,
        StartDrag,
        StopDragging,
        StartHover,
        StopHover,
        GetCursorOnFocus,
        ConfigureContainerForEntity,
        ApplyTranslationFromEntityContainer,
        GetDistanceBetween,
        RemoveEntity
    };

    extern bool debugMode; // set to true to allow debug drawing of transforms

    const float COLLISION_BUFFER_ON_HOVER_PERCENTAGE = 0.03f; // buffer for collision detection when hovering over an entity, in pixels (applies to each side separately), this is a percentage of the entity's size

    using namespace spring;
    using namespace snowhouse; // assert

    const spring::Spring DEFAULT_SPRING_ZERO = {.value = 0, .stiffness = 200.f, .damping = 40.f, .targetValue = 0}; // default spring of value of 0
    const spring::Spring DEFAULT_SPRING_ONE = {.value = 1, .stiffness = 200.f, .damping = 40.f, .targetValue = 1};  // default spring of value of 1 (for scale, etc.)

    /**
     * Represents a basic game object. This can be ui, a sprite, a text box, etc.
     * Clickable, draggable, hoverable
     * Can have children & a container parent
     * Contains state information for rendering, collision, focus, hover, click, drag, and release
     * (Differs from tranform parent-child relationships in that there are no strong/weak bonds, just direct inheritance of position, scale, rotation, etc.)
     */
    struct GameObject
    {
        // The list of children (and a parent) for a treelike structure. This can be used for things like drawing, deterministice movement and parallax
        std::optional<entt::entity> parent;

        // For lookup by ID
        std::map<std::string, entt::entity> children; //TODO: handle all children update code to include both children and orderedChildren, and use orderedChildren for ordered traversal (like in the UI system)
        // For ordered traversal
        std::vector<entt::entity> orderedChildren;

        bool ignoresPause = false; // set to true if the entity should move (transform updated) even when the game is paused (createdOnPause)

        // If we provide a container, all nodes within that container are translated with that container as the reference frame.
        entt::entity container = entt::null; // Reference to the container entity

        std::optional<entt::entity> collisionTransform; // Reference to the transform entity that should be used for collision detection, if this particular entity should not be used

        std::optional<float> clickTimeout; // set to a value in seconds if the entity should have a click timeout. If cursor is pressed, then released within this time, the entity is considered clicked. This can be customized by setting this varaible, otherwise it is 0.2f seconds

        // these methods add customizable methods for interaction handling. Default implementations exist in transform namespace. Those methods will also call these methods if they exist.
        struct Methods
        {
            // Variable access methods (customizable)
            std::function<entt::entity(entt::registry &, entt::entity)> getObjectToDrag; // add this to customize drag behavior separate from teh states struct

            // draw/update methods (customizable)
            std::function<void(entt::registry &, entt::entity, float)> update;                       // should be called every frame if this object has this method
            std::function<void(std::shared_ptr<layer::Layer>, entt::registry &, entt::entity)> draw; // should be called every frame if this object has this method

            // Action methods(customizable)
            std::function<void(entt::registry &, entt::entity)> onClick;                 // Click handler for the node
            std::function<void(entt::registry &, entt::entity, entt::entity)> onRelease; // a click release function, when the cursor is released on this node
            std::function<void(entt::registry &, entt::entity)> onHover;                 // Hover handler for the node
            std::function<void(entt::registry &, entt::entity)> onStopHover;             // Stop hover handler for the node
            std::function<void(entt::registry &, entt::entity)> onDrag;
            std::function<void(entt::registry &, entt::entity)> onStopDrag;

            // default handlers for release, click, update, animate, hover, stop_hover, drag, stop_drag, can_drag
        };
        // configure defaults
        std::unordered_map<TransformMethod, std::any> transformFunctions;
        std::unordered_map<TransformMethod, std::any> hooksToCallBefore, hooksToCallAfter; // methods which should be called before or after the default methods, respectively

        // these methods are actually replaceable to mimic inheritance.
        // They can be called with the util::call_method function.
        /**
         *
         *  call_method<void>(node_methods, "init");  // Calls node_init()

            int mid = call_method<int, int, int>(node_methods, "fast_mid_dist", 10, 20);
            std::cout << "Midpoint: " << mid << "\n";

            bool collides = call_method<bool, float, float>(node_methods, "collides_with_point", 5.0f, 5.0f);
            std::cout << "Collision: " << (collides ? "Yes" : "No") << "\n";
         */
        using MethodTable = std::unordered_map<std::string, std::any>;

        Methods methods;
        MethodTable inheritedMethods;

        // TODO: probably need to go through all files and replace references which were originally v.draw(), v.drawself(), and so on
        std::function<void(entt::registry &registry, entt::entity e, float dt)> updateFunction;          // call every frame for the node
        std::function<void(std::shared_ptr<layer::Layer>, entt::registry &, entt::entity, int)> drawFunction; // called every frame on top of the object's own draw method (so object's own draw method executes, then this one). NOT CALLED AUTOMATICALLY, NEED TO BE CALLED MANUALLY IN THE DRAW LOOP

        struct State
        {
            bool visible = true; // set to false if the entity should not be rendered

            bool collisionEnabled = false; // set to true if the entity should collide with other entities (and the cursor)
            bool isColliding = false;      // set to true if the entity is currently colliding with another entity (or the cursor)

            bool focusEnabled = false;   // set to true if the entity can be focused on (controller focus)
            bool isBeingFocused = false; // set to true if the entity is currently focused on (controller focus)

            bool hoverEnabled = false;   // set to true if the entity can be hovered over
            bool isBeingHovered = false; // set to true if the entity is currently being hovered over

            bool enlargeOnHover = true; // set to true if the entity should enlarge when hovered over (this is a visual effect, not a transform change)
            bool enlargeOnDrag = true; // set to true if the entity should enlarge when clicked (this is a visual effect, not a transform change)

            bool clickEnabled = false;   // set to true if the entity can be clicked
            bool isBeingClicked = false; // set to true if the entity is currently being clicked

            bool dragEnabled = false;    // set to true if the entity can be dragged
            bool isBeingDragged = false; // set to true if the entity is currently being dragged

            bool triggerOnReleaseEnabled = false; // set to true if the entity handles being released "on" (mouse button release of another object being dragged on top of it/just mouse button relese)
            bool isTriggeringOnRelease = false;   // set to true if the entity is currently being released

            bool isUnderOverlay = false; // set to true if the entity is under an overlay, in the DrawBoundingBoxAndDebugInfo method for node.
        } state;

        struct
        {
            bool calculationsInProgress = false;  // set to true if the entity transform is currently being calculated (for debug display purposes)
            std::optional<std::string> debugText; // set to a string if the entity should display debug text
        } debug;

        Vector2 dragOffset = {0, 0};  // offset from the mouse position when dragging
        Vector2 clickOffset = {0, 0}; // offset from the mouse position when clicking
        Vector2 hoverOffset = {0, 0}; // offset from the mouse position when hovering

        std::optional<Vector2> shadowDisplacement; // parallax for shadows
        std::optional<Vector2> layerDisplacement;  // parallax for layers
        std::optional<Vector2> layerDisplacementPrev; // previous layer displacement for parallax
        std::optional<float> shadowHeight;         // depth of a shadow, used for rendering shadow
    };

    /**
     * This component holds information regarding property inheritance and alignment of entities.
     */
    struct InheritedProperties
    {
        enum class Type
        {
            RoleRoot,      // has no master entity, is the root of the hierarchy
            RoleInheritor, // has a master entity, inherits properties from it such as location, rotation, scale, etc. REVIEW: it looks like inheritors can also have other inheritors that derive from it 
            // TODO: RoleCarbonCopy should probably have springs synced so there is no delay in copying properties
            RoleCarbonCopy,     // copies size, rotation, everything from the master entity, making it look identical
            PermanentAttachment // attaches to the master entity, essentially becoming part of it (think of a badge attached to a playing card or a health bar attached to a player). This ignores sync bonds, but respects alignment and offset.
        }; // Only children can have a master entity. Period. RoleCarbonCopy copies everything from the major entity full stop.
        Type role_type = Type::RoleRoot; // all entities are parents by default

        entt::entity master = entt::null; // Reference to the major entity

        std::optional<Vector2> offset, prevOffset; // Offset from the major entity, influences hierarchy

        // Bond types for property inheritance
        enum class Sync
        {
            Strong, // strong incorporates parent's properties instantly
            Weak    // weak eases into parent's properties
        }; // The bond type, either 'Strong' or 'Weak'. Strong instantly adjusts VT, Weak manually calculates VT changes (no inheriting from major entity)
        std::optional<Sync> location_bond;
        std::optional<Sync> size_bond;
        std::optional<Sync> rotation_bond;
        std::optional<Sync> scale_bond;

        // Alignments like HORIZONTAL_LEFT will align the child to be outside the edge of the parent. Use ALIGN_TO_INNER_EDGES to align to the inner edges of the parent. Set offset to fine-tune alignment additionally.
        // Note that for ui containers, bottom, top, right, etc. will actually automatically align inside the parent container, so you don't need to use ALIGN_TO_INNER_EDGES for those.
        struct Alignment
        {

            static constexpr int NONE = 0;                      // 0b00000000
            static constexpr int HORIZONTAL_LEFT = 1 << 0;      // 0b00000001
            static constexpr int HORIZONTAL_CENTER = 1 << 1;    // 0b00000010
            static constexpr int HORIZONTAL_RIGHT = 1 << 2;     // 0b00000100
            static constexpr int VERTICAL_TOP = 1 << 3;         // 0b00001000
            static constexpr int VERTICAL_CENTER = 1 << 4;      // 0b00010000
            static constexpr int VERTICAL_BOTTOM = 1 << 5;      // 0b00100000
            static constexpr int ALIGN_TO_INNER_EDGES = 1 << 6; // 0b01000000

            // Utility functions to make flag operations more readable
            static constexpr bool hasFlag(int flags, int flag)
            {
                return (flags & flag) != 0;
            }

            static constexpr void addFlag(int &flags, int flag)
            {
                flags |= flag;
            }

            static constexpr void removeFlag(int &flags, int flag)
            {
                flags &= ~flag;
            }

            static constexpr void toggleFlag(int &flags, int flag)
            {
                flags ^= flag;
            }

            Vector2 extraAlignmentFinetuningOffset{}, prevExtraAlignmentFinetuningOffset{}; // Fine-tuning of alignment
            int alignment = NONE;           // No alignment by default
            int prevAlignment = NONE;       // No alignment by default
        };

        std::optional<Alignment> flags;

        // ==== BUILDER CLASS ====
        struct Builder
        {
        private:
            std::shared_ptr<InheritedProperties> props = std::make_shared<InheritedProperties>();

        public:
            Builder() = default;

            Builder &addRoleType(Type type)
            {
                props->role_type = type;
                return *this;
            }

            Builder &addMaster(entt::entity masterEntity)
            {
                props->master = masterEntity;
                return *this;
            }

            Builder &addOffset(Vector2 off)
            {
                props->offset = off;
                return *this;
            }

            Builder &addLocationBond(Sync bond)
            {
                props->location_bond = bond;
                return *this;
            }

            Builder &addSizeBond(Sync bond)
            {
                props->size_bond = bond;
                return *this;
            }

            Builder &addRotationBond(Sync bond)
            {
                props->rotation_bond = bond;
                return *this;
            }

            Builder &addScaleBond(Sync bond)
            {
                props->scale_bond = bond;
                return *this;
            }

            Builder &addAlignment(int alignment)
            {
                if (!props->flags)
                    props->flags = Alignment{};
                props->flags->alignment = alignment;
                return *this;
            }

            Builder &addAlignmentOffset(Vector2 off)
            {
                if (!props->flags)
                    props->flags = Alignment{};
                props->flags->extraAlignmentFinetuningOffset = off;
                return *this;
            }

            InheritedProperties build()
            {
                return *props;
            }
        };
    };

    // Auto-adds springs as entities to registry, which will be updated by the spring system automatically
    /**
     * Basic transform component for entities. Contains x, y, w, h, r, and s springs for position, size, rotation, and scale.
     */
    struct Transform
    {
        entt::entity self; // the entity this transform is attached to, for convenience

        float rotationOffset = 0.f; // offset for rotation, used for tilting the entity based on its velocity. This also incorporates dynaaic motion and x leaning. Use this value (add to VT rotation) for rendering.

        // these are used in frame calculations to determine if the transform needs to be updated
        struct FrameCalculation
        {
            // data structure for parent caching, used by the GetMaster() method
            struct MasterCache
            {
                std::optional<entt::entity> master;
                std::optional<Vector2> offset;
            };
            std::optional<MasterCache> currentMasterCache;
            std::optional<MasterCache> oldMasterCache;

            int lastUpdatedFrame = 0;           // the last frame the transform was updated on
            std::optional<Vector2> tempOffsets; // used as intermediate storage for offsets
            bool stationary = false;            // if true, the transform will not move (saves calculations)
            bool alignmentChanged = false;      // if true, the alignment hierarchy has changed, and needs to be updated
        };
        FrameCalculation frameCalculation{};

        entt::registry *registry;

        std::optional<entt::entity> middleEntityForAlignment; // used for alignment to this entity's middle. Used by ui.

        // The x, y values of a transform are in world space unless they are children of another entity, in which case they are in local space, relative to their parent (or parents, if they are children of children)
        entt::entity x;
        entt::entity y;
        entt::entity w;
        entt::entity h;
        entt::entity r;
        entt::entity s;
        
        // ====== CACHED VALUES, updated once per frame ======
        // Add plain‐float members for the precomputed values:
        float cachedActualX;
        float cachedActualY;
        float cachedActualW;
        float cachedActualH;
        float cachedActualR;
        float cachedActualS;
        float cachedVisualX;
        float cachedVisualY;
        float cachedVisualW;
        float cachedVisualH;
        float cachedVisualRWithDynamicMotionAndXLeaning;
        float cachedVisualS;
        float cachedVisualR; 
        float cachedVisualSWithHoverAndDynamicMotionReflected;

        // ====== CACHED VALUES, updated once per frame ======
        struct Cached
        {
            float actualX, actualY, actualW, actualH, actualR, actualS;
            float visualX, visualY, visualW, visualH, 
                visualR, visualRWithDynamicMotionAndXLeaning, 
                visualS, visualSWithHoverAndDynamicMotionReflected;
        } cache;

        // Store which frame we last updated "cache" for:
        int lastCacheFrame = -1;

        //==========================================================================
        // This is the function you call at the start of every getter. It checks
        // if we've already filled 'cache' for the current frame. If not, it
        // reads all Springs (and other data) exactly once and populates the cache.
        //==========================================================================
        void updateCachedValues(bool forceUpdate = false)
        {
            // Get the current frame counter from your main loop:
            int currentFrame = main_loop::mainLoop.frame;

            // Only refill if we're in a new frame:
            if (lastCacheFrame == currentFrame && !forceUpdate)
                return;

            // --- Read every Spring exactly once and store into local temporaries ---
            Spring& springX = registry->get<Spring>(x);
            Spring& springY = registry->get<Spring>(y);
            Spring& springW = registry->get<Spring>(w);
            Spring& springH = registry->get<Spring>(h);
            Spring& springR = registry->get<Spring>(r);
            Spring& springS = registry->get<Spring>(s);

            // Fill “actual” values straight from targetValue:
            cache.actualX = springX.targetValue;
            cache.actualY = springY.targetValue;
            cache.actualW = springW.targetValue;
            cache.actualH = springH.targetValue;
            cache.actualR = springR.targetValue;
            cache.actualS = springS.targetValue;

            // Fill “visual” values straight from current value:
            cache.visualX = springX.value;
            cache.visualY = springY.value;
            cache.visualW = springW.value;
            cache.visualH = springH.value;
            cache.visualR = springR.value;
            cache.visualS = springS.value;

            // Now compute anything that depends on dynamicMotion or GameObject state:
            //  – visualRWithDynamicMotionAndXLeaning = value + rotationOffset
            cache.visualRWithDynamicMotionAndXLeaning = cache.visualR + rotationOffset;

            // For scale with hover/drag, you need to query GameObject only once:
            float baseScale = cache.visualS;
            if (registry->any_of<GameObject>(self))
            {
                GameObject& go = registry->get<GameObject>(self);

                if (go.state.isBeingHovered && go.state.enlargeOnHover)
                {
                    baseScale *= 1.f + COLLISION_BUFFER_ON_HOVER_PERCENTAGE;
                }
                if (go.state.isBeingDragged && go.state.enlargeOnDrag)
                {
                    baseScale += COLLISION_BUFFER_ON_HOVER_PERCENTAGE * 2.f;
                }
            }

            float addedScale = (dynamicMotion ? dynamicMotion->scale : 0.f);
            cache.visualSWithHoverAndDynamicMotionReflected = baseScale + addedScale;

            // Finally, mark that we updated for this frame:
            lastCacheFrame = currentFrame;
        }
        
        void updateCachedValues(const Spring& springX, const Spring& springY, const Spring& springW, const Spring& springH, const Spring& springR, const Spring& springS, bool forceUpdate = false)
        {
            int currentFrame = main_loop::mainLoop.frame;

            if (lastCacheFrame == currentFrame && !forceUpdate)
                return;

            // Fill “actual” values straight from targetValue:
            cache.actualX = springX.targetValue;
            cache.actualY = springY.targetValue;
            cache.actualW = springW.targetValue;
            cache.actualH = springH.targetValue;
            cache.actualR = springR.targetValue;
            cache.actualS = springS.targetValue;

            // Fill “visual” values straight from current value:
            cache.visualX = springX.value;
            cache.visualY = springY.value;
            cache.visualW = springW.value;
            cache.visualH = springH.value;
            cache.visualR = springR.value;
            cache.visualS = springS.value;

            // Visual rotation with dynamic motion and rotation offset
            cache.visualRWithDynamicMotionAndXLeaning = cache.visualR + rotationOffset;

            // Scale with hover/drag: Only query GameObject once
            float baseScale = cache.visualS;
            if (registry->any_of<GameObject>(self))
            {
                GameObject& go = registry->get<GameObject>(self);

                if (go.state.isBeingHovered && go.state.enlargeOnHover)
                {
                    baseScale *= 1.f + COLLISION_BUFFER_ON_HOVER_PERCENTAGE;
                }
                if (go.state.isBeingDragged && go.state.enlargeOnDrag)
                {
                    baseScale += COLLISION_BUFFER_ON_HOVER_PERCENTAGE * 2.f;
                }
            }

            float addedScale = (dynamicMotion ? dynamicMotion->scale : 0.f);
            cache.visualSWithHoverAndDynamicMotionReflected = baseScale + addedScale;

            // Mark update
            lastCacheFrame = currentFrame;
        }


        bool reduceXToZero = false; // set to true if the w value should interpolate to 0 instead of the target value
        bool reduceYToZero = false; // set to true if the h value should interpolate to 0 instead of the target value

        // access methods
        // Actual X is the desired X value, Visual X is the current X value which is slowly easing toward the actual X value
        // Position (X, Y)
        // Position (X)
        auto getActualX() -> float
        {
            updateCachedValues();
            return cache.actualX;
        }

        auto getVisualX() -> float
        {
            updateCachedValues();
            return cache.visualX;
        }

        auto getXSpring() -> Spring &
        {
            return registry->get<Spring>(x);
        }

        auto setActualX(float newX) -> void
        {
            // 1) Update the Spring
            registry->get<Spring>(this->x).targetValue = newX;

            updateCachedValues(true);
        }

        auto setVisualX(float newX) -> void
        {
            registry->get<Spring>(this->x).value = newX;

            updateCachedValues(true);
        }


        // Position (Y)
        auto getActualY() -> float
        {
            updateCachedValues();
            return cache.actualY;
        }

        auto getVisualY() -> float
        {
            updateCachedValues();
            return cache.visualY;
        }

        auto getYSpring() -> Spring &
        {
            return registry->get<Spring>(y);
        }

        auto setActualY(float newY) -> void
        {
            registry->get<Spring>(this->y).targetValue = newY;

            updateCachedValues(true);
        }

        auto setVisualY(float newY) -> void
        {
            registry->get<Spring>(this->y).value = newY;

            updateCachedValues(true);
        }


        // Size (W)
        auto getActualW() -> float
        {
            updateCachedValues();
            return cache.actualW;
        }

        auto getVisualW() -> float
        {
            updateCachedValues();
            return cache.visualW;
        }

        auto getWSpring() -> Spring &
        {
            return registry->get<Spring>(w);
        }

        auto setActualW(float newW) -> void
        {
            registry->get<Spring>(this->w).targetValue = newW;

            updateCachedValues(true);
        }

        auto setVisualW(float newW) -> void
        {
            registry->get<Spring>(this->w).value = newW;

            updateCachedValues(true);
        }


        // Size (H)
        auto getActualH() -> float
        {
            updateCachedValues();
            return cache.actualH;
        }

        auto getVisualH() -> float
        {
            updateCachedValues();
            return cache.visualH;
        }

        auto getHSpring() -> Spring &
        {
            return registry->get<Spring>(h);
        }

        auto setActualH(float newH) -> void
        {
            registry->get<Spring>(this->h).targetValue = newH;

            updateCachedValues(true);
        }

        auto setVisualH(float newH) -> void
        {
            registry->get<Spring>(this->h).value = newH;

            updateCachedValues(true);
        }


        // Rotation (R)
        auto getActualRotation() -> float
        {
            updateCachedValues();
            return cache.actualR;
        }

        auto getVisualR() -> float
        {
            updateCachedValues();
            return cache.visualR;
        }

        // Use this when you need “current rotation + dynamicMotion + x‐leaning”
        auto getVisualRWithDynamicMotionAndXLeaning() -> float
        {
            updateCachedValues();
            return cache.visualRWithDynamicMotionAndXLeaning;
        }

        auto getRSpring() -> Spring &
        {
            return registry->get<Spring>(r);
        }

        auto setActualRotation(float newR) -> void
        {
            registry->get<Spring>(this->r).targetValue = newR;

            updateCachedValues(true);
        }

        auto setVisualRotation(float newR) -> void
        {
            registry->get<Spring>(this->r).value = newR;

            updateCachedValues(true);
        }


        // Scale (S)
        auto getActualScale() -> float
        {
            updateCachedValues();
            return cache.actualS;
        }

        auto getVisualScale() -> float
        {
            updateCachedValues();
            return cache.visualS;
        }

        // When you need hover + dynamic‐motion:
        auto getVisualScaleWithHoverAndDynamicMotionReflected() -> float
        {
            updateCachedValues();
            return cache.visualSWithHoverAndDynamicMotionReflected;
        }

        auto getSSpring() -> Spring &
        {
            return registry->get<Spring>(s);
        }

        auto setActualScale(float newS) -> void
        {
            registry->get<Spring>(this->s).targetValue = newS;

            updateCachedValues(true);
        }

        auto setVisualScale(float newS) -> void
        {
            registry->get<Spring>(this->s).value = newS;

            updateCachedValues(true);
        }

        // utility
        auto getHoverCollisionBufferX() -> float { return COLLISION_BUFFER_ON_HOVER_PERCENTAGE * getVisualW(); }
        auto getHoverCollisionBufferY() -> float { return COLLISION_BUFFER_ON_HOVER_PERCENTAGE * getVisualH(); }

        struct DynamicMotion
        {
            float startTime = 0;      // used for easing
            float endTime = 0;        // used for easing
            float scale = 0;          // current scale
            float scaleAmount = 0;    // scale amplitude
            float rotation = 0;       // current rotation
            float rotationAmount = 0; // rotation amplitude
        };
        std::optional<DynamicMotion> dynamicMotion;

        Transform()
        {
            this->registry = &globals::registry;

            x = registry->create();
            y = registry->create();
            w = registry->create();
            h = registry->create();
            r = registry->create();
            s = registry->create();

            auto XSpring = registry->emplace<Spring>(x, DEFAULT_SPRING_ZERO);
            auto YSpring = registry->emplace<Spring>(y, DEFAULT_SPRING_ZERO);
            auto WSpring = registry->emplace<Spring>(w, DEFAULT_SPRING_ONE);
            auto HSpring = registry->emplace<Spring>(h, DEFAULT_SPRING_ONE);
            auto RSpring = registry->emplace<Spring>(r, DEFAULT_SPRING_ZERO);
            auto SSpring = registry->emplace<Spring>(s, DEFAULT_SPRING_ONE);
        }
        

        ~Transform()
        {
            // registry->destroy(x);
            // registry->destroy(y);
            // registry->destroy(w);
            // registry->destroy(h);
            // registry->destroy(r);
            // registry->destroy(s);
        }
    };

    // Function that gets called when a transform component is destroyed
    inline void onTransformDestroyed(entt::registry &registry, entt::entity entity) {
        if (registry.any_of<Transform>(entity)) {
            auto &transform = registry.get<Transform>(entity);
            registry.destroy(transform.x);
            registry.destroy(transform.y);
            registry.destroy(transform.w);
            registry.destroy(transform.h);
            registry.destroy(transform.r);
            registry.destroy(transform.s);
            // std::cout << "Particle " << particle.id << " destroyed!" << std::endl;
        }
    }

    // Function to register the destruction callback
    inline void registerDestroyListeners(entt::registry &registry) {
        registry.on_destroy<Transform>().connect<&onTransformDestroyed>();
    }

    // used to cache master lookups in a global map.
    struct MasterCacheEntry
    {
        entt::entity master = entt::null;
        Vector2 offset = {0, 0};
        Transform *parentTransform = nullptr;
        InheritedProperties *parentRole = nullptr;
    };
    
    struct SpringCacheBundle {
        Spring* x;
        Spring* y;
        Spring* r;
        Spring* s;
        Spring* w;
        Spring* h;
    };

}