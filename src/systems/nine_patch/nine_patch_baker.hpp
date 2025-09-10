// NinePatchBaker.hpp
#pragma once
#include <array>
#include <string>
#include <optional>
#include <utility>
#include "raylib.h"
#include "spdlog/spdlog.h"

#include "core/globals.hpp"
#include "core/init.hpp"

namespace nine_patch {
    
    struct NineSliceNames {
        // 3x3 pieces: corners, sides, center
        std::string tl, t, tr;
        std::string l,  c, r;
        std::string bl, b, br;
    };

    // Result bundle you can pipe into your UI builder
    struct BakedNinePatch {
        NPatchInfo info;     // use as-is
        Texture2D  texture;  // use as source texture
    };

    // Helper: safe int cast from float size (prevents negative/NaN)
    static inline int iround_pos(float f) {
        if (!(f >= 0.0f)) return 0;
        return (int)std::lround(f);
    }

    // Returns std::nullopt if atlas mismatch or critical size errors.
    inline std::optional<BakedNinePatch>
    BakeNinePatchFromSprites(const NineSliceNames& names, float scale /* >= 0.0f, typical 1.0f */)
    {
        if (scale <= 0.0f) {
            spdlog::warn("BakeNinePatchFromSprites: scale <= 0, forcing to 1.0");
            scale = 1.0f;
        }

        // Fetch frames
        const globals::SpriteFrameData F_tl = init::getSpriteFrame(names.tl);
        const globals::SpriteFrameData F_t  = init::getSpriteFrame(names.t);
        const globals::SpriteFrameData F_tr = init::getSpriteFrame(names.tr);
        const globals::SpriteFrameData F_l  = init::getSpriteFrame(names.l);
        const globals::SpriteFrameData F_c  = init::getSpriteFrame(names.c);
        const globals::SpriteFrameData F_r  = init::getSpriteFrame(names.r);
        const globals::SpriteFrameData F_bl = init::getSpriteFrame(names.bl);
        const globals::SpriteFrameData F_b  = init::getSpriteFrame(names.b);
        const globals::SpriteFrameData F_br = init::getSpriteFrame(names.br);

        // Validate atlas consistency
        const std::string atlas = F_tl.atlasUUID;
        auto sameAtlas = [&](const globals::SpriteFrameData& f){ return f.atlasUUID == atlas; };
        if (!(sameAtlas(F_t) && sameAtlas(F_tr) && sameAtlas(F_l) && sameAtlas(F_c) &&
            sameAtlas(F_r) && sameAtlas(F_bl) && sameAtlas(F_b) && sameAtlas(F_br)))
        {
            spdlog::error("BakeNinePatchFromSprites: All nine sprites must come from the same atlas.");
            return std::nullopt;
        }

        // Pull the atlas texture
        if (globals::textureAtlasMap.find(atlas) == globals::textureAtlasMap.end()) {
            spdlog::error("BakeNinePatchFromSprites: atlas texture '{}' not found.", atlas);
            return std::nullopt;
        }
        const Texture2D& atlasTex = globals::textureAtlasMap.at(atlas);

        // Derive border thicknesses from corners (authoritative)
        const float leftW   = F_tl.frame.width;
        const float rightW  = F_tr.frame.width;
        const float topH    = F_tl.frame.height;
        const float bottomH = F_bl.frame.height;

        if (leftW <= 0 || rightW <= 0 || topH <= 0 || bottomH <= 0) {
            spdlog::error("BakeNinePatchFromSprites: invalid corner sizes (<= 0).");
            return std::nullopt;
        }

        // Center band sizes inferred from sides/center
        const float midW = std::max({F_t.frame.width, F_c.frame.width, F_b.frame.width});
        const float midH = std::max({F_l.frame.height, F_c.frame.height, F_r.frame.height});
        if (midW <= 0 || midH <= 0) {
            spdlog::error("BakeNinePatchFromSprites: invalid middle span sizes (<= 0).");
            return std::nullopt;
        }

        // Sanity checks (not fatal): matching row heights / column widths
        auto rowHeightsMatch = [](float a, float b, float c) {
            return std::fabs(a - b) < 0.5f && std::fabs(b - c) < 0.5f;
        };
        auto colWidthsMatch = [](float a, float b, float c) {
            return std::fabs(a - b) < 0.5f && std::fabs(b - c) < 0.5f;
        };

        // Warn if thicknesses disagree in row/col; we’ll still bake using max spans
        if (!colWidthsMatch(F_tl.frame.width, F_l.frame.width, F_bl.frame.width)) {
            spdlog::warn("NinePatch bake: left column widths differ; using corner width for border.");
        }
        if (!colWidthsMatch(F_tr.frame.width, F_r.frame.width, F_br.frame.width)) {
            spdlog::warn("NinePatch bake: right column widths differ; using corner width for border.");
        }
        if (!rowHeightsMatch(F_tl.frame.height, F_t.frame.height, F_tr.frame.height)) {
            spdlog::warn("NinePatch bake: top row heights differ; using corner height for border.");
        }
        if (!rowHeightsMatch(F_bl.frame.height, F_b.frame.height, F_br.frame.height)) {
            spdlog::warn("NinePatch bake: bottom row heights differ; using corner height for border.");
        }

        // Compute baked overall size (scaled)
        const int L  = iround_pos(leftW   * scale);
        const int R  = iround_pos(rightW  * scale);
        const int T  = iround_pos(topH    * scale);
        const int B  = iround_pos(bottomH * scale);
        const int MW = iround_pos(midW    * scale);
        const int MH = iround_pos(midH    * scale);

        const int bakedW = L + MW + R;
        const int bakedH = T + MH + B;
        if (bakedW <= 0 || bakedH <= 0) {
            spdlog::error("BakeNinePatchFromSprites: computed baked size is zero.");
            return std::nullopt;
        }

        // Allocate render target and draw
        RenderTexture2D rt = LoadRenderTexture(bakedW, bakedH);
        BeginTextureMode(rt);
            ClearBackground({0,0,0,0});

            // Helper to draw one slice from atlas into a dest rectangle
            auto drawSlice = [&](const globals::SpriteFrameData& f, Rectangle dst) {
                // DrawTexturePro expects source rect in texture space; flip y handled by raylib internally in framebuffer
                DrawTexturePro(
                    atlasTex,
                    f.frame,                                // source rectangle in atlas
                    dst,                                    // destination in baked texture
                    {0,0},                                  // origin
                    0.0f,                                   // rotation
                    WHITE
                );
            };

            // Precompute destination rectangles for each grid cell
            const Rectangle dst_tl { 0.0f,            0.0f,            (float)L,  (float)T };
            const Rectangle dst_t  { (float)L,        0.0f,            (float)MW, (float)T };
            const Rectangle dst_tr { (float)(L+MW),   0.0f,            (float)R,  (float)T };

            const Rectangle dst_l  { 0.0f,            (float)T,        (float)L,  (float)MH };
            const Rectangle dst_c  { (float)L,        (float)T,        (float)MW, (float)MH };
            const Rectangle dst_r  { (float)(L+MW),   (float)T,        (float)R,  (float)MH };

            const Rectangle dst_bl { 0.0f,            (float)(T+MH),   (float)L,  (float)B };
            const Rectangle dst_b  { (float)L,        (float)(T+MH),   (float)MW, (float)B };
            const Rectangle dst_br { (float)(L+MW),   (float)(T+MH),   (float)R,  (float)B };

            // Draw all slices (source is their atlas rect; dest is grid cell)
            drawSlice(F_tl, dst_tl);
            drawSlice(F_t,  dst_t);
            drawSlice(F_tr, dst_tr);

            drawSlice(F_l,  dst_l);
            drawSlice(F_c,  dst_c);
            drawSlice(F_r,  dst_r);

            drawSlice(F_bl, dst_bl);
            drawSlice(F_b,  dst_b);
            drawSlice(F_br, dst_br);

        EndTextureMode();

        // The baked texture we’ll reference for NPatch
        // Note: RenderTexture2D holds a Texture2D in `.texture`
        Texture2D bakedTex = rt.texture;

        // Build NPatchInfo: source is the whole baked area; borders are scaled corner sizes
        NPatchInfo info{};
        info.source = Rectangle{ 0, 0, (float)bakedW, (float)bakedH };
        info.left   = L;
        info.top    = T;
        info.right  = R;
        info.bottom = B;
        info.layout = NPATCH_NINE_PATCH;

        // We intentionally keep rt alive somewhere if you need to keep the FBO.
        // If you only need the texture, you can store bakedTex; Raylib manages lifetime
        // but ensure it remains valid as long as you draw with it.

        return BakedNinePatch{ info, bakedTex };
    }

}
