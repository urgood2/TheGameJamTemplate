#include "textVer2.hpp"

#include "raylib.h"
#include <string>
#include <vector>
#include <map>
#include <functional>
#include <regex>
#include <iostream>
#include <spdlog/spdlog.h>

#include "rlgl.h"

#include "text_effects.hpp"

#include "util/common_headers.hpp"
#include "util/utilities.hpp"
#include "systems/transform/transform_functions.hpp"
#include "systems/transform/transform.hpp"

#include "core/init.hpp"

#include "../../core/globals.hpp"

namespace TextSystem
{
    std::map<std::string, std::function<void(float, Character &, const std::vector<std::string> &)>> effectFunctions;

    namespace Functions
    {
        
        // automatically runs parseText() on the given text configuration and returns a transform-enabled entity
        auto createTextEntity(const Text &text, float x, float y) -> entt::entity
        {
            auto entity = transform::CreateOrEmplace(&globals::registry, globals::gameWorldContainerEntity, x, y, 1, 1);
            auto &transform = globals::registry.get<transform::Transform>(entity);
            auto &gameObject = globals::registry.get<transform::GameObject>(entity);
            auto &textComp = globals::registry.emplace<Text>(entity, text);

            // update the text if there is a callback
            if (textComp.get_value_callback)
            {
                textComp.rawText = textComp.get_value_callback();

                SPDLOG_DEBUG("Text value callback returned: {}", textComp.rawText);
            }
            
            if (effectFunctions.empty())
            {
                TextSystem::initEffects();
            }
            parseText(entity);

            // apply effects if any are set
            if (textComp.effectStringsToApplyGloballyOnTextChange.size() > 0)
            {
                for (auto &tag : textComp.effectStringsToApplyGloballyOnTextChange)
                {
                    applyGlobalEffects(entity, tag);
                    SPDLOG_DEBUG("Applying global effects for tag: {}", tag);
                }
            }

            //TODO: testing
            gameObject.state.dragEnabled = true;
            gameObject.state.hoverEnabled = true;
            gameObject.state.collisionEnabled = true;
            gameObject.state.clickEnabled = true;
            return entity;
        }
        
        

        #include <algorithm> // For std::min

        // Function to resize text entity to fit the given target width and height
        // also modifes the offset so that the text is still in the same location as before with respect to the top left corner
        // the centering is done by modifying the offset of the transform
        void resizeTextToFit(entt::entity textEntity, float targetWidth, float targetHeight, bool centerLaterally, bool centerVertically)
        {
            auto &transform = globals::registry.get<transform::Transform>(textEntity);
            auto &text = globals::registry.get<Text>(textEntity);
            auto &role = globals::registry.get<transform::InheritedProperties>(textEntity);
            
            auto [width, height] = calculateBoundingBox(textEntity);
            
            // calculate the scale factor to fit the target width and height
            float scaleX = targetWidth / width;
            float scaleY = targetHeight / height;
            float scale = std::min(scaleX, scaleY); // Use the smaller scale factor to maintain aspect ratio
            
            // apply the new scale
            text.renderScale = scale;
            
            // if necessary, center the text laterally and vertically
            if (centerLaterally)
            {
                role.offset->x = (targetWidth - width * scale) / 2.0f;
            }
            else 
            {
                role.offset->x = 0.0f; // Reset lateral offset if not centering
            }
            if (centerVertically)
            {
                role.offset->y = (targetHeight - height * scale) / 2.0f;
            }
            else 
            {
                role.offset->y = 0.0f; // Reset vertical offset if not centering
            }
        }




        Character createCharacter(entt::entity textEntity, int codepoint, const Vector2 &startPosition, const Font &font, float fontSize,
                                  float &currentX, float &currentY, float wrapWidth, Text::Alignment alignment,
                                  float &currentLineWidth, std::vector<float> &lineWidths, int index, int &lineNumber)
        {
            auto &text = globals::registry.get<Text>(textEntity);
            
            int utf8Size = 0;
            const char *utf8Char = CodepointToUTF8(codepoint, &utf8Size);
            std::string characterString(utf8Char, utf8Size); // Create a string with the exact size
            Vector2 charSize = MeasureTextEx(font, characterString.c_str(), fontSize, 1.0f);
            // apply renderscale
            charSize.x *= text.renderScale;
            charSize.y *= text.renderScale;

            // Check for line wrapping, do this only if character wrapping is enabled
            if (text.wrapMode == Text::WrapMode::CHARACTER && wrapWidth > 0 && (currentX - startPosition.x) + charSize.x > wrapWidth)
            {
                lineWidths.push_back(currentLineWidth); // Save the width of the completed line
                currentX = startPosition.x;             // Reset to the start of the line
                currentY += charSize.y;                 // Move to the next line
                currentLineWidth = 0.0f;                // Reset current line width
                lineNumber++;                           // Increment line number
            }

            // spdlog::debug("Creating character: '{}' (codepoint: {}), x={}, y={}, line={}", characterString, codepoint, currentX, currentY, lineNumber);

            Character character{};

            character.value = codepoint;
            character.offset.x =currentX- startPosition.x;
            character.offset.y = currentY - startPosition.y;
            character.size.x = charSize.x;
            character.size.y = charSize.y;
            character.index = index;
            character.lineNumber = lineNumber;
            character.color = WHITE;
            character.scale = 1.0f;
            character.rotation = 0.0f;
            character.createdTime = text.createdTime;

            SPDLOG_DEBUG("Creating character: '{}' (codepoint: {}), x={}, y={}, line={}, offsetY={}, offsetX={}", characterString, codepoint, currentX, currentY, lineNumber, character.offset.y, character.offset.x);
            if (text.pop_in_enabled)
            {
                character.pop_in = 0.0f;
                character.pop_in_delay = index * 0.1f; // Staggered pop-in effect
            }

            currentX += text.fontData.spacing * text.renderScale + charSize.x;         // Advance X position (include spacing)
            currentLineWidth += charSize.x + text.fontData.spacing * text.renderScale; // Update line width
            return character;
        }

