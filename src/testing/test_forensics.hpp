#pragma once
// TODO: Implement test_forensics

#include <string>
#include <vector>

namespace testing {

class TestForensics {
public:
    void record_event(const std::string& event);
    void clear();
    const std::vector<std::string>& events() const;

private:
    std::vector<std::string> events_;
};

} // namespace testing
