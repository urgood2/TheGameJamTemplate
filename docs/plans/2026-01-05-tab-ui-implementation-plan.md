# Tab UI Implementation Plan (Simplified)

**Date**: 2026-01-05  
**Status**: Ready for TDD Implementation  
**Approach**: Zero new components, single C++ function, Lua-only tab logic

---

## 1. Executive Summary

### Goal
Implement Balatro-style tab UI where the container persists while content swaps.

### Strategy  
- **NO new components** - Reuse existing `UIConfig` fields
- **ONE new C++ function** - `box::ReplaceChildren()`
- **Tab logic in Lua** - Store definitions in closures, use existing `choice`/`chosen`

### Complexity Comparison

| Aspect | Original Plan | Simplified Plan |
|--------|--------------|-----------------|
| New C++ components | 3 | **0** |
| New C++ files | 2 | **0** (add to existing) |
| New C++ functions | 4 | **1** |
| C++ tests | 11 | **12** (more thorough) |
| Lua tests | 4 | **8** (more thorough) |

---

## 2. Balatro's Approach (Reference)

```lua
-- How Balatro stores tab data: just put it on the button's config
UIBox_button({
    id = 'tab_but_Game',
    ref_table = {
        tab_definition_function = function() return {...} end,
    },
    choice = true,   -- Radio button behavior
    chosen = true    -- Currently selected
})

-- How Balatro switches tabs
G.FUNCS.change_tab = function(e)
    local tab_contents = e.UIBox:get_UIE_by_ID('tab_contents')
    tab_contents.config.object:remove()           -- Destroy old
    tab_contents.config.object = UIBox{...}       -- Create new
    tab_contents.UIBox:recalculate()              -- Relayout
end
```

---

## 3. Implementation Design

### 3.1 Existing Infrastructure (Already Have)

| Feature | Location | Purpose |
|---------|----------|---------|
| `config.id` | `UIConfig` | Find elements by ID |
| `config.choice` | `UIConfig` | Radio button grouping |
| `config.chosen` | `UIConfig` | Selected state visual |
| `config.group` | `UIConfig` | Group related elements |
| `config.buttonCallback` | `UIConfig` | Click handlers |
| `box::GetUIEByID()` | `box.hpp:51-52` | Find element by ID |
| `box::Remove()` | `box.hpp:56` | Destroy UIBox recursively |
| `box::Recalculate()` | `box.hpp:58` | Relayout UIBox |
| `box::TraverseUITreeBottomUp()` | `box.hpp:66` | Safe recursive destruction |
| `box::BuildUIElementTree()` | `box.hpp:34` | Build UI from definition |

### 3.2 New C++ Function (Single Addition)

```cpp
// Add to: src/systems/ui/box.hpp

namespace ui::box {

/// Replace all children of a UI element with new content from a definition.
/// Safely destroys existing children, builds new tree, and recalculates layout.
/// 
/// @param registry EnTT registry
/// @param parent Element whose children will be replaced (must be valid)
/// @param newDefinition UI definition tree to build as new children
/// @return true if replacement succeeded, false on error
/// 
/// @note Thread-safety: NOT thread-safe, must be called from main thread
/// @note The parent element itself is NOT destroyed, only its children
/// @note Triggers automatic recalculation of the containing UIBox
bool ReplaceChildren(
    entt::registry& registry,
    entt::entity parent,
    UIElementTemplateNode& newDefinition
);

} // namespace ui::box
```

### 3.3 C++ Implementation

```cpp
// Add to: src/systems/ui/box.cpp

bool box::ReplaceChildren(
    entt::registry& registry,
    entt::entity parent,
    UIElementTemplateNode& newDefinition
) {
    // ========== VALIDATION ==========
    if (!registry.valid(parent)) {
        SPDLOG_WARN("ReplaceChildren: Invalid parent entity");
        return false;
    }
    
    auto* uiElement = registry.try_get<UIElementComponent>(parent);
    if (!uiElement) {
        SPDLOG_WARN("ReplaceChildren: Parent {} has no UIElementComponent", 
                    static_cast<int>(parent));
        return false;
    }
    
    entt::entity uiBox = uiElement->uiBox;
    if (!registry.valid(uiBox)) {
        SPDLOG_WARN("ReplaceChildren: UIBox {} is invalid", 
                    static_cast<int>(uiBox));
        return false;
    }
    
    auto* node = registry.try_get<transform::GameObject>(parent);
    if (!node) {
        SPDLOG_WARN("ReplaceChildren: Parent {} has no GameObject", 
                    static_cast<int>(parent));
        return false;
    }
    
    // ========== DESTROY OLD CHILDREN ==========
    // Collect children first to avoid iterator invalidation
    std::vector<entt::entity> childrenToDestroy;
    childrenToDestroy.reserve(node->orderedChildren.size());
    for (auto child : node->orderedChildren) {
        if (registry.valid(child)) {
            childrenToDestroy.push_back(child);
        }
    }
    
    // Destroy each child subtree (bottom-up for safety)
    for (auto child : childrenToDestroy) {
        TraverseUITreeBottomUp(registry, child, [&](entt::entity e) {
            // Clean up any attached objects
            if (auto* cfg = registry.try_get<UIConfig>(e)) {
                if (cfg->object && registry.valid(cfg->object.value())) {
                    registry.destroy(cfg->object.value());
                }
            }
            registry.destroy(e);
        }, false);  // Don't exclude topmost (the child itself)
    }
    
    // Clear parent's child containers
    node->children.clear();
    node->orderedChildren.clear();
    
    // ========== BUILD NEW CHILDREN ==========
    // Build new UI tree under parent
    BuildUIElementTree(registry, uiBox, newDefinition, parent);
    
    // ========== RECALCULATE LAYOUT ==========
    Recalculate(registry, uiBox);
    
    SPDLOG_DEBUG("ReplaceChildren: Replaced {} old children with new content on entity {}", 
                 childrenToDestroy.size(), static_cast<int>(parent));
    
    return true;
}
```

