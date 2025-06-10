#include "localization.hpp"

#include "core/globals.hpp"
#include "util/utilities.hpp"

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

    void loadFontData(const std::string &jsonPath)
    {
        std::ifstream f(jsonPath);
        if (!f.is_open())
        {
            SPDLOG_ERROR("Could not open fonts.json at '{}'", jsonPath);
            return;
        }

        json j;
        try
        {
            f >> j;
        }
        catch (const std::exception &e)
        {
            SPDLOG_ERROR("Failed to parse {}: {}", jsonPath, e.what());
            return;
        }

        for (auto &[langCode, fontJ] : j.items())
        {
            globals::FontData fd;
            fd.fontLoadedSize = fontJ.value("loadedSize", 32.f);
            fd.fontScale = fontJ.value("scale", 1.f);
            fd.spacing = fontJ.value("spacing", 1.f);
            auto off = fontJ.value("offset", std::vector<float>{0, 0});
            fd.fontRenderOffset = {off[0], off[1]};

            std::string file = fontJ.value("file", std::string{});
            file = util::getRawAssetPathNoUUID(file);
            if (!file.empty())
            {
                fd.font = LoadFont(file.c_str());
                if (fd.font.texture.id == 0)
                {
                    SPDLOG_ERROR("Failed to load font '{}' for '{}'", file, langCode);
                }
            }
            // print debug content
            SPDLOG_DEBUG("Loaded font for language '{}': loadedSize={}, scale={}, spacing={}, offset=({}, {})",
                langCode, fd.fontLoadedSize, fd.fontScale, fd.spacing, fd.fontRenderOffset.x, fd.fontRenderOffset.y);
            languageFontData[langCode] = fd;
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

}