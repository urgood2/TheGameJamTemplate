#include "tiled_loader.hpp"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <filesystem>
#include <functional>
#include <memory>
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
    rec.record_property("tiled", {"clear_maps", "", "Unload all registered Tiled maps."});
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
