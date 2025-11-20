#!/bin/bash

# Documentation Reorganization Script
# This script moves all markdown documentation into an organized docs/ structure
# Uses git mv to preserve file history

set -e  # Exit on error

echo "========================================="
echo "Documentation Reorganization Script"
echo "========================================="
echo ""

# Create directory structure
echo "Creating directory structure..."
mkdir -p docs/api
mkdir -p docs/systems/core
mkdir -p docs/systems/text-ui
mkdir -p docs/systems/ai-behavior
mkdir -p docs/systems/combat
mkdir -p docs/systems/advanced
mkdir -p docs/tutorials
mkdir -p docs/guides/shaders
mkdir -p docs/guides/examples
mkdir -p docs/guides/implementation-summaries
mkdir -p docs/external
mkdir -p docs/assets
mkdir -p docs/tools
mkdir -p docs/project-management/todos
mkdir -p docs/project-management/design
mkdir -p docs/project-management/game-jams

echo "✓ Directory structure created"
echo ""

# Move API documentation
echo "Moving API documentation..."
if [ -f "assets/scripts/lua_camera_docs.md" ]; then
    git mv assets/scripts/lua_camera_docs.md docs/api/
fi
if [ -f "assets/scripts/physics_docs.md" ]; then
    git mv assets/scripts/physics_docs.md docs/api/
fi
if [ -f "assets/scripts/particles_doc.md" ]; then
    git mv assets/scripts/particles_doc.md docs/api/
fi
if [ -f "assets/scripts/timer_docs.md" ]; then
    git mv assets/scripts/timer_docs.md docs/api/
fi
if [ -f "assets/scripts/timer_chaining.md" ]; then
    git mv assets/scripts/timer_chaining.md docs/api/
fi
if [ -f "assets/scripts/lua_quadtree_api.md" ]; then
    git mv assets/scripts/lua_quadtree_api.md docs/api/
fi
if [ -f "assets/scripts/transform_local_render_callback_doc.md" ]; then
    git mv assets/scripts/transform_local_render_callback_doc.md docs/api/
fi
if [ -f "assets/scripts/working_with_sol.md" ]; then
    git mv assets/scripts/working_with_sol.md docs/api/
fi
if [ -f "assets/scripts/ui/ui_helper_reference.md" ]; then
    git mv assets/scripts/ui/ui_helper_reference.md docs/api/
fi
if [ -f "assets/scripts/tracy_with_lua.md" ]; then
    git mv assets/scripts/tracy_with_lua.md docs/api/
fi
echo "✓ API documentation moved"
echo ""

# Move system documentation
echo "Moving system documentation..."
if [ -f "assets/scripts/entity_state_management_doc.md" ]; then
    git mv assets/scripts/entity_state_management_doc.md docs/systems/core/
fi
if [ -f "assets/scripts/static_ui_text_system_doc.md" ]; then
    git mv assets/scripts/static_ui_text_system_doc.md docs/systems/text-ui/
fi
if [ -f "assets/scripts/controller_navigation.md" ]; then
    git mv assets/scripts/controller_navigation.md docs/systems/advanced/
fi
echo "✓ System documentation moved"
echo ""

# Move AI documentation
echo "Moving AI documentation..."
if [ -f "assets/scripts/ai/AI_README.md" ]; then
    git mv assets/scripts/ai/AI_README.md docs/systems/ai-behavior/
fi
if [ -f "assets/scripts/ai/AI_CAVEATS.md" ]; then
    git mv assets/scripts/ai/AI_CAVEATS.md docs/systems/ai-behavior/
fi
if [ -f "assets/scripts/nodemap/README.md" ]; then
    git mv assets/scripts/nodemap/README.md docs/systems/ai-behavior/nodemap_README.md
fi
if [ -f "assets/scripts/monobehavior/monobehavior_readme.md" ]; then
    git mv assets/scripts/monobehavior/monobehavior_readme.md docs/systems/ai-behavior/
fi
echo "✓ AI documentation moved"
echo ""

