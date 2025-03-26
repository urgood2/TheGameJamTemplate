// #include "new_text_system.hpp"

// #include <raylib.h>  // Assuming Raylib for graphics
// #include "../util/common_headers.hpp"
// #include <string>
// #include <vector>
// #include <optional>
// #include <glm/glm.hpp>

// #include "../components/components.hpp"

// #include "../systems/new_movable_system.hpp"

// DynaText::colours{Color{79, 99, 103, 255},/* Black*/ 
//                                 Color{255, 255, 255, 255}};

// // it is assumed that the entity has a movable component already
// auto init(entt::entity, const DynaTextConfig& config_in) {
    
//     auto &dynaText = registry.emplace<DynaText>(entity);

//     // Copy or initialize config
//     DynaTextConfig config = config_in;
//     dynaText.config = config;

//     // Shadow, scale, pop-in rate, bump amount, and font
//     dynaText.config.shadow = config.shadow.value_or(false);
//     dynaText.config.scale = config.scale.value_or(1.0f);
//     dynaText.config.pop_in_rate = config.pop_in_rate.value_or(3.0f);
//     dynaText.config.bump_rate = config.bump_rate.value_or(2.666f);
//     dynaText.config.bump_amount = config.bump_amount.value_or(1.0f);
//     dynaText.config.font = config.font.baseSize > 0 ? config.font : GetFontDefault();  // Use default if none provided

//     // Handle string as table
//     // FIXME: not necessary since this is not lua
//     // if (!config.string_list.empty()) {
//     //     if (config.string_list.size() == 1 && typeid(config.string_list[0]) != typeid(std::vector<std::string>)) {
//     //         config.string_list[0] = config.string_list[0];  // Ensure it's a string list
//     //     }
//     // } else {
//     //     config.string_list = {"HELLO WORLD"};
//     // }
    
//     if (config.string_list.empty()) {
//         dynaText.config.string_list = {"HELLO WORLD"};
//     }

//     // Text Offset
//     dynaText.config.text_offset.x = config.font.baseSize * config.scale.value() + config.x_offset.value_or(0.0f);
//     dynaText.config.text_offset.y = config.font.baseSize * config.scale. value() + config.y_offset.value_or(0.0f);

//     // Default color
//     dynaText.config.colours = config.colours.empty() ? std::vector<Color>{RED} : config.colours;

//     // Timer and silent flag
//     dynaText.config.created_time = (float)GetTime();  // Replace with your game timer
//     dynaText.config.silent = config.silent.value_or(false);

//     // Pop-in start
//     dynaText.start_pop_in = config.pop_in.value_or(false);

//     // Initialize sizes
//     dynaText.config.W = 0.0f;
//     dynaText.config.H = 0.0f;

//     // Initialize strings and focus on the first one
//     dynaText.strings.clear();
//     dynaText.focused_string_index = 0; // 0 since this is c++ and not lua

//     // Update text, first pass
//     updateText(true);

//     // Handle scaling when the text width exceeds the maximum width
//     if (dynaText.config.maxw && dynaText.config.W > dynaText.config.maxw.value()) {
//         dynaText.start_pop_in = config.pop_in.value_or(false);
//         dynaText.config.scale = config.scale.value() * (config.maxw.value() / config.W);
//         updateText(true);  // Update again with new scale
//     }

//     // Handle multiple strings (pop-out logic)
//     if (dynaText.config.string_list.size() > 1) {
//         dynaText.config.pop_delay = config.pop_delay.value_or(1.5f);
//         popOut(4);  // Pop-out for multiple strings
//     }
    
//     //TODO: link entity that holds dynatext to movable later
//     // Initialize Moveable - Assuming Moveable is a component or class you're inheriting
//     // Moveable::init(config_in.X.value_or(0.0f), config_in.Y.value_or(0.0f), config.W, config.H);

//     //TODO: this is also from movable
//     // Set text rotation
//     auto &moveable = registry.get<Moveable>(entity);

//     moveable.T.value().r = config.text_rot.value_or(0.0f);

//     // Initialize states - Assuming 'states' is a struct with flags for interactions
//     moveable.states.hover_can = false;
//     moveable.states.click_can = false;
//     moveable.states.collide_can = false;
//     moveable.states.drag_can = false;
//     moveable.states.release_on_can = false;

