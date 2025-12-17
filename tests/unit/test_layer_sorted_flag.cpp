#include <gtest/gtest.h>

#include "systems/layer/layer.hpp"
#include "systems/layer/layer_command_buffer.hpp"
#include "systems/layer/layer_optimized.hpp"

class LayerSortedFlagTest : public ::testing::Test {
protected:
    std::shared_ptr<layer::Layer> testLayer;

    void SetUp() override {
        testLayer = std::make_shared<layer::Layer>();
        testLayer->isSorted = true;  // Start sorted
    }

    void TearDown() override {
        if (testLayer) {
            layer::layer_command_buffer::Clear(testLayer);
        }
        testLayer.reset();
    }
};

// Test that adding a command sets isSorted to false
TEST_F(LayerSortedFlagTest, AddingCommandMarksDirty) {
    EXPECT_TRUE(testLayer->isSorted) << "Layer should start sorted";

    // Add a command with z=0
    auto* cmd = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(testLayer, 0);
    ASSERT_NE(cmd, nullptr) << "Command should be allocated";

    EXPECT_FALSE(testLayer->isSorted) << "Layer should be marked unsorted after adding command";
}

// Test that adding a command with non-zero z also marks dirty
TEST_F(LayerSortedFlagTest, AddingCommandWithZOrderMarksDirty) {
    EXPECT_TRUE(testLayer->isSorted) << "Layer should start sorted";

    // Add a command with z=10
    auto* cmd = layer::layer_command_buffer::Add<layer::CmdDrawCircleFilled>(testLayer, 10);
    ASSERT_NE(cmd, nullptr) << "Command should be allocated";

    EXPECT_FALSE(testLayer->isSorted) << "Layer should be marked unsorted after adding z-ordered command";
}

// Test that GetCommandsSorted marks the layer as sorted
TEST_F(LayerSortedFlagTest, GetCommandsSortedMarksSorted) {
    // Add a command to make it dirty
    layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(testLayer, 5);
    EXPECT_FALSE(testLayer->isSorted) << "Layer should be unsorted after adding command";

    // Get sorted commands
    const auto& commands = layer::layer_command_buffer::GetCommandsSorted(testLayer);

    EXPECT_TRUE(testLayer->isSorted) << "Layer should be marked sorted after GetCommandsSorted";
}

// Test that adding another command after sorting marks dirty again
TEST_F(LayerSortedFlagTest, AddingCommandAfterSortingMarksDirty) {
    // Add first command
    layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(testLayer, 0);
    EXPECT_FALSE(testLayer->isSorted);

    // Sort
    layer::layer_command_buffer::GetCommandsSorted(testLayer);
    EXPECT_TRUE(testLayer->isSorted);

    // Add another command
    layer::layer_command_buffer::Add<layer::CmdDrawCircleFilled>(testLayer, 0);
    EXPECT_FALSE(testLayer->isSorted) << "Layer should be marked unsorted after adding new command";
}

// Test that Clear marks the layer as sorted
TEST_F(LayerSortedFlagTest, ClearMarksSorted) {
    // Add commands to make it dirty
    layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(testLayer, 5);
    layer::layer_command_buffer::Add<layer::CmdDrawCircleFilled>(testLayer, 3);
    EXPECT_FALSE(testLayer->isSorted);

    // Clear
    layer::layer_command_buffer::Clear(testLayer);

    EXPECT_TRUE(testLayer->isSorted) << "Layer should be marked sorted after Clear";
    EXPECT_EQ(testLayer->commands.size(), 0) << "Commands should be empty after Clear";
}

// Test that calling GetCommandsSorted multiple times doesn't re-sort
TEST_F(LayerSortedFlagTest, GetCommandsSortedCached) {
    // Add commands with different z-orders
    auto* cmd1 = layer::layer_command_buffer::Add<layer::CmdDrawRectangle>(testLayer, 10);
    auto* cmd2 = layer::layer_command_buffer::Add<layer::CmdDrawCircleFilled>(testLayer, 5);
    auto* cmd3 = layer::layer_command_buffer::Add<layer::CmdDrawLine>(testLayer, 15);

    EXPECT_FALSE(testLayer->isSorted);

    // First call should sort
    const auto& commands1 = layer::layer_command_buffer::GetCommandsSorted(testLayer);
    EXPECT_TRUE(testLayer->isSorted);
    EXPECT_EQ(commands1.size(), 3);

    // Verify sorted order (by z)
    EXPECT_EQ(commands1[0].z, 5);   // cmd2
    EXPECT_EQ(commands1[1].z, 10);  // cmd1
    EXPECT_EQ(commands1[2].z, 15);  // cmd3

    // Second call should NOT re-sort (flag should remain true)
    const auto& commands2 = layer::layer_command_buffer::GetCommandsSorted(testLayer);
    EXPECT_TRUE(testLayer->isSorted);
    EXPECT_EQ(&commands1, &commands2) << "Should return reference to same vector";
}

// Test edge case: empty layer stays sorted
TEST_F(LayerSortedFlagTest, EmptyLayerStaysSorted) {
    EXPECT_TRUE(testLayer->isSorted);

    // Get commands on empty layer
    const auto& commands = layer::layer_command_buffer::GetCommandsSorted(testLayer);

    EXPECT_TRUE(testLayer->isSorted);
    EXPECT_EQ(commands.size(), 0);
}
