#include "input_functions.hpp"

#include "raylib.h"

#include "entt/entt.hpp"

#include "spdlog/spdlog.h"
#include "systems/camera/camera_manager.hpp"
#include "systems/collision/broad_phase.hpp"
#include "util/common_headers.hpp"

#include "core/globals.hpp"

#include "input.hpp"
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
    // Hide/show cursor only when a window exists (tests may run headless).
    static void SafeHideCursor()
    {
        if (IsWindowReady())
            HideCursor();
    }

    static void SafeShowCursor()
    {
        if (IsWindowReady())
            ShowCursor();
    }

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
        // Process all characters pressed this frame
        int key = GetCharPressed();
        SPDLOG_DEBUG("Handling text input, char pressed: {}", key);
        while (key > 0) {
            // Optionally, filter which characters you allow
            // Here we limit to printable ASCII 32..126
            if ((key >= 32) && (key <= 126) && input.text.length() < input.maxLength) {
                char c = static_cast<char>(key);

                if (input.allCaps) {
                    c = toupper(c);
                }

                // Insert at cursor position
                input.text.insert(input.cursorPos, 1, c);
                input.cursorPos++;
            }

            key = GetCharPressed(); // Get next character in queue
        }

        // Handle Backspace
        if (IsKeyPressed(KEY_BACKSPACE) && input.cursorPos > 0) {
            input.text.erase(input.cursorPos - 1, 1);
            input.cursorPos--;
        }

        // Move cursor left/right
        if (IsKeyPressed(KEY_LEFT) && input.cursorPos > 0) {
            input.cursorPos--;
        }
        if (IsKeyPressed(KEY_RIGHT) && input.cursorPos < input.text.length()) {
            input.cursorPos++;
        }

        // Handle Enter
        if (IsKeyPressed(KEY_ENTER) && input.callback) {
            input.callback();
        }
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
                ReconfigureInputDeviceInfo(inputState, InputDeviceInputCategory::KEYBOARD);
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
                ReconfigureInputDeviceInfo(inputState, InputDeviceInputCategory::KEYBOARD);
                ProcessKeyboardKeyRelease(inputState, (KeyboardKey)key);
                keyDownLastFrame[key] = false;
            }
        }

        // poll touch? LATER: implement touch
        if (GetTouchPointCount() > 0)
        {
            ReconfigureInputDeviceInfo(inputState, InputDeviceInputCategory::TOUCH);
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
            ReconfigureInputDeviceInfo(inputState, InputDeviceInputCategory::MOUSE);
            Vector2 mousePos = globals::getScaledMousePositionCached();
            EnqueueLeftMouseButtonPress(inputState, mousePos.x, mousePos.y);
            bus.publish(events::MouseClicked{mousePos, MOUSE_LEFT_BUTTON});
        }
        if (mouseDetectDownFirstFrameRight)
        {
            ReconfigureInputDeviceInfo(inputState, InputDeviceInputCategory::MOUSE);
            Vector2 mousePos = globals::getScaledMousePositionCached();
            // TODO: right mouse handling isn't really configured, need to add
            EnqueRightMouseButtonPress(inputState, mousePos.x, mousePos.y);
            bus.publish(events::MouseClicked{mousePos, MOUSE_RIGHT_BUTTON});
        }
        if (mosueLeftDownCurrentFrame == false && mouseLeftDownLastFrame == true)
        { // release only for left button
            ReconfigureInputDeviceInfo(inputState, InputDeviceInputCategory::MOUSE);
            Vector2 mousePos = globals::getScaledMousePositionCached();
            ProcessLeftMouseButtonRelease(registry, inputState, mousePos.x, mousePos.y, ctx);
        }

        mouseLeftDownLastFrame = mosueLeftDownCurrentFrame;
        mouseRightDownLastFrame = mouseRightDownCurrentFrame;
        // no middle mouse

        // poll mouse movement
        if (GetMouseDelta().x != 0 || GetMouseDelta().y != 0)
        {
            ReconfigureInputDeviceInfo(inputState, InputDeviceInputCategory::MOUSE);
        }
        
        // poll mouse wheel
        if (GetMouseWheelMove() != 0)
        {
            ReconfigureInputDeviceInfo(inputState, InputDeviceInputCategory::MOUSE);
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
                    SetCurrentGamepad(inputState, GetGamepadName(0), 0);
                    ReconfigureInputDeviceInfo(inputState, InputDeviceInputCategory::GAMEPAD_BUTTON, (GamepadButton)button);
                    ProcessButtonPress(inputState, (GamepadButton)button, ctx);
                }
                if (gamepadButtonDetectUpFirstFrame)
                {
                    SetCurrentGamepad(inputState, GetGamepadName(0), 0);
                    ReconfigureInputDeviceInfo(inputState, InputDeviceInputCategory::GAMEPAD_BUTTON, (GamepadButton)button);
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
                SetCurrentGamepad(inputState, GetGamepadName(0), 0);
                
                // SPDLOG_DEBUG("Axis movement detected! Lx={} Ly={}", axisLeftX, axisLeftY);
                // SPDLOG_INFO("Axes: {}", GetGamepadAxisCount(0));

                
                ReconfigureInputDeviceInfo(inputState, InputDeviceInputCategory::GAMEPAD_AXIS);
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
            ReconfigureInputDeviceInfo(inputState, finalCategory);
        }

        // auto inputCategory = UpdateGamepadAxisInput(inputState, registry, dt, ctx);
        auto &transform = registry.get<transform::Transform>(globals::getCursorEntity());

        handleRawInput(registry, inputState, dt, ctx);

        // ReconfigureInputDeviceInfo(inputState, finalCategory);

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

    // The universal controller for what type of HID Device the player is using to interact with the game. The game should be able to handle switching to any viable HID at any time
    // axis_cursor, axis, button, mouse, touch
    auto ReconfigureInputDeviceInfo(InputState &state, InputDeviceInputCategory category, const GamepadButton button) -> void
    {
        if (category == InputDeviceInputCategory::NONE || category == state.hid.last_type)
            return;


        const bool isControllerInput =
            category == InputDeviceInputCategory::GAMEPAD_AXIS ||
            category == InputDeviceInputCategory::GAMEPAD_BUTTON ||
            category == InputDeviceInputCategory::GAMEPAD_AXIS_CURSOR;

        const bool isMouseKeyboardTouch =
            category == InputDeviceInputCategory::KEYBOARD ||
            category == InputDeviceInputCategory::MOUSE ||
            category == InputDeviceInputCategory::TOUCH;

        //----------------------------------------------------------
        // CONTROLLER INPUT: Enable controller mode persistently
        //----------------------------------------------------------
        if (isControllerInput)
        {
            if (!state.hid.controller_enabled)
            {
                SPDLOG_DEBUG("Switching to controller input: {}", magic_enum::enum_name(category));
                SafeHideCursor();
            }

            state.hid.controller_enabled = true;
            state.hid.last_type = category;
            state.hid.dpad_enabled = true;
            state.hid.pointer_enabled = (category == InputDeviceInputCategory::GAMEPAD_AXIS_CURSOR);
            state.hid.axis_cursor_enabled = (category == InputDeviceInputCategory::GAMEPAD_AXIS_CURSOR);
            state.hid.mouse_enabled = false;
            state.hid.touch_enabled = false;
            return;
        }

        //----------------------------------------------------------
        // MOUSE / KEYBOARD / TOUCH INPUT: Disable controller mode
        //----------------------------------------------------------
        if (isMouseKeyboardTouch && state.hid.controller_enabled)
        {
            SPDLOG_DEBUG("Switching away from controller input to {}", magic_enum::enum_name(category));

            state.hid.controller_enabled = false;
            state.hid.last_type = category;
            state.hid.dpad_enabled = (category == InputDeviceInputCategory::KEYBOARD);
            state.hid.pointer_enabled = (category == InputDeviceInputCategory::MOUSE || category == InputDeviceInputCategory::TOUCH);
            state.hid.mouse_enabled = (category == InputDeviceInputCategory::MOUSE);
            state.hid.touch_enabled = (category == InputDeviceInputCategory::TOUCH);
            state.hid.axis_cursor_enabled = false;

            // clear controller metadata
            state.gamepad.console.clear();
            state.gamepad.object.clear();
            state.gamepad.mapping.clear();
            state.gamepad.name.clear();

            // restore cursor
            SafeShowCursor();

            // unfocus UI
            auto& reg = resolveRegistry();
            auto view = reg.view<transform::GameObject, ui::UIConfig>();
            for (auto entity : view)
                view.get<transform::GameObject>(entity).state.isBeingFocused = false;
        }
    }


    auto UpdateUISprites(const std::string &console_type) -> void
    {
        // LATER: implement later if needed
        //  Update sprites based on console type (e.g., load textures, modify UI)
        if (console_type == "Nintendo")
        {
            // Set Nintendo-specific icons
        }
        else if (console_type == "PlayStation")
        {
            // Set PlayStation-specific icons
        }
        else
        {
            // Default to Xbox
        }
    }

    std::string DeduceConsoleFromGamepad(int gamepadIndex)
    {
        if (!IsGamepadAvailable(gamepadIndex))
            return "No Gamepad";

        std::string gamepadName = GetGamepadName(gamepadIndex);

        // Gamepad name patterns for different consoles
        std::map<std::string, std::string> gamepadPatterns = {
            {"PS", "PlayStation"},
            {"Sony", "PlayStation"},
            {"DualShock", "PlayStation"},
            {"DualSense", "PlayStation"},
            {"Wireless Controller", "PlayStation"}, // DualSense controller
            {"Nintendo", "Nintendo"},
            {"Switch", "Nintendo"},
            {"Joy-Con", "Nintendo"},
            {"Pro Controller", "Nintendo"},
            {"Xbox", "Xbox"},
            {"XInput", "Xbox"},
            {"Elite", "Xbox"},
            {"360", "Xbox"},
        };

        for (const auto &[pattern, console] : gamepadPatterns)
        {
            if (gamepadName.find(pattern) != std::string::npos)
            {
                return console;
            }
        }

        return "Unknown Console"; // Default case
    }

    auto SetCurrentGamepad(InputState &state, const std::string &gamepad_object, int gamepadID) -> void
    {
        if (state.gamepad.object != gamepad_object)
        {
            state.gamepad.object = gamepad_object;

            // Get mapping string and name
            // state.gamepad.mapping = getGamepadMappingString(gamepad_object);
            state.gamepad.name = GetGamepadName(gamepadID);

            // Determine the console type
            std::string console_type = DeduceConsoleFromGamepad(gamepadID);
            if (state.gamepad.console != console_type)
            {
                state.gamepad.console = console_type;

                // Update UI elements based on console type (e.g., sprites)
                UpdateUISprites(state.gamepad.console);
            }
            
            state.gamepad.id = gamepadID;

        }
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
        // SPDLOG_DEBUG("Button press detected: {}", magic_enum::enum_name(button));
        state.gamepadButtonsPressedThisFrame[button] = true;
        state.gamepadButtonsHeldThisFrame[button] = true;
        input::DispatchRaw(state, InputDeviceInputCategory::GAMEPAD_BUTTON, (int)button, true);
        resolveEventBus(ctx).publish(events::GamepadButtonPressed{state.gamepad.id, button});
    }

    auto ProcessButtonRelease(InputState &state, GamepadButton button, EngineContext* ctx) -> void
    {
        state.gamepadButtonsHeldThisFrame[button] = false;
        state.gamepadButtonsReleasedThisFrame[button] = true;
        input::DispatchRaw(state, InputDeviceInputCategory::GAMEPAD_BUTTON, (int)button, false);
        resolveEventBus(ctx).publish(events::GamepadButtonReleased{state.gamepad.id, button});
    }

    auto ProcessAxisButtons(InputState &state, EngineContext* ctx) -> void
    {
        for (auto &[key, axisButton] : state.axis_buttons)
        {
            // Trigger a button release if the button is no longer active or has changed
            if (axisButton.previous && (!axisButton.current || axisButton.previous != axisButton.current))
            {
                ProcessButtonRelease(state, axisButton.previous.value(), ctx);
            }

            // Trigger a button press if a new button becomes active
            if (axisButton.current && axisButton.previous != axisButton.current)
            {
                ProcessButtonPress(state, axisButton.current.value(), ctx);
            }
        }
    }

    auto UpdateGamepadAxisInput(InputState &state, entt::registry &registry, float dt, EngineContext* ctx) -> InputDeviceInputCategory
    {
        InputDeviceInputCategory axisInterpretation = InputDeviceInputCategory::NONE;

        // // hack to ensure mouse state isn't written over
        // if (state.hid.controller_enabled == false)
        //     axisInterpretation = InputDeviceInputCategory::MOUSE;

        // Reset axis button states
        for (auto &[key, axisButton] : state.axis_buttons)
        {
            axisButton.previous = axisButton.current;
            axisButton.current.reset();
        }

        if (state.hid.controller_enabled)
        {
            //---------------------------------------------------------------
            //                     Left Thumbstick
            //---------------------------------------------------------------
            AssertThat(IsGamepadAvailable(state.gamepad.id), Is().EqualTo(true));

            float l_stick_x = GetGamepadAxisMovement(state.gamepad.id, GAMEPAD_AXIS_LEFT_X);
            float l_stick_y = GetGamepadAxisMovement(state.gamepad.id, GAMEPAD_AXIS_LEFT_Y);

            // If something is being dragged, treat the left stick as cursor input
            if (registry.valid(state.cursor_dragging_target) && (std::abs(l_stick_x) + std::abs(l_stick_y)) > constants::LEFT_STICK_DEADZONE)
            {
                axisInterpretation = InputDeviceInputCategory::GAMEPAD_AXIS_CURSOR; // Cursor movement detected

                // Deadzone handling for left stick
                if (std::abs(l_stick_x) < constants::LEFT_STICK_DEADZONE)
                    l_stick_x = 0;
                if (std::abs(l_stick_y) < constants::LEFT_STICK_DEADZONE)
                    l_stick_y = 0;
                l_stick_x += (l_stick_x > 0 ? -constants::LEFT_STICK_DEADZONE : 0.0f) + (l_stick_x < 0 ? constants::LEFT_STICK_DEADZONE : 0.0f);
                l_stick_y += (l_stick_y > 0 ? -constants::LEFT_STICK_DEADZONE : 0.0f) + (l_stick_y < 0 ? constants::LEFT_STICK_DEADZONE : 0.0f);

                // Modify the cursor position based on left stick values
                auto &transform = registry.get<transform::Transform>(globals::getCursorEntity());
                transform.setActualX(transform.getActualX() + l_stick_x * dt * state.axis_cursor_speed);
                transform.setActualY(transform.getActualY() + l_stick_y * dt * state.axis_cursor_speed);

                // Update screen space cursor position
                state.cursor_position.x = transform.getActualX();
                state.cursor_position.y = transform.getActualY();
            }
            else
            {
                // Treat the left stick as a directional pad (dpad) input
                auto &axisButton = state.axis_buttons["left_stick"];
                axisButton.current = axisButton.previous;
                if ((std::abs(l_stick_x) + std::abs(l_stick_y)) > constants::LEFT_STICK_DPAD_ACTIVATION_THRESHOLD)
                {
                    axisInterpretation = InputDeviceInputCategory::GAMEPAD_BUTTON; // Left stick is a button

                    axisButton.current = std::abs(l_stick_x) > std::abs(l_stick_y)
                                             ? (l_stick_x > 0 ? dpadRight : dpadLeft)
                                             : (l_stick_y > 0 ? dpadDown : dpadUp);
                }
                else if ((std::abs(l_stick_x) + std::abs(l_stick_y)) < constants::LEFT_STICK_DPAD_RELEASE_THRESHOLD)
                {
                    axisButton.current.reset();
                }
            }

            //---------------------------------------------------------------
            //                     Right Thumbstick
            //---------------------------------------------------------------
            float r_stick_x = GetGamepadAxisMovement(state.gamepad.id, GAMEPAD_AXIS_RIGHT_X);
            float r_stick_y = GetGamepadAxisMovement(state.gamepad.id, GAMEPAD_AXIS_RIGHT_Y);

            const float deadzone = constants::RIGHT_STICK_DEADZONE;

            float mag = std::sqrt(std::pow(r_stick_x, 2) + std::pow(r_stick_y, 2));
            if (mag > deadzone)
            {
                axisInterpretation = InputDeviceInputCategory::GAMEPAD_AXIS_CURSOR; // Cursor movement detected

                // Apply deadzone for right stick
                if (std::abs(r_stick_x) < deadzone)
                    r_stick_x = 0;
                if (std::abs(r_stick_y) < deadzone)
                    r_stick_y = 0;
                r_stick_x = r_stick_x + (r_stick_x > 0 ? -deadzone : 0) + (r_stick_x < 0 ? deadzone : 0);
                r_stick_y = r_stick_y + (r_stick_y > 0 ? -deadzone : 0) + (r_stick_y < 0 ? deadzone : 0);

                // Modify the cursor position based on right stick values
                auto &transform = registry.get<transform::Transform>(globals::getCursorEntity());
                transform.setActualX(transform.getActualX() + r_stick_x * dt * state.axis_cursor_speed);
                transform.setActualY(transform.getActualY() + r_stick_y * dt * state.axis_cursor_speed);

                // Update screen space cursor position
                state.cursor_position.x = transform.getActualX();
                state.cursor_position.y = transform.getActualY();
            }

            //---------------------------------------------------------------
            //                         Triggers
            //---------------------------------------------------------------
            float l_trig = GetGamepadAxisMovement(state.gamepad.id, GAMEPAD_AXIS_LEFT_TRIGGER);
            float r_trig = GetGamepadAxisMovement(state.gamepad.id, GAMEPAD_AXIS_RIGHT_TRIGGER);

            auto &axisButtonLTrigger = state.axis_buttons["left_trigger"];
            auto &axisButtonRTrigger = state.axis_buttons["right_trigger"];

            axisButtonLTrigger.current = state.axis_buttons["left_trigger"].previous;
            axisButtonRTrigger.current = state.axis_buttons["right_trigger"].previous;

            // Handle the triggers as button presses
            if (l_trig > constants::TRIGGER_ACTIVATION_THRESHOLD)
            {
                axisButtonLTrigger.current = leftTrigger;
            }
            else if (l_trig < constants::TRIGGER_RELEASE_THRESHOLD)
            {
                axisButtonLTrigger.current.reset();
            }

            if (r_trig > constants::TRIGGER_ACTIVATION_THRESHOLD)
            {
                axisButtonRTrigger.current = rightTrigger;
            }
            else if (r_trig < constants::TRIGGER_RELEASE_THRESHOLD)
            {
                axisButtonRTrigger.current.reset();
            }

            // Return "gamepadbutton" if any trigger is active
            if (axisButtonRTrigger.current || axisButtonLTrigger.current)
            {
                axisInterpretation = (axisInterpretation == InputDeviceInputCategory::NONE) ? InputDeviceInputCategory::GAMEPAD_BUTTON : axisInterpretation;
            }

            // Handle button press/release for axis buttons
            ProcessAxisButtons(state, ctx);
            
            // send axis each frame so action_value aggregates
            input::DispatchRaw(state, InputDeviceInputCategory::GAMEPAD_AXIS, (int)GAMEPAD_AXIS_LEFT_X,  true, l_stick_x);
            input::DispatchRaw(state, InputDeviceInputCategory::GAMEPAD_AXIS, (int)GAMEPAD_AXIS_LEFT_Y,  true, l_stick_y);
            input::DispatchRaw(state, InputDeviceInputCategory::GAMEPAD_AXIS, (int)GAMEPAD_AXIS_RIGHT_X, true, r_stick_x);
            input::DispatchRaw(state, InputDeviceInputCategory::GAMEPAD_AXIS, (int)GAMEPAD_AXIS_RIGHT_Y, true, r_stick_y);
            input::DispatchRaw(state, InputDeviceInputCategory::GAMEPAD_AXIS, (int)GAMEPAD_AXIS_LEFT_TRIGGER,  true, l_trig);
            input::DispatchRaw(state, InputDeviceInputCategory::GAMEPAD_AXIS, (int)GAMEPAD_AXIS_RIGHT_TRIGGER, true, r_trig);
        }

        // Reset focus if necessary
        if (axisInterpretation != InputDeviceInputCategory::NONE)
        {
            state.focus_interrupt = false;
        }

        return axisInterpretation;
    }

    auto ButtonPressUpdate(entt::registry &registry, InputState &state, const GamepadButton button, float dt) -> void
    {
        // Exit if frame lock is active
        if (state.activeInputLocks["frame"])
            return;

        // Reset hold time and clear focus interrupt
        state.gamepadHeldButtonDurations[button] = 0;
        state.focus_interrupt = false;

        // Check for focused input capture
        if (!CaptureFocusedInput(registry, state, "press", button, dt))
        {
            if (button == GAMEPAD_BUTTON_LEFT_FACE_UP)
                NavigateFocus(registry, state, "U"); // DPAD TODO: change up down etc. to enums
            else if (button == GAMEPAD_BUTTON_LEFT_FACE_DOWN)
                NavigateFocus(registry, state, "D");
            else if (button == GAMEPAD_BUTTON_LEFT_FACE_LEFT)
                NavigateFocus(registry, state, "L");
            else if (button == GAMEPAD_BUTTON_LEFT_FACE_RIGHT)
                NavigateFocus(registry, state, "R");
        }

        // Check input lock conditions
        if ((state.inputLocked && !globals::getIsGamePaused()) || state.activeInputLocks["frame"] || state.frame_buttonpress)
            return;
        state.frame_buttonpress = true;

        // Check button registry
        if (state.button_registry.contains(button) && !state.button_registry[button].empty() &&
            !state.button_registry[button][0].under_overlay)
        {
            state.button_registry[button][0].click = true;
        }
        else
        {
            // Handle specific button actions
            if (button == GAMEPAD_BUTTON_MIDDLE_RIGHT)
            { // start button
              // if (state.game_state == GameState::SPLASH) {
              //     deleteRun();  // Reset the game
              //     mainMenu();   // Return to the main menu
              // }
            }
            else if (button == GAMEPAD_BUTTON_RIGHT_FACE_DOWN)
            { // A button (xbox)
                if (state.cursor_focused_target != entt::null)
                {
                    // FIXME: patching this out for now. 
                    // auto &focusedNode = registry.get<transform::GameObject>(state.cursor_focused_target);
                    // auto &focusedUIConfig = registry.get<ui::UIConfig>(state.cursor_focused_target);
                    // if (focusedUIConfig.focusArgs->type == "slider" &&
                    //     !state.hid.mouse_enabled && !state.hid.axis_cursor_enabled)
                    // {
                    //     // Do nothing
                    // }
                    // else
                    // {
                    //     // Trigger left cursor press
                    //     ProcessLeftMouseButtonPress(registry, state); // Trigger left cursor press
                    // }
                }
                else
                {
                    ProcessLeftMouseButtonPress(registry, state); // Trigger left cursor press
                }
            }
            else if (button == GAMEPAD_BUTTON_RIGHT_FACE_RIGHT)
            { // B button (xbox)
                if (state.cursor_focused_target != entt::null /** && some check wehther area exists, and whether state.cursor_focused_target_area is the same as that area*/)
                {
                    EnqueRightMouseButtonPress(state); // Trigger right cursor press
                }
                else
                {
                    state.focus_interrupt = true;
                }
            }
        }
    }

    auto HeldButtonUpdate(entt::registry &registry, InputState &state, const GamepadButton button, float dt) -> void
    {
        // Ignore input if the system is locked or already processed
        if ((state.inputLocked && !globals::getIsGamePaused()) || state.activeInputLocks["frame"] || state.frame_buttonpress)
            return;
        state.frame_buttonpress = true;

        // SPDLOG_DEBUG("Held button: {}", magic_enum::enum_name(button));

        // Increment hold time for the button
        if (state.gamepadHeldButtonDurations.contains(button))
        {
            state.gamepadHeldButtonDurations[button] += dt;
            CaptureFocusedInput(registry, state, "hold", button, dt); // Process hold input
        }

        // Handle directional button repeat behavior
        if ((button == GAMEPAD_BUTTON_LEFT_FACE_LEFT || button == GAMEPAD_BUTTON_LEFT_FACE_RIGHT || button == GAMEPAD_BUTTON_LEFT_FACE_UP || button == GAMEPAD_BUTTON_LEFT_FACE_DOWN) && !state.no_holdcap)
        {
            state.repress_timer = state.repress_timer > 0.0f ? state.repress_timer : constants::BUTTON_REPEAT_INITIAL_DELAY;
            if (state.gamepadHeldButtonDurations[button] > state.repress_timer)
            {
                state.repress_timer = constants::BUTTON_REPEAT_SUBSEQUENT_DELAY;
                state.gamepadHeldButtonDurations[button] = 0.0f; // Reset hold time
                ButtonPressUpdate(registry, state, button, dt);  // Trigger button press action

                SPDLOG_DEBUG("Repeating button: {}", magic_enum::enum_name(button));
            }
        }
    }

    // Handles button release updates
    void ReleasedButtonUpdate(entt::registry &registry, InputState &state, const GamepadButton button, float dt)
    {
        // Check if button is being tracked
        if (state.gamepadHeldButtonDurations.find(button) == state.gamepadHeldButtonDurations.end())
        {
            return;
        }

        // Set repress timer
        state.repress_timer = constants::BUTTON_REPEAT_INITIAL_DELAY;

        // Remove button from tracking
        state.gamepadHeldButtonDurations.erase(button);

        // Handle specific button logic
        if (button == GAMEPAD_BUTTON_RIGHT_FACE_DOWN)
        { // A button (xbox)
            SPDLOG_DEBUG("A button released");
            ProcessLeftMouseButtonRelease(registry, state);
        }
    }

    // Function to process the key and return the correct character

    // **Maps Raylib's KeyboardKey to characters (handles shift & caps)**
    char GetCharacterFromKey(KeyboardKey key, bool caps)
    {
        static std::unordered_map<KeyboardKey, std::pair<char, char>> keyMap = {
            {KEY_A, {'a', 'A'}}, {KEY_B, {'b', 'B'}}, {KEY_C, {'c', 'C'}}, {KEY_D, {'d', 'D'}}, {KEY_E, {'e', 'E'}}, {KEY_F, {'f', 'F'}}, {KEY_G, {'g', 'G'}}, {KEY_H, {'h', 'H'}}, {KEY_I, {'i', 'I'}}, {KEY_J, {'j', 'J'}}, {KEY_K, {'k', 'K'}}, {KEY_L, {'l', 'L'}}, {KEY_M, {'m', 'M'}}, {KEY_N, {'n', 'N'}}, {KEY_O, {'o', 'O'}}, {KEY_P, {'p', 'P'}}, {KEY_Q, {'q', 'Q'}}, {KEY_R, {'r', 'R'}}, {KEY_S, {'s', 'S'}}, {KEY_T, {'t', 'T'}}, {KEY_U, {'u', 'U'}}, {KEY_V, {'v', 'V'}}, {KEY_W, {'w', 'W'}}, {KEY_X, {'x', 'X'}}, {KEY_Y, {'y', 'Y'}}, {KEY_Z, {'z', 'Z'}}, {KEY_ZERO, {'0', ')'}}, {KEY_ONE, {'1', '!'}}, {KEY_TWO, {'2', '@'}}, {KEY_THREE, {'3', '#'}}, {KEY_FOUR, {'4', '$'}}, {KEY_FIVE, {'5', '%'}}, {KEY_SIX, {'6', '^'}}, {KEY_SEVEN, {'7', '&'}}, {KEY_EIGHT, {'8', '*'}}, {KEY_NINE, {'9', '('}}, {KEY_SPACE, {' ', ' '}}, {KEY_MINUS, {'-', '_'}}, {KEY_EQUAL, {'=', '+'}}, {KEY_LEFT_BRACKET, {'[', '{'}}, {KEY_RIGHT_BRACKET, {']', '}'}}, {KEY_SEMICOLON, {';', ':'}}, {KEY_APOSTROPHE, {'\'', '"'}}, {KEY_COMMA, {',', '<'}}, {KEY_PERIOD, {'.', '>'}}, {KEY_SLASH, {'/', '?'}}, {KEY_BACKSLASH, {'\\', '|'}}};

        if (keyMap.find(key) != keyMap.end())
        {
            return caps ? keyMap[key].second : keyMap[key].first;
        }
        return '\0'; // Return null character if not found
    }

    // **Processes user text input and updates the entity's text field**
    void ProcessTextInput(entt::registry &registry, entt::entity entity, KeyboardKey key, bool shift, bool capsLock)
    {
        auto &textInput = registry.get<ui::TextInput>(entity);

        bool caps = capsLock || shift || textInput.allCaps;
        char inputChar = GetCharacterFromKey(key, caps);

        // **Backspace: Remove previous character**
        if (key == KEY_BACKSPACE && textInput.cursorPos > 0)
        {
            textInput.text.erase(textInput.cursorPos - 1, 1);
            textInput.cursorPos--;
        }
        // **Delete: Remove next character**
        else if (key == KEY_DELETE && textInput.cursorPos < textInput.text.size())
        {
            textInput.text.erase(textInput.cursorPos, 1);
        }
        // **Enter: Finish input and execute callback**
        else if (key == KEY_ENTER)
        {
            if (textInput.callback)
                textInput.callback();
            registry.remove<ui::TextInput>(entity); // Unhook text input
        }
        // **Arrow Left: Move cursor left**
        else if (key == KEY_LEFT)
        {
            if (textInput.cursorPos > 0)
            {
                textInput.cursorPos--;
            }
        }
        // **Arrow Right: Move cursor right**
        else if (key == KEY_RIGHT)
        {
            if (textInput.cursorPos < textInput.text.size())
            {
                textInput.cursorPos++;
            }
        }
        // **Normal character input**
        else if (inputChar != '\0' && textInput.text.length() < textInput.maxLength)
        {
            textInput.text.insert(textInput.cursorPos, 1, inputChar);
            textInput.cursorPos++;
        }
    }

    // **Hooks an entity to listen for text input**
    void HookTextInput(entt::registry &registry, entt::entity entity)
    {
        registry.emplace_or_replace<ui::TextInput>(entity, ui::TextInput{});
    }

    // **Unhooks text input (removes control)**
    void UnhookTextInput(entt::registry &registry, entt::entity entity)
    {
        registry.remove<ui::TextInput>(entity);
    }

    void KeyboardKeyPressUpdate(entt::registry &registry, InputState &state, KeyboardKey key, float dt)
    {
        // Exit early if frame locks are active
        if (state.activeInputLocks["frame"])
            return;

        // Normalize keys (adjustments for keypad keys and enter key)
        KeyboardKey normalizedKey = key;
        if (key == KEY_KP_ENTER)
            normalizedKey = KEY_ENTER;

        // Handle text input hook
        if (state.text_input_hook)
        {
            if (normalizedKey == KEY_ESCAPE)
            {
                state.text_input_hook.reset(); // Clear text input hook
            }
            else if (normalizedKey == KEY_CAPS_LOCK)
            {
                state.capslock = !state.capslock; // Toggle capslock
            }
            else
            {
                ProcessTextInput(registry, state.text_input_hook.value(), normalizedKey,
                                 state.keysHeldThisFrame[KEY_LEFT_SHIFT] || state.keysHeldThisFrame[KEY_RIGHT_SHIFT], state.capslock);
            }
            return;
        }

        // Escape key handling for menu and state transitions
        if (normalizedKey == KEY_ESCAPE)
        {
            // LATER: depending on game state, transition to different game states.
            // For instance, if in splash screen go to main nmenu
            // or if overlay menu is not active, open options menu
            // or if overlay menu is active, close it
        }

        // Exit if locks or frame restrictions are active
        if ((state.inputLocked && !globals::getIsGamePaused()) || state.activeInputLocks["frame"] || state.frame_buttonpress)
            return;
        state.frame_buttonpress = true;
        state.heldKeyDurations[normalizedKey] = 0;

#ifndef RELEASE_MODE
        // LATER: debug tools can be added here, depending on the key pressed
        //  Debug tool toggle
        //  debug tool ui,
        //  hover handling (hover_target)
        //  debug ui toggle, debug shortcuts for changing game state
        //  toggle mouse visibility
        //  toggle profiling
        //  toggle debug tooltips
        //  toggle performance mode, etc.

        // not sure if using macro is the best way to handle this.
#endif
    }

    void KeyboardKeyHoldUpdate(InputState &state, KeyboardKey key, float dt)
    {
        // Exit early if locked or certain conditions are met
        if ((state.inputLocked && !globals::getIsGamePaused()) || state.activeInputLocks["frame"] || state.frame_buttonpress)
        {
            return;
        }

        // Check if the key is being tracked in heldKeyDurations
        if (state.heldKeyDurations.find(key) != state.heldKeyDurations.end())
        {
            // Handle the "R" key specifically
            if (key == KEY_R && !globals::getIsGamePaused())
            {
                // If the key has been held for more than the reset duration
                if (state.heldKeyDurations[key] > constants::KEY_HOLD_RESET_DURATION)
                {
                    // Do something - TODO: reset state?

                    // Reset key hold time
                    state.heldKeyDurations.erase(key);
                }
                else
                {
                    // Increment the hold time for the key
                    state.heldKeyDurations[key] += dt;
                }
            }
        }
    }

    void KeyboardKeyReleasedUpdate(InputState &state, KeyboardKey key, float dt)
    {
        // Exit early if locked, paused, or certain frame conditions are met
        if ((state.inputLocked && !globals::getIsGamePaused()) || state.activeInputLocks["frame"] || state.frame_buttonpress)
        {
            return;
        }

        // Mark the frame as having processed a button press
        state.frame_buttonpress = true;

        // Toggle debug mode if "A" is released while "G" is held, and not in release mode
        if (key == KEY_A && state.keysHeldThisFrame[KEY_G] && !globals::getReleaseMode())
        {
            // example way to toggle debug tools
        }

        // Handle "TAB" key to remove debug tools
        if (key == KEY_TAB /**&& flag to show debug tool active */)
        {
            // do something
        }
    }

    // Key Press: Marks the key as pressed and held
    void ProcessKeyboardKeyDown(InputState &state, KeyboardKey key)
    {
        state.keysPressedThisFrame[key] = true;
        state.keysHeldThisFrame[key] = true;
        
        input::DispatchRaw(state, InputDeviceInputCategory::KEYBOARD, (int)key, true);
    }

    // Key Release: Marks the key as released and removes it from held keys
    void ProcessKeyboardKeyRelease(InputState &state, KeyboardKey key)
    {
        SPDLOG_DEBUG("Key released: {}", magic_enum::enum_name(key));
        state.keysHeldThisFrame.erase(key); // Remove the key from held keys
        state.keysReleasedThisFrame[key] = true;
        input::DispatchRaw(state, InputDeviceInputCategory::KEYBOARD, (int)key, false);

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
    
    auto RebuildActionIndex(InputState &s) -> void {
        s.code_to_actions.clear();
        for (auto &kv : s.action_bindings) {
            const auto &name = kv.first;
            const auto &vec  = kv.second;
            for (size_t i = 0; i < vec.size(); ++i) {
                const auto &b = vec[i];
                // Only index bindings that can ever be active (context gating is rechecked at dispatch)
                s.code_to_actions.emplace(ActionKey{b.device, b.code}, std::pair<std::string,size_t>{name, i});
            }
        }
    }

    // per-frame cleanup; call at end of Update
    auto DecayActions(InputState &s) -> void {
        for (auto &kv : s.actions) {
            auto &st = kv.second;
            st.pressed = false;
            st.released = false;
            st.down = false;
            st.value = 0.f; // axis value is recomputed each frame
        }
    }

    // O(1) dispatch for raw events/axes
    auto DispatchRaw(InputState &s, InputDeviceInputCategory dev, int code, bool down, float value) -> void {
        if (s.rebind_listen) {
            ActionBinding b;
            b.device = dev;
            b.code = code;
            b.trigger = down ? ActionTrigger::Pressed : ActionTrigger::Released;
            s.rebind_listen = false;
            if (s.on_rebind_done) s.on_rebind_done(true, b);
            return;
        }

        auto range = s.code_to_actions.equal_range(ActionKey{dev, code});
        for (auto it = range.first; it != range.second; ++it) {
            const auto &name = it->second.first;
            const auto &bind = s.action_bindings[name][it->second.second];

            // context gate
            if (!(bind.context == "global" || bind.context == s.active_context)) continue;

            auto &st = s.actions[name];

            // trigger matching (if-chains per your style)
            if (bind.trigger == ActionTrigger::Pressed) {
                if (down) {
                    if (!st.down) st.pressed = true;  // only on rising edge
                    st.down = true;
                } else {
                    st.held = 0.f;
                }
            }
            else if (bind.trigger == ActionTrigger::Released) {
                if (!down) { st.released = true; st.down = false; st.held = 0.f; }
            }
            else if (bind.trigger == ActionTrigger::Held) {
                if (down) st.down = true;
            }
            else if (bind.trigger == ActionTrigger::Repeat) {
                // implement your repeat cadence if desired
            }
            else if (bind.trigger == ActionTrigger::AxisPos) {
                if (value > bind.threshold) st.value = std::max(st.value, value);
            }
            else if (bind.trigger == ActionTrigger::AxisNeg) {
                if (value < -bind.threshold) st.value = std::min(st.value, value);
            }
        }
    }

    // Tick held timers; call once per frame before DecayActions
    auto TickActionHolds(InputState &s, float dt) -> void {
        for (auto &kv : s.actions) if (kv.second.down) kv.second.held += dt;
    }

    // Public C++ API
    auto bind_action(InputState &s, const std::string &action, const ActionBinding &b) -> void {
        s.action_bindings[action].push_back(b);
        RebuildActionIndex(s);
    }
    auto clear_action(InputState &s, const std::string &action) -> void {
        s.action_bindings.erase(action);
        s.actions.erase(action);
        RebuildActionIndex(s);
    }
    auto set_context(InputState &s, const std::string &ctx) -> void {
        s.active_context = ctx;
        // no need to rebuild index here; we check context on dispatch
    }
    auto action_pressed (InputState &s, const std::string &a) -> bool  { return s.actions[a].pressed; }
    auto action_released(InputState &s, const std::string &a) -> bool  { return s.actions[a].released; }
    auto action_down    (InputState &s, const std::string &a) -> bool  { return s.actions[a].down; }
    auto action_value   (InputState &s, const std::string &a) -> float { 
        return s.actions[a].value; 
    }

    auto start_rebind(InputState &s, const std::string &action, std::function<void(bool, ActionBinding)> cb) -> void {
        s.rebind_action = action;
        s.on_rebind_done = std::move(cb);
        s.rebind_listen = true;
    }
    
    static auto to_device(const std::string &s) -> InputDeviceInputCategory {
        if (s == "keyboard") return InputDeviceInputCategory::KEYBOARD;
        if (s == "mouse")    return InputDeviceInputCategory::MOUSE;
        if (s == "gamepad_button") return InputDeviceInputCategory::GAMEPAD_BUTTON;
        if (s == "gamepad_axis")   return InputDeviceInputCategory::GAMEPAD_AXIS;
        return InputDeviceInputCategory::NONE;
    }
    static auto to_trigger(const std::string &s) -> ActionTrigger {
        if (s == "Pressed")  return ActionTrigger::Pressed;
        if (s == "Released") return ActionTrigger::Released;
        if (s == "Held")     return ActionTrigger::Held;
        if (s == "Repeat")   return ActionTrigger::Repeat;
        if (s == "AxisPos")  return ActionTrigger::AxisPos;
        if (s == "AxisNeg")  return ActionTrigger::AxisNeg;
        return ActionTrigger::Pressed;
    }

    
    auto exposeToLua(sol::state &lua, EngineContext* ctx) -> void
    {
        (void)ctx; // currently unused; kept for context-aware expansion

        // Sol2 binding for input::InputState struct
        auto &L = lua;
        
        L.new_usertype<HIDFlags>("HIDFlags",
                                  sol::constructors<sol::types<>>(),
                                  "last_type", &HIDFlags::last_type,
                                  "dpad_enabled", &HIDFlags::dpad_enabled,
                                  "pointer_enabled", &HIDFlags::pointer_enabled,
                                  "touch_enabled", &HIDFlags::touch_enabled,
                                  "controller_enabled", &HIDFlags::controller_enabled,
                                  "mouse_enabled", &HIDFlags::mouse_enabled,
                                  "axis_cursor_enabled", &HIDFlags::axis_cursor_enabled);
        
        
        auto inputStateType = L.new_usertype<input::InputState>("InputState",
                                          sol::no_constructor,
                                          // Cursor targets and interaction
                                          "cursor_clicked_target", &input::InputState::cursor_clicked_target,
                                          "cursor_prev_clicked_target", &input::InputState::cursor_prev_clicked_target,
                                          "cursor_focused_target", &input::InputState::cursor_focused_target,
                                          "cursor_prev_focused_target", &input::InputState::cursor_prev_focused_target,
                                          "cursor_focused_target_area", &input::InputState::cursor_focused_target_area,
                                          "cursor_dragging_target", &input::InputState::cursor_dragging_target,
                                          "cursor_prev_dragging_target", &input::InputState::cursor_prev_dragging_target,
                                          "cursor_prev_released_on_target", &input::InputState::cursor_prev_released_on_target,
                                          "cursor_released_on_target", &input::InputState::cursor_released_on_target,
                                          "current_designated_hover_target", &input::InputState::current_designated_hover_target,
                                          "prev_designated_hover_target", &input::InputState::prev_designated_hover_target,
                                          "cursor_hovering_target", &input::InputState::cursor_hovering_target,
                                          "cursor_prev_hovering_target", &input::InputState::cursor_prev_hovering_target,
                                          "cursor_hovering_handled", &input::InputState::cursor_hovering_handled,

                                          // Collision and cursor lists
                                          "collision_list", &input::InputState::collision_list,
                                          "nodes_at_cursor", &input::InputState::nodes_at_cursor,

                                          // Cursor positions
                                          "cursor_position", &input::InputState::cursor_position,
                                          "cursor_down_position", &input::InputState::cursor_down_position,
                                          "cursor_up_position", &input::InputState::cursor_up_position,
                                          "focus_cursor_pos", &input::InputState::focus_cursor_pos,
                                          "cursor_down_time", &input::InputState::cursor_down_time,
                                          "cursor_up_time", &input::InputState::cursor_up_time,

                                          // Cursor handling flags
                                          "cursor_down_handled", &input::InputState::cursor_down_handled,
                                          "cursor_down_target", &input::InputState::cursor_down_target,
                                          "cursor_down_target_click_timeout", &input::InputState::cursor_down_target_click_timeout,
                                          "cursor_up_handled", &input::InputState::cursor_up_handled,
                                          "cursor_up_target", &input::InputState::cursor_up_target,
                                          "cursor_released_on_handled", &input::InputState::cursor_released_on_handled,
                                          "cursor_click_handled", &input::InputState::cursor_click_handled,
                                          "is_cursor_down", &input::InputState::is_cursor_down,

                                          // Frame button press
                                          "frame_buttonpress", &input::InputState::frame_buttonpress,
                                          "repress_timer", &input::InputState::repress_timer,
                                          "no_holdcap", &input::InputState::no_holdcap,

                                          // Text input hook
                                          "text_input_hook", &input::InputState::text_input_hook,
                                          "capslock", &input::InputState::capslock,
                                          "coyote_focus", &input::InputState::coyote_focus,

                                          "cursor_hover_transform", &input::InputState::cursor_hover_transform,
                                          "cursor_hover_time", &input::InputState::cursor_hover_time,
                                          "L_cursor_queue", &input::InputState::L_cursor_queue,

                                          // Key states
                                          "keysPressedThisFrame", &input::InputState::keysPressedThisFrame,
                                          "keysHeldThisFrame", &input::InputState::keysHeldThisFrame,
                                          "heldKeyDurations", &input::InputState::heldKeyDurations,
                                          "keysReleasedThisFrame", &input::InputState::keysReleasedThisFrame,

                                          // Gamepad buttons
                                          "gamepadButtonsPressedThisFrame", &input::InputState::gamepadButtonsPressedThisFrame,
                                          "gamepadButtonsHeldThisFrame", &input::InputState::gamepadButtonsHeldThisFrame,
                                          "gamepadHeldButtonDurations", &input::InputState::gamepadHeldButtonDurations,
                                          "gamepadButtonsReleasedThisFrame", &input::InputState::gamepadButtonsReleasedThisFrame,

                                          // Input locks
                                          "focus_interrupt", &input::InputState::focus_interrupt,
                                          "activeInputLocks", &input::InputState::activeInputLocks,
                                          "inputLocked", &input::InputState::inputLocked,

                                          // Axis buttons
                                          "axis_buttons", &input::InputState::axis_buttons,

                                          // Gamepad state
                                          "axis_cursor_speed", &input::InputState::axis_cursor_speed,
                                          "button_registry", &input::InputState::button_registry,
                                          "snap_cursor_to", &input::InputState::snap_cursor_to,

                                          // Cursor context & HID flags
                                          "cursor_context", &input::InputState::cursor_context,
                                          "hid", sol::property([](input::InputState &s) -> HIDFlags& {
    return s.hid;
}),

                                          // Gamepad config
                                          "gamepad", &input::InputState::gamepad,
                                          "overlay_menu_active_timer", &input::InputState::overlay_menu_active_timer,
                                          "overlay_menu_active", &input::InputState::overlay_menu_active,
                                          "screen_keyboard", &input::InputState::screen_keyboard);
                                          
        inputStateType["cursor_hovering_target"] = sol::property(
            [](input::InputState &state) -> entt::entity {
                return state.cursor_hovering_target;
            },
            [](input::InputState &state, entt::entity target) {
                state.cursor_hovering_target = target;
            });

        // Finally assign the singleton instance to globals.input.state
        // lua["globals"]["inputstate"] = &globals::inputState;

        // Replacing large enums with safe Lua table creation to avoid sol2 argument overflow

        // 1. Raylib KeyboardKey enum (complete)
        lua["KeyboardKey"] = lua.create_table_with(
            "KEY_NULL", KEY_NULL,
            "KEY_APOSTROPHE", KEY_APOSTROPHE,
            "KEY_COMMA", KEY_COMMA,
            "KEY_MINUS", KEY_MINUS,
            "KEY_PERIOD", KEY_PERIOD,
            "KEY_SLASH", KEY_SLASH,
            "KEY_ZERO", KEY_ZERO,
            "KEY_ONE", KEY_ONE,
            "KEY_TWO", KEY_TWO,
            "KEY_THREE", KEY_THREE,
            "KEY_FOUR", KEY_FOUR,
            "KEY_FIVE", KEY_FIVE,
            "KEY_SIX", KEY_SIX,
            "KEY_SEVEN", KEY_SEVEN,
            "KEY_EIGHT", KEY_EIGHT,
            "KEY_NINE", KEY_NINE,
            "KEY_SEMICOLON", KEY_SEMICOLON,
            "KEY_EQUAL", KEY_EQUAL,
            "KEY_A", KEY_A,
            "KEY_B", KEY_B,
            "KEY_C", KEY_C,
            "KEY_D", KEY_D,
            "KEY_E", KEY_E,
            "KEY_F", KEY_F,
            "KEY_G", KEY_G,
            "KEY_H", KEY_H,
            "KEY_I", KEY_I,
            "KEY_J", KEY_J,
            "KEY_K", KEY_K,
            "KEY_L", KEY_L,
            "KEY_M", KEY_M,
            "KEY_N", KEY_N,
            "KEY_O", KEY_O,
            "KEY_P", KEY_P,
            "KEY_Q", KEY_Q,
            "KEY_R", KEY_R,
            "KEY_S", KEY_S,
            "KEY_T", KEY_T,
            "KEY_U", KEY_U,
            "KEY_V", KEY_V,
            "KEY_W", KEY_W,
            "KEY_X", KEY_X,
            "KEY_Y", KEY_Y,
            "KEY_Z", KEY_Z,
            "KEY_LEFT_BRACKET", KEY_LEFT_BRACKET,
            "KEY_BACKSLASH", KEY_BACKSLASH,
            "KEY_RIGHT_BRACKET", KEY_RIGHT_BRACKET,
            "KEY_GRAVE", KEY_GRAVE,
            "KEY_SPACE", KEY_SPACE,
            "KEY_ESCAPE", KEY_ESCAPE,
            "KEY_ENTER", KEY_ENTER,
            "KEY_TAB", KEY_TAB,
            "KEY_BACKSPACE", KEY_BACKSPACE,
            "KEY_INSERT", KEY_INSERT,
            "KEY_DELETE", KEY_DELETE,
            "KEY_RIGHT", KEY_RIGHT,
            "KEY_LEFT", KEY_LEFT,
            "KEY_DOWN", KEY_DOWN,
            "KEY_UP", KEY_UP,
            "KEY_PAGE_UP", KEY_PAGE_UP,
            "KEY_PAGE_DOWN", KEY_PAGE_DOWN,
            "KEY_HOME", KEY_HOME,
            "KEY_END", KEY_END,
            "KEY_CAPS_LOCK", KEY_CAPS_LOCK,
            "KEY_SCROLL_LOCK", KEY_SCROLL_LOCK,
            "KEY_NUM_LOCK", KEY_NUM_LOCK,
            "KEY_PRINT_SCREEN", KEY_PRINT_SCREEN,
            "KEY_PAUSE", KEY_PAUSE,
            "KEY_F1", KEY_F1,
            "KEY_F2", KEY_F2,
            "KEY_F3", KEY_F3,
            "KEY_F4", KEY_F4,
            "KEY_F5", KEY_F5,
            "KEY_F6", KEY_F6,
            "KEY_F7", KEY_F7,
            "KEY_F8", KEY_F8,
            "KEY_F9", KEY_F9,
            "KEY_F10", KEY_F10,
            "KEY_F11", KEY_F11,
            "KEY_F12", KEY_F12,
            "KEY_LEFT_SHIFT", KEY_LEFT_SHIFT,
            "KEY_LEFT_CONTROL", KEY_LEFT_CONTROL,
            "KEY_LEFT_ALT", KEY_LEFT_ALT,
            "KEY_LEFT_SUPER", KEY_LEFT_SUPER,
            "KEY_RIGHT_SHIFT", KEY_RIGHT_SHIFT,
            "KEY_RIGHT_CONTROL", KEY_RIGHT_CONTROL,
            "KEY_RIGHT_ALT", KEY_RIGHT_ALT,
            "KEY_RIGHT_SUPER", KEY_RIGHT_SUPER,
            "KEY_KB_MENU", KEY_KB_MENU,
            "KEY_KP_0", KEY_KP_0,
            "KEY_KP_1", KEY_KP_1,
            "KEY_KP_2", KEY_KP_2,
            "KEY_KP_3", KEY_KP_3,
            "KEY_KP_4", KEY_KP_4,
            "KEY_KP_5", KEY_KP_5,
            "KEY_KP_6", KEY_KP_6,
            "KEY_KP_7", KEY_KP_7,
            "KEY_KP_8", KEY_KP_8,
            "KEY_KP_9", KEY_KP_9,
            "KEY_KP_DECIMAL", KEY_KP_DECIMAL,
            "KEY_KP_DIVIDE", KEY_KP_DIVIDE,
            "KEY_KP_MULTIPLY", KEY_KP_MULTIPLY,
            "KEY_KP_SUBTRACT", KEY_KP_SUBTRACT,
            "KEY_KP_ADD", KEY_KP_ADD,
            "KEY_KP_ENTER", KEY_KP_ENTER,
            "KEY_KP_EQUAL", KEY_KP_EQUAL,
            "KEY_BACK", KEY_BACK,
            "KEY_MENU", KEY_MENU,
            "KEY_VOLUME_UP", KEY_VOLUME_UP,
            "KEY_VOLUME_DOWN", KEY_VOLUME_DOWN);

        // 2. MouseButton enum
        lua["MouseButton"] = lua.create_table_with(
            "MOUSE_BUTTON_LEFT", MOUSE_BUTTON_LEFT,
            "MOUSE_BUTTON_RIGHT", MOUSE_BUTTON_RIGHT,
            "MOUSE_BUTTON_MIDDLE", MOUSE_BUTTON_MIDDLE,
            "MOUSE_BUTTON_SIDE", MOUSE_BUTTON_SIDE,
            "MOUSE_BUTTON_EXTRA", MOUSE_BUTTON_EXTRA,
            "MOUSE_BUTTON_FORWARD", MOUSE_BUTTON_FORWARD,
            "MOUSE_BUTTON_BACK", MOUSE_BUTTON_BACK);

        // 3. GamepadButton enum
        lua["GamepadButton"] = lua.create_table_with(
            "GAMEPAD_BUTTON_UNKNOWN", GAMEPAD_BUTTON_UNKNOWN,
            "GAMEPAD_BUTTON_LEFT_FACE_UP", GAMEPAD_BUTTON_LEFT_FACE_UP,
            "GAMEPAD_BUTTON_LEFT_FACE_RIGHT", GAMEPAD_BUTTON_LEFT_FACE_RIGHT,
            "GAMEPAD_BUTTON_LEFT_FACE_DOWN", GAMEPAD_BUTTON_LEFT_FACE_DOWN,
            "GAMEPAD_BUTTON_LEFT_FACE_LEFT", GAMEPAD_BUTTON_LEFT_FACE_LEFT,
            "GAMEPAD_BUTTON_RIGHT_FACE_UP", GAMEPAD_BUTTON_RIGHT_FACE_UP,
            "GAMEPAD_BUTTON_RIGHT_FACE_RIGHT", GAMEPAD_BUTTON_RIGHT_FACE_RIGHT,
            "GAMEPAD_BUTTON_RIGHT_FACE_DOWN", GAMEPAD_BUTTON_RIGHT_FACE_DOWN,
            "GAMEPAD_BUTTON_RIGHT_FACE_LEFT", GAMEPAD_BUTTON_RIGHT_FACE_LEFT,
            "GAMEPAD_BUTTON_LEFT_TRIGGER_1", GAMEPAD_BUTTON_LEFT_TRIGGER_1,
            "GAMEPAD_BUTTON_LEFT_TRIGGER_2", GAMEPAD_BUTTON_LEFT_TRIGGER_2,
            "GAMEPAD_BUTTON_RIGHT_TRIGGER_1", GAMEPAD_BUTTON_RIGHT_TRIGGER_1,
            "GAMEPAD_BUTTON_RIGHT_TRIGGER_2", GAMEPAD_BUTTON_RIGHT_TRIGGER_2,
            "GAMEPAD_BUTTON_MIDDLE_LEFT", GAMEPAD_BUTTON_MIDDLE_LEFT,
            "GAMEPAD_BUTTON_MIDDLE", GAMEPAD_BUTTON_MIDDLE,
            "GAMEPAD_BUTTON_MIDDLE_RIGHT", GAMEPAD_BUTTON_MIDDLE_RIGHT,
            "GAMEPAD_BUTTON_LEFT_THUMB", GAMEPAD_BUTTON_LEFT_THUMB,
            "GAMEPAD_BUTTON_RIGHT_THUMB", GAMEPAD_BUTTON_RIGHT_THUMB);

        // 4. GamepadAxis enum
        lua["GamepadAxis"] = lua.create_table_with(
            "GAMEPAD_AXIS_LEFT_X", GAMEPAD_AXIS_LEFT_X,
            "GAMEPAD_AXIS_LEFT_Y", GAMEPAD_AXIS_LEFT_Y,
            "GAMEPAD_AXIS_RIGHT_X", GAMEPAD_AXIS_RIGHT_X,
            "GAMEPAD_AXIS_RIGHT_Y", GAMEPAD_AXIS_RIGHT_Y,
            "GAMEPAD_AXIS_LEFT_TRIGGER", GAMEPAD_AXIS_LEFT_TRIGGER,
            "GAMEPAD_AXIS_RIGHT_TRIGGER", GAMEPAD_AXIS_RIGHT_TRIGGER);

        // 5. InputDeviceInputCategory enum
        lua["InputDeviceInputCategory"] = lua.create_table_with(
            "NONE", InputDeviceInputCategory::NONE,
            "GAMEPAD_AXIS_CURSOR", InputDeviceInputCategory::GAMEPAD_AXIS_CURSOR,
            "GAMEPAD_AXIS", InputDeviceInputCategory::GAMEPAD_AXIS,
            "GAMEPAD_BUTTON", InputDeviceInputCategory::GAMEPAD_BUTTON,
            "MOUSE", InputDeviceInputCategory::MOUSE,
            "TOUCH", InputDeviceInputCategory::TOUCH,
        
            "KEYBOARD", (int)InputDeviceInputCategory::KEYBOARD   // NEW
        );

        // 2. Simple structs
        lua.new_usertype<AxisButtonState>("AxisButtonState",
                                          sol::constructors<AxisButtonState()>(),
                                          "current", &AxisButtonState::current,
                                          "previous", &AxisButtonState::previous);

        lua.new_usertype<NodeData>("NodeData",
                                   sol::constructors<NodeData()>(),
                                   "node", &NodeData::node,
                                   "click", &NodeData::click,
                                   "menu", &NodeData::menu,
                                   "under_overlay", &NodeData::under_overlay);

        lua.new_usertype<SnapTarget>("SnapTarget",
                                     sol::constructors<SnapTarget()>(),
                                     "node", &SnapTarget::node,
                                     "transform", &SnapTarget::transform,
                                     "type", &SnapTarget::type);

        // CursorContext and nested CursorLayer
        lua.new_usertype<CursorContext::CursorLayer>("CursorLayer",
                                                     sol::constructors<CursorContext::CursorLayer()>(),
                                                     "cursor_focused_target", &CursorContext::CursorLayer::cursor_focused_target,
                                                     "cursor_position", &CursorContext::CursorLayer::cursor_position,
                                                     "focus_interrupt", &CursorContext::CursorLayer::focus_interrupt);

        lua.new_usertype<CursorContext>("CursorContext",
                                        sol::constructors<CursorContext()>(),
                                        "layer", &CursorContext::layer,
                                        "stack", &CursorContext::stack);

        lua.new_usertype<GamepadState>("GamepadState",
                                       sol::constructors<GamepadState()>(),
                                       "object", &GamepadState::object,
                                       "mapping", &GamepadState::mapping,
                                       "name", &GamepadState::name,
                                       "console", &GamepadState::console,
                                       "id", &GamepadState::id);

        lua.new_usertype<HIDFlags>("HIDFlags",
                                   sol::constructors<HIDFlags()>(),
                                   "last_type", &HIDFlags::last_type,
                                   "dpad_enabled", &HIDFlags::dpad_enabled,
                                   "pointer_enabled", &HIDFlags::pointer_enabled,
                                   "touch_enabled", &HIDFlags::touch_enabled,
                                   "controller_enabled", &HIDFlags::controller_enabled,
                                   "mouse_enabled", &HIDFlags::mouse_enabled,
                                   "axis_cursor_enabled", &HIDFlags::axis_cursor_enabled);


        // raylib input

        auto in = lua.create_named_table("input");

        // make function for testing if gamepad enabled
        in.set_function("isGamepadEnabled", []() -> bool {
            return resolveInputState().hid.controller_enabled;
        });
        
        // TODO: need to expose the enums too

        // Keyboard
        in.set_function("isKeyDown", &IsKeyDown);
        in.set_function("isKeyPressed", &IsKeyPressed);
        in.set_function("isKeyReleased", &IsKeyReleased);
        in.set_function("isKeyUp", &IsKeyUp);
        
    

        // Mouse
        in.set_function("isMouseDown", &IsMouseButtonDown);
        in.set_function("isMousePressed", &IsMouseButtonPressed);
        in.set_function("isMouseReleased", &IsMouseButtonReleased);
        in.set_function("getMousePos", &globals::getScaledMousePositionCached);
        in.set_function("getMouseWheel", &GetMouseWheelMove);
        
        in.set_function("updateCursorFocus", []() {
            auto& state = resolveInputState();
            auto& reg = resolveRegistry();
            UpdateCursor(state, reg);
        });

        // Gamepad
        in.set_function("isPadConnected", &IsGamepadAvailable);
        in.set_function("isPadButtonDown", &IsGamepadButtonDown);
        in.set_function("getPadAxis", &GetGamepadAxisMovement);

        // Text / misc
        in.set_function("getChar", &GetCharPressed);
        in.set_function("getKeyPressed", &GetKeyPressed);
        in.set_function("setExitKey", &SetExitKey);

        // --- BindingRecorder definitions for input system ---

        auto &rec = BindingRecorder::instance();
        auto inputPath = std::vector<std::string>{"input"};

        // 1) InputState usertype
        rec.add_type("InputState", true);
        auto &isDef = rec.add_type("InputState");
        isDef.doc = "Per-frame snapshot of cursor, keyboard, mouse, and gamepad state.";

#define PROP(typeName, propName, docString) \
    rec.record_property("InputState", {propName, typeName, docString});

        // Cursor targets & interaction
        PROP("Entity", "cursor_clicked_target", "Entity clicked this frame")
        PROP("Entity", "cursor_prev_clicked_target", "Entity clicked in previous frame")
        PROP("Entity", "cursor_focused_target", "Entity under cursor focus now")
        PROP("Entity", "cursor_prev_focused_target", "Entity under cursor focus last frame")
        PROP("Rectangle", "cursor_focused_target_area", "Bounds of the focused target")
        PROP("Entity", "cursor_dragging_target", "Entity currently being dragged")
        PROP("Entity", "cursor_prev_dragging_target", "Entity dragged last frame")
        PROP("Entity", "cursor_prev_released_on_target", "Entity released on target last frame")
        PROP("Entity", "cursor_released_on_target", "Entity released on target this frame")
        PROP("Entity", "current_designated_hover_target", "Entity designated for hover handling")
        PROP("Entity", "prev_designated_hover_target", "Previously designated hover target")
        PROP("Entity", "cursor_hovering_target", "Entity being hovered now")
        PROP("Entity", "cursor_prev_hovering_target", "Entity hovered last frame")
        PROP("bool", "cursor_hovering_handled", "Whether hover was already handled")

        // Collision & cursor lists
        PROP("std::vector<Entity>", "collision_list", "All entities colliding with cursor")
        PROP("std::vector<NodeData>", "nodes_at_cursor", "All UI nodes under cursor")

        // Cursor positions & timing
        PROP("Vector2", "cursor_position", "Current cursor position")
        PROP("Vector2", "cursor_down_position", "Position where cursor was pressed")
        PROP("Vector2", "cursor_up_position", "Position where cursor was released")
        PROP("Vector2", "focus_cursor_pos", "Cursor pos used for gamepad/keyboard focus")
        PROP("float", "cursor_down_time", "Time of last cursor press")
        PROP("float", "cursor_up_time", "Time of last cursor release")

        // Cursor handling flags
        PROP("bool", "cursor_down_handled", "Down event handled flag")
        PROP("Entity", "cursor_down_target", "Entity pressed down on")
        PROP("float", "cursor_down_target_click_timeout", "Click timeout interval")
        PROP("bool", "cursor_up_handled", "Up event handled flag")
        PROP("Entity", "cursor_up_target", "Entity released on")
        PROP("bool", "cursor_released_on_handled", "Release handled flag")
        PROP("bool", "cursor_click_handled", "Click handled flag")
        PROP("bool", "is_cursor_down", "Is cursor currently down?")

        // Frame button press
        PROP("std::vector<InputButton>", "frame_buttonpress", "Buttons pressed this frame")
        PROP("std::unordered_map<InputButton,float>", "repress_timer", "Cooldown per button")
        PROP("bool", "no_holdcap", "Disable repeated hold events")

        // Text input hook
        PROP("std::function<void(int)>", "text_input_hook", "Callback for text input events")
        PROP("bool", "capslock", "Is caps-lock active")
        PROP("bool", "coyote_focus", "Allow focus grace period")

        // Cursor hover & queue
        PROP("Transform", "cursor_hover_transform", "Transform under cursor")
        PROP("float", "cursor_hover_time", "Hover duration")
        PROP("std::deque<Entity>", "L_cursor_queue", "Recent cursor targets queue")

        // Key & gamepad state
        PROP("std::vector<KeyboardKey>", "keysPressedThisFrame", "Keys pressed this frame")
        PROP("std::vector<KeyboardKey>", "keysHeldThisFrame", "Keys held down")
        PROP("std::unordered_map<KeyboardKey,float>", "heldKeyDurations", "Hold durations per key")
        PROP("std::vector<KeyboardKey>", "keysReleasedThisFrame", "Keys released this frame")

        PROP("std::vector<GamepadButton>", "gamepadButtonsPressedThisFrame", "Gamepad buttons pressed this frame")
        PROP("std::vector<GamepadButton>", "gamepadButtonsHeldThisFrame", "Held gamepad buttons")
        PROP("std::unordered_map<GamepadButton,float>", "gamepadHeldButtonDurations", "Hold durations per button")
        PROP("std::vector<GamepadButton>", "gamepadButtonsReleasedThisFrame", "Released gamepad buttons")

        // Input locks
        PROP("bool", "focus_interrupt", "Interrupt focus navigation")
        PROP("std::vector<InputLock>", "activeInputLocks", "Currently active input locks")
        PROP("bool", "inputLocked", "Is global input locked")

        // Axis buttons
        PROP("std::unordered_map<GamepadAxis,AxisButtonState>", "axis_buttons", "Axis-as-button states")

        // Gamepad & cursor config
        PROP("float", "axis_cursor_speed", "Cursor speed from gamepad axis")
        PROP("ButtonRegistry", "button_registry", "Action-to-button mapping")
        PROP("SnapTarget", "snap_cursor_to", "Cursor snap target")

        // CursorContext & HID
        PROP("CursorContext", "cursor_context", "Nested cursor focus contexts")
        PROP("HIDFlags", "hid", "Current HID flags")

        // Gamepad state
        PROP("GamepadState", "gamepad", "Latest gamepad info")
        PROP("float", "overlay_menu_active_timer", "Overlay menu timer")
        PROP("bool", "overlay_menu_active", "Is overlay menu active")
        PROP("ScreenKeyboard", "screen_keyboard", "On-screen keyboard state")

#undef PROP

        // 2) Raylib KeyboardKey enum
        rec.add_type("KeyboardKey");
        auto &kkDef = rec.add_type("KeyboardKey");
        kkDef.doc = "Raylib keyboard key codes";
#define ENUM_PROP(name) rec.record_property("KeyboardKey", {#name, std::to_string(name), "Keyboard key enum"})
        ENUM_PROP(KEY_NULL);
        ENUM_PROP(KEY_APOSTROPHE);
        ENUM_PROP(KEY_COMMA);
        ENUM_PROP(KEY_MINUS);
        ENUM_PROP(KEY_PERIOD);
        ENUM_PROP(KEY_SLASH);
        ENUM_PROP(KEY_ZERO);
        ENUM_PROP(KEY_ONE);
        ENUM_PROP(KEY_TWO);
        ENUM_PROP(KEY_THREE);
        ENUM_PROP(KEY_FOUR);
        ENUM_PROP(KEY_FIVE);
        ENUM_PROP(KEY_SIX);
        ENUM_PROP(KEY_SEVEN);
        ENUM_PROP(KEY_EIGHT);
        ENUM_PROP(KEY_NINE);
        ENUM_PROP(KEY_SEMICOLON);
        ENUM_PROP(KEY_EQUAL);
        ENUM_PROP(KEY_A);
        ENUM_PROP(KEY_B);
        ENUM_PROP(KEY_C);
        ENUM_PROP(KEY_D);
        ENUM_PROP(KEY_E);
        ENUM_PROP(KEY_F);
        ENUM_PROP(KEY_G);
        ENUM_PROP(KEY_H);
        ENUM_PROP(KEY_I);
        ENUM_PROP(KEY_J);
        ENUM_PROP(KEY_K);
        ENUM_PROP(KEY_L);
        ENUM_PROP(KEY_M);
        ENUM_PROP(KEY_N);
        ENUM_PROP(KEY_O);
        ENUM_PROP(KEY_P);
        ENUM_PROP(KEY_Q);
        ENUM_PROP(KEY_R);
        ENUM_PROP(KEY_S);
        ENUM_PROP(KEY_T);
        ENUM_PROP(KEY_U);
        ENUM_PROP(KEY_V);
        ENUM_PROP(KEY_W);
        ENUM_PROP(KEY_X);
        ENUM_PROP(KEY_Y);
        ENUM_PROP(KEY_Z);
        ENUM_PROP(KEY_LEFT_BRACKET);
        ENUM_PROP(KEY_BACKSLASH);
        ENUM_PROP(KEY_RIGHT_BRACKET);
        ENUM_PROP(KEY_GRAVE);
        ENUM_PROP(KEY_SPACE);
        ENUM_PROP(KEY_ESCAPE);
        ENUM_PROP(KEY_ENTER);
        ENUM_PROP(KEY_TAB);
        ENUM_PROP(KEY_BACKSPACE);
        ENUM_PROP(KEY_INSERT);
        ENUM_PROP(KEY_DELETE);
        ENUM_PROP(KEY_RIGHT);
        ENUM_PROP(KEY_LEFT);
        ENUM_PROP(KEY_DOWN);
        ENUM_PROP(KEY_UP);
        ENUM_PROP(KEY_PAGE_UP);
        ENUM_PROP(KEY_PAGE_DOWN);
        ENUM_PROP(KEY_HOME);
        ENUM_PROP(KEY_END);
        ENUM_PROP(KEY_CAPS_LOCK);
        ENUM_PROP(KEY_SCROLL_LOCK);
        ENUM_PROP(KEY_NUM_LOCK);
        ENUM_PROP(KEY_PRINT_SCREEN);
        ENUM_PROP(KEY_PAUSE);
        ENUM_PROP(KEY_F1);
        ENUM_PROP(KEY_F2);
        ENUM_PROP(KEY_F3);
        ENUM_PROP(KEY_F4);
        ENUM_PROP(KEY_F5);
        ENUM_PROP(KEY_F6);
        ENUM_PROP(KEY_F7);
        ENUM_PROP(KEY_F8);
        ENUM_PROP(KEY_F9);
        ENUM_PROP(KEY_F10);
        ENUM_PROP(KEY_F11);
        ENUM_PROP(KEY_F12);
        ENUM_PROP(KEY_LEFT_SHIFT);
        ENUM_PROP(KEY_LEFT_CONTROL);
        ENUM_PROP(KEY_LEFT_ALT);
        ENUM_PROP(KEY_LEFT_SUPER);
        ENUM_PROP(KEY_RIGHT_SHIFT);
        ENUM_PROP(KEY_RIGHT_CONTROL);
        ENUM_PROP(KEY_RIGHT_ALT);
        ENUM_PROP(KEY_RIGHT_SUPER);
        ENUM_PROP(KEY_KB_MENU);
#undef ENUM_PROP

        // 3) MouseButton enum
        rec.add_type("MouseButton");
        rec.record_property("MouseButton", {"MOUSE_BUTTON_LEFT", std::to_string(MOUSE_BUTTON_LEFT), "Left mouse button"});
        rec.record_property("MouseButton", {"MOUSE_BUTTON_RIGHT", std::to_string(MOUSE_BUTTON_RIGHT), "Right mouse button"});
        rec.record_property("MouseButton", {"MOUSE_BUTTON_MIDDLE", std::to_string(MOUSE_BUTTON_MIDDLE), "Middle mouse button"});
        rec.record_property("MouseButton", {"MOUSE_BUTTON_SIDE", std::to_string(MOUSE_BUTTON_SIDE), "Side mouse button"});
        rec.record_property("MouseButton", {"MOUSE_BUTTON_EXTRA", std::to_string(MOUSE_BUTTON_EXTRA), "Extra mouse button"});
        rec.record_property("MouseButton", {"MOUSE_BUTTON_FORWARD", std::to_string(MOUSE_BUTTON_FORWARD), "Forward mouse button"});
        rec.record_property("MouseButton", {"MOUSE_BUTTON_BACK", std::to_string(MOUSE_BUTTON_BACK), "Back mouse button"});

        // 4) GamepadButton enum
        rec.add_type("GamepadButton");
#define GB(name) rec.record_property("GamepadButton", {#name, std::to_string(name), "Gamepad button enum"})
        GB(GAMEPAD_BUTTON_UNKNOWN);
        GB(GAMEPAD_BUTTON_LEFT_FACE_UP);
        GB(GAMEPAD_BUTTON_LEFT_FACE_RIGHT);
        GB(GAMEPAD_BUTTON_LEFT_FACE_DOWN);
        GB(GAMEPAD_BUTTON_LEFT_FACE_LEFT);
        GB(GAMEPAD_BUTTON_RIGHT_FACE_UP);
        GB(GAMEPAD_BUTTON_RIGHT_FACE_RIGHT);
        GB(GAMEPAD_BUTTON_RIGHT_FACE_DOWN);
        GB(GAMEPAD_BUTTON_RIGHT_FACE_LEFT);
        GB(GAMEPAD_BUTTON_LEFT_TRIGGER_1);
        GB(GAMEPAD_BUTTON_LEFT_TRIGGER_2);
        GB(GAMEPAD_BUTTON_RIGHT_TRIGGER_1);
        GB(GAMEPAD_BUTTON_RIGHT_TRIGGER_2);
        GB(GAMEPAD_BUTTON_MIDDLE_LEFT);
        GB(GAMEPAD_BUTTON_MIDDLE);
        GB(GAMEPAD_BUTTON_MIDDLE_RIGHT);
        GB(GAMEPAD_BUTTON_LEFT_THUMB);
        GB(GAMEPAD_BUTTON_RIGHT_THUMB);
#undef GB

        // 5) GamepadAxis enum
        rec.add_type("GamepadAxis");
#define GA(name) rec.record_property("GamepadAxis", {#name, std::to_string(name), "Gamepad axis enum"})
        GA(GAMEPAD_AXIS_LEFT_X);
        GA(GAMEPAD_AXIS_LEFT_Y);
        GA(GAMEPAD_AXIS_RIGHT_X);
        GA(GAMEPAD_AXIS_RIGHT_Y);
        GA(GAMEPAD_AXIS_LEFT_TRIGGER);
        GA(GAMEPAD_AXIS_RIGHT_TRIGGER);
#undef GA

        // 6) InputDeviceInputCategory enum
        rec.add_type("InputDeviceInputCategory");
        rec.record_property("InputDeviceInputCategory", {"NONE", std::to_string((int)InputDeviceInputCategory::NONE), "No input category"});
        rec.record_property("InputDeviceInputCategory", {"GAMEPAD_AXIS_CURSOR", std::to_string((int)InputDeviceInputCategory::GAMEPAD_AXIS_CURSOR), "Axis-driven cursor category"});
        rec.record_property("InputDeviceInputCategory", {"GAMEPAD_AXIS", std::to_string((int)InputDeviceInputCategory::GAMEPAD_AXIS), "Gamepad axis category"});
        rec.record_property("InputDeviceInputCategory", {"GAMEPAD_BUTTON", std::to_string((int)InputDeviceInputCategory::GAMEPAD_BUTTON), "Gamepad button category"});
        rec.record_property("InputDeviceInputCategory", {"MOUSE", std::to_string((int)InputDeviceInputCategory::MOUSE), "Mouse input category"});
        rec.record_property("InputDeviceInputCategory", {"TOUCH", std::to_string((int)InputDeviceInputCategory::TOUCH), "Touch input category"});

        // 7) Simple structs
        rec.add_type("AxisButtonState");
        rec.record_property("AxisButtonState", {"current", "bool", "Is axis beyond threshold this frame?"});
        rec.record_property("AxisButtonState", {"previous", "bool", "Was axis beyond threshold last frame?"});

        rec.add_type("NodeData");
        rec.record_property("NodeData", {"node", "Entity", "UI node entity"});
        rec.record_property("NodeData", {"click", "bool", "Was node clicked?"});
        rec.record_property("NodeData", {"menu", "bool", "Is menu open on node?"});
        rec.record_property("NodeData", {"under_overlay", "bool", "Is node under overlay?"});

        rec.add_type("SnapTarget");
        rec.record_property("SnapTarget", {"node", "Entity", "Target entity to snap cursor to"});
        rec.record_property("SnapTarget", {"transform", "Transform", "Target’s transform"});
        rec.record_property("SnapTarget", {"type", "SnapType", "Snap behavior type"});

        rec.add_type("CursorContext::CursorLayer");
        rec.record_property("CursorContext::CursorLayer", {"cursor_focused_target", "Entity", "Layer’s focused target entity"});
        rec.record_property("CursorContext::CursorLayer", {"cursor_position", "Vector2", "Layer’s cursor position"});
        rec.record_property("CursorContext::CursorLayer", {"focus_interrupt", "bool", "Interrupt flag for this layer"});

        rec.add_type("CursorContext", true);
        rec.record_property("CursorContext", {"layer", "CursorContext::CursorLayer", "Current layer"});
        rec.record_property("CursorContext", {"stack", "std::vector<CursorContext::CursorLayer>", "Layer stack"});

        rec.add_type("GamepadState", true);
        rec.record_property("GamepadState", {"object", "GamepadObject", "Raw gamepad object"});
        rec.record_property("GamepadState", {"mapping", "GamepadMapping", "Button/axis mapping"});
        rec.record_property("GamepadState", {"name", "std::string", "Gamepad name"});
        rec.record_property("GamepadState", {"console", "bool", "Is console gamepad?"});
        rec.record_property("GamepadState", {"id", "int", "System device ID"});

        rec.add_type("HIDFlags");
        rec.record_property("HIDFlags", {"last_type", "InputDeviceInputCategory", "Last HID type used"});
        rec.record_property("HIDFlags", {"dpad_enabled", "bool", "D-pad navigation enabled"});
        rec.record_property("HIDFlags", {"pointer_enabled", "bool", "Pointer input enabled"});
        rec.record_property("HIDFlags", {"touch_enabled", "bool", "Touch input enabled"});
        rec.record_property("HIDFlags", {"controller_enabled", "bool", "Controller navigation enabled"});
        rec.record_property("HIDFlags", {"mouse_enabled", "bool", "Mouse navigation enabled"});
        rec.record_property("HIDFlags", {"axis_cursor_enabled", "bool", "Axis-as-cursor enabled"});

        rec.record_method("ai", {"set_worldstate",
                                 "---@param e Entity\n"
                                 "---@param key string\n"
                                 "---@param value boolean\n"
                                 "---@return nil",
                                 "Sets a single world-state flag on the entity’s current state."});

        rec.record_method("ai", {"set_goal",
                                 "---@param e Entity\n"
                                 "---@param goal table<string,boolean>\n"
                                 "---@return nil",
                                 "Clears the existing goal and sets new goal flags for the entity."});

        rec.record_method("ai", {"patch_worldstate",
                                 "---@param e Entity\n"
                                 "---@param key string\n"
                                 "---@param value boolean\n"
                                 "---@return nil",
                                 "Patches one world-state flag without clearing other flags."});

        rec.record_method("ai", {"patch_goal",
                                 "---@param e Entity\n"
                                 "---@param tbl table<string,boolean>\n"
                                 "---@return nil",
                                 "Patches multiple goal flags without clearing the existing goal."});

        rec.record_method("ai", {"get_blackboard",
                                 "---@param e Entity\n"
                                 "---@return Blackboard",
                                 "Returns the entity’s Blackboard component."});

        rec.record_method("", {"create_ai_entity",
                               "---@param type string\n"
                               "---@param overrides table<string,any>?\n"
                               "---@return Entity",
                               "Spawns a new AI entity of the given type with optional overrides."});

        rec.record_method("ai", {"force_interrupt",
                                 "---@param e Entity\n"
                                 "---@return nil",
                                 "Immediately interrupts the entity’s current GOAP action."});

        rec.record_method("ai", {"list_lua_files",
                                 "---@param dir string\n"
                                 "---@return string[]",
                                 "Lists all Lua files (no extension) in the given scripts directory."});
                   
        // input.bind(actionName, { device="keyboard", key=KeyboardKey.KEY_SPACE, trigger="Pressed", threshold=0.5, modifiers={...}, context="gameplay" })
        in.set_function("bind", [](const std::string &action, sol::table t) {
            auto &s = resolveInputState();
            ActionBinding b;
            b.device = to_device(t.get_or<std::string>("device", "keyboard"));
            b.trigger = to_trigger(t.get_or<std::string>("trigger", "Pressed"));
            b.threshold = t.get_or("threshold", constants::INPUT_BINDING_DEFAULT_THRESHOLD);
            b.context = t.get_or<std::string>("context", "global");
            b.chord_group = t.get_or<std::string>("chord_group", "");

            // code by device
            if (b.device == InputDeviceInputCategory::KEYBOARD) {
                b.code = t.get_or("key", (int)KEY_NULL);
                if (auto mods = t.get<sol::optional<sol::table>>("modifiers"); mods) {
                    for (auto &kv : *mods) b.modifiers.push_back((KeyboardKey)kv.second.as<int>());
                }
            } else if (b.device == InputDeviceInputCategory::MOUSE) {
                b.code = t.get_or("mouse", (int)MOUSE_BUTTON_LEFT);
            } else if (b.device == InputDeviceInputCategory::GAMEPAD_BUTTON) {
                b.code = t.get_or("button", (int)GAMEPAD_BUTTON_RIGHT_FACE_DOWN);
            } else if (b.device == InputDeviceInputCategory::GAMEPAD_AXIS) {
                b.code = t.get_or("axis", (int)GAMEPAD_AXIS_LEFT_X);
            }

            input::bind_action(s, action, b);
        });

        in.set_function("clear", [](const std::string &action) {
            auto& state = resolveInputState();
            input::clear_action(state, action);
        });

        in.set_function("action_pressed",  [](const std::string &a){ auto& s = resolveInputState(); return input::action_pressed (s, a); });
        in.set_function("action_released", [](const std::string &a){ auto& s = resolveInputState(); return input::action_released(s, a); });
        in.set_function("action_down",     [](const std::string &a){ auto& s = resolveInputState(); return input::action_down    (s, a); });
        in.set_function("action_value",    [](const std::string &a){ auto& s = resolveInputState(); return input::action_value   (s, a); });

        in.set_function("set_context", [](const std::string &ctx){
            auto& s = resolveInputState();
            input::set_context(s, ctx);
        });

        // input.start_rebind("Jump", function(ok, binding) ... end)
        in.set_function("start_rebind", [](const std::string &action, sol::function cb) {
            auto &s = resolveInputState();
            input::start_rebind(s, action, [cb](bool ok, const ActionBinding &b) {
                lua_State* L = cb.lua_state();        // raw lua_State*
                sol::state_view sv(L);                // wrap it

                sol::table out = sv.create_table();   // create a table on this state
                out["ok"]        = ok;
                out["device"]    = static_cast<int>(b.device);
                out["code"]      = b.code;
                out["trigger"]   = static_cast<int>(b.trigger);
                out["threshold"] = b.threshold;
                out["context"]   = b.context;

                // modifiers array
                sol::table mods = sv.create_table();
                int i = 1;
                for (auto m : b.modifiers) {
                    mods[i++] = static_cast<int>(m);
                }
                out["modifiers"] = mods;

                // Call back into Lua: (ok, bindingTable)
                cb(ok, out);
            });
        });
        
        rec.record_free_function(inputPath, MethodDef{
            "updateCursorFocus",
            "---@return nil",
            "Update cursor focus based on current input state.",
            /*is_static=*/true,
            /*is_overload=*/false
        });

        // Optional BindingRecorder docs
        
        // input.bind
        rec.record_free_function(inputPath, MethodDef{
            "bind",
            "---@param action string\n"
            "---@param cfg {device:string, key?:integer, mouse?:integer, button?:integer, axis?:integer, trigger?:string, threshold?:number, modifiers?:integer[], context?:string}\n"
            "---@return nil",
            "Bind an action to a device code with a trigger.",
            /*is_static=*/true,
            /*is_overload=*/false
        });

        // input.clear
        rec.record_free_function(inputPath, MethodDef{
            "clear",
            "---@param action string\n---@return nil",
            "Clear all bindings for an action.",
            true, false
        });

        // input.action_pressed
        rec.record_free_function(inputPath, MethodDef{
            "action_pressed",
            "---@param action string\n---@return boolean",
            "True on the frame the action is pressed.",
            true, false
        });

        // input.action_released
        rec.record_free_function(inputPath, MethodDef{
            "action_released",
            "---@param action string\n---@return boolean",
            "True on the frame the action is released.",
            true, false
        });

        // input.action_down
        rec.record_free_function(inputPath, MethodDef{
            "action_down",
            "---@param action string\n---@return boolean",
            "True while the action is held.",
            true, false
        });

        // input.action_value
        rec.record_free_function(inputPath, MethodDef{
            "action_value",
            "---@param action string\n---@return number",
            "Analog value for axis-type actions.",
            true, false
        });

        // input.set_context
        rec.record_free_function(inputPath, MethodDef{
            "set_context",
            "---@param ctx string\n---@return nil",
            "Set the active input context.",
            true, false
        });

        // input.start_rebind
        rec.record_free_function(inputPath, MethodDef{
            "start_rebind",
            "---@param action string\n---@param cb fun(ok:boolean,binding:table)\n---@return nil",
            "Capture the next input event and pass it to callback as a binding table.",
            true, false
        });

    }

}