//     // Set role (weak bonds) - this would need to be handled based on your game logic
//     //TODO: also from movable, needs to be implemented
//     // setRole("Weak", "Weak");
//     setRole

//     // Add to MOVEABLE list, assuming you have a global or manager system for this
//     //TODO: handle this with entt later
//     // if (typeid(*this) == typeid(DynaText)) {
//     //     G.I.MOVEABLE.push_back(this);  // Assuming G.I.MOVEABLE is a container for Moveable objects
//     // }
// }

// void update(float dt) {
//     updateText();
//     alignLetters();
// }

// void updateText(bool first_pass) {
//     // Reset width and height
//     config.W = 0;
//     config.H = 0;

//     // Iterate over the strings
//     for (size_t k = 0; k < config.string_list.size(); ++k) {
//         std::string& v = config.string_list[k];
        
//         if (first_pass) {
//             std::string new_string = v;
//             Color outer_colour = BLANK;
//             Color inner_colour = BLANK;
//             float part_scale = 1.0f;
            
//             //TODO: so this part seems to hanle color coding. We have our own implementation for that, so we'll add that in later
//             // Assuming ref_table, prefix, suffix are being handled somehow in the C++ system
//             // struct StringEntry {
//             //     std::optional<std::string> prefix;
//             //     std::optional<std::string> suffix;
//             //     std::optional<std::unordered_map<std::string, std::string>> ref_table;
//             //     std::optional<std::string> ref_value;
//             //     std::optional<float> scale;
//             //     std::optional<Color> outer_colour;
//             //     std::optional<Color> colour;
//             //     std::string string;
//             // };
//             // if (auto entry = std::get_if<StringEntry>(&v)) {
//             //     // If there's a ref_table and ref_value, fetch the reference value
//             //     std::string ref_value = entry->ref_table && entry->ref_value
//             //                             ? (*entry->ref_table)[*entry->ref_value]
//             //                             : entry->string;

//             //     // Concatenate prefix, ref_value, and suffix
//             //     new_string = (entry->prefix.value_or("")) + ref_value + (entry->suffix.value_or(""));

//             //     part_a = entry->prefix ? entry->prefix->size() : 0;
//             //     part_b = new_string.size() - (entry->suffix ? entry->suffix->size() : 0);

//             //     // Apply scale if defined
//             //     if (entry->scale) {
//             //         part_scale = entry->scale.value();
//             //     }

//             //     // Apply colors during the first pass
//             //     if (first_pass) {
//             //         outer_colour = entry->outer_colour.value_or(BLANK);
//             //         inner_colour = entry->colour.value_or(BLANK);
//             //     }
//             // } else {
//             //     new_string = std::get<std::string>(v);  // Handle as plain string
//             // }
            
//             //TODO: assuming the color-coding code above changed the new_string
//             auto &old_string = v;
//             // If the string changed or it's the first pass, update it
//             if (strings[k].empty() || old_string != new_string || first_pass) {
//                 if (start_pop_in) reset_pop_in = true;
//                 reset_pop_in = reset_pop_in || config.reset_pop_in.value_or(false); // reset_pop_in is true if reset_pop_in is true or config.reset_pop_in is true

//                 if (!reset_pop_in) {
//                     config.pop_out.reset();
//                     config.pop_in.reset(); // Reset pop-in if not resetting
//                 } else {
//                     config.pop_in = config.pop_in.value_or(0.0f);
//                     config.created_time = (float)GetTime();  // Use your game's timer system
//                 }

//                 // Set new string value
//                 strings[k].clear();  // Clear old letters

//                 float tempW = 0.0f;
//                 float tempH = 0.0f;
//                 size_t current_letter = 0;

//                 // Create letters from the string
//                 for (char c : new_string) {
//                     Letter let_tab;
//                     let_tab.char_ = std::string(1, c);
//                     let_tab.scale = part_scale;

//                     // Calculate letter dimensions
//                     float tx = MeasureTextEx(config.font, let_tab.char_.c_str(), config.font.baseSize * config.scale.value() * part_scale, 0).x; // MeasureTextEx is a raylib function
//                     float ty = MeasureTextEx(config.font, let_tab.char_.c_str(), config.font.baseSize * config.scale.value() * part_scale, 0).y; 

