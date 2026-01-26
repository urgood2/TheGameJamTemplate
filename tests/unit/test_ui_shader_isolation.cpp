#include <gtest/gtest.h>
#include "systems/shaders/shader_pipeline.hpp"

// Test UIShaderRenderContext logic without GPU context
// These tests verify swap count tracking and parity calculation
// IMPORTANT: Do NOT test RAII guards or texture operations (require graphics context)

TEST(UIShaderRenderContext, SwapCountInitializesToZero) {
    shader_pipeline::UIShaderRenderContext ctx;
    EXPECT_EQ(ctx.swapCount, 0);
}

TEST(UIShaderRenderContext, ResetSwapCountSetsToZero) {
    shader_pipeline::UIShaderRenderContext ctx;
    
    ctx.swapCount = 5;
    EXPECT_EQ(ctx.swapCount, 5);
    
    ctx.resetSwapCount();
    EXPECT_EQ(ctx.swapCount, 0);
}

TEST(UIShaderRenderContext, SwapIncrementsSwapCount) {
    shader_pipeline::UIShaderRenderContext ctx;
    
    EXPECT_EQ(ctx.swapCount, 0);
    
    ctx.swap();
    EXPECT_EQ(ctx.swapCount, 1);
    
    ctx.swap();
    EXPECT_EQ(ctx.swapCount, 2);
    
    ctx.swap();
    EXPECT_EQ(ctx.swapCount, 3);
}

TEST(UIShaderRenderContext, SwapCountParityCalculation) {
    shader_pipeline::UIShaderRenderContext ctx;
    
    // Even counts (0, 2, 4) should NOT need Y-flip
    ctx.swapCount = 0;
    EXPECT_FALSE(ctx.needsYFlip());  // (0 % 2) != 0 is false
    
    ctx.swapCount = 2;
    EXPECT_FALSE(ctx.needsYFlip());  // (2 % 2) != 0 is false
    
    ctx.swapCount = 4;
    EXPECT_FALSE(ctx.needsYFlip());  // (4 % 2) != 0 is false
    
    // Odd counts (1, 3, 5) should need Y-flip
    ctx.swapCount = 1;
    EXPECT_TRUE(ctx.needsYFlip());   // (1 % 2) != 0 is true
    
    ctx.swapCount = 3;
    EXPECT_TRUE(ctx.needsYFlip());   // (3 % 2) != 0 is true
    
    ctx.swapCount = 5;
    EXPECT_TRUE(ctx.needsYFlip());   // (5 % 2) != 0 is true
}

TEST(UIShaderRenderContext, ResetAfterMultipleSwaps) {
    shader_pipeline::UIShaderRenderContext ctx;
    
    ctx.swap();
    ctx.swap();
    ctx.swap();
    EXPECT_EQ(ctx.swapCount, 3);
    
    ctx.resetSwapCount();
    EXPECT_EQ(ctx.swapCount, 0);
    
    ctx.swap();
    EXPECT_EQ(ctx.swapCount, 1);
}

TEST(UIShaderRenderContext, InitializedFlagDefaultsFalse) {
    shader_pipeline::UIShaderRenderContext ctx;
    EXPECT_FALSE(ctx.initialized);
}
