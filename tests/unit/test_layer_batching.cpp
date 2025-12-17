#include <gtest/gtest.h>

#include "systems/layer/layer.hpp"
#include "systems/layer/layer_command_buffer.hpp"
#include "systems/layer/layer_optimized.hpp"

class LayerBatchingTest : public ::testing::Test {
protected:
    std::shared_ptr<layer::Layer> testLayer;

    void SetUp() override {
        testLayer = std::make_shared<layer::Layer>();
        // Ensure flags start at default
        layer::layer_command_buffer::g_enableStateBatching = false;
    }

    void TearDown() override {
        if (testLayer) {
            layer::layer_command_buffer::Clear(testLayer);
        }
        testLayer.reset();
        // Reset flags to default
        layer::layer_command_buffer::g_enableStateBatching = false;
    }

    // Helper to count consecutive sequences of same command type
    int countTypeChanges(const std::vector<layer::DrawCommandV2>& commands, layer::DrawCommandType type) {
        int changes = 0;
        bool inSequence = false;

        for (const auto& cmd : commands) {
            if (cmd.type == type) {
                if (!inSequence) {
                    changes++;
                    inSequence = true;
                }
            } else {
                inSequence = false;
            }
        }

        return changes;
    }
};

// Test that shader batching reduces shader state changes
TEST_F(LayerBatchingTest, ShaderBatchingReducesStateChanges) {
    // Scenario: Multiple draw commands with different shaders interspersed
    // Without batching: many shader changes
    // With batching: shaders grouped together

    // Create a simple shader (we'll use dummy shaders for testing)
    Shader shader1 = {1, 0, 0};  // Mock shader with id=1
    Shader shader2 = {2, 0, 0};  // Mock shader with id=2

    // Add commands in mixed order: draw with shader1, draw with shader2, draw with shader1
    // All at same z-level to focus on shader batching
    int z = 5;

    // Pattern: shader1, draw, shader2, draw, shader1, draw
    auto* setShader1_a = layer::layer_command_buffer::Add<layer::CmdSetShader>(
        testLayer, z, layer::DrawCommandSpace::Screen);
    setShader1_a->shader = shader1;

    auto* draw1 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(
        testLayer, z, layer::DrawCommandSpace::Screen);

    auto* setShader2 = layer::layer_command_buffer::Add<layer::CmdSetShader>(
        testLayer, z, layer::DrawCommandSpace::Screen);
    setShader2->shader = shader2;

    auto* draw2 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(
        testLayer, z, layer::DrawCommandSpace::Screen);

    auto* setShader1_b = layer::layer_command_buffer::Add<layer::CmdSetShader>(
        testLayer, z, layer::DrawCommandSpace::Screen);
    setShader1_b->shader = shader1;

    auto* draw3 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(
        testLayer, z, layer::DrawCommandSpace::Screen);

    const auto& commands = layer::layer_command_buffer::GetCommandsSorted(testLayer);

    // Without shader batching, we expect commands in insertion order
    // So we should see 3 distinct SetShader command sequences
    // (This test documents current behavior before shader batching is implemented)

    int shaderChanges = countTypeChanges(commands, layer::DrawCommandType::SetShader);

    // Current behavior: 3 shader changes (shader1, shader2, shader1)
    // After implementing shader batching with g_enableShaderBatching flag:
    // Expected: 2 shader changes (shader1 group, shader2 group)

    // For now, just verify we can count shader changes
    EXPECT_EQ(shaderChanges, 3) << "Without batching, expect 3 distinct shader sequences";

    // NOTE: This test will be updated once shader batching is implemented
    // The assertion will change to:
    // if (g_enableShaderBatching) {
    //     EXPECT_LE(shaderChanges, 2) << "With batching, shader changes should be reduced";
    // }
}

// Test that texture batching reduces texture state changes
TEST_F(LayerBatchingTest, TextureBatchingReducesStateChanges) {
    // Similar to shader test, but for textures
    Texture2D tex1 = {1, 0, 0, 0, 0};  // Mock texture with id=1
    Texture2D tex2 = {2, 0, 0, 0, 0};  // Mock texture with id=2

    int z = 5;

    // Pattern: tex1, draw, tex2, draw, tex1, draw
    auto* setTex1_a = layer::layer_command_buffer::Add<layer::CmdSetTexture>(
        testLayer, z, layer::DrawCommandSpace::Screen);
    setTex1_a->texture = tex1;

    auto* draw1 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(
        testLayer, z, layer::DrawCommandSpace::Screen);

    auto* setTex2 = layer::layer_command_buffer::Add<layer::CmdSetTexture>(
        testLayer, z, layer::DrawCommandSpace::Screen);
    setTex2->texture = tex2;

    auto* draw2 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(
        testLayer, z, layer::DrawCommandSpace::Screen);

    auto* setTex1_b = layer::layer_command_buffer::Add<layer::CmdSetTexture>(
        testLayer, z, layer::DrawCommandSpace::Screen);
    setTex1_b->texture = tex1;

    auto* draw3 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(
        testLayer, z, layer::DrawCommandSpace::Screen);

    const auto& commands = layer::layer_command_buffer::GetCommandsSorted(testLayer);

    int textureChanges = countTypeChanges(commands, layer::DrawCommandType::SetTexture);

    // Current behavior: 3 texture changes
    EXPECT_EQ(textureChanges, 3) << "Without batching, expect 3 distinct texture sequences";

    // NOTE: Will be updated once texture batching is implemented
}

