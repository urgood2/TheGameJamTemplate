#pragma once
// TODO: Implement test_runtime

#include <cstdint>

namespace testing {

struct TestModeConfig;

class TestRuntime {
public:
    TestRuntime() = default;
    bool initialize(const TestModeConfig& config);
    void shutdown();
    void tick_frame();
    bool is_running() const;

private:
    bool running_ = false;
};

} // namespace testing
