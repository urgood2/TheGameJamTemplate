# Input/Sound/AI Bindings

## Scope
Bindings for player input, audio playback, and AI systems exposed to Lua.

## Source Files
- `src/systems/input/input_lua_bindings.cpp`
- `src/systems/sound/sound_system.cpp`
- `src/systems/ai/ai_system.cpp`

## Binding Patterns (C++)
- Input: `sol::table in = lua["in"]; in.set_function(...)` plus `lua.create_table_with(...)` for enums.
- Sound: `lua.set_function("playSoundEffect", ...)` with `rec.record_free_function(...)` for signatures.
- AI: `sol::table ai = lua["ai"]; ai.set_function(...)` and `lua.set_function("create_ai_entity", ...)`.

## Frequency Scan
Command attempted (fails currently due to `args.roots` being strings in `scripts/frequency_scan.py`):
`python3 scripts/frequency_scan.py --system input_sound_ai --bindings planning/inventory/bindings.input_sound_ai.json --roots assets/scripts --mode token_aware --output planning/inventory/frequency.input_sound_ai.json`

## Extractor Gaps
- `sound_system.cpp`: file scan only checks the first ~5KB for binding markers; `lua.set_function(...)` entries appear later, so sound functions are parsed manually into the inventory.
- `ai_system.cpp`: bindings are extracted under `bindings.core.json` (no `ai` mapping in extractor); filtered by `source_ref`.

## Tests
- `input.is_key_pressed.basic` → `sol2_function_in_iskeypressed`
- `input.get_mouse_position.basic` → `sol2_function_in_getmousepos`
- `sound.play.basic` → `sol2_function_playsoundeffect`
- `sound.stop.basic` → `sol2_function_stopallmusic`
- `ai.list_lua_files.basic` → `sol2_function_ai_list_lua_files`
- `ai.create_entity.basic` → `sol2_function_create_ai_entity`

