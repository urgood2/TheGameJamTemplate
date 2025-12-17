#include <gtest/gtest.h>

#include "systems/layer/layer.hpp"
#include "systems/layer/layer_command_buffer.hpp"
#include "systems/layer/layer_optimized.hpp"

class LayerStateBatchingTest : public ::testing::Test {
protected:
    std::shared_ptr<layer::Layer> testLayer;

    void SetUp() override {
        testLayer = std::make_shared<layer::Layer>();
        // Ensure flag starts at default (false)
        layer::layer_command_buffer::g_enableStateBatching = false;
    }

    void TearDown() override {
        if (testLayer) {
            layer::layer_command_buffer::Clear(testLayer);
        }
        testLayer.reset();
        // Reset flag to default
        layer::layer_command_buffer::g_enableStateBatching = false;
    }
};

// Test that with flag OFF, commands are sorted by z only, preserving insertion order within same z
TEST_F(LayerStateBatchingTest, FlagOffSortsByZOnly) {
    layer::layer_command_buffer::g_enableStateBatching = false;

    // Add commands with same z but different spaces
    // Insertion order: Screen, World, Screen
    auto* cmd1 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(
        testLayer, 5, layer::DrawCommandSpace::Screen);
    auto* cmd2 = layer::layer_command_buffer::Add<layer::CmdDrawCircleFilled>(
        testLayer, 5, layer::DrawCommandSpace::World);
    auto* cmd3 = layer::layer_command_buffer::Add<layer::CmdDrawLine>(
        testLayer, 5, layer::DrawCommandSpace::Screen);

    const auto& commands = layer::layer_command_buffer::GetCommandsSorted(testLayer);

    ASSERT_EQ(commands.size(), 3);

    // All commands should have same z
    EXPECT_EQ(commands[0].z, 5);
    EXPECT_EQ(commands[1].z, 5);
    EXPECT_EQ(commands[2].z, 5);

    // Insertion order should be preserved (no sorting by space)
    EXPECT_EQ(commands[0].space, layer::DrawCommandSpace::Screen);
    EXPECT_EQ(commands[1].space, layer::DrawCommandSpace::World);
    EXPECT_EQ(commands[2].space, layer::DrawCommandSpace::Screen);
}

// Test that with flag ON, commands are sorted by z, then by space
TEST_F(LayerStateBatchingTest, FlagOnSortsByZThenSpace) {
    layer::layer_command_buffer::g_enableStateBatching = true;

    // Add commands with same z but different spaces
    // Insertion order: Screen, World, Screen
    auto* cmd1 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(
        testLayer, 5, layer::DrawCommandSpace::Screen);
    auto* cmd2 = layer::layer_command_buffer::Add<layer::CmdDrawCircleFilled>(
        testLayer, 5, layer::DrawCommandSpace::World);
    auto* cmd3 = layer::layer_command_buffer::Add<layer::CmdDrawLine>(
        testLayer, 5, layer::DrawCommandSpace::Screen);

    const auto& commands = layer::layer_command_buffer::GetCommandsSorted(testLayer);

    ASSERT_EQ(commands.size(), 3);

    // All commands should have same z
    EXPECT_EQ(commands[0].z, 5);
    EXPECT_EQ(commands[1].z, 5);
    EXPECT_EQ(commands[2].z, 5);

    // Commands should be batched by space (World < Screen in enum order)
    EXPECT_EQ(commands[0].space, layer::DrawCommandSpace::World);
    EXPECT_EQ(commands[1].space, layer::DrawCommandSpace::Screen);
    EXPECT_EQ(commands[2].space, layer::DrawCommandSpace::Screen);
}

// Test that with flag ON, z-order takes precedence over space
TEST_F(LayerStateBatchingTest, FlagOnZOrderTakesPrecedence) {
    layer::layer_command_buffer::g_enableStateBatching = true;

    // Add commands with different z and different spaces
    auto* cmd1 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(
        testLayer, 10, layer::DrawCommandSpace::Screen);
    auto* cmd2 = layer::layer_command_buffer::Add<layer::CmdDrawCircleFilled>(
        testLayer, 5, layer::DrawCommandSpace::World);
    auto* cmd3 = layer::layer_command_buffer::Add<layer::CmdDrawLine>(
        testLayer, 15, layer::DrawCommandSpace::Screen);
    auto* cmd4 = layer::layer_command_buffer::Add<layer::CmdDrawTriangle>(
        testLayer, 5, layer::DrawCommandSpace::Screen);

    const auto& commands = layer::layer_command_buffer::GetCommandsSorted(testLayer);

    ASSERT_EQ(commands.size(), 4);

    // Should be sorted by z first
    EXPECT_EQ(commands[0].z, 5);
    EXPECT_EQ(commands[1].z, 5);
    EXPECT_EQ(commands[2].z, 10);
    EXPECT_EQ(commands[3].z, 15);

    // Within z=5, should be sorted by space (World < Screen)
    EXPECT_EQ(commands[0].space, layer::DrawCommandSpace::World);
    EXPECT_EQ(commands[1].space, layer::DrawCommandSpace::Screen);
}

