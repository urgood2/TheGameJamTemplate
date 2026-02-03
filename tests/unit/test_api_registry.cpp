#include <gtest/gtest.h>

#include <atomic>
#include <filesystem>
#include <string>

#include <nlohmann/json.hpp>

#include "testing/schema_validator.hpp"
#include "testing/test_api_registry.hpp"

namespace {

std::filesystem::path make_temp_file(const std::string& name) {
    static std::atomic<int> counter{0};
    const auto id = counter.fetch_add(1);
    auto dir = std::filesystem::temp_directory_path() /
               ("test_api_registry_" + std::to_string(id));
    std::error_code ec;
    std::filesystem::create_directories(dir, ec);
    return dir / name;
}

testing::TestApiRegistry make_sample_registry() {
    testing::TestApiRegistry registry;
    registry.set_version("1.2.3");
    registry.register_state_path({"game.initialized", "boolean", false, "Game initialized"});
    registry.register_query({"ui.element_rect",
                             {{"name", "string", true, "element name"}},
                             "table {x,y,w,h}",
                             "Get UI element rect"});
    registry.register_command({"scene.load",
                               {{"name", "string", true, "scene name"}},
                               "Load scene"});
    registry.register_capability("screenshots", true);
    registry.register_capability("gamepad", false);
    return registry;
}

} // namespace

TEST(TestApiRegistryVersion, SetAndValidateSemver) {
    testing::TestApiRegistry registry;
    EXPECT_EQ(registry.get_version(), "0.0.0");

    registry.set_version("2.0.1");
    EXPECT_EQ(registry.get_version(), "2.0.1");

    registry.set_version("not-a-version");
    EXPECT_EQ(registry.get_version(), "2.0.1");

    registry.set_version("1.0");
    EXPECT_EQ(registry.get_version(), "2.0.1");
}

TEST(TestApiRegistryVersion, InitializeResetsState) {
    testing::TestApiRegistry registry = make_sample_registry();
    testing::TestModeConfig config;
    registry.initialize(config);

    EXPECT_EQ(registry.get_version(), "0.0.0");
    EXPECT_TRUE(registry.get_all_state_paths().empty());
    EXPECT_TRUE(registry.get_all_queries().empty());
    EXPECT_TRUE(registry.get_all_commands().empty());
    EXPECT_TRUE(registry.get_all_capabilities().empty());
}

TEST(TestApiRegistryRegistration, StatePathAndQueryLookup) {
    testing::TestApiRegistry registry;
    registry.register_state_path({"game.player.health", "number", true, "Health value"});
    registry.register_state_path({"game.player.health", "number", false, "Read-only health"});

    const auto state = registry.get_state_path("game.player.health");
    ASSERT_TRUE(state.has_value());
    EXPECT_FALSE(state->writable);
    EXPECT_EQ(state->description, "Read-only health");

    registry.register_query({"ui.element_rect",
                             {{"name", "string", true, "element name"}},
                             "table",
                             "Get rect"});
    const auto query = registry.get_query("ui.element_rect");
    ASSERT_TRUE(query.has_value());
    ASSERT_EQ(query->arguments.size(), 1u);
    EXPECT_EQ(query->arguments[0].name, "name");
    EXPECT_EQ(query->returns, "table");
}

TEST(TestApiRegistryRegistration, CommandAndCapabilityLookup) {
    testing::TestApiRegistry registry;
    registry.register_command({"scene.load",
                               {{"name", "string", true, "scene name"}},
                               "Load scene"});
    registry.register_capability("screenshots", true);

    EXPECT_TRUE(registry.validate_command("scene.load"));
    EXPECT_FALSE(registry.validate_command("scene.unload"));
    EXPECT_TRUE(registry.has_capability("screenshots"));
    EXPECT_FALSE(registry.has_capability("perf"));
}

TEST(TestApiRegistryValidation, ValidateReturnsFalseForUnknowns) {
    testing::TestApiRegistry registry;
    EXPECT_FALSE(registry.validate_state_path("missing.path"));
    EXPECT_FALSE(registry.validate_query("missing.query"));
    EXPECT_FALSE(registry.validate_command("missing.command"));
}

TEST(TestApiRegistryFingerprint, DeterministicAndSensitiveToChanges) {
    testing::TestApiRegistry registry = make_sample_registry();
    const auto first = registry.compute_fingerprint();
    const auto second = registry.compute_fingerprint();
    EXPECT_EQ(first, second);

    testing::TestApiRegistry registry_same;
    registry_same.register_capability("gamepad", false);
    registry_same.register_capability("screenshots", true);
    registry_same.register_command({"scene.load",
                                    {{"name", "string", true, "scene name"}},
                                    "Load scene"});
    registry_same.register_state_path({"game.initialized", "boolean", false, "Game initialized"});
    registry_same.register_query({"ui.element_rect",
                                  {{"name", "string", true, "element name"}},
                                  "table {x,y,w,h}",
                                  "Get UI element rect"});
    registry_same.set_version("1.2.3");
    EXPECT_EQ(first, registry_same.compute_fingerprint());

    registry_same.register_capability("perf", true);
    EXPECT_NE(first, registry_same.compute_fingerprint());
}

TEST(TestApiRegistryJson, ExportValidatesAgainstSchema) {
    auto registry = make_sample_registry();
    const auto path = make_temp_file("test_api.json");
    ASSERT_TRUE(registry.write_json(path));

    nlohmann::json instance;
    std::string err;
    ASSERT_TRUE(testing::load_json_file(path, instance, err)) << err;
    ASSERT_TRUE(instance.contains("schema_version"));
    EXPECT_EQ(instance["schema_version"], "1.0.0");

    const auto result = testing::validate_json_with_schema_file(instance,
                                                                "tests/schemas/test_api.schema.json");
    EXPECT_TRUE(result.ok) << result.error;
}
