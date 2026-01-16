// src/systems/ui/type_traits.hpp
// UI type classification utilities for box.cpp refactoring.
// Part of the Phase 2 utility extraction.
//
// These helpers centralize the UITypeEnum classification logic that was
// previously scattered across many switch statements in box.cpp.
#pragma once

#include "systems/ui/ui_data.hpp"

namespace ui {

/// Type classification utilities for UITypeEnum
/// Centralizes type checking logic that was previously scattered across box.cpp
struct TypeTraits {
    /// Types that arrange children vertically (one per row)
    static constexpr bool isVerticalFlow(UITypeEnum t) {
        return t == UITypeEnum::VERTICAL_CONTAINER ||
               t == UITypeEnum::ROOT ||
               t == UITypeEnum::SCROLL_PANE;
    }

    /// Types that arrange children horizontally (one per column)
    static constexpr bool isHorizontalFlow(UITypeEnum t) {
        return t == UITypeEnum::HORIZONTAL_CONTAINER;
    }

    /// Types that can contain children (layout containers)
    static constexpr bool isContainer(UITypeEnum t) {
        return isVerticalFlow(t) || isHorizontalFlow(t);
    }

    /// Types that are leaf nodes (cannot have children, have intrinsic content)
    static constexpr bool isLeaf(UITypeEnum t) {
        return t == UITypeEnum::RECT_SHAPE ||
               t == UITypeEnum::TEXT ||
               t == UITypeEnum::OBJECT ||
               t == UITypeEnum::INPUT_TEXT ||
               t == UITypeEnum::SLIDER_UI;
    }

    /// Types that need content-based sizing (text measurement, sprite size, etc.)
    static constexpr bool needsIntrinsicSizing(UITypeEnum t) {
        return t == UITypeEnum::TEXT ||
               t == UITypeEnum::OBJECT;
    }

    /// Types that can receive text content
    static constexpr bool isTextElement(UITypeEnum t) {
        return t == UITypeEnum::TEXT ||
               t == UITypeEnum::INPUT_TEXT;
    }

    /// Types that display sprites or game objects
    static constexpr bool isVisualElement(UITypeEnum t) {
        return t == UITypeEnum::OBJECT ||
               t == UITypeEnum::RECT_SHAPE;
    }

    /// Types that can be interacted with (clicked, hovered)
    static constexpr bool isInteractive(UITypeEnum t) {
        return t == UITypeEnum::RECT_SHAPE ||
               t == UITypeEnum::TEXT ||
               t == UITypeEnum::INPUT_TEXT ||
               t == UITypeEnum::OBJECT ||
               t == UITypeEnum::SLIDER_UI;
    }

    /// Types that accumulate child dimensions in the main axis
    /// For vertical: accumulates heights, takes max width
    /// For horizontal: accumulates widths, takes max height
    static constexpr bool accumulatesMainAxis(UITypeEnum t) {
        return isContainer(t);
    }

    /// Get the string name of a UITypeEnum for debugging
    static const char* typeName(UITypeEnum t) {
        switch (t) {
            case UITypeEnum::NONE:                 return "NONE";
            case UITypeEnum::ROOT:                 return "ROOT";
            case UITypeEnum::VERTICAL_CONTAINER:   return "VERTICAL_CONTAINER";
            case UITypeEnum::HORIZONTAL_CONTAINER: return "HORIZONTAL_CONTAINER";
            case UITypeEnum::SCROLL_PANE:          return "SCROLL_PANE";
            case UITypeEnum::SLIDER_UI:            return "SLIDER_UI";
            case UITypeEnum::INPUT_TEXT:           return "INPUT_TEXT";
            case UITypeEnum::RECT_SHAPE:           return "RECT_SHAPE";
            case UITypeEnum::TEXT:                 return "TEXT";
            case UITypeEnum::OBJECT:               return "OBJECT";
            default:                               return "UNKNOWN";
        }
    }
};

} // namespace ui
