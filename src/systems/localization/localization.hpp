#pragma once

#include "util/common_headers.hpp"

#include <string>
#include <unordered_map>
#include "sol/sol.hpp"

struct EngineContext;

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

  // Named font registry - for custom fonts like tooltip fonts
  extern std::unordered_map<std::string, globals::FontData> namedFonts;
  
  /// Load a named font from file path with specified size (single-size, for backwards compatibility)
  extern void loadNamedFont(const std::string& name, const std::string& path, float size);

  /// Load a named font from file path with multiple sizes (for multi-size font cache)
  /// @param name The name to register the font under (e.g., "tooltip")
  /// @param path The file path to the font file (TTF/OTF)
  /// @param sizes Vector of sizes to load the font at
  /// @param defaultSize The default size to use when none is specified
  extern void loadNamedFontSizes(const std::string& name, const std::string& path,
                                  const std::vector<int>& sizes, int defaultSize);

  /// Get a named font by name, falls back to current language font if not found
  extern const globals::FontData& getNamedFont(const std::string& name);

  /// Check if a named font exists
  extern bool hasNamedFont(const std::string& name);

  // ==========================
  // Localization System API
  // ==========================

  extern void exposeToLua(sol::state &lua, EngineContext* ctx = nullptr);

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
  extern const globals::FontData& getFontData();

  // Register a listener:
  inline void onLanguageChanged(LangChangedCb cb)
  {
    langChangedCallbacks.push_back(std::move(cb));
  }

  extern  void loadFontData(const std::string& jsonPath);

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

  Example with a uitemplateNode:

  ```
    tooltipButtonText.config.initFunc = [](entt::registry* registry, entt::entity e) {
            localization::onLanguageChanged([&](auto newLang){
                TextSystem::Functions::setText(e, localization::get("ui.tooltip_text_hover"));
            });
        };
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
  
  // Clear all registered callbacks (used on shutdown/reset to drop Lua refs safely).
  inline void clearLanguageChangedCallbacks() { langChangedCallbacks.clear(); }

  inline const std::string& getCurrentLanguage()
  {
    return currentLang;
  }

}
