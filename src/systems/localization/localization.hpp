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


namespace localization
{
    // ==========================
    // Localization System internals
    // ==========================
    extern std::string currentLang;
    extern std::string fallbackLang;
    extern std::unordered_map<std::string, nlohmann::json> languageData;
    extern std::string resolveKey(const nlohmann::json& data, const std::string& key);

    // ==========================
    // Localization System API
    // ==========================
    
    extern void loadLanguage(const std::string& langCode, const std::string& path );
    extern void setFallbackLanguage(const std::string& langCode);

    extern std::string get(const std::string& key);

    template <typename... Args>
    std::string get(const std::string& key, Args&&... args) {
        std::string raw = get(key);
        try {
            return fmt::format(fmt::runtime(raw), std::forward<Args>(args)...);
        } catch (const fmt::format_error& e) {
            return "[FORMAT ERROR: " + std::string(e.what()) + "]";
        }
    }

}