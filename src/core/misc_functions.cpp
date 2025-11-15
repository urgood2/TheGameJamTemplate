#include "misc_fuctions.hpp"

#include "util/common_headers.hpp"
#include "util/utilities.hpp"
#include "core/globals.hpp"
#include "core/game.hpp"
#include "core/init.hpp"
#include "systems/shaders/shader_system.hpp"
#include "systems/palette/palette_quantizer.hpp"
namespace game
{
    std::function<void()> OnUIScaleChanged = []() {
        // Default implementation does nothing
        SPDLOG_DEBUG("OnUIScaleChanged called, but no action defined.");
    };

    void SetUpShaderUniforms()
    {

        using namespace globals;
        // pre-load shader values for later use
        
        // my own polychrome
        // register frame‐time‐dependent uniforms
        shaders::registerUniformUpdate("custom_polychrome", [](Shader &sh) {
            // if you ever need to animate waveSpeed or time, update here
            globalShaderUniforms.set("custom_polychrome", "time",    (float)main_loop::getTime());
        });

        // one‐time defaults
        globalShaderUniforms.set("custom_polychrome", "stripeFreq",  0.3f);
        globalShaderUniforms.set("custom_polychrome", "waveFreq",    2.0f);
        globalShaderUniforms.set("custom_polychrome", "waveAmp",     0.4f);
        globalShaderUniforms.set("custom_polychrome", "waveSpeed",   0.1f);
        globalShaderUniforms.set("custom_polychrome", "stripeWidth", 1.0f);
        globalShaderUniforms.set("custom_polychrome", "polychrome",  Vector2{0.0f, 0.1f});
        
        
        // spotlight shader
        // one‐time defaults
        // update on every frame in case of resize
        globalShaderUniforms.set("spotlight", "screen_width",  static_cast<float>(GetScreenWidth()));
        globalShaderUniforms.set("spotlight", "screen_height", static_cast<float>(GetScreenHeight()));
        globalShaderUniforms.set("spotlight", "circle_size",      0.5f);
        globalShaderUniforms.set("spotlight", "feather",          0.05f);
        globalShaderUniforms.set("spotlight", "circle_position",  Vector2{0.5f, 0.5f});
        
        
        // palette shader
        
        palette_quantizer::setPaletteTexture("palette_quantize", util::getRawAssetPathNoUUID("graphics/palettes/resurrect-64-1x.png"));
        // static auto paletteTex = LoadTexture(util::getRawAssetPathNoUUID("graphics/palettes/duel-1x.png").c_str());
        // SetTextureFilter(paletteTex, TEXTURE_FILTER_POINT);
        // globalShaderUniforms.set("palette_quantize", "palette", paletteTex);
        // globalShaderUniforms.set("palette_quantize", "palette_size", 256.f); // size of the palette
        


        // one-time defaults
        globalShaderUniforms.set("random_displacement_anim", "interval",   0.5f);
        globalShaderUniforms.set("random_displacement_anim", "timeDelay",  1.4f);
        globalShaderUniforms.set("random_displacement_anim", "intensityX", 4.0f);
        globalShaderUniforms.set("random_displacement_anim", "intensityY", 4.0f);
        globalShaderUniforms.set("random_displacement_anim", "seed",       42.0f);

        // every frame, drive the time
        shaders::registerUniformUpdate("random_displacement_anim", [](Shader &shader) {
            globalShaderUniforms.set("random_displacement_anim", "iTime", (float)main_loop::getTime());
        });

        
        globalShaderUniforms.set("pixelate_image", "texSize",
            Vector2{ (float)globals::screenWidth, (float)globals::screenHeight });
        globalShaderUniforms.set("pixelate_image", "pixelRatio",
            0.4f);


        
        const int TILE_SIZE = 64; // size of a tile in pixels, temporary, used for tile grid overlay

        
        auto frame = init::getSpriteFrame("tile-grid-boundary.png");
        auto atlasID =  frame.atlasUUID;
        auto atlas = globals::textureAtlasMap.at(atlasID);
        auto gridX = frame.frame.x;
        auto gridY = frame.frame.y;
        auto gridW = frame.frame.width;
        auto gridH = frame.frame.height;
        
        atlas = globals::textureAtlasMap.at(atlasID);
        
        // tile grid overlay
        shaders::registerUniformUpdate("tile_grid_overlay", [atlas](Shader &s) {            
            globalShaderUniforms.set("tile_grid_overlay", "mouse_position",
                                     GetMousePosition());   
            
            globalShaderUniforms.set("tile_grid_overlay", "atlas", atlas);  
            
            // auto shader = shaders::getShader("tile_grid_overlay");
            
            // int atlasLoc = GetShaderLocation(shader, "atlas");
            // SetShaderValueTexture(shader, atlasLoc, atlas);
            
        });
        
        float desiredCellSize = TILE_SIZE;             // in world‐units
        float scale = 1.0f/desiredCellSize;    // how many cells per world‐unit

        
        // atlas dims
        globalShaderUniforms.set("tile_grid_overlay", "uImageSize",
            Vector2{ float(atlas.width), float(atlas.height) });
        // which grid sprite
        globalShaderUniforms.set("tile_grid_overlay", "uGridRect",
                    Vector4{ gridX, gridY, gridW, gridH });

        // grid parameters
        globalShaderUniforms.set("tile_grid_overlay", "scale",             scale);
        globalShaderUniforms.set("tile_grid_overlay", "base_opacity",      0.0f);
        globalShaderUniforms.set("tile_grid_overlay", "highlight_opacity", 0.4f);
        globalShaderUniforms.set("tile_grid_overlay", "distance_scaling",  100.0f);

        // outer space

        shaders::registerUniformUpdate("outer_space_donuts_bg", [](Shader &shader) { // update iTime every frame
            globalShaderUniforms.set("outer_space_donuts_bg", "iTime", static_cast<float>(main_loop::getTime()));
        });
        // One-time setup
        globalShaderUniforms.set("outer_space_donuts_bg", "iResolution", Vector2{(float)GetScreenWidth(), (float)GetScreenHeight()});
        globalShaderUniforms.set("outer_space_donuts_bg", "grayAmount", 0.77f); // Set initial gray amount
        globalShaderUniforms.set("outer_space_donuts_bg", "desaturateAmount ", 2.87f); // Set initial desaturation amount
        globalShaderUniforms.set("outer_space_donuts_bg", "speedFactor", 0.61f); // Set initial speed factor

        globalShaderUniforms.set("outer_space_donuts_bg", "u_brightness", 0.17f); // Set initial brightness
        globalShaderUniforms.set("outer_space_donuts_bg", "u_noisiness", 0.22f); // Set initial noisiness
        globalShaderUniforms.set("outer_space_donuts_bg", "u_hueOffset", 0.0f); // Set initial hue offset
        globalShaderUniforms.set("outer_space_donuts_bg", "u_donutWidth", -2.77f); // Set initial donut width
        globalShaderUniforms.set("outer_space_donuts_bg", "pixel_filter", 150.f); // Set initial hue offset
        
        //TODO: hue offset can be animated with timer

        
        // flash shader
        shaders::registerUniformUpdate("flash", [](Shader &shader) { // update iTime every frame
            globalShaderUniforms.set("flash", "iTime", static_cast<float>(main_loop::getTime()));
        });

        // screen transition
        globalShaderUniforms.set("screen_tone_transition", "in_out", 0.f);
        globalShaderUniforms.set("screen_tone_transition", "position", 0.0f);
        globalShaderUniforms.set("screen_tone_transition", "size", Vector2{32.f, 32.f});
        globalShaderUniforms.set("screen_tone_transition", "screen_pixel_size", Vector2{1.0f / GetScreenWidth(), 1.0f / GetScreenHeight()});
        globalShaderUniforms.set("screen_tone_transition", "in_color", Vector4{0.0f, 0.0f, 0.0f, 1.0f});
        globalShaderUniforms.set("screen_tone_transition", "out_color", Vector4{1.0f, 1.0f, 1.0f, 1.0f});

        // background shader

        /*

            iTime	float	0.0 → ∞	Elapsed time in seconds. Drives animation. Use main_loop::getTime() or delta accumulation.
            texelSize	vec2	1.0 / screenSize	Inverse of resolution. E.g., vec2(1.0/1280.0, 1.0/720.0).
            polar_coordinates	bool	0 or 1	Whether to enable polar swirl distortion. 1 = ON.
            polar_center	vec2	0.0–1.0	Normalized UV center of polar distortion. (0.5, 0.5) = screen center.
            polar_zoom	float	0.1–5.0	Zooms radial distortion. 1.0 = normal. Lower = zoomed out, higher = intense warping.
            polar_repeat	float	1.0–10.0	Number of angular repetitions. Integer values give clean symmetry, higher = more spirals.
            spin_rotation	float	-50.0 to 50.0	Adds static phase offset to swirl. Negative = reverse direction.
            spin_speed	float	0.0–10.0+	Time-based swirl speed. 1.0 is normal. Higher values animate faster.
            offset	vec2	-1.0 to 1.0	Offsets center of swirl (in screen space units, scaled internally). (0,0) = centered.
            contrast	float	0.1–5.0	Intensity of color banding & separation. 1–2 is moderate. Too low = washed out, too high = posterized.
            spin_amount	float	0.0–1.0	Controls swirl based on distance from center. 0 = flat, 1 = full swirl.
            pixel_filter	float	50.0–1000.0	Pixelation size. Higher = smaller pixels. Use screen length / desired resolution.
            colour_1	vec4	Any RGBA	Base layer color. Dominates background.
            colour_2	vec4	Any RGBA	Middle blend color. Transitions with contrast and distance.
            colour_3	vec4	Any RGBA	Accent/outer color. Used at edges in the paint-like effect.
        */
        globalShaderUniforms.set("balatro_background", "texelSize", Vector2{1.0f / GetScreenWidth(), 1.0f / GetScreenHeight()}); // Dynamic resolution
        globalShaderUniforms.set("balatro_background", "polar_coordinates", 0.0f);
        globalShaderUniforms.set("balatro_background", "polar_center", Vector2{0.5f, 0.5f});
        globalShaderUniforms.set("balatro_background", "polar_zoom", 4.52f);
        globalShaderUniforms.set("balatro_background", "polar_repeat", 2.91f);
        globalShaderUniforms.set("balatro_background", "spin_rotation", 7.0205107f);
        globalShaderUniforms.set("balatro_background", "spin_speed", 6.8f);
        globalShaderUniforms.set("balatro_background", "offset", Vector2{0.0f, 0.0f});
        globalShaderUniforms.set("balatro_background", "contrast", 4.43f);
        globalShaderUniforms.set("balatro_background", "spin_amount", -0.09f);
        globalShaderUniforms.set("balatro_background", "pixel_filter", 300.0f);
        globalShaderUniforms.set("balatro_background", "colour_1", Vector4{0.020128006f, 0.0139369555f, 0.049019635f, 1.0f});
        globalShaderUniforms.set("balatro_background", "colour_2", Vector4{0.029411793f, 1.0f, 0.0f, 1.0f});
        globalShaderUniforms.set("balatro_background", "colour_3", Vector4{1.0f, 1.0f, 1.0f, 1.0f});
        shaders::registerUniformUpdate("balatro_background", [](Shader &shader) { // update iTime every frame
            globalShaderUniforms.set("balatro_background", "iTime", static_cast<float>(main_loop::getTime()));

            /*
                spin rotation:

                0.0	Neutral, baseline rotation
                1.0	Slight phase shift
                10.0	Visible but not overwhelming twist
                50.0+	Heavy spiral skewing, starts to distort hard
                Negative	Reverses swirl direction
                Fractional	Works fine – adds minor shifting
            */
            globalShaderUniforms.set("balatro_background", "spin_rotation", static_cast<float>(sin(main_loop::getTime() * 0.01f) * 13.0f));
        });

        // crt

        /*
            resolution	vec2	Typically {320, 180} to {1920, 1080}	Target screen resolution, required for scaling effects and sampling.
            iTime	float	0.0 → ∞	Time in seconds. Use main_loop::getTime(). Drives rolling lines, noise, chromatic aberration.
            scan_line_amount	float	0.0 – 1.0	Strength of horizontal scanlines. 0.0 = off, 1.0 = full effect.
            scan_line_strength	float	-12.0 – -1.0	How sharp the scanlines are. More negative = thinner/darker.
            pixel_strength	float	-4.0 – 0.0	How much pixel sampling blur is applied. 0.0 = sharp, -4.0 = blurry.
            warp_amount	float	0.0 – 5.0	Barrel distortion strength. Around 0.1 – 0.4 looks classic CRT.
            noise_amount	float	0.0 – 0.3	Random static per pixel. Good for a "dirty signal" look.
            interference_amount	float	0.0 – 1.0	Horizontal jitter/noise. Higher = more glitchy interference.
            grille_amount	float	0.0 – 1.0	Visibility of CRT RGB grille pattern. 0.1 – 0.4 is subtle, 1.0 is strong.
            grille_size	float	1.0 – 5.0	Scales the RGB grille. Smaller = tighter grille pattern.
            vignette_amount	float	0.0 – 2.0	Amount of darkening at corners. 1.0 is typical.
            vignette_intensity	float	0.0 – 1.0	Sharpness of vignette. 0.2 = soft falloff, 1.0 = harsh.
            aberation_amount	float	0.0 – 1.0	Chromatic aberration (RGB channel shift). Subtle at 0.1, heavy at 0.5+.
            roll_line_amount	float	0.0 – 1.0	Strength of vertical rolling white line. Retro TV effect.
            roll_speed	float	-8.0 – 8.0	Speed/direction of the rolling line. Positive = down, negative = up.
        */
        globalShaderUniforms.set("crt", "resolution", Vector2{static_cast<float>(GetScreenWidth()), static_cast<float>(GetScreenHeight())});
        shaders::registerUniformUpdate("crt", [](Shader &shader) { // update iTime every frame
            globalShaderUniforms.set("crt", "iTime", static_cast<float>(main_loop::getTime()));
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
        globalShaderUniforms.set("shockwave", "resolution", Vector2{(float)GetScreenWidth(), (float)GetScreenHeight()});
        globalShaderUniforms.set("shockwave", "strength", 0.18f);
        globalShaderUniforms.set("shockwave", "center", Vector2{0.5f, 0.5f});
        globalShaderUniforms.set("shockwave", "radius", 1.93f);
        globalShaderUniforms.set("shockwave", "aberration", -2.115f);
        globalShaderUniforms.set("shockwave", "width", 0.28f);
        globalShaderUniforms.set("shockwave", "feather", 0.415f);

        // glitch
        globalShaderUniforms.set("glitch", "resolution", Vector2{(float)GetScreenWidth(), (float)GetScreenHeight()});
        shaders::registerUniformUpdate("glitch", [](Shader &shader) { // update iTime every frame
            globalShaderUniforms.set("glitch", "iTime", static_cast<float>(main_loop::getTime()));
        });
        globalShaderUniforms.set("glitch", "shake_power", 0.03f);
        globalShaderUniforms.set("glitch", "shake_rate", 0.2f);
        globalShaderUniforms.set("glitch", "shake_speed", 5.0f);
        globalShaderUniforms.set("glitch", "shake_block_size", 30.5f);
        globalShaderUniforms.set("glitch", "shake_color_rate", 0.01f);

        // wind
        shaders::registerUniformUpdate("wind", [](Shader &shader) { // update iTime every frame
            globalShaderUniforms.set("wind", "iTime", static_cast<float>(main_loop::getTime()));
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
        
        globalShaderUniforms.set("fireworks", "uGridRect", Vector4{0,0,1,1});
        globalShaderUniforms.set("fireworks", "uImageSize", Vector2{(float)screenWidth,(float)screenHeight});
        

        globalShaderUniforms.set("fireworks", "Praticle_num", (int)30);
        globalShaderUniforms.set("fireworks", "TimeStep", (int)3);

        // Floats
        globalShaderUniforms.set("fireworks", "s77",            1.13f);
        globalShaderUniforms.set("fireworks", "Range",          1.14f);
        globalShaderUniforms.set("fireworks", "s55",            1.51f);
        globalShaderUniforms.set("fireworks", "gravity",       -0.49f);
        globalShaderUniforms.set("fireworks", "ShneyMagnitude", 0.42f);
        globalShaderUniforms.set("fireworks", "s33",            4.15f);
        globalShaderUniforms.set("fireworks", "iTime",        373.62292f);
        globalShaderUniforms.set("fireworks", "s99",            9.92f);
        globalShaderUniforms.set("fireworks", "s11",            0.40f);
        globalShaderUniforms.set("fireworks", "speed",          5.57f);
        
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

        
        shaders::registerUniformUpdate("starry_tunnel", [](Shader &shader){
            globalShaderUniforms.set("starry_tunnel", "iTime", (float)GetTime());
        });

        
        // singel item glow
        shaders::registerUniformUpdate("item_glow", [](Shader &shader) {
            globalShaderUniforms.set("item_glow", "iTime", (float)GetTime());
        });
        globalShaderUniforms.set("item_glow", "glow_color", Vector4{1.0f, 0.9f, 0.5f, 1.0f});
        globalShaderUniforms.set("item_glow", "intensity", 1.5f);
        globalShaderUniforms.set("item_glow", "spread", 1.0f);
        globalShaderUniforms.set("item_glow", "pulse_speed", 1.0f);

        

        // pseudo 3d skew
    shaders::registerUniformUpdate("3d_skew", [](Shader &shader)
                                       {
        globalShaderUniforms.set("3d_skew", "iTime", static_cast<float>(main_loop::getTime()));
        globalShaderUniforms.set("3d_skew", "mouse_screen_pos", GetMousePosition());
        globalShaderUniforms.set("3d_skew", "resolution", Vector2{
            static_cast<float>(GetScreenWidth()),
            static_cast<float>(GetScreenHeight())
        }); });
        // --- Projection parameters (from your log) ---
        globalShaderUniforms.set("3d_skew", "fov", -0.39f); // From runtime dump
        globalShaderUniforms.set("3d_skew", "x_rot", 0.0f); // No X tilt
        globalShaderUniforms.set("3d_skew", "y_rot", 0.0f); // No Y orbit
        globalShaderUniforms.set("3d_skew", "inset", 0.0f); // No edge compression
        // --- Interaction dynamics ---
        globalShaderUniforms.set("3d_skew", "hovering", 0.3f);         // From your log
        globalShaderUniforms.set("3d_skew", "rand_trans_power", 0.4f); // From your log
        globalShaderUniforms.set("3d_skew", "rand_seed", 3.1415f);      // Per-object offset
        globalShaderUniforms.set("3d_skew", "rotation", 0.0f);          // No UV twist
        globalShaderUniforms.set("3d_skew", "cull_back", 0.0f);         // Disable backface culling
        // --- Geometry settings ---
        float drawWidth = static_cast<float>(GetScreenWidth());
        float drawHeight = static_cast<float>(GetScreenHeight());
        globalShaderUniforms.set("3d_skew", "regionRate", Vector2{
                                                              drawWidth / drawWidth,  // = 1.0
                                                              drawHeight / drawHeight // = 1.0
                                                          });
        globalShaderUniforms.set("3d_skew", "pivot", Vector2{0.0f, 0.0f}); // Al

        // squish
        globalShaderUniforms.set("squish", "up_left", Vector2{0.0f, 0.0f});
        globalShaderUniforms.set("squish", "up_right", Vector2{1.0f, 0.0f});
        globalShaderUniforms.set("squish", "down_right", Vector2{1.0f, 1.0f});
        globalShaderUniforms.set("squish", "down_left", Vector2{0.0f, 1.0f});
        globalShaderUniforms.set("squish", "plane_size", Vector2{(float)GetScreenWidth(), (float)GetScreenHeight()});
        shaders::registerUniformUpdate("squish", [](Shader &shader)
                                       {
        // occilate x and y
        globalShaderUniforms.set("squish", "squish_x", (float) sin(main_loop::getTime() * 0.5f) * 0.1f);
        globalShaderUniforms.set("squish", "squish_Y", (float) cos(main_loop::getTime() * 0.2f) * 0.1f); });

        // peaches background
        std::vector<Color> myPalette = {
            WHITE,
            BLUE,
            GREEN,
            RED,
            YELLOW,
            PURPLE};

        globalShaderUniforms.set("peaches_background", "resolution", Vector2{(float)GetScreenWidth(), (float)GetScreenHeight()});
        shaders::registerUniformUpdate("peaches_background", [](Shader &shader)
                                       { globalShaderUniforms.set("peaches_background", "iTime", (float)main_loop::getTime() * 0.5f); }); 
        globalShaderUniforms.set("peaches_background", "resolution", Vector2{(float)GetScreenWidth(), (float)GetScreenHeight()});

        // === Peaches Background Shader Uniforms ===
        globalShaderUniforms.set("peaches_background", "iTime", static_cast<float>(main_loop::getTime())); // Real-time updated
        globalShaderUniforms.set("peaches_background", "resolution", Vector2{1440.0f, 900.0f}); // Your screen size

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
        globalShaderUniforms.set("peaches_background", "colorTint", Vector3{0.33f, 0.57f, 0.31f});
        globalShaderUniforms.set("peaches_background", "blob_color_blend", 0.69f);
        globalShaderUniforms.set("peaches_background", "hue_shift", 0.8f);

        globalShaderUniforms.set("peaches_background", "pixel_size", 6.0f);                  // Bigger = chunkier pixels
        globalShaderUniforms.set("peaches_background", "pixel_enable", 1.0f);                // Turn on
        globalShaderUniforms.set("peaches_background", "blob_offset", Vector2{0.0f, -0.1f}); // Moves all blobs upward
        globalShaderUniforms.set("peaches_background", "movement_randomness", 16.2f);        // Tweak live

        // fade_zoom transition
        globalShaderUniforms.set("fade_zoom", "progress", 0.0f);                        // Animate from 0 to 1
        globalShaderUniforms.set("fade_zoom", "zoom_strength", 0.2f);                   // Optional zoom
        globalShaderUniforms.set("fade_zoom", "fade_color", Vector3{0.0f, 0.0f, 0.0f}); // black

        // slide_fade transition
        globalShaderUniforms.set("fade", "progress", 0.0f);                        // Animate from 0.0 to 1.0
        globalShaderUniforms.set("fade", "slide_direction", Vector2{1.0f, 0.0f});  // Slide to the right
        globalShaderUniforms.set("fade", "fade_color", Vector3{0.0f, 0.0f, 0.0f}); // Fade through black

        // foil
        // Time-related
        globalShaderUniforms.set("foil", "time", (float)main_loop::getTime()); // or animated time
        // Dissolve factor (0.0 to 1.0)
        globalShaderUniforms.set("foil", "dissolve", 0.0f); // animate this for dissolve effect
        // Foil animation vector (e.g. shimmer intensity/direction)
        globalShaderUniforms.set("foil", "foil", Vector2{1.0f, 1.0f}); // tweak for animation patterns
        // Texture region and layout
        globalShaderUniforms.set("foil", "texture_details", Vector4{0.0f, 0.0f, 128.0f, 128.0f}); // x,y offset + width,height
        globalShaderUniforms.set("foil", "image_details", Vector2{128.0f, 128.0f});               // full image dimensions
        // Color burn blend colors (used during dissolve)
        globalShaderUniforms.set("foil", "burn_colour_1", Vector4{1.0f, 0.3f, 0.0f, 1.0f}); // hot orange
        globalShaderUniforms.set("foil", "burn_colour_2", Vector4{1.0f, 1.0f, 0.2f, 1.0f}); // yellow glow
        // Shadow mode (if true, output darkened tones)
        globalShaderUniforms.set("foil", "shadow", 0.0f);

        // Time and dissolve progression
        globalShaderUniforms.set("holo", "time", 0.0f);     // Should be updated every frame
        globalShaderUniforms.set("holo", "dissolve", 0.0f); // 0.0 (off) to 1.0 (full dissolve)

        // Texture layout
        globalShaderUniforms.set("holo", "texture_details", Vector4{0.0f, 0.0f, 64.0f, 64.0f}); // offsetX, offsetY, texWidth, texHeight
        globalShaderUniforms.set("holo", "image_details", Vector2{64.0f, 64.0f});               // actual size in pixels

        // Shine and interference control
        globalShaderUniforms.set("holo", "holo", Vector2{1.2f, 0.8f}); // x = shine intensity, y = interference scroll

        // Colors
        globalShaderUniforms.set("holo", "burn_colour_1", ColorNormalize(BLUE));   // Edge glow color A
        globalShaderUniforms.set("holo", "burn_colour_2", ColorNormalize(PURPLE)); // Edge glow color B
        globalShaderUniforms.set("holo", "shadow", 0.0f);                          // Set true to enable shadow pass

        // Mouse hover distortion
        globalShaderUniforms.set("holo", "mouse_screen_pos", Vector2{0.0f, 0.0f}); // In screen pixels
        globalShaderUniforms.set("holo", "hovering", 0.0f);                        // 0.0 = off, 1.0 = on
        globalShaderUniforms.set("holo", "screen_scale", 1.0f);                    // Scale of UI in pixels

        // Time update
        shaders::registerUniformUpdate("holo", [](Shader &shader)
                                       { globalShaderUniforms.set("holo", "time", (float)main_loop::getTime()); });

        // Texture details
        globalShaderUniforms.set("polychrome", "texture_details", Vector4{0.0f, 0.0f, 64.0f, 64.0f}); // offsetX, offsetY, texWidth, texHeight
        globalShaderUniforms.set("polychrome", "image_details", Vector2{64.0f, 64.0f});               // actual size in pixels

        // Animation + effect tuning
        globalShaderUniforms.set("polychrome", "time", (float)main_loop::getTime());
        globalShaderUniforms.set("polychrome", "dissolve", 0.0f);                // 0.0 to 1.0
        globalShaderUniforms.set("polychrome", "polychrome", Vector2{0.1, 0.1}); // tweak for effect, hue_modulation, animation speed

        // Visual options
        globalShaderUniforms.set("polychrome", "shadow", 0.0f);
        globalShaderUniforms.set("polychrome", "burn_colour_1", Vector4{1.0f, 1.0f, 0, 1.0f});    // glowing edge
        globalShaderUniforms.set("polychrome", "burn_colour_2", Vector4{1.0f, 1.0f, 1.0f, 1.0f}); // highlight outer burn

        globalShaderUniforms.set("negative_shine", "texture_details", Vector4{0.0f, 0.0f, 64.0f, 64.0f}); // offsetX, offsetY, texWidth, texHeight
        globalShaderUniforms.set("negative_shine", "image_details", Vector2{64.0f, 64.0f});               // actual size in pixels

        // Shine animation control
        globalShaderUniforms.set("negative_shine", "negative_shine", Vector2{1.0f, 1.0f}); // x = phase offset, y = amplitude

        // Burn edge colors
        globalShaderUniforms.set("negative_shine", "burn_colour_1", ColorNormalize(SKYBLUE)); // Primary edge highlight
        globalShaderUniforms.set("negative_shine", "burn_colour_2", ColorNormalize(PINK));    // Secondary edge highlight
        globalShaderUniforms.set("negative_shine", "shadow", 0.0f);                           // 0.0 = normal, 1.0 = shadow mode

        // Mouse interaction (if used in vertex distortion)
        globalShaderUniforms.set("negative_shine", "mouse_screen_pos", Vector2{0.0f, 0.0f});
        globalShaderUniforms.set("negative_shine", "hovering", 0.0f);
        globalShaderUniforms.set("negative_shine", "screen_scale", 1.0f);

        // Time uniform updater
        shaders::registerUniformUpdate("negative_shine", [](Shader &shader)
                                       { globalShaderUniforms.set("negative_shine", "time", (float)main_loop::getTime()); });

        // Texture layout details
        globalShaderUniforms.set("negative", "texture_details", Vector4{0.0f, 0.0f, 64.0f, 64.0f}); // offsetX, offsetY, texWidth, texHeight
        globalShaderUniforms.set("negative", "image_details", Vector2{64.0f, 64.0f});               // actual size in pixels

        // Negative effect control
        globalShaderUniforms.set("negative", "negative", Vector2{1.0f, 1.0f}); // x = hue inversion offset, y = brightness inversion toggle (non-zero enables)

        // Dissolve and timing
        globalShaderUniforms.set("negative", "dissolve", 0.0f); // 0.0 = off, 1.0 = fully dissolved
        shaders::registerUniformUpdate("negative", [](Shader &shader)
                                       { globalShaderUniforms.set("negative", "time", (float)main_loop::getTime()); });

        // Edge burn colors
        globalShaderUniforms.set("negative", "burn_colour_1", ColorNormalize(RED));    // Primary burn color
        globalShaderUniforms.set("negative", "burn_colour_2", ColorNormalize(ORANGE)); // Secondary burn color
        globalShaderUniforms.set("negative", "shadow", 0.0f);                          // 1.0 = enable black mask shadow mode

        // UI hover distortion (optional)
        globalShaderUniforms.set("negative", "mouse_screen_pos", Vector2{0.0f, 0.0f});
        globalShaderUniforms.set("negative", "hovering", 0.0f);     // 0.0 = no hover effect, 1.0 = active
        globalShaderUniforms.set("negative", "screen_scale", 1.0f); // UI scale factor
        
        // spectrum rect
        globalShaderUniforms.set("spectrum_circle", "iResolution", Vector2{static_cast<float>(GetScreenWidth()), static_cast<float>(GetScreenHeight())});

        shaders::registerUniformUpdate("spectrum_circle", [](Shader &shader) {
            globalShaderUniforms.set("spectrum_circle", "iTime", static_cast<float>(main_loop::getTime()));
        });
        globalShaderUniforms.set("spectrum_circle", "uCenter",   Vector2{200, 150});  // relative to uRectPos
        globalShaderUniforms.set("spectrum_circle", "uRadius",   30.0f);
        
        // spectrum line
        shaders::registerUniformUpdate("spectrum_line_background", [](Shader &shader) {
            globalShaderUniforms.set("spectrum_line_background", "iTime", static_cast<float>(main_loop::getTime()));
            globalShaderUniforms.set("spectrum_line_background", "iResolution", Vector2{static_cast<float>(GetScreenWidth()), static_cast<float>(GetScreenHeight())});
        });
        
        // One-time configuration (or updated as needed)
        globalShaderUniforms.set("spectrum_line_background", "uLineSpacing", 100.0f);     // spacing between scanlines
        globalShaderUniforms.set("spectrum_line_background", "uLineWidth", 0.75f);        // thickness of each scanline
        globalShaderUniforms.set("spectrum_line_background", "uBeamHeight", 30.0f);       // vertical beam thickness
        globalShaderUniforms.set("spectrum_line_background", "uBeamIntensity", 1.0f);     // how strong the beam glows
        globalShaderUniforms.set("spectrum_line_background", "uOpacity", 1.0f);           // overlay strength (0 = invisible, 1 = full effect)
        
        globalShaderUniforms.set("spectrum_line_background", "uBeamY",          200.0f);  // vertical position in pixels
        globalShaderUniforms.set("spectrum_line_background", "uBeamWidth",      400.0f);  // horizontal length in pixels
        globalShaderUniforms.set("spectrum_line_background", "uBeamX",          400.0f);  //


        globalShaderUniforms.set("voucher_sheen", "booster", Vector2{0.0f, 0.0f});
        globalShaderUniforms.set("voucher_sheen", "dissolve", 0.0f);
        globalShaderUniforms.set("voucher_sheen", "time", 0.0f);
        globalShaderUniforms.set("voucher_sheen", "texture_details", Vector4{0.0f, 0.0f, 64.0f, 64.0f}); // .xy = offset, .zw = scale
        globalShaderUniforms.set("voucher_sheen", "image_details", Vector2{64.0f, 64.0f}); // set to your texture size
        globalShaderUniforms.set("voucher_sheen", "shadow", false);
        globalShaderUniforms.set("voucher_sheen", "burn_colour_1", ColorNormalize(BLUE));
        globalShaderUniforms.set("voucher_sheen", "burn_colour_2", ColorNormalize(PURPLE));

        // Optional live updates
        shaders::registerUniformUpdate("voucher_sheen", [](Shader &shader) {
            globalShaderUniforms.set("voucher_sheen", "time", static_cast<float>(main_loop::getTime()));
        });

    }
}