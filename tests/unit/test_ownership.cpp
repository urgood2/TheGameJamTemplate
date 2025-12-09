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