        void adjustAlignment(entt::entity textEntity, const std::vector<float> &lineWidths)
        {
            auto &text = globals::registry.get<Text>(textEntity);
            
            float scaledWrapWidth = text.wrapWidth / text.renderScale;
            
            // spdlog::debug("Adjusting alignment for text with alignment mode: {}", magic_enum::enum_name<Text::Alignment>(text.alignment));

            for (size_t line = 0; line < lineWidths.size(); ++line)
            {
                float leftoverWidth = scaledWrapWidth - lineWidths[line];
                // spdlog::debug("Line {}: leftoverWidth = {}, wrapWidth = {}, lineWidth = {}", line, leftoverWidth, text.wrapWidth, lineWidths[line]);

                if (leftoverWidth <= 0.0f)
                {
                    // spdlog::debug("Line {} fits perfectly, skipping alignment.", line);
                    continue; // Skip alignment for lines that perfectly fit
                }

                if (text.alignment == Text::Alignment::CENTER)
                { // Center alignment
                    // spdlog::debug("Applying center alignment for line {}", line);
                    for (auto &character : text.characters)
                    {
                        if (character.lineNumber == line)
                        {
                            // spdlog::debug("Before: Character '{}' at x={}", character.value, character.offset.x);
                            character.offset.x += leftoverWidth / 2.0f;
                            // spdlog::debug("After: Character '{}' at x={}", character.value, character.offset.x);
                        }
                    }
                }
                else if (text.alignment == Text::Alignment::RIGHT)
                { // Right alignment
                    // spdlog::debug("Applying right alignment for line {}", line);
                    for (auto &character : text.characters)
                    {
                        if (character.lineNumber == line)
                        {
                            auto currentLineWidth = lineWidths[line];
                            // spdlog::debug("Before: Character '{}' at x={}", character.value, character.offset.x);
                            character.offset.x = character.offset.x - currentLineWidth + text.wrapWidth;
                            // spdlog::debug("After: Character '{}' at x={}", character.value, character.offset.x);
                        }
                    }
                }
                else if (text.alignment == Text::Alignment::JUSTIFIED)
                { // Justified alignment
                    // spdlog::debug("Applying justified alignment for line {}", line);

                    size_t spacesCount = 0;
                    std::vector<size_t> spaceIndices; // To track indices of spaces for debugging

                    for (size_t i = 0; i < text.characters.size(); ++i)
                    {
                        const auto &character = text.characters[i];
                        if (character.lineNumber == line && character.value == ' ')
                        {
                            spacesCount++;
                            spaceIndices.push_back(i); // Save index of the space
                        }
                    }

                    // spdlog::debug("Line {}: spacesCount = {}", line, spacesCount);

                    if (spacesCount > 0)
                    {
                        float addedSpacePerSpace = leftoverWidth / spacesCount;
                        // spdlog::debug("Line {}: addedSpacePerSpace = {}", line, addedSpacePerSpace);

                        float cumulativeShift = 0.0f;

                        for (auto &character : text.characters)
                        {
                        
                            if (character.lineNumber == line)
                            {
                                if (character.value == ' ')
                                {
                                    // spdlog::debug("Space character at x={} gets additional space: {}", character.offset.x, addedSpacePerSpace);
                                    cumulativeShift += addedSpacePerSpace;
                                }

                                // spdlog::debug("Before: Character '{}' at x={}", character.value, character.offset.x);
                                character.offset.x += cumulativeShift;
                                // spdlog::debug("After: Character '{}' at x={}", character.value, character.offset.x);
                            }
                        }

                        // Debug: Print all space positions for this line
                        for (size_t index : spaceIndices)
                        {
                            auto &spaceCharacter = text.characters[index];
                            // spdlog::debug("Space character position: x={}, y={}, index={}", spaceCharacter.offset.x, spaceCharacter.offset.y, index);
                        }
                    }
                    else
                    {
                        // spdlog::warn("Line {} has no spaces, skipping justified alignment.", line);
                    }
                }
            }
        }

        Character createImageCharacter(entt::entity textEntity, const std::string &uuid, float width, float height, float scale,
            Color fg, Color bg,
            const Vector2 &startPosition, // Added to match createCharacter
            float &currentX, float &currentY,
            float wrapWidth,
            Text::Alignment alignment,
            float &currentLineWidth, std::vector<float> &lineWidths,
            int index, int &lineNumber)
        {
            auto &text = globals::registry.get<Text>(textEntity);

            // Scale image size based on render scale and imageScale
            float scaledWidth = width * scale * text.renderScale;
            float scaledHeight = height * scale * text.renderScale;

            // get max line height 
            float maxLineHeight = MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y;
            float lineHeight = text.fontSize * text.renderScale; // Approximate line height (same as text char height)
            float verticalOffset = (lineHeight - scaledHeight) * 0.5f;

            // Line wrapping check (same logic as character layout)
            if (text.wrapMode == Text::WrapMode::CHARACTER && wrapWidth > 0 &&
                (currentX - startPosition.x) + scaledWidth > wrapWidth)
            {
                lineWidths.push_back(currentLineWidth); // Save the width of the completed line
                currentX = startPosition.x;             // Reset X to start of line
                currentY += scaledHeight;               // Move Y down by line height
                currentLineWidth = 0.0f;                // Reset width accumulator
                lineNumber++;                           // Move to next line
            }

            Character imgChar;
            imgChar.value = 0;
            imgChar.isImage = true;
            imgChar.spriteUUID = uuid;
            imgChar.imageScale = scale;
            imgChar.fgTint = fg;
            imgChar.bgTint = bg;
            imgChar.offset.x = currentX - startPosition.x;
            imgChar.offset.y = currentY - startPosition.y + verticalOffset; // Adjust Y offset for image height, to center it vertically
            imgChar.size.x = scaledWidth;
            imgChar.size.y = scaledHeight;
            imgChar.index = index;
            imgChar.lineNumber = lineNumber;
            imgChar.color = WHITE;
            imgChar.scale = 1.0f;
            imgChar.rotation = 0.0f;
            imgChar.createdTime = text.createdTime;

            SPDLOG_DEBUG("Creating image character '{}' @ {},{} size {}x{}", uuid, currentX, currentY, scaledWidth, scaledHeight);

            if (text.pop_in_enabled)
            {
                imgChar.pop_in = 0.0f;
                imgChar.pop_in_delay = index * 0.1f;
            }

            // Advance cursor and width
            currentX += scaledWidth + text.fontData.spacing * text.renderScale;
            currentLineWidth += scaledWidth + text.fontData.spacing * text.renderScale;

            return imgChar;
        }

