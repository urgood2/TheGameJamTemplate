#include "testing/test_input_provider.hpp"

namespace testing {

void TestInputProvider::clear() {
    queue_.clear();
    read_index_ = 0;
}

void TestInputProvider::enqueue(const TestInputEvent& event) {
    queue_.push_back(event);
}

bool TestInputProvider::dequeue(TestInputEvent& out_event) {
    if (read_index_ >= queue_.size()) {
        return false;
    }
    out_event = queue_[read_index_++];
    return true;
}

std::size_t TestInputProvider::size() const {
    return queue_.size() - read_index_;
}

} // namespace testing
