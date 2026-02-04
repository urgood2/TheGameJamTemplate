#include <gtest/gtest.h>

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <string>

#include "testing/baseline_manager.hpp"
#include "testing/test_mode_config.hpp"

namespace {

class CwdGuard {
public:
    explicit CwdGuard(const std::filesystem::path& path)
        : previous_(std::filesystem::current_path()) {
        std::filesystem::current_path(path);
    }

    ~CwdGuard() {
        std::filesystem::current_path(previous_);
    }

private:
    std::filesystem::path previous_;
};

std::filesystem::path make_temp_root() {
    auto root = std::filesystem::temp_directory_path() / "baseline_manager_tests";
    std::filesystem::create_directories(root);
    return root;
}

std::filesystem::path write_file(const std::filesystem::path& path, const std::string& content) {
    std::filesystem::create_directories(path.parent_path());
    std::ofstream out(path);
    out << content;
    return path;
}

} // namespace

TEST(BaselineManager, ResolveBaselinePaths) {
    auto root = make_temp_root();
    CwdGuard guard(root);

    testing::TestModeConfig config;
    config.resolution_width = 800;
    config.resolution_height = 600;
    config.baseline_key = "software_sdr_srgb";
    config.baseline_staging_dir = root / "tests" / "baselines_staging";

    testing::BaselineManager manager;
    manager.initialize(config);

    auto missing = manager.resolve_baseline("menu.main_loads", "title_screen");
    EXPECT_FALSE(missing.has_value());

    auto baseline_dir = root / "tests" / "baselines" / "linux" /
        "software_sdr_srgb" / "800x600" / "menu.main_loads";
    auto baseline_path = write_file(baseline_dir / "title_screen.png", "data");

    auto resolved = manager.resolve_baseline("menu.main_loads", "title_screen");
    ASSERT_TRUE(resolved.has_value());
    EXPECT_EQ(resolved->filename().string(), "title_screen.png");
}

TEST(BaselineManager, LoadMetadata) {
    auto root = make_temp_root();
    CwdGuard guard(root);

    testing::TestModeConfig config;
    config.resolution_width = 800;
    config.resolution_height = 600;
    config.baseline_key = "software_sdr_srgb";
    config.baseline_staging_dir = root / "tests" / "baselines_staging";

    testing::BaselineManager manager;
    manager.initialize(config);

    auto meta_dir = root / "tests" / "baselines" / "linux" /
        "software_sdr_srgb" / "800x600" / "menu.main_loads";
    write_file(meta_dir / "title_screen.png.meta.json",
               "{\"threshold_percent\": 0.75, \"per_channel_tolerance\": 12,"
               "\"masks\": [{\"x\":1,\"y\":2,\"w\":3,\"h\":4}],"
               "\"notes\":\"mask\"}");

    auto metadata = manager.load_metadata("menu.main_loads", "title_screen");
    EXPECT_NEAR(metadata.threshold_percent, 0.75, 0.001);
    EXPECT_EQ(metadata.per_channel_tolerance, 12);
    ASSERT_EQ(metadata.masks.size(), 1u);
    EXPECT_EQ(metadata.masks[0].x, 1);
    EXPECT_EQ(metadata.masks[0].y, 2);
    EXPECT_EQ(metadata.masks[0].w, 3);
    EXPECT_EQ(metadata.masks[0].h, 4);
    EXPECT_EQ(metadata.notes, "mask");
}

TEST(BaselineManager, WriteBaselineStageAndDeny) {
    auto root = make_temp_root();
    CwdGuard guard(root);

    auto source = write_file(root / "source.png", "data");

    testing::TestModeConfig config;
    config.resolution_width = 800;
    config.resolution_height = 600;
    config.baseline_key = "software_sdr_srgb";
    config.baseline_write_mode = testing::BaselineWriteMode::Stage;
    config.baseline_staging_dir = root / "tests" / "baselines_staging";

    testing::BaselineManager manager;
    manager.initialize(config);
    EXPECT_TRUE(manager.write_baseline("menu.main_loads", "title_screen", source));

    auto staged = root / "tests" / "baselines_staging" / "linux" /
        "software_sdr_srgb" / "800x600" / "menu.main_loads" / "title_screen.png";
    EXPECT_TRUE(std::filesystem::exists(staged));

    config.baseline_write_mode = testing::BaselineWriteMode::Deny;
    manager.initialize(config);
    EXPECT_FALSE(manager.write_baseline("menu.main_loads", "title_screen", source));
}

TEST(BaselineManager, ApplyModeRequiresToken) {
    auto root = make_temp_root();
    CwdGuard guard(root);

    auto source = write_file(root / "source.png", "data");

    testing::TestModeConfig config;
    config.resolution_width = 800;
    config.resolution_height = 600;
    config.baseline_key = "software_sdr_srgb";
    config.baseline_write_mode = testing::BaselineWriteMode::Apply;
    config.baseline_approve_token = "secret";
    config.baseline_staging_dir = root / "tests" / "baselines_staging";

    testing::BaselineManager manager;
    manager.initialize(config);
    EXPECT_FALSE(manager.write_baseline("menu.main_loads", "title_screen", source));

    setenv("E2E_BASELINE_APPROVE", "secret", 1);
    manager.initialize(config);
    EXPECT_TRUE(manager.write_baseline("menu.main_loads", "title_screen", source));

    auto applied = root / "tests" / "baselines" / "linux" /
        "software_sdr_srgb" / "800x600" / "menu.main_loads" / "title_screen.png";
    EXPECT_TRUE(std::filesystem::exists(applied));
}