        ParsedEffectArguments splitEffects(const std::string &effects)
        {
            // spdlog::debug("Splitting effects: {}", effects);
            ParsedEffectArguments parsedArguments;

            std::regex pattern(R"((\w+)(?:=([\-\w\.,]+))?)"); // Matches 'name' or 'name=arg,...'
            auto begin = std::sregex_iterator(effects.begin(), effects.end(), pattern);
            auto end = std::sregex_iterator();

            for (std::sregex_iterator i = begin; i != end; ++i)
            {
                std::smatch match = *i;
                std::string effectName = match[1];
                std::vector<std::string> args;

                if (match[2].matched)
                {
                    std::string argsString = match[2];
                    size_t pos = 0;
                    while ((pos = argsString.find(',')) != std::string::npos)
                    {
                        args.push_back(argsString.substr(0, pos));
                        argsString.erase(0, pos + 1);
                    }
                    args.push_back(argsString); // last arg
                }

                parsedArguments.arguments[effectName] = args;
            }

            return parsedArguments;
        }

        auto deleteCharacters(entt::entity textEntity)
        {
            auto &text = globals::registry.get<Text>(textEntity);
            // for (auto &character : text.characters)
            // {
            //     globals::registry.destroy(character);
            // }
            text.characters.clear();
        }