// Test combined shader + texture batching
TEST_F(LayerBatchingTest, CombinedShaderTextureBatching) {
    Shader shader1 = {1, 0, 0};
    Shader shader2 = {2, 0, 0};
    Texture2D tex1 = {1, 0, 0, 0, 0};
    Texture2D tex2 = {2, 0, 0, 0, 0};

    int z = 5;

    // Complex pattern: shader1+tex1, shader1+tex2, shader2+tex1, shader1+tex1
    // Optimal batching should group by shader first, then texture

    // shader1 + tex1
    auto* setShader1_a = layer::layer_command_buffer::Add<layer::CmdSetShader>(
        testLayer, z, layer::DrawCommandSpace::Screen);
    setShader1_a->shader = shader1;
    auto* setTex1_a = layer::layer_command_buffer::Add<layer::CmdSetTexture>(
        testLayer, z, layer::DrawCommandSpace::Screen);
    setTex1_a->texture = tex1;
    auto* draw1 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(
        testLayer, z, layer::DrawCommandSpace::Screen);

    // shader1 + tex2
    auto* setShader1_b = layer::layer_command_buffer::Add<layer::CmdSetShader>(
        testLayer, z, layer::DrawCommandSpace::Screen);
    setShader1_b->shader = shader1;
    auto* setTex2_a = layer::layer_command_buffer::Add<layer::CmdSetTexture>(
        testLayer, z, layer::DrawCommandSpace::Screen);
    setTex2_a->texture = tex2;
    auto* draw2 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(
        testLayer, z, layer::DrawCommandSpace::Screen);

    // shader2 + tex1
    auto* setShader2 = layer::layer_command_buffer::Add<layer::CmdSetShader>(
        testLayer, z, layer::DrawCommandSpace::Screen);
    setShader2->shader = shader2;
    auto* setTex1_b = layer::layer_command_buffer::Add<layer::CmdSetTexture>(
        testLayer, z, layer::DrawCommandSpace::Screen);
    setTex1_b->texture = tex1;
    auto* draw3 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(
        testLayer, z, layer::DrawCommandSpace::Screen);

    // shader1 + tex1 (again)
    auto* setShader1_c = layer::layer_command_buffer::Add<layer::CmdSetShader>(
        testLayer, z, layer::DrawCommandSpace::Screen);
    setShader1_c->shader = shader1;
    auto* setTex1_c = layer::layer_command_buffer::Add<layer::CmdSetTexture>(
        testLayer, z, layer::DrawCommandSpace::Screen);
    setTex1_c->texture = tex1;
    auto* draw4 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(
        testLayer, z, layer::DrawCommandSpace::Screen);

    const auto& commands = layer::layer_command_buffer::GetCommandsSorted(testLayer);

    int shaderChanges = countTypeChanges(commands, layer::DrawCommandType::SetShader);
    int textureChanges = countTypeChanges(commands, layer::DrawCommandType::SetTexture);

    // Current behavior: many state changes
    EXPECT_EQ(shaderChanges, 4);
    EXPECT_EQ(textureChanges, 4);

    // After batching:
    // - shader1 group (with tex1 + tex2)
    // - shader2 group (with tex1)
    // Ideally: 2 shader changes, 3-4 texture changes
    // (texture changes depend on secondary sort key)
}

// Test that z-order still takes precedence over batching
TEST_F(LayerBatchingTest, ZOrderTakesPrecedenceOverBatching) {
    Shader shader1 = {1, 0, 0};
    Shader shader2 = {2, 0, 0};

    // Different z levels with same shader repeated
    auto* setShader1_z1 = layer::layer_command_buffer::Add<layer::CmdSetShader>(
        testLayer, 1, layer::DrawCommandSpace::Screen);
    setShader1_z1->shader = shader1;
    auto* draw1 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(
        testLayer, 1, layer::DrawCommandSpace::Screen);

    auto* setShader2_z2 = layer::layer_command_buffer::Add<layer::CmdSetShader>(
        testLayer, 2, layer::DrawCommandSpace::Screen);
    setShader2_z2->shader = shader2;
    auto* draw2 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(
        testLayer, 2, layer::DrawCommandSpace::Screen);

    auto* setShader1_z3 = layer::layer_command_buffer::Add<layer::CmdSetShader>(
        testLayer, 3, layer::DrawCommandSpace::Screen);
    setShader1_z3->shader = shader1;
    auto* draw3 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(
        testLayer, 3, layer::DrawCommandSpace::Screen);

    const auto& commands = layer::layer_command_buffer::GetCommandsSorted(testLayer);

    // Verify z-order is respected
    EXPECT_EQ(commands[0].z, 1);
    EXPECT_EQ(commands[1].z, 1);
    EXPECT_EQ(commands[2].z, 2);
    EXPECT_EQ(commands[3].z, 2);
    EXPECT_EQ(commands[4].z, 3);
    EXPECT_EQ(commands[5].z, 3);

    // Even with batching, shader1 appears at z=1 and z=3 separately
    // because z-order takes precedence
}
