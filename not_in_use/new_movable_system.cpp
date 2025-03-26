#include "new_movable_system.hpp"

#include <entt/entt.hpp>
#include <glm/glm.hpp>
#include <cmath>
#include <string>
#include <algorithm>
#include <raymath.h>

#include "../util/utilities.hpp"
#include "../components/components.hpp"
#include "../core/globals.hpp"

//TODO: needs fine-tuning, testing, turning to entt


// Additional methods for Moveable

auto init_moveable(entt::registry& registry, int x, int y, int w, int h, entt::entity container) -> entt::entity {
    // Create a new entity in the registry
    entt::entity entity = registry.create();

    Moveable moveable;

    // --The Visible transform is initally set to the same values as the transform T.
    // --Note that the VT has an extra 'scale' factor, this is used to manipulate the center-adjusted
    // --scale of any objects that need to be drawn larger or smaller
   
    moveable.T = {x, y, w, h, 0.0f, 1.0f}; // default rotation 0.0f
    moveable.VT = {x, y, w, h, 0.0f, 1.0f}; // default scale 1.0f

    // Collision transform initialized to the same as main transform
    moveable.CT = moveable.T;

    // Assign a unique ID and determine if created on pause
    // REVIEW: do this with entt
    // ID = G::getInstance().getNextID();
    // created_on_pause = G::getInstance().settings.paused;
    moveable.created_on_pause = game::isPaused;

    // Set container, default to G.ROOM if not specified
    // TODO: create a node instance in globals called room, to indicate the map
    moveable.container = (container == entt::null) ? G_ROOM : container;

    // Default states for visibility and interaction capabilities
    moveable.states.collide.can = false;
    moveable.states.hover.can = true;
    moveable.states.click.can = true;
    moveable.states.drag.can = true;
    moveable.states.release_on.can = true;


    // --To determine location of VT, we need to keep track of the velocity of VT as it approaches T for the next frame
    
    moveable.velocity = {0.0f, 0.0f};
    moveable.angular_velocity = 0.0f;
    moveable.scale_velocity = 0.0f;
    moveable.mag = 0.0f; //REVIEW:  what is this? not sure from the lua code

    // --For more robust drawing, attaching, movement and fewer redundant movement calculations, Moveables each have a 'role'
    // --that describes a heirarchy of move() calls. Any Moveables with 'Major' role type behave normally, essentially recalculating their
    // --VT every frame to ensure smooth movement. Moveables can be set to 'Minor' role and attached to some 'Major' moveable
    // --to weld the Minor moveable to the Major moveable. This makes the dependent moveable set their T and VT to be equal to 
    // --the corresponding 'Major' T and VT, plus some defined offset.
    // --For finer control over what parts of T and VT are inherited, xy_bond, wh_bond, and r_bond can be set to one of
    // --'Strong' or 'Weak'. Strong simply copies the values, Weak allows the 'Minor' moveable to calculate their own.

    moveable.role.role_type = Role::Major;//-Major dictates movement, Minor is welded to some major
    moveable.role.offset = {0.0f, 0.0f}; // --Offset from Minor to Major
    moveable.role.major_entity = entt::null;
    moveable.role.draw_major = entity; // self //TODO: what is this used for?
    moveable.role.xy_bond = Role::Strong; // Bond for position
    moveable.role.wh_bond = Role::Strong; // Bond for width and height (size)
    moveable.role.r_bond = Role::Strong; // Bond for rotation
    moveable.role.scale_bond = Role::Strong; // Bond for scale
    
    moveable.alignment.type = "a"; // --Alignment type
    moveable.alignment.offset = {0.0f, 0.0f}; // --Alignment offset
    moveable.alignment.prev_offset = {0.0f, 0.0f}; // --Previous alignment offset
    moveable.alignment.prev_type = ""; // --Previous alignment type

    // --the pinch table is used to modify the VT.w and VT.h compared to T.w and T.h. If either x or y pinch is
    // --set to true, the VT width and or height will ease to 0. If pinch is false, they ease to T.w or T.h
    moveable.pinch.x = false;
    moveable.pinch.y = false;

    // --Keep track of the last time this Moveable was moved via :move(dt). When it is successfully moved, set to equal
    // --the current G.TIMERS.REAL, and if it is called again this frame, doesn't recalculate move(dt)
    moveable.last_moved = -1.0f;
    moveable.last_aligned = -1.0f;

    moveable.static_rotation = false; // For locking rotation

    // moveable.offset = {0.0f, 0.0f}; // TODO: what is this , doesn't seem to be used in the lua code
    moveable.mid = entity; // for centering veritcally and horizontally on self

    moveable.shadow_parallax = {0.0f, -1.5f}; // For shadow parallax
    moveable.layered_parallax = {0.0f, 0.0f}; // For layered parallax
    moveable.shadow_height = 0.2f; // Shadow height

    calculate_parallax(moveable);

    registry.emplace<Moveable>(entity);

    return entity;
}

