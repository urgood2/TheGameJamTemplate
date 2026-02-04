#include <gtest/gtest.h>

#include "testing/determinism_guard.hpp"
#include "testing/test_mode_config.hpp"

TEST(DeterminismGuard, WarnModeRecordsViolation) {
    testing::TestModeConfig config;
    config.determinism_violation = testing::DeterminismViolationMode::Warn;

    testing::DeterminismGuard guard;
    guard.initialize(config);
    guard.begin_frame();
    guard.check_time_usage("unit_test");

    auto violations = guard.get_violations();
    ASSERT_EQ(violations.size(), 1u);
    EXPECT_EQ(violations[0].code, testing::DeterminismCode::DET_TIME);
    EXPECT_EQ(violations[0].frame_number, 1);
    EXPECT_FALSE(violations[0].timestamp.empty());
}

TEST(DeterminismGuard, FatalModeThrows) {
    testing::TestModeConfig config;
    config.determinism_violation = testing::DeterminismViolationMode::Fatal;

    testing::DeterminismGuard guard;
    guard.initialize(config);

    EXPECT_THROW(guard.check_rng_usage("unit_test", false), std::runtime_error);
}

TEST(DeterminismGuard, NetworkModeLocalhost) {
    testing::TestModeConfig config;
    config.determinism_violation = testing::DeterminismViolationMode::Warn;
    config.allow_network = testing::NetworkMode::Localhost;

    testing::DeterminismGuard guard;
    guard.initialize(config);

    guard.check_network_access("localhost:8080");
    EXPECT_FALSE(guard.has_violations());

    guard.check_network_access("example.com:80");
    EXPECT_TRUE(guard.has_violations());
}