### 3.4 Lua Binding

```cpp
// Add to: src/systems/ui/ui.cpp (in exposeToLua function)

// Expose ReplaceChildren to Lua
lua["ui"]["box"]["ReplaceChildren"] = [](entt::entity parent, sol::table definition) {
    auto& registry = *globals::getRegistry();
    auto nodeDef = ui::definitions::tableToUIElementTemplateNode(definition);
    return ui::box::ReplaceChildren(registry, parent, nodeDef);
};
```

### 3.5 Lua Tab DSL

```lua
-- Add to: assets/scripts/ui/ui_syntax_sugar.lua

------------------------------------------------------------
-- TAB SYSTEM
-- Stores tab definitions in Lua closures, no C++ tab components needed
------------------------------------------------------------

--- Module-level storage for tab definitions
--- Key: container ID (string), Value: { tabs = {...}, activeId = "..." }
local _tabRegistry = {}

--- Create a tabbed UI container
--- @param opts table Configuration options
--- @param opts.id string Unique container ID (auto-generated if nil)
--- @param opts.tabs table Array of {id, label, content} tab definitions
--- @param opts.activeTab string ID of initially active tab (defaults to first)
--- @param opts.tabBarPadding number Padding in tab bar (default 2)
--- @param opts.contentPadding number Padding in content area (default 6)
--- @param opts.buttonColor string Tab button color (default "gray")
--- @param opts.activeButtonColor string Active tab button color (default "blue")
--- @param opts.contentColor string Content area background color
--- @param opts.contentMinWidth number Minimum content area width
--- @param opts.contentMinHeight number Minimum content area height
--- @return table UI definition node
function dsl.tabs(opts)
    opts = opts or {}
    local tabs = opts.tabs or {}
    
    -- Validate tabs
    if #tabs == 0 then
        log_warn("dsl.tabs: No tabs provided")
        return dsl.vbox{ children = {} }
    end
    
    -- Generate container ID
    local containerId = opts.id or ("tabs_" .. tostring(math.random(100000, 999999)))
    local activeTab = opts.activeTab or tabs[1].id
    
    -- Validate activeTab exists
    local activeFound = false
    for _, tab in ipairs(tabs) do
        if tab.id == activeTab then
            activeFound = true
            break
        end
    end
    if not activeFound then
        log_warn("dsl.tabs: activeTab '" .. tostring(activeTab) .. "' not found, using first tab")
        activeTab = tabs[1].id
    end
    
    -- Store tab definitions for later lookup
    _tabRegistry[containerId] = {
        tabs = tabs,
        activeId = activeTab
    }
    
    -- Build tab buttons
    local tabButtons = {}
    for i, tab in ipairs(tabs) do
        local isActive = (tab.id == activeTab)
        local buttonId = "tab_btn_" .. tab.id
        
        table.insert(tabButtons, def{
            type = "HORIZONTAL_CONTAINER",
            config = {
                id = buttonId,
                color = color(isActive and (opts.activeButtonColor or "blue") or (opts.buttonColor or "gray")),
                hover = true,
                choice = true,
                chosen = isActive,
                group = containerId,
                emboss = opts.emboss or 2,
                padding = opts.buttonPadding or 4,
                minWidth = opts.buttonMinWidth,
                minHeight = opts.buttonMinHeight,
                buttonCallback = function()
                    dsl.switchTab(containerId, tab.id)
                end,
            },
            children = {
                dsl.text(tab.label, {
                    fontSize = opts.fontSize or 14,
                    color = opts.textColor or "white",
                    shadow = true
                })
            }
        })
    end
    
    -- Get initial content
    local initialContent = nil
    for _, tab in ipairs(tabs) do
        if tab.id == activeTab then
            local success, result = pcall(tab.content)
            if success then
                initialContent = result
            else
                log_error("dsl.tabs: Error generating content for tab '" .. tab.id .. "': " .. tostring(result))
                initialContent = dsl.text("Error loading tab", { color = "red" })
            end
            break
        end
    end
    
    -- Build container
    return def{
        type = "VERTICAL_CONTAINER",
        config = {
            id = containerId,
            padding = opts.containerPadding or 0,
            color = color(opts.containerColor),
        },
        children = {
            -- Tab bar
            def{
                type = "HORIZONTAL_CONTAINER",
                config = {
                    id = containerId .. "_bar",
                    padding = opts.tabBarPadding or 2,
                    align = opts.tabBarAlign or bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
                },
                children = tabButtons
            },
            -- Content area
            def{
                type = "VERTICAL_CONTAINER",
                config = {
                    id = containerId .. "_content",
                    padding = opts.contentPadding or 6,
                    minWidth = opts.contentMinWidth,
                    minHeight = opts.contentMinHeight,
                    color = color(opts.contentColor),
                },
                children = initialContent and { initialContent } or {}
            }
        }
    }
end

--- Switch to a different tab
--- @param containerId string The tab container's ID
--- @param newTabId string The ID of the tab to switch to
--- @return boolean true if switch succeeded
function dsl.switchTab(containerId, newTabId)
    -- Get stored tab data
    local tabData = _tabRegistry[containerId]
    if not tabData then
        log_warn("dsl.switchTab: Unknown container '" .. tostring(containerId) .. "'")
        return false
    end
    
    -- Already on this tab?
    if tabData.activeId == newTabId then
        log_debug("dsl.switchTab: Already on tab '" .. newTabId .. "'")
        return true
    end
    
    -- Find the container entity
    local container = ui.box.GetUIEByID(registry, containerId)
    if not container then
        log_warn("dsl.switchTab: Container entity not found: " .. containerId)
        return false
    end
    
    -- Find the new tab definition
    local newTabDef = nil
    for _, tab in ipairs(tabData.tabs) do
        if tab.id == newTabId then
            newTabDef = tab
            break
        end
    end
    
    if not newTabDef then
        log_warn("dsl.switchTab: Tab not found: " .. newTabId)
        return false
    end
    
    -- Generate new content (with error handling)
    local newContent
    local success, result = pcall(newTabDef.content)
    if success then
        newContent = result
    else
        log_error("dsl.switchTab: Error generating content for tab '" .. newTabId .. "': " .. tostring(result))
        newContent = dsl.text("Error loading tab", { color = "red" })
    end
    
    -- Update button states
    local oldTabId = tabData.activeId
    for _, tab in ipairs(tabData.tabs) do
        local btnId = "tab_btn_" .. tab.id
        local btn = ui.box.GetUIEByID(registry, container, btnId)
        if btn then
            local btnConfig = component_cache.get(btn, UIConfig)
            if btnConfig then
                local isNowActive = (tab.id == newTabId)
                btnConfig.chosen = isNowActive
                -- Note: Color update would require separate handling if needed
            end
        end
    end
    
    -- Replace content
    local contentSlot = ui.box.GetUIEByID(registry, container, containerId .. "_content")
    if not contentSlot then
        log_warn("dsl.switchTab: Content slot not found: " .. containerId .. "_content")
        return false
    end
    
    local replaceSuccess = ui.box.ReplaceChildren(contentSlot, newContent)
    if not replaceSuccess then
        log_error("dsl.switchTab: Failed to replace content")
        return false
    end
    
    -- Update stored state
    tabData.activeId = newTabId
    
    log_debug("dsl.switchTab: Switched from '" .. oldTabId .. "' to '" .. newTabId .. "'")
    return true
end

--- Get the currently active tab ID
--- @param containerId string The tab container's ID
--- @return string|nil Active tab ID, or nil if container not found
function dsl.getActiveTab(containerId)
    local tabData = _tabRegistry[containerId]
    return tabData and tabData.activeId or nil
end

--- Clean up tab registry entry (call when destroying tab container)
--- @param containerId string The tab container's ID
function dsl.cleanupTabs(containerId)
    _tabRegistry[containerId] = nil
end

--- Get all registered tab IDs for a container
--- @param containerId string The tab container's ID
--- @return table|nil Array of tab IDs, or nil if container not found
function dsl.getTabIds(containerId)
    local tabData = _tabRegistry[containerId]
    if not tabData then return nil end
    
    local ids = {}
    for _, tab in ipairs(tabData.tabs) do
        table.insert(ids, tab.id)
    end
    return ids
end
```