// Clamps the Moveable within the room boundaries
void lr_clamp(Moveable& moveable) {
    if (moveable.T.value().x < 0) moveable.T.value().x = 0;
    if (moveable.VT.value().x < 0) moveable.VT.value().x = 0;
    float room_width = G.ROOM.T.value().w;
    if ((moveable.T.value().x + moveable.T.value().w) > room_width)
        moveable.T.value().x = room_width - moveable.T.value().w;
    if ((moveable.VT.value().x + moveable.VT.value().w) > room_width)
        moveable.VT.value().x = room_width - moveable.VT.value().w;
}

// Aligns the Moveable to its major based on alignment settings
void align_to_major(entt::registry& registry, entt::entity entity, Moveable& moveable) {
    // If already aligned this frame, skip
    if (G_TIMER_REAL == moveable.last_aligned) return;
    moveable.last_aligned = G_TIMER_REAL;

    auto& alignment = moveable.alignment;

    // Update type fields if alignment type has changed
    if (alignment.type != alignment.prev_type) {
        alignment.prev_type = alignment.type;

        alignment.align_absolute = (alignment.type == "a");
        alignment.align_middle = (alignment.type.find('m') != std::string::npos);
        alignment.align_center = (alignment.type.find('c') != std::string::npos);
        alignment.align_bottom = (alignment.type.find('b') != std::string::npos);
        alignment.align_top = (alignment.type.find('t') != std::string::npos);
        alignment.align_left = (alignment.type.find('l') != std::string::npos);
        alignment.align_right = (alignment.type.find('r') != std::string::npos);
        alignment.align_inside = (alignment.type.find('i') != std::string::npos);
    }

    // Return if no changes in alignment offset and type
    if (alignment.prev_offset == alignment.offset && alignment.prev_type == alignment.type)
        return;

    moveable.NEW_ALIGNMENT = true;

    // Return if 'a' (absolute) alignment or no major entity to align with
    if (alignment.align_absolute || moveable.role.major_entity == entt::null)
        return;

    auto& major_moveable = registry.get<Moveable>(moveable.role.major_entity);

    auto& mid_movable = registry.get<Moveable>(moveable.mid);

    // Horizontal alignment adjustments
    if (alignment.align_middle) { // Align to middle horizontally
        moveable.role.offset.x = 0.5*major_moveable.T.value().w - (mid_movable.T.value().w)/2 + moveable.alignment.offset.x - mid_movable.T.value().x + moveable.T.value().x;
    } else if (alignment.align_left) { // Align to left
        moveable.role.offset.x = alignment.offset.x;
    } else if (alignment.align_right) { // Align to right
        if (alignment.align_inside) { // Inner right alignment
            moveable.role.offset.x = alignment.offset.x + (major_moveable.T.value().w - moveable.T.value().w);
        } else {
            moveable.role.offset.x = alignment.offset.x + major_moveable.T.value().w;
        }
    }

    // Vertical alignment adjustments
    if (alignment.align_center) { // Align to center vertically
        moveable.role.offset.y = 0.5*major_moveable.T.value().h - (mid_movable.T.value().h)/2 + moveable.alignment.offset.y - mid_movable.T.value().y + moveable.T.value().y;
    } else if (alignment.align_top) { // Align to top
        moveable.role.offset.y = alignment.offset.y;
    } else if (alignment.align_bottom) { // Align to bottom
        if (alignment.align_inside) { // Inner bottom alignment
            moveable.role.offset.y = alignment.offset.y + (major_moveable.T.value().h - moveable.T.value().h);
        } else {
            moveable.role.offset.y = alignment.offset.y + major_moveable.T.value().h;
        }
    }

    // Update the Moveable's transform (T) based on the major's transform and offset
    // moveable.T.position = major_moveable.T.position + moveable.role.offset;
    moveable.T.value().x = major_moveable.T.value().x + moveable.role.offset.x;
    moveable.T.value().y = major_moveable.T.value().y + moveable.role.offset.y;

    // Store the previous alignment offset to avoid redundant calculations
    alignment.prev_offset = alignment.offset;
}