// Test that toggling the flag affects sorting behavior
TEST_F(LayerStateBatchingTest, TogglingFlagChangesSortBehavior) {
    // First, add commands with flag OFF
    layer::layer_command_buffer::g_enableStateBatching = false;

    auto* cmd1 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(
        testLayer, 5, layer::DrawCommandSpace::Screen);
    auto* cmd2 = layer::layer_command_buffer::Add<layer::CmdDrawCircleFilled>(
        testLayer, 5, layer::DrawCommandSpace::World);

    const auto& commands1 = layer::layer_command_buffer::GetCommandsSorted(testLayer);

    // Insertion order preserved
    EXPECT_EQ(commands1[0].space, layer::DrawCommandSpace::Screen);
    EXPECT_EQ(commands1[1].space, layer::DrawCommandSpace::World);

    // Clear and try again with flag ON
    layer::layer_command_buffer::Clear(testLayer);
    layer::layer_command_buffer::g_enableStateBatching = true;

    auto* cmd3 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(
        testLayer, 5, layer::DrawCommandSpace::Screen);
    auto* cmd4 = layer::layer_command_buffer::Add<layer::CmdDrawCircleFilled>(
        testLayer, 5, layer::DrawCommandSpace::World);

    const auto& commands2 = layer::layer_command_buffer::GetCommandsSorted(testLayer);

    // Sorted by space (World < Screen)
    EXPECT_EQ(commands2[0].space, layer::DrawCommandSpace::World);
    EXPECT_EQ(commands2[1].space, layer::DrawCommandSpace::Screen);
}

// Test that batching preserves insertion order within same z and space
TEST_F(LayerStateBatchingTest, FlagOnPreservesInsertionOrderWithinBatch) {
    layer::layer_command_buffer::g_enableStateBatching = true;

    // Add multiple commands with same z and same space
    auto* cmd1 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(
        testLayer, 5, layer::DrawCommandSpace::Screen);
    auto* cmd2 = layer::layer_command_buffer::Add<layer::CmdDrawCircleFilled>(
        testLayer, 5, layer::DrawCommandSpace::Screen);
    auto* cmd3 = layer::layer_command_buffer::Add<layer::CmdDrawLine>(
        testLayer, 5, layer::DrawCommandSpace::Screen);

    const auto& commands = layer::layer_command_buffer::GetCommandsSorted(testLayer);

    ASSERT_EQ(commands.size(), 3);

    // All should have same z and space
    EXPECT_EQ(commands[0].z, 5);
    EXPECT_EQ(commands[1].z, 5);
    EXPECT_EQ(commands[2].z, 5);
    EXPECT_EQ(commands[0].space, layer::DrawCommandSpace::Screen);
    EXPECT_EQ(commands[1].space, layer::DrawCommandSpace::Screen);
    EXPECT_EQ(commands[2].space, layer::DrawCommandSpace::Screen);

    // Insertion order should be preserved (stable_sort)
    EXPECT_EQ(commands[0].data, cmd1);
    EXPECT_EQ(commands[1].data, cmd2);
    EXPECT_EQ(commands[2].data, cmd3);
}

// Test complex scenario with mixed z-levels and spaces
TEST_F(LayerStateBatchingTest, ComplexMixedScenario) {
    layer::layer_command_buffer::g_enableStateBatching = true;

    // Create a complex scenario:
    // z=1 Screen, z=2 World, z=1 World, z=2 Screen, z=3 World, z=3 Screen
    auto* cmd1 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(
        testLayer, 1, layer::DrawCommandSpace::Screen);
    auto* cmd2 = layer::layer_command_buffer::Add<layer::CmdDrawCircleFilled>(
        testLayer, 2, layer::DrawCommandSpace::World);
    auto* cmd3 = layer::layer_command_buffer::Add<layer::CmdDrawLine>(
        testLayer, 1, layer::DrawCommandSpace::World);
    auto* cmd4 = layer::layer_command_buffer::Add<layer::CmdDrawTriangle>(
        testLayer, 2, layer::DrawCommandSpace::Screen);
    auto* cmd5 = layer::layer_command_buffer::Add<layer::CmdDrawPolygon>(
        testLayer, 3, layer::DrawCommandSpace::World);
    auto* cmd6 = layer::layer_command_buffer::Add<layer::CmdDrawText>(
        testLayer, 3, layer::DrawCommandSpace::Screen);

    const auto& commands = layer::layer_command_buffer::GetCommandsSorted(testLayer);

    ASSERT_EQ(commands.size(), 6);

    // Expected order:
    // z=1: World (cmd3), Screen (cmd1)
    // z=2: World (cmd2), Screen (cmd4)
    // z=3: World (cmd5), Screen (cmd6)

    EXPECT_EQ(commands[0].z, 1);
    EXPECT_EQ(commands[0].space, layer::DrawCommandSpace::World);
    EXPECT_EQ(commands[0].data, cmd3);

    EXPECT_EQ(commands[1].z, 1);
    EXPECT_EQ(commands[1].space, layer::DrawCommandSpace::Screen);
    EXPECT_EQ(commands[1].data, cmd1);

    EXPECT_EQ(commands[2].z, 2);
    EXPECT_EQ(commands[2].space, layer::DrawCommandSpace::World);
    EXPECT_EQ(commands[2].data, cmd2);

    EXPECT_EQ(commands[3].z, 2);
    EXPECT_EQ(commands[3].space, layer::DrawCommandSpace::Screen);
    EXPECT_EQ(commands[3].data, cmd4);

    EXPECT_EQ(commands[4].z, 3);
    EXPECT_EQ(commands[4].space, layer::DrawCommandSpace::World);
    EXPECT_EQ(commands[4].data, cmd5);

    EXPECT_EQ(commands[5].z, 3);
    EXPECT_EQ(commands[5].space, layer::DrawCommandSpace::Screen);
    EXPECT_EQ(commands[5].data, cmd6);
}
