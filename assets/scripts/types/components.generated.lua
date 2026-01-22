---@meta
--[[
================================================================================
COMPONENT TYPES - Auto-generated from chugget_code_definitions.lua
================================================================================
This file is GENERATED. Do not edit manually.

To regenerate:
    python3 tools/lua-types/generate_component_types.py

These types provide IDE autocomplete for ECS components.
]]


---@alias Entity number Entity ID (integer handle)
---@alias EntityID number Alias for Entity
---@alias ComponentType table Component type table used with component_cache.get


---@class GameObject
---@field parent Entity|nil -@type table<Entity, boolean>
---@field orderedChildren table<integer, Entity> -@type boolean
---@field container Entity|nil -@type Transform|nil
---@field clickTimeout number -@type GameObjectMethods|nil
---@field updateFunction function|nil -@type function|nil
---@field state GameObjectState -@type Vector2
---@field clickOffset Vector2 -@type Vector2
---@field shadowMode ShadowMode -@type Vector2
---@field layerDisplacement Vector2 -@type Vector2
---@field shadowHeight number

---@class GameObjectMethods
---@field getObjectToDrag function|nil Returns the entity that should be dragged.
---@field update function|nil Called every frame.
---@field draw function|nil Called every frame for drawing.
---@field onClick function|nil Called on click.
---@field onRightClick function|nil Called on right-click.
---@field onRelease function|nil Called on click release.
---@field onHover function|nil Called when hover starts.
---@field onStopHover function|nil Called when hover ends.
---@field onDrag function|nil Called while dragging.
---@field onStopDrag function|nil

---@class GameObjectState
---@field visible boolean -@type boolean
---@field isColliding boolean -@type boolean
---@field isBeingFocused boolean -@type boolean
---@field isBeingHovered boolean -@type boolean
---@field enlargeOnDrag boolean -@type boolean
---@field isBeingClicked boolean -@type boolean
---@field dragEnabled boolean -@type boolean
---@field triggerOnReleaseEnabled boolean -@type boolean
---@field isUnderOverlay boolean

---@class ScriptComponent

---@class Transform
---@field actualX number The logical X position.
---@field visualX number The visual (spring-interpolated) X position.
---@field actualY number The logical Y position.
---@field visualY number The visual (spring-interpolated) Y position.
---@field actualW number The logical width.
---@field visualW number The visual width.
---@field actualH number The logical height.
---@field visualH number The visual height.
---@field rotation number The logical rotation in degrees.
---@field scale number

