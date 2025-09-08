// testing whether ldtk_loader.hpp and ldtk_import.hpp can be fused together

#pragma once

// --- Dependencies ---
#include "third_party/ldtk_loader/src/Project.hpp"
#include "spdlog/spdlog.h"
#include "third_party/ldtkimport/include/ldtkimport/LdtkDefFile.hpp"
#include "third_party/ldtkimport/include/ldtkimport/Level.h"
#include "util/utilities.hpp"
#include <raylib.h>
#include <string>
#include <unordered_map>
#include <memory>
#include <queue>
#include <ostream>
#include "systems/layer/layer_command_buffer.hpp"
#include "systems/layer/layer_order_system.hpp"
#include "systems/layer/layer_optimized.hpp"

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

static inline const Texture2D& LoadTextureCached(const std::string& fullPath) {
    auto& cache = internal_loader::tilesetCache; // reuse your cache map<string, {Texture2D texture;}>
    auto it = cache.find(fullPath);
    if (it == cache.end()) {
        Texture2D tex = LoadTexture(fullPath.c_str());
        if (tex.id > 0) SetTextureFilter(tex, TEXTURE_FILTER_POINT);
        cache[fullPath].texture = tex;
        return cache[fullPath].texture;
    }
    return it->second.texture;
}
static inline float CoverScale(int dstW, int dstH, int srcW, int srcH) {
    const float sx = (float)dstW / (float)srcW;
    const float sy = (float)dstH / (float)srcH;
    return sx > sy ? sx : sy;
}
static inline float ContainScale(int dstW, int dstH, int srcW, int srcH) {
    const float sx = (float)dstW / (float)srcW;
    const float sy = (float)dstH / (float)srcH;
    return sx < sy ? sx : sy;
}

