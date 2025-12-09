// testing whether ldtk_loader.hpp and ldtk_import.hpp can be fused together

#pragma once

// --- Dependencies ---
#include "third_party/ldtk_loader/src/Project.hpp"
#include "spdlog/spdlog.h"
#include "third_party/ldtkimport/include/ldtkimport/LdtkDefFile.hpp"
#include "third_party/ldtkimport/include/ldtkimport/Level.h"
#include "util/utilities.hpp"
#include "entt/entt.hpp"
#include <raylib.h>
#include "core/globals.hpp"
#include "systems/physics/physics_manager.hpp"
#include "systems/physics/physics_world.hpp"
#include "systems/physics/physics_components.hpp"
#include <string>
#include <unordered_map>
#include <memory>
#include <queue>
#include <ostream>
#include <functional>
#include <fstream>
#include <stdexcept>
#include <vector>
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

    struct ProjectConfig {
        std::string projectPath;
        std::string assetDir;
        std::vector<std::string> colliderLayers;
        std::unordered_map<std::string, std::string> entityPrefabs;
    };

    // Optional hooks to external systems
    extern ProjectConfig activeConfig;
    extern bool hasActiveProject;
    extern entt::registry* registry;
    using EntitySpawnFn = std::function<void(const ldtk::Entity&, entt::registry&)>;
    extern EntitySpawnFn entitySpawner;
    extern std::string activeLevel;
    extern std::string activePhysicsWorld;
}

// Forward decls
inline void Unload();

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

// ---------------------- Config-driven loading ----------------------
inline internal_loader::ProjectConfig LoadConfig(const std::string& path) {
    std::ifstream f(path);
    if (!f.is_open()) {
        throw std::runtime_error("LDtk config not found at " + path);
    }
    json j;
    f >> j;
    internal_loader::ProjectConfig cfg{};
    cfg.projectPath  = j.value("project_path", "");
    cfg.assetDir     = j.value("asset_dir", "");
    if (j.contains("collider_layers") && j["collider_layers"].is_array()) {
        for (const auto& v : j["collider_layers"]) cfg.colliderLayers.push_back(v.get<std::string>());
    }
    if (j.contains("entity_prefabs") && j["entity_prefabs"].is_object()) {
        for (auto it = j["entity_prefabs"].begin(); it != j["entity_prefabs"].end(); ++it) {
            cfg.entityPrefabs[it.key()] = it.value().get<std::string>();
        }
    }
    if (cfg.projectPath.empty()) {
        throw std::runtime_error("LDtk config missing required field project_path");
    }
    return cfg;
}

inline void SetRegistry(entt::registry& R) {
    internal_loader::registry = &R;
}

inline void SetEntitySpawner(internal_loader::EntitySpawnFn fn) {
    internal_loader::entitySpawner = std::move(fn);
}

inline const internal_loader::ProjectConfig& GetActiveConfig() {
    return internal_loader::activeConfig;
}

inline std::string PrefabForEntity(const std::string& entityName) {
    auto it = internal_loader::activeConfig.entityPrefabs.find(entityName);
    return (it == internal_loader::activeConfig.entityPrefabs.end()) ? std::string{} : it->second;
}

inline const std::vector<std::string>& ColliderLayers() {
    return internal_loader::activeConfig.colliderLayers;
}

inline physics::PhysicsWorld* GetPhysicsWorld(const std::string& name) {
    if (!globals::physicsManager) return nullptr;
    auto* rec = globals::physicsManager->get(name);
    return rec ? rec->w.get() : nullptr;
}

inline bool HasActiveProject() { return internal_loader::hasActiveProject; }
inline bool HasActiveLevel() { return !internal_loader::activeLevel.empty(); }
inline const std::string& GetActiveLevel() { return internal_loader::activeLevel; }
inline const std::string& GetActivePhysicsWorld() { return internal_loader::activePhysicsWorld; }

