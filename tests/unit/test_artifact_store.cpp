#include <gtest/gtest.h>

#include <filesystem>
#include <fstream>

#include "testing/artifact_store.hpp"
#include "testing/path_sandbox.hpp"
#include "testing/test_mode_config.hpp"

namespace fs = std::filesystem;

namespace {

struct ArtifactStoreFixture {
    fs::path base;
    testing::TestModeConfig config;
    testing::PathSandbox sandbox;
    testing::ArtifactStore store;

    explicit ArtifactStoreFixture(const fs::path& base_path) : base(base_path) {
        std::error_code ec;
        fs::remove_all(base, ec);
        fs::create_directories(base, ec);

        config.run_root = base;
        config.artifacts_dir = base / "artifacts";
        config.forensics_dir = base / "forensics";
        config.baseline_staging_dir = base / "baselines_staging";

        sandbox.initialize(config);
        store.initialize(config, sandbox);
    }
};

std::string read_file_text(const fs::path& path) {
    std::ifstream in(path);
    std::string contents((std::istreambuf_iterator<char>(in)),
                         std::istreambuf_iterator<char>());
    return contents;
}

} // namespace

TEST(ArtifactStore, WriteTextCreatesFile) {
    ArtifactStoreFixture fixture(fs::current_path() / "tests" / "out" / "artifact_store_write");

    EXPECT_TRUE(fixture.store.write_text("test.txt", "hello"));

    const fs::path output_path = fixture.config.artifacts_dir / "test.txt";
    EXPECT_TRUE(fs::exists(output_path));
    EXPECT_EQ(read_file_text(output_path), "hello");
}

TEST(ArtifactStore, RejectsAbsolutePath) {
    ArtifactStoreFixture fixture(fs::current_path() / "tests" / "out" / "artifact_store_abs");

    const fs::path abs_path = fixture.config.artifacts_dir / "abs.txt";
    EXPECT_FALSE(fixture.store.write_text(abs_path, "data"));
    EXPECT_FALSE(fs::exists(abs_path));
}

TEST(ArtifactStore, RejectsPathOutsideArtifactsRoot) {
    ArtifactStoreFixture fixture(fs::current_path() / "tests" / "out" / "artifact_store_escape");

    EXPECT_FALSE(fixture.store.write_text("../escape.txt", "data"));
    const fs::path escaped = fixture.base / "escape.txt";
    EXPECT_FALSE(fs::exists(escaped));
}

TEST(ArtifactStore, CopyFileHonorsReadRoots) {
    ArtifactStoreFixture fixture(fs::current_path() / "tests" / "out" / "artifact_store_copy");

    const fs::path read_root = fixture.base / "read_root";
    fs::create_directories(read_root);
    const fs::path source = read_root / "source.txt";
    std::ofstream(source) << "payload";

    fixture.sandbox.add_read_root(read_root);

    EXPECT_TRUE(fixture.store.copy_file(source, "copied.txt"));
    const fs::path copied = fixture.config.artifacts_dir / "copied.txt";
    EXPECT_TRUE(fs::exists(copied));
    EXPECT_EQ(read_file_text(copied), "payload");
}

TEST(ArtifactStore, CopyFileRejectsUntrustedSource) {
    ArtifactStoreFixture fixture(fs::current_path() / "tests" / "out" / "artifact_store_untrusted");

    const fs::path source = fixture.base / "untrusted.txt";
    std::ofstream(source) << "payload";

    EXPECT_FALSE(fixture.store.copy_file(source, "bad.txt"));
    const fs::path copied = fixture.config.artifacts_dir / "bad.txt";
    EXPECT_FALSE(fs::exists(copied));
}
