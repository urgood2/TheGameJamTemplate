#pragma once

#include "third_party/ldtkimport/include/ldtkimport/LdtkDefFile.hpp"
#include "third_party/ldtkimport/include/ldtkimport/Level.h"
#include <raylib.h>
#include <string>
#include <unordered_map>
#include <memory>
#include <queue>
#pragma once

namespace ldtk_rule_import {
    using namespace ldtkimport;

// --- Internal state ---
namespace {
    LdtkDefFile defFile;
#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
    RulesLog rulesLog;
#endif
    Level* levelPtr = nullptr;
    RenderTexture2D renderer{};
    std::unordered_map<std::string, Texture2D> textureCache;
    std::string assetDirectory;
}

// --- Setup ---

// Set a pointer to the active Level
inline void SetLevel(Level& lvl) {
    levelPtr = &lvl;
}

// Set base directory for tileset assets
inline void SetAssetDirectory(const std::string& dir) {
    assetDirectory = dir;
}

// Load LDtk definitions (defs section) from file
inline void LoadDefinitions(const std::string& defPath) {
    if (!defFile.loadFromFile(
#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
        rulesLog,
#endif
        defPath.c_str(), true))
    {
        throw std::runtime_error("Failed to load LDtk definitions: " + defPath);
    }
}

// Run auto-layer rules on the current Level
inline void RunRules(uint8_t runSettings = 0) {
    if (!levelPtr) throw std::runtime_error("Level pointer not set");
    if (!defFile.ensureValidForRules(*levelPtr)) {
        throw std::runtime_error("Definitions not valid for rules");
    }
#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
    rulesLog.tileGrid.clear();
#endif
    defFile.runRules(
#if !defined(NDEBUG) && LDTK_IMPORT_DEBUG_RULE > 0
        rulesLog,
#endif
        *levelPtr, runSettings);
}

// Draw a specific tile grid layer at given scale
inline void DrawGridLayer(int layerIdx, float scale = 1.0f) {
    if (!levelPtr) throw std::runtime_error("Level pointer not set");
    auto& grid = levelPtr->getTileGridByIdx(layerIdx);
    int w = grid.getWidth();
    int h = grid.getHeight();
    // Initialize or resize render target
    if (renderer.texture.id) UnloadRenderTexture(renderer);
    renderer = LoadRenderTexture(
        static_cast<int>(w * scale),
        static_cast<int>(h * scale)
    );

    BeginTextureMode(renderer);
    ClearBackground(BLACK);

    // Fetch tileset texture
    const auto& layerDef = defFile.getLayers()[layerIdx];
    auto tileset = defFile.getTileset(layerDef.tilesetDefUid);
    std::string path = assetDirectory.empty() ? tileset->imagePath : assetDirectory + "/" + tileset->imagePath;
    Texture2D& tex = textureCache.count(path)
        ? textureCache[path]
        : textureCache[path] = LoadTexture(path.c_str());

    int tileSize = tileset->tileSize;
    for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
            auto& cellTiles = grid(x, y);
            if (cellTiles.empty()) continue;
            // draw first tile in cell
            const auto& tile = cellTiles.front();
            int tid = tile.tileId;
            int16_t px, py;
            tileset->getCoordinates(tid, px, py);
            Rectangle src{ (float)px * tileSize, (float)py * tileSize,
                           static_cast<float>(tileSize), static_cast<float>(tileSize) };
            Rectangle dst{ x * tileSize * scale + tile.posXOffset,
                           y * tileSize * scale + tile.posYOffset,
                           tileSize * scale,
                           tileSize * scale };
            DrawTexturePro(tex, src, dst, {0,0}, 0.0f, WHITE);
        }
    }
    EndTextureMode();

    // Blit to screen (flipped Y)
    Rectangle srcRec{ 0, 0,
        static_cast<float>(renderer.texture.width),
        -static_cast<float>(renderer.texture.height)
    };
    Rectangle dstRec{ 0, 0,
        static_cast<float>(renderer.texture.width),
        static_cast<float>(renderer.texture.height)
    };
    DrawTexturePro(renderer.texture, srcRec, dstRec, {0,0}, 0.0f, WHITE);
}

// Unload all textures and render target
inline void Unload() {
    for (auto& kv : textureCache) UnloadTexture(kv.second);
    textureCache.clear();
    if (renderer.texture.id) UnloadRenderTexture(renderer);
}

// --- TileGrid API Exposures ---

inline TileGrid& GetTileGrid(int layerIdx) {
    if (!levelPtr) throw std::runtime_error("Level pointer not set");
    return levelPtr->getTileGridByIdx(layerIdx);
}