---@class UIConfig
---@field stylingType UIStylingType|nil The visual style of the element.
---@field nPatchInfo NPatchInfo|nil 9-patch slicing information.
---@field nPatchSourceTexture string|nil Texture path for the 9-patch.
---@field spriteSourceTexture Texture2D*|nil Pointer to the sprite source texture.
---@field spriteSourceRect Rectangle|nil Source rectangle in the sprite texture.
---@field spriteScaleMode SpriteScaleMode How the sprite should be scaled (default: Stretch).
---@field id string|nil Unique identifier for this UI element.
---@field instanceType string|nil A specific instance type for categorization.
---@field uiType UITypeEnum|nil The fundamental type of the UI element.
---@field drawLayer string|nil The layer on which this element is drawn.
---@field group string|nil The focus group this element belongs to.
---@field groupParent string|nil The parent focus group.
---@field location_bond InheritedPropertiesSync|nil Bonding strength for location.
---@field rotation_bond InheritedPropertiesSync|nil Bonding strength for rotation.
---@field size_bond InheritedPropertiesSync|nil Bonding strength for size.
---@field scale_bond InheritedPropertiesSync|nil Bonding strength for scale.
---@field offset Vector2|nil Offset from the parent/aligned position.
---@field scale number|nil Scale multiplier.
---@field textSpacing number|nil Spacing for text characters.
---@field focusWithObject boolean|nil Whether focus is tied to a game object.
---@field refreshMovement boolean|nil Force movement refresh.
---@field no_recalc boolean|nil Prevents recalculation of transform.
---@field non_recalc boolean|nil Alias for no_recalc.
---@field noMovementWhenDragged boolean|nil Prevents movement while being dragged.
---@field master string|nil ID of the master element.
---@field parent string|nil ID of the parent element.
---@field object Entity|nil The game object associated with this UI element.
---@field objectRecalculate boolean|nil Force recalculation based on the object.
---@field alignmentFlags integer|nil Bitmask of alignment flags.
---@field width number|nil Explicit width.
---@field height number|nil Explicit height.
---@field maxWidth number|nil Maximum width.
---@field maxHeight number|nil Maximum height.
---@field minWidth number|nil Minimum width.
---@field minHeight number|nil Minimum height.
---@field padding number|nil Padding around the content.
---@field color string|nil Background color.
---@field outlineColor string|nil Outline color.
---@field outlineThickness number|nil Outline thickness in pixels.
---@field makeMovementDynamic boolean|nil Enables springy movement.
---@field shadow Vector2|nil Offset for the shadow.
---@field outlineShadow Vector2|nil Offset for the outline shadow.
---@field shadowColor string|nil Color of the shadow.
---@field noFill boolean|nil If true, the background is not filled.
---@field pixelatedRectangle boolean|nil Use pixel-perfect rectangle drawing.
---@field canCollide boolean|nil Whether collision is possible.
---@field collideable boolean|nil Alias for canCollide.
---@field forceCollision boolean|nil Forces collision checks.
---@field button_UIE boolean|nil Behaves as a button.
---@field disable_button boolean|nil Disables button functionality.
---@field progressBarFetchValueLambda function|nil Function to get the progress bar's current value.
---@field progressBar boolean|nil If this element is a progress bar.
---@field progressBarEmptyColor string|nil Color of the empty part of the progress bar.
---@field progressBarFullColor string|nil Color of the filled part of the progress bar.
---@field progressBarMaxValue number|nil The maximum value of the progress bar.
---@field progressBarValueComponentName string|nil Component name to fetch progress value from.
---@field progressBarValueFieldName string|nil Field name to fetch progress value from.
---@field ui_object_updated boolean|nil Flag indicating the UI object was updated.
---@field buttonDelayStart boolean|nil Flag for button delay start.
---@field buttonDelay number|nil Delay for button actions.
---@field buttonDelayProgress number|nil Progress of the button delay.
---@field buttonDelayEnd boolean|nil Flag for button delay end.
---@field buttonClicked boolean|nil True if the button was clicked this frame.
---@field buttonDistance number|nil Distance for button press effect.
---@field tooltip string|nil Simple tooltip text.
---@field detailedTooltip Tooltip|nil A detailed tooltip object.
---@field onDemandTooltip function|nil A function that returns a tooltip.
---@field hover boolean|nil Flag indicating if the element is being hovered.
---@field force_focus boolean|nil Forces this element to take focus.
---@field dynamicMotion boolean|nil Enables dynamic motion effects.
---@field choice boolean|nil Marks this as a choice in a selection.
---@field chosen boolean|nil True if this choice is currently selected.
---@field one_press boolean|nil Button can only be pressed once.
---@field chosen_vert boolean|nil Indicates a vertical choice selection.
---@field draw_after boolean|nil Draw this element after its children.
---@field focusArgs FocusArgs|nil Arguments for focus behavior.
---@field updateFunc function|nil Custom update function.
---@field initFunc function|nil Custom initialization function.
---@field onUIResizeFunc function|nil Callback for when the UI is resized.
---@field onUIScalingResetToOne function|nil Callback for when UI scaling resets.
---@field instaFunc function|nil A function to be executed instantly.
---@field buttonCallback function|nil Callback for button presses.
---@field buttonTemp boolean|nil Temporary button flag.
---@field textGetter function|nil Function to dynamically get text content.
---@field ref_entity Entity|nil A referenced entity.
---@field ref_component string|nil Name of a referenced component.
---@field ref_value any|nil A referenced value.
---@field prev_ref_value any|nil The previous referenced value.
---@field text string|nil Static text content.
---@field fontSize number|nil Override font size for this element.
---@field fontName string|nil Named font to use instead of the language default.
---@field language string|nil Language key for localization.
---@field verticalText boolean|nil If true, text is rendered vertically.
---@field hPopup boolean|nil Is a horizontal popup.
---@field dPopup boolean|nil Is a detailed popup.
---@field hPopupConfig UIConfig|nil Configuration for the horizontal popup.
---@field dPopupConfig UIConfig|nil Configuration for the detailed popup.
---@field extend_up boolean|nil If the element extends upwards.
---@field resolution Vector2|nil Resolution context for this element.
---@field emboss boolean|nil Apply an emboss effect.
---@field line_emboss boolean|nil Apply a line emboss effect.
---@field mid boolean|nil A miscellaneous flag.
---@field noRole boolean|nil This element has no inherited properties role.
---@field role InheritedProperties|nil The inherited properties role.
---@field isFiller boolean True if this is a filler element.
---@field flexWeight number Flex proportion for filler space distribution.
---@field maxFillSize number Maximum filler size in pixels (0 = unlimited).
---@field computedFillSize number

