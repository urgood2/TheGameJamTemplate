#include "my_own_movable_impl.hpp"

#include <memory>

#include "../../core/graphics.hpp"
#include "../../core/globals.hpp"
#include "../../core/gui.hpp"

#include "../event/event_system.hpp"

#include "magic_enum/magic_enum.hpp"
#include "raymath.h"
#include "rlgl.h"

#include "../../util/utilities.hpp"

#include "sol/sol.hpp"

// TODO: things to implement: location syncing, rotation/size syncing, velocity syncing, acceleration syncing, scale syncing, juice syncing
// Needs pinch, alignment, shadow as well
// TODO: drawing implementation as animated sprite/ debug shape outline

namespace Movable
{

    

    /**
     *  Flags & variables
     **/
    bool isDragging = false;

    auto updateMovableSystem(float dt) -> void
    {
        auto view = globals::registry.view<Movable>();

        for (auto entity : view)
        {
            auto &movable = view.get<Movable>(entity);

            assert(movable.actualLocation.has_value() && "Actual location must be set for Movable component");

            // Initialize visual properties to actual values if they are not set
            if (!movable.visualLocation.has_value() && movable.actualLocation.has_value())
            {
                movable.visualLocation = movable.actualLocation;
            }
            if (!movable.velocity.has_value())
            {
                movable.velocity = Vector2{0, 0};
            }
            if (!movable.visualAcceleration.has_value())
            {
                movable.visualAcceleration = Vector2{0, 0};
            }
            if (!movable.visualSize.has_value() && movable.actualSize.has_value())
            {
                movable.visualSize = movable.actualSize;
            }
            if (!movable.visualRotation.has_value() && movable.actualRotation.has_value())
            {
                movable.visualRotation = movable.actualRotation.value();
            }
            if (!movable.visualScale.has_value() && movable.actualScale.has_value())
            {
                movable.visualScale = movable.actualScale.value();
            }

            // Handle dragging
            if (globals::registry.any_of<Dragging>(entity))
            {
                auto &dragging = globals::registry.get<Dragging>(entity);

                // Get current mouse position in world space
                Vector2 mousePosition = GetScreenToWorld2D(GetMousePosition(), globals::camera);

                if (dragging.draggedPoint.has_value() == false)
                {
                    // give initial value
                    dragging.draggedPoint = mousePosition;
                }
                // Update actualLocation based on mouse position and offset
                movable.actualLocation->x = mousePosition.x - dragging.offset->x;
                movable.actualLocation->y = mousePosition.y - dragging.offset->y;

                // save the dragged point on the Moveable
                dragging.draggedPoint = {
                    movable.visualLocation->x + dragging.offset->x,
                    movable.visualLocation->y + dragging.offset->y};

                // Smoothly update visualLocation for smooth dragging
                // constexpr float smoothingFactor = 0.9f;
                // movable.visualLocation->x = smoothingFactor * movable.visualLocation->x +
                //                             (1 - smoothingFactor) * movable.actualLocation->x;
                // movable.visualLocation->y = smoothingFactor * movable.visualLocation->y +
                //                             (1 - smoothingFactor) * movable.actualLocation->y;
            }

            // Exponential smoothing parameters (similar to Lua's G.exp_times)
            // Dynamically calculate smoothing factor, similar to Lua's G.exp_times.xy
            constexpr float expSmoothingScale = 0.80f;   // reduce to make faster
            constexpr float expSmoothingRotation = 0.7f; // Smoothing for rotation
            constexpr float maxVelocity = 1500.0f;       // Maximum velocity limit

            // Position smoothing
            if (movable.visualLocation && movable.actualLocation)
            {
                // Dynamically calculate smoothing factor, similar to Lua's G.exp_times.xy
                float adjustedDt = std::min(dt * 1000.0f, 1.0f);
                float expSmoothingXY = std::exp(-10.0f * adjustedDt);

                // Calculate velocity for x and y directions
                movable.velocity->x = expSmoothingXY * movable.velocity->x +
                                      (1 - expSmoothingXY) * (movable.actualLocation->x - movable.visualLocation->x) * 800 * dt;
                movable.velocity->y = expSmoothingXY * movable.velocity->y +
                                      (1 - expSmoothingXY) * (movable.actualLocation->y - movable.visualLocation->y) * 800 * dt;

                // Clamp velocity to maximum
                float velocityMagnitude = sqrt(movable.velocity->x * movable.velocity->x + movable.velocity->y * movable.velocity->y);
                if (velocityMagnitude > maxVelocity)
                {
                    movable.velocity->x *= maxVelocity / velocityMagnitude;
                    movable.velocity->y *= maxVelocity / velocityMagnitude;
                }

                // Update visual location based on velocity
                movable.visualLocation->x += movable.velocity->x * dt;
                movable.visualLocation->y += movable.velocity->y * dt;

                // Snap to target if close
                if (fabs(movable.visualLocation->x - movable.actualLocation->x) < 0.01f && fabs(movable.velocity->x) < 0.01f)
                {
                    movable.visualLocation->x = movable.actualLocation->x;
                    movable.velocity->x = 0;
                }
                if (fabs(movable.visualLocation->y - movable.actualLocation->y) < 0.01f && fabs(movable.velocity->y) < 0.01f)
                {
                    movable.visualLocation->y = movable.actualLocation->y;
                    movable.velocity->y = 0;
                }
            }

            // Scale smoothing
            float expTimesScale = std::exp(-60.0f * dt); // Exponential decay

            // Calculate the desired scale based on various factors
            float desiredScale = movable.actualScale.value();

            // Include zoom effects (if applicable)
            if (globals::registry.any_of<Dragging>(entity))
            {
                desiredScale += 0.1f;
            }
            else if (globals::registry.any_of<Hovering>(entity))
            {
                desiredScale += 0.05f ;
            }

            // Ensure juice effect contribution is temporary and controlled
            float juiceContribution = movable.juice ? movable.juice->scale : 0.f;
            // SPDLOG_DEBUG("juiceContribution: {}", juiceContribution);

            // Ensure both visualScale and actualScale are valid
            if (movable.visualScale && movable.actualScale)
            {
                // Smoothly update scale velocity using exponential decay
                movable.scaleVelocity = expTimesScale * movable.scaleVelocity.value() +
                                        (1.0f - expTimesScale) * (desiredScale - movable.visualScale.value());

                // Update the visual scale, adding juice contribution as a transient effect
                movable.visualScale = movable.visualScale.value() + movable.scaleVelocity.value() + juiceContribution;

                // Snap to the desired scale if the difference is negligible
                if (fabs(movable.visualScale.value() - (desiredScale + juiceContribution)) < 0.001f &&
                    fabs(movable.scaleVelocity.value()) < 0.001f)
                {
                    movable.visualScale = desiredScale; // Exclude juice from steady state
                    movable.scaleVelocity = 0;
                }
            }

            /// Width and height smoothing (size)
            if (movable.visualSize && movable.actualSize)
            {
                // Smoothing factor (higher values mean faster return)
                constexpr float smoothingFactor = 10.0f;
                constexpr float snapThreshold = 0.01f; // Snap to target when close enough

                // Update x dimension
                movable.visualSize->x += (movable.actualSize->x - movable.visualSize->x) * smoothingFactor * dt;
                // Snap to target if close enough
                if (fabs(movable.actualSize->x - movable.visualSize->x) < snapThreshold)
                {
                    movable.visualSize->x = movable.actualSize->x;
                }

                // Update y dimension
                movable.visualSize->y += (movable.actualSize->y - movable.visualSize->y) * smoothingFactor * dt;
                // Snap to target if close enough
                if (fabs(movable.actualSize->y - movable.visualSize->y) < snapThreshold)
                {
                    movable.visualSize->y = movable.actualSize->y;
                }
            }

            // Rotation smoothing
            // Incorporate velocity influence in the desired rotation
            float desiredRotation = movable.actualRotation.value() + 0.00015f * movable.velocity->x / dt;
            // float maxRotation = 30.f; // Example max rotation angle (radians or degrees)
            // desiredRotation = std::clamp(desiredRotation, movable.actualRotation.value() - maxRotation, movable.actualRotation.value() + maxRotation);

            // SPDLOG_DEBUG("movable.velocity: {}", movable.velocity->x);
            // SPDLOG_DEBUG("desiredRotation: {}", desiredRotation);

            // Add juice effect if applicable
            if (movable.juice)
                desiredRotation += movable.juice->rotation * 2;

            // Only proceed if both visualRotation and actualRotation are valid
            if (movable.visualRotation && movable.actualRotation)
            {
                // Smooth the rotation velocity
                movable.rotationVelocity = expSmoothingRotation * movable.rotationVelocity.value() +
                                           (1 - expSmoothingRotation) * (desiredRotation - movable.visualRotation.value());

                // Update the visual rotation by adding the smoothed velocity
                movable.visualRotation = movable.visualRotation.value() + movable.rotationVelocity.value();

                // Snap to target rotation if the difference is negligible
                if (fabs(movable.visualRotation.value() - desiredRotation) < 0.001f &&
                    fabs(movable.rotationVelocity.value()) < 0.001f)
                {
                    movable.visualRotation = desiredRotation;
                    movable.rotationVelocity = 0;
                }
            }

            // Update the juice effect
            updateJuiceToMovable(movable, dt);
        }
    }

