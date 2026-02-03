#pragma once
// TODO: Implement perf_tracker

#include <vector>

namespace testing {

class PerfTracker {
public:
    void clear();
    void record_frame_ms(double ms);
    double average_ms() const;

private:
    std::vector<double> frames_;
};

} // namespace testing
