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

#include "../../core/globals.hpp"

namespace TextSystem
{

    namespace Functions
    {

        // Exponential easing
        auto easeInExpo = [](float x)
        {
            return (x <= 0.0f) ? 0.0f : std::pow(2.0f, 10.0f * (x - 1.0f));
        };

        auto easeOutExpo = [](float x)
        {
            return (x >= 1.0f) ? 1.0f : 1.0f - std::pow(2.0f, -10.0f * x);
        };

        // adds some default effects to the text. This is a good place to add custom effects
        void initEffects(Text &text)
        {
            spdlog::debug("Initializing effects for text.");
            text.effectFunctions["color"] = [](float dt, Character &character, const std::vector<std::string> &args)
            {
                if (!args.empty())
                {
                    std::string colorName = args[0];
                    // spdlog::debug("Applying color effect: {}", colorName);
                    if (colorName == "red")
                    {
                        character.color = RED;
                    }
                    else if (colorName == "blue")
                    {
                        character.color = BLUE;
                    }
                }
            };

            text.effectFunctions["shake"] = [](float dt, Character &character, const std::vector<std::string> &args)
            {
                auto effectName = "shake";
                if (character.offsets.find(effectName) == character.offsets.end())
                {
                    character.offsets[effectName] = Vector2{0, 0};
                }
                if (args.size() >= 2)
                {
                    try
                    {
                        float shakeX = std::stof(args[0]);
                        float shakeY = std::stof(args[1]);
                        character.offsets[effectName].x = sin(GetTime() * 10.0f + character.index * 5) * shakeX;
                        character.offsets[effectName].y = cos(GetTime() * 10.0f + character.index * 5) * shakeY;
                        // spdlog::debug("Applying shake effect with arguments: x={}, y={}", shakeX, shakeY);
                    }
                    catch (const std::exception &)
                    {
                        spdlog::error("Invalid argument type for shake effect");
                    }
                }
            };

            // Four arguments: min scale, max scale, pulse speed, stagger offset (optional)
            text.effectFunctions["pulse"] = [](float dt, Character &character, const std::vector<std::string> &args)
            {
                float minScale = 0.8f;
                float maxScale = 1.2f;
                float pulseSpeed = 2.0f;
                float stagger = 0.0f;

                try
                {
                    if (!args.empty())
                        minScale = std::stof(args[0]);
                    if (args.size() >= 2)
                        maxScale = std::stof(args[1]);
                    if (args.size() >= 3)
                        pulseSpeed = std::stof(args[2]);
                    if (args.size() >= 4)
                        stagger = std::stof(args[3]);

                    if (maxScale < minScale)
                        std::swap(minScale, maxScale);
                }
                catch (const std::exception &)
                {
                    spdlog::warn("Invalid pulse effect arguments; using defaults.");
                }

                float time = GetTime() * pulseSpeed + character.index * stagger;
                float wave = (std::sin(time) + 1.0f) * 0.5f; // Normalize to 0–1
                character.scale = minScale + (maxScale - minScale) * wave;
            };

            text.effectFunctions["rotate"] = [](float dt, Character &character, const std::vector<std::string> &args)
            {
                float speed = 2.0f;  // Default speed (Hz)
                float angle = 25.0f; // Default rotation angle in degrees

                try
                {
                    if (!args.empty())
                        speed = std::stof(args[0]);
                    if (args.size() >= 2)
                        angle = std::stof(args[1]);
                }
                catch (const std::exception &)
                {
                    spdlog::warn("Invalid arguments for 'rotate' effect; using defaults.");
                }

                character.rotation = std::sin(GetTime() * speed + character.index * 10.0f) * angle;
            };

            text.effectFunctions["float"] = [](float dt, Character &character, const std::vector<std::string> &args)
            {
                float speed = 2.5f;
                float amplitude = 5.0f;
                float phaseOffsetPerChar = 4.0f;

                try
                {
                    if (args.size() >= 1)
                        speed = std::stof(args[0]);
                    if (args.size() >= 2)
                        amplitude = std::stof(args[1]);
                    if (args.size() >= 3)
                        phaseOffsetPerChar = std::stof(args[2]);
                }
                catch (const std::exception &)
                {
                    spdlog::warn("Invalid arguments for 'float' effect; using defaults.");
                }

                const char *effectName = "float";
                if (character.offsets.find(effectName) == character.offsets.end())
                {
                    character.offsets[effectName] = Vector2{0, 0};
                }

                character.offsets[effectName].y = std::sin(GetTime() * speed + character.index * phaseOffsetPerChar) * amplitude;
            };

            text.effectFunctions["bump"] = [](float dt, Character &character, const std::vector<std::string> &args)
            {
                // === Configurable parameters ===
                float speed = 6.0f;     // Oscillation speed (e.g., 2.0 = medium bounce rate)
                float amplitude = 3.0f; // Bump height in pixels (e.g., 4.0 = small bump, 10.0 = big pop)
                float threshold = 0.8f; // Trigger cutoff (0.0 to 1.0). Lower = more frequent bumps. Higher = snappier, rarer bumps
                                        // e.g., 0.9 means "only bump when sine wave is near its peak"
                float stagger = 1.2f;   // Phase offset per character index (e.g., 0.0 = all bump together, 1.0 = ripple effect)

                try
                {
                    if (!args.empty())
                        speed = std::stof(args[0]); // Example: bump=3.0
                    if (args.size() >= 2)
                        amplitude = std::stof(args[1]); // Example: bump=3.0,6.0
                    if (args.size() >= 3)
                        threshold = std::stof(args[2]); // Example: bump=3.0,6.0,0.8
                    if (args.size() >= 4)
                        stagger = std::stof(args[3]); // Example: bump=3.0,6.0,0.8,0.25
                }
                catch (const std::exception &)
                {
                    spdlog::warn("Invalid bump effect args; using defaults.");
                }

                const char *effectName = "bump";
                if (character.offsets.find(effectName) == character.offsets.end())
                {
                    character.offsets[effectName] = Vector2{0, 0};
                }

                // Time-based sine wave with optional character phase offset
                float time = GetTime() * speed + character.index * stagger;
                float wave = (std::sin(time) + 1.0f) * 0.5f; // Normalize sine to 0–1

                // Apply bump only when wave exceeds threshold (creates a snap/jump instead of a floaty sine)
                float bump = (wave > threshold) ? amplitude : 0.0f;

                character.offsets[effectName].y = bump;
            };

            // this is the same as rotation, but has different defaults
            text.effectFunctions["wiggle"] = [](float dt, Character &character, const std::vector<std::string> &args)
            {
                float speed = 10.0f; // how fast it wiggles
                float angle = 10.0f; // max angle in degrees
                float stagger = 1.0f;

                try
                {
                    if (!args.empty())
                        speed = std::stof(args[0]);
                    if (args.size() >= 2)
                        angle = std::stof(args[1]);
                    if (args.size() >= 3)
                        stagger = std::stof(args[2]);
                }
                catch (...)
                {
                }

                character.rotation = std::sin(GetTime() * speed + character.index * stagger) * angle;
            };

            // TODO: Make the rest of the effects, including pop-in. pop-out, etc.

            // FIXME: only works for entire text only, partial text will lag too much
            text.effectFunctions["slide"] = [](float dt, Character &character, const std::vector<std::string> &args)
            {
                if (character.firstFrame)
                {
                    character.firstFrame = false;
                    character.createdTime = GetTime();
                }

                float duration = 0.3f;           // How long the slide takes
                float stagger = 0.1f;            // Delay per character index
                std::string alphaMode = "in";    // "in", "out", or ""
                std::string directionMode = "l"; // "l", "r", "t", "b"

                try
                {
                    if (!args.empty())
                        duration = std::stof(args[0]);
                    if (args.size() >= 2)
                        stagger = std::stof(args[1]);
                    if (args.size() >= 3)
                        alphaMode = args[2];
                    if (args.size() >= 4)
                        directionMode = args[3];
                }
                catch (...)
                {
                }

                const char *effectName = "slide";

                float timeAlive = static_cast<float>(GetTime()) - character.createdTime;

                // Apply stagger delay
                float timeOffset = character.index * stagger;
                float localTime = std::max(0.0f, timeAlive - timeOffset);

                // Clamp t between 0 and 1
                float t = std::clamp(localTime / duration, 0.0f, 1.0f);

                // Set initial offset once
                if (character.offsets.find(effectName) == character.offsets.end())
                {
                    Vector2 offset{0, 0};
                    float magnitude = 50.0f;

                    if (directionMode == "l")
                        offset = Vector2{-magnitude, 0}; // left to right
                    else if (directionMode == "r")
                        offset = Vector2{magnitude, 0}; // right to left
                    else if (directionMode == "t")
                        offset = Vector2{0, -magnitude}; // top to bottom
                    else if (directionMode == "b")
                        offset = Vector2{0, magnitude}; // bottom to top

                    character.offsets[effectName] = offset;
                }

                // Ease out the offset
                auto &offset = character.offsets[effectName];
                if (alphaMode == "in")
                {
                    offset.x = easeInExpo(t) * offset.x;
                    offset.y = easeInExpo(t) * offset.y;
                }
                else if (alphaMode == "out")
                {
                    offset.x = (1.0f - easeOutExpo(t)) * offset.x;
                    offset.y = (1.0f - easeOutExpo(t)) * offset.y;
                }
                // offset.x *= (1.0f - t);
                // offset.y *= (1.0f - t);

                // Alpha fade
                if (!alphaMode.empty())
                {
                    if (alphaMode == "in")
                    {
                        character.color.a = static_cast<unsigned char>(std::clamp(255.0f * t, 0.0f, 255.0f));
                    }
                    else if (alphaMode == "out")
                    {
                        character.color.a = static_cast<unsigned char>(std::clamp(255.0f * (1.0f - t), 0.0f, 255.0f));
                    }
                }

                // this is an effect that has a clear start and finish, so mark it.
                if (t >= 1.0f)
                {
                    character.effectFinished[effectName] = true;
                }
            };

            text.effectFunctions["pop"] = [](float dt, Character &character, const std::vector<std::string> &args)
            {
                if (character.firstFrame)
                {
                    character.firstFrame = false;
                    character.createdTime = GetTime();
                }

                float duration = 0.3f;   // Total pop duration
                float stagger = 0.1f;    // Delay per character index
                std::string mode = "in"; // "in" = pop in, "out" = pop out

                try
                {
                    if (!args.empty())
                        duration = std::stof(args[0]);
                    if (args.size() >= 2)
                        stagger = std::stof(args[1]);
                    if (args.size() >= 3)
                        mode = args[2];
                }
                catch (...)
                {
                }

                const char *effectName = "pop";

                float timeAlive = static_cast<float>(GetTime()) - character.createdTime;

                // Staggered delay with capped index
                float timeOffset = character.index * stagger;
                float localTime = std::max(0.0f, timeAlive - timeOffset);

                float t = std::clamp(localTime / duration, 0.0f, 1.0f);

                // Calculate scale factor
                float scale = 1.0f;
                if (mode == "in")
                    scale = easeOutExpo(t);
                else if (mode == "out")
                    scale = 1.0f - easeOutExpo(t);

                // Clamp to avoid visual glitches
                scale = std::clamp(scale, 0.0f, 1.0f);

                // Apply scale (non-destructive)
                character.scaleModifiers[effectName] = scale;

                // this is an effect that has a clear start and finish, so mark it.
                if (t >= 1.0f)
                {
                    character.effectFinished[effectName] = true;
                }
            };

            text.effectFunctions["spin"] = [](float dt, Character &character, const std::vector<std::string> &args)
            {
                if (character.firstFrame)
                {
                    character.firstFrame = false;
                    character.createdTime = GetTime();
                }

                float speed = 1.0f;   // rotations per second
                float stagger = 0.5f; // delay per character index

                try
                {
                    if (!args.empty())
                        speed = std::stof(args[0]);
                    if (args.size() >= 2)
                        stagger = std::stof(args[1]);
                }
                catch (...)
                {
                    // Silently ignore parse errors
                }

                float currentTime = GetTime();
                float startTime = character.createdTime + character.index * stagger;

                if (currentTime >= startTime)
                {
                    float elapsed = currentTime - startTime;
                    character.rotation = elapsed * speed * 360.0f;
                }
                else
                {
                    character.rotation = 0.0f; // Not spinning yet
                }
            };

            text.effectFunctions["fade"] = [](float dt, Character &character, const std::vector<std::string> &args)
            {
                float speed = 3.0f;
                float minAlpha = 0.4f;
                float maxAlpha = 1.0f;
                float stagger = 0.5f;
                float frequency = 3.0f;

                try
                {
                    if (!args.empty())
                        speed = std::stof(args[0]);
                    if (args.size() >= 2)
                        minAlpha = std::stof(args[1]);
                    if (args.size() >= 3)
                        maxAlpha = std::stof(args[2]);
                    if (args.size() >= 4)
                        stagger = std::stof(args[3]);
                    if (args.size() >= 5)
                        frequency = std::stof(args[4]);
                }
                catch (...)
                {
                }

                float t = GetTime() * speed - character.index * stagger; // subtract to move left to right
                float normalized = (std::sin(t * frequency) + 1.0f) * 0.5f;
                float alpha = minAlpha + (maxAlpha - minAlpha) * normalized;
                character.color.a = static_cast<unsigned char>(alpha * 255.0f);
            };

            text.effectFunctions["highlight"] = [](float dt, Character &character, const std::vector<std::string> &args)
            {
                float speed = 4.0f;
                float brightness = 0.4f;
                float stagger = 0.5f;
                std::string direction = "right";
                std::string mode = "threshold"; // "bleed" or "threshold"
                float thresholdWidth = 0.7f;    // Only used in "threshold" mode
                std::optional<Color> highlightColor = YELLOW;

                try
                {
                    if (!args.empty())
                        speed = std::stof(args[0]);
                    if (args.size() >= 2)
                        brightness = std::stof(args[1]);
                    if (args.size() >= 3)
                        stagger = std::stof(args[2]);
                    if (args.size() >= 4)
                        direction = args[3];
                    if (args.size() >= 5)
                        mode = args[4];
                    if (args.size() >= 6)
                        thresholdWidth = std::stof(args[5]);

                    if (args.size() >= 7 && args[6].length() == 6)
                    {
                        // Parse hex color string like "FF9900"
                        unsigned int r = std::stoul(args[6].substr(0, 2), nullptr, 16);
                        unsigned int g = std::stoul(args[6].substr(2, 2), nullptr, 16);
                        unsigned int b = std::stoul(args[6].substr(4, 2), nullptr, 16);
                        highlightColor = Color{(unsigned char)r, (unsigned char)g, (unsigned char)b, 255};
                    }
                }
                catch (...)
                {
                }

                float indexOffset = (direction == "right") ? -character.index * stagger : character.index * stagger;
                float t = GetTime() * speed + indexOffset;

                float wave = (std::sin(t) + 1.0f) * 0.5f;
                float factor = wave;

                if (mode == "threshold")
                {
                    float center = 0.5f;
                    float lower = center - thresholdWidth * 0.5f;
                    float upper = center + thresholdWidth * 0.5f;
                    factor = (wave >= lower && wave <= upper) ? 1.0f : 0.0f;
                }

                auto lerp = [](float a, float b, float t)
                { return a + (b - a) * t; };

                Color base = character.color; // Replace with character.baseColor if available
                Color result = base;

                if (highlightColor.has_value())
                {
                    // Lerp toward highlightColor
                    result.r = static_cast<unsigned char>(std::clamp(lerp(base.r, highlightColor->r, factor), 0.0f, 255.0f));
                    result.g = static_cast<unsigned char>(std::clamp(lerp(base.g, highlightColor->g, factor), 0.0f, 255.0f));
                    result.b = static_cast<unsigned char>(std::clamp(lerp(base.b, highlightColor->b, factor), 0.0f, 255.0f));
                }
                else
                {
                    // Lerp toward white (brightness based)
                    result.r = static_cast<unsigned char>(std::clamp(lerp(base.r, 255.0f, brightness * factor), 0.0f, 255.0f));
                    result.g = static_cast<unsigned char>(std::clamp(lerp(base.g, 255.0f, brightness * factor), 0.0f, 255.0f));
                    result.b = static_cast<unsigned char>(std::clamp(lerp(base.b, 255.0f, brightness * factor), 0.0f, 255.0f));
                }

                character.color = result;
            };

            text.effectFunctions["rainbow"] = [](float dt, Character &character, const std::vector<std::string> &args)
            {
                float speed = 60.0f;         // Hue change speed (degrees/sec)
                float stagger = 10.0f;       // Phase delay per character
                float thresholdStep = 50.0f; // 0 = smooth rainbow, >0 = thresholded (e.g. 60.0 = 6-color rainbow)

                try
                {
                    if (!args.empty())
                        speed = std::stof(args[0]);
                    if (args.size() >= 2)
                        stagger = std::stof(args[1]);
                    if (args.size() >= 3)
                        thresholdStep = std::stof(args[2]); // NEW: optional threshold
                }
                catch (...)
                {
                }

                float hue = fmodf((GetTime() * speed - character.index * stagger), 360.0f);

                // Apply hue thresholding if set
                if (thresholdStep > 0.0f)
                {
                    hue = std::floor(hue / thresholdStep) * thresholdStep;
                }

                character.color = ColorFromHSV(hue, 1.0f, 1.0f);
            };

            text.effectFunctions["expand"] = [](float dt, Character &character, const std::vector<std::string> &args)
            {
                float speed = 2.0f;     // How fast it pulses
                float minScale = 0.8f;  // Minimum scale
                float maxScale = 1.2f;  // Maximum scale
                float stagger = 0.0f;   // Per-character delay
                std::string axis = "y"; // "x", "y", or "both"

                try
                {
                    if (!args.empty())
                        minScale = std::stof(args[0]);
                    if (args.size() >= 2)
                        maxScale = std::stof(args[1]);
                    if (args.size() >= 3)
                        speed = std::stof(args[2]);
                    if (args.size() >= 4)
                        stagger = std::stof(args[3]);
                    if (args.size() >= 5)
                        axis = args[4];
                }
                catch (...)
                {
                    spdlog::warn("Invalid expand effect args; using defaults.");
                }

                if (maxScale < minScale)
                    std::swap(minScale, maxScale);

                float t = GetTime() * speed + character.index * stagger;
                float wave = (std::sin(t) + 1.0f) * 0.5f; // Normalize 0–1
                float scale = minScale + (maxScale - minScale) * wave;

                if (axis == "x")
                {
                    character.scaleXModifier = scale;
                }
                else if (axis == "y")
                {
                    character.scaleYModifier = scale;
                }
                else
                {
                    character.scaleXModifier = scale;
                    character.scaleYModifier = scale;
                }
            };

            text.effectFunctions["bounce"] = [](float dt, Character &character, const std::vector<std::string> &args)
            {
                float gravity = 700.0f;
                float height = -20.0f; // Starting Y offset
                float duration = 0.5f; // Time to fall to ground
                float stagger = 0.1f;  // Optional delay per character

                try
                {
                    if (!args.empty())
                        gravity = std::stof(args[0]);
                    if (args.size() >= 2)
                        height = std::stof(args[1]);
                    if (args.size() >= 3)
                        duration = std::stof(args[2]);
                    if (args.size() >= 4)
                        stagger = std::stof(args[3]);
                }
                catch (...)
                {
                }

                const char *effectName = "bounce";
                const std::string velKey = effectName + std::string("_vel");
                const std::string timeKey = effectName + std::string("_start");

                // Initialize position, velocity, and start time
                if (character.offsets.find(effectName) == character.offsets.end())
                {
                    character.offsets[effectName] = Vector2{0, height};
                    character.customData[velKey] = height / duration;
                    character.customData[timeKey] = GetTime();
                }

                float startTime = character.customData[timeKey] + stagger * character.index;
                if (GetTime() < startTime)
                    return; // Stagger delay not reached

                float &y = character.offsets[effectName].y;
                float &vel = character.customData[velKey];

                vel += gravity * dt;
                y += vel * dt;

                if (y > 0.0f)
                {
                    y = 0.0f;
                    vel = -vel * 0.5f; // Dampened bounce
                    if (std::abs(vel) < 10.0f)
                        vel = 0.0f; // Settle on ground
                }

                // this is an effect that has a clear start and finish, so mark it.

                if (vel == 0.0f)
                {
                    character.effectFinished[effectName] = true;
                }
            };

            text.effectFunctions["scramble"] = [](float dt, Character &character, const std::vector<std::string> &args)
            {
                float duration = 0.4f;     // How long scrambling lasts
                float stagger = 0.1f;      // Delay per character index
                float scrambleRate = 15.f; // Changes per second

                try
                {
                    if (!args.empty())
                        duration = std::stof(args[0]);
                    if (args.size() >= 2)
                        stagger = std::stof(args[1]);
                    if (args.size() >= 3)
                        scrambleRate = std::stof(args[2]);
                }
                catch (...)
                {
                }

                float now = GetTime();
                float elapsed = now - character.createdTime - character.index * stagger;

                if (elapsed < duration)
                {
                    const char *effectName = "scramble_last";
                    float &lastChange = character.customData[effectName];

                    if (now - lastChange >= 1.0f / scrambleRate || character.overrideCodepoint == std::nullopt)
                    {
                        lastChange = now;
                        int code = 33 + (rand() % 94); // Printable ASCII
                        character.overrideCodepoint = code;
                    }
                }
                else
                {
                    character.overrideCodepoint.reset(); // Show final character
                }

                // this is an effect that has a clear start and finish, so mark it.
                if (elapsed >= duration)
                {
                    character.effectFinished["scramble"] = true;
                }
            };
        }

