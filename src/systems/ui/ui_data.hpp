#pragma once

#include "util/common_headers.hpp"

#include <string>
#include <vector>
#include <unordered_map>
#include <variant>
#include <functional>

#include "systems/transform/transform_functions.hpp"
#include "systems/input/input_functions.hpp"
#include "systems/layer/layer.hpp"
#include "systems/reflection/reflection.hpp"


//Note: uibox is master to all ui elements within it, including the root element.
// UI box does not have any children within the ui hierarchy.
// Each ui element can have a parent (root ui element or some other element below that)
namespace ui
{
    
    // this marks objects like text, animations, etc. which are attached to a UI element. For optimization purposes.
    struct ObjectAttachedToUITag {
        bool dummy = true; // dummy variable 
    };
    
    enum class UITypeEnum
    {           
        NONE = 0,   // no type, for error checking

        // containers. (root is treated as a column if it has children)
        ROOT = 1,   // container, base ui element which serves as head of hierarchy.
        VERTICAL_CONTAINER = 2, // container, a columnar ui element
        HORIZONTAL_CONTAINER = 3,    // container, a row ui element

        // ui elements.
        SLIDER_UI = 4, // element, a slider bar ui element
        INPUT_TEXT = 5, // element, a text input ui element
        RECT_SHAPE = 6,   // element, box shape
        TEXT = 7,  // element, Simple text (not dynamic or animated)
        OBJECT = 8 // element, game object (like animated text, sprite, etc.)
    };

    /**
     * Represents a single UI element in the UI system.
     */
    struct UIElementComponent
    {
        UITypeEnum UIT = UITypeEnum::NONE;                   // UI Type (e.g., TEXT, BUTTON)
        entt::entity uiBox = entt::null;                     // The UIBox this element belongs to
        std::unordered_map<std::string, std::string> config; // Configuration properties specific to this element
    };

    /**
     * For ui elements which allow tet input.
     */
    struct TextInput {
        std::string text;      // The text content
        size_t cursorPos = 0;  // Cursor position in the string
        size_t maxLength = 50; // Max allowed characters
        bool allCaps = false;  // Force capitalization
        std::function<void()> callback; // Optional callback when pressing Enter
    };
    
    struct TextInputHook {
        entt::entity hookedEntity = entt::null;
    };

    /**
     * Represents a UIBox, which is a container for UI elements and other UIBoxes.
     */
    struct UIBoxComponent
    {
        std::optional<entt::entity> uiRoot;     // Root entity right below uibox (every ui box has a root entity, which is the first entity in the hierarchy)
        std::map<int, entt::entity> drawLayers; // used to explicitly assign additional elements to be drawn in a specific layer after the root ui and children are drawn (children with config.drawLayer aren't drawn in drawchildren())
    };

    // TODO: test with each variable in config and other structs to document behavior

    // contains active states (not config) of the UI element
    struct UIState
    {
        std::optional<Vector2> contentDimensions; // dimensions of the content for the ui node. This is used in the alignment setting methods.
        std::optional<std::string> textDrawable; // TODO: seems to be simply text, should be a string and drawn with raylib's text drawing probably, or removed entirely since we can use config's text setting
        std::optional<float> last_clicked;        
        std::optional<float> object_focus_timer; // focused-on timer for objects which are ui elements
        std::optional<float> focus_timer;        // focused-on timer for ui elements
    };

    // helper struct for tooltip
    struct Tooltip
    {
        std::optional<std::string> title;
        std::optional<std::string> text;
    };

    // helper struct for controller focus
    struct FocusArgs
    {
        //TODO: how to allow both keyboard or gamepad 
        std::optional<GamepadButton> button;     // Registers a button that should be linked to this UI element. Allows gamepad or keyboard input to trigger the UI element.
        std::optional<bool> snap_to;             // Determines whether the UI element should be auto-focused when created.
        std::optional<bool> registered;          // Prevents duplicate registration of a UI element. Ensures the UI element is only registered once for input handling.
        std::optional<std::string> type;         // slider, tab, etc. for handling focus. Specifies what type of focus behavior this UI element should use. Could be used to group UI elements under specific focus management types.
        std::optional<entt::entity> claim_focus_from; // Specifies that focus should be funneled from a specific UI element. These properties define a focus funnel system that determines how keyboard/gamepad navigation should be handled.
        std::optional<entt::entity> redirect_focus_to;   // Specifies that focus should be funneled toward a specific UI element. These properties define a focus funnel system that determines how keyboard/gamepad navigation should be handled.
        std::optional<std::string> nav;          // type of focus navigation? ("wide": Focus is primarily horizontal, so check the y axis. "tall": Focus is primarily vertical, so check the x axis.) Clear to disable TODO: change to enum
        bool no_loop{false};                     // set to true to prevent looping focus
    };

