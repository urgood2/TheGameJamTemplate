// src/core/ownership.hpp
#pragma once

#include <string_view>
#include <string>

// Forward declaration for sol::state
namespace sol { class state; }

namespace ownership {

// Compile-time constants - cannot be modified at runtime
inline constexpr std::string_view DISCORD_LINK = "https://discord.com/invite/rp6yXxKu5z";
inline constexpr std::string_view ITCH_LINK = "https://chugget.itch.io/";

// Build ID generated at compile time (CMake injects these via -D flags)
// Defaults provided for builds without CMake injection
#ifndef BUILD_ID_VALUE
#define BUILD_ID_VALUE "dev-local"
#endif
#ifndef BUILD_SIGNATURE_VALUE
#define BUILD_SIGNATURE_VALUE "unsigned"
#endif

inline const char* BUILD_ID = BUILD_ID_VALUE;
inline const char* BUILD_SIGNATURE = BUILD_SIGNATURE_VALUE;

// Tamper detection state
struct TamperState {
    bool detected = false;
    std::string luaDiscordValue;
    std::string luaItchValue;
};

// Validate displayed links against compile-time constants
// Called from Lua after rendering ownership info
void validate(const std::string& displayedDiscord, const std::string& displayedItch);

// Check if tampering was detected
bool isTamperDetected();

// Get current tamper state (for rendering warning)
const TamperState& getTamperState();

// Reset tamper state (for testing)
void resetTamperState();

// Register Lua bindings for ownership validation
void registerLuaBindings(sol::state& lua);

}  // namespace ownership
