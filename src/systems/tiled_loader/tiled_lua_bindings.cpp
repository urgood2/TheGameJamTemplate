#include "tiled_loader.hpp"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <filesystem>
#include <functional>
#include <memory>
#include <optional>
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

#include "core/game.hpp"
#include "core/globals.hpp"
#include "sol/sol.hpp"
#include "systems/layer/layer.hpp"
#include "systems/physics/physics_components.hpp"
#include "systems/physics/physics_manager.hpp"
#include "systems/scripting/binding_recorder.hpp"
#include "util/utilities.hpp"

namespace tiled_loader {
namespace {

sol::function g_objectSpawner;
std::vector<entt::entity> g_generatedGridColliderEntities;
std::unordered_map<std::string, Texture2D> g_tilesetTextureCache;

std::filesystem::path ResolveAssetPath(const std::string& pathLike);

struct TileDrawOptions {
    std::string mapId;
    int baseZ = 0;
    int layerZStep = 1;
    int zPerRow = 1;
    float offsetX = 0.0f;
    float offsetY = 0.0f;
    float opacity = 1.0f;
    bool ySorted = false;
};

void ClearTilesetTextureCache() {
    for (auto& kv : g_tilesetTextureCache) {
        if (kv.second.id > 0) {
            UnloadTexture(kv.second);
        }
    }
    g_tilesetTextureCache.clear();
}

Texture2D ResolveTilesetTextureOrThrow(const TilesetData& tileset) {
    std::filesystem::path imagePath = tileset.resolvedImagePath;
    if (!imagePath.empty() && !std::filesystem::exists(imagePath)) {
        imagePath = ResolveAssetPath(imagePath.string());
    }
    if (imagePath.empty() || !std::filesystem::exists(imagePath)) {
        if (!tileset.image.empty()) {
            imagePath = ResolveAssetPath(tileset.image);
        }
    }
    if (imagePath.empty() || !std::filesystem::exists(imagePath)) {
        throw std::runtime_error("Unable to resolve Tiled tileset image for '" + tileset.name + "'");
    }

    const std::string key = imagePath.lexically_normal().string();
    const auto it = g_tilesetTextureCache.find(key);
    if (it != g_tilesetTextureCache.end()) {
        return it->second;
    }

    Texture2D loaded = LoadTexture(key.c_str());
    if (loaded.id == 0) {
        throw std::runtime_error("Failed to load Tiled tileset texture: " + key);
    }
    SetTextureFilter(loaded, TEXTURE_FILTER_POINT);
    g_tilesetTextureCache.emplace(key, loaded);
    return loaded;
}

TileDrawOptions TileDrawOptionsFromLua(sol::optional<sol::table> opts) {
    TileDrawOptions out{};
    if (!opts.has_value()) {
        return out;
    }

    const sol::table table = *opts;
    out.mapId = table.get_or("map_id", std::string{});
    out.baseZ = table.get_or("base_z", 0);
    out.layerZStep = table.get_or("layer_z_step", 1);
    out.zPerRow = table.get_or("z_per_row", 1);
    out.offsetX = table.get_or("offset_x", 0.0f);
    out.offsetY = table.get_or("offset_y", 0.0f);
    out.opacity = table.get_or("opacity", 1.0f);
    out.opacity = std::clamp(out.opacity, 0.0f, 1.0f);
    return out;
}

uint8_t OpacityToByte(float opacity) {
    const float clamped = std::clamp(opacity, 0.0f, 1.0f);
    return static_cast<uint8_t>(std::lround(clamped * 255.0f));
}

void QueueTileCommand(const std::shared_ptr<layer::Layer>& drawLayer, const MapData& map, uint32_t rawGid, float tileX,
                      float tileY, float opacity, int layerZ, const TileDrawOptions& options, int* queuedCount) {
    if (rawGid == 0u) {
        return;
    }

    const DecodedGid decoded = DecodeGid(rawGid);
    if (decoded.tileId == 0u) {
        return;
    }

    ResolvedTileSource source{};
    std::string resolveErr;
    if (!ResolveTileSource(map, decoded.tileId, &source, &resolveErr)) {
        throw std::runtime_error("Failed to resolve tile source for gid " + std::to_string(rawGid) + ": " + resolveErr);
    }

    if (source.tilesetIndex >= map.tilesets.size()) {
        throw std::runtime_error("Resolved tile source references an out-of-range tileset index");
    }
    const TilesetData& tileset = map.tilesets[source.tilesetIndex];
    const Texture2D texture = ResolveTilesetTextureOrThrow(tileset);

    const TileTransform transform = OrthogonalTransformFromFlags(decoded.flags);
    Rectangle src{static_cast<float>(source.sourceX), static_cast<float>(source.sourceY),
                  static_cast<float>(source.sourceWidth), static_cast<float>(source.sourceHeight)};
    if (transform.flipX) {
        src.width = -src.width;
    }
    if (transform.flipY) {
        src.height = -src.height;
    }

    const int mapTileW = (map.tileWidth > 0) ? map.tileWidth : source.sourceWidth;
    const int mapTileH = (map.tileHeight > 0) ? map.tileHeight : source.sourceHeight;

    const float worldX = options.offsetX + tileX * static_cast<float>(mapTileW);
    const float worldY =
        options.offsetY + (tileY + 1.0f) * static_cast<float>(mapTileH) - static_cast<float>(source.sourceHeight);
    const Vector2 size{static_cast<float>(source.sourceWidth), static_cast<float>(source.sourceHeight)};
    const float rotation = static_cast<float>(transform.rotationDegrees);
    const Vector2 rotationCenter =
        (rotation == 0.0f) ? Vector2{0.0f, 0.0f} : Vector2{size.x * 0.5f, size.y * 0.5f};

    int drawZ = layerZ;
    if (options.ySorted) {
        drawZ += static_cast<int>(std::floor(tileY)) * options.zPerRow;
    }

    const Color tint{255, 255, 255, OpacityToByte(opacity)};
    layer::QueueCommand<layer::CmdTexturePro>(
        drawLayer,
        [texture, src, worldX, worldY, size, rotationCenter, rotation, tint](layer::CmdTexturePro* cmd) {
            cmd->texture = texture;
            cmd->source = src;
            cmd->offsetX = worldX;
            cmd->offsetY = worldY;
            cmd->size = size;
            cmd->rotationCenter = rotationCenter;
            cmd->rotation = rotation;
            cmd->color = tint;
        },
        drawZ, layer::DrawCommandSpace::World);

    if (queuedCount != nullptr) {
        ++(*queuedCount);
    }
}

void DrawTileLayer(const std::shared_ptr<layer::Layer>& drawLayer, const MapData& map, const LayerData& layer,
                   const TileLayerData& tileLayer, float originTileX, float originTileY, float opacity, int layerZ,
                   const TileDrawOptions& options, int* queuedCount) {
    const float layerTileX = originTileX + static_cast<float>(tileLayer.x);
    const float layerTileY = originTileY + static_cast<float>(tileLayer.y);

    if (!tileLayer.chunks.empty()) {
        for (const auto& chunk : tileLayer.chunks) {
            if (chunk.width <= 0 || chunk.height <= 0) {
                continue;
            }
            const size_t chunkCellCount = static_cast<size_t>(chunk.width) * static_cast<size_t>(chunk.height);
            for (int y = 0; y < chunk.height; ++y) {
                for (int x = 0; x < chunk.width; ++x) {
                    const size_t idx = static_cast<size_t>(y) * static_cast<size_t>(chunk.width) +
                                       static_cast<size_t>(x);
                    if (idx >= chunkCellCount || idx >= chunk.gids.size()) {
                        continue;
                    }
                    const float worldTileX = layerTileX + static_cast<float>(chunk.x + x);
                    const float worldTileY = layerTileY + static_cast<float>(chunk.y + y);
                    QueueTileCommand(drawLayer, map, chunk.gids[idx], worldTileX, worldTileY, opacity, layerZ, options,
                                     queuedCount);
                }
            }
        }
        return;
    }

    const int width = (tileLayer.width > 0) ? tileLayer.width : layer.width;
    const int height = (tileLayer.height > 0) ? tileLayer.height : layer.height;
    if (width <= 0 || height <= 0) {
        return;
    }

    const size_t expected = static_cast<size_t>(width) * static_cast<size_t>(height);
    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            const size_t idx = static_cast<size_t>(y) * static_cast<size_t>(width) + static_cast<size_t>(x);
            if (idx >= expected || idx >= tileLayer.gids.size()) {
                continue;
            }
            const float worldTileX = layerTileX + static_cast<float>(x);
            const float worldTileY = layerTileY + static_cast<float>(y);
            QueueTileCommand(drawLayer, map, tileLayer.gids[idx], worldTileX, worldTileY, opacity, layerZ, options,
                             queuedCount);
        }
    }
}