        void parseText(entt::entity textEntity)
        {
            // if characters are not cleared, delete them
            deleteCharacters(textEntity);

            auto &text = globals::registry.get<Text>(textEntity);
            auto &transform = globals::registry.get<transform::Transform>(textEntity);

            // float effectiveWrapWidth = text.wrapEnabled ? text.wrapWidth : std::numeric_limits<float>::max();
            float effectiveWrapWidth = text.wrapEnabled ? text.wrapWidth : std::numeric_limits<float>::max();
            effectiveWrapWidth /= text.renderScale;

            Vector2 textPosition = {transform.getActualX(), transform.getActualY()};
            
            // spdlog::debug("Parsing text: {}", text.rawText);

            const char *rawText = text.rawText.c_str();

            std::regex pattern(R"(\[(.*?)\]\((.*?)\))"); // support [img](uuid=SPRITE_UUID;scale=1.2;fg=FFFFFF;bg=000000)
            std::smatch match;
            std::string regexText = text.rawText;

            const char *currentPos = regexText.c_str(); // Pointer to current position in the string

            float currentX = transform.getActualX();
            float currentY = transform.getActualY();

            std::vector<float> lineWidths; // To store widths of all lines
            float currentLineWidth = 0.0f;

            int codepointIndex = 0; // Index in the original text
            int lineNumber = 0;     // Line number for characters

            // Regex matching on raw UTF-8 text
            while (std::regex_search(regexText, match, pattern))
            {
                // spdlog::debug("Match found: {} with effects: {}", match[1].str(), match[2].str());

                // spdlog::debug("Match position: {}, length: {}", match.position(0), match.length(0));
                // spdlog::debug("Processing plain text before the match");
                // spdlog::debug("Plain text string: {}", std::string(currentPos, match.position(0)));

                // Process plain text before the match
                while (currentPos < regexText.c_str() + match.position(0))
                {
                    // get string at match position
                    std::string plainText(currentPos, match.position(0) - (currentPos - regexText.c_str()));

                    int codepointSize = 0;
                    int codepoint = GetCodepointNext(currentPos, &codepointSize);

                    if (codepoint == '\n') // Handle line breaks
                    {
                        lineWidths.push_back(currentLineWidth); // Save current line width
                        currentX = transform.getActualX();             // Reset X position
                        currentY += MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y * text.renderScale;
                        currentLineWidth = 0.0f;
                        lineNumber++;
                    }

                    else if (codepoint == ' ' && text.wrapMode == Text::WrapMode::WORD) // Detect spaces, only for word wrap
                    {
                        // Look ahead to calculate the width of the next word
                        const char *lookaheadPos = currentPos + codepointSize;
                        float nextWordWidth = 0.0f;

                        // Accumulate the width of the next word
                        std::string lookaheadChar{};
                        std::string lookaheadCharString{};
                        while (*lookaheadPos && *lookaheadPos != ' ' && *lookaheadPos != '\n')
                        {
                            int lookaheadCodepointSize = 0;
                            int lookaheadCodepoint = GetCodepointNext(lookaheadPos, &lookaheadCodepointSize);

                            // Measure the size of the character and add to the word's width
                            lookaheadChar = CodepointToString(lookaheadCodepoint);
                            lookaheadCharString = lookaheadCharString + lookaheadChar;
                            Vector2 charSize = MeasureTextEx(text.fontData.font, lookaheadChar.c_str(), text.fontSize, 1.0f);
                            charSize.x *= text.renderScale;
                            charSize.y *= text.renderScale;
                            nextWordWidth += charSize.x;

                            // Advance the lookahead pointer
                            lookaheadPos += lookaheadCodepointSize;
                        }

                        // Check if the next word will exceed the wrap width
                        if ((currentX - transform.getActualX()) + nextWordWidth > effectiveWrapWidth)
                        {
                            // spdlog::debug("Wrap would have exceeded width: currentX={}, wrapWidth={}, nextWordWidth={}, exceeds={}", currentX, effectiveWrapWidth, nextWordWidth, (currentX - transform.getActualX()) + nextWordWidth);

                            // If the next word exceeds the wrap width, move to the next line
                            lineWidths.push_back(currentLineWidth);                           // Save current line width
                            currentX = transform.getActualX();                                       // Reset X position
                            currentY += MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y  * text.renderScale; // Move to the next line
                            currentLineWidth = 0.0f;
                            lineNumber++;

                            // // spdlog::debug("Word wrap: Moving to next line before processing space at x={}, y={}, line={}, with word {}",
                            //               currentX, currentY, lineNumber, lookaheadCharString);
                        }
                        else
                        {
                            auto character = createCharacter(textEntity, codepoint, textPosition, text.fontData.font, text.fontSize,
                                                             currentX, currentY, effectiveWrapWidth, text.alignment,
                                                             currentLineWidth, lineWidths, codepointIndex, lineNumber);
                            text.characters.push_back(character);
                        }
                    }
                    else if (codepoint == ' ' && text.wrapMode == Text::WrapMode::CHARACTER) // Detect spaces
                    {
                        if (currentX == transform.getActualX())
                        {
                            // Skip the space character at the beginning of the line
                            currentPos += codepointSize; // Advance pointer
                            codepointIndex++;
                            continue;
                        }
                        else
                        {
                            auto character = createCharacter(textEntity, codepoint, textPosition, text.fontData.font, text.fontSize,
                                                             currentX, currentY, effectiveWrapWidth, text.alignment,
                                                             currentLineWidth, lineWidths, codepointIndex, lineNumber);
                            text.characters.push_back(character);
                        }
                    }
                    else
                    {
                        auto character = createCharacter(textEntity, codepoint, textPosition, text.fontData.font, text.fontSize,
                                                         currentX, currentY, effectiveWrapWidth, text.alignment,
                                                         currentLineWidth, lineWidths, codepointIndex, lineNumber);
                        text.characters.push_back(character);
                    }

                    currentPos += codepointSize; // Advance pointer
                    codepointIndex++;
                }

                // Process matched effect text
                std::string effectText = match[1];
                std::string effects = match[2];
                

                if (effectText == "img")
                {
                    // this has to be an image character, ignore effect text
                    ParsedEffectArguments imgArgs = splitEffects(effects);

                    // extract image params
                    std::string uuid = imgArgs.arguments["uuid"].empty() ? "" : imgArgs.arguments["uuid"][0];
                    float scale = imgArgs.arguments["scale"].empty() ? 1.0f : std::stof(imgArgs.arguments["scale"][0]);
                    Color fgTint = util::getColor(imgArgs.arguments["fg"].empty() ? "WHITE" : imgArgs.arguments["fg"][0]);
                    Color bgTint = util::getColor(imgArgs.arguments["bg"].empty() ? "BLANK" : imgArgs.arguments["bg"][0]);
                    bool shadow = imgArgs.arguments["shadow"].empty() ? false : (imgArgs.arguments["shadow"][0] == "true" || imgArgs.arguments["shadow"][0] == "1");

                    // scaling for image
                    //TODO: fetch the sprite size, scale it down to fit the text heigth
                    float maxFontHeight = MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y * text.renderScale;
                    auto spriteFrame = init::getSpriteFrame(uuid);
                    auto desiredImageHeight = maxFontHeight * scale;
                    auto desiredImageWidth = spriteFrame.frame.width * (desiredImageHeight / spriteFrame.frame.height);
                    
                    // wrapping check
                    //TODO: maybe refactor this
                    if ((currentX - transform.getActualX()) + desiredImageWidth > effectiveWrapWidth)
                    {
                        lineWidths.push_back(currentLineWidth);
                        currentX = transform.getActualX();
                        currentY += maxFontHeight;
                        currentLineWidth = 0.0f;
                        lineNumber++;
                    } 

                    auto imageChar = createImageCharacter(textEntity, uuid, desiredImageWidth, desiredImageHeight, scale,
                        fgTint, bgTint,
                        textPosition, currentX, currentY, effectiveWrapWidth, text.alignment,
                        currentLineWidth, lineWidths, codepointIndex, lineNumber);

                    imageChar.imageShadowEnabled = shadow; // Set shadow effect for images
                    
                    text.characters.push_back(imageChar);

                    // move regexText and currentPos forward
                    regexText = match.suffix().str();
                    currentPos = regexText.c_str();
                    continue; // skip to next match
                }

                // spdlog::debug("Processing effect text: {}", effectText);

                // handle normal effect text
                const char *effectPos = effectText.c_str();
                ParsedEffectArguments parsedArguments = splitEffects(effects);
                handleEffectSegment(effectPos, lineWidths, currentLineWidth, currentX, textEntity, currentY, lineNumber, codepointIndex, parsedArguments);

                // Update regexText to process the suffix
                regexText = match.suffix().str();

                // FIXME: this does not set current position properly on the second matched effect text
                // TODO: get the position of the suffix and set currentPos to that
                //  Advance currentPos past the matched section
                //  currentPos = regexText.c_str() + (match.position(0) + match.length(0));
                currentPos = regexText.c_str();
            }

            // spdlog::debug("Processing plain text after the last match: {}", currentPos);
            while (*currentPos)
            {
                // get string at match position
                std::string plainText(currentPos, match.position(0) - (currentPos - regexText.c_str()));

                int codepointSize = 0;
                int codepoint = GetCodepointNext(currentPos, &codepointSize);

                if (codepoint == '\n') // Handle line breaks
                {
                    lineWidths.push_back(currentLineWidth); // Save current line width
                    currentX = transform.getActualX();             // Reset X position
                    currentY += MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y  * text.renderScale;
                    currentLineWidth = 0.0f;
                    lineNumber++;
                }

                else if (codepoint == ' ' && text.wrapMode == Text::WrapMode::WORD) // Detect spaces
                {
                    // Look ahead to calculate the width of the next word
                    const char *lookaheadPos = currentPos + codepointSize;
                    float nextWordWidth = 0.0f;

                    // Accumulate the width of the next word
                    std::string lookaheadChar{};
                    std::string lookaheadCharString{};
                    while (*lookaheadPos && *lookaheadPos != ' ' && *lookaheadPos != '\n')
                    {
                        int lookaheadCodepointSize = 0;
                        int lookaheadCodepoint = GetCodepointNext(lookaheadPos, &lookaheadCodepointSize);

                        // Measure the size of the character and add to the word's width
                        lookaheadChar = CodepointToString(lookaheadCodepoint);
                        lookaheadCharString = lookaheadCharString + lookaheadChar;
                        Vector2 charSize = MeasureTextEx(text.fontData.font, lookaheadChar.c_str(), text.fontSize, 1.0f);
                        charSize.x *= text.renderScale;
                        charSize.y *= text.renderScale;
                        nextWordWidth += charSize.x;

                        // Advance the lookahead pointer
                        lookaheadPos += lookaheadCodepointSize;
                    }

                    // Check if the next word will exceed the wrap width
                    if ((currentX - transform.getActualX()) + nextWordWidth > effectiveWrapWidth)
                    {
                        // If the next word exceeds the wrap width, move to the next line
                        lineWidths.push_back(currentLineWidth);                           // Save current line width
                        currentX = transform.getActualX();                                       // Reset X position
                        currentY += MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y  * text.renderScale; // Move to the next line
                        currentLineWidth = 0.0f;
                        lineNumber++;

                        // spdlog::debug("Word wrap: Moving to next line before processing space at x={}, y={}, line={}, with word {}",
                        //               currentX, currentY, lineNumber, lookaheadCharString);
                    }
                    else
                    {
                        // FIXME: Ignore the space character if line changed
                        auto character = createCharacter(textEntity, codepoint, textPosition, text.fontData.font, text.fontSize,
                                                         currentX, currentY, effectiveWrapWidth, text.alignment,
                                                         currentLineWidth, lineWidths, codepointIndex, lineNumber);
                        text.characters.push_back(character);
                    }
                }
                else if (codepoint == ' ' && text.wrapMode == Text::WrapMode::CHARACTER) // Detect spaces
                {
                    // does adding the char take us over the wrap width?
                    if ((currentX - transform.getActualX()) + MeasureTextEx(text.fontData.font, " ", text.fontSize, 1.0f).x  * text.renderScale > effectiveWrapWidth)
                    {
                        // if so skip this space character

                        // Skip the space character at the beginning of the line
                        currentPos += codepointSize; // Advance pointer
                        codepointIndex++;
                        continue;
                    }
                    else
                    {
                        auto character = createCharacter(textEntity, codepoint, textPosition, text.fontData.font, text.fontSize,
                                                         currentX, currentY, effectiveWrapWidth, text.alignment,
                                                         currentLineWidth, lineWidths, codepointIndex, lineNumber);
                        text.characters.push_back(character);
                    }
                }
                else
                {
                    auto character = createCharacter(textEntity, codepoint, textPosition, text.fontData.font, text.fontSize,
                                                     currentX, currentY, effectiveWrapWidth, text.alignment,
                                                     currentLineWidth, lineWidths, codepointIndex, lineNumber);
                    text.characters.push_back(character);
                }

                currentPos += codepointSize; // Advance pointer
                codepointIndex++;
            }

            // Save the last line's width
            if (currentLineWidth > 0.0f)
            {
                lineWidths.push_back(currentLineWidth);
            }

            // Adjust alignment after parsing
            adjustAlignment(textEntity, lineWidths);

            // print all characters out for debugging
            for (const auto &character : text.characters)
            {
                int utf8Size = 0;
                // spdlog::debug("Character: '{}', x={}, y={}, line={}", CodepointToUTF8(character.value, &utf8Size), character.offset.x, character.offset.y, character.lineNumber);
            }

            auto ptr = std::make_shared<Text>(text);
            
            for (auto &character : text.characters)
            {
                character.parentText = ptr;
            }

            // get last character
            if (!text.characters.empty())
            {
                auto &lastCharacter = text.characters.back();
                lastCharacter.isFinalCharacterInText = true;
            }
        
            // gotta reflect final width and height
            auto [width, height] = calculateBoundingBox(textEntity);
            transform.setActualW(width);
            transform.setActualH(height);
        }

