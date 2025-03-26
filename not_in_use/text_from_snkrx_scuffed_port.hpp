#ifndef TEXT_SYSTEM_H
#define TEXT_SYSTEM_H

#include <functional>
#include <string>
#include <vector>
#include <unordered_map>
#include "raylib.h"

// Character struct
struct Character {
    char character;
    Vector2 position = {0, 0};   // Base position
    Vector2 offset = {0, 0};     // Shake or other effects
    Vector2 scale = {1, 1};      // Scale
    float rotation = 0.0f;       // Rotation
    Color color = WHITE;         // Color
    std::vector<std::string> tags; // List of tags for this character
};

// Line struct
struct Line {
    std::vector<Character> characters;
    Font font;
    std::string alignment = "left"; // "left", "center", "right", or "justified"
    float heightOffset = 0.0f;      // Offset for this line
    float heightMultiplier = 1.0f; // Multiplier for line height
};

// TextTag struct
struct TextTag {
    std::function<void(Character&, int)> init;           // Initialization function
    std::function<void(Character&, float, int)> update;  // Update function (dt)
    std::function<void(const Character&, int)> draw;     // Custom draw function
};

// Text class
class Text {
private:
    std::vector<Line> lines;                            // List of lines
    std::unordered_map<std::string, TextTag> textTags;  // Tags and their actions
    float width = 0.0f;                                 // Width of the text block
    float height = 0.0f;                                // Height of the text block

    void formatText(); // Helper to calculate text layout.

public:
    Text(const std::vector<Line>& textLines, const std::unordered_map<std::string, TextTag>& tags);

    void update(float dt);                 // Update the text
    void draw(Vector2 position);           // Draw the text
};

#endif // TEXT_SYSTEM_H