// Hard set the desired transform T and visible transform VT
void hard_set_T(Moveable& moveable, float X, float Y, float W, float H) {
    moveable.T.value().x = X;
    moveable.T.value().y = Y;
    moveable.T.value().w = W;
    moveable.T.value().h = H;

    moveable.velocity = { 0.0f, 0.0f };
    moveable.angular_velocity = 0.0f;
    moveable.scale_velocity = 0.0f;

    moveable.VT = moveable.T;
    calculate_parallax(moveable);
}

void hard_set_VT(Moveable& moveable) {
    moveable.VT = moveable.T;
}

// Apply juice effect to the Moveable
void juice_up(Moveable& moveable, float amount, float rot_amt) {
    if (reduced_motion) return;

    float end_time = G_TIMER_REAL + 0.4f;
    float start_time = G_TIMER_REAL;
    moveable.juice.value().scale = 0.0f;
    moveable.juice.value().scale_amt = amount;
    moveable.juice.value().rotation = 0.0f;
    moveable.juice.value().rotation_amt = (rot_amt != 0.0f) ? rot_amt : ((rand() % 2 == 0) ? 0.6f * amount : -0.6f * amount);
    moveable.juice.value().start_time = start_time;
    moveable.juice.value().end_time = end_time;

    moveable.VT.value().scale = 1.0f - 0.6f * amount;
}

// Move juice effect over time
void move_juice(Moveable& moveable, float dt) {
    if (moveable.juice.value().end_time < G_TIMER_REAL) {
        moveable.juice = {};
    } else {
        float time_since_start = G_TIMER_REAL - moveable.juice.value().start_time;
        float juice_progress = (moveable.juice.value().end_time - G_TIMER_REAL) / (moveable.juice.value().end_time - moveable.juice.value().start_time);

        moveable.juice.value().scale = moveable.juice.value().scale_amt * sin(50.8f * time_since_start) * pow(std::max(0.0f, juice_progress), 3);
        moveable.juice.value().rotation = moveable.juice.value().rotation_amt * sin(40.8f * time_since_start) * pow(std::max(0.0f, juice_progress), 2);
    }
}

// Main move function called each frame
void move(entt::registry& registry, entt::entity entity, Moveable& moveable, float dt) {
    // Frame check, skips move if already processed for the current frame
    if (moveable.FRAME.MOVE >= G_FRAMES_MOVE) return; // TODO: what does FRAMES do?

    // Update frame data
    moveable.FRAME_OLD_MAJOR = moveable.FRAME_MAJOR;
    moveable.FRAME_MAJOR = std::nullopt; //TODO: major must be a optional to something
    moveable.FRAME.MOVE = G_FRAMES_MOVE; // TODO: frame number caching from game.lua in lua file

    // Skip move if paused and not created during a pause
    if (!moveable.created_on_pause && game::isPaused) return; //TODO: created on pause is from node

    // Align to major entity
    align_to_major(registry, entity, moveable);
    moveable.CALCING = false; //TODO: find origins of this variable, could be node or something

    if (moveable.role.role_type == Role::Glued) {
        // For "Glued" role, attach to major if valid
        if (registry.valid(moveable.role.major_entity)) {
            glue_to_major(registry, moveable);
        }
    } else if (moveable.role.role_type == Role::Minor && registry.valid(moveable.role.major_entity)) {
        // If "Minor", ensure the major has also moved for this frame
        auto& major = registry.get<Moveable>(moveable.role.major_entity);
        if (major.FRAME.MOVE < G_FRAMES_MOVE) {
            move(registry, moveable.role.major_entity, major, dt);
        }
        // Stationary state inherited from major, with additional checks for movement
        moveable.STATIONARY = major.STATIONARY;
        if (!moveable.STATIONARY || moveable.NEW_ALIGNMENT /* ||
            moveable.config.refresh_movement */ || moveable.juice || // REVIEW: where does moveable config come from? (moveable.config.refresh_movement seems to be for ui?). Removing for now
            moveable.role.xy_bond == Role::Weak ||
            moveable.role.r_bond == Role::Weak) {
            moveable.CALCING = true;
            move_with_major(registry, entity, dt);
        }
    } else if (moveable.role.role_type == Role::Major) {
        // For "Major" role, perform various movement calculations
        moveable.STATIONARY = true;
        move_juice(moveable, dt);
        move_xy(moveable, dt);
        move_r(moveable, dt);
        move_scale(moveable, dt);
        move_wh(moveable, dt);
        calculate_parallax(moveable);
    }

    // Apply alignment clamp if needed
    if (moveable.alignment.type == "lr_clamp") {
        lr_clamp(moveable);
    }

    // Reset alignment flag
    moveable.NEW_ALIGNMENT = false;
}


