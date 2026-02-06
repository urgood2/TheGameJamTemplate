#include "tiled_loader.hpp"

#include <algorithm>
#include <cctype>
#include <cstdlib>
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

constexpr int kMaskNorth = 1;
constexpr int kMaskEast = 2;
constexpr int kMaskSouth = 4;
constexpr int kMaskWest = 8;
constexpr int kMaskAllCardinal = kMaskNorth | kMaskEast | kMaskSouth | kMaskWest;

struct BitmaskRule {
    int terrain = 0;
    int requiredMask = 0;
    int forbiddenMask = 0;
    int priority = 0;
    int order = 0;
    std::string name;
    ProceduralTile tile;
};

struct CompiledRuleset {
    RuleDefs defs;
    std::vector<BitmaskRule> bitmaskRules;
    std::filesystem::path runtimeRulesPath;
};

std::unordered_map<std::string, MapData> g_loadedMaps;
std::string g_activeMap;

std::unordered_map<std::string, CompiledRuleset> g_loadedRules;
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

bool IsLikelyRuntimeRulePath(const std::string& value) {
    return EndsWithCaseInsensitive(value, ".json");
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

int CountBits(int value) {
    value &= kMaskAllCardinal;
    int count = 0;
    while (value != 0) {
        count += (value & 1);
        value >>= 1;
    }
    return count;
}

int DirectionTokenToMask(const std::string& token) {
    const std::string lowered = ToLowerCopy(token);
    if (lowered == "n" || lowered == "north" || lowered == "up") {
        return kMaskNorth;
    }
    if (lowered == "e" || lowered == "east" || lowered == "right") {
        return kMaskEast;
    }
    if (lowered == "s" || lowered == "south" || lowered == "down") {
        return kMaskSouth;
    }
    if (lowered == "w" || lowered == "west" || lowered == "left") {
        return kMaskWest;
    }
    return 0;
}

std::optional<int> ParseMaskFromString(const std::string& text, std::string* error) {
    const std::string trimmed = Trim(text);
    if (trimmed.empty()) {
        return 0;
    }

    char* endPtr = nullptr;
    const long parsedInt = std::strtol(trimmed.c_str(), &endPtr, 0);
    if (endPtr != nullptr && *endPtr == '\0') {
        if (parsedInt < 0 || parsedInt > kMaskAllCardinal) {
            if (error) {
                *error = "Mask integer out of [0, 15] range: " + trimmed;
            }
            return std::nullopt;
        }
        return static_cast<int>(parsedInt);
    }

    int mask = 0;
    bool parsedAny = false;
    std::string token;
    auto flushToken = [&]() -> bool {
        if (token.empty()) {
            return true;
        }

        const int singleDirectionMask = DirectionTokenToMask(token);
        if (singleDirectionMask != 0) {
            mask |= singleDirectionMask;
            parsedAny = true;
            token.clear();
            return true;
        }

        bool consumedAsDirectionSequence = true;
        int seqMask = 0;
        for (char c : token) {
            const std::string oneChar(1, static_cast<char>(std::tolower(static_cast<unsigned char>(c))));
            const int m = DirectionTokenToMask(oneChar);
            if (m == 0) {
                consumedAsDirectionSequence = false;
                break;
            }
            seqMask |= m;
        }
        if (consumedAsDirectionSequence) {
            mask |= seqMask;
            parsedAny = true;
            token.clear();
            return true;
        }

        if (error) {
            *error = "Unknown direction token in mask string: '" + token + "'";
        }
        return false;
    };

    for (char c : trimmed) {
        const unsigned char uc = static_cast<unsigned char>(c);
        if (std::isalnum(uc) != 0 || c == '_') {
            token.push_back(c);
            continue;
        }
        if (!flushToken()) {
            return std::nullopt;
        }
    }
    if (!flushToken()) {
        return std::nullopt;
    }

    if (!parsedAny) {
        if (error) {
            *error = "Failed to parse mask string: '" + trimmed + "'";
        }
        return std::nullopt;
    }

    return mask & kMaskAllCardinal;
}

std::optional<int> ParseMaskNode(const json& node, const std::string& fieldName, std::string* error) {
    if (node.is_null()) {
        return 0;
    }
    if (node.is_number_unsigned()) {
        const uint64_t uv = node.get<uint64_t>();
        if (uv > static_cast<uint64_t>(kMaskAllCardinal)) {
            if (error) {
                *error = "Mask '" + fieldName + "' out of [0, 15] range";
            }
            return std::nullopt;
        }
        return static_cast<int>(uv);
    }
    if (node.is_number_integer()) {
        const int64_t iv = node.get<int64_t>();
        if (iv < 0 || iv > kMaskAllCardinal) {
            if (error) {
                *error = "Mask '" + fieldName + "' out of [0, 15] range";
            }
            return std::nullopt;
        }
        return static_cast<int>(iv);
    }
    if (node.is_string()) {
        return ParseMaskFromString(node.get<std::string>(), error);
    }
    if (node.is_array()) {
        int mask = 0;
        for (const auto& item : node) {
            auto parsed = ParseMaskNode(item, fieldName, error);
            if (!parsed.has_value()) {
                return std::nullopt;
            }
            mask |= parsed.value();
        }
        return mask & kMaskAllCardinal;
    }

    if (error) {
        *error = "Mask field '" + fieldName + "' must be int|string|array";
    }
    return std::nullopt;
}

bool ParseTileSpec(const json& ruleJson, ProceduralTile* outTile, std::string* error) {
    if (outTile == nullptr) {
        if (error) {
            *error = "ParseTileSpec called with null output pointer";
        }
        return false;
    }

    outTile->tileId = 0;
    outTile->flipX = false;
    outTile->flipY = false;
    outTile->rotation = 0;
    outTile->offsetX = 0.0f;
    outTile->offsetY = 0.0f;
    outTile->opacity = 1.0f;

    const json* tileNode = &ruleJson;
    const auto tileIt = ruleJson.find("tile");
    if (tileIt != ruleJson.end()) {
        if (!tileIt->is_object()) {
            if (error) {
                *error = "Rule 'tile' field must be an object";
            }
            return false;
        }
        tileNode = &(*tileIt);
    }

    auto parseIntField = [&](const json& node, const std::string& key, int* outValue) -> bool {
        const auto it = node.find(key);
        if (it == node.end()) {
            return false;
        }
        if (it->is_number_integer()) {
            *outValue = static_cast<int>(it->get<int64_t>());
            return true;
        }
        if (it->is_number_unsigned()) {
            *outValue = static_cast<int>(it->get<uint64_t>());
            return true;
        }
        if (error) {
            *error = "Tile field '" + key + "' must be an integer";
        }
        return false;
    };

    if (!(parseIntField(*tileNode, "id", &outTile->tileId) || parseIntField(*tileNode, "tile_id", &outTile->tileId) ||
          parseIntField(ruleJson, "tile_id", &outTile->tileId))) {
        if (error) {
            *error = "Rule tile spec is missing required tile id";
        }
        return false;
    }

    outTile->flipX = tileNode->value("flip_x", ruleJson.value("flip_x", false));
    outTile->flipY = tileNode->value("flip_y", ruleJson.value("flip_y", false));
    outTile->rotation = tileNode->value("rotation", ruleJson.value("rotation", 0));
    outTile->offsetX = tileNode->value("offset_x", ruleJson.value("offset_x", 0.0f));
    outTile->offsetY = tileNode->value("offset_y", ruleJson.value("offset_y", 0.0f));
    outTile->opacity = tileNode->value("opacity", ruleJson.value("opacity", ruleJson.value("alpha", 1.0f)));

    return true;
}

bool ParseBitmaskRule(const json& ruleJson, int defaultTerrain, int order, BitmaskRule* outRule, std::string* error) {
    if (outRule == nullptr) {
        if (error) {
            *error = "ParseBitmaskRule called with null output pointer";
        }
        return false;
    }
    if (!ruleJson.is_object()) {
        if (error) {
            *error = "Rule entry must be an object";
        }
        return false;
    }

    outRule->terrain = defaultTerrain;
    if (ruleJson.contains("terrain")) {
        const auto& terrainNode = ruleJson.at("terrain");
        if (terrainNode.is_number_integer()) {
            outRule->terrain = static_cast<int>(terrainNode.get<int64_t>());
        } else if (terrainNode.is_number_unsigned()) {
            outRule->terrain = static_cast<int>(terrainNode.get<uint64_t>());
        } else {
            if (error) {
                *error = "Rule 'terrain' must be an integer";
            }
            return false;
        }
    }

    outRule->requiredMask = 0;
    outRule->forbiddenMask = 0;

    if (ruleJson.contains("required_mask")) {
        const auto parsed = ParseMaskNode(ruleJson.at("required_mask"), "required_mask", error);
        if (!parsed.has_value()) {
            return false;
        }
        outRule->requiredMask = parsed.value();
    }
    if (ruleJson.contains("required")) {
        const auto parsed = ParseMaskNode(ruleJson.at("required"), "required", error);
        if (!parsed.has_value()) {
            return false;
        }
        outRule->requiredMask |= parsed.value();
    }
    if (ruleJson.contains("forbidden_mask")) {
        const auto parsed = ParseMaskNode(ruleJson.at("forbidden_mask"), "forbidden_mask", error);
        if (!parsed.has_value()) {
            return false;
        }
        outRule->forbiddenMask = parsed.value();
    }
    if (ruleJson.contains("forbidden")) {
        const auto parsed = ParseMaskNode(ruleJson.at("forbidden"), "forbidden", error);
        if (!parsed.has_value()) {
            return false;
        }
        outRule->forbiddenMask |= parsed.value();
    }
    if (ruleJson.contains("exact_mask")) {
        const auto parsed = ParseMaskNode(ruleJson.at("exact_mask"), "exact_mask", error);
        if (!parsed.has_value()) {
            return false;
        }
        outRule->requiredMask = parsed.value();
        outRule->forbiddenMask = (~parsed.value()) & kMaskAllCardinal;
    }

    outRule->requiredMask &= kMaskAllCardinal;
    outRule->forbiddenMask &= kMaskAllCardinal;

    if ((outRule->requiredMask & outRule->forbiddenMask) != 0) {
        if (error) {
            *error = "Rule required/forbidden masks overlap";
        }
        return false;
    }

    outRule->priority = ruleJson.value("priority", 0);
    outRule->name = ruleJson.value("name", "rule_" + std::to_string(order));
    outRule->order = order;

    if (!ParseTileSpec(ruleJson, &outRule->tile, error)) {
        return false;
    }

    return true;
}

bool ParseRuntimeBitmaskRulesFile(const std::filesystem::path& runtimePath, CompiledRuleset* outRuleset, std::string* error) {
    if (outRuleset == nullptr) {
        if (error) {
            *error = "ParseRuntimeBitmaskRulesFile called with null output pointer";
        }
        return false;
    }

    json root{};
    if (!ReadJsonFile(runtimePath, &root, error)) {
        return false;
    }
    if (!root.is_object()) {
        if (error) {
            *error = "Runtime rules JSON root must be an object";
        }
        return false;
    }

    const auto rulesIt = root.find("rules");
    if (rulesIt == root.end() || !rulesIt->is_array()) {
        if (error) {
            *error = "Runtime rules JSON requires a 'rules' array";
        }
        return false;
    }

    const int defaultTerrain = root.value("default_terrain", 1);
    outRuleset->runtimeRulesPath = runtimePath;
    outRuleset->bitmaskRules.clear();
    outRuleset->bitmaskRules.reserve(rulesIt->size());

    int order = 0;
    for (const auto& ruleJson : *rulesIt) {
        BitmaskRule parsed{};
        if (!ParseBitmaskRule(ruleJson, defaultTerrain, order, &parsed, error)) {
            if (error && !error->empty()) {
                std::ostringstream oss;
                oss << "Runtime rule parse failed at index " << order << ": " << *error;
                *error = oss.str();
            }
            return false;
        }
        outRuleset->bitmaskRules.push_back(std::move(parsed));
        ++order;
    }

    return true;
}

std::optional<std::string> FindRuleEntryValue(const RuleDefs& defs, std::initializer_list<const char*> keys) {
    std::unordered_set<std::string> expectedKeys;
    expectedKeys.reserve(keys.size());
    for (const char* key : keys) {
        expectedKeys.insert(ToLowerCopy(std::string(key)));
    }

    for (const auto& entry : defs.entries) {
        if (!entry.key.has_value() || !entry.value.has_value()) {
            continue;
        }
        const std::string lowered = ToLowerCopy(*entry.key);
        if (expectedKeys.find(lowered) != expectedKeys.end()) {
            return entry.value.value();
        }
    }

    return std::nullopt;
}

int ComputeCardinalMaskForCell(const GridInput& grid, int x, int y, int terrain) {
    auto cellAt = [&](int tx, int ty) -> int {
        const size_t idx = static_cast<size_t>(ty) * static_cast<size_t>(grid.width) + static_cast<size_t>(tx);
        return grid.cells[idx];
    };

    int mask = 0;
    if (y > 0 && cellAt(x, y - 1) == terrain) {
        mask |= kMaskNorth;
    }
    if (x + 1 < grid.width && cellAt(x + 1, y) == terrain) {
        mask |= kMaskEast;
    }
    if (y + 1 < grid.height && cellAt(x, y + 1) == terrain) {
        mask |= kMaskSouth;
    }
    if (x > 0 && cellAt(x - 1, y) == terrain) {
        mask |= kMaskWest;
    }
    return mask;
}

void VisitObjectsInLayerTree(const LayerData& layer, const std::function<void(const LayerData&, const ObjectData&)>& visitor,
                             size_t* count) {
    if (layer.type == LayerType::ObjectGroup) {
        for (const auto& object : layer.objects) {
            if (visitor) {
                visitor(layer, object);
            }
            if (count != nullptr) {
                ++(*count);
            }
        }
    }

    for (const auto& child : layer.children) {
        VisitObjectsInLayerTree(child, visitor, count);
    }
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

TileTransform OrthogonalTransformFromFlags(const GidFlags& flags) {
    TileTransform transform{};

    if (!flags.flipDiagonally) {
        transform.flipX = flags.flipHorizontally;
        transform.flipY = flags.flipVertically;
        return transform;
    }

    // Tiled orthogonal diagonal flip maps to a rotated quad plus optional mirror.
    if (flags.flipHorizontally && flags.flipVertically) {
        transform.rotationDegrees = 90;
        transform.flipX = true;
        return transform;
    }
    if (flags.flipHorizontally) {
        transform.rotationDegrees = 90;
        return transform;
    }
    if (flags.flipVertically) {
        transform.rotationDegrees = 270;
        return transform;
    }

    transform.rotationDegrees = 270;
    transform.flipX = true;
    return transform;
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

bool ResolveTileSource(const MapData& map, uint32_t tileId, ResolvedTileSource* outTile, std::string* error) {
    if (outTile == nullptr) {
        if (error) {
            *error = "ResolveTileSource called with null output pointer";
        }
        return false;
    }
    if (tileId == 0u) {
        if (error) {
            *error = "ResolveTileSource requires tileId > 0";
        }
        return false;
    }
    if (map.tilesetRefs.empty() || map.tilesets.empty() || map.tilesetRefs.size() != map.tilesets.size()) {
        if (error) {
            *error = "Map tileset metadata is missing or inconsistent";
        }
        return false;
    }

    size_t matchedIndex = map.tilesetRefs.size();
    for (size_t i = 0; i < map.tilesetRefs.size(); ++i) {
        const int firstGid = map.tilesetRefs[i].firstGid;
        if (firstGid <= 0) {
            continue;
        }
        if (static_cast<uint32_t>(firstGid) <= tileId) {
            matchedIndex = i;
        } else {
            break;
        }
    }
    if (matchedIndex >= map.tilesetRefs.size()) {
        if (error) {
            *error = "No tileset found for tileId " + std::to_string(tileId);
        }
        return false;
    }

    const TilesetRef& ref = map.tilesetRefs[matchedIndex];
    const TilesetData& tileset = map.tilesets[matchedIndex];
    const int localTileId = static_cast<int>(tileId) - ref.firstGid;
    if (localTileId < 0) {
        if (error) {
            *error = "Computed negative local tile id for tileId " + std::to_string(tileId);
        }
        return false;
    }
    if (tileset.tileCount > 0 && localTileId >= tileset.tileCount) {
        if (error) {
            *error = "tileId " + std::to_string(tileId) + " exceeds tileset tilecount";
        }
        return false;
    }

    const int tileW = (tileset.tileWidth > 0) ? tileset.tileWidth : map.tileWidth;
    const int tileH = (tileset.tileHeight > 0) ? tileset.tileHeight : map.tileHeight;
    if (tileW <= 0 || tileH <= 0) {
        if (error) {
            *error = "Invalid tile dimensions for tileset '" + tileset.name + "'";
        }
        return false;
    }

    int columns = tileset.columns;
    if (columns <= 0 && tileset.imageWidth > 0) {
        columns = tileset.imageWidth / tileW;
    }
    if (columns <= 0) {
        if (error) {
            *error = "Unable to determine tileset columns for '" + tileset.name + "'";
        }
        return false;
    }

    outTile->tilesetIndex = matchedIndex;
    outTile->firstGid = ref.firstGid;
    outTile->localTileId = localTileId;
    outTile->sourceWidth = tileW;
    outTile->sourceHeight = tileH;
    outTile->sourceX = (localTileId % columns) * tileW;
    outTile->sourceY = (localTileId / columns) * tileH;
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

size_t CountObjects(const std::string& mapId) {
    const MapData* map = GetMap(mapId);
    if (map == nullptr) {
        return 0;
    }

    size_t count = 0;
    for (const auto& layer : map->layers) {
        VisitObjectsInLayerTree(layer, {}, &count);
    }
    return count;
}

size_t CountObjectsInActiveMap() {
    if (!HasActiveMap()) {
        return 0;
    }
    return CountObjects(g_activeMap);
}

bool ForEachObject(const std::string& mapId, const std::function<void(const LayerData&, const ObjectData&)>& visitor) {
    const MapData* map = GetMap(mapId);
    if (map == nullptr) {
        return false;
    }

    for (const auto& layer : map->layers) {
        VisitObjectsInLayerTree(layer, visitor, nullptr);
    }
    return true;
}

bool ForEachObjectInActiveMap(const std::function<void(const LayerData&, const ObjectData&)>& visitor) {
    if (!HasActiveMap()) {
        return false;
    }
    return ForEachObject(g_activeMap, visitor);
}

bool LoadRuleDefs(const std::filesystem::path& rulesPath, std::string* error) {
    RuleDefs rules{};
    if (!LoadRuleFile(rulesPath, &rules, error)) {
        return false;
    }

    CompiledRuleset compiled{};
    compiled.defs = rules;

    const auto runtimeJsonRef =
        FindRuleEntryValue(rules, {"runtime_json", "runtime_rules", "rules_json", "bitmask_rules"});

    if (runtimeJsonRef.has_value()) {
        if (!IsLikelyRuntimeRulePath(*runtimeJsonRef)) {
            if (error) {
                *error = "runtime_json must point to a .json file: " + *runtimeJsonRef;
            }
            return false;
        }

        const auto runtimePath = ResolveRelativePath(
            rulesPath.has_parent_path() ? rulesPath.parent_path() : std::filesystem::path{}, *runtimeJsonRef);
        if (!std::filesystem::exists(runtimePath)) {
            if (error) {
                *error = "Runtime rules JSON not found: " + runtimePath.string();
            }
            return false;
        }
        if (!ParseRuntimeBitmaskRulesFile(runtimePath, &compiled, error)) {
            return false;
        }
    } else {
        std::filesystem::path fallback = rulesPath;
        fallback.replace_extension(".runtime.json");
        if (std::filesystem::exists(fallback)) {
            if (!ParseRuntimeBitmaskRulesFile(fallback, &compiled, error)) {
                return false;
            }
        }
    }

    g_loadedRules[rules.id] = std::move(compiled);
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

    const CompiledRuleset* compiled = nullptr;
    if (!rulesetId.empty()) {
        const auto it = g_loadedRules.find(rulesetId);
        if (it == g_loadedRules.end()) {
            if (error) {
                *error = "Unknown ruleset id: " + rulesetId;
            }
            return false;
        }
        compiled = &it->second;
    }

    out->width = grid.width;
    out->height = grid.height;
    out->cells.assign(expectedCells, {});

    if (compiled != nullptr && !compiled->bitmaskRules.empty()) {
        for (int y = 0; y < grid.height; ++y) {
            for (int x = 0; x < grid.width; ++x) {
                const size_t idx = static_cast<size_t>(y) * static_cast<size_t>(grid.width) +
                                   static_cast<size_t>(x);
                const int terrain = grid.cells[idx];
                const int neighborMask = ComputeCardinalMaskForCell(grid, x, y, terrain);

                const BitmaskRule* bestRule = nullptr;
                int bestSpecificity = -1;
                for (const auto& rule : compiled->bitmaskRules) {
                    if (rule.terrain != terrain) {
                        continue;
                    }
                    if ((neighborMask & rule.requiredMask) != rule.requiredMask) {
                        continue;
                    }
                    if ((neighborMask & rule.forbiddenMask) != 0) {
                        continue;
                    }

                    const int specificity = CountBits(rule.requiredMask) + CountBits(rule.forbiddenMask);
                    if (bestRule == nullptr || rule.priority > bestRule->priority ||
                        (rule.priority == bestRule->priority && specificity > bestSpecificity) ||
                        (rule.priority == bestRule->priority && specificity == bestSpecificity &&
                         rule.order < bestRule->order)) {
                        bestRule = &rule;
                        bestSpecificity = specificity;
                    }
                }

                if (bestRule != nullptr) {
                    out->cells[idx].push_back(bestRule->tile);
                }
            }
        }
    }

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
