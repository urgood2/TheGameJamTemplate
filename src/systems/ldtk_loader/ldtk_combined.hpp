// testing whether ldtk_loader.hpp and ldtk_import.hpp can be fused together

#pragma once

// --- Dependencies ---
#include <LDtkLoader/Project.hpp>
#include "third_party/ldtkimport/include/ldtkimport/LdtkDefFile.hpp"
#include "third_party/ldtkimport/include/ldtkimport/Level.h"
#include <raylib.h>
#include <string>
#include <unordered_map>
#include <memory>
#include <queue>
#include <ostream>

// ---------------------------------------------
// Namespace: ldtk_loader (LDtkLoader + raylib)
// ---------------------------------------------
namespace ldtk_loader {

namespace internal_loader {
    extern ::ldtk::Project project;
    extern std::string assetDirectory;
    extern RenderTexture2D renderTexture;
    struct TilesetData { Texture2D texture; };
    extern std::unordered_map<std::string, TilesetData> tilesetCache;
}

inline void SetAssetDirectory(const std::string& dir) {
    internal_loader::assetDirectory = dir;
}
inline void LoadProject(const std::string& path) {
    internal_loader::project.loadFromFile(path.c_str());
}
inline void InitRenderTexture(int width, int height) {
    auto& rt = internal_loader::renderTexture;
    if (rt.texture.id) UnloadRenderTexture(rt);
    rt = LoadRenderTexture(width, height);
}
inline void PreloadTileset(const std::string& relPath) {
    std::string full = internal_loader::assetDirectory.empty()
        ? relPath
        : internal_loader::assetDirectory + "/" + relPath;
    auto& cache = internal_loader::tilesetCache;
    if (!cache.count(full)) {
        cache[full].texture = LoadTexture(full.c_str());
    }
}
inline void DrawLayer(const std::string& levelName,
                      const std::string& layerName,
                      float scale = 1.0f) {
    const auto& world = internal_loader::project.getWorld();
    const auto& level = world.getLevel(levelName);
    const auto& layer = level.getLayer(layerName);
    const auto& tiles = layer.allTiles();
    int w = level.size.x;
    int h = level.size.y;

    InitRenderTexture(w, h);
    BeginTextureMode(internal_loader::renderTexture);
    ClearBackground(BLACK);

    for (auto& tile : tiles) {
        Vector2 pos = { tile.getPosition().x * scale,
                        tile.getPosition().y * scale };
        auto rectInterim = tile.getTextureRect();
        Rectangle r = { (float)rectInterim.x, (float)rectInterim.y,
                           (float)rectInterim.width, (float)rectInterim.height };
        Rectangle src = { r.x, r.y,
                          r.width  * (tile.flipX ? -1.0f : 1.0f),
                          r.height * (tile.flipY ? -1.0f : 1.0f) };
        std::string tp = layer.getTileset().path;
        std::string full = internal_loader::assetDirectory.empty()
            ? tp
            : internal_loader::assetDirectory + "/" + tp;
        auto& cache = internal_loader::tilesetCache;
        if (!cache.count(full)) {
            cache[full].texture = LoadTexture(full.c_str());
        }
        DrawTextureRec(cache[full].texture, src, pos, WHITE);
    }
    EndTextureMode();

    Rectangle srcRec = { 0, 0,
        static_cast<float>(internal_loader::renderTexture.texture.width),
        -static_cast<float>(internal_loader::renderTexture.texture.height)
    };
    Rectangle dstRec = { 0, 0,
        internal_loader::renderTexture.texture.width  * scale,
        internal_loader::renderTexture.texture.height * scale
    };
    DrawTexturePro(internal_loader::renderTexture.texture,
                   srcRec, dstRec, {0, 0}, 0.0f, WHITE);
}
inline void DrawAllLayers(const std::string& levelName, float scale = 1.0f) {
    const auto& world = internal_loader::project.getWorld();
    const auto& level = world.getLevel(levelName);
    for (auto& layer : level.allLayers()) {
        DrawLayer(levelName, layer.getName(), scale);
    }
}
inline void Unload() {
    for (auto& kv : internal_loader::tilesetCache) {
        UnloadTexture(kv.second.texture);
    }
    internal_loader::tilesetCache.clear();
    auto& rt = internal_loader::renderTexture;
    if (rt.texture.id) UnloadRenderTexture(rt);
}
inline size_t GetCachedTilesetCount() {
    return internal_loader::tilesetCache.size();
}

} // namespace ldtk_loader