inline void LoadProjectFromConfig(const std::string& configPathRaw) {
    const std::string cfgPath = util::getRawAssetPathNoUUID(configPathRaw);
    internal_loader::activeConfig = LoadConfig(cfgPath);
    internal_loader::hasActiveProject = true;

    if (!internal_loader::activeConfig.assetDir.empty()) {
        SetAssetDirectory(internal_loader::activeConfig.assetDir);
    }
    const std::string projPath = util::getRawAssetPathNoUUID(internal_loader::activeConfig.projectPath);
    LoadProject(projPath);
}

inline void ReloadProject(const std::string& configPathRaw) {
    Unload();
    LoadProjectFromConfig(configPathRaw);
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
        layerPtr, [scx, scy, scw, sch](layer::CmdBeginScissorMode* cmd){
            cmd->area = Rectangle{(float)scx, (float)scy, (float)scw, (float)sch};
        }, renderZLevel, layer::DrawCommandSpace::World
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
                Rectangle dst{ x, y, tileW, tileH };
                layer::QueueCommand<layer::CmdTexturePro>(layerPtr, [tex, src, dst](layer::CmdTexturePro *cmd) {
                    cmd->texture = tex;
                    cmd->source = src;
                    cmd->offsetX = dst.x;
                    cmd->offsetY = dst.y;
                    cmd->size = {dst.width, dst.height};
                    cmd->rotationCenter = {0, 0};
                    cmd->rotation = 0;
                    cmd->color = WHITE;
                }, renderZLevel, layer::DrawCommandSpace::World);
            }
        }
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
    layer::QueueCommand<layer::CmdTexturePro>(layerPtr, [tex, src, dst](layer::CmdTexturePro *cmd) {
        cmd->texture = tex;
        cmd->source = src;
        cmd->offsetX = dst.x;
        cmd->offsetY = dst.y;
        cmd->size = {dst.width, dst.height};
        cmd->rotationCenter = {0, 0};
        cmd->rotation = 0;
        cmd->color = WHITE;
    }, renderZLevel, layer::DrawCommandSpace::World);
    
    layer::QueueCommand<layer::CmdEndScissorMode>(
        layerPtr, [](layer::CmdEndScissorMode*){}, renderZLevel, layer::DrawCommandSpace::World
    );
}

inline bool RectsOverlap(const Rectangle& a, const Rectangle& b) {
    return !(a.x > b.x + b.width || a.x + a.width < b.x ||
             a.y > b.y + b.height || a.y + a.height < b.y);
}

struct EntitySpawnInfo {
    std::string name;
    std::string layer;
    Vector2 position; // pixels
    ldtk::IntPoint grid;    // grid coords
};

struct LDTKColliderTag {
    std::string level;
    std::string layer;
};

