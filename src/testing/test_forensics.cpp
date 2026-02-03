#include "testing/test_forensics.hpp"

namespace testing {

void TestForensics::record_event(const std::string& event) {
    events_.push_back(event);
}

void TestForensics::clear() {
    events_.clear();
}

const std::vector<std::string>& TestForensics::events() const {
    return events_;
}

} // namespace testing