        void handleEffectSegment(const char *&effectPos, std::vector<float> &lineWidths, float &currentLineWidth, float &currentX, entt::entity textEntity, float &currentY, int &lineNumber, int &codepointIndex, TextSystem::ParsedEffectArguments &parsedArguments)
        {
            auto &text = globals::registry.get<Text>(textEntity);
            auto &transform = globals::registry.get<transform::Transform>(textEntity);
            Vector2 textPosition = {transform.getActualX(), transform.getActualY()};

            float effectiveWrapWidth = text.wrapEnabled ? text.wrapWidth : std::numeric_limits<float>::max();

            bool firstCharacter = true;
            while (*effectPos)
            {
                int codepointSize = 0;
                int codepoint = GetCodepointNext(effectPos, &codepointSize);

                // check wrapping for first character
                if (firstCharacter && text.wrapMode == Text::WrapMode::CHARACTER) {

                }
                else if (firstCharacter && text.wrapMode == Text::WrapMode::WORD) {
                    // Look ahead to measure next word
                    const char *lookaheadPos = effectPos + codepointSize;
                    float nextWordWidth = 0.0f;
                    std::string lookaheadWord;
                    while (*lookaheadPos && *lookaheadPos != ' ' && *lookaheadPos != '\n')
                    {
                        int lookaheadSize = 0;
                        int lookaheadCodepoint = GetCodepointNext(lookaheadPos, &lookaheadSize);
                        std::string utf8Char = CodepointToString(lookaheadCodepoint);
                        //TODO: spacing should omitted if the previous character is a space or the first character of the string
                        nextWordWidth += text.fontData.spacing + MeasureTextEx(text.fontData.font, utf8Char.c_str(), text.fontSize, 1.0f).x  * text.renderScale;
                        lookaheadPos += lookaheadSize;
                    }

                    //TODO: spacing seems off?

                    // just reposition in next line without skippin codepoint
                    if ((currentX - textPosition.x) + nextWordWidth > effectiveWrapWidth)
                    {
                        lineWidths.push_back(currentLineWidth);
                        currentX = textPosition.x;
                        currentY += MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y * text.renderScale;
                        currentLineWidth = 0.0f;
                        lineNumber++;
                    }
                }

                if (codepoint == '\n') // Explicit line break in effect text
                {
                    lineWidths.push_back(currentLineWidth);
                    currentX = textPosition.x;
                    currentY += MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y * text.renderScale;
                    currentLineWidth = 0.0f;
                    lineNumber++;
                }
                else if (codepoint == ' ')
                {
                    if (text.wrapMode == Text::WrapMode::WORD)
                    {
                        // Look ahead to measure next word
                        const char *lookaheadPos = effectPos + codepointSize;
                        float nextWordWidth = 0.0f;
                        std::string lookaheadWord;
                        while (*lookaheadPos && *lookaheadPos != ' ' && *lookaheadPos != '\n')
                        {
                            int lookaheadSize = 0;
                            int lookaheadCodepoint = GetCodepointNext(lookaheadPos, &lookaheadSize);
                            std::string utf8Char = CodepointToString(lookaheadCodepoint);
                            //TODO: spacing should omitted if the previous character is a space or the first character of the string
                            nextWordWidth += text.fontData.spacing + MeasureTextEx(text.fontData.font, utf8Char.c_str(), text.fontSize, 1.0f).x * text.renderScale;
                            lookaheadPos += lookaheadSize;
                        }

                        //TODO: spacing seems off?

                        if ((currentX - textPosition.x) + nextWordWidth > effectiveWrapWidth)
                        {
                            lineWidths.push_back(currentLineWidth);
                            currentX = textPosition.x;
                            currentY += MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y * text.renderScale;
                            currentLineWidth = 0.0f;
                            lineNumber++;
                            effectPos += codepointSize;
                            codepointIndex++;
                            continue;
                        }
                    }
                    else if (text.wrapMode == Text::WrapMode::CHARACTER)
                    {
                        float spaceWidth = MeasureTextEx(text.fontData.font, " ", text.fontSize, 1.0f).x * text.renderScale;
                        if ((currentX - textPosition.x) + spaceWidth > effectiveWrapWidth)
                        {
                            // Skip space at start of line
                            effectPos += codepointSize;
                            codepointIndex++;
                            continue;
                        }
                    }
                }

                // Create and store character
                auto character = createCharacter(textEntity, codepoint, textPosition, text.fontData.font, text.fontSize,
                                                      currentX, currentY, effectiveWrapWidth, text.alignment,
                                                      currentLineWidth, lineWidths, codepointIndex, lineNumber);

                character.parsedEffectArguments = parsedArguments;

                for (const auto &[effectName, args] : parsedArguments.arguments)
                {
                    if (effectFunctions.count(effectName))
                    {
                        character.effects[effectName] = effectFunctions[effectName];
                    }
                }

                text.characters.push_back(character);
                effectPos += codepointSize;
                codepointIndex++;

                firstCharacter = false;
            }
        }
        
