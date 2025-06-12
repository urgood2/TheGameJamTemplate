#pragma once

#include "raylib.h"
#include <string>
#include <vector>
#include <map>
#include <functional>
#include <regex>
#include <set>
#include <optional>

#include "core/globals.hpp"
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
        float rotation;   // r
        float scale;      // sx, sy
        Vector2 size{}; // w, h
        Vector2 shadowDisplacement{0, -1.5f}; // shadow offset
        float shadowHeight = 0.2f;
        std::optional<float> scaleXModifier, scaleYModifier; // optionally modify x or y scale separately
        Color color;
        std::unordered_map<std::string, Vector2> offsets; // offsets used by various effects
        std::unordered_map<std::string, Vector2> shadowDisplacementOffsets; // offsets used by various effects, applied to shadow
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

        // support images
        bool isImage = false;
        bool imageShadowEnabled = true; // Enable shadow effect for images. Uses shadow data from transform components
        std::string spriteUUID;
        float imageScale = 1.0f;
        Color fgTint = WHITE;
        Color bgTint = BLANK;        
    };

    extern std::map<std::string, std::function<void(float, Character &, const std::vector<std::string> &)>> effectFunctions;

    struct Text
    {
        // used to dynamically update the text
        //TODO: apply
        std::function<std::string(void)> get_value_callback; // Function to get the value to be shown as text. 
        std::function<void(entt::entity)> onStringContentUpdatedOrChangedViaCallback; // function which is called when the rawText is changed through get_value_callback or through setText(). Called after parseText is called anew to apply changes.
        
        std::vector<std::string> effectStringsToApplyGloballyOnTextChange; // these tags will be applied to all characters in the text when the text is updated. This is useful for applying effects to all characters in the text, such as pop-in or fade-in effects, consistently even when the content of the text is updated.
        
        std::function<void()> onFinishedEffect; // callback for when an effect that keeps track of finished state has finished in the last character of a text. Note that it doesn't keep track of multiple such effects, and will respond tot he first one that finishes.
        
        bool pop_in_enabled = false; // deprecated

        bool shadow_enabled = true; // Enable shadow effect for characters. Uses shadow data from transform components

        float width{}, height{}; // width and height of the entire text, updated every draw call
        
        
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
        float prevRenderScale = 1.0f; // used to check if the render scale has changed, so we can update the text
        float renderScale = 1.0f; // Modifies the scale of the entire text object. TODO: should probably be synced with the transform as well.
        std::string rawText; // can contain text with effect tags
        std::vector<Character> characters; // contains the generated characters, with their effects applied
        
        globals::FontData fontData;
        
        float fontSize{10.f};
        bool wrapEnabled = true;          // if enabled, will disrespect provided wrap width and behave like there is no wrap width at all
        //FIXME: wrap is bugged, so is alignment
        float wrapWidth;
        
        Alignment alignment = Alignment::LEFT; // 0: Left, 1: Center, 2: Right
        WrapMode wrapMode = WrapMode::WORD;
        float createdTime = -1; // time the text was created, used for pop-in animation
        std::unordered_map<std::string, float> effectStartTime;// keeps track of effect started times unique to each effect
        
        
        bool applyTransformRotationAndScale = true; // whether to apply the transform rotation and scale to this character. If false, dynamic motion, rotation, scale changes to the base transform will not affect the final output.
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

            TextBuilder &setFontData(const globals::FontData &fontData)
            {
                text_.fontData = fontData;
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

            TextBuilder &setCreatedTime(float time)
            {
                text_.createdTime = time;
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

        // extern void initEffects();

        extern Character createCharacter(entt::entity textEntity, int codepoint, const Vector2 &startPosition, const Font &font, float fontSize,
            float &currentX, float &currentY, float wrapWidth, Text::Alignment alignment,
            float &currentLineWidth, std::vector<float> &lineWidths, int index, int &lineNumber);

        extern void adjustAlignment(entt::entity textEntity, const std::vector<float> &lineWidths);

        extern ParsedEffectArguments splitEffects(const std::string &effects);
        
        extern auto createTextEntity(const Text &text, float x, float y) -> entt::entity;
        
        extern Vector2 calculateBoundingBox (entt::entity textEntity);

        extern std::string CodepointToString(int codepoint);
        
        extern Character createImageCharacter(entt::entity textEntity, const std::string &uuid, float width, float height, float scale,
            Color fg, Color bg,
            const Vector2 &startPosition, // Added to match createCharacter
            float &currentX, float &currentY,
            float wrapWidth,
            Text::Alignment alignment,
            float &currentLineWidth, std::vector<float> &lineWidths,
            int index, int &lineNumber);

        extern void parseText(entt::entity textEntity);
        void handleEffectSegment(const char *&effectPos, std::vector<float> &lineWidths, float &currentLineWidth, float &currentX, entt::entity textEntity, float &currentY, int &lineNumber, int &codepointIndex, TextSystem::ParsedEffectArguments &parsedArguments);
        extern void updateText(entt::entity textEntity, float dt);

        extern void renderText(entt::entity textEntity, std::shared_ptr<layer::Layer> layerPtr, bool debug = true);

        extern void clearAllEffects(entt::entity textEntity);

        extern void applyGlobalEffects(entt::entity textEntity, const std::string &effectString);

        extern void debugPrintText(entt::entity textEntity);

        extern void resizeTextToFit(entt::entity textEntity, float targetWidth, float targetHeight, bool centerLaterally =true, bool centerVertically = true);
        extern void setTextScaleAndRecenter(entt::entity textEntity, float renderScale, float targetWidth, float targetHeight, bool centerLaterally, bool centerVertically);
        extern void resetTextScaleAndLayout(entt::entity textEntity);
        
        extern void setText(entt::entity textEntity, const std::string &text);

    } // namespace Functions


    extern auto exposeToLua(sol::state &lua) -> void;

} // namespace TextSystem
