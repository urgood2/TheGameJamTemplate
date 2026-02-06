# Wall Autotile Coverage

This folder contains runtime wall autotile rulesets for the two required asset sources:

- `assets/graphics/pre-packing-files_globbed/dungeon_mode`
- `assets/graphics/pre-packing-files_globbed/dungeon_437`

## Included wall autotile tiles

- `dungeon_mode_walls.runtime.json` uses the dedicated wall autotile cluster:
  - `dm_240`..`dm_250`, `dm_254`
- `dungeon_437_walls.runtime.json` uses canonical wall glyphs and flips where needed:
  - `d437_169`, `d437_170`, `d437_179`, `d437_196`, `d437_197`, `d437_219`

## Coverage validation

- Machine-readable coverage report:
  - `planning/tiled_assets/rulesets/wall_rule_coverage_report.json`
- Validator script:
  - `scripts/tiled_wall_rule_coverage.py`
- Run coverage validation:
  - `python3 scripts/tiled_wall_rule_coverage.py --check-only`

## Intentional exclusions

Assets categorized as non-wall in `planning/tiled_assets/required_asset_manifest.json` are intentionally excluded from wall autotiling and should be handled by object placement, decoration layers, entity spawning, or UI pipelines.

Wall-category files not listed above are still covered by taxonomy and remain available for future ruleset expansion (variant-specific themes, shaded variants, and stylized alternates).