    //TODO: resolution sensitive gui how?

    // for slider ui elements
    struct SliderComponent {
        std::optional<Color> color;
        std::optional<std::string> text;
        std::optional<float> min, max, value;
        std::optional<int> decimal_places;
        std::optional<float> w, h;
    };
    
    // marks ui elements which are inventory slots.
    struct InventoryGridTileComponent {
        std::optional<entt::entity> item; // the item in the grid tile  
    };

    //TODO: Separate config into its own config entity with separete components for each ui type instead of one mammoth container?
    //TODO: Difference between popups and alerts? - alertss are not drawn, even when they are children. Alerts are drawn on top of everything else (like ! badges on top right). Pop-ups are uiboxes themselves, but I can't figure out where they are drawn. Drag pop-ups are drawn with other children. 
    
    // defines whether a specific ui element is drawn as a rounded rectangle or a 9-patch border
    enum class UIStylingType {
        ROUNDED_RECTANGLE,
        NINEPATCH_BORDERS
    };
    
    // make tuple<NPatchInfo, Texture2D> a typename
    using NPatchDataStruct = std::tuple<NPatchInfo, Texture2D>;
    
    //TODO: Draw layer seems to be a number? Check
    //TODO: Funnel to and funnel from can be boolean? What are they?
    // UIBox interprets this data as high-level container settings which affect all ui elements within
    // UIElement interprets config at a per-element level
    struct UIConfig
    {
        UIStylingType stylingType = UIStylingType::ROUNDED_RECTANGLE; // Determines how the UI element is drawn (rounded rectangle or 9-patch borders)
        
        std::optional<NPatchInfo> nPatchInfo; // 9-patch data for the UI element. This is used when the stylingType is set to NINEPATCH_BORDERS. It contains information about the texture and how to draw it.
        std::optional<Texture2D> nPatchSourceTexture; // the atlas texture used for 9-patch.
        
        // General Properties
        std::optional<std::string> id;           // Unique identifier, used to store in children vector. If predefined in the definition stage, it will be maintained. Otherwise, children of an entity get a unique id starting at 0 and incrementing.
        std::optional<std::string> instanceType; // Instance type of the UI element
        std::optional<UITypeEnum> uiType;        // UI type category
        //TODO: check implementation done properly
        std::optional<int> drawLayer;            // Determines which layer this UI element should be drawn in.
        std::optional<std::string> group;        // radio button group to which this element belongs
        std::optional<entt::entity> groupParent; // the parent entity of the group, set automatically during init
 

        //TODO: document which settings are used only for initial config, and what is used for runtime state

        // Positioning and Transformation
        std::optional<transform::InheritedProperties::Sync> location_bond, rotation_bond, size_bond, scale_bond; // Bonds for transformations
        std::optional<Vector2> offset;                                             // Positional offset
        std::optional<float> scale{1.0f};                                                // UI scale, also applies to text (not sure if it does to size?)
        std::optional<float> textSpacing; // optional spacing parameter for text in UI elements
        std::optional<bool> focusWithObject;                                       // Ensures that when an associated object (e.g., an entity, card, or UI element) gains focus, the UI element also becomes focused. Typically used when a UI element represents an object in the game and should highlight/select the object when focused. Updates the object_focus_timer property.
        std::optional<bool> refreshMovement;                                       // Signals that an object's movement needs to be recalculated, if this config is attached to an object in a UI element. Also makes it update every frame
        std::optional<bool> no_recalc, non_recalc;                                 // Prevents automatic recalculation of UI layout
        bool noMovementWhenDragged = false; // Prevents movement of the UI element when it is being dragged. This is useful for UI elements that should not move when the user interacts with them (sliders)

