#pragma once
// TODO: Implement test_mode integration

#include <memory>

namespace testing {

struct TestModeConfig;
class TestRuntime;

class TestMode {
public:
    TestMode() = default;
    bool initialize(const TestModeConfig& config);
    void shutdown();
    void update();
    TestRuntime* runtime();

private:
    std::unique_ptr<TestRuntime> runtime_;
};

bool is_test_mode_enabled();
void set_test_mode_enabled(bool enabled);

} // namespace testing
