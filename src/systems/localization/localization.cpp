#include "localization.hpp"

#include "core/globals.hpp"
#include "util/utilities.hpp"

#include "systems/scripting/binding_recorder.hpp"

#include <fmt/args.h>

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
      

        auto& rec = BindingRecorder::instance();
        const std::vector<std::string> path = {"localization"};

        // 1) Bind the functions and record their metadata simultaneously.
        // The get_or_create_table logic is now handled inside bind_function.

        rec.add_type("localization").doc = "namespace for localization functions";

        // loadLanguage
        rec.bind_function(lua, path, "loadLanguage", &localization::loadLanguage,
            "---@param languageCode string # The language to load (e.g., 'en_US').\n"
            "---@param path string # The filepath to the language JSON file.\n"
            "---@return nil",
            "Loads a language file for the given language code from a specific path."
        );

        // setFallbackLanguage
        rec.bind_function(lua, path, "setFallbackLanguage", &localization::setFallbackLanguage,
            "---@param languageCode string # The language code to use as a fallback (e.g., 'en_US').\n"
            "---@return nil",
            "Sets a fallback language if a key isn't found in the current one."
        );
        
        // getCurrentLanguage
        rec.bind_function(lua, path, "getCurrentLanguage",
            // Lua signature: getCurrentLanguage() -> string
            []() -> std::string {
                return localization::getCurrentLanguage();
            },
            // Lua-facing documentation
            "---@return string # The currently active language code.\n"
            "Gets the currently active language code. This is useful for checking which language is currently set.",
            "Returns the currently active language code."
        );

        // get
        rec.bind_function(lua, path, "get",
            // Lua signature: get(key : string, args? : table<string,any>) -> string
            [](const std::string &key, sol::object maybeArgs)->std::string {
                // 1) Fetch the raw template
                std::string raw = localization::getRaw(key);
        
                // 2) No args?  Just return the raw string
                if (!maybeArgs.is<sol::table>()) {
                    return raw;
                }
        
                // 3) Otherwise build a dynamic fmt store
                auto args = maybeArgs.as<sol::table>();
                fmt::dynamic_format_arg_store<fmt::format_context> store;
        
                // 4) Iterate over name→value in the Lua table
                for (auto &kv : args) {
                    // key must be string
                    std::string name = kv.first.as<std::string>();
                    sol::object val  = kv.second;
        
                    if (val.is<std::string>()) {
                        store.push_back(fmt::arg(name.c_str(), val.as<std::string>()));
                    }
                    else if (val.is<int>()) {
                        store.push_back(fmt::arg(name.c_str(), val.as<int>()));
                    }
                    else if (val.is<double>()) {
                        store.push_back(fmt::arg(name.c_str(), val.as<double>()));
                    }
                    else if (val.is<bool>()) {
                        store.push_back(fmt::arg(name.c_str(), val.as<bool>()));
                    }
                    else if (val.is<float>()) {
                        store.push_back(fmt::arg(name.c_str(), val.as<float>()));
                    }
                    // …add more type branches as needed…
                }
        
                // 5) Format and return
                try {
                    return fmt::vformat(raw, store);
                }
                catch (const fmt::format_error &e) {
                    return "[FORMAT ERROR: " + std::string(e.what()) + "]";
                }
            },
            // Lua-facing documentation
            "---@param key string                 # Localization key\n"
            "---@param args table<string,any>?    # Optional named formatting args\n"
            "---@return string                    # Localized & formatted text\n",
            "Retrieves a localized string by key, formatting it with an optional Lua table of named parameters."
        );
        

        // getRaw
        rec.bind_function(lua, path, "getRaw", &localization::getRaw,
            "---@param key string # The localization key.\n"
            "---@return string # The raw, untransformed string or a '[MISSING: key]' message.",
            "Gets the raw string from the language file, using fallbacks if necessary."
        );

        // getFontData
        rec.bind_function(lua, path, "getFontData", &localization::getFontData,
            "---@return FontData # A handle to the font data for the current language.",
            "Retrieves font data associated with the current language."
        );

        // loadFontData
        rec.bind_function(lua, path, "loadFontData", &localization::loadFontData,
            "---@param path string # The file path to the font data JSON.\n"
            "---@return nil",
            "Loads font data from the specified path."
        );

        // onLanguageChanged
        rec.bind_function(lua, path, "onLanguageChanged", &localization::onLanguageChanged,
            "---@param callback fun(newLanguageCode: string) # A function to call when the language changes.\n"
            "---@return nil",
            "Registers a callback that executes after the current language changes."
        );

        // setCurrentLanguage
        rec.bind_function(lua, path, "setCurrentLanguage", &localization::setCurrentLanguage,
            "---@param languageCode string # The language code to make active.\n"
            "---@return boolean # True if the language was set successfully, false otherwise.",
            "Sets the current language and notifies all listeners."
        );

    }

}