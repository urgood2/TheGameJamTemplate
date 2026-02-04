#include <gtest/gtest.h>

#include <chrono>
#include <filesystem>
#include <fstream>

#include "testing/path_sandbox.hpp"

namespace {

std::filesystem::path make_temp_root() {
    const auto now = std::chrono::steady_clock::now().time_since_epoch().count();
    auto root = std::filesystem::temp_directory_path() / ("path_sandbox_" + std::to_string(now));
    std::filesystem::create_directories(root);
    return root;
}

void write_text(const std::filesystem::path& path) {
    std::filesystem::create_directories(path.parent_path());
    std::ofstream out(path);
    out << "data";
}

} // namespace

TEST(PathSandbox, WriteWithinRootAllowed) {
    auto root = make_temp_root();
    testing::PathSandbox sandbox;
    sandbox.set_root(root);

    EXPECT_TRUE(sandbox.is_writable("artifact.txt"));
    auto resolved = sandbox.resolve_write_path("artifact.txt");
    EXPECT_TRUE(resolved.has_value());
}

TEST(PathSandbox, WriteOutsideRootBlocked) {
    auto root = make_temp_root();
    testing::PathSandbox sandbox;
    sandbox.set_root(root);

    auto outside = root.parent_path() / "outside.txt";
    EXPECT_FALSE(sandbox.is_writable(outside));
}

TEST(PathSandbox, ReadWithinRootAllowed) {
    auto root = make_temp_root();
    auto file = root / "readme.txt";
    write_text(file);

    testing::PathSandbox sandbox;
    sandbox.add_read_root(root);

    EXPECT_TRUE(sandbox.is_readable(file));
    auto resolved = sandbox.resolve_read_path(file);
    EXPECT_TRUE(resolved.has_value());
}

TEST(PathSandbox, ReadOutsideRootBlocked) {
    auto root = make_temp_root();
    auto file = std::filesystem::temp_directory_path() / "outside_read.txt";
    write_text(file);

    testing::PathSandbox sandbox;
    sandbox.add_read_root(root);

    EXPECT_FALSE(sandbox.is_readable(file));
}

TEST(PathSandbox, TraversalBlocked) {
    auto root = make_temp_root();
    testing::PathSandbox sandbox;
    sandbox.set_root(root);

    EXPECT_FALSE(sandbox.is_writable("../escape.txt"));
}