inline void DrawLevelBackground(std::shared_ptr<layer::Layer> layerPtr,
    const ldtk::Level& level, const Rectangle* ccropOpt = nullptr, const int renderZLevel = 0) {
    const int w = level.size.x, h = level.size.y;
    const Rectangle CLIP = ccropOpt ? *ccropOpt : Rectangle{0, 0, (float)w, (float)h};

    // Optional solid fill (outside scissor so the whole level gets the color)
    ::Color bg{ level.bg_color.r, level.bg_color.g, level.bg_color.b, level.bg_color.a };
    if (bg.a) {
        // layer::QueueCommand<layer::CmdDrawRectanglePro>(layerPtr, [width = transform.getVisualW(), height = transform.getVisualH(), color = drawColor](layer::CmdDrawRectanglePro *cmd)
        // {
        //     cmd->offsetX      = 0;
        //     cmd->offsetY      = 0;
        //     cmd->size.x  = width;
        //     cmd->size.y = height;
        //     cmd->color  = color; }, 
        //     0, drawCommandSpace);
        layer::QueueCommand<layer::CmdDrawRectanglePro>(layerPtr, [x = 0, y = 0, w = (float)w, h = (float)h, bg](layer::CmdDrawRectanglePro *cmd) {
            cmd->offsetX = x;
            cmd->offsetY = y;
            cmd->size.x = w;
            cmd->size.y = h;
            cmd->color = bg;
        }, renderZLevel, layer::DrawCommandSpace::World);
    }

    if (!level.hasBgImage()) return;
    const auto& bgimg = level.getBgImage();

    // Resolve/load texture
    const std::string rel  = std::string(bgimg.path.c_str());
    const std::string full = internal_loader::assetDirectory.empty()
                           ? rel
                           : (internal_loader::assetDirectory + "/" + rel);
    const Texture2D& tex = LoadTextureCached(util::getRawAssetPathNoUUID(full));
    if (tex.id <= 0) return;

    // Source rect: crop if present
    const bool hasCrop = (bgimg.crop.width > 0 && bgimg.crop.height > 0);
    Rectangle src{
        (float)(hasCrop ? bgimg.crop.x      : 0),
        (float)(hasCrop ? bgimg.crop.y      : 0),
        (float)(hasCrop ? bgimg.crop.width  : tex.width),
        (float)(hasCrop ? bgimg.crop.height : tex.height)
    };

    auto pmod = [](float a, float m) { float r = fmodf(a, m); return (r < 0) ? (r + m) : r; };
    auto coverScale   = [](int dw, int dh, float sw, float sh){ float sx=(float)dw/sw, sy=(float)dh/sh; return sx>sy?sx:sy; };
    auto containScale = [](int dw, int dh, float sw, float sh){ float sx=(float)dw/sw, sy=(float)dh/sh; return sx<sy?sx:sy; };

    // Prefer real mode/pivot if you’ve added getters
    std::string mode = "Cover";
    Vector2 pivot{0.5f, 0.5f};
    if (true) { mode = level.getBgPosMode(); auto pv = level.getBgPivot(); pivot = {pv.x, pv.y}; }

    // Heuristic for precomputed placement (__bgPos). If you have a getter, use that instead.
    const bool hasComputed =
        (!((bgimg.scale.x == 1.f && bgimg.scale.y == 1.f) && (bgimg.pos.x == 0 && bgimg.pos.y == 0))) || hasCrop;

    // --- begin scissor just for the image draw ---
    const int scx = (int)std::floor(CLIP.x);
    const int scy = (int)std::floor(CLIP.y);
    const int scw = (int)std::ceil (CLIP.width);
    const int sch = (int)std::ceil (CLIP.height);
    // BeginScissorMode(scx, scy, scw, sch);
    layer::QueueCommand<layer::CmdBeginScissorMode>(
        layerPtr, [](layer::CmdBeginScissorMode*){}, renderZLevel, layer::DrawCommandSpace::World
    );

    if (hasComputed) {
        if (mode == "Repeat") {
            const float sx = (bgimg.scale.x == 0.f) ? 1.f : bgimg.scale.x;
            const float sy = (bgimg.scale.y == 0.f) ? 1.f : bgimg.scale.y;
            const float tileW = src.width  * sx;
            const float tileH = src.height * sy;

            const float firstX = CLIP.x - pmod(CLIP.x - (float)bgimg.pos.x, tileW);
            const float firstY = CLIP.y - pmod(CLIP.y - (float)bgimg.pos.y, tileH);

            for (float y = firstY; y < CLIP.y + CLIP.height; y += tileH) {
                for (float x = firstX; x < CLIP.x + CLIP.width;  x += tileW) {
                    // DrawTexturePro(tex, src, Rectangle{ x, y, tileW, tileH }, Vector2{0,0}, 0.0f, WHITE);
                    
                    layer::QueueCommand<layer::CmdTexturePro>(layerPtr, [tex, src, dest = Rectangle{ x, y, tileW, tileH }](layer::CmdTexturePro *cmd) {
                            cmd->texture = tex;
                            cmd->source = src;
                            cmd->offsetX = 0;
                            cmd->offsetY = 0;
                            cmd->size = {dest.width, dest.height};
                            cmd->rotationCenter = {0, 0};
                            cmd->rotation = 0;
                            cmd->color = WHITE;
                        }, renderZLevel, layer::DrawCommandSpace::World);
                }
            }
        } else {
            const float sx = (bgimg.scale.x == 0.f) ? 1.f : bgimg.scale.x;
            const float sy = (bgimg.scale.y == 0.f) ? 1.f : bgimg.scale.y;
            Rectangle dst{ (float)bgimg.pos.x, (float)bgimg.pos.y, src.width * sx, src.height * sy };
            // DrawTexturePro(tex, src, dst, Vector2{0,0}, 0.0f, WHITE);
            layer::QueueCommand<layer::CmdTexturePro>(layerPtr, [tex, src, dst](layer::CmdTexturePro *cmd) {
                cmd->texture = tex;
                cmd->source = src;
                cmd->offsetX = 0;
                cmd->offsetY = 0;
                cmd->size = {dst.width, dst.height};
                cmd->rotationCenter = {0, 0};
                cmd->rotation = 0;
                cmd->color = WHITE;
            }, renderZLevel, layer::DrawCommandSpace::World);
        }
        // EndScissorMode();
        layer::QueueCommand<layer::CmdEndScissorMode>(
        layerPtr, [](layer::CmdEndScissorMode*){}, renderZLevel, layer::DrawCommandSpace::World
    );
        return;
    }

    // No __bgPos → compute placement
    if (mode == "Repeat") {
        const float sx = 1.f, sy = 1.f;
        const float tileW = src.width  * sx;
        const float tileH = src.height * sy;

        for (float y = CLIP.y; y < CLIP.y + CLIP.height; y += tileH) {
            for (float x = CLIP.x; x < CLIP.x + CLIP.width;  x += tileW) {
                DrawTexturePro(tex, src, Rectangle{ x, y, tileW, tileH }, Vector2{0,0}, 0.0f, WHITE);
            }
        }
        // EndScissorMode();
        layer::QueueCommand<layer::CmdEndScissorMode>(
        layerPtr, [](layer::CmdEndScissorMode*){}, renderZLevel, layer::DrawCommandSpace::World
    );
        return;
    }

    float sw = src.width, sh = src.height;
    if (mode == "Cover")   { float s = coverScale(w, h, src.width, src.height);   sw = src.width * s; sh = src.height * s; }
    else if (mode == "Contain") { float s = containScale(w, h, src.width, src.height); sw = src.width * s; sh = src.height * s; }
    else if (mode == "Stretch") { sw = (float)w; sh = (float)h; } // Unscaled: leave as-is

    const float levelPX = (float)w * pivot.x, levelPY = (float)h * pivot.y;
    const float imgPX   = sw * pivot.x,       imgPY   = sh * pivot.y;
    Rectangle dst{ levelPX - imgPX, levelPY - imgPY, sw, sh };
    DrawTexturePro(tex, src, dst, Vector2{0,0}, 0.0f, WHITE);

    // EndScissorMode();
    
    layer::QueueCommand<layer::CmdEndScissorMode>(
        layerPtr, [](layer::CmdEndScissorMode*){}, renderZLevel, layer::DrawCommandSpace::World
    );
}

