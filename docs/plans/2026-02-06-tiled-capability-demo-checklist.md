# Tiled Capability Demo Checklist

Date: 2026-02-06  
Status: In Progress

Purpose: single regression scenario that exercises all required Tiled capabilities in one run.

## Capability Coverage

- [x] Map load (`tiled.load_map`) + active map set (`tiled.set_active_map`)
- [x] Draw all layers (`tiled.draw_all_layers`)
- [x] Draw all layers with y-sort (`tiled.draw_all_layers_ysorted`)
- [x] Draw a specific layer (`tiled.draw_layer`)
- [x] Draw a specific layer with y-sort (`tiled.draw_layer_ysorted`)
- [x] Object extraction (`tiled.get_objects`)
- [x] Object spawn callback (`tiled.set_spawner` + `tiled.spawn_objects`)
- [x] Programmatic autotiling with `dungeon_mode_walls.rules.txt`
- [x] Programmatic autotiling with `dungeon_437_walls.rules.txt`
- [x] Procedural collider generation (`tiled.build_colliders_from_grid`)

## Required Asset Coverage Integration

- [x] `dungeon_mode` wall ruleset authored and loadable
- [x] `dungeon_437` wall ruleset authored and loadable
- [x] Wall coverage report generated with no uncovered assets
- [x] Taxonomy manifest generated for both required source folders

## Validation Coverage

- [x] Lua unit test for capability demo with mocked tiled bindings
- [x] Lua unit test for procgen tiled bridge wrappers
- [x] Python tests for taxonomy + wall coverage
- [ ] Manual in-engine run with a real `.tmj` map and screenshot capture
- [ ] Manual collision debug pass in engine (player/projectile contacts)