// ----------------------------------------------------
// Namespace: ldtk_rule_import (ldtkimport + raylib)
// ----------------------------------------------------
namespace ldtk_rule_import {

using namespace ldtkimport;

namespace internal_rule {
    extern LdtkDefFile defFile;
#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
    extern RulesLog rulesLog;
#endif
    extern Level* levelPtr;
    extern RenderTexture2D renderer;
    extern std::unordered_map<std::string, Texture2D> textureCache;
    extern std::string assetDirectory;
}

inline void SetLevel(Level& lvl) {
    internal_rule::levelPtr = &lvl;
}
inline void SetAssetDirectory(const std::string& dir) {
    internal_rule::assetDirectory = dir;
}
inline void LoadDefinitions(const std::string& defPath) {
    if (!internal_rule::defFile.loadFromFile(
#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
        internal_rule::rulesLog,
#endif
        defPath.c_str(), true)) {
        throw std::runtime_error("Failed to load LDtk definitions: " + defPath);
    }
}
inline void RunRules(uint8_t runSettings = 0) {
    auto ptr = internal_rule::levelPtr;
    if (!ptr) throw std::runtime_error("Level pointer not set");
    if (!internal_rule::defFile.ensureValidForRules(*ptr)) {
        throw std::runtime_error("Definitions not valid for rules");
    }
#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
    internal_rule::rulesLog.tileGrid.clear();
#endif
    internal_rule::defFile.runRules(
#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
        internal_rule::rulesLog,
#endif
        *ptr, runSettings);
}
inline void DrawGridLayer(int layerIdx, float scale = 1.0f) {
    auto ptr = internal_rule::levelPtr;
    if (!ptr) throw std::runtime_error("Level pointer not set");
    auto& grid = ptr->getTileGridByIdx(layerIdx);
    int w = grid.getWidth(), h = grid.getHeight();
    auto& rt = internal_rule::renderer;
    if (rt.texture.id) UnloadRenderTexture(rt);
    rt = LoadRenderTexture(int(w * scale), int(h * scale));

    BeginTextureMode(rt);
    ClearBackground(BLACK);

    const auto& layerDef = internal_rule::defFile.getLayers()[layerIdx];
    auto tileset = internal_rule::defFile.getTileset(layerDef.tilesetDefUid);
    std::string path = internal_rule::assetDirectory.empty()
        ? tileset->imagePath
        : internal_rule::assetDirectory + "/" + tileset->imagePath;
    Texture2D& tex = internal_rule::textureCache.count(path)
        ? internal_rule::textureCache[path]
        : internal_rule::textureCache[path] = LoadTexture(path.c_str());

    int tileSize = tileset->tileSize;
    for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
            auto& cellTiles = grid(x, y);
            if (cellTiles.empty()) continue;
            auto& tile = cellTiles.front();
            int16_t px, py;
            tileset->getCoordinates(tile.tileId, px, py);
            Rectangle src { (float)px * tileSize, (float)py * tileSize,
                             float(tileSize), float(tileSize) };
            Rectangle dst { x * tileSize * scale + tile.posXOffset,
                             y * tileSize * scale + tile.posYOffset,
                             tileSize * scale, tileSize * scale };
            DrawTexturePro(tex, src, dst, {0, 0}, 0.0f, WHITE);
        }
    }
    EndTextureMode();

    Rectangle srcRec { 0, 0,
        float(rt.texture.width), -float(rt.texture.height)
    };
    Rectangle dstRec { 0, 0,
        float(rt.texture.width), float(rt.texture.height)
    };
    DrawTexturePro(rt.texture, srcRec, dstRec, {0, 0}, 0.0f, WHITE);
}
inline void Unload() {
    for (auto& kv : internal_rule::textureCache) UnloadTexture(kv.second);
    internal_rule::textureCache.clear();
    auto& rt = internal_rule::renderer;
    if (rt.texture.id) UnloadRenderTexture(rt);
}

