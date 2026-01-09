#include <gtest/gtest.h>

#include "components/components.hpp"

class BlackboardTest : public ::testing::Test {
protected:
    Blackboard blackboard;
};

TEST_F(BlackboardTest, SetAndGetFloat) {
    blackboard.set("health", 100.0f);
    EXPECT_FLOAT_EQ(blackboard.get<float>("health"), 100.0f);
}

TEST_F(BlackboardTest, SetAndGetString) {
    blackboard.set<std::string>("name", "player");
    EXPECT_EQ(blackboard.get<std::string>("name"), "player");
}

TEST_F(BlackboardTest, SetAndGetVector2) {
    Vector2 pos{10.0f, 20.0f};
    blackboard.set("position", pos);
    
    Vector2 result = blackboard.get<Vector2>("position");
    EXPECT_FLOAT_EQ(result.x, 10.0f);
    EXPECT_FLOAT_EQ(result.y, 20.0f);
}

TEST_F(BlackboardTest, GetThrowsOnKeyNotFound) {
    EXPECT_THROW(blackboard.get<float>("nonexistent"), std::runtime_error);
}

TEST_F(BlackboardTest, GetThrowsOnTypeMismatch) {
    blackboard.set("value", 42);
    EXPECT_THROW(blackboard.get<std::string>("value"), std::bad_any_cast);
}

TEST_F(BlackboardTest, ContainsReturnsTrueForExistingKey) {
    blackboard.set("key", 1);
    EXPECT_TRUE(blackboard.contains("key"));
}

TEST_F(BlackboardTest, ContainsReturnsFalseForMissingKey) {
    EXPECT_FALSE(blackboard.contains("missing"));
}

TEST_F(BlackboardTest, ClearRemovesAllEntries) {
    blackboard.set("a", 1);
    blackboard.set("b", 2);
    blackboard.set("c", 3);
    
    blackboard.clear();
    
    EXPECT_TRUE(blackboard.isEmpty());
    EXPECT_EQ(blackboard.size(), 0u);
}

TEST_F(BlackboardTest, SizeReturnsCorrectCount) {
    EXPECT_EQ(blackboard.size(), 0u);
    
    blackboard.set("a", 1);
    EXPECT_EQ(blackboard.size(), 1u);
    
    blackboard.set("b", 2);
    EXPECT_EQ(blackboard.size(), 2u);
}

TEST_F(BlackboardTest, IsEmptyReturnsTrueWhenEmpty) {
    EXPECT_TRUE(blackboard.isEmpty());
    
    blackboard.set("x", 1);
    EXPECT_FALSE(blackboard.isEmpty());
}
