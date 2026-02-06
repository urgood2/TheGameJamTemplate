#include <gtest/gtest.h>

#include <filesystem>
#include <fstream>

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

} // namespace

