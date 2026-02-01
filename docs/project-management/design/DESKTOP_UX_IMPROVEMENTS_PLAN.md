# Desktop Build UX Improvements - Implementation Plan

> Generated: 2026-01-21
> Status: Planning (Not Implemented)

## Executive Summary

This plan outlines **desktop-specific UX improvements** for the C++20/Raylib/Lua game engine, focusing on a **threaded loading screen** (desktop-only) and numerous quality-of-life features that enhance the desktop gaming experience.

---

## Current State Analysis

### Existing Infrastructure
| Feature | Status | Location |
|---------|--------|----------|
| Web Loading Screen | ✅ Excellent (Balatro-style) | `src/minshell.html` |
| Desktop Loading Screen | ⚠️ Basic (text only) | `src/main.cpp:171-176`, `src/core/init.cpp:69-104` |
| Splash Image Support | ✅ Present | `src/core/init.cpp:45-67` |
| GameState System | ✅ Present | `src/core/globals.hpp:86` (`LOADING_SCREEN` state exists) |
| Progress Bar UI | ✅ Component exists | `src/systems/ui/ui_data.hpp` |
| Lazy Shader Loading | ✅ Available | `src/systems/shaders/shader_system.cpp:411+` |
| Crash Reporting | ✅ Excellent | `src/util/crash_reporter.cpp` |
| Telemetry Events | ✅ Loading stages tracked | `src/core/init.cpp:1123+` |
| Save System (Async) | ✅ Threaded on desktop | `src/systems/save/save_file_io.cpp:141` |
| UI System | ✅ Excellent | `UIElementTemplateNodeBuilder`, `UIConfigBuilder` |

---

## Proposed Features (Priority Order)

### TIER 1: High Impact, Medium Effort

#### 1. Threaded Loading Screen with Animated Progress (DESKTOP ONLY)

**Why**: Desktop currently shows static "Loading..." text while web has beautiful animated loading.

**CRITICAL: Platform Guard**
```cpp
// This feature is DESKTOP ONLY - Web uses minshell.html loading screen
#if !defined(PLATFORM_WEB) && !defined(__EMSCRIPTEN__)
// Threaded loading implementation here
#endif
```

**Implementation**:
```cpp
// New file: src/systems/loading/loading_screen.hpp
#pragma once

// DESKTOP ONLY - Web builds use minshell.html for loading
#if !defined(PLATFORM_WEB) && !defined(__EMSCRIPTEN__)

#include <atomic>
#include <thread>
#include <mutex>
#include <string>
#include <vector>
#include <functional>

namespace loading {

class LoadingScreen {
public:
    // Lifecycle
    void initialize();
    void shutdown();
    
    // Threading
    void startBackgroundLoading(std::function<void()> loadingWork);
    bool isLoadingComplete() const { return m_loadingComplete.load(); }
    
    // Progress tracking (thread-safe)
    void setProgress(float progress);  // 0.0 - 1.0
    float getProgress() const { return m_progress.load(); }
    
    void setStage(const std::string& stageName);
    std::string getStage() const;
    
    // Rendering (main thread only)
    void render(float dt);
    
    // Loading tips
    void setLoadingTips(const std::vector<std::string>& tips);
    
private:
    // Thread-safe state
    std::atomic<float> m_progress{0.0f};
    std::atomic<bool> m_loadingComplete{false};
    std::atomic<bool> m_shouldCancel{false};
    
    // Protected by mutex
    mutable std::mutex m_stageMutex;
    std::string m_currentStage;
    
    // Worker thread
    std::thread m_loadThread;
    
    // Visual state (main thread only)
    float m_displayProgress{0.0f};  // Smoothed for display
    float m_tipTimer{0.0f};
    int m_currentTipIndex{0};
    std::vector<std::string> m_loadingTips;
    
    // Animation
    float m_animationTime{0.0f};
    float m_pulsePhase{0.0f};
};

// Global accessor
LoadingScreen& getLoadingScreen();

} // namespace loading

#endif // !PLATFORM_WEB && !__EMSCRIPTEN__
```

