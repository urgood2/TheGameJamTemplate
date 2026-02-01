# bd-2qf.71: [Descent] S10 Wall/floor tile rendering

## Summary
- Verified `assets/scripts/descent/render.lua` already renders wall/floor tiles using FOV visibility/explored state and hides unseen tiles.
- Added tile normalization so table tiles (with `type/id/kind`) render correctly alongside string tiles.

## Implementation
- Tile visibility uses `descent.fov` (`visible`/`explored`/`unseen`) to dim explored tiles and hide unseen.
- Tile lookup supports map `get_tile` and 1D/2D storage via `get_tile_value`.
- Wall/floor/stairs rendering respects visibility and hides unexplored tiles.

## Notes
- Rendering code is in `assets/scripts/descent/render.lua` and provides a `build_render_grid()` + `draw()` entry point.
- Not executed in this environment (no runnable Linux build / cmake). Logic review only.

