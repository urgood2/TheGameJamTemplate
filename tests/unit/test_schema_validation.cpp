#include <gtest/gtest.h>

#include <fstream>

#include <nlohmann/json.hpp>

#include "testing/schema_validator.hpp"

TEST(SchemaValidator, ReportSampleValidates) {
    nlohmann::json schema;
    nlohmann::json sample;
    {
        std::ifstream schema_file("tests/schemas/report.schema.json");
        ASSERT_TRUE(schema_file.is_open());
        schema_file >> schema;
    }
    {
        std::ifstream sample_file("tests/schemas/report.sample.json");
        ASSERT_TRUE(sample_file.is_open());
        sample_file >> sample;
    }

    const auto result = testing::validate_json_against_schema(sample, schema);
    EXPECT_TRUE(result.ok) << result.error;
}

TEST(SchemaValidator, ExitOnInvalidReport) {
    nlohmann::json invalid_report = {
        {"run", nlohmann::json::object()},
        {"tests", nlohmann::json::array()},
        {"summary", nlohmann::json::object()}
    };

    EXPECT_EXIT(
        testing::validate_or_exit("tests/schemas/report.schema.json", invalid_report, "report.json"),
        ::testing::ExitedWithCode(2),
        ".*"
    );
}