inline void DrawLayer(std::shared_ptr<layer::Layer> layerPtr, const std::string& levelName, const std::string& layerName, float scale = 1.0f, const int renderZLevel = 0) {
    const auto& world = internal_loader::project.getWorld();
    const auto& level = world.getLevel(levelName);
    const auto& layer = level.getLayer(layerName);

    if (!layer.hasTileset()) return;

    const std::string rel  = layer.getTileset().path;
    const std::string full = internal_loader::assetDirectory.empty()
                           ? rel
                           : internal_loader::assetDirectory + "/" + rel;

    auto& cache = internal_loader::tilesetCache;
    if (!cache.count(full)) {
        cache[full].texture = LoadTexture(util::getAssetPathUUIDVersion(full).c_str());
        // Optional (prevents bleeding): SetTextureFilter(cache[full].texture, TEXTURE_FILTER_POINT);
    }
    const Texture2D& tex = cache[full].texture;

    // Make sure alpha blending is on (it is by default, but explicit is fine)
    // BeginBlendMode(BLEND_ALPHA);

    for (const auto& tile : layer.allTiles()) {
        const auto p  = tile.getPosition();        // includes layer offset
        const auto tr = tile.getTextureRect();     // positive size

        Vector2   pos = { (float)p.x, (float)p.y };
        Rectangle src = { (float)tr.x, (float)tr.y, (float)tr.width, (float)tr.height };

        // Flip by negating source dims ONLY; do NOT move pos.
        if (tile.flipX) src.width  = -src.width;
        if (tile.flipY) src.height = -src.height;

        unsigned char a = (unsigned char)std::round(255.f * tile.alpha * layer.getOpacity());
        Color tint = { 255, 255, 255, a };

        // DrawTextureRec(tex, src, pos, tint);
        
        layer::QueueCommand<layer::CmdTexturePro>(layerPtr, [tex, src, pos, tint](layer::CmdTexturePro *cmd) {
            cmd->texture = tex;
            cmd->source = src;
            cmd->offsetX = pos.x;
            cmd->offsetY = pos.y;
            cmd->size = {src.width, src.height};
            cmd->rotationCenter = {0, 0};
            cmd->rotation = 0;
            cmd->color = tint;
        }, renderZLevel, layer::DrawCommandSpace::World);
        
        // layer::QueueCommand<layer::CmdTexturePro>(layerPtr, [tex, src, dst](layer::CmdTexturePro *cmd) {
        //         cmd->texture = tex;
        //         cmd->source = src;
        //         cmd->offsetX = 0;
        //         cmd->offsetY = 0;
        //         cmd->size = {dst.width, dst.height};
        //         cmd->rotationCenter = {0, 0};
        //         cmd->rotation = 0;
        //         cmd->color = WHITE;
        //     }, renderZLevel);
    }

    // EndBlendMode();
}