**Visual Features**:
- Animated progress bar with shader effects (port `loading` class from minshell.html)
- Rotating loading tips from `assets/localization/en_us.json`
- Splash image with parallax/subtle animation
- Percentage counter with easing
- Background shader animation (reuse existing `balatro_background` or `peaches_background`)

**Integration with existing init.cpp**:
```cpp
// In src/core/init.cpp - modify initializeGame()

void initializeGame(bool& loadingDone) {
#if !defined(PLATFORM_WEB) && !defined(__EMSCRIPTEN__)
    // Desktop: Use threaded loading with animated UI
    auto& loadingScreen = loading::getLoadingScreen();
    loadingScreen.initialize();
    
    loadingScreen.startBackgroundLoading([&loadingDone, &loadingScreen]() {
        // JSON loading (20%)
        loadingScreen.setStage("Loading configuration...");
        loadJSONData();
        loadingScreen.setProgress(0.2f);
        
        // Texture loading (50%)
        loadingScreen.setStage("Loading textures...");
        loadTextures();
        loadingScreen.setProgress(0.5f);
        
        // Shader loading (70%)
        loadingScreen.setStage("Compiling shaders...");
        loadShaders();
        loadingScreen.setProgress(0.7f);
        
        // Audio loading (85%)
        loadingScreen.setStage("Loading audio...");
        loadAudio();
        loadingScreen.setProgress(0.85f);
        
        // Lua initialization (100%)
        loadingScreen.setStage("Initializing scripts...");
        initializeLua();
        loadingScreen.setProgress(1.0f);
        
        loadingDone = true;
    });
    
    // Main thread: Render loading screen while worker loads
    while (!loadingScreen.isLoadingComplete()) {
        float dt = GetFrameTime();
        loadingScreen.render(dt);
    }
    
    loadingScreen.shutdown();
#else
    // Web: Use synchronous loading (minshell.html handles the UI)
    loadJSONData();
    loadTextures();
    loadShaders();
    loadAudio();
    initializeLua();
    loadingDone = true;
#endif
}
```

**Estimated Effort**: 2-3 days

---

#### 2. Settings Menu UI (Using Existing UI System)

**Why**: Players need a proper in-game settings menu with all options.

**Implementation using existing `UIElementTemplateNodeBuilder` / `UIConfigBuilder`**:

