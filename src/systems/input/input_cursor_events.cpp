#include "input_cursor_events.hpp"

#include "input_constants.hpp"
#include "input_actions.hpp"

#include "core/globals.hpp"
#include "core/engine_context.hpp"
#include "core/events.hpp"

#include "systems/transform/transform_functions.hpp"
#include "systems/main_loop_enhancement/main_loop.hpp"
#include "systems/ui/ui.hpp"
#include "systems/ui/element.hpp"
#include "systems/timer/timer.hpp"
#include "systems/physics/transform_physics_hook.hpp"

#include "raylib.h"
#include "raymath.h"
#include "spdlog/spdlog.h"

#include <algorithm>

namespace input {
namespace cursor_events {

// ───────────────────────────────────────────────────────────────────────────
// Forward declarations for internal helpers
// ───────────────────────────────────────────────────────────────────────────

static EngineContext* resolveCtx(EngineContext* ctx) {
    return ctx ? ctx : globals::g_ctx;
}

static event_bus::EventBus& resolveEventBus(EngineContext* ctx) {
    if (auto* resolved = resolveCtx(ctx)) {
        return resolved->eventBus;
    }
    // Fallback to global event bus
    return globals::getEventBus();
}

// ───────────────────────────────────────────────────────────────────────────
// Helpers
// ───────────────────────────────────────────────────────────────────────────

void stop_hover(entt::registry &registry, entt::entity target)
{
    if (!registry.valid(target)) return;

    // ❌ Don't stop hover while dragging this entity
    if (registry.any_of<transform::GameObject>(target))
    {
        auto &node = registry.get<transform::GameObject>(target);
        if (node.state.isBeingDragged)
            return;
    }

    if (registry.any_of<ui::UIElementComponent>(target))
    {
        ui::element::StopHover(registry, target);
    }
    else if (auto *node = registry.try_get<transform::GameObject>(target))
    {
        if (node->methods.onStopHover)
            node->methods.onStopHover(registry, target);
    }
}

// ───────────────────────────────────────────────────────────────────────────
// Propagation to GameObjects
// ───────────────────────────────────────────────────────────────────────────

void propagate_release(input::InputState &inputState, entt::registry &registry)
{
    // explicit stop hover to ensure no hover stop is missed
    if (inputState.prev_designated_hover_target != entt::null &&
    inputState.current_designated_hover_target != inputState.prev_designated_hover_target)
    {
        // stop_hover(registry, inputState.prev_designated_hover_target);
    }

    if (inputState.cursor_released_on_handled == false && registry.valid(inputState.cursor_prev_dragging_target))
    {
        auto &releasedOnTargetNode = registry.get<transform::GameObject>(inputState.cursor_released_on_target);

        // previous dragging target was also the hover target
        if (inputState.cursor_prev_dragging_target == inputState.current_designated_hover_target)
        {

            if (registry.any_of<ui::UIElementComponent>(inputState.cursor_released_on_target))
            {
                auto &uiElement = registry.get<ui::UIElementComponent>(inputState.cursor_released_on_target);
                ui::element::Release(registry, inputState.cursor_released_on_target, inputState.cursor_prev_dragging_target);
            }
            else if (releasedOnTargetNode.methods.onStopHover)
                // releasedOnTargetNode.methods.onStopHover(registry, inputState.cursor_released_on_target);
                ;

            inputState.current_designated_hover_target = entt::null;
        }
        // release the previously dragged target
        if (registry.any_of<ui::UIElementComponent>(inputState.cursor_released_on_target))
        {
            auto &uiElement = registry.get<ui::UIElementComponent>(inputState.cursor_released_on_target);
            ui::element::Release(registry, inputState.cursor_released_on_target, inputState.cursor_prev_dragging_target);
        }

        if (releasedOnTargetNode.methods.onRelease)
        {
            SPDLOG_DEBUG("Node {} was released on top of {}", static_cast<int>(inputState.cursor_prev_dragging_target), static_cast<int>(inputState.cursor_released_on_target));

            releasedOnTargetNode.methods.onRelease(registry, inputState.cursor_released_on_target, inputState.cursor_prev_dragging_target);
        }
        inputState.cursor_released_on_handled = true;
    }

    // handle the hovered-over object

    if (registry.valid(inputState.current_designated_hover_target))
    {

        // save the location relative to the transform of the hover target so cursor "sticks"
        transform::SetClickOffset(&registry, inputState.current_designated_hover_target, inputState.cursor_hover_transform.value(), false);

        // new hover target
        if (inputState.prev_designated_hover_target != inputState.current_designated_hover_target)
        {

            // make sure dragging & hover don't happen at the same time. Run hover handler for new target
            if (inputState.current_designated_hover_target != inputState.cursor_dragging_target && !inputState.hid.touch_enabled)
            {
                auto &hoverTargetNode = registry.get<transform::GameObject>(inputState.current_designated_hover_target);
                if (registry.any_of<ui::UIElementComponent>(inputState.current_designated_hover_target))
                {
                    auto &uiElement = registry.get<ui::UIElementComponent>(inputState.current_designated_hover_target);
                    ui::element::ApplyHover(registry, inputState.current_designated_hover_target);
                }
                else if (hoverTargetNode.methods.onHover)
                {
                    hoverTargetNode.methods.onHover(registry, inputState.current_designated_hover_target);
                }
            }
            // touch input enabled
            else if (inputState.hid.touch_enabled)
            {
                // wait for a short time before running hover handler
                auto hoverTargetAsOfNow = inputState.current_designated_hover_target;
                timer::TimerSystem::timer_after(TOUCH_INPUT_MINIMUM_HOVER_TIME, [&inputState, &registry, hoverTargetAsOfNow](std::optional<float> notImportant)
                                                {
                                                    // still hovering
                                                    if (registry.valid(hoverTargetAsOfNow) && hoverTargetAsOfNow == inputState.current_designated_hover_target)
                                                    {
                                                        auto &hoverTargetNode = registry.get<transform::GameObject>(hoverTargetAsOfNow);

                                                        if (registry.any_of<ui::UIElementComponent>(hoverTargetAsOfNow))
                                                        {
                                                            auto &uiElement = registry.get<ui::UIElementComponent>(hoverTargetAsOfNow);
                                                            ui::element::ApplyHover(registry, hoverTargetAsOfNow);
                                                        }
                                                        else if (hoverTargetNode.methods.onHover)
                                                        {
                                                            hoverTargetNode.methods.onHover(registry, hoverTargetAsOfNow);
                                                        }
                                                    } });

                // if touch had a prev hover target, remove hover
                if (registry.valid(inputState.prev_designated_hover_target))
                {
                    auto &prevHoverTargetNode = registry.get<transform::GameObject>(inputState.prev_designated_hover_target);

                    if (registry.any_of<ui::UIElementComponent>(inputState.prev_designated_hover_target))
                    {
                        auto &uiElement = registry.get<ui::UIElementComponent>(inputState.prev_designated_hover_target);
                        ui::element::StopHover(registry, inputState.prev_designated_hover_target);
                    }
                    else if (prevHoverTargetNode.methods.onStopHover)
                    {
                        // prevHoverTargetNode.methods.onStopHover(registry, inputState.prev_designated_hover_target);
                    }
                }
            }

            // hover has moved over, stop hovering over previous target
            if (registry.valid(inputState.prev_designated_hover_target))
            {
                auto &prevHoverTargetNode = registry.get<transform::GameObject>(inputState.prev_designated_hover_target);

                if (registry.any_of<ui::UIElementComponent>(inputState.prev_designated_hover_target))
                {
                    auto &uiElement = registry.get<ui::UIElementComponent>(inputState.prev_designated_hover_target);
                    ui::element::StopHover(registry, inputState.prev_designated_hover_target);
                }
                else if (prevHoverTargetNode.methods.onStopHover)
                {
                    // prevHoverTargetNode.methods.onStopHover(registry, inputState.prev_designated_hover_target);
                }
            }
        }
    }
    else
    {
        // no valid hover target, prev target is valid, stop hovering over that one
        if (registry.valid(inputState.prev_designated_hover_target))
        {
            auto &prevHoverTargetNode = registry.get<transform::GameObject>(inputState.prev_designated_hover_target);

            if (registry.any_of<ui::UIElementComponent>(inputState.prev_designated_hover_target))
            {
                auto &uiElement = registry.get<ui::UIElementComponent>(inputState.prev_designated_hover_target);
                // ui::element::StopHover(registry, inputState.prev_designated_hover_target);
            }
            else if (prevHoverTargetNode.methods.onStopHover)
            {
                // prevHoverTargetNode.methods.onStopHover(registry, inputState.prev_designated_hover_target);
            }
        }
    }
}

void propagate_drag(entt::registry &registry, input::InputState &inputState)
{
    if (registry.valid(inputState.cursor_dragging_target))
    {
        auto &draggingTargetNode = registry.get<transform::GameObject>(inputState.cursor_dragging_target);
        transform::StartDrag(&registry, inputState.cursor_dragging_target, true);
        if (draggingTargetNode.methods.onDrag)
        {
            draggingTargetNode.methods.onDrag(registry, inputState.cursor_dragging_target);
        }
        else
        {
            // SPDLOG_DEBUG("No drag handler for entity {}", static_cast<int>(inputState.cursor_dragging_target));
        }
    }
}

void hover_drag_check(entt::registry &registry, input::InputState &inputState)
{
    if (registry.valid(inputState.current_designated_hover_target) && inputState.current_designated_hover_target == inputState.cursor_dragging_target && !inputState.hid.touch_enabled)
    {
        // dont let hovering happen while dragging.
        auto &hoverTargetNode = registry.get<transform::GameObject>(inputState.current_designated_hover_target);

        if (registry.any_of<ui::UIElementComponent>(inputState.current_designated_hover_target))
        {
            auto &uiElement = registry.get<ui::UIElementComponent>(inputState.current_designated_hover_target);
            ui::element::StopHover(registry, inputState.current_designated_hover_target);
        }
        else if (hoverTargetNode.methods.onStopHover)
        {
            hoverTargetNode.methods.onStopHover(registry, inputState.current_designated_hover_target);
        }
    }
}

void propagate_clicks(entt::registry &registry, input::InputState &inputState)
{
    if (registry.valid(inputState.cursor_clicked_target) && inputState.cursor_click_handled == false)
    {

        auto &clickedTargetNode = registry.get<transform::GameObject>(inputState.cursor_clicked_target);

        if (registry.all_of<ui::UIElementComponent, ui::UIConfig, ui::UIState, transform::GameObject>(inputState.cursor_clicked_target))
        {
            ui::element::Click(registry, inputState.cursor_clicked_target);

            if (static_cast<int>(inputState.cursor_clicked_target) == 228)
            {
                SPDLOG_DEBUG("Clicked on checkbox");
            }
        }
        if (clickedTargetNode.methods.onClick)
        {
            clickedTargetNode.methods.onClick(registry, inputState.cursor_clicked_target);
        }
        SPDLOG_DEBUG("Clicked on entity {}", static_cast<int>(inputState.cursor_clicked_target));
        inputState.cursor_click_handled = true; // TODO: perhaps rename these to be more intuitive
    }
}

// ───────────────────────────────────────────────────────────────────────────
// Event Handlers
// ───────────────────────────────────────────────────────────────────────────

void handle_hover_event(InputState &inputState, entt::registry &registry) {
    // 🔒 Skip hover updates while dragging
    if (registry.valid(inputState.cursor_dragging_target))
        return;

    bool hasHover = registry.valid(inputState.cursor_hovering_target) || inputState.is_cursor_down;
    entt::entity current = inputState.current_designated_hover_target;
    entt::entity newHover = hasHover ? inputState.cursor_hovering_target : entt::null;

    // 1. If new == old → just mark still hovered
    if (newHover == current && newHover != entt::null) return;

    // 2. If old exists and is different → stop old
    if (registry.valid(current) && current != newHover)
        stop_hover(registry, current);

    // 3. If new exists → start hover
    if (registry.valid(newHover)) {
        auto &node = registry.get<transform::GameObject>(newHover);
        node.state.isBeingHovered = true;
        if (node.methods.onHover) node.methods.onHover(registry, newHover);
    }

    // 4. Update
    inputState.current_designated_hover_target = newHover;
}

void handle_released_event(input::InputState &inputState, entt::registry &registry)
{
    if (inputState.cursor_up_handled == false)
    {

        auto *cursorUpTargetNode = registry.try_get<transform::GameObject>(inputState.cursor_up_target);
        
        SPDLOG_DEBUG("[RELEASE-DEBUG] cursor_up_target={} prev_dragging={} collision_list_size={}", 
            static_cast<int>(inputState.cursor_up_target), 
            static_cast<int>(inputState.cursor_prev_dragging_target),
            inputState.collision_list.size());

        // if cursorUpTargetNode is the same as the cursor_prev_dragging_target, get another entity colliding with the cursor from the collision list and use that instead for cursor_up_target
        if (inputState.cursor_up_target == inputState.cursor_prev_dragging_target)
        {
            SPDLOG_DEBUG("[RELEASE-DEBUG] Looking for drop target in collision_list...");
            entt::entity nextCollided{entt::null};
            for (auto &collision : inputState.collision_list)
            {
                auto *collisionNode = registry.try_get<transform::GameObject>(collision);
                if (collisionNode == nullptr) {
                    SPDLOG_DEBUG("[RELEASE-DEBUG] entity {} has no GameObject", static_cast<int>(collision));
                    continue;
                }
                if (collisionNode->state.triggerOnReleaseEnabled == false) {
                    SPDLOG_DEBUG("[RELEASE-DEBUG] entity {} has triggerOnReleaseEnabled=false", static_cast<int>(collision));
                    continue;
                }
                if (collision != inputState.cursor_prev_dragging_target)
                {
                    nextCollided = collision;
                    SPDLOG_DEBUG("Cursor up target is the same as cursor down target, using next collided entity {}", static_cast<int>(nextCollided));
                    break;
                }
            }

            if (registry.valid(nextCollided))
            {
                inputState.cursor_up_target = nextCollided;
                cursorUpTargetNode = registry.try_get<transform::GameObject>(inputState.cursor_up_target);
            } else {
                SPDLOG_DEBUG("[RELEASE-DEBUG] No valid drop target found in collision_list!");
            }
        }

        // or was dragging something else?
        if (registry.valid(inputState.cursor_prev_dragging_target) && registry.valid(inputState.cursor_up_target) && cursorUpTargetNode->state.triggerOnReleaseEnabled)
        {
            inputState.cursor_released_on_target = inputState.cursor_up_target;
            SPDLOG_DEBUG("Cursor released on target {}", static_cast<int>(inputState.cursor_up_target));
            // TODO: change these anmes to be more intuitive
            inputState.cursor_released_on_handled = false;
        }

        // if dragging, stop dragging
        if (registry.valid(inputState.cursor_dragging_target))
        {
            SPDLOG_DEBUG("Stop dragging");

            // 🔴 ADD: tell physics to restore body type and switch back to AuthoritativePhysics
            physics::OnDrop(registry, inputState.cursor_dragging_target);

            transform::StopDragging(&registry, inputState.cursor_dragging_target);

            auto &downTargetNode = registry.get<transform::GameObject>(inputState.cursor_down_target);
            downTargetNode.state.isBeingDragged = false;
            inputState.cursor_dragging_target = entt::null;
        }

        // cursor released in same location as cursor press and within cursor timeout
        // TODO: de-nest this horrible code
        if (registry.valid(inputState.cursor_down_target))
        {
            if (!inputState.cursor_down_target_click_timeout || inputState.cursor_down_target_click_timeout.value_or(constants::DEFAULT_CLICK_TIMEOUT) * main_loop::mainLoop.timescale > inputState.cursor_up_time - inputState.cursor_down_time)
            {
                SPDLOG_DEBUG("Cursor up time: {}, cursor down time: {}", inputState.cursor_up_time, inputState.cursor_down_time);
                SPDLOG_DEBUG("Cursor down target click timeout: {}", inputState.cursor_down_target_click_timeout.value_or(constants::DEFAULT_CLICK_TIMEOUT) * main_loop::mainLoop.timescale);
                // cursor hasn't moved enough

                if (Vector2Distance(inputState.cursor_down_position.value(), inputState.cursor_up_position.value()) < CURSOR_MINIMUM_MOVEMENT_DISTANCE)
                {
                    SPDLOG_DEBUG("Cursor movement distance : {}", Vector2Distance(inputState.cursor_down_position.value(), inputState.cursor_up_position.value()));
                    auto &downTargetNode = registry.get<transform::GameObject>(inputState.cursor_down_target);
                    // register as click
                    if (downTargetNode.state.clickEnabled)
                    {
                        SPDLOG_DEBUG("Cursor releasedEvent: cursor down target {} has click enabled, registering as click", static_cast<int>(inputState.cursor_down_target));
                        inputState.cursor_clicked_target = inputState.cursor_down_target;
                        inputState.cursor_click_handled = false;
                    }
                }
            }
        }
        inputState.cursor_up_handled = true; // finish handling cursor up
    }
}

void handle_down_event(entt::registry &registry, input::InputState &inputState)
{
    if (registry.valid(inputState.cursor_down_target) && inputState.cursor_down_handled == false)
    { // TODO: so this is false if cursor is down and hasn't been handled?

        auto &cursorDownTargetNode = registry.get<transform::GameObject>(inputState.cursor_down_target);

        // start dragging if target can be dragged
        if (cursorDownTargetNode.state.dragEnabled)
        {
            SPDLOG_DEBUG("Start dragging");
            cursorDownTargetNode.state.isBeingDragged = true;
            transform::SetClickOffset(&registry, inputState.cursor_down_target, inputState.cursor_down_position.value(), true);
            inputState.cursor_dragging_target = inputState.cursor_down_target;

            // call onDrag if exists
            if (cursorDownTargetNode.methods.onDrag)
            {
                cursorDownTargetNode.methods.onDrag(registry, inputState.cursor_down_target);
            }
        }
        // mark cursor down as handled
        inputState.cursor_down_handled = true;
    }
}

// ───────────────────────────────────────────────────────────────────────────
// Mouse Button Processing
// ───────────────────────────────────────────────────────────────────────────

void process_raylib_click(input::InputState &inputState, entt::registry &registry)
{
    if (!inputState.L_cursor_queue) return;

    // Cursor click has been queued by raylib
    const auto click = *inputState.L_cursor_queue;
    process_left_press(registry, inputState, click.x, click.y);
    inputState.L_cursor_queue.reset();

    // After processing the click, reconcile active TextInput w/ current cursor hits.
    const entt::entity active = inputState.activeTextInput;

    // Nothing active: nothing to toggle
    if (active == entt::null) {
        // SetMouseCursor(MOUSE_CURSOR_DEFAULT);
        return;
    }

    // If entity is gone or no longer has TextInput, clear it
    if (!registry.valid(active) || !registry.any_of<ui::TextInput>(active)) {
        SPDLOG_DEBUG("Active text input {} invalid or missing component; clearing",
                    static_cast<int>(active));
        inputState.activeTextInput = entt::null;
        // SetMouseCursor(MOUSE_CURSOR_DEFAULT);
        return;
    }

    // Still valid: check if cursor is over it
    const bool under_cursor =
        std::find(inputState.nodes_at_cursor.begin(),
                inputState.nodes_at_cursor.end(),
                active) != inputState.nodes_at_cursor.end();

    auto &textInputNode = registry.get<ui::TextInput>(active);
    textInputNode.isActive = under_cursor;

    if (!under_cursor) {
        SPDLOG_DEBUG("Marking active text input {} as inactive", static_cast<int>(active));
        inputState.activeTextInput = entt::null;
        // SetMouseCursor(MOUSE_CURSOR_DEFAULT);
    } else {
        // SetMouseCursor(MOUSE_CURSOR_IBEAM);
    }
}

void enqueue_left_press(InputState &state, float x, float y)
{
    // Return early if the frame is locked
    if (state.activeInputLocks["frame"])
    {
        return;
    }

    // Handle the splash state by simulating an "Escape" key press, for example

    // Queue the left cursor press with the specified coordinates
    state.L_cursor_queue = {x, y};
}

void enqueue_right_press(InputState &state, float x, float y)
{
    if (state.activeInputLocks["frame"])
    {
        return;
    }
    state.R_cursor_queue = Vector2{x, y};
}

void propagate_right_clicks(entt::registry &registry, input::InputState &inputState)
{
    if (!inputState.R_cursor_queue) return;
    inputState.R_cursor_queue.reset();

    entt::entity target = entt::null;

    if (registry.valid(inputState.current_designated_hover_target))
    {
        target = inputState.current_designated_hover_target;
    }
    else if (registry.valid(inputState.cursor_focused_target))
    {
        target = inputState.cursor_focused_target;
    }

    if (!registry.valid(target)) return;

    auto *node = registry.try_get<transform::GameObject>(target);
    if (!node) return;

    if (node->state.rightClickEnabled && node->methods.onRightClick)
    {
        node->methods.onRightClick(registry, target);
        SPDLOG_DEBUG("Right-clicked on entity {}", static_cast<int>(target));
    }
}

// called by update() function
void process_left_press(entt::registry &registry, InputState &state, float x, float y)
{
    // Default to current cursor position if x or y is not provided
    if (x < 0.0f)
        x = state.cursor_position.x;
    if (y < 0.0f)
        y = state.cursor_position.y;

    // Return early if locked or frame conditions prevent processing
    if ((state.inputLocked && (!globals::getIsGamePaused() || globals::getScreenWipe())) || state.activeInputLocks["frame"])
    {
        return;
    }

    SPDLOG_DEBUG("Left mouse button pressed at ({}, {})", x, y);

    // Calculate scaled cursor position and update cursor down state
    state.cursor_down_position = {x, y};
    state.cursor_down_time = main_loop::mainLoop.totaltimeTimer;
    state.cursor_down_handled = false;
    state.cursor_down_target = entt::null;
    state.is_cursor_down = true;

    // Determine the press node (priority: touch -> hovering -> focused)
    entt::entity press_node;

    // Check for the highest priority: touch input and a hover target
    if (state.hid.touch_enabled && registry.valid(state.cursor_hovering_target))
    {
        press_node = state.cursor_hovering_target;
    }
    // If no press node yet, check for hovering target
    else if (registry.valid(state.current_designated_hover_target))
    {
        SPDLOG_DEBUG("Current designated hover target is valid");
        press_node = state.current_designated_hover_target;
    }
    // If still no press node, check for a focused target
    else if (registry.valid(state.cursor_focused_target))
    {
        SPDLOG_DEBUG("Current designated focus target is valid");
        press_node = state.cursor_focused_target;
    }

    // still none, just check for the first cursor collided target which is clickable (maybe run on all of them?)
    else
    {
        for (auto &entity : state.collision_list)
        {
            auto &node = registry.get<transform::GameObject>(entity);
            if (node.state.clickEnabled)
            {
                press_node = entity;
                break;
            }
        }
    }

    // Assign the press node as the target if it can handle a click or drag
    if (registry.valid(press_node) && registry.any_of<transform::GameObject>(press_node))
    {
        auto &node = registry.get<transform::GameObject>(press_node);
        if (node.state.clickEnabled)
        {
            SPDLOG_DEBUG("Press node can click, setting cursor down target");
            state.cursor_down_target = press_node;
        }
        else if (node.state.dragEnabled)
        {
            SPDLOG_DEBUG("Press node can drag, setting cursor down target");
            state.cursor_down_target = press_node;
        }
    }

    // Fallback to the room if no valid target is found
    if (!registry.valid(state.cursor_down_target))
    {
        SPDLOG_DEBUG("No valid target found, falling back to ROOM");
        state.cursor_down_target = globals::getGameWorldContainer();
    }

    input::DispatchRaw(state, InputDeviceInputCategory::MOUSE, MOUSE_LEFT_BUTTON, /*down*/true, /*value*/0.f);
}

// called by update() function
void process_left_release(entt::registry &registry, InputState &state, float x, float y, EngineContext* ctx)
{
    auto& bus = resolveEventBus(ctx);
    // Default to current cursor position if x or y is not provided
    if (x < 0.0f)
        x = state.cursor_position.x;
    if (y < 0.0f)
        y = state.cursor_position.y;

    // Return early if locked or frame conditions prevent processing
    if ((state.inputLocked && (!globals::getIsGamePaused() || globals::getScreenWipe())) || state.activeInputLocks["frame"])
    {
        return;
    }

    SPDLOG_DEBUG("Left mouse button released at ({}, {})", x, y);

    // Update cursor release state
    state.cursor_up_position = {x, y};
    state.cursor_up_time = main_loop::mainLoop.totaltimeTimer;
    state.cursor_up_handled = false;
    state.cursor_up_target = entt::null;
    state.is_cursor_down = false;

    // Determine the release target (hovering -> focused)
    if (registry.valid(state.current_designated_hover_target))
    {
        SPDLOG_DEBUG("Current designated hover target is valid for release");
        state.cursor_up_target = state.current_designated_hover_target;
    }
    else if (registry.valid(state.cursor_focused_target))
    {
        SPDLOG_DEBUG("Cursor focused target is valid for release");
        state.cursor_up_target = state.cursor_focused_target;
    }
    else
    {

        // Fallback to ROOM if no valid target
        state.cursor_up_target = globals::getGameWorldContainer();
        SPDLOG_DEBUG("No valid target found, falling back to ROOM");
    }

    input::DispatchRaw(state, InputDeviceInputCategory::MOUSE, MOUSE_LEFT_BUTTON, /*down*/false, /*value*/0.f);

    // Publish the click event with resolved target for systems that listen via the bus.
    bus.publish(events::MouseClicked{
        {x, y},
        MOUSE_LEFT_BUTTON,
        state.cursor_up_target
    });

    // Notify UI subscribers when a UI element was activated via mouse.
    if (registry.valid(state.cursor_up_target) &&
        registry.any_of<ui::UIElementComponent>(state.cursor_up_target)) {
        bus.publish(events::UIButtonActivated{state.cursor_up_target, MOUSE_LEFT_BUTTON});
    }
}

} // namespace cursor_events
} // namespace input
