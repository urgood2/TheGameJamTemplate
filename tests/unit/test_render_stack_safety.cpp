#include <gtest/gtest.h>
#include "systems/layer/render_stack_error.hpp"

TEST(RenderStackSafety, ErrorContainsStackDepth) {
    layer::RenderStackError error(16, "overflow");
    EXPECT_EQ(error.depth(), 16);
    EXPECT_NE(std::string(error.what()).find("overflow"), std::string::npos);
}

TEST(RenderStackSafety, ErrorContainsContext) {
    layer::RenderStackError error(5, "push failed", "during UI render");
    std::string msg = error.what();
    EXPECT_NE(msg.find("during UI render"), std::string::npos);
}
