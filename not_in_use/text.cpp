// -- Mixin that adds character based text functionality to the object.
// -- This implements a character based effect system which should allow you to implement any kind of text effect possible, from setting a character's color, to making it move, shake or play sounds.
// -- WARNING: currently the | character cannot be used in the text or bugs will happen, will be fixed when I need to use it in a game
// --
// -- Defining an effect:
// --   color_effect = function(dt, layer, text, c, color)
// --     layer:set_color(color)
// --   end
// --
// -- Every effect is a single function that gets called every frame for every character before each character is drawn.
// -- In the example above, we define the color effect as a function that simply sets the color for next draw operations, which will be the operations in which this specific character is drawn, and so it will be drawn with that color.
// -- The effect function receives the following arguments:
// --   dt - time step
// --   layer - the layer the character will be drawn to, don't call any draw functions for the character yourself or you'll be just drawing the character twice
// --   text - a reference to the text object
// --   c - an anchor object, which is a table containing .x, .y, .r, .sx, .sy, .ox, .oy, .c, .line, .i and .effects attributes
// --   effect arguments - all arguments after c are the effect's arguments, for color it's just a single color, but for other effects it might be multiple values
// --
// -- Another effect:
// --  shake = function(dt, layer, text, c, intensity, duration)
// --    if text.first_frame then
// --      if not c.shakes then c:shake_init() end
// --      c:shake_shake(intensity, duration)
// --    end
// --    c.ox, c.oy = c.shake_amount.x, c.shake_amount.y
// --  end,
// --
// -- For some effects it makes sense to do most or all of its operations only when the text object is created, and to do this it's useful to use the text.first_frame variable, which is only true on the frame the text object is created.
// -- In shake_effect's case, we initialize the character's shake mixin and then call the shake function to start shaking, and then on update we set the object's offset to the shake amount.
// -- Both intensity and duration values are passed in from the text's definition: i.e. [this text is shaking](shake=4,2) <- 4 is intensity, 2 is duration
// -- Arguments for effects can theoretically be any Lua value, as internally it just loadstrings the string for each argument, but in some cases this might break and I haven't tested for every possible thing so keep that in mind.
// --
// -- Creating a text object:
// --   text('[this text is red](color=colors.red2[0]), [this text is shaking](shake=4,4), [this text is red and shaking](color=colors.red2[0];shake=4,4), this text is normal', {
// --     text_font = some_font, -- optional, defaults to engine's default font
// --     text_effects = {color = color_effect, shake = shake_effect}, -- optional, defaults to engine's default effects; if defined, effect key name has to be same as the effect's name on the text inside delimiters ()
// --     text_alignment = 'center', -- optional, defaults to 'left'
// --     w = 200, -- mandatory, acts as wrap width for text
// --     height_multiplier = 1 -- optional, defaults to 1
// --   })
// -- The text can be created from the global text function, or as a mixin in your own objects.
// -- The text additionally receives a table of attributes after the text string with the following properties:
// --   .text_font - the font to be used for the text, if not specified will use the engine's default font
// --   .text_effects - the effects to be used for the text, if not specified will use the engine's default text effects
// --   .text_alignment - how the text should align itself with regards to its wrap width, possible values are 'center', 'justified', 'right' and 'left'; if not specified defaults to 'left'
// --   .w - the object's width, used as wrap width; if not specified an error will happen, the width must be defined before initializing this object as a text
// --   .height_multiplier - multiplier over the font's height for placing the line below

#include <iostream>
#include <functional>
#include <map>
#include <string>
#include <vector>
#include <any>
#include <typeinfo>
#include <iostream>
#include <string>
#include <vector>
#include <regex>
#include <sstream>
#include <variant>
#include <stdexcept>

#include "raylib.h"

#include "../../util/common_headers.hpp"
#include "text.hpp"
#include "rlgl.h"


namespace text
{
    using EffectFunction = std::function<void(float, Layer &, Text &, Character &, const std::vector<std::any> &)>;
    
