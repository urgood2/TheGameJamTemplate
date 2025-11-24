#include <gtest/gtest.h>

#include "core/globals.hpp"

TEST(CollisionLog, TruncatesAtMax) {
    // Push more than the cap (32) and ensure size is bounded and ordered.
    for (int i = 0; i < 40; ++i) {
        globals::pushCollisionLog(globals::CollisionNote{
            static_cast<entt::entity>(i),
            static_cast<entt::entity>(i + 1),
            true,
            Vector2{0.0f, 0.0f},
            static_cast<double>(i)});
    }

    const auto& log = globals::getCollisionLog();
    ASSERT_EQ(log.size(), 32u);
    // Oldest should be from i = 8 (because 40 - 32 = 8)
    EXPECT_EQ(static_cast<int>(log.front().a), 8);
    EXPECT_EQ(static_cast<int>(log.back().a), 39);
}