void DrawLayerTree(const std::shared_ptr<layer::Layer>& drawLayer, const MapData& map, const LayerData& layer,
                   const std::optional<std::string>& targetMapLayerName, float parentTileX, float parentTileY,
                   float parentOpacity, int* nextTileLayerIndex, int* queuedCount, const TileDrawOptions& options) {
    if (!layer.visible) {
        return;
    }

    const float thisTileX = parentTileX + static_cast<float>(layer.x);
    const float thisTileY = parentTileY + static_cast<float>(layer.y);
    const float thisOpacity = std::clamp(parentOpacity * layer.opacity, 0.0f, 1.0f);

    if (layer.type == LayerType::TileLayer && layer.tileLayer.has_value()) {
        const int thisLayerIndex = *nextTileLayerIndex;
        ++(*nextTileLayerIndex);

        const bool nameMatches = !targetMapLayerName.has_value() || layer.name == *targetMapLayerName;
        if (nameMatches && thisOpacity > 0.0f) {
            const int layerZ = options.baseZ + thisLayerIndex * options.layerZStep;
            DrawTileLayer(drawLayer, map, layer, *layer.tileLayer, thisTileX, thisTileY, thisOpacity, layerZ, options,
                          queuedCount);
        }
    }

    for (const auto& child : layer.children) {
        DrawLayerTree(drawLayer, map, child, targetMapLayerName, thisTileX, thisTileY, thisOpacity, nextTileLayerIndex,
                      queuedCount, options);
    }
}

