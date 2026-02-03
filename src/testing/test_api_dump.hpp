#pragma once
// TODO: Implement test_api_dump

#include <filesystem>

namespace testing {

class TestApiRegistry;

bool write_test_api_json(const TestApiRegistry& registry,
                        const std::filesystem::path& output_path);

} // namespace testing