//                     let_tab.dims = {tx / (config.font.baseSize), ty / (config.font.baseSize)};// Set letter dimensions, which are normalized to font base size
//                     let_tab.offset = {0.0f, 0.0f};  // Offset initialization, could be updated later
//                     let_tab.pop_in = first_pass ? (reset_pop_in ? 0 : 1) : 1; // if this is first pass, set pop_in to 0 if reset_pop_in is true, else set to 1
//                     let_tab.colour = inner_colour; //TODO: redo colors later

//                     if (k > 1) {
//                         let_tab.pop_in = 0;
//                     }

//                     // Add the letter to the string array
//                     strings[k].push_back(let_tab);

//                     // Update width and height
//                     tempW += tx; // tempW is the total width of the string
//                     tempH = std::max(ty, tempH); // tempH is the height of the string
//                     current_letter++;
//                 }

//                 // Set string dimensions
//                 // strings[k].W = tempW;
//                 // strings[k].H = tempH;
//                 stringWidths[k] = tempW; //TODO: where are these intialized? and where are they cleared? same for offsets maps
//                 stringHeights[k] = tempH;
//             }
//         }

//         // Update the width and height of the entire text block
//         // if (strings[k].W > config.W) {
//         //     config.W = strings[k].W;
//         //     strings[k].W_offset = 0;
//         // }
//         if (stringWidths[k] > config.W) {
//             config.W = stringWidths[k];
//             // strings[k].W_offset = 0;
//             stringWOffsets[k] = 0;
//         }
//         // if (strings[k].H > config.H) {
//         //     config.H = strings[k].H;
//         //     strings[k].H_offset = 0;
//         // }
//         if (stringHeights[k] > config.H) {
//             config.H = stringHeights[k];
//             // strings[k].H_offset = 0;
//             stringHOffsets[k] = 0;
//         }
//     }

//     // Update the dimensions in the T object (transform)
//     //TODO: figure out what these lines do?
//     if (T) {
//         if ((T.value().w != config.W || T.value().h != config.H) && (!first_pass || reset_pop_in)) {
//             //FIXME: not sure what this does, removing for now
//             // ui_object_updated = true;
//             // config.non_recalc = config.non_recalc;
//         }
//         T.value().w = config.W;
//         T.value().h = config.H;
//     }

//     // Reset flags
//     reset_pop_in = false;
//     start_pop_in = false;

//     // Update letter offsets
//     for (size_t k = 0; k < strings.size(); ++k) {
//         // strings[k].W_offset = 0.5f * (config.W - strings[k].W);
//         stringWOffsets[k] = 0.5f * (config.W - stringWidths[k]);
//         // strings[k].H_offset = 0.5f * (config.H - strings[k].H + config.y_offset.value_or(0));
//         stringHOffsets[k] = 0.5f * (config.H - stringHeights[k] + config.y_offset.value_or(0));
//     }
// }

// void popOut(float pop_out_timer) {
//     // Set the pop-out timer or default to 1
//     config.pop_out = pop_out_timer ? pop_out_timer : 1.0f;

//     // Update pop_out_time by adding the current game time and pop_delay (if it exists)
//     pop_out_time = (float)GetTime() + config.pop_delay.value_or(0.0f);
// }

// void popIn(float pop_in_timer) {
//     // Reset pop-in state
//     reset_pop_in = true;

//     // Cancel any ongoing pop-out effects
//     config.pop_out.reset();

//     // Set the pop-in timer or default to 0
//     config.pop_in = pop_in_timer ? pop_in_timer : 0.0f;

//     // Update the creation time
//     config.created_time = (float)GetTime();  // Use the current game time

//     // Iterate over the letters in the focused string and reset pop_in for each letter
//     for (auto& letter : strings[focused_string_index]) {
//         letter.pop_in = 0.0f;
//     }

//     // Update the text with the new state
//     updateText();
// }

