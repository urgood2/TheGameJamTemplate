#include "text_system.hpp"

// Constructor
Text::Text(const std::vector<Line>& textLines, const std::unordered_map<std::string, TextTag>& tags)
    : lines(textLines), textTags(tags) {
    formatText();
}

// Helper: Format Text
void Text::formatText() {
    width = 0;
    height = 0;

    for (auto& line : lines) {
        float lineWidth = 0;
        for (auto& character : line.characters) {
            lineWidth += MeasureTextEx(line.font, std::string(1, character.character).c_str(),
                                       line.heightMultiplier * line.font.baseSize, 1).x;
        }

        float xOffset = 0;
        if (line.alignment == "center") {
            xOffset = (width - lineWidth) / 2.0f;
        } else if (line.alignment == "right") {
            xOffset = width - lineWidth;
        }

        float x = xOffset, y = height;
        for (auto& character : line.characters) {
            character.position = {x, y};
            x += MeasureTextEx(line.font, std::string(1, character.character).c_str(),
                               line.heightMultiplier * line.font.baseSize, 1).x;
        }

        height += line.font.baseSize * line.heightMultiplier + line.heightOffset;
        if (lineWidth > width) width = lineWidth;
    }
}

// Update
void Text::update(float dt) {
    for (size_t lineIdx = 0; lineIdx < lines.size(); ++lineIdx) {
        auto& line = lines[lineIdx];
        for (size_t charIdx = 0; charIdx < line.characters.size(); ++charIdx) {
            auto& character = line.characters[charIdx];
            for (const auto& tag : character.tags) {
                if (textTags.count(tag) && textTags[tag].update) {
                    textTags[tag].update(character, dt, charIdx);
                }
            }
        }
    }
}

// Draw
void Text::draw(Vector2 position) {
    for (const auto& line : lines) {
        for (const auto& character : line.characters) {
            // Apply tag-specific draw logic.
            for (const auto& tag : character.tags) {
                if (textTags.count(tag) && textTags[tag].draw) {
                    textTags[tag].draw(character, &character - &line.characters[0]);
                }
            }

            // Calculate final position with offset and rotation.
            Vector2 finalPosition = Vector2Add(position, Vector2Add(character.position, character.offset));
            DrawTextPro(line.font,
                        std::string(1, character.character).c_str(),
                        finalPosition,
                        {0, 0}, // Origin
                        character.rotation,
                        line.font.baseSize * character.scale.x,
                        1,
                        character.color);
        }
    }
}

// example usage

// #include "text_system.h"
// #include "raylib.h"

// // Main
// int main() {
//     InitWindow(800, 600, "Text System");

//     Font font = LoadFont("resources/arial.ttf");

//     // Define Tags
//     TextTag yellowTextTag = {
//         .init = [](Character& c, int idx) {
//             c.color = YELLOW;
//         },
//         .update = nullptr,
//         .draw = nullptr
//     };

//     TextTag shakingTextTag = {
//         .init = [](Character& c, int idx) {
//             c.offset = {0, 0};
//         },
//         .update = [](Character& c, float dt, int idx) {
//             c.offset.x = rand() % 8 - 4;
//             c.offset.y = rand() % 8 - 4;
//         },
//         .draw = nullptr
//     };

//     // Text Data
//     Line line1 = {{Character{'H'}, Character{'e'}, Character{'l'}, Character{'l'}, Character{'o'}}, font, "center"};
//     Line line2 = {{Character{'W'}, Character{'o'}, Character{'r'}, Character{'l'}, Character{'d'}}, font, "center"};
//     line1.characters[0].tags = {"yellow"};
//     line2.characters[0].tags = {"shaking"};

//     std::vector<Line> lines = {line1, line2};

//     // Define Text
//     Text text(lines, {{"yellow", yellowTextTag}, {"shaking", shakingTextTag}});

//     // Game loop
//     while (!WindowShouldClose()) {
//         float dt = GetFrameTime();

//         text.update(dt);

//         BeginDrawing();
//         ClearBackground(BLACK);

//         text.draw({400, 300});

//         EndDrawing();
//     }

//     CloseWindow();
//     return 0;
// }