// Glue the Moveable to its major entity
void glue_to_major(entt::registry& registry, Moveable& moveable) {
    auto& major_moveable = registry.get<Moveable>(moveable.role.major_entity);

    moveable.T = major_moveable.T;

    moveable.VT.value().x = major_moveable.VT.value().x + 0.5f * (1.0f - major_moveable.VT.value().w / major_moveable.T.value().w) * moveable.T.value().w;
    moveable.VT.value().y = major_moveable.VT.value().y;
    // moveable.VT.size = major_moveable.VT.size;
    moveable.VT.value().w = major_moveable.VT.value().w;
    moveable.VT.value().h = major_moveable.VT.value().h;
    moveable.VT.value().r = major_moveable.VT.value().r;
    moveable.VT.value().scale = major_moveable.VT.value().scale;

    moveable.pinch = major_moveable.pinch;
    moveable.shadow_parallax = major_moveable.shadow_parallax;
}

// Move the Moveable with its major entity
void move_with_major(entt::registry& registry, entt::entity entity, float dt) {
    auto &moveable = registry.get<Moveable>(entity);

    if (moveable.role.role_type != Role::Minor) return;

    auto major_data = get_major(registry, entity);
    auto& major_moveable = registry.get<Moveable>(major_data.value().major_entity);

    move_juice(moveable, dt);

    glm::vec2 rotated_offset = moveable.role.offset + major_data.value().offset;

    if (moveable.role.r_bond == Role::Weak) {
        // Handle weak rotation bond
    } else {
        if (std::abs(major_moveable.VT.value().r) < 0.0001f) {
            // No rotation
        } else {
            float cos_r = std::cos(major_moveable.VT.value().r);
            float sin_r = std::sin(major_moveable.VT.value().r);

            glm::vec2 wh = -0.5f * glm::vec2(moveable.T.value().w, moveable.T.value().h) + 0.5f * glm::vec2(major_moveable.T.value().w, major_moveable.T.value().h);

            // glm::vec2 wh = -0.5f * moveable.T.value().size + 0.5f * major_moveable.T.value().size;
            glm::vec2 offs = moveable.role.offset + major_data.value().offset - wh;

            rotated_offset.x = offs.x * cos_r - offs.y * sin_r + wh.x;
            rotated_offset.y = offs.x * sin_r + offs.y * cos_r + wh.y;
        }
    }

    // moveable.T.position = major_moveable.T.position + rotated_offset;

    moveable.T.value().x = major_moveable.T.value().x + rotated_offset.x;
    moveable.T.value().y = major_moveable.T.value().y + rotated_offset.y;

    if (moveable.role.xy_bond == Role::Strong) {
        // moveable.VT.position = major_moveable.VT.position + rotated_offset;
        moveable.VT.value().x = major_moveable.VT.value().x + rotated_offset.x;
        moveable.VT.value().y = major_moveable.VT.value().y + rotated_offset.y;
    } else if (moveable.role.xy_bond == Role::Weak) {
        move_xy(moveable, dt);
    }

    if (moveable.role.r_bond == Role::Strong) {
        moveable.VT.value().r = moveable.T.value().r + major_moveable.VT.value().r + ((moveable.juice.value().rotation != 0.0f) ? moveable.juice.value().rotation : 0.0f);
    } else if (moveable.role.r_bond == Role::Weak) {
        move_r(moveable, dt);
    }

    if (moveable.role.scale_bond == Role::Strong) {
        moveable.VT.value().scale = moveable.T.value().scale * (major_moveable.VT.value().scale / major_moveable.T.value().scale) + ((moveable.juice.value().scale != 0.0f) ? moveable.juice.value().scale : 0.0f);
    } else if (moveable.role.scale_bond == Role::Weak) {
        move_scale(moveable, dt);
    }

    if (moveable.role.wh_bond == Role::Strong) {
        moveable.VT.value().x += 0.5f * (1.0f - major_moveable.VT.value().w / major_moveable.T.value().w) * moveable.T.value().w;
        moveable.VT.value().w = moveable.T.value().w * (major_moveable.VT.value().w / major_moveable.T.value().w);
        moveable.VT.value().h = moveable.T.value().h * (major_moveable.VT.value().h / major_moveable.T.value().h);
        
    } else if (moveable.role.wh_bond == Role::Weak) {
        move_wh(moveable, dt);
    }

    calculate_parallax(moveable);
}

