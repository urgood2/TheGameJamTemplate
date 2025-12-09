#include "ownership.hpp"
#include "sol/sol.hpp"
#include "raylib.h"
#include <atomic>
#include <mutex>

namespace ownership {

namespace {
    // Thread-safe tamper state
    // The detected flag uses atomic for lock-free reads in the render loop
    // The mutex protects the string members during validation
    std::atomic<bool> g_tamperDetected{false};
    std::mutex g_tamperStateMutex;
    TamperState g_tamperState;
}

void validate(const std::string& displayedDiscord, const std::string& displayedItch) {
    std::lock_guard<std::mutex> lock(g_tamperStateMutex);

    g_tamperState.luaDiscordValue = displayedDiscord;
    g_tamperState.luaItchValue = displayedItch;

    // Check if displayed values match compile-time constants
    bool discordMatches = (displayedDiscord == DISCORD_LINK);
    bool itchMatches = (displayedItch == ITCH_LINK);

    bool detected = !(discordMatches && itchMatches);
    g_tamperState.detected = detected;
    g_tamperDetected.store(detected, std::memory_order_release);
}

bool isTamperDetected() {
    return g_tamperDetected.load(std::memory_order_acquire);
}

const TamperState& getTamperState() {
    std::lock_guard<std::mutex> lock(g_tamperStateMutex);
    return g_tamperState;
}

void resetTamperState() {
    std::lock_guard<std::mutex> lock(g_tamperStateMutex);
    g_tamperState = TamperState{};
    g_tamperDetected.store(false, std::memory_order_release);
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

    ownership_table.set_function("getBuildSignature", []() -> std::string {
        return std::string(BUILD_SIGNATURE);
    });

    // Add validate function that calls the existing validate()
    ownership_table.set_function("validate", [](const std::string& displayedDiscord, const std::string& displayedItch) {
        validate(displayedDiscord, displayedItch);
    });

    // Create a metatable to make the table read-only
    sol::table metatable = lua.create_table();

    // Prevent modifications by throwing an error on __newindex
    metatable[sol::meta_function::new_index] = [](sol::table, sol::object key, sol::object) {
        std::string key_str = "unknown";
        if (key.is<std::string>()) {
            key_str = key.as<std::string>();
        }
        throw std::runtime_error("ownership table is read-only, cannot modify field: " + key_str);
    };

    // Prevent metatable modification
    metatable[sol::meta_function::metatable] = "protected";

    // Apply the metatable to the ownership table
    ownership_table[sol::metatable_key] = metatable;

    // Register the table in the global namespace
    lua["ownership"] = ownership_table;
}

void renderTamperWarningIfNeeded(int screenWidth, int screenHeight) {
    // Use atomic for lock-free check in render loop
    if (!g_tamperDetected.load(std::memory_order_acquire)) {
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
    // Store strings in variables to avoid dangling pointers in TextFormat
    std::string discordText = std::string("Discord: ") + std::string(DISCORD_LINK);
    DrawText(discordText.c_str(), boxX + padding, textY, fontSize, SKYBLUE);

    textY += fontSize + 5;
    std::string itchText = std::string("Itch.io: ") + std::string(ITCH_LINK);
    DrawText(itchText.c_str(), boxX + padding, textY, fontSize, SKYBLUE);

    textY += fontSize + 20;
    DrawText(TextFormat("Build ID: %s", BUILD_ID), boxX + padding, textY, fontSize - 2, GRAY);
}

}  // namespace ownership
