#pragma once

#include <filesystem>
#include <optional>
#include <string>
#include <vector>

#include "testing/test_mode_config.hpp"

namespace testing {

struct BaselineMask {
    int x = 0;
    int y = 0;
    int w = 0;
    int h = 0;
};

struct BaselineMetadata {
    double threshold_percent = 0.5;
    int per_channel_tolerance = 5;
    std::vector<BaselineMask> masks;
    std::string notes;
};

class BaselineManager {
public:
    void initialize(const TestModeConfig& config);

    std::optional<std::filesystem::path> resolve_baseline(const std::string& test_id,
                                                          const std::string& name) const;
    std::optional<std::filesystem::path> resolve_metadata(const std::string& test_id,
                                                          const std::string& name) const;
    BaselineMetadata load_metadata(const std::string& test_id,
                                   const std::string& name) const;

    bool write_baseline(const std::string& test_id,
                        const std::string& name,
                        const std::filesystem::path& source);

    std::string baseline_key() const;
    std::filesystem::path get_baseline_dir(const std::string& test_id) const;

private:
    std::filesystem::path baselines_dir_;
    std::filesystem::path staging_dir_;
    std::string platform_ = "unknown";
    std::string baseline_key_ = "software_sdr_srgb";
    std::string resolution_ = "";
    BaselineWriteMode write_mode_ = BaselineWriteMode::Deny;
    std::string approve_token_;
};

} // namespace testing
