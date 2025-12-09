#include "ownership.hpp"

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

}  // namespace ownership
