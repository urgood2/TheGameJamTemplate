- [ ] sometimes I get a bug at this line (called a number..?): 
```lua
local helpButtonUIBox = ui.box.Initialize({x = globals.screenWidth() - 300, y = 500}, helpButtonRoot)
```
- [ ]
```
--FIXME: why/ does is this nil in web? ui.box
if not ui.box then
                        log_error("UI box system is not available, cannot remove HP UI box.")
                        registry:destroy(ui_elem.hp_ui_box)
                        registry:destroy(ui_elem.hp_ui_text)
                    else
                        ui.box.Remove(registry, ui_elem.hp_ui_box)
                    end
```
- really long dynamic texts cause massive slowdowns -> only on debug builds.
- attempt to call number value (uibox initialize method) sometimes happens, why?
```
[2025-07-21 00:56:56.708] [error] [timer.cpp:154] Timer action failed: attempt to call a number value
stack traceback:
	[C]: in field 'Initialize'
	...emplate/TheGameJamTemplate/assets/scripts/ui/ui_defs.lua:998: in field 'generateUI'
	...Template/TheGameJamTemplate/assets/scripts/core/main.lua:405: in function 'base.initMainGame'
	...Template/TheGameJamTemplate/assets/scripts/core/main.lua:602: in function 'base.changeGameState'
	...Template/TheGameJamTemplate/assets/scripts/core/main.lua:290: in function <...Template/TheGameJamTemplate/assets/scripts/core/main.lua:281>
```