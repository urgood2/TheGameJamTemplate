// src/systems/ui/layout_metrics.hpp
// Layout metrics helper for box.cpp refactoring.
// Part of the Phase 2 utility extraction.
//
// Bundles related sizing values (padding, emboss, scale) with helper
// methods for consistent calculations throughout the sizing pass.
#pragma once

#include "systems/ui/ui_data.hpp"
#include "core/globals.hpp"
#include "raylib.h"  // For Vector2

namespace ui {

/// Bundles layout-related metrics from UIConfig with helper calculations.
/// Use LayoutMetrics::from(config) to create from a UIConfig.
struct LayoutMetrics {
    float padding;      ///< Effective padding (config padding * scale * globalScale)
    float emboss;       ///< Emboss depth (config emboss * scale * globalScale)
    float scale;        ///< Element-specific scale (default 1.0)
    float globalScale;  ///< Global UI scale factor

    /// Create LayoutMetrics from a UIConfig
    /// @param cfg The UIConfig to extract metrics from
    /// @return LayoutMetrics with all values computed
    static LayoutMetrics from(const UIConfig& cfg) {
        float s = cfg.scale.value_or(1.0f);
        float gs = globals::getGlobalUIScaleFactor();
        return {
            .padding = cfg.effectivePadding(),
            .emboss = cfg.emboss.value_or(0.f) * s * gs,
            .scale = s,
            .globalScale = gs
        };
    }

    /// Create LayoutMetrics with explicit values (for testing)
    static LayoutMetrics manual(float p, float e, float s, float gs) {
        return { .padding = p, .emboss = e, .scale = s, .globalScale = gs };
    }

    /// Content area dimensions after removing padding from all sides
    /// @param w Total width including padding
    /// @param h Total height including padding
    /// @return Inner content area dimensions
    Vector2 contentArea(float w, float h) const {
        return { w - 2.f * padding, h - 2.f * padding };
    }

    /// Offset from element origin to content area origin (top-left of content)
    Vector2 contentOffset() const {
        return { padding, padding };
    }

    /// Total height including emboss shadow
    /// @param baseHeight Height without emboss
    /// @return Height with emboss added
    float totalHeight(float baseHeight) const {
        return baseHeight + emboss;
    }

    /// Total width including emboss shadow (if emboss affects width)
    /// @param baseWidth Width without emboss
    /// @return Width with emboss added
    float totalWidth(float baseWidth) const {
        return baseWidth + emboss;
    }

    /// Combined scale factor (element scale * global scale)
    float combinedScale() const {
        return scale * globalScale;
    }

    /// Apply combined scale to a dimension
    float scaled(float value) const {
        return value * combinedScale();
    }

    /// Apply combined scale to a size
    Vector2 scaled(Vector2 size) const {
        return { size.x * combinedScale(), size.y * combinedScale() };
    }

    /// Calculate size with padding added on all sides
    /// @param contentW Content width
    /// @param contentH Content height
    /// @return Total size with padding on all sides
    Vector2 withPadding(float contentW, float contentH) const {
        return { contentW + 2.f * padding, contentH + 2.f * padding };
    }

    /// Add trailing padding to accumulated dimension (for container sizing)
    /// After iterating children, each adds their size + padding.
    /// This adds the final trailing padding.
    float addTrailingPadding(float accumulated) const {
        return accumulated + padding;
    }

    /// Check if this element has any emboss effect
    bool hasEmboss() const {
        return emboss > 0.f;
    }

    /// Check if this element has custom (non-default) scale
    bool hasCustomScale() const {
        return scale != 1.0f;
    }
};

} // namespace ui
