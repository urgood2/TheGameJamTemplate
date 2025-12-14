#include "input_functions.hpp"
#include "input_lua_bindings.hpp"
#include "input_keyboard.hpp"
#include "input_gamepad.hpp"
#include "input_hid.hpp"

#include "raylib.h"

#include "entt/entt.hpp"

#include "spdlog/spdlog.h"
#include "systems/camera/camera_manager.hpp"
#include "systems/collision/broad_phase.hpp"
#include "util/common_headers.hpp"

#include "core/globals.hpp"

#include "input.hpp"
#include "input_actions.hpp"
#include "input_constants.hpp"
#include "input_function_data.hpp"

#include "systems/transform/transform_functions.hpp"
#include "systems/main_loop_enhancement/main_loop.hpp"
#include "systems/ui/ui.hpp"
#include "systems/ui/ui_data.hpp"
#include "systems/ui/element.hpp"
#include "systems/scripting/binding_recorder.hpp"
#include "systems/timer/timer.hpp"
#include "systems/physics/transform_physics_hook.hpp"
#include "core/engine_context.hpp"
#include "core/events.hpp"

#include "raylib.h"
#include "raymath.h"

#include <algorithm>
#include <vector>
#include <unordered_map>
#include <string>
#include <regex>

using namespace snowhouse; // assert
// TODO: focus traversal with gamepad should be tested after ui
// TODO: cursor stacks also need to be tested after ui
namespace input
{
    // Resolve input state and registry, preferring the EngineContext when available.
    static EngineContext* resolveCtx(EngineContext* ctx) {
        return ctx ? ctx : globals::g_ctx;
    }

    static InputState& resolveInputState() {
        if (globals::g_ctx && globals::g_ctx->inputState) {
            return *globals::g_ctx->inputState;
        }
        return globals::getInputState();
    }

    static entt::registry& resolveRegistry() {
        return globals::getRegistry();
    }

    static event_bus::EventBus& resolveEventBus(EngineContext* ctx) {
        if (auto* resolved = resolveCtx(ctx)) {
            return resolved->eventBus;
        }
        return globals::getEventBus();
    }

    void HandleTextInput(ui::TextInput &input) {
        keyboard::handle_text_input(input);
    }
    

    // Initializes the controller
    auto Init(InputState &inputState, entt::registry &registry, EngineContext* ctx) -> void
    {
        // make new
        inputState = InputState{};

        // clear all locks
        inputState.activeInputLocks.clear();

        // create locks
        inputState.activeInputLocks["frame"] = false;
        inputState.activeInputLocks["frame_lock_reset_next_frame"] = false;
        
        // always make container entity by default
        globals::setGameWorldContainer(transform::CreateGameWorldContainerEntity(&registry, 0, 0, globals::VIRTUAL_WIDTH, globals::VIRTUAL_HEIGHT));
        auto &gameMapNode = registry.get<transform::GameObject>(globals::getGameWorldContainer());
        gameMapNode.debug.debugText = "Map Container";

        // create cursor
        globals::setCursorEntity(transform::CreateOrEmplace(&registry, globals::getGameWorldContainer(), 0, 0, 10, 10));
        // screen space
        registry.emplace_or_replace<collision::ScreenSpaceCollisionMarker>(globals::getCursorEntity());
        auto &cursorNode = registry.get<transform::GameObject>(globals::getCursorEntity());
        cursorNode.debug.debugText = "Cursor";

        if (ctx) {
            ctx->inputState = &inputState;
        }
    }

    auto PollInput(entt::registry &registry, InputState &inputState, float dt, EngineContext* ctx) -> void
    {
        auto& bus = resolveEventBus(ctx);

        // keyboard input polling
        // ---------------- Keyboard Input ----------------
        static std::vector<bool> keyDownLastFrame(KEY_KP_EQUAL + 1, false);
        for (int key = 0; key <= KEY_KP_EQUAL; key++)
        {
            if (IsKeyDown(key))
            {
                hid::reconfigure_device_info(inputState, InputDeviceInputCategory::KEYBOARD);
                ProcessKeyboardKeyDown(inputState, (KeyboardKey)key);
                if (!keyDownLastFrame[key]) {
                    keyDownLastFrame[key] = true;
                    const bool shift = IsKeyDown(KEY_LEFT_SHIFT) || IsKeyDown(KEY_RIGHT_SHIFT);
                    const bool ctrl = IsKeyDown(KEY_LEFT_CONTROL) || IsKeyDown(KEY_RIGHT_CONTROL);
                    const bool alt = IsKeyDown(KEY_LEFT_ALT) || IsKeyDown(KEY_RIGHT_ALT);
                    bus.publish(events::KeyPressed{key, shift, ctrl, alt});
                }
            }
            if (IsKeyReleased(key))
            {
                hid::reconfigure_device_info(inputState, InputDeviceInputCategory::KEYBOARD);
                ProcessKeyboardKeyRelease(inputState, (KeyboardKey)key);
                keyDownLastFrame[key] = false;
            }
        }

        // poll touch? LATER: implement touch
        if (GetTouchPointCount() > 0)
        {
            hid::reconfigure_device_info(inputState, InputDeviceInputCategory::TOUCH);
        }

        // poll mouse buttons
        static bool mouseLeftDownLastFrame = false, mouseRightDownLastFrame = false,
                    mosueLeftDownCurrentFrame = false, mouseRightDownCurrentFrame = false;

        mosueLeftDownCurrentFrame = IsMouseButtonDown(MOUSE_LEFT_BUTTON);
        mouseRightDownCurrentFrame = IsMouseButtonDown(MOUSE_RIGHT_BUTTON);

        bool mouseDetectDownFirstFrameLeft = mosueLeftDownCurrentFrame && !mouseLeftDownLastFrame;
        bool mouseDetectDownFirstFrameRight = mouseRightDownCurrentFrame && !mouseRightDownLastFrame;

        // SPDLOG_DEBUG("Current frame - Mouse left down: {} right down: {}", mosueLeftDownCurrentFrame, mouseRightDownCurrentFrame);
        // SPDLOG_DEBUG("Last frame - Mouse left down: {} right down: {}", mouseLeftDownLastFrame, mouseRightDownLastFrame);

        if (mouseDetectDownFirstFrameLeft)
        { // this should only register first time the button is held down
            hid::reconfigure_device_info(inputState, InputDeviceInputCategory::MOUSE);
            Vector2 mousePos = globals::getScaledMousePositionCached();
            EnqueueLeftMouseButtonPress(inputState, mousePos.x, mousePos.y);
            bus.publish(events::MouseClicked{mousePos, MOUSE_LEFT_BUTTON});
        }
        if (mouseDetectDownFirstFrameRight)
        {
            hid::reconfigure_device_info(inputState, InputDeviceInputCategory::MOUSE);
            Vector2 mousePos = globals::getScaledMousePositionCached();
            // TODO: right mouse handling isn't really configured, need to add
            EnqueRightMouseButtonPress(inputState, mousePos.x, mousePos.y);
            bus.publish(events::MouseClicked{mousePos, MOUSE_RIGHT_BUTTON});
        }
        if (mosueLeftDownCurrentFrame == false && mouseLeftDownLastFrame == true)
        { // release only for left button
            hid::reconfigure_device_info(inputState, InputDeviceInputCategory::MOUSE);
            Vector2 mousePos = globals::getScaledMousePositionCached();
            ProcessLeftMouseButtonRelease(registry, inputState, mousePos.x, mousePos.y, ctx);
        }

        mouseLeftDownLastFrame = mosueLeftDownCurrentFrame;
        mouseRightDownLastFrame = mouseRightDownCurrentFrame;
        // no middle mouse

        // poll mouse movement
        if (GetMouseDelta().x != 0 || GetMouseDelta().y != 0)
        {
            hid::reconfigure_device_info(inputState, InputDeviceInputCategory::MOUSE);
        }
        
        // poll mouse wheel
        if (GetMouseWheelMove() != 0)
        {
            hid::reconfigure_device_info(inputState, InputDeviceInputCategory::MOUSE);
            input::DispatchRaw(inputState,
            InputDeviceInputCategory::GAMEPAD_AXIS, // intentionally using gamepad axis category here to represent mouse wheel as an axis
            AXIS_MOUSE_WHEEL_Y,
            /*down*/ true,
            /*value*/ GetMouseWheelMove());
        }

        // poll gamepad
        if (IsGamepadAvailable(0))
        { // just the one gamepad

            struct GamepadButtonState
            {
                bool downLastFrame = false, downCurrentFrame = false;
            };
            static std::unordered_map<GamepadButton, GamepadButtonState> gamepadButtonStates;

            for (int button = GamepadButton::GAMEPAD_BUTTON_LEFT_FACE_UP; button <= GAMEPAD_BUTTON_RIGHT_THUMB; button++)
            {
                gamepadButtonStates[(GamepadButton)button].downCurrentFrame = IsGamepadButtonDown(0, (GamepadButton)button);

                bool gamepadButtonDetectDownFirstFrame = gamepadButtonStates[(GamepadButton)button].downCurrentFrame && !gamepadButtonStates[(GamepadButton)button].downLastFrame;
                bool gamepadButtonDetectUpFirstFrame = !gamepadButtonStates[(GamepadButton)button].downCurrentFrame && gamepadButtonStates[(GamepadButton)button].downLastFrame;

                if (gamepadButtonDetectDownFirstFrame)
                {
                    hid::set_current_gamepad(inputState, GetGamepadName(0), 0);
                    hid::reconfigure_device_info(inputState, InputDeviceInputCategory::GAMEPAD_BUTTON, (GamepadButton)button);
                    ProcessButtonPress(inputState, (GamepadButton)button, ctx);
                }
                if (gamepadButtonDetectUpFirstFrame)
                {
                    hid::set_current_gamepad(inputState, GetGamepadName(0), 0);
                    hid::reconfigure_device_info(inputState, InputDeviceInputCategory::GAMEPAD_BUTTON, (GamepadButton)button);
                    ProcessButtonRelease(inputState, (GamepadButton)button, ctx);
                }

                gamepadButtonStates[(GamepadButton)button].downLastFrame = gamepadButtonStates[(GamepadButton)button].downCurrentFrame;
            }

            // // Detect joystick movement
            float axisLeftX = GetGamepadAxisMovement(0, GAMEPAD_AXIS_LEFT_X);
            float axisLeftY = GetGamepadAxisMovement(0, GAMEPAD_AXIS_LEFT_Y);
            float axisRightX = GetGamepadAxisMovement(0, GAMEPAD_AXIS_RIGHT_X);
            float axisRightY = GetGamepadAxisMovement(0, GAMEPAD_AXIS_RIGHT_Y);
            float axisLT = GetGamepadAxisMovement(0, GAMEPAD_AXIS_LEFT_TRIGGER);
            float axisRT = GetGamepadAxisMovement(0, GAMEPAD_AXIS_RIGHT_TRIGGER);
            // printf("Gamepad name: %s\n", GetGamepadName(0));
            // printf("Axis count: %d\n", GetGamepadAxisCount(0));
            // SPDLOG_DEBUG("Axis movements: Lx={} Ly={} Rx={} Ry={} LT={} RT={}", axisLeftX, axisLeftY, axisRightX, axisRightY, axisLT, axisRT);
            if (abs(axisLeftX) > constants::GAMEPAD_AXIS_MOVEMENT_THRESHOLD ||
                abs(axisLeftY) > constants::GAMEPAD_AXIS_MOVEMENT_THRESHOLD ||
                abs(axisRightX) > constants::GAMEPAD_AXIS_MOVEMENT_THRESHOLD ||
                abs(axisRightY) > constants::GAMEPAD_AXIS_MOVEMENT_THRESHOLD ||
                axisLT > -1.f || axisRT > -1.f)
            {
                hid::set_current_gamepad(inputState, GetGamepadName(0), 0);
                
                // SPDLOG_DEBUG("Axis movement detected! Lx={} Ly={}", axisLeftX, axisLeftY);
                // SPDLOG_INFO("Axes: {}", GetGamepadAxisCount(0));

                
                hid::reconfigure_device_info(inputState, InputDeviceInputCategory::GAMEPAD_AXIS);
                UpdateGamepadAxisInput(inputState, registry, dt, ctx);
            }
        }
    }

