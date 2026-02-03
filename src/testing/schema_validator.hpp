#pragma once

#include <filesystem>
#include <string>

#include <nlohmann/json.hpp>

namespace testing {

struct SchemaValidationResult {
    bool ok = false;
    std::string error;
};

SchemaValidationResult validate_json_against_schema(const nlohmann::json& instance,
                                                   const nlohmann::json& schema);
SchemaValidationResult validate_json_with_schema_file(const nlohmann::json& instance,
                                                     const std::filesystem::path& schema_path);

bool load_json_file(const std::filesystem::path& path,
                   nlohmann::json& out,
                   std::string& err);

bool write_json_file(const std::filesystem::path& path,
                    const nlohmann::json& value,
                    std::string& err);

void validate_or_exit(const std::filesystem::path& schema_path,
                      const nlohmann::json& instance,
                      const std::string& label);

} // namespace testing