        // Parent-Child Relationship
        std::optional<entt::entity> master; // alignment master for uibox. If not specified, parent is used, or if not that either, oneself is used.
        std::optional<entt::entity> parent; // Parent UI entity (this is not where the hierarchy is stored, this parent is specified for configuration purposes)
        std::optional<entt::entity> object; // Associated object attached to this ui element (animated text entity, for instanac)
        bool objectRecalculate = false; // If this is set to true, this object (attached to the ui element) will be recalculated when the containing ui element's initializeVisualTransform() method is called. Note that only uibox actually has a recalculate method (meaning a uibox can be attached to a ui element???)
        //TODO: check if this is the case

        // Dimensions and Alignment
        std::optional<int> alignmentFlags;// Alignment setting, center default
        std::optional<int> width, height, maxWidth, maxHeight, minWidth, minHeight; // Size constraints. Max constraints will override normal constraints if they exceed the maximum (except for text.)
        std::optional<float> padding;                                                   // UI element padding

        // Visibility and Styling
        std::optional<Color> color, outlineColor; // UI element colors
        std::optional<float> outlineThickness;               // Outline width (if any)
        bool makeMovementDynamic = false;                    // Makes the UI element's movement dynamic (reflects rotation, scale from transform)
        bool shadow = false;                        // Enables shadows for the UI element.
        bool outlineShadow = false;                 // Enables shadows for the outline of the UI element. Enable only if using outlines, rather than filled rects.
        std::optional<Color> shadowColor;          // Sets the color of the shadow.
        bool noFill = false;                        // Prevents UI filling effect
        bool pixelatedRectangle = true;            // use special rounded rectangle rendering? True by default.

        // Interaction & Collision
        std::optional<bool> canCollide, collideable, forceCollision; // Collision properties (TODO: CanCollide & Collideable are the same?)
        std::optional<entt::entity> button_UIE;                      // Links this UI element to another element that acts as a button. This is used to propagate button clicked/hover state to children for instance, for drawing.
        bool disable_button = false;                                 // If this is a button, is it disabled?

        // UI Element State
        // should return a value between 0 and 1, used for setting the progress bar value, given no ref_component is set
        std::function<float(entt::entity)> progressBarFetchValueLambda = nullptr; 
        bool progressBar = false;                                                            // Indicates if this is a progress bar. A progress bar must have progressBarValueFieldName and progressBarMaxValue and progressBarComponentName set.
        std::optional<Color> progressBarEmptyColor, progressBarFullColor;                    // Progress bar colors
        std::optional<float> progressBarMaxValue;                                            // Max value for progress bar
        std::optional<std::string> progressBarValueComponentName, progressBarValueFieldName; 
        bool ui_object_updated = false;                                                      // Indicates that the UI object needs to be reprocessed, if this config is attached to a UI element's object

        // Button Delays & Clicks
        std::optional<float> buttonDelayStart; //Track when the button delay started and when it should end.
        std::optional<float>  buttonDelay; //Adds a delay before the button can be used again.
        std::optional<float>  buttonDelayProgress; // Represents the progress of the button delay (0 to 1).
        std::optional<float>  buttonDelayEnd;  // Track when the button delay started and when it should end.
        bool buttonClicked = false;                                                              // Tracks if a button has been clicked.
        std::optional<float> buttonDistance;                                                     // Adjusts the visual effect of a button press (parallax effect).

        // Tooltip & Hover Effects
        std::optional<Tooltip> tooltip;
        std::optional<Tooltip> detailedTooltip;
        //TODO: tooltip def must be used to generate uibox
        std::optional<Tooltip> onDemandTooltip; // Creates a tooltip only when hovered.
        bool hover = false;                                               // COnfigures if hovering is allowed for this ui element.

        // Special UI Behaviors
        bool force_focus = false;                      // Forces the UI element to be focusable, even if it normally wouldn't be.
        std::optional<bool> dynamicMotion; // enables jiggle when it first appears.                
        std::optional<bool> choice; // Allows an element to act as part of a selectable group (radio button behavior)
        std::optional<bool> chosen; // Indicates whether this choice has been selected. (displays indicator)
        std::optional<bool> one_press; // Ensures the button can only be pressed once (irreversible)
        std::optional<std::string> chosen_vert;        // Alters the drawing behavior of the "chosen triangle" to be vertical.
        bool draw_after = false;                       //Specifies that this element should be drawn after its children.
        std::optional<FocusArgs> focusArgs;            // Focus arguments for UI elements

