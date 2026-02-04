#include "testing/determinism_guard.hpp"

#include <chrono>
#include <stdexcept>

#include "spdlog/spdlog.h"
#include "testing/test_mode_config.hpp"

namespace testing {
namespace {

const char* code_label(DeterminismCode code) {
    switch (code) {
        case DeterminismCode::DET_TIME:
            return "DET_TIME";
        case DeterminismCode::DET_RNG:
            return "DET_RNG";
        case DeterminismCode::DET_FS_ORDER:
            return "DET_FS_ORDER";
        case DeterminismCode::DET_ASYNC_ORDER:
            return "DET_ASYNC_ORDER";
        case DeterminismCode::DET_NET:
            return "DET_NET";
    }
    return "DET_UNKNOWN";
}

std::string timestamp_now() {
    auto now = std::chrono::system_clock::now().time_since_epoch();
    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now).count();
    return std::to_string(ms);
}

bool is_localhost_endpoint(const std::string& endpoint) {
    if (endpoint.find("localhost") != std::string::npos) {
        return true;
    }
    if (endpoint.find("127.0.0.1") != std::string::npos) {
        return true;
    }
    if (endpoint.find("::1") != std::string::npos) {
        return true;
    }
    if (endpoint.find("[::1]") != std::string::npos) {
        return true;
    }
    return false;
}

} // namespace

void DeterminismGuard::initialize(const TestModeConfig& config) {
    mode_ = config.determinism_violation;
    network_mode_ = config.allow_network;
}

void DeterminismGuard::begin_frame() {
    ++current_frame_;
}

void DeterminismGuard::end_frame() {
}

void DeterminismGuard::reset() {
    std::lock_guard<std::mutex> lock(mutex_);
    violations_.clear();
    current_frame_ = 0;
}

void DeterminismGuard::report_violation(DeterminismCode code,
                                        const std::string& details) {
    record_violation(code, details, std::nullopt);
}

void DeterminismGuard::report_violation_with_stack(DeterminismCode code,
                                                   const std::string& details,
                                                   const std::vector<std::string>& stack) {
    record_violation(code, details, stack);
}

void DeterminismGuard::check_time_usage(const std::string& caller) {
    report_violation(DeterminismCode::DET_TIME, "time usage: " + caller);
}

void DeterminismGuard::check_rng_usage(const std::string& caller, bool is_seeded) {
    if (!is_seeded) {
        report_violation(DeterminismCode::DET_RNG, "rng usage: " + caller);
    }
}

void DeterminismGuard::check_fs_enumeration(const std::string& path, bool is_sorted) {
    if (!is_sorted) {
        report_violation(DeterminismCode::DET_FS_ORDER, "filesystem order: " + path);
    }
}

void DeterminismGuard::check_network_access(const std::string& endpoint) {
    if (allow_network_endpoint(endpoint)) {
        return;
    }
    report_violation(DeterminismCode::DET_NET, "network access: " + endpoint);
}

std::vector<ViolationRecord> DeterminismGuard::get_violations() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return violations_;
}

bool DeterminismGuard::has_violations() const {
    std::lock_guard<std::mutex> lock(mutex_);
    return !violations_.empty();
}

void DeterminismGuard::record_violation(
    DeterminismCode code,
    const std::string& details,
    const std::optional<std::vector<std::string>>& stack) {
    ViolationRecord record;
    record.code = code;
    record.details = details;
    record.stack = stack;
    record.frame_number = current_frame_;
    record.timestamp = timestamp_now();

    {
        std::lock_guard<std::mutex> lock(mutex_);
        violations_.push_back(record);
    }

    spdlog::warn("[determinism] {}: {}", code_label(code), details);

    if (mode_ == DeterminismViolationMode::Fatal) {
        throw std::runtime_error(std::string("determinism_violation:") +
                                 code_label(code) + ":" + details);
    }
}

bool DeterminismGuard::allow_network_endpoint(const std::string& endpoint) const {
    switch (network_mode_) {
        case NetworkMode::Any:
            return true;
        case NetworkMode::Localhost:
            return is_localhost_endpoint(endpoint);
        case NetworkMode::Deny:
        default:
            return false;
    }
}

} // namespace testing
