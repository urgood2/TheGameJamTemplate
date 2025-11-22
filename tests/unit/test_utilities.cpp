#include <gtest/gtest.h>

#include "util/utilities.hpp"
#include "systems/uuid/uuid.hpp"

class UtilitiesPathTest : public ::testing::Test {
protected:
    void SetUp() override { uuid::map.clear(); }
    void TearDown() override { uuid::map.clear(); }
};

TEST_F(UtilitiesPathTest, RawAssetPathUsesAssetsPrefix) {
    const std::string asset = "images/ui/button.png";
    const auto full = util::getRawAssetPathNoUUID(asset);
    EXPECT_NE(full.find(asset), std::string::npos);
    EXPECT_EQ(full.rfind(asset), full.size() - asset.size());
}

TEST_F(UtilitiesPathTest, AssetPathLookupReturnsMappedPath) {
    const std::string path = "sounds/click.wav";
    const std::string uid = uuid::add(path);

    const auto resolved = util::getAssetPathUUIDVersion(uid);
    EXPECT_EQ(resolved, path);
}

TEST(UtilitiesMathTest, DistanceReturnsPythagoreanResult) {
    const float dist = util::getDistance(0.0f, 0.0f, 3.0f, 4.0f);
    EXPECT_FLOAT_EQ(dist, 5.0f);
}