    auto checkMovableCollisionWithPoint(Movable &movable, Vector2 point) -> bool
    {
        if (movable.visualLocation.has_value() && movable.visualSize.has_value())
        {
            // Get the rectangle's top-left corner, size, rotation, and scale
            Vector2 topLeft = *movable.visualLocation;
            Vector2 size = *movable.visualSize;
            float rotation = movable.visualRotation.value_or(0.0f); // Assuming rotation is in degrees
            float scale = movable.visualScale.value_or(1.f);

            // Scale the size
            size.x *= scale;
            size.y *= scale;

            // Compute the rectangle's center position
            Vector2 center = {
                topLeft.x + size.x / 2.0f,
                topLeft.y + size.y / 2.0f};

            // Compute the half-size of the scaled rectangle
            Vector2 halfSize = {size.x / 2.0f, size.y / 2.0f};

            // Translate the point into the rectangle's local space
            Vector2 localPoint = point;

            // First, translate the point to the rectangle's center
            localPoint.x -= center.x;
            localPoint.y -= center.y;

            // Then, rotate the point back by the negative rectangle rotation
            float radians = -DEG2RAD * rotation;
            float cosTheta = cosf(radians);
            float sinTheta = sinf(radians);
            float rotatedX = cosTheta * localPoint.x + sinTheta * localPoint.y;
            float rotatedY = -sinTheta * localPoint.x + cosTheta * localPoint.y;
            localPoint = {rotatedX, rotatedY};

            // Finally, check if the transformed point is inside the scaled rectangle
            if (localPoint.x >= -halfSize.x && localPoint.x <= halfSize.x &&
                localPoint.y >= -halfSize.y && localPoint.y <= halfSize.y)
            {
                return true;
            }
        }
        return false;
    }

