# Game Engine Documentation

Welcome to the game engine documentation! This directory contains comprehensive documentation for all engine features, systems, and APIs.

## Quick Start

- [Lua Scripting Cheatsheet](api/cheatsheet.md) - Quick reference for Lua scripting
- [Lua API Reference](api/lua_api_reference.md) - Comprehensive API documentation

## Documentation Structure

### API Documentation (`api/`)
Complete API references for Lua scripting and engine features.

- [Lua API Reference](api/lua_api_reference.md) - Comprehensive feature documentation
- [Lua Scripting Cheatsheet](api/cheatsheet.md) - Quick reference guide
- [Lua Camera Documentation](api/lua_camera_docs.md) - Camera system API
- [Lua Quadtree API](api/lua_quadtree_api.md) - Spatial partitioning
- [Working with Sol2](api/working_with_sol.md) - C++ to Lua bindings

### System Documentation (`systems/`)
Detailed documentation for individual engine systems.

#### Core Systems
- [Layer System Tutorial](systems/layer_tutorial.md) - Rendering layers
- [Physics System](systems/physics_docs.md) - Physics and collision
- [Particle System](systems/particles_doc.md) - Particle effects
- [Timer System](systems/timer_docs.md) - Timing and scheduling
- [Timer Chaining](systems/timer_chaining.md) - Advanced timer patterns

#### Text & UI
- [Static UI Text System](systems/static_ui_text_system_doc.md)
- [Dynamic Text Documentation](systems/text_dynamic_text_documentation.md)
- [Text Effects Documentation](systems/text_effects_documentation.md)
- [UI Helper Reference](systems/ui_helper_reference.md)

#### AI & Behavior
- [AI System README](systems/ai_README.md) - GOAP AI overview
- [AI Caveats](systems/ai_CAVEATS.md) - Known issues and limitations
- [Monobehavior System](systems/monobehavior_readme.md) - Component behavior patterns
- [Entity State Management](systems/entity_state_management_doc.md)

#### Advanced Features
- [Transform Local Render Callbacks](systems/transform_local_render_callback_doc.md)
- [Input Action Binding Usage](systems/input_action_binding_usage.md)
- [Controller Navigation](systems/controller_navigation.md)
- [Spring System (Lua)](systems/spring_lua.md)
- [Steering Behaviors](systems/steering_readme.md)
- [Composable Mechanics Integration](systems/composable_mechanics_integration_notes.md)
- [Reflection System](systems/reflection_readme.md)
- [Nodemap System](systems/nodemap_README.md)

#### Combat System
- [Combat System README](systems/combat_README.md)
- [Combat Integration Tutorial (WIP)](systems/combat_integration_tutorial_WIP.md)

### Tutorial Documentation (`tutorials/`)
Step-by-step guides and learning resources.

- [String Formatting](tutorials/string_formatting.md)
- [List of Defined Events](tutorials/list_of_defined_events.md)
- [Game Init Cheatsheet](tutorials/game_init_cheatsheet.md)
- [Debugging Lua](tutorials/DEBUGGING_LUA.md)

### Technical Guides (`guides/`)
Implementation details and technical references.

#### Shaders & Rendering
- [Shader Pipeline Refactor Summary](guides/SHADER_PIPELINE_REFACTOR_SUMMARY.md)
- [Shader Pipeline Safety Guide](guides/SHADER_PIPELINE_SAFETY_GUIDE.md)
- [Pipeline Diagnostics](guides/PIPELINE_DIAGNOSTICS_ADDED.md)
- [Pipeline Camera Fix V2](guides/PIPELINE_CAMERA_FIX_V2.md)
- [Pipeline Quirks Fixed](guides/PIPELINE_QUIRKS_FIXED.md)
- [Shader Web Error Messages](guides/shader_web_error_msgs.md)

#### Code Examples & Snippets
- [New Drawing Primitives Example](guides/new_drawing_primitives_example.md)
- [9-Slice U9 Configurable Snippet](guides/9slice_u9_configurable_snippet.md)
- [Deformable Chipmunk Snippet](guides/DeformableChipmunkSnippet.md)
- [Sprite Atlas UV Remapping](guides/sprite_atlas_uv_remapping_snippet.md)
- [Sprite Bound Expansion](guides/sprite_bound_expansion_snippet.md)
- [SNKRX Code Snippets](guides/SNKRX_code_snippets_and_techniques.md)

#### Implementation Summaries
- [RAII Guards Implementation Summary](guides/RAII_GUARDS_IMPLEMENTATION_SUMMARY.md)

### External Libraries (`external/`)
Documentation for third-party libraries.

- [Forma](external/forma_README.md) - Layout library
- [HUMP](external/hump_README.md) - Helper Utilities for Massive Progression
- [Object.lua](external/object.md) - Class/OOP library
- [Color System](external/color_README.md)

### Asset Documentation (`assets/`)
Documentation specific to game assets.

- [Animation Warnings](assets/animation_WARNINGS.md)
- [Tileset Use Suggestions](assets/tileset_use_suggestions.md)
- [Localization Notes](assets/LOCALIZATION_NOTES.md)
- [BabelEdit Warning](assets/BABEL_EDIT_WARNING.md)

### Tools & Debugging (`tools/`)
Development and debugging tools documentation.

- [Using Tracy Profiler](tools/USING_TRACY.md)
- [Tracy with Lua](tools/tracy_with_lua.md)

## Project Management

### TODO Lists
Active development tracking:
- [TODO.md](../TODO.md) - Main TODO list
- [TODO Outstanding Bugs](../TODO_outstanding_bugs.md)
- [TODO Implemented Features Needing Testing](../TODO_implemented_features_which_need_testing.md)

### Design Documents
- [TODO Design](../TODO_design.md) - Design planning
- [TODO Stat Planning](../TODO_stat_planning.md) - Game statistics design
- [TODO Devlog](../TODO_devlog.md) - Development log

### Game Jam Archives
- [TODO Prototype](../TODO_prototype.md)
- [TODO JAME GAM 50](../TODO_JAME_GAM_50.md)
- [TODO JAME GAM 51](../TODO_JAME_GAM_51.md)

## Contributing

When adding new documentation:
1. Place API documentation in `docs/api/`
2. Place system documentation in `docs/systems/`
3. Place tutorials in `docs/tutorials/`
4. Place technical guides in `docs/guides/`
5. Update this index with a link to your new documentation

## License

Code other than from https://github.com/tupini07/raylib-cpp-cmake-template is copyrighted by Chugget. Please do not use without permission.