// void alignLetters() {
//     // Handle pop cycle: change focused string randomly or by cycling
//     if (pop_cycle) {
//         // focused_string_index = (config.random_element && rand() % strings.size()) 
//         //                     ? rand() % strings.size() + 1 
//         //                     : (focused_string_index == strings.size() - 1 ? 1 : focused_string_index + 1);

//         focused_string_index = (config.random_element && rand() % config.string_list.size()) 
//                             || (focused_string_index == strings.size() - 1 ? 0 : focused_string_index + 1); // reset to 0-based index instead of 1-based

        
//         pop_cycle = false;

//         // Reset pop_in for all letters in the new focused string
//         for (auto& letter : strings[focused_string_index]) {
//             letter.pop_in = 0;
//         }

//         // Update pop_in and reset created time
//         config.pop_in = 0.1f;
//         config.pop_out.reset();
//         config.created_time = (float)GetTime();
//     }

//     // Update letters in the focused string
//     auto& current_string = strings[focused_string_index];
//     for (size_t k = 0; k < current_string.size(); ++k) {
//         auto& letter = current_string[k];

//         // Handle pop-out effect
//         if (config.pop_out) {
//             // This line sets letter.pop_in to a value between 0.0f and 1.0f, representing some form of "pop-in" effect. Initially, letter.pop_in will be close to 1.0f (or exactly 1.0f if min_cycle_time hasn't elapsed since pop_out_time). As time passes, letter.pop_in will gradually decrease, eventually reaching 0.0f. This likely controls the visibility, size, or intensity of letter.pop_in in a time-based cycle.
//             letter.pop_in = std::min(1.0f, std::max(
//                 (config.min_cycle_time.value_or(1.0f)) - 
//                 ((float)GetTime() - pop_out_time) * config.pop_out.value() / 
//                 (config.min_cycle_time.value_or(1.0f)), 
//                 0.0f)); 

//             letter.pop_in *= letter.pop_in;  // Apply easing (square the value)

//             // Set pop cycle if at the end of string and pop_in is 0
//             if (k == current_string.size() - 1 && letter.pop_in <= 0 && strings.size() > 1) {
//                 pop_cycle = true;
//             }
//         }
//         // Handle pop-in effect
//         else if (config.pop_in) {
//             float prev_pop_in = letter.pop_in;
//             // This expression sets letter.pop_in to a value between 0.0f and 1.0f, representing a time-based pop-in effect. Initially, letter.pop_in will be close to 1.0f (or exactly 1.0f if min_cycle_time is zero), and as time passes, the value will gradually decrease based on the adjusted elapsed time, string size, and pop-in rate. This could control an animation or visual effect where each letter or element “pops in” over time.
//             letter.pop_in = std::min(1.0f, std::max(
//                 ((float)GetTime() - config.pop_in.value() - config.created_time) * current_string.size() * config.pop_in_rate.value() - k + 1,
//                 config.min_cycle_time == 0 ? 1.0f : 0.0f));

//             letter.pop_in *= letter.pop_in;  // Apply easing (square the value)

//             // Play sound if pop-in crosses a threshold
//             if (prev_pop_in <= 0 && letter.pop_in > 0 && !config.silent.value_or(false) && 
//                 (current_string.size() < 10 || k % 2 == 0)) {
                
//                 //TODO: do my own bounds checking with map
//                 if (T.value().x > GetScreenWidth() + 2 || T.value().y > GetScreenHeight() + 2 || T.value().x < -2 || T.value().y < -2) {
//                     // Do not play sound if the letter is outside the room bounds
//                 } else {
//                     //TODO: use audio system to play sound
//                     // playSound("paper1", 0.45f + 0.05f * rand() / RAND_MAX + (0.3f / current_string.size()) * k + config.pitch_shift.value_or(0.0f));
//                 }
//             }

//             // Set pop_out if the entire string is fully popped in
//             if (k == current_string.size() - 1 && letter.pop_in >= 1) {
//                 if (strings.size() > 1) {
//                     pop_delay = ((float)GetTime() - config.pop_in.value() - config.created_time + config.pop_delay.value_or(1.5f));
//                     popOut(4.0f);
//                 } else {
//                     config.pop_in.reset();
//                 }
//             }
//         }

//         // Reset rotation and scale
//         letter.r = 0.0f;
//         letter.scale = 1.0f;