    auto drawSingleMovableAsRect(Movable &movable, Color color) -> void
    {
        // do not draw if the movable is noDraw
        if (movable.noDraw && movable.noDraw.value() == true)
            return;

        float finalScale = movable.visualScale.value();
        // SPDLOG_DEBUG("visualScale: {}", finalScale);
        float finalRotation = movable.visualRotation.value();

        if (movable.juice)
        {
            finalScale += movable.juice->scale;
            finalRotation += movable.juice->rotation;
        }

        // SPDLOG_DEBUG("finalScale: {}", finalScale);

        // Calculate offset to center the scaling on the center of the shape
        float offsetX = (movable.visualSize->x) / 2;
        float offsetY = (movable.visualSize->y) / 2;

        // Push the current transformation matrix
        rlPushMatrix();

        // Translate to the center of the rectangle based on its top-left corner (visualLocation)
        rlTranslatef(movable.visualLocation->x + offsetX, movable.visualLocation->y + offsetY, 0);

        // Scale and rotate around the new origin (the center of the rectangle)
        rlScalef(finalScale, finalScale, 1);
        rlRotatef(finalRotation, 0, 0, 1);

        // Draw the rectangle centered at the origin (0, 0) now
        DrawRectanglePro(
            Rectangle{
                -movable.visualSize->x / 2,
                -movable.visualSize->y / 2,
                movable.visualSize->x,
                movable.visualSize->y},
            Vector2{0, 0},
            0,
            color);

        // Restore the previous transformation matrix
        rlPopMatrix();
    }