<!-- AUTOGEN:BEGIN binding_list -->
- `AxisButtonState.current` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:690`
- `AxisButtonState.previous` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:691`
- `AxisButtonState` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:336`
- `Blackboard` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1573`
- `CursorContext.layer` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:710`
- `CursorContext.stack` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:711`
- `CursorContext::CursorLayer.cursor_focused_target` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:705`
- `CursorContext::CursorLayer.cursor_position` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:706`
- `CursorContext::CursorLayer.focus_interrupt` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:707`
- `CursorContext::CursorLayer` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:704`
- `CursorContext` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:361`
- `CursorLayer` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:355`
- `GamepadAxis` — (enum) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:315`
- `GamepadAxis` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:669`
- `GamepadButton` — (enum) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:294`
- `GamepadButton` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:646`
- `GamepadState.console` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:717`
- `GamepadState.id` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:718`
- `GamepadState.mapping` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:715`
- `GamepadState.name` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:716`
- `GamepadState.object` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:714`
- `GamepadState` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:366`
- `HIDFlags.axis_cursor_enabled` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:727`
- `HIDFlags.controller_enabled` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:725`
- `HIDFlags.dpad_enabled` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:722`
- `HIDFlags.last_type` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:721`
- `HIDFlags.mouse_enabled` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:726`
- `HIDFlags.pointer_enabled` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:723`
- `HIDFlags.touch_enabled` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:724`
- `HIDFlags` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:374`
- `InputDeviceInputCategory.GAMEPAD_AXIS_CURSOR` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:682`
- `InputDeviceInputCategory.GAMEPAD_AXIS` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:683`
- `InputDeviceInputCategory.GAMEPAD_BUTTON` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:684`
- `InputDeviceInputCategory.MOUSE` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:685`
- `InputDeviceInputCategory.NONE` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:681`
- `InputDeviceInputCategory.TOUCH` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:686`
- `InputDeviceInputCategory` — (enum) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:324`
- `InputDeviceInputCategory` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:680`
- `InputState` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:443`
- `KeyboardKey` — (enum) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:171`
- `KeyboardKey` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:540`
- `L.HIDFlags` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:52`
- `L.InputState` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:63`
- `MouseButton.MOUSE_BUTTON_BACK` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:643`
- `MouseButton.MOUSE_BUTTON_EXTRA` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:641`
- `MouseButton.MOUSE_BUTTON_FORWARD` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:642`
- `MouseButton.MOUSE_BUTTON_LEFT` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:637`
- `MouseButton.MOUSE_BUTTON_MIDDLE` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:639`
- `MouseButton.MOUSE_BUTTON_RIGHT` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:638`
- `MouseButton.MOUSE_BUTTON_SIDE` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:640`
- `MouseButton` — (enum) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:284`
- `MouseButton` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:636`
- `NodeData.click` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:695`
- `NodeData.menu` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:696`
- `NodeData.node` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:694`
- `NodeData.under_overlay` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:697`
- `NodeData` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:341`
- `SnapTarget.node` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:700`
- `SnapTarget.transform` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:701`
- `SnapTarget.type` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:702`
- `SnapTarget` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:348`
- `ai.clear_trace` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1886`
- `ai.dump_blackboard` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:2086`
- `ai.dump_plan` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:2030`
- `ai.dump_worldstate` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:2014`
- `ai.force_interrupt` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1644`
- `ai.get_all_atoms` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:2049`
- `ai.get_blackboard` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1590`
- `ai.get_entity_ai_def` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1080`
- `ai.get_goap_state` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1921`
- `ai.get_trace_events` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1845`
- `ai.get_worldstate` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1120`
- `ai.has_plan` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:2070`
- `ai.list_goap_entities` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1902`
- `ai.list_lua_files` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1647`
- `ai.patch_goal` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1154`
- `ai.patch_worldstate` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1147`
- `ai.pause_ai_system` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1088`
- `ai.report_goal_selection` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1798`
- `ai.resume_ai_system` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1101`
- `ai.set_goal` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1138`
- `ai.set_worldstate` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1114`
- `ai` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1072`
- `bb.clear` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1299`
- `bb.decay` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1381`
- `bb.get_vec2` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1326`
- `bb.get` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1212`
- `bb.has` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1286`
- `bb.inc` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1352`
- `bb.set_vec2` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1312`
- `bb.set` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1165`
- `clearPlaylist` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:288`
- `create_ai_entity_with_overrides` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1630`
- `create_ai_entity` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1607`
- `fadeInMusic` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:335`
- `fadeInMusic` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:418`
- `fadeOutMusic` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:345`
- `fadeOutMusic` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:419`
- `getTrackVolume` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:326`
- `in.action_down` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:810`
- `in.action_pressed` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:808`
- `in.action_released` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:809`
- `in.action_value` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:811`
- `in.bind` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:777`
- `in.clearActiveScrollPane` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:422`
- `in.clear` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:803`
- `in.getChar` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:433`
- `in.getKeyPressed` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:434`
- `in.getMousePos` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:412`
- `in.getMouseWheel` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:413`
- `in.getPadAxis` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:430`
- `in.getState` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:394`
- `in.isGamepadEnabled` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:390`
- `in.isKeyDown` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:401`
- `in.isKeyPressed` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:402`
- `in.isKeyReleased` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:403`
- `in.isKeyUp` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:404`
- `in.isMouseDown` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:409`
- `in.isMousePressed` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:410`
- `in.isMouseReleased` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:411`
- `in.isPadButtonDown` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:429`
- `in.isPadConnected` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:428`
- `in.setExitKey` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:435`
- `in.set_context` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:813`
- `in.start_rebind` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:819`
- `in.updateCursorFocus` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/input/input_lua_bindings.cpp:415`
- `pauseMusic` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:354`
- `pauseMusic` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:420`
- `playMusic` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:246`
- `playMusic` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:414`
- `playPlaylist` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:257`
- `playSoundEffect` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:166`
- `playSoundEffect` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:413`
- `queueMusic` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:306`
- `queueMusic` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:417`
- `resetSoundSystem` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:219`
- `resumeMusic` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:364`
- `resumeMusic` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:421`
- `sense.all_in_range` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1509`
- `sense.distance` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1424`
- `sense.nearest` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1436`
- `sense.position` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/ai/ai_system.cpp:1411`
- `setCategoryVolume` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:392`
- `setCategoryVolume` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:424`
- `setLowPassSpeed` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:237`
- `setLowPassTarget` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:228`
- `setMusicVolume` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:383`
- `setMusicVolume` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:423`
- `setSoundPitch` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:402`
- `setSoundPitch` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:425`
- `setTrackVolume` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:316`
- `setVolume` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:374`
- `setVolume` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:422`
- `stopAllMusic` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:296`
- `toggleDelayEffect` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:210`
- `toggleLowPassFilter` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/sound/sound_system.cpp:201`
<!-- AUTOGEN:END binding_list -->
