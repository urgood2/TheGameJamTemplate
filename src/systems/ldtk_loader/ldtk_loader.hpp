#pragma once

#include <LDtkLoader/Project.hpp>
#include <raylib.h>
#include <string>
#include <unordered_map>

namespace ldtk_loader {

// --- Internal state ---
namespace {
    ldtk::Project project;
    std::string assetDirectory;
    RenderTexture2D renderTexture{};
    struct TilesetData { Texture2D texture; };
    std::unordered_map<std::string, TilesetData> tilesetCache;
}

// Set base directory for tileset assets
inline void SetAssetDirectory(const std::string& dir) {
    assetDirectory = dir;
}

// Load an LDtk project file; throws std::exception on failure
inline void LoadProject(const std::string& path) {
    project.loadFromFile(path.c_str());
}

// Initialize or resize the render texture
inline void InitRenderTexture(int width, int height) {
    if (renderTexture.texture.id) UnloadRenderTexture(renderTexture);
    renderTexture = LoadRenderTexture(width, height);
}

// Preload a specific tileset texture by path
inline void PreloadTileset(const std::string& relPath) {
    std::string full = assetDirectory.empty() ? relPath : assetDirectory + "/" + relPath;
    if (!tilesetCache.count(full)) {
        tilesetCache[full].texture = LoadTexture(full.c_str());
    }
}

// Draw one layer by name at given scale
inline void DrawLayer(const std::string& levelName,
                      const std::string& layerName,
                      float scale = 1.0f) {
    const auto& world = project.getWorld();
    const auto& level = world.getLevel(levelName);
    const auto& layer = level.getLayer(layerName);
    const auto& tiles = layer.allTiles();
    int w = level.size.x, h = level.size.y;

    InitRenderTexture(w, h);
    BeginTextureMode(renderTexture);
    ::ClearBackground(BLACK);

    for (auto& tile : tiles) {
        Vector2 pos = { tile.getPosition().x * scale,
                        tile.getPosition().y * scale };
        auto rectInterim = tile.getTextureRect();
        Rectangle rect =  { (float)rectInterim.x, (float)rectInterim.y,
            (float)rectInterim.width, (float)rectInterim.height };
        Rectangle src = { rect.x, rect.y,
                          rect.width * (tile.flipX ? -1.0f : 1.0f),
                          rect.height * (tile.flipY ? -1.0f : 1.0f) };
        std::string tp = layer.getTileset().path;
        std::string full = assetDirectory.empty() ? tp : assetDirectory + "/" + tp;
        if (!tilesetCache.count(full)) {
            tilesetCache[full].texture = LoadTexture(full.c_str());
        }
        DrawTextureRec(tilesetCache[full].texture, src, pos, WHITE);
    }

    EndTextureMode();

    // Blit to screen
    Rectangle srcRec = { 0, 0,
        static_cast<float>(renderTexture.texture.width),
        -static_cast<float>(renderTexture.texture.height)
    };
    Rectangle dstRec = { 0, 0,
        renderTexture.texture.width * scale,
        renderTexture.texture.height * scale
    };
    DrawTexturePro(renderTexture.texture, srcRec, dstRec, {0,0}, 0.0f, WHITE);
}

// Draw all layers in a level in order provided
inline void DrawAllLayers(const std::string& levelName, float scale = 1.0f) {
    const auto& world = project.getWorld();
    const auto& level = world.getLevel(levelName);
    for (auto& layer : level.allLayers()) {
        DrawLayer(levelName, layer.getName(), scale);
    }
}

// Unload all loaded textures and render resources
inline void Unload() {
    for (auto& kv : tilesetCache) UnloadTexture(kv.second.texture);
    tilesetCache.clear();
    if (renderTexture.texture.id) UnloadRenderTexture(renderTexture);
}

// Utility: get number of tilesets loaded
inline size_t GetCachedTilesetCount() {
    return tilesetCache.size();
}

} // namespace ldtk_loader
