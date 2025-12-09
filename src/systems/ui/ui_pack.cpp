#include "ui_pack.hpp"
#include "core/globals.hpp"
#include "core/engine_context.hpp"
#include "util/common_headers.hpp"
#include <fstream>

namespace ui {

namespace {

SpriteScaleMode parseScaleMode(const std::string& mode) {
    if (mode == "tile") return SpriteScaleMode::Tile;
    if (mode == "fixed") return SpriteScaleMode::Fixed;
    return SpriteScaleMode::Stretch;
}

RegionDef parseRegionDef(const json& j, const Rectangle& atlasBounds) {
    RegionDef def;

    if (j.contains("region") && j["region"].is_array() && j["region"].size() == 4) {
        auto& r = j["region"];
        def.region = {
            r[0].get<float>(),
            r[1].get<float>(),
            r[2].get<float>(),
            r[3].get<float>()
        };

        // Validate region is within atlas bounds
        if (def.region.x < 0 || def.region.y < 0 ||
            def.region.x + def.region.width > atlasBounds.width ||
            def.region.y + def.region.height > atlasBounds.height) {
            SPDLOG_WARN("Region [{}, {}, {}, {}] exceeds atlas bounds [{}, {}] - clamping",
                def.region.x, def.region.y, def.region.width, def.region.height,
                atlasBounds.width, atlasBounds.height);

            // Clamp to valid bounds
            def.region.x = std::max(0.0f, def.region.x);
            def.region.y = std::max(0.0f, def.region.y);
            def.region.width = std::min(def.region.width, atlasBounds.width - def.region.x);
            def.region.height = std::min(def.region.height, atlasBounds.height - def.region.y);
        }
    }

    if (j.contains("9patch") && j["9patch"].is_array() && j["9patch"].size() == 4) {
        auto& p = j["9patch"];
        NPatchInfo info{};
        info.source = def.region;
        info.left = p[0].get<int>();
        info.top = p[1].get<int>();
        info.right = p[2].get<int>();
        info.bottom = p[3].get<int>();
        info.layout = NPATCH_NINE_PATCH;
        def.ninePatch = info;
    }

    if (j.contains("scale_mode")) {
        def.scaleMode = parseScaleMode(j["scale_mode"].get<std::string>());
    }

    return def;
}

ButtonDef parseButtonDef(const json& j, const Rectangle& atlasBounds) {
    ButtonDef def;
    if (j.contains("normal")) def.normal = parseRegionDef(j["normal"], atlasBounds);
    if (j.contains("hover")) def.hover = parseRegionDef(j["hover"], atlasBounds);
    if (j.contains("pressed")) def.pressed = parseRegionDef(j["pressed"], atlasBounds);
    if (j.contains("disabled")) def.disabled = parseRegionDef(j["disabled"], atlasBounds);
    return def;
}

ProgressBarDef parseProgressBarDef(const json& j, const Rectangle& atlasBounds) {
    ProgressBarDef def;
    if (j.contains("background")) def.background = parseRegionDef(j["background"], atlasBounds);
    if (j.contains("fill")) def.fill = parseRegionDef(j["fill"], atlasBounds);
    return def;
}

ScrollbarDef parseScrollbarDef(const json& j, const Rectangle& atlasBounds) {
    ScrollbarDef def;
    if (j.contains("track")) def.track = parseRegionDef(j["track"], atlasBounds);
    if (j.contains("thumb")) def.thumb = parseRegionDef(j["thumb"], atlasBounds);
    return def;
}

SliderDef parseSliderDef(const json& j, const Rectangle& atlasBounds) {
    SliderDef def;
    if (j.contains("track")) def.track = parseRegionDef(j["track"], atlasBounds);
    if (j.contains("thumb")) def.thumb = parseRegionDef(j["thumb"], atlasBounds);
    return def;
}

InputDef parseInputDef(const json& j, const Rectangle& atlasBounds) {
    InputDef def;
    if (j.contains("normal")) def.normal = parseRegionDef(j["normal"], atlasBounds);
    if (j.contains("focus")) def.focus = parseRegionDef(j["focus"], atlasBounds);
    return def;
}

} // anonymous namespace

bool registerPack(const std::string& name, const std::string& manifestPath) {
    std::ifstream file(manifestPath);
    if (!file.is_open()) {
        SPDLOG_ERROR("Failed to open UI pack manifest: {}", manifestPath);
        return false;
    }

    json manifest;
    try {
        file >> manifest;
    } catch (const json::parse_error& e) {
        SPDLOG_ERROR("Failed to parse UI pack manifest {}: {}", manifestPath, e.what());
        return false;
    }

    UIAssetPack pack;
    pack.name = name;

    // Get atlas path relative to manifest directory
    std::filesystem::path manifestDir = std::filesystem::path(manifestPath).parent_path();
    if (manifest.contains("atlas")) {
        // Validate atlas path to prevent directory traversal attacks
        std::filesystem::path atlasRelPath = manifest["atlas"].get<std::string>();

        // Reject absolute paths or paths with parent directory references
        if (atlasRelPath.is_absolute() || atlasRelPath.string().find("..") != std::string::npos) {
            SPDLOG_ERROR("Invalid atlas path in manifest {}: path must be relative and cannot contain '..'", manifestPath);
            return false;
        }

        pack.atlasPath = (manifestDir / atlasRelPath).string();
    }

    // Load texture if not already loaded and get bounds for validation
    Rectangle atlasBounds{0, 0, 0, 0};
    if (!pack.atlasPath.empty()) {
        auto* existingTex = getAtlasTexture(pack.atlasPath);
        if (existingTex) {
            // Texture already loaded
            atlasBounds = {0, 0, static_cast<float>(existingTex->width), static_cast<float>(existingTex->height)};
        } else {
            // Load and cache the texture
            Texture2D tex = LoadTexture(pack.atlasPath.c_str());
            if (tex.id != 0) {
                atlasBounds = {0, 0, static_cast<float>(tex.width), static_cast<float>(tex.height)};
                if (globals::g_ctx) {
                    globals::g_ctx->textureAtlas[pack.atlasPath] = tex;
                } else {
                    globals::textureAtlasMap[pack.atlasPath] = tex;
                }
            } else {
                SPDLOG_ERROR("Failed to load UI pack atlas: {}", pack.atlasPath);
                return false;
            }
        }
    }

    // Parse element definitions with bounds validation
    if (manifest.contains("panels")) {
        for (auto& [key, val] : manifest["panels"].items()) {
            pack.panels[key] = parseRegionDef(val, atlasBounds);
        }
    }

    if (manifest.contains("buttons")) {
        for (auto& [key, val] : manifest["buttons"].items()) {
            pack.buttons[key] = parseButtonDef(val, atlasBounds);
        }
    }

    if (manifest.contains("progress_bars")) {
        for (auto& [key, val] : manifest["progress_bars"].items()) {
            pack.progressBars[key] = parseProgressBarDef(val, atlasBounds);
        }
    }

    if (manifest.contains("scrollbars")) {
        for (auto& [key, val] : manifest["scrollbars"].items()) {
            pack.scrollbars[key] = parseScrollbarDef(val, atlasBounds);
        }
    }

    if (manifest.contains("sliders")) {
        for (auto& [key, val] : manifest["sliders"].items()) {
            pack.sliders[key] = parseSliderDef(val, atlasBounds);
        }
    }

    if (manifest.contains("inputs")) {
        for (auto& [key, val] : manifest["inputs"].items()) {
            pack.inputs[key] = parseInputDef(val, atlasBounds);
        }
    }

    if (manifest.contains("icons")) {
        for (auto& [key, val] : manifest["icons"].items()) {
            pack.icons[key] = parseRegionDef(val, atlasBounds);
        }
    }

    // Store in registry
    if (globals::g_ctx) {
        globals::g_ctx->uiPacks[name] = std::move(pack);
        auto& storedPack = globals::g_ctx->uiPacks[name];

        SPDLOG_INFO("Registered UI pack '{}' with {} panels, {} buttons, {} icons",
            name, storedPack.panels.size(),
            storedPack.buttons.size(),
            storedPack.icons.size());
        return true;
    }

    SPDLOG_ERROR("No EngineContext available to register UI pack");
    return false;
}

UIAssetPack* getPack(const std::string& name) {
    if (globals::g_ctx) {
        auto it = globals::g_ctx->uiPacks.find(name);
        if (it != globals::g_ctx->uiPacks.end()) {
            return &it->second;
        }
    }
    return nullptr;
}

void unregisterPack(const std::string& name, bool unloadTexture) {
    if (!globals::g_ctx) {
        SPDLOG_WARN("No EngineContext available to unregister UI pack");
        return;
    }

    auto it = globals::g_ctx->uiPacks.find(name);
    if (it == globals::g_ctx->uiPacks.end()) {
        SPDLOG_WARN("UI pack '{}' not found for unregistration", name);
        return;
    }

    std::string atlasPath = it->second.atlasPath;

    // Remove pack from registry
    globals::g_ctx->uiPacks.erase(it);
    SPDLOG_INFO("Unregistered UI pack '{}'", name);

    // Optionally unload texture (careful - may be shared by other packs)
    if (unloadTexture && !atlasPath.empty()) {
        auto texIt = globals::g_ctx->textureAtlas.find(atlasPath);
        if (texIt != globals::g_ctx->textureAtlas.end()) {
            UnloadTexture(texIt->second);
            globals::g_ctx->textureAtlas.erase(texIt);
            SPDLOG_INFO("Unloaded atlas texture: {}", atlasPath);
        }
    }
}

} // namespace ui
