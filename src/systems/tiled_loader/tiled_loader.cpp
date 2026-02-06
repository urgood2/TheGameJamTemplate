#include "tiled_loader.hpp"

#include <algorithm>
#include <cctype>
#include <fstream>
#include <limits>
#include <sstream>
#include <unordered_map>
#include <unordered_set>

#include "nlohmann/json.hpp"

namespace tiled_loader {
namespace {

using json = nlohmann::json;

constexpr uint32_t kFlipHorizontalMask = 0x80000000u;
constexpr uint32_t kFlipVerticalMask = 0x40000000u;
constexpr uint32_t kFlipDiagonalMask = 0x20000000u;
constexpr uint32_t kRotatedHex120Mask = 0x10000000u;
constexpr uint32_t kAllTiledFlagBitsMask =
    kFlipHorizontalMask | kFlipVerticalMask | kFlipDiagonalMask | kRotatedHex120Mask;

std::unordered_map<std::string, MapData> g_loadedMaps;
std::string g_activeMap;

std::unordered_map<std::string, RuleDefs> g_loadedRules;
ProceduralResults g_lastProceduralResults;

std::string Trim(std::string_view text) {
    size_t begin = 0;
    while (begin < text.size() && std::isspace(static_cast<unsigned char>(text[begin])) != 0) {
        ++begin;
    }

    size_t end = text.size();
    while (end > begin && std::isspace(static_cast<unsigned char>(text[end - 1])) != 0) {
        --end;
    }

    return std::string(text.substr(begin, end - begin));
}

std::string ToLowerCopy(std::string value) {
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return value;
}

bool EndsWithCaseInsensitive(const std::string& value, const std::string& suffix) {
    if (suffix.size() > value.size()) {
        return false;
    }
    const size_t start = value.size() - suffix.size();
    for (size_t i = 0; i < suffix.size(); ++i) {
        const unsigned char a = static_cast<unsigned char>(value[start + i]);
        const unsigned char b = static_cast<unsigned char>(suffix[i]);
        if (std::tolower(a) != std::tolower(b)) {
            return false;
        }
    }
    return true;
}

bool IsLikelyMapPath(const std::string& value) {
    return EndsWithCaseInsensitive(value, ".tmj") || EndsWithCaseInsensitive(value, ".tmx") ||
           EndsWithCaseInsensitive(value, ".json");
}

std::filesystem::path ResolveRelativePath(const std::filesystem::path& baseDir, const std::string& maybeRelative) {
    std::filesystem::path p{maybeRelative};
    if (p.empty()) {
        return p;
    }
    if (p.is_relative()) {
        p = baseDir / p;
    }
    return p.lexically_normal();
}

bool ReadJsonFile(const std::filesystem::path& path, json* out, std::string* error) {
    if (out == nullptr) {
        if (error) {
            *error = "ReadJsonFile called with null output pointer";
        }
        return false;
    }

    std::ifstream file(path);
    if (!file.is_open()) {
        if (error) {
            *error = "Unable to open file: " + path.string();
        }
        return false;
    }

    try {
        file >> *out;
    } catch (const std::exception& ex) {
        if (error) {
            *error = "Failed to parse JSON from " + path.string() + ": " + ex.what();
        }
        return false;
    }

    return true;
}

Property ParseProperty(const json& propertyJson) {
    Property p{};
    p.name = propertyJson.value("name", "");
    p.type = propertyJson.value("type", "");

    if (!propertyJson.contains("value")) {
        p.value = std::monostate{};
        return p;
    }

    const json& v = propertyJson.at("value");
    if (v.is_boolean()) {
        p.value = v.get<bool>();
    } else if (v.is_number_integer()) {
        p.value = static_cast<int64_t>(v.get<int64_t>());
    } else if (v.is_number_unsigned()) {
        const uint64_t uv = v.get<uint64_t>();
        if (uv > static_cast<uint64_t>(std::numeric_limits<int64_t>::max())) {
            p.value = static_cast<double>(uv);
        } else {
            p.value = static_cast<int64_t>(uv);
        }
    } else if (v.is_number_float()) {
        p.value = v.get<double>();
    } else if (v.is_string()) {
        p.value = v.get<std::string>();
    } else {
        p.value = v.dump();
    }

    return p;
}

void ParseProperties(const json& parentJson, std::vector<Property>* outProperties) {
    if (outProperties == nullptr) {
        return;
    }
    outProperties->clear();

    const auto it = parentJson.find("properties");
    if (it == parentJson.end() || !it->is_array()) {
        return;
    }

    for (const auto& item : *it) {
        if (item.is_object()) {
            outProperties->push_back(ParseProperty(item));
        }
    }
}

bool ParseTileset(const json& tilesetJson, const std::filesystem::path& tilesetPathHint, TilesetData* outTileset, std::string* error) {
    if (outTileset == nullptr) {
        if (error) {
            *error = "ParseTileset called with null output pointer";
        }
        return false;
    }
    if (!tilesetJson.is_object()) {
        if (error) {
            *error = "Tileset JSON node is not an object";
        }
        return false;
    }

    outTileset->sourcePath = tilesetPathHint;
    outTileset->name = tilesetJson.value("name", tilesetPathHint.stem().string());
    outTileset->tileWidth = tilesetJson.value("tilewidth", 0);
    outTileset->tileHeight = tilesetJson.value("tileheight", 0);
    outTileset->tileCount = tilesetJson.value("tilecount", 0);
    outTileset->columns = tilesetJson.value("columns", 0);
    outTileset->image = tilesetJson.value("image", "");
    outTileset->imageWidth = tilesetJson.value("imagewidth", 0);
    outTileset->imageHeight = tilesetJson.value("imageheight", 0);

    if (!outTileset->image.empty()) {
        const auto baseDir = tilesetPathHint.has_parent_path() ? tilesetPathHint.parent_path() : std::filesystem::path{};
        outTileset->resolvedImagePath = ResolveRelativePath(baseDir, outTileset->image);
    } else {
        outTileset->resolvedImagePath.clear();
    }

    return true;
}

bool ParseLayer(const json& layerJson, const std::filesystem::path& mapDir, LayerData* outLayer, std::string* error);

void ParseObjectPolyline(const json& pointsJson, std::vector<ObjectPoint>* out) {
    if (out == nullptr || !pointsJson.is_array()) {
        return;
    }
    out->clear();
    out->reserve(pointsJson.size());
    for (const auto& pt : pointsJson) {
        if (!pt.is_object()) {
            continue;
        }
        ObjectPoint p{};
        p.x = pt.value("x", 0.0f);
        p.y = pt.value("y", 0.0f);
        out->push_back(p);
    }
}

bool ParseObject(const json& objectJson, ObjectData* outObject, std::string* error) {
    if (outObject == nullptr) {
        if (error) {
            *error = "ParseObject called with null output pointer";
        }
        return false;
    }
    if (!objectJson.is_object()) {
        if (error) {
            *error = "Object JSON node is not an object";
        }
        return false;
    }

    outObject->id = objectJson.value("id", 0);
    outObject->name = objectJson.value("name", "");
    outObject->type = objectJson.value("type", "");
    outObject->className = objectJson.value("class", "");
    outObject->x = objectJson.value("x", 0.0f);
    outObject->y = objectJson.value("y", 0.0f);
    outObject->width = objectJson.value("width", 0.0f);
    outObject->height = objectJson.value("height", 0.0f);
    outObject->rotation = objectJson.value("rotation", 0.0f);
    outObject->visible = objectJson.value("visible", true);
    outObject->point = objectJson.value("point", false);
    outObject->ellipse = objectJson.value("ellipse", false);

    if (objectJson.contains("gid")) {
        const auto& gidJson = objectJson.at("gid");
        if (gidJson.is_number_unsigned()) {
            outObject->gid = static_cast<uint32_t>(gidJson.get<uint64_t>());
        } else if (gidJson.is_number_integer()) {
            const int64_t gidValue = gidJson.get<int64_t>();
            if (gidValue >= 0) {
                outObject->gid = static_cast<uint32_t>(gidValue);
            }
        }
    } else {
        outObject->gid.reset();
    }

    if (objectJson.contains("polygon")) {
        ParseObjectPolyline(objectJson.at("polygon"), &outObject->polygon);
    } else {
        outObject->polygon.clear();
    }

    if (objectJson.contains("polyline")) {
        ParseObjectPolyline(objectJson.at("polyline"), &outObject->polyline);
    } else {
        outObject->polyline.clear();
    }

    ParseProperties(objectJson, &outObject->properties);
    return true;
}

LayerType ParseLayerType(const std::string& type) {
    const std::string lowered = ToLowerCopy(type);
    if (lowered == "tilelayer") return LayerType::TileLayer;
    if (lowered == "objectgroup") return LayerType::ObjectGroup;
    if (lowered == "imagelayer") return LayerType::ImageLayer;
    if (lowered == "group") return LayerType::Group;
    return LayerType::Unknown;
}

bool ParseTileLayer(const json& layerJson, TileLayerData* outTileLayer, std::string* error) {
    if (outTileLayer == nullptr) {
        if (error) {
            *error = "ParseTileLayer called with null output pointer";
        }
        return false;
    }

    outTileLayer->x = layerJson.value("x", 0);
    outTileLayer->y = layerJson.value("y", 0);
    outTileLayer->width = layerJson.value("width", 0);
    outTileLayer->height = layerJson.value("height", 0);
    outTileLayer->gids.clear();
    outTileLayer->chunks.clear();

    const auto dataIt = layerJson.find("data");
    if (dataIt != layerJson.end() && dataIt->is_array()) {
        outTileLayer->gids.reserve(dataIt->size());
        for (const auto& gidNode : *dataIt) {
            if (gidNode.is_number_unsigned()) {
                outTileLayer->gids.push_back(static_cast<uint32_t>(gidNode.get<uint64_t>()));
            } else if (gidNode.is_number_integer()) {
                const int64_t gid = gidNode.get<int64_t>();
                outTileLayer->gids.push_back(gid < 0 ? 0u : static_cast<uint32_t>(gid));
            } else {
                outTileLayer->gids.push_back(0);
            }
        }
    }

    const auto chunksIt = layerJson.find("chunks");
    if (chunksIt != layerJson.end() && chunksIt->is_array()) {
        outTileLayer->chunks.reserve(chunksIt->size());
        for (const auto& chunkJson : *chunksIt) {
            if (!chunkJson.is_object()) {
                continue;
            }
            ChunkData chunk{};
            chunk.x = chunkJson.value("x", 0);
            chunk.y = chunkJson.value("y", 0);
            chunk.width = chunkJson.value("width", 0);
            chunk.height = chunkJson.value("height", 0);
            const auto chunkDataIt = chunkJson.find("data");
            if (chunkDataIt != chunkJson.end() && chunkDataIt->is_array()) {
                chunk.gids.reserve(chunkDataIt->size());
                for (const auto& gidNode : *chunkDataIt) {
                    if (gidNode.is_number_unsigned()) {
                        chunk.gids.push_back(static_cast<uint32_t>(gidNode.get<uint64_t>()));
                    } else if (gidNode.is_number_integer()) {
                        const int64_t gid = gidNode.get<int64_t>();
                        chunk.gids.push_back(gid < 0 ? 0u : static_cast<uint32_t>(gid));
                    } else {
                        chunk.gids.push_back(0u);
                    }
                }
            }
            outTileLayer->chunks.push_back(std::move(chunk));
        }
    }

    return true;
}

bool ParseLayer(const json& layerJson, const std::filesystem::path& mapDir, LayerData* outLayer, std::string* error) {
    (void)mapDir;
    if (outLayer == nullptr) {
        if (error) {
            *error = "ParseLayer called with null output pointer";
        }
        return false;
    }
    if (!layerJson.is_object()) {
        if (error) {
            *error = "Layer JSON node is not an object";
        }
        return false;
    }

    outLayer->id = layerJson.value("id", 0);
    outLayer->name = layerJson.value("name", "");
    outLayer->type = ParseLayerType(layerJson.value("type", ""));
    outLayer->opacity = layerJson.value("opacity", 1.0f);
    outLayer->visible = layerJson.value("visible", true);
    outLayer->x = layerJson.value("x", 0);
    outLayer->y = layerJson.value("y", 0);
    outLayer->width = layerJson.value("width", 0);
    outLayer->height = layerJson.value("height", 0);
    outLayer->tileLayer.reset();
    outLayer->objects.clear();
    outLayer->children.clear();
    ParseProperties(layerJson, &outLayer->properties);

    if (outLayer->type == LayerType::TileLayer) {
        TileLayerData tileLayer{};
        if (!ParseTileLayer(layerJson, &tileLayer, error)) {
            return false;
        }
        outLayer->tileLayer = std::move(tileLayer);
    } else if (outLayer->type == LayerType::ObjectGroup) {
        const auto objectsIt = layerJson.find("objects");
        if (objectsIt != layerJson.end() && objectsIt->is_array()) {
            outLayer->objects.reserve(objectsIt->size());
            for (const auto& objectJson : *objectsIt) {
                ObjectData object{};
                if (!ParseObject(objectJson, &object, error)) {
                    return false;
                }
                outLayer->objects.push_back(std::move(object));
            }
        }
    } else if (outLayer->type == LayerType::Group) {
        const auto childrenIt = layerJson.find("layers");
        if (childrenIt != layerJson.end() && childrenIt->is_array()) {
            outLayer->children.reserve(childrenIt->size());
            for (const auto& childJson : *childrenIt) {
                LayerData child{};
                if (!ParseLayer(childJson, mapDir, &child, error)) {
                    return false;
                }
                outLayer->children.push_back(std::move(child));
            }
        }
    }

    return true;
}

bool ParseMapJson(const json& mapJson, const std::filesystem::path& mapPath, MapData* outMap, std::string* error) {
    if (outMap == nullptr) {
        if (error) {
            *error = "ParseMapJson called with null output pointer";
        }
        return false;
    }
    if (!mapJson.is_object()) {
        if (error) {
            *error = "Map JSON root is not an object";
        }
        return false;
    }

    outMap->sourcePath = mapPath;
    outMap->id = MapIdFromPath(mapPath);
    outMap->name = mapJson.value("name", outMap->id);
    outMap->orientation = mapJson.value("orientation", "orthogonal");
    outMap->renderOrder = mapJson.value("renderorder", "right-down");
    outMap->width = mapJson.value("width", 0);
    outMap->height = mapJson.value("height", 0);
    outMap->tileWidth = mapJson.value("tilewidth", 0);
    outMap->tileHeight = mapJson.value("tileheight", 0);
    outMap->infinite = mapJson.value("infinite", false);
    outMap->layers.clear();
    outMap->tilesetRefs.clear();
    outMap->tilesets.clear();

    const std::filesystem::path mapDir = mapPath.has_parent_path() ? mapPath.parent_path() : std::filesystem::path{};

    const auto layersIt = mapJson.find("layers");
    if (layersIt != mapJson.end() && layersIt->is_array()) {
        outMap->layers.reserve(layersIt->size());
        for (const auto& layerJson : *layersIt) {
            LayerData layer{};
            if (!ParseLayer(layerJson, mapDir, &layer, error)) {
                return false;
            }
            outMap->layers.push_back(std::move(layer));
        }
    }

    const auto tilesetsIt = mapJson.find("tilesets");
    if (tilesetsIt != mapJson.end() && tilesetsIt->is_array()) {
        outMap->tilesetRefs.reserve(tilesetsIt->size());
        outMap->tilesets.reserve(tilesetsIt->size());
        for (const auto& tilesetRefJson : *tilesetsIt) {
            if (!tilesetRefJson.is_object()) {
                continue;
            }

            TilesetRef ref{};
            ref.firstGid = tilesetRefJson.value("firstgid", 0);
            ref.source = tilesetRefJson.value("source", "");
            if (!ref.source.empty()) {
                ref.resolvedSourcePath = ResolveRelativePath(mapDir, ref.source);
            } else {
                ref.resolvedSourcePath = mapPath;
            }

            TilesetData tileset{};
            if (!ref.source.empty()) {
                json tilesetJson{};
                if (!ReadJsonFile(ref.resolvedSourcePath, &tilesetJson, error)) {
                    return false;
                }
                if (!ParseTileset(tilesetJson, ref.resolvedSourcePath, &tileset, error)) {
                    return false;
                }
            } else {
                if (!ParseTileset(tilesetRefJson, mapPath, &tileset, error)) {
                    return false;
                }
            }

            outMap->tilesetRefs.push_back(std::move(ref));
            outMap->tilesets.push_back(std::move(tileset));
        }
    }

    std::vector<size_t> order(outMap->tilesetRefs.size());
    for (size_t i = 0; i < order.size(); ++i) {
        order[i] = i;
    }
    std::sort(order.begin(), order.end(), [outMap](size_t a, size_t b) {
        return outMap->tilesetRefs[a].firstGid < outMap->tilesetRefs[b].firstGid;
    });

    std::vector<TilesetRef> sortedRefs;
    std::vector<TilesetData> sortedTilesets;
    sortedRefs.reserve(order.size());
    sortedTilesets.reserve(order.size());
    for (const size_t idx : order) {
        sortedRefs.push_back(std::move(outMap->tilesetRefs[idx]));
        sortedTilesets.push_back(std::move(outMap->tilesets[idx]));
    }
    outMap->tilesetRefs = std::move(sortedRefs);
    outMap->tilesets = std::move(sortedTilesets);

    return true;
}

} // namespace

DecodedGid DecodeGid(uint32_t gid) {
    DecodedGid decoded{};
    decoded.flags.flipHorizontally = (gid & kFlipHorizontalMask) != 0;
    decoded.flags.flipVertically = (gid & kFlipVerticalMask) != 0;
    decoded.flags.flipDiagonally = (gid & kFlipDiagonalMask) != 0;
    decoded.flags.rotatedHex120 = (gid & kRotatedHex120Mask) != 0;
    decoded.tileId = gid & ~kAllTiledFlagBitsMask;
    return decoded;
}

std::string MapIdFromPath(const std::filesystem::path& path) {
    const std::string stem = path.stem().string();
    return stem.empty() ? path.filename().string() : stem;
}

std::string RulesetIdFromPath(const std::filesystem::path& path) {
    const std::string stem = path.stem().string();
    return stem.empty() ? path.filename().string() : stem;
}

bool LoadMapFile(const std::filesystem::path& mapPath, MapData* outMap, std::string* error) {
    json mapJson{};
    if (!ReadJsonFile(mapPath, &mapJson, error)) {
        return false;
    }
    return ParseMapJson(mapJson, mapPath, outMap, error);
}

bool LoadRuleFile(const std::filesystem::path& rulesPath, RuleDefs* outRules, std::string* error) {
    if (outRules == nullptr) {
        if (error) {
            *error = "LoadRuleFile called with null output pointer";
        }
        return false;
    }

    std::ifstream in(rulesPath);
    if (!in.is_open()) {
        if (error) {
            *error = "Unable to open rules file: " + rulesPath.string();
        }
        return false;
    }

    outRules->id = RulesetIdFromPath(rulesPath);
    outRules->sourcePath = rulesPath;
    outRules->entries.clear();
    outRules->referencedMaps.clear();

    std::unordered_set<std::string> seenRefs;

    std::string line;
    int lineNumber = 0;
    while (std::getline(in, line)) {
        ++lineNumber;
        const std::string trimmed = Trim(line);
        if (trimmed.empty()) {
            continue;
        }
        if (trimmed.rfind("#", 0) == 0 || trimmed.rfind(";", 0) == 0 || trimmed.rfind("//", 0) == 0) {
            continue;
        }

        RuleEntry entry{};
        entry.lineNumber = lineNumber;
        entry.raw = trimmed;

        const size_t eq = trimmed.find('=');
        if (eq != std::string::npos) {
            entry.key = Trim(std::string_view(trimmed).substr(0, eq));
            entry.value = Trim(std::string_view(trimmed).substr(eq + 1));

            const std::string keyLower = ToLowerCopy(*entry.key);
            if ((keyLower == "rule" || keyLower == "input" || keyLower == "output" || keyLower == "map" ||
                 keyLower == "rulemap") &&
                IsLikelyMapPath(*entry.value)) {
                if (seenRefs.insert(*entry.value).second) {
                    outRules->referencedMaps.push_back(*entry.value);
                }
            }
        } else if (IsLikelyMapPath(trimmed)) {
            if (seenRefs.insert(trimmed).second) {
                outRules->referencedMaps.push_back(trimmed);
            }
        }

        outRules->entries.push_back(std::move(entry));
    }

    return true;
}

bool RegisterMap(const std::filesystem::path& mapPath, std::string* error) {
    MapData parsed{};
    if (!LoadMapFile(mapPath, &parsed, error)) {
        return false;
    }
    g_loadedMaps[parsed.id] = std::move(parsed);
    return true;
}

bool HasMap(const std::string& mapId) {
    return g_loadedMaps.find(mapId) != g_loadedMaps.end();
}

const MapData* GetMap(const std::string& mapId) {
    const auto it = g_loadedMaps.find(mapId);
    if (it == g_loadedMaps.end()) {
        return nullptr;
    }
    return &it->second;
}

std::vector<std::string> GetLoadedMapIds() {
    std::vector<std::string> ids;
    ids.reserve(g_loadedMaps.size());
    for (const auto& kv : g_loadedMaps) {
        ids.push_back(kv.first);
    }
    std::sort(ids.begin(), ids.end());
    return ids;
}

void ClearAllMaps() {
    g_loadedMaps.clear();
    g_activeMap.clear();
}

bool SetActiveMap(const std::string& mapId) {
    if (!HasMap(mapId)) {
        return false;
    }
    g_activeMap = mapId;
    return true;
}

bool HasActiveMap() {
    return !g_activeMap.empty() && HasMap(g_activeMap);
}

std::string GetActiveMap() {
    return HasActiveMap() ? g_activeMap : std::string{};
}

bool LoadRuleDefs(const std::filesystem::path& rulesPath, std::string* error) {
    RuleDefs rules{};
    if (!LoadRuleFile(rulesPath, &rules, error)) {
        return false;
    }
    g_loadedRules[rules.id] = std::move(rules);
    return true;
}

bool HasRuleDefs(const std::string& rulesetId) {
    return g_loadedRules.find(rulesetId) != g_loadedRules.end();
}

std::vector<std::string> GetLoadedRulesetIds() {
    std::vector<std::string> ids;
    ids.reserve(g_loadedRules.size());
    for (const auto& kv : g_loadedRules) {
        ids.push_back(kv.first);
    }
    std::sort(ids.begin(), ids.end());
    return ids;
}

void ClearRuleDefs() {
    g_loadedRules.clear();
}

bool ApplyRules(const GridInput& grid, const std::string& rulesetId, ProceduralResults* out, std::string* error) {
    if (out == nullptr) {
        if (error) {
            *error = "ApplyRules called with null output pointer";
        }
        return false;
    }
    if (grid.width <= 0 || grid.height <= 0) {
        if (error) {
            *error = "ApplyRules requires positive grid width and height";
        }
        return false;
    }

    const size_t expectedCells = static_cast<size_t>(grid.width) * static_cast<size_t>(grid.height);
    if (grid.cells.size() < expectedCells) {
        if (error) {
            std::ostringstream oss;
            oss << "ApplyRules expected at least " << expectedCells << " cells, got " << grid.cells.size();
            *error = oss.str();
        }
        return false;
    }

    if (!rulesetId.empty() && !HasRuleDefs(rulesetId)) {
        if (error) {
            *error = "Unknown ruleset id: " + rulesetId;
        }
        return false;
    }

    out->width = grid.width;
    out->height = grid.height;
    out->cells.assign(expectedCells, {});

    g_lastProceduralResults = *out;
    return true;
}

const ProceduralResults& GetLastProceduralResults() {
    return g_lastProceduralResults;
}

void CleanupProcedural() {
    g_lastProceduralResults = ProceduralResults{};
}

} // namespace tiled_loader