int DrawMapTileLayers(const std::string& targetLayerName, const std::optional<std::string>& targetMapLayerName,
                      const TileDrawOptions& options) {
    const std::string mapId = ResolveMapIdOrThrow(options.mapId);
    const MapData* map = GetMap(mapId);
    if (map == nullptr) {
        throw std::runtime_error("Map was resolved but no longer exists: " + mapId);
    }
    if (map->orientation != "orthogonal") {
        throw std::runtime_error("tiled draw supports only orthogonal maps in v1; map '" + mapId +
                                 "' has orientation '" + map->orientation + "'");
    }
    if (map->tileWidth <= 0 || map->tileHeight <= 0) {
        throw std::runtime_error("Map '" + mapId + "' has invalid tile dimensions");
    }

    const std::shared_ptr<layer::Layer> drawLayer = game::GetLayer(targetLayerName);
    if (!drawLayer) {
        throw std::runtime_error("Unknown render layer: " + targetLayerName);
    }

    int nextTileLayerIndex = 0;
    int queuedCount = 0;
    for (const auto& layer : map->layers) {
        DrawLayerTree(drawLayer, *map, layer, targetMapLayerName, 0.0f, 0.0f, options.opacity, &nextTileLayerIndex,
                      &queuedCount, options);
    }
    return queuedCount;
}

