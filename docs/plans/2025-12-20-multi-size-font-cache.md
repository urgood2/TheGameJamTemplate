# Multi-Size Font Cache Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Eliminate font pixelation by loading fonts at multiple sizes and selecting the best match at render time.

**Architecture:** Extend `FontData` struct to store multiple font sizes in a sorted map. At render time, select the closest (preferring larger) cached size and render at 1:1 scale. Expose selection API to Lua for manual command buffer rendering.

**Tech Stack:** C++ (localization system), Raylib (LoadFontEx, SetTextureFilter), JSON (fonts.json config), Sol2 (Lua bindings)

---

## Task 1: Update fonts.json Configuration

**Files:**
- Modify: `assets/localization/fonts.json`

**Step 1: Update English font config**

Replace the English section with multi-size configuration:

```json
"en_us": {
  "file": "fonts/en/Kenney Thick.ttf",
  "sizes": [16, 22, 32, 44],
  "defaultSize": 22,
  "scale": 1.0,
  "spacing": 1.0,
  "offset": [0, 0],
  "ranges": [
    [32, 126]
  ],
  "__Comment": "ranges: 0x0020 → 32, 0x007E → 126."
}
```

**Step 2: Update Korean font config**

Replace the Korean section with multi-size configuration (using Galmuri's 11px multiples):

```json
"ko_kr": {
  "file": "fonts/ko/Galmuri11-Bold.ttf",
  "sizes": [11, 22, 33, 44],
  "defaultSize": 22,
  "scale": 1.0,
  "spacing": 1.2,
  "offset": [2, 0],
  "ranges": [
    [32, 126],
    [4352, 4607],
    [12592, 12687],
    [44032, 55203]
  ],
  "__Comment": "ranges: ASCII; 0x1100 → 4352, 0x11FF → 4607; 0x3130 → 12592, 0x318F → 12687; 0xAC00 → 44032, 0xD7A3 → 55203"
}
```

**Step 3: Commit**

```bash
git add assets/localization/fonts.json
git commit -m "config: add multi-size font arrays to fonts.json"
```

---

## Task 2: Update FontData Struct

**Files:**
- Modify: `src/core/globals.hpp`

**Step 1: Find the FontData struct**

Search for `struct FontData` in globals.hpp (around line 50-70).

**Step 2: Update the struct**

Replace the existing FontData struct with:

```cpp
struct FontData {
  // Multi-size font cache (size -> Font, sorted for efficient lookup)
  std::map<int, Font> fontsBySize;
  int defaultSize = 22;

  // Existing fields
  float fontScale = 1.0f;
  float spacing = 1.0f;
  Vector2 fontRenderOffset = {0, 0};
  std::vector<int> codepoints;

  // Returns the best font for requested size (prefers larger sizes for downscaling)
  const Font& getBestFontForSize(float requestedSize) const {
    int requested = static_cast<int>(std::round(requestedSize));

    // Find smallest size >= requested (prefer downscaling)
    auto it = fontsBySize.lower_bound(requested);
    if (it != fontsBySize.end()) {
      return it->second;
    }
    // Fall back to largest available size
    if (!fontsBySize.empty()) {
      return fontsBySize.rbegin()->second;
    }
    // Ultimate fallback - return empty font (should never happen)
    static Font empty{};
    return empty;
  }

  // Convenience: get default font
  const Font& getDefaultFont() const {
    return getBestFontForSize(static_cast<float>(defaultSize));
  }
};
```

**Step 3: Add required include**

At the top of globals.hpp, ensure `<map>` is included:

```cpp
#include <map>
```

**Step 4: Commit**

```bash
git add src/core/globals.hpp
git commit -m "feat: update FontData struct for multi-size cache"
```

---

## Task 3: Update Font Loading Logic

**Files:**
- Modify: `src/systems/localization/localization.cpp`

**Step 1: Update loadFontData() function**

Find `void loadFontData(const std::string &jsonPath)` (around line 42).

Replace the loading loop contents. The key changes are:
1. Parse `sizes` array (with fallback to legacy `loadedSize`)
2. Parse `defaultSize`
3. Loop through sizes and call LoadFontEx for each
4. Apply TEXTURE_FILTER_BILINEAR to each font texture

```cpp
void loadFontData(const std::string &jsonPath) {
  std::ifstream f(jsonPath);
  if (!f.is_open()) {
    SPDLOG_ERROR("Failed to open font JSON file: {}", jsonPath);
    return;
  }

  json j;
  try {
    f >> j;
  } catch (const std::exception &e) {
    SPDLOG_ERROR("Failed to parse font JSON '{}': {}", jsonPath, e.what());
    return;
  }

  for (auto &[lang, fontJ] : j.items()) {
    globals::FontData fd;

    // --- Parse sizes array (with fallback to legacy loadedSize) ---
    std::vector<int> sizes;
    if (fontJ.contains("sizes") && fontJ["sizes"].is_array()) {
      for (auto &s : fontJ["sizes"]) {
        sizes.push_back(s.get<int>());
      }
    } else if (fontJ.contains("loadedSize")) {
      // Legacy fallback: single size
      sizes.push_back(static_cast<int>(fontJ["loadedSize"].get<float>()));
    } else {
      sizes.push_back(22); // Ultimate fallback
    }

    // Parse defaultSize
    fd.defaultSize = fontJ.value("defaultSize", sizes.empty() ? 22 : sizes[0]);

    // --- Copy other JSON parameters (with defaults) ---
    fd.fontScale = fontJ.value("scale", 1.0f);
    fd.spacing = fontJ.value("spacing", 1.0f);

    if (auto it = fontJ.find("offset");
        it != fontJ.end() && it->is_array() && it->size() == 2) {
      fd.fontRenderOffset = {(*it)[0].get<float>(), (*it)[1].get<float>()};
    }

    // --- Gather ranges (or fallback to ASCII) ---
    std::vector<std::pair<int, int>> ranges;
    if (auto it = fontJ.find("ranges"); it != fontJ.end() && it->is_array()) {
      for (auto &pair : *it) {
        if (pair.is_array() && pair.size() == 2)
          ranges.emplace_back(pair[0].get<int>(), pair[1].get<int>());
      }
    } else {
      ranges.emplace_back(0x0020, 0x007E); // ASCII default
    }

    // --- Flatten into codepoint list ---
    auto &cps = fd.codepoints;
    for (auto [lo, hi] : ranges) {
      for (int cp = lo; cp <= hi; ++cp)
        cps.push_back(cp);
    }

    // --- Load font at each size ---
    std::string file =
        util::getRawAssetPathNoUUID(fontJ["file"].get<std::string>());
    if (!file.empty()) {
      for (int size : sizes) {
        Font font = LoadFontEx(file.c_str(), size, cps.data(),
                               static_cast<int>(cps.size()));

        if (font.texture.id == 0) {
          SPDLOG_ERROR("Failed to LoadFontEx '{}' at {}px for '{}'", file, size,
                       lang);
        } else {
          // Apply bilinear filtering for smoother downscaling
          SetTextureFilter(font.texture, TEXTURE_FILTER_BILINEAR);
          fd.fontsBySize[size] = font;
          SPDLOG_INFO("Loaded font '{}' at {}px ({} glyphs) for '{}'", file,
                      size, cps.size(), lang);
        }
      }
    } else {
      SPDLOG_ERROR("Missing font file path for '{}'", lang);
    }

    languageFontData[lang] = std::move(fd);
  }
}
```

**Step 2: Commit**

```bash
git add src/systems/localization/localization.cpp
git commit -m "feat: load fonts at multiple sizes with bilinear filtering"
```

---

## Task 4: Update Named Font Loading

**Files:**
- Modify: `src/systems/localization/localization.cpp`

**Step 1: Update loadNamedFont() function**

Find `void loadNamedFont(const std::string &name, const std::string &path, float size)` (around line 123).

Update it to store the font in the multi-size map:

```cpp
void loadNamedFont(const std::string &name, const std::string &path,
                   float size) {
  globals::FontData fd;
  int sizeInt = static_cast<int>(size);
  fd.defaultSize = sizeInt;
  fd.fontScale = 1.0f;
  fd.spacing = 1.0f;
  fd.fontRenderOffset = {0, 0};

  // Use the current language's codepoints instead of just ASCII
  const auto &currentFontData = getFontData();
  if (!currentFontData.codepoints.empty()) {
    fd.codepoints = currentFontData.codepoints;
  } else {
    for (int cp = 0x0020; cp <= 0x007E; ++cp) {
      fd.codepoints.push_back(cp);
    }
  }

  std::string filePath = util::getRawAssetPathNoUUID(path);
  if (!filePath.empty()) {
    Font font = LoadFontEx(filePath.c_str(), sizeInt, fd.codepoints.data(),
                           static_cast<int>(fd.codepoints.size()));

    if (font.texture.id == 0) {
      SPDLOG_ERROR("Failed to load named font '{}' from '{}'", name, filePath);
    } else {
      SetTextureFilter(font.texture, TEXTURE_FILTER_BILINEAR);
      fd.fontsBySize[sizeInt] = font;
      SPDLOG_INFO("Loaded named font '{}' from '{}' ({} glyphs, size {})", name,
                  filePath, fd.codepoints.size(), sizeInt);
      namedFonts[name] = std::move(fd);
    }
  } else {
    SPDLOG_ERROR("Named font path is empty for '{}'", name);
  }
}
```

**Step 2: Commit**

```bash
git add src/systems/localization/localization.cpp
git commit -m "feat: update loadNamedFont to use multi-size map"
```

---

## Task 5: Add Lua Bindings for Font Selection

**Files:**
- Modify: `src/systems/localization/localization.cpp`

**Step 1: Find the Lua binding section**

Search for `lua.new_usertype<Font>` or `lua["localization"]` (around line 250-300).

**Step 2: Add new Lua bindings**

Add these bindings in the Lua registration section:

```cpp
// Get best font for requested size from named font
lua["localization"]["getBestFontForSize"] =
    [](const std::string &fontName, float requestedSize) -> Font {
  const auto &fontData = getNamedFont(fontName);
  return fontData.getBestFontForSize(requestedSize);
};

// Get the actual size of the best font (for layout calculations)
lua["localization"]["getBestFontSizeFor"] =
    [](const std::string &fontName, float requestedSize) -> int {
  const auto &fontData = getNamedFont(fontName);
  return fontData.getBestFontForSize(requestedSize).baseSize;
};

// Get best font for current language (not named font)
lua["localization"]["getBestLangFontForSize"] =
    [](float requestedSize) -> Font {
  const auto &fontData = getFontData();
  return fontData.getBestFontForSize(requestedSize);
};
```

**Step 3: Commit**

```bash
git add src/systems/localization/localization.cpp
git commit -m "feat: add Lua bindings for multi-size font selection"
```

---

## Task 6: Update UI Text Rendering (element.cpp)

**Files:**
- Modify: `src/systems/ui/element.cpp`

**Step 1: Find TEXT element rendering**

Search for `layer::TextPro` calls in element.cpp. There are approximately 6 locations.

**Step 2: Update each TextPro call pattern**

For each location where text is rendered, change from:

```cpp
// OLD PATTERN
float fontSize = config->fontSize.value_or(fontData.fontLoadedSize);
layer::TextPro(text, fontData.font, x, y, {0,0}, 0, fontSize, spacing, color);
```

To:

```cpp
// NEW PATTERN
float requestedSize = config->fontSize.value_or(static_cast<float>(fontData.defaultSize));
const Font& bestFont = fontData.getBestFontForSize(requestedSize);
float actualSize = static_cast<float>(bestFont.baseSize);
layer::TextPro(text, bestFont, x, y, {0,0}, 0, actualSize, spacing, color);
```

**Step 3: Specific locations to update**

Around lines 1514-1516 (shadow text):
```cpp
float requestedSize = config->fontSize.has_value()
    ? config->fontSize.value()
    : static_cast<float>(fontData.defaultSize);
const Font& bestFont = fontData.getBestFontForSize(requestedSize);
float actualSize = static_cast<float>(bestFont.baseSize);
layer::TextPro(config->text.value().c_str(), bestFont, textX, textY,
               {0, 0}, 0, actualSize, spacing, shadowColor);
```

Around lines 1577-1579 (main text):
```cpp
float requestedSize = config->fontSize.has_value()
    ? config->fontSize.value()
    : static_cast<float>(fontData.defaultSize);
const Font& bestFont = fontData.getBestFontForSize(requestedSize);
float actualSize = static_cast<float>(bestFont.baseSize);
layer::TextPro(config->text.value().c_str(), bestFont, textX, textY,
               {0, 0}, 0, actualSize, spacing, renderColor);
```

**Step 4: Update MeasureTextEx calls**

Also update text measurement to use the correct font size for layout:

```cpp
float requestedSize = config->fontSize.value_or(static_cast<float>(fontData.defaultSize));
const Font& bestFont = fontData.getBestFontForSize(requestedSize);
float actualSize = static_cast<float>(bestFont.baseSize);
auto [measuredWidth, measuredHeight] = MeasureTextEx(bestFont, text.c_str(), actualSize, fontData.spacing);
```

**Step 5: Commit**

```bash
git add src/systems/ui/element.cpp
git commit -m "feat: use multi-size font selection in UI text rendering"
```

---

## Task 7: Update text_handler.cpp

**Files:**
- Modify: `src/systems/ui/handlers/text_handler.cpp`

**Step 1: Apply same pattern as element.cpp**

Find `layer::TextPro` and `layer::QueueCommand<layer::CmdTextPro>` calls (around lines 103-104, 159-160).

**Step 2: Update to use getBestFontForSize**

Apply the same transformation as Task 6:

```cpp
float requestedSize = config->fontSize.value_or(static_cast<float>(fontData.defaultSize));
const Font& bestFont = fontData.getBestFontForSize(requestedSize);
float actualSize = static_cast<float>(bestFont.baseSize);
```

Then use `bestFont` and `actualSize` in the TextPro calls.

**Step 3: Commit**

```bash
git add src/systems/ui/handlers/text_handler.cpp
git commit -m "feat: use multi-size font selection in text_handler"
```

---

## Task 8: Remove Tooltip Font Size Mismatch in Lua

**Files:**
- Modify: `assets/scripts/core/gameplay.lua`

**Step 1: Find loadTooltipFont function**

Around line 299, find the `loadTooltipFont()` function.

**Step 2: Update to load at render size**

Change the tooltip sizes to match what will be rendered:

```lua
local function loadTooltipFont()
    if not (localization and localization.loadNamedFont) then
        return
    end

    local lang = localization.getCurrentLanguage and localization.getCurrentLanguage() or "en_us"
    local tooltipFont, tooltipSize
    if lang == "ko_kr" then
        tooltipFont = "fonts/ko/Galmuri11-Bold.ttf"
        tooltipSize = 22  -- Changed from 32 to match tooltipStyle.fontSize
    else
        tooltipFont = "fonts/en/ProggyCleanCENerdFontMono-Regular.ttf"
        tooltipSize = 22  -- Changed from 44 to match tooltipStyle.fontSize
    end
    localization.loadNamedFont("tooltip", tooltipFont, tooltipSize)
    TOOLTIP_FONT_VERSION = TOOLTIP_FONT_VERSION + 1
end
```

**Step 3: Commit**

```bash
git add assets/scripts/core/gameplay.lua
git commit -m "fix: load tooltip font at render size to prevent scaling"
```

---

## Task 9: Build and Test

**Step 1: Build the project**

```bash
just build-debug
```

**Step 2: Run the game and verify**

1. Launch the game
2. Switch language to Korean
3. Hover over items to see tooltips
4. Verify text is crisp, not pixelated

**Step 3: Test English as well**

1. Switch language to English
2. Verify tooltips still render correctly

**Step 4: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: address any issues found during testing"
```

---

## Task 10: Merge or PR

**Option A: Direct merge (if tests pass)**

```bash
git checkout master
git merge feature/multi-size-font-cache
git push
```

**Option B: Create PR**

```bash
git push -u origin feature/multi-size-font-cache
gh pr create --title "feat: multi-size font cache for crisp text rendering" --body "..."
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Update fonts.json config | `assets/localization/fonts.json` |
| 2 | Update FontData struct | `src/core/globals.hpp` |
| 3 | Update font loading | `src/systems/localization/localization.cpp` |
| 4 | Update named font loading | `src/systems/localization/localization.cpp` |
| 5 | Add Lua bindings | `src/systems/localization/localization.cpp` |
| 6 | Update element.cpp | `src/systems/ui/element.cpp` |
| 7 | Update text_handler.cpp | `src/systems/ui/handlers/text_handler.cpp` |
| 8 | Fix tooltip font size | `assets/scripts/core/gameplay.lua` |
| 9 | Build and test | - |
| 10 | Merge or PR | - |
