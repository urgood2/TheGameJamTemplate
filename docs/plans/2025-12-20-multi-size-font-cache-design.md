# Multi-Size Font Cache Design

**Date:** 2025-12-20
**Status:** Approved
**Problem:** Korean fonts (Galmuri11 pixel font) appear pixelated when loaded at one size and rendered at another.

## Background

Galmuri11 is a bitmap/pixel font designed for 11px or integer multiples (22, 33, 44px). Currently:
- Korean tooltip font loaded at 32px
- Rendered at 22px (tooltipStyle.fontSize)
- DrawTextPro scales 32→22 (0.6875×), destroying pixel-perfect edges

## Design Decisions

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| Size selection | Nearest size, prefer larger | Downscaling with bilinear looks better than upscaling |
| Configuration | Per-language `sizes` array | Allows Korean to use 11px multiples, English to use common UI sizes |
| API | Automatic selection | Zero changes to existing UI code |
| Implementation | C++ only | Avoids Lua↔C++ round trips, single source of truth |
| Loading | Eager at startup | Predictable memory, no runtime hitches |
| Lua access | Explicit bindings | For manual command buffer rendering |

## Configuration Schema

### Updated fonts.json

```json
{
  "en_us": {
    "file": "fonts/en/Kenney Thick.ttf",
    "sizes": [16, 22, 32, 44],
    "defaultSize": 22,
    "scale": 1.0,
    "spacing": 1.0,
    "offset": [0, 0],
    "ranges": [[32, 126]]
  },
  "ko_kr": {
    "file": "fonts/ko/Galmuri11-Bold.ttf",
    "sizes": [11, 22, 33, 44],
    "defaultSize": 22,
    "scale": 1.0,
    "spacing": 1.2,
    "offset": [2, 0],
    "ranges": [[32, 126], [4352, 4607], [12592, 12687], [44032, 55203]]
  }
}
```

**Backward compatibility:** Falls back to legacy `loadedSize` if `sizes` array missing.

## C++ Data Structures

### Updated FontData (globals.hpp)

```cpp
struct FontData {
    // Existing fields
    float fontScale = 1.0f;
    float spacing = 1.0f;
    Vector2 fontRenderOffset = {0, 0};
    std::vector<int> codepoints;

    // Multi-size font cache
    std::map<int, Font> fontsBySize;  // size -> Font (sorted)
    int defaultSize = 22;

    // Returns best font for requested size (prefers larger)
    const Font& getBestFontForSize(float requestedSize) const {
        int requested = static_cast<int>(std::round(requestedSize));
        auto it = fontsBySize.lower_bound(requested);
        if (it != fontsBySize.end()) {
            return it->second;
        }
        return fontsBySize.rbegin()->second;
    }
};
```

## Font Loading (localization.cpp)

```cpp
void loadFontData(const std::string &jsonPath) {
    // ... JSON parsing ...

    for (auto &[lang, fontJ] : j.items()) {
        globals::FontData fd;

        // Parse sizes array (with legacy fallback)
        std::vector<int> sizes;
        if (fontJ.contains("sizes") && fontJ["sizes"].is_array()) {
            for (auto& s : fontJ["sizes"]) {
                sizes.push_back(s.get<int>());
            }
        } else if (fontJ.contains("loadedSize")) {
            sizes.push_back(static_cast<int>(fontJ["loadedSize"].get<float>()));
        } else {
            sizes.push_back(22);
        }

        fd.defaultSize = fontJ.value("defaultSize", sizes[0]);

        // ... codepoint parsing ...

        // Load font at each size
        std::string file = util::getRawAssetPathNoUUID(fontJ["file"].get<std::string>());
        for (int size : sizes) {
            Font font = LoadFontEx(file.c_str(), size,
                                   fd.codepoints.data(), fd.codepoints.size());
            if (font.texture.id != 0) {
                SetTextureFilter(font.texture, TEXTURE_FILTER_BILINEAR);
                fd.fontsBySize[size] = font;
            }
        }

        languageFontData[lang] = std::move(fd);
    }
}
```

## Render-Time Usage (element.cpp)

```cpp
// Select best-sized font, render at native size (no GPU scaling)
const auto& fontData = localization::getNamedFont(fontName);
float requestedSize = config->fontSize.value_or(fontData.defaultSize);
const Font& bestFont = fontData.getBestFontForSize(requestedSize);
int actualSize = bestFont.baseSize;
layer::TextPro(text, bestFont, x, y, {0,0}, 0, actualSize, spacing, color);
```

## Lua API

```cpp
// New bindings in localization.cpp
lua["localization"]["getBestFontForSize"] = [](const std::string& fontName,
                                                 float requestedSize) -> Font {
    const auto& fontData = getNamedFont(fontName);
    return fontData.getBestFontForSize(requestedSize);
};

lua["localization"]["getBestFontSizeFor"] = [](const std::string& fontName,
                                                float requestedSize) -> int {
    const auto& fontData = getNamedFont(fontName);
    return fontData.getBestFontForSize(requestedSize).baseSize;
};
```

### Lua Usage

```lua
local bestFont = localization.getBestFontForSize("tooltip", 22)
local actualSize = bestFont.baseSize
layer.queueTextPro(myLayer, function(cmd)
    cmd.text = "Hello"
    cmd.font = bestFont
    cmd.fontSize = actualSize
end, z)
```

## Files to Modify

| File | Changes |
|------|---------|
| `assets/localization/fonts.json` | Add `sizes` arrays, add `defaultSize` |
| `src/core/globals.hpp` | Update `FontData` struct |
| `src/systems/localization/localization.cpp` | Multi-size loading, Lua bindings |
| `src/systems/ui/element.cpp` | Use `getBestFontForSize()` |
| `src/systems/ui/handlers/text_handler.cpp` | Same pattern |

## Memory Impact

- Korean: 4 sizes × ~2.5MB ≈ 10MB (vs 2.5MB before)
- English: 4 sizes × ~50KB ≈ 200KB (vs 50KB before)
- Acceptable trade-off for crisp text
