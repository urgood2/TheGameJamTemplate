// #pragma once

// #include <raylib.h>
// #include <string>
// #include <vector>
// #include <optional>
// #include <map>
// #include <glm/glm.hpp>

// #include "../components/components.hpp"


// // States for UI interaction
// // FIXME: not sure where this belongs, seems to be ui-based - It's from the node class
// struct States {
//     std::optional<bool> hover_can = false;
//     std::optional<bool> click_can = false;
//     std::optional<bool> collide_can = false;
//     std::optional<bool> drag_can = false;
//     std::optional<bool> release_on_can = false;
// };

// // Configuration for DynaText animations and effects
// struct DynaTextConfig {
//     std::optional<bool> shadow;
//     std::optional<float> scale{1.0f};
//     std::optional<float> pop_in_rate{3.0f};
//     std::optional<float> bump_rate{2.666f};
//     std::optional<float> bump_amount{1.0f};
//     Font font;
//     std::vector<std::string> string_list{"HELLO WORLD"};
//     Vector2 text_offset{0.0f, 0.0f};
//     std::vector<Color> colours{RED};
//     float created_time = 0.0f;
//     std::optional<bool> silent;
//     std::optional<bool> float_;
//     std::optional<bool> bump;
//     std::optional<float> pop_in;
//     std::optional<float> pop_out;
//     float W = 0.0f, H = 0.0f;
//     std::optional<float> pop_delay;
//     std::optional<float> text_rot;
//     std::optional<float> x_offset;
//     std::optional<float> y_offset;
//     std::optional<float> spacing;
//     std::optional<float> maxw;
//     std::optional<bool> reset_pop_in;
//     std::optional<float> pitch_shift;
//     std::optional<bool> random_element;
//     std::optional<float> min_cycle_time;
//     std::optional<bool> rotate;
// };

// // Character-level properties within DynaText
// struct Letter {
//     Texture2D texture;
//     std::string char_;
//     Vector2 offset{0.0f, 0.0f};
//     Vector2 dims{0.0f, 0.0f};
//     float scale = 1.0f;
//     float pop_in = 1.0f;
//     Color prefix = BLANK;
//     Color suffix = BLANK;
//     Color colour = BLANK;
//     float r = 0.0f;
// };

// // Quiver animation settings
// struct Quiver {
//     float speed;
//     float amount;
//     bool silent;
// };

// // Pulse animation settings
// struct Pulse {
//     float speed;
//     float width;
//     float start;
//     float amount;
//     bool silent;
// };

// // Main class for dynamic animated text
// class DynaText {
//     // Internal members
//     std::optional<TransformCustom> T{};
//     States states;
//     std::optional<Quiver> quiver;
//     std::optional<Pulse> pulse;
    
//     DynaTextConfig config;
//     std::vector<std::vector<Letter>> strings;
//     std::map<int, float> stringWidths;
//     std::map<int, float> stringHeights;
//     std::map<int, float> stringWOffsets;
//     std::map<int, float> stringHOffsets;

//     std::vector<Color> colours;

//     // this is from movable, need to unify somehow?
//     glm::vec2 shadow_parallax{0, -1.5f};

//     std::optional<float> pop_delay;

//     int focused_string_index = 1;
//     bool start_pop_in = false;
//     bool reset_pop_in = false;
//     float pop_out_time = 0.0;
//     bool pop_cycle = false;
// };


// // Core methods
// void init(const DynaTextConfig& cfg);
// void update(float dt);
// void draw();

// // Animation and effect methods
// void setQuiver(std::optional<float> amt);
// void setPulse(std::optional<float> amt);
// void popOut(float pop_out_timer);
// void popIn(float pop_in_timer);

// // should be private methods
// void updateText(bool first_pass = false);
// void alignLetters();