        void setText(entt::entity textEntity, const std::string &text)
        {
            auto &textComponent = globals::registry.get<Text>(textEntity);
            textComponent.rawText = text;
            textComponent.renderScale = 1.0f;
            
            clearAllEffects(textEntity);
            deleteCharacters(textEntity);
            parseText(textEntity);
        }

        void updateText(entt::entity textEntity, float dt)
        {
            
            auto &gameWorldTransform = globals::registry.get<transform::Transform>(globals::gameWorldContainerEntity);
            auto &textTransform = globals::registry.get<transform::Transform>(textEntity);

            auto &text = globals::registry.get<Text>(textEntity);
            // spdlog::debug("Updating text with delta time: {}", dt);

            // check value from lamdba function if there is one
            
            // check if renderscale changed
            if (text.renderScale != text.prevRenderScale) {
                spdlog::debug("Render scale changed from {} to {}", text.prevRenderScale, text.renderScale);
                text.prevRenderScale = text.renderScale;
                
                // update transform dimensions
                auto [width, height] = calculateBoundingBox(textEntity);
                textTransform.setActualW(width);
                textTransform.setActualH(height);
            }

            if (text.get_value_callback)
            {
                auto value = text.get_value_callback();
                if (value != text.rawText)
                {
                    // reset renderscale
                    text.renderScale = 1.0f;

                    // SPDLOG_DEBUG("Text value changed from '{}' to '{}'", text.rawText, value);
                    text.rawText = value;
                    clearAllEffects(textEntity);
                    parseText(textEntity);
                    for (auto tag : text.effectStringsToApplyGloballyOnTextChange) {
                        applyGlobalEffects(textEntity, tag);
                    }

                    // call callback
                    if (text.onStringContentUpdatedViaCallback)
                    {
                        text.onStringContentUpdatedViaCallback(textEntity);
                    }
                }
            }



            for (auto &character : text.characters)
            {
                // update shadow
                character.shadowDisplacement.x = ((textTransform.getActualX() + textTransform.getActualW() / 2) - (gameWorldTransform.getActualX() + gameWorldTransform.getActualW() / 2)) / (gameWorldTransform.getActualW() / 2) * 1.5f;

                // Apply Pop-in Animation
                //TODO: deprecated, use pop effect instead
                // if (character.pop_in && character.pop_in < 1.0f)
                // {
                //     float elapsedTime = GetTime() - text.createdTime - character.pop_in_delay.value_or(0.05f);
                //     if (elapsedTime > 0)
                //     {
                //         character.pop_in = std::min(1.0f, elapsedTime / 0.5f);                  // 0.5s duration
                //         character.pop_in = character.pop_in.value() * character.pop_in.value(); // Ease-in effect
                //     }
                // }

                // Apply all effects to the character
                for (const auto &[effectName, effectFunction] : character.effects)
                {
                    const auto &args = character.parsedEffectArguments.arguments.at(effectName);
                    // spdlog::debug("Applying effect: {} with arguments: {}", effectName, args.size());
                    effectFunction(dt, character, args);
                }

                // unset first frame flag
                character.firstFrame = false;

                // check if a character is the last one in the text, and there is an onFinishedAllEffects callback, and at least one effect is finished
                if (character.isFinalCharacterInText && text.onFinishedEffect && character.effectFinished.empty() == false)
                {
                    // run callback just once and clear
                    text.onFinishedEffect();
                    text.onFinishedEffect = nullptr;
                }
            }
        }

        std::string CodepointToString(int codepoint)
        {
            int utf8Size = 0;
            const char *utf8Char = CodepointToUTF8(codepoint, &utf8Size);

            if (utf8Size == 0 || utf8Char == nullptr)
            {
                // Return an empty string or handle invalid codepoint as needed
                spdlog::error("Invalid UTF-8 conversion for codepoint: {}", codepoint);
                return std::string();
            }

            // Construct a std::string from the UTF-8 character data
            return std::string(utf8Char, utf8Size);
        }
        
        //TODO: probably sync transform dimensions to this
        Vector2 calculateBoundingBox (entt::entity textEntity) {

            auto &text = globals::registry.get<Text>(textEntity);
            auto &transform = globals::registry.get<transform::Transform>(textEntity);

            // Calculate the bounding box dimensions
            float minX = std::numeric_limits<float>::max();
            float minY = std::numeric_limits<float>::max();
            float maxX = std::numeric_limits<float>::lowest();
            float maxY = std::numeric_limits<float>::lowest();

            // go through every character and get the highest offset, add the character's width to it
            for (auto &character: text.characters) {

                // get the character's position and size
                float charX = transform.getActualX() + character.offset.x * text.renderScale;
                float charY = transform.getActualY() +character.offset.y * text.renderScale;
                float charWidth = MeasureTextEx(text.fontData.font, CodepointToString(character.value).c_str(), text.fontSize, 1.0f).x * text.renderScale;
                float charHeight = MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y * text.renderScale; // Assuming height is same for all characters

                // Update min and max values
                minX = std::min(minX, charX);
                minY = std::min(minY, charY);
                maxX = std::max(maxX, charX + charWidth);
                maxY = std::max(maxY, charY + charHeight);
            }

            // auto &lastChar = text.characters.back();
            // // get line height of last character
            // float lineHeight = MeasureTextEx(text.fontData.font, "A", text.fontSize, 1.0f).y;
            // maxY = transform.getActualY() + (lastChar.lineNumber + 1) * (lineHeight);

            float width = maxX - minX;
            float height = maxY - minY;

            // use transform scale to calculate the final width and height
            width *= transform.getVisualScaleWithHoverAndDynamicMotionReflected();
            height *= transform.getVisualScaleWithHoverAndDynamicMotionReflected();
            
            return {width, height};
        }