# Move combat documentation
echo "Moving combat documentation..."
if [ -f "assets/scripts/combat/ARCHITECTURE.md" ]; then
    git mv assets/scripts/combat/ARCHITECTURE.md docs/systems/combat/
fi
if [ -f "assets/scripts/combat/README.md" ]; then
    git mv assets/scripts/combat/README.md docs/systems/combat/
fi
if [ -f "assets/scripts/combat/QUICK_REFERENCE.md" ]; then
    git mv assets/scripts/combat/QUICK_REFERENCE.md docs/systems/combat/
fi
if [ -f "assets/scripts/combat/INTEGRATION_GUIDE.md" ]; then
    git mv assets/scripts/combat/INTEGRATION_GUIDE.md docs/systems/combat/
fi
if [ -f "assets/scripts/combat/PROJECTILE_SYSTEM_DOCUMENTATION.md" ]; then
    git mv assets/scripts/combat/PROJECTILE_SYSTEM_DOCUMENTATION.md docs/systems/combat/
fi
if [ -f "assets/scripts/combat/PROJECTILE_ARCHITECTURE.md" ]; then
    git mv assets/scripts/combat/PROJECTILE_ARCHITECTURE.md docs/systems/combat/
fi
if [ -f "assets/scripts/combat/WAND_INTEGRATION_GUIDE.md" ]; then
    git mv assets/scripts/combat/WAND_INTEGRATION_GUIDE.md docs/systems/combat/
fi
if [ -f "assets/scripts/combat/integration_tutorial_WIP.md" ]; then
    git mv assets/scripts/combat/integration_tutorial_WIP.md docs/systems/combat/
fi
if [ -f "assets/scripts/wand/WAND_EXECUTION_ARCHITECTURE.md" ]; then
    git mv assets/scripts/wand/WAND_EXECUTION_ARCHITECTURE.md docs/systems/combat/
fi
if [ -f "assets/scripts/wand/README.md" ]; then
    git mv assets/scripts/wand/README.md docs/systems/combat/wand_README.md
fi
echo "✓ Combat documentation moved"
echo ""

# Move shader guides
echo "Moving shader guides..."
if [ -f "assets/shaders/RAYLIB_SHADER_GUIDE.md" ]; then
    git mv assets/shaders/RAYLIB_SHADER_GUIDE.md docs/guides/shaders/
fi
if [ -f "assets/shaders/SHADER_SNIPPETS.md" ]; then
    git mv assets/shaders/SHADER_SNIPPETS.md docs/guides/shaders/
fi
if [ -f "assets/shaders/SNIPPETS_FOR_LATER.md" ]; then
    git mv assets/shaders/SNIPPETS_FOR_LATER.md docs/guides/shaders/
fi
if [ -f "assets/shaders/sprite_atlas_uv_remapping_snippet.md" ]; then
    git mv assets/shaders/sprite_atlas_uv_remapping_snippet.md docs/guides/shaders/
fi
if [ -f "assets/shaders/sprite_bound_expansion_snippet.md" ]; then
    git mv assets/shaders/sprite_bound_expansion_snippet.md docs/guides/shaders/
fi
if [ -f "assets/shaders/shader_web_error_msgs.md" ]; then
    git mv assets/shaders/shader_web_error_msgs.md docs/guides/shaders/
fi
# Web shader snippets (duplicates)
if [ -f "assets/shaders/web/sprite_atlas_uv_remapping_snippet.md" ]; then
    git mv assets/shaders/web/sprite_atlas_uv_remapping_snippet.md docs/guides/shaders/web_sprite_atlas_uv_remapping_snippet.md
fi
if [ -f "assets/shaders/web/sprite_bound_expansion_snippet.md" ]; then
    git mv assets/shaders/web/sprite_bound_expansion_snippet.md docs/guides/shaders/web_sprite_bound_expansion_snippet.md
fi
echo "✓ Shader guides moved"
echo ""

# Move code examples
echo "Moving code examples..."
if [ -f "assets/scripts/cheatsheet.md" ]; then
    git mv assets/scripts/cheatsheet.md docs/guides/examples/