    auto drawEntityWithAnimation(entt::entity e, bool debug) -> void
    {
        // Ensure the entity has a Movable component
        if (!globals::registry.any_of<Movable>(e))
        {
            SPDLOG_WARN("Entity {} does not have a Movable component.", static_cast<int>(e));
            return;
        }

        Movable &movable = globals::registry.get<Movable>(e);

        // Skip drawing if the Movable component specifies noDraw
        if (movable.noDraw && movable.noDraw.value() == true)
            return;

        // Fetch the animation frame if the entity has an AnimationQueueComponent
        Rectangle *animationFrame = nullptr;
        SpriteComponentASCII *currentSprite = nullptr;

        if (globals::registry.any_of<AnimationQueueComponent>(e))
        {
            auto &aqc = globals::registry.get<AnimationQueueComponent>(e);

            // Use the current animation frame or the default frame
            if (aqc.animationQueue.empty())
            {
                if (!aqc.defaultAnimation.animationList.empty())
                {
                    animationFrame = &aqc.defaultAnimation.animationList[aqc.defaultAnimation.currentAnimIndex].first.spriteFrame->frame;
                    currentSprite = &aqc.defaultAnimation.animationList[aqc.defaultAnimation.currentAnimIndex].first;
                }
            }
            else
            {
                auto &currentAnimObject = aqc.animationQueue[aqc.currentAnimationIndex];
                animationFrame = &currentAnimObject.animationList[currentAnimObject.currentAnimIndex].first.spriteFrame->frame;
                currentSprite = &currentAnimObject.animationList[currentAnimObject.currentAnimIndex].first;
            }
        }

        Texture2D atlasTexture = *currentSprite->spriteData.texture;

        // Determine rendering size based on Movable component
        float finalScale = movable.visualScale.value();
        float finalRotation = movable.visualRotation.value();

        if (movable.juice)
        {
            finalScale += movable.juice->scale;
            finalRotation += movable.juice->rotation;
        }

        float renderWidth = movable.visualSize->x * finalScale;
        float renderHeight = movable.visualSize->y * finalScale;
        float offsetX = renderWidth / 2;
        float offsetY = renderHeight / 2;

        // Check if the entity has colors (fg/bg)
        Color bgColor = Color{0, 0, 0, 0}; // Default to fully transparent
        Color fgColor = WHITE;             // Default foreground color
        bool drawBackground = false;
        bool drawForeground = true;

        if (currentSprite)
        {
            bgColor = currentSprite->bgColor;
            fgColor = currentSprite->fgColor;
            drawBackground = !currentSprite->noBackgroundColor;
            drawForeground = !currentSprite->noForegroundColor;
        }

        // Push the current transformation matrix
        rlPushMatrix();

        // Apply transformations from movable
        rlTranslatef(movable.visualLocation->x + offsetX, movable.visualLocation->y + offsetY, 0); // Translate to center of entity
        rlScalef(finalScale, finalScale, 1);                                                       // Scale relative to center
        rlRotatef(finalRotation, 0, 0, 1);                                                         // Rotate around center

        // Draw background rectangle if enabled
        if (drawBackground)
        {
            DrawRectanglePro(
                Rectangle{
                    -offsetX, -offsetY, // Centered rectangle
                    movable.visualSize->x, movable.visualSize->y},
                Vector2{0, 0}, // Rotation center
                0,             // No additional rotation
                bgColor);
        }

        // Draw the animation frame or a default rectangle if no animation is present
        if (drawForeground)
        {
            if (animationFrame)
            {
                DrawTexturePro(
                    atlasTexture,
                    *animationFrame,
                    Rectangle{-offsetX, -offsetY, movable.visualSize->x, movable.visualSize->y},
                    Vector2{0, 0}, // Rotation center
                    0,
                    fgColor);
            }
            else
            {
                DrawRectanglePro(
                    Rectangle{-offsetX, -offsetY, movable.visualSize->x, movable.visualSize->y},
                    Vector2{0, 0}, // Rotation center
                    0,
                    fgColor);
            }
        }

        // Debug mode: Draw boundary rectangle
        if (debug)
        {
            Color debugColor = {255, 0, 0, 128}; // Semi-transparent red for debug
            DrawRectangleLinesEx(
                Rectangle{
                    -offsetX, -offsetY, // Centered rectangle
                    movable.visualSize->x, movable.visualSize->y},
                1.0f,        // Line thickness
                debugColor); // Color
        }

        // Restore the previous transformation matrix
        rlPopMatrix();
    }

