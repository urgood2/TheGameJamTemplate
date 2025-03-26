
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

namespace text
{
    // ---------------------------------------------------------
    // Structures
    // ---------------------------------------------------------
    
    struct Layer
    {
        void set_color(const std::string &color)
        {
            // TODO: not sure what this does ATM
        }
    };

    enum class Alignment {
        LEFT,
        CENTER,
        RIGHT,
        JUSTIFIED
    };

    // A structure to hold parsed effect details
    struct ParsedEffect
    {
        std::string effectName;                                   // Name of the effect (e.g., "color")
        std::vector<std::any> arguments; // Effect arguments (e.g., "red", 5.0)
    };

    // A structure to hold parsed text details (each field with its effects)
    struct ParsedText
    {
        size_t i;                                // Start index of the field
        std::string field;                       // The text field inside [ ]
        std::string effects;                     // The effects inside ( )
        std::vector<ParsedEffect> parsedEffects; // Fully parsed effects
    };

    struct Text;

    struct Shake
    {
        float x = 0.0f;
        float y = 0.0f;
    };

    struct Character
    {
        
        Shake shake_amount;

        std::string c;        // The character itself
        
        std::vector<ParsedEffect> effects; // Effects applied to this character

        int x = 0, y = 0;     // Local position
        int line = 0;         // Line number
        float r = 0;          // Rotation
        float sx = 1, sy = 1; // Scale
        float ox = 0, oy = 0; // Offset
        int w = 0, h = 0;     // Width and height

        void shake_init()
        {
            // TODO: not sure what this does
        }

        // applies shake effect
        void shake_shake(float intensity, float duration)
        {
            // TODO: not sure what this does atm
        }
    };

    // Define type for effect functions
    using EffectFunction = std::function<void(float, Layer &, Text &, Character &, const std::vector<std::any> &)>;

    struct Text
    {
        std::string raw_text;

        std::vector<Character> characters;

        bool first_frame = true; // only true on first frame of being activated

        Font font;

        std::map<std::string, EffectFunction> text_effects;

        enum class Alignment
        {
            CENTER,
            JUSTIFIED,
            RIGHT,
            LEFT
        } alignment = Alignment::LEFT;

        int wrap_width{0};             // wrap width (pixels?)
        int text_width{0};             // width of the text (pixels?)
        int text_height{0};            // height of the text (pixels?)
        float height_multiplier{1.0f}; // font spacing vertical
    };
    
    // ---------------------------------------------------------
    // Variables
    // ---------------------------------------------------------

    // Default text effects map
    extern std::map<std::string, EffectFunction> default_text_effects;
    
    // ---------------------------------------------------------
    // Main Functions
    // ---------------------------------------------------------
    
    extern auto text_parse(Text &text) -> void;
    
    extern auto text_format(Text &text) -> void;

    extern void text_update(Text &text, float dt, float x, float y, float r, float sx, float sy);
    
    // ---------------------------------------------------------
    // Utility
    // ---------------------------------------------------------
    extern auto text_init(std::string rawText, const Font &font, const std::map<std::string, EffectFunction> &textEffects, Text::Alignment alignment = Text::Alignment::LEFT, float heightMultiplier = 1.f, float wrapWidth = 300) -> Text;
    extern std::any parseArg(const std::string &arg);
    extern std::vector<std::string> splitEffects(const std::string &effects);
    extern ParsedEffect parseEffect(const std::string &effect);
    extern std::vector<ParsedText> parseRawText(const std::string &rawText);
    extern std::vector<Character> buildCharacters(const std::string &rawText, const std::vector<ParsedText> &parsedText);
}