#include <gtest/gtest.h>

#include <filesystem>
#include <fstream>
#include <string>
#include <vector>

#include "systems/tiled_loader/tiled_loader.hpp"

namespace fs = std::filesystem;

namespace {

class TiledLoaderTest : public ::testing::Test {
protected:
    void SetUp() override {
        testRoot = fs::current_path() / "tests" / "out" / "tiled_loader";
        fs::remove_all(testRoot);
        fs::create_directories(testRoot);

        tiled_loader::ClearAllMaps();
        tiled_loader::ClearRuleDefs();
        tiled_loader::CleanupProcedural();
    }

    void TearDown() override {
        tiled_loader::ClearAllMaps();
        tiled_loader::ClearRuleDefs();
        tiled_loader::CleanupProcedural();
    }

    void WriteFile(const fs::path& path, const std::string& contents) {
        fs::create_directories(path.parent_path());
        std::ofstream out(path);
        ASSERT_TRUE(out.is_open()) << "Failed to open " << path;
        out << contents;
    }

    fs::path testRoot;
};

TEST_F(TiledLoaderTest, DecodeGidStripsAllFlagBits) {
    constexpr uint32_t rawTile = 77u;
    constexpr uint32_t gid = 0xF0000000u | rawTile;

    const tiled_loader::DecodedGid decoded = tiled_loader::DecodeGid(gid);

    EXPECT_EQ(decoded.tileId, rawTile);
    EXPECT_TRUE(decoded.flags.flipHorizontally);
    EXPECT_TRUE(decoded.flags.flipVertically);
    EXPECT_TRUE(decoded.flags.flipDiagonally);
    EXPECT_TRUE(decoded.flags.rotatedHex120);
}

TEST_F(TiledLoaderTest, OrthogonalTransformFromFlagsHandlesDiagonalCombinations) {
    using tiled_loader::GidFlags;
    using tiled_loader::TileTransform;

    auto check = [](const GidFlags& flags, bool expectedFlipX, bool expectedFlipY, int expectedRotation) {
        const TileTransform t = tiled_loader::OrthogonalTransformFromFlags(flags);
        EXPECT_EQ(t.flipX, expectedFlipX);
        EXPECT_EQ(t.flipY, expectedFlipY);
        EXPECT_EQ(t.rotationDegrees, expectedRotation);
    };

    check(GidFlags{}, false, false, 0);
    check(GidFlags{true, false, false, false}, true, false, 0);
    check(GidFlags{false, true, false, false}, false, true, 0);
    check(GidFlags{true, true, false, false}, true, true, 0);

    check(GidFlags{false, false, true, false}, true, false, 270);
    check(GidFlags{true, false, true, false}, false, false, 90);
    check(GidFlags{false, true, true, false}, false, false, 270);
    check(GidFlags{true, true, true, false}, true, false, 90);
}

TEST_F(TiledLoaderTest, LoadMapFileParsesExternalTilesetAndChunkLayer) {
    const fs::path mapPath = testRoot / "maps" / "sample.tmj";
    const fs::path tilesetPath = testRoot / "maps" / "tiles" / "base.tsj";

    WriteFile(tilesetPath, R"json(
{
  "name": "base",
  "tilewidth": 16,
  "tileheight": 16,
  "tilecount": 4,
  "columns": 2,
  "image": "base.png",
  "imagewidth": 32,
  "imageheight": 32
}
)json");

    WriteFile(mapPath, R"json(
{
  "name": "sample_map",
  "orientation": "orthogonal",
  "renderorder": "right-down",
  "width": 4,
  "height": 4,
  "tilewidth": 16,
  "tileheight": 16,
  "infinite": true,
  "layers": [
    {
      "id": 1,
      "name": "Ground",
      "type": "tilelayer",
      "visible": true,
      "opacity": 1.0,
      "chunks": [
        { "x": -1, "y": 2, "width": 1, "height": 1, "data": [2147483649] }
      ],
      "properties": [
        { "name": "collider", "type": "bool", "value": true }
      ]
    }
  ],
  "tilesets": [
    { "firstgid": 1, "source": "tiles/base.tsj" }
  ]
}
)json");

    tiled_loader::MapData map{};
    std::string err;
    ASSERT_TRUE(tiled_loader::LoadMapFile(mapPath, &map, &err)) << err;

    EXPECT_EQ(map.id, "sample");
    EXPECT_EQ(map.name, "sample_map");
    EXPECT_TRUE(map.infinite);
    ASSERT_EQ(map.layers.size(), 1u);
    ASSERT_TRUE(map.layers[0].tileLayer.has_value());
    ASSERT_EQ(map.layers[0].tileLayer->chunks.size(), 1u);
    EXPECT_EQ(map.layers[0].tileLayer->chunks[0].x, -1);
    EXPECT_EQ(map.layers[0].tileLayer->chunks[0].y, 2);
    ASSERT_EQ(map.layers[0].tileLayer->chunks[0].gids.size(), 1u);

    const auto decoded = tiled_loader::DecodeGid(map.layers[0].tileLayer->chunks[0].gids[0]);
    EXPECT_EQ(decoded.tileId, 1u);
    EXPECT_TRUE(decoded.flags.flipHorizontally);

    ASSERT_EQ(map.tilesetRefs.size(), 1u);
    ASSERT_EQ(map.tilesets.size(), 1u);
    EXPECT_EQ(map.tilesetRefs[0].firstGid, 1);
    EXPECT_EQ(map.tilesets[0].tileWidth, 16);
    EXPECT_EQ(map.tilesets[0].tileHeight, 16);
    EXPECT_EQ(map.tilesets[0].name, "base");
    EXPECT_TRUE(map.tilesets[0].resolvedImagePath.filename() == "base.png");
}

TEST_F(TiledLoaderTest, ResolveTileSourceHandlesMixedTilesetsAndColumnsFallback) {
    const fs::path mapPath = testRoot / "maps" / "source_resolve.tmj";
    WriteFile(mapPath, R"json(
{
  "width": 1,
  "height": 1,
  "tilewidth": 16,
  "tileheight": 16,
  "layers": [],
  "tilesets": [
    {
      "firstgid": 1,
      "name": "a",
      "tilewidth": 16,
      "tileheight": 16,
      "tilecount": 4,
      "columns": 2,
      "image": "a.png",
      "imagewidth": 32,
      "imageheight": 32
    },
    {
      "firstgid": 100,
      "name": "b",
      "tilewidth": 32,
      "tileheight": 32,
      "tilecount": 6,
      "columns": 0,
      "image": "b.png",
      "imagewidth": 96,
      "imageheight": 64
    }
  ]
}
)json");

    tiled_loader::MapData map{};
    std::string err;
    ASSERT_TRUE(tiled_loader::LoadMapFile(mapPath, &map, &err)) << err;
    ASSERT_EQ(map.tilesets.size(), 2u);

    tiled_loader::ResolvedTileSource out{};
    ASSERT_TRUE(tiled_loader::ResolveTileSource(map, 1u, &out, &err)) << err;
    EXPECT_EQ(out.tilesetIndex, 0u);
    EXPECT_EQ(out.localTileId, 0);
    EXPECT_EQ(out.sourceX, 0);
    EXPECT_EQ(out.sourceY, 0);
    EXPECT_EQ(out.sourceWidth, 16);
    EXPECT_EQ(out.sourceHeight, 16);

    ASSERT_TRUE(tiled_loader::ResolveTileSource(map, 4u, &out, &err)) << err;
    EXPECT_EQ(out.tilesetIndex, 0u);
    EXPECT_EQ(out.localTileId, 3);
    EXPECT_EQ(out.sourceX, 16);
    EXPECT_EQ(out.sourceY, 16);

    constexpr uint32_t flaggedGid = 0x80000000u | 100u;
    const tiled_loader::DecodedGid decoded = tiled_loader::DecodeGid(flaggedGid);
    ASSERT_TRUE(tiled_loader::ResolveTileSource(map, decoded.tileId, &out, &err)) << err;
    EXPECT_EQ(out.tilesetIndex, 1u);
    EXPECT_EQ(out.localTileId, 0);
    EXPECT_EQ(out.sourceX, 0);
    EXPECT_EQ(out.sourceY, 0);
    EXPECT_EQ(out.sourceWidth, 32);
    EXPECT_EQ(out.sourceHeight, 32);

    ASSERT_TRUE(tiled_loader::ResolveTileSource(map, 103u, &out, &err)) << err;
    EXPECT_EQ(out.tilesetIndex, 1u);
    EXPECT_EQ(out.localTileId, 3);
    EXPECT_EQ(out.sourceX, 0);  // columns derived from imagewidth/tilewidth => 3.
    EXPECT_EQ(out.sourceY, 32);

    EXPECT_FALSE(tiled_loader::ResolveTileSource(map, 110u, &out, &err));
    EXPECT_FALSE(err.empty());
}

TEST_F(TiledLoaderTest, RegisterMapAndActiveMapLifecycle) {
    const fs::path mapPath = testRoot / "world.tmj";
    WriteFile(mapPath, R"json(
{
  "width": 1,
  "height": 1,
  "tilewidth": 16,
  "tileheight": 16,
  "layers": [],
  "tilesets": []
}
)json");

    std::string err;
    ASSERT_TRUE(tiled_loader::RegisterMap(mapPath, &err)) << err;
    EXPECT_TRUE(tiled_loader::HasMap("world"));
    EXPECT_FALSE(tiled_loader::HasActiveMap());
    EXPECT_TRUE(tiled_loader::SetActiveMap("world"));
    EXPECT_TRUE(tiled_loader::HasActiveMap());
    EXPECT_EQ(tiled_loader::GetActiveMap(), "world");
}

TEST_F(TiledLoaderTest, CountObjectsAndForEachObjectTraverseNestedGroups) {
    const fs::path mapPath = testRoot / "objects.tmj";
    WriteFile(mapPath, R"json(
{
  "width": 4,
  "height": 4,
  "tilewidth": 16,
  "tileheight": 16,
  "layers": [
    {
      "id": 1,
      "name": "ObjectsTop",
      "type": "objectgroup",
      "objects": [
        { "id": 11, "name": "spawn_a", "type": "Enemy", "x": 8, "y": 16, "properties": [ { "name": "hp", "type": "int", "value": 10 } ] },
        { "id": 12, "name": "spawn_b", "type": "Chest", "x": 32, "y": 48 }
      ]
    },
    {
      "id": 2,
      "name": "GroupParent",
      "type": "group",
      "layers": [
        {
          "id": 3,
          "name": "ObjectsNested",
          "type": "objectgroup",
          "objects": [
            { "id": 13, "name": "spawn_c", "type": "Enemy", "x": 64, "y": 64, "gid": 2147483651 }
          ]
        }
      ]
    }
  ],
  "tilesets": []
}
)json");

    std::string err;
    ASSERT_TRUE(tiled_loader::RegisterMap(mapPath, &err)) << err;
    ASSERT_TRUE(tiled_loader::SetActiveMap("objects"));

    EXPECT_EQ(tiled_loader::CountObjects("objects"), 3u);
    EXPECT_EQ(tiled_loader::CountObjectsInActiveMap(), 3u);

    std::vector<int> objectIds;
    std::vector<std::string> layerNames;
    ASSERT_TRUE(tiled_loader::ForEachObject("objects",
                                            [&](const tiled_loader::LayerData& layer, const tiled_loader::ObjectData& object) {
                                                objectIds.push_back(object.id);
                                                layerNames.push_back(layer.name);
                                            }));
    EXPECT_EQ(objectIds.size(), 3u);
    EXPECT_EQ(layerNames.size(), 3u);
    EXPECT_EQ(objectIds[0], 11);
    EXPECT_EQ(objectIds[1], 12);
    EXPECT_EQ(objectIds[2], 13);
    EXPECT_EQ(layerNames[0], "ObjectsTop");
    EXPECT_EQ(layerNames[2], "ObjectsNested");

    size_t enemyCount = 0;
    ASSERT_TRUE(tiled_loader::ForEachObjectInActiveMap([&](const tiled_loader::LayerData&, const tiled_loader::ObjectData& object) {
        if (object.type == "Enemy") {
            ++enemyCount;
        }
    }));
    EXPECT_EQ(enemyCount, 2u);
}

TEST_F(TiledLoaderTest, LoadRuleFileParsesReferencesAndApplyRulesStub) {
    const fs::path rulesPath = testRoot / "rules.txt";
    WriteFile(rulesPath, R"txt(
# comment
input = maps/biome_input.tmx
output=maps/biome_output.tmx
rules/forest_rule.tmj
noise = 4
; ignored
)txt");

    tiled_loader::RuleDefs defs{};
    std::string err;
    ASSERT_TRUE(tiled_loader::LoadRuleFile(rulesPath, &defs, &err)) << err;

    EXPECT_EQ(defs.id, "rules");
    ASSERT_EQ(defs.entries.size(), 4u);
    ASSERT_EQ(defs.referencedMaps.size(), 3u);
    EXPECT_EQ(defs.referencedMaps[0], "maps/biome_input.tmx");
    EXPECT_EQ(defs.referencedMaps[1], "maps/biome_output.tmx");
    EXPECT_EQ(defs.referencedMaps[2], "rules/forest_rule.tmj");

    ASSERT_TRUE(tiled_loader::LoadRuleDefs(rulesPath, &err)) << err;
    EXPECT_TRUE(tiled_loader::HasRuleDefs("rules"));

    tiled_loader::GridInput grid{};
    grid.width = 2;
    grid.height = 2;
    grid.cells = {1, 0, 2, 3};

    tiled_loader::ProceduralResults out{};
    ASSERT_TRUE(tiled_loader::ApplyRules(grid, "rules", &out, &err)) << err;
    EXPECT_EQ(out.width, 2);
    EXPECT_EQ(out.height, 2);
    ASSERT_EQ(out.cells.size(), 4u);
    EXPECT_TRUE(out.cells[0].empty());
    EXPECT_TRUE(out.cells[1].empty());
}

TEST_F(TiledLoaderTest, ApplyRulesRejectsUnknownRulesetAndInvalidGrid) {
    tiled_loader::ProceduralResults out{};
    std::string err;

    tiled_loader::GridInput invalid{};
    invalid.width = 0;
    invalid.height = 1;
    EXPECT_FALSE(tiled_loader::ApplyRules(invalid, "", &out, &err));

    tiled_loader::GridInput missingCells{};
    missingCells.width = 2;
    missingCells.height = 2;
    missingCells.cells = {1};
    EXPECT_FALSE(tiled_loader::ApplyRules(missingCells, "", &out, &err));

    tiled_loader::GridInput valid{};
    valid.width = 1;
    valid.height = 1;
    valid.cells = {1};
    EXPECT_FALSE(tiled_loader::ApplyRules(valid, "missing_ruleset", &out, &err));
}

TEST_F(TiledLoaderTest, LoadRuleDefsCompilesRuntimeBitmaskRulesDeterministically) {
    const fs::path rulesPath = testRoot / "rules" / "walls.rules.txt";
    const fs::path runtimePath = testRoot / "rules" / "walls.runtime.json";

    WriteFile(rulesPath, R"txt(
runtime_json = walls.runtime.json
)txt");

    WriteFile(runtimePath, R"json(
{
  "default_terrain": 1,
  "rules": [
    { "name": "low_priority", "terrain": 1, "required_mask": 0, "forbidden_mask": 0, "priority": 1, "tile_id": 10 },
    { "name": "high_less_specific", "terrain": 1, "required_mask": 0, "forbidden_mask": 0, "priority": 5, "tile_id": 20 },
    { "name": "high_more_specific_first", "terrain": 1, "required_mask": 0, "forbidden_mask": 15, "priority": 5, "tile_id": 30 },
    { "name": "high_more_specific_second", "terrain": 1, "required_mask": 0, "forbidden_mask": 15, "priority": 5, "tile_id": 40 }
  ]
}
)json");

    std::string err;
    ASSERT_TRUE(tiled_loader::LoadRuleDefs(rulesPath, &err)) << err;
    EXPECT_TRUE(tiled_loader::HasRuleDefs("walls.rules"));

    tiled_loader::GridInput grid{};
    grid.width = 1;
    grid.height = 1;
    grid.cells = {1};

    tiled_loader::ProceduralResults out{};
    ASSERT_TRUE(tiled_loader::ApplyRules(grid, "walls.rules", &out, &err)) << err;
    ASSERT_EQ(out.cells.size(), 1u);
    ASSERT_EQ(out.cells[0].size(), 1u);
    EXPECT_EQ(out.cells[0][0].tileId, 30);
}

TEST_F(TiledLoaderTest, RuntimeBitmaskRulesSupportExactMaskStringParsing) {
    const fs::path rulesPath = testRoot / "rules" / "cross.rules.txt";
    const fs::path runtimePath = testRoot / "rules" / "cross.runtime.json";

    WriteFile(rulesPath, R"txt(
runtime_json = cross.runtime.json
)txt");

    WriteFile(runtimePath, R"json(
{
  "default_terrain": 1,
  "rules": [
    { "name": "cross", "terrain": 1, "exact_mask": "n,e,s,w", "priority": 10, "tile_id": 99 },
    { "name": "fallback", "terrain": 1, "required_mask": 0, "forbidden_mask": 0, "priority": 0, "tile_id": 1 }
  ]
}
)json");

    std::string err;
    ASSERT_TRUE(tiled_loader::LoadRuleDefs(rulesPath, &err)) << err;

    tiled_loader::GridInput grid{};
    grid.width = 3;
    grid.height = 3;
    grid.cells = {
        1, 1, 1,
        1, 1, 1,
        1, 1, 1,
    };

    tiled_loader::ProceduralResults out{};
    ASSERT_TRUE(tiled_loader::ApplyRules(grid, "cross.rules", &out, &err)) << err;
    ASSERT_EQ(out.cells.size(), 9u);
    ASSERT_EQ(out.cells[4].size(), 1u);
    ASSERT_EQ(out.cells[0].size(), 1u);
    EXPECT_EQ(out.cells[4][0].tileId, 99); // center has N/E/S/W neighbors.
    EXPECT_EQ(out.cells[0][0].tileId, 1);  // corner falls back.
}

TEST_F(TiledLoaderTest, LoadRuleDefsRejectsInvalidRuntimeMaskConfig) {
    const fs::path rulesPath = testRoot / "rules" / "bad.rules.txt";
    const fs::path runtimePath = testRoot / "rules" / "bad.runtime.json";

    WriteFile(rulesPath, R"txt(
runtime_json = bad.runtime.json
)txt");

    WriteFile(runtimePath, R"json(
{
  "default_terrain": 1,
  "rules": [
    {
      "name": "invalid_overlap",
      "terrain": 1,
      "required": ["north"],
      "forbidden": ["n"],
      "tile_id": 10
    }
  ]
}
)json");

    std::string err;
    EXPECT_FALSE(tiled_loader::LoadRuleDefs(rulesPath, &err));
    EXPECT_FALSE(err.empty());
}

} // namespace