```lua
-- New file: assets/scripts/ui/settings_menu.lua
local SettingsMenu = {}

-- Current settings state (synced with C++ settings_manager)
local currentSettings = {
    -- Graphics
    windowMode = "borderless",  -- "windowed", "borderless", "fullscreen"
    resolution = {1920, 1080},
    vsync = true,
    targetFPS = 60,
    
    -- Audio
    masterVolume = 1.0,
    musicVolume = 0.7,
    sfxVolume = 1.0,
    
    -- Accessibility
    uiScale = 1.0,
    screenShake = true,
    flashingEffects = true,
    textSpeed = 1.0,
}

-- Available resolutions (populated from C++)
local availableResolutions = {
    {1280, 720, "720p"},
    {1920, 1080, "1080p"},
    {2560, 1440, "1440p"},
    {3840, 2160, "4K"},
}

-- Create a slider row for settings
local function createSliderRow(label, valueGetter, valueSetter, minVal, maxVal, step)
    local labelText = ui.definitions.getNewDynamicTextEntry(
        function() return label end,
        20.0,
        "color=white"
    )
    
    local valueText = ui.definitions.getNewDynamicTextEntry(
        function() return string.format("%.0f%%", valueGetter() * 100) end,
        18.0,
        "color=apricot_cream"
    )
    
    local sliderDef = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addMinWidth(200)
                :addMinHeight(20)
                :addColor(util.getColor("slate_gray"))
                :addProgressBar(true)
                :addProgressBarEmptyColor(util.getColor("charcoal"))
                :addProgressBarFullColor(util.getColor("sky_blue"))
                :addProgressBarFetchValueLamnda(function(e)
                    return valueGetter()
                end)
                :addCanCollide(true)
                :addButtonCallback(function(entity)
                    -- Handle slider drag
                    local transform = component_cache.get(entity, Transform)
                    local mouseX = GetMouseX()
                    local relativeX = (mouseX - transform.actualX) / transform.actualW
                    local newValue = math.max(minVal, math.min(maxVal, relativeX))
                    newValue = math.floor(newValue / step + 0.5) * step
                    valueSetter(newValue)
                end)
                :build()
        )
        :build()
    
    local row = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                :addPadding(8)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChild(labelText)
        :addChild(sliderDef)
        :addChild(valueText)
        :build()
    
    return row
end

-- Create a toggle row for boolean settings
local function createToggleRow(label, valueGetter, valueSetter)
    local labelText = ui.definitions.getNewDynamicTextEntry(
        function() return label end,
        20.0,
        "color=white"
    )
    
    local toggleText = ui.definitions.getNewDynamicTextEntry(
        function() return valueGetter() and "ON" or "OFF" end,
        18.0,
        function() return valueGetter() and "color=green" or "color=red" end
    )
    
    local toggleButton = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addMinWidth(80)
                :addMinHeight(32)
                :addColor(function() 
                    return valueGetter() and util.getColor("forest_green") or util.getColor("crimson")
                end)
                :addCanCollide(true)
                :addButtonUIE(true)
                :addButtonCallback(function(entity)
                    valueSetter(not valueGetter())
                    playSound("ui_click")
                end)
                :addEmboss(3.0)
                :build()
        )
        :addChild(toggleText)
        :build()
    
    local row = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                :addPadding(8)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChild(labelText)
        :addChild(toggleButton)
        :build()
    
    return row
end

-- Create dropdown for window mode / resolution
local function createDropdownRow(label, options, currentValueGetter, valueSetter)
    local labelText = ui.definitions.getNewDynamicTextEntry(
        function() return label end,
        20.0,
        "color=white"
    )
    
    local currentText = ui.definitions.getNewDynamicTextEntry(
        function() return currentValueGetter() end,
        18.0,
        "color=gold"
    )
    
    local leftArrow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addMinWidth(32)
                :addMinHeight(32)
                :addColor(util.getColor("slate_gray"))
                :addCanCollide(true)
                :addButtonUIE(true)
                :addButtonCallback(function(entity)
                    -- Cycle backwards
                    local currentIdx = 1
                    for i, opt in ipairs(options) do
                        if opt.value == currentValueGetter() then
                            currentIdx = i
                            break
                        end
                    end
                    local newIdx = currentIdx - 1
                    if newIdx < 1 then newIdx = #options end
                    valueSetter(options[newIdx].value)
                    playSound("ui_click")
                end)
                :build()
        )
        :addChild(ui.definitions.getNewDynamicTextEntry(function() return "<" end, 24.0, "color=white"))
        :build()
    
    local rightArrow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addMinWidth(32)
                :addMinHeight(32)
                :addColor(util.getColor("slate_gray"))
                :addCanCollide(true)
                :addButtonUIE(true)
                :addButtonCallback(function(entity)
                    -- Cycle forwards
                    local currentIdx = 1
                    for i, opt in ipairs(options) do
                        if opt.value == currentValueGetter() then
                            currentIdx = i
                            break
                        end
                    end
                    local newIdx = currentIdx + 1
                    if newIdx > #options then newIdx = 1 end
                    valueSetter(options[newIdx].value)
                    playSound("ui_click")
                end)
                :build()
        )
        :addChild(ui.definitions.getNewDynamicTextEntry(function() return ">" end, 24.0, "color=white"))
        :build()
    
    local valueContainer = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addMinWidth(180)
                :addColor(util.getColor("charcoal"))
                :addPadding(6)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChild(leftArrow)
        :addChild(currentText)
        :addChild(rightArrow)
        :build()
    
    local row = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                :addPadding(8)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChild(labelText)
        :addChild(valueContainer)
        :build()
    
    return row
end

-- Build the complete settings menu
function SettingsMenu.create()
    -- Section: Graphics
    local graphicsTitle = ui.definitions.getNewDynamicTextEntry(
        function() return "GRAPHICS" end,
        24.0,
        "color=gold;float"
    )
    
    local windowModeRow = createDropdownRow(
        "Window Mode",
        {
            {value = "windowed", label = "Windowed"},
            {value = "borderless", label = "Borderless"},
            {value = "fullscreen", label = "Fullscreen"},
        },
        function() return currentSettings.windowMode end,
        function(v) 
            currentSettings.windowMode = v
            settings_manager.setWindowMode(v)  -- C++ binding
        end
    )
    
    local vsyncRow = createToggleRow(
        "V-Sync",
        function() return currentSettings.vsync end,
        function(v)
            currentSettings.vsync = v
            settings_manager.setVSync(v)
        end
    )
    
    local fpsRow = createDropdownRow(
        "Target FPS",
        {
            {value = 30, label = "30"},
            {value = 60, label = "60"},
            {value = 120, label = "120"},
            {value = 144, label = "144"},
            {value = 0, label = "Unlimited"},
        },
        function() 
            if currentSettings.targetFPS == 0 then return "Unlimited" end
            return tostring(currentSettings.targetFPS)
        end,
        function(v)
            currentSettings.targetFPS = v
            settings_manager.setTargetFPS(v)
        end
    )
    
    local graphicsSection = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.VERTICAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("dark_slate"))
                :addPadding(12)
                :addEmboss(4.0)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP))
                :build()
        )
        :addChild(graphicsTitle)
        :addChild(windowModeRow)
        :addChild(vsyncRow)
        :addChild(fpsRow)
        :build()
    
    -- Section: Audio
    local audioTitle = ui.definitions.getNewDynamicTextEntry(
        function() return "AUDIO" end,
        24.0,
        "color=gold;float"
    )
    
    local masterVolumeRow = createSliderRow(
        "Master Volume",
        function() return currentSettings.masterVolume end,
        function(v)
            currentSettings.masterVolume = v
            settings_manager.setMasterVolume(v)
        end,
        0.0, 1.0, 0.05
    )
    
    local musicVolumeRow = createSliderRow(
        "Music Volume",
        function() return currentSettings.musicVolume end,
        function(v)
            currentSettings.musicVolume = v
            settings_manager.setMusicVolume(v)
        end,
        0.0, 1.0, 0.05
    )
    
    local sfxVolumeRow = createSliderRow(
        "SFX Volume",
        function() return currentSettings.sfxVolume end,
        function(v)
            currentSettings.sfxVolume = v
            settings_manager.setSFXVolume(v)
        end,
        0.0, 1.0, 0.05
    )
    
    local audioSection = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.VERTICAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("dark_slate"))
                :addPadding(12)
                :addEmboss(4.0)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP))
                :build()
        )
        :addChild(audioTitle)
        :addChild(masterVolumeRow)
        :addChild(musicVolumeRow)
        :addChild(sfxVolumeRow)
        :build()
    
    -- Section: Accessibility
    local accessibilityTitle = ui.definitions.getNewDynamicTextEntry(
        function() return "ACCESSIBILITY" end,
        24.0,
        "color=gold;float"
    )
    
    local screenShakeRow = createToggleRow(
        "Screen Shake",
        function() return currentSettings.screenShake end,
        function(v)
            currentSettings.screenShake = v
            settings_manager.setScreenShake(v)
        end
    )
    
    local flashingRow = createToggleRow(
        "Flashing Effects",
        function() return currentSettings.flashingEffects end,
        function(v)
            currentSettings.flashingEffects = v
            settings_manager.setFlashingEffects(v)
        end
    )
    
    local uiScaleRow = createSliderRow(
        "UI Scale",
        function() return (currentSettings.uiScale - 0.75) / 1.25 end,  -- Normalize 0.75-2.0 to 0-1
        function(v)
            currentSettings.uiScale = 0.75 + v * 1.25  -- Convert back
            settings_manager.setUIScale(currentSettings.uiScale)
        end,
        0.0, 1.0, 0.1
    )
    
    local accessibilitySection = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.VERTICAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("dark_slate"))
                :addPadding(12)
                :addEmboss(4.0)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP))
                :build()
        )
        :addChild(accessibilityTitle)
        :addChild(screenShakeRow)
        :addChild(flashingRow)
        :addChild(uiScaleRow)
        :build()
    
    -- Action buttons
    local saveButton = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addMinWidth(120)
                :addMinHeight(40)
                :addColor(util.getColor("forest_green"))
                :addCanCollide(true)
                :addButtonUIE(true)
                :addButtonCallback(function(entity)
                    settings_manager.saveSettings()
                    playSound("ui_confirm")
                    SettingsMenu.hide()
                end)
                :addEmboss(4.0)
                :build()
        )
        :addChild(ui.definitions.getNewDynamicTextEntry(function() return "SAVE" end, 20.0, "color=white"))
        :build()
    
    local cancelButton = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addMinWidth(120)
                :addMinHeight(40)
                :addColor(util.getColor("crimson"))
                :addCanCollide(true)
                :addButtonUIE(true)
                :addButtonCallback(function(entity)
                    settings_manager.revertSettings()
                    playSound("ui_cancel")
                    SettingsMenu.hide()
                end)
                :addEmboss(4.0)
                :build()
        )
        :addChild(ui.definitions.getNewDynamicTextEntry(function() return "CANCEL" end, 20.0, "color=white"))
        :build()
    
    local resetButton = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.ROOT)
        :addConfig(
            UIConfigBuilder.create()
                :addMinWidth(150)
                :addMinHeight(40)
                :addColor(util.getColor("slate_gray"))
                :addCanCollide(true)
                :addButtonUIE(true)
                :addButtonCallback(function(entity)
                    settings_manager.resetToDefaults()
                    SettingsMenu.refreshFromSettings()
                    playSound("ui_click")
                end)
                :addEmboss(4.0)
                :build()
        )
        :addChild(ui.definitions.getNewDynamicTextEntry(function() return "RESET DEFAULTS" end, 18.0, "color=white"))
        :build()
    
    local buttonRow = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.HORIZONTAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("blank"))
                :addPadding(16)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER))
                :build()
        )
        :addChild(saveButton)
        :addChild(cancelButton)
        :addChild(resetButton)
        :build()
    
    -- Main container
    local settingsTitle = ui.definitions.getNewDynamicTextEntry(
        function() return "SETTINGS" end,
        32.0,
        "color=white;float"
    )
    
    local settingsRoot = UIElementTemplateNodeBuilder.create()
        :addType(UITypeEnum.VERTICAL_CONTAINER)
        :addConfig(
            UIConfigBuilder.create()
                :addColor(util.getColor("midnight_blue"))
                :addPadding(20)
                :addEmboss(6.0)
                :addMinWidth(500)
                :addAlign(bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_TOP))
                :build()
        )
        :addChild(settingsTitle)
        :addChild(graphicsSection)
        :addChild(audioSection)
        :addChild(accessibilitySection)
        :addChild(buttonRow)
        :build()
    
    -- Create and position the UI box
    SettingsMenu.uiBox = ui.box.Initialize(
        {x = globals.screenWidth() / 2 - 250, y = 50},
        settingsRoot
    )
    
    -- Initially hidden
    SettingsMenu.hide()
    
    return SettingsMenu.uiBox
end

function SettingsMenu.show()
    if SettingsMenu.uiBox then
        local transform = component_cache.get(SettingsMenu.uiBox, Transform)
        transform.actualX = globals.screenWidth() / 2 - transform.actualW / 2
        transform.actualY = globals.screenHeight() / 2 - transform.actualH / 2
        transform.visualX = transform.actualX
        transform.visualY = transform.actualY
        -- Set visible (implementation depends on your visibility system)
        SettingsMenu.visible = true
    end
end

function SettingsMenu.hide()
    if SettingsMenu.uiBox then
        local transform = component_cache.get(SettingsMenu.uiBox, Transform)
        transform.actualY = globals.screenHeight() + 1000  -- Move off screen
        transform.visualY = transform.actualY
        SettingsMenu.visible = false
    end
end

function SettingsMenu.toggle()
    if SettingsMenu.visible then
        SettingsMenu.hide()
    else
        SettingsMenu.show()
    end
end

function SettingsMenu.refreshFromSettings()
    -- Reload currentSettings from C++ settings_manager
    currentSettings = settings_manager.getAllSettings()
end

return SettingsMenu
```