// Move position
void move_xy(Moveable& moveable, float dt) {
    if ((moveable.T.value().x != moveable.VT.value().x || moveable.T.value().y != moveable.VT.value().x) || (glm::length(moveable.velocity) > 0.01f)) {
        // Calculate velocity using x and y components
        float vel_x = G.exp_times_xy * moveable.velocity.x + (1.0f - G.exp_times_xy) * (moveable.T.value().x - moveable.VT.value().x) * 35.0f * dt;
        float vel_y = G.exp_times_xy * moveable.velocity.y + (1.0f - G.exp_times_xy) * (moveable.T.value().y - moveable.VT.value().x) * 35.0f * dt;
        
        moveable.velocity = { vel_x, vel_y };

        // Limit the velocity if it exceeds the maximum allowed
        if (glm::length(moveable.velocity) > G.exp_times_max_vel) {
            moveable.velocity = glm::normalize(moveable.velocity) * G.exp_times_max_vel;
        }

        moveable.STATIONARY = false;

        // Update VT position using velocity
        moveable.VT.value().x += moveable.velocity.x;
        moveable.VT.value().x += moveable.velocity.y;

        // Check if the VT position is close enough to T position and the velocity is low enough to stop
        if (std::abs(moveable.VT.value().x - moveable.T.value().x) < 0.01f && std::abs(moveable.VT.value().x - moveable.T.value().y) < 0.01f && glm::length(moveable.velocity) < 0.01f) {
            moveable.VT.value().x = moveable.T.value().x;
            moveable.VT.value().x = moveable.T.value().y;
            moveable.velocity = { 0.0f, 0.0f };
        }
    }
}


// Move scale
void move_scale(Moveable& moveable, float dt) {
    float des_scale = moveable.T.value().scale + ((moveable.dragging ? 0.1f : 0.0f) + (moveable.juice.value().scale != 0.0f ? moveable.juice.value().scale : 0.0f));
    if ((des_scale != moveable.VT.value().scale) || (std::abs(moveable.scale_velocity) > 0.001f)) {
        moveable.STATIONARY = false;
        moveable.scale_velocity = G.exp_times_scale * moveable.scale_velocity + (1.0f - G.exp_times_scale) * (des_scale - moveable.VT.value().scale);
        moveable.VT.value().scale += moveable.scale_velocity;
    }
}

// Move width and height
// Move width and height
void move_wh(Moveable& moveable, float dt) {
    if (((moveable.T.value().w != moveable.VT.value().w || moveable.T.value().h != moveable.VT.value().h) && !moveable.pinch.x && !moveable.pinch.y) ||
        (moveable.VT.value().w > 0.0f && moveable.pinch.x) ||
        (moveable.VT.value().h > 0.0f && moveable.pinch.y)) {
        moveable.STATIONARY = false;
        float delta = 8.0f * dt;

        // Update width and height with respective pinch checks
        moveable.VT.value().w += delta * (moveable.pinch.x ? -1.0f : 1.0f) * moveable.T.value().w;
        moveable.VT.value().h += delta * (moveable.pinch.y ? -1.0f : 1.0f) * moveable.T.value().h;

        // Clamp the width and height to ensure they stay within valid bounds
        moveable.VT.value().w = std::clamp(moveable.VT.value().w, 0.0f, moveable.T.value().w);
        moveable.VT.value().h = std::clamp(moveable.VT.value().h, 0.0f, moveable.T.value().h);
    }
}