    void drawDebugTextNextToMovable(Movable &movable)
    {
        if (movable.visualLocation.has_value())
        {
            DrawText(movable.debugTextDisplay.c_str(), movable.visualLocation->x + 10, movable.visualLocation->y + 10, 20, RED);
        }
    }

//     // Function to apply initial juice effect
//     void applyJuiceToMovable(Movable &movable, float initialScale, std::optional<float> initialRotation)
// {
//     const float dampingFactor = 0.9f; // Controls how much each successive effect diminishes

//     if (movable.juice.has_value())
//     {
//         // Apply damping to existing scale and rotation to reduce the effect of accumulation
//         movable.juice->scale_amt = movable.juice->scale_amt * dampingFactor + initialScale * (1.0f - dampingFactor);
//         movable.juice->r_amt = movable.juice->r_amt * dampingFactor + initialRotation.value_or((rand() % 2 == 0 ? 0.6f * initialScale : -0.6f * initialScale)) * (1.0f - dampingFactor);
        
//         // Extend the duration
//         movable.juice->end_time = G_TIMER_REAL + 0.4f;
//     }
//     else
//     {
//         // Initialize a new juice effect
//         movable.juice = Movable::Juice{};
//         movable.juice->scale = 0.0f;    // Initial scale offset
//         movable.juice->rotation = 0.0f; // Initial rotation offset
//         movable.juice->scale_amt = initialScale;
//         movable.juice->r_amt = initialRotation.value_or((rand() % 2 == 0 ? 0.6f * initialScale : -0.6f * initialScale));
//         movable.juice->start_time = G_TIMER_REAL;
//         movable.juice->end_time = G_TIMER_REAL + 0.4f; // Effect lasts for 0.4 seconds
//     }
// }
// Function to apply initial juice effect
void applyJuiceToMovable(Movable &movable, float initialScale, std::optional<float> initialRotation, std::optional<bool> dampened)
{
    const float dampingFactor = 0.9f; // Controls how much each successive effect diminishes

    if (movable.juice.has_value())
    {
        if (dampened.value_or(false))
        {
            // Apply damping to existing scale and rotation to reduce the effect of accumulation
            movable.juice->scale_amt = movable.juice->scale_amt * dampingFactor + initialScale * (1.0f - dampingFactor);
            movable.juice->r_amt = movable.juice->r_amt * dampingFactor + initialRotation.value_or((rand() % 2 == 0 ? 0.6f * initialScale : -0.6f * initialScale)) * (1.0f - dampingFactor);
        }
        else
        {
            // Directly add the new effect without damping
            movable.juice->scale_amt += initialScale;
            movable.juice->r_amt += initialRotation.value_or((rand() % 2 == 0 ? 0.6f * initialScale : -0.6f * initialScale));
        }

        // Extend the duration
        movable.juice->end_time = globals::G_TIMER_REAL + 0.4f;
    }
    else
    {
        // Initialize a new juice effect
        movable.juice = Movable::Juice{};
        movable.juice->scale = 0.0f;    // Initial scale offset
        movable.juice->rotation = 0.0f; // Initial rotation offset
        movable.juice->scale_amt = initialScale;
        movable.juice->r_amt = initialRotation.value_or((rand() % 2 == 0 ? 0.6f * initialScale : -0.6f * initialScale));
        movable.juice->start_time = globals::G_TIMER_REAL;
        movable.juice->end_time = globals::G_TIMER_REAL + 0.4f; // Effect lasts for 0.4 seconds
    }
}



