#include "localization.hpp"

#include "core/globals.hpp"
#include "util/utilities.hpp"

#include "systems/scripting/binding_recorder.hpp"

namespace localization
{
    // ==========================
    // Localization System internals
    // ==========================
    std::string currentLang{};
    std::string fallbackLang = "en";
    std::unordered_map<std::string, nlohmann::json> languageData{};
    std::unordered_map<std::string, FlatMap> flatLanguageData{};
    std::vector<LangChangedCb> langChangedCallbacks{};
    std::unordered_map<std::string, globals::FontData> languageFontData{};

    std::string resolveKey(const json &data, const std::string &key)
    {
        std::istringstream stream(key);
        std::string segment;
        const json *current = &data;

        while (std::getline(stream, segment, '.'))
        {
            if (current->contains(segment))
            {
                current = &(*current)[segment];
            }
            else
            {
                return "";
            }
        }

        if (current->is_string())
        {
            return current->get<std::string>();
        }

        return "";
    }

    void loadFontData(const std::string &jsonPath) {
        std::ifstream f(jsonPath);
        json j; f >> j;

        for (auto& [lang, fontJ] : j.items()) {
            globals::FontData fd;
            // … copy loadedSize, scale, spacing, offset exactly as before …

            // 1) Gather ranges from JSON (or fall back to ASCII)
            std::vector<std::pair<int,int>> ranges;
            if (auto it = fontJ.find("ranges"); it != fontJ.end()) {
                for (auto& pair : *it) {
                    int lo = pair[0].get<int>();
                    int hi = pair[1].get<int>();
                    ranges.emplace_back(lo, hi);
                }
            } else {
                ranges.emplace_back(0x0020, 0x007E);
            }

            // 2) Flatten into a single codepoint list
            auto& cps = fd.codepoints;
            for (auto [lo,hi] : ranges) {
                for (int cp = lo; cp <= hi; ++cp) {
                    cps.push_back(cp);
                }
            }

            // 3) Load with LoadFontEx
            std::string file = util::getRawAssetPathNoUUID(fontJ["file"].get<std::string>());
            if (!file.empty()) {
                fd.font = LoadFontEx(
                    file.c_str(),
                    static_cast<int>(fd.fontLoadedSize),
                    cps.data(),
                    static_cast<int>(cps.size())
                );
                if (fd.font.texture.id == 0) {
                    SPDLOG_ERROR("Failed to LoadFontEx '{}' for '{}'", file, lang);
                }
            }

            languageFontData[lang] = std::move(fd);
        }
    }

    const globals::FontData& getFontData() {
        if (auto it = languageFontData.find(currentLang); it != languageFontData.end())
            return it->second;
        if (auto it2 = languageFontData.find(fallbackLang); it2 != languageFontData.end())
            return it2->second;
        return globals::FontData{};
    }

    // ==========================
    // Localization System API
    // ==========================
    void loadLanguage(const std::string &langCode, const std::string &path)
    {
        std::ifstream file(path + langCode + ".json");
        if (!file.is_open())
        {
            std::cerr << "Failed to load language file: " << path + langCode + ".json\n";
            return;
        }

        try
        {
            languageData[langCode] = json::parse(file);
            currentLang = langCode;
        }
        catch (const std::exception &e)
        {
            std::cerr << "JSON parse error in " << langCode << ": " << e.what() << '\n';
        }

        // after parsing languageData[langCode]:
        std::unordered_map<std::string, std::string> flat;
        std::function<void(const json &, const std::string &)> walk = [&](auto &node, auto prefix)
        {
            for (auto &item : node.items())
            {
                auto full = prefix.empty() ? item.key() : prefix + "." + item.key();
                if (item.value().is_string())
                    flat[full] = item.value().template get<std::string>();
                else
                    walk(item.value(), full);
            }
        };
        walk(languageData[langCode], "");
        flatLanguageData[langCode] = std::move(flat);
    }

    void setFallbackLanguage(const std::string &langCode)
    {
        fallbackLang = langCode;
    }

    std::string get(const std::string &key)
    {
        auto it = languageData.find(currentLang);
        if (it != languageData.end())
        {
            std::string result = resolveKey(it->second, key);
            if (!result.empty())
                return result;
        }

        if (fallbackLang != currentLang)
        {
            auto fallbackIt = languageData.find(fallbackLang);
            if (fallbackIt != languageData.end())
            {
                std::string result = resolveKey(fallbackIt->second, key);
                if (!result.empty())
                    return result;
            }
        }

        return "[MISSING: " + key + "]";
    }

    void exposeToLua(sol::state &lua) {
        // 1) Make the top-level table
        sol::table loc = lua.create_table();
        lua["localization"] = loc;

        // 2) Core API
        loc.set_function("loadLanguage",        &localization::loadLanguage);
        loc.set_function("setFallbackLanguage", &localization::setFallbackLanguage);

        // Bind only the non-templated get(key) overload
        loc.set_function("get", 
            static_cast<std::string(*)(const std::string&)>(&localization::get)
        );
        loc.set_function("getRaw", &localization::getRaw);

        // 3) Font data
        loc.set_function("getFontData", &localization::getFontData);
        loc.set_function("loadFontData", &localization::loadFontData);

        // 4) Language change notifications
        loc.set_function("onLanguageChanged", &localization::onLanguageChanged);
        loc.set_function("setCurrentLanguage", &localization::setCurrentLanguage);
    }

}