// Move rotation
void move_r(Moveable& moveable, float dt) {
    float des_r = moveable.T.value().r + 0.015f * moveable.velocity.x / dt + ((moveable.juice.value().rotation != 0.0f) ? moveable.juice.value().rotation * 2.0f : 0.0f);

    if ((des_r != moveable.VT.value().r) || (std::abs(moveable.angular_velocity) > 0.001f)) {
        moveable.STATIONARY = false;
        moveable.angular_velocity = G.exp_times_r * moveable.angular_velocity + (1.0f - G.exp_times_r) * (des_r - moveable.VT.value().r);
        moveable.VT.value().r += moveable.angular_velocity;
        if (std::abs(moveable.VT.value().r - moveable.T.value().r) < 0.001f && std::abs(moveable.angular_velocity) < 0.001f) {
            moveable.VT.value().r = moveable.T.value().r;
            moveable.angular_velocity = 0.0f;
        }
    }
}

// Calculate parallax effects
void calculate_parallax(Moveable& moveable) {
    if (G.ROOM.T.value().w == 0.0f) return;
    moveable.shadow_parallax.x = (moveable.T.value().x + 0.5f * moveable.T.value().w - 0.5f * G.ROOM.T.value().w) / (0.5f * G.ROOM.T.value().w) * 1.5f;
}

// Set role of the Moveable
void set_role(Moveable& moveable, const Role& new_role) {
    moveable.role = new_role;
    if (moveable.role.role_type == Role::Major) {
        moveable.role.major_entity = entt::null;
    }
}

// Get the major Moveable recursively
//TODO: figure this part out
// C++ get_major function based on Lua
// entity is the current entity to get the major of
auto get_major(entt::registry& registry, entt::entity entity) -> std::optional<MajorData>{
    auto& moveable = registry.get<Moveable>(entity);
    if (moveable.role.role_type != Role::Major && 
        moveable.role.major_entity != entt::null &&
        moveable.role.xy_bond != Role::Weak && 
        moveable.role.r_bond != Role::Weak) {
        
        // Check if FRAME_MAJOR needs refresh
        if (!moveable.FRAME_MAJOR_CACHE_REFRESH) { //TODO: not sure where this should be set. It is done in ui.lua in balatro
            // Initialize FRAME_MAJOR and clear temp offsets if needed
            moveable.FRAME_MAJOR = MajorData();
            moveable.temp_offs = glm::vec2(0.0f, 0.0f);

            // Recursive call to get the deepest major
            auto major_data = get_major(registry, moveable.role.major_entity);

            // Update FRAME_MAJOR with calculated offset
            moveable.FRAME_MAJOR.value().major_entity = major_data.value().major_entity;
            moveable.FRAME_MAJOR.value().offset = major_data.value().offset + moveable.role.offset + moveable.layered_parallax;
        }

        // Return cached FRAME_MAJOR data
        return moveable.FRAME_MAJOR;
    } else {
        // Fallback case: use ARGS for temporary data
        moveable.ARGS.get_major.major_entity = entity; // Self entity
        moveable.ARGS.get_major.offset = {0.0f, 0.0f};
        return moveable.ARGS.get_major;
    }
}

// Remove the Moveable from the registry
void remove(entt::registry& registry, entt::entity entity) {

    auto &moveable = registry.get<Moveable>(entity);

    //TODO: remove with entt, not this way

    // auto &globalList = G::getInstance();
    // globalList.removeNode(this);

    for (auto &child : moveable.children)
    {
        remove(registry, child);
    }
    moveable.children.clear();

    // TODO: create this controller input thingy from controller.lua
    // TODO: this has to be done after input system is implemented, I think?
    // if (G::controller.clicked.target == this)
    //     G::controller.clicked.target = nullptr;
    // if (G::controller.focused.target == this)
    //     G::controller.focused.target = nullptr;
    // if (G::controller.dragging.target == this)
    //     G::controller.dragging.target = nullptr;
    // if (G::controller.hovering.target == this)
    //     G::controller.hovering.target = nullptr;
    // TODO: compare with entt id later

    moveable.REMOVED = true;


    registry.destroy(entity);
}




