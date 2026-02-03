#pragma once
// TODO: Implement test_api_registry

#include <string>
#include <vector>

namespace testing {

enum class TestApiKind {
    Query,
    Command,
    State
};

struct TestApiEntry {
    std::string name;
    TestApiKind kind = TestApiKind::Query;
};

class TestApiRegistry {
public:
    void register_entry(const TestApiEntry& entry);
    const std::vector<TestApiEntry>& entries() const;

private:
    std::vector<TestApiEntry> entries_;
};

} // namespace testing
