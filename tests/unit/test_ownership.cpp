// tests/unit/test_ownership.cpp
#include <gtest/gtest.h>
#include "core/ownership.hpp"
#include "sol/sol.hpp"

TEST(Ownership, ConstantsAreDefined) {
    EXPECT_FALSE(ownership::DISCORD_LINK.empty());
    EXPECT_FALSE(ownership::ITCH_LINK.empty());
    EXPECT_TRUE(ownership::DISCORD_LINK.find("discord.com") != std::string_view::npos);
    EXPECT_TRUE(ownership::ITCH_LINK.find("itch.io") != std::string_view::npos);
}

TEST(Ownership, BuildIdIsDefined) {
    EXPECT_NE(ownership::BUILD_ID, nullptr);
    EXPECT_GT(strlen(ownership::BUILD_ID), 0);
}

TEST(Ownership, BuildSignatureIsDefined) {
    EXPECT_NE(ownership::BUILD_SIGNATURE, nullptr);
    EXPECT_GT(strlen(ownership::BUILD_SIGNATURE), 0);
}

TEST(Ownership, BuildIdHasExpectedFormat) {
    // Format: <git-short-hash>-<YYYYMMDD>-<HHMMSS> or "dev-local"
    std::string buildId = ownership::BUILD_ID;
    // Either dev-local or matches pattern like "a3f2b1c-20250609-143052"
    bool isDevLocal = (buildId == "dev-local");
    bool hasTimestamp = (buildId.length() > 15 && buildId.find('-') != std::string::npos);
    EXPECT_TRUE(isDevLocal || hasTimestamp);
}

TEST(Ownership, TamperStateDefaultsToNotDetected) {
    ownership::TamperState state;
    EXPECT_FALSE(state.detected);
    EXPECT_TRUE(state.luaDiscordValue.empty());
    EXPECT_TRUE(state.luaItchValue.empty());
}

TEST(Ownership, ValidateDetectsTampering) {
    ownership::resetTamperState();

    // Validate with correct values - no tampering
    ownership::validate(std::string(ownership::DISCORD_LINK),
                        std::string(ownership::ITCH_LINK));
    EXPECT_FALSE(ownership::isTamperDetected());

    // Validate with wrong Discord link - tampering detected
    ownership::resetTamperState();
    ownership::validate("https://discord.gg/fake", std::string(ownership::ITCH_LINK));
    EXPECT_TRUE(ownership::isTamperDetected());

    // Validate with wrong itch link - tampering detected
    ownership::resetTamperState();
    ownership::validate(std::string(ownership::DISCORD_LINK), "https://fake.itch.io/");
    EXPECT_TRUE(ownership::isTamperDetected());
}

TEST(Ownership, LuaBindingsExist) {
    sol::state lua;
    lua.open_libraries(sol::lib::base, sol::lib::string);

    ownership::registerLuaBindings(lua);

    // Check that ownership table exists
    sol::table ownership_table = lua["ownership"];
    EXPECT_TRUE(ownership_table.valid());

    // Check that getDiscordLink function exists and returns correct value
    sol::function getDiscordLink = ownership_table["getDiscordLink"];
    EXPECT_TRUE(getDiscordLink.valid());
    std::string discordLink = getDiscordLink();
    EXPECT_EQ(discordLink, ownership::DISCORD_LINK);

    // Check that getItchLink function exists and returns correct value
    sol::function getItchLink = ownership_table["getItchLink"];
    EXPECT_TRUE(getItchLink.valid());
    std::string itchLink = getItchLink();
    EXPECT_EQ(itchLink, ownership::ITCH_LINK);

    // Check that getBuildId function exists and returns correct value
    sol::function getBuildId = ownership_table["getBuildId"];
    EXPECT_TRUE(getBuildId.valid());
    std::string buildId = getBuildId();
    EXPECT_EQ(buildId, ownership::BUILD_ID);

    // Check that validate function exists
    sol::function validate = ownership_table["validate"];
    EXPECT_TRUE(validate.valid());

    // Test that validate function works
    ownership::resetTamperState();
    validate(std::string(ownership::DISCORD_LINK), std::string(ownership::ITCH_LINK));
    EXPECT_FALSE(ownership::isTamperDetected());

    // Test that validate detects tampering
    ownership::resetTamperState();
    validate("https://fake.discord.com", std::string(ownership::ITCH_LINK));
    EXPECT_TRUE(ownership::isTamperDetected());
}

TEST(Ownership, RenderWarningFunctionExists) {
    // Just verify the function exists and is callable
    // Actual rendering requires raylib context which we don't have in unit tests
    ownership::resetTamperState();

    // Should not crash when called with no tampering
    ownership::renderTamperWarningIfNeeded(800, 600);

    // Trigger tampering
    ownership::validate("fake", "fake");
    EXPECT_TRUE(ownership::isTamperDetected());

    // Should not crash when tampering detected (would render in real context)
    ownership::renderTamperWarningIfNeeded(800, 600);
}