**Estimated Effort**: 2-3 days

---

#### 3. Screenshot System (F12 / PrintScreen)
**Why**: Players want to capture moments; streamers need this constantly.

**Implementation**:
```cpp
// New: src/systems/screenshot/screenshot_system.hpp
namespace screenshot {
    void captureScreenshot();           // Full screen
    void captureWithUI(bool includeUI); // Toggle UI visibility
    void captureRegion(Rectangle area); // Partial capture
    void openScreenshotFolder();        // Shell open
    
    struct Config {
        std::string format = "png";     // png, jpg, bmp
        std::string folder = "screenshots";
        bool includeTimestamp = true;
        bool flashEffect = true;
        bool playCameraSound = true;
        bool copyToClipboard = false;   // Windows only initially
    };
}
```

**UX Features**:
- Camera shutter sound effect
- Brief white flash overlay
- Toast notification: "Screenshot saved!"
- Auto-naming: `{GameName}_{YYYY-MM-DD_HH-MM-SS}.png`

**Estimated Effort**: 1 day

---

#### 4. Performance Overlay (Toggle with F3)
**Why**: Players/developers need real-time performance metrics.

**Implementation**:
```cpp
// Extend existing: src/util/perf_overlay.hpp
namespace perf_overlay {
    enum class DisplayLevel {
        OFF,
        MINIMAL,    // FPS only (corner)
        STANDARD,   // FPS, frame time, memory
        DETAILED,   // + draw calls, entities, Lua memory
        DEVELOPER   // + Tracy zones, shader stats
    };
    
    void cycleDisplayLevel();  // F3 to cycle
    void render(float dt);
}
```

