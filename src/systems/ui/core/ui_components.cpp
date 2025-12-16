#include "ui_components.hpp"

namespace ui {

UIStyleConfig extractStyle(const UIConfig& c) {
    UIStyleConfig s;
    s.stylingType = c.stylingType;
    s.color = c.color;
    s.outlineColor = c.outlineColor;
    s.shadowColor = c.shadowColor;
    s.progressBarEmptyColor = c.progressBarEmptyColor;
    s.progressBarFullColor = c.progressBarFullColor;
    s.outlineThickness = c.outlineThickness;
    s.emboss = c.emboss;
    s.resolution = c.resolution;
    s.shadow = c.shadow;
    s.outlineShadow = c.outlineShadow;
    s.noFill = c.noFill;
    s.pixelatedRectangle = c.pixelatedRectangle;
    s.line_emboss = c.line_emboss;
    s.nPatchInfo = c.nPatchInfo;
    s.nPatchSourceTexture = c.nPatchSourceTexture;
    s.nPatchTiling = c.nPatchTiling;
    s.spriteSourceTexture = c.spriteSourceTexture;
    s.spriteSourceRect = c.spriteSourceRect;
    s.spriteScaleMode = c.spriteScaleMode;
    return s;
}

UILayoutConfig extractLayout(const UIConfig& c) {
    UILayoutConfig l;
    l.width = c.width;
    l.height = c.height;
    l.maxWidth = c.maxWidth;
    l.maxHeight = c.maxHeight;
    l.minWidth = c.minWidth;
    l.minHeight = c.minHeight;
    l.padding = c.padding;
    l.extend_up = c.extend_up;
    l.alignmentFlags = c.alignmentFlags;
    l.location_bond = c.location_bond;
    l.rotation_bond = c.rotation_bond;
    l.size_bond = c.size_bond;
    l.scale_bond = c.scale_bond;
    l.offset = c.offset;
    l.scale = c.scale;
    l.no_recalc = c.no_recalc;
    l.non_recalc = c.non_recalc;
    l.mid = c.mid;
    l.noRole = c.noRole;
    l.role = c.role;
    l.master = c.master;
    l.parent = c.parent;
    l.drawLayer = c.drawLayer;
    l.draw_after = c.draw_after;
    return l;
}

UIInteractionConfig extractInteraction(const UIConfig& c) {
    UIInteractionConfig i;
    i.canCollide = c.canCollide;
    i.collideable = c.collideable;
    i.forceCollision = c.forceCollision;
    i.hover = c.hover;
    i.button_UIE = c.button_UIE;
    i.disable_button = c.disable_button;
    i.buttonDelay = c.buttonDelay;
    i.buttonDelayStart = c.buttonDelayStart;
    i.buttonDelayEnd = c.buttonDelayEnd;
    i.buttonDelayProgress = c.buttonDelayProgress;
    i.buttonDistance = c.buttonDistance;
    i.buttonClicked = c.buttonClicked;
    i.force_focus = c.force_focus;
    i.focusWithObject = c.focusWithObject;
    i.focusArgs = c.focusArgs;
    i.tooltip = c.tooltip;
    i.detailedTooltip = c.detailedTooltip;
    i.onDemandTooltip = c.onDemandTooltip;
    i.buttonCallback = c.buttonCallback;
    i.buttonTemp = c.buttonTemp;
    i.updateFunc = c.updateFunc;
    i.initFunc = c.initFunc;
    i.onUIResizeFunc = c.onUIResizeFunc;
    i.onUIScalingResetToOne = c.onUIScalingResetToOne;
    i.instaFunc = c.instaFunc;
    i.choice = c.choice;
    i.chosen = c.chosen;
    i.one_press = c.one_press;
    i.chosen_vert = c.chosen_vert;
    i.group = c.group;
    i.groupParent = c.groupParent;
    i.dynamicMotion = c.dynamicMotion;
    i.makeMovementDynamic = c.makeMovementDynamic;
    i.noMovementWhenDragged = c.noMovementWhenDragged;
    i.refreshMovement = c.refreshMovement;
    return i;
}

UIContentConfig extractContent(const UIConfig& c) {
    UIContentConfig t;
    t.text = c.text;
    t.language = c.language;
    t.verticalText = c.verticalText;
    t.textSpacing = c.textSpacing;
    t.fontSize = c.fontSize;
    t.fontName = c.fontName;
    t.textGetter = c.textGetter;
    t.object = c.object;
    t.objectRecalculate = c.objectRecalculate;
    t.ui_object_updated = c.ui_object_updated;
    t.includeChildrenInShaderPass = c.includeChildrenInShaderPass;
    t.progressBar = c.progressBar;
    t.progressBarMaxValue = c.progressBarMaxValue;
    t.progressBarValueComponentName = c.progressBarValueComponentName;
    t.progressBarValueFieldName = c.progressBarValueFieldName;
    t.progressBarFetchValueLambda = c.progressBarFetchValueLambda;
    t.ref_entity = c.ref_entity;
    t.ref_component = c.ref_component;
    t.ref_value = c.ref_value;
    t.prev_ref_value = c.prev_ref_value;
    t.hPopup = c.hPopup;
    t.dPopup = c.dPopup;
    t.hPopupConfig = c.hPopupConfig;
    t.dPopupConfig = c.dPopupConfig;
    t.instanceType = c.instanceType;
    return t;
}

} // namespace ui