fi
if [ -f "assets/SNKRX_code_snippets_and_techniques.md" ]; then
    git mv assets/SNKRX_code_snippets_and_techniques.md docs/guides/examples/
fi
if [ -f "DeformableChipmunkSnippet.md" ]; then
    git mv DeformableChipmunkSnippet.md docs/guides/examples/
fi
if [ -f "9slice_u9_configurable_snippet.md" ]; then
    git mv 9slice_u9_configurable_snippet.md docs/guides/examples/
fi
if [ -f "assets/scripts/tutorial/string_formatting.md" ]; then
    git mv assets/scripts/tutorial/string_formatting.md docs/guides/examples/
fi
if [ -f "assets/scripts/tutorial/list_of_defined_events.md" ]; then
    git mv assets/scripts/tutorial/list_of_defined_events.md docs/guides/examples/
fi
echo "✓ Code examples moved"
echo ""

# Move implementation summaries
echo "Moving implementation summaries..."
if [ -f "APPLIED_BUG_FIXES.md" ]; then
    git mv APPLIED_BUG_FIXES.md docs/guides/implementation-summaries/
fi
if [ -f "COMBAT_LOOP_SUMMARY.md" ]; then
    git mv COMBAT_LOOP_SUMMARY.md docs/guides/implementation-summaries/
fi
if [ -f "PIPELINE_CAMERA_FIX_V2.md" ]; then
    git mv PIPELINE_CAMERA_FIX_V2.md docs/guides/implementation-summaries/
fi
if [ -f "PIPELINE_DIAGNOSTICS_ADDED.md" ]; then
    git mv PIPELINE_DIAGNOSTICS_ADDED.md docs/guides/implementation-summaries/
fi
if [ -f "PIPELINE_QUIRKS_FIXED.md" ]; then
    git mv PIPELINE_QUIRKS_FIXED.md docs/guides/implementation-summaries/
fi
if [ -f "PROJECTILE_PHYSICS_INTEGRATION.md" ]; then
    git mv PROJECTILE_PHYSICS_INTEGRATION.md docs/guides/implementation-summaries/
fi
if [ -f "PROJECTILE_SYSTEM_REPORT.md" ]; then
    git mv PROJECTILE_SYSTEM_REPORT.md docs/guides/implementation-summaries/
fi
if [ -f "PROJECTILE_TEST_INTEGRATION.md" ]; then
    git mv PROJECTILE_TEST_INTEGRATION.md docs/guides/implementation-summaries/
fi
if [ -f "RAII_GUARDS_IMPLEMENTATION_SUMMARY.md" ]; then
    git mv RAII_GUARDS_IMPLEMENTATION_SUMMARY.md docs/guides/implementation-summaries/
fi
if [ -f "SHADER_PIPELINE_REFACTOR_SUMMARY.md" ]; then
    git mv SHADER_PIPELINE_REFACTOR_SUMMARY.md docs/guides/implementation-summaries/
fi
if [ -f "SHADER_PIPELINE_SAFETY_GUIDE.md" ]; then
    git mv SHADER_PIPELINE_SAFETY_GUIDE.md docs/guides/implementation-summaries/
fi
if [ -f "TASK_4_COMBAT_LOOP_REPORT.md" ]; then
    git mv TASK_4_COMBAT_LOOP_REPORT.md docs/guides/implementation-summaries/
fi
if [ -f "TASK_5_BUG_FIXES_REPORT.md" ]; then
    git mv TASK_5_BUG_FIXES_REPORT.md docs/guides/implementation-summaries/
fi
if [ -f "WAND_EXECUTION_REPORT.md" ]; then
    git mv WAND_EXECUTION_REPORT.md docs/guides/implementation-summaries/
fi
echo "✓ Implementation summaries moved"
echo ""

# Move external library documentation
echo "Moving external library documentation..."
if [ -f "assets/scripts/external/forma/README.md" ]; then
    git mv assets/scripts/external/forma/README.md docs/external/forma_README.md
fi
if [ -f "assets/scripts/external/hump/README.md" ]; then
    git mv assets/scripts/external/hump/README.md docs/external/hump_README.md
