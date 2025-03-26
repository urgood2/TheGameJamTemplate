#pragma once

#include <entt/entt.hpp>
#include <glm/glm.hpp>
#include <string>
#include <functional>
#include <algorithm>

#include "../components/components.hpp"


struct G {
    struct {
        std::optional<TransformCustom> T; // Room Transform
    } ROOM;
    static constexpr float exp_times_xy = 0.9f; //TODO: what are these?
    static constexpr float exp_times_scale = 0.9f;
    static constexpr float exp_times_r = 0.9f;
    static constexpr float exp_times_max_vel = 10.0f;
} G;

// MajorData struct holds entity and offset data
struct MajorData {
    entt::entity major_entity = entt::null;
    glm::vec2 offset{0.0f, 0.0f};
};

// ARGS equivalent for temporary storage
struct Args {
    MajorData get_major; // Holds temporary MajorData for get_major
    glm::vec2 drag_cursor_trans{0.0f, 0.0f}; // For drag
    glm::vec2 drag_translation{0.0f, 0.0f};  // For drag
};

// Role hierarchy: Major or Minor

// --For more robust drawing, attaching, movement and fewer redundant movement calculations, Moveables each have a 'role'
// --that describes a heirarchy of move() calls. Any Moveables with 'Major' role type behave normally, essentially recalculating their
// --VT every frame to ensure smooth movement. Moveables can be set to 'Minor' role and attached to some 'Major' moveable
// --to weld the Minor moveable to the Major moveable. This makes the dependent moveable set their T and VT to be equal to 
// --the corresponding 'Major' T and VT, plus some defined offset.
// --For finer control over what parts of T and VT are inherited, xy_bond, wh_bond, and r_bond can be set to one of
// --'Strong' or 'Weak'. Strong simply copies the values, Weak allows the 'Minor' moveable to calculate their own.

struct Role {
    enum Type { Major, Minor, Glued };
    Type role_type = Major; // --Major dictates movement, Minor is welded to some major
    glm::vec2 offset{0, 0};   // --Offset from Minor to Major
    entt::entity major_entity{entt::null}; // Reference to the Major entity

    enum BondType { Strong, Weak };
    BondType xy_bond = Strong;     // Bond for position
    BondType wh_bond = Strong;     // Bond for width and height (size)
    BondType r_bond = Strong;      // Bond for rotation
    BondType scale_bond = Strong;  // Bond for scale

    entt::entity draw_major{entt::null}; // Entity to draw as major
};



// Alignment component to manage how entities align to each other.
struct Alignment {
    std::string type = "a";               // Current alignment type (default: "a" for absolute)
    glm::vec2 offset{0, 0};               // Offset for the alignment
    glm::vec2 prev_offset{0, 0};          // Previous offset, used to detect changes in alignment
    std::string prev_type = "";           // Previous alignment type, to check if type has changed

    // Explicit alignment flags to replace type_list
    bool align_absolute = true;           // 'a': absolute alignment
    bool align_middle = false;            // 'm': center horizontally
    bool align_center = false;            // 'c': center vertically
    bool align_bottom = false;            // 'b': align to bottom
    bool align_top = false;               // 't': align to top
    bool align_left = false;              // 'l': align to left
    bool align_right = false;             // 'r': align to right
    bool align_inside = false;            // 'i': internal alignment for boundaries

    // Reset alignment flags based on type
    void update_flags() {
        align_absolute = (type == "a");
        align_middle = (type.find('m') != std::string::npos);
        align_center = (type.find('c') != std::string::npos);
        align_bottom = (type.find('b') != std::string::npos);
        align_top = (type.find('t') != std::string::npos);
        align_left = (type.find('l') != std::string::npos);
        align_right = (type.find('r') != std::string::npos);
        align_inside = (type.find('i') != std::string::npos);
    }
};

// Pinching properties for scaling objects down
struct Pinch {
    bool x = false;  // Pinch along X-axis
    bool y = false;  // Pinch along Y-axis
};

