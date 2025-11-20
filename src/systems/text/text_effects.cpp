#include "text_effects.hpp"
#include "util/utilities.hpp"
#include "systems/main_loop_enhancement/main_loop.hpp"

namespace TextSystem {

    // Exponential easing
    auto easeInExpo = [](float x)
    {
        return (x <= 0.0f) ? 0.0f : std::pow(2.0f, 10.0f * (x - 1.0f));
    };

    auto easeOutExpo = [](float x)
    {
        return (x >= 1.0f) ? 1.0f : 1.0f - std::pow(2.0f, -10.0f * x);
    };

    
    void initEffects()
    {
        spdlog::debug("Initializing effects for text.");
        effectFunctions["color"] = [](float dt, Character &character, const std::vector<std::string> &args)
        {
            if (!args.empty())
            {
                std::string colorName = args[0];
                // spdlog::debug("Applying color effect: {}", colorName);
                try
                {
                    auto color= util::getColor(colorName);
                    character.color = color;
                }
                catch(const std::exception& e)
                {
                    std::cerr << e.what() << '\n';
                }
                
            }
        };

        effectFunctions["shake"] = [](float dt, Character &character, const std::vector<std::string> &args)
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
                    character.offsets[effectName].x = sin(main_loop::getTime() * 10.0f + character.index * 5) * shakeX;
                    character.offsets[effectName].y = cos(main_loop::getTime() * 10.0f + character.index * 5) * shakeY;
                    // spdlog::debug("Applying shake effect with arguments: x={}, y={}", shakeX, shakeY);
                }
                catch (const std::exception &)
                {
                    spdlog::error("Invalid argument type for shake effect");
                }
            }
        };

        // Four arguments: min scale, max scale, pulse speed, stagger offset (optional)
        effectFunctions["pulse"] = [](float dt, Character &character, const std::vector<std::string> &args)
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

            float time = main_loop::getTime() * pulseSpeed + character.index * stagger;
            float wave = (std::sin(time) + 1.0f) * 0.5f; // Normalize to 0–1
            character.scale = minScale + (maxScale - minScale) * wave;
        };

        effectFunctions["rotate"] = [](float dt, Character &character, const std::vector<std::string> &args)
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

            character.rotation = std::sin(main_loop::getTime() * speed + character.index * 10.0f) * angle;
        };

        effectFunctions["float"] = [](float dt, Character &character, const std::vector<std::string> &args)
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

            character.offsets[effectName].y = std::sin(main_loop::getTime() * speed + character.index * phaseOffsetPerChar) * amplitude;
        };

        effectFunctions["bump"] = [](float dt, Character &character, const std::vector<std::string> &args)
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
            if (character.shadowDisplacementOffsets.find(effectName) == character.offsets.end())
            {
                character.shadowDisplacementOffsets[effectName] = Vector2{0, 0};
            }

            // Time-based sine wave with optional character phase offset
            float time = - main_loop::getTime() * speed + character.index * stagger;
            float wave = (std::sin(time) + 1.0f) * 0.5f; // Normalize sine to 0–1

            // Apply bump only when wave exceeds threshold (creates a snap/jump instead of a floaty sine)
            float bump = (wave > threshold) ? amplitude : 0.0f;

            character.offsets[effectName].y = -bump; // bump up
            character.shadowDisplacementOffsets[effectName].y = bump;
        };

        // this is the same as rotation, but has different defaults
        effectFunctions["wiggle"] = [](float dt, Character &character, const std::vector<std::string> &args)
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

            character.rotation = std::sin(main_loop::getTime() * speed + character.index * stagger) * angle;
        };

        // TODO: Make the rest of the effects, including pop-in. pop-out, etc.

        // FIXME: only works for entire text only, partial text will lag too much
        effectFunctions["slide"] = [](float dt, Character &character, const std::vector<std::string> &args)
        {
            if (character.firstFrame)
            {
                character.firstFrame = false;
                character.createdTime = main_loop::getTime();
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

            float timeAlive = static_cast<float>(main_loop::getTime()) - character.createdTime;

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

        effectFunctions["pop"] = [](float dt, Character &character, const std::vector<std::string> &args)
        {
            if (character.firstFrame)
            {
                character.firstFrame = false;
                character.createdTime = main_loop::getTime();
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

            float timeAlive = static_cast<float>(main_loop::getTime()) - character.createdTime;

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

        effectFunctions["spin"] = [](float dt, Character &character, const std::vector<std::string> &args)
        {
            if (character.firstFrame)
            {
                character.firstFrame = false;
                character.createdTime = main_loop::getTime();
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

            float currentTime = main_loop::getTime();
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

        effectFunctions["fan"] = [](float /*dt*/, Character &character, const std::vector<std::string> &args)
        {
            // args[0] = maxAngle in degrees (optional, defaults to 30)
            float maxAngle = 10.0f;
            try {
                if (!args.empty())
                    maxAngle = std::stof(args[0]);
            } catch (...) { /* ignore bad input */ }

            // If there's only one character, no fan
            
            if (character.parentText->characters.size() <= 1)
            {
                character.rotation = 0.0f;
                return;
            }

            // Compute a normalized [-1..+1] index around center
            float mid         = (character.parentText->characters.size() - 1) * 0.5f;
            float offsetIndex = static_cast<float>(character.index) - mid;
            float normalized  = offsetIndex / mid;  // = -1 at first char, +1 at last

            // Apply constant rotation
            character.rotation = normalized * maxAngle;
        };

        effectFunctions["fade"] = [](float dt, Character &character, const std::vector<std::string> &args)
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

            float t = main_loop::getTime() * speed - character.index * stagger; // subtract to move left to right
            float normalized = (std::sin(t * frequency) + 1.0f) * 0.5f;
            float alpha = minAlpha + (maxAlpha - minAlpha) * normalized;
            character.color.a = static_cast<unsigned char>(alpha * 255.0f);
        };

        effectFunctions["highlight"] = [](float dt, Character &character, const std::vector<std::string> &args)
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
            float t = main_loop::getTime() * speed + indexOffset;

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

        effectFunctions["rainbow"] = [](float dt, Character &character, const std::vector<std::string> &args)
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

            float hue = fmodf((main_loop::getTime() * speed - character.index * stagger), 360.0f);

            // Apply hue thresholding if set
            if (thresholdStep > 0.0f)
            {
                hue = std::floor(hue / thresholdStep) * thresholdStep;
            }

            character.color = ColorFromHSV(hue, 1.0f, 1.0f);
        };

        effectFunctions["expand"] = [](float dt, Character &character, const std::vector<std::string> &args)
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

            float t = main_loop::getTime() * speed + character.index * stagger;
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

        effectFunctions["bounce"] = [](float dt, Character &character, const std::vector<std::string> &args)
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
                character.customData[timeKey] = main_loop::getTime();
            }

            float startTime = character.customData[timeKey] + stagger * character.index;
            if (main_loop::getTime() < startTime)
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

        effectFunctions["scramble"] = [](float dt, Character &character, const std::vector<std::string> &args)
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

            float now = main_loop::getTime();
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
}