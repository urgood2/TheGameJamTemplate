# Pristine Stats Tooltips Design

**Date:** 2025-12-18
**Status:** Approved
**Goal:** Clean appearance, visually pleasing, readable, no visual glitches

## Problem Statement

The player stat and details panel tooltips have several issues:
1. Weird characters (white blocks) appearing in section headings
2. Text too small and mashed together, reducing legibility
3. Inconsistent font usage between headers and content

## Root Cause Analysis

1. **White blocks in headers**: `StatTooltipSystem.makeSectionHeader()` uses `dsl.text()` without specifying `fontName`, causing fallback to a different font
2. **Small text**: Header font size is 10-14px vs 22px for content
3. **Cramped layout**: Row padding is 1-2px, header padding is 2-3px

## Design Decisions

### Typography & Spacing

| Element | Current | New |
|---------|---------|-----|
| Section Headers | 10-14px | 18px |
| Stat Labels | 22px | 20px |
| Stat Values | 22px | 20px |
| Row Padding | 1-2px | 5px |
| Header Padding | 2-3px | 8px |
| Section Gap (above) | 0px | 12px |
| Column Padding | 2-4px | 8px |
| Inner Padding | 4-10px | 12px |

### Font Consistency

- All text elements explicitly use `fontName = "tooltip"` (ProggyCleanCE Nerd Font)
- Headers, labels, and values all use the same font family

### Layout Changes

| Tooltip | Current Columns | New Columns |
|---------|-----------------|-------------|
| Basic Stats | 3 | 2 |
| Detailed Stats | 5 | 3 |

### Overflow Handling

Progressive fallback cascade when tooltip exceeds screen bounds:

| Level | Headers | Content | Padding | Columns (Detailed) |
|-------|---------|---------|---------|-------------------|
| 0 (Default) | 18px | 20px | 5px | 3 |
| 1 (Tight) | 16px | 18px | 4px | 3 |
| 2 (Compact) | 14px | 16px | 3px | 2 |
| 3 (Minimum) | 12px | 14px | 2px | 2 |

Detection occurs after tooltip positioning. If overflow detected, rebuild with next fallback level.

## Implementation Tasks

### Task 1: Fix font consistency in headers
- File: `assets/scripts/core/gameplay.lua`
- Function: `StatTooltipSystem.makeSectionHeader()`
- Change: Add `fontName = tooltipStyle.fontName` to `dsl.text()` call

### Task 2: Update tooltipStyle constants
- File: `assets/scripts/core/gameplay.lua`
- Add new constants to `tooltipStyle` table:
  - `headerFontSize = 18`
  - `contentFontSize = 20`
  - `sectionGap = 12`
- Update existing: `rowPadding = 5`, `headerPadding = 8`

### Task 3: Update makePlayerStatsTooltip()
- File: `assets/scripts/core/gameplay.lua`
- Change column count from 3 to 2
- Apply new padding/sizing values from tooltipStyle

### Task 4: Update makeDetailedStatsTooltip()
- File: `assets/scripts/core/gameplay.lua`
- Change column count from 5 to 3
- Apply consistent styling with basic stats

### Task 5: Add section gap spacing
- File: `assets/scripts/core/gameplay.lua`
- Modify `StatTooltipSystem.makeSectionHeader()` to include top margin
- Or add spacer element before headers in `buildRows()`

### Task 6: Implement overflow detection & fallback
- File: `assets/scripts/core/gameplay.lua`
- Create sizing level constants table
- Create `getAdaptiveSizing(screenW, screenH, tooltipW, tooltipH)` helper
- Modify `ensurePlayerStatsTooltip()` and `ensureDetailedStatsTooltip()` to:
  1. Build tooltip at default size
  2. Measure bounds
  3. Rebuild at smaller level if overflow detected

### Task 7: Test & verify
- Test both tooltips at various window sizes
- Verify no white blocks or visual glitches
- Confirm overflow fallback works correctly

## Files Modified

- `assets/scripts/core/gameplay.lua` (primary changes)

## Success Criteria

- [ ] No white block characters in any tooltip text
- [ ] All text uses consistent ProggyCleanCE font
- [ ] Section headers clearly visible at 18px
- [ ] Comfortable row spacing (5px padding)
- [ ] Basic stats: 2-column layout
- [ ] Detailed stats: 3-column layout
- [ ] Tooltips never overflow screen bounds
- [ ] Graceful size reduction when space is limited