// For visual effects (bounce/scale/rotation juice)
struct Juice {
    float scale = 0.0f;
    float scale_amt = 0.0f;      // Amount to scale up or down
    float rotation = 0.0f;
    float rotation_amt = 0.0f;   // Amount to rotate
    float start_time = 0.0f;
    float end_time = 0.0f;
    bool handled_elsewhere = false; // If handled elsewhere in the code: The handled_elsewhere flag in this code is used in the Moveable:move_juice method. When handled_elsewhere is set to true, it prevents the Moveable object from processing its own "juice" effect independently. Here's what it does in detail:
    // Moveable:move_juice Check: The move_juice method first checks if self.juice exists and if self.juice.handled_elsewhere is true. If handled_elsewhere is true, the method skips over the rest of the animation processing and doesn’t apply any "juice" effect directly to this instance.
    // External Handling: When handled_elsewhere is true, it signals that another part of the code (potentially a parent object, a controller, or an animation manager) is responsible for controlling or managing the "juice" effect, which includes the scale or rotation transformations of Moveable. This allows for flexibility, where some instances might rely on a shared system or centralized logic to control their effects.
    // Juice Reset Timing: If handled_elsewhere is false (or unset), move_juice will perform its usual updates, animating the scale and rotation (r) values based on the timing (start_time and end_time). This includes easing out the effect as end_time approaches, after which self.juice is removed.
};

struct State {
    bool visible = true;
    struct {
        bool can = false;
        bool is = false;
    } collide, focus, hover, click, drag, release_on;
};

// Moveable struct that includes movement, velocity, and role management.
struct Moveable {

    entt::entity container; // container (parent?) entity
    State states; //
    std::vector<entt::entity> children; // different from major/minor, this is for children of the entity

    std::optional<TransformCustom> T;  // Desired transform
    std::optional<TransformCustom> VT; // Visible transform (eases toward T)
    std::optional<TransformCustom> CT; // Collision transform 

    std::unordered_map<std::string, int> config; // Configurations for the noode? REVIEW: not sure what this does

    bool created_on_pause = false; // Created during pause (FIXME: this is from Node, need to combine)

    // --To determine location of VT, we need to keep track of the velocity of VT as it approaches T for the next frame
    glm::vec2 velocity{0, 0}; // Velocity of VT easing to T
    float angular_velocity{0.0f}; // Rotation velocity
    float scale_velocity{0.0f};   // Scale velocity
    float mag{0.0f};              // Magnitude velocity (optional control)

    Args ARGS; // Temporary storage for various arguments

    Role role; // Role of the Moveable

    Alignment alignment; // Alignment component

    Pinch pinch; // Pinch properties for scaling

    std::optional<Juice> juice; // Juice properties for bounce/scale/rotation effects

    std::optional<MajorData> FRAME_MAJOR; // For frame-based caching of major data
    bool FRAME_MAJOR_CACHE_REFRESH = false; // Refresh flag
    std::optional<MajorData> FRAME_OLD_MAJOR; // Old major data for tracking changes

    // --the pinch table is used to modify the VT.value().w and VT.value().h compared to T.value().w and T.value().h. If either x or y pinch is
    // --set to true, the VT width and or height will ease to 0. If pinch is false, they ease to T.value().w or T.value().h
    
    // For internal frame tracking (similar to Lua code)
    struct FrameData { //TODO: what does this do? IT is not used in the c++ code, apply from lua
        long MOVE = -1;
    } FRAME;

    // For handling parallax, shadows, etc.
    glm::vec2 shadow_parallax{0, -1.5f};
    glm::vec2 layered_parallax{0, 0};
    float shadow_height = 0.2f;

    bool CALCING = false;          // This is set to true when the Moveable does its own calculations TODO: this is from node?
    bool static_rotation = false;  // For locking rotation
    bool dragging = false;         // Dragging state
    glm::vec2 click_offset{0, 0},  // Offset from cursor when dragging
             temp_offs{0, 0},// TODO: not sure what this is
             hover_offset;               
    
    // --Keep track of the last time this Moveable was moved via :move(dt). When it is successfully moved, set to equal
    // --the current G_TIMER_REAL, and if it is called again this frame, doesn't recalculate move(dt)
    
