#pragma once
// TODO: Implement determinism_guard

namespace testing {

class DeterminismGuard {
public:
    void begin_frame();
    void end_frame();
    void reset();
};

} // namespace testing
