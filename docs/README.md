# Game Jam Template - Documentation Index

Welcome to the comprehensive documentation for the Game Jam Template. This index organizes all documentation into logical categories for easy navigation.

## Quick Start

- [Main README](../README.md) - Project overview and setup
- [Changelog](../CHANGELOG.md) - Recent changes and history
- [Tracy Profiling](../USING_TRACY.md) - Performance profiling guide
- [Lua Debugging](assets/DEBUGGING_LUA.md) - Debug your Lua scripts
- [Game Design Context](../GAME_DESIGN_CONTEXT.md) - Central gameplay/design tenets

## Content Creation

- [Content Overview](content-creation/CONTENT_OVERVIEW.md) - Quick index for adding game content
- [Adding Cards](content-creation/ADDING_CARDS.md) - Action, modifier, trigger cards
- [Adding Jokers](content-creation/ADDING_JOKERS.md) - Passive artifacts
- [Adding Triggers](content-creation/ADDING_TRIGGERS.md) - Trigger cards & event wiring
- [Adding Projectiles](content-creation/ADDING_PROJECTILES.md) - Projectile presets
- [Adding Avatars](content-creation/ADDING_AVATARS.md) - Ascension system

## Architecture & Standards
- [System Architecture Overview](guides/SYSTEM_ARCHITECTURE.md)
- [C++ Documentation Standards](guides/DOCUMENTATION_STANDARDS.md)

## API Documentation

### Core Lua APIs
- **[Lua Scripting Reference](api/lua_api_reference.md)** - Current bindings by system, sourced from generated `chugget_code_definitions.lua`
- [Camera System](api/lua_camera_docs.md) - Camera controls, follow modes, effects
- [Physics System](api/physics_docs.md) - Physics, collision, steering behaviors
- [Particle System](api/particles_doc.md) - Particle creation and emitters
- [Timer System](api/timer_docs.md) - Timer utilities and chaining (**bindings currently disabled; see doc header**)
- [Transform Local Rendering](api/transform_local_render_callback_doc.md) - Local-space rendering

### Specialized APIs
- **[Combat Systems API](api/combat-systems.md)** - Triggers, status effects, and equipment
- [Quadtree API](api/lua_quadtree_api.md) - Spatial partitioning
- [UI Helper Reference](api/ui_helper_reference.md) - UI building utilities
- [UI DSL Reference](api/ui-dsl-reference.md) - Comprehensive guide to the UI DSL system
- [Sprite Panels & Decorations](api/sprite-panels.md) - Custom sprite panels, buttons, and decorations
- [Sol2 Integration](api/working_with_sol.md) - C++/Lua binding guide

## System Documentation

### Core Systems
- [Entity State Management](systems/core/entity_state_management_doc.md) - Entity lifecycle and state tags
- [Static UI Text System](systems/text-ui/static_ui_text_system_doc.md) - UI text rendering
- [Command Buffer Text Renderer](systems/text-ui/command_buffer_text.md) - Per-character effects over the layer command buffer

### AI & Behavior
- [AI System README](systems/ai-behavior/AI_README.md) - GOAP-based AI system
- [AI Caveats](systems/ai-behavior/AI_CAVEATS.md) - Known issues and workarounds
- [Nodemap System](systems/ai-behavior/nodemap_README.md) - Node-based behavior system
- [MonoBehavior System](systems/ai-behavior/monobehavior_readme.md) - Component system

### Combat Systems
- [Combat Architecture](systems/combat/ARCHITECTURE.md) - Combat system design
- [Combat README](systems/combat/README.md) - Combat system overview
- [Quick Reference](systems/combat/QUICK_REFERENCE.md) - Combat API quick reference
- [Integration Guide](systems/combat/INTEGRATION_GUIDE.md) - Adding combat to your game
- [Projectile System](systems/combat/PROJECTILE_SYSTEM_DOCUMENTATION.md) - Projectile mechanics
- [Projectile Architecture](systems/combat/PROJECTILE_ARCHITECTURE.md) - Projectile design
- [Wand Integration](systems/combat/WAND_INTEGRATION_GUIDE.md) - Wand system guide
- [Wand Execution Architecture](systems/combat/WAND_EXECUTION_ARCHITECTURE.md) - Wand internals
- [Integration Tutorial (WIP)](systems/combat/integration_tutorial_WIP.md) - Step-by-step tutorial

### Advanced Features
- [Controller Navigation](systems/advanced/controller_navigation.md) - Gamepad input handling

## Guides & Tutorials

### Security & Protection
- [Ownership System](guides/OWNERSHIP_SYSTEM.md) - Game theft prevention and watermarking

### Shader Development
- [Raylib Shader Guide](guides/shaders/RAYLIB_SHADER_GUIDE.md) - Writing shaders for Raylib
- [Shader Snippets](guides/shaders/SHADER_SNIPPETS.md) - Reusable shader code
- [Snippets for Later](guides/shaders/SNIPPETS_FOR_LATER.md) - Future shader ideas
- [Sprite Atlas UV Remapping](guides/shaders/sprite_atlas_uv_remapping_snippet.md) - Atlas shaders
- [Sprite Bound Expansion](guides/shaders/sprite_bound_expansion_snippet.md) - Shader bound tricks
- [Web Shader Error Messages](guides/shaders/shader_web_error_msgs.md) - WebGL shader debugging