inline void DrawAllLayers(std::shared_ptr<layer::Layer> layerPtr, const std::string& levelName, float scale = 1.0f, const int renderZLevel = 0) {
    const auto& world = internal_loader::project.getWorld();
    const auto& level = world.getLevel(levelName);

    // background first
    DrawLevelBackground(layerPtr, level, nullptr, renderZLevel);

    for (auto it = level.allLayers().rbegin(); it != level.allLayers().rend(); ++it) {
        
        // if (it->getName() == "Default_floor")
        // if (it->getName() == "Custom_floor")
        // if (it->getName() == "Collisions")
        
        // if (it->getName() == "Wall_tops")
        DrawLayer(layerPtr, levelName, it->getName(), scale, renderZLevel);
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
    int gw = grid.getWidth(), gh = grid.getHeight();

    const auto& layerDef = internal_rule::defFile.getLayers()[layerIdx];
    auto tileset = internal_rule::defFile.getTileset(layerDef.tilesetDefUid);
    const int tileSize = tileset->tileSize;

    // allocate correct pixel dimensions
    auto& rt = internal_rule::renderer;
    if (rt.texture.id) UnloadRenderTexture(rt);
    rt = LoadRenderTexture(gw * tileSize, gh * tileSize);

    // fetch tileset texture
    std::string path = internal_rule::assetDirectory.empty() ? tileset->imagePath
                       : internal_rule::assetDirectory + "/" + tileset->imagePath;
    Texture2D& tex = internal_rule::textureCache.count(path) ? internal_rule::textureCache[path]
                         : internal_rule::textureCache[path] = LoadTexture(path.c_str());

    BeginTextureMode(rt);
    ClearBackground(BLANK); // ★ transparent

    for (int y = 0; y < gh; ++y) {
        for (int x = 0; x < gw; ++x) {
            auto& cellTiles = grid(x, y);
            if (cellTiles.empty()) continue;

            // draw ALL stacked tiles in display order
            for (const auto& t : cellTiles) {
                int16_t px, py;
                tileset->getCoordinates(t.tileId, px, py);
                Rectangle src { (float)px * tileSize, (float)py * tileSize,
                                (float)tileSize, (float)tileSize };
                Rectangle dst { (float)(x * tileSize + t.posXOffset),
                                (float)(y * tileSize + t.posYOffset),
                                (float)tileSize, (float)tileSize };
                DrawTexturePro(tex, src, dst, {0,0}, 0.0f, WHITE);
            }
        }
    }

    EndTextureMode();

    // present once, scaled
    Rectangle srcRec { 0, 0, (float)rt.texture.width, -(float)rt.texture.height };
    Rectangle dstRec { 0, 0, rt.texture.width * scale, rt.texture.height * scale };
    DrawTexturePro(rt.texture, srcRec, dstRec, {0,0}, 0.0f, WHITE);
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