std::filesystem::path ResolveAssetPath(const std::string& pathLike) {
    std::filesystem::path direct{pathLike};
    if (std::filesystem::exists(direct)) {
        return direct;
    }

    const std::string resolved = util::getRawAssetPathNoUUID(pathLike);
    if (!resolved.empty()) {
        std::filesystem::path resolvedPath{resolved};
        if (std::filesystem::exists(resolvedPath)) {
            return resolvedPath;
        }
    }

    return direct;
}

GridInput GridFromLua(sol::table gridTable) {
    GridInput grid{};
    grid.width = gridTable.get_or("width", 0);
    grid.height = gridTable.get_or("height", 0);

    sol::table cells = gridTable.get_or("cells", sol::table());
    const int expectedCount = (grid.width > 0 && grid.height > 0) ? (grid.width * grid.height) : 0;
    grid.cells.reserve(static_cast<size_t>(expectedCount > 0 ? expectedCount : 0));
    for (int i = 1; i <= expectedCount; ++i) {
        grid.cells.push_back(cells.get_or(i, 0));
    }

    return grid;
}

sol::object PropertyValueToLua(sol::state_view lua, const PropertyValue& value) {
    if (std::holds_alternative<std::monostate>(value)) {
        return sol::make_object(lua, sol::lua_nil);
    }
    if (std::holds_alternative<bool>(value)) {
        return sol::make_object(lua, std::get<bool>(value));
    }
    if (std::holds_alternative<int64_t>(value)) {
        return sol::make_object(lua, std::get<int64_t>(value));
    }
    if (std::holds_alternative<double>(value)) {
        return sol::make_object(lua, std::get<double>(value));
    }
    if (std::holds_alternative<std::string>(value)) {
        return sol::make_object(lua, std::get<std::string>(value));
    }
    return sol::make_object(lua, sol::lua_nil);
}

sol::table PropertiesToLua(sol::state_view lua, const std::vector<Property>& properties) {
    sol::table out = lua.create_table(static_cast<int>(properties.size()), 0);
    int index = 1;
    for (const auto& property : properties) {
        sol::table item = lua.create_table();
        item["name"] = property.name;
        item["type"] = property.type;
        item["value"] = PropertyValueToLua(lua, property.value);
        out[index++] = item;
        if (!property.name.empty()) {
            out[property.name] = PropertyValueToLua(lua, property.value);
        }
    }
    return out;
}

sol::table PointsToLua(sol::state_view lua, const std::vector<ObjectPoint>& points) {
    sol::table out = lua.create_table(static_cast<int>(points.size()), 0);
    int index = 1;
    for (const auto& point : points) {
        sol::table p = lua.create_table();
        p["x"] = point.x;
        p["y"] = point.y;
        out[index++] = p;
    }
    return out;
}

sol::table ObjectToLua(sol::state_view lua, const std::string& mapId, const LayerData& layer, const ObjectData& object) {
    sol::table out = lua.create_table();
    out["map_id"] = mapId;
    out["layer"] = layer.name;
    out["id"] = object.id;
    out["name"] = object.name;
    out["type"] = object.type;
    out["class"] = object.className;
    out["x"] = object.x;
    out["y"] = object.y;
    out["width"] = object.width;
    out["height"] = object.height;
    out["rotation"] = object.rotation;
    out["visible"] = object.visible;
    out["point"] = object.point;
    out["ellipse"] = object.ellipse;
    out["properties"] = PropertiesToLua(lua, object.properties);

    if (!object.polygon.empty()) {
        out["polygon"] = PointsToLua(lua, object.polygon);
    }
    if (!object.polyline.empty()) {
        out["polyline"] = PointsToLua(lua, object.polyline);
    }

    if (object.gid.has_value()) {
        const DecodedGid decoded = DecodeGid(*object.gid);
        const TileTransform transform = OrthogonalTransformFromFlags(decoded.flags);
        out["gid"] = *object.gid;
        out["tile_id"] = decoded.tileId;
        out["flip_x"] = transform.flipX;
        out["flip_y"] = transform.flipY;
        out["rotation"] = transform.rotationDegrees;
        out["flip_diag"] = decoded.flags.flipDiagonally;
        out["rot_hex120"] = decoded.flags.rotatedHex120;
    }

    return out;
}

