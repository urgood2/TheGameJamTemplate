#pragma once

#include <entt/entt.hpp>
#include <optional>
#include <string>
#include <raylib.h>

#include "../../util/utilities.hpp"

//TODO: apply a partitioning scheme for efficient collisions when necessary

namespace Movable {

    struct TextDisplayUIMarker // this component is used to mark text that should be rendered above the ui elements
    {
    };

    struct TextDisplay
    {
        std::string text;
        bool visible{true};
        Color color{util::getColor("STEAM_LORDS_PALETTE_c0d1cc_SOFT_LIGHT_BLUE")};
    };
    
struct Movable
    {
        struct Juice
        {                        // to be added to visual scale and rotation for additional effect
            float scale{1};      // Current scale offset to add to visual scale
            float scale_amt{0};  // Maximum oscillation amplitude for scale
            float rotation{0};   // Current rotation offset to add to visual rotation
            float r_amt{0};      // Maximum oscillation amplitude for rotation
            float start_time{0}; // Start time of the juice effect
            float end_time{0};   // End time of the juice effect

            // TODO: untested values
            Vector2 size_amt{0, 0};     // Maximum oscillation amplitude for size
            Vector2 accel_amt{0, 0};    // Maximum oscillation amplitude for acceleration
            Vector2 position_amt{0, 0}; // Maximum oscillation amplitude for position
            Vector2 velocity_amt{0, 0}; // Maximum oscillation amplitude for velocity

            
        };

        std::optional<Vector2> actualLocation;
        std::optional<Vector2> actualAcceleration;
        std::optional<Vector2> actualSize;

        std::optional<Vector2> visualLocation;
        std::optional<Vector2> visualAcceleration;
        std::optional<Vector2> visualSize;


        std::optional<Vector2> velocity=Vector2{0,0}; // the speed at which actual transform approaches visual transform
        std::optional<float> rotationVelocity{0};
        std::optional<float> scaleVelocity{0};

        std::optional<float> actualRotation{0};
        std::optional<float> actualScale{1};

        std::optional<float> visualRotation{0};
        std::optional<float> visualScale{1};

        std::string debugTextDisplay{};

        std::optional<Juice> juice;

        std::optional<bool> noDraw; // shape will not be drawn (text will still be drawn)
        
        bool draggable{true}; // only set to true if the entity can be dragged by mouse
    };
    
    // dragging
    struct Dragging
    {
        std::optional<Vector2> offset;
        std::optional<Vector2> draggedPoint; // the point being dragged
    };

    struct Hovering
    {
    };

// for location syncing
    struct LinkedLocation
    {
        entt::entity linked_entity;
        float offset_x, offset_y;
    };

    extern auto updateMovableSystem(float dt) -> void;
    void applyJuiceToMovable(Movable &movable, float initialScale, std::optional<float> initialRotation, std::optional<bool> dampened = false);
    extern auto updateJuiceToMovable(Movable &movable, float dt) -> void;
    extern auto checkMovableCollisionWithPoint(Movable &movable, Vector2 point) -> bool;
    // TODO: this needs to change to take my own impl into account, such as sprites
    extern auto drawSingleMovableAsText(entt::entity entity, Color color) -> void;
    extern void drawDebugTextNextToMovable(Movable &movable);
    extern auto drawSingleMovableAsRect(Movable &movable, Color color = GRAY) -> void;
    extern auto drawSingleMovableAsTextWithShadow(entt::entity entity, Color color, Vector2 screenCenter, float parallaxFactor) -> void;
    extern auto updateLinkedLocations() -> void;
    extern auto handleMouseInteraction(Vector2 mousePosition, bool isMouseDown) -> void;
    extern auto drawEntityWithAnimation(entt::entity e, bool debug = false) -> void;
}