---

## 4. TDD Test Plan (Comprehensive)

### 4.1 C++ Unit Tests - Core Function

```cpp
// tests/unit/test_replace_children.cpp

#include <gtest/gtest.h>
#include "systems/ui/box.hpp"
#include "systems/ui/ui_data.hpp"

class ReplaceChildrenTest : public ::testing::Test {
protected:
    entt::registry registry;
    
    void SetUp() override {
        // Initialize any required globals
    }
    
    // Helper: Create a simple UIBox with a content slot
    entt::entity createTestUIBox() {
        auto def = ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::ROOT)
            .addConfig(ui::UIConfig::Builder::create()
                .addId("test_root")
                .build())
            .addChild(ui::UIElementTemplateNode::Builder::create()
                .addType(ui::UITypeEnum::VERTICAL_CONTAINER)
                .addConfig(ui::UIConfig::Builder::create()
                    .addId("content_slot")
                    .build())
                .build())
            .build();
        
        return ui::box::Initialize(registry, {0, 0, 400, 300, 0}, def);
    }
    
    // Helper: Create a text definition
    ui::UIElementTemplateNode createTextDef(const std::string& text) {
        return ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::TEXT)
            .addConfig(ui::UIConfig::Builder::create()
                .addText(text)
                .build())
            .build();
    }
    
    // Helper: Get child count
    size_t getChildCount(entt::entity parent) {
        auto* node = registry.try_get<transform::GameObject>(parent);
        return node ? node->orderedChildren.size() : 0;
    }
    
    // Helper: Get first child
    entt::entity getFirstChild(entt::entity parent) {
        auto* node = registry.try_get<transform::GameObject>(parent);
        return (node && !node->orderedChildren.empty()) 
            ? node->orderedChildren[0] : entt::null;
    }
};

//------------------------------------------------------------
// BASIC FUNCTIONALITY TESTS
//------------------------------------------------------------

TEST_F(ReplaceChildrenTest, ReturnsTrue_OnValidInput) {
    auto box = createTestUIBox();
    auto slot = *ui::box::GetUIEByID(registry, box, "content_slot");
    
    auto newDef = createTextDef("New Content");
    bool result = ui::box::ReplaceChildren(registry, slot, newDef);
    
    EXPECT_TRUE(result);
}

TEST_F(ReplaceChildrenTest, DestroysOldChildren) {
    auto box = createTestUIBox();
    auto slot = *ui::box::GetUIEByID(registry, box, "content_slot");
    
    // Add initial content
    auto initialDef = createTextDef("Initial");
    ui::box::ReplaceChildren(registry, slot, initialDef);
    auto oldChild = getFirstChild(slot);
    ASSERT_TRUE(registry.valid(oldChild));
    
    // Replace with new content
    auto newDef = createTextDef("New");
    ui::box::ReplaceChildren(registry, slot, newDef);
    
    // Old child should be destroyed
    EXPECT_FALSE(registry.valid(oldChild));
}

TEST_F(ReplaceChildrenTest, BuildsNewChildren) {
    auto box = createTestUIBox();
    auto slot = *ui::box::GetUIEByID(registry, box, "content_slot");
    ASSERT_EQ(getChildCount(slot), 0);
    
    auto newDef = createTextDef("Hello");
    ui::box::ReplaceChildren(registry, slot, newDef);
    
    EXPECT_EQ(getChildCount(slot), 1);
    
    auto child = getFirstChild(slot);
    auto* config = registry.try_get<ui::UIConfig>(child);
    ASSERT_NE(config, nullptr);
    EXPECT_EQ(config->text.value_or(""), "Hello");
}

TEST_F(ReplaceChildrenTest, PreservesParentConfig) {
    auto box = createTestUIBox();
    auto slot = *ui::box::GetUIEByID(registry, box, "content_slot");
    
    // Set parent config values
    auto& config = registry.get<ui::UIConfig>(slot);
    config.padding = 10.0f;
    config.color = RED;
    
    // Replace children
    auto newDef = createTextDef("Test");
    ui::box::ReplaceChildren(registry, slot, newDef);
    
    // Parent config should be unchanged
    auto& configAfter = registry.get<ui::UIConfig>(slot);
    EXPECT_FLOAT_EQ(configAfter.padding.value_or(0), 10.0f);
    EXPECT_EQ(configAfter.color->r, RED.r);
}

TEST_F(ReplaceChildrenTest, TriggersLayoutRecalculation) {
    auto box = createTestUIBox();
    auto slot = *ui::box::GetUIEByID(registry, box, "content_slot");
    
    auto& transformBefore = registry.get<transform::Transform>(slot);
    float heightBefore = transformBefore.actualH;
    
    // Add tall content
    auto tallDef = ui::UIElementTemplateNode::Builder::create()
        .addType(ui::UITypeEnum::VERTICAL_CONTAINER)
        .addChild(createTextDef("Line 1"))
        .addChild(createTextDef("Line 2"))
        .addChild(createTextDef("Line 3"))
        .addChild(createTextDef("Line 4"))
        .addChild(createTextDef("Line 5"))
        .build();
    
    ui::box::ReplaceChildren(registry, slot, tallDef);
    
    auto& transformAfter = registry.get<transform::Transform>(slot);
    EXPECT_GT(transformAfter.actualH, heightBefore);
}

//------------------------------------------------------------
// EDGE CASE TESTS
//------------------------------------------------------------

TEST_F(ReplaceChildrenTest, ReturnsFalse_OnInvalidParent) {
    auto newDef = createTextDef("Test");
    bool result = ui::box::ReplaceChildren(registry, entt::null, newDef);
    
    EXPECT_FALSE(result);
}

TEST_F(ReplaceChildrenTest, ReturnsFalse_OnDestroyedParent) {
    auto box = createTestUIBox();
    auto slot = *ui::box::GetUIEByID(registry, box, "content_slot");
    
    registry.destroy(slot);
    
    auto newDef = createTextDef("Test");
    bool result = ui::box::ReplaceChildren(registry, slot, newDef);
    
    EXPECT_FALSE(result);
}

TEST_F(ReplaceChildrenTest, HandlesEmptyContent) {
    auto box = createTestUIBox();
    auto slot = *ui::box::GetUIEByID(registry, box, "content_slot");
    
    // Add initial content
    auto initialDef = createTextDef("Initial");
    ui::box::ReplaceChildren(registry, slot, initialDef);
    ASSERT_EQ(getChildCount(slot), 1);
    
    // Replace with empty container
    auto emptyDef = ui::UIElementTemplateNode::Builder::create()
        .addType(ui::UITypeEnum::VERTICAL_CONTAINER)
        .build();
    
    bool result = ui::box::ReplaceChildren(registry, slot, emptyDef);
    
    EXPECT_TRUE(result);
    EXPECT_EQ(getChildCount(slot), 1);  // Empty container is still a child
}

TEST_F(ReplaceChildrenTest, HandlesDeeplyNestedContent) {
    auto box = createTestUIBox();
    auto slot = *ui::box::GetUIEByID(registry, box, "content_slot");
    
    // Create 5 levels of nesting
    auto level5 = createTextDef("Deep");
    auto level4 = ui::UIElementTemplateNode::Builder::create()
        .addType(ui::UITypeEnum::VERTICAL_CONTAINER)
        .addChild(level5)
        .build();
    auto level3 = ui::UIElementTemplateNode::Builder::create()
        .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
        .addChild(level4)
        .build();
    auto level2 = ui::UIElementTemplateNode::Builder::create()
        .addType(ui::UITypeEnum::VERTICAL_CONTAINER)
        .addChild(level3)
        .build();
    auto level1 = ui::UIElementTemplateNode::Builder::create()
        .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
        .addChild(level2)
        .build();
    
    bool result = ui::box::ReplaceChildren(registry, slot, level1);
    
    EXPECT_TRUE(result);
    // Verify we can find the deep text
    // (would need to traverse tree to verify)
}

TEST_F(ReplaceChildrenTest, CleansUpAttachedObjects) {
    auto box = createTestUIBox();
    auto slot = *ui::box::GetUIEByID(registry, box, "content_slot");
    
    // Create content with an attached object
    auto objEntity = registry.create();
    registry.emplace<transform::Transform>(objEntity);
    
    auto defWithObj = ui::UIElementTemplateNode::Builder::create()
        .addType(ui::UITypeEnum::OBJECT)
        .addConfig(ui::UIConfig::Builder::create()
            .addObject(objEntity)
            .build())
        .build();
    
    ui::box::ReplaceChildren(registry, slot, defWithObj);
    ASSERT_TRUE(registry.valid(objEntity));
    
    // Replace with simple content
    auto newDef = createTextDef("New");
    ui::box::ReplaceChildren(registry, slot, newDef);
    
    // Attached object should also be destroyed
    EXPECT_FALSE(registry.valid(objEntity));
}

//------------------------------------------------------------
// MEMORY SAFETY TESTS
//------------------------------------------------------------

TEST_F(ReplaceChildrenTest, NoMemoryLeaks_OnRepeatedReplacements) {
    auto box = createTestUIBox();
    auto slot = *ui::box::GetUIEByID(registry, box, "content_slot");
    
    size_t initialEntityCount = registry.storage<entt::entity>().size();
    
    // Replace content many times
    for (int i = 0; i < 100; ++i) {
        auto def = createTextDef("Iteration " + std::to_string(i));
        ui::box::ReplaceChildren(registry, slot, def);
    }
    
    // Entity count should not grow unboundedly
    size_t finalEntityCount = registry.storage<entt::entity>().size();
    // Allow some growth for the current content, but not 100x
    EXPECT_LT(finalEntityCount, initialEntityCount + 20);
}

TEST_F(ReplaceChildrenTest, NoDoubleFree_OnRapidReplacements) {
    auto box = createTestUIBox();
    auto slot = *ui::box::GetUIEByID(registry, box, "content_slot");
    
    // Rapid replacements should not cause crashes
    for (int i = 0; i < 50; ++i) {
        auto def = createTextDef("Fast " + std::to_string(i));
        EXPECT_NO_THROW(ui::box::ReplaceChildren(registry, slot, def));
    }
}

//------------------------------------------------------------
// CONSISTENCY TESTS
//------------------------------------------------------------

TEST_F(ReplaceChildrenTest, ParentChildRelationshipsCorrect) {
    auto box = createTestUIBox();
    auto slot = *ui::box::GetUIEByID(registry, box, "content_slot");
    
    auto def = ui::UIElementTemplateNode::Builder::create()
        .addType(ui::UITypeEnum::VERTICAL_CONTAINER)
        .addConfig(ui::UIConfig::Builder::create()
            .addId("new_vbox")
            .build())
        .addChild(createTextDef("Child 1"))
        .addChild(createTextDef("Child 2"))
        .build();
    
    ui::box::ReplaceChildren(registry, slot, def);
    
    // Verify parent-child relationships
    auto vbox = getFirstChild(slot);
    auto* vboxNode = registry.try_get<transform::GameObject>(vbox);
    ASSERT_NE(vboxNode, nullptr);
    EXPECT_EQ(vboxNode->parent.value_or(entt::null), slot);
    
    for (auto child : vboxNode->orderedChildren) {
        auto* childNode = registry.try_get<transform::GameObject>(child);
        ASSERT_NE(childNode, nullptr);
        EXPECT_EQ(childNode->parent.value_or(entt::null), vbox);
    }
}

TEST_F(ReplaceChildrenTest, UIElementComponent_HasCorrectUIBox) {
    auto box = createTestUIBox();
    auto slot = *ui::box::GetUIEByID(registry, box, "content_slot");
    
    auto def = createTextDef("Test");
    ui::box::ReplaceChildren(registry, slot, def);
    
    auto child = getFirstChild(slot);
    auto* uiElement = registry.try_get<ui::UIElementComponent>(child);
    ASSERT_NE(uiElement, nullptr);
    EXPECT_EQ(uiElement->uiBox, box);
}
```