std::string ResolveMapIdOrThrow(const std::string& mapId) {
    if (!mapId.empty()) {
        if (!HasMap(mapId)) {
            throw std::runtime_error("Unknown Tiled map id: " + mapId);
        }
        return mapId;
    }

    const std::string active = GetActiveMap();
    if (active.empty()) {
        throw std::runtime_error("No active Tiled map is set");
    }
    return active;
}

int EmitObjects(const std::string& mapId, sol::state_view lua, const std::function<void(sol::table&&)>& sink) {
    int count = 0;
    const bool ok = ForEachObject(mapId, [&](const LayerData& layer, const ObjectData& object) {
        sink(ObjectToLua(lua, mapId, layer, object));
        ++count;
    });
    if (!ok) {
        throw std::runtime_error("Failed to iterate Tiled objects for map id '" + mapId + "'");
    }
    return count;
}

void ClearGeneratedGridColliders() {
    if (g_generatedGridColliderEntities.empty()) {
        return;
    }

    entt::registry& registry = globals::registry;
    for (entt::entity e : g_generatedGridColliderEntities) {
        if (registry.valid(e)) {
            registry.destroy(e);
        }
    }
    g_generatedGridColliderEntities.clear();
}

sol::table ProceduralResultsToLua(sol::state_view lua, const ProceduralResults& results) {
    sol::table out = lua.create_table();
    out["width"] = results.width;
    out["height"] = results.height;

    sol::table cells = lua.create_table(static_cast<int>(results.cells.size()), 0);
    int index = 1;
    for (const auto& cellTiles : results.cells) {
        sol::table cell = lua.create_table(static_cast<int>(cellTiles.size()), 0);
        int tileIndex = 1;
        for (const auto& tile : cellTiles) {
            sol::table t = lua.create_table();
            t["tile_id"] = tile.tileId;
            t["flip_x"] = tile.flipX;
            t["flip_y"] = tile.flipY;
            t["rotation"] = tile.rotation;
            t["offset_x"] = tile.offsetX;
            t["offset_y"] = tile.offsetY;
            t["opacity"] = tile.opacity;
            cell[tileIndex++] = t;
        }
        cells[index++] = cell;
    }
    out["cells"] = cells;
    return out;
}

} // namespace