    // Default text effects map
    std::map<std::string, EffectFunction> default_text_effects = {
        {"color", [](float dt, Layer &layer, Text &text, Character &c, const std::vector<std::any> &args)
         {
             if (!args.empty() && args[0].type() == typeid(std::string))
             {
                 // layer.set_color(std::any_cast<std::string>(args[0]));
                 // TODO: what does "layer" do?
             }
             else
             {
                 std::cerr << "Invalid argument for color effect.\n";
             }
         }},

        {"shake", [](float dt, Layer &layer, Text &text, Character &c, const std::vector<std::any> &args)
         {
             if (text.first_frame)
             {
                 c.shake_init();
                 // the first two option arguments should be intensity and duration
                 if (args.size() >= 2 &&
                     args[0].type() == typeid(float) &&
                     args[1].type() == typeid(float))
                 {
                     float intensity = std::any_cast<float>(args[0]);
                     float duration = std::any_cast<float>(args[1]);
                     c.shake_shake(intensity, duration);
                 }
                 else
                 {
                     std::cerr << "Invalid arguments for shake effect.\n";
                 }
             }
             c.ox = c.shake_amount.x;
             c.oy = c.shake_amount.y;
         }}};

    auto text_init(std::string rawText, const Font &font, const std::map<std::string, EffectFunction> &textEffects, Text::Alignment alignment, float heightMultiplier, float wrapWidth) -> Text
    {
        Text text{};
        text.raw_text = rawText;
        text.font = font;
        text.text_effects = textEffects;
        text.alignment = alignment;
        text.height_multiplier = heightMultiplier;
        text.wrap_width = wrapWidth;
        text_parse(text);
        text_format(text);
        return text;
    }

    // Function to parse an argument from the effect string
    // If the argument contains '#', treat it as a string; otherwise, try to convert it to a double
    std::any parseArg(const std::string &arg)
    {
        if (arg.find('#') != std::string::npos)
        {
            return arg; // Treat as a string
        }
        else
        {
            try
            {
                return std::stod(arg); // Try to convert to a double
            }
            catch (...)
            {
                throw std::invalid_argument("Invalid argument format: " + arg);
            }
        }
    }

    // Function to split effects by ';'
    std::vector<std::string> splitEffects(const std::string &effects)
    {
        std::vector<std::string> result;
        std::istringstream stream(effects);
        std::string token;
        while (std::getline(stream, token, ';'))
        {
            result.push_back(token);
        }
        return result;
    }

    // Function to parse a single effect string (e.g., "color=red")
    ParsedEffect parseEffect(const std::string &effect)
    {
        auto pos = effect.find('=');
        if (pos == std::string::npos)
        {
            throw std::invalid_argument("Invalid effect format: " + effect);
        }

        ParsedEffect parsed;
        parsed.effectName = effect.substr(0, pos); // Extract the effect name

        // Extract arguments (everything after '=')
        std::string args = effect.substr(pos + 1);
        std::istringstream argStream(args);
        std::string arg;
        while (std::getline(argStream, arg, ','))
        {
            parsed.arguments.push_back(parseArg(arg)); // Parse each argument
        }
        return parsed;
    }

    // Function to parse raw text and extract text fields and their effects
    std::vector<ParsedText> parseRawText(const std::string &rawText)
    {
        std::regex pattern(R"(\[(.*?)\]\((.*?)\))"); // Match [field](effects)
        std::smatch match;
        std::vector<ParsedText> parsedText;
        std::string text = rawText;

        while (std::regex_search(text, match, pattern))
        {
            ParsedText entry;
            entry.i = match.position(0);    // Start index of the match
            entry.field = match[1].str();   // Extract text inside [ ]
            entry.effects = match[2].str(); // Extract effects inside ( )

            // Parse effects inside ( )
            auto effectsList = splitEffects(entry.effects);
            for (const auto &effect : effectsList)
            {
                entry.parsedEffects.push_back(parseEffect(effect));
            }

            parsedText.push_back(entry);
            text = match.suffix(); // Move to the next part of the text
        }

        return parsedText;
    }

