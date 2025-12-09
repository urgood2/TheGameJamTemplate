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

RegionDef parseRegionDef(const json& j) {
    RegionDef def;

    if (j.contains("region") && j["region"].is_array() && j["region"].size() == 4) {
        auto& r = j["region"];
        def.region = {
            r[0].get<float>(),
            r[1].get<float>(),
            r[2].get<float>(),
            r[3].get<float>()
        };
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

ButtonDef parseButtonDef(const json& j) {
    ButtonDef def;
    if (j.contains("normal")) def.normal = parseRegionDef(j["normal"]);
    if (j.contains("hover")) def.hover = parseRegionDef(j["hover"]);
    if (j.contains("pressed")) def.pressed = parseRegionDef(j["pressed"]);
    if (j.contains("disabled")) def.disabled = parseRegionDef(j["disabled"]);
    return def;
}

ProgressBarDef parseProgressBarDef(const json& j) {
    ProgressBarDef def;
    if (j.contains("background")) def.background = parseRegionDef(j["background"]);
    if (j.contains("fill")) def.fill = parseRegionDef(j["fill"]);
    return def;
}

ScrollbarDef parseScrollbarDef(const json& j) {
    ScrollbarDef def;
    if (j.contains("track")) def.track = parseRegionDef(j["track"]);
    if (j.contains("thumb")) def.thumb = parseRegionDef(j["thumb"]);
    return def;
}

SliderDef parseSliderDef(const json& j) {
    SliderDef def;
    if (j.contains("track")) def.track = parseRegionDef(j["track"]);
    if (j.contains("thumb")) def.thumb = parseRegionDef(j["thumb"]);
    return def;
}

InputDef parseInputDef(const json& j) {
    InputDef def;
    if (j.contains("normal")) def.normal = parseRegionDef(j["normal"]);
    if (j.contains("focus")) def.focus = parseRegionDef(j["focus"]);
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
        pack.atlasPath = (manifestDir / manifest["atlas"].get<std::string>()).string();
    }

    // Load texture if not already loaded
    if (!pack.atlasPath.empty()) {
        auto* existingTex = getAtlasTexture(pack.atlasPath);
        if (existingTex) {
            pack.atlas = existingTex;
        } else {
            // Load and cache the texture
            Texture2D tex = LoadTexture(pack.atlasPath.c_str());
            if (tex.id != 0) {
                if (globals::g_ctx) {
                    globals::g_ctx->textureAtlas[pack.atlasPath] = tex;
                    pack.atlas = &globals::g_ctx->textureAtlas[pack.atlasPath];
                } else {
                    globals::textureAtlasMap[pack.atlasPath] = tex;
                    pack.atlas = &globals::textureAtlasMap[pack.atlasPath];
                }
            } else {
                SPDLOG_ERROR("Failed to load UI pack atlas: {}", pack.atlasPath);
            }
        }
    }

    // Parse element definitions
    if (manifest.contains("panels")) {
        for (auto& [key, val] : manifest["panels"].items()) {
            pack.panels[key] = parseRegionDef(val);
        }
    }

    if (manifest.contains("buttons")) {
        for (auto& [key, val] : manifest["buttons"].items()) {
            pack.buttons[key] = parseButtonDef(val);
        }
    }

    if (manifest.contains("progress_bars")) {
        for (auto& [key, val] : manifest["progress_bars"].items()) {
            pack.progressBars[key] = parseProgressBarDef(val);
        }
    }

    if (manifest.contains("scrollbars")) {
        for (auto& [key, val] : manifest["scrollbars"].items()) {
            pack.scrollbars[key] = parseScrollbarDef(val);
        }
    }

    if (manifest.contains("sliders")) {
        for (auto& [key, val] : manifest["sliders"].items()) {
            pack.sliders[key] = parseSliderDef(val);
        }
    }

    if (manifest.contains("inputs")) {
        for (auto& [key, val] : manifest["inputs"].items()) {
            pack.inputs[key] = parseInputDef(val);
        }
    }

    if (manifest.contains("icons")) {
        for (auto& [key, val] : manifest["icons"].items()) {
            pack.icons[key] = parseRegionDef(val);
        }
    }

    // Store in registry
    if (globals::g_ctx) {
        globals::g_ctx->uiPacks[name] = std::move(pack);
        SPDLOG_INFO("Registered UI pack '{}' with {} panels, {} buttons, {} icons",
            name, globals::g_ctx->uiPacks[name].panels.size(),
            globals::g_ctx->uiPacks[name].buttons.size(),
            globals::g_ctx->uiPacks[name].icons.size());
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

} // namespace ui
