#include "testing/test_api_registry.hpp"

namespace testing {

void TestApiRegistry::register_entry(const TestApiEntry& entry) {
    entries_.push_back(entry);
}

const std::vector<TestApiEntry>& TestApiRegistry::entries() const {
    return entries_;
}

} // namespace testing