//         // Apply rotation if enabled
//         if (config.rotate) {
//             //         This expression sets letter.r to a rotation angle that:
//             // Oscillates slightly based on the current time if reduced_motion is disabled.
//             // Centers each letter’s rotation based on its position in the string, giving a “fan-out” effect around the center of the string.
//             // Allows clockwise or counter-clockwise rotation based on config.rotate.
//             letter.r = (config.rotate == 2 ? -1.0f : 1.0f) *
//                        (0.2f * (-static_cast<int>(current_string.size()) / 2 - 0.5f + k) / static_cast<float>(current_string.size()) +
//                         (reduced_motion ? 0.0f : 1.0f) * 0.02f * sin(2 * (float)GetTime() + k));
//         }

//         // Apply pulse effect if enabled
//         if (pulse) {
//             //         This section adjusts the letter.scale, creating a pulsing or expanding effect:

//             // reduced_motion ? 0.0f : 1.0f:
//             //     If reduced_motion is true, this entire expression is effectively 0, disabling the pulsing effect.
//             //     If reduced_motion is false, this allows the pulsing effect to apply.

//             // (1.0f / config.pulse->width) * config.pulse->amount:
//             //     1.0f / config.pulse->width: Normalizes the effect by width, making the pulsing effect sensitive to config.pulse->width.
//             //     config.pulse->amount: Scales the amount of pulsing, defining the intensity of the effect.

//             //         This part calculates a pulsing value based on (float)GetTime() and config.pulse->start, representing when the pulse effect should occur. Here's what each part does:

//             // First term: (config.pulse->start - (float)GetTime()) * config.pulse->speed + k + config.pulse->width
//             //     This scales down as time passes (since (float)GetTime() increases), moving closer to zero, which reduces the pulse effect.
//             // Second term: ((float)GetTime() - config.pulse->start) * config.pulse->speed - k + config.pulse->width + 2
//             //     This term increases as time passes, adding back a scaling effect.
//             // std::min(..., 0.0f): Ensures that any result is at least 0, which prevents letter.scale from dropping below its original scale.
//             letter.scale += (reduced_motion ? 0.0f : 1.0f) *
//                             (1.0f / pulse.value().width) * pulse.value().amount *
//                             std::max(
//                                 std::min((pulse.value().start - (float)GetTime()) * pulse.value().speed + k + pulse.value().width,
//                                          ((float)GetTime() - pulse.value().start) * pulse.value().speed - k + pulse.value().width + 2),
//                                 0.0f);
//             //         This part adjusts letter.r, adding rotation based on letter.scale:

//             // reduced_motion ? 0.0f : 1.0f: Disables the rotation effect if reduced_motion is enabled.

//             // (letter.scale - 1.0f): This makes the rotation dependent on letter.scale, so that letters rotate more as they expand and less as they shrink.

//             // Rotation Based on Position:
//             //     0.02f * (-static_cast<int>(current_string.size()) / 2 - 0.5f + k): This centers the rotation around the middle of current_string, giving letters on each side of the center different rotation angles.
//             letter.r += (reduced_motion ? 0.0f : 1.0f) * (letter.scale - 1.0f) *
//                         (0.02f * (-static_cast<int>(current_string.size()) / 2 - 0.5f + k));

//             //         This checks if the pulse effect is past its intended duration:

//             // If config.pulse->start is significantly greater than the current time, factoring in current_string.size() and pulse->speed, it means the pulsing has completed, so config.pulse is reset.
//             if (pulse.value().start > (float)GetTime() + 2 * pulse.value().speed * current_string.size()) {
//                 pulse.reset();
//             }
//         }

//         // Apply quiver effect if enabled
//         if (quiver) {
//             //             reduced_motion ? 0.0f : 1.0f:

//             //     If reduced_motion is true, this entire expression evaluates to 0, disabling the quiver effect, likely for accessibility purposes.
//             //     If reduced_motion is false, it allows the quiver effect to apply.

//             // 0.1f * config.quiver->amount:

