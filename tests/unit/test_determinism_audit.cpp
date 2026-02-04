#include <gtest/gtest.h>

#include "testing/determinism_audit.hpp"

TEST(DeterminismAudit, NoDivergenceWhenHashesMatch) {
    testing::DeterminismAudit audit;
    audit.start(2);
    audit.record_hash("abc");
    audit.record_hash("abc");
    EXPECT_FALSE(audit.has_diverged());
}

TEST(DeterminismAudit, DetectsDivergence) {
    testing::DeterminismAudit audit;
    audit.start(2);
    audit.record_hash("abc");
    audit.record_hash("def");
    EXPECT_TRUE(audit.has_diverged());
}

TEST(DeterminismAudit, RunsReported) {
    testing::DeterminismAudit audit;
    audit.start(3);
    EXPECT_EQ(audit.runs(), 3);
}
