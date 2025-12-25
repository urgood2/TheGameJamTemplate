#include <gtest/gtest.h>

#include <filesystem>
#include <fstream>
#include <thread>
#include <chrono>

#include "systems/save/save_file_io.hpp"

namespace fs = std::filesystem;

class SaveFileIOTest : public ::testing::Test {
protected:
    void SetUp() override {
        temp_dir = fs::temp_directory_path() / "save_file_io_test";
        fs::create_directories(temp_dir);
    }

    void TearDown() override {
        std::error_code ec;
        fs::remove_all(temp_dir, ec);
    }

    fs::path temp_dir;
};

TEST_F(SaveFileIOTest, LoadFileReturnsNulloptForMissingFile) {
    auto result = save_io::load_file((temp_dir / "nonexistent.json").string());
    EXPECT_FALSE(result.has_value());
}

TEST_F(SaveFileIOTest, LoadFileReturnsContentForExistingFile) {
    auto path = temp_dir / "test.json";
    {
        std::ofstream f(path);
        f << R"({"version": 1})";
    }

    auto result = save_io::load_file(path.string());
    ASSERT_TRUE(result.has_value());
    EXPECT_EQ(*result, R"({"version": 1})");
}

TEST_F(SaveFileIOTest, FileExistsReturnsFalseForMissing) {
    EXPECT_FALSE(save_io::file_exists((temp_dir / "nope.json").string()));
}

TEST_F(SaveFileIOTest, FileExistsReturnsTrueForExisting) {
    auto path = temp_dir / "exists.json";
    { std::ofstream f(path); f << "{}"; }
    EXPECT_TRUE(save_io::file_exists(path.string()));
}

TEST_F(SaveFileIOTest, DeleteFileRemovesFile) {
    auto path = temp_dir / "to_delete.json";
    { std::ofstream f(path); f << "{}"; }

    EXPECT_TRUE(fs::exists(path));
    EXPECT_TRUE(save_io::delete_file(path.string()));
    EXPECT_FALSE(fs::exists(path));
}

TEST_F(SaveFileIOTest, DeleteFileSucceedsForMissingFile) {
    EXPECT_TRUE(save_io::delete_file((temp_dir / "already_gone.json").string()));
}
