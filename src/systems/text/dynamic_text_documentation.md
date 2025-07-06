
- Instantiating new text entities:
    - Note that this auto-updates localized strings on language change if the fourth argument is omitted or true (set to false if you don't want this behavior)

``` lua

local buildingText = ui.definitions.getNewDynamicTextEntry(
        function() localization.get("ui.building_text") end,  -- initial text
        20.0,                                 -- font size
        "float"                       -- animation spec
    )
```