        void renderText(entt::entity textEntity, std::shared_ptr<layer::Layer> layerPtr, bool debug)
        {
            auto &text = globals::registry.get<Text>(textEntity);
            auto &textTransform = globals::registry.get<transform::Transform>(textEntity);
            float renderScale = text.renderScale; // 🟡 Use renderScale


            layer::AddPushMatrix(layerPtr);

            // Apply entity-level transforms
            layer::AddTranslate(layerPtr,
                textTransform.getVisualX() + textTransform.getVisualW() * 0.5f,
                textTransform.getVisualY() + textTransform.getVisualH() * 0.5f,
                0);
                
            if (text.applyTransformRotationAndScale)
            {
                layer::AddScale(layerPtr,
                    textTransform.getVisualScaleWithHoverAndDynamicMotionReflected(),
                    textTransform.getVisualScaleWithHoverAndDynamicMotionReflected(),
                    1);
                    
                layer::AddRotate(layerPtr,
                    textTransform.getVisualRWithDynamicMotionAndXLeaning());
            }
            
            layer::AddTranslate(layerPtr,
                -textTransform.getVisualW() * 0.5f,
                -textTransform.getVisualH() * 0.5f,
                0);


            for (const auto &character : text.characters)
            {

                // if (character.isImage) 
                    // SPDLOG_DEBUG("Rendering image character: {} with size: {}x{}", character.value, character.size.x, character.size.y);
                

                float popInScale = 1.0f;
                if (character.pop_in)
                {
                    popInScale = character.pop_in.value();
                }

                // Calculate character position with offset
                Vector2 charPosition = {
                    character.offset.x * renderScale,
                    character.offset.y * renderScale};

                // add all optional offsets
                for (const auto &[effectName, offset] : character.offsets)
                {
                    charPosition.x += offset.x * renderScale;
                    charPosition.y += offset.y * renderScale;
                }
                

                // Convert the codepoint to UTF-8 string for rendering
                int utf8Size = 0;
                const char *utf8Char = CodepointToUTF8(character.overrideCodepoint.value_or(character.value), &utf8Size);
                auto utf8String = CodepointToString(character.overrideCodepoint.value_or(character.value));

                Vector2 charSize = MeasureTextEx(text.fontData.font, utf8String.c_str(), text.fontSize, 1.0f);
                charSize.x *= text.renderScale;
                charSize.y *= text.renderScale;

                if (character.isImage) { 
                    charSize.x = character.size.x * renderScale;
                    charSize.y = character.size.y * renderScale;
                }

                // sanity checkdd
                if (charSize.x == 0)
                {
                    spdlog::warn("Missing glyph for character: '{}'. Replacing with '?'.", utf8Char);
                    utf8Char = "?";
                }

                float finalScale = character.scale * popInScale;
                // apply additional scale modifiers
                for (const auto &[effectName, scaleModifier] : character.scaleModifiers)
                {
                    finalScale *= scaleModifier;
                }
                float finalScaleX = character.scaleXModifier.value_or(1.0f) * finalScale;
                float finalScaleY = character.scaleYModifier.value_or(1.0f) * finalScale;
                finalScaleX *= text.fontData.fontScale;
                finalScaleY *= text.fontData.fontScale;

                // add fontdata offset for finetuning
                if (!character.isImage) {
                    charPosition.x += text.fontData.fontRenderOffset.x * finalScaleX * renderScale;
                    charPosition.y += text.fontData.fontRenderOffset.y * finalScaleY * renderScale;
                }

                layer::AddPushMatrix(layerPtr);

                // apply scaling that is centered on the character
                layer::AddTranslate(layerPtr, charPosition.x + charSize.x * 0.5f, charPosition.y + charSize.y * 0.5f, 0);
                layer::AddScale(layerPtr, finalScaleX, finalScaleY, 1);
                layer::AddRotate(layerPtr, character.rotation);
                layer::AddTranslate(layerPtr, -charSize.x * 0.5f, -charSize.y * 0.5f, 0);


                // render shadow if enabled
                // draw shadow based on shadow displacement
                if (text.shadow_enabled)
                {
                    float baseExaggeration = globals::BASE_SHADOW_EXAGGERATION;
                    float heightFactor = 1.0f + character.shadowHeight; // Increase effect based on height

                    float rawScale = text.renderScale;
                    float scaleFactor = std::clamp(rawScale * rawScale, 0.01f, 1.0f);

                    // Adjust for font size (reduce shadow effect when font size < 30)
                    float fontSize = static_cast<float>(globals::fontData.fontLoadedSize);
                    float fontFactor = std::clamp(fontSize / 60.0f, 0.05f, 1.0f); // Tunable lower bound, higher denominator = less shadow

                    // Final combined scale factor
                    float finalFactor = scaleFactor * fontFactor;

                    float shadowOffsetX = character.shadowDisplacement.x * baseExaggeration * heightFactor * finalFactor;
                    float shadowOffsetY = -character.shadowDisplacement.y * baseExaggeration * heightFactor * finalFactor;

                    
                    // float shadowOffsetX = character.shadowDisplacement.x * baseExaggeration * heightFactor * renderScale;
                    // float shadowOffsetY = - character.shadowDisplacement.y * baseExaggeration * heightFactor * renderScale; // make shadow stretch downward
                    
                    // apply offsets to shadow if any
                    for (const auto &[effectName, offset] : character.shadowDisplacementOffsets)
                    {
                        shadowOffsetX += offset.x;
                        shadowOffsetY += offset.y;
                    }

                    // Translate to shadow position
                    layer::AddTranslate(layerPtr, -shadowOffsetX, shadowOffsetY);

                    

                    if (character.isImage) {
                        auto spriteFrame = init::getSpriteFrame(character.spriteUUID);
                        auto sourceRect = spriteFrame.frame;
                        auto atlasTexture = globals::textureAtlasMap[spriteFrame.atlasUUID];
                        auto destRect = Rectangle{0, 0, character.size.x, character.size.y};
                        layer::AddTexturePro(layerPtr, atlasTexture, sourceRect, 0, 0, {destRect.width, destRect.height}, {0, 0}, 0, Fade(BLACK, 0.7f)); 
                    }
                    else {
                        // Draw shadow 
                        layer::AddTextPro(layerPtr, utf8String.c_str(), text.fontData.font, 0, 0, {0, 0}, 0, text.fontSize * renderScale, text.fontData.spacing, Fade(BLACK, 0.7f));
                    }

                    // Reset translation to original position
                    layer::AddTranslate(layerPtr, shadowOffsetX, -shadowOffsetY);
                }

                // Render the character
                if (character.isImage) {
                    auto spriteFrame = init::getSpriteFrame(character.spriteUUID);
                    auto sourceRect = spriteFrame.frame;
                    auto atlasTexture = globals::textureAtlasMap[spriteFrame.atlasUUID];
                    auto destRect = Rectangle{0, 0, character.size.x, character.size.y};
                    layer::AddTexturePro(layerPtr, atlasTexture, sourceRect, 0, 0, {destRect.width, destRect.height}, {0, 0}, 0, character.fgTint); 
                }
                else {
                    layer::AddTextPro(layerPtr, utf8String.c_str(), text.fontData.font, 0, 0, {0, 0}, 0, text.fontSize * renderScale, text.fontData.spacing, character.color);
                }
                
                if (debug && globals::drawDebugInfo) {
                    // subtract finetuning offset
                    if (!character.isImage) {
                        layer::AddTranslate(layerPtr, - text.fontData.fontRenderOffset.x * finalScaleX * renderScale, - text.fontData.fontRenderOffset.y * finalScaleY * renderScale, 0);
                    }
                    
                    
                    // draw bounding box for the character
                    layer::AddRectangleLinesPro(layerPtr, 0, 0, charSize, 1.0f, BLUE);
                }
                
                layer::AddPopMatrix(layerPtr);
            }

            // Draw debug bounding box
            if (debug && globals::drawDebugInfo)
            {
                auto &transform = globals::registry.get<transform::Transform>(textEntity);
                
                // Calculate the bounding box dimensions
                auto [width, height] = calculateBoundingBox(textEntity);

                //FIXME: known bug where this bounding box stretchs to the right and down when scaled up, instead of being centered
                
                // Draw the bounding box for the text
                // layer::AddRectangleLinesPro(layerPtr, 0, 0, {width, height}, 5.0f, WHITE);
                // DrawRectangleLines(transform.getVisualX(), transform.getVisualY(), width, height, GRAY);

                // Draw text showing the dimensions
                std::string dimensionsText = "Width: " + std::to_string(width) + ", Height: " + std::to_string(height);
                layer::AddText(layerPtr, dimensionsText.c_str(), GetFontDefault(), 0, -20, GRAY, 10); // Position the text above the box
            }
            
            layer::AddPopMatrix(layerPtr); // Pops the entity-level transform
            
        }