        // Function Callbacks & Scripting
        std::optional<std::function<void(entt::registry*, entt::entity, float)>> updateFunc; //  Function to call on update (every frame) & init
        std::optional<std::function<void(entt::registry*, entt::entity)>> initFunc; //  Function to call once when the UI element is initialized
        std::optional<std::function<void(entt::registry*, entt::entity)>> onUIResizeFunc; // Function to call when the UI element is resized
        std::optional<std::function<void(entt::registry*, entt::entity)>> onUIScalingResetToOne; // Function to call when ui scaling should be set to 1.0 global scale (so width & height should be reset)
        
        std::optional<bool> instaFunc;   // Runs func immediately upon ui initialization.
        std::optional<std::function<void()>> buttonCallback; // the button click callback if this is a button
        std::optional<std::function<void()>> buttonTemp;                     // Temporarily stores the button property while button_delay is active.

        // Reference System 
        std::optional<std::function<std::string()>> textGetter; // Function to get text for this element, used to update if this is a text UI element
        std::optional<entt::entity> ref_entity;       // Entity reference
        std::optional<std::string> ref_component;     // Component name (ref_component)
        std::optional<std::string> ref_value;         // Field name within the above component
        std::optional<entt::meta_any> prev_ref_value; // stores a cached version of the value retrieved using the above

        // Text Configuration
        std::optional<std::string> text;     // Display text
        std::optional<std::string> language; // Language for text
        std::optional<bool> verticalText;    // Is the text displayed vertically?

        // Popup Configuration
        std::optional<entt::entity> hPopup;     // hover pop-up (child)
        std::optional<entt::entity> dPopup;     // drag pop-up (child)
        std::shared_ptr<UIConfig> hPopupConfig; // Separate configuration for popups?
        std::shared_ptr<UIConfig> dPopupConfig; // Separate configuration for popups?

        // Miscellaneous
        std::optional<float> extend_up;      // Extra space added upwards for resizing UI elements
        std::optional<float> resolution;     // Used for pixelated rectangle rendering
        std::optional<float> emboss;         // Emboss effect height for UI elements
        bool line_emboss = false;            // Adds an embossed effect to outlines.
        //TODO: check this does as expected
        bool mid = false;                    // Marks the midpoint of a UI structure (transform.mid)
        std::optional<bool> noRole;          // Prevents the element from being assigned a role in the layout.
        std::optional<transform::InheritedProperties> role; // Role component for UI

        struct Builder {
            std::shared_ptr<UIConfig> uiConfig = std::make_shared<UIConfig>();

            static Builder create() {
                return Builder();
            }

            Builder& addId(const std::string& id) {
                uiConfig->id = id;
                return *this;
            }
            
            Builder& addTextGetter(const std::function<std::string()>& textGetter) {
                uiConfig->textGetter = textGetter;
                return *this;
            }

            Builder& addInstanceType(const std::string& instanceType) {
                uiConfig->instanceType = instanceType;
                return *this;
            }

            Builder& addUiType(const UITypeEnum& uiType) {
                uiConfig->uiType = uiType;
                return *this;
            }

            Builder& addDrawLayer(const int& drawLayer) {
                uiConfig->drawLayer = drawLayer;
                return *this;
            }

            Builder& addGroup(const std::string& group) {
                uiConfig->group = group;
                return *this;
            }

            Builder& addLocationBond(const transform::InheritedProperties::Sync& locationBond) {
                uiConfig->location_bond = locationBond;
                return *this;
            }

            Builder& addRotationBond(const transform::InheritedProperties::Sync& rotationBond) {
                uiConfig->rotation_bond = rotationBond;
                return *this;
            }

            Builder& addSizeBond(const transform::InheritedProperties::Sync& sizeBond) {
                uiConfig->size_bond = sizeBond;
                return *this;
            }

            Builder& addScaleBond(const transform::InheritedProperties::Sync& scaleBond) {
                uiConfig->scale_bond = scaleBond;
                return *this;
            }

            Builder& addOffset(const Vector2& offset) {
                uiConfig->offset = offset;
                return *this;
            }

