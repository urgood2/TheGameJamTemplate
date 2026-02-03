#include "testing/test_runtime.hpp"
#include "testing/test_mode_config.hpp"

namespace testing {

bool TestRuntime::initialize(const TestModeConfig& config) {
    (void)config;
    running_ = true;
    return true;
}

void TestRuntime::shutdown() {
    running_ = false;
}

void TestRuntime::tick_frame() {
}

bool TestRuntime::is_running() const {
    return running_;
}

} // namespace testing