        Character createCharacter(Text text, int codepoint, const Vector2 &startPosition, const Font &font, float fontSize,
                                  float &currentX, float &currentY, float wrapWidth, Text::Alignment alignment,
                                  float &currentLineWidth, std::vector<float> &lineWidths, int index, int &lineNumber)
        {
            int utf8Size = 0;
            const char *utf8Char = CodepointToUTF8(codepoint, &utf8Size);
            std::string characterString(utf8Char, utf8Size); // Create a string with the exact size
            Vector2 charSize = MeasureTextEx(font, characterString.c_str(), fontSize, 1.0f);

            // Check for line wrapping, do this only if character wrapping is enabled
            if (text.wrapMode == Text::WrapMode::CHARACTER && wrapWidth > 0 && (currentX - startPosition.x) + charSize.x > wrapWidth)
            {
                lineWidths.push_back(currentLineWidth); // Save the width of the completed line
                currentX = startPosition.x;             // Reset to the start of the line
                currentY += charSize.y;                 // Move to the next line
                currentLineWidth = 0.0f;                // Reset current line width
                lineNumber++;                           // Increment line number
            }

            spdlog::debug("Creating character: '{}' (codepoint: {}), x={}, y={}, line={}", characterString, codepoint, currentX, currentY, lineNumber);

            // Character character{
            //     codepoint, Vector2{currentX, currentY}, 0.0f, 1.0f, WHITE, Vector2{0, 0}, {}, {}, index, lineNumber};
            Character character{};
            character.value = codepoint;
            character.position = Vector2{currentX, currentY};
            character.index = index;
            character.lineNumber = lineNumber;
            character.color = WHITE;
            character.scale = 1.0f;
            character.rotation = 0.0f;
            character.createdTime = text.createdTime;

            if (text.pop_in_enabled)
            {
                character.pop_in = 0.0f;
                character.pop_in_delay = index * 0.1f; // Staggered pop-in effect
            }

            currentX += text.spacing + charSize.x;         // Advance X position (include spacing)
            currentLineWidth += charSize.x + text.spacing; // Update line width
            return character;
        }

