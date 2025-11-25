#include <gtest/gtest.h>

#include "core/engine_context.hpp"
#include "systems/localization/localization.hpp"

struct LocalizationTest : ::testing::Test {
    void SetUp() override {
        savedLang = localization::currentLang;
        savedFallback = localization::fallbackLang;
        savedData = localization::languageData;
        savedFlat = localization::flatLanguageData;
        savedCallbacks = localization::langChangedCallbacks;
        localization::langChangedCallbacks.clear();
    }
    void TearDown() override {
        localization::currentLang = savedLang;
        localization::fallbackLang = savedFallback;
        localization::languageData = savedData;
        localization::flatLanguageData = savedFlat;
        localization::langChangedCallbacks = savedCallbacks;
    }

    std::string savedLang;
    std::string savedFallback;
    std::unordered_map<std::string, nlohmann::json> savedData;
    std::unordered_map<std::string, localization::FlatMap> savedFlat;
    std::vector<localization::LangChangedCb> savedCallbacks;
};

TEST_F(LocalizationTest, ExposeToLuaBindsLocalizationTable) {
    localization::languageData.clear();
    localization::flatLanguageData.clear();
    localization::currentLang = "en";
    localization::fallbackLang = "en";
    localization::flatLanguageData["en"]["ui.ok"] = "OK";

    sol::state lua;
    lua.open_libraries(sol::lib::base);

    EngineContext ctx{EngineConfig{std::string{"config.json"}}};
    localization::exposeToLua(lua, &ctx);

    auto localizationTable = lua["localization"];
    ASSERT_TRUE(localizationTable.valid());

    const auto result = localizationTable["getRaw"]("ui.ok");
    ASSERT_TRUE(result.valid());
    EXPECT_EQ(result.get<std::string>(), "OK");
}

TEST_F(LocalizationTest, SetCurrentLanguageNotifiesCallbacks) {
    localization::languageData.clear();
    localization::flatLanguageData.clear();

    localization::languageData["en"] = nlohmann::json::object();
    localization::languageData["es"] = nlohmann::json::object();
    localization::flatLanguageData["en"]["menu.start"] = "Start";
    localization::flatLanguageData["es"]["menu.start"] = "Comenzar";
    localization::fallbackLang = "en";
    localization::currentLang = "en";

    int called = 0;
    std::string last;
    localization::onLanguageChanged([&](const std::string& lang) {
        ++called;
        last = lang;
    });

    const bool ok = localization::setCurrentLanguage("es");

    EXPECT_TRUE(ok);
    EXPECT_EQ(called, 1);
    EXPECT_EQ(last, "es");
    EXPECT_EQ(localization::currentLang, "es");
}

TEST_F(LocalizationTest, GetRawFallsBackToFallbackLanguage) {
    localization::languageData.clear();
    localization::flatLanguageData.clear();

    localization::currentLang = "es";
    localization::fallbackLang = "en";
    localization::flatLanguageData["en"]["menu.quit"] = "Quit";
    localization::flatLanguageData["es"] = {};

    const std::string value = localization::getRaw("menu.quit");
    EXPECT_EQ(value, "Quit");
}