            Builder& addScale(const float& scale) {
                uiConfig->scale = scale;
                return *this;
            }

            Builder& addTextSpacing(const float& textSpacing) {
                uiConfig->textSpacing = textSpacing;
                return *this;
            }

            Builder& addFocusWithObject(const bool& focusWithObject) {
                uiConfig->focusWithObject = focusWithObject;
                return *this;
            }

            Builder& addRefreshMovement(const bool& refreshMovement) {
                uiConfig->refreshMovement = refreshMovement;
                return *this;
            }
            
            Builder& addNoMovementWhenDragged(const bool& noMovementWhenDragged) {
                uiConfig->noMovementWhenDragged = noMovementWhenDragged;
                return *this;
            }

            Builder& addNoRecalc(const bool& noRecalc) {
                uiConfig->no_recalc = noRecalc;
                return *this;
            }

            Builder& addNonRecalc(const bool& nonRecalc) {
                uiConfig->non_recalc = nonRecalc;
                return *this;
            }
            
            Builder& addMakeMovementDynamic(const bool& makeMovementDynamic) {
                uiConfig->makeMovementDynamic = makeMovementDynamic;
                return *this;
            }

            Builder& addMaster(const entt::entity& master) {
                uiConfig->master = master;
                return *this;
            }

            Builder& addParent(const entt::entity& parent) {
                uiConfig->parent = parent;
                return *this;
            }

            Builder& addObject(const entt::entity& object) {
                uiConfig->object = object;
                return *this;
            }
    
    
        
            // align only applies to containers, not to ui elements
            Builder& addAlign(const int& align) {
                uiConfig->alignmentFlags = align;
                return *this;
            }

            Builder& addWidth(const int& width) {
                uiConfig->width = width;
                return *this;
            }

            Builder& addHeight(const int& height) {
                uiConfig->height = height;
                return *this;
            }

            Builder& addMaxWidth(const int& maxWidth) {
                uiConfig->maxWidth = maxWidth;
                return *this;
            }

            Builder& addMaxHeight(const int& maxHeight) {
                uiConfig->maxHeight = maxHeight;
                return *this;
            }

            Builder& addMinWidth(const int& minWidth) {
                uiConfig->minWidth = minWidth;
                return *this;
            }

            Builder& addMinHeight(const int& minHeight) {
                uiConfig->minHeight = minHeight;
                return *this;
            }

            Builder& addPadding(const float& padding) {
                uiConfig->padding = padding;
                return *this;
            }

            Builder& addColor(const Color& colour) {
                uiConfig->color = colour;
                return *this;
            }

            Builder& addOutlineColor(const Color& outlineColour) {
                uiConfig->outlineColor = outlineColour;
                return *this;
            }

            Builder& addOutlineThickness(const float& outlineThickness) {
                uiConfig->outlineThickness = outlineThickness;
                return *this;
            }

            Builder& addShadow(const bool& shadow) {
                uiConfig->shadow = shadow;
                return *this;
            }

            Builder& addShadowColor(const Color& shadowColour) {
                uiConfig->shadowColor = shadowColour;
                return *this;
            }

            Builder& addNoFill(const bool& noFill) {
                uiConfig->noFill = noFill;
                return *this;
            }

            Builder& addPixelatedRectangle(const bool& pixelatedRectangle) {
                uiConfig->pixelatedRectangle = pixelatedRectangle;
                return *this;
            }

            Builder& addCanCollide(const bool& canCollide) {
                uiConfig->canCollide = canCollide;
                return *this;
            }

            Builder& addCollideable(const bool& collideable) {
                uiConfig->collideable = collideable;
                return *this;
            }

            Builder& addForceCollision(const bool& forceCollision) {
                uiConfig->forceCollision = forceCollision;
                return *this;
            }

            Builder& addButtonUIE(const entt::entity& buttonUIE) {
                uiConfig->button_UIE = buttonUIE;
                return *this;
            }

            Builder& addDisableButton(const bool& disableButton) {
                uiConfig->disable_button = disableButton;
                return *this;
            }
            
            Builder& addProgressBarFetchValueLamnda(const std::function<float(entt::entity)>& progressBarFetchValueLambda) {
                uiConfig->progressBarFetchValueLambda = progressBarFetchValueLambda;
                return *this;
            }