    // Function to update juice effect with a dampening oscillator
    void updateJuiceToMovable(Movable &movable, float dt)
    {
        if (movable.juice.has_value())
        {
            float currentTime = globals::G_TIMER_REAL;
            if (currentTime >= movable.juice->end_time)
            {
                // End the juice effect if the time is up
                movable.juice.reset();
            }
            else
            {
                float elapsed_time = currentTime - movable.juice->start_time;
                float duration = movable.juice->end_time - movable.juice->start_time;

                // Calculate damping factors for scale and rotation
                float scaleDamping = std::max(0.0f, std::pow((movable.juice->end_time - currentTime) / duration, 3.0f));
                float rotationDamping = std::max(0.0f, std::pow((movable.juice->end_time - currentTime) / duration, 2.0f));

                // Dampened oscillation toward scale of 1
                float targetScale = 0.f;

                movable.juice->scale = targetScale + (movable.juice->scale_amt * std::sin(50.8f * elapsed_time) * scaleDamping);
                // SPDLOG_DEBUG("targetScale: {}", targetScale);
                // SPDLOG_DEBUG("movable.juice->scale: {}", movable.juice->scale);

                // Dampened oscillation toward rotation of 0
                float targetRotation = 0.0f;
                movable.juice->rotation = targetRotation + (movable.juice->r_amt * std::sin(40.8f * elapsed_time) * rotationDamping);
            }
        }
    }

    /**
     *  Flags & variables
     **/
    entt::entity currentlyDraggedEntity = entt::null;