    // Last movement and alignment times
    float last_moved = -1.0f;
    float last_aligned = -1.0f;

    entt::entity mid; // this is used for mid alignment, not sure what it does


    bool NEW_ALIGNMENT = false;
    // NEW_ALIGNMENT
    // Purpose: NEW_ALIGNMENT is used to indicate that an object's alignment or position has recently changed.
    // When Set: This flag is set to true in functions like Moveable:align_to_major, Moveable:drag, or any time the position or alignment needs to be updated due to changes in its role, alignment offsets, or position relative to its "Major" node.
    // Usage: When NEW_ALIGNMENT is true, it signals that the Moveable object should recalculate its transform (VT) relative to its "Major" object or the game world. After updating the alignment, NEW_ALIGNMENT is reset to false, allowing the system to skip alignment calculations in frames where no changes occurred.
    // Optimization: By avoiding recalculations for objects that haven't changed, NEW_ALIGNMENT optimizes the alignment and positioning code, particularly for objects that stay stationary or have fixed roles.
    bool STATIONARY = true;
    // STATIONARY
    // Purpose: STATIONARY flags whether a Moveable object has completed its movement for the frame or if it remains in the same position without requiring updates.
    // When Set: This flag is set to true if the object’s Visible Transform (VT) matches its target Transform (T), and its velocity values are minimal (indicating no further movement).
    // Usage: If an object is STATIONARY, it signals to the system that movement calculations (like easing towards T or adjusting VT) can be skipped, as the object is effectively still.
    // Optimization: Like NEW_ALIGNMENT, STATIONARY helps reduce unnecessary calculations, especially for objects that don’t need to update every frame, reducing the overall load on the engine for static or temporarily inactive objects.

    
    std::optional<std::string> DEBUG_VALUE;// this is for debugging, show text when this value is not empty
    bool debug = false; // TODO: this is from G::getInstance().debug, move elsewhere  later

    bool REMOVED = false; // for remove()  function, not sure what this does

};

// Additional functions for managing Moveable objects
void lr_clamp(Moveable& moveable);
void align_to_major(entt::registry& registry, entt::entity entity, Moveable& moveable);
void move_with_major(entt::registry& registry, entt::entity entity, float dt);
void glue_to_major(entt::registry& registry, Moveable& moveable);
void hard_set_T(Moveable& moveable, float X, float Y, float W, float H);
void hard_set_VT(Moveable& moveable);
void juice_up(Moveable& moveable, float amount = 0.4f, float rot_amt = 0.0f);
void move_juice(Moveable& moveable, float dt);
void move(entt::registry& registry, entt::entity entity, Moveable& moveable, float dt);
auto init_moveable(entt::registry& registry, int x, int y, int w, int h, entt::entity container) -> entt::entity;
auto get_major(entt::registry& registry, entt::entity entity) -> std::optional<MajorData>;

struct RoleArgs {
    std::optional<std::string> role_type = std::nullopt;
    std::optional<glm::vec2> offset = std::nullopt;
    std::optional<Role> major = std::nullopt;
    std::optional<bool> xy_bond = std::nullopt;
    std::optional<bool> wh_bond = std::nullopt;
    std::optional<bool> r_bond = std::nullopt;
    std::optional<bool> scale_bond = std::nullopt;
    std::optional<bool> draw_major = std::nullopt;
};

// auto set_role(entt::registry& registry, entt::entity entity, const RoleArgs &roleArgs) -> void;

void move_xy(Moveable& moveable, float dt) ;
void move_r(Moveable& moveable, float dt) ;
void move_scale(Moveable& moveable, float dt) ;
void move_wh(Moveable& moveable, float dt) ;
void move_wh(Moveable& moveable, float dt) ;
void calculate_parallax(Moveable& moveable);

// methods from node
void drawBoundingRect(Moveable& node);
void draw(entt::entity entity);
bool collidesWithPoint(Moveable& node, float pointX, float pointY);
void setOffset(Moveable& node, const Vector2& point, const std::string& type);
float fastMidDist(const Moveable& node, const Moveable& otherNode);