        void adjustAlignment(Text &text, const std::vector<float> &lineWidths)
        {
            spdlog::debug("Adjusting alignment for text with alignment mode: {}", magic_enum::enum_name<Text::Alignment>(text.alignment));

            for (size_t line = 0; line < lineWidths.size(); ++line)
            {
                float leftoverWidth = text.wrapWidth - lineWidths[line];
                spdlog::debug("Line {}: leftoverWidth = {}, wrapWidth = {}, lineWidth = {}", line, leftoverWidth, text.wrapWidth, lineWidths[line]);

                if (leftoverWidth <= 0.0f)
                {
                    spdlog::debug("Line {} fits perfectly, skipping alignment.", line);
                    continue; // Skip alignment for lines that perfectly fit
                }

                if (text.alignment == Text::Alignment::CENTER)
                { // Center alignment
                    spdlog::debug("Applying center alignment for line {}", line);
                    for (auto &character : text.characters)
                    {
                        if (character.lineNumber == line)
                        {
                            spdlog::debug("Before: Character '{}' at x={}", character.value, character.position.x);
                            character.position.x += leftoverWidth / 2.0f;
                            spdlog::debug("After: Character '{}' at x={}", character.value, character.position.x);
                        }
                    }
                }
                else if (text.alignment == Text::Alignment::RIGHT)
                { // Right alignment
                    spdlog::debug("Applying right alignment for line {}", line);
                    for (auto &character : text.characters)
                    {
                        if (character.lineNumber == line)
                        {
                            spdlog::debug("Before: Character '{}' at x={}", character.value, character.position.x);
                            character.position.x += leftoverWidth;
                            spdlog::debug("After: Character '{}' at x={}", character.value, character.position.x);
                        }
                    }
                }
                else if (text.alignment == Text::Alignment::JUSTIFIED)
                { // Justified alignment
                    spdlog::debug("Applying justified alignment for line {}", line);

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

                    spdlog::debug("Line {}: spacesCount = {}", line, spacesCount);

                    if (spacesCount > 0)
                    {
                        float addedSpacePerSpace = leftoverWidth / spacesCount;
                        spdlog::debug("Line {}: addedSpacePerSpace = {}", line, addedSpacePerSpace);

                        float cumulativeShift = 0.0f;

                        for (auto &character : text.characters)
                        {
                            if (character.lineNumber == line)
                            {
                                if (character.value == ' ')
                                {
                                    spdlog::debug("Space character at x={} gets additional space: {}", character.position.x, addedSpacePerSpace);
                                    cumulativeShift += addedSpacePerSpace;
                                }

                                spdlog::debug("Before: Character '{}' at x={}", character.value, character.position.x);
                                character.position.x += cumulativeShift;
                                spdlog::debug("After: Character '{}' at x={}", character.value, character.position.x);
                            }
                        }

                        // Debug: Print all space positions for this line
                        for (size_t index : spaceIndices)
                        {
                            const auto &spaceCharacter = text.characters[index];
                            spdlog::debug("Space character position: x={}, y={}, index={}", spaceCharacter.position.x, spaceCharacter.position.y, index);
                        }
                    }
                    else
                    {
                        spdlog::warn("Line {} has no spaces, skipping justified alignment.", line);
                    }
                }
            }
        }

