/**
 * @file input_functions.cpp
 * @brief Input system orchestrator - coordinates all input modules
 *
 * This file serves as the main entry point for the input system.
 * Actual logic is delegated to specialized modules:
 * - input_polling: Raw input polling and Raylib abstraction
 * - input_keyboard: Keyboard and text input
 * - input_gamepad: Gamepad buttons and axes
 * - input_cursor: Cursor position and collision
 * - input_cursor_events: Click/drag/hover propagation
 * - input_focus: Focus navigation
 * - input_actions: Action binding system
 * - input_hid: HID device switching
 * - input_lua_bindings: Lua API exposure
 */

#include "input_functions.hpp"
#include "input_lua_bindings.hpp"
#include "input_keyboard.hpp"
#include "input_gamepad.hpp"
#include "input_hid.hpp"
#include "input_cursor.hpp"
#include "input_cursor_events.hpp"
#include "input_focus.hpp"
#include "input_polling.hpp"
#include "input_actions.hpp"
#include "input_constants.hpp"
#include "input_function_data.hpp"

#include "raylib.h"
#include "entt/entt.hpp"

#include "systems/collision/broad_phase.hpp"
#include "systems/transform/transform_functions.hpp"
#include "systems/main_loop_enhancement/main_loop.hpp"
#include "systems/ui/ui.hpp"
#include "systems/ui/ui_data.hpp"
#include "systems/ui/element.hpp"
#include "systems/timer/timer.hpp"
#include "core/globals.hpp"
#include "core/engine_context.hpp"

#include <algorithm>
#include <vector>

using namespace snowhouse; // assert

namespace input
{
    // ========================================
    // Context Resolution Helpers
    // ========================================

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

    // ========================================
    // System Initialization
    // ========================================

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

    // ========================================
    // Text Input Handling
    // ========================================

    void HandleTextInput(ui::TextInput &input) {
        keyboard::handle_text_input(input);
    }

    // ========================================
    // Main Update Loop - Orchestration
    // ========================================

    auto PollInput(entt::registry &registry, InputState &inputState, float dt, EngineContext* ctx) -> void
    {
        polling::poll_all_inputs(registry, inputState, dt, ctx);
    }

    auto handleRawInput(entt::registry &registry, InputState &inputState, float dt, EngineContext* ctx) -> void
    {
        PollInput(registry, inputState, dt, ctx);

        ProcessInputLocks(inputState, registry, dt);

        DeleteInvalidEntitiesFromInputRegistry(inputState, registry);
        

    }

