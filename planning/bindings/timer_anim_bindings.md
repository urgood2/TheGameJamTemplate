# Timer/Animation Bindings

## Scope
Bindings for the timer system (timers, tweens, event queue) and the animation system.

## Source Files
- `src/systems/timer/timer.cpp`
- `src/systems/anim_system.cpp`

## Binding Patterns (C++)
- Timer: `timer` table created via `luaView["timer"]` and populated with `t.set_function(...)`.
- Timer math: `timer.math` via local `m` table and `m.set_function(...)`.
- Event queue: `EventQueueSystem` table via local `eq` and `eq.set_function(...)`, `eq.new_enum(...)`, `eq.new_usertype(...)`.
- Animation: `animation_system` table created via `lua.create_named_table("animation_system")` with `rec.bind_function(...)`.

## Frequency Scan
Command to run once `scripts/frequency_scan.py` is fixed:
`python3 scripts/frequency_scan.py --system timer_anim --bindings planning/inventory/bindings.timer_anim.json --roots assets/scripts --mode token_aware --output planning/inventory/frequency.timer_anim.json`

## Extractor Gaps
- Extractor records local table names (`t`, `m`, `eq`) instead of Lua namespaces. Inventory normalized to:
  - `timer.*` for `t.*`
  - `timer.math.*` for `m.*`
  - `EventQueueSystem.*` for `eq.*`
- `animation_system` bindings were captured without the table prefix; inventory normalized to `animation_system.*`.

## Tests
- `timer.after.basic` → `sol2_function_timer_after`
- `timer.every.basic` → `sol2_function_timer_every`
- `timer.cancel.basic` → `sol2_function_timer_cancel`
- `timer.tween.basic` → `sol2_function_timer_tween`
- `animation.create.basic` → `sol2_function_animation_system_createanimatedobjectwithtransform`
- `animation.play.basic` → `sol2_function_animation_system_play`
- `animation.chain.basic` → `sol2_function_animation_system_onanimationend`