inline void DrawLayer(std::shared_ptr<layer::Layer> layerPtr, const std::string& levelName, const std::string& layerName, float scale = 1.0f, const int renderZLevel = 0, const Rectangle* viewOpt = nullptr) {
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

        Rectangle dstRect{pos.x, pos.y, src.width, src.height};
        if (viewOpt && !RectsOverlap(dstRect, *viewOpt)) {
            continue;
        }

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



inline void DrawAllLayers(std::shared_ptr<layer::Layer> layerPtr, const std::string& levelName, float scale = 1.0f, const int renderZLevel = 0, const Rectangle* viewOpt = nullptr) {
    const auto& world = internal_loader::project.getWorld();
    const auto& level = world.getLevel(levelName);

    // background first
    DrawLevelBackground(layerPtr, level, nullptr, renderZLevel);

    for (auto it = level.allLayers().rbegin(); it != level.allLayers().rend(); ++it) {
        
        // if (it->getName() == "Default_floor")
        // if (it->getName() == "Custom_floor")
        // if (it->getName() == "Collisions")
        
        // if (it->getName() == "Wall_tops")
        DrawLayer(layerPtr, levelName, it->getName(), scale, renderZLevel, viewOpt);
    }
}

inline void ForEachEntity(const std::string& levelName, const std::function<void(const EntitySpawnInfo&)>& fn) {
    const auto& world = internal_loader::project.getWorld();
    const auto& level = world.getLevel(levelName);
    for (const auto& layer : level.allLayers()) {
        for (const auto& ent : layer.allEntities()) {
            EntitySpawnInfo info;
            info.name   = ent.getName();
            info.layer  = layer.getName();
            info.position = { (float)ent.getPosition().x, (float)ent.getPosition().y };
            info.grid   = ent.getGridPosition();
            fn(info);
        }
    }
}

inline void SpawnEntities(const std::string& levelName) {
    if (!internal_loader::entitySpawner || !internal_loader::registry) return;
    const auto& world = internal_loader::project.getWorld();
    const auto& level = world.getLevel(levelName);
    for (const auto& layer : level.allLayers()) {
        for (const auto& ent : layer.allEntities()) {
            internal_loader::entitySpawner(ent, *internal_loader::registry);
        }
    }
}

inline void ForEachIntGrid(const std::string& levelName,
                           const std::string& layerName,
                           const std::function<void(int x, int y, int value)>& fn) {
    const auto& world = internal_loader::project.getWorld();
    const auto& level = world.getLevel(levelName);
    const auto& layer = level.getLayer(layerName);
    const int w = layer.getGridSize().x;
    const int h = layer.getGridSize().y;
    for (int y = 0; y < h; ++y) {
        for (int x = 0; x < w; ++x) {
            const auto& val = layer.getIntGridVal(x, y);
            fn(x, y, val.value);
        }
    }
}

// -------------------- Physics helpers --------------------
inline void ClearCollidersForLevel(const std::string& levelName, physics::PhysicsWorld& world) {
    auto* R = internal_loader::registry;
    if (!R) return;
    auto view = R->view<LDTKColliderTag, physics::ColliderComponent>();
    std::vector<entt::entity> toDelete;
    for (auto e : view) {
        const auto& tag = view.get<LDTKColliderTag>(e);
        if (tag.level != levelName) continue;
        toDelete.push_back(e);
    }
    for (auto e : toDelete) {
        world.ClearAllShapes(e);
        R->destroy(e);
    }
}

inline void ClearCollidersForLevel(const std::string& levelName, const std::string& worldName) {
    if (auto* world = GetPhysicsWorld(worldName)) {
        ClearCollidersForLevel(levelName, *world);
        if (globals::physicsManager) {
            globals::physicsManager->markNavmeshDirty(worldName);
        }
    }
}

inline void BuildCollidersForLevel(const std::string& levelName,
                                   physics::PhysicsWorld& world,
                                   const std::string& worldName,
                                   const std::string& physicsTag = "WORLD") {
    auto* R = internal_loader::registry;
    if (!R) {
        spdlog::warn("LDtk BuildCollidersForLevel: registry not set");
        return;
    }
    const auto& cfg = internal_loader::activeConfig;
    const auto& lworld = internal_loader::project.getWorld();
    const auto& level = lworld.getLevel(levelName);

    ClearCollidersForLevel(levelName, world);

    for (const auto& layerName : cfg.colliderLayers) {
        const ldtk::Layer* target = nullptr;
        for (const auto& l : level.allLayers()) {
            if (l.getName() == layerName) { target = &l; break; }
        }
        if (!target) {
            spdlog::warn("LDtk collider layer '{}' not found in level '{}'", layerName, levelName);
            continue;
        }
        const auto& layer = *target;
        const int cell = layer.getCellSize();
        const auto offset = layer.getOffset();
        const auto grid = layer.getGridSize();

        // Only IntGrid for now; treat non-zero as solid
        if (layer.getType() != ldtk::LayerType::IntGrid) continue;

        for (int y = 0; y < grid.y; ++y) {
            int x = 0;
            while (x < grid.x) {
                const int val = layer.getIntGridVal(x, y).value;
                if (val == 0) { ++x; continue; }

                int runStart = x;
                int runEnd = x;
                while (runEnd + 1 < grid.x && layer.getIntGridVal(runEnd + 1, y).value != 0) {
                    ++runEnd;
                }
                const int runLen = (runEnd - runStart) + 1;

                float w = (float)(runLen * cell);
                float h = (float)cell;
                float cx = (float)offset.x + runStart * cell + w * 0.5f;
                float cy = (float)offset.y + y * cell + h * 0.5f;

                entt::entity e = R->create();
                R->emplace<PhysicsWorldRef>(e, worldName);
                R->emplace<PhysicsLayer>(e, physicsTag);
                R->emplace<LDTKColliderTag>(e, LDTKColliderTag{levelName, layerName});

                world.AddCollider(e, physicsTag, "rectangle", w, h, -1, -1, false);
                world.SetBodyPosition(e, cx, cy);

                x = runEnd + 1;
            }
        }
    }

    if (globals::physicsManager) {
        globals::physicsManager->markNavmeshDirty(worldName);
    }
}

inline void BuildCollidersForLevel(const std::string& levelName,
                                   const std::string& worldName,
                                   const std::string& physicsTag = "WORLD") {
    if (auto* world = GetPhysicsWorld(worldName)) {
        BuildCollidersForLevel(levelName, *world, worldName, physicsTag);
    }
}

inline void SpawnEntitiesForLevel(const std::string& levelName) {
    if (!internal_loader::entitySpawner || !internal_loader::registry) {
        spdlog::warn("LDtk SpawnEntitiesForLevel: spawner or registry not set");
        return;
    }
    SpawnEntities(levelName);
}

inline Rectangle CameraViewRect(const Camera2D& cam, float viewportW, float viewportH, float padding = 0.0f) {
    const float zoom = (cam.zoom == 0.0f) ? 1.0f : cam.zoom;
    const float w = viewportW / zoom + padding * 2.0f;
    const float h = viewportH / zoom + padding * 2.0f;
    return Rectangle{
        cam.target.x - w * 0.5f,
        cam.target.y - h * 0.5f,
        w,
        h
    };
}

inline void SetActiveLevel(const std::string& levelName,
                           const std::string& worldName,
                           bool rebuildColliders = true,
                           bool spawnEntities = true,
                           const std::string& physicsTag = "WORLD") {
    if (!internal_loader::registry) {
        spdlog::warn("LDtk SetActiveLevel: registry not set, call ldtk.load_config first");
        return;
    }
    if (HasActiveLevel() && !internal_loader::activePhysicsWorld.empty()) {
        ClearCollidersForLevel(internal_loader::activeLevel, internal_loader::activePhysicsWorld);
    }
    internal_loader::activeLevel = levelName;
    internal_loader::activePhysicsWorld = worldName;
    if (rebuildColliders) {
        BuildCollidersForLevel(levelName, worldName, physicsTag);
    }
    if (spawnEntities) {
        SpawnEntitiesForLevel(levelName);
    }
}

inline void Unload() {
    for (auto& kv : internal_loader::tilesetCache) {
        UnloadTexture(kv.second.texture);
    }
    internal_loader::tilesetCache.clear();
    auto& rt = internal_loader::renderTexture;
    if (rt.texture.id) UnloadRenderTexture(rt);
    internal_loader::hasActiveProject = false;
    internal_loader::activeConfig = internal_loader::ProjectConfig{};
    internal_loader::activeLevel.clear();
    internal_loader::activePhysicsWorld.clear();
}
inline size_t GetCachedTilesetCount() {
    return internal_loader::tilesetCache.size();
}

// -------------------- Level Query Helpers --------------------

struct LevelBounds {
    float x, y, width, height;
};

inline LevelBounds GetLevelBounds(const std::string& levelName) {
    const auto& world = internal_loader::project.getWorld();
    const auto& level = world.getLevel(levelName);
    return LevelBounds{
        (float)level.position.x,
        (float)level.position.y,
        (float)level.size.x,
        (float)level.size.y
    };
}

struct LevelMeta {
    int width, height;
    int world_x, world_y;
    int depth;
    ldtk::Color bg_color;
};

inline LevelMeta GetLevelMeta(const std::string& levelName) {
    const auto& world = internal_loader::project.getWorld();
    const auto& level = world.getLevel(levelName);
    return LevelMeta{
        level.size.x,
        level.size.y,
        level.position.x,
        level.position.y,
        level.depth,
        level.bg_color
    };
}

inline bool LevelExists(const std::string& levelName) {
    try {
        const auto& world = internal_loader::project.getWorld();
        world.getLevel(levelName);
        return true;
    } catch (...) {
        return false;
    }
}

struct NeighborData {
    std::string north;
    std::string south;
    std::string east;
    std::string west;
    std::vector<std::string> overlap;
};

inline NeighborData GetNeighbors(const std::string& levelName) {
    const auto& world = internal_loader::project.getWorld();
    const auto& level = world.getLevel(levelName);

    NeighborData result;

    auto getFirst = [](const std::vector<const ldtk::Level*>& vec) -> std::string {
        return vec.empty() ? "" : vec[0]->name;
    };

    result.north = getFirst(level.getNeighbours(ldtk::Dir::North));
    result.south = getFirst(level.getNeighbours(ldtk::Dir::South));
    result.east = getFirst(level.getNeighbours(ldtk::Dir::East));
    result.west = getFirst(level.getNeighbours(ldtk::Dir::West));

    for (const auto* neighbor : level.getNeighbours(ldtk::Dir::Overlap)) {
        result.overlap.push_back(neighbor->name);
    }

    return result;
}

// -------------------- Entity Query Helpers --------------------

struct EntityInfo {
    std::string name;
    std::string iid;
    float x, y;
    int grid_x, grid_y;
    int width, height;
    std::string layer;
    std::vector<std::string> tags;
};

inline std::vector<EntityInfo> GetEntitiesByName(const std::string& levelName, const std::string& entityName) {
    std::vector<EntityInfo> result;
    const auto& world = internal_loader::project.getWorld();
    const auto& level = world.getLevel(levelName);

    for (const auto& layer : level.allLayers()) {
        for (const auto& ent : layer.allEntities()) {
            if (ent.getName() == entityName) {
                EntityInfo info;
                info.name = ent.getName();
                info.iid = ent.iid.str();
                info.x = (float)ent.getPosition().x;
                info.y = (float)ent.getPosition().y;
                info.grid_x = ent.getGridPosition().x;
                info.grid_y = ent.getGridPosition().y;
                info.width = ent.getSize().x;
                info.height = ent.getSize().y;
                info.layer = layer.getName();
                info.tags = ent.getTags();
                result.push_back(info);
            }
        }
    }
    return result;
}

struct EntityPosition {
    float x, y;
    bool found;
};

inline EntityPosition GetEntityPositionByIID(const std::string& levelName, const std::string& iid) {
    const auto& world = internal_loader::project.getWorld();
    const auto& level = world.getLevel(levelName);

    for (const auto& layer : level.allLayers()) {
        for (const auto& ent : layer.allEntities()) {
            if (ent.iid.str() == iid) {
                return EntityPosition{
                    (float)ent.getPosition().x,
                    (float)ent.getPosition().y,
                    true
                };
            }
        }
    }
    return EntityPosition{0, 0, false};
}

// Get raw Entity reference for field extraction (used by Lua bindings)
inline const ldtk::Entity* GetEntityByIID(const std::string& levelName, const std::string& iid) {
    const auto& world = internal_loader::project.getWorld();
    const auto& level = world.getLevel(levelName);

    for (const auto& layer : level.allLayers()) {
        for (const auto& ent : layer.allEntities()) {
            if (ent.iid.str() == iid) {
                return &ent;
            }
        }
    }
    return nullptr;
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

// -------------------- Lua-friendly Rule Runner API --------------------

// Managed Level for procedural generation from Lua
namespace internal_rule {
    extern std::unique_ptr<Level> managedLevel;
}

// Create a Level from dimensions and IntGrid values
inline void CreateLevelFromIntGrid(int width, int height, const std::vector<int>& cells) {
    if (!internal_rule::managedLevel) {
        internal_rule::managedLevel = std::make_unique<Level>();
    }

    // Convert int vector to intgridvalue_t vector
    std::vector<intgridvalue_t> values;
    values.reserve(cells.size());
    for (int v : cells) {
        values.push_back(static_cast<intgridvalue_t>(v));
    }

    internal_rule::managedLevel->setIntGrid(
        static_cast<dimensions_t>(width),
        static_cast<dimensions_t>(height),
        std::move(values)
    );

    // Point internal level pointer to managed level
    internal_rule::levelPtr = internal_rule::managedLevel.get();
}

// Set IntGrid cell value
inline void SetIntGridCell(int x, int y, int value) {
    if (!internal_rule::managedLevel) {
        throw std::runtime_error("No managed level created - call CreateLevelFromIntGrid first");
    }
    internal_rule::managedLevel->setIntGrid(x, y, static_cast<intgridvalue_t>(value));
}

// Get number of layers defined in the LDtk project
inline size_t GetLayerCount() {
    return internal_rule::defFile.getLayers().size();
}

// Get layer name by index
inline std::string GetLayerName(int layerIdx) {
    const auto& layers = internal_rule::defFile.getLayers();
    if (layerIdx < 0 || layerIdx >= static_cast<int>(layers.size())) {
        return "";
    }
    return layers[layerIdx].name;
}

// Find layer index by name
inline int GetLayerIndex(const std::string& layerName) {
    const auto& layers = internal_rule::defFile.getLayers();
    for (size_t i = 0; i < layers.size(); ++i) {
        if (layers[i].name == layerName) {
            return static_cast<int>(i);
        }
    }
    return -1;
}

// Structure for tile result
struct TileResult {
    int tile_id;
    bool flip_x;
    bool flip_y;
    float alpha;
    int offset_x;
    int offset_y;
};

// Get tile results for a specific cell
inline std::vector<TileResult> GetTileResultsAt(int layerIdx, int x, int y) {
    std::vector<TileResult> results;

    if (!internal_rule::levelPtr) return results;
    if (layerIdx < 0 || layerIdx >= static_cast<int>(internal_rule::levelPtr->getTileGridCount())) {
        return results;
    }

    auto& grid = internal_rule::levelPtr->getTileGridByIdx(layerIdx);
    // Check bounds manually
    if (x < 0 || x >= grid.getWidth() || y < 0 || y >= grid.getHeight()) return results;

    const auto& tiles = grid(x, y);
    for (const auto& t : tiles) {
        TileResult r;
        r.tile_id = t.tileId;
        r.flip_x = ldtkimport::TileFlags::isFlippedX(t.flags);
        r.flip_y = ldtkimport::TileFlags::isFlippedY(t.flags);
        r.alpha = t.opacity / 100.0f; // Convert from 0-100 to 0.0-1.0
        r.offset_x = t.posXOffset;
        r.offset_y = t.posYOffset;
        results.push_back(r);
    }

    return results;
}

// Run rules and ensure tile grids are set up
inline void RunRulesForLevel(const std::string& layerName) {
    if (!internal_rule::managedLevel) {
        throw std::runtime_error("No managed level - call CreateLevelFromIntGrid first");
    }

    // Find the layer index
    int layerIdx = GetLayerIndex(layerName);
    if (layerIdx < 0) {
        throw std::runtime_error("Layer not found: " + layerName);
    }

    // Ensure we have enough tile grids
    size_t layerCount = internal_rule::defFile.getLayers().size();
    internal_rule::managedLevel->setTileGridCount(layerCount);

    // Set layer UID for each tile grid
    for (size_t i = 0; i < layerCount; ++i) {
        internal_rule::managedLevel->getTileGridByIdx(i).setLayerUid(
            internal_rule::defFile.getLayers()[i].uid
        );
    }

    // Run the rules
    RunRules(0);
}

// Get all tile results for a layer as a flat structure
struct LayerTileResults {
    int width;
    int height;
    std::vector<std::vector<TileResult>> cells; // One vector per cell
};

inline LayerTileResults GetAllTileResults(int layerIdx) {
    LayerTileResults results;
    results.width = 0;
    results.height = 0;

    if (!internal_rule::levelPtr) return results;
    if (layerIdx < 0 || layerIdx >= static_cast<int>(internal_rule::levelPtr->getTileGridCount())) {
        return results;
    }

    auto& grid = internal_rule::levelPtr->getTileGridByIdx(layerIdx);
    results.width = grid.getWidth();
    results.height = grid.getHeight();
    results.cells.reserve(results.width * results.height);

    for (int y = 0; y < results.height; ++y) {
        for (int x = 0; x < results.width; ++x) {
            results.cells.push_back(GetTileResultsAt(layerIdx, x, y));
        }
    }

    return results;
}

// Clean up managed level
inline void CleanupManagedLevel() {
    internal_rule::managedLevel.reset();
    internal_rule::levelPtr = nullptr;
}

// -------------------- Command Buffer Rendering for Procedural Tiles --------------------

// Draw procedural tile grid layer to a command buffer layer
// Uses the same pattern as ldtk_loader::DrawLayer but for procedurally generated tiles
inline void DrawProceduralLayer(
    std::shared_ptr<layer::Layer> layerPtr,
    int layerIdx,
    float offsetX = 0.0f,
    float offsetY = 0.0f,
    int renderZLevel = 0,
    const Rectangle* viewOpt = nullptr,
    float opacity = 1.0f)
{
    if (!internal_rule::levelPtr) {
        spdlog::warn("DrawProceduralLayer: No managed level - call apply_rules first");
        return;
    }

    if (layerIdx < 0 || layerIdx >= static_cast<int>(internal_rule::levelPtr->getTileGridCount())) {
        spdlog::warn("DrawProceduralLayer: Invalid layer index {}", layerIdx);
        return;
    }

    // Get layer definition and tileset
    const auto& layers = internal_rule::defFile.getLayers();
    if (layerIdx >= static_cast<int>(layers.size())) {
        spdlog::warn("DrawProceduralLayer: Layer index {} out of range", layerIdx);
        return;
    }

    const auto& layerDef = layers[layerIdx];
    auto* tileset = internal_rule::defFile.getTileset(layerDef.tilesetDefUid);
    if (!tileset) {
        spdlog::warn("DrawProceduralLayer: No tileset for layer {}", layerIdx);
        return;
    }

    const int tileSize = tileset->tileSize;

    // Load tileset texture (use cache)
    std::string path = internal_rule::assetDirectory.empty()
                       ? tileset->imagePath
                       : internal_rule::assetDirectory + "/" + tileset->imagePath;

    if (!internal_rule::textureCache.count(path)) {
        internal_rule::textureCache[path] = LoadTexture(util::getAssetPathUUIDVersion(path).c_str());
    }
    const Texture2D& tex = internal_rule::textureCache[path];

    // Get the tile grid
    auto& grid = internal_rule::levelPtr->getTileGridByIdx(layerIdx);
    int gw = grid.getWidth();
    int gh = grid.getHeight();

    // Iterate all cells and queue draw commands
    for (int y = 0; y < gh; ++y) {
        for (int x = 0; x < gw; ++x) {
            const auto& cellTiles = grid(x, y);
            if (cellTiles.empty()) continue;

            // Draw all stacked tiles in the cell
            for (const auto& t : cellTiles) {
                // Calculate source rectangle from tile ID
                int16_t srcX, srcY;
                tileset->getCoordinates(t.tileId, srcX, srcY);

                Rectangle src {
                    static_cast<float>(srcX * tileSize),
                    static_cast<float>(srcY * tileSize),
                    static_cast<float>(tileSize),
                    static_cast<float>(tileSize)
                };

                // Calculate destination position
                float posX = offsetX + x * tileSize + t.posXOffset;
                float posY = offsetY + y * tileSize + t.posYOffset;

                // Frustum culling
                if (viewOpt) {
                    Rectangle dstRect{posX, posY, static_cast<float>(tileSize), static_cast<float>(tileSize)};
                    if (!ldtk_loader::RectsOverlap(dstRect, *viewOpt)) {
                        continue;
                    }
                }

                // Handle flip flags
                if (ldtkimport::TileFlags::isFlippedX(t.flags)) src.width = -src.width;
                if (ldtkimport::TileFlags::isFlippedY(t.flags)) src.height = -src.height;

                // Calculate alpha (opacity from tile and layer)
                float tileAlpha = t.opacity / 100.0f;
                unsigned char a = static_cast<unsigned char>(std::round(255.f * tileAlpha * opacity));
                Color tint = { 255, 255, 255, a };

                // Queue the draw command
                layer::QueueCommand<layer::CmdTexturePro>(layerPtr,
                    [tex, src, posX, posY, tileSize, tint](layer::CmdTexturePro* cmd) {
                        cmd->texture = tex;
                        cmd->source = src;
                        cmd->offsetX = posX;
                        cmd->offsetY = posY;
                        cmd->size = {static_cast<float>(tileSize), static_cast<float>(tileSize)};
                        cmd->rotationCenter = {0, 0};
                        cmd->rotation = 0;
                        cmd->color = tint;
                    }, renderZLevel, layer::DrawCommandSpace::World);
            }
        }
    }
}

// Draw all procedural layers (in correct order for proper z-ordering)
inline void DrawAllProceduralLayers(
    std::shared_ptr<layer::Layer> layerPtr,
    float offsetX = 0.0f,
    float offsetY = 0.0f,
    int baseZLevel = 0,
    const Rectangle* viewOpt = nullptr,
    float opacity = 1.0f)
{
    if (!internal_rule::levelPtr) return;

    size_t layerCount = internal_rule::levelPtr->getTileGridCount();

    // Draw layers in reverse order (back to front, like normal LDTK rendering)
    for (int i = static_cast<int>(layerCount) - 1; i >= 0; --i) {
        DrawProceduralLayer(layerPtr, i, offsetX, offsetY, baseZLevel + i, viewOpt, opacity);
    }
}

// Get tileset info for a layer (useful for Lua to know tile size)
struct TilesetInfo {
    int tileSize;
    int width;  // in pixels
    int height; // in pixels
    std::string imagePath;
};

inline TilesetInfo GetTilesetInfoForLayer(int layerIdx) {
    TilesetInfo info{0, 0, 0, ""};

    const auto& layers = internal_rule::defFile.getLayers();
    if (layerIdx < 0 || layerIdx >= static_cast<int>(layers.size())) {
        return info;
    }

    auto* tileset = internal_rule::defFile.getTileset(layers[layerIdx].tilesetDefUid);
    if (!tileset) return info;

    info.tileSize = tileset->tileSize;
    info.width = tileset->imageWidth;
    info.height = tileset->imageHeight;
    info.imagePath = tileset->imagePath;
    return info;
}

} // namespace ldtk_rule_import
