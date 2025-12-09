#include "ownership.hpp"
#include "sol/sol.hpp"

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

}  // namespace ownership