    auto handleMouseInteraction(Vector2 mousePosition, bool isMouseDown) -> void
    {
        static bool wasMouseDown = false; // Tracks the previous mouse state

        auto view = globals::registry.view<Movable>();
        bool isHovered = false;    // Tracks if any entity is hovered
        bool hoverHandled = false; // Tracks if hovering logic is already handled
        bool dragHandled = false;  // Tracks if dragging logic is already handled

        // Handle mouse interactions
        for (auto entity : view)
        {
            auto &movable = view.get<Movable>(entity);

            if (movable.visualLocation.has_value() && movable.visualSize.has_value())
            {
                // Check if the mouse is over the Movable
                if (checkMovableCollisionWithPoint(movable, mousePosition))
                {
                    isHovered = true;

                    // Handle hover
                    // Handle hover
                    if (!hoverHandled && !globals::registry.any_of<Hovering>(entity))
                    {
                        globals::registry.emplace_or_replace<Hovering>(entity); // Add hover flag
                        hoverHandled = true;                           // Mark hovering as handled

                        // Fire hover start event
                        sol::table arguments = globals::lua.create_table();
                        arguments["entity"] = entity;
                        arguments["type"] = "hover_start"; // Custom event type
                        event_system::publishLuaEvent("movable_mouse_hovered", arguments);

                        // Apply juice effect for hover
                        applyJuiceToMovable(movable, 0.01f, 1.f);
                    }

                    // Handle clicking
                    if (isMouseDown && !wasMouseDown)
                    {
                        // Fire click event for this Movable
                        sol::table arguments = globals::lua.create_table();
                        arguments["entity"] = entity;
                        arguments["type"] = "click"; // Custom event type
                        event_system::publishLuaEvent("movable_mouse_clicked", arguments);
                    }

                    // Handle dragging for draggable Movables
                    if (isMouseDown && movable.draggable && !isDragging && !dragHandled)
                    {
                        // Start dragging and record the offset
                        Dragging dragComponent;
                        dragComponent.offset = {
                            mousePosition.x - movable.visualLocation->x,
                            mousePosition.y - movable.visualLocation->y,
                        };
                        isDragging = true;
                        currentlyDraggedEntity = entity;
                        globals::registry.emplace_or_replace<Dragging>(entity, dragComponent);
                        dragHandled = true; // Mark dragging as handled
                    }

                    // Exit the loop if both hover and drag are handled
                    if (hoverHandled && (dragHandled || isDragging))
                    {
                        break;
                    }
                }
                else if (globals::registry.any_of<Hovering>(entity))
                {
                    // Remove hover flag if no longer hovered
                    globals::registry.remove<Hovering>(entity);
                }
            }
        }

        // Clear hover flags if no entity is hovered
        if (!isHovered)
        {
            auto hoveringView = globals::registry.view<Hovering>();
            for (auto entity : hoveringView)
            {
                globals::registry.remove<Hovering>(entity);
            }
        }

        // Reset dragging state when mouse button is released
        if (!isMouseDown)
        {
            auto draggingView = globals::registry.view<Dragging>();
            for (auto entity : draggingView)
            {
                globals::registry.remove<Dragging>(entity); // Clear dragging component

                // Send mouse button release event for this Movable
                sol::table arguments = globals::lua.create_table();
                arguments["entity"] = entity;
                arguments["type"] = "release"; // Custom event type
                event_system::publishLuaEvent("movable_mouse_released", arguments);
            }
            isDragging = false;
            currentlyDraggedEntity = entt::null; // Reset currently dragged entity
        }

        // Update the previous mouse state
        wasMouseDown = isMouseDown;
    }