    // Function to build characters from raw text and parsed effects
    std::vector<Character> buildCharacters(const std::string &rawText, const std::vector<ParsedText> &parsedText)
    {
        std::vector<Character> characters;

        // Iterate through each character in the raw text
        for (size_t i = 0; i < rawText.size(); ++i)
        {
            auto c = rawText[i];           // Current character
            bool shouldBeCharacter = true; // Assume this character is valid
            std::vector<ParsedEffect> effects;

            // Check if the character is part of a parsed effect field
            for (const auto &t : parsedText)
            {
                if (i >= t.i && i < t.i + t.field.size())
                {
                    effects = t.parsedEffects; // Apply effects from the parsed text
                }
                // Exclude delimiters and effects sections
                if (i >= t.i + t.field.size() && i < t.i + t.field.size() + t.effects.size())
                {
                    shouldBeCharacter = false;
                    break;
                }
            }

            // Add valid characters to the list
            if (shouldBeCharacter)
            {
                Character character;
                character.c = std::string(1, c);
                character.effects = effects;
                characters.push_back(character);
            }
        }

        return characters;
    }

    // Parses raw_text into the characters list, which contains every valid character as the following table: {c = character as a string, effects = effects that apply to this character as a table}
    auto text_parse(Text &text) -> void
    {

        // Parse text and store all delimiters as well as text field and effects into the parsed_text table
        // Parse each effect: 'effect_name=arg1,arg2' becomes {effect_name, arg1, arg2}
        auto parsedText = parseRawText(text.raw_text);

        // Read the parsed_text table to figure out which characters should be in the final text ([] and () delimiters shouldn't be in, neither should any text inside effect () delimiters)

        // Build the characters table containing each valid character as well as the effects that apply to it

        auto builtCharacters = buildCharacters(text.raw_text, parsedText);

        text.characters = builtCharacters;
    }

    auto text_format(Text &text) -> void
    {
        // Check if `w` (wrap width) is defined
        if (text.wrap_width == 0)
        {
            throw std::runtime_error(".w must be defined for text formatting to work.");
        }

        int cx = 0, cy = 0; // Current position for character placement
        int line = 1;       // Current line number

        // First pass: position characters
        for (auto &c : text.characters)
        {
            if (c.c == "|")
            {
                // Line break
                cx = 0;
                cy += text.font.baseSize * text.height_multiplier;
                line++;
            }
            else if (c.c == " ")
            {
                // Handle spaces and word wrapping
                bool wrapped = false;
                if (c.effects.size() <= 1)
                { // Check wrapping only if not in effect delimiters
                    int from_space_x = cx;
                    // Calculate the width of the next word
                    for (size_t i = &c - &text.characters[0] + 1; i < text.characters.size() && text.characters[i].c != " "; i++)
                    {
                        from_space_x += MeasureText(text.characters[i].c.c_str(), text.font.baseSize);
                    }
                    // Wrap if the word exceeds the wrap width
                    if (from_space_x > text.wrap_width)
                    {
                        cx = 0;
                        cy += text.font.baseSize * text.height_multiplier;
                        line++;
                        wrapped = true;
                    }
                }
                if (!wrapped)
                {
                    c.x = cx;
                    c.y = cy;
                    c.line = line;
                    c.w = MeasureText(c.c.c_str(), text.font.baseSize);
                    c.h = text.font.baseSize;
                    cx += c.w;
                    // Wrap line if needed
                    if (cx > text.wrap_width)
                    {
                        cx = 0;
                        cy += text.font.baseSize * text.height_multiplier;
                        line++;
                    }
                }
                else
                {
                    c.c = "|"; // Mark as line break
                }
            }
            else
            {
                // Regular character
                c.x = cx;
                c.y = cy;
                c.line = line;
                c.w = MeasureText(c.c.c_str(), text.font.baseSize);
                c.h = text.font.baseSize;
                cx += c.w;
                // Wrap line if needed
                if (cx > text.wrap_width)
                {
                    cx = 0;
                    cy += text.font.baseSize * text.height_multiplier;
                    line++;
                }
            }
        }

        // Remove line separators ('|')
        text.characters.erase(
            std::remove_if(text.characters.begin(), text.characters.end(), [](const Character &c)
                           { return c.c == "|"; }),
            text.characters.end());

        // Assign index (`i`) to each character
        for (size_t i = 0; i < text.characters.size(); i++)
        {
            text.characters[i].line = i + 1;
        }

        // Calculate text width and height
        text.text_width = 0;
        std::vector<int> line_widths(line, 0); // Track width of each line
        for (const auto &c : text.characters)
        {
            line_widths[c.line - 1] += MeasureText(c.c.c_str(), text.font.baseSize);
        }
        text.text_width = *std::max_element(line_widths.begin(), line_widths.end());
        text.text_height = cy + text.font.baseSize * text.height_multiplier;

        // Apply alignment
        for (int i = 0; i < line; i++)
        {
            int line_w = line_widths[i];
            int leftover_w = text.text_width - line_w;
            if (text.alignment == Text::Alignment::CENTER)
            {
                for (auto &c : text.characters)
                {
                    if (c.line == i + 1)
                    {
                        c.x += leftover_w / 2;
                    }
                }
            }
            else if (text.alignment == Text::Alignment::RIGHT)
            {
                for (auto &c : text.characters)
                {
                    if (c.line == i + 1)
                    {
                        c.x += leftover_w;
                    }
                }
            }
            else if (text.alignment == Text::Alignment::JUSTIFIED)
            {
                int space_count = 0;
                for (const auto &c : text.characters)
                {
                    if (c.line == i + 1 && c.c == " ")
                    {
                        space_count++;
                    }
                }
                if (space_count > 0)
                {
                    int extra_space = leftover_w / space_count;
                    int offset = 0;
                    for (auto &c : text.characters)
                    {
                        if (c.line == i + 1)
                        {
                            if (c.c == " ")
                            {
                                c.x += offset;
                                offset += extra_space;
                            }
                            else
                            {
                                c.x += offset;
                            }
                        }
                    }
                }
            }
        }
    }