**Display Info**:
| Level | Metrics |
|-------|---------|
| Minimal | FPS |
| Standard | FPS, Frame Time (ms), RAM |
| Detailed | + Draw Calls, Entity Count, Lua Memory, GC Pause |
| Developer | + Active Shaders, Texture Memory, Tracy Data |

**Estimated Effort**: 1 day

---

### TIER 2: Quality of Life

#### 5. Window Management System
**Why**: Modern games need flexible window modes.

**Features**:
- **Window Modes**: Windowed, Borderless Fullscreen, Exclusive Fullscreen
- **Multi-Monitor Support**: Remember last monitor, move window between monitors
- **Resolution Presets**: Common resolutions + "Native" option
- **Aspect Ratio Lock**: For ultrawide monitors

**Implementation**:
```cpp
// New: src/systems/window/window_manager.hpp
namespace window_manager {
    enum class WindowMode { WINDOWED, BORDERLESS, FULLSCREEN };
    
    void setWindowMode(WindowMode mode);
    void setResolution(int w, int h);
    void moveToMonitor(int monitorIndex);
    std::vector<Resolution> getAvailableResolutions();
    void toggleFullscreen();  // Alt+Enter
}
```

**Estimated Effort**: 1-2 days

---

#### 6. Settings Persistence & Profiles
**Why**: Settings must persist across sessions.

