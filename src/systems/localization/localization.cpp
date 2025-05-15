#include "localization.hpp"

namespace localization
{
    // ==========================
    // Localization System internals
    // ==========================
    std::string currentLang{};
    std::string fallbackLang = "en";
    std::unordered_map<std::string, nlohmann::json> languageData{};
    std::string resolveKey(const json& data, const std::string& key) {
        std::istringstream stream(key);
        std::string segment;
        const json* current = &data;
    
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
    

    // ==========================
    // Localization System API
    // ==========================
    void loadLanguage(const std::string& langCode, const std::string& path) {
        std::ifstream file(path + langCode + ".json");
        if (!file.is_open()) {
            std::cerr << "Failed to load language file: " << path + langCode + ".json\n";
            return;
        }
    
        try {
            languageData[langCode] = json::parse(file);
            currentLang = langCode;
        } catch (const std::exception& e) {
            std::cerr << "JSON parse error in " << langCode << ": " << e.what() << '\n';
        }
    }
    
    void setFallbackLanguage(const std::string& langCode) {
        fallbackLang = langCode;
    }
    
    std::string get(const std::string& key) {
        auto it = languageData.find(currentLang);
        if (it != languageData.end()) {
            std::string result = resolveKey(it->second, key);
            if (!result.empty()) return result;
        }
    
        if (fallbackLang != currentLang) {
            auto fallbackIt = languageData.find(fallbackLang);
            if (fallbackIt != languageData.end()) {
                std::string result = resolveKey(fallbackIt->second, key);
                if (!result.empty()) return result;
            }
        }
    
        return "[MISSING: " + key + "]";
    }    
    
}