        void clearAllEffects(entt::entity textEntity)
        {
            auto &text = globals::registry.get<Text>(textEntity);
            for (auto &character : text.characters)
            {

                character.effects.clear();
                character.parsedEffectArguments.arguments.clear();
                character.scaleModifiers.clear();
                character.offsets.clear();
                character.shadowDisplacementOffsets.clear();
                character.scaleXModifier.reset();
                character.scaleYModifier.reset();
                character.overrideCodepoint.reset();
                character.effectFinished.clear();
            }

        }

        void applyGlobalEffects(entt::entity textEntity, const std::string &effectString)
        {
            auto &text = globals::registry.get<Text>(textEntity);
            ParsedEffectArguments parsedArguments = splitEffects(effectString);

            for (auto &character : text.characters)
            {
                character.parsedEffectArguments.arguments.insert(parsedArguments.arguments.begin(), parsedArguments.arguments.end());

                for (const auto &[effectName, args] : parsedArguments.arguments)
                {
                    if (effectFunctions.count(effectName))
                    {
                        character.effects[effectName] = effectFunctions[effectName];
                    }
                    else
                    {
                        spdlog::warn("Effect '{}' not registered. Skipping.", effectName);
                    }
                }
            }
        }

        void debugPrintText(entt::entity textEntity)
        {
            auto &text = globals::registry.get<Text>(textEntity);
            SPDLOG_DEBUG("Text Entity: {}", static_cast<int>(textEntity));
            SPDLOG_DEBUG("\tText: {}", text.rawText);
            SPDLOG_DEBUG("\tFont: {}", text.fontData.font.baseSize);
            SPDLOG_DEBUG("\tFont Size: {}", text.fontSize);
            // SPDLOG_DEBUG("Position: ({}, {})", text.position.x, text.position.y);
            SPDLOG_DEBUG("\tAlignment: {}", magic_enum::enum_name<Text::Alignment>(text.alignment));
            SPDLOG_DEBUG("\tWrap Width: {}", text.wrapWidth);
            SPDLOG_DEBUG("\tWrap Mode: {}", static_cast<int>(text.wrapMode));
            SPDLOG_DEBUG("\tSpacing: {}", text.fontData.spacing);
            SPDLOG_DEBUG("\tShadow Enabled: {}", text.shadow_enabled);
            SPDLOG_DEBUG("\tPop-in Enabled: {}", text.pop_in_enabled);
            SPDLOG_DEBUG("\tCharacters: {}", text.characters.size());
            for (const auto &character : text.characters)
            {
                int byteCount = 0;
                SPDLOG_DEBUG("Character: '{}', Position (relative): ({}, {}), Line Number: {}, Effects: {}", CodepointToUTF8(character.value, &byteCount), character.offset.x, character.offset.y, character.lineNumber, character.effects.size());
                for (const auto &[effectName, effectFunction] : character.effects)
                {
                    SPDLOG_DEBUG("\t\tEffect: {}", effectName);
                }
            }
        }

    } // namespace Functions
} // namespace TextSystem

// // Example Usage
// int main() {
//     spdlog::set_level(spdlog::level::debug);
//     InitWindow(800, 600, "Text Effects System");
//     SetTargetFPS(60);

//     Font font = LoadFont("resources/arial.ttf");
//     TextSystem::Text text{
//         "Hello [World](color=red;x=4;y=4)", font, 20.0f, 400.0f, Vector2{100, 100}, 0};

//     TextSystem::Functions::initEffects(text);
//     TextSystem::Functions::parseText(text);

//     while (!WindowShouldClose()) {
//         BeginDrawing();
//         ClearBackground(RAYWHITE);

//         TextSystem::Functions::render(text, GetFrameTime());

//         EndDrawing();
//     }

//     UnloadFont(font);
//     CloseWindow();

//     return 0;
// }