            Builder& addProgressBar(const bool& progressBar) {
                uiConfig->progressBar = progressBar;
                return *this;
            }

            Builder& addProgressBarEmptyColor(const Color& progressBarEmptyColor) {
                uiConfig->progressBarEmptyColor = progressBarEmptyColor;
                return *this;
            }

            Builder& addProgressBarFullColor(const Color& progressBarFullColor) {
                uiConfig->progressBarFullColor = progressBarFullColor;
                return *this;
            }

            Builder& addProgressBarMaxValue(const float& progressBarMaxValue) {
                uiConfig->progressBarMaxValue = progressBarMaxValue;
                return *this;
            }

            Builder& addProgressBarValueComponentName(const std::string& progressBarValueComponentName) {
                uiConfig->progressBarValueComponentName = progressBarValueComponentName;
                return *this;
            }

            Builder& addProgressBarValueFieldName(const std::string& progressBarValueFieldName) {
                uiConfig->progressBarValueFieldName = progressBarValueFieldName;
                return *this;
            }

            Builder& addUIObjectUpdated(const bool& uiObjectUpdated) {
                uiConfig->ui_object_updated = uiObjectUpdated;
                return *this;
            }

            Builder& addButtonDelayStart(const float& buttonDelayStart) {
                uiConfig->buttonDelayStart = buttonDelayStart;
                return *this;
            }

            Builder& addButtonDelay(const float& buttonDelay) {
                uiConfig->buttonDelay = buttonDelay;
                return *this;
            }

            Builder& addButtonDelayProgress(const float& buttonDelayProgress) {
                uiConfig->buttonDelayProgress = buttonDelayProgress;
                return *this;
            }

            Builder& addButtonDelayEnd(const float& buttonDelayEnd) {
                uiConfig->buttonDelayEnd = buttonDelayEnd;
                return *this;
            }

            Builder& addButtonClicked(const bool& buttonClicked) {
                uiConfig->buttonClicked = buttonClicked;
                return *this;
            }

            Builder& addButtonDistance(const float& buttonDistance) {
                uiConfig->buttonDistance = buttonDistance;
                return *this;
            }

            Builder& addTooltip(const Tooltip& tooltip) {
                uiConfig->tooltip = tooltip;
                return *this;
            }

            Builder& addDetailedTooltip(const Tooltip& detailedTooltip) {
                uiConfig->detailedTooltip = detailedTooltip;
                return *this;
            }

            Builder& addOnDemandTooltip(const Tooltip& onDemandTooltip) {
                uiConfig->onDemandTooltip = onDemandTooltip;
                return *this;
            }

            Builder& addHover(const bool& hover) {
                uiConfig->hover = hover;
                return *this;
            }

            Builder& addForceFocus(const bool& forceFocus) {
                uiConfig->force_focus = forceFocus;
                return *this;
            }

            Builder& addDynamicMotion(const bool& dynamicMotion) {
                uiConfig->dynamicMotion = dynamicMotion;
                return *this;
            }

            Builder& addChoice(const bool& choice) {
                uiConfig->choice = choice;
                return *this;
            }

            Builder& addChosen(const bool& chosen) {
                uiConfig->chosen = chosen;
                return *this;
            }

            Builder& addOnePress(const bool& onePress) {
                uiConfig->one_press = onePress;
                return *this;
            }

            Builder& addChosenVert(const std::string& chosenVert) {
                uiConfig->chosen_vert = chosenVert;
                return *this;
            }

            Builder& addDrawAfter(const bool& drawAfter) {
                uiConfig->draw_after = drawAfter;
                return *this;
            }

            Builder& addFocusArgs(const FocusArgs& focusArgs) {
                uiConfig->focusArgs = focusArgs;
                return *this;
            }

            Builder& addUpdateFunc(const std::function<void(entt::registry*, entt::entity, float)> &func) {
                uiConfig->updateFunc = func;
                return *this;
            }
            
            Builder& addInitFunc(const std::function<void(entt::registry*, entt::entity)> &func) {
                uiConfig->initFunc = func;
                return *this;
            }
            
            Builder& addOnUIResizeFunc(const std::function<void(entt::registry*, entt::entity)> &func) {
                uiConfig->onUIResizeFunc = func;
                return *this;
            }
            