    // TODO: this needs to change to take my own impl into account
    auto drawSingleMovableAsText(entt::entity entity, Color color) -> void
    {
        if (!globals::registry.any_of<TextDisplay>(entity) || !globals::registry.any_of<Movable>(entity))
            return;

        auto &textDisplay = globals::registry.get<TextDisplay>(entity);
        if (!textDisplay.visible)
            return;

        auto &movable = globals::registry.get<Movable>(entity);
        std::string text = textDisplay.text;

        float baseScale = movable.visualScale.value_or(1.0f);
        float baseRotation = movable.visualRotation.value_or(0.0f);

        // Apply juice transformations if available
        float finalScale = baseScale;
        float finalRotation = baseRotation;
        if (movable.juice)
        {
            finalScale += movable.juice->scale - 1;
            finalRotation += movable.juice->rotation;
        }

        // Measure text size based on base font size
        Vector2 textSize = MeasureTextEx(GetFontDefault(), text.c_str(), 20, 1);

        // Calculate the unscaled center offset (based on scale = 1)
        float centerX = textSize.x / 2;
        float centerY = textSize.y / 2;

        // Push the transformation matrix
        rlPushMatrix();

        // Step 1: Translate to the top-left anchor point (visualLocation)
        rlTranslatef(movable.visualLocation->x, movable.visualLocation->y, 0);

        // Step 2: Translate to the center of the unscaled text
        rlTranslatef(centerX, centerY, 0);

        // Step 3: Apply scaling and rotation around this center
        rlScalef(finalScale, finalScale, 1);
        rlRotatef(finalRotation, 0, 0, 1);

        // Step 4: Translate back to the top-left of the scaled text
        rlTranslatef(-centerX, -centerY, 0);

        int baseSize = globals::configJSON.at("fonts").at("default_size").get<int>();

        // Draw the text, with (0,0) as the anchor point
        DrawTextPro(
            globals::font,
            text.c_str(),
            Vector2{0, 0}, // Start position is the top-left corner
            Vector2{0, 0}, // No additional origin offset
            0,             // Rotation already applied in the matrix
            baseSize,      // Base font size
            1,             // Character spacing
            color);

        rlPopMatrix();
    }

    
    auto drawSingleMovableAsTextWithShadow(entt::entity entity, Color color, Vector2 screenCenter, float parallaxFactor) -> void
{
    if (!globals::registry.any_of<TextDisplay>(entity) || !globals::registry.any_of<Movable>(entity))
        return;

    auto &textDisplay = globals::registry.get<TextDisplay>(entity);
    if (!textDisplay.visible)
        return;

    auto &movable = globals::registry.get<Movable>(entity);
    std::string text = textDisplay.text;

    float baseScale = movable.visualScale.value_or(1.0f);
    float baseRotation = movable.visualRotation.value_or(0.0f);

    // Apply juice transformations if available
    float finalScale = baseScale;
    float finalRotation = baseRotation;
    if (movable.juice)
    {
        finalScale += movable.juice->scale;
        finalRotation += movable.juice->rotation;
    }

    int baseSize = globals::configJSON.at("fonts").at("default_size").get<int>();

    // Measure text size based on base font size
    Vector2 textSize = MeasureTextEx(globals::font, text.c_str(), baseSize, 1);

    // Calculate the unscaled center offset (based on scale = 1)
    float centerX = textSize.x / 2;
    float centerY = textSize.y / 2;

    // Calculate fixed shadow offset based on parallaxFactor
    Vector2 shadowOffset = {
        parallaxFactor,
        parallaxFactor};

    // Draw shadow text
    rlPushMatrix();

    rlTranslatef(movable.visualLocation->x + shadowOffset.x, movable.visualLocation->y + shadowOffset.y, 0);
    rlTranslatef(centerX, centerY, 0);
    rlScalef(finalScale, finalScale, 1);
    rlRotatef(finalRotation, 0, 0, 1);
    rlTranslatef(-centerX, -centerY, 0);

    DrawTextPro(
        globals::font,
        text.c_str(),
        Vector2{0, 0},
        Vector2{0, 0},
        0,
        baseSize,
        1,
        BLACK); // Shadow color

    rlPopMatrix();

    // Draw main text
    rlPushMatrix();

    rlTranslatef(movable.visualLocation->x, movable.visualLocation->y, 0);
    rlTranslatef(centerX, centerY, 0);
    rlScalef(finalScale, finalScale, 1);
    rlRotatef(finalRotation, 0, 0, 1);
    rlTranslatef(-centerX, -centerY, 0);

    DrawTextPro(
        globals::font,
        text.c_str(),
        Vector2{0, 0},
        Vector2{0, 0},
        0,
        baseSize,
        1,
        color);

    rlPopMatrix();
}

    void updateLinkedLocations()
    {
        auto view = globals::registry.view<Movable, LinkedLocation>();

        for (auto entity : view)
        {
            auto &movable = view.get<Movable>(entity);
            const auto &link = view.get<LinkedLocation>(entity);

            if (globals::registry.valid(link.linked_entity) && globals::registry.any_of<Movable>(link.linked_entity))
            {
                auto &linked_movable = globals::registry.get<Movable>(link.linked_entity);

                // Apply the offset
                movable.visualLocation->x = linked_movable.visualLocation->x + link.offset_x;
                movable.visualLocation->y = linked_movable.visualLocation->y + link.offset_y;
            }
        }
    }

}