### 4.2 C++ Integration Tests

```cpp
// tests/unit/test_replace_children_integration.cpp

TEST_F(ReplaceChildrenTest, Integration_MultipleContentSlotsInSameUIBox) {
    // Create UIBox with two content slots
    auto def = ui::UIElementTemplateNode::Builder::create()
        .addType(ui::UITypeEnum::ROOT)
        .addChild(ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::HORIZONTAL_CONTAINER)
            .addChild(ui::UIElementTemplateNode::Builder::create()
                .addType(ui::UITypeEnum::VERTICAL_CONTAINER)
                .addConfig(ui::UIConfig::Builder::create()
                    .addId("slot_left")
                    .build())
                .build())
            .addChild(ui::UIElementTemplateNode::Builder::create()
                .addType(ui::UITypeEnum::VERTICAL_CONTAINER)
                .addConfig(ui::UIConfig::Builder::create()
                    .addId("slot_right")
                    .build())
                .build())
            .build())
        .build();
    
    auto box = ui::box::Initialize(registry, {0, 0, 800, 600, 0}, def);
    auto slotLeft = *ui::box::GetUIEByID(registry, box, "slot_left");
    auto slotRight = *ui::box::GetUIEByID(registry, box, "slot_right");
    
    // Replace left slot
    auto leftDef = createTextDef("Left Content");
    ui::box::ReplaceChildren(registry, slotLeft, leftDef);
    
    // Replace right slot
    auto rightDef = createTextDef("Right Content");
    ui::box::ReplaceChildren(registry, slotRight, rightDef);
    
    // Both should have correct content
    auto leftChild = getFirstChild(slotLeft);
    auto rightChild = getFirstChild(slotRight);
    
    EXPECT_EQ(registry.get<ui::UIConfig>(leftChild).text.value_or(""), "Left Content");
    EXPECT_EQ(registry.get<ui::UIConfig>(rightChild).text.value_or(""), "Right Content");
}

TEST_F(ReplaceChildrenTest, Integration_ReplacingDoesNotAffectSiblings) {
    auto def = ui::UIElementTemplateNode::Builder::create()
        .addType(ui::UITypeEnum::ROOT)
        .addChild(ui::UIElementTemplateNode::Builder::create()
            .addType(ui::UITypeEnum::VERTICAL_CONTAINER)
            .addChild(ui::UIElementTemplateNode::Builder::create()
                .addType(ui::UITypeEnum::TEXT)
                .addConfig(ui::UIConfig::Builder::create()
                    .addId("sibling_above")
                    .addText("Above")
                    .build())
                .build())
            .addChild(ui::UIElementTemplateNode::Builder::create()
                .addType(ui::UITypeEnum::VERTICAL_CONTAINER)
                .addConfig(ui::UIConfig::Builder::create()
                    .addId("content_slot")
                    .build())
                .build())
            .addChild(ui::UIElementTemplateNode::Builder::create()
                .addType(ui::UITypeEnum::TEXT)
                .addConfig(ui::UIConfig::Builder::create()
                    .addId("sibling_below")
                    .addText("Below")
                    .build())
                .build())
            .build())
        .build();
    
    auto box = ui::box::Initialize(registry, {0, 0, 400, 600, 0}, def);
    auto slot = *ui::box::GetUIEByID(registry, box, "content_slot");
    auto siblingAbove = *ui::box::GetUIEByID(registry, box, "sibling_above");
    auto siblingBelow = *ui::box::GetUIEByID(registry, box, "sibling_below");
    
    // Replace content
    auto newDef = createTextDef("New Content");
    ui::box::ReplaceChildren(registry, slot, newDef);
    
    // Siblings should be unaffected
    EXPECT_TRUE(registry.valid(siblingAbove));
    EXPECT_TRUE(registry.valid(siblingBelow));
    EXPECT_EQ(registry.get<ui::UIConfig>(siblingAbove).text.value_or(""), "Above");
    EXPECT_EQ(registry.get<ui::UIConfig>(siblingBelow).text.value_or(""), "Below");
}
```