    auto handleRawInput(entt::registry &registry, InputState &inputState, float dt, EngineContext* ctx) -> void
    {
        PollInput(registry, inputState, dt, ctx);

        ProcessInputLocks(inputState, registry, dt);

        DeleteInvalidEntitiesFromInputRegistry(inputState, registry);
        
        
    }
    
    auto DetectMouseActivity(InputState &state) -> InputDeviceInputCategory
    {
        Vector2 mousePos = globals::getScaledMousePositionCached();

        // Movement threshold
        bool moved = std::fabs(mousePos.x - state.cursor_position.x) > constants::MOUSE_MOVEMENT_THRESHOLD ||
                    std::fabs(mousePos.y - state.cursor_position.y) > constants::MOUSE_MOVEMENT_THRESHOLD;

        // Buttons or wheel
        bool clicked = IsMouseButtonPressed(MOUSE_LEFT_BUTTON) ||
                    IsMouseButtonPressed(MOUSE_RIGHT_BUTTON) ||
                    GetMouseWheelMove() != 0.0f;

        if (moved || clicked)
        {
            state.cursor_position = mousePos; // keep in sync
            return InputDeviceInputCategory::MOUSE;
        }

        return InputDeviceInputCategory::NONE;
    }

    auto Update(entt::registry &registry, InputState &inputState, float dt, EngineContext* ctx) -> void
    {
        ZONE_SCOPED("Input system update");
        
        auto mouseCategory = DetectMouseActivity(inputState);
        auto gamepadCategory = UpdateGamepadAxisInput(inputState, registry, dt, ctx);

        // Choose which device takes precedence
        InputDeviceInputCategory finalCategory = InputDeviceInputCategory::NONE;

        if (mouseCategory != InputDeviceInputCategory::NONE)
        {
            finalCategory = mouseCategory;
        }
        else if (gamepadCategory != InputDeviceInputCategory::NONE)
        {
            finalCategory = gamepadCategory;
        }
        else
        {
            finalCategory = inputState.hid.last_type; // fallback to last known
        }
        
        // SPDLOG_DEBUG("Final category is {}", magic_enum::enum_name(finalCategory));

        if (finalCategory != InputDeviceInputCategory::NONE) {
            hid::reconfigure_device_info(inputState, finalCategory);
        }

        // auto inputCategory = UpdateGamepadAxisInput(inputState, registry, dt, ctx);
        auto &transform = registry.get<transform::Transform>(globals::getCursorEntity());

        handleRawInput(registry, inputState, dt, ctx);

        // hid::reconfigure_device_info(inputState, finalCategory);

        // button/key updates
        PropagateButtonAndKeyUpdates(inputState, registry, dt);

        resetInputStateForProcessing(inputState);
        ProcessControllerSnapToObject(inputState, registry);

        handleRawCursor(inputState, registry);
        MarkEntitiesCollidingWithCursor(registry, inputState, {transform.getVisualX(), transform.getVisualY()});
        
        // static entt::entity activeScrollPane = entt::null;
        static const float scrollSpeed = constants::SCROLL_SPEED;
        // apply scrollpane movement & mousewheel input action polling
        {
            const float mouseWheelMove = GetMouseWheelMove();

            if (registry.valid(inputState.activeScrollPane)
                && inputState.activeScrollPane != entt::null
                && registry.any_of<ui::UIScrollComponent>(inputState.activeScrollPane)
                && std::find(inputState.nodes_at_cursor.begin(),
                            inputState.nodes_at_cursor.end(),
                            inputState.activeScrollPane) != inputState.nodes_at_cursor.end())
            {
                auto &scr = registry.get<ui::UIScrollComponent>(inputState.activeScrollPane);

                if (mouseWheelMove != 0.f && scr.vertical && scr.maxOffset > 0.f) {
                    // wheel up -> content moves down -> offset decreases
                    // keep your sign convention the same as before:
                    scr.offset -= mouseWheelMove * scrollSpeed; // invert if needed
                    scr.offset  = std::clamp(scr.offset, scr.minOffset, scr.maxOffset);

                    if (scr.offset != scr.prevOffset) {
                        // make bars visible for a bit
                        scr.showUntilT = main_loop::getTime() + scr.showSeconds;

                        // push displacement to children (your existing pattern)
                        ui::box::TraverseUITreeBottomUp(
                            registry, inputState.activeScrollPane,
                            [&](entt::entity child) {
                                auto &go = registry.get<transform::GameObject>(child);
                                // vertical-only displacement
                                go.scrollPaneDisplacement = Vector2{0.f, -scr.offset};
                                // NOTE: negative here because you’re conceptually translating content up
                                // If your renderer expects +offset down, flip sign accordingly.
                            },
                            true
                        );

                        scr.prevOffset = scr.offset;
                    }
                }
            } else {
                inputState.activeScrollPane = entt::null;
            }
        }
        
        UpdateFocusForRelevantNodes(registry, inputState, std::nullopt, ctx);
        UpdateCursorHoveringState(registry, inputState);
        processRaylibLeftClick(inputState, registry);

        // cache drag, hover, click, release targets
        cacheInputTargets(inputState);

        handleCursorDownEvent(registry, inputState);
        handleCursorReleasedEvent(inputState, registry);
        handleCursorHoverEvent(inputState, registry);

        propagateClicksToGameObjects(registry, inputState);
        propagateDragToGameObjects(registry, inputState);
        propagateReleaseToGameObjects(inputState, registry);
        // hover target is also being dragged right now, and touch input not being used (no touch input)
        hoverDragSimultaneousCheck(registry, inputState);

        // handle clicks in the registry
        ProcessInputRegistry(inputState, registry);
    
        if (registry.valid(inputState.activeTextInput) && inputState.activeTextInput != entt::null) {
            auto &textInputNode = registry.get<ui::TextInput>(inputState.activeTextInput);
            HandleTextInput(textInputNode);
        }
        
    }
    
