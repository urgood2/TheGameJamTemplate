#include "input_cursor.hpp"
#include "input_functions.hpp"

#include "raylib.h"
#include "raymath.h"
#include "entt/entt.hpp"
#include "spdlog/spdlog.h"

#include "core/globals.hpp"
#include "systems/camera/camera_manager.hpp"
#include "systems/transform/transform_functions.hpp"
#include "systems/main_loop_enhancement/main_loop.hpp"
#include "systems/ui/ui_data.hpp"

using namespace snowhouse; // assert

namespace input::cursor {

    void set_current_position(entt::registry &registry, InputState &state)
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

    void modify_context_layer(entt::registry &registry, InputState &state, int delta)
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
        input::NavigateFocus(registry, state);
    }

    void snap_to_node(entt::registry &registry, InputState &state, entt::entity node, const Vector2 &transform)
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

    void update(InputState &state, entt::registry &registry, std::optional<Vector2> hardSetT)
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

    void mark_entities_colliding(entt::registry &registry, InputState &state, const Vector2 &cursor_trans)
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

    void update_hovering_state(entt::registry &registry, InputState &state)
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

    void handle_raw(InputState &inputState, entt::registry &registry)
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
        set_current_position(registry, inputState);
    }

    void process_controller_snap(InputState &inputState, entt::registry &registry)
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
                snap_to_node(registry, inputState, snapTarget, context.cursor_position);
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
                    snap_to_node(registry, inputState, inputState.cursor_prev_dragging_target);
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
                    update(inputState, registry);
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

} // namespace input::cursor