### 4.3 Lua Unit Tests

```lua
-- tests/lua/test_tab_ui.lua

local TestRunner = require("tests.test_runner")
local dsl = require("ui.ui_syntax_sugar")

local tests = {}

------------------------------------------------------------
-- DSL.TABS TESTS
------------------------------------------------------------

function tests.test_tabs_creates_valid_definition()
    local def = dsl.tabs{
        id = "test_tabs",
        tabs = {
            { id = "a", label = "Tab A", content = function() return dsl.text("A") end },
            { id = "b", label = "Tab B", content = function() return dsl.text("B") end }
        }
    }
    
    assert(def ~= nil, "tabs should return a definition")
    assert(def.type == "VERTICAL_CONTAINER", "root should be vertical container")
    assert(def.config.id == "test_tabs", "should have correct ID")
    assert(#def.children == 2, "should have tab bar and content area")
end

function tests.test_tabs_creates_correct_button_count()
    local def = dsl.tabs{
        tabs = {
            { id = "a", label = "A", content = function() return dsl.text("A") end },
            { id = "b", label = "B", content = function() return dsl.text("B") end },
            { id = "c", label = "C", content = function() return dsl.text("C") end },
        }
    }
    
    local tabBar = def.children[1]
    assert(#tabBar.children == 3, "should have 3 tab buttons")
end

function tests.test_tabs_first_tab_active_by_default()
    local def = dsl.tabs{
        id = "test_default",
        tabs = {
            { id = "first", label = "First", content = function() return dsl.text("F") end },
            { id = "second", label = "Second", content = function() return dsl.text("S") end }
        }
    }
    
    local tabBar = def.children[1]
    local firstBtn = tabBar.children[1]
    local secondBtn = tabBar.children[2]
    
    assert(firstBtn.config.chosen == true, "first button should be chosen")
    assert(secondBtn.config.chosen == false, "second button should not be chosen")
end

function tests.test_tabs_respects_activeTab_option()
    local def = dsl.tabs{
        id = "test_active",
        activeTab = "second",
        tabs = {
            { id = "first", label = "First", content = function() return dsl.text("F") end },
            { id = "second", label = "Second", content = function() return dsl.text("S") end }
        }
    }
    
    local tabBar = def.children[1]
    local firstBtn = tabBar.children[1]
    local secondBtn = tabBar.children[2]
    
    assert(firstBtn.config.chosen == false, "first button should not be chosen")
    assert(secondBtn.config.chosen == true, "second button should be chosen")
end

function tests.test_tabs_handles_empty_tabs_gracefully()
    local def = dsl.tabs{
        tabs = {}
    }
    
    -- Should not crash, should return something
    assert(def ~= nil, "should handle empty tabs")
end

function tests.test_tabs_handles_invalid_activeTab()
    local def = dsl.tabs{
        activeTab = "nonexistent",
        tabs = {
            { id = "a", label = "A", content = function() return dsl.text("A") end }
        }
    }
    
    -- Should fall back to first tab
    local tabBar = def.children[1]
    local firstBtn = tabBar.children[1]
    assert(firstBtn.config.chosen == true, "should fall back to first tab")
end

------------------------------------------------------------
-- SWITCH TAB TESTS (require spawned UI)
------------------------------------------------------------

function tests.test_switchTab_returns_true_on_success()
    local containerId = "switch_test_" .. tostring(math.random(100000))
    local box = dsl.spawn({ x = 0, y = 0 }, dsl.tabs{
        id = containerId,
        tabs = {
            { id = "a", label = "A", content = function() return dsl.text("Content A") end },
            { id = "b", label = "B", content = function() return dsl.text("Content B") end }
        }
    })
    
    local result = dsl.switchTab(containerId, "b")
    
    assert(result == true, "switchTab should return true")
    
    -- Cleanup
    ui.box.Remove(registry, box)
    dsl.cleanupTabs(containerId)
end

function tests.test_switchTab_updates_activeTab()
    local containerId = "active_test_" .. tostring(math.random(100000))
    local box = dsl.spawn({ x = 0, y = 0 }, dsl.tabs{
        id = containerId,
        tabs = {
            { id = "a", label = "A", content = function() return dsl.text("A") end },
            { id = "b", label = "B", content = function() return dsl.text("B") end }
        }
    })
    
    assert(dsl.getActiveTab(containerId) == "a", "should start on tab a")
    
    dsl.switchTab(containerId, "b")
    
    assert(dsl.getActiveTab(containerId) == "b", "should be on tab b after switch")
    
    -- Cleanup
    ui.box.Remove(registry, box)
    dsl.cleanupTabs(containerId)
end

function tests.test_switchTab_returns_false_for_unknown_container()
    local result = dsl.switchTab("nonexistent_container_12345", "a")
    assert(result == false, "should return false for unknown container")
end

function tests.test_switchTab_returns_false_for_unknown_tab()
    local containerId = "unknown_tab_test_" .. tostring(math.random(100000))
    local box = dsl.spawn({ x = 0, y = 0 }, dsl.tabs{
        id = containerId,
        tabs = {
            { id = "a", label = "A", content = function() return dsl.text("A") end }
        }
    })
    
    local result = dsl.switchTab(containerId, "nonexistent")
    
    assert(result == false, "should return false for unknown tab")
    
    -- Cleanup
    ui.box.Remove(registry, box)
    dsl.cleanupTabs(containerId)
end

function tests.test_switchTab_handles_content_error_gracefully()
    local containerId = "error_test_" .. tostring(math.random(100000))
    local box = dsl.spawn({ x = 0, y = 0 }, dsl.tabs{
        id = containerId,
        tabs = {
            { id = "a", label = "A", content = function() return dsl.text("A") end },
            { id = "b", label = "B", content = function() 
                error("Intentional error for testing")
            end }
        }
    })
    
    -- Should not crash, should show error state
    local result = dsl.switchTab(containerId, "b")
    
    assert(result == true, "should still succeed but show error")
    
    -- Cleanup
    ui.box.Remove(registry, box)
    dsl.cleanupTabs(containerId)
end

function tests.test_switchTab_same_tab_is_noop()
    local containerId = "noop_test_" .. tostring(math.random(100000))
    local contentCallCount = 0
    
    local box = dsl.spawn({ x = 0, y = 0 }, dsl.tabs{
        id = containerId,
        tabs = {
            { id = "a", label = "A", content = function() 
                contentCallCount = contentCallCount + 1
                return dsl.text("A") 
            end }
        }
    })
    
    local initialCount = contentCallCount  -- After initial render
    
    dsl.switchTab(containerId, "a")  -- Same tab
    
    assert(contentCallCount == initialCount, "should not regenerate content for same tab")
    
    -- Cleanup
    ui.box.Remove(registry, box)
    dsl.cleanupTabs(containerId)
end

------------------------------------------------------------
-- VISUAL CONSISTENCY TESTS
------------------------------------------------------------

function tests.test_rapid_tab_switching_no_crash()
    local containerId = "rapid_test_" .. tostring(math.random(100000))
    local box = dsl.spawn({ x = 0, y = 0 }, dsl.tabs{
        id = containerId,
        tabs = {
            { id = "a", label = "A", content = function() return dsl.text("A") end },
            { id = "b", label = "B", content = function() return dsl.text("B") end },
            { id = "c", label = "C", content = function() return dsl.text("C") end }
        }
    })
    
    -- Rapidly switch tabs
    for i = 1, 50 do
        local tabs = {"a", "b", "c"}
        local tab = tabs[(i % 3) + 1]
        dsl.switchTab(containerId, tab)
    end
    
    -- Should not have crashed
    assert(dsl.getActiveTab(containerId) ~= nil, "should have valid active tab after rapid switching")
    
    -- Cleanup
    ui.box.Remove(registry, box)
    dsl.cleanupTabs(containerId)
end

------------------------------------------------------------
-- RUN TESTS
------------------------------------------------------------

return TestRunner.run(tests)
```