//             //     0.1f: A small multiplier that reduces the impact of config.quiver->amount, creating a slight scaling effect rather than a large one.
//             //     config.quiver->amount: This controls the intensity of the quiver effect. A higher value will increase the scale slightly more, while a lower value reduces it.
//             letter.scale += (reduced_motion ? 0.0f : 1.0f) * (0.1f * quiver.value().amount);

//             //             reduced_motion ? 0.0f : 1.0f:

//             //     As in the scale adjustment, this disables the rotation effect if reduced_motion is enabled.

//             // 0.3f * config.quiver->amount:

//             //     0.3f: A small multiplier that dampens the overall quiver effect, creating a subtle jitter.
//             //     config.quiver->amount: Controls the intensity of the quiver effect for the rotation, allowing customization of how much "quiver" each letter experiences.
//             letter.r += (reduced_motion ? 0.0f : 1.0f) * 0.3f * quiver.value().amount *
//                         (sin(41.12342f * (float)GetTime() * quiver.value().speed + k * 1223.2f) +
//                          cos(63.21231f * (float)GetTime() * quiver.value().speed + k * 1112.2f) * sin(36.1231f * (float)GetTime() * quiver.value().speed) +
//                          cos(95.123f * (float)GetTime() * quiver.value().speed + k * 1233.2f) -
//                          sin(30.133421f * (float)GetTime() * quiver.value().speed + k * 123.2f));
//             //                      This entire expression creates a complex, seemingly random pattern for letter.r based on a combination of sine and cosine functions. Here’s how it works:

//             // Each sin and cos function uses GetGameTime() multiplied by config.quiver->speed to create oscillations that change over time, resulting in a continuously changing rotation.
//             // Each function is further offset by a factor of k, so each letter (or instance with a different k value) has a unique oscillation pattern.
//             // sin(...) + cos(...) * sin(...) + cos(...) - sin(...): Combining these functions at different frequencies and with offsets creates a non-linear, jittery effect. It gives each letter a unique "quiver" that changes independently over time.
//         }

//         // Apply float effect if enabled
//         if (config.float_) {
//             //             This code sets letter.offset.y to a combination of a time-based oscillation and scale-based offset, resulting in a vertical "bounce" or "wave" effect:

//             //     Vertical Oscillation: Letters will have a smooth, sinusoidal up-and-down motion that varies with time ((float)GetTime()) and their position (k), making each letter move in its own unique rhythm.
//             //     Scale Influence: If letter.scale is above 1.0f, the letters will also shift upwards proportionally to their scale.
//             //     Reduced Motion: If reduced_motion is enabled, both the oscillation and scale effects are disabled, setting letter.offset.y to 0.0f.

//             // The result is a lively, wave-like motion, where each letter moves independently in a way that simulates gentle floating or bouncing.

//             //         sqrtf(config.scale):

//             // This applies a square root of the config.scale value, which likely controls the overall scaling effect.
//             // Using sqrtf instead of the raw scale value makes the scaling effect less intense, giving a smoother increase or decrease.

//             //             2.0f: A base offset value that ensures the offset has a minimum value.
//             // (config.font.baseSize / G_TILESIZE) * 2000: This scales the effect based on the font size, creating larger oscillations for larger font sizes. The division by G_TILESIZE normalizes baseSize in relation to the tile size, and multiplying by 2000 intensifies the effect.
//             // sin(2.666f * (float)GetTime() + 200 * k): This sine function creates a time-based oscillation that shifts over time.

//             //     2.666f * (float)GetTime(): Controls the speed of oscillation based on the current time ((float)GetTime()).
//             //     + 200 * k: Adds a phase shift for each letter based on its index (k), so each letter oscillates slightly differently.
//             letter.offset.y = (reduced_motion ? 0.0f : 1.0f) * sqrtf(config.scale.value()) *
//                               (2.0f + (config.font.baseSize / G_TILESIZE) * 2000 * sin(2.666f * (float)GetTime() + 200 * k)) +
//                               60 * (letter.scale - 1.0f);
//         }

//         // Apply bump effect if enabled
//         if (config.bump) {
//             //             Bump Intensity Multipliers:

//             //     config.bump_amount: Controls the overall strength or intensity of the bump effect. Higher values make the bump effect more pronounced.
//             //     sqrtf(config.scale): Applies a scaling factor, where config.scale adjusts the bump effect based on the letter’s scale. Using sqrtf makes this effect smoother and less intense.
//             //     7.0f: Additional multiplier that intensifies the effect.

