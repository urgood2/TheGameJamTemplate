#pragma once

#include <mutex>
#include <optional>
#include <string>
#include <vector>

namespace testing {

enum class DeterminismViolationMode;
enum class NetworkMode;
struct TestModeConfig;

enum class DeterminismCode {
    DET_TIME,
    DET_RNG,
    DET_FS_ORDER,
    DET_ASYNC_ORDER,
    DET_NET
};

struct ViolationRecord {
    DeterminismCode code;
    std::string details;
    std::optional<std::vector<std::string>> stack;
    int frame_number = 0;
    std::string timestamp;
};

class DeterminismGuard {
public:
    void initialize(const TestModeConfig& config);

    void begin_frame();
    void end_frame();
    void reset();

    void report_violation(DeterminismCode code, const std::string& details);
    void report_violation_with_stack(DeterminismCode code,
                                     const std::string& details,
                                     const std::vector<std::string>& stack);

    void check_time_usage(const std::string& caller);
    void check_rng_usage(const std::string& caller, bool is_seeded);
    void check_fs_enumeration(const std::string& path, bool is_sorted);
    void check_network_access(const std::string& endpoint);

    std::vector<ViolationRecord> get_violations() const;
    bool has_violations() const;

private:
    void record_violation(DeterminismCode code,
                          const std::string& details,
                          const std::optional<std::vector<std::string>>& stack);
    bool allow_network_endpoint(const std::string& endpoint) const;

    DeterminismViolationMode mode_{};
    NetworkMode network_mode_{};
    mutable std::mutex mutex_;
    std::vector<ViolationRecord> violations_;
    int current_frame_ = 0;
};

} // namespace testing