**Current State**: `assets/config.json` exists but limited.

**Enhanced Implementation**:
```cpp
// New: src/systems/settings/settings_manager.hpp
struct GameSettings {
    // Graphics
    WindowMode windowMode = WindowMode::BORDERLESS;
    int resolutionW = 1920, resolutionH = 1080;
    bool vsync = true;
    int targetFPS = 60;  // 0 = uncapped
    
    // Audio
    float masterVolume = 1.0f;
    float musicVolume = 0.7f;
    float sfxVolume = 1.0f;
    
    // Accessibility
    float uiScale = 1.0f;
    bool screenShake = true;
    bool flashingEffects = true;
    float textSpeed = 1.0f;
    
    // Keybindings (map of action -> key)
    std::unordered_map<std::string, int> keybindings;
};

void saveSettings(const std::string& profileName = "default");
void loadSettings(const std::string& profileName = "default");
```

**File Location**: `{UserAppData}/GameName/settings.json` (platform-appropriate)

**Estimated Effort**: 1-2 days

---

#### 7. First-Time User Experience (FTUE)
**Why**: Guide new players through first launch.

**Features**:
1. **Initial Setup Wizard**:
   - Language selection
   - Display mode auto-detection
   - Controller detection
   - Audio test
   
2. **Tutorial Prompts**:
   - Contextual hints on first encounter
   - "Press F1 for help" reminder
   
