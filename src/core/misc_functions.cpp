#include "misc_fuctions.hpp"

#include "core/engine_context.hpp"
#include "core/game.hpp"
#include "core/globals.hpp"
#include "core/init.hpp"
#include "systems/palette/palette_quantizer.hpp"
#include "systems/shaders/shader_system.hpp"
#include "util/common_headers.hpp"
#include "util/utilities.hpp"
namespace game {
std::function<void()> OnUIScaleChanged = []() {
  // Default implementation does nothing
  SPDLOG_DEBUG("OnUIScaleChanged called, but no action defined.");
};

void SetUpShaderUniforms() {

  using namespace globals;
  // pre-load shader values for later use

  // my own polychrome
  // register frame‐time‐dependent uniforms
  shaders::registerUniformUpdate("custom_polychrome", [](Shader &sh) {
    // if you ever need to animate waveSpeed or time, update here
    globals::getGlobalShaderUniforms().set("custom_polychrome", "time",
                                           (float)main_loop::getTime());
  });

  // one‐time defaults
  globals::getGlobalShaderUniforms().set("custom_polychrome", "stripeFreq",
                                         0.3f);
  globals::getGlobalShaderUniforms().set("custom_polychrome", "waveFreq", 2.0f);
  globals::getGlobalShaderUniforms().set("custom_polychrome", "waveAmp", 0.4f);
  globals::getGlobalShaderUniforms().set("custom_polychrome", "waveSpeed",
                                         0.1f);
  globals::getGlobalShaderUniforms().set("custom_polychrome", "stripeWidth",
                                         1.0f);
  globals::getGlobalShaderUniforms().set("custom_polychrome", "polychrome",
                                         Vector2{0.0f, 0.1f});

  // spotlight shader
  // one‐time defaults
  // update on every frame in case of resize
  globals::getGlobalShaderUniforms().set(
      "spotlight", "screen_width", static_cast<float>(globals::VIRTUAL_WIDTH));
  globals::getGlobalShaderUniforms().set(
      "spotlight", "screen_height",
      static_cast<float>(globals::VIRTUAL_HEIGHT));
  globals::getGlobalShaderUniforms().set("spotlight", "circle_size", 0.5f);
  globals::getGlobalShaderUniforms().set("spotlight", "feather", 0.05f);
  globals::getGlobalShaderUniforms().set("spotlight", "circle_position",
                                         Vector2{0.5f, 0.5f});

  // palette shader

  palette_quantizer::setPaletteTexture(
      "palette_quantize",
      util::getRawAssetPathNoUUID("graphics/palettes/resurrect-64-1x.png"));
  // static auto paletteTex =
  // LoadTexture(util::getRawAssetPathNoUUID("graphics/palettes/duel-1x.png").c_str());
  // SetTextureFilter(paletteTex, TEXTURE_FILTER_POINT);
  // globalShaderUniforms.set("palette_quantize", "palette", paletteTex);
  // globalShaderUniforms.set("palette_quantize", "palette_size", 256.f); //
  // size of the palette

  // one-time defaults
  globals::getGlobalShaderUniforms().set("random_displacement_anim", "interval",
                                         0.5f);
  globals::getGlobalShaderUniforms().set("random_displacement_anim",
                                         "timeDelay", 1.4f);
  globals::getGlobalShaderUniforms().set("random_displacement_anim",
                                         "intensityX", 4.0f);
  globals::getGlobalShaderUniforms().set("random_displacement_anim",
                                         "intensityY", 4.0f);
  globals::getGlobalShaderUniforms().set("random_displacement_anim", "seed",
                                         42.0f);

  // every frame, drive the time
  shaders::registerUniformUpdate(
      "random_displacement_anim", [](Shader &shader) {
        globals::getGlobalShaderUniforms().set(
            "random_displacement_anim", "iTime", (float)main_loop::getTime());
      });

  globals::getGlobalShaderUniforms().set(
      "pixelate_image", "texSize",
      Vector2{(float)globals::getScreenWidth(),
              (float)globals::getScreenHeight()});
  globals::getGlobalShaderUniforms().set("pixelate_image", "pixelRatio", 0.9f);

  const int TILE_SIZE =
      64; // size of a tile in pixels, temporary, used for tile grid overlay

  auto frame = init::getSpriteFrame("tile-grid-boundary.png", globals::g_ctx);
  auto atlasID = frame.atlasUUID;
  Texture2D atlas{};
  if (auto *tex = getAtlasTexture(atlasID)) {
    atlas = *tex;
  }
  if (atlas.id == 0) {
    SPDLOG_ERROR("Texture atlas '{}' not found for tile grid overlay", atlasID);
    return;
  }
  auto gridX = frame.frame.x;
  auto gridY = frame.frame.y;
  auto gridW = frame.frame.width;
  auto gridH = frame.frame.height;

  // tile grid overlay
  shaders::registerUniformUpdate("tile_grid_overlay", [atlas](Shader &s) {
    globalShaderUniforms.set("tile_grid_overlay", "mouse_position",
                             getScaledMousePositionCached());

    globalShaderUniforms.set("tile_grid_overlay", "atlas", atlas);

    // auto shader = shaders::getShader("tile_grid_overlay");

    // int atlasLoc = GetShaderLocation(shader, "atlas");
    // SetShaderValueTexture(shader, atlasLoc, atlas);
  });

  float desiredCellSize = TILE_SIZE;    // in world‐units
  float scale = 1.0f / desiredCellSize; // how many cells per world‐unit

  // atlas dims
  globals::getGlobalShaderUniforms().set(
      "tile_grid_overlay", "uImageSize",
      Vector2{float(atlas.width), float(atlas.height)});
  // which grid sprite
  globals::getGlobalShaderUniforms().set("tile_grid_overlay", "uGridRect",
                                         Vector4{gridX, gridY, gridW, gridH});

  // grid parameters
  globals::getGlobalShaderUniforms().set("tile_grid_overlay", "scale", scale);
  globals::getGlobalShaderUniforms().set("tile_grid_overlay", "base_opacity",
                                         0.0f);
  globals::getGlobalShaderUniforms().set("tile_grid_overlay",
                                         "highlight_opacity", 0.4f);
  globals::getGlobalShaderUniforms().set("tile_grid_overlay",
                                         "distance_scaling", 100.0f);

  // outer space

  shaders::registerUniformUpdate(
      "outer_space_donuts_bg", [](Shader &shader) { // update iTime every frame
        globalShaderUniforms.set("outer_space_donuts_bg", "iTime",
                                 static_cast<float>(main_loop::getTime()));
      });
  // One-time setup
  globalShaderUniforms.set(
      "outer_space_donuts_bg", "iResolution",
      Vector2{(float)globals::VIRTUAL_WIDTH, (float)globals::VIRTUAL_HEIGHT});
  globalShaderUniforms.set("outer_space_donuts_bg", "grayAmount",
                           0.77f); // Set initial gray amount
  globalShaderUniforms.set("outer_space_donuts_bg", "desaturateAmount ",
                           2.87f); // Set initial desaturation amount
  globalShaderUniforms.set("outer_space_donuts_bg", "speedFactor",
                           0.61f); // Set initial speed factor

  globalShaderUniforms.set("outer_space_donuts_bg", "u_brightness",
                           0.17f); // Set initial brightness
  globalShaderUniforms.set("outer_space_donuts_bg", "u_noisiness",
                           0.22f); // Set initial noisiness
  globalShaderUniforms.set("outer_space_donuts_bg", "u_hueOffset",
                           0.0f); // Set initial hue offset
  globalShaderUniforms.set("outer_space_donuts_bg", "u_donutWidth",
                           -2.77f); // Set initial donut width
  globalShaderUniforms.set("outer_space_donuts_bg", "pixel_filter",
                           150.f); // Set initial hue offset

  // TODO: hue offset can be animated with timer

  // flash shader
  shaders::registerUniformUpdate(
      "flash", [](Shader &shader) { // update iTime every frame
        globalShaderUniforms.set("flash", "iTime",
                                 static_cast<float>(main_loop::getTime()));
      });

  // screen transition
  globalShaderUniforms.set("screen_tone_transition", "in_out", 0.f);
  globalShaderUniforms.set("screen_tone_transition", "position", 0.0f);
  globalShaderUniforms.set("screen_tone_transition", "size",
                           Vector2{32.f, 32.f});
  globalShaderUniforms.set(
      "screen_tone_transition", "screen_pixel_size",
      Vector2{1.0f / globals::VIRTUAL_WIDTH, 1.0f / globals::VIRTUAL_HEIGHT});
  globalShaderUniforms.set("screen_tone_transition", "in_color",
                           Vector4{0.0f, 0.0f, 0.0f, 1.0f});
  globalShaderUniforms.set("screen_tone_transition", "out_color",
                           Vector4{1.0f, 1.0f, 1.0f, 1.0f});

  // background shader

  /*

      iTime	float	0.0 → ∞	Elapsed time in seconds. Drives animation. Use
     main_loop::getTime() or delta accumulation. texelSize	vec2	1.0 /
     screenSize	Inverse of resolution. E.g., vec2(1.0/1280.0, 1.0/720.0).
      polar_coordinates	bool	0 or 1	Whether to enable polar swirl
     distortion. 1 = ON. polar_center	vec2	0.0–1.0	Normalized UV center of
     polar distortion. (0.5, 0.5) = screen center. polar_zoom	float	0.1–5.0
     Zooms radial distortion. 1.0 = normal. Lower = zoomed out, higher = intense
     warping. polar_repeat	float	1.0–10.0	Number of angular
     repetitions. Integer values give clean symmetry, higher = more spirals.
      spin_rotation	float	-50.0 to 50.0	Adds static phase offset to
     swirl. Negative = reverse direction. spin_speed	float	0.0–10.0+
     Time-based swirl speed. 1.0 is normal. Higher values animate faster. offset
     vec2	-1.0 to 1.0	Offsets center of swirl (in screen space units,
     scaled internally). (0,0) = centered. contrast	float	0.1–5.0
     Intensity of color banding & separation. 1–2 is moderate. Too low = washed
     out, too high = posterized. spin_amount	float	0.0–1.0	Controls swirl
     based on distance from center. 0 = flat, 1 = full swirl. pixel_filter
     float	50.0–1000.0	Pixelation size. Higher = smaller pixels. Use
     screen length / desired resolution. colour_1	vec4	Any RGBA
     Base layer color. Dominates background. colour_2	vec4	Any RGBA
     Middle blend color. Transitions with contrast and distance. colour_3
     vec4	Any RGBA	Accent/outer color. Used at edges in the
     paint-like effect.
  */
  globalShaderUniforms.set(
      "balatro_background", "texelSize",
      Vector2{1.0f / globals::VIRTUAL_WIDTH,
              1.0f / globals::VIRTUAL_HEIGHT}); // Dynamic resolution
  globalShaderUniforms.set("balatro_background", "polar_coordinates", 0.0f);
  globalShaderUniforms.set("balatro_background", "polar_center",
                           Vector2{0.5f, 0.5f});
  globalShaderUniforms.set("balatro_background", "polar_zoom", 4.52f);
  globalShaderUniforms.set("balatro_background", "polar_repeat", 2.91f);
  globalShaderUniforms.set("balatro_background", "spin_rotation", 7.0205107f);
  globalShaderUniforms.set("balatro_background", "spin_speed", 6.8f);
  globalShaderUniforms.set("balatro_background", "offset", Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("balatro_background", "contrast", 4.43f);
  globalShaderUniforms.set("balatro_background", "spin_amount", -0.09f);
  globalShaderUniforms.set("balatro_background", "pixel_filter", 300.0f);
  globalShaderUniforms.set(
      "balatro_background", "colour_1",
      Vector4{0.020128006f, 0.0139369555f, 0.049019635f, 1.0f});
  globalShaderUniforms.set("balatro_background", "colour_2",
                           Vector4{0.029411793f, 1.0f, 0.0f, 1.0f});
  globalShaderUniforms.set("balatro_background", "colour_3",
                           Vector4{1.0f, 1.0f, 1.0f, 1.0f});
  shaders::registerUniformUpdate(
      "balatro_background", [](Shader &shader) { // update iTime every frame
        globalShaderUniforms.set("balatro_background", "iTime",
                                 static_cast<float>(main_loop::getTime()));

        /*
            spin rotation:

            0.0	Neutral, baseline rotation
            1.0	Slight phase shift
            10.0	Visible but not overwhelming twist
            50.0+	Heavy spiral skewing, starts to distort hard
            Negative	Reverses swirl direction
            Fractional	Works fine – adds minor shifting
        */
        globalShaderUniforms.set(
            "balatro_background", "spin_rotation",
            static_cast<float>(sin(main_loop::getTime() * 0.01f) * 13.0f));
      });

  // crt

  /*
      resolution	vec2	Typically {320, 180} to {1920, 1080}	Target
     screen resolution, required for scaling effects and sampling. iTime
     float	0.0 → ∞	Time in seconds. Use main_loop::getTime(). Drives
     rolling lines, noise, chromatic aberration. scan_line_amount	float
     0.0 – 1.0	Strength of horizontal scanlines. 0.0 = off, 1.0 = full effect.
      scan_line_strength	float	-12.0 – -1.0	How sharp the scanlines
     are. More negative = thinner/darker. pixel_strength	float	-4.0 –
     0.0	How much pixel sampling blur is applied. 0.0 = sharp, -4.0 =
     blurry. warp_amount	float	0.0 – 5.0	Barrel distortion
     strength. Around 0.1 – 0.4 looks classic CRT. noise_amount	float	0.0 –
     0.3	Random static per pixel. Good for a "dirty signal" look.
      interference_amount	float	0.0 – 1.0	Horizontal jitter/noise.
     Higher = more glitchy interference. grille_amount	float	0.0 – 1.0
     Visibility of CRT RGB grille pattern. 0.1 – 0.4 is subtle, 1.0 is strong.
      grille_size	float	1.0 – 5.0	Scales the RGB grille. Smaller =
     tighter grille pattern. vignette_amount	float	0.0 – 2.0	Amount
     of darkening at corners. 1.0 is typical. vignette_intensity	float
     0.0 – 1.0	Sharpness of vignette. 0.2 = soft falloff, 1.0 = harsh.
      aberation_amount	float	0.0 – 1.0	Chromatic aberration (RGB
     channel shift). Subtle at 0.1, heavy at 0.5+. roll_line_amount	float
     0.0 – 1.0	Strength of vertical rolling white line. Retro TV effect.
      roll_speed	float	-8.0 – 8.0	Speed/direction of the rolling
     line. Positive = down, negative = up.
  */
  globalShaderUniforms.set(
      "crt", "resolution",
      Vector2{static_cast<float>(globals::VIRTUAL_WIDTH),
              static_cast<float>(globals::VIRTUAL_HEIGHT)});
  shaders::registerUniformUpdate(
      "crt", [](Shader &shader) { // update iTime every frame
        globalShaderUniforms.set("crt", "iTime",
                                 static_cast<float>(main_loop::getTime()));
      });
  globalShaderUniforms.set("crt", "roll_speed", 1.49f);
  globalShaderUniforms.set("crt", "resolution", Vector2{1280, 700});
  globalShaderUniforms.set("crt", "noise_amount", 0.0f);
  globalShaderUniforms.set("crt", "scan_line_amount", -0.17f);
  globalShaderUniforms.set("crt", "grille_amount", 0.37f);
  globalShaderUniforms.set("crt", "scan_line_strength", -3.78f);
  globalShaderUniforms.set("crt", "pixel_strength", 0.1f);
  globalShaderUniforms.set("crt", "vignette_amount", 1.41f);
  globalShaderUniforms.set("crt", "warp_amount", 0.06f);
  globalShaderUniforms.set("crt", "interference_amount", 0.f);
  globalShaderUniforms.set("crt", "roll_line_amount", 0.12f);
  globalShaderUniforms.set("crt", "grille_size", 0.51f);
  globalShaderUniforms.set("crt", "vignette_intensity", 0.10f);
  globalShaderUniforms.set("crt", "iTime", 113.47279f);
  globalShaderUniforms.set("crt", "aberation_amount", 0.93f);
  globalShaderUniforms.set("crt", "enable_rgb_scanlines", 1.0f);
  globalShaderUniforms.set("crt", "enable_dark_scanlines", 1.0f);
  globalShaderUniforms.set("crt", "scanline_density", 200.f);
  globalShaderUniforms.set("crt", "scanline_intensity", 0.10f);
  globalShaderUniforms.set("crt", "enable_bloom", 1.0f);
  globalShaderUniforms.set("crt", "bloom_strength", 0.19f);
  globalShaderUniforms.set("crt", "bloom_radius", 4.0f);
  globalShaderUniforms.set("crt", "glitch_strength", 0.02f);
  globalShaderUniforms.set("crt", "glitch_speed", 3.0f);
  globalShaderUniforms.set("crt", "glitch_density", 180.0f);

  // shockwave
  globalShaderUniforms.set(
      "shockwave", "resolution",
      Vector2{(float)globals::VIRTUAL_WIDTH, (float)globals::VIRTUAL_HEIGHT});
  globalShaderUniforms.set("shockwave", "strength", 0.18f);
  globalShaderUniforms.set("shockwave", "center", Vector2{0.5f, 0.5f});
  globalShaderUniforms.set("shockwave", "radius", 1.93f);
  globalShaderUniforms.set("shockwave", "aberration", -2.115f);
  globalShaderUniforms.set("shockwave", "width", 0.28f);
  globalShaderUniforms.set("shockwave", "feather", 0.415f);

  // glitch
  globalShaderUniforms.set(
      "glitch", "resolution",
      Vector2{(float)globals::VIRTUAL_WIDTH, (float)globals::VIRTUAL_HEIGHT});
  shaders::registerUniformUpdate(
      "glitch", [](Shader &shader) { // update iTime every frame
        globalShaderUniforms.set("glitch", "iTime",
                                 static_cast<float>(main_loop::getTime()));
      });
  globalShaderUniforms.set("glitch", "shake_power", 0.03f);
  globalShaderUniforms.set("glitch", "shake_rate", 0.2f);
  globalShaderUniforms.set("glitch", "shake_speed", 5.0f);
  globalShaderUniforms.set("glitch", "shake_block_size", 30.5f);
  globalShaderUniforms.set("glitch", "shake_color_rate", 0.01f);

  // wind
  shaders::registerUniformUpdate(
      "wind", [](Shader &shader) { // update iTime every frame
        globalShaderUniforms.set("wind", "iTime",
                                 static_cast<float>(main_loop::getTime()));
      });
  globalShaderUniforms.set("wind", "speed", 1.0f);
  globalShaderUniforms.set("wind", "minStrength", 0.05f);
  globalShaderUniforms.set("wind", "maxStrength", 0.1f);
  globalShaderUniforms.set("wind", "strengthScale", 100.0f);
  globalShaderUniforms.set("wind", "interval", 3.5f);
  globalShaderUniforms.set("wind", "detail", 2.0f);
  globalShaderUniforms.set("wind", "distortion", 1.0f);
  globalShaderUniforms.set("wind", "heightOffset", 0.0f);
  globalShaderUniforms.set("wind", "offset", 1.0f); // vary per object

  // vacuum collpase
  shaders::registerUniformUpdate("vacuum_collapse", [](Shader &shader) {
    globalShaderUniforms.set("vacuum_collapse", "iTime", (float)GetTime());
  });

  globalShaderUniforms.set("vacuum_collapse", "burst_progress", 0.0f);
  globalShaderUniforms.set("vacuum_collapse", "spread_strength", 1.0f);
  globalShaderUniforms.set("vacuum_collapse", "distortion_strength", 0.05f);
  globalShaderUniforms.set("vacuum_collapse", "fade_start", 0.7f);

  shaders::registerUniformUpdate("fireworks", [](Shader &shader) {
    globalShaderUniforms.set("fireworks", "iTime", (float)GetTime());
  });

  globalShaderUniforms.set("fireworks", "uGridRect", Vector4{0, 0, 1, 1});
  globalShaderUniforms.set("fireworks", "uImageSize",
                           Vector2{(float)screenWidth, (float)screenHeight});

  globalShaderUniforms.set("fireworks", "Praticle_num", (int)30);
  globalShaderUniforms.set("fireworks", "TimeStep", (int)2);

  // Floats (mirrors original Godot defaults)
  globalShaderUniforms.set("fireworks", "s77", 0.90f);
  globalShaderUniforms.set("fireworks", "Range", 0.75f);
  globalShaderUniforms.set("fireworks", "s55", 0.16f);
  globalShaderUniforms.set("fireworks", "gravity", 0.50f);
  globalShaderUniforms.set("fireworks", "ShneyMagnitude", 1.00f);
  globalShaderUniforms.set("fireworks", "s33", 0.13f);
  globalShaderUniforms.set("fireworks", "iTime", 0.0f);
  globalShaderUniforms.set("fireworks", "s99", 6.50f);
  globalShaderUniforms.set("fireworks", "s11", 0.80f);
  globalShaderUniforms.set("fireworks", "speed", 2.00f);

  // starry tunnel
  globalShaderUniforms.set("starry_tunnel", "m", 12);
  globalShaderUniforms.set("starry_tunnel", "n", 40);

  globalShaderUniforms.set("starry_tunnel", "hasNeonEffect", true);
  globalShaderUniforms.set("starry_tunnel", "hasDot", false);
  globalShaderUniforms.set("starry_tunnel", "haszExpend", false);

  globalShaderUniforms.set("starry_tunnel", "theta", 20.0f);
  globalShaderUniforms.set("starry_tunnel", "addH", 5.0f);
  globalShaderUniforms.set("starry_tunnel", "scale", 0.05f);

  globalShaderUniforms.set("starry_tunnel", "light_disperse", 4.0f);
  globalShaderUniforms.set("starry_tunnel", "stertch", 30.0f);
  globalShaderUniforms.set("starry_tunnel", "speed", 30.0f);
  globalShaderUniforms.set("starry_tunnel", "modTime", 20.0f);

  globalShaderUniforms.set("starry_tunnel", "rotate_speed", 3.0f);
  globalShaderUniforms.set("starry_tunnel", "rotate_plane_speed", 1.0f);
  globalShaderUniforms.set("starry_tunnel", "theta_sine_change_speed", 0.0f);

  globalShaderUniforms.set("starry_tunnel", "iswhite", false);
  globalShaderUniforms.set("starry_tunnel", "isdarktotransparent", false);
  globalShaderUniforms.set("starry_tunnel", "bemask", false);
  globalShaderUniforms.set("starry_tunnel", "debugMode", 0);

  shaders::registerUniformUpdate("starry_tunnel", [](Shader &shader) {
    globalShaderUniforms.set("starry_tunnel", "iTime", (float)GetTime());
  });

  // singel item glow
  shaders::registerUniformUpdate("item_glow", [](Shader &shader) {
    globalShaderUniforms.set("item_glow", "iTime", (float)GetTime());
  });
  globalShaderUniforms.set("item_glow", "glow_color",
                           Vector4{1.0f, 0.9f, 0.5f, 0.10f});
  globalShaderUniforms.set("item_glow", "intensity", 1.5f);
  globalShaderUniforms.set("item_glow", "spread", 1.0f);
  globalShaderUniforms.set("item_glow", "pulse_speed", 1.0f);

  // efficient_pixel_outline
  globalShaderUniforms.set("efficient_pixel_outline", "uGridRect",
                           Vector4{0, 0, 1, 1});
  globalShaderUniforms.set("efficient_pixel_outline", "uImageSize",
                           Vector2{(float)screenWidth, (float)screenHeight});
  globalShaderUniforms.set("efficient_pixel_outline", "outlineColor",
                           Vector4{0.0f, 0.0f, 0.0f, 1.0f});
  globalShaderUniforms.set("efficient_pixel_outline", "outlineType", 2);
  globalShaderUniforms.set("efficient_pixel_outline", "thickness", 1.0f);

  // atlas_outline
  globalShaderUniforms.set("atlas_outline", "uGridRect", Vector4{0, 0, 1, 1});
  globalShaderUniforms.set("atlas_outline", "uImageSize",
                           Vector2{(float)screenWidth, (float)screenHeight});
  globalShaderUniforms.set("atlas_outline", "outlineWidth", 1.0f);
  globalShaderUniforms.set("atlas_outline", "outlineColor",
                           Vector4{1.0f, 1.0f, 1.0f, 1.0f});

  // pixel_perfect_dissolving
  shaders::registerUniformUpdate(
      "pixel_perfect_dissolving", [](Shader &shader) {
        globalShaderUniforms.set("pixel_perfect_dissolving", "iTime",
                                 (float)GetTime());
      });
  globalShaderUniforms.set("pixel_perfect_dissolving", "uGridRect",
                           Vector4{0, 0, 1, 1});
  globalShaderUniforms.set("pixel_perfect_dissolving", "uImageSize",
                           Vector2{(float)screenWidth, (float)screenHeight});
  globalShaderUniforms.set("pixel_perfect_dissolving", "sensitivity", 0.5f);

  // dissolve_with_burn_edge
  globalShaderUniforms.set("dissolve_with_burn_edge", "uGridRect",
                           Vector4{0, 0, 1, 1});
  globalShaderUniforms.set("dissolve_with_burn_edge", "uImageSize",
                           Vector2{(float)screenWidth, (float)screenHeight});
  globalShaderUniforms.set("dissolve_with_burn_edge", "burn_size", 0.5f);
  globalShaderUniforms.set("dissolve_with_burn_edge", "burn_color",
                           Vector4{1.0f, 0.5f, 0.0f, 1.0f});
  globalShaderUniforms.set("dissolve_with_burn_edge", "dissolve_amount", 0.0f);

  // burn_2d
  shaders::registerUniformUpdate("burn_2d", [](Shader &shader) {
    globalShaderUniforms.set("burn_2d", "iTime", (float)GetTime());
  });
  globalShaderUniforms.set("burn_2d", "uGridRect", Vector4{0, 0, 1, 1});
  globalShaderUniforms.set("burn_2d", "uImageSize",
                           Vector2{(float)screenWidth, (float)screenHeight});
  globalShaderUniforms.set("burn_2d", "ashColor",
                           Vector4{0.2f, 0.2f, 0.2f, 1.0f});
  globalShaderUniforms.set("burn_2d", "burnColor",
                           Vector4{1.0f, 0.3f, 0.0f, 1.0f});
  globalShaderUniforms.set("burn_2d", "proBurnColor",
                           Vector4{1.0f, 1.0f, 0.0f, 1.0f});
  globalShaderUniforms.set("burn_2d", "burn_amount", 0.0f);

  // hologram_2d
  shaders::registerUniformUpdate("hologram_2d", [](Shader &shader) {
    globalShaderUniforms.set("hologram_2d", "iTime", (float)GetTime());
  });
  globalShaderUniforms.set("hologram_2d", "uGridRect", Vector4{0, 0, 1, 1});
  globalShaderUniforms.set("hologram_2d", "uImageSize",
                           Vector2{(float)screenWidth, (float)screenHeight});
  globalShaderUniforms.set("hologram_2d", "strength", 0.3f);
  globalShaderUniforms.set("hologram_2d", "offset", 0.1f);

  // liquid_effects
  shaders::registerUniformUpdate("liquid_effects", [](Shader &shader) {
    globalShaderUniforms.set("liquid_effects", "iTime", (float)GetTime());
  });
  globalShaderUniforms.set("liquid_effects", "uGridRect", Vector4{0, 0, 1, 1});
  globalShaderUniforms.set("liquid_effects", "uImageSize",
                           Vector2{(float)screenWidth, (float)screenHeight});
  globalShaderUniforms.set("liquid_effects", "amplitude", 0.05f);
  globalShaderUniforms.set("liquid_effects", "frequency", 10.0f);
  globalShaderUniforms.set("liquid_effects", "speed", 2.0f);

  // liquid_fill_sphere
  shaders::registerUniformUpdate("liquid_fill_sphere", [](Shader &shader) {
    globalShaderUniforms.set("liquid_fill_sphere", "iTime", (float)GetTime());
  });
  globalShaderUniforms.set("liquid_fill_sphere", "uGridRect",
                           Vector4{0, 0, 1, 1});
  globalShaderUniforms.set("liquid_fill_sphere", "uImageSize",
                           Vector2{(float)screenWidth, (float)screenHeight});
  globalShaderUniforms.set("liquid_fill_sphere", "fill_amount", 0.5f);
  globalShaderUniforms.set("liquid_fill_sphere", "liquid_color",
                           Vector4{0.0f, 0.5f, 1.0f, 0.8f});

  // pixel_art_trail
  shaders::registerUniformUpdate("pixel_art_trail", [](Shader &shader) {
    globalShaderUniforms.set("pixel_art_trail", "iTime", (float)GetTime());
  });
  globalShaderUniforms.set("pixel_art_trail", "uGridRect", Vector4{0, 0, 1, 1});
  globalShaderUniforms.set("pixel_art_trail", "uImageSize",
                           Vector2{(float)screenWidth, (float)screenHeight});
  globalShaderUniforms.set("pixel_art_trail", "trail_length", 5.0f);
  globalShaderUniforms.set("pixel_art_trail", "trail_color",
                           Vector4{1.0f, 1.0f, 1.0f, 0.5f});

  // animated_dotted_outline
  shaders::registerUniformUpdate("animated_dotted_outline", [](Shader &shader) {
    globalShaderUniforms.set("animated_dotted_outline", "iTime",
                             (float)GetTime());
  });
  globalShaderUniforms.set("animated_dotted_outline", "uGridRect",
                           Vector4{0, 0, 1, 1});
  globalShaderUniforms.set("animated_dotted_outline", "uImageSize",
                           Vector2{(float)screenWidth, (float)screenHeight});
  globalShaderUniforms.set("animated_dotted_outline", "line_color",
                           Vector4{1.0f, 1.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("animated_dotted_outline", "line_thickness", 1.0f);
  globalShaderUniforms.set("animated_dotted_outline", "frequency", 10.0f);

  // colorful_outline
  globalShaderUniforms.set("colorful_outline", "uGridRect",
                           Vector4{0, 0, 1, 1});
  globalShaderUniforms.set("colorful_outline", "uImageSize",
                           Vector2{(float)screenWidth, (float)screenHeight});
  globalShaderUniforms.set("colorful_outline", "intensity", 50);
  globalShaderUniforms.set("colorful_outline", "precision", 0.01f);
  globalShaderUniforms.set("colorful_outline", "outline_color",
                           Vector4{1.0f, 0.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("colorful_outline", "outline_color_2",
                           Vector4{0.0f, 1.0f, 1.0f, 1.0f});

  // dynamic_glow
  shaders::registerUniformUpdate("dynamic_glow", [](Shader &shader) {
    globalShaderUniforms.set("dynamic_glow", "iTime", (float)GetTime());
  });
  globalShaderUniforms.set("dynamic_glow", "uGridRect", Vector4{0, 0, 1, 1});
  globalShaderUniforms.set("dynamic_glow", "uImageSize",
                           Vector2{(float)screenWidth, (float)screenHeight});
  globalShaderUniforms.set("dynamic_glow", "glow_strength", 2.0f);
  globalShaderUniforms.set("dynamic_glow", "glow_color",
                           Vector4{1.0f, 0.5f, 0.0f, 1.0f});

  // wobbly
  shaders::registerUniformUpdate("wobbly", [](Shader &shader) {
    globalShaderUniforms.set("wobbly", "iTime", (float)GetTime());
  });
  globalShaderUniforms.set("wobbly", "uGridRect", Vector4{0, 0, 1, 1});
  globalShaderUniforms.set("wobbly", "uImageSize",
                           Vector2{(float)screenWidth, (float)screenHeight});
  globalShaderUniforms.set("wobbly", "amplitude", 0.02f);
  globalShaderUniforms.set("wobbly", "frequency", 5.0f);

  // bounce_wave
  shaders::registerUniformUpdate("bounce_wave", [](Shader &shader) {
    globalShaderUniforms.set("bounce_wave", "iTime", (float)GetTime());
  });
  globalShaderUniforms.set("bounce_wave", "uGridRect", Vector4{0, 0, 1, 1});
  globalShaderUniforms.set("bounce_wave", "uImageSize",
                           Vector2{(float)screenWidth, (float)screenHeight});
  globalShaderUniforms.set("bounce_wave", "amplitude", 10.0f);
  globalShaderUniforms.set("bounce_wave", "frequency", 5.0f);

  // radial_fire_2d
  shaders::registerUniformUpdate("radial_fire_2d", [](Shader &shader) {
    globalShaderUniforms.set("radial_fire_2d", "iTime", (float)GetTime());
  });
  globalShaderUniforms.set("radial_fire_2d", "uGridRect", Vector4{0, 0, 1, 1});
  globalShaderUniforms.set("radial_fire_2d", "uImageSize",
                           Vector2{(float)screenWidth, (float)screenHeight});
  globalShaderUniforms.set("radial_fire_2d", "fire_intensity", 1.0f);

  // radial_shine_2d
  shaders::registerUniformUpdate("radial_shine_2d", [](Shader &shader) {
    globalShaderUniforms.set("radial_shine_2d", "iTime", (float)GetTime());
  });
  globalShaderUniforms.set("radial_shine_2d", "uGridRect", Vector4{0, 0, 1, 1});
  globalShaderUniforms.set("radial_shine_2d", "uImageSize",
                           Vector2{(float)screenWidth, (float)screenHeight});
  globalShaderUniforms.set("radial_shine_2d", "shine_color",
                           Vector4{1.0f, 1.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("radial_shine_2d", "shine_strength", 1.0f);

  // holographic_card
  shaders::registerUniformUpdate("holographic_card", [](Shader &shader) {
    globalShaderUniforms.set("holographic_card", "iTime", (float)GetTime());
  });
  globalShaderUniforms.set("holographic_card", "uGridRect",
                           Vector4{0, 0, 1, 1});
  globalShaderUniforms.set("holographic_card", "uImageSize",
                           Vector2{(float)screenWidth, (float)screenHeight});
  globalShaderUniforms.set("holographic_card", "rotation", 0.0f);
  globalShaderUniforms.set("holographic_card", "perspective_strength", 0.3f);

  // pseudo 3d skew
  shaders::registerUniformUpdate("3d_skew", [](Shader &shader) {
    globalShaderUniforms.set("3d_skew", "iTime",
                             static_cast<float>(main_loop::getTime()));
    globalShaderUniforms.set("3d_skew", "time",
                             static_cast<float>(main_loop::getTime()));
    globalShaderUniforms.set("3d_skew", "mouse_screen_pos",
                             getScaledMousePositionCached());
    globalShaderUniforms.set(
        "3d_skew", "resolution",
        Vector2{static_cast<float>(globals::VIRTUAL_WIDTH),
                static_cast<float>(globals::VIRTUAL_HEIGHT)});
    // Keep dissolve defaults in sync with the Godot reference.
    globalShaderUniforms.set("3d_skew", "spread_strength", 1.0f);
    globalShaderUniforms.set("3d_skew", "distortion_strength", 0.05f);
    globalShaderUniforms.set("3d_skew", "fade_start", 0.7f);
  });
  // --- Projection parameters (from your log) ---
  globalShaderUniforms.set("3d_skew", "fov", -0.39f); // From runtime dump
  globalShaderUniforms.set("3d_skew", "x_rot", 0.0f); // No X tilt
  globalShaderUniforms.set("3d_skew", "y_rot", 0.0f); // No Y orbit
  globalShaderUniforms.set("3d_skew", "inset", 0.0f); // No edge compression
  // --- Interaction dynamics ---
  globalShaderUniforms.set("3d_skew", "hovering", 0.3f); // From your log
  globalShaderUniforms.set("3d_skew", "rand_trans_power",
                           0.4f); // From your log
  globalShaderUniforms.set("3d_skew", "rand_seed",
                           3.1415f);                     // Per-object offset
  globalShaderUniforms.set("3d_skew", "rotation", 0.0f); // No UV twist
  globalShaderUniforms.set("3d_skew", "cull_back",
                           0.0f); // Disable backface culling
  globalShaderUniforms.set("3d_skew", "tilt_enabled", 0.0f);
  // --- Geometry settings ---
  float drawWidth = static_cast<float>(globals::VIRTUAL_WIDTH);
  float drawHeight = static_cast<float>(globals::VIRTUAL_HEIGHT);
  globalShaderUniforms.set("3d_skew", "regionRate",
                           Vector2{
                               drawWidth / drawWidth,  // = 1.0
                               drawHeight / drawHeight // = 1.0
                           });
  globalShaderUniforms.set("3d_skew", "pivot", Vector2{0.0f, 0.0f}); // Al
  globalShaderUniforms.set("3d_skew", "quad_center",
                           Vector2{0.0f, 0.0f}); // Screen-space center
  globalShaderUniforms.set("3d_skew", "quad_size",
                           Vector2{1.0f, 1.0f}); // Screen-space size
  globalShaderUniforms.set("3d_skew", "uv_passthrough", 0.0f);
  globalShaderUniforms.set("3d_skew", "uGridRect",
                           Vector4{0.0f, 0.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew", "uImageSize",
                           Vector2{drawWidth, drawHeight});
  globalShaderUniforms.set("3d_skew", "texture_details",
                           Vector4{0.0f, 0.0f, 64.0f, 64.0f});
  globalShaderUniforms.set("3d_skew", "image_details",
                           Vector2{65.15f, 64.0f});
  globalShaderUniforms.set("3d_skew", "dissolve", 0.0f);
  globalShaderUniforms.set("3d_skew", "shadow", 0.0f);
  globalShaderUniforms.set("3d_skew", "burn_colour_1",
                           Vector4{0.0f, 0.0f, 0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew", "burn_colour_2",
                           Vector4{0.0f, 0.0f, 0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew", "card_rotation", 0.0f);
  globalShaderUniforms.set("3d_skew", "material_tint",
                           Vector3{1.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew", "grain_intensity", -1.95f);
  globalShaderUniforms.set("3d_skew", "grain_scale", -2.21f);
  globalShaderUniforms.set("3d_skew", "sheen_strength", -1.49f);
  globalShaderUniforms.set("3d_skew", "sheen_width", 2.22f);
  globalShaderUniforms.set("3d_skew", "sheen_speed", 2.3f);
  globalShaderUniforms.set("3d_skew", "noise_amount", 1.12f);
  globalShaderUniforms.set("3d_skew", "spread_strength", 1.0f);
  globalShaderUniforms.set("3d_skew", "distortion_strength", 0.05f);
  globalShaderUniforms.set("3d_skew", "fade_start", 0.7f);

  // pseudo 3d skew hologram (shares defaults; overlay differs in shader code)
  shaders::registerUniformUpdate("3d_skew_hologram", [](Shader &shader) {
    globalShaderUniforms.set("3d_skew_hologram", "iTime",
                             static_cast<float>(main_loop::getTime()));
    globalShaderUniforms.set("3d_skew_hologram", "time",
                             static_cast<float>(main_loop::getTime()));
    globalShaderUniforms.set("3d_skew_hologram", "mouse_screen_pos",
                             getScaledMousePositionCached());
    globalShaderUniforms.set(
        "3d_skew_hologram", "resolution",
        Vector2{static_cast<float>(globals::VIRTUAL_WIDTH),
                static_cast<float>(globals::VIRTUAL_HEIGHT)});
    globalShaderUniforms.set("3d_skew_hologram", "spread_strength", 1.0f);
    globalShaderUniforms.set("3d_skew_hologram", "distortion_strength", 0.05f);
    globalShaderUniforms.set("3d_skew_hologram", "fade_start", 0.7f);
  });
  globalShaderUniforms.set("3d_skew_hologram", "fov", -0.39f);
  globalShaderUniforms.set("3d_skew_hologram", "x_rot", 0.0f);
  globalShaderUniforms.set("3d_skew_hologram", "y_rot", 0.0f);
  globalShaderUniforms.set("3d_skew_hologram", "inset", 0.0f);
  globalShaderUniforms.set("3d_skew_hologram", "hovering", 0.3f);
  globalShaderUniforms.set("3d_skew_hologram", "rand_trans_power", 0.4f);
  globalShaderUniforms.set("3d_skew_hologram", "rand_seed", 3.1415f);
  globalShaderUniforms.set("3d_skew_hologram", "rotation", 0.0f);
  globalShaderUniforms.set("3d_skew_hologram", "cull_back", 0.0f);
  globalShaderUniforms.set("3d_skew_hologram", "tilt_enabled", 0.0f);
  float holoDrawWidth = static_cast<float>(globals::VIRTUAL_WIDTH);
  float holoDrawHeight = static_cast<float>(globals::VIRTUAL_HEIGHT);
  globalShaderUniforms.set("3d_skew_hologram", "regionRate",
                           Vector2{holoDrawWidth / holoDrawWidth,
                                   holoDrawHeight / holoDrawHeight});
  globalShaderUniforms.set("3d_skew_hologram", "pivot",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_hologram", "quad_center",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_hologram", "quad_size",
                           Vector2{1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_hologram", "uv_passthrough", 0.0f);
  globalShaderUniforms.set("3d_skew_hologram", "uGridRect",
                           Vector4{0.0f, 0.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_hologram", "uImageSize",
                           Vector2{holoDrawWidth, holoDrawHeight});
  globalShaderUniforms.set("3d_skew_hologram", "texture_details",
                           Vector4{0.0f, 0.0f, 64.0f, 64.0f});
  globalShaderUniforms.set("3d_skew_hologram", "image_details",
                           Vector2{65.15f, 64.0f});
  globalShaderUniforms.set("3d_skew_hologram", "dissolve", 0.0f);
  globalShaderUniforms.set("3d_skew_hologram", "shadow", 0.0f);
  globalShaderUniforms.set("3d_skew_hologram", "burn_colour_1",
                           Vector4{0.0f, 0.0f, 0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_hologram", "burn_colour_2",
                           Vector4{0.0f, 0.0f, 0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_hologram", "card_rotation", 0.0f);
  globalShaderUniforms.set("3d_skew_hologram", "material_tint",
                           Vector3{1.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_hologram", "grain_intensity", -1.95f);
  globalShaderUniforms.set("3d_skew_hologram", "grain_scale", -2.21f);
  globalShaderUniforms.set("3d_skew_hologram", "sheen_strength", -1.49f);
  globalShaderUniforms.set("3d_skew_hologram", "sheen_width", 2.22f);
  globalShaderUniforms.set("3d_skew_hologram", "sheen_speed", 2.3f);
  globalShaderUniforms.set("3d_skew_hologram", "noise_amount", 1.12f);
  globalShaderUniforms.set("3d_skew_hologram", "spread_strength", 1.0f);
  globalShaderUniforms.set("3d_skew_hologram", "distortion_strength", 0.05f);
  globalShaderUniforms.set("3d_skew_hologram", "fade_start", 0.7f);

  // pseudo 3d skew polychrome (sheen replaced by polychrome hue shift)
  shaders::registerUniformUpdate("3d_skew_polychrome", [](Shader &shader) {
    globalShaderUniforms.set("3d_skew_polychrome", "iTime",
                             static_cast<float>(main_loop::getTime()));
    globalShaderUniforms.set("3d_skew_polychrome", "time",
                             static_cast<float>(main_loop::getTime()));
    globalShaderUniforms.set("3d_skew_polychrome", "mouse_screen_pos",
                             getScaledMousePositionCached());
    globalShaderUniforms.set(
        "3d_skew_polychrome", "resolution",
        Vector2{static_cast<float>(globals::VIRTUAL_WIDTH),
                static_cast<float>(globals::VIRTUAL_HEIGHT)});
    globalShaderUniforms.set("3d_skew_polychrome", "spread_strength", 1.0f);
    globalShaderUniforms.set("3d_skew_polychrome", "distortion_strength", 0.05f);
    globalShaderUniforms.set("3d_skew_polychrome", "fade_start", 0.7f);
  });
  globalShaderUniforms.set("3d_skew_polychrome", "fov", -0.39f);
  globalShaderUniforms.set("3d_skew_polychrome", "x_rot", 0.0f);
  globalShaderUniforms.set("3d_skew_polychrome", "y_rot", 0.0f);
  globalShaderUniforms.set("3d_skew_polychrome", "inset", 0.0f);
  globalShaderUniforms.set("3d_skew_polychrome", "hovering", 0.3f);
  globalShaderUniforms.set("3d_skew_polychrome", "rand_trans_power", 0.4f);
  globalShaderUniforms.set("3d_skew_polychrome", "rand_seed", 3.1415f);
  globalShaderUniforms.set("3d_skew_polychrome", "rotation", 0.0f);
  globalShaderUniforms.set("3d_skew_polychrome", "cull_back", 0.0f);
  globalShaderUniforms.set("3d_skew_polychrome", "tilt_enabled", 0.0f);
  float polyDrawWidth = static_cast<float>(globals::VIRTUAL_WIDTH);
  float polyDrawHeight = static_cast<float>(globals::VIRTUAL_HEIGHT);
  globalShaderUniforms.set("3d_skew_polychrome", "regionRate",
                           Vector2{polyDrawWidth / polyDrawWidth,
                                   polyDrawHeight / polyDrawHeight});
  globalShaderUniforms.set("3d_skew_polychrome", "pivot",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_polychrome", "quad_center",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_polychrome", "quad_size",
                           Vector2{1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_polychrome", "uv_passthrough", 0.0f);
  globalShaderUniforms.set("3d_skew_polychrome", "uGridRect",
                           Vector4{0.0f, 0.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_polychrome", "uImageSize",
                           Vector2{polyDrawWidth, polyDrawHeight});
  globalShaderUniforms.set("3d_skew_polychrome", "texture_details",
                           Vector4{0.0f, 0.0f, 64.0f, 64.0f});
  globalShaderUniforms.set("3d_skew_polychrome", "image_details",
                           Vector2{65.15f, 64.0f});
  globalShaderUniforms.set("3d_skew_polychrome", "dissolve", 0.0f);
  globalShaderUniforms.set("3d_skew_polychrome", "shadow", 0.0f);
  globalShaderUniforms.set("3d_skew_polychrome", "burn_colour_1",
                           Vector4{0.0f, 0.0f, 0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_polychrome", "burn_colour_2",
                           Vector4{0.0f, 0.0f, 0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_polychrome", "card_rotation", 0.0f);
  globalShaderUniforms.set("3d_skew_polychrome", "material_tint",
                           Vector3{1.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_polychrome", "grain_intensity", -1.95f);
  globalShaderUniforms.set("3d_skew_polychrome", "grain_scale", -2.21f);
  globalShaderUniforms.set("3d_skew_polychrome", "sheen_strength", -1.49f);
  globalShaderUniforms.set("3d_skew_polychrome", "sheen_width", 2.22f);
  globalShaderUniforms.set("3d_skew_polychrome", "sheen_speed", 2.3f);
  globalShaderUniforms.set("3d_skew_polychrome", "noise_amount", 1.12f);
  globalShaderUniforms.set("3d_skew_polychrome", "spread_strength", 1.0f);
  globalShaderUniforms.set("3d_skew_polychrome", "distortion_strength", 0.05f);
  globalShaderUniforms.set("3d_skew_polychrome", "fade_start", 0.7f);
  globalShaderUniforms.set("3d_skew_polychrome", "polychrome",
                           Vector2{0.65f, 0.25f});

  // pseudo 3d skew foil (foil overlay)
  shaders::registerUniformUpdate("3d_skew_foil", [](Shader &shader) {
    globalShaderUniforms.set("3d_skew_foil", "iTime",
                             static_cast<float>(main_loop::getTime()));
    globalShaderUniforms.set("3d_skew_foil", "time",
                             static_cast<float>(main_loop::getTime()));
    globalShaderUniforms.set("3d_skew_foil", "mouse_screen_pos",
                             getScaledMousePositionCached());
    globalShaderUniforms.set(
        "3d_skew_foil", "resolution",
        Vector2{static_cast<float>(globals::VIRTUAL_WIDTH),
                static_cast<float>(globals::VIRTUAL_HEIGHT)});
    globalShaderUniforms.set("3d_skew_foil", "spread_strength", 1.0f);
    globalShaderUniforms.set("3d_skew_foil", "distortion_strength", 0.05f);
    globalShaderUniforms.set("3d_skew_foil", "fade_start", 0.7f);
  });
  globalShaderUniforms.set("3d_skew_foil", "fov", -0.39f);
  globalShaderUniforms.set("3d_skew_foil", "x_rot", 0.0f);
  globalShaderUniforms.set("3d_skew_foil", "y_rot", 0.0f);
  globalShaderUniforms.set("3d_skew_foil", "inset", 0.0f);
  globalShaderUniforms.set("3d_skew_foil", "hovering", 0.3f);
  globalShaderUniforms.set("3d_skew_foil", "rand_trans_power", 0.4f);
  globalShaderUniforms.set("3d_skew_foil", "rand_seed", 3.1415f);
  globalShaderUniforms.set("3d_skew_foil", "rotation", 0.0f);
  globalShaderUniforms.set("3d_skew_foil", "cull_back", 0.0f);
  globalShaderUniforms.set("3d_skew_foil", "tilt_enabled", 0.0f);
  float foilDrawWidth = static_cast<float>(globals::VIRTUAL_WIDTH);
  float foilDrawHeight = static_cast<float>(globals::VIRTUAL_HEIGHT);
  globalShaderUniforms.set("3d_skew_foil", "regionRate",
                           Vector2{foilDrawWidth / foilDrawWidth,
                                   foilDrawHeight / foilDrawHeight});
  globalShaderUniforms.set("3d_skew_foil", "pivot",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_foil", "quad_center",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_foil", "quad_size",
                           Vector2{1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_foil", "uv_passthrough", 0.0f);
  globalShaderUniforms.set("3d_skew_foil", "uGridRect",
                           Vector4{0.0f, 0.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_foil", "uImageSize",
                           Vector2{foilDrawWidth, foilDrawHeight});
  globalShaderUniforms.set("3d_skew_foil", "texture_details",
                           Vector4{0.0f, 0.0f, 64.0f, 64.0f});
  globalShaderUniforms.set("3d_skew_foil", "image_details",
                           Vector2{65.15f, 64.0f});
  globalShaderUniforms.set("3d_skew_foil", "dissolve", 0.0f);
  globalShaderUniforms.set("3d_skew_foil", "shadow", 0.0f);
  globalShaderUniforms.set("3d_skew_foil", "burn_colour_1",
                           Vector4{0.0f, 0.0f, 0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_foil", "burn_colour_2",
                           Vector4{0.0f, 0.0f, 0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_foil", "card_rotation", 0.0f);
  globalShaderUniforms.set("3d_skew_foil", "material_tint",
                           Vector3{1.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_foil", "grain_intensity", -1.95f);
  globalShaderUniforms.set("3d_skew_foil", "grain_scale", -2.21f);
  globalShaderUniforms.set("3d_skew_foil", "sheen_strength", -1.49f);
  globalShaderUniforms.set("3d_skew_foil", "sheen_width", 2.22f);
  globalShaderUniforms.set("3d_skew_foil", "sheen_speed", 2.3f);
  globalShaderUniforms.set("3d_skew_foil", "noise_amount", 1.12f);
  globalShaderUniforms.set("3d_skew_foil", "spread_strength", 1.0f);
  globalShaderUniforms.set("3d_skew_foil", "distortion_strength", 0.05f);
  globalShaderUniforms.set("3d_skew_foil", "fade_start", 0.7f);
  globalShaderUniforms.set("3d_skew_foil", "foil",
                           Vector2{0.65f, 0.25f});

  // pseudo 3d skew negative shine
  shaders::registerUniformUpdate("3d_skew_negative_shine", [](Shader &shader) {
    globalShaderUniforms.set("3d_skew_negative_shine", "iTime",
                             static_cast<float>(main_loop::getTime()));
    globalShaderUniforms.set("3d_skew_negative_shine", "time",
                             static_cast<float>(main_loop::getTime()));
    globalShaderUniforms.set("3d_skew_negative_shine", "mouse_screen_pos",
                             getScaledMousePositionCached());
    globalShaderUniforms.set(
        "3d_skew_negative_shine", "resolution",
        Vector2{static_cast<float>(globals::VIRTUAL_WIDTH),
                static_cast<float>(globals::VIRTUAL_HEIGHT)});
    globalShaderUniforms.set("3d_skew_negative_shine", "spread_strength", 1.0f);
    globalShaderUniforms.set("3d_skew_negative_shine", "distortion_strength", 0.05f);
    globalShaderUniforms.set("3d_skew_negative_shine", "fade_start", 0.7f);
  });
  globalShaderUniforms.set("3d_skew_negative_shine", "fov", -0.39f);
  globalShaderUniforms.set("3d_skew_negative_shine", "x_rot", 0.0f);
  globalShaderUniforms.set("3d_skew_negative_shine", "y_rot", 0.0f);
  globalShaderUniforms.set("3d_skew_negative_shine", "inset", 0.0f);
  globalShaderUniforms.set("3d_skew_negative_shine", "hovering", 0.3f);
  globalShaderUniforms.set("3d_skew_negative_shine", "rand_trans_power", 0.4f);
  globalShaderUniforms.set("3d_skew_negative_shine", "rand_seed", 3.1415f);
  globalShaderUniforms.set("3d_skew_negative_shine", "rotation", 0.0f);
  globalShaderUniforms.set("3d_skew_negative_shine", "cull_back", 0.0f);
  globalShaderUniforms.set("3d_skew_negative_shine", "tilt_enabled", 0.0f);
  float negDrawWidth = static_cast<float>(globals::VIRTUAL_WIDTH);
  float negDrawHeight = static_cast<float>(globals::VIRTUAL_HEIGHT);
  globalShaderUniforms.set("3d_skew_negative_shine", "regionRate",
                           Vector2{negDrawWidth / negDrawWidth,
                                   negDrawHeight / negDrawHeight});
  globalShaderUniforms.set("3d_skew_negative_shine", "pivot",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_negative_shine", "quad_center",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_negative_shine", "quad_size",
                           Vector2{1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_negative_shine", "uv_passthrough", 0.0f);
  globalShaderUniforms.set("3d_skew_negative_shine", "uGridRect",
                           Vector4{0.0f, 0.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_negative_shine", "uImageSize",
                           Vector2{negDrawWidth, negDrawHeight});
  globalShaderUniforms.set("3d_skew_negative_shine", "texture_details",
                           Vector4{0.0f, 0.0f, 64.0f, 64.0f});
  globalShaderUniforms.set("3d_skew_negative_shine", "image_details",
                           Vector2{65.15f, 64.0f});
  globalShaderUniforms.set("3d_skew_negative_shine", "dissolve", 0.0f);
  globalShaderUniforms.set("3d_skew_negative_shine", "shadow", 0.0f);
  globalShaderUniforms.set("3d_skew_negative_shine", "burn_colour_1",
                           Vector4{0.0f, 0.0f, 0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_negative_shine", "burn_colour_2",
                           Vector4{0.0f, 0.0f, 0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_negative_shine", "card_rotation", 0.0f);
  globalShaderUniforms.set("3d_skew_negative_shine", "material_tint",
                           Vector3{1.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_negative_shine", "grain_intensity", -1.95f);
  globalShaderUniforms.set("3d_skew_negative_shine", "grain_scale", -2.21f);
  globalShaderUniforms.set("3d_skew_negative_shine", "sheen_strength", -1.49f);
  globalShaderUniforms.set("3d_skew_negative_shine", "sheen_width", 2.22f);
  globalShaderUniforms.set("3d_skew_negative_shine", "sheen_speed", 2.3f);
  globalShaderUniforms.set("3d_skew_negative_shine", "noise_amount", 1.12f);
  globalShaderUniforms.set("3d_skew_negative_shine", "spread_strength", 1.0f);
  globalShaderUniforms.set("3d_skew_negative_shine", "distortion_strength", 0.05f);
  globalShaderUniforms.set("3d_skew_negative_shine", "fade_start", 0.7f);
  globalShaderUniforms.set("3d_skew_negative_shine", "negative_shine",
                           Vector2{0.65f, 0.25f});

  // pseudo 3d skew negative
  shaders::registerUniformUpdate("3d_skew_negative", [](Shader &shader) {
    globalShaderUniforms.set("3d_skew_negative", "iTime",
                             static_cast<float>(main_loop::getTime()));
    globalShaderUniforms.set("3d_skew_negative", "time",
                             static_cast<float>(main_loop::getTime()));
    globalShaderUniforms.set("3d_skew_negative", "mouse_screen_pos",
                             getScaledMousePositionCached());
    globalShaderUniforms.set(
        "3d_skew_negative", "resolution",
        Vector2{static_cast<float>(globals::VIRTUAL_WIDTH),
                static_cast<float>(globals::VIRTUAL_HEIGHT)});
    globalShaderUniforms.set("3d_skew_negative", "spread_strength", 1.0f);
    globalShaderUniforms.set("3d_skew_negative", "distortion_strength", 0.05f);
    globalShaderUniforms.set("3d_skew_negative", "fade_start", 0.7f);
  });
  globalShaderUniforms.set("3d_skew_negative", "fov", -0.39f);
  globalShaderUniforms.set("3d_skew_negative", "x_rot", 0.0f);
  globalShaderUniforms.set("3d_skew_negative", "y_rot", 0.0f);
  globalShaderUniforms.set("3d_skew_negative", "inset", 0.0f);
  globalShaderUniforms.set("3d_skew_negative", "hovering", 0.3f);
  globalShaderUniforms.set("3d_skew_negative", "rand_trans_power", 0.4f);
  globalShaderUniforms.set("3d_skew_negative", "rand_seed", 3.1415f);
  globalShaderUniforms.set("3d_skew_negative", "rotation", 0.0f);
  globalShaderUniforms.set("3d_skew_negative", "cull_back", 0.0f);
  globalShaderUniforms.set("3d_skew_negative", "tilt_enabled", 0.0f);
  float neg2DrawWidth = static_cast<float>(globals::VIRTUAL_WIDTH);
  float neg2DrawHeight = static_cast<float>(globals::VIRTUAL_HEIGHT);
  globalShaderUniforms.set("3d_skew_negative", "regionRate",
                           Vector2{neg2DrawWidth / neg2DrawWidth,
                                   neg2DrawHeight / neg2DrawHeight});
  globalShaderUniforms.set("3d_skew_negative", "pivot",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_negative", "quad_center",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_negative", "quad_size",
                           Vector2{1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_negative", "uv_passthrough", 0.0f);
  globalShaderUniforms.set("3d_skew_negative", "uGridRect",
                           Vector4{0.0f, 0.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_negative", "uImageSize",
                           Vector2{neg2DrawWidth, neg2DrawHeight});
  globalShaderUniforms.set("3d_skew_negative", "texture_details",
                           Vector4{0.0f, 0.0f, 64.0f, 64.0f});
  globalShaderUniforms.set("3d_skew_negative", "image_details",
                           Vector2{65.15f, 64.0f});
  globalShaderUniforms.set("3d_skew_negative", "dissolve", 0.0f);
  globalShaderUniforms.set("3d_skew_negative", "shadow", 0.0f);
  globalShaderUniforms.set("3d_skew_negative", "burn_colour_1",
                           Vector4{0.0f, 0.0f, 0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_negative", "burn_colour_2",
                           Vector4{0.0f, 0.0f, 0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_negative", "card_rotation", 0.0f);
  globalShaderUniforms.set("3d_skew_negative", "material_tint",
                           Vector3{1.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_negative", "grain_intensity", -1.95f);
  globalShaderUniforms.set("3d_skew_negative", "grain_scale", -2.21f);
  globalShaderUniforms.set("3d_skew_negative", "sheen_strength", -1.49f);
  globalShaderUniforms.set("3d_skew_negative", "sheen_width", 2.22f);
  globalShaderUniforms.set("3d_skew_negative", "sheen_speed", 2.3f);
  globalShaderUniforms.set("3d_skew_negative", "noise_amount", 1.12f);
  globalShaderUniforms.set("3d_skew_negative", "spread_strength", 1.0f);
  globalShaderUniforms.set("3d_skew_negative", "distortion_strength", 0.05f);
  globalShaderUniforms.set("3d_skew_negative", "fade_start", 0.7f);
  globalShaderUniforms.set("3d_skew_negative", "negative",
                           Vector2{0.65f, 0.25f});

  // pseudo 3d skew holo
  shaders::registerUniformUpdate("3d_skew_holo", [](Shader &shader) {
    globalShaderUniforms.set("3d_skew_holo", "iTime",
                             static_cast<float>(main_loop::getTime()));
    globalShaderUniforms.set("3d_skew_holo", "time",
                             static_cast<float>(main_loop::getTime()));
    globalShaderUniforms.set("3d_skew_holo", "mouse_screen_pos",
                             getScaledMousePositionCached());
    globalShaderUniforms.set(
        "3d_skew_holo", "resolution",
        Vector2{static_cast<float>(globals::VIRTUAL_WIDTH),
                static_cast<float>(globals::VIRTUAL_HEIGHT)});
    globalShaderUniforms.set("3d_skew_holo", "spread_strength", 1.0f);
    globalShaderUniforms.set("3d_skew_holo", "distortion_strength", 0.05f);
    globalShaderUniforms.set("3d_skew_holo", "fade_start", 0.7f);
  });
  globalShaderUniforms.set("3d_skew_holo", "fov", -0.39f);
  globalShaderUniforms.set("3d_skew_holo", "x_rot", 0.0f);
  globalShaderUniforms.set("3d_skew_holo", "y_rot", 0.0f);
  globalShaderUniforms.set("3d_skew_holo", "inset", 0.0f);
  globalShaderUniforms.set("3d_skew_holo", "hovering", 0.3f);
  globalShaderUniforms.set("3d_skew_holo", "rand_trans_power", 0.4f);
  globalShaderUniforms.set("3d_skew_holo", "rand_seed", 3.1415f);
  globalShaderUniforms.set("3d_skew_holo", "rotation", 0.0f);
  globalShaderUniforms.set("3d_skew_holo", "cull_back", 0.0f);
  globalShaderUniforms.set("3d_skew_holo", "tilt_enabled", 0.0f);
  float holo2DrawWidth = static_cast<float>(globals::VIRTUAL_WIDTH);
  float holo2DrawHeight = static_cast<float>(globals::VIRTUAL_HEIGHT);
  globalShaderUniforms.set("3d_skew_holo", "regionRate",
                           Vector2{holo2DrawWidth / holo2DrawWidth,
                                   holo2DrawHeight / holo2DrawHeight});
  globalShaderUniforms.set("3d_skew_holo", "pivot",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_holo", "quad_center",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_holo", "quad_size",
                           Vector2{1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_holo", "uv_passthrough", 0.0f);
  globalShaderUniforms.set("3d_skew_holo", "uGridRect",
                           Vector4{0.0f, 0.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_holo", "uImageSize",
                           Vector2{holo2DrawWidth, holo2DrawHeight});
  globalShaderUniforms.set("3d_skew_holo", "texture_details",
                           Vector4{0.0f, 0.0f, 64.0f, 64.0f});
  globalShaderUniforms.set("3d_skew_holo", "image_details",
                           Vector2{65.15f, 64.0f});
  globalShaderUniforms.set("3d_skew_holo", "dissolve", 0.0f);
  globalShaderUniforms.set("3d_skew_holo", "shadow", 0.0f);
  globalShaderUniforms.set("3d_skew_holo", "burn_colour_1",
                           Vector4{0.0f, 0.0f, 0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_holo", "burn_colour_2",
                           Vector4{0.0f, 0.0f, 0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_holo", "card_rotation", 0.0f);
  globalShaderUniforms.set("3d_skew_holo", "material_tint",
                           Vector3{1.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_holo", "grain_intensity", -1.95f);
  globalShaderUniforms.set("3d_skew_holo", "grain_scale", -2.21f);
  globalShaderUniforms.set("3d_skew_holo", "sheen_strength", -1.49f);
  globalShaderUniforms.set("3d_skew_holo", "sheen_width", 2.22f);
  globalShaderUniforms.set("3d_skew_holo", "sheen_speed", 2.3f);
  globalShaderUniforms.set("3d_skew_holo", "noise_amount", 1.12f);
  globalShaderUniforms.set("3d_skew_holo", "spread_strength", 1.0f);
  globalShaderUniforms.set("3d_skew_holo", "distortion_strength", 0.05f);
  globalShaderUniforms.set("3d_skew_holo", "fade_start", 0.7f);
  globalShaderUniforms.set("3d_skew_holo", "holo",
                           Vector2{0.65f, 0.25f});

  // pseudo 3d skew voucher
  shaders::registerUniformUpdate("3d_skew_voucher", [](Shader &shader) {
    globalShaderUniforms.set("3d_skew_voucher", "iTime",
                             static_cast<float>(main_loop::getTime()));
    globalShaderUniforms.set("3d_skew_voucher", "time",
                             static_cast<float>(main_loop::getTime()));
    globalShaderUniforms.set("3d_skew_voucher", "mouse_screen_pos",
                             getScaledMousePositionCached());
    globalShaderUniforms.set(
        "3d_skew_voucher", "resolution",
        Vector2{static_cast<float>(globals::VIRTUAL_WIDTH),
                static_cast<float>(globals::VIRTUAL_HEIGHT)});
    globalShaderUniforms.set("3d_skew_voucher", "spread_strength", 1.0f);
    globalShaderUniforms.set("3d_skew_voucher", "distortion_strength", 0.05f);
    globalShaderUniforms.set("3d_skew_voucher", "fade_start", 0.7f);
  });
  globalShaderUniforms.set("3d_skew_voucher", "fov", -0.39f);
  globalShaderUniforms.set("3d_skew_voucher", "x_rot", 0.0f);
  globalShaderUniforms.set("3d_skew_voucher", "y_rot", 0.0f);
  globalShaderUniforms.set("3d_skew_voucher", "inset", 0.0f);
  globalShaderUniforms.set("3d_skew_voucher", "hovering", 0.3f);
  globalShaderUniforms.set("3d_skew_voucher", "rand_trans_power", 0.4f);
  globalShaderUniforms.set("3d_skew_voucher", "rand_seed", 3.1415f);
  globalShaderUniforms.set("3d_skew_voucher", "rotation", 0.0f);
  globalShaderUniforms.set("3d_skew_voucher", "cull_back", 0.0f);
  globalShaderUniforms.set("3d_skew_voucher", "tilt_enabled", 0.0f);
  float voucherDrawWidth = static_cast<float>(globals::VIRTUAL_WIDTH);
  float voucherDrawHeight = static_cast<float>(globals::VIRTUAL_HEIGHT);
  globalShaderUniforms.set("3d_skew_voucher", "regionRate",
                           Vector2{voucherDrawWidth / voucherDrawWidth,
                                   voucherDrawHeight / voucherDrawHeight});
  globalShaderUniforms.set("3d_skew_voucher", "pivot",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_voucher", "quad_center",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_voucher", "quad_size",
                           Vector2{1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_voucher", "uv_passthrough", 0.0f);
  globalShaderUniforms.set("3d_skew_voucher", "uGridRect",
                           Vector4{0.0f, 0.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_voucher", "uImageSize",
                           Vector2{voucherDrawWidth, voucherDrawHeight});
  globalShaderUniforms.set("3d_skew_voucher", "texture_details",
                           Vector4{0.0f, 0.0f, 64.0f, 64.0f});
  globalShaderUniforms.set("3d_skew_voucher", "image_details",
                           Vector2{65.15f, 64.0f});
  globalShaderUniforms.set("3d_skew_voucher", "dissolve", 0.0f);
  globalShaderUniforms.set("3d_skew_voucher", "shadow", 0.0f);
  globalShaderUniforms.set("3d_skew_voucher", "burn_colour_1",
                           Vector4{0.0f, 0.0f, 0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_voucher", "burn_colour_2",
                           Vector4{0.0f, 0.0f, 0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_voucher", "card_rotation", 0.0f);
  globalShaderUniforms.set("3d_skew_voucher", "material_tint",
                           Vector3{1.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_voucher", "grain_intensity", -1.95f);
  globalShaderUniforms.set("3d_skew_voucher", "grain_scale", -2.21f);
  globalShaderUniforms.set("3d_skew_voucher", "sheen_strength", -1.49f);
  globalShaderUniforms.set("3d_skew_voucher", "sheen_width", 2.22f);
  globalShaderUniforms.set("3d_skew_voucher", "sheen_speed", 2.3f);
  globalShaderUniforms.set("3d_skew_voucher", "noise_amount", 1.12f);
  globalShaderUniforms.set("3d_skew_voucher", "spread_strength", 1.0f);
  globalShaderUniforms.set("3d_skew_voucher", "distortion_strength", 0.05f);
  globalShaderUniforms.set("3d_skew_voucher", "fade_start", 0.7f);
  globalShaderUniforms.set("3d_skew_voucher", "booster",
                           Vector2{0.65f, 0.25f});

  // pseudo 3d skew gold seal
  shaders::registerUniformUpdate("3d_skew_gold_seal", [](Shader &shader) {
    globalShaderUniforms.set("3d_skew_gold_seal", "iTime",
                             static_cast<float>(main_loop::getTime()));
    globalShaderUniforms.set("3d_skew_gold_seal", "time",
                             static_cast<float>(main_loop::getTime()));
    globalShaderUniforms.set("3d_skew_gold_seal", "mouse_screen_pos",
                             getScaledMousePositionCached());
    globalShaderUniforms.set(
        "3d_skew_gold_seal", "resolution",
        Vector2{static_cast<float>(globals::VIRTUAL_WIDTH),
                static_cast<float>(globals::VIRTUAL_HEIGHT)});
    globalShaderUniforms.set("3d_skew_gold_seal", "spread_strength", 1.0f);
    globalShaderUniforms.set("3d_skew_gold_seal", "distortion_strength", 0.05f);
    globalShaderUniforms.set("3d_skew_gold_seal", "fade_start", 0.7f);
  });
  globalShaderUniforms.set("3d_skew_gold_seal", "fov", -0.39f);
  globalShaderUniforms.set("3d_skew_gold_seal", "x_rot", 0.0f);
  globalShaderUniforms.set("3d_skew_gold_seal", "y_rot", 0.0f);
  globalShaderUniforms.set("3d_skew_gold_seal", "inset", 0.0f);
  globalShaderUniforms.set("3d_skew_gold_seal", "hovering", 0.3f);
  globalShaderUniforms.set("3d_skew_gold_seal", "rand_trans_power", 0.4f);
  globalShaderUniforms.set("3d_skew_gold_seal", "rand_seed", 3.1415f);
  globalShaderUniforms.set("3d_skew_gold_seal", "rotation", 0.0f);
  globalShaderUniforms.set("3d_skew_gold_seal", "cull_back", 0.0f);
  globalShaderUniforms.set("3d_skew_gold_seal", "tilt_enabled", 0.0f);
  float goldDrawWidth = static_cast<float>(globals::VIRTUAL_WIDTH);
  float goldDrawHeight = static_cast<float>(globals::VIRTUAL_HEIGHT);
  globalShaderUniforms.set("3d_skew_gold_seal", "regionRate",
                           Vector2{goldDrawWidth / goldDrawWidth,
                                   goldDrawHeight / goldDrawHeight});
  globalShaderUniforms.set("3d_skew_gold_seal", "pivot",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_gold_seal", "quad_center",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_gold_seal", "quad_size",
                           Vector2{1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_gold_seal", "uv_passthrough", 0.0f);
  globalShaderUniforms.set("3d_skew_gold_seal", "uGridRect",
                           Vector4{0.0f, 0.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_gold_seal", "uImageSize",
                           Vector2{goldDrawWidth, goldDrawHeight});
  globalShaderUniforms.set("3d_skew_gold_seal", "texture_details",
                           Vector4{0.0f, 0.0f, 64.0f, 64.0f});
  globalShaderUniforms.set("3d_skew_gold_seal", "image_details",
                           Vector2{65.15f, 64.0f});
  globalShaderUniforms.set("3d_skew_gold_seal", "dissolve", 0.0f);
  globalShaderUniforms.set("3d_skew_gold_seal", "shadow", 0.0f);
  globalShaderUniforms.set("3d_skew_gold_seal", "burn_colour_1",
                           Vector4{0.0f, 0.0f, 0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_gold_seal", "burn_colour_2",
                           Vector4{0.0f, 0.0f, 0.0f, 0.0f});
  globalShaderUniforms.set("3d_skew_gold_seal", "card_rotation", 0.0f);
  globalShaderUniforms.set("3d_skew_gold_seal", "material_tint",
                           Vector3{1.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("3d_skew_gold_seal", "grain_intensity", -1.95f);
  globalShaderUniforms.set("3d_skew_gold_seal", "grain_scale", -2.21f);
  globalShaderUniforms.set("3d_skew_gold_seal", "sheen_strength", -1.49f);
  globalShaderUniforms.set("3d_skew_gold_seal", "sheen_width", 2.22f);
  globalShaderUniforms.set("3d_skew_gold_seal", "sheen_speed", 2.3f);
  globalShaderUniforms.set("3d_skew_gold_seal", "noise_amount", 1.12f);
  globalShaderUniforms.set("3d_skew_gold_seal", "spread_strength", 1.0f);
  globalShaderUniforms.set("3d_skew_gold_seal", "distortion_strength", 0.05f);
  globalShaderUniforms.set("3d_skew_gold_seal", "fade_start", 0.7f);
  globalShaderUniforms.set("3d_skew_gold_seal", "gold_seal",
                           Vector4{0.65f, 0.25f, 0.0f, 1.0f});

  // Additional pseudo-3D skew variants share the same baseline uniforms.
  auto registerPseudo3DSkewVariant =
      [&](const std::string& shaderName, const std::string& effectUniform) {
        const std::string shaderKey = shaderName;
        shaders::registerUniformUpdate(shaderKey, [shaderKey](Shader& shader) {
          globalShaderUniforms.set(
              shaderKey, "iTime", static_cast<float>(main_loop::getTime()));
          globalShaderUniforms.set(
              shaderKey, "time", static_cast<float>(main_loop::getTime()));
          globalShaderUniforms.set(shaderKey, "mouse_screen_pos",
                                   getScaledMousePositionCached());
          globalShaderUniforms.set(
              shaderKey, "resolution",
              Vector2{static_cast<float>(globals::VIRTUAL_WIDTH),
                      static_cast<float>(globals::VIRTUAL_HEIGHT)});
          globalShaderUniforms.set(shaderKey, "spread_strength", 1.0f);
          globalShaderUniforms.set(shaderKey, "distortion_strength", 0.05f);
          globalShaderUniforms.set(shaderKey, "fade_start", 0.7f);
        });

        globalShaderUniforms.set(shaderKey, "fov", -0.39f);
        globalShaderUniforms.set(shaderKey, "x_rot", 0.0f);
        globalShaderUniforms.set(shaderKey, "y_rot", 0.0f);
        globalShaderUniforms.set(shaderKey, "inset", 0.0f);
        globalShaderUniforms.set(shaderKey, "hovering", 0.3f);
        globalShaderUniforms.set(shaderKey, "rand_trans_power", 0.4f);
        globalShaderUniforms.set(shaderKey, "rand_seed", 3.1415f);
        globalShaderUniforms.set(shaderKey, "rotation", 0.0f);
        globalShaderUniforms.set(shaderKey, "cull_back", 0.0f);
        globalShaderUniforms.set(shaderKey, "tilt_enabled", 0.0f);

        float drawWidth = static_cast<float>(globals::VIRTUAL_WIDTH);
        float drawHeight = static_cast<float>(globals::VIRTUAL_HEIGHT);
        globalShaderUniforms.set(shaderKey, "regionRate",
                                 Vector2{drawWidth / drawWidth,
                                         drawHeight / drawHeight});
        globalShaderUniforms.set(shaderKey, "pivot", Vector2{0.0f, 0.0f});
        globalShaderUniforms.set(shaderKey, "quad_center",
                                 Vector2{0.0f, 0.0f});
        globalShaderUniforms.set(shaderKey, "quad_size",
                                 Vector2{1.0f, 1.0f});
        globalShaderUniforms.set(shaderKey, "uv_passthrough", 0.0f);
        globalShaderUniforms.set(shaderKey, "uGridRect",
                                 Vector4{0.0f, 0.0f, 1.0f, 1.0f});
        globalShaderUniforms.set(shaderKey, "uImageSize",
                                 Vector2{drawWidth, drawHeight});
        globalShaderUniforms.set(shaderKey, "texture_details",
                                 Vector4{0.0f, 0.0f, 64.0f, 64.0f});
        globalShaderUniforms.set(shaderKey, "image_details",
                                 Vector2{65.15f, 64.0f});
        globalShaderUniforms.set(shaderKey, "dissolve", 0.0f);
        globalShaderUniforms.set(shaderKey, "shadow", 0.0f);
        globalShaderUniforms.set(shaderKey, "burn_colour_1",
                                 Vector4{0.0f, 0.0f, 0.0f, 0.0f});
        globalShaderUniforms.set(shaderKey, "burn_colour_2",
                                 Vector4{0.0f, 0.0f, 0.0f, 0.0f});
        globalShaderUniforms.set(shaderKey, "card_rotation", 0.0f);
        globalShaderUniforms.set(shaderKey, "material_tint",
                                 Vector3{1.0f, 1.0f, 1.0f});
        globalShaderUniforms.set(shaderKey, "grain_intensity", -1.95f);
        globalShaderUniforms.set(shaderKey, "grain_scale", -2.21f);
        globalShaderUniforms.set(shaderKey, "sheen_strength", -1.49f);
        globalShaderUniforms.set(shaderKey, "sheen_width", 2.22f);
        globalShaderUniforms.set(shaderKey, "sheen_speed", 2.3f);
        globalShaderUniforms.set(shaderKey, "noise_amount", 1.12f);
        globalShaderUniforms.set(shaderKey, "spread_strength", 1.0f);
        globalShaderUniforms.set(shaderKey, "distortion_strength", 0.05f);
        globalShaderUniforms.set(shaderKey, "fade_start", 0.7f);
        globalShaderUniforms.set(shaderKey, effectUniform,
                                 Vector2{0.65f, 0.25f});
      };

  registerPseudo3DSkewVariant("3d_skew_aurora", "aurora");
  registerPseudo3DSkewVariant("3d_skew_iridescent", "iridescent");
  registerPseudo3DSkewVariant("3d_skew_nebula", "nebula");
  registerPseudo3DSkewVariant("3d_skew_plasma", "plasma");
  registerPseudo3DSkewVariant("3d_skew_prismatic", "prismatic");
  registerPseudo3DSkewVariant("3d_skew_thermal", "thermal");
  registerPseudo3DSkewVariant("3d_skew_crystalline", "crystalline");
  registerPseudo3DSkewVariant("3d_skew_glitch", "glitch");
  registerPseudo3DSkewVariant("3d_skew_negative_tint", "negative_tint");
  registerPseudo3DSkewVariant("3d_skew_oil_slick", "oil_slick");
  registerPseudo3DSkewVariant("3d_skew_polka_dot", "polka_dot");
  // squish
  globalShaderUniforms.set("squish", "up_left", Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("squish", "up_right", Vector2{1.0f, 0.0f});
  globalShaderUniforms.set("squish", "down_right", Vector2{1.0f, 1.0f});
  globalShaderUniforms.set("squish", "down_left", Vector2{0.0f, 1.0f});
  globalShaderUniforms.set(
      "squish", "plane_size",
      Vector2{(float)globals::VIRTUAL_WIDTH, (float)globals::VIRTUAL_HEIGHT});
  shaders::registerUniformUpdate("squish", [](Shader &shader) {
    // occilate x and y
    globalShaderUniforms.set("squish", "squish_x",
                             (float)sin(main_loop::getTime() * 0.5f) * 0.1f);
    globalShaderUniforms.set("squish", "squish_Y",
                             (float)cos(main_loop::getTime() * 0.2f) * 0.1f);
  });

  // peaches background
  std::vector<Color> myPalette = {WHITE, BLUE, GREEN, RED, YELLOW, PURPLE};

  globalShaderUniforms.set(
      "peaches_background", "resolution",
      Vector2{(float)globals::VIRTUAL_WIDTH, (float)globals::VIRTUAL_HEIGHT});
  shaders::registerUniformUpdate("peaches_background", [](Shader &shader) {
    globalShaderUniforms.set("peaches_background", "iTime",
                             (float)main_loop::getTime() * 0.2f);
  });
  globalShaderUniforms.set(
      "peaches_background", "resolution",
      Vector2{(float)globals::VIRTUAL_WIDTH, (float)globals::VIRTUAL_HEIGHT});

  // === Peaches Background Shader Uniforms ===
  globalShaderUniforms.set(
      "peaches_background", "iTime",
      static_cast<float>(main_loop::getTime())); // Real-time updated
  globalShaderUniforms.set("peaches_background", "resolution",
                           Vector2{1440.0f, 900.0f}); // Your screen size

  // === Blob Settings ===
  globalShaderUniforms.set("peaches_background", "blob_count", 5.02f);
  globalShaderUniforms.set("peaches_background", "blob_spacing", -0.89f);
  globalShaderUniforms.set("peaches_background", "shape_amplitude", 0.205f);

  // === Visual Distortion and Intensity ===
  globalShaderUniforms.set("peaches_background", "distortion_strength", 4.12f);
  globalShaderUniforms.set("peaches_background", "noise_strength", 0.14f);
  globalShaderUniforms.set("peaches_background", "radial_falloff", -0.03f);
  globalShaderUniforms.set("peaches_background", "wave_strength", 1.55f);
  globalShaderUniforms.set("peaches_background", "highlight_gain", 3.8f);
  globalShaderUniforms.set("peaches_background", "cl_shift", 0.1f);

  // === Edge Softness ===
  globalShaderUniforms.set("peaches_background", "edge_softness_min", 0.32f);
  globalShaderUniforms.set("peaches_background", "edge_softness_max", 0.68f);

  // === Color Configuration ===
  globalShaderUniforms.set("peaches_background", "colorTint",
                           Vector3{0.33f, 0.57f, 0.31f});
  globalShaderUniforms.set("peaches_background", "blob_color_blend", 0.69f);
  globalShaderUniforms.set("peaches_background", "hue_shift", 0.8f);

  globalShaderUniforms.set("peaches_background", "pixel_size",
                           6.0f); // Bigger = chunkier pixels
  globalShaderUniforms.set("peaches_background", "pixel_enable",
                           1.0f); // Turn on
  globalShaderUniforms.set("peaches_background", "blob_offset",
                           Vector2{0.0f, -0.1f}); // Moves all blobs upward
  globalShaderUniforms.set("peaches_background", "movement_randomness",
                           16.2f); // Tweak live

  // === Fireworks Background Shader ===
  globalShaderUniforms.set("fireworks_background", "resolution",
                           Vector2{(float)globals::VIRTUAL_WIDTH, (float)globals::VIRTUAL_HEIGHT});
  shaders::registerUniformUpdate("fireworks_background", [](Shader &shader) {
    globalShaderUniforms.set("fireworks_background", "iTime",
                             (float)main_loop::getTime());
  });

  // Particle settings
  globalShaderUniforms.set("fireworks_background", "num_particles", 75);
  globalShaderUniforms.set("fireworks_background", "num_fireworks", 5);
  globalShaderUniforms.set("fireworks_background", "time_scale", 1.0f);
  globalShaderUniforms.set("fireworks_background", "gravity_strength", 0.1f);
  globalShaderUniforms.set("fireworks_background", "brightness", 1.0f);
  globalShaderUniforms.set("fireworks_background", "particle_size", 50.0f);
  globalShaderUniforms.set("fireworks_background", "spread", 1.5f);
  globalShaderUniforms.set("fireworks_background", "color_power", 1.25f);

  // Flag effect (disabled by default)
  globalShaderUniforms.set("fireworks_background", "flag_enable", 0.0f);
  globalShaderUniforms.set("fireworks_background", "flag_color_top",
                           Vector3{1.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("fireworks_background", "flag_color_bottom",
                           Vector3{1.0f, 0.0f, 0.0f});
  globalShaderUniforms.set("fireworks_background", "flag_wave_speed", 1.0f);
  globalShaderUniforms.set("fireworks_background", "flag_wave_amp", 0.1f);
  globalShaderUniforms.set("fireworks_background", "flag_brightness", 0.15f);

  // fade_zoom transition
  globalShaderUniforms.set("fade_zoom", "progress",
                           0.0f); // Animate from 0 to 1
  globalShaderUniforms.set("fade_zoom", "zoom_strength", 0.2f); // Optional zoom
  globalShaderUniforms.set("fade_zoom", "fade_color",
                           Vector3{0.0f, 0.0f, 0.0f}); // black

  // slide_fade transition
  globalShaderUniforms.set("fade", "progress", 0.0f); // Animate from 0.0 to 1.0
  globalShaderUniforms.set("fade", "slide_direction",
                           Vector2{1.0f, 0.0f}); // Slide to the right
  globalShaderUniforms.set("fade", "fade_color",
                           Vector3{0.0f, 0.0f, 0.0f}); // Fade through black

  // foil
  // Time-related
  globalShaderUniforms.set("foil", "time",
                           (float)main_loop::getTime()); // or animated time
  // Dissolve factor (0.0 to 1.0)
  globalShaderUniforms.set("foil", "dissolve",
                           0.0f); // animate this for dissolve effect
  // Foil animation vector (e.g. shimmer intensity/direction)
  globalShaderUniforms.set("foil", "foil",
                           Vector2{1.0f, 1.0f}); // tweak for animation patterns
  // Texture region and layout
  globalShaderUniforms.set(
      "foil", "texture_details",
      Vector4{0.0f, 0.0f, 128.0f, 128.0f}); // x,y offset + width,height
  globalShaderUniforms.set("foil", "image_details",
                           Vector2{128.0f, 128.0f}); // full image dimensions
  // Color burn blend colors (used during dissolve)
  globalShaderUniforms.set("foil", "burn_colour_1",
                           Vector4{1.0f, 0.3f, 0.0f, 1.0f}); // hot orange
  globalShaderUniforms.set("foil", "burn_colour_2",
                           Vector4{1.0f, 1.0f, 0.2f, 1.0f}); // yellow glow
  // Shadow mode (if true, output darkened tones)
  globalShaderUniforms.set("foil", "shadow", 0.0f);

  // Time and dissolve progression
  globalShaderUniforms.set("holo", "time",
                           0.0f); // Should be updated every frame
  globalShaderUniforms.set("holo", "dissolve",
                           0.0f); // 0.0 (off) to 1.0 (full dissolve)

  // Texture layout
  globalShaderUniforms.set(
      "holo", "texture_details",
      Vector4{0.0f, 0.0f, 64.0f,
              64.0f}); // offsetX, offsetY, texWidth, texHeight
  globalShaderUniforms.set("holo", "image_details",
                           Vector2{64.0f, 64.0f}); // actual size in pixels

  // Shine and interference control
  globalShaderUniforms.set(
      "holo", "holo",
      Vector2{1.2f, 0.8f}); // x = shine intensity, y = interference scroll

  // Colors
  globalShaderUniforms.set("holo", "burn_colour_1",
                           ColorNormalize(BLUE)); // Edge glow color A
  globalShaderUniforms.set("holo", "burn_colour_2",
                           ColorNormalize(PURPLE)); // Edge glow color B
  globalShaderUniforms.set("holo", "shadow",
                           0.0f); // Set true to enable shadow pass

  // Mouse hover distortion
  globalShaderUniforms.set("holo", "mouse_screen_pos",
                           Vector2{0.0f, 0.0f});      // In screen pixels
  globalShaderUniforms.set("holo", "hovering", 0.0f); // 0.0 = off, 1.0 = on
  globalShaderUniforms.set("holo", "screen_scale",
                           1.0f); // Scale of UI in pixels

  // Time update
  shaders::registerUniformUpdate("holo", [](Shader &shader) {
    globalShaderUniforms.set("holo", "time", (float)main_loop::getTime());
  });

  // Texture details
  globalShaderUniforms.set(
      "polychrome", "texture_details",
      Vector4{0.0f, 0.0f, 64.0f,
              64.0f}); // offsetX, offsetY, texWidth, texHeight
  globalShaderUniforms.set("polychrome", "image_details",
                           Vector2{64.0f, 64.0f}); // actual size in pixels

  // Animation + effect tuning
  globalShaderUniforms.set("polychrome", "time", (float)main_loop::getTime());
  globalShaderUniforms.set("polychrome", "dissolve", 0.0f); // 0.0 to 1.0
  globalShaderUniforms.set(
      "polychrome", "polychrome",
      Vector2{0.1, 0.1}); // tweak for effect, hue_modulation, animation speed

  // Visual options
  globalShaderUniforms.set("polychrome", "shadow", 0.0f);
  globalShaderUniforms.set("polychrome", "burn_colour_1",
                           Vector4{1.0f, 1.0f, 0, 1.0f}); // glowing edge
  globalShaderUniforms.set(
      "polychrome", "burn_colour_2",
      Vector4{1.0f, 1.0f, 1.0f, 1.0f}); // highlight outer burn

  globalShaderUniforms.set(
      "negative_shine", "texture_details",
      Vector4{0.0f, 0.0f, 64.0f,
              64.0f}); // offsetX, offsetY, texWidth, texHeight
  globalShaderUniforms.set("negative_shine", "image_details",
                           Vector2{64.0f, 64.0f}); // actual size in pixels

  // Shine animation control
  globalShaderUniforms.set(
      "negative_shine", "negative_shine",
      Vector2{1.0f, 1.0f}); // x = phase offset, y = amplitude

  // Burn edge colors
  globalShaderUniforms.set("negative_shine", "burn_colour_1",
                           ColorNormalize(SKYBLUE)); // Primary edge highlight
  globalShaderUniforms.set("negative_shine", "burn_colour_2",
                           ColorNormalize(PINK)); // Secondary edge highlight
  globalShaderUniforms.set("negative_shine", "shadow",
                           0.0f); // 0.0 = normal, 1.0 = shadow mode

  // Mouse interaction (if used in vertex distortion)
  globalShaderUniforms.set("negative_shine", "mouse_screen_pos",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("negative_shine", "hovering", 0.0f);
  globalShaderUniforms.set("negative_shine", "screen_scale", 1.0f);

  // Time uniform updater
  shaders::registerUniformUpdate("negative_shine", [](Shader &shader) {
    globalShaderUniforms.set("negative_shine", "time",
                             (float)main_loop::getTime());
  });

  // Texture layout details
  globalShaderUniforms.set(
      "negative", "texture_details",
      Vector4{0.0f, 0.0f, 64.0f,
              64.0f}); // offsetX, offsetY, texWidth, texHeight
  globalShaderUniforms.set("negative", "image_details",
                           Vector2{64.0f, 64.0f}); // actual size in pixels

  // Negative effect control
  globalShaderUniforms.set(
      "negative", "negative",
      Vector2{1.0f, 1.0f}); // x = hue inversion offset, y = brightness
                            // inversion toggle (non-zero enables)

  // Dissolve and timing
  globalShaderUniforms.set("negative", "dissolve",
                           0.0f); // 0.0 = off, 1.0 = fully dissolved
  shaders::registerUniformUpdate("negative", [](Shader &shader) {
    globalShaderUniforms.set("negative", "time", (float)main_loop::getTime());
  });

  // Edge burn colors
  globalShaderUniforms.set("negative", "burn_colour_1",
                           ColorNormalize(RED)); // Primary burn color
  globalShaderUniforms.set("negative", "burn_colour_2",
                           ColorNormalize(ORANGE)); // Secondary burn color
  globalShaderUniforms.set("negative", "shadow",
                           0.0f); // 1.0 = enable black mask shadow mode

  // UI hover distortion (optional)
  globalShaderUniforms.set("negative", "mouse_screen_pos", Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("negative", "hovering",
                           0.0f); // 0.0 = no hover effect, 1.0 = active
  globalShaderUniforms.set("negative", "screen_scale", 1.0f); // UI scale factor

  // spectrum rect
  globalShaderUniforms.set(
      "spectrum_circle", "iResolution",
      Vector2{static_cast<float>(globals::VIRTUAL_WIDTH),
              static_cast<float>(globals::VIRTUAL_HEIGHT)});

  shaders::registerUniformUpdate("spectrum_circle", [](Shader &shader) {
    globalShaderUniforms.set("spectrum_circle", "iTime",
                             static_cast<float>(main_loop::getTime()));
  });
  globalShaderUniforms.set("spectrum_circle", "uCenter",
                           Vector2{200, 150}); // relative to uRectPos
  globalShaderUniforms.set("spectrum_circle", "uRadius", 30.0f);

  // spectrum line
  shaders::registerUniformUpdate(
      "spectrum_line_background", [](Shader &shader) {
        globalShaderUniforms.set("spectrum_line_background", "iTime",
                                 static_cast<float>(main_loop::getTime()));
        globalShaderUniforms.set(
            "spectrum_line_background", "iResolution",
            Vector2{static_cast<float>(globals::VIRTUAL_WIDTH),
                    static_cast<float>(globals::VIRTUAL_HEIGHT)});
      });

  // One-time configuration (or updated as needed)
  globalShaderUniforms.set("spectrum_line_background", "uLineSpacing",
                           100.0f); // spacing between scanlines
  globalShaderUniforms.set("spectrum_line_background", "uLineWidth",
                           0.75f); // thickness of each scanline
  globalShaderUniforms.set("spectrum_line_background", "uBeamHeight",
                           30.0f); // vertical beam thickness
  globalShaderUniforms.set("spectrum_line_background", "uBeamIntensity",
                           1.0f); // how strong the beam glows
  globalShaderUniforms.set(
      "spectrum_line_background", "uOpacity",
      1.0f); // overlay strength (0 = invisible, 1 = full effect)

  globalShaderUniforms.set("spectrum_line_background", "uBeamY",
                           200.0f); // vertical position in pixels
  globalShaderUniforms.set("spectrum_line_background", "uBeamWidth",
                           400.0f); // horizontal length in pixels
  globalShaderUniforms.set("spectrum_line_background", "uBeamX", 400.0f); //

  globalShaderUniforms.set("voucher_sheen", "booster", Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("voucher_sheen", "dissolve", 0.0f);
  globalShaderUniforms.set("voucher_sheen", "time", 0.0f);
  globalShaderUniforms.set(
      "voucher_sheen", "texture_details",
      Vector4{0.0f, 0.0f, 64.0f, 64.0f}); // .xy = offset, .zw = scale
  globalShaderUniforms.set("voucher_sheen", "image_details",
                           Vector2{64.0f, 64.0f}); // set to your texture size
  globalShaderUniforms.set("voucher_sheen", "shadow", false);
  globalShaderUniforms.set("voucher_sheen", "burn_colour_1",
                           ColorNormalize(BLUE));
  globalShaderUniforms.set("voucher_sheen", "burn_colour_2",
                           ColorNormalize(PURPLE));

  // Optional live updates
  shaders::registerUniformUpdate("voucher_sheen", [](Shader &shader) {
    globalShaderUniforms.set("voucher_sheen", "time",
                             static_cast<float>(main_loop::getTime()));
  });

  // discrete_clouds
  shaders::registerUniformUpdate("discrete_clouds", [](Shader &shader) {
    globalShaderUniforms.set("discrete_clouds", "time",
                             static_cast<float>(main_loop::getTime()));
  });
  globalShaderUniforms.set("discrete_clouds", "bottom_color",
                           Vector4{1.0f, 1.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("discrete_clouds", "top_color",
                           Vector4{0.0f, 0.0f, 0.0f, 1.0f});
  globalShaderUniforms.set("discrete_clouds", "layer_count", 20);
  globalShaderUniforms.set("discrete_clouds", "time_scale", 0.2f);
  globalShaderUniforms.set("discrete_clouds", "base_intensity", 0.5f);
  globalShaderUniforms.set("discrete_clouds", "size", 0.1f);

  // bounding_battle_bg
  shaders::registerUniformUpdate("bounding_battle_bg", [](Shader &shader) {
    globalShaderUniforms.set("bounding_battle_bg", "time",
                             static_cast<float>(main_loop::getTime()));
  });
  globalShaderUniforms.set("bounding_battle_bg", "snes_transparency", false);
  globalShaderUniforms.set("bounding_battle_bg", "gba_transparency", false);
  globalShaderUniforms.set("bounding_battle_bg", "horizontal_scan_line", false);
  globalShaderUniforms.set("bounding_battle_bg", "vertical_scan_line", false);
  globalShaderUniforms.set("bounding_battle_bg", "enable_palette_cycling",
                           false);
  globalShaderUniforms.set("bounding_battle_bg", "sprite_scroll_direction",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("bounding_battle_bg", "sprite_scroll_speed", 0.01f);
  globalShaderUniforms.set("bounding_battle_bg",
                           "gba_transparency_scroll_direction",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("bounding_battle_bg",
                           "gba_transparency_scroll_speed", 0.01f);
  globalShaderUniforms.set("bounding_battle_bg", "gba_transparency_value",
                           0.5f);
  globalShaderUniforms.set("bounding_battle_bg", "horizontal_wave_amplitude",
                           0.0f);
  globalShaderUniforms.set("bounding_battle_bg", "horizontal_wave_frequency",
                           0.0f);
  globalShaderUniforms.set("bounding_battle_bg", "horizontal_wave_speed", 1.0f);
  globalShaderUniforms.set("bounding_battle_bg", "vertical_wave_amplitude",
                           0.0f);
  globalShaderUniforms.set("bounding_battle_bg", "vertical_wave_frequency",
                           0.0f);
  globalShaderUniforms.set("bounding_battle_bg", "vertical_wave_speed", 1.0f);
  globalShaderUniforms.set("bounding_battle_bg", "horizontal_deform_amplitude",
                           0.0f);
  globalShaderUniforms.set("bounding_battle_bg", "horizontal_deform_frequency",
                           0.0f);
  globalShaderUniforms.set("bounding_battle_bg", "horizontal_deform_speed",
                           1.0f);
  globalShaderUniforms.set("bounding_battle_bg", "vertical_deform_amplitude",
                           0.0f);
  globalShaderUniforms.set("bounding_battle_bg", "vertical_deform_frequency",
                           0.0f);
  globalShaderUniforms.set("bounding_battle_bg", "vertical_deform_speed", 1.0f);
  globalShaderUniforms.set("bounding_battle_bg", "width", 640.0f);
  globalShaderUniforms.set("bounding_battle_bg", "height", 480.0f);
  globalShaderUniforms.set("bounding_battle_bg", "palette_cycling_speed", 0.1f);

  // wobbly
  shaders::registerUniformUpdate("wobbly", [](Shader &shader) {
    globalShaderUniforms.set("wobbly", "time",
                             static_cast<float>(main_loop::getTime()));
  });
  globalShaderUniforms.set("wobbly", "alpha_tresh", 0.8f);
  globalShaderUniforms.set("wobbly", "shrink", 2.0f);
  globalShaderUniforms.set("wobbly", "offset_mul", 2.0f);
  globalShaderUniforms.set("wobbly", "coff_angle", 0.0f);
  globalShaderUniforms.set("wobbly", "coff_mul", 0.5f);
  globalShaderUniforms.set("wobbly", "coff_std", 0.2f);
  globalShaderUniforms.set("wobbly", "amp1", 0.125f);
  globalShaderUniforms.set("wobbly", "freq1", 4.0f);
  globalShaderUniforms.set("wobbly", "speed1", 5.0f);
  globalShaderUniforms.set("wobbly", "amp2", 0.125f);
  globalShaderUniforms.set("wobbly", "freq2", 9.0f);
  globalShaderUniforms.set("wobbly", "speed2", 1.46f);

  // bounce_wave
  shaders::registerUniformUpdate("bounce_wave", [](Shader &shader) {
    globalShaderUniforms.set("bounce_wave", "time",
                             static_cast<float>(main_loop::getTime()));
  });
  globalShaderUniforms.set("bounce_wave", "amplitude", 0.05f);
  globalShaderUniforms.set("bounce_wave", "frequency", 10.0f);
  globalShaderUniforms.set("bounce_wave", "speed", 2.0f);
  globalShaderUniforms.set("bounce_wave", "quantization", 8.0f);

  // infinite_scrolling_texture
  shaders::registerUniformUpdate(
      "infinite_scrolling_texture", [](Shader &shader) {
        globalShaderUniforms.set("infinite_scrolling_texture", "time",
                                 static_cast<float>(main_loop::getTime()));
      });
  globalShaderUniforms.set("infinite_scrolling_texture", "scroll_speed", 0.1f);
  globalShaderUniforms.set("infinite_scrolling_texture", "angle", 0.0f);
  globalShaderUniforms.set("infinite_scrolling_texture", "pixel_perfect", true);

  // rain_snow
  shaders::registerUniformUpdate("rain_snow", [](Shader &shader) {
    globalShaderUniforms.set("rain_snow", "time",
                             static_cast<float>(main_loop::getTime()));
  });
  globalShaderUniforms.set("rain_snow", "rain_amount", 500.0f);
  globalShaderUniforms.set("rain_snow", "near_rain_length", 0.3f);
  globalShaderUniforms.set("rain_snow", "far_rain_length", 0.1f);
  globalShaderUniforms.set("rain_snow", "near_rain_width", 0.5f);
  globalShaderUniforms.set("rain_snow", "far_rain_width", 0.3f);
  globalShaderUniforms.set("rain_snow", "near_rain_transparency", 1.0f);
  globalShaderUniforms.set("rain_snow", "far_rain_transparency", 0.5f);
  globalShaderUniforms.set("rain_snow", "rain_color",
                           Vector4{1.0f, 1.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("rain_snow", "base_rain_speed", 0.3f);
  globalShaderUniforms.set("rain_snow", "additional_rain_speed_range", 0.3f);

  // pixel_art_gradient
  globalShaderUniforms.set("pixel_art_gradient", "grid_size", 16.0f);
  globalShaderUniforms.set("pixel_art_gradient", "smooth_size", 8.0f);

  // extensible_color_palette
  globalShaderUniforms.set("extensible_color_palette", "u_size", 8);
  globalShaderUniforms.set("extensible_color_palette", "u_use_lerp", true);
  globalShaderUniforms.set("extensible_color_palette", "u_add_source_colors",
                           false);
  globalShaderUniforms.set("extensible_color_palette", "u_add_greyscale_colors",
                           false);

  // dissolve_burn
  shaders::registerUniformUpdate("dissolve_burn", [](Shader &shader) {
    globalShaderUniforms.set("dissolve_burn", "time",
                             static_cast<float>(main_loop::getTime()));
  });
  globalShaderUniforms.set("dissolve_burn", "burn_color",
                           Vector4{1.0f, 0.7f, 0.0f, 1.0f});
  globalShaderUniforms.set("dissolve_burn", "burn_size", 0.1f);
  globalShaderUniforms.set("dissolve_burn", "dissolve_amount", 0.0f);

  // hologram_2d
  shaders::registerUniformUpdate("hologram_2d", [](Shader &shader) {
    globalShaderUniforms.set("hologram_2d", "time",
                             static_cast<float>(main_loop::getTime()));
  });
  globalShaderUniforms.set("hologram_2d", "scan_line_amount", 1.0f);
  globalShaderUniforms.set("hologram_2d", "warp_amount", 0.1f);

  // wobbly_grid
  shaders::registerUniformUpdate("wobbly_grid", [](Shader &shader) {
    globalShaderUniforms.set("wobbly_grid", "time",
                             static_cast<float>(main_loop::getTime()));
  });
  globalShaderUniforms.set("wobbly_grid", "amplitude", 10.0f);
  globalShaderUniforms.set("wobbly_grid", "frequency", 5.0f);
  globalShaderUniforms.set("wobbly_grid", "speed", 2.0f);

  // radial_shine_2d
  shaders::registerUniformUpdate("radial_shine_2d", [](Shader &shader) {
    globalShaderUniforms.set("radial_shine_2d", "time",
                             static_cast<float>(main_loop::getTime()));
  });
  globalShaderUniforms.set("radial_shine_2d", "center", Vector2{0.5f, 0.5f});
  globalShaderUniforms.set("radial_shine_2d", "shine_speed", 1.0f);
  globalShaderUniforms.set("radial_shine_2d", "shine_width", 0.1f);
  globalShaderUniforms.set("radial_shine_2d", "shine_strength", 1.0f);

  // fireworks_2d
  shaders::registerUniformUpdate("fireworks_2d", [](Shader &shader) {
    globalShaderUniforms.set("fireworks_2d", "time",
                             static_cast<float>(main_loop::getTime()));
  });
  globalShaderUniforms.set("fireworks_2d", "particle_count", 100);
  globalShaderUniforms.set("fireworks_2d", "explosion_radius", 0.3f);

  // efficient_pixel_outlines
  globalShaderUniforms.set("efficient_pixel_outlines", "outline_color",
                           Vector4{1.0f, 1.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("efficient_pixel_outlines", "outline_thickness",
                           1.0f);
  globalShaderUniforms.set("efficient_pixel_outlines", "use_8_directions",
                           false);

  // pixel_perfect_dissolve
  shaders::registerUniformUpdate("pixel_perfect_dissolve", [](Shader &shader) {
    globalShaderUniforms.set("pixel_perfect_dissolve", "time",
                             static_cast<float>(main_loop::getTime()));
  });
  globalShaderUniforms.set("pixel_perfect_dissolve", "dissolve_amount", 0.0f);
  globalShaderUniforms.set("pixel_perfect_dissolve", "pixel_size", 1.0f);

  // random_displacement
  shaders::registerUniformUpdate("random_displacement", [](Shader &shader) {
    globalShaderUniforms.set("random_displacement", "time",
                             static_cast<float>(main_loop::getTime()));
  });
  globalShaderUniforms.set("random_displacement", "displacement_amount", 5.0f);
  globalShaderUniforms.set("random_displacement", "speed", 1.0f);

  // atlas_outline
  globalShaderUniforms.set("atlas_outline", "outline_color",
                           Vector4{1.0f, 1.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("atlas_outline", "outline_thickness", 1.0f);
  globalShaderUniforms.set("atlas_outline", "uGridRect",
                           Vector4{0.0f, 0.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("atlas_outline", "uImageSize",
                           Vector2{64.0f, 64.0f});
  // Screen shaders - drop_shadow
  globalShaderUniforms.set(
      "drop_shadow", "background_color",
      Vector4{0.0f, 0.0f, 0.0f, 0.0f}); // transparent background
  globalShaderUniforms.set(
      "drop_shadow", "shadow_color",
      Vector4{0.0f, 0.0f, 0.0f, 0.5f}); // semi-transparent black shadow
  globalShaderUniforms.set("drop_shadow", "offset_in_pixels",
                           Vector2{5.0f, 5.0f}); // shadow offset
  globalShaderUniforms.set(
      "drop_shadow", "screen_pixel_size",
      Vector2{1.0f / globals::VIRTUAL_WIDTH, 1.0f / globals::VIRTUAL_HEIGHT});

  // Screen shaders - chromatic_aberration
  globalShaderUniforms.set("chromatic_aberration", "r_displacement",
                           Vector2{3.0f, 0.0f});
  globalShaderUniforms.set("chromatic_aberration", "g_displacement",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("chromatic_aberration", "b_displacement",
                           Vector2{-3.0f, 0.0f});
  globalShaderUniforms.set("chromatic_aberration", "height", 0.7f);
  globalShaderUniforms.set("chromatic_aberration", "width", 0.5f);
  globalShaderUniforms.set("chromatic_aberration", "fade", 0.7f);
  globalShaderUniforms.set(
      "chromatic_aberration", "screen_pixel_size",
      Vector2{1.0f / globals::VIRTUAL_WIDTH, 1.0f / globals::VIRTUAL_HEIGHT});

  // Screen shaders - darkened_blur
  globalShaderUniforms.set("darkened_blur", "lod",
                           5.0f); // blur level (mipmap LOD)
  globalShaderUniforms.set(
      "darkened_blur", "mix_percentage",
      0.3f); // how much to darken (0.0 = no darkening, 1.0 = black)

  // Screen shaders - custom_2d_light
  globalShaderUniforms.set("custom_2d_light", "light_color",
                           Vector3{255.0f, 255.0f, 255.0f}); // white light
  globalShaderUniforms.set("custom_2d_light", "brightness", 0.5f);
  globalShaderUniforms.set("custom_2d_light", "attenuation_strength", 0.5f);
  globalShaderUniforms.set("custom_2d_light", "intensity", 1.0f);
  globalShaderUniforms.set("custom_2d_light", "max_brightness", 1.0f);

  // Screen shaders - palette_shader
  globalShaderUniforms.set("palette_shader", "palette_size",
                           16); // number of colors in palette

  // Screen shaders - perspective_warp
  globalShaderUniforms.set("perspective_warp", "topleft", Vector2{0.01f, 0.0f});
  globalShaderUniforms.set("perspective_warp", "topright", Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("perspective_warp", "bottomleft",
                           Vector2{0.0f, 0.0f});
  globalShaderUniforms.set("perspective_warp", "bottomright",
                           Vector2{0.0f, 0.0f});

  // Screen shaders - radial_shine_highlight
  globalShaderUniforms.set("radial_shine_highlight", "spread", 0.5f);
  globalShaderUniforms.set("radial_shine_highlight", "cutoff", 0.1f);
  globalShaderUniforms.set("radial_shine_highlight", "size", 1.0f);
  globalShaderUniforms.set("radial_shine_highlight", "speed", 1.0f);
  globalShaderUniforms.set("radial_shine_highlight", "ray1_density", 8.0f);
  globalShaderUniforms.set("radial_shine_highlight", "ray2_density", 30.0f);
  globalShaderUniforms.set("radial_shine_highlight", "ray2_intensity", 0.3f);
  globalShaderUniforms.set("radial_shine_highlight", "core_intensity", 2.0f);
  globalShaderUniforms.set("radial_shine_highlight", "seed", 5.0f);
  globalShaderUniforms.set("radial_shine_highlight", "hdr", 0); // false
  shaders::registerUniformUpdate("radial_shine_highlight", [](Shader &shader) {
    globalShaderUniforms.set("radial_shine_highlight", "time",
                             static_cast<float>(main_loop::getTime()));
  });
  // ========== NEW SHADERS FROM GODOT CONVERSION ==========

  // efficient_pixel_outline - Pixel-perfect outlines (4-way/8-way)
  globalShaderUniforms.set("efficient_pixel_outline", "outlineColor",
                           Vector4{0.0f, 0.0f, 0.0f, 1.0f});
  globalShaderUniforms.set("efficient_pixel_outline", "outlineType",
                           2); // 0=none, 1=4-way, 2=8-way
  globalShaderUniforms.set("efficient_pixel_outline", "thickness", 1.0f);

  // atlas_outline - Atlas-aware outlines for sprite regions
  globalShaderUniforms.set("atlas_outline", "outlineWidth", 1.0f);
  globalShaderUniforms.set("atlas_outline", "outlineColor",
                           Vector4{0.0f, 0.0f, 0.0f, 1.0f});
  globalShaderUniforms.set("atlas_outline", "uGridRect",
                           Vector4{0.0f, 0.0f, 1.0f, 1.0f});
  globalShaderUniforms.set("atlas_outline", "uImageSize", Vector2{1.0f, 1.0f});

  // burn_2d - Burn/dissolve effect with ash colors
  shaders::registerUniformUpdate("burn_2d", [](Shader &shader) {
    globalShaderUniforms.set("burn_2d", "iTime",
                             static_cast<float>(main_loop::getTime()));
  });
  globalShaderUniforms.set("burn_2d", "burnSize", 1.0f);
  globalShaderUniforms.set("burn_2d", "burnColor1",
                           Vector4{1.0f, 0.7f, 0.0f, 1.0f}); // Orange
  globalShaderUniforms.set("burn_2d", "burnColor2",
                           Vector4{0.5f, 0.0f, 0.0f, 1.0f}); // Dark red
  globalShaderUniforms.set("burn_2d", "burnColor3",
                           Vector4{0.1f, 0.1f, 0.1f, 1.0f}); // Ash

  // dissolve_burn_edge - Simple dissolve with burn edge
  globalShaderUniforms.set("dissolve_burn_edge", "burnSize", 1.3f);
  globalShaderUniforms.set("dissolve_burn_edge", "progress", 0.0f);

  // drop_shadow - Drop shadow effect
  globalShaderUniforms.set("drop_shadow", "shadowOffset", Vector2{5.0f, 5.0f});
  globalShaderUniforms.set("drop_shadow", "shadowColor",
                           Vector4{0.0f, 0.0f, 0.0f, 0.5f});
  globalShaderUniforms.set("drop_shadow", "shadowSoftness", 1.0f);

  // hologram - Hologram visual effect
  shaders::registerUniformUpdate("hologram", [](Shader &shader) {
    globalShaderUniforms.set("hologram", "iTime",
                             static_cast<float>(main_loop::getTime()));
  });
  globalShaderUniforms.set("hologram", "strength", 0.5f);
  globalShaderUniforms.set("hologram", "frequency", 10.0f);

  // liquid_sphere - Liquid-filled sphere with waves
  shaders::registerUniformUpdate("liquid_sphere", [](Shader &shader) {
    globalShaderUniforms.set("liquid_sphere", "iTime",
                             static_cast<float>(main_loop::getTime()));
  });
  globalShaderUniforms.set("liquid_sphere", "liquidLevel", 0.5f);
  globalShaderUniforms.set("liquid_sphere", "waveAmplitude", 0.1f);
  globalShaderUniforms.set("liquid_sphere", "waveFrequency", 5.0f);
  globalShaderUniforms.set("liquid_sphere", "liquidColor",
                           Vector4{0.2f, 0.6f, 0.8f, 0.7f});

  // texture_liquid - Dual-wave water fill effect
  shaders::registerUniformUpdate("texture_liquid", [](Shader &shader) {
    globalShaderUniforms.set("texture_liquid", "iTime",
                             static_cast<float>(main_loop::getTime()));
  });
  globalShaderUniforms.set("texture_liquid", "waterColor1",
                           Vector4{0.2f, 0.6f, 0.8f, 0.5f});
  globalShaderUniforms.set("texture_liquid", "waterColor2",
                           Vector4{0.1f, 0.5f, 0.7f, 0.4f});
  globalShaderUniforms.set("texture_liquid", "waterLevelPercentage", 0.0f);
  globalShaderUniforms.set("texture_liquid", "waveFrequency1", 10.0f);
  globalShaderUniforms.set("texture_liquid", "waveAmplitude1", 0.05f);
  globalShaderUniforms.set("texture_liquid", "waveFrequency2", 15.0f);
  globalShaderUniforms.set("texture_liquid", "waveAmplitude2", 0.03f);

  // pixel_perfect_dissolve - Resolution-independent dissolve
  globalShaderUniforms.set("pixel_perfect_dissolve", "sensitivity", 0.5f);
}
} // namespace game