// Draws the bounding rectangle of the Node for debugging purposes
void drawBoundingRect(Moveable& moveable)
{
    if (moveable.debug)
    { // Only draw if debugging is enabled
        // TransformCustom &transform = (VT != nullptr) ? *VT : T; //TODO: is VT from movable?
        TransformCustom &transform = (moveable.VT.has_value()) ? moveable.VT.value() : moveable.T.value(); //TODO: is VT from movable?

        BeginMode2D(camera); // Begin 2D mode for transformations

        // Calculate the position, adjusting for scaling and translation
        // TODO: replace G_TILESIZE with my own tile size, get it from conig?
        Vector2 position{transform.x * G_TILESIZE + transform.w * G_TILESIZE * 0.5f,
                         transform.y * G_TILESIZE + transform.h * G_TILESIZE * 0.5f};
        Vector2 offset{transform.w * G_TILESIZE * 0.5f, transform.h * G_TILESIZE * 0.5f};
        position = Vector2Subtract(position, offset);

        // Line width and color vary based on state (e.g., focus, collision)
        int lineWidth = (moveable.states.focus.is) ? 2 : 1;
        Color lineColor = (moveable.states.collide.is) ? Color{0, 255, 0, 77} : Color{255, 0, 0, 77};

        if (moveable.states.focus.can)
        {
            lineColor = util::getColor("GOLD");
            lineWidth = 1;
        }
        if (moveable.CALCING)
        {
            lineColor = BLUE;
            lineWidth = 3;
        }

        // Draw rectangle with calculated properties
        DrawRectangleLinesEx(
            {position.x, position.y, transform.w * G_TILESIZE, transform.h * G_TILESIZE},
            lineWidth, lineColor);

        // Draw debug text if DEBUG_VALUE exists
        if (moveable.DEBUG_VALUE)
        {
            DrawText(moveable.DEBUG_VALUE.value().c_str(), position.x + transform.w * G_TILESIZE,
                     position.y + transform.h * G_TILESIZE, 10, YELLOW);
        }

        EndMode2D(); // End 2D mode
    }
}

// Draws the Node, including the bounding rectangle and all children
void draw(entt::entity entity)
{
    auto &moveable = registry.get<Moveable>(entity);
    drawBoundingRect(moveable);
    if (moveable.states.visible)
    {   // Only draw if visible
        // TODO: use a marker component (NodeDrawMarker) to indicate that the node should be drawn
        // TODO: draw via a system that draws all nodes with the marker
        // addToDrawHash(this); // don't need this function in c++

        // Draw each child Node recursively
        for (entt::entity child : moveable.children)
        {
            draw(child); //TODO: major/minor should probably be a component marker
        }
    }
}

// Checks if a given point (pointX, pointY) collides with the Node, considering container transformations
bool collidesWithPoint(Moveable &moveable, float pointX, float pointY)
{
    // if (!container)
    if (moveable.container == entt::null)
        return false;

    // TransformCustom &T = (CT != nullptr) ? *CT : this->T;
    TransformCustom &T = (moveable.CT.has_value()) ? moveable.CT.value() : moveable.T.value(); 

    // TODO: use the draw marker component to tell if the node should be checked for collision outside this method
    auto &containerMoveable = registry.get<Moveable>(moveable.container);
    
    Vector2 point = {pointX, pointY};
    Vector2 translation = {containerMoveable.T.value().x, containerMoveable.T.value().y};
    float containerRotation = containerMoveable.T.value().r;
    float buffer = (moveable.states.hover.is) ? G_COLLISION_BUFFER : 0; 

    // Translate and rotate the point into local container space
    point.x -= translation.x;
    point.y -= translation.y;

    if (fabs(containerRotation) >= 0.1f)
    {
        float cosTheta = cos(-containerRotation);
        float sinTheta = sin(-containerRotation);

        float rotatedX = cosTheta * point.x - sinTheta * point.y;
        float rotatedY = sinTheta * point.x + cosTheta * point.y;

        point.x = rotatedX;
        point.y = rotatedY;
    }

    // Apply Node's own rotation if necessary
    float nodeRotation = T.r;
    if (fabs(nodeRotation) >= 0.1f)
    {
        float cosTheta = cos(-nodeRotation);
        float sinTheta = sin(-nodeRotation);

        point.x -= T.x + T.w * 0.5f;
        point.y -= T.y + T.h * 0.5f;

        float rotatedX = cosTheta * point.x - sinTheta * point.y;
        float rotatedY = sinTheta * point.x + cosTheta * point.y;

        point.x = rotatedX + T.x + T.w * 0.5f;
        point.y = rotatedY + T.y + T.h * 0.5f;
    }

    // Check if point is within Node bounds with buffer
    return (point.x >= T.x - buffer && point.x <= T.x + T.w + buffer &&
            point.y >= T.y - buffer && point.y <= T.y + T.h + buffer);
}