---

## 5. File Changes Summary

### Modified Files Only (No New Files)

| File | Changes |
|------|---------|
| `src/systems/ui/box.hpp` | Add `ReplaceChildren()` declaration (3 lines) |
| `src/systems/ui/box.cpp` | Add `ReplaceChildren()` implementation (~60 lines) |
| `src/systems/ui/ui.cpp` | Add Lua binding for `ReplaceChildren` (5 lines) |
| `assets/scripts/ui/ui_syntax_sugar.lua` | Add `dsl.tabs()`, `switchTab()`, helpers (~150 lines) |
| `tests/unit/test_ui_box.cpp` | Add `ReplaceChildren` tests (~200 lines) |
| `assets/scripts/tests/test_tab_ui.lua` | Add Lua tests (~150 lines) |

### Total New Code
- **C++**: ~70 lines (function + binding)
- **Lua**: ~150 lines (tab DSL)
- **Tests**: ~350 lines

---

## 6. Implementation Order

| Phase | Task | Tests First | Est. Time |
|-------|------|-------------|-----------|
| 1 | Write C++ unit tests for `ReplaceChildren` | 12 tests | 1 hour |
| 2 | Implement `ReplaceChildren` in `box.cpp` | - | 1 hour |
| 3 | Add Lua binding | - | 15 min |
| 4 | Write Lua tab tests | 8 tests | 45 min |
| 5 | Implement `dsl.tabs()` and `switchTab()` | - | 1.5 hours |
| 6 | Manual visual testing | - | 30 min |
| 7 | Edge case fixes | - | 1 hour |

