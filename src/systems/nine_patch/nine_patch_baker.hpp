// NinePatchBaker.hpp
#pragma once
#include "core/engine_context.hpp"
#include "raylib.h"
#include "rlgl.h"
#include "spdlog/spdlog.h"
#include <array>
#include <optional>
#include <string>
#include <utility>

#include "core/globals.hpp"
#include "core/init.hpp"

namespace nine_patch {

struct NineSliceNames {
  // 3x3 pieces: corners, sides, center
  std::string tl, t, tr;
  std::string l, c, r;
  std::string bl, b, br;
};

// Result bundle you can pipe into your UI builder
struct BakedNinePatch {
  NPatchInfo info;   // use as-is
  Texture2D texture; // use as source texture
};

enum class SpriteScaleMode {
    Fixed,
    Stretch,
    Tile
};

struct NPatchRegionModes {
    SpriteScaleMode topLeft = SpriteScaleMode::Fixed;
    SpriteScaleMode topRight = SpriteScaleMode::Fixed;
    SpriteScaleMode bottomLeft = SpriteScaleMode::Fixed;
    SpriteScaleMode bottomRight = SpriteScaleMode::Fixed;
    SpriteScaleMode top = SpriteScaleMode::Tile;
    SpriteScaleMode bottom = SpriteScaleMode::Tile;
    SpriteScaleMode left = SpriteScaleMode::Tile;
    SpriteScaleMode right = SpriteScaleMode::Tile;
    SpriteScaleMode center = SpriteScaleMode::Stretch;
};

struct NPatchTiling {
  bool top = false, bottom = false, left = false, right = false;
  bool centerX = false, centerY = false;
  Color background = {0, 0, 0, 0};
  float pixelScale = 1.0f;
};

// Helper: safe int cast from float size (prevents negative/NaN)
static inline int iround_pos(float f) {
  if (!(f >= 0.0f))
    return 0;
  return (int)std::lround(f);
}

// Returns std::nullopt if atlas mismatch or critical size errors.
inline std::optional<BakedNinePatch>
BakeNinePatchFromSprites(const NineSliceNames &names,
                         float scale /* >= 0.0f, typical 1.0f */) {
  if (scale <= 0.0f) {
    spdlog::warn("BakeNinePatchFromSprites: scale <= 0, forcing to 1.0");
    scale = 1.0f;
  }

  // Fetch frames
  const globals::SpriteFrameData F_tl =
      init::getSpriteFrame(names.tl, globals::g_ctx);
  const globals::SpriteFrameData F_t =
      init::getSpriteFrame(names.t, globals::g_ctx);
  const globals::SpriteFrameData F_tr =
      init::getSpriteFrame(names.tr, globals::g_ctx);
  const globals::SpriteFrameData F_l =
      init::getSpriteFrame(names.l, globals::g_ctx);
  const globals::SpriteFrameData F_c =
      init::getSpriteFrame(names.c, globals::g_ctx);
  const globals::SpriteFrameData F_r =
      init::getSpriteFrame(names.r, globals::g_ctx);
  const globals::SpriteFrameData F_bl =
      init::getSpriteFrame(names.bl, globals::g_ctx);
  const globals::SpriteFrameData F_b =
      init::getSpriteFrame(names.b, globals::g_ctx);
  const globals::SpriteFrameData F_br =
      init::getSpriteFrame(names.br, globals::g_ctx);

  // Validate atlas consistency
  const std::string atlas = F_tl.atlasUUID;
  auto sameAtlas = [&](const globals::SpriteFrameData &f) {
    return f.atlasUUID == atlas;
  };
  if (!(sameAtlas(F_t) && sameAtlas(F_tr) && sameAtlas(F_l) && sameAtlas(F_c) &&
        sameAtlas(F_r) && sameAtlas(F_bl) && sameAtlas(F_b) &&
        sameAtlas(F_br))) {
    spdlog::error("BakeNinePatchFromSprites: All nine sprites must come from "
                  "the same atlas.");
    return std::nullopt;
  }

  // Pull the atlas texture (context-first, legacy fallback)
  const Texture2D *atlasTexPtr = getAtlasTexture(atlas);
  if (!atlasTexPtr) {
    spdlog::error("BakeNinePatchFromSprites: atlas texture '{}' not found.",
                  atlas);
    return std::nullopt;
  }
  const Texture2D &atlasTex = *atlasTexPtr;

  // Derive border thicknesses from corners (authoritative)
  const float leftW = F_tl.frame.width;
  const float rightW = F_tr.frame.width;
  const float topH = F_tl.frame.height;
  const float bottomH = F_bl.frame.height;

  if (leftW <= 0 || rightW <= 0 || topH <= 0 || bottomH <= 0) {
    spdlog::error("BakeNinePatchFromSprites: invalid corner sizes (<= 0).");
    return std::nullopt;
  }

  // Center band sizes inferred from sides/center
  const float midW =
      std::max({F_t.frame.width, F_c.frame.width, F_b.frame.width});
  const float midH =
      std::max({F_l.frame.height, F_c.frame.height, F_r.frame.height});
  if (midW <= 0 || midH <= 0) {
    spdlog::error(
        "BakeNinePatchFromSprites: invalid middle span sizes (<= 0).");
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
    spdlog::warn("NinePatch bake: left column widths differ; using corner "
                 "width for border.");
  }
  if (!colWidthsMatch(F_tr.frame.width, F_r.frame.width, F_br.frame.width)) {
    spdlog::warn("NinePatch bake: right column widths differ; using corner "
                 "width for border.");
  }
  if (!rowHeightsMatch(F_tl.frame.height, F_t.frame.height,
                       F_tr.frame.height)) {
    spdlog::warn("NinePatch bake: top row heights differ; using corner height "
                 "for border.");
  }
  if (!rowHeightsMatch(F_bl.frame.height, F_b.frame.height,
                       F_br.frame.height)) {
    spdlog::warn("NinePatch bake: bottom row heights differ; using corner "
                 "height for border.");
  }

  // Compute baked overall size (scaled)
  const int L = iround_pos(leftW * scale);
  const int R = iround_pos(rightW * scale);
  const int T = iround_pos(topH * scale);
  const int B = iround_pos(bottomH * scale);
  const int MW = iround_pos(midW * scale);
  const int MH = iround_pos(midH * scale);

  const int bakedW = L + MW + R;
  const int bakedH = T + MH + B;
  if (bakedW <= 0 || bakedH <= 0) {
    spdlog::error("BakeNinePatchFromSprites: computed baked size is zero.");
    return std::nullopt;
  }

  // Allocate render target and draw
  RenderTexture2D rt = LoadRenderTexture(bakedW, bakedH);
  SetTextureFilter(rt.texture, TEXTURE_FILTER_POINT);
  BeginTextureMode(rt);
  ClearBackground({0, 0, 0, 0});

  // Helper to draw one slice from atlas into a dest rectangle
  auto drawSlice = [&](const globals::SpriteFrameData &f, Rectangle dst) {
    // DrawTexturePro expects source rect in texture space; flip y handled by
    // raylib internally in framebuffer
    DrawTexturePro(atlasTex,
                   f.frame, // source rectangle in atlas
                   dst,     // destination in baked texture
                   {0, 0},  // origin
                   0.0f,    // rotation
                   WHITE);
  };

  // Precompute destination rectangles for each grid cell
  const Rectangle dst_tl{0.0f, 0.0f, (float)L, (float)T};
  const Rectangle dst_t{(float)L, 0.0f, (float)MW, (float)T};
  const Rectangle dst_tr{(float)(L + MW), 0.0f, (float)R, (float)T};

  const Rectangle dst_l{0.0f, (float)T, (float)L, (float)MH};
  const Rectangle dst_c{(float)L, (float)T, (float)MW, (float)MH};
  const Rectangle dst_r{(float)(L + MW), (float)T, (float)R, (float)MH};

  const Rectangle dst_bl{0.0f, (float)(T + MH), (float)L, (float)B};
  const Rectangle dst_b{(float)L, (float)(T + MH), (float)MW, (float)B};
  const Rectangle dst_br{(float)(L + MW), (float)(T + MH), (float)R, (float)B};

  // Draw all slices (source is their atlas rect; dest is grid cell)
  drawSlice(F_tl, dst_tl);
  drawSlice(F_t, dst_t);
  drawSlice(F_tr, dst_tr);

  drawSlice(F_l, dst_l);
  drawSlice(F_c, dst_c);
  drawSlice(F_r, dst_r);

  drawSlice(F_bl, dst_bl);
  drawSlice(F_b, dst_b);
  drawSlice(F_br, dst_br);

  EndTextureMode();

  // The baked texture we’ll reference for NPatch
  // Note: RenderTexture2D holds a Texture2D in `.texture`
  Texture2D bakedTex = rt.texture;

  // Build NPatchInfo: source is the whole baked area; borders are scaled corner
  // sizes
  NPatchInfo info{};
  info.source = Rectangle{0, 0, (float)bakedW, (float)bakedH};
  info.left = L;
  info.top = T;
  info.right = R;
  info.bottom = B;
  info.layout = NPATCH_NINE_PATCH;

  // We intentionally keep rt alive somewhere if you need to keep the FBO.
  // If you only need the texture, you can store bakedTex; Raylib manages
  // lifetime but ensure it remains valid as long as you draw with it.

  return BakedNinePatch{info, bakedTex};
}

// DrawTextureNPatchTiled: true-tiling version (no stretch distortion).
// - tilesTop/tilesBottom: repeat top/bottom horizontally
// - tilesLeft/tilesRight: repeat sides vertically
// - tilesCenterX/Y: repeat center
// - bg: optional solid background (transparent by default)
// - pixelScale: uniform scale to apply to *tiles* (choose the same scale you
// used for corners)
//   Typically: pixelScale = 1.0f for pixel-perfect; or
//   topBorder/dstTopBorderSrcPixels for consistency.
// pixelScale tells the tiler “scale each repeated tile this much when stamping
// it out.” Use 1.0f for pixel-perfect; use the same scale you applied to the
// borders if you’re scaling the patch up/down.
inline void DrawTextureNPatchTiled(Texture2D tex, NPatchInfo info,
                                   Rectangle dest, Vector2 origin,
                                   float rotation, Color tint, bool tilesTop,
                                   bool tilesBottom, bool tilesLeft,
                                   bool tilesRight, bool tilesCenterX,
                                   bool tilesCenterY, Color bg = {0, 0, 0, 0},
                                   float pixelScale = 1.0f) {
  if (tex.id <= 0)
    return;

  // Ensure integer-aligned to avoid subpixel sampling (optional but recommended
  // for pixel art)
  dest.x = std::round(dest.x);
  dest.y = std::round(dest.y);
  dest.width = std::round(dest.width);
  dest.height = std::round(dest.height);

  // Source sizes in pixels
  const float srcW = std::fabs(info.source.width);
  const float srcH = std::fabs(info.source.height);

  // Border in *source* pixels
  float L = (float)info.left;
  float T = (float)info.top;
  float R = (float)info.right;
  float B = (float)info.bottom;

  // Compute the visible borders (Raylib clamps when dest is too small)
  float patchW = (dest.width <= 0) ? 0.f : dest.width;
  float patchH = (dest.height <= 0) ? 0.f : dest.height;

  bool drawCenter = true;
  bool drawMiddle = true;

  if (patchW <= (L + R) && info.layout != NPATCH_THREE_PATCH_VERTICAL) {
    drawCenter = false;
    const float k = (patchW <= 0.f) ? 0.f : (patchW / (L + R));
    R = patchW - (L * k);
    L = patchW - R;
  }
  if (patchH <= (T + B) && info.layout != NPATCH_THREE_PATCH_HORIZONTAL) {
    drawMiddle = false;
    const float k = (patchH <= 0.f) ? 0.f : (patchH / (T + B));
    B = patchH - (T * k);
    T = patchH - B;
  }

  // Vertex rect (local space, like Raylib)
  const float Ax = 0.f, Ay = 0.f;
  const float Bx = L, By = T;
  const float Cx = patchW - R, Cy = patchH - B;
  const float Dx = patchW, Dy = patchH;

  // Source UVs (same derivation as Raylib)
  const float uA = info.source.x / tex.width;
  const float vA = info.source.y / tex.height;
  const float uB = (info.source.x + L) / tex.width;
  const float vB = (info.source.y + T) / tex.height;
  const float uC = (info.source.x + info.source.width - R) / tex.width;
  const float vC = (info.source.y + info.source.height - B) / tex.height;
  const float uD = (info.source.x + info.source.width) / tex.width;
  const float vD = (info.source.y + info.source.height) / tex.height;

  // Helper to draw a solid background quad in local space
  auto DrawLocalSolid = [&](float x, float y, float w, float h, Color c) {
    rlSetTexture(0);
    rlBegin(RL_QUADS);
    rlColor4ub(c.r, c.g, c.b, c.a);
    rlVertex2f(x, y + h);
    rlVertex2f(x + w, y + h);
    rlVertex2f(x + w, y);
    rlVertex2f(x, y);
    rlEnd();
  };

  // Helper to draw one textured quad (UV rect -> local rect)
  auto Quad = [&](float x0, float y0, float x1, float y1, float u0, float v0,
                  float u1, float v1) {
    rlBegin(RL_QUADS);
    rlColor4ub(tint.r, tint.g, tint.b, tint.a);
    rlNormal3f(0, 0, 1);
    rlTexCoord2f(u0, v1);
    rlVertex2f(x0, y1);
    rlTexCoord2f(u1, v1);
    rlVertex2f(x1, y1);
    rlTexCoord2f(u1, v0);
    rlVertex2f(x1, y0);
    rlTexCoord2f(u0, v0);
    rlVertex2f(x0, y0);
    rlEnd();
  };

  const float srcCenterW = (srcW - L - R);
  const float srcCenterH = (srcH - T - B);

  // Tile pitch (in *destination* pixels) chosen to preserve texel scale =
  // pixelScale Edges: scale to match border thickness for the short axis;
  // repeat along the long axis.
  const float pitchTopW = std::max(1.f, srcCenterW * pixelScale);
  const float pitchBottomW = pitchTopW;
  const float pitchLeftH = std::max(1.f, srcCenterH * pixelScale);
  const float pitchRightH = pitchLeftH;
  const float pitchCenterW = std::max(1.f, srcCenterW * pixelScale);
  const float pitchCenterH = std::max(1.f, srcCenterH * pixelScale);

  rlPushMatrix();
  rlTranslatef(dest.x, dest.y, 0.f);
  rlRotatef(rotation, 0.f, 0.f, 1.f);
  rlTranslatef(-origin.x, -origin.y, 0.f);

  // Background fill first (covers the whole patch area in local space)
  if (bg.a != 0)
    DrawLocalSolid(0, 0, patchW, patchH, bg);

  rlSetTexture(tex.id);

  // Corners (identical to Raylib: single quads)
  Quad(Ax, Ay, Bx, By, uA, vA, uB, vB); // TL
  Quad(Cx, Ay, Dx, By, uC, vA, uD, vB); // TR
  Quad(Ax, Cy, Bx, Dy, uA, vC, uB, vD); // BL
  Quad(Cx, Cy, Dx, Dy, uC, vC, uD, vD); // BR

  // Top edge: repeat horizontally if tilesTop, else stretch once
  auto DrawTop = [&] {
    const float y0 = Ay, y1 = By;
    const float u0 = uB, u1 = uC, v0 = vA, v1 = vB; // top strip UV
    if (!drawCenter)
      return; // nothing between corners if center suppressed horizontally
    if (!tilesTop) {
      Quad(Bx, y0, Cx, y1, u0, v0, u1, v1);
      return;
    }
    for (float x = Bx; x < Cx; x += pitchTopW) {
      const float x1 = std::min(x + pitchTopW, Cx);
      const float frac = (x1 - x) / pitchTopW;
      const float u1f = u0 + (u1 - u0) * frac;
      Quad(x, y0, x1, y1, u0, v0, u1f, v1);
    }
  };

  // Bottom edge
  auto DrawBottom = [&] {
    const float y0 = Cy, y1 = Dy;
    const float u0 = uB, u1 = uC, v0 = vC, v1 = vD;
    if (!drawCenter)
      return;
    if (!tilesBottom) {
      Quad(Bx, y0, Cx, y1, u0, v0, u1, v1);
      return;
    }
    for (float x = Bx; x < Cx; x += pitchBottomW) {
      const float x1 = std::min(x + pitchBottomW, Cx);
      const float frac = (x1 - x) / pitchBottomW;
      const float u1f = u0 + (u1 - u0) * frac;
      Quad(x, y0, x1, y1, u0, v0, u1f, v1);
    }
  };

  // Left edge
  auto DrawLeft = [&] {
    const float x0 = Ax, x1 = Bx;
    const float u0 = uA, u1 = uB, v0 = vB, v1 = vC;
    if (!drawMiddle)
      return;
    if (!tilesLeft) {
      Quad(x0, By, x1, Cy, u0, v0, u1, v1);
      return;
    }
    for (float y = By; y < Cy; y += pitchLeftH) {
      const float y1f = std::min(y + pitchLeftH, Cy);
      const float frac = (y1f - y) / pitchLeftH;
      const float v1f = v0 + (v1 - v0) * frac;
      Quad(x0, y, x1, y1f, u0, v0, u1, v1f);
    }
  };

  // Right edge
  auto DrawRight = [&] {
    const float x0 = Cx, x1 = Dx;
    const float u0 = uC, u1 = uD, v0 = vB, v1 = vC;
    if (!drawMiddle)
      return;
    if (!tilesRight) {
      Quad(x0, By, x1, Cy, u0, v0, u1, v1);
      return;
    }
    for (float y = By; y < Cy; y += pitchRightH) {
      const float y1f = std::min(y + pitchRightH, Cy);
      const float frac = (y1f - y) / pitchRightH;
      const float v1f = v0 + (v1 - v0) * frac;
      Quad(x0, y, x1, y1f, u0, v0, u1, v1f);
    }
  };

  // Center region (repeat X/Y independently if requested)
  auto DrawCenter = [&] {
    if (!drawCenter || !drawMiddle)
      return;
    const float u0 = uB, u1 = uC, v0 = vB, v1 = vC;
    if (!tilesCenterX && !tilesCenterY) {
      Quad(Bx, By, Cx, Cy, u0, v0, u1, v1);
      return;
    }
    for (float y = By; y < Cy; y += pitchCenterH) {
      const float y1f = std::min(y + pitchCenterH, Cy);
      const float fy = (y1f - y) / pitchCenterH;
      const float v1f = v0 + (v1 - v0) * fy;
      for (float x = Bx; x < Cx; x += pitchCenterW) {
        const float x1f = std::min(x + pitchCenterW, Cx);
        const float fx = (x1f - x) / pitchCenterW;
        const float u1f = u0 + (u1 - u0) * fx;
        Quad(x, y, x1f, y1f, u0, v0, u1f, v1f);
      }
    }
  };

  // Draw order = top/bottom/left/right/center
  DrawTop();
  DrawBottom();
  DrawLeft();
  DrawRight();
  DrawCenter();

  rlPopMatrix();
  rlSetTexture(0);
}

inline void DrawTextureNPatchTiledSafe(Texture2D tex, NPatchInfo info,
                                       Rectangle dest, Vector2 origin,
                                       float rotation, Color tint,
                                       const NPatchTiling &til) {
  // Normalize negative source (raylib behavior)
  Rectangle src = info.source;
  if (src.width < 0) {
    src.x += src.width;
    src.width = -src.width;
  }
  if (src.height < 0) {
    src.y += src.height;
    src.height = -src.height;
  }
  info.source = src;

  const float srcW = src.width;
  const float srcH = src.height;
  const float L = (float)info.left, R = (float)info.right;
  const float T = (float)info.top, B = (float)info.bottom;

  const bool canTileX = (srcW - L - R) > 0.0f; // center span exists
  const bool canTileY = (srcH - T - B) > 0.0f;

  // Edges must still render even if they can't tile.
  const bool tileTop = til.top; // tile if true, else stretch
  const bool tileBottom = til.bottom;
  const bool tileLeft = til.left;
  const bool tileRight = til.right;

  // Center tiling only if there is a center span.
  const bool tileCX = til.centerX && canTileX;
  const bool tileCY = til.centerY && canTileY;

  // If no tiling at all and no background, use vanilla path.
  const bool wantsTilingOrBG = tileTop || tileBottom || tileLeft || tileRight ||
                               tileCX || tileCY || (til.background.a != 0);

  if (info.layout != NPATCH_NINE_PATCH || !wantsTilingOrBG) {
    DrawTextureNPatch(tex, info, dest, origin, rotation, tint);
    return;
  }

  // Optional: warn once if center asked to tile but can't.
  // (doesn't affect drawing—still draws with stretch)
  // if (til.centerX && !canTileX) SPDLOG_WARN("NPatch centerX requested but no
  // center span ({} - {} - {} <= 0)", srcW, L, R); if (til.centerY &&
  // !canTileY) SPDLOG_WARN("NPatch centerY requested but no center span ({} -
  // {} - {} <= 0)", srcH, T, B);

  DrawTextureNPatchTiled(tex, info, dest, origin, rotation, tint, tileTop,
                         tileBottom, tileLeft, tileRight, tileCX, tileCY,
                         til.background, til.pixelScale);
}

} // namespace nine_patch