    auto DetectMouseActivity(InputState &state) -> InputDeviceInputCategory
    {
        return polling::detect_mouse_activity(state);
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
            hid::reconfigure_device_info(registry, inputState, finalCategory);
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
        cursor_events::propagate_right_clicks(registry, inputState);
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

    void finalizeUpdateAtEndOfFrame(InputState &inputState, float dt) {
        TickActionHolds(inputState, dt);
        DecayActions(inputState);
    }

    // ========================================
    // Cursor Event Propagation - Delegation
    // ========================================

    void stopHover(entt::registry &registry, entt::entity target)
    {
        cursor_events::stop_hover(registry, target);
    }

    void propagateReleaseToGameObjects(input::InputState &inputState, entt::registry &registry)
    {
        cursor_events::propagate_release(inputState, registry);
    }
    
    

    void propagateDragToGameObjects(entt::registry &registry, input::InputState &inputState)
    {
        cursor_events::propagate_drag(registry, inputState);
    }

    void hoverDragSimultaneousCheck(entt::registry &registry, input::InputState &inputState)
    {
        cursor_events::hover_drag_check(registry, inputState);
    }

    void propagateClicksToGameObjects(entt::registry &registry, input::InputState &inputState)
    {
        cursor_events::propagate_clicks(registry, inputState);
    }

    void handleCursorHoverEvent(InputState &inputState, entt::registry &registry)
    {
        cursor_events::handle_hover_event(inputState, registry);
    }


    

    void handleCursorReleasedEvent(input::InputState &inputState, entt::registry &registry)
    {
        cursor_events::handle_released_event(inputState, registry);
    }

    void handleCursorDownEvent(entt::registry &registry, input::InputState &inputState)
    {
        cursor_events::handle_down_event(registry, inputState);
    }

    void processRaylibLeftClick(input::InputState &inputState, entt::registry &registry)
    {
        cursor_events::process_raylib_click(inputState, registry);
    }

    // ========================================
    // Input State Management
    // ========================================

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

    // ========================================
    // Cursor Position Management - Delegation
    // ========================================

    void handleRawCursor(input::InputState &inputState, entt::registry &registry)
    {
        cursor::handle_raw(inputState, registry);
    }

    void ProcessControllerSnapToObject(input::InputState &inputState, entt::registry &registry)
    {
        cursor::process_controller_snap(inputState, registry);
    }

    // ========================================
    // Button/Key Press Propagation
    // ========================================

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

    // ========================================
    // Input Lock Management
    // ========================================

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
        auto it = inputState.activeInputLocks.find("frame_lock_reset_next_frame");
        if (it != inputState.activeInputLocks.end() && it->second)
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

    // ========================================
    // HID Management - Wrappers
    // ========================================

    auto ReconfigureInputDeviceInfo(entt::registry &registry, InputState &state, InputDeviceInputCategory category, GamepadButton button) -> void
    {
        hid::reconfigure_device_info(registry, state, category, button);
    }

    auto UpdateUISprites(const std::string &console_type) -> void
    {
        hid::update_ui_sprites(console_type);
    }

    auto SetCurrentGamepad(InputState &state, const std::string &gamepad_object, int gamepadID) -> void
    {
        hid::set_current_gamepad(state, gamepad_object, gamepadID);
    }

    // ========================================
    // Input Registry Management
    // ========================================

    auto SetCurrentCursorPosition(entt::registry &registry, InputState &state) -> void
    {
        cursor::set_current_position(registry, state);
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

    // ========================================
    // Cursor Manipulation - Wrappers
    // ========================================

    auto ModifyCurrentCursorContextLayer(entt::registry &registry, InputState &state, int delta) -> void
    {
        cursor::modify_context_layer(registry, state, delta);
    }

    auto SnapToNode(entt::registry &registry, InputState &state, entt::entity node, const Vector2 &transform) -> void
    {
        cursor::snap_to_node(registry, state, node, transform);
    }

    auto UpdateCursor(InputState &state, entt::registry &registry, std::optional<Vector2> hardSetT) -> void
    {
        cursor::update(state, registry, hardSetT);
    }

    // ========================================
    // Gamepad Input - Wrappers
    // ========================================

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

    void ReleasedButtonUpdate(entt::registry &registry, InputState &state, const GamepadButton button, float dt)
    {
        gamepad::released_button_update(registry, state, button, dt);
    }

    // ========================================
    // Keyboard Input - Wrappers
    // ========================================

    char GetCharacterFromKey(KeyboardKey key, bool caps)
    {
        return keyboard::get_character_from_key(key, caps);
    }

    void ProcessTextInput(entt::registry &registry, entt::entity entity, KeyboardKey key, bool shift, bool capsLock)
    {
        keyboard::process_text_input(registry, entity, key, shift, capsLock);
    }

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

    // ========================================
    // Collision Detection - Wrappers
    // ========================================

    void MarkEntitiesCollidingWithCursor(entt::registry &registry, InputState &state, const Vector2 &cursor_trans)
    {
        cursor::mark_entities_colliding(registry, state, cursor_trans);
    }

    void UpdateCursorHoveringState(entt::registry &registry, InputState &state)
    {
        cursor::update_hovering_state(registry, state);
    }

    // ========================================
    // Mouse Event Queueing - Wrappers
    // ========================================

    void EnqueueLeftMouseButtonPress(InputState &state, float x, float y)
    {
        cursor_events::enqueue_left_press(state, x, y);
    }

    // save press to be handled by update() function
    void EnqueRightMouseButtonPress(InputState &state, float x, float y)
    {
        cursor_events::enqueue_right_press(state, x, y);
    }

    // called by update() function
    void ProcessLeftMouseButtonPress(entt::registry &registry, InputState &state, float x, float y)
    {
        cursor_events::process_left_press(registry, state, x, y);
    }

    // called by update() function
    void ProcessLeftMouseButtonRelease(entt::registry &registry, InputState &state, float x, float y, EngineContext* ctx)
    {
        cursor_events::process_left_release(registry, state, x, y, ctx);
    }

    // ========================================
    // Focus Management - Wrappers
    // ========================================

    bool IsNodeFocusable(entt::registry &registry, InputState &state, entt::entity entity)
    {
        return focus::IsNodeFocusable(registry, state, entity);
    }

    // focus only works for controller input, when focus interrupt is not enabled, and when the game is not paused, and the input isn't locked.
    void UpdateFocusForRelevantNodes(entt::registry &registry, InputState &state, std::optional<std::string> dir, EngineContext* ctx)
    {
        focus::UpdateFocusForRelevantNodes(registry, state, dir, ctx);
    }

    void NavigateFocus(entt::registry &registry, InputState &state, std::optional<std::string> dir)
    {
        // Step 1: Update focus based on direction (or nearest focusable entity if no direction)
        UpdateFocusForRelevantNodes(registry, state, dir);

        // Step 2: Update cursor position to match the newly focused entity
        UpdateCursor(state, registry);
    }

    // ========================================
    // Focus Input Capture (Legacy)
    // ========================================

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
            state.gamepadHeldButtonDurations.count(xboxAButton) && state.gamepadHeldButtonDurations[xboxAButton] != 0 && state.gamepadHeldButtonDurations[xboxAButton] < constants::BUTTON_HOLD_COYOTE_TIME &&
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

    // ========================================
    // Action System - Wrappers
    // ========================================

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

    // ========================================
    // Lua Bindings - Delegation
    // ========================================

    auto exposeToLua(sol::state &lua, EngineContext* ctx) -> void
    {
        lua_bindings::expose_to_lua(lua, ctx);
    }

} // namespace input