        ParsedEffectArguments splitEffects(const std::string &effects)
        {
            spdlog::debug("Splitting effects: {}", effects);
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

        void parseText(Text &text)
        {
            spdlog::debug("Parsing text: {}", text.rawText);

            const char *rawText = text.rawText.c_str();

            std::regex pattern(R"(\[(.*?)\]\((.*?)\))");
            std::smatch match;
            std::string regexText = text.rawText;

            const char *currentPos = regexText.c_str(); // Pointer to current position in the string

            float currentX = text.position.x;
            float currentY = text.position.y;

            std::vector<float> lineWidths; // To store widths of all lines
            float currentLineWidth = 0.0f;

            int codepointIndex = 0; // Index in the original text
            int lineNumber = 0;     // Line number for characters

            // Regex matching on raw UTF-8 text
            while (std::regex_search(regexText, match, pattern))
            {
                spdlog::debug("Match found: {} with effects: {}", match[1].str(), match[2].str());

                spdlog::debug("Match position: {}, length: {}", match.position(0), match.length(0));
                spdlog::debug("Processing plain text before the match");
                spdlog::debug("Plain text string: {}", std::string(currentPos, match.position(0)));

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
                        currentX = text.position.x;             // Reset X position
                        currentY += MeasureTextEx(text.font, "A", text.fontSize, 1.0f).y;
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
                            Vector2 charSize = MeasureTextEx(text.font, lookaheadChar.c_str(), text.fontSize, 1.0f);
                            nextWordWidth += charSize.x;

                            // Advance the lookahead pointer
                            lookaheadPos += lookaheadCodepointSize;
                        }

                        // Check if the next word will exceed the wrap width
                        if ((currentX - text.position.x) + nextWordWidth > text.wrapWidth)
                        {
                            spdlog::debug("Wrap would have exceeded width: currentX={}, wrapWidth={}, nextWordWidth={}, exceeds={}", currentX, text.wrapWidth, nextWordWidth, (currentX - text.position.x) + nextWordWidth);

                            // If the next word exceeds the wrap width, move to the next line
                            lineWidths.push_back(currentLineWidth);                           // Save current line width
                            currentX = text.position.x;                                       // Reset X position
                            currentY += MeasureTextEx(text.font, "A", text.fontSize, 1.0f).y; // Move to the next line
                            currentLineWidth = 0.0f;
                            lineNumber++;

                            spdlog::debug("Word wrap: Moving to next line before processing space at x={}, y={}, line={}, with word {}",
                                          currentX, currentY, lineNumber, lookaheadCharString);
                        }
                        else
                        {
                            auto character = createCharacter(text, codepoint, text.position, text.font, text.fontSize,
                                                             currentX, currentY, text.wrapWidth, text.alignment,
                                                             currentLineWidth, lineWidths, codepointIndex, lineNumber);
                            text.characters.push_back(character);
                        }
                    }
                    else if (codepoint == ' ' && text.wrapMode == Text::WrapMode::CHARACTER) // Detect spaces
                    {
                        if (currentX == text.position.x)
                        {
                            // Skip the space character at the beginning of the line
                            currentPos += codepointSize; // Advance pointer
                            codepointIndex++;
                            continue;
                        }
                        else
                        {
                            auto character = createCharacter(text, codepoint, text.position, text.font, text.fontSize,
                                                             currentX, currentY, text.wrapWidth, text.alignment,
                                                             currentLineWidth, lineWidths, codepointIndex, lineNumber);
                            text.characters.push_back(character);
                        }
                    }
                    else
                    {
                        auto character = createCharacter(text, codepoint, text.position, text.font, text.fontSize,
                                                         currentX, currentY, text.wrapWidth, text.alignment,
                                                         currentLineWidth, lineWidths, codepointIndex, lineNumber);
                        text.characters.push_back(character);
                    }

                    currentPos += codepointSize; // Advance pointer
                    codepointIndex++;
                }