<!-- AUTOGEN:BEGIN binding_list -->
- `AnimationQueueComponent` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:93`
- `EventQueueSystem.ConditionData.check` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1210`
- `EventQueueSystem.ConditionData` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1205`
- `EventQueueSystem.EaseData.endTime` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1201`
- `EventQueueSystem.EaseData.endValue` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1199`
- `EventQueueSystem.EaseData.getValueCallback` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1203`
- `EventQueueSystem.EaseData.setValueCallback` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1202`
- `EventQueueSystem.EaseData.startTime` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1200`
- `EventQueueSystem.EaseData.startValue` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1198`
- `EventQueueSystem.EaseData.type` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1197`
- `EventQueueSystem.EaseDataBuilder` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1250`
- `EventQueueSystem.EaseData` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1186`
- `EventQueueSystem.EaseType.ELASTIC_IN` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1156`
- `EventQueueSystem.EaseType.ELASTIC_OUT` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1157`
- `EventQueueSystem.EaseType.LERP` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1155`
- `EventQueueSystem.EaseType.QUAD_IN` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1158`
- `EventQueueSystem.EaseType.QUAD_OUT` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1159`
- `EventQueueSystem.EaseType` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1153`
- `EventQueueSystem.Event.blocksQueue` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1233`
- `EventQueueSystem.Event.canBeBlocked` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1234`
- `EventQueueSystem.Event.complete` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1235`
- `EventQueueSystem.Event.condition` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1244`
- `EventQueueSystem.Event.createdWhilePaused` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1239`
- `EventQueueSystem.Event.debugID` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1246`
- `EventQueueSystem.Event.delaySeconds` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1237`
- `EventQueueSystem.Event.deleteNextCycleImmediately` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1247`
- `EventQueueSystem.Event.ease` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1243`
- `EventQueueSystem.Event.eventTrigger` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1232`
- `EventQueueSystem.Event.func` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1240`
- `EventQueueSystem.Event.retainAfterCompletion` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1238`
- `EventQueueSystem.Event.tag` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1245`
- `EventQueueSystem.Event.time` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1242`
- `EventQueueSystem.Event.timerStarted` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1236`
- `EventQueueSystem.Event.timerType` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1241`
- `EventQueueSystem.EventBuilder` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1272`
- `EventQueueSystem.Event` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1212`
- `EventQueueSystem.TimerType.REAL_TIME` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1182`
- `EventQueueSystem.TimerType.TOTAL_TIME_EXCLUDING_PAUSE` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1183`
- `EventQueueSystem.TimerType` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1180`
- `EventQueueSystem.TriggerType.AFTER` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1171`
- `EventQueueSystem.TriggerType.BEFORE` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1172`
- `EventQueueSystem.TriggerType.CONDITION` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1174`
- `EventQueueSystem.TriggerType.EASE` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1173`
- `EventQueueSystem.TriggerType.IMMEDIATE` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1170`
- `EventQueueSystem.TriggerType` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1168`
- `EventQueueSystem.add_event` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1311`
- `EventQueueSystem.clear_queue` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1313`
- `EventQueueSystem.get_event_by_tag` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1312`
- `EventQueueSystem.update` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1314`
- `EventQueueSystem` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1143`
- `animation_system.clearCallbacks` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:399`
- `animation_system.createAnimatedObjectWithTransform` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:137`
- `animation_system.createStillAnimationFromSpriteUUID` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:233`
- `animation_system.getCurrentFrame` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:284`
- `animation_system.getFrameCount` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:291`
- `animation_system.getNinepatchUIBorderInfo` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:116`
- `animation_system.getProgress` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:305`
- `animation_system.isPlaying` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:298`
- `animation_system.onAnimationEnd` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:391`
- `animation_system.onFrameChange` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:375`
- `animation_system.onLoopComplete` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:383`
- `animation_system.pause` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:319`
- `animation_system.play` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:312`
- `animation_system.replaceAnimatedObjectOnEntity` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:165`
- `animation_system.resetAnimationUIRenderScale` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:267`
- `animation_system.resizeAnimationObjectToFit` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:275`
- `animation_system.resizeAnimationObjectsInEntityToFitAndCenterUI` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:254`
- `animation_system.resizeAnimationObjectsInEntityToFit` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:242`
- `animation_system.seekFrame` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:341`
- `animation_system.setDirection` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:359`
- `animation_system.setFGColorForAllAnimationObjects` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:124`
- `animation_system.setLoopCount` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:367`
- `animation_system.setSpeed` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:333`
- `animation_system.set_flip` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:215`
- `animation_system.set_horizontal_flip` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:102`
- `animation_system.setupAnimatedObjectOnEntity` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:201`
- `animation_system.stop` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:326`
- `animation_system.toggle_flip` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:224`
- `animation_system.update` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:109`
- `animation_system` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/anim_system.cpp:91`
- `timer.TimerType.AFTER` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:226`
- `timer.TimerType.COOLDOWN` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:227`
- `timer.TimerType.EVERY_RENDER_FRAME_ONLY` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:232`
- `timer.TimerType.EVERY_STEP` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:229`
- `timer.TimerType.EVERY` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:228`
- `timer.TimerType.FOR` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:230`
- `timer.TimerType.RUN` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:225`
- `timer.TimerType.TWEEN` — (property) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:231`
- `timer.TimerType` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:223`
- `timer.after` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:380`
- `timer.cancel` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:235`
- `timer.clear_all` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:244`
- `timer.cooldown` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:391`
- `timer.every_step` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:428`
- `timer.every` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:408`
- `timer.for_time` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:451`
- `timer.get_delay` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:238`
- `timer.get_every_index` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:236`
- `timer.get_for_elapsed` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:241`
- `timer.get_multiplier` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:240`
- `timer.get_timer_and_delay` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:242`
- `timer.kill_group` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1003`
- `timer.math.lerp` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:195`
- `timer.math.remap` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:194`
- `timer.math` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:197`
- `timer.pause_group` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1010`
- `timer.pause` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:989`
- `timer.reset` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:237`
- `timer.resume_group` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:1017`
- `timer.resume` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:996`
- `timer.run_every_render_frame` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:355`
- `timer.run` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:342`
- `timer.set_multiplier` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:239`
- `timer.tween` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:468`
- `timer.update` — (function) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:320`
- `timer` — (usertype) — `/data/projects/TheGameJamTemplate@cass-memory-update/src/systems/timer/timer.cpp:187`
<!-- AUTOGEN:END binding_list -->
