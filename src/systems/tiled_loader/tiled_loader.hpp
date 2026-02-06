#pragma once

#include <cstddef>
#include <functional>
#include <cstdint>
#include <filesystem>
#include <optional>
#include <string>
#include <variant>
#include <vector>

namespace sol {
class state;
}

namespace tiled_loader {

struct GidFlags {
    bool flipHorizontally = false;
    bool flipVertically = false;
    bool flipDiagonally = false;
    bool rotatedHex120 = false;
};

struct DecodedGid {
    uint32_t tileId = 0; // Global tile id with Tiled high-bit flags stripped.
    GidFlags flags{};
};

DecodedGid DecodeGid(uint32_t gid);

struct TileTransform {
    bool flipX = false;
    bool flipY = false;
    int rotationDegrees = 0; // Orthogonal mode: 0, 90, 180, 270.
};

TileTransform OrthogonalTransformFromFlags(const GidFlags& flags);

using PropertyValue = std::variant<std::monostate, bool, int64_t, double, std::string>;

struct Property {
    std::string name;
    std::string type;
    PropertyValue value;
};

struct TilesetRef {
    int firstGid = 0;
    std::string source; // Relative path from map file if external.
    std::filesystem::path resolvedSourcePath;
};

struct TilesetData {
    std::string name;
    int tileWidth = 0;
    int tileHeight = 0;
    int tileCount = 0;
    int columns = 0;
    std::string image;
    int imageWidth = 0;
    int imageHeight = 0;
    std::filesystem::path sourcePath;
    std::filesystem::path resolvedImagePath;
};

enum class LayerType {
    Unknown,
    TileLayer,
    ObjectGroup,
    ImageLayer,
    Group,
};

struct ChunkData {
    int x = 0;
    int y = 0;
    int width = 0;
    int height = 0;
    std::vector<uint32_t> gids;
};

struct TileLayerData {
    int x = 0;
    int y = 0;
    int width = 0;
    int height = 0;
    std::vector<uint32_t> gids;      // Finite maps.
    std::vector<ChunkData> chunks;   // Infinite maps.
};

struct ObjectPoint {
    float x = 0.0f;
    float y = 0.0f;
};

struct ObjectData {
    int id = 0;
    std::string name;
    std::string type;
    std::string className;
    float x = 0.0f;
    float y = 0.0f;
    float width = 0.0f;
    float height = 0.0f;
    float rotation = 0.0f;
    std::optional<uint32_t> gid;
    bool visible = true;
    bool point = false;
    bool ellipse = false;
    std::vector<ObjectPoint> polygon;
    std::vector<ObjectPoint> polyline;
    std::vector<Property> properties;
};

struct LayerData {
    int id = 0;
    std::string name;
    LayerType type = LayerType::Unknown;
    float opacity = 1.0f;
    bool visible = true;
    int x = 0;
    int y = 0;
    int width = 0;
    int height = 0;
    std::optional<TileLayerData> tileLayer;
    std::vector<ObjectData> objects;
    std::vector<Property> properties;
    std::vector<LayerData> children; // For group layers.
};

struct MapData {
    std::string id; // Derived from map file stem by default.
    std::string name;
    std::filesystem::path sourcePath;
    std::string orientation;
    std::string renderOrder;
    int width = 0;
    int height = 0;
    int tileWidth = 0;
    int tileHeight = 0;
    bool infinite = false;
    std::vector<LayerData> layers;
    std::vector<TilesetRef> tilesetRefs;
    std::vector<TilesetData> tilesets;
};

struct ResolvedTileSource {
    size_t tilesetIndex = 0;
    int firstGid = 0;
    int localTileId = 0;
    int sourceX = 0;
    int sourceY = 0;
    int sourceWidth = 0;
    int sourceHeight = 0;
};

struct RuleEntry {
    int lineNumber = 0;
    std::string raw;
    std::optional<std::string> key;
    std::optional<std::string> value;
};

struct RuleDefs {
    std::string id; // Derived from rules file stem by default.
    std::filesystem::path sourcePath;
    std::vector<RuleEntry> entries;
    std::vector<std::string> referencedMaps;
};

struct GridInput {
    int width = 0;
    int height = 0;
    std::vector<int> cells; // Row-major (x + y * width), Lua 1-indexed on bindings.
};

struct ProceduralTile {
    int tileId = 0;
    bool flipX = false;
    bool flipY = false;
    int rotation = 0;
    float offsetX = 0.0f;
    float offsetY = 0.0f;
    float opacity = 1.0f;
};

struct ProceduralResults {
    int width = 0;
    int height = 0;
    std::vector<std::vector<ProceduralTile>> cells;
};

std::string MapIdFromPath(const std::filesystem::path& path);
std::string RulesetIdFromPath(const std::filesystem::path& path);

bool LoadMapFile(const std::filesystem::path& mapPath, MapData* outMap, std::string* error = nullptr);
bool LoadRuleFile(const std::filesystem::path& rulesPath, RuleDefs* outRules, std::string* error = nullptr);
bool ResolveTileSource(const MapData& map, uint32_t tileId, ResolvedTileSource* outTile, std::string* error = nullptr);

bool RegisterMap(const std::filesystem::path& mapPath, std::string* error = nullptr);
bool HasMap(const std::string& mapId);
const MapData* GetMap(const std::string& mapId);
std::vector<std::string> GetLoadedMapIds();
void ClearAllMaps();

bool SetActiveMap(const std::string& mapId);
bool HasActiveMap();
std::string GetActiveMap();
size_t CountObjects(const std::string& mapId);
size_t CountObjectsInActiveMap();
bool ForEachObject(const std::string& mapId, const std::function<void(const LayerData&, const ObjectData&)>& visitor);
bool ForEachObjectInActiveMap(const std::function<void(const LayerData&, const ObjectData&)>& visitor);

bool LoadRuleDefs(const std::filesystem::path& rulesPath, std::string* error = nullptr);
bool HasRuleDefs(const std::string& rulesetId);
std::vector<std::string> GetLoadedRulesetIds();
void ClearRuleDefs();

bool ApplyRules(const GridInput& grid, const std::string& rulesetId, ProceduralResults* out, std::string* error = nullptr);
const ProceduralResults& GetLastProceduralResults();
void CleanupProcedural();

void exposeToLua(sol::state& lua);

} // namespace tiled_loader