                // Process matched effect text
                std::string effectText = match[1];
                std::string effects = match[2];
                ParsedEffectArguments parsedArguments = splitEffects(effects);

                spdlog::debug("Processing effect text: {}", effectText);

                const char *effectPos = effectText.c_str();

                handleEffectSegment(effectPos, lineWidths, currentLineWidth, currentX, text, currentY, lineNumber, codepointIndex, parsedArguments);

                // Update regexText to process the suffix
                regexText = match.suffix().str();

                // FIXME: this does not set current position properly on the second matched effect text
                // TODO: get the position of the suffix and set currentPos to that
                //  Advance currentPos past the matched section
                //  currentPos = regexText.c_str() + (match.position(0) + match.length(0));
                currentPos = regexText.c_str();
            }

            spdlog::debug("Processing plain text after the last match: {}", currentPos);
            while (*currentPos)
            {
                // get string at match position
                std::string plainText(currentPos, match.position(0) - (currentPos - regexText.c_str()));

                int codepointSize = 0;
                int codepoint = GetCodepointNext(currentPos, &codepointSize);

                if (codepoint == '\n') // Handle line breaks
                {
                    lineWidths.push_back(currentLineWidth); // Save current line width
                    currentX = text.position.x;             // Reset X position
                    currentY += MeasureTextEx(text.font, "A", text.fontSize, 1.0f).y;
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
                        Vector2 charSize = MeasureTextEx(text.font, lookaheadChar.c_str(), text.fontSize, 1.0f);
                        nextWordWidth += charSize.x;

                        // Advance the lookahead pointer
                        lookaheadPos += lookaheadCodepointSize;
                    }

                    // Check if the next word will exceed the wrap width
                    if ((currentX - text.position.x) + nextWordWidth > text.wrapWidth)
                    {
                        // If the next word exceeds the wrap width, move to the next line
                        lineWidths.push_back(currentLineWidth);                           // Save current line width
                        currentX = text.position.x;                                       // Reset X position
                        currentY += MeasureTextEx(text.font, "A", text.fontSize, 1.0f).y; // Move to the next line
                        currentLineWidth = 0.0f;
                        lineNumber++;

                        spdlog::debug("Word wrap: Moving to next line before processing space at x={}, y={}, line={}, with word {}",
                                      currentX, currentY, lineNumber, lookaheadCharString);
                    }
                    else
                    {
                        // FIXME: Ignore the space character if line changed
                        auto character = createCharacter(text, codepoint, text.position, text.font, text.fontSize,
                                                         currentX, currentY, text.wrapWidth, text.alignment,
                                                         currentLineWidth, lineWidths, codepointIndex, lineNumber);
                        text.characters.push_back(character);
                    }
                }
                else if (codepoint == ' ' && text.wrapMode == Text::WrapMode::CHARACTER) // Detect spaces
                {
                    // does adding the char take us over the wrap width?
                    if ((currentX - text.position.x) + MeasureTextEx(text.font, " ", text.fontSize, 1.0f).x > text.wrapWidth)
                    {
                        // if so skip this space character

                        // Skip the space character at the beginning of the line
                        currentPos += codepointSize; // Advance pointer
                        codepointIndex++;
                        continue;
                    }
                    else
                    {
                        auto character = createCharacter(text, codepoint, text.position, text.font, text.fontSize,
                                                         currentX, currentY, text.wrapWidth, text.alignment,
                                                         currentLineWidth, lineWidths, codepointIndex, lineNumber);
                        text.characters.push_back(character);
                    }
                }
                else
                {
                    auto character = createCharacter(text, codepoint, text.position, text.font, text.fontSize,
                                                     currentX, currentY, text.wrapWidth, text.alignment,
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
            adjustAlignment(text, lineWidths);

            // print all characters out for debugging
            for (const auto &character : text.characters)
            {
                int utf8Size = 0;
                spdlog::debug("Character: '{}', x={}, y={}, line={}", CodepointToUTF8(character.value, &utf8Size), character.position.x, character.position.y, character.lineNumber);
            }

            auto ptr = std::make_shared<Text>(text);
            
            for (auto &character : text.characters)
            {
                character.parentText = ptr;
            }

            // get last character
            if (!text.characters.empty())
            {
                text.characters.back().isFinalCharacterInText = true;
            }
        }

        void handleEffectSegment(const char *&effectPos, std::vector<float> &lineWidths, float &currentLineWidth, float &currentX, TextSystem::Text &text, float &currentY, int &lineNumber, int &codepointIndex, TextSystem::ParsedEffectArguments &parsedArguments)
        {
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
                        nextWordWidth += text.spacing + MeasureTextEx(text.font, utf8Char.c_str(), text.fontSize, 1.0f).x;
                        lookaheadPos += lookaheadSize;
                    }

                    //TODO: spacing seems off?

                    // just reposition in next line without skippin codepoint
                    if ((currentX - text.position.x) + nextWordWidth > text.wrapWidth)
                    {
                        lineWidths.push_back(currentLineWidth);
                        currentX = text.position.x;
                        currentY += MeasureTextEx(text.font, "A", text.fontSize, 1.0f).y;
                        currentLineWidth = 0.0f;
                        lineNumber++;
                    }
                }