    // Update function for rendering and applying effects
    void text_update(Text &text, float dt, float x, float y, float r, float sx, float sy)
    {
        // Push a transformation matrix
        rlPushMatrix(); // TODO: push, draw commands should be abstracted to layers

        // Apply transformations for position, rotation, and scaling
        rlTranslatef(x, y, 0); // Translate to the specified position
        rlRotatef(r, 0, 0, 1); // Rotate around the Z-axis
        rlScalef(sx, sy, 1);   // Scale in X and Y directions

        // Iterate through each character
        for (auto &c : text.characters)
        {
            // Apply all effects to the character
            for (const auto &effect : c.effects)
            {
                // The first element of effect_table is the effect name
                const std::string &effect_name = effect.effectName;

                // Find the corresponding effect function in the text_effects map
                auto effect_it = text.text_effects.find(effect_name);
                if (effect_it != text.text_effects.end())
                {
                    auto &effect_function = effect_it->second;

                    // Extract arguments (starting from the second element of effect_table)
                    std::vector<std::any> args = effect.arguments;

                    // Call the effect function
                    Layer tempLayer;
                    effect_function(dt, tempLayer, text, c, args); // TODO: layers are not implement atm
                }
            }

            // Push character-specific transformations
            rlPushMatrix();

            // Translate and offset the character
            rlTranslatef(c.x + c.ox - text.text_width / 2, c.y + c.oy - text.text_height / 2, 0);
            rlRotatef(c.r, 0, 0, 1); // Rotate the character
            rlScalef(c.sx, c.sy, 1); // Scale the character
            SPDLOG_DEBUG("Drawing character: {} at ({}, {}) with rotation {} and scale ({}, {}) and offset ({}, {})", c.c, c.x, c.y, c.r, c.sx, c.sy, c.ox, c.oy);

            // Draw the character
            DrawTextEx(
                text.font,
                c.c.c_str(), // Convert the character to a string
                {0, 0},                      // Draw at the transformed origin
                text.font.baseSize,          // Font size
                1.0f,                        // Spacing between characters
                BLACK                        // Default color
            );

            // Pop character-specific transformations
            rlPopMatrix();
        }

        // Pop the transformation matrix for the text object
        rlPopMatrix();

        // Mark first frame as false after the first update
        if (text.first_frame)
        {
            text.first_frame = false;
        }
    }
}