            Builder& addOnUIScalingResetToOne(const std::function<void(entt::registry*, entt::entity)> &func) {
                uiConfig->onUIScalingResetToOne = func;
                return *this;
            }

            Builder& addInstaFunc(const bool& instaFunc) {
                uiConfig->instaFunc = instaFunc;
                return *this;
            }

            Builder& addButtonCallback(const std::function<void()> buttonCallback) {
                uiConfig->buttonCallback = buttonCallback;
                return *this;
            }

            Builder& addButtonTemp(const std::function<void()> buttonTemp) {
                uiConfig->buttonTemp = buttonTemp;
                return *this;
            }

            Builder& addRefEntity(const entt::entity& refEntity) {
                uiConfig->ref_entity = refEntity;
                return *this;
            }

            Builder& addRefComponent(const std::string& refComponent) {
                uiConfig->ref_component = refComponent;
                return *this;
            }

            Builder& addRefValue(const std::string& refValue) {
                uiConfig->ref_value = refValue;
                return *this;
            }

            Builder& addPrevRefValue(const entt::meta_any& prevRefValue) {
                uiConfig->prev_ref_value = prevRefValue;
                return *this;
            }

            Builder& addText(const std::string& text) {
                uiConfig->text = text;
                return *this;
            }

            Builder& addLanguage(const std::string& language) {
                uiConfig->language = language;
                return *this;
            }

            Builder& addVerticalText(const bool& verticalText) {
                uiConfig->verticalText = verticalText;
                return *this;
            }

            Builder& addHPopup(const entt::entity& hPopup) {
                uiConfig->hPopup = hPopup;
                return *this;
            }

            Builder& addHPopupConfig(const std::shared_ptr<UIConfig>& hPopupConfig) {
                uiConfig->hPopupConfig = hPopupConfig;
                return *this;
            }

            Builder& addDPopup(const entt::entity& dPopup) {
                uiConfig->dPopup = dPopup;
                return *this;
            }

            Builder& addDPopupConfig(const std::shared_ptr<UIConfig>& dPopupConfig) {
                uiConfig->dPopupConfig = dPopupConfig;
                return *this;
            }

            Builder& addExtendUp(const float& extendUp) {
                uiConfig->extend_up = extendUp;
                return *this;
            }

            Builder& addResolution(const float& resolution) {
                uiConfig->resolution = resolution;
                return *this;
            }

            Builder& addEmboss(const float& emboss) {
                uiConfig->emboss = emboss;
                return *this;
            }

            Builder& addLineEmboss(const bool& lineEmboss) {
                uiConfig->line_emboss = lineEmboss;
                return *this;
            }

            Builder& addMid(const bool& mid) {
                uiConfig->mid = mid;
                return *this;
            }

            Builder& addNoRole(const bool& noRole) {
                uiConfig->noRole = noRole;
                return *this;
            }

            Builder& addRole(const transform::InheritedProperties& role) {
                uiConfig->role = role;
                return *this;
            }
            
            Builder& addStylingType(const UIStylingType& stylingType) {
                uiConfig->stylingType = stylingType;
                return *this;
            }

            Builder& addNPatchInfo(const std::optional<NPatchInfo>& nPatchInfo) {
                uiConfig->nPatchInfo = nPatchInfo;
                return *this;
            }

            Builder& addNPatchSourceTexture(const std::optional<Texture2D>& nPatchSourceTexture) {
                uiConfig->nPatchSourceTexture = nPatchSourceTexture;
                return *this;
            }

            UIConfig build() {
                return *uiConfig;
            }
        };
    };

    // TODO: probably get rid of intermediate types like this?
    struct TransformConfig
    {
        float x;
        float y;
        float w;
        float h;
        float r;
    };

    // Create a local variable to store the calculated transform values
    struct LocalTransform
    {
        float x = 0.f, y = 0.f, w = 0.f, h = 0.f;
    };

    // used for generating ui definitions
    struct UIElementTemplateNode
    {
        UITypeEnum type{UITypeEnum::NONE};                             // Type of UI Element (e.g., ROOT, TEXT, COLUMN)
        UIConfig config;                             // Config settings (align, padding, color, etc.)
        std::vector<UIElementTemplateNode> children; // Child UI elements
        struct Builder;   // <-- just announce it exists

        
    };
    
    
    struct UIElementTemplateNode::Builder {
        UIElementTemplateNode uiElement{};
        bool addTypeCalled = false; // Flag to check if addType was called

