#include "ownership.hpp"
#include "sol/sol.hpp"
#include "raylib.h"

namespace ownership {

namespace {
    TamperState g_tamperState;
}

void validate(const std::string& displayedDiscord, const std::string& displayedItch) {
    g_tamperState.luaDiscordValue = displayedDiscord;
    g_tamperState.luaItchValue = displayedItch;

    // Check if displayed values match compile-time constants
    bool discordMatches = (displayedDiscord == DISCORD_LINK);
    bool itchMatches = (displayedItch == ITCH_LINK);

    g_tamperState.detected = !(discordMatches && itchMatches);
}

bool isTamperDetected() {
    return g_tamperState.detected;
}

const TamperState& getTamperState() {
    return g_tamperState;
}

void resetTamperState() {
    g_tamperState = TamperState{};
}

void registerLuaBindings(sol::state& lua) {
    // Create ownership table
    sol::table ownership_table = lua.create_table();

    // Add read-only getters for compile-time constants
    ownership_table.set_function("getDiscordLink", []() -> std::string {
        return std::string(DISCORD_LINK);
    });

    ownership_table.set_function("getItchLink", []() -> std::string {
        return std::string(ITCH_LINK);
    });

    ownership_table.set_function("getBuildId", []() -> std::string {
        return std::string(BUILD_ID);
    });

    // Add validate function that calls the existing validate()
    ownership_table.set_function("validate", [](const std::string& displayedDiscord, const std::string& displayedItch) {
        validate(displayedDiscord, displayedItch);
    });

    // Register the table in the global namespace
    lua["ownership"] = ownership_table;
}

void renderTamperWarningIfNeeded(int screenWidth, int screenHeight) {
    if (!g_tamperState.detected) {
        return;
    }

    // Warning box dimensions
    const int boxWidth = 500;
    const int boxHeight = 280;
    const int boxX = (screenWidth - boxWidth) / 2;
    const int boxY = (screenHeight - boxHeight) / 2;
    const int padding = 20;
    const int fontSize = 18;
    const int titleFontSize = 24;

    // Semi-transparent dark overlay
    DrawRectangle(0, 0, screenWidth, screenHeight, Fade(BLACK, 0.7f));

    // Warning box background
    DrawRectangle(boxX, boxY, boxWidth, boxHeight, Fade(DARKGRAY, 0.95f));
    DrawRectangleLines(boxX, boxY, boxWidth, boxHeight, RED);
    DrawRectangleLines(boxX + 1, boxY + 1, boxWidth - 2, boxHeight - 2, RED);

    // Warning title
    const char* title = "WARNING: POTENTIALLY STOLEN BUILD";
    int titleWidth = MeasureText(title, titleFontSize);
    DrawText(title, boxX + (boxWidth - titleWidth) / 2, boxY + padding, titleFontSize, RED);

    // Warning message
    int textY = boxY + padding + titleFontSize + 20;
    DrawText("This copy may have been modified and", boxX + padding, textY, fontSize, WHITE);
    textY += fontSize + 5;
    DrawText("redistributed without permission.", boxX + padding, textY, fontSize, WHITE);

    textY += fontSize + 20;
    DrawText("Official sources:", boxX + padding, textY, fontSize, YELLOW);

    textY += fontSize + 10;
    DrawText(TextFormat("Discord: %s", std::string(DISCORD_LINK).c_str()),
             boxX + padding, textY, fontSize, SKYBLUE);

    textY += fontSize + 5;
    DrawText(TextFormat("Itch.io: %s", std::string(ITCH_LINK).c_str()),
             boxX + padding, textY, fontSize, SKYBLUE);

    textY += fontSize + 20;
    DrawText(TextFormat("Build ID: %s", BUILD_ID), boxX + padding, textY, fontSize - 2, GRAY);
}

}  // namespace ownership