---@class UIContentConfig
---@field text string|nil Static text content.
---@field language string|nil Language key for localization.
---@field verticalText boolean|nil If true, text is rendered vertically.
---@field fontSize number|nil Font size for text elements.
---@field fontName string|nil Named font to use.
---@field textGetter function|nil Function to dynamically get text content.
---@field object Entity|nil The game object associated with this UI element.
---@field objectRecalculate boolean Force recalculation based on object.
---@field progressBar boolean If this element is a progress bar.
---@field progressBarMaxValue number|nil Maximum value of the progress bar.
---@field ref_entity Entity|nil A referenced entity.
---@field instanceType string|nil

---@class UIElementComponent
---@field UIT UITypeEnum The type of this UI element.
---@field uiBox Entity The root entity of the UI box this element belongs to.
---@field config UIConfig

---@class UIInteractionConfig
---@field canCollide boolean|nil Whether collision is possible.
---@field hover boolean Whether element is currently hovered.
---@field disable_button boolean Disables button functionality.
---@field buttonClicked boolean True if button was clicked this frame.
---@field force_focus boolean Forces this element to take focus.
---@field focusArgs FocusArgs|nil Arguments for focus behavior.
---@field tooltip Tooltip|nil Simple tooltip.
---@field buttonCallback function|nil Callback for button presses.
---@field updateFunc function|nil Custom update function.
---@field choice boolean|nil Marks this as a choice element.
---@field dynamicMotion boolean|nil

---@class UILayoutConfig
---@field width integer|nil Explicit width.
---@field height integer|nil Explicit height.
---@field maxWidth integer|nil Maximum width.
---@field maxHeight integer|nil Maximum height.
---@field minWidth integer|nil Minimum width.
---@field minHeight integer|nil Minimum height.
---@field padding number|nil Padding around the content.
---@field alignmentFlags integer|nil Bitmask of alignment flags.
---@field offset Vector2|nil Offset from aligned position.
---@field scale number|nil Scale multiplier.
---@field mid boolean A miscellaneous layout flag.
---@field draw_after boolean

---@class UIState
---@field contentDimensions Vector2 The calculated dimensions of the element's content.
---@field textDrawable TextDrawable The drawable text object.
---@field last_clicked Entity The last entity that was clicked within this UI context.
---@field object_focus_timer number Timer for object focus events.
---@field focus_timer number

---@class UIStyleConfig
---@field stylingType UIStylingType The visual style type (rounded rectangle, 9-patch, sprite).
---@field color Color|nil Background color.
---@field outlineColor Color|nil Outline color.
---@field shadowColor Color|nil Shadow color.
---@field outlineThickness number|nil Outline thickness in pixels.
---@field shadow boolean Whether shadow is enabled.
---@field noFill boolean If true, background is not filled.
---@field pixelatedRectangle boolean

---------------------------------------------------------------------------
-- Component Type Globals (for use with component_cache.get)
---------------------------------------------------------------------------

---@type GameObject
GameObject = {}

---@type GameObjectMethods
GameObjectMethods = {}

---@type GameObjectState
GameObjectState = {}

---@type ScriptComponent
ScriptComponent = {}

---@type Transform
Transform = {}

---@type UIConfig
UIConfig = {}

---@type UIContentConfig
UIContentConfig = {}

---@type UIElementComponent
UIElementComponent = {}

---@type UIInteractionConfig
UIInteractionConfig = {}

---@type UILayoutConfig
UILayoutConfig = {}

---@type UIState
UIState = {}

---@type UIStyleConfig
UIStyleConfig = {}