// Access tiles in a cell
inline tiles_t& GetTilesAt(int layerIdx, int x, int y) {
    return GetTileGrid(layerIdx)(x, y);
}
// Access tiles by flat index
inline tiles_t& GetTilesAtIdx(int layerIdx, size_t idx) {
    return GetTileGrid(layerIdx)(idx);
}

// Grid dimensions and count
inline int GetGridWidth(int layerIdx) { return GetTileGrid(layerIdx).getWidth(); }
inline int GetGridHeight(int layerIdx) { return GetTileGrid(layerIdx).getHeight(); }
inline size_t GetTileGridCount() { return levelPtr ? levelPtr->getTileGridCount() : 0; }

// Cell placement checks
inline bool CanStillPlaceTiles(int layerIdx, int x, int y) {
    return GetTileGrid(layerIdx).canStillPlaceTiles(x, y);
}
inline uint8_t GetHighestPriority(int layerIdx, int x, int y) {
    return GetTileGrid(layerIdx).getHighestPriority(x, y);
}

// Random seed and UID
inline void SetTileGridRandomSeed(int layerIdx, uint32_t s) { GetTileGrid(layerIdx).setRandomSeed(s); }
inline uint32_t GetTileGridRandomSeed(int layerIdx) { return GetTileGrid(layerIdx).getRandomSeed(); }
inline void SetTileGridLayerUid(int layerIdx, ldtkimport::uid_t uid) { GetTileGrid(layerIdx).setLayerUid(uid); }
inline ldtkimport::uid_t GetTileGridLayerUid(int layerIdx) { return GetTileGrid(layerIdx).getLayerUid(); }

// Debug printing
inline void DebugPrintTileGrid(int layerIdx, std::ostream& os) {
    os << GetTileGrid(layerIdx);
}
inline void DebugPrintAllTileGrids(std::ostream& os) {
    if (!levelPtr) return;
    levelPtr->debugPrintTileGrids(os);
}

// --- TileGrid Manipulation ---

inline void ClearGridLayer(int layerIdx) { GetTileGrid(layerIdx).cleanUp(); }
inline void FillGridLayer(int layerIdx, tileid_t tid) {
    auto& grid = GetTileGrid(layerIdx);
    for (int y = 0; y < grid.getHeight(); ++y)
        for (int x = 0; x < grid.getWidth(); ++x)
            grid.putTile(tid, x, y, 0, 0, UINT8_MAX, 0, 0);
}
inline void ResizeGridLayer(int layerIdx, int w, int h) { GetTileGrid(layerIdx).setSize(w, h); }

// --- Flood Fill ---
inline void FloodFillGrid(int layerIdx,
                          int startX,
                          int startY,
                          tileid_t newTid,
                          bool allowDiagonal = false) {
    auto& grid = GetTileGrid(layerIdx);
    int w = grid.getWidth(), h = grid.getHeight();
    if (startX<0||startX>=w||startY<0||startY>=h) return;
    auto& startTiles = grid(startX, startY);
    tileid_t origTid = startTiles.empty() ? tileid_t(-1) : startTiles.front().tileId;
    if (origTid == newTid) return;

    std::vector<std::vector<bool>> vis(h, std::vector<bool>(w));
    std::queue<std::pair<int,int>> q;
    q.emplace(startX, startY);
    vis[startY][startX] = true;

    const std::vector<std::pair<int,int>> orth{{1,0},{-1,0},{0,1},{0,-1}};
    const std::vector<std::pair<int,int>> diag{{1,1},{1,-1},{-1,1},{-1,-1}};

    while (!q.empty()) {
        auto [x,y] = q.front(); q.pop();
        auto& tiles = grid(x,y);
        tileid_t tid = tiles.empty() ? tileid_t(-1) : tiles.front().tileId;
        if (tid != origTid) continue;
        grid.putTile(newTid, x, y, 0, 0, UINT8_MAX, 0, 0);
        for (auto d: orth) {
            int nx=x+d.first, ny=y+d.second;
            if (nx>=0&&nx<w&&ny>=0&&ny<h&&!vis[ny][nx]) { vis[ny][nx]=true; q.emplace(nx,ny);} }
        if (allowDiagonal) for (auto d: diag) {
            int nx=x+d.first, ny=y+d.second;
            if (nx>=0&&nx<w&&ny>=0&&ny<h&&!vis[ny][nx]) { vis[ny][nx]=true; q.emplace(nx,ny);} }
    }
}

} // namespace ldtk_rule_import