        static Builder create() {
            return Builder();
        }

        Builder& addType(const UITypeEnum& type) {
            if (!magic_enum::enum_contains<UITypeEnum>(type)) {
                throw std::invalid_argument(
                  std::string("addType(): invalid UITypeEnum value = ")
                  + std::to_string(static_cast<int>(type))
                );
            }
            uiElement.type = type;
            addTypeCalled = true; // Set the flag to true when addType is called
            return *this;
        }

        Builder& addConfig(const UIConfig& config) {
            uiElement.config = config;
            return *this;
        }
        
        Builder& addChild(const UIElementTemplateNode& child) {
            uiElement.children.push_back(child);
            return *this;
        }

        UIElementTemplateNode build() {
            // assert that addType was called for this builder.
            if (!addTypeCalled) {
                throw std::runtime_error("UIElementTemplateNode must have a type set before building.");
            }
            return uiElement;
        }
    };

    // Data structure for drawing a pixellated rectangle with rough edges
    struct UIPixellatedRect {
        float w = 0.0f;    // Width of the rectangle
        float h = 0.0f;    // Height of the rectangle
        float shadowX = 0.0f; // X shadow offset
        float shadowY = 0.0f; // Y shadow offset
        float progress = 1.0f; // Animation progress (0-1)

        float parallax = 1.5f; // Parallax factor

        std::map<std::string, std::vector<float>> vertices; // Vertices for different types of pixelated rectangles

        UIPixellatedRect() = default;

        // Constructor to initialize with values
        UIPixellatedRect(float width, float height, float shadowOffsetX, float shadowOffsetY, float prog) 
            : w(width), h(height), shadowX(shadowOffsetX), shadowY(shadowOffsetY), progress(prog) {}

        // Function to clear the vertices
        void clearVertices() {
            vertices.clear();
        }

        // Function to check if the cache needs an update
        bool isOutdated(float newW, float newH, float newShadowX, float newShadowY, float newProgress) const {
            return (w != newW || h != newH || shadowX != newShadowX || shadowY != newShadowY || progress != newProgress);
        }
    };
    
    const int RoundedRectangleVerticesCache_TYPE_NONE          = 0;
    const int RoundedRectangleVerticesCache_TYPE_FILL          = 1 << 0;
    const int RoundedRectangleVerticesCache_TYPE_OUTLINE       = 1 << 1;
    const int RoundedRectangleVerticesCache_TYPE_SHADOW        = 1 << 2;
    const int RoundedRectangleVerticesCache_TYPE_EMBOSS        = 1 << 3;
    const int RoundedRectangleVerticesCache_TYPE_LINE_EMBOSS   = 1 << 4;

    struct RoundedRectangleVerticesCache {

        int renderTypeFlags = RoundedRectangleVerticesCache_TYPE_NONE;

        float w = 0.0f;    // Width of the full rectangle (not reflecting prgoress)
        float h = 0.0f;    // Height of the full rectangle (not reflecting prgoress)
        Vector2 shadowDisplacement = {0, 0}; // shadow displacement
        std::optional<float> progress = 1.0f; // modifies the width of the rect by scale if active

        float lineThickness = 1.0f; // Thickness of the outline, in pixels
        std::vector<Vector2> innerVerticesProgressReflected{}; // inner vertices for rounded rect (reflects progress value in width)
        std::vector<Vector2> outerVerticesProgressReflected{}; // outer vertices for rounded rect (reflects progress value in width)

        std::vector<Vector2> innerVerticesFullRect{}; // inner vertices for rounded rect (full width)
        std::vector<Vector2> outerVerticesFullRect{}; // outer vertices for rounded rect (full width)

    };

    extern bool uiGroupInitialized; // Flag to check if the UI group has been initialized
    extern decltype(std::declval<entt::registry&>()
                 .group<
                   UIElementComponent,
                   UIConfig,
                   UIState,
                   transform::GameObject,
                   transform::Transform
                 >()) globalUIGroup;
    
    
}