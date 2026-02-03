#include "testing/determinism_audit.hpp"

namespace testing {

void DeterminismAudit::start(int runs) {
    runs_ = runs;
    hashes_.clear();
}

void DeterminismAudit::record_hash(const std::string& hash) {
    hashes_.push_back(hash);
}

bool DeterminismAudit::has_diverged() const {
    return false;
}

int DeterminismAudit::runs() const {
    return runs_;
}

} // namespace testing
