#include "testing/perf_tracker.hpp"

namespace testing {

void PerfTracker::clear() {
    frames_.clear();
}

void PerfTracker::record_frame_ms(double ms) {
    frames_.push_back(ms);
}

double PerfTracker::average_ms() const {
    if (frames_.empty()) {
        return 0.0;
    }
    double total = 0.0;
    for (double value : frames_) {
        total += value;
    }
    return total / static_cast<double>(frames_.size());
}

} // namespace testing