3. **Benchmarking** (Optional):
   - Quick auto-benchmark on first run
   - Suggest graphics settings

**Implementation**:
```cpp
// New: src/systems/ftue/ftue_manager.hpp
namespace ftue {
    bool isFirstRun();
    void markSetupComplete();
    void showSetupWizard();
    void showContextualHint(const std::string& hintId);
}
```

**Estimated Effort**: 2-3 days

---

#### 8. Auto-Save & Crash Recovery
**Why**: Players shouldn't lose progress.

**Current State**: Async save exists in `save_file_io.cpp`.

**Enhancements**:
```cpp
// Extend: src/systems/save/auto_save.hpp
namespace auto_save {
    void setInterval(float seconds);  // Default: 60s
    void enableOnSceneTransition(bool enable);
    void createRecoveryPoint();       // Before risky operations
    
    bool hasRecoveryData();
    void offerRecovery();             // "Recover from crash?" dialog
    void clearRecoveryData();
}
```

**Recovery Flow**:
1. On crash: Save state to `recovery.sav`
2. On next launch: Detect recovery file → Prompt user → Restore or discard

**Estimated Effort**: 1-2 days

---

### TIER 3: Polish Features

#### 9. Input Rebinding System
**Why**: Accessibility and preference.

**Features**:
- Full keyboard rebinding
- Controller rebinding (with SDL GameController DB already present)
- Multiple input support per action (keyboard + controller)
- Reset to defaults
- Conflict detection

**Implementation**:
```cpp
// New: src/systems/input/input_rebinding.hpp
namespace input_rebinding {
    void startListeningForKey(const std::string& actionName);
    void bindKey(const std::string& action, int keyCode);
    void bindControllerButton(const std::string& action, int button);
    bool hasConflict(const std::string& action, int keyCode);
    void resetToDefaults();
}
```

**Estimated Effort**: 2 days

---

#### 10. Update/Patch Notification System
**Why**: Keep players informed about updates.

**Implementation**:
```cpp
// New: src/systems/update/update_checker.hpp
namespace update_checker {
    struct VersionInfo {
        std::string currentVersion;
        std::string latestVersion;
        std::string changelog;
        std::string downloadUrl;
    };
    
    void checkForUpdatesAsync();  // Non-blocking HTTP request
    void showUpdateAvailableUI(const VersionInfo& info);
}
```

**Source**: Check itch.io API or custom endpoint.

**Estimated Effort**: 1 day

---

#### 11. Accessibility Features
**Why**: Inclusive design.

**Features**:
| Feature | Description |
|---------|-------------|
| UI Scaling | 75% - 200% |
| High Contrast Mode | Enhanced visibility |
| Reduce Motion | Disable screen shake, minimize animations |
| Colorblind Modes | Deuteranopia, Protanopia, Tritanopia filters |
| Text Size | Independent of UI scale |
| Audio Cues | Visual → Audio alternatives |
| One-Handed Mode | Simplified controls |

**Shader-based colorblind filter**:
```glsl
// assets/shaders/colorblind_filter.fs
uniform int colorblindMode; // 0=none, 1=deuteranopia, 2=protanopia, 3=tritanopia
// Apply daltonization matrix to final output
```

**Estimated Effort**: 2-3 days

---

#### 12. Steam-Like Overlay (Shift+Tab)
**Why**: Quick access to common features without leaving game.

**Features**:
- FPS counter
- Screenshot capture
- Quick settings (volume, fullscreen toggle)
- Achievements progress (if implemented)
- Friends list (if multiplayer)

**Implementation**: ImGui overlay with dedicated render pass.

**Estimated Effort**: 2-3 days

---

## Implementation Roadmap