void exposeToLua(sol::state& lua) {
    auto& rec = BindingRecorder::instance();

    sol::table tiled = lua.create_table();

    tiled.set_function("load_map", [](const std::string& mapPath) {
        const auto resolved = ResolveAssetPath(mapPath);
        std::string err;
        if (!RegisterMap(resolved, &err)) {
            throw std::runtime_error("tiled.load_map failed: " + err);
        }
        return MapIdFromPath(resolved);
    });

    tiled.set_function("loaded_maps", []() {
        return sol::as_table(GetLoadedMapIds());
    });

    tiled.set_function("set_active_map", [](const std::string& mapId) {
        if (!SetActiveMap(mapId)) {
            throw std::runtime_error("tiled.set_active_map failed: unknown map id '" + mapId + "'");
        }
    });

    tiled.set_function("has_active_map", []() {
        return HasActiveMap();
    });

    tiled.set_function("active_map", []() {
        return GetActiveMap();
    });

    tiled.set_function("clear_maps", []() {
        ClearAllMaps();
        ClearTilesetTextureCache();
    });

    tiled.set_function("draw_all_layers", [](const std::string& targetLayerName, sol::optional<sol::table> opts) {
        TileDrawOptions options = TileDrawOptionsFromLua(opts);
        options.ySorted = false;
        return DrawMapTileLayers(targetLayerName, std::nullopt, options);
    });

    tiled.set_function("draw_all_layers_ysorted", [](const std::string& targetLayerName, sol::optional<sol::table> opts) {
        TileDrawOptions options = TileDrawOptionsFromLua(opts);
        options.ySorted = true;
        return DrawMapTileLayers(targetLayerName, std::nullopt, options);
    });

    tiled.set_function("draw_layer",
                       [](const std::string& mapLayerName, const std::string& targetLayerName,
                          sol::optional<sol::table> opts) {
                           TileDrawOptions options = TileDrawOptionsFromLua(opts);
                           options.ySorted = false;
                           return DrawMapTileLayers(targetLayerName, mapLayerName, options);
                       });

    tiled.set_function("draw_layer_ysorted",
                       [](const std::string& mapLayerName, const std::string& targetLayerName,
                          sol::optional<sol::table> opts) {
                           TileDrawOptions options = TileDrawOptionsFromLua(opts);
                           options.ySorted = true;
                           return DrawMapTileLayers(targetLayerName, mapLayerName, options);
                       });

    tiled.set_function("clear_draw_cache", []() {
        ClearTilesetTextureCache();
    });

    tiled.set_function("object_count", sol::overload([]() {
        return static_cast<int>(CountObjectsInActiveMap());
    }, [](const std::string& mapId) {
        const std::string resolvedMapId = ResolveMapIdOrThrow(mapId);
        return static_cast<int>(CountObjects(resolvedMapId));
    }));

    tiled.set_function("get_objects", sol::overload([&lua]() {
        const std::string mapId = ResolveMapIdOrThrow("");
        sol::table objects = lua.create_table();
        int index = 1;
        EmitObjects(mapId, lua, [&](sol::table&& obj) {
            objects[index++] = std::move(obj);
        });
        return objects;
    }, [&lua](const std::string& mapId) {
        const std::string resolvedMapId = ResolveMapIdOrThrow(mapId);
        sol::table objects = lua.create_table();
        int index = 1;
        EmitObjects(resolvedMapId, lua, [&](sol::table&& obj) {
            objects[index++] = std::move(obj);
        });
        return objects;
    }));

    tiled.set_function("each_object", sol::overload([&lua](sol::function cb) {
        const std::string mapId = ResolveMapIdOrThrow("");
        EmitObjects(mapId, lua, [&](sol::table&& obj) {
            cb(std::move(obj));
        });
    }, [&lua](const std::string& mapId, sol::function cb) {
        const std::string resolvedMapId = ResolveMapIdOrThrow(mapId);
        EmitObjects(resolvedMapId, lua, [&](sol::table&& obj) {
            cb(std::move(obj));
        });
    }));

    tiled.set_function("set_spawner", [](sol::function fn) {
        g_objectSpawner = fn;
    });

    tiled.set_function("spawn_objects", sol::overload([&lua]() {
        const std::string mapId = ResolveMapIdOrThrow("");
        if (!g_objectSpawner.valid()) {
            throw std::runtime_error("tiled.spawn_objects requires tiled.set_spawner(...) first");
        }
        return EmitObjects(mapId, lua, [&](sol::table&& obj) {
            g_objectSpawner(std::move(obj));
        });
    }, [&lua](const std::string& mapId) {
        const std::string resolvedMapId = ResolveMapIdOrThrow(mapId);
        if (!g_objectSpawner.valid()) {
            throw std::runtime_error("tiled.spawn_objects requires tiled.set_spawner(...) first");
        }
        return EmitObjects(resolvedMapId, lua, [&](sol::table&& obj) {
            g_objectSpawner(std::move(obj));
        });
    }));

    tiled.set_function("clear_spawner", []() {
        g_objectSpawner = sol::lua_nil;
    });

    tiled.set_function("load_rule_defs", [](const std::string& rulesPath) {
        const auto resolved = ResolveAssetPath(rulesPath);
        std::string err;
        if (!LoadRuleDefs(resolved, &err)) {
            throw std::runtime_error("tiled.load_rule_defs failed: " + err);
        }
        return RulesetIdFromPath(resolved);
    });

    tiled.set_function("loaded_rulesets", []() {
        return sol::as_table(GetLoadedRulesetIds());
    });

    tiled.set_function("clear_rule_defs", []() {
        ClearRuleDefs();
    });

    tiled.set_function("apply_rules", [&lua](sol::table gridTable, const std::string& rulesetId) {
        GridInput grid = GridFromLua(gridTable);
        ProceduralResults out{};
        std::string err;
        if (!ApplyRules(grid, rulesetId, &out, &err)) {
            throw std::runtime_error("tiled.apply_rules failed: " + err);
        }
        return ProceduralResultsToLua(lua, out);
    });

    tiled.set_function("build_colliders_from_grid",
                       [](sol::table gridTable, const std::string& worldName, sol::optional<std::string> tag,
                          sol::optional<sol::table> solidValues, sol::optional<int> cellSizeOpt) {
                           const int width = gridTable.get_or("width", 0);
                           const int height = gridTable.get_or("height", 0);
                           const sol::table cells = gridTable.get_or("cells", sol::table());
                           const std::string physicsTag = tag.value_or("WORLD");

                           ClearGeneratedGridColliders();
                           if (width <= 0 || height <= 0) {
                               return 0;
                           }

                           PhysicsManager* physicsManager = globals::physicsManager.get();
                           if (physicsManager == nullptr) {
                               throw std::runtime_error("tiled.build_colliders_from_grid failed: physics manager is unavailable");
                           }
                           auto* worldRec = physicsManager->get(worldName);
                           if (worldRec == nullptr || !worldRec->w) {
                               throw std::runtime_error("tiled.build_colliders_from_grid failed: unknown physics world '" +
                                                        worldName + "'");
                           }

                           entt::registry& registry = globals::registry;
                           auto* world = worldRec->w.get();
                           const int cellSize = cellSizeOpt.value_or(16);
                           if (cellSize <= 0) {
                               throw std::runtime_error("tiled.build_colliders_from_grid failed: cellSize must be > 0");
                           }

                           std::unordered_set<int> solidLookup;
                           if (solidValues.has_value()) {
                               for (auto& pair : *solidValues) {
                                   if (pair.second.is<int>()) {
                                       solidLookup.insert(pair.second.as<int>());
                                   }
                               }
                           }
                           const bool useSolidLookup = !solidLookup.empty();
                           auto isSolid = [&](int value) {
                               return useSolidLookup ? (solidLookup.count(value) > 0) : (value != 0);
                           };

                           for (int y = 0; y < height; ++y) {
                               int x = 0;
                               while (x < width) {
                                   const int idx = y * width + x + 1; // Lua 1-indexed.
                                   if (!isSolid(cells.get_or(idx, 0))) {
                                       ++x;
                                       continue;
                                   }

                                   int runEnd = x;
                                   while (runEnd + 1 < width) {
                                       const int nextIdx = y * width + (runEnd + 1) + 1;
                                       if (!isSolid(cells.get_or(nextIdx, 0))) {
                                           break;
                                       }
                                       ++runEnd;
                                   }

                                   const int runLen = (runEnd - x) + 1;
                                   const float colliderW = static_cast<float>(runLen * cellSize);
                                   const float colliderH = static_cast<float>(cellSize);
                                   const float centerX = static_cast<float>(x * cellSize) + colliderW * 0.5f;
                                   const float centerY = static_cast<float>(y * cellSize) + colliderH * 0.5f;

                                   const entt::entity e = registry.create();
                                   registry.emplace<PhysicsWorldRef>(e, worldName);
                                   registry.emplace<PhysicsLayer>(e, physicsTag);
                                   world->AddCollider(e, physicsTag, "rectangle", colliderW, colliderH, -1, -1, false);
                                   world->SetBodyPosition(e, centerX, centerY);
                                   g_generatedGridColliderEntities.push_back(e);

                                   x = runEnd + 1;
                               }
                           }

                           physicsManager->markNavmeshDirty(worldName);
                           return static_cast<int>(g_generatedGridColliderEntities.size());
                       });

    tiled.set_function("clear_generated_colliders", []() {
        ClearGeneratedGridColliders();
    });

    tiled.set_function("get_tile_grid", [&lua]() {
        return ProceduralResultsToLua(lua, GetLastProceduralResults());
    });

    tiled.set_function("cleanup_procedural", []() {
        ClearGeneratedGridColliders();
        CleanupProcedural();
    });

    lua["tiled"] = tiled;

    rec.record_property("tiled", {"load_map", "", "Load a .tmj map file and register it by stem id."});
    rec.record_property("tiled", {"loaded_maps", "", "Return currently loaded map ids."});
    rec.record_property("tiled", {"set_active_map", "", "Set the active Tiled map by id."});
    rec.record_property("tiled", {"has_active_map", "", "Whether an active Tiled map is set."});
    rec.record_property("tiled", {"active_map", "", "Return the active Tiled map id (or empty)."});
    rec.record_property("tiled", {"clear_maps", "", "Unload all registered Tiled maps and clear Tiled draw textures."});
    rec.record_property("tiled", {"draw_all_layers", "", "Queue all visible tile layers from a map into a render layer."});
    rec.record_property("tiled", {"draw_all_layers_ysorted", "",
                                  "Queue all visible tile layers with row-based z sorting."});
    rec.record_property("tiled", {"draw_layer", "", "Queue one named tile layer from a map into a render layer."});
    rec.record_property("tiled", {"draw_layer_ysorted", "",
                                  "Queue one named tile layer with row-based z sorting."});
    rec.record_property("tiled", {"clear_draw_cache", "", "Unload tileset textures cached by Tiled rendering APIs."});
    rec.record_property("tiled", {"object_count", "", "Count object-layer objects on a map (or active map)."});
    rec.record_property("tiled", {"get_objects", "", "Return object-layer objects as Lua tables."});
    rec.record_property("tiled", {"each_object", "", "Iterate object-layer objects with callback(objectTable)."});
    rec.record_property("tiled", {"set_spawner", "", "Set callback used by tiled.spawn_objects."});
    rec.record_property("tiled", {"spawn_objects", "", "Invoke spawner callback for each object-layer object."});
    rec.record_property("tiled", {"clear_spawner", "", "Clear currently registered Tiled object spawner callback."});
    rec.record_property("tiled", {"load_rule_defs", "", "Load Tiled automap rule definitions from rules.txt."});
    rec.record_property("tiled", {"loaded_rulesets", "", "Return loaded ruleset ids."});
    rec.record_property("tiled", {"clear_rule_defs", "", "Unload all loaded rulesets."});
    rec.record_property("tiled", {"apply_rules", "", "Apply loaded ruleset to a procedural grid."});
    rec.record_property("tiled", {"build_colliders_from_grid", "",
                                  "Build static colliders from grid values into a physics world."});
    rec.record_property("tiled", {"clear_generated_colliders", "",
                                  "Destroy colliders previously created by tiled.build_colliders_from_grid."});
    rec.record_property("tiled", {"get_tile_grid", "", "Get the most recent procedural tile output."});
    rec.record_property("tiled", {"cleanup_procedural", "",
                                  "Clear procedural tile output state and generated grid colliders."});
}

} // namespace tiled_loader
