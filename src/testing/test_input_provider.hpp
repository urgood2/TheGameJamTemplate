#pragma once
// TODO: Implement test_input_provider

#include <cstdint>
#include <string>
#include <vector>

namespace testing {

struct TestInputEvent {
    std::string type;
    int key = 0;
    float x = 0.0f;
    float y = 0.0f;
};

class TestInputProvider {
public:
    void clear();
    void enqueue(const TestInputEvent& event);
    bool dequeue(TestInputEvent& out_event);
    std::size_t size() const;

private:
    std::vector<TestInputEvent> queue_;
    std::size_t read_index_ = 0;
};

} // namespace testing
