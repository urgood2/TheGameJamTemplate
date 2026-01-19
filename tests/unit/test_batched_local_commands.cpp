#include <gtest/gtest.h>

#include "systems/shaders/shader_draw_commands.hpp"

using namespace shader_draw_commands;

class BatchedLocalCommandsTest : public ::testing::Test {
protected:
    BatchedLocalCommands batch;

    // Helper to create a minimal OwnedDrawCommand with specified z
    OwnedDrawCommand makeCommand(int z) {
        OwnedDrawCommand cmd;
        cmd.cmd.z = z;
        return cmd;
    }
};

// Test that the isSorted flag exists and defaults to true
TEST_F(BatchedLocalCommandsTest, IsSortedFlagDefaultsToTrue) {
    EXPECT_TRUE(batch.isSorted) << "New batch should default to isSorted=true";
}

// Test that monotonically increasing z-order maintains sorted flag
TEST_F(BatchedLocalCommandsTest, MonotonicZOrderMaintainsSortedFlag) {
    batch.addCommand(makeCommand(1));
    batch.addCommand(makeCommand(2));
    batch.addCommand(makeCommand(3));

    EXPECT_TRUE(batch.isSorted)
        << "Monotonically increasing z-order should keep isSorted=true";
}

// Test that equal z-order values still maintain sorted flag
TEST_F(BatchedLocalCommandsTest, EqualZOrderMaintainsSortedFlag) {
    batch.addCommand(makeCommand(5));
    batch.addCommand(makeCommand(5));
    batch.addCommand(makeCommand(5));

    EXPECT_TRUE(batch.isSorted)
        << "Equal z-values should maintain isSorted=true (stable sort preserves order)";
}

// Test that breaking z-order (lower after higher) clears sorted flag
TEST_F(BatchedLocalCommandsTest, BreakingZOrderClearsSortedFlag) {
    batch.addCommand(makeCommand(3));
    batch.addCommand(makeCommand(1));  // Lower z after higher

    EXPECT_FALSE(batch.isSorted)
        << "Lower z after higher should set isSorted=false";
}

// Test that clear() resets the sorted flag to true
TEST_F(BatchedLocalCommandsTest, ClearResetsSortedFlag) {
    batch.addCommand(makeCommand(3));
    batch.addCommand(makeCommand(1));  // Makes isSorted=false
    ASSERT_FALSE(batch.isSorted);

    batch.clear();

    EXPECT_TRUE(batch.isSorted)
        << "clear() should reset isSorted=true";
    EXPECT_TRUE(batch.commands.empty())
        << "clear() should also empty the commands vector";
}

// Test that addCommand actually adds the command
TEST_F(BatchedLocalCommandsTest, AddCommandAddsToVector) {
    EXPECT_EQ(batch.commands.size(), 0u);

    batch.addCommand(makeCommand(10));

    EXPECT_EQ(batch.commands.size(), 1u);
    EXPECT_EQ(batch.commands[0].cmd.z, 10);
}

// Test edge case: first command always maintains sorted
TEST_F(BatchedLocalCommandsTest, FirstCommandAlwaysMaintainsSorted) {
    batch.addCommand(makeCommand(100));
    EXPECT_TRUE(batch.isSorted);

    batch.clear();
    batch.addCommand(makeCommand(-50));
    EXPECT_TRUE(batch.isSorted);
}

// Test complex sequence: sorted, then unsorted, then clear, then sorted again
TEST_F(BatchedLocalCommandsTest, ComplexSequenceTracksCorrectly) {
    // Start sorted
    batch.addCommand(makeCommand(1));
    batch.addCommand(makeCommand(2));
    EXPECT_TRUE(batch.isSorted);

    // Break sort
    batch.addCommand(makeCommand(0));
    EXPECT_FALSE(batch.isSorted);

    // Clear and restart
    batch.clear();
    EXPECT_TRUE(batch.isSorted);

    // New sequence stays sorted
    batch.addCommand(makeCommand(10));
    batch.addCommand(makeCommand(20));
    EXPECT_TRUE(batch.isSorted);
}
