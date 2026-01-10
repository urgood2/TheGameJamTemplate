// LDtk Lua bindings extracted from scripting_functions.cpp
// This file contains all the Lua bindings for the LDtk loader system

#include "ldtk_combined.hpp"
#include "ldtk_field_converters.hpp"
#include "sol/sol.hpp"
#include "systems/scripting/binding_recorder.hpp"
#include "systems/scripting/sol2_helpers.hpp"
#include "core/game.hpp"
#include "core/globals.hpp"
#include "spdlog/spdlog.h"

namespace ldtk_loader {

void exposeToLua(sol::state& lua) {
  auto& rec = BindingRecorder::instance();

  sol::table ldtk = lua.create_table();

  ldtk.set_function("load_config", [](const std::string &cfgPath) {
    // cfgPath is relative to assets/ (same convention as other loaders)
    ldtk_loader::ReloadProject(cfgPath);
    ldtk_loader::SetRegistry((globals::g_ctx) ? globals::g_ctx->registry : globals::getRegistry());
  });

  ldtk.set_function(
      "spawn_entities", [](const std::string &levelName, sol::function cb) {
        ldtk_loader::SetRegistry((globals::g_ctx) ? globals::g_ctx->registry : globals::getRegistry());
        ldtk_loader::ForEachEntity(
            levelName, [cb](const ldtk_loader::EntitySpawnInfo &info) {
              sol2_util::safe_call(cb, "ldtk_spawn_entities_callback",
                   info.name, info.position.x, info.position.y, info.layer,
                   info.grid.x, info.grid.y);
            });
      });

  ldtk.set_function("prefab_for", [](const std::string &entityName) {
    return ldtk_loader::PrefabForEntity(entityName);
  });

  auto entityFieldsToLua = [](sol::state_view lua_view, const ldtk::Entity &ent) -> sol::table {
    sol::table fields = lua_view.create_table();
    using namespace ldtk_converters;

    for (const auto &fieldDef : ent.allFields()) {
      const std::string &name = fieldDef.name;
      try {
        switch (fieldDef.type) {
        case ldtk::FieldType::Int: {
          const auto &f = ent.getField<int>(name);
          if (!f.is_null()) fields[name] = f.value();
          break;
        }
        case ldtk::FieldType::Float: {
          const auto &f = ent.getField<float>(name);
          if (!f.is_null()) fields[name] = f.value();
          break;
        }
        case ldtk::FieldType::Bool: {
          const auto &f = ent.getField<bool>(name);
          if (!f.is_null()) fields[name] = f.value();
          break;
        }
        case ldtk::FieldType::String: {
          const auto &f = ent.getField<std::string>(name);
          if (!f.is_null()) fields[name] = f.value();
          break;
        }
        case ldtk::FieldType::Color: {
          const auto &f = ent.getField<ldtk::Color>(name);
          if (!f.is_null()) fields[name] = colorToLua(lua_view, f.value());
          break;
        }
        case ldtk::FieldType::Point: {
          const auto &f = ent.getField<ldtk::IntPoint>(name);
          if (!f.is_null()) fields[name] = pointToLua(lua_view, f.value());
          break;
        }
        case ldtk::FieldType::Enum: {
          const auto &f = ent.getField<ldtk::EnumValue>(name);
          if (!f.is_null()) fields[name] = f.value().name;
          break;
        }
        case ldtk::FieldType::FilePath: {
          const auto &f = ent.getField<ldtk::FilePath>(name);
          if (!f.is_null()) fields[name] = std::string(f.value().c_str());
          break;
        }
        case ldtk::FieldType::EntityRef: {
          const auto &f = ent.getField<ldtk::EntityRef>(name);
          if (!f.is_null()) fields[name] = entityRefToLua(lua_view, f.value());
          break;
        }
        case ldtk::FieldType::ArrayInt:
          fields[name] = simpleArrayToLua(lua_view, ent.getArrayField<int>(name));
          break;
        case ldtk::FieldType::ArrayFloat:
          fields[name] = simpleArrayToLua(lua_view, ent.getArrayField<float>(name));
          break;
        case ldtk::FieldType::ArrayBool:
          fields[name] = simpleArrayToLua(lua_view, ent.getArrayField<bool>(name));
          break;
        case ldtk::FieldType::ArrayString:
          fields[name] = simpleArrayToLua(lua_view, ent.getArrayField<std::string>(name));
          break;
        case ldtk::FieldType::ArrayColor:
          fields[name] = arrayToLua(lua_view, ent.getArrayField<ldtk::Color>(name), colorToLua);
          break;
        case ldtk::FieldType::ArrayPoint:
          fields[name] = arrayToLua(lua_view, ent.getArrayField<ldtk::IntPoint>(name), pointToLua);
          break;
        case ldtk::FieldType::ArrayEnum:
          fields[name] = enumArrayToLua(lua_view, ent.getArrayField<ldtk::EnumValue>(name));
          break;
        case ldtk::FieldType::ArrayFilePath:
          fields[name] = filePathArrayToLua(lua_view, ent.getArrayField<ldtk::FilePath>(name));
          break;
        case ldtk::FieldType::ArrayEntityRef:
          fields[name] = arrayToLua(lua_view, ent.getArrayField<ldtk::EntityRef>(name), entityRefToLua);
          break;
        }
      } catch (const std::exception &e) {
        spdlog::warn("LDtk field extraction error for '{}': {}", name, e.what());
      }
    }
    return fields;
  };

  ldtk.set_function("set_spawner", [&lua, entityFieldsToLua](sol::function fn) {
    static sol::function stored;
    stored = fn;
    ldtk_loader::SetEntitySpawner(
        [fn, &lua, entityFieldsToLua](const ldtk::Entity &ent, entt::registry & /*R*/) {
          const auto pos = ent.getPosition();
          const auto grid = ent.getGridPosition();
          sol::table fields = entityFieldsToLua(lua, ent);
          sol2_util::safe_call(fn, "ldtk_entity_spawner",
               ent.getName(), (float)pos.x, (float)pos.y, ent.layer->getName(),
               grid.x, grid.y, fields);
        });
    ldtk_loader::SetRegistry((globals::g_ctx) ? globals::g_ctx->registry : globals::getRegistry());
  });

  ldtk.set_function("each_intgrid", [](const std::string &levelName,
                                       const std::string &layerName,
                                       sol::function cb) {
    ldtk_loader::ForEachIntGrid(levelName, layerName,
                                [cb](int x, int y, int value) {
                                  sol2_util::safe_call(cb, "ldtk_each_intgrid_callback", x, y, value);
                                });
  });

  ldtk.set_function("collider_layers",
                    []() { return ldtk_loader::ColliderLayers(); });

  ldtk.set_function("build_colliders", [](const std::string &levelName,
                                          const std::string &worldName,
                                          sol::optional<std::string> tag) {
    ldtk_loader::BuildCollidersForLevel(levelName, worldName,
                                        tag.value_or("WORLD"));
  });

  ldtk.set_function("clear_colliders", [](const std::string &levelName,
                                          const std::string &worldName) {
    ldtk_loader::ClearCollidersForLevel(levelName, worldName);
  });

  ldtk.set_function(
      "set_active_level",
      [](const std::string &levelName, const std::string &worldName,
         sol::optional<bool> rebuildColliders,
         sol::optional<bool> spawnEntities, sol::optional<std::string> tag) {
        ldtk_loader::SetActiveLevel(
            levelName, worldName, rebuildColliders.value_or(true),
            spawnEntities.value_or(true), tag.value_or("WORLD"));
      });

  ldtk.set_function("active_level",
                    []() { return ldtk_loader::GetActiveLevel(); });
  ldtk.set_function("has_active_level",
                    []() { return ldtk_loader::HasActiveLevel(); });

  // Level query helpers
  ldtk.set_function("level_exists", [](const std::string &levelName) {
    return ldtk_loader::LevelExists(levelName);
  });

  ldtk.set_function("get_level_bounds", [&lua](const std::string &levelName) {
    auto bounds = ldtk_loader::GetLevelBounds(levelName);
    sol::table result = lua.create_table();
    result["x"] = bounds.x;
    result["y"] = bounds.y;
    result["width"] = bounds.width;
    result["height"] = bounds.height;
    return result;
  });

  ldtk.set_function("get_level_meta", [&lua](const std::string &levelName) {
    auto meta = ldtk_loader::GetLevelMeta(levelName);
    sol::table result = lua.create_table();
    result["width"] = meta.width;
    result["height"] = meta.height;
    result["world_x"] = meta.world_x;
    result["world_y"] = meta.world_y;
    result["depth"] = meta.depth;
    sol::table bg = lua.create_table();
    bg["r"] = meta.bg_color.r;
    bg["g"] = meta.bg_color.g;
    bg["b"] = meta.bg_color.b;
    bg["a"] = meta.bg_color.a;
    result["bg_color"] = bg;
    return result;
  });

  ldtk.set_function("get_neighbors", [&lua](const std::string &levelName) {
    auto neighbors = ldtk_loader::GetNeighbors(levelName);
    sol::table result = lua.create_table();
    if (!neighbors.north.empty()) result["north"] = neighbors.north;
    if (!neighbors.south.empty()) result["south"] = neighbors.south;
    if (!neighbors.east.empty()) result["east"] = neighbors.east;
    if (!neighbors.west.empty()) result["west"] = neighbors.west;
    if (!neighbors.overlap.empty()) {
      result["overlap"] = sol::as_table(neighbors.overlap);
    }
    return result;
  });

  // Entity query helpers
  ldtk.set_function("get_entity_position", [&lua](const std::string &levelName,
                                                           const std::string &iid) {
    auto pos = ldtk_loader::GetEntityPositionByIID(levelName, iid);
    if (!pos.found) return sol::object(sol::lua_nil);
    sol::table result = lua.create_table();
    result["x"] = pos.x;
    result["y"] = pos.y;
    return sol::object(result);
  });

  ldtk.set_function("get_entities_by_name", [&lua, entityFieldsToLua](
                                                const std::string &levelName,
                                                const std::string &entityName) {
    auto entities = ldtk_loader::GetEntitiesByName(levelName, entityName);
    sol::table result = lua.create_table();

    // Also get fields for each entity
    const auto& world = ldtk_loader::internal_loader::project.getWorld();
    const auto& level = world.getLevel(levelName);

    int idx = 1;
    for (const auto& info : entities) {
      sol::table ent = lua.create_table();
      ent["name"] = info.name;
      ent["iid"] = info.iid;
      ent["x"] = info.x;
      ent["y"] = info.y;
      ent["grid_x"] = info.grid_x;
      ent["grid_y"] = info.grid_y;
      ent["width"] = info.width;
      ent["height"] = info.height;
      ent["layer"] = info.layer;
      ent["tags"] = sol::as_table(info.tags);

      // Get fields for this entity
      const auto* entPtr = ldtk_loader::GetEntityByIID(levelName, info.iid);
      if (entPtr) {
        ent["fields"] = entityFieldsToLua(lua, *entPtr);
      }

      result[idx++] = ent;
    }
    return result;
  });

  // -------------------- Procedural Rule Runner API --------------------

  // Apply LDtk auto-rules to a Lua-provided IntGrid
  ldtk.set_function("apply_rules", [&lua](sol::table gridTable, const std::string& layerName) {
    // Extract grid dimensions and cells from Lua table
    int width = gridTable.get_or("width", 0);
    int height = gridTable.get_or("height", 0);
    sol::table cells = gridTable.get_or("cells", sol::table());

    if (width <= 0 || height <= 0) {
      throw std::runtime_error("Invalid grid dimensions");
    }

    // Convert Lua table to vector
    std::vector<int> cellValues;
    cellValues.reserve(width * height);
    for (int i = 1; i <= width * height; ++i) {
      cellValues.push_back(cells.get_or(i, 0));
    }

    // Create level from IntGrid
    ldtk_rule_import::CreateLevelFromIntGrid(width, height, cellValues);

    // Run rules
    ldtk_rule_import::RunRulesForLevel(layerName);

    // Get layer index
    int layerIdx = ldtk_rule_import::GetLayerIndex(layerName);
    if (layerIdx < 0) {
      throw std::runtime_error("Layer not found: " + layerName);
    }

    // Get results and convert to Lua table
    auto results = ldtk_rule_import::GetAllTileResults(layerIdx);

    sol::table output = lua.create_table();
    output["width"] = results.width;
    output["height"] = results.height;

    sol::table outputCells = lua.create_table();
    int idx = 1;
    for (const auto& cellTiles : results.cells) {
      sol::table cellTable = lua.create_table();
      int tileIdx = 1;
      for (const auto& tile : cellTiles) {
        sol::table tileTable = lua.create_table();
        tileTable["tile_id"] = tile.tile_id;
        tileTable["flip_x"] = tile.flip_x;
        tileTable["flip_y"] = tile.flip_y;
        tileTable["alpha"] = tile.alpha;
        tileTable["offset_x"] = tile.offset_x;
        tileTable["offset_y"] = tile.offset_y;
        cellTable[tileIdx++] = tileTable;
      }
      outputCells[idx++] = cellTable;
    }
    output["cells"] = outputCells;

    return output;
  });

  // Build colliders from a Lua-provided IntGrid (without using LDtk level)
  ldtk.set_function("build_colliders_from_grid",
      [](sol::table gridTable, const std::string& worldName, sol::optional<std::string> tag) {
    int width = gridTable.get_or("width", 0);
    int height = gridTable.get_or("height", 0);
    sol::table cells = gridTable.get_or("cells", sol::table());
    std::string physicsTag = tag.value_or("WORLD");

    if (width <= 0 || height <= 0) return;

    auto* world = ldtk_loader::GetPhysicsWorld(worldName);
    if (!world) {
      spdlog::warn("build_colliders_from_grid: physics world '{}' not found", worldName);
      return;
    }

    auto* R = ldtk_loader::internal_loader::registry;
    if (!R) {
      spdlog::warn("build_colliders_from_grid: registry not set");
      return;
    }

    const int cellSize = 16; // Default cell size, could be made configurable

    // Scan rows for horizontal runs of solid cells
    for (int y = 0; y < height; ++y) {
      int x = 0;
      while (x < width) {
        int idx = y * width + x + 1; // Lua 1-indexed
        int val = cells.get_or(idx, 0);
        if (val == 0) { ++x; continue; }

        int runStart = x;
        int runEnd = x;
        while (runEnd + 1 < width) {
          int nextIdx = y * width + (runEnd + 1) + 1;
          if (cells.get_or(nextIdx, 0) == 0) break;
          ++runEnd;
        }
        int runLen = (runEnd - runStart) + 1;

        float w = (float)(runLen * cellSize);
        float h = (float)cellSize;
        float cx = runStart * cellSize + w * 0.5f;
        float cy = y * cellSize + h * 0.5f;

        entt::entity e = R->create();
        R->emplace<PhysicsWorldRef>(e, worldName);
        R->emplace<PhysicsLayer>(e, physicsTag);

        world->AddCollider(e, physicsTag, "rectangle", w, h, -1, -1, false);
        world->SetBodyPosition(e, cx, cy);

        x = runEnd + 1;
      }
    }

    if (globals::physicsManager) {
      globals::physicsManager->markNavmeshDirty(worldName);
    }
  });

  // Get layer information from loaded LDtk project
  ldtk.set_function("get_layer_count", []() {
    return ldtk_rule_import::GetLayerCount();
  });

  ldtk.set_function("get_layer_name", [](int layerIdx) {
    return ldtk_rule_import::GetLayerName(layerIdx);
  });

  ldtk.set_function("get_layer_index", [](const std::string& layerName) {
    return ldtk_rule_import::GetLayerIndex(layerName);
  });

  // Clean up managed level (optional, called automatically when apply_rules is called again)
  ldtk.set_function("cleanup_procedural", []() {
    ldtk_rule_import::CleanupManagedLevel();
  });

  // -------------------- Procedural Rendering API --------------------

  // Draw a single procedural layer to the command buffer
  // layerIdx: which tile grid layer to draw (from apply_rules output)
  // targetLayer: which game layer to draw to ("sprites", "background", etc.)
  ldtk.set_function("draw_procedural_layer",
      [](int layerIdx, const std::string& targetLayerName,
         sol::optional<float> offsetX, sol::optional<float> offsetY,
         sol::optional<int> zLevel, sol::optional<float> opacity) {

        auto layer = game::GetLayer(targetLayerName);
        if (!layer) {
          spdlog::warn("draw_procedural_layer: Layer '{}' not found", targetLayerName);
          return;
        }

        ldtk_rule_import::DrawProceduralLayer(
            layer,
            layerIdx,
            offsetX.value_or(0.0f),
            offsetY.value_or(0.0f),
            zLevel.value_or(0),
            nullptr,  // viewOpt - TODO: could add camera culling
            opacity.value_or(1.0f)
        );
      });

  // Draw all procedural layers to the command buffer
  ldtk.set_function("draw_all_procedural_layers",
      [](const std::string& targetLayerName,
         sol::optional<float> offsetX, sol::optional<float> offsetY,
         sol::optional<int> baseZLevel, sol::optional<float> opacity) {

        auto layer = game::GetLayer(targetLayerName);
        if (!layer) {
          spdlog::warn("draw_all_procedural_layers: Layer '{}' not found", targetLayerName);
          return;
        }

        ldtk_rule_import::DrawAllProceduralLayers(
            layer,
            offsetX.value_or(0.0f),
            offsetY.value_or(0.0f),
            baseZLevel.value_or(0),
            nullptr,  // viewOpt
            opacity.value_or(1.0f)
        );
      });

  // Get tileset info for a layer (tile size, dimensions, etc.)
  ldtk.set_function("get_tileset_info", [&lua](int layerIdx) {
    auto info = ldtk_rule_import::GetTilesetInfoForLayer(layerIdx);
    sol::table result = lua.create_table();
    result["tile_size"] = info.tileSize;
    result["width"] = info.width;
    result["height"] = info.height;
    result["image_path"] = info.imagePath;
    return result;
  });

  // -------------------- Filtered and Y-Sorted Rendering --------------------

  // Draw procedural layer with tile ID filtering
  // Only draws tiles whose IDs are in the provided table
  ldtk.set_function("draw_procedural_layer_filtered",
      [](int layerIdx, const std::string& targetLayerName, sol::table tileIds,
         sol::optional<float> offsetX, sol::optional<float> offsetY,
         sol::optional<int> zLevel, sol::optional<float> opacity) {

        auto layer = game::GetLayer(targetLayerName);
        if (!layer) {
          spdlog::warn("draw_procedural_layer_filtered: Layer '{}' not found", targetLayerName);
          return;
        }

        // Convert Lua table to std::set
        std::set<int> allowedTiles;
        for (auto& pair : tileIds) {
          if (pair.second.is<int>()) {
            allowedTiles.insert(pair.second.as<int>());
          }
        }

        ldtk_rule_import::DrawProceduralLayerFiltered(
            layer,
            layerIdx,
            allowedTiles,
            offsetX.value_or(0.0f),
            offsetY.value_or(0.0f),
            zLevel.value_or(0),
            nullptr,
            opacity.value_or(1.0f)
        );
      });

  // Draw procedural layer with Y-based Z-sorting (for top-down games)
  // Each row gets a different Z-level: z = base_z + row * z_per_row
  ldtk.set_function("draw_procedural_layer_ysorted",
      [](int layerIdx, const std::string& targetLayerName,
         sol::optional<float> offsetX, sol::optional<float> offsetY,
         sol::optional<int> baseZLevel, sol::optional<int> zPerRow,
         sol::optional<float> opacity) {

        auto layer = game::GetLayer(targetLayerName);
        if (!layer) {
          spdlog::warn("draw_procedural_layer_ysorted: Layer '{}' not found", targetLayerName);
          return;
        }

        ldtk_rule_import::DrawProceduralLayerYSorted(
            layer,
            layerIdx,
            offsetX.value_or(0.0f),
            offsetY.value_or(0.0f),
            baseZLevel.value_or(0),
            zPerRow.value_or(1),
            nullptr,
            opacity.value_or(1.0f)
        );
      });

  // Draw a single tile at a specific world position (for maximum control)
  // Useful when iterating tile data from Lua and rendering selectively
  ldtk.set_function("draw_tile",
      [](int layerIdx, int tileId, const std::string& targetLayerName,
         float worldX, float worldY, int zLevel,
         sol::optional<bool> flipX, sol::optional<bool> flipY,
         sol::optional<float> opacity) {

        auto layer = game::GetLayer(targetLayerName);
        if (!layer) {
          spdlog::warn("draw_tile: Layer '{}' not found", targetLayerName);
          return;
        }

        ldtk_rule_import::DrawSingleTile(
            layer,
            layerIdx,
            tileId,
            worldX,
            worldY,
            zLevel,
            flipX.value_or(false),
            flipY.value_or(false),
            opacity.value_or(1.0f)
        );
      });

  // Get all tile results for a layer as a table (for custom iteration/filtering)
  ldtk.set_function("get_tile_grid", [&lua](int layerIdx) {
    sol::table result = lua.create_table();

    auto tileResults = ldtk_rule_import::GetAllTileResults(layerIdx);
    result["width"] = tileResults.width;
    result["height"] = tileResults.height;

    // Create cells table
    sol::table cells = lua.create_table();
    for (int y = 0; y < tileResults.height; ++y) {
      for (int x = 0; x < tileResults.width; ++x) {
        int idx = y * tileResults.width + x;
        const auto& cellTiles = tileResults.cells[idx];

        if (!cellTiles.empty()) {
          sol::table cellTable = lua.create_table();
          int tileIdx = 1;
          for (const auto& tile : cellTiles) {
            sol::table tileTable = lua.create_table();
            tileTable["tile_id"] = tile.tile_id;
            tileTable["flip_x"] = tile.flip_x;
            tileTable["flip_y"] = tile.flip_y;
            tileTable["alpha"] = tile.alpha;
            tileTable["offset_x"] = tile.offset_x;
            tileTable["offset_y"] = tile.offset_y;
            cellTable[tileIdx++] = tileTable;
          }
          // Use x,y indexing: cells[y][x]
          if (!cells[y].valid()) {
            cells[y] = lua.create_table();
          }
          cells[y][x] = cellTable;
        }
      }
    }
    result["cells"] = cells;

    // Add helper method to get tiles at position
    result["get"] = [&lua, tileResults](sol::this_state L, int x, int y) -> sol::object {
      if (x < 0 || x >= tileResults.width || y < 0 || y >= tileResults.height) {
        return sol::lua_nil;
      }
      int idx = y * tileResults.width + x;
      const auto& cellTiles = tileResults.cells[idx];
      if (cellTiles.empty()) {
        return sol::lua_nil;
      }

      sol::state_view lua_view(L);
      sol::table cellTable = lua_view.create_table();
      int tileIdx = 1;
      for (const auto& tile : cellTiles) {
        sol::table tileTable = lua_view.create_table();
        tileTable["tile_id"] = tile.tile_id;
        tileTable["flip_x"] = tile.flip_x;
        tileTable["flip_y"] = tile.flip_y;
        tileTable["alpha"] = tile.alpha;
        tileTable["offset_x"] = tile.offset_x;
        tileTable["offset_y"] = tile.offset_y;
        cellTable[tileIdx++] = tileTable;
      }
      return cellTable;
    };

    return result;
  });

  // -------------------- Signal Emission Support --------------------
  // Store signal emitter callback (expects: emitter(eventName, dataTable))
  static sol::function ldtkSignalEmitter;

  ldtk.set_function("set_signal_emitter", [](sol::function fn) {
    ldtkSignalEmitter = fn;
  });

  // Helper to emit signals if emitter is set
  auto emitLdtkSignal = [&lua](const std::string& eventName, sol::table data) {
    if (ldtkSignalEmitter.valid()) {
      try {
        ldtkSignalEmitter(eventName, data);
      } catch (const std::exception& e) {
        spdlog::warn("LDTK signal emission error for '{}': {}", eventName, e.what());
      }
    }
  };

  // Wrap set_active_level to emit signals
  ldtk.set_function(
      "set_active_level_with_signals",
      [&lua, emitLdtkSignal](const std::string &levelName, const std::string &worldName,
         sol::optional<bool> rebuildColliders,
         sol::optional<bool> spawnEntities, sol::optional<std::string> tag) {
        bool doColliders = rebuildColliders.value_or(true);
        bool doSpawn = spawnEntities.value_or(true);
        std::string physicsTag = tag.value_or("WORLD");

        ldtk_loader::SetActiveLevel(levelName, worldName, doColliders, doSpawn, physicsTag);

        // Emit ldtk_level_loaded signal
        sol::table levelData = lua.create_table();
        levelData["level_name"] = levelName;
        levelData["world_name"] = worldName;
        levelData["colliders_built"] = doColliders;
        levelData["entities_spawned"] = doSpawn;

        if (ldtkSignalEmitter.valid()) {
          try {
            ldtkSignalEmitter("ldtk_level_loaded", levelData);

            if (doColliders) {
              sol::table colliderData = lua.create_table();
              colliderData["level_name"] = levelName;
              colliderData["world_name"] = worldName;
              colliderData["physics_tag"] = physicsTag;
              ldtkSignalEmitter("ldtk_colliders_built", colliderData);
            }
          } catch (const std::exception& e) {
            spdlog::warn("LDTK signal emission error: {}", e.what());
          }
        }
      });

  // Convenience function to emit entity spawned signal (call from Lua spawner)
  ldtk.set_function("emit_entity_spawned",
      [&lua](const std::string& entityName, float px, float py,
                     const std::string& layerName, sol::optional<sol::table> extraData) {
        if (!ldtkSignalEmitter.valid()) return;

        sol::table data = lua.create_table();
        data["entity_name"] = entityName;
        data["px"] = px;
        data["py"] = py;
        data["layer"] = layerName;
        if (extraData.has_value()) {
          data["extra"] = extraData.value();
        }

        try {
          ldtkSignalEmitter("ldtk_entity_spawned", data);
        } catch (const std::exception& e) {
          spdlog::warn("LDTK entity_spawned signal error: {}", e.what());
        }
      });

  lua["ldtk"] = ldtk;
  rec.record_property(
      "ldtk", {"load_config", "",
               "Load and bind an LDtk project via JSON config (project_path, "
               "asset_dir, collider_layers, entity_prefabs)."});
  rec.record_property(
      "ldtk",
      {"spawn_entities", "",
       "Iterate entities in a level and invoke the provided Lua callback."});
  rec.record_property("ldtk", {"each_intgrid", "",
                               "Iterate intgrid values in a level layer."});
  rec.record_property(
      "ldtk", {"prefab_for", "",
               "Look up a prefab id for an LDtk entity name from config."});
  rec.record_property(
      "ldtk", {"collider_layers", "",
               "List collider layers declared in the active LDtk config."});
  rec.record_property("ldtk", {"build_colliders", "",
                               "Generate static colliders for the configured "
                               "collider layers into a physics world."});
  rec.record_property(
      "ldtk",
      {"clear_colliders", "",
       "Remove generated colliders for a level from a physics world."});
  rec.record_property("ldtk",
                      {"set_spawner", "",
                       "Register a Lua callback invoked per LDtk entity "
                       "(name, px, py, layer, gx, gy, tagsTable)."});
  rec.record_property("ldtk",
                      {"set_active_level", "",
                       "Set the active LDtk level, optionally rebuilding "
                       "colliders and spawning entities."});
  rec.record_property(
      "ldtk", {"active_level", "",
               "Returns the current active LDtk level name (or empty)."});
  rec.record_property("ldtk", {"has_active_level", "",
                               "True if an active LDtk level is set."});
  rec.record_property("ldtk", {"level_exists", "",
                               "Check if a level exists in the loaded project."});
  rec.record_property("ldtk", {"get_level_bounds", "",
                               "Get bounds (x, y, width, height) for a level."});
  rec.record_property("ldtk", {"get_level_meta", "",
                               "Get metadata (width, height, world_x, world_y, depth, bg_color) for a level."});
  rec.record_property("ldtk", {"get_neighbors", "",
                               "Get neighboring levels (north, south, east, west, overlap)."});
  rec.record_property("ldtk", {"get_entity_position", "",
                               "Get position of an entity by IID."});
  rec.record_property("ldtk", {"get_entities_by_name", "",
                               "Get all entities with a given name, including fields."});
  rec.record_property("ldtk", {"apply_rules", "",
                               "Apply LDtk auto-rules to a Lua IntGrid table, returning tile results."});
  rec.record_property("ldtk", {"build_colliders_from_grid", "",
                               "Build physics colliders from a Lua IntGrid table."});
  rec.record_property("ldtk", {"get_layer_count", "",
                               "Get number of layers in the LDtk project."});
  rec.record_property("ldtk", {"get_layer_name", "",
                               "Get layer name by index."});
  rec.record_property("ldtk", {"get_layer_index", "",
                               "Get layer index by name."});
  rec.record_property("ldtk", {"cleanup_procedural", "",
                               "Clean up managed procedural level."});
  rec.record_property("ldtk", {"set_signal_emitter", "",
                               "Set a callback for LDTK events: function(eventName, dataTable)."});
  rec.record_property("ldtk", {"set_active_level_with_signals", "",
                               "Like set_active_level but emits ldtk_level_loaded and ldtk_colliders_built signals."});
  rec.record_property("ldtk", {"emit_entity_spawned", "",
                               "Emit ldtk_entity_spawned signal (call from spawner callback)."});
}

} // namespace ldtk_loader
