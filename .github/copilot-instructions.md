# GitHub Copilot Instructions

Tree snapshot of the repository (depth <= 3, hidden entries excluded). Generated with a Python fallback because `tree` is not installed in this environment.

```text
.
├── BATCHED_ENTITY_RENDERING.md
├── BUILDING_FOR_WEB
├── CHANGELOG.md
├── CMakeLists.txt
├── DRAW_COMMAND_BATCH_TESTING_GUIDE.md
├── DRAW_COMMAND_OPTIMIZATION.md
├── IMPLEMENTATION_SUMMARY.md
├── INTEGRATION_GUIDE.md
├── Justfile
├── PROJECTILE_ARCHITECTURE_FIX.md
├── PROJECTILE_TEST_FIX.md
├── README.md
├── TESTING_CHECKLIST.md
├── USING_TRACY.md
├── archived_cpp
│   └── particle_old
│       ├── particleAttachmentSystem.cpp
│       ├── particleAttachmentSystem.hpp
│       ├── particles.cpp
│       └── particles.hpp
├── assets
│   ├── Title.png
│   ├── Typical_2D_platformer_example.ldtk
│   ├── Typical_TopDown_example.ldtk
│   ├── all_uuids.json #auto_generated #verified.json
│   ├── atlas
│   │   ├── Beach by deepnight.png
│   │   ├── Cavernas_by_Adam_Saltsman.png
│   │   ├── Inca_back2_by_Kronbits.png
│   │   ├── Inca_front_by_Kronbits-extended.png
│   │   ├── NuclearBlaze_by_deepnight.aseprite
│   │   ├── SunnyLand_by_Ansimuz-extended.png
│   │   ├── TopDown_by_deepnight.png
│   │   └── classicAutoTiles.aseprite
│   ├── config.json
│   ├── fonts
│   │   ├── en
│   │   └── ko
│   ├── gamecontrollerdb.txt
│   ├── graphics
│   │   ├── animations.json
│   │   ├── ascii_sprites_data.json
│   │   ├── ascii_sprites_texture.png
│   │   ├── ascii_sprites_texturepacker.tps
│   │   ├── ascii_tilesets
│   │   ├── cp437_20x20_sprites.json
│   │   ├── cp437_20x20_sprites.png
│   │   ├── cp437_20x20_sprites_for_viewing.png
│   │   ├── cp437_20x20_texturePackerProject.tps
│   │   ├── cp437_mappings.json
│   │   ├── cp437ui.aseprite
│   │   ├── cp437ui.png
│   │   ├── npatch.json
│   │   ├── npatch_border_sample.png
│   │   ├── palettes
│   │   ├── pre-packing-files_globbed
│   │   ├── rounded_rect.aseprite
│   │   ├── rounded_rect.png
│   │   ├── rounded_rect_small.aseprite
│   │   ├── rounded_rect_small.png
│   │   ├── rounded_rect_very_small.aseprite
│   │   ├── rounded_rect_very_small.png
│   │   ├── shader_textures
│   │   ├── sprites-0.json
│   │   ├── sprites-1.json
│   │   ├── sprites-2.json
│   │   ├── sprites_atlas-0.png
│   │   ├── sprites_atlas-1.png
│   │   ├── sprites_atlas-2.png
│   │   ├── sprites_texturepacker.tps
│   │   ├── tile-grid-boundary.aseprite
│   │   ├── tile-grid-boundary.png
│   │   └── weather-or-not.png
│   ├── localization
│   │   ├── en_us.json
│   │   ├── fonts.json
│   │   ├── ko_kr.json
│   │   └── localization.babel
│   ├── raws
│   │   ├── colors.json
│   │   └── eng_synonyms.json
│   ├── scripts
│   │   ├── AI_TABLE_CONTENT_EXAMPLE.lua
│   │   ├── ai
│   │   ├── ai_actions.json
│   │   ├── ai_worldstate.json
│   │   ├── chugget_code_definitions.lua
│   │   ├── color
│   │   ├── combat
│   │   ├── conditions
│   │   ├── core
│   │   ├── creatures.json
│   │   ├── examples
│   │   ├── external
│   │   ├── init
│   │   ├── monobehavior
│   │   ├── nodemap
│   │   ├── scripting_config.json
│   │   ├── shaders
│   │   ├── task
│   │   ├── task_manager
│   │   ├── test_draw_batching.lua
│   │   ├── test_projectiles.lua
│   │   ├── tutorial
│   │   ├── ui
│   │   ├── util
│   │   └── wand
│   ├── scripts_archived
│   │   ├── jame_gam_50
│   │   └── jame_gam_weather_or_not
│   ├── shaders
│   │   ├── 3d_skew_fragment.fs
│   │   ├── 3d_skew_vertex.vs
│   │   ├── UIEFFECT_README.md
│   │   ├── animated_dotted_outline_fragment.fs
│   │   ├── animated_dotted_outline_vertex.vs
│   │   ├── archived
│   │   ├── atlas_outline_fragment.fs
│   │   ├── atlas_outline_vertex.vs
│   │   ├── base.fs
│   │   ├── base.vs
│   │   ├── bounce_wave_fragment.fs
│   │   ├── bounce_wave_vertex.vs
│   │   ├── bounding_battle_bg_fragment.fs
│   │   ├── bounding_battle_bg_vertex.vs
│   │   ├── burn_2d_fragment.fs
│   │   ├── burn_2d_vertex.vs
│   │   ├── burn_dissolve.fs
│   │   ├── burn_dissolve.vs
│   │   ├── card_tilt_ambient_dynamic.fs
│   │   ├── card_tilt_ambient_dynamic.vs
│   │   ├── chromatic_aberration_fragment.fs
│   │   ├── chromatic_aberration_vertex.vs
│   │   ├── colorful_outline_fragment.fs
│   │   ├── colorful_outline_vertex.vs
│   │   ├── crt_fragment.fs
│   │   ├── crt_vertex.vs
│   │   ├── custom_2d_light_fragment.fs
│   │   ├── custom_2d_light_vertex.vs
│   │   ├── custom_polychrome_fragment.fs
│   │   ├── custom_polychrome_vertex.vs
│   │   ├── customizable_spectrum_beam_overlay_fragment.fs
│   │   ├── darkened_blur_fragment.fs
│   │   ├── darkened_blur_vertex.vs
│   │   ├── discrete_clouds_fragment.fs
│   │   ├── discrete_clouds_vertex.vs
│   │   ├── dissolve_burn_edge_fragment.fs
│   │   ├── dissolve_burn_edge_vertex.vs
│   │   ├── dissolve_burn_fragment.fs
│   │   ├── dissolve_burn_vertex.vs
│   │   ├── dissolve_with_burn_edge_fragment.fs
│   │   ├── dissolve_with_burn_edge_vertex.vs
│   │   ├── drop_shadow_final_fragment.fs
│   │   ├── drop_shadow_final_vertex.vs
│   │   ├── drop_shadow_fragment.fs
│   │   ├── drop_shadow_vertex.vs
│   │   ├── dynamic_glow_fragment.fs
│   │   ├── dynamic_glow_vertex.vs
│   │   ├── edge_effect_fragment.fs
│   │   ├── edge_effect_vertex.vs
│   │   ├── efficient_pixel_outline_fragment.fs
│   │   ├── efficient_pixel_outline_vertex.vs
│   │   ├── efficient_pixel_outlines_fragment.fs
│   │   ├── efficient_pixel_outlines_vertex.vs
│   │   ├── extensible_color_palette_fragment.fs
│   │   ├── extensible_color_palette_vertex.vs
│   │   ├── fade_fragment.fs
│   │   ├── fade_vertex.vs
│   │   ├── fade_zoom_fragment.fs
│   │   ├── fade_zoom_vertex.vs
│   │   ├── fireworks_2d_fragment.fs
│   │   ├── fireworks_2d_vertex.vs
│   │   ├── fireworks_fragment.fs
│   │   ├── fireworks_vertex.vs
│   │   ├── flash.fs
│   │   ├── flash.vs
│   │   ├── flash_fragment.fs
│   │   ├── flash_vertex.vs
│   │   ├── foil_fragment.fs
│   │   ├── foil_vertex.vs
│   │   ├── gamejam_fragment.fs
│   │   ├── gamejam_vertex.vs
│   │   ├── glitch_fragment.fs
│   │   ├── glitch_vertex.vs
│   │   ├── glow_fragment.fs
│   │   ├── glow_vertex.vs
│   │   ├── holo_fragment.fs
│   │   ├── holo_vertex.vs
│   │   ├── hologram_2d_fragment.fs
│   │   ├── hologram_2d_vertex.vs
│   │   ├── hologram_fragment.fs
│   │   ├── hologram_vertex.vs
│   │   ├── holographic_card_fragment.fs
│   │   ├── holographic_card_vertex.vs
│   │   ├── infinite_scrolling_texture_fragment.fs
│   │   ├── infinite_scrolling_texture_vertex.vs
│   │   ├── item_glow_fragment.fs
│   │   ├── item_glow_vertex.vs
│   │   ├── liquid_effects_fragment.fs
│   │   ├── liquid_effects_vertex.vs
│   │   ├── liquid_fill_sphere_fragment.fs
│   │   ├── liquid_fill_sphere_vertex.vs
│   │   ├── liquid_sphere_fragment.fs
│   │   ├── liquid_sphere_vertex.vs
│   │   ├── movable_gui.vs
│   │   ├── negative_fragment.fs
│   │   ├── negative_shine_fragment.fs
│   │   ├── negative_shine_vertex.vs
│   │   ├── negative_vertex.vs
│   │   ├── on_demand_juice.fs
│   │   ├── on_demand_juice.vs
│   │   ├── outer_space_donuts_bg_fragment.fs
│   │   ├── outer_space_donuts_bg_vertex.vs
│   │   ├── palette_quantize_fragment.fs
│   │   ├── palette_quantize_vertex.vs
│   │   ├── palette_shader_fragment.fs
│   │   ├── palette_shader_vertex.vs
│   │   ├── parallax_shadow.fs
│   │   ├── parallax_shadow.vs
│   │   ├── peaches_background_fragment.fs
│   │   ├── peaches_background_vertex.vs
│   │   ├── perspective_warp_fragment.fs
│   │   ├── perspective_warp_vertex.vs
│   │   ├── pixel_art_gradient_fragment.fs
│   │   ├── pixel_art_gradient_vertex.vs
│   │   ├── pixel_art_trail_fragment.fs
│   │   ├── pixel_art_trail_vertex.vs
│   │   ├── pixel_perfect_dissolve_fragment.fs
│   │   ├── pixel_perfect_dissolve_vertex.vs
│   │   ├── pixel_perfect_dissolving_fragment.fs
│   │   ├── pixel_perfect_dissolving_vertex.vs
│   │   ├── pixelate_image_fragment.fs
│   │   ├── pixelate_image_vertex.vs
│   │   ├── pixelated_glitch.fs
│   │   ├── pixelated_glitch.vs
│   │   ├── pixelperfect_outline.fs
│   │   ├── pixelperfect_outline.vs
│   │   ├── polychrome_fragment.fs
│   │   ├── polychrome_vertex.vs
│   │   ├── radial_fire_2d_fragment.fs
│   │   ├── radial_fire_2d_vertex.vs
│   │   ├── radial_shine_2d_fragment.fs
│   │   ├── radial_shine_2d_vertex.vs
│   │   ├── radial_shine_highlight_fragment.fs
│   │   ├── radial_shine_highlight_vertex.vs
│   │   ├── rain_snow_fragment.fs
│   │   ├── rain_snow_vertex.vs
│   │   ├── random_displacement_anim_fragment.fs
│   │   ├── random_displacement_anim_vertex.vs
│   │   ├── random_displacement_fragment.fs
│   │   ├── random_displacement_vertex.vs
│   │   ├── ripple.fs
│   │   ├── ripple.vs
│   │   ├── sakura_overlay_fragment.fs
│   │   ├── sakura_overlay_vertex.vs
│   │   ├── screen_tone_transition_fragment.fs
│   │   ├── screen_tone_transition_vertex.vs
│   │   ├── shaders.json
│   │   ├── sheen.fs
│   │   ├── sheen.vs
│   │   ├── shockwave_fragment.fs
│   │   ├── shockwave_vertex.vs
│   │   ├── smooth_up_and_down_ambient.fs
│   │   ├── smooth_up_and_down_ambient.vs
│   │   ├── spectrum_circle_fragment.fs
│   │   ├── spectrum_circle_vertex.vs
│   │   ├── spectrum_line_background_fragment.fs
│   │   ├── spectrum_line_background_vertex.vs
│   │   ├── spotlight_fragment.fs
│   │   ├── spotlight_vertex.vs
│   │   ├── squish_fragment.fs
│   │   ├── squish_vertex.vs
│   │   ├── starry_tunnel_fragment.fs
│   │   ├── starry_tunnel_vertex.vs
│   │   ├── texture_liquid_fragment.fs
│   │   ├── texture_liquid_vertex.vs
│   │   ├── tile_grid_overlay_fragment.fs
│   │   ├── tile_grid_overlay_vertex.vs
│   │   ├── ui_single_flash.fs
│   │   ├── ui_single_flash.vs
│   │   ├── uieffect_blur_fast.fs
│   │   ├── uieffect_blur_medium.fs
│   │   ├── uieffect_color_filter.fs
│   │   ├── uieffect_common.vs
│   │   ├── uieffect_edge_detection.fs
│   │   ├── uieffect_edge_plain.fs
│   │   ├── uieffect_edge_shiny.fs
│   │   ├── uieffect_gradation_linear.fs
│   │   ├── uieffect_gradation_radial.fs
│   │   ├── uieffect_pixelation.fs
│   │   ├── uieffect_tone_grayscale.fs
│   │   ├── uieffect_tone_negative.fs
│   │   ├── uieffect_tone_posterize.fs
│   │   ├── uieffect_tone_sepia.fs
│   │   ├── uieffect_transition_burn.fs
│   │   ├── uieffect_transition_dissolve.fs
│   │   ├── uieffect_transition_fade.fs
│   │   ├── uieffect_transition_melt.fs
│   │   ├── vacuum_collapse_fragment.fs
│   │   ├── vacuum_collapse_vertex.vs
│   │   ├── voucher_sheen_fragment.fs
│   │   ├── voucher_sheen_vertex.vs
│   │   ├── web
│   │   ├── wind_fragment.fs
│   │   ├── wind_vertex.vs
│   │   ├── wobbly_fragment.fs
│   │   ├── wobbly_grid_fragment.fs
│   │   ├── wobbly_grid_vertex.vs
│   │   └── wobbly_vertex.vs
│   ├── siralim_data
│   │   ├── Siralim Ultimate Compendium - Cards.csv
│   │   ├── Siralim Ultimate Compendium - Relics.csv
│   │   ├── Siralim Ultimate Compendium - Spells.csv
│   │   └── Siralim Ultimate Compendium - Traits.csv
│   ├── sounds
│   │   ├── AMBIENCE_SciFi_Space_Hangar_05_loop_stereo.wav
│   │   ├── AXE_Chop_Tree_Subtle_01_RR2_mono.wav
│   │   ├── Building Place.wav
│   │   ├── Building Plop.wav
│   │   ├── CAMERA_DSLR_Dial_Rotate_03_mono.wav
│   │   ├── CARDS_Deal_01_RR1_mono.wav
│   │   ├── CARDS_Deal_01_RR2_mono.wav
│   │   ├── CARDS_Deal_01_RR3_mono.wav
│   │   ├── CARDS_Deal_01_RR4_mono.wav
│   │   ├── CARDS_Deal_01_RR5_mono.wav
│   │   ├── CARDS_Deal_02_RR1_mono.wav
│   │   ├── CASH_REGISTER_Cha-ching_04_mono.wav
│   │   ├── CHURCH_BELL_03_mono.wav
│   │   ├── Casual Whoosh 8.wav
│   │   ├── Damage Tick.wav
│   │   ├── Default Strike.wav
│   │   ├── Difficulty 1 Fair Weather.wav
│   │   ├── Difficulty 3 Acid Rain.wav
│   │   ├── Difficulty 4 Radioactive Snow.wav
│   │   ├── Dig Sound.wav
│   │   ├── Dropped into Duplicate Window.wav
│   │   ├── Dry Vegetation - Default Footwear - Walk 1.wav
│   │   ├── Dry Vegetation - Default Footwear - Walk 2.wav
│   │   ├── Dry Vegetation - Default Footwear - Walk 4.wav
│   │   ├── Dry Vegetation - Default Footwear - Walk 5.wav
│   │   ├── Dry Vegetation - Default Footwear - Walk 6.wav
│   │   ├── Duplicate.wav
│   │   ├── End of Day.wav
│   │   ├── FABRIC_Movement_Fast_01_mono.wav
│   │   ├── FOOTSTEP_Rock_Walk_01_RR01_mono.wav
│   │   ├── FOOTSTEP_Rock_Walk_01_RR02_mono.wav
│   │   ├── FOOTSTEP_Rock_Walk_01_RR03_mono.wav
│   │   ├── FOOTSTEP_Rock_Walk_01_RR04_mono.wav
│   │   ├── FOOTSTEP_Rock_Walk_01_RR05_mono.wav
│   │   ├── FOOTSTEP_Rock_Walk_01_RR06_mono.wav
│   │   ├── FOOTSTEP_Rock_Walk_01_RR07_mono.wav
│   │   ├── FOOTSTEP_Rock_Walk_01_RR08_mono.wav
│   │   ├── FOOTSTEP_Rock_Walk_01_RR09_mono.wav
│   │   ├── FOOTSTEP_Rock_Walk_01_RR10_mono.wav
│   │   ├── GORE_Deep_Short_Splat_02_mono.wav
│   │   ├── Gems Loot 1.wav
│   │   ├── Gold Gain.wav
│   │   ├── IMPACT_Stone_On_Stone_01_Subtle_mono.wav
│   │   ├── IMPACT_Stone_On_Stone_02_Subtle_mono.wav
│   │   ├── IMPACT_Stone_On_Stone_03_Subtle_mono.wav
│   │   ├── IMPACT_Stone_On_Stone_04_Subtle_mono.wav
│   │   ├── MAGIC_SPELL_Spawn_mono.wav
│   │   ├── MECHANICS_Metal_Mechanism_05_mono.wav
│   │   ├── MONSTER_Breath_01_mono.wav
│   │   ├── Main Menu Theme.wav
│   │   ├── NOTIFICATION_Subtle_07_mono.wav
│   │   ├── Ni Sound Dark Game Trailer Transitions Whoosh 01.wav
│   │   ├── Ni Sound Dark Game Trailer Transitions Whoosh 02.wav
│   │   ├── Pick Up.wav
│   │   ├── Rain Ambience.wav
│   │   ├── Regular Ambience.wav
│   │   ├── SMILETRON - Self Titled - 01 SANCTUM.ogg
│   │   ├── SMILETRON - Self Titled - 02 ORACLE.ogg
│   │   ├── SMILETRON - Self Titled - 03 MICROCOSMIC.ogg
│   │   ├── SMILETRON - Self Titled - 04 GEMINI.ogg
│   │   ├── SMILETRON - Self Titled - 05 CERULEAN.ogg
│   │   ├── SNAP_Clean_mono.wav
│   │   ├── Shop Buy.wav
│   │   ├── Snow Ambience.wav
│   │   ├── TIME_WARP_Start_08_mono.wav
│   │   ├── TIME_WARP_Stop_08_mono.wav
│   │   ├── Tranquil Tides.wav
│   │   ├── UIClick_Bright positive click 3.wav
│   │   ├── UIClick_Cartoon button 2.wav
│   │   ├── UI_Animate_Whisper_Appear_stereo.wav
│   │   ├── UI_Click_Snappy_mono.wav
│   │   ├── WHOOSH_Air_Blade_RR3_mono.wav
│   │   ├── WHOOSH_Air_Slow_RR10_mono.wav
│   │   ├── WHOOSH_Air_Super_Fast_RR1_mono.wav
│   │   ├── WHOOSH_Air_Super_Fast_RR2_mono.wav
│   │   ├── WHOOSH_Air_Super_Fast_RR3_mono.wav
│   │   ├── WHOOSH_Air_Super_Fast_RR4_mono.wav
│   │   ├── WHOOSH_Air_Super_Fast_RR6_mono.wav
│   │   ├── WHOOSH_Deep_Smooth_02_mono copy.wav
│   │   ├── WHOOSH_Deep_Smooth_02_mono.wav
│   │   ├── WHOOSH_Fast_03_mono.wav
│   │   └── sounds.json
│   ├── test.png
│   ├── test_features.ldtk
│   ├── test_translation_project.babel
│   └── world.ldtk
├── build
│   ├── CMakeCache.txt
│   ├── CMakeFiles
│   │   ├── 3.28.3
│   │   ├── 3.30.3
│   │   ├── 4.0.1
│   │   ├── CMakeConfigureLog.yaml
│   │   ├── CMakeDirectoryInformation.cmake
│   │   ├── CMakeRuleHashes.txt
│   │   ├── InstallScripts.json
│   │   ├── Makefile.cmake
│   │   ├── Makefile2
│   │   ├── Progress
│   │   ├── TargetDirectories.txt
│   │   ├── VerifyGlobs.cmake
│   │   ├── activate_emsdk.dir
│   │   ├── build_luajit.dir
│   │   ├── clean_all.dir
│   │   ├── clean_web_build.dir
│   │   ├── cmake.check_cache
│   │   ├── cmake.verify_globs
│   │   ├── compile_web_build.dir
│   │   ├── configure_web_build.dir
│   │   ├── copy_assets.dir
│   │   ├── gzip_assets.dir
│   │   ├── inject_web_patch.dir
│   │   ├── pkgRedirects
│   │   ├── progress.marks
│   │   ├── push_web_build.dir
│   │   ├── raylib-cpp-cmake-template.dir
│   │   ├── rename_to_index.dir
│   │   └── zip_web_build.dir
│   ├── CPackConfig.cmake
│   ├── CPackSourceConfig.cmake
│   ├── CTestTestfile.cmake
│   ├── Debug
│   │   ├── bin
│   │   ├── include
│   │   └── lib
│   ├── Makefile
│   ├── SPIRV-Tools-diffConfig.cmake
│   ├── SPIRV-Tools-linkConfig.cmake
│   ├── SPIRV-Tools-lintConfig.cmake
│   ├── SPIRV-Tools-optConfig.cmake
│   ├── SPIRV-Tools-reduceConfig.cmake
│   ├── SPIRV-Tools-toolsConfig.cmake
│   ├── SPIRV-ToolsConfig.cmake
│   ├── Testing
│   │   ├── 20250326-1242
│   │   ├── 20250330-0659
│   │   ├── 20250403-1106
│   │   ├── 20250406-0746
│   │   ├── 20250407-1010
│   │   ├── 20250409-1144
│   │   ├── 20250412-0218
│   │   ├── 20250413-1556
│   │   ├── 20250414-1157
│   │   ├── 20250415-1127
│   │   ├── 20250417-1048
│   │   ├── 20250418-1229
│   │   ├── 20250419-0030
│   │   ├── 20250421-1109
│   │   ├── 20250424-1054
│   │   ├── TAG
│   │   └── Temporary
│   ├── TracyTargets.cmake
│   ├── _cmrc
│   │   └── include
│   ├── _deps
│   │   ├── catch2-build
│   │   ├── catch2-src
│   │   ├── catch2-subbuild
│   │   ├── dawn-build
│   │   ├── dawn-src
│   │   ├── dawn-subbuild
│   │   ├── entt-build
│   │   ├── entt-src
│   │   ├── entt-subbuild
│   │   ├── fmt-build
│   │   ├── fmt-src
│   │   ├── fmt-subbuild
│   │   ├── glm-build
│   │   ├── glm-src
│   │   ├── glm-subbuild
│   │   ├── googletest-build
│   │   ├── googletest-src
│   │   ├── googletest-subbuild
│   │   ├── json-build
│   │   ├── json-src
│   │   ├── json-subbuild
│   │   ├── ldtkloader-build
│   │   ├── ldtkloader-src
│   │   ├── ldtkloader-subbuild
│   │   ├── lua-build
│   │   ├── lua-src
│   │   ├── lua-subbuild
│   │   ├── luajit-build
│   │   ├── luajit-src
│   │   ├── luajit-subbuild
│   │   ├── magic_enum-build
│   │   ├── magic_enum-src
│   │   ├── magic_enum-subbuild
│   │   ├── random-build
│   │   ├── random-src
│   │   ├── random-subbuild
│   │   ├── raylib-build
│   │   ├── raylib-src
│   │   ├── raylib-subbuild
│   │   ├── slang-build
│   │   ├── slang-src
│   │   ├── slang-subbuild
│   │   ├── snowhouse-build
│   │   ├── snowhouse-src
│   │   ├── snowhouse-subbuild
│   │   ├── sol2-build
│   │   ├── sol2-src
│   │   ├── sol2-subbuild
│   │   ├── spdlog-build
│   │   ├── spdlog-src
│   │   ├── spdlog-subbuild
│   │   ├── stduuid-build
│   │   ├── stduuid-src
│   │   ├── stduuid-subbuild
│   │   ├── tweeny-build
│   │   ├── tweeny-src
│   │   └── tweeny-subbuild
│   ├── bin
│   ├── cmake_install.cmake
│   ├── compile_commands.json
│   ├── generators
│   │   └── Debug
│   ├── imgui.ini
│   ├── include
│   │   └── glslang
│   ├── lib
│   │   ├── libgmock.a
│   │   ├── libgmock_main.a
│   │   ├── libgpgoap.a
│   │   ├── libgtest.a
│   │   └── libgtest_main.a
│   ├── raylib-cpp-cmake-template
│   ├── screenshot000.png
│   ├── src
│   │   └── third_party
│   └── tests
│       ├── CMakeFiles
│       ├── CTestTestfile.cmake
│       ├── Makefile
│       ├── cmake_install.cmake
│       ├── unit_tests
│       ├── unit_tests[1]_include.cmake
│       └── unit_tests[1]_tests.cmake
├── build-asan
│   ├── CMakeCache.txt
│   ├── CMakeFiles
│   │   ├── 3.28.3
│   │   ├── CMakeConfigureLog.yaml
│   │   ├── CMakeDirectoryInformation.cmake
│   │   ├── CMakeRuleHashes.txt
│   │   ├── Makefile.cmake
│   │   ├── Makefile2
│   │   ├── TargetDirectories.txt
│   │   ├── VerifyGlobs.cmake
│   │   ├── activate_emsdk.dir
│   │   ├── clean_all.dir
│   │   ├── clean_web_build.dir
│   │   ├── cmake.check_cache
│   │   ├── cmake.verify_globs
│   │   ├── compile_web_build.dir
│   │   ├── configure_web_build.dir
│   │   ├── copy_assets.dir
│   │   ├── gzip_assets.dir
│   │   ├── inject_web_patch.dir
│   │   ├── pkgRedirects
│   │   ├── progress.marks
│   │   ├── push_web_build.dir
│   │   ├── raylib-cpp-cmake-template.dir
│   │   ├── rename_to_index.dir
│   │   ├── run-tests.dir
│   │   └── zip_web_build.dir
│   ├── CPackConfig.cmake
│   ├── CPackSourceConfig.cmake
│   ├── CTestTestfile.cmake
│   ├── Makefile
│   ├── Testing
│   │   └── Temporary
│   ├── TracyTargets.cmake
│   ├── _deps
│   │   ├── catch2-build
│   │   ├── catch2-src
│   │   ├── catch2-subbuild
│   │   ├── entt-build
│   │   ├── entt-src
│   │   ├── entt-subbuild
│   │   ├── glm-build
│   │   ├── glm-src
│   │   ├── glm-subbuild
│   │   ├── googletest-build
│   │   ├── googletest-src
│   │   ├── googletest-subbuild
│   │   ├── json-build
│   │   ├── json-src
│   │   ├── json-subbuild
│   │   ├── lua-build
│   │   ├── lua-src
│   │   ├── lua-subbuild
│   │   ├── magic_enum-build
│   │   ├── magic_enum-src
│   │   ├── magic_enum-subbuild
│   │   ├── random-build
│   │   ├── random-src
│   │   ├── random-subbuild
│   │   ├── raylib-build
│   │   ├── raylib-src
│   │   ├── raylib-subbuild
│   │   ├── snowhouse-build
│   │   ├── snowhouse-src
│   │   ├── snowhouse-subbuild
│   │   ├── spdlog-build
│   │   ├── spdlog-src
│   │   ├── spdlog-subbuild
│   │   ├── stduuid-build
│   │   ├── stduuid-src
│   │   └── stduuid-subbuild
│   ├── bin
│   ├── cmake_install.cmake
│   ├── lib
│   │   ├── libgpgoap.a
│   │   ├── libgtest.a
│   │   └── libgtest_main.a
│   ├── src
│   │   └── third_party
│   └── tests
│       ├── CMakeFiles
│       ├── CTestTestfile.cmake
│       ├── Makefile
│       ├── cmake_install.cmake
│       ├── unit_tests
│       ├── unit_tests[1]_include.cmake
│       └── unit_tests[1]_tests.cmake
├── claude.md
├── cmake
│   ├── inject_snippet.html
│   └── inject_snippet.ps1
├── docs
│   ├── README.md
│   ├── api
│   │   ├── lua_api_reference.md
│   │   ├── lua_camera_docs.md
│   │   ├── lua_quadtree_api.md
│   │   ├── particles_doc.md
│   │   ├── physics_docs.md
│   │   ├── timer_chaining.md
│   │   ├── timer_docs.md
│   │   ├── tracy_with_lua.md
│   │   ├── transform_local_render_callback_doc.md
│   │   ├── ui_helper_reference.md
│   │   └── working_with_sol.md
│   ├── assets
│   │   ├── BABEL_EDIT_WARNING.md
│   │   ├── LOCALIZATION_NOTES.md
│   │   ├── animation_WARNINGS.md
│   │   └── tileset_use_suggestions.md
│   ├── external
│   │   ├── color_README.md
│   │   ├── forma_README.md
│   │   ├── hump_README.md
│   │   └── object.md
│   ├── guides
│   │   ├── TESTING_GUIDE.md
│   │   ├── examples
│   │   ├── implementation-summaries
│   │   └── shaders
│   ├── project-management
│   │   ├── design
│   │   ├── game-jams
│   │   ├── todos
│   │   └── vertical_slice_plan.md
│   ├── systems
│   │   ├── advanced
│   │   ├── ai-behavior
│   │   ├── combat
│   │   ├── core
│   │   └── text-ui
│   ├── tools
│   │   └── DEBUGGING_LUA.md
│   └── tutorials
├── e
├── external
│   └── uieffect
│       └── src
├── imgui.ini
├── include
│   ├── GPGOAP
│   │   ├── CMakeLists.txt
│   │   ├── README.md
│   │   ├── astar.c
│   │   ├── astar.h
│   │   ├── goap.c
│   │   ├── goap.h
│   │   └── main.c
│   ├── fudge_pathfinding
│   │   ├── astar_search.h
│   │   ├── binary_heap.h
│   │   ├── edge.h
│   │   ├── grid_map.h
│   │   ├── grid_node.h
│   │   ├── grid_node_array.h
│   │   ├── hot_queue.h
│   │   ├── jump_point_map.h
│   │   ├── load_matrix.h
│   │   ├── map.h
│   │   ├── node_state.h
│   │   ├── position_map.h
│   │   ├── priority_queue.h
│   │   ├── priority_queue_stl.h
│   │   ├── rra.h
│   │   ├── search_stats.h
│   │   ├── up_heap.h
│   │   ├── util
│   │   └── vertex_matrix.h
│   ├── hfsm2
│   │   └── machine.hpp
│   ├── raygui.h
│   ├── raymath.h
│   ├── spine
│   │   ├── Animation.h
│   │   ├── AnimationState.h
│   │   ├── AnimationStateData.h
│   │   ├── Atlas.h
│   │   ├── AtlasAttachmentLoader.h
│   │   ├── Attachment.h
│   │   ├── AttachmentLoader.h
│   │   ├── AttachmentTimeline.h
│   │   ├── AttachmentType.h
│   │   ├── BlendMode.h
│   │   ├── BlockAllocator.h
│   │   ├── Bone.h
│   │   ├── BoneData.h
│   │   ├── BoundingBoxAttachment.h
│   │   ├── ClippingAttachment.h
│   │   ├── Color.h
│   │   ├── ColorTimeline.h
│   │   ├── ConstraintData.h
│   │   ├── ContainerUtil.h
│   │   ├── CurveTimeline.h
│   │   ├── Debug.h
│   │   ├── DeformTimeline.h
│   │   ├── DrawOrderTimeline.h
│   │   ├── Event.h
│   │   ├── EventData.h
│   │   ├── EventTimeline.h
│   │   ├── Extension.h
│   │   ├── HasRendererObject.h
│   │   ├── HashMap.h
│   │   ├── IkConstraint.h
│   │   ├── IkConstraintData.h
│   │   ├── IkConstraintTimeline.h
│   │   ├── Inherit.h
│   │   ├── InheritTimeline.h
│   │   ├── Json.h
│   │   ├── LinkedMesh.h
│   │   ├── Log.h
│   │   ├── MathUtil.h
│   │   ├── MeshAttachment.h
│   │   ├── MixBlend.h
│   │   ├── MixDirection.h
│   │   ├── PathAttachment.h
│   │   ├── PathConstraint.h
│   │   ├── PathConstraintData.h
│   │   ├── PathConstraintMixTimeline.h
│   │   ├── PathConstraintPositionTimeline.h
│   │   ├── PathConstraintSpacingTimeline.h
│   │   ├── Physics.h
│   │   ├── PhysicsConstraint.h
│   │   ├── PhysicsConstraintData.h
│   │   ├── PhysicsConstraintTimeline.h
│   │   ├── PointAttachment.h
│   │   ├── Pool.h
│   │   ├── PositionMode.h
│   │   ├── Property.h
│   │   ├── RTTI.h
│   │   ├── RegionAttachment.h
│   │   ├── RotateMode.h
│   │   ├── RotateTimeline.h
│   │   ├── ScaleTimeline.h
│   │   ├── Sequence.h
│   │   ├── SequenceTimeline.h
│   │   ├── ShearTimeline.h
│   │   ├── Skeleton.h
│   │   ├── SkeletonBinary.h
│   │   ├── SkeletonBounds.h
│   │   ├── SkeletonClipping.h
│   │   ├── SkeletonData.h
│   │   ├── SkeletonJson.h
│   │   ├── SkeletonRenderer.h
│   │   ├── Skin.h
│   │   ├── Slot.h
│   │   ├── SlotData.h
│   │   ├── SpacingMode.h
│   │   ├── SpineObject.h
│   │   ├── SpineString.h
│   │   ├── TextureLoader.h
│   │   ├── TextureRegion.h
│   │   ├── Timeline.h
│   │   ├── TransformConstraint.h
│   │   ├── TransformConstraintData.h
│   │   ├── TransformConstraintTimeline.h
│   │   ├── TranslateTimeline.h
│   │   ├── Triangulator.h
│   │   ├── Updatable.h
│   │   ├── Vector.h
│   │   ├── Version.h
│   │   ├── VertexAttachment.h
│   │   ├── Vertices.h
│   │   ├── dll.h
│   │   └── spine.h
│   └── taskflow-master
│       └── taskflow
├── new_drawing_primitives_example.md
├── output.txt
├── reorganize_docs.sh
├── scripts
│   └── run_tests.sh
├── shaders_to_build
│   ├── README.md
│   ├── download_godot_shaders.py
│   ├── godot_sources
│   │   ├── %e7%87%83%e7%83%a7-burn-2d.godot
│   │   ├── 2d-dissolve-with-burn-edge.godot
│   │   ├── 2d-drop-shadow.godot
│   │   ├── 2d-hologram-shader.godot
│   │   ├── 2d-holographic-card-shader.godot
│   │   ├── 2d-liquid-fill-inside-sphere-v2.godot
│   │   ├── 2d-rim-light-2.godot
│   │   ├── 2d-top-down-shadows-tilemap-ready.godot
│   │   ├── 2dfireworks.godot
│   │   ├── 2dradial-shine-2.godot
│   │   ├── animated-dotted-outline.godot
│   │   ├── bloody-pool-smooth-blood-trail.godot
│   │   ├── bounce-wave.godot
│   │   ├── bounding-battle-background.godot
│   │   ├── chromatic-aberration-sphere.godot
│   │   ├── chromatic-aberration-vignette.godot
│   │   ├── color-replacer-pixel-perfect-damage-shader.godot
│   │   ├── colorful-outline.godot
│   │   ├── custom-2d-light.godot
│   │   ├── darkened-blur.godot
│   │   ├── discrete-clouds.godot
│   │   ├── drop-in-pbr-2d-lighting-system-with-soft-shadows-and-ambient-occlusion.godot
│   │   ├── dynamic-glow.godot
│   │   ├── efficient-2d-pixel-outlines.godot
│   │   ├── extensible-color-palette-mk-2.godot
│   │   ├── falling-leaf-shader.godot
│   │   ├── infinite-scrolling-texture-with-angle-modifier.godot
│   │   ├── outline-for-atlas-texture-region.godot
│   │   ├── palette-shader-lospec-compatible.godot
│   │   ├── perspective-warp-skew-shader.godot
│   │   ├── phantom-star-for-godot-4-2.godot
│   │   ├── pixel-art-gradient.godot
│   │   ├── pixel-art-trail.godot
│   │   ├── pixel-perfect-dissolving.godot
│   │   ├── procedural-cyclic-slash.godot
│   │   ├── radial-fire-2d.godot
│   │   ├── radial-shine-highlight.godot
│   │   ├── rain-and-snow-with-parallax-scrolling-effect.godot
│   │   ├── random-displacement-animation-easy-ui-animation.godot
│   │   ├── spotlight-effect-transition-with-feathering-position.godot
│   │   ├── texture-based-liquid-effects.godot
│   │   ├── wobbly-grid.godot
│   │   └── wobbly-shader.godot
│   ├── shader_todo.md
│   └── shaders_for_sprite_effects.md
├── src
│   ├── components
│   │   ├── components.hpp
│   │   ├── graphics.hpp
│   │   └── particle.hpp
│   ├── core
│   │   ├── engine_context.cpp
│   │   ├── engine_context.hpp
│   │   ├── game.cpp
│   │   ├── game.hpp
│   │   ├── game_events.hpp
│   │   ├── game_init_cheatsheet.md
│   │   ├── globals.cpp
│   │   ├── globals.hpp
│   │   ├── graphics.cpp
│   │   ├── graphics.hpp
│   │   ├── gui.cpp
│   │   ├── gui.hpp
│   │   ├── init.cpp
│   │   ├── init.hpp
│   │   ├── misc_fuctions.hpp
│   │   ├── misc_functions.cpp
│   │   ├── ui_button_callbacks.hpp
│   │   ├── ui_definitions.cpp
│   │   └── ui_definitions.hpp
│   ├── main.cpp
│   ├── minshell.html
│   ├── systems
│   │   ├── ai
│   │   ├── anim_system.cpp
│   │   ├── anim_system.hpp
│   │   ├── camera
│   │   ├── chipmunk_objectivec
│   │   ├── collision
│   │   ├── composable_mechanics
│   │   ├── entity_gamestate_management
│   │   ├── event
│   │   ├── factory
│   │   ├── fade
│   │   ├── gif
│   │   ├── gui_indicator
│   │   ├── input
│   │   ├── layer
│   │   ├── ldtk_loader
│   │   ├── ldtk_rule_import
│   │   ├── line_of_sight
│   │   ├── localization
│   │   ├── main_loop_enhancement
│   │   ├── nine_patch
│   │   ├── palette
│   │   ├── particles
│   │   ├── physics
│   │   ├── random
│   │   ├── reflection
│   │   ├── screenshake
│   │   ├── scripting
│   │   ├── second_order_dynamics
│   │   ├── shaders
│   │   ├── sound
│   │   ├── spring
│   │   ├── systems.cpp
│   │   ├── systems.hpp
│   │   ├── text
│   │   ├── timer
│   │   ├── transform
│   │   ├── tutorial
│   │   ├── ui
│   │   └── uuid
│   ├── third_party
│   │   ├── GPGOAP
│   │   ├── LuaJIT-2.1
│   │   ├── chipmunk
│   │   ├── fmt
│   │   ├── imgui_console
│   │   ├── ldtk_loader
│   │   ├── ldtkimport
│   │   ├── luajit-cmake-master
│   │   ├── navmesh
│   │   ├── objectpool-master
│   │   ├── rlImGui
│   │   ├── sol2
│   │   ├── spine_impl
│   │   ├── tracy-master
│   │   └── unify
│   └── util
│       ├── common_headers.hpp
│       ├── easing.cpp
│       ├── easing.h
│       ├── random_utils.cpp
│       ├── random_utils.hpp
│       ├── text_processing.hpp
│       ├── utilities.cpp
│       ├── utilities.hpp
│       └── web_glad_shim.hpp
├── test.html
├── tests
│   ├── CMakeLists.txt
│   ├── helpers
│   │   └── test_stubs.cpp
│   ├── mocks
│   │   └── mock_engine_context.hpp
│   └── unit
│       ├── test_binding_recorder.cpp
│       ├── test_color_utils.cpp
│       ├── test_component_cache.cpp
│       ├── test_engine_context.cpp
│       ├── test_input_state.cpp
│       ├── test_physics_manager.cpp
│       ├── test_shader_system.cpp
│       ├── test_transform_hooks.cpp
│       ├── test_utilities.cpp
│       └── test_uuid.cpp
└── todo_from_snkrx
    └── done
        ├── camera(1).lua
        ├── enemies.lua
        ├── graphics.lua
        ├── objects.lua
        ├── physics.lua
        ├── player.lua
        ├── shared.lua
        ├── steering.lua
        └── table.lua

312 directories, 685 files (depth <= 3)
```

To refresh this snapshot, re-run the generator:

```bash
python - <<'PY'
import os

root = '.'
max_depth = 3
include_hidden = False

dir_count = 0
file_count = 0

def iter_entries(path):
    names = []
    for name in os.listdir(path):
        if not include_hidden and name.startswith('.'):
            continue
        names.append(name)
    names.sort()
    return names

def walk(path, prefix='', depth=0):
    global dir_count, file_count
    entries = iter_entries(path)
    total = len(entries)
    for idx, name in enumerate(entries):
        full = os.path.join(path, name)
        is_dir = os.path.isdir(full)
        connector = '└── ' if idx == total - 1 else '├── '
        print(f\"{prefix}{connector}{name}\")
        if is_dir:
            dir_count += 1
            if depth + 1 < max_depth:
                new_prefix = f\"{prefix}{'    ' if idx == total - 1 else '│   '}\"
                walk(full, new_prefix, depth + 1)
        else:
            file_count += 1

print(root)
walk(root, depth=0)
print(f\"\\n{dir_count} directories, {file_count} files (depth <= {max_depth})\")
PY
```
