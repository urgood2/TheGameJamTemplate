#include <gtest/gtest.h>

#include "systems/layer/layer_optimized.hpp"

class DrawCallCounterTest : public ::testing::Test {
protected:
    void SetUp() override {
        // Reset counter before each test
        layer::g_drawCallsThisFrame = 0;
    }

    void TearDown() override {
        layer::g_drawCallsThisFrame = 0;
    }
};

TEST_F(DrawCallCounterTest, CounterExistsAndStartsAtZero) {
    EXPECT_EQ(layer::g_drawCallsThisFrame, 0);
}

TEST_F(DrawCallCounterTest, CounterCanBeIncremented) {
    layer::g_drawCallsThisFrame = 0;
    layer::g_drawCallsThisFrame++;
    EXPECT_EQ(layer::g_drawCallsThisFrame, 1);

    layer::g_drawCallsThisFrame++;
    EXPECT_EQ(layer::g_drawCallsThisFrame, 2);
}

TEST_F(DrawCallCounterTest, CounterCanBeReset) {
    layer::g_drawCallsThisFrame = 42;
    EXPECT_EQ(layer::g_drawCallsThisFrame, 42);

    layer::g_drawCallsThisFrame = 0;
    EXPECT_EQ(layer::g_drawCallsThisFrame, 0);
}