//             // Oscillating Component with std::max:

//             //         std::max(0.0f, ...): This clamps the value to a minimum of 0.0f, so the bump effect only applies in the positive direction (upward) and avoids negative offsets.

//             //     Bump Wave Calculation:
//             //             (5.0f + config.bump_rate): Adjusts the amplitude of the sine wave, which influences how far the letter can "bump" upward. The bump_rate allows for dynamic amplitude adjustment.
//             //             sin(config.bump_rate * GetGameTime() + 200 * k): Creates a sine wave oscillation, where:
//             //                 config.bump_rate * GetGameTime() controls the oscillation speed.
//             //                 200 * k introduces a phase shift based on k, giving each letter a unique starting point in the wave, so they "bump" at different times.
//             //             - 3.0f - config.bump_rate: This shifts the sine wave downwards, ensuring that it passes through 0 more frequently. Combined with std::max, it only generates positive bumps.

//             // Overall Effect

//             // This code gives letter.offset.y a "bump" effect that shifts each letter slightly upward in a rhythmic, wave-like motion. Here’s how it all comes together:

//             //     Bump Motion: The sine-based calculation makes each letter "bump" up and down at a rate defined by config.bump_rate and GetGameTime(), with each letter offset slightly based on its position (k).
//             //     Scale and Intensity Control: The bump amount and scale settings make it possible to adjust the bump effect’s intensity and ensure it’s proportional to the letter’s size.
//             //     Reduced Motion: If reduced_motion is enabled, the bump effect is disabled by setting letter.offset.y to 0.0f.

//             // This creates a dynamic, slightly bouncing effect where each letter moves in a coordinated but offset pattern, adding visual interest and motion to the text.

//             letter.offset.y = (reduced_motion ? 0.0f : 1.0f) * config.bump_amount.value() * sqrtf(config.scale.value()) * 7.0f *
//                               std::max(0.0f, (5.0f + config.bump_rate.value()) * sin(config.bump_rate.value() * (float)GetTime() + 200 * k) - 3.0f - config.bump_rate.value());
//         }
//     }
// }

// void setQuiver(std::optional<float> amt) {
//     quiver = Quiver{
//         .speed = 0.5f,           // Speed of the quiver effect
//         .amount = amt ? amt.value() : 0.7f,          // Amount of quiver, defaulting to 0.1
//         .silent = false           // Silent flag, always false
//     };
// }

// void setPulse(std::optional<float> amt) {
//     pulse = Pulse{
//         .speed = 40.0f,           // Speed of the pulse effect
//         .width = 2.5f,            // Width of the pulse effect
//         .start = (float)GetTime(),       // Start time for the pulse effect (similar to G.TIMERS.REAL),
//         .amount = amt ? amt.value() : 0.2f,  // Amount of the pulse, defaulting to 0.2
//         .silent = false           // Silent flag, always false
//     };
// }

// void draw() {
//     // Draw particle effect if it exists
//     //TODO: connect an emitter component to the text later? how does particle linking work with text in the lua files?
//     // if (children.particle_effect) {
//     //     children.particle_effect->draw();
//     // }

//     // Draw shadow if shadow is enabled
//     if (config.shadow) {
//         // Prepare for drawing the shadow
//         // prepDraw(1);  // translate, etc.
//         Vector2 translation_offset{
//             stringWOffsets[focused_string_index] + config.text_offset.x * (config.font.baseSize / G_TILESIZE) + shadow_parrallax.x * config.scale.value() / G_TILESIZE,
//             // strings[focused_string_index].W_offset + config.text_offset.x * (config.font.baseSize / G_TILESIZE),
//             // strings[focused_string_index].H_offset + config.text_offset.y * (config.font.baseSize / G_TILESIZE)
//             stringHOffsets[focused_string_index] + config.text_offset.y * (config.font.baseSize / G_TILESIZE)
//         };
//         DrawTranslate(translation_offset);  // Assume this translates the drawing context

//         if (config.spacing) {
//             DrawTranslate(Vector2{config.spacing.value() * (config.font.baseSize / G_TILESIZE), 0.0f});
//         }

