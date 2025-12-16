#pragma once

#include "entt/entity/fwd.hpp"
#include "util/common_headers.hpp"
#include "systems/transform/transform_functions.hpp"
#include "systems/ui/ui_data.hpp"  // For UITypeEnum, UIStylingType, etc.
#include "systems/nine_patch/nine_patch_baker.hpp"  // For NPatchTiling
#include "systems/ui/ui_pack.hpp"  // For SpriteScaleMode

#include <string>
#include <optional>
#include <functional>

namespace ui {

// Forward declaration for compatibility layer
struct UIConfig;

// =============================================================================
// UIElementCore - Identity and hierarchy (always present)
// =============================================================================
struct UIElementCore {
    UITypeEnum type{UITypeEnum::NONE};
    entt::entity uiBox{entt::null};
    std::string id;
    int treeOrder{0};
};

// =============================================================================
// UIStyleConfig - Visual appearance only
// =============================================================================
struct UIStyleConfig {
    // Styling type
    UIStylingType stylingType{UIStylingType::ROUNDED_RECTANGLE};

    // Colors
    std::optional<Color> color;
    std::optional<Color> outlineColor;
    std::optional<Color> shadowColor;
    std::optional<Color> progressBarEmptyColor;
    std::optional<Color> progressBarFullColor;

    // Outline & effects
    std::optional<float> outlineThickness;
    std::optional<float> emboss;
    std::optional<float> resolution;
    bool shadow{false};
    bool outlineShadow{false};
    bool noFill{false};
    bool pixelatedRectangle{true};
    bool line_emboss{false};

    // 9-patch styling
    std::optional<NPatchInfo> nPatchInfo;
    std::optional<Texture2D> nPatchSourceTexture;
    std::optional<nine_patch::NPatchTiling> nPatchTiling;

    // Sprite styling
    std::optional<Texture2D*> spriteSourceTexture;
    std::optional<Rectangle> spriteSourceRect;
    SpriteScaleMode spriteScaleMode{SpriteScaleMode::Stretch};
};

// =============================================================================
// UILayoutConfig - Positioning and dimensions
// =============================================================================
struct UILayoutConfig {
    // Dimensions
    std::optional<int> width, height;
    std::optional<int> maxWidth, maxHeight;
    std::optional<int> minWidth, minHeight;
    std::optional<float> padding;
    std::optional<float> extend_up;

    // Alignment
    std::optional<int> alignmentFlags;

    // Transform bonds
    std::optional<transform::InheritedProperties::Sync> location_bond;
    std::optional<transform::InheritedProperties::Sync> rotation_bond;
    std::optional<transform::InheritedProperties::Sync> size_bond;
    std::optional<transform::InheritedProperties::Sync> scale_bond;

    // Position & scale
    std::optional<Vector2> offset;
    std::optional<float> scale;

    // Layout behavior
    std::optional<bool> no_recalc;
    std::optional<bool> non_recalc;
    bool mid{false};
    std::optional<bool> noRole;
    std::optional<transform::InheritedProperties> role;

    // Hierarchy
    std::optional<entt::entity> master;
    std::optional<entt::entity> parent;
    std::optional<int> drawLayer;
    bool draw_after{false};
};

// =============================================================================
// UIInteractionConfig - Input handling and callbacks
// =============================================================================
struct UIInteractionConfig {
    // Collision & interaction flags
    std::optional<bool> canCollide;
    std::optional<bool> collideable;
    std::optional<bool> forceCollision;
    bool hover{false};

    // Button behavior
    std::optional<entt::entity> button_UIE;
    bool disable_button{false};
    std::optional<float> buttonDelay;
    std::optional<float> buttonDelayStart;
    std::optional<float> buttonDelayEnd;
    std::optional<float> buttonDelayProgress;
    std::optional<float> buttonDistance;
    bool buttonClicked{false};

    // Focus
    bool force_focus{false};
    std::optional<bool> focusWithObject;
    std::optional<FocusArgs> focusArgs;

    // Tooltips
    std::optional<Tooltip> tooltip;
    std::optional<Tooltip> detailedTooltip;
    std::optional<Tooltip> onDemandTooltip;

    // Callbacks
    std::optional<std::function<void()>> buttonCallback;
    std::optional<std::function<void()>> buttonTemp;
    std::optional<std::function<void(entt::registry*, entt::entity, float)>> updateFunc;
    std::optional<std::function<void(entt::registry*, entt::entity)>> initFunc;
    std::optional<std::function<void(entt::registry*, entt::entity)>> onUIResizeFunc;
    std::optional<std::function<void(entt::registry*, entt::entity)>> onUIScalingResetToOne;
    std::optional<bool> instaFunc;

    // Choice/selection
    std::optional<bool> choice;
    std::optional<bool> chosen;
    std::optional<bool> one_press;
    std::optional<std::string> chosen_vert;
    std::optional<std::string> group;
    std::optional<entt::entity> groupParent;

    // Motion
    std::optional<bool> dynamicMotion;
    bool makeMovementDynamic{false};
    bool noMovementWhenDragged{false};
    std::optional<bool> refreshMovement;
};

// =============================================================================
// UIContentConfig - Text, objects, references (type-specific content)
// =============================================================================
struct UIContentConfig {
    // Text
    std::optional<std::string> text;
    std::optional<std::string> language;
    std::optional<bool> verticalText;
    std::optional<float> textSpacing;
    std::optional<float> fontSize;
    std::optional<std::string> fontName;
    std::optional<std::function<std::string()>> textGetter;

    // Object attachment
    std::optional<entt::entity> object;
    bool objectRecalculate{false};
    bool ui_object_updated{false};
    bool includeChildrenInShaderPass{true};

    // Progress bar
    bool progressBar{false};
    std::optional<float> progressBarMaxValue;
    std::optional<std::string> progressBarValueComponentName;
    std::optional<std::string> progressBarValueFieldName;
    std::optional<std::function<float(entt::entity)>> progressBarFetchValueLambda;

    // Reference system
    std::optional<entt::entity> ref_entity;
    std::optional<std::string> ref_component;
    std::optional<std::string> ref_value;
    std::optional<entt::meta_any> prev_ref_value;

    // Popups
    std::optional<entt::entity> hPopup;
    std::optional<entt::entity> dPopup;
    std::shared_ptr<UIConfig> hPopupConfig;
    std::shared_ptr<UIConfig> dPopupConfig;

    // Instance metadata
    std::optional<std::string> instanceType;
};

// =============================================================================
// UIConfigBundle - For passing all configs through builder
// =============================================================================
struct UIConfigBundle {
    UIStyleConfig style;
    UILayoutConfig layout;
    UIInteractionConfig interaction;
    UIContentConfig content;
};

// =============================================================================
// Extraction functions (Phase 1 compatibility layer)
// =============================================================================
UIStyleConfig extractStyle(const UIConfig& config);
UILayoutConfig extractLayout(const UIConfig& config);
UIInteractionConfig extractInteraction(const UIConfig& config);
UIContentConfig extractContent(const UIConfig& config);

} // namespace ui
