#include "testing/test_mode.hpp"
#include "testing/test_runtime.hpp"

namespace testing {

namespace {
bool g_test_mode_enabled = false;
}

bool TestMode::initialize(const TestModeConfig& config) {
    (void)config;
    runtime_ = std::make_unique<TestRuntime>();
    g_test_mode_enabled = true;
    return true;
}

void TestMode::shutdown() {
    if (runtime_) {
        runtime_->shutdown();
    }
    runtime_.reset();
    g_test_mode_enabled = false;
}

void TestMode::update() {
    if (runtime_) {
        runtime_->tick_frame();
    }
}

TestRuntime* TestMode::runtime() {
    return runtime_.get();
}

bool is_test_mode_enabled() {
    return g_test_mode_enabled;
}

void set_test_mode_enabled(bool enabled) {
    g_test_mode_enabled = enabled;
}

} // namespace testing
