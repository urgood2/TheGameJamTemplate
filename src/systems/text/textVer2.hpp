#pragma once

#include "raylib.h"
#include <string>
#include <vector>
#include <map>
#include <functional>
#include <regex>
#include <set>
#include <optional>

#include "util/common_headers.hpp"

//TODO: some error-checking to ensure that all tags are enclosed

namespace TextSystem
{

    struct ParsedEffectArguments
    {
        std::map<std::string, std::vector<std::string>> arguments; // Effect name -> List of arguments
    };

    // c - an anchor object, which is a table containing .x, .y, .r, .sx, .sy, .ox, .oy, .c, .line, .i and .effects attributes
    struct Text;

    struct Character
    {
        int value;        // Unicode codepoint value
        std::optional<int> overrideCodepoint; // override the character with a different codepoint
        Vector2 position; // x, y
        float rotation;   // r
        float scale;      // sx, sy
        Vector2 size{}; // w, h
        Vector2 shadowDisplacement{0, -1.5f}; // shadow offset
        float shadowHeight = 0.2f;
        std::optional<float> scaleXModifier, scaleYModifier; // optionally modify x or y scale separately
        Color color;
        std::unordered_map<std::string, Vector2> offsets; // offsets used by various effects
        std::unordered_map<std::string, float> scaleModifiers; // scale used by various effects
        std::unordered_map<std::string, float> customData; // cutom data storage for effects
        Vector2 offset; // just the base offset
        std::map<std::string, std::function<void(float, Character &, const std::vector<std::string> &)>> effects{};
        ParsedEffectArguments parsedEffectArguments{}; // Parsed arguments for effects
        int index;                                   // Index of the character in the text
        int lineNumber;                              // Line number of the character
        bool firstFrame = true;                      // only true on first frame of being activated
        std::set<std::string> tags;                  // these can be accessed/set programatically for identifying specific characters later, idk if necessary but it seems like a good feature

        //FIXME: pop-in is deprecated in favor of using the pop-in effect.
        std::optional<float> pop_in;       // New: Pop-in animation state (0 to 1)
        std::optional<float> pop_in_delay; // New: Delay for pop-in based on character index

        float createdTime = -1; // time the text was created

        std::shared_ptr<Text> parentText; // pointer to the parent text object

        bool isFinalCharacterInText = false; // whether this character is the last character in the text
        std::unordered_map<std::string, bool> effectFinished; // keeps track of whether an effect has finished, not tracked by all effects but only by effects that need to know when they are done, such as pop. This is used in tandem with isFinalCharacterInText to trigger callbacks when the last character in the text has finished all relevant effects.
    };

    struct Text
    {
        std::function<void()> onFinishedEffect; // callback for when an effect that keeps track of finished state has finished in the last character of a text. Note that it doesn't keep track of multiple such effects, and will respond tot he first one that finishes.
        
        bool pop_in_enabled = false; // New: Enable pop-in animation for individual characters

        bool shadow_enabled = true; // New: Enable shadow effect for characters. Uses shadow data from transform components

        
        
        float width{}, height{}; // width and height of the text, updated every draw call
        
        enum class Alignment
        {
            LEFT,
            CENTER,
            RIGHT,
            JUSTIFIED
        };
        enum class WrapMode
        {
            WORD,
            CHARACTER
        };
        std::string rawText;
        std::vector<Character> characters;
        std::map<std::string, std::function<void(float, Character &, const std::vector<std::string> &)>> effectFunctions;
        Font font;
        float fontSize;
        bool wrapEnabled = true;          // if enabled, will disrespect provided wrap width and behave like there is no wrap width at all
        float wrapWidth;
        Alignment alignment = Alignment::LEFT; // 0: Left, 1: Center, 2: Right
        WrapMode wrapMode = WrapMode::WORD;
        int spacing = 1;        // spacing amount used when rendering & calculating text
        float createdTime = -1; // time the text was created, used for pop-in animation
        std::unordered_map<std::string, float> effectStartTime;// keeps track of effect started times unique to each effect
    };

    namespace Builders
    {
        class TextBuilder
        {
        public:
            TextBuilder()
            {
                text_ = {};
            }

            TextBuilder &setRawText(const std::string &text)
            {
                text_.rawText = text;
                return *this;
            }

            TextBuilder &setFont(Font font)
            {
                text_.font = font;
                return *this;
            }

            TextBuilder &setOnFinishedEffect(std::function<void()> callback)
            {
                text_.onFinishedEffect = callback;
                return *this;
            }

            TextBuilder &setFontSize(float size)
            {
                text_.fontSize = size;
                return *this;
            }

            TextBuilder &setWrapWidth(float width)
            {
                text_.wrapWidth = width;
                return *this;
            }

            TextBuilder &setAlignment(Text::Alignment align)
            {
                text_.alignment = align;
                return *this;
            }

            TextBuilder &setWrapMode(Text::WrapMode mode)
            {
                text_.wrapMode = mode;
                return *this;
            }

            TextBuilder &setSpacing(int spacing)
            {
                text_.spacing = spacing;
                return *this;
            }

            TextBuilder &setCreatedTime(float time)
            {
                text_.createdTime = time;
                return *this;
            }

            TextBuilder &setEffectFunctions(const std::map<std::string, std::function<void(float, Character &, const std::vector<std::string> &)>> &functions)
            {
                text_.effectFunctions = functions;
                return *this;
            }

            TextBuilder &setPopInEnabled(bool enabled)
            {
                text_.pop_in_enabled = enabled;
                return *this;
            }

            Text build()
            {
                // set created time
                if (text_.createdTime == -1)
                {
                    text_.createdTime = GetTime();
                }
                return text_;
            }

        private:
            Text text_;
        };
    }

    namespace Functions
    {

        extern void initEffects(Text &text);

        extern Character createCharacter(entt::entity textEntity, int codepoint, const Vector2 &startPosition, const Font &font, float fontSize,
            float &currentX, float &currentY, float wrapWidth, Text::Alignment alignment,
            float &currentLineWidth, std::vector<float> &lineWidths, int index, int &lineNumber);

        extern void adjustAlignment(entt::entity textEntity, const std::vector<float> &lineWidths);

        extern ParsedEffectArguments splitEffects(const std::string &effects);
        
        extern auto createTextEntity(const Text &text, float x, float y) -> entt::entity;
        
        extern Vector2 calculateBoundingBox (entt::entity textEntity);

        extern std::string CodepointToString(int codepoint);

        extern void parseText(entt::entity textEntity);
        void handleEffectSegment(const char *&effectPos, std::vector<float> &lineWidths, float &currentLineWidth, float &currentX, entt::entity textEntity, float &currentY, int &lineNumber, int &codepointIndex, TextSystem::ParsedEffectArguments &parsedArguments);
        extern void updateText(entt::entity textEntity, float dt);

        extern void renderText(entt::entity textEntity, std::shared_ptr<layer::Layer> layerPtr, bool debug = false);

        extern void clearAllEffects(entt::entity textEntity);

        extern void applyGlobalEffects(entt::entity textEntity, const std::string &effectString);

    } // namespace Functions

} // namespace TextSystem