**Total Estimated Time**: 6 hours

---

## 7. Potential Bug Areas (Watch For)

| Risk | Mitigation |
|------|------------|
| **Memory leaks** | Test entity count before/after repeated replacements |
| **Double-free** | Bottom-up traversal, collect entities before destroying |
| **Orphaned objects** | Explicitly destroy `config.object` entities |
| **Invalid entity access** | Check `registry.valid()` before all operations |
| **Layout glitches** | Always call `Recalculate()` after replacement |
| **Stale Lua references** | Use string IDs, not entity handles in closures |
| **Content generation errors** | Wrap `pcall()` around content functions |
| **Tab state desync** | Single source of truth in `_tabRegistry` |

---

## 8. Usage Example

```lua
local dsl = require("ui.ui_syntax_sugar")

-- Create settings menu with tabs
local settingsUI = dsl.tabs{
    id = "settings",
    activeTab = "game",
    contentMinWidth = 400,
    contentMinHeight = 300,
    tabs = {
        {
            id = "game",
            label = "Game",
            content = function()
                return dsl.vbox{
                    children = {
                        dsl.text("Game Settings", { fontSize = 20 }),
                        dsl.spacer(10),
                        dsl.button("Speed: Normal", { onClick = toggleSpeed }),
                        dsl.button("Difficulty: Medium", { onClick = toggleDifficulty }),
                    }
                }
            end
        },
        {
            id = "graphics",
            label = "Graphics",
            content = function()
                return dsl.vbox{
                    children = {
                        dsl.text("Graphics Settings", { fontSize = 20 }),
                        dsl.spacer(10),
                        dsl.button("Fullscreen: Off", { onClick = toggleFullscreen }),
                        dsl.button("VSync: On", { onClick = toggleVSync }),
                    }
                }
            end
        },
        {
            id = "audio",
            label = "Audio",
            content = function()
                return dsl.vbox{
                    children = {
                        dsl.text("Audio Settings", { fontSize = 20 }),
                        dsl.spacer(10),
                        dsl.progressBar({ getValue = getMasterVolume }),
                        dsl.progressBar({ getValue = getMusicVolume }),
                    }
                }
            end
        }
    }
}

local menuBox = dsl.spawn({ x = 400, y = 300 }, settingsUI)

-- Later, programmatically switch tabs:
dsl.switchTab("settings", "audio")
```

---

## 9. Open Questions (Deferred)

These can be addressed in future iterations:

1. **Controller navigation** - Shoulder buttons to cycle tabs?
2. **Tab animations** - Fade/slide transitions?
3. **Visual button updates** - Change button color on selection?
4. **Tab overflow** - Scrollable tab bar for many tabs?
5. **Nested tabs** - Tabs within tabs?
