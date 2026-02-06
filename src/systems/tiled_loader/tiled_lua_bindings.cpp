#include "tiled_loader.hpp"

#include <filesystem>
#include <stdexcept>
#include <string>

#include "sol/sol.hpp"
#include "systems/scripting/binding_recorder.hpp"
#include "util/utilities.hpp"

namespace tiled_loader {
namespace {

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

    tiled.set_function("get_tile_grid", [&lua]() {
        return ProceduralResultsToLua(lua, GetLastProceduralResults());
    });

    tiled.set_function("cleanup_procedural", []() {
        CleanupProcedural();
    });

    lua["tiled"] = tiled;

    rec.record_property("tiled", {"load_map", "", "Load a .tmj map file and register it by stem id."});
    rec.record_property("tiled", {"loaded_maps", "", "Return currently loaded map ids."});
    rec.record_property("tiled", {"set_active_map", "", "Set the active Tiled map by id."});
    rec.record_property("tiled", {"has_active_map", "", "Whether an active Tiled map is set."});
    rec.record_property("tiled", {"active_map", "", "Return the active Tiled map id (or empty)."});
    rec.record_property("tiled", {"clear_maps", "", "Unload all registered Tiled maps."});
    rec.record_property("tiled", {"load_rule_defs", "", "Load Tiled automap rule definitions from rules.txt."});
    rec.record_property("tiled", {"loaded_rulesets", "", "Return loaded ruleset ids."});
    rec.record_property("tiled", {"clear_rule_defs", "", "Unload all loaded rulesets."});
    rec.record_property("tiled", {"apply_rules", "", "Apply loaded ruleset to a procedural grid (stub phase)."});
    rec.record_property("tiled", {"get_tile_grid", "", "Get the most recent procedural tile output."});
    rec.record_property("tiled", {"cleanup_procedural", "", "Clear procedural tile output state."});
}

} // namespace tiled_loader
