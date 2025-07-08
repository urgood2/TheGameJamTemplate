#include "ldtk_combined.hpp"



namespace ldtk_loader {

    namespace internal_loader {
        ::ldtk::Project project{};
        std::string assetDirectory{};
        RenderTexture2D renderTexture{};
        std::unordered_map<std::string, TilesetData> tilesetCache{};
    }
}

namespace ldtk_rule_import {

    using namespace ldtkimport;
    
    namespace internal_rule {
        LdtkDefFile defFile;
    #if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
        RulesLog rulesLog{};
    #endif
        Level* levelPtr = nullptr;
        RenderTexture2D renderer{};
        std::unordered_map<std::string, Texture2D> textureCache;
        std::string assetDirectory;
    }
}    