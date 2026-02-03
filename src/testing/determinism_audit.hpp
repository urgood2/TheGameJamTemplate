#pragma once
// TODO: Implement determinism_audit

#include <string>
#include <vector>

namespace testing {

class DeterminismAudit {
public:
    void start(int runs);
    void record_hash(const std::string& hash);
    bool has_diverged() const;
    int runs() const;

private:
    int runs_ = 0;
    std::vector<std::string> hashes_;
};

} // namespace testing