//         Color shadow_color = config.shadow_colour.value_or(Color{0, 0, 0, static_cast<unsigned char>(0.3f)});

//         // Draw each letter's shadow
//         for (const auto& letter : strings[focused_string_index]) {
//             float real_pop_in = (config.min_cycle_time == 0) ? 1.0f : letter.pop_in;

//             DrawTextPro(
//                 letter.texture,  // The letter texture
//                 Vector2{
//                     0.5f * (letter.dims.x - letter.offset.x) * (config.font.baseSize / G_TILESIZE) - shadow_parrallax.x * config.scale.value() / G_TILESIZE,
//                     0.5f * letter.dims.y * (config.font.baseSize / G_TILESIZE) - shadow_parrallax.y * config.scale.value() / G_TILESIZE
//                 },
//                 Vector2{0.5f * letter.dims.x / config.scale.value(), 0.5f * letter.dims.y / config.scale.value()},  // Origin
//                 letter.r,  // Rotation
//                 real_pop_in * config.scale.value() * (config.font.baseSize / G_TILESIZE),  // Scale
//                 shadow_color  // Color
//             );

//             // Translate to the next letter position
//             DrawTranslate(Vector2{letter.dims.x * (config.font.baseSize / G_TILESIZE), 0.0f});
//         }
//         EndDrawing();
//     }

//     // Draw the main text
//     // prepDraw(1);  // Prepare for drawing text (translate, etc.)
//     DrawTranslate(Vector2{
//         // strings[focused_string_index].W_offset + config.text_offset.x * (config.font.baseSize / G_TILESIZE),
//         stringWOffsets[focused_string_index] + config.text_offset.x * (config.font.baseSize / G_TILESIZE),
//         // strings[focused_string_index].H_offset + config.text_offset.y * (config.font.baseSize / G_TILESIZE)
//         stringHOffsets[focused_string_index] + config.text_offset.y * (config.font.baseSize / G_TILESIZE)
//     });

//     if (config.spacing) {
//         DrawTranslate(Vector2{config.spacing.value() * (config.font.baseSize / G_TILESIZE), 0.0f});
//     }

//     Vector2 shadow_norm{
//         shadow_parrallax.x / std::sqrt(shadow_parrallax.y * shadow_parrallax.y + shadow_parrallax.x * shadow_parrallax.x) * (config.font.baseSize / G_TILESIZE),
//         shadow_parrallax.y / std::sqrt(shadow_parrallax.y * shadow_parrallax.y + shadow_parrallax.x * shadow_parrallax.x) * (config.font.baseSize / G_TILESIZE)
//     };

//     // Draw each letter
//     for (size_t k = 0; k < strings[focused_string_index].size(); ++k) {
//         const auto& letter = strings[focused_string_index][k];
//         float real_pop_in = (config.min_cycle_time == 0) ? 1.0f : letter.pop_in;

//         Color letter_color = letter.prefix.value_or(
//             letter.suffix.value_or(
//                 letter.colour.value_or(colours[k % colours.size()])));

//         DrawTextPro(
//             letter.texture,  // Letter texture
//             Vector2{
//                 0.5f * (letter.dims.x - letter.offset.x) * (config.font.baseSize / G_TILESIZE) + shadow_norm.x,
//                 0.5f * (letter.dims.y - letter.offset.y) * (config.font.baseSize / G_TILESIZE) + shadow_norm.y
//             },
//             Vector2{0.5f * letter.dims.x / config.scale, 0.5f * letter.dims.y / config.scale},  // Origin
//             letter.r,  // Rotation
//             real_pop_in * letter.scale * config.scale * (config.font.baseSize / G_TILESIZE),  // Scale
//             letter_color  // Color
//         );

//         // Move to the next letter's position
//         DrawTranslate(Vector2{letter.dims.x * (config.font.baseSize / G_TILESIZE), 0.0f});
//     }
//     EndDrawing();

//     // Draw additional UI elements like bounding box or hitbox if needed
//     // addToDrawHash();  // Custom function TODO: remove this later
//     drawBoundingRect();  // Draw a bounding rectangle (optional) TODO: this should coem from a system once this is tested
// }