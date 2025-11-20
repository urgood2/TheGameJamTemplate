#!/bin/bash

# Create all necessary subdirectories
mkdir -p docs/api docs/systems docs/tutorials docs/guides docs/external docs/assets docs/tools

# Move root-level guide files to docs/guides/
git mv SHADER_PIPELINE_REFACTOR_SUMMARY.md docs/guides/
git mv SHADER_PIPELINE_SAFETY_GUIDE.md docs/guides/
git mv PIPELINE_DIAGNOSTICS_ADDED.md docs/guides/
git mv PIPELINE_CAMERA_FIX_V2.md docs/guides/
git mv PIPELINE_QUIRKS_FIXED.md docs/guides/
git mv RAII_GUARDS_IMPLEMENTATION_SUMMARY.md docs/guides/
git mv new_drawing_primitives_example.md docs/guides/
git mv 9slice_u9_configurable_snippet.md docs/guides/
git mv DeformableChipmunkSnippet.md docs/guides/

# Move assets/scripts/ API files to docs/api/
git mv assets/scripts/cheatsheet.md docs/api/
git mv assets/scripts/lua_camera_docs.md docs/api/
git mv assets/scripts/lua_quadtree_api.md docs/api/
git mv assets/scripts/working_with_sol.md docs/api/

# Move assets/scripts/ system files to docs/systems/
git mv assets/scripts/physics_docs.md docs/systems/
git mv assets/scripts/particles_doc.md docs/systems/
git mv assets/scripts/timer_docs.md docs/systems/
git mv assets/scripts/timer_chaining.md docs/systems/
git mv assets/scripts/static_ui_text_system_doc.md docs/systems/
git mv assets/scripts/controller_navigation.md docs/systems/
git mv assets/scripts/entity_state_management_doc.md docs/systems/
git mv assets/scripts/transform_local_render_callback_doc.md docs/systems/
git mv assets/scripts/tracy_with_lua.md docs/systems/

# Move AI system files to docs/systems/
git mv assets/scripts/ai/AI_README.md docs/systems/
git mv assets/scripts/ai/AI_CAVEATS.md docs/systems/

# Move combat system files to docs/systems/ (with renaming)
git mv assets/scripts/combat/README.md docs/systems/combat_README.md
git mv assets/scripts/combat/integration_tutorial_WIP.md docs/systems/combat_integration_tutorial_WIP.md

# Move monobehavior file to docs/systems/
git mv assets/scripts/monobehavior/monobehavior_readme.md docs/systems/

# Move nodemap file to docs/systems/ (with renaming)
git mv assets/scripts/nodemap/README.md docs/systems/nodemap_README.md

# Move UI file to docs/systems/
git mv assets/scripts/ui/ui_helper_reference.md docs/systems/

# Move external library files to docs/external/
git mv assets/scripts/external/forma/README.md docs/external/forma_README.md
git mv assets/scripts/external/hump/README.md docs/external/hump_README.md
git mv assets/scripts/external/object.md docs/external/

# Move color README to docs/external/ (with renaming)
git mv assets/scripts/color/README.md docs/external/color_README.md

# Move tutorial files to docs/tutorials/
git mv assets/scripts/tutorial/string_formatting.md docs/tutorials/
git mv assets/scripts/tutorial/list_of_defined_events.md docs/tutorials/
git mv assets/scripts/DEBUGGING_LUA.md docs/tutorials/

# Move src/core/ tutorial to docs/tutorials/
git mv src/core/game_init_cheatsheet.md docs/tutorials/

# Move src/systems/ documentation to docs/systems/ (with renaming where needed)
git mv src/systems/layer/tutorial.md docs/systems/layer_tutorial.md
git mv src/systems/physics/steering_readme.md docs/systems/
git mv src/systems/spring/spring_lua.md docs/systems/
git mv src/systems/input/input_action_binding_usage.md docs/systems/
git mv src/systems/reflection/readme.md docs/systems/reflection_readme.md
git mv src/systems/composable_mechanics/integration_notes.md docs/systems/composable_mechanics_integration_notes.md

# Move text system documentation to docs/systems/ (with renaming)
git mv src/systems/text/effects_documentation.md docs/systems/text_effects_documentation.md
git mv src/systems/text/dynamic_text_documentation.md docs/systems/text_dynamic_text_documentation.md
git mv src/systems/text/static_ui_text_documentation.md docs/systems/text_static_ui_text_documentation.md

# Move assets/graphics/ documentation to docs/assets/
git mv assets/graphics/animation_WARNINGS.md docs/assets/
git mv "assets/graphics/tileset use suggestions.md" docs/assets/tileset_use_suggestions.md

# Move assets/localization/ documentation to docs/assets/
git mv assets/localization/LOCALIZATION_NOTES.md docs/assets/
git mv assets/localization/BABEL_EDIT_WARNING.md docs/assets/

# Move assets/shaders/ documentation to docs/guides/
git mv assets/shaders/sprite_atlas_uv_remapping_snippet.md docs/guides/
git mv assets/shaders/sprite_bound_expansion_snippet.md docs/guides/
git mv assets/shaders/shader_web_error_msgs.md docs/guides/

# Move SNKRX code snippets to docs/guides/
git mv assets/SNKRX_code_snippets_and_techniques.md docs/guides/

# Move USING_TRACY.md to docs/tools/
git mv USING_TRACY.md docs/tools/

echo "All documentation files have been reorganized successfully!"