### Phase 1: Core Desktop UX (Week 1-2)
1. [ ] Threaded Loading Screen (Desktop Only)
2. [ ] Settings Menu UI
3. [ ] Screenshot System
4. [ ] Performance Overlay
5. [ ] Settings Persistence (C++ backend)

### Phase 2: Polish (Week 3-4)
6. [ ] Window Management
7. [ ] Input Rebinding
8. [ ] Auto-Save Enhancement
9. [ ] FTUE Wizard

### Phase 3: Advanced (Week 5+)
10. [ ] Accessibility Features
11. [ ] Update Checker
12. [ ] Overlay System

---

## Technical Considerations

### Platform Guards (CRITICAL)

**Threaded loading is DESKTOP ONLY:**
```cpp
#if !defined(PLATFORM_WEB) && !defined(__EMSCRIPTEN__)
    // Desktop-specific code here
#else
    // Web fallback (or use minshell.html)
#endif
```

### Threading Safety
- Use `std::atomic` for progress values
- `std::mutex` for string/complex state
- Never access Raylib/OpenGL from worker thread
- Queue render commands to main thread

### Platform Differences
| Feature | Windows | macOS | Linux |
|---------|---------|-------|-------|
| Clipboard | ✅ `SetClipboardText` | ✅ | ✅ |
| Shell Open | `ShellExecute` | `open` | `xdg-open` |
| AppData | `%APPDATA%` | `~/Library/Application Support` | `~/.local/share` |

### Config File Location
```cpp
std::string getConfigPath() {
#ifdef _WIN32
    return std::string(getenv("APPDATA")) + "/GameName/";
#elif __APPLE__
    return std::string(getenv("HOME")) + "/Library/Application Support/GameName/";
#else
    return std::string(getenv("HOME")) + "/.local/share/GameName/";
#endif
}
```

---

## Suggested File Structure

```
src/systems/
├── loading/
│   ├── loading_screen.hpp      # Desktop-only threaded loading
│   ├── loading_screen.cpp
│   └── loading_tips.hpp
├── screenshot/
│   ├── screenshot_system.hpp
│   └── screenshot_system.cpp
├── window/
│   ├── window_manager.hpp
│   └── window_manager.cpp
├── settings/
│   ├── settings_manager.hpp    # C++ backend
│   └── settings_manager.cpp
├── ftue/
│   ├── ftue_manager.hpp
│   └── ftue_manager.cpp
├── overlay/
│   ├── game_overlay.hpp
│   └── game_overlay.cpp
└── accessibility/
    ├── accessibility_manager.hpp
    └── colorblind_shader.hpp

assets/scripts/ui/
└── settings_menu.lua           # Lua UI implementation
```

---

## Quick Wins (Can Implement Today)

1. **Add F12 screenshot** - Just `TakeScreenshot()` + notification
2. **Toggle FPS counter** - Already have perf_overlay infrastructure
3. **Port loading animation** - CSS from minshell.html → Shader uniform animations (desktop only)
4. **Loading tips** - Read from localization JSON, rotate every 3 seconds

---

## Summary

This plan provides **11 desktop UX improvements** ranging from essential (threaded loading, settings menu, screenshots) to advanced (overlay system). The architecture leverages existing systems (UI DSL, settings, telemetry, shaders) while adding new capabilities.

**Key changes from initial plan:**
- Removed: Replay Buffer feature (too complex for current scope)
- Added: Explicit DESKTOP ONLY guards for threaded loading (web uses minshell.html)
- Added: Full Settings Menu UI implementation using existing `UIElementTemplateNodeBuilder`/`UIConfigBuilder` system

**Recommended starting point**: Settings Menu UI (Feature #2) as it provides immediate user value and establishes patterns for other UI features.

---

## References

- Existing web loading screen: `src/minshell.html`
- Current desktop init: `src/core/init.cpp`
- GameState enum: `src/core/globals.hpp:86`
- UI System: `UIElementTemplateNodeBuilder`, `UIConfigBuilder` in `chugget_code_definitions.lua`
- Crash reporter (reference for threading): `src/util/crash_reporter.cpp`
- Async save (reference for threading): `src/systems/save/save_file_io.cpp`

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