                if (codepoint == '\n') // Explicit line break in effect text
                {
                    lineWidths.push_back(currentLineWidth);
                    currentX = text.position.x;
                    currentY += MeasureTextEx(text.font, "A", text.fontSize, 1.0f).y;
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
                            nextWordWidth += text.spacing + MeasureTextEx(text.font, utf8Char.c_str(), text.fontSize, 1.0f).x;
                            lookaheadPos += lookaheadSize;
                        }

                        //TODO: spacing seems off?

                        if ((currentX - text.position.x) + nextWordWidth > text.wrapWidth)
                        {
                            lineWidths.push_back(currentLineWidth);
                            currentX = text.position.x;
                            currentY += MeasureTextEx(text.font, "A", text.fontSize, 1.0f).y;
                            currentLineWidth = 0.0f;
                            lineNumber++;
                            effectPos += codepointSize;
                            codepointIndex++;
                            continue;
                        }
                    }
                    else if (text.wrapMode == Text::WrapMode::CHARACTER)
                    {
                        float spaceWidth = MeasureTextEx(text.font, " ", text.fontSize, 1.0f).x;
                        if ((currentX - text.position.x) + spaceWidth > text.wrapWidth)
                        {
                            // Skip space at start of line
                            effectPos += codepointSize;
                            codepointIndex++;
                            continue;
                        }
                    }
                }

                // Create and store character
                Character character = createCharacter(text, codepoint, text.position, text.font, text.fontSize,
                                                      currentX, currentY, text.wrapWidth, text.alignment,
                                                      currentLineWidth, lineWidths, codepointIndex, lineNumber);

                character.parsedEffectArguments = parsedArguments;

                for (const auto &[effectName, args] : parsedArguments.arguments)
                {
                    if (text.effectFunctions.count(effectName))
                    {
                        character.effects[effectName] = text.effectFunctions[effectName];
                    }
                }

                text.characters.push_back(character);
                effectPos += codepointSize;
                codepointIndex++;

                firstCharacter = false;
            }
        }

        void updateText(Text &text, float dt)
        {

            // spdlog::debug("Updating text with delta time: {}", dt);
            for (auto &character : text.characters)
            {
                // Apply Pop-in Animation
                //TODO: deprecated, use pop effect instead
                if (character.pop_in && character.pop_in < 1.0f)
                {
                    float elapsedTime = GetTime() - text.createdTime - character.pop_in_delay.value_or(0.05f);
                    if (elapsedTime > 0)
                    {
                        character.pop_in = std::min(1.0f, elapsedTime / 0.5f);                  // 0.5s duration
                        character.pop_in = character.pop_in.value() * character.pop_in.value(); // Ease-in effect
                    }
                }

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

        void renderText(const Text &text, bool debug)
        {
            for (const auto &character : text.characters)
            {

                float popInScale = 1.0f;
                if (character.pop_in)
                {
                    popInScale = character.pop_in.value();
                }

                // Calculate character position with offset
                Vector2 charPosition = {
                    character.position.x + character.offset.x,
                    character.position.y + character.offset.y};

                // add all optional offsets
                for (const auto &[effectName, offset] : character.offsets)
                {
                    charPosition.x += offset.x;
                    charPosition.y += offset.y;
                }

                // Convert the codepoint to UTF-8 string for rendering
                int utf8Size = 0;
                const char *utf8Char = CodepointToUTF8(character.overrideCodepoint.value_or(character.value), &utf8Size);
                auto utf8String = CodepointToString(character.overrideCodepoint.value_or(character.value));

                Vector2 charSize = MeasureTextEx(text.font, utf8String.c_str(), text.fontSize, 1.0f);
                // sanity check
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

                rlPushMatrix();

                // apply scaling that is centered on the character

                rlTranslatef(charPosition.x + charSize.x * 0.5f, charPosition.y + charSize.y * 0.5f, 0);
                rlScalef(finalScaleX, finalScaleY, 1);
                rlRotatef(character.rotation, 0, 0, 1);
                rlTranslatef(-charSize.x * 0.5f, -charSize.y * 0.5f, 0);

                // Render the character
                DrawTextPro(text.font, utf8String.c_str(), Vector2{0, 0}, Vector2{0, 0}, 0.f, text.fontSize, text.spacing, character.color);

                rlPopMatrix();
            }

            // Draw debug bounding box
            if (debug)
            {
                // Calculate the bounding box dimensions
                float minX = std::numeric_limits<float>::max();
                float minY = std::numeric_limits<float>::max();
                float maxX = std::numeric_limits<float>::lowest();
                float maxY = std::numeric_limits<float>::lowest();

                minX = text.position.x;
                minY = text.position.y;
                maxX = text.position.x + text.wrapWidth;
                // get line height of last character
                float lineHeight = MeasureTextEx(text.font, "A", text.fontSize, 1.0f).y;
                maxY = text.position.y + (text.characters.back().lineNumber + 1) * (lineHeight);

                float width = maxX - minX;
                float height = maxY - minY;

                // Draw the bounding box
                DrawRectangleLines(minX, minY, width, height, RED);

                // Draw text showing the dimensions
                std::string dimensionsText = "Width: " + std::to_string(width) + ", Height: " + std::to_string(height);
                DrawText(dimensionsText.c_str(), minX, minY - 20, 10, RED); // Position the text above the box
            }
        }

        void clearAllEffects(Text &text)
        {
            for (auto &character : text.characters)
            {
                character.effects.clear();
                character.parsedEffectArguments.arguments.clear();
                character.scaleModifiers.clear();
                character.offsets.clear();
                character.scaleXModifier.reset();
                character.scaleYModifier.reset();
                character.overrideCodepoint.reset();
            }
        }

        void applyGlobalEffects(Text &text, const std::string &effectString)
        {
            ParsedEffectArguments parsedArguments = splitEffects(effectString);

            for (auto &character : text.characters)
            {
                character.parsedEffectArguments.arguments.insert(parsedArguments.arguments.begin(), parsedArguments.arguments.end());

                for (const auto &[effectName, args] : parsedArguments.arguments)
                {
                    if (text.effectFunctions.count(effectName))
                    {
                        character.effects[effectName] = text.effectFunctions[effectName];
                    }
                    else
                    {
                        spdlog::warn("Effect '{}' not registered. Skipping.", effectName);
                    }
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
