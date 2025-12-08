#include "localization.hpp"

#include "core/globals.hpp"
#include "util/utilities.hpp"

#include "systems/scripting/binding_recorder.hpp"

#include <fmt/args.h>

namespace localization {
// ==========================
// Localization System internals
// ==========================
std::string currentLang{};
std::string fallbackLang = "en";
std::unordered_map<std::string, nlohmann::json> languageData{};
std::unordered_map<std::string, FlatMap> flatLanguageData{};
std::vector<LangChangedCb> langChangedCallbacks{};
std::unordered_map<std::string, globals::FontData> languageFontData{};
std::unordered_map<std::string, globals::FontData> namedFonts{};

std::string resolveKey(const json &data, const std::string &key) {
  std::istringstream stream(key);
  std::string segment;
  const json *current = &data;

  while (std::getline(stream, segment, '.')) {
    if (current->contains(segment)) {
      current = &(*current)[segment];
    } else {
      return "";
    }
  }

  if (current->is_string()) {
    return current->get<std::string>();
  }

  return "";
}

void loadFontData(const std::string &jsonPath) {
  std::ifstream f(jsonPath);
  if (!f.is_open()) {
    SPDLOG_ERROR("Failed to open font JSON file: {}", jsonPath);
    return;
  }

  json j;
  try {
    f >> j;
  } catch (const std::exception &e) {
    SPDLOG_ERROR("Failed to parse font JSON '{}': {}", jsonPath, e.what());
    return;
  }

  for (auto &[lang, fontJ] : j.items()) {
    globals::FontData fd;

    // --- Copy JSON parameters (with defaults) ---
    fd.fontLoadedSize = fontJ.value("loadedSize", 32.0f);
    fd.fontScale = fontJ.value("scale", 1.0f);
    fd.spacing = fontJ.value("spacing", 1.0f);

    if (auto it = fontJ.find("offset");
        it != fontJ.end() && it->is_array() && it->size() == 2) {
      fd.fontRenderOffset = {(*it)[0].get<float>(), (*it)[1].get<float>()};
    }

    // --- Gather ranges (or fallback to ASCII) ---
    std::vector<std::pair<int, int>> ranges;
    if (auto it = fontJ.find("ranges"); it != fontJ.end() && it->is_array()) {
      for (auto &pair : *it) {
        if (pair.is_array() && pair.size() == 2)
          ranges.emplace_back(pair[0].get<int>(), pair[1].get<int>());
      }
    } else {
      ranges.emplace_back(0x0020, 0x007E); // ASCII default
    }

    // --- Flatten into codepoint list ---
    auto &cps = fd.codepoints;
    for (auto [lo, hi] : ranges) {
      for (int cp = lo; cp <= hi; ++cp)
        cps.push_back(cp);
    }

    // --- Load font ---
    std::string file =
        util::getRawAssetPathNoUUID(fontJ["file"].get<std::string>());
    if (!file.empty()) {
      fd.font = LoadFontEx(file.c_str(), static_cast<int>(fd.fontLoadedSize),
                           cps.data(), static_cast<int>(cps.size()));

      if (fd.font.texture.id == 0) {
        SPDLOG_ERROR("Failed to LoadFontEx '{}' for '{}'", file, lang);
      } else {
        SPDLOG_INFO("Loaded font '{}' ({} glyphs) for '{}'", file, cps.size(),
                    lang);
      }
    } else {
      SPDLOG_ERROR("Missing font file path for '{}'", lang);
    }

    languageFontData[lang] = std::move(fd);
  }
}

const globals::FontData &getFontData() {
  static const globals::FontData empty{};
  if (auto it = languageFontData.find(currentLang);
      it != languageFontData.end())
    return it->second;
  if (auto it2 = languageFontData.find(fallbackLang);
      it2 != languageFontData.end())
    return it2->second;
  return empty;
}

// ==========================
// Named Font Registry
// ==========================
void loadNamedFont(const std::string &name, const std::string &path,
                   float size) {
  globals::FontData fd;
  fd.fontLoadedSize = size;
  fd.fontScale = 1.0f;
  fd.spacing = 1.0f;
  fd.fontRenderOffset = {0, 0};

  // Default ASCII codepoints
  for (int cp = 0x0020; cp <= 0x007E; ++cp) {
    fd.codepoints.push_back(cp);
  }

  std::string filePath = util::getRawAssetPathNoUUID(path);
  if (!filePath.empty()) {
    fd.font = LoadFontEx(filePath.c_str(), static_cast<int>(fd.fontLoadedSize),
                         fd.codepoints.data(),
                         static_cast<int>(fd.codepoints.size()));

    if (fd.font.texture.id == 0) {
      SPDLOG_ERROR("Failed to load named font '{}' from '{}'", name, filePath);
    } else {
      SPDLOG_INFO("Loaded named font '{}' from '{}' ({} glyphs, size {})", name,
                  filePath, fd.codepoints.size(), size);
      namedFonts[name] = std::move(fd);
    }
  } else {
    SPDLOG_ERROR("Named font path is empty for '{}'", name);
  }
}

const globals::FontData &getNamedFont(const std::string &name) {
  if (auto it = namedFonts.find(name); it != namedFonts.end()) {
    return it->second;
  }
  // Fall back to current language font
  return getFontData();
}

bool hasNamedFont(const std::string &name) {
  return namedFonts.find(name) != namedFonts.end();
}

// ==========================
// Localization System API
// ==========================
void loadLanguage(const std::string &langCode, const std::string &path) {
  std::ifstream file(path + langCode + ".json");
  if (!file.is_open()) {
    std::cerr << "Failed to load language file: "
              << path + langCode + ".json\n";
    return;
  }

  try {
    languageData[langCode] = json::parse(file);
    currentLang = langCode;
  } catch (const std::exception &e) {
    std::cerr << "JSON parse error in " << langCode << ": " << e.what() << '\n';
  }

  // after parsing languageData[langCode]:
  std::unordered_map<std::string, std::string> flat;
  std::function<void(const json &, const std::string &)> walk =
      [&](auto &node, auto prefix) {
        for (auto &item : node.items()) {
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

void setFallbackLanguage(const std::string &langCode) {
  fallbackLang = langCode;
}

std::string get(const std::string &key) {
  auto it = languageData.find(currentLang);
  if (it != languageData.end()) {
    std::string result = resolveKey(it->second, key);
    if (!result.empty())
      return result;
  }

  if (fallbackLang != currentLang) {
    auto fallbackIt = languageData.find(fallbackLang);
    if (fallbackIt != languageData.end()) {
      std::string result = resolveKey(fallbackIt->second, key);
      if (!result.empty())
        return result;
    }
  }

  return "[MISSING: " + key + "]";
}

void exposeToLua(sol::state &lua, EngineContext *ctx) {

  auto &rec = BindingRecorder::instance();
  const std::vector<std::string> path = {"localization"};

  // 1) Bind the functions and record their metadata simultaneously.
  // The get_or_create_table logic is now handled inside bind_function.

  struct FontData {
    Font font{};
    float fontLoadedSize = 32.f; // the size of the font when loaded
    float fontScale = 1.0f;      // the scale of the font when rendered
    float spacing = 1.0f;        // the horizontal spacing for the font
    Vector2 fontRenderOffset = {
        2,
        0}; // the offset of the font when rendered, applied to ensure text is
            // centered correctly in ui, it is multiplied by scale when applied
    // <— store your codepoint list if you ever need it later
    std::vector<int> codepoints;
  };
  // bind fontdata type.
  lua.new_usertype<Font>("Font", "baseSize", &Font::baseSize, "texture",
                         &Font::texture, "recs", &Font::recs);

  lua.new_usertype<FontData>(
      "FontData", "font", &FontData::font, "fontLoadedSize",
      &FontData::fontLoadedSize, "fontScale", &FontData::fontScale, "spacing",
      &FontData::spacing, "fontRenderOffset", &FontData::fontRenderOffset,
      "codepoints", &FontData::codepoints);
  rec.add_type("FontData").doc =
      "Structure containing font data for localization.";

  rec.add_type("localization").doc = "namespace for localization functions";

  // loadLanguage
  rec.bind_function(
      lua, path, "loadLanguage", &localization::loadLanguage,
      "---@param languageCode string # The language to load (e.g., 'en_US').\n"
      "---@param path string # The filepath to the language JSON file.\n"
      "---@return nil",
      "Loads a language file for the given language code from a specific "
      "path.");

  // setFallbackLanguage
  rec.bind_function(
      lua, path, "setFallbackLanguage", &localization::setFallbackLanguage,
      "---@param languageCode string # The language code to use as a fallback "
      "(e.g., 'en_US').\n"
      "---@return nil",
      "Sets a fallback language if a key isn't found in the current one.");

  // getCurrentLanguage
  rec.bind_function(
      lua, path, "getCurrentLanguage",
      // Lua signature: getCurrentLanguage() -> string
      []() -> std::string { return localization::getCurrentLanguage(); },
      // Lua-facing documentation
      "---@return string # The currently active language code.\n"
      "---Gets the currently active language code. This is useful for checking "
      "which language is currently set.",
      "Returns the currently active language code.");

  // get
  rec.bind_function(
      lua, path, "get",
      // Lua signature: get(key : string, args? : table<string,any>) -> string
      [](const std::string &key, sol::object maybeArgs) -> std::string {
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
          sol::object val = kv.second;

          if (val.is<std::string>()) {
            store.push_back(fmt::arg(name.c_str(), val.as<std::string>()));
          } else if (val.is<int>()) {
            store.push_back(fmt::arg(name.c_str(), val.as<int>()));
          } else if (val.is<double>()) {
            store.push_back(fmt::arg(name.c_str(), val.as<double>()));
          } else if (val.is<bool>()) {
            store.push_back(fmt::arg(name.c_str(), val.as<bool>()));
          } else if (val.is<float>()) {
            store.push_back(fmt::arg(name.c_str(), val.as<float>()));
          }
          // …add more type branches as needed…
        }

        // 5) Format and return
        try {
          return fmt::vformat(raw, store);
        } catch (const fmt::format_error &e) {
          return "[FORMAT ERROR: " + std::string(e.what()) + "]";
        }
      },
      // Lua-facing documentation
      "---@param key string                 # Localization key\n"
      "---@param args table<string,any>?    # Optional named formatting args\n"
      "---@return string                    # Localized & formatted text\n",
      "Retrieves a localized string by key, formatting it with an optional Lua "
      "table of named parameters.");

  // getRaw
  rec.bind_function(lua, path, "getRaw", &localization::getRaw,
                    "---@param key string # The localization key.\n"
                    "---@return string # The raw, untransformed string or a "
                    "'[MISSING: key]' message.",
                    "Gets the raw string from the language file, using "
                    "fallbacks if necessary.");

  // getFontData
  rec.bind_function(
      lua, path, "getFontData", &localization::getFontData,
      "---@return FontData # A handle to the font data for the current "
      "language.",
      "Retrieves font data associated with the current language.");

  rec.bind_function(
      lua, path, "getFont",
      []() -> Font { return localization::getFontData().font; },
      "---@return FontData # The font for the current language.\n",
      "Gets the font data for the current language.");

  rec.bind_function(
      lua, path, "getTextWidthWithCurrentFont",
      [](const std::string &text, float fontSize, float spacing) -> float {
        Font font = localization::getFontData().font;
        if (font.baseSize <= 0)
          return 0.0f;

        Vector2 size = MeasureTextEx(font, text.c_str(), fontSize, spacing);
        return size.x;
      },
      "---@param text string # The text to measure.\n"
      "---@param fontSize number # The font size to use when measuring.\n"
      "---@param spacing number # The spacing between characters.\n"
      "---@return number # The width of the text when rendered with the "
      "current language's font.\n",
      "Gets the rendered width of a text string using the current language's "
      "font.");

  // loadFontData
  rec.bind_function(
      lua, path, "loadFontData", &localization::loadFontData,
      "---@param path string # The file path to the font data JSON.\n"
      "---@return nil",
      "Loads font data from the specified path.");

  // loadNamedFont
  rec.bind_function(
      lua, path, "loadNamedFont", &localization::loadNamedFont,
      "---@param name string # The name to register the font under (e.g., "
      "'tooltip').\n"
      "---@param path string # The file path to the font file (TTF/OTF).\n"
      "---@param size number # The font size to load.\n"
      "---@return nil",
      "Loads a named font from a file path with the specified size.");

  // getNamedFont
  rec.bind_function(
      lua, path, "getNamedFont", &localization::getNamedFont,
      "---@return FontData # The font data for the named font, or current "
      "language font if not found.",
      "Gets a named font by name, falling back to current language font.");

  // hasNamedFont
  rec.bind_function(lua, path, "hasNamedFont", &localization::hasNamedFont,
                    "---@param name string # The name of the font to check.\n"
                    "---@return boolean # True if the named font exists.",
                    "Checks if a named font has been loaded.");

  // onLanguageChanged
  rec.bind_function(
      lua, path, "onLanguageChanged", &localization::onLanguageChanged,
      "---@param callback fun(newLanguageCode: string) # A function to call "
      "when the language changes.\n"
      "---@return nil",
      "Registers a callback that executes after the current language changes.");

  // setCurrentLanguage
  rec.bind_function(
      lua, path, "setCurrentLanguage", &localization::setCurrentLanguage,
      "---@param languageCode string # The language code to make active.\n"
      "---@return boolean # True if the language was set successfully, false "
      "otherwise.",
      "Sets the current language and notifies all listeners.");
}

} // namespace localization