### Code Examples
- [Cheatsheet](guides/examples/cheatsheet.md) - Quick code snippets
- [SNKRX Techniques](guides/examples/SNKRX_code_snippets_and_techniques.md) - Patterns from SNKRX
- [Deformable Chipmunk](guides/examples/DeformableChipmunkSnippet.md) - Soft-body physics
- [9-Slice U9 Config](guides/examples/9slice_u9_configurable_snippet.md) - 9-slice UI elements
- [String Formatting](guides/examples/string_formatting.md) - Text formatting utilities
- [Defined Events List](guides/examples/list_of_defined_events.md) - Event system reference
- [Tracy with Lua](guides/examples/tracy_with_lua.md) - Profiling Lua code

### Implementation Summaries
- [Applied Bug Fixes](guides/implementation-summaries/APPLIED_BUG_FIXES.md) - Bug fix log
- [Combat Loop Summary](guides/implementation-summaries/COMBAT_LOOP_SUMMARY.md) - Combat implementation
- [Pipeline Camera Fix V2](guides/implementation-summaries/PIPELINE_CAMERA_FIX_V2.md) - Camera rendering fix
- [Pipeline Diagnostics Added](guides/implementation-summaries/PIPELINE_DIAGNOSTICS_ADDED.md) - Debug tools
- [Pipeline Quirks Fixed](guides/implementation-summaries/PIPELINE_QUIRKS_FIXED.md) - Rendering fixes
- [Projectile Physics Integration](guides/implementation-summaries/PROJECTILE_PHYSICS_INTEGRATION.md) - Physics integration
- [Projectile System Report](guides/implementation-summaries/PROJECTILE_SYSTEM_REPORT.md) - Projectile system
- [Projectile Test Integration](guides/implementation-summaries/PROJECTILE_TEST_INTEGRATION.md) - Testing
- [RAII Guards Implementation](guides/implementation-summaries/RAII_GUARDS_IMPLEMENTATION_SUMMARY.md) - RAII patterns
- [Shader Pipeline Refactor](guides/implementation-summaries/SHADER_PIPELINE_REFACTOR_SUMMARY.md) - Pipeline redesign
- [Shader Pipeline Safety Guide](guides/implementation-summaries/SHADER_PIPELINE_SAFETY_GUIDE.md) - Safe shader usage
- [Task 4 Combat Loop Report](guides/implementation-summaries/TASK_4_COMBAT_LOOP_REPORT.md) - Combat task report
- [Task 5 Bug Fixes Report](guides/implementation-summaries/TASK_5_BUG_FIXES_REPORT.md) - Bug fix task
- [Wand Execution Report](guides/implementation-summaries/WAND_EXECUTION_REPORT.md) - Wand implementation
- [LDtk Integration Notes](guides/implementation-summaries/LDTK_INTEGRATION_NOTES.md) - LDtk config/Lua/collider flow

## External Libraries

- [Forma Library](external/forma_README.md) - Forma utilities
- [HUMP Library](external/hump_README.md) - Helper Utilities for Massive Progression
- [Object.lua](external/object.md) - Object-oriented programming library
- [Color System](external/color_README.md) - Color utilities

## Asset Documentation

### Graphics
- [Animation Warnings](assets/animation_WARNINGS.md) - Animation gotchas
- [Tileset Use Suggestions](assets/tileset_use_suggestions.md) - Tileset best practices

### Localization
- [Babel Edit Warning](assets/BABEL_EDIT_WARNING.md) - Localization tool notes
- [Localization Notes](assets/LOCALIZATION_NOTES.md) - Internationalization guide

## Tools & Debugging

- [Debugging Lua](tools/DEBUGGING_LUA.md) - Lua debugging techniques
- [Tracy Profiling](../USING_TRACY.md) - Performance profiling
- [Testing Plan](../TESTING_PLAN.md) - Testing strategies

## Project Management

### TODO Lists
- [Main TODO](project-management/todos/TODO.md) - Primary task list
- [Design TODO](project-management/todos/TODO_design.md) - Design tasks
- [Documentation TODO](project-management/todos/TODO_documentation.md) - ⚠️ Now integrated into API docs
- [Devlog TODO](project-management/todos/TODO_devlog.md) - Development log
- [Implemented Features](project-management/todos/TODO_implemented_features_which_need_testing.md) - Test queue
- [Prototype TODO](project-management/todos/TODO_prototype.md) - Prototype tasks
- [Stat Planning](project-management/todos/TODO_stat_planning.md) - Game balance planning
- [Systems Refined](project-management/todos/TODO_systems_refined.md) - System architecture

### Design Documents
- [Testing Plan](project-management/design/TESTING_PLAN.md) - QA strategy

### Game Jam Archives
- [Jame Gam #50](project-management/game-jams/TODO_JAME_GAM_50.md) - Jam #50 postmortem
- [Jame Gam #51](project-management/game-jams/TODO_JAME_GAM_51.md) - Jam #51 postmortem
- [Weather or Not Scripts (Archived)](project-management/game-jams/jame_gam_weather_or_not/) - Full game archive

---

## Navigation Tips

- Use Ctrl+F (Cmd+F) to search this page for specific topics
- Most documentation includes code examples you can copy-paste
- Check the [Main TODO](project-management/todos/TODO.md) for current project status
- All paths are relative to the repository root

## Contributing to Documentation

When adding new documentation:
1. Place files in the appropriate category directory
2. Update this index with a link
3. Include code examples where possible
4. Cross-reference related documentation

---

**Last Updated**: 2026-01-13