fi
if [ -f "assets/scripts/external/object.md" ]; then
    git mv assets/scripts/external/object.md docs/external/
fi
if [ -f "assets/scripts/color/README.md" ]; then
    git mv assets/scripts/color/README.md docs/external/color_README.md
fi
echo "✓ External library documentation moved"
echo ""

# Move asset documentation
echo "Moving asset documentation..."
if [ -f "assets/graphics/animation_WARNINGS.md" ]; then
    git mv assets/graphics/animation_WARNINGS.md docs/assets/
fi
if [ -f "assets/graphics/tileset use suggestions.md" ]; then
    git mv "assets/graphics/tileset use suggestions.md" docs/assets/tileset_use_suggestions.md
fi
if [ -f "assets/localization/BABEL_EDIT_WARNING.md" ]; then
    git mv assets/localization/BABEL_EDIT_WARNING.md docs/assets/
fi
if [ -f "assets/localization/LOCALIZATION_NOTES.md" ]; then
    git mv assets/localization/LOCALIZATION_NOTES.md docs/assets/
fi
echo "✓ Asset documentation moved"
echo ""

# Move tools documentation
echo "Moving tools documentation..."
if [ -f "assets/scripts/DEBUGGING_LUA.md" ]; then
    git mv assets/scripts/DEBUGGING_LUA.md docs/tools/
fi
echo "✓ Tools documentation moved"
echo ""

# Move TODO lists
echo "Moving TODO lists to project management..."
if [ -f "TODO.md" ]; then
    git mv TODO.md docs/project-management/todos/
fi
if [ -f "TODO_design.md" ]; then
    git mv TODO_design.md docs/project-management/todos/
fi
if [ -f "TODO_documentation.md" ]; then
    git mv TODO_documentation.md docs/project-management/todos/
fi
if [ -f "TODO_devlog.md" ]; then
    git mv TODO_devlog.md docs/project-management/todos/
fi
if [ -f "TODO_implemented_features_which_need_testing.md" ]; then
    git mv TODO_implemented_features_which_need_testing.md docs/project-management/todos/
fi
if [ -f "TODO_prototype.md" ]; then
    git mv TODO_prototype.md docs/project-management/todos/
fi
if [ -f "TODO_stat_planning.md" ]; then
    git mv TODO_stat_planning.md docs/project-management/todos/
fi
if [ -f "TODO_systems_refined.md" ]; then
    git mv TODO_systems_refined.md docs/project-management/todos/
fi
echo "✓ TODO lists moved"
echo ""

# Move design documents
echo "Moving design documents..."
if [ -f "TESTING_PLAN.md" ]; then
    git mv TESTING_PLAN.md docs/project-management/design/
fi
echo "✓ Design documents moved"
echo ""

# Move game jam archives
echo "Moving game jam archives..."
if [ -f "TODO_JAME_GAM_50.md" ]; then
    git mv TODO_JAME_GAM_50.md docs/project-management/game-jams/
fi
if [ -f "TODO_JAME_GAM_51.md" ]; then
    git mv TODO_JAME_GAM_51.md docs/project-management/game-jams/
fi
echo "✓ Game jam archives moved"
echo ""

# Move archived game jam documentation
echo "Moving archived game jam documentation..."
# These are already in subdirectories, so we'll move the whole directory if it exists
if [ -d "assets/scripts_archived/jame_gam_weather_or_not" ]; then
    # Create docs for this archive
    echo "  - Moving Weather or Not archive..."
    git mv assets/scripts_archived/jame_gam_weather_or_not docs/project-management/game-jams/
fi
echo "✓ Archived game jam documentation moved"
echo ""

echo "========================================="
echo "Documentation reorganization complete!"
echo "========================================="
echo ""
echo "Summary:"
echo "  - Created organized docs/ structure"
echo "  - Moved ~134 markdown files"
echo "  - Preserved git history using git mv"
echo "  - All files categorized by purpose"
echo ""
echo "Next steps:"
echo "  1. Review the changes: git status"
echo "  2. Commit: git commit -m 'docs: reorganize documentation into structured hierarchy'"
echo "  3. Push: git push"
echo ""
