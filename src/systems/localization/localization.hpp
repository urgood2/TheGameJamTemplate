#pragma once

#include "util/common_headers.hpp"

#include <string>
#include <unordered_map>

/**

Example usage:

```json
{
  "menu": {
    "start": "Start Game",
    "exit": "Exit",
    "welcome": "Welcome, {name}!"
  },
  "error": {
    "network": "Network error occurred."
  }
}
```

<code>
```cpp

localization::setFallbackLanguage("en");
localization::loadLanguage("en");
localization::loadLanguage("ko"); // If you have Korean, preload it too

std::string start = localization::get("menu.start"); // → "Start Game"
std::string welcome = localization::get("menu.welcome", fmt::arg("name", "Josh")); // → "Welcome, Josh!"

```
</code>
*/
namespace globals
{
  struct FontData;
}

namespace localization
{
  // ==========================
  // Localization System internals
  // ==========================
  extern std::string currentLang;
  extern std::string fallbackLang;
  extern std::unordered_map<std::string, nlohmann::json> languageData;
  extern std::string resolveKey(const nlohmann::json &data, const std::string &key);

  using FlatMap = std::unordered_map<std::string, std::string>;
  extern std::unordered_map<std::string, FlatMap> flatLanguageData;

  using LangChangedCb = std::function<void(const std::string &newLang)>;
  extern std::vector<LangChangedCb> langChangedCallbacks;

  extern std::unordered_map<std::string, globals::FontData> languageFontData;

  // ==========================
  // Localization System API
  // ==========================

  extern void loadLanguage(const std::string &langCode, const std::string &path);
  extern void setFallbackLanguage(const std::string &langCode);

  extern std::string get(const std::string &key);

  // 1) A thin non-templated “raw” lookup that uses your flattened maps:
  inline const std::string& getRaw(const std::string& key) {
    // try current language
    auto &flat = flatLanguageData[currentLang];
    if (auto it = flat.find(key); it != flat.end())
      return it->second;

    // fallback language
    if (currentLang != fallbackLang) {
      auto &fb = flatLanguageData[fallbackLang];
      if (auto it2 = fb.find(key); it2 != fb.end())
        return it2->second;
    }

    static const std::string missing = "[MISSING: " + key + "]";
    return missing;
  }

  template <typename... Args>
  std::string get(const std::string &key, Args &&...args)
  {
    std::string raw = getRaw(key);
    try
    {
      return fmt::format(fmt::runtime(raw), std::forward<Args>(args)...);
    }
    catch (const fmt::format_error &e)
    {
      return "[FORMAT ERROR: " + std::string(e.what()) + "]";
    }
  }

  // in localization.cpp
  inline const globals::FontData& getFontData() {
      if (auto it = languageFontData.find(currentLang); it != languageFontData.end())
          return it->second;
      if (auto it2 = languageFontData.find(fallbackLang); it2 != languageFontData.end())
          return it2->second;
      static globals::FontData defaultFD{};
      return defaultFD;
  }

  // Register a listener:
  inline void onLanguageChanged(LangChangedCb cb)
  {
    langChangedCallbacks.push_back(std::move(cb));
  }

  inline void loadFontData(const std::string& jsonPath)
  {
      std::ifstream f(jsonPath);
      if (!f.is_open()) {
          SPDLOG_ERROR("Could not open fonts.json at '{}'", jsonPath);
          return;
      }

      json j;
      try { f >> j; }
      catch (const std::exception& e) {
          SPDLOG_ERROR("Failed to parse {}: {}", jsonPath, e.what());
          return;
      }

      for (auto& [langCode, fontJ] : j.items()) {
          globals::FontData fd;
          fd.fontLoadedSize   = fontJ.value("loadedSize", 32.f);
          fd.fontScale        = fontJ.value("scale",       1.f);
          fd.spacing          = fontJ.value("spacing",     1.f);
          auto off = fontJ.value("offset", std::vector<float>{0,0});
          fd.fontRenderOffset = { off[0], off[1] };

          std::string file    = fontJ.value("file", std::string{});
          if (!file.empty()) {
              fd.font = LoadFont(file.c_str());
              if (fd.font.texture.id == 0) {
                  SPDLOG_ERROR("Failed to load font '{}' for '{}'", file, langCode);
              }
          }
          languageFontData[langCode] = fd;
      }
  }

  // Call this from your setter:
  // Suppose you have a Label class that you want to re-text whenever the lang changes:
  /*
  Usage:
  ```cpp
    localization::onLanguageChanged([&](auto newLang){
          myLabel.setText( localization::get("menu.start") );
          myLabel.setFontData( localization::languageFontData[newLang] );
        });
  ```
  */
  inline bool setCurrentLanguage(const std::string &langCode)
  {
    if (!languageData.count(langCode))
    {
      SPDLOG_WARN("Language '{}' not loaded", langCode);
      return false;
    }
    currentLang = langCode;
    // notify everyone
    for (auto &cb : langChangedCallbacks)
    {
      cb(currentLang);
    }
    return true;
  }

}