// Expose TileGrid API
inline ldtkimport::TileGrid& GetTileGrid(int layerIdx) {
    auto ptr = internal_rule::levelPtr;
    if (!ptr) throw std::runtime_error("Level pointer not set");
    return ptr->getTileGridByIdx(layerIdx);
}
inline tiles_t& GetTilesAt(int layerIdx, int x, int y) { return GetTileGrid(layerIdx)(x, y); }
inline tiles_t& GetTilesAtIdx(int layerIdx, size_t idx) { return GetTileGrid(layerIdx)(idx); }
inline int GetGridWidth(int layerIdx) { return GetTileGrid(layerIdx).getWidth(); }
inline int GetGridHeight(int layerIdx) { return GetTileGrid(layerIdx).getHeight(); }
inline size_t GetTileGridCount() { return internal_rule::levelPtr ? internal_rule::levelPtr->getTileGridCount() : 0; }
inline bool CanStillPlaceTiles(int layerIdx, int x, int y) { return GetTileGrid(layerIdx).canStillPlaceTiles(x, y); }
inline uint8_t GetHighestPriority(int layerIdx, int x, int y) { return GetTileGrid(layerIdx).getHighestPriority(x, y); }
inline void SetTileGridRandomSeed(int layerIdx, uint32_t s) { GetTileGrid(layerIdx).setRandomSeed(s); }
inline uint32_t GetTileGridRandomSeed(int layerIdx) { return GetTileGrid(layerIdx).getRandomSeed(); }
inline void SetTileGridLayerUid(int layerIdx, ldtkimport::uid_t uid) { GetTileGrid(layerIdx).setLayerUid(uid); }
inline ldtkimport::uid_t GetTileGridLayerUid(int layerIdx) { return GetTileGrid(layerIdx).getLayerUid(); }
inline void DebugPrintTileGrid(int layerIdx, std::ostream& os) { os << GetTileGrid(layerIdx); }
inline void DebugPrintAllTileGrids(std::ostream& os) { if (internal_rule::levelPtr) internal_rule::levelPtr->debugPrintTileGrids(os); }

// TileGrid manipulation
inline void ClearGridLayer(int layerIdx) { GetTileGrid(layerIdx).cleanUp(); }
inline void FillGridLayer(int layerIdx, tileid_t tid) {
    auto& grid = GetTileGrid(layerIdx);
    for (int y = 0; y < grid.getHeight(); ++y)
        for (int x = 0; x < grid.getWidth(); ++x)
            grid.putTile(tid, x, y, 0, 0, UINT8_MAX, 0, 0);
}
inline void ResizeGridLayer(int layerIdx, int w, int h) { GetTileGrid(layerIdx).setSize(w, h); }

// Flood fill utility
inline void FloodFillGrid(int layerIdx,
                          int startX,
                          int startY,
                          tileid_t newTid,
                          bool allowDiagonal = false) {
    auto& grid = GetTileGrid(layerIdx);
    int w = grid.getWidth(), h = grid.getHeight();
    if (startX < 0 || startX >= w || startY < 0 || startY >= h) return;
    auto& startTiles = grid(startX, startY);
    tileid_t origTid = startTiles.empty() ? tileid_t(-1) : startTiles.front().tileId;
    if (origTid == newTid) return;

    std::vector<std::vector<bool>> vis(h, std::vector<bool>(w));
    std::queue<std::pair<int,int>> q;
    q.emplace(startX, startY);
    vis[startY][startX] = true;

    const std::array<std::pair<int,int>,4> orth{{{1,0},{-1,0},{0,1},{0,-1}}};
    const std::array<std::pair<int,int>,4> diag{{{1,1},{1,-1},{-1,1},{-1,-1}}};

    while (!q.empty()) {
        auto [x, y] = q.front(); q.pop();
        auto& cellTiles = grid(x, y);
        tileid_t tid = cellTiles.empty() ? tileid_t(-1) : cellTiles.front().tileId;
        if (tid != origTid) continue;
        grid.putTile(newTid, x, y, 0, 0, UINT8_MAX, 0, 0);
        for (auto d : orth) {
            int nx = x + d.first, ny = y + d.second;
            if (nx>=0 && nx<w && ny>=0 && ny<h && !vis[ny][nx]) {
                vis[ny][nx] = true;
                q.emplace(nx, ny);
            }
        }
        if (allowDiagonal) for (auto d : diag) {
            int nx = x + d.first, ny = y + d.second;
            if (nx>=0 && nx<w && ny>=0 && ny<h && !vis[ny][nx]) {
                vis[ny][nx] = true;
                q.emplace(nx, ny);
            }
        }
    }
}

} // namespace ldtk_rule_import
