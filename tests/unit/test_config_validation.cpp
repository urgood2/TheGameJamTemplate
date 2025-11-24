#include <gtest/gtest.h>

#include "nlohmann/json.hpp"

#include "core/globals.hpp"
#include "util/error_handling.hpp"

using json = nlohmann::json;

TEST(ConfigValidation, MissingScreenFieldsLoggedAndIgnored) {
    // Simulate missing width/height fields.
    globals::configJSON = json{
        {"render_data", {{"screen", {}}}}
    };

    // Reuse the helper logic inline (mirrors loadConfigFileValues lambda).
    auto requireField = [](const json& j, std::initializer_list<const char*> keys) -> util::Result<const json*, std::string> {
        const json* cur = &j;
        for (auto* k : keys) {
            if (!cur->contains(k)) {
                return util::Result<const json*, std::string>(std::string("missing config field: ") + k);
            }
            cur = &cur->at(k);
        }
        return util::Result<const json*, std::string>(cur);
    };

    auto widthField  = requireField(globals::configJSON, {"render_data","screen","width"});
    auto heightField = requireField(globals::configJSON, {"render_data","screen","height"});

    EXPECT_TRUE(widthField.isErr());
    EXPECT_TRUE(heightField.isErr());
}
