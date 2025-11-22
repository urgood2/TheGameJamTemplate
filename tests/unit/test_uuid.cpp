#include <gtest/gtest.h>

#include "systems/uuid/uuid.hpp"

class UUIDMapTest : public ::testing::Test {
protected:
    void SetUp() override { uuid::map.clear(); }
    void TearDown() override { uuid::map.clear(); }
};

TEST_F(UUIDMapTest, AddStoresNormalizedKeyAndValue) {
    const std::string path = "assets/foo/bar.txt";
    const std::string uid = uuid::add(path);

    ASSERT_FALSE(uid.empty());
    auto found = uuid::map.find(uid);
    ASSERT_NE(found, uuid::map.end());
    EXPECT_EQ(found->second, path);
}

TEST_F(UUIDMapTest, LookupReturnsOriginalPathForUid) {
    const std::string path = "assets/ui/panel.png";
    const std::string uid = uuid::add(path);

    const auto resolved = uuid::lookup(uid);
    EXPECT_EQ(resolved, path);
}