    // call at the end of frame for cleanup & action ticking
    void finalizeUpdateAtEndOfFrame(InputState &inputState, float dt) {
        // action bindings
        input::TickActionHolds(inputState, dt);
        input::DecayActions(inputState);
    }
    
    void stopHover(entt::registry &registry, entt::entity target)
    {
        if (!registry.valid(target)) return;
        
        // ❌ Don’t stop hover while dragging this entity
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


    void propagateReleaseToGameObjects(input::InputState &inputState, entt::registry &registry)
    {
        // explicit stop hover to ensure no hover stop is missed
        if (inputState.prev_designated_hover_target != entt::null &&
        inputState.current_designated_hover_target != inputState.prev_designated_hover_target)
        {
            // stopHover(registry, inputState.prev_designated_hover_target);
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
    
    

    void propagateDragToGameObjects(entt::registry &registry, input::InputState &inputState)
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

    void hoverDragSimultaneousCheck(entt::registry &registry, input::InputState &inputState)
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

    void propagateClicksToGameObjects(entt::registry &registry, input::InputState &inputState)
    {
        if (registry.valid(inputState.cursor_clicked_target) && inputState.cursor_click_handled == false)
        {

            auto &clickedTargetNode = registry.get<transform::GameObject>(inputState.cursor_clicked_target);

            // use node's custom click handler if there is one
            if (registry.any_of<ui::UIElementComponent>(inputState.cursor_clicked_target))
            {
                auto &uiElement = registry.get<ui::UIElementComponent>(inputState.cursor_clicked_target);
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

    void handleCursorHoverEvent(InputState &inputState, entt::registry &registry) {
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
        stopHover(registry, current);

    // 3. If new exists → start hover
    if (registry.valid(newHover)) {
        auto &node = registry.get<transform::GameObject>(newHover);
        node.state.isBeingHovered = true;
        if (node.methods.onHover) node.methods.onHover(registry, newHover);
    }

    // 4. Update
    inputState.current_designated_hover_target = newHover;
}


    

    void handleCursorReleasedEvent(input::InputState &inputState, entt::registry &registry)
    {
        if (inputState.cursor_up_handled == false)
        {

            auto *cursorUpTargetNode = registry.try_get<transform::GameObject>(inputState.cursor_up_target);

            // if cursorUpTargetNode is the same as the cursor_prev_dragging_target, get another entity colliding with the cursor from the collision list and use that instead for cursor_up_target
            if (inputState.cursor_up_target == inputState.cursor_prev_dragging_target)
            {
                entt::entity nextCollided{entt::null};
                for (auto &collision : inputState.collision_list)
                {
                    auto *collisionNode = registry.try_get<transform::GameObject>(collision);
                    if (collisionNode == nullptr)
                        continue;
                    if (collisionNode->state.triggerOnReleaseEnabled == false)
                        continue;
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

    void handleCursorDownEvent(entt::registry &registry, input::InputState &inputState)
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

    void processRaylibLeftClick(input::InputState &inputState, entt::registry &registry)
    {
        if (!inputState.L_cursor_queue) return;

        // Cursor click has been queued by raylib
        const auto click = *inputState.L_cursor_queue;
        ProcessLeftMouseButtonPress(registry, inputState, click.x, click.y);
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


    void resetInputStateForProcessing(input::InputState &inputState)
    {
        inputState.frame_buttonpress = false;

        // reset input states

        inputState.keysPressedThisFrame.clear();
        inputState.keysReleasedThisFrame.clear();
        inputState.gamepadButtonsPressedThisFrame.clear();
        inputState.gamepadButtonsReleasedThisFrame.clear();
    }

    void cacheInputTargets(input::InputState &inputState)
    {
        inputState.cursor_prev_dragging_target = inputState.cursor_dragging_target;
        inputState.cursor_prev_released_on_target = inputState.cursor_released_on_target;
        inputState.cursor_prev_clicked_target = inputState.cursor_clicked_target;
        inputState.prev_designated_hover_target = inputState.current_designated_hover_target;
    }

    void handleRawCursor(input::InputState &inputState, entt::registry &registry)
    {
        // set mouse cursor image to be only visible when relevant
        if (inputState.hid.pointer_enabled && !(inputState.hid.mouse_enabled || inputState.hid.touch_enabled) && (inputState.focus_interrupt == false))
        {
            auto &node = registry.get<transform::GameObject>(globals::getCursorEntity());
            node.state.visible = true;
        }
        else
        {
            auto &node = registry.get<transform::GameObject>(globals::getCursorEntity());
            node.state.visible = false;
        }

        // set cursor position
        SetCurrentCursorPosition(registry, inputState);
    }

    void ProcessControllerSnapToObject(input::InputState &inputState, entt::registry &registry)
    {
        if (inputState.hid.controller_enabled)
        {
            if (inputState.cursor_context.layer < inputState.cursor_context.stack.size())
            {
                auto &context = inputState.cursor_context.stack[inputState.cursor_context.layer];

                // valid cursor context exists
                entt::entity snapTarget = entt::null;
                if (registry.valid(context.cursor_focused_target))
                    snapTarget = context.cursor_focused_target;
                SnapToNode(registry, inputState, snapTarget, context.cursor_position);
                // TODO: what is interrupt stack? and context interrupt?
                // self.interrupt.stack = _context.interrupt

                // remove context stack at the index
                inputState.cursor_context.stack.erase(inputState.cursor_context.stack.begin() + inputState.cursor_context.layer);
            }

            // previously dragged target has been released, snap focus to it
            if (registry.valid(inputState.cursor_prev_dragging_target) && !registry.valid(inputState.cursor_dragging_target))
            {
                // TODO: figure out what coyote focus does here
                if (inputState.coyote_focus == false)
                {
                    SnapToNode(registry, inputState, inputState.cursor_prev_dragging_target);
                }
                else
                {
                    inputState.coyote_focus = false;
                }
            }

            // there is a location cursor should snap to
            if (registry.valid(inputState.snap_cursor_to.node))
            {
                // TODO: wha tis this? has to do with interrupt focus?
                //  self.interrupt.focus = self.interrupt.stack
                //  self.interrupt.stack = false

                if (registry.any_of<transform::GameObject>(inputState.snap_cursor_to.node))
                {
                    inputState.cursor_prev_focused_target = inputState.cursor_focused_target;
                    inputState.cursor_focused_target = inputState.snap_cursor_to.node;
                    UpdateCursor(inputState, registry);
                }
                // reset focus state for previous target
                if (inputState.cursor_prev_focused_target != inputState.cursor_focused_target && registry.valid(inputState.cursor_prev_focused_target))
                {
                    auto &prevTarget = registry.get<transform::GameObject>(inputState.cursor_prev_focused_target);
                    prevTarget.state.isBeingFocused = false;
                }
                inputState.snap_cursor_to = {}; // reset target now
            }
        }
    }

    void PropagateButtonAndKeyUpdates(input::InputState &inputState, entt::registry &registry, float dt)
    {
        if (globals::getScreenWipe() == false)
        { // no input handling during screen transitions

            // keyboard keys
            for (auto &[key, value] : inputState.keysPressedThisFrame)
            {
                if (value)
                    KeyboardKeyPressUpdate(registry, inputState, key, dt);
            }
            for (auto &[key, value] : inputState.keysHeldThisFrame)
            {
                if (value)
                    KeyboardKeyHoldUpdate(inputState, key, dt);
            }
            for (auto &[key, value] : inputState.keysReleasedThisFrame)
            {
                if (value)
                    KeyboardKeyReleasedUpdate(inputState, key, dt);
            }

            // gamepad buttons
            for (auto &[button, value] : inputState.gamepadButtonsPressedThisFrame)
            {
                if (value)
                    ButtonPressUpdate(registry, inputState, button, dt);
            }
            for (auto &[button, value] : inputState.gamepadButtonsHeldThisFrame)
            {
                if (value)
                    HeldButtonUpdate(registry, inputState, button, dt);
            }
            for (auto &[button, value] : inputState.gamepadButtonsReleasedThisFrame)
            {
                if (value)
                    ReleasedButtonUpdate(registry, inputState, button, dt);
            }
        }
    }

    void ProcessInputLocks(input::InputState &inputState, entt::registry &registry, float dt)
    {
        inputState.inputLocked = false;
        if (globals::getScreenWipe())
        {
            inputState.activeInputLocks["wipe"] = true;
        }
        else
        {
            inputState.activeInputLocks["wipe"] = false;
        }

        // check all locks, if any are true, set locked to true
        for (auto &[key, value] : inputState.activeInputLocks)
        {
            if (value)
            {
                inputState.inputLocked = true;
            }
        }

        // frame_set, when true, resets "frame" lock after 0.1s
        if (inputState.activeInputLocks.at("frame_lock_reset_next_frame"))
        {
            timer::TimerSystem::timer_after(constants::OVERLAY_MENU_FRAME_LOCK_DURATION, [&inputState](std::optional<float> notImportant)
                                            { inputState.activeInputLocks["frame"] = false; });
        }

        // depending on how long the overlay menu has been active, set the frame lock

        if (!inputState.overlay_menu_active_timer)
            inputState.overlay_menu_active_timer = 0.0f;
        if (registry.valid(globals::getOverlayMenu()))
            inputState.overlay_menu_active_timer = inputState.overlay_menu_active_timer.value() + dt;
        else
            inputState.overlay_menu_active_timer = 0.0f;
    }


    auto SetCurrentCursorPosition(entt::registry &registry, InputState &state) -> void
    {
        if ((state.hid.mouse_enabled || state.hid.touch_enabled) && !state.hid.controller_enabled)
        {
            // TODO: document focus_interrupt, rename
            state.focus_interrupt = false;
            // no focus when using mouse
            if (registry.valid(state.cursor_focused_target) || state.cursor_focused_target != entt::null)
            {
                state.cursor_prev_focused_target = state.cursor_focused_target;
                state.cursor_focused_target = entt::null;
            }
            // set cursor position to mouse position, derive cursor transform
            state.cursor_position = globals::getScaledMousePositionCached();

            auto &transform = registry.get<transform::Transform>(globals::getCursorEntity());
            transform.setActualX(state.cursor_position.x);
            transform.setActualY(state.cursor_position.y);
            transform.setVisualX(state.cursor_position.x);
            transform.setVisualY(state.cursor_position.y);

            // SPDLOG_DEBUG("Cursor position: {}, {}", state.cursor_position.x, state.cursor_position.y);
        }
    }

    auto DeleteInvalidEntitiesFromInputRegistry(InputState &state, entt::registry &registry) -> void
    {
        for (auto &[button, entities] : state.button_registry)
        {
            // Remove invalid nodes from the registry
            entities.erase(
                std::remove_if(entities.begin(), entities.end(), [&](NodeData nodeData)
                               {
                                   return !registry.valid(nodeData.node); // Check if the entity is still valid
                               }),
                entities.end());
        }
    }

    auto AddNodeToInputRegistry(entt::registry &registry, InputState &state, entt::entity node, const GamepadButton button) -> void
    {
        // If the button doesn't have a registry list yet, initialize it
        if (state.button_registry.find(button) == state.button_registry.end())
        {
            state.button_registry[button] = {};
        }

        // Add the new node to the front of the list
        NodeData newNodeData = {.node = node, .menu = registry.valid(globals::getOverlayMenu()) || globals::getIsGamePaused()}; // there is an overlay menu that exists for the game, or the game is currently paused (paused menu). That means this node should be treated as a menu item.
        state.button_registry[button].insert(state.button_registry[button].begin(), newNodeData);
    }

    auto ProcessInputRegistry(InputState &state, entt::registry &registry) -> void
    {
        auto &roomTransform = registry.get<transform::Transform>(globals::getGameWorldContainer());
        Rectangle roomBounds = {0, 0, roomTransform.getActualW(), roomTransform.getActualH()};
        bool overlayMenuActive = globals::getUnderOverlay();

        for (auto &[button, entities] : state.button_registry)
        {
            for (auto &entry : entities)
            {
                // Check if the node is valid, has been clicked, and is in the correct menu or state
                if (registry.valid(entry.node) && entry.node != entt::null)
                {
                    auto &transform = registry.get<transform::Transform>(entry.node);
                    auto &nodeComponent = registry.get<transform::GameObject>(entry.node);

                    if (entry.click && nodeComponent.methods.onClick && entry.menu == overlayMenuActive)
                    {
                        // Check if the node is within the room bounds
                        if (transform.getActualX() > -2 &&
                            transform.getActualX() < roomBounds.width + 2 &&
                            transform.getActualY() > -2 &&
                            transform.getActualY() < roomBounds.height + 2)
                        {

                            // Trigger the node's click behavior
                            nodeComponent.methods.onClick(registry, entry.node);
                        }
                        // Reset the click flag
                        entry.click = false;
                    }
                }
            }
        }
    }

    auto ModifyCurrentCursorContextLayer(entt::registry &registry, InputState &state, int delta) -> void
    {
        auto &context = state.cursor_context;

        AssertThat(context.layer >= 0, Is().EqualTo(true));
        AssertThat(delta, Is().Not().EqualTo(0));
        AssertThat(delta, Is().EqualTo(1).Or().EqualTo(-1).Or().EqualTo(-1000).Or().EqualTo(-2000));

        if (delta == 1)
        {
            // Add a new layer to the context
            CursorContext::CursorLayer newLayer = {
                .cursor_focused_target = state.cursor_focused_target,
                .cursor_position = state.cursor_position,
                .focus_interrupt = state.focus_interrupt,
            };
            if (context.layer < static_cast<int>(context.stack.size()))
            {
                context.stack[context.layer] = newLayer;
            }
            else
            {
                context.stack.push_back(newLayer);
            }
            context.layer++;
        }
        else if (delta == -1)
        {
            // Remove the top layer from the stack
            if (context.layer > 0)
            {
                context.stack.pop_back();
                context.layer--;
            }
        }
        else if (delta == -1000)
        {
            // Remove all but the base layer
            if (!context.stack.empty())
            {
                auto baseLayer = context.stack.front();
                context.stack.clear();
                context.stack.push_back(baseLayer);
            }
            context.layer = 0;
        }
        else if (delta == -2000)
        {
            // Remove all layers
            context.stack.clear();
            context.layer = 0;
        }

        // Navigate focus, defaulting to the top layer
        NavigateFocus(registry, state);
    }

    auto SnapToNode(entt::registry &registry, InputState &state, entt::entity node, const Vector2 &transform) -> void
    {
        // Determine the type of snap target based on whether a node is provided
        if (registry.valid(node) && node != entt::null)
        {
            state.snap_cursor_to = {node, {0, 0}, "node"};
        }
        else
        {
            state.snap_cursor_to = {entt::null, transform, "transform"};
        }
    }

    auto UpdateCursor(InputState &state, entt::registry &registry, std::optional<Vector2> hardSetT) -> void
    {
        if (hardSetT)
        {
            // Update cursor position based on the provided transform
            state.cursor_position.x = hardSetT->x;
            state.cursor_position.y = hardSetT->y;

            auto &transform = registry.get<transform::Transform>(globals::getCursorEntity());
            transform.setActualX(hardSetT->x);
            transform.setActualY(hardSetT->y);
            transform.setVisualX(hardSetT->x);
            transform.setVisualY(hardSetT->y);

            return;
        }
        
        // Update from hardware mouse if mouse is active
        if (state.hid.mouse_enabled)
        {
            Vector2 mousePos = globals::getScaledMousePositionCached();
            state.cursor_position = mousePos;

            auto &transform = registry.get<transform::Transform>(globals::getCursorEntity());
            transform.setActualX(mousePos.x);
            transform.setActualY(mousePos.y);
            transform.setVisualX(mousePos.x);
            transform.setVisualY(mousePos.y);
            return;
        }

        if (state.cursor_focused_target != entt::null && registry.valid(state.cursor_focused_target))
        {
            // Get the focused target's position
            auto &nodeComponent = registry.get<transform::GameObject>(state.cursor_focused_target);
            state.cursor_position = transform::GetCursorOnFocus(&registry, state.cursor_focused_target);

            // Update game-world coordinates
            auto &transform = registry.get<transform::Transform>(globals::getCursorEntity());
            transform.setActualX(state.cursor_position.x);
            transform.setActualY(state.cursor_position.y);
            transform.setVisualX(state.cursor_position.x);
            transform.setVisualY(state.cursor_position.y);
        }
    }

    auto ProcessButtonPress(InputState &state, GamepadButton button, EngineContext* ctx) -> void
    {
        gamepad::process_button_press(state, button, ctx);
    }

    auto ProcessButtonRelease(InputState &state, GamepadButton button, EngineContext* ctx) -> void
    {
        gamepad::process_button_release(state, button, ctx);
    }

    auto ProcessAxisButtons(InputState &state, EngineContext* ctx) -> void
    {
        gamepad::process_axis_buttons(state, ctx);
    }

    auto UpdateGamepadAxisInput(InputState &state, entt::registry &registry, float dt, EngineContext* ctx) -> InputDeviceInputCategory
    {
        return gamepad::update_axis_input(state, registry, dt, ctx);
    }

    auto ButtonPressUpdate(entt::registry &registry, InputState &state, const GamepadButton button, float dt) -> void
    {
        gamepad::button_press_update(registry, state, button, dt);
    }

    auto HeldButtonUpdate(entt::registry &registry, InputState &state, const GamepadButton button, float dt) -> void
    {
        gamepad::held_button_update(registry, state, button, dt);
    }

    // Handles button release updates
    void ReleasedButtonUpdate(entt::registry &registry, InputState &state, const GamepadButton button, float dt)
    {
        gamepad::released_button_update(registry, state, button, dt);
    }

    // **Maps Raylib's KeyboardKey to characters (handles shift & caps)**
    char GetCharacterFromKey(KeyboardKey key, bool caps)
    {
        return keyboard::get_character_from_key(key, caps);
    }

    // **Processes user text input and updates the entity's text field**
    void ProcessTextInput(entt::registry &registry, entt::entity entity, KeyboardKey key, bool shift, bool capsLock)
    {
        keyboard::process_text_input(registry, entity, key, shift, capsLock);
    }

    // **Hooks an entity to listen for text input**
    void HookTextInput(entt::registry &registry, entt::entity entity)
    {
        keyboard::hook_text_input(registry, entity);
    }

    // **Unhooks text input (removes control)**
    void UnhookTextInput(entt::registry &registry, entt::entity entity)
    {
        keyboard::unhook_text_input(registry, entity);
    }

    void KeyboardKeyPressUpdate(entt::registry &registry, InputState &state, KeyboardKey key, float dt)
    {
        keyboard::key_press_update(registry, state, key, dt);
    }

    void KeyboardKeyHoldUpdate(InputState &state, KeyboardKey key, float dt)
    {
        keyboard::key_hold_update(state, key, dt);
    }

    void KeyboardKeyReleasedUpdate(InputState &state, KeyboardKey key, float dt)
    {
        keyboard::key_released_update(state, key, dt);
    }

    // Key Press: Marks the key as pressed and held
    void ProcessKeyboardKeyDown(InputState &state, KeyboardKey key)
    {
        keyboard::process_key_down(state, key);
    }

    // Key Release: Marks the key as released and removes it from held keys
    void ProcessKeyboardKeyRelease(InputState &state, KeyboardKey key)
    {
        keyboard::process_key_release(state, key);
    }

    void MarkEntitiesCollidingWithCursor(entt::registry &registry, InputState &state, const Vector2 &cursor_trans)
    {
        // Clear previous collision data
        state.collision_list.clear();
        state.nodes_at_cursor.clear();

        // Early return if Coyote focus is active
        if (state.coyote_focus)
            return;

        // Handle dragging target
        if (state.cursor_dragging_target != entt::null)
        {
            auto &target = state.cursor_dragging_target;
            auto &node = registry.get<transform::GameObject>(target);
            node.state.isColliding = true; // Mark collision as active
            state.nodes_at_cursor.push_back(target);
            state.collision_list.push_back(target);
        }

        struct CollisionAtCursorFlag
        {
        }; // flag to help clear non-colliding entities

        // Use quadtree broad-phase + precise collision check
        auto entitiesAtCursor = transform::FindAllEntitiesAtPoint(cursor_trans, &camera_manager::Get("world_camera")->cam);

        // remove component from all entities
        registry.view<CollisionAtCursorFlag>().each([&registry](entt::entity e)
                                                    { registry.remove<CollisionAtCursorFlag>(e); });

        // Iterate through the precise collision results
        for (entt::entity e : entitiesAtCursor)
        {
            if (e == globals::getGameWorldContainer() || e == globals::getCursorEntity())
                continue; // skip container

            auto &node = registry.get<transform::GameObject>(e);

            if (!node.state.collisionEnabled)
                continue; // skip disabled collision

            // Mark as colliding
            node.state.isColliding = true;

            registry.emplace_or_replace<CollisionAtCursorFlag>(e); // mark entity as colliding at cursor

            state.nodes_at_cursor.push_back(e);
            state.collision_list.push_back(e);
            
            // if it contains a uiConfig and it's a scrollpane, set it to the active scrollpane
            auto uiConfig = registry.try_get<ui::UIConfig>(e);
            if (uiConfig && uiConfig->uiType == ui::UITypeEnum::SCROLL_PANE)
            {
                state.activeScrollPane = e; // Set the active scrollpane
            }
        }

        // Clear collision state for entities not at cursor
        auto allTransformViewExcludeCursorCollision = registry.view<transform::Transform>(entt::exclude<CollisionAtCursorFlag>);

        for (auto entity : allTransformViewExcludeCursorCollision)
        {
            if (entity == globals::getGameWorldContainer() || entity == globals::getCursorEntity())
                continue; // skip container

            auto node = registry.try_get<transform::GameObject>(entity);
            if (!node || !node->state.collisionEnabled)
                continue; // skip disabled collision

            node->state.isColliding = false;    // Clear collision state
            node->state.isBeingHovered = false; // Clear hover state
        }
    }

    void UpdateCursorHoveringState(entt::registry &registry, InputState &state)
    {
        // Initialize cursor hover state if not already initialized
        if (!state.cursor_hover_transform)
        {
            state.cursor_hover_transform = Vector2{0.0f, 0.0f};
        }
        auto &cursorTransform = registry.get<transform::Transform>(globals::getCursorEntity());

        state.cursor_hover_transform->x = cursorTransform.getActualX();
        state.cursor_hover_transform->y = cursorTransform.getActualY();
        state.cursor_hover_time = main_loop::mainLoop.realtimeTimer;

        // Update previous target and reset current target
        state.cursor_prev_hovering_target = state.cursor_hovering_target;
        state.cursor_hovering_target = entt::null;

        // Handle early return conditions
        if (state.focus_interrupt ||
            (state.inputLocked && (!globals::getIsGamePaused() || globals::getScreenWipe())) ||
            state.activeInputLocks["frame"] ||
            state.coyote_focus)
        {
            state.cursor_hovering_target = globals::getGameWorldContainer();
            return;
        }

        // Handle controller input hover logic

        if (state.hid.controller_enabled && registry.valid(state.cursor_focused_target) && registry.get<transform::GameObject>(state.cursor_focused_target).state.hoverEnabled)
        {
            auto &nodeFocusedTarget = registry.get<transform::GameObject>(state.cursor_focused_target);
            if ((state.hid.dpad_enabled || state.hid.axis_cursor_enabled) && nodeFocusedTarget.state.isColliding)
            {
                state.cursor_hovering_target = state.cursor_focused_target;
            }
            else
            {
                for (auto &entity : state.collision_list)
                {
                    auto &node = registry.get<transform::GameObject>(entity);
                    if (node.state.hoverEnabled)
                    {
                        state.cursor_hovering_target = entity;
                        break;
                    }
                }
            }
        }
        else
        {
            // Handle hover logic for non-controller inputs
            for (auto &entity : state.collision_list)
            {
                auto &node = registry.get<transform::GameObject>(entity);
                if (node.state.hoverEnabled && (!node.state.isBeingDragged || state.hid.touch_enabled))
                {
                    // SPDLOG_DEBUG("Hovering target found: {}", static_cast<int>(entity));
                    state.cursor_hovering_target = entity;
                    break;
                }
            }
        }

        // Fallback to the ROOM if no valid hover target is found
        if (!registry.valid(state.cursor_hovering_target) || (registry.valid(state.cursor_dragging_target) && !state.hid.touch_enabled))
            state.cursor_hovering_target = globals::getGameWorldContainer();

        // If the target has changed, mark hover as not handled
        if (state.cursor_hovering_target != state.cursor_prev_hovering_target)
        {
            state.cursor_hovering_handled = false;
        }
    }

    // save press to be handled by update() function
    void EnqueueLeftMouseButtonPress(InputState &state, float x, float y)
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

    // save press to be handled by update() function
    void EnqueRightMouseButtonPress(InputState &state, float x, float y)
    {
        // Exit early if the frame is locked
        if (state.activeInputLocks["frame"])
        {
            return;
        }

        // Handle right cursor press logic when the game is not paused and an object is highlighted, for example
        if (!globals::getIsGamePaused() && state.cursor_focused_target != entt::null)
        {
        }
    }

    // called by update() function
    void ProcessLeftMouseButtonPress(entt::registry &registry, InputState &state, float x, float y)
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
    void ProcessLeftMouseButtonRelease(entt::registry &registry, InputState &state, float x, float y, EngineContext* ctx)
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

    bool IsNodeFocusable(entt::registry &registry, InputState &state, entt::entity entity)
    {

        // REVIEW: only focus on ui for now (may need to change later)
        if (!registry.any_of<ui::UIConfig>(entity))
        {
            return false;
        }

        auto &node = registry.get<transform::GameObject>(entity);
        auto &transform = registry.get<transform::Transform>(entity);
        auto &uiConfig = registry.get<ui::UIConfig>(entity);

        auto &roomNode = registry.get<transform::GameObject>(globals::getGameWorldContainer());
        auto &roomTransform = registry.get<transform::Transform>(globals::getGameWorldContainer());

        // If the node is outside the room's height bounds, it's not focusable
        if (transform.getActualY() > roomTransform.getActualY() + roomTransform.getActualH() + 3)
        {
            return false;
        }

        // Check the primary conditions for focusability
        auto *uiElementComp = registry.try_get<ui::UIElementComponent>(entity);
        bool finalCondition = (uiElementComp && registry.valid(uiElementComp->uiBox)) || registry.get<transform::GameObject>(entity).state.visible;

        if (registry.valid(entity) && !node.state.isUnderOverlay &&
            ((node.state.hoverEnabled && !registry.valid(state.cursor_dragging_target)) || (state.cursor_dragging_target == entity)) &&
            ((node.ignoresPause && globals::getIsGamePaused()) || (!node.ignoresPause && !globals::getIsGamePaused())) &&
            node.state.visible && finalCondition)
        {

            // If a screen keyboard is active
            // If this node is a key in the active screen keyboard and it’s clickable → allow focus.
            if (state.screen_keyboard)
            {
                auto uiBox = registry.try_get<ui::UIElementComponent>(entity)->uiBox;
                auto &uiConfig = registry.get<ui::UIConfig>(entity);
                if (registry.valid(uiBox) && uiBox == state.screen_keyboard && uiConfig.buttonCallback)
                {
                    // is a key within the on screen keyboard
                    return true;
                }
            }
            else
            {

                // LATER: check the node for focusability with custom game code
                // Your code here

                // Check specific configuration flags

                // Always allow focus no matter what.
                if (uiConfig.force_focus)
                {
                    return true;
                }
                // If it’s a clickable button → allow focus.
                if (uiConfig.buttonCallback)
                {
                    return true;
                }
                if (uiConfig.focusArgs)
                {
                    // type == "none" → explicitly disables focus.
                    // claim_focus_from → another disqualifier.
                    // otherwise it’s focusable.
                    if (uiConfig.focusArgs->type == "none" || uiConfig.focusArgs->claim_focus_from)
                    {
                        return false;
                    }
                    else
                    {
                        return true;
                    }
                }
            }
        }

        // Default return value is false
        return false;
    }

    // focus only works for controller input, when focus interrupt is not enabled, and when the game is not paused, and the input isn't locked.
    void UpdateFocusForRelevantNodes(entt::registry &registry, InputState &state, std::optional<std::string> dir, EngineContext* ctx)
    {
        auto& bus = resolveEventBus(ctx);
        const entt::entity prevFocused = state.cursor_focused_target;
        
        // -----------------------------------------------------------------------------
        // Controller override integration
        // -----------------------------------------------------------------------------
        if (state.controllerNavOverride)
        {
            state.controllerNavOverride = false; // consume flag
            if (registry.valid(state.cursor_focused_target)) {
                auto &focused_node = registry.get<transform::GameObject>(state.cursor_focused_target);
                focused_node.state.isBeingFocused = true;
            }
            return;
        }

        state.cursor_prev_focused_target = state.cursor_focused_target;

        if (!state.hid.controller_enabled || state.focus_interrupt ||
            (state.inputLocked && (!globals::getIsGamePaused() || globals::getScreenWipe())))
        {
            if (registry.valid(state.cursor_focused_target))
            {
                registry.get<transform::GameObject>(state.cursor_focused_target).state.isBeingFocused = false;
            }
            state.cursor_focused_target = entt::null;
            if (state.cursor_focused_target != prevFocused) {
                bus.publish(events::UIElementFocused{state.cursor_focused_target});
            }
            return;
        }

        temporaryListOfFocusedNodes.clear();
        temporaryListOfPotentiallyFocusableNodes.clear();

        if (registry.valid(state.cursor_focused_target))
        {
            auto &node = registry.get<transform::GameObject>(state.cursor_focused_target);
            node.state.isBeingFocused = false;

            if (!IsNodeFocusable(registry, state, state.cursor_focused_target) ||
                !transform::CheckCollisionWithPoint(&registry, state.cursor_focused_target, state.cursor_position) ||
                state.hid.axis_cursor_enabled)
            {
                state.cursor_focused_target = entt::null;
            }
        }

        // Debugging.
        if (dir && dir.value() == "D")
        { // debug downward dir
            SPDLOG_DEBUG("Cursor focused target is {} need to move focus", static_cast<int>(state.cursor_focused_target));
        }

        if (!dir && registry.valid(state.cursor_focused_target))
        {
            auto &node = registry.get<transform::GameObject>(state.cursor_focused_target);
            node.state.focusEnabled = true;
            FocusEntry entry = {.node = state.cursor_focused_target};
            temporaryListOfPotentiallyFocusableNodes.push_back(entry);
        }

        if (!dir)
        {
            for (auto node_entity : state.nodes_at_cursor)
            {
                auto &node = registry.get<transform::GameObject>(node_entity);
                node.state.focusEnabled = false;
                node.state.isBeingFocused = false;

                if (temporaryListOfPotentiallyFocusableNodes.empty() && IsNodeFocusable(registry, state, node_entity))
                {
                    node.state.focusEnabled = true;
                    FocusEntry entry = {.node = node_entity};
                    temporaryListOfPotentiallyFocusableNodes.push_back(entry); // REVIEW: so focusables seems to update frame by frame
                }
            }
        }
        else
        {
            auto view = registry.view<transform::Transform, transform::GameObject>();
            int sizeDebug = view.size_hint();
            for (auto moveable_entity : view)
            {
                auto &node = registry.get<transform::GameObject>(moveable_entity);
                node.state.focusEnabled = false;
                node.state.isBeingFocused = false;

                if (IsNodeFocusable(registry, state, moveable_entity))
                {
                    // SPDLOG_DEBUG("Focusable node found: {}", static_cast<int>(moveable_entity));
                    node.state.focusEnabled = true;
                    FocusEntry entry = {.node = moveable_entity};
                    temporaryListOfPotentiallyFocusableNodes.push_back(entry);
                }
            }
        }

        if (dir && dir.value() == "D")
        { // debug downward dir
            SPDLOG_DEBUG("Temporary list of potentially focusable nodes size: {}", temporaryListOfPotentiallyFocusableNodes.size());
        }

        if (temporaryListOfPotentiallyFocusableNodes.empty() == false)
        {
            if (dir)
            {
                // now handle directional focus for custom game entities
                bool focusedTargetisGameEntityWithFocusing = false; // REVIEW: dummmy value, update
                if ((dir == "L" || dir == "R") && registry.valid(state.cursor_focused_target) && focusedTargetisGameEntityWithFocusing)
                {
                    auto &focused_node = registry.get<transform::GameObject>(state.cursor_focused_target);

                    // check if the node is a specific type of entity (ie a card), that it is in the hand area, and the hand area exists
                    // if so, update the focused node's index by -1 or +1 based on the direction, loop to zero or the end if necessary
                    // if the new rank is different from the current index, update the focus list with the node with the new index

                    // LATER: custom focus manipulation logic here for game entities
                }
                else
                {
                    auto &roomTransform = registry.get<transform::Transform>(globals::getGameWorldContainer());
                    auto &cursorTransform = registry.get<transform::Transform>(globals::getCursorEntity());
                    state.focus_cursor_pos = {cursorTransform.getActualX() - roomTransform.getActualX(), cursorTransform.getActualY() - roomTransform.getActualY()};

                    // If a node is already focused, use its center point as the reference position.
                    // If the node has a redirect_focus_to target, use that instead.
                    if (registry.valid(state.cursor_focused_target))
                    {
                        auto &node = registry.get<transform::GameObject>(state.cursor_focused_target);
                        auto &uiConfig = registry.get<ui::UIConfig>(state.cursor_focused_target);
                        auto funnelEntity = (uiConfig.focusArgs && uiConfig.focusArgs->redirect_focus_to) ? uiConfig.focusArgs->redirect_focus_to.value() : state.cursor_focused_target;

                        auto &funnelTransform = registry.get<transform::Transform>(funnelEntity);

                        state.focus_cursor_pos = {
                            funnelTransform.getActualX() + constants::CENTER_POSITION_MULTIPLIER * funnelTransform.getActualW(),
                            funnelTransform.getActualY() + constants::CENTER_POSITION_MULTIPLIER * funnelTransform.getActualH()};
                    }

                    // If there’s no currently focused target but a valid hovering target, use its focus position.
                    else if (registry.valid(state.current_designated_hover_target))
                    {
                        auto &hover_node = registry.get<transform::GameObject>(state.current_designated_hover_target);
                        if (hover_node.state.focusEnabled)
                        {
                            auto hover_pos = transform::GetCursorOnFocus(&registry, state.current_designated_hover_target); // Function to determine hover position
                            auto &roomTransform = registry.get<transform::Transform>(globals::getGameWorldContainer());
                            state.focus_cursor_pos = {
                                (hover_pos.x - roomTransform.getActualX()),
                                (hover_pos.y - roomTransform.getActualY())};
                        }
                    }

                    // Iterates through all focusable nodes and checks if they’re valid candidates based on direction.
                    // Computes the vector from the cursor position to each node.
                    for (auto entity : temporaryListOfPotentiallyFocusableNodes)
                    { // REVIEW: focusables are checked, then added to focus_list for processing
                        if (entity.node == state.current_designated_hover_target || entity.node == state.cursor_focused_target)
                            continue;

                        auto &node = registry.get<transform::GameObject>(entity.node);
                        auto &uiConfig = registry.get<ui::UIConfig>(entity.node);

                        auto &target_node = (uiConfig.focusArgs && uiConfig.focusArgs->redirect_focus_to)
                                                ? uiConfig.focusArgs->redirect_focus_to.value()
                                                : entity.node;
                        auto &targetNodeTransform = registry.get<transform::Transform>(target_node);
                        auto &targetNodeRole = registry.get<transform::InheritedProperties>(target_node);

                        Vector2 targetNodePos = {
                            (targetNodeTransform.getActualX()),
                            (targetNodeTransform.getActualY())};

                        // debug
                        if (targetNodePos.y < 0)
                        {
                            SPDLOG_DEBUG("Target node position is negative: ({}, {})", targetNodePos.x, targetNodePos.y);
                        }

                        // focus_vec is the vector pointing from the cursor to the center of the node
                        Vector2 focus_vec = {
                            targetNodePos.x + constants::CENTER_POSITION_MULTIPLIER * targetNodeTransform.getActualW() - state.focus_cursor_pos->x,
                            targetNodePos.y + constants::CENTER_POSITION_MULTIPLIER * targetNodeTransform.getActualH() - state.focus_cursor_pos->y};

                        if (dir && dir.value() == "D" || dir.value() == "U")
                        { // debug downward dir
                            SPDLOG_DEBUG("Focusable node found: {}", static_cast<int>(entity.node));
                            SPDLOG_DEBUG(" -Supplied direction: {}", dir.value());
                            SPDLOG_DEBUG(" -Focus vector: ({}, {})", focus_vec.x, focus_vec.y);
                            SPDLOG_DEBUG(" -Target node transform: ({}, {})", targetNodePos.x, targetNodePos.y);
                            SPDLOG_DEBUG(" -Current focus cursor position: ({}, {})", state.focus_cursor_pos->x, state.focus_cursor_pos->y);
                        }

                        // Determines if the node is within the valid direction using position checks

                        // Checks if the node has a nav type (either "wide" or "tall")
                        bool eligible = false;
                        if (uiConfig.focusArgs && uiConfig.focusArgs->nav)
                        {
                            if (uiConfig.focusArgs->nav == "wide")
                            {
                                if (focus_vec.y > constants::FOCUS_VECTOR_THRESHOLD && dir == "D")
                                    eligible = true;
                                else if (focus_vec.y < -constants::FOCUS_VECTOR_THRESHOLD && dir == "U")
                                    eligible = true;
                                else if (std::abs(focus_vec.y) < targetNodeTransform.getActualH() / 2)
                                    eligible = true;
                            }
                            else if (uiConfig.focusArgs->nav == "tall")
                            {
                                if (focus_vec.x > constants::FOCUS_VECTOR_THRESHOLD && dir == "R")
                                    eligible = true;
                                else if (focus_vec.x < -constants::FOCUS_VECTOR_THRESHOLD && dir == "L")
                                    eligible = true;
                                else if (std::abs(focus_vec.x) < targetNodeTransform.getActualW() / 2)
                                    eligible = true;
                            }
                        }
                        // If no nav type exists, determine the dominant movement direction:
                        else if (std::abs(focus_vec.x) > std::abs(focus_vec.y))
                        {
                            if (focus_vec.x > 0 && dir == "R")
                                eligible = true;
                            else if (focus_vec.x < 0 && dir == "L")
                                eligible = true;
                        }
                        else
                        {
                            if (focus_vec.y > 0 && dir == "D")
                                eligible = true;
                            else if (focus_vec.y < 0 && dir == "U")
                                eligible = true;
                        }

                        if (eligible)
                        {
                            SPDLOG_DEBUG("Eligible node found: {}", static_cast<int>(entity.node));
                            temporaryListOfFocusedNodes.push_back({.node = entity.node, .dist = std::abs(focus_vec.x) + std::abs(focus_vec.y)});
                        }

                        // FIXME: debugging by commenting this out
                        //  if (temporaryListOfFocusedNodes.empty()) {
                        //      if (registry.valid(state.cursor_focused_target)) {
                        //          auto& focused_node = registry.get<transform::GameObject>(state.cursor_focused_target);
                        //          focused_node.state.isBeingFocused = true;
                        //      }
                        //      return;
                        //  }
                    } // end for loop

                    if (temporaryListOfFocusedNodes.empty())
                    {
                        if (registry.valid(state.cursor_focused_target))
                        {
                            auto &focused_node = registry.get<transform::GameObject>(state.cursor_focused_target);
                            focused_node.state.isBeingFocused = true;
                        }
                        return;
                    }

                    std::sort(temporaryListOfFocusedNodes.begin(), temporaryListOfFocusedNodes.end(),
                              [](const auto &a, const auto &b)
                              {
                                  return a.dist < b.dist;
                              });
                }
            }
            // no direction control supplied
            else
            {
                if (registry.valid(state.cursor_focused_target))
                {
                    temporaryListOfFocusedNodes.push_back({.node = state.cursor_focused_target, .dist = 0});
                }
                // get fousable that collids
                else
                {
                    temporaryListOfFocusedNodes.push_back({.node = temporaryListOfPotentiallyFocusableNodes.front().node, .dist = 0});
                }
            }
        }

        // Assigns the closest valid node as the focused target.
        if (!temporaryListOfFocusedNodes.empty())
        {
            auto &first_node = registry.get<transform::GameObject>(temporaryListOfFocusedNodes[0].node);
            auto &first_node_ui_config = registry.get<ui::UIConfig>(temporaryListOfFocusedNodes[0].node);
            state.cursor_focused_target = (first_node_ui_config.focusArgs && first_node_ui_config.focusArgs->claim_focus_from)
                                              ? first_node_ui_config.focusArgs->claim_focus_from.value()
                                              : temporaryListOfFocusedNodes[0].node;

            if (state.cursor_focused_target != state.cursor_prev_focused_target)
            {
                globals::getVibration() += constants::FOCUS_VIBRATION_INTENSITY;
            }
        }
        else
        {
            state.cursor_focused_target = entt::null;
        }

        if (registry.valid(state.cursor_focused_target))
        {
            auto &focused_node = registry.get<transform::GameObject>(state.cursor_focused_target);
            focused_node.state.isBeingFocused = true;
        }

        if (state.cursor_focused_target != prevFocused) {
            bus.publish(events::UIElementFocused{state.cursor_focused_target});
        }
    }

    bool CaptureFocusedInput(entt::registry &registry, InputState &state, const std::string inputType, GamepadButton button, float dt)
    {
        return false; // temporarily disable
        bool ret = false;
        entt::entity focused = state.cursor_focused_target;
        bool externButton = false; // not d-pad
        state.no_holdcap = false;

        // REVIEW: there can be transforms which are in-game areas (think card areas in a card game)
        bool focusedObjectHasEncompassingArea = false;       // REVIEW: dummy value, would be implementation specific
        bool focusedObjectCanBeHighlightedInItsArea = false; // REVIEW: dummy value, would be implementation specific

        // Normally, players must fully press and release "A" before pressing left or right.
        // With this code, even if they press left or right right after pressing "A", the switch still happens.
        // LATER: not entirely sure I understand this. Need to review
        if (inputType == "press" && (button == GAMEPAD_BUTTON_LEFT_FACE_LEFT || button == GAMEPAD_BUTTON_LEFT_FACE_RIGHT) &&
            registry.valid(focused) && registry.valid(state.cursor_dragging_target) &&
            state.gamepadHeldButtonDurations.at(xboxAButton) != 0 /** A for xbox */ > 0 && state.gamepadHeldButtonDurations[xboxAButton] < constants::BUTTON_HOLD_COYOTE_TIME &&
            focusedObjectHasEncompassingArea && focusedObjectCanBeHighlightedInItsArea)
        {
            ProcessLeftMouseButtonRelease(registry, state);                      // Release cursor
            NavigateFocus(registry, state, (button == xboxXButton) ? "L" : "R"); // Move focus
            state.gamepadHeldButtonDurations.erase(xboxAButton);                 // Reset hold time
            state.coyote_focus = true;
            ret = true;
        }

        // If focused entity is being dragged and a D-pad button is pressed
        else if (inputType == "press" && registry.valid(focused) && focused == state.cursor_dragging_target)
        {
            auto &focusedNode = registry.get<transform::GameObject>(focused);
            focusedNode.state.isBeingDragged = false; // disable dragging temporarily

            // Moving card rank within a hand area
            if (button == dpadLeft /**  && focused.rank > 1 */)
            {
                // REVIEW: swap the position of a node with the one to the left
                // eg. swapCardRanks(focusedNode, focusedNode.rank - 1);
            }
            else if (button == dpadRight /** && focusedNode.rank < focusedNode.area.cards.size() */)
            {
                // REVIEW: swap the position of a node with the one to the right
                // eg. swapCardRanks(focusedNode, focusedNode.rank + 1);
            }

            // re-align entities in the area if necessary
            // eg. realignCards();
            UpdateCursor(state, registry); // Update cursor
            focusedNode.state.isBeingDragged = true;
            ret = true;
        }

        // Handling overlay menu navigation

        // overlay menu is active and not in keyboard mode
        if (state.overlay_menu_active && !state.screen_keyboard && inputType == "press")
        {
            if (button == GAMEPAD_BUTTON_LEFT_TRIGGER_1 || button == GAMEPAD_BUTTON_RIGHT_TRIGGER_1)
            {
                focused = ui::box::GetUIEByID(registry, globals::getOverlayMenu(), "tab_shoulders").value_or(entt::null);
                externButton = true;
            }
        }

        // Handling ui elements with focusArgs (cycle, tab, slider)
        if (registry.valid(focused))
        {
            auto &focusedNode = registry.get<transform::GameObject>(focused);
            auto &focusedNodeUIConfig = registry.get<ui::UIConfig>(focused);
            auto childrenIterator = focusedNode.orderedChildren.begin();
            if (focusedNodeUIConfig.focusArgs)
            {

                // REVIEW: check after doing ui whether 0 and 2 are correct index values
                if (focusedNodeUIConfig.focusArgs->type.value() == "cycle" && inputType == "press")
                {
                    if ((externButton && button == GAMEPAD_BUTTON_LEFT_TRIGGER_1) || (!externButton && button == dpadLeft))
                    {
                        auto &childNode = registry.get<transform::GameObject>(*childrenIterator);
                        // click(childrenIterator->second); //Click left option
                        ui::element::Click(registry, *childrenIterator);
                        // childNode.methods.onClick(registry, childrenIterator->second);
                        ret = true;
                    }
                    if ((externButton && button == GAMEPAD_BUTTON_RIGHT_TRIGGER_1) || (!externButton && button == dpadRight))
                    {
                        childrenIterator++;
                        childrenIterator++; // need to access third element
                        auto &childNode = registry.get<transform::GameObject>(*childrenIterator);
                        // click(childrenIterator->second); // Click right option
                        ui::element::Click(registry, *childrenIterator);
                        // childNode.methods.onClick(registry, childrenIterator->second);
                        ret = true;
                    }
                }
                if (focusedNodeUIConfig.focusArgs->type.value() == "tab" && inputType == "press")
                {
                    // Retrieve all possible tab choices within the same UI group
                    auto firstChild = focusedNode.orderedChildren.begin();
                    auto firstChildofFirstChild = registry.get<transform::GameObject>(*firstChild).children.begin();
                    auto &firstChildofFirstChildUIConfig = registry.get<ui::UIConfig>(firstChildofFirstChild->second);
                    auto protoChoices = ui::box::GetGroup(registry, entt::null, firstChildofFirstChildUIConfig.group.value());
                    std::vector<entt::entity> choices;
                    // Filter only valid tab choices
                    for (auto choiceEntity : protoChoices)
                    {
                        auto &choiceNode = registry.get<transform::GameObject>(choiceEntity);
                        auto &choiceNodeUIConfig = registry.get<ui::UIConfig>(choiceEntity);
                        if (choiceNodeUIConfig.choice && choiceNodeUIConfig.buttonCallback)
                        {
                            choices.push_back(choiceEntity);
                        }
                    }

                    // Find the currently selected tab and determine movement direction
                    for (size_t i = 0; i < choices.size(); ++i)
                    {
                        auto &choiceNode = registry.get<transform::GameObject>(choices[i]);
                        auto &choiceNodeUIConfig = registry.get<ui::UIConfig>(choices[i]);

                        if (choiceNodeUIConfig.chosen)
                        { // Found selected tab
                            size_t nextIndex;

                            if ((externButton && button == leftShoulderButton) || (!externButton && button == dpadLeft))
                            {
                                // Move left (previous tab)
                                nextIndex = (i != 0) ? (i - 1) : (choices.size() - 1);
                                if (choiceNodeUIConfig.focusArgs->no_loop && nextIndex > i)
                                {
                                    return false; // No looping, do nothing
                                }
                            }
                            else if ((externButton && button == rightShoulderButton) || (!externButton && button == dpadRight))
                            {
                                // Move right (next tab)
                                nextIndex = (i != choices.size() - 1) ? (i + 1) : 0;
                                if (choiceNodeUIConfig.focusArgs->no_loop && nextIndex < i)
                                {
                                    return false; // No looping, do nothing
                                }
                            }
                            else
                            {
                                return false; // No valid input detected
                            }

                            // Click new tab & update cursor
                            auto &choiceNode = registry.get<transform::GameObject>(choices[nextIndex]);
                            // click(choices[nextIndex]); // Simulate clicking the new tab
                            ui::element::Click(registry, choices[nextIndex]);
                            // choiceNode.methods.onClick(registry, choices[nextIndex]);
                            SnapToNode(registry, state, choices[nextIndex]); // Snap cursor to new tab
                            UpdateCursor(state, registry);                   // Refresh cursor position
                            return true;
                        }
                    }
                }

                else if (focusedNodeUIConfig.focusArgs->type.value() == "slider")
                {
                    if (button == dpadLeft)
                    {
                        state.no_holdcap = true;
                        if (inputType == "hold" && state.gamepadHeldButtonDurations[button] > constants::SLIDER_HOLD_ACTIVATION_TIME)
                        {
                            // TODO: change
                            ui::util::sliderDiscrete(registry, focusedNode.orderedChildren[0], -dt * state.gamepadHeldButtonDurations[button] * constants::SLIDER_CONTINUOUS_MULTIPLIER);
                        }
                        if (inputType == "press")
                        {
                            ui::util::sliderDiscrete(registry, focusedNode.orderedChildren[0], -constants::SLIDER_DISCRETE_STEP);
                        }
                        ret = true;
                    }
                    else if (button == dpadRight)
                    {
                        state.no_holdcap = true;
                        if (inputType == "hold" && state.gamepadHeldButtonDurations[button] > constants::SLIDER_HOLD_ACTIVATION_TIME)
                        {
                            ui::util::sliderDiscrete(registry, focusedNode.orderedChildren[0], dt * state.gamepadHeldButtonDurations[button] * constants::SLIDER_CONTINUOUS_MULTIPLIER);
                        }
                        if (inputType == "press")
                        {
                            ui::util::sliderDiscrete(registry, focusedNode.orderedChildren[0], constants::SLIDER_DISCRETE_STEP);
                        }
                        ret = true;
                    }
                }
            }
        }

        // Apply vibration if input was handled
        if (ret)
        {
            globals::getVibration() += constants::ACTION_VIBRATION_INTENSITY;
        }
        return ret;
    }

    void NavigateFocus(entt::registry &registry, InputState &state, std::optional<std::string> dir)
    {
        // Step 1: Update focus based on direction (or nearest focusable entity if no direction)
        UpdateFocusForRelevantNodes(registry, state, dir);

        // Step 2: Update cursor position to match the newly focused entity
        UpdateCursor(state, registry);
    }
    
    // ========================================
    // Action System - Wrapper Functions
    // ========================================
    // These functions delegate to the input::actions module

    auto RebuildActionIndex(InputState &s) -> void {
        actions::rebuild_index(s);
    }

    auto DecayActions(InputState &s) -> void {
        actions::decay(s);
    }

    auto DispatchRaw(InputState &s, InputDeviceInputCategory dev, int code, bool down, float value) -> void {
        actions::dispatch_raw(s, dev, code, down, value);
    }

    auto TickActionHolds(InputState &s, float dt) -> void {
        actions::tick_holds(s, dt);
    }

    // Public C++ API - wrappers for backward compatibility
    auto bind_action(InputState &s, const std::string &action, const ActionBinding &b) -> void {
        actions::bind(s, action, b);
    }

    auto clear_action(InputState &s, const std::string &action) -> void {
        actions::clear(s, action);
    }

    auto set_context(InputState &s, const std::string &ctx) -> void {
        actions::set_context(s, ctx);
    }

    auto action_pressed(InputState &s, const std::string &a) -> bool {
        return actions::pressed(s, a);
    }

    auto action_released(InputState &s, const std::string &a) -> bool {
        return actions::released(s, a);
    }

    auto action_down(InputState &s, const std::string &a) -> bool {
        return actions::down(s, a);
    }

    auto action_value(InputState &s, const std::string &a) -> float {
        return actions::value(s, a);
    }

    auto start_rebind(InputState &s, const std::string &action, std::function<void(bool, ActionBinding)> cb) -> void {
        actions::start_rebind(s, action, std::move(cb));
    }

    static auto to_device(const std::string &s) -> InputDeviceInputCategory {
        return actions::to_device(s);
    }

    static auto to_trigger(const std::string &s) -> ActionTrigger {
        return actions::to_trigger(s);
    }


    auto exposeToLua(sol::state &lua, EngineContext* ctx) -> void
    {
        // Delegate to the dedicated Lua bindings module
        lua_bindings::expose_to_lua(lua, ctx);
    }

}
