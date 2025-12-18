#include <gtest/gtest.h>

#include "util/startup_timer.hpp"

#include <thread>
#include <chrono>

class StartupTimerTest : public ::testing::Test {
protected:
    void SetUp() override {
        // Reset timer state before each test
        startup_timer::reset();
    }

    void TearDown() override {
        startup_timer::reset();
    }
};

TEST_F(StartupTimerTest, RecordPhaseStoresTimingData) {
    startup_timer::begin_phase("test_phase");
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
    startup_timer::end_phase("test_phase");

    auto phases = startup_timer::get_phases();
    ASSERT_EQ(phases.size(), 1);
    EXPECT_EQ(phases[0].name, "test_phase");
    EXPECT_GT(phases[0].duration_ms, 0.0);
}

TEST_F(StartupTimerTest, MultiplePhaseTracking) {
    startup_timer::begin_phase("phase1");
    std::this_thread::sleep_for(std::chrono::milliseconds(5));
    startup_timer::end_phase("phase1");

    startup_timer::begin_phase("phase2");
    std::this_thread::sleep_for(std::chrono::milliseconds(5));
    startup_timer::end_phase("phase2");

    auto phases = startup_timer::get_phases();
    ASSERT_EQ(phases.size(), 2);
    EXPECT_EQ(phases[0].name, "phase1");
    EXPECT_EQ(phases[1].name, "phase2");
}

TEST_F(StartupTimerTest, ScopedPhaseAutoEndsOnDestruction) {
    {
        startup_timer::ScopedPhase phase("scoped_test");
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }

    auto phases = startup_timer::get_phases();
    ASSERT_EQ(phases.size(), 1);
    EXPECT_EQ(phases[0].name, "scoped_test");
    EXPECT_GT(phases[0].duration_ms, 0.0);
}

TEST_F(StartupTimerTest, GetTotalDurationSumsAllPhases) {
    startup_timer::begin_phase("phase1");
    std::this_thread::sleep_for(std::chrono::milliseconds(5));
    startup_timer::end_phase("phase1");

    startup_timer::begin_phase("phase2");
    std::this_thread::sleep_for(std::chrono::milliseconds(5));
    startup_timer::end_phase("phase2");

    auto total = startup_timer::get_total_duration();
    EXPECT_GT(total, 9.0);  // Should be at least 10ms combined
}

TEST_F(StartupTimerTest, ResetClearsAllPhases) {
    startup_timer::begin_phase("test");
    startup_timer::end_phase("test");

    ASSERT_EQ(startup_timer::get_phases().size(), 1);

    startup_timer::reset();

    EXPECT_EQ(startup_timer::get_phases().size(), 0);
    EXPECT_EQ(startup_timer::get_total_duration(), 0.0);
}

TEST_F(StartupTimerTest, PrintSummaryDoesNotCrash) {
    startup_timer::begin_phase("phase1");
    startup_timer::end_phase("phase1");

    // Should not crash
    EXPECT_NO_THROW(startup_timer::print_summary());
}

TEST_F(StartupTimerTest, EndPhaseWithoutBeginIsHandledGracefully) {
    // Should not crash
    EXPECT_NO_THROW(startup_timer::end_phase("nonexistent"));
    EXPECT_EQ(startup_timer::get_phases().size(), 0);
}

TEST_F(StartupTimerTest, NestedPhasesAreTrackedSeparately) {
    startup_timer::begin_phase("outer");
    std::this_thread::sleep_for(std::chrono::milliseconds(5));

    startup_timer::begin_phase("inner");
    std::this_thread::sleep_for(std::chrono::milliseconds(5));
    startup_timer::end_phase("inner");

    startup_timer::end_phase("outer");

    auto phases = startup_timer::get_phases();
    ASSERT_EQ(phases.size(), 2);
    // Phases are recorded in completion order (inner finishes first)
    EXPECT_EQ(phases[0].name, "inner");
    EXPECT_EQ(phases[1].name, "outer");
    // Outer should have longer duration (includes inner's time)
    EXPECT_GT(phases[1].duration_ms, phases[0].duration_ms);
}