// Sets an offset for the Node based on a point and interaction type ("click" or "hover")
void setOffset(Moveable& moveable, const Vector2 &point, const std::string &type)
{
    Vector2 localPoint = point;

    auto &containerMoveable = registry.get<Moveable>(moveable.container);

    Vector2 translation = {-containerMoveable.T.value().w / 2, -containerMoveable.T.value().h / 2};
    localPoint = Vector2Add(localPoint, translation);

    if (moveable.container != entt::null)
    {
        float cosTheta = cosf(-containerMoveable.T.value().r);
        float sinTheta = sinf(-containerMoveable.T.value().r);

        float rotatedX = cosTheta * localPoint.x - sinTheta * localPoint.y;
        float rotatedY = sinTheta * localPoint.x + cosTheta * localPoint.y;

        localPoint.x = rotatedX;
        localPoint.y = rotatedY;
    }

    translation = {containerMoveable.T.value().w / 2 - containerMoveable.T.value().x, containerMoveable.T.value().h / 2 - containerMoveable.T.value().y};
    localPoint = Vector2Add(localPoint, translation);

    if (type == "click")
    {
        moveable.click_offset.x = localPoint.x - moveable.T.value().x;
        moveable.click_offset.y = localPoint.y - moveable.T.value().y;
        
        // {localPoint.x - T.value().x, localPoint.y - T.value().y};
    }
    else if (type == "hover")
    {
        // hover_offset = {localPoint.x - T.value().x, localPoint.y - T.value().y};
        moveable.hover_offset.x = localPoint.x - moveable.T.value().x;
        moveable.hover_offset.y = localPoint.y - moveable.T.value().y;
    }
}

// Removes the Node from various lists and clears references
void remove()
{
    
}

// Calculates squared distance from this Node to the center of another Node
float fastMidDist(const Moveable& node, const Moveable &otherNode)
{
    float dx = (otherNode.T.value().x + 0.5f * otherNode.T.value().w) - (node.T.value().x + 0.5f * node.T.value().w);
    float dy = (otherNode.T.value().y + 0.5f * otherNode.T.value().h) - (node.T.value().y + 0.5f * node.T.value().h);
    return dx * dx + dy * dy;
}

//TODO: set_role needs to be looked at
// auto set_role(entt::registry& registry, entt::entity entity, const RoleArgs &roleArgs) -> void {

//     auto &moveable = registry.get<Moveable>(entity);

//     auto &role = moveable.role;

//     // Check if args.major has a valid role pointer
//     if (roleArgs.major && !roleArgs.major.value()->set_role) return;

//     // Check if args.offset is a valid glm::vec2
//     if (roleArgs.offset && (!roleArgs.offset->y && !roleArgs.offset->x)) {
//         role.offset = std::nullopt;  // Reset offset if invalid
//     } else {
//         role.offset = roleArgs.offset.value_or(role.offset);
//     }

//     // Set role properties, falling back to existing role values if not provided
//     role.role_type = roleArgs.role_type.value_or(role.role_type);
//     role.major = roleArgs.major.value_or(role.major);
//     role.xy_bond = roleArgs.xy_bond.value_or(role.xy_bond);
//     role.wh_bond = roleArgs.wh_bond.value_or(role.wh_bond);
//     role.r_bond = roleArgs.r_bond.value_or(role.r_bond);
//     role.scale_bond = roleArgs.scale_bond.value_or(role.scale_bond);
//     role.draw_major = roleArgs.draw_major.value_or(role.draw_major);

//     // If role_type is 'Major', remove the major reference
//     if (role.role_type == Role::Type::Major) {
//         role.major_entity = entt::null;
//     }
// }

//TODO: put all new classes into their own namespace