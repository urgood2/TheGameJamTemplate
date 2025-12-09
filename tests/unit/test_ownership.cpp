// tests/unit/test_ownership.cpp
#include <gtest/gtest.h>
#include "core/ownership.hpp"

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
