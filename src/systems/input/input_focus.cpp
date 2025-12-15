#include "input_focus.hpp"

#include "input.hpp"
#include "input_constants.hpp"
#include "input_function_data.hpp"
#include "input_cursor.hpp"

#include "core/globals.hpp"
#include "core/engine_context.hpp"
#include "core/events.hpp"

#include "systems/transform/transform_functions.hpp"
#include "systems/ui/ui.hpp"
#include "systems/ui/ui_data.hpp"
#include "systems/ui/element.hpp"

#include "spdlog/spdlog.h"
#include "raymath.h"

#include <algorithm>

namespace input {
namespace focus {

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
        // If this node is a key in the active screen keyboard and it's clickable → allow focus.
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
            // If it's a clickable button → allow focus.
            if (uiConfig.buttonCallback)
            {
                return true;
            }
            if (uiConfig.focusArgs)
            {
                // type == "none" → explicitly disables focus.
                // claim_focus_from → another disqualifier.
                // otherwise it's focusable.
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
    auto& bus = ctx ? ctx->eventBus : globals::getEventBus();
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

        if (!focus::IsNodeFocusable(registry, state, state.cursor_focused_target) ||
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

            if (temporaryListOfPotentiallyFocusableNodes.empty() && focus::IsNodeFocusable(registry, state, node_entity))
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

            if (focus::IsNodeFocusable(registry, state, moveable_entity))
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

                // If there's no currently focused target but a valid hovering target, use its focus position.
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

                // Iterates through all focusable nodes and checks if they're valid candidates based on direction.
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
        // Release cursor (this is in input_cursor_events module, need full namespace path from input_functions.cpp)
        // For now, calling through the wrapper in input namespace
        input::ProcessLeftMouseButtonRelease(registry, state, 0, 0, nullptr);
        focus::NavigateFocus(registry, state, (button == xboxXButton) ? "L" : "R"); // Move focus
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
        input::UpdateCursor(state, registry); // Update cursor
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
                        input::SnapToNode(registry, state, choices[nextIndex], {0, 0}); // Snap cursor to new tab
                        input::UpdateCursor(state, registry);                   // Refresh cursor position
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
    focus::UpdateFocusForRelevantNodes(registry, state, dir);

    // Step 2: Update cursor position to match the newly focused entity
    input::UpdateCursor(state, registry);
}

} // namespace focus
} // namespace input
