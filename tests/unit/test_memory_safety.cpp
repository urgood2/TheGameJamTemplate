#include <gtest/gtest.h>

#include <algorithm>
#include <memory>
#include <random>
#include <string>
#include <thread>
#include <vector>

#include "systems/shaders/shader_system.hpp"

// =============================================================================
// Shader System Memory Safety Tests
// These tests are designed to catch memory issues when run with AddressSanitizer
// =============================================================================

namespace
{
    // Stub shader API for testing
    struct ShaderMemoryTestStats
    {
        static void Reset()
        {
            loadCount = 0;
            unloadCount = 0;
            allocatedShaders.clear();
        }

        inline static int loadCount = 0;
        inline static int unloadCount = 0;
        inline static std::vector<unsigned int> allocatedShaders;
    };

    Shader MemoryTestLoadShader(const char*, const char*)
    {
        ShaderMemoryTestStats::loadCount++;
        Shader shader{};
        shader.id = 100 + ShaderMemoryTestStats::loadCount;
        ShaderMemoryTestStats::allocatedShaders.push_back(shader.id);
        return shader;
    }

    void MemoryTestUnloadShader(Shader shader)
    {
        ShaderMemoryTestStats::unloadCount++;
        auto it = std::find(ShaderMemoryTestStats::allocatedShaders.begin(),
                           ShaderMemoryTestStats::allocatedShaders.end(),
                           shader.id);
        if (it != ShaderMemoryTestStats::allocatedShaders.end())
        {
            ShaderMemoryTestStats::allocatedShaders.erase(it);
        }
    }

    int MemoryTestGetShaderLocation(Shader, const char*)
    {
        return 0;
    }

    void MemoryTestSetShaderValue(Shader, int, const void*, int) {}
    void MemoryTestSetShaderValueTexture(Shader, int, Texture2D) {}
    void MemoryTestBeginShaderMode(Shader) {}
    void MemoryTestEndShaderMode() {}
    unsigned int MemoryTestRlGetShaderIdDefault() { return 0; }

    void InstallMemoryTestHooks()
    {
        shaders::SetShaderApiHooks({
            MemoryTestLoadShader,
            MemoryTestUnloadShader,
            MemoryTestGetShaderLocation,
            MemoryTestSetShaderValue,
            MemoryTestSetShaderValueTexture,
            MemoryTestBeginShaderMode,
            MemoryTestEndShaderMode,
            MemoryTestRlGetShaderIdDefault
        });
    }

} // namespace

class ShaderMemorySafetyTest : public ::testing::Test
{
protected:
    void SetUp() override
    {
        ShaderMemoryTestStats::Reset();
        InstallMemoryTestHooks();
        shaders::loadedShaders.clear();
        shaders::shaderPaths.clear();
        shaders::shaderFileModificationTimes.clear();
    }

    void TearDown() override
    {
        shaders::ResetShaderApiHooks();
        shaders::loadedShaders.clear();
        shaders::shaderPaths.clear();
        shaders::shaderFileModificationTimes.clear();
    }
};

// Test rapid allocation/deallocation cycles - ASAN will catch use-after-free
TEST_F(ShaderMemorySafetyTest, RapidShaderLoadUnloadCycles)
{
    const int numCycles = 100;

    for (int i = 0; i < numCycles; i++)
    {
        std::string shaderName = "test_shader_" + std::to_string(i);

        // Load shader
        Shader shader = shaders::GetShaderApiHooks().load_shader("test.vs", "test.fs");
        shaders::loadedShaders[shaderName] = shader;
        shaders::shaderPaths[shaderName] = {"test.vs", "test.fs"};

        // Immediately unload
        shaders::GetShaderApiHooks().unload_shader(shader);
        shaders::loadedShaders.erase(shaderName);
        shaders::shaderPaths.erase(shaderName);
    }

    EXPECT_EQ(ShaderMemoryTestStats::loadCount, numCycles);
    EXPECT_EQ(ShaderMemoryTestStats::unloadCount, numCycles);
    EXPECT_TRUE(ShaderMemoryTestStats::allocatedShaders.empty());
}

// Test uniform operations with various string lengths - ASAN catches buffer overflows
TEST_F(ShaderMemorySafetyTest, UniformSetWithVariousStringLengths)
{
    shaders::ShaderUniformSet set;

    // Empty string
    set.set("", 1.0f);

    // Short string
    set.set("u", 2.0f);

    // Normal string
    set.set("uNormalUniform", 3.0f);

    // Long string
    std::string longName(1000, 'x');
    set.set(longName, 4.0f);

    // Very long string
    std::string veryLongName(10000, 'y');
    set.set(veryLongName, 5.0f);

    // Verify all were stored correctly
    EXPECT_NE(set.get(""), nullptr);
    EXPECT_NE(set.get("u"), nullptr);
    EXPECT_NE(set.get("uNormalUniform"), nullptr);
    EXPECT_NE(set.get(longName), nullptr);
    EXPECT_NE(set.get(veryLongName), nullptr);

    // Verify values
    EXPECT_FLOAT_EQ(std::get<float>(*set.get("")), 1.0f);
    EXPECT_FLOAT_EQ(std::get<float>(*set.get(veryLongName)), 5.0f);
}

// Test uniform overwrite - ensures proper cleanup of old values
TEST_F(ShaderMemorySafetyTest, UniformOverwriteCleanup)
{
    shaders::ShaderUniformSet set;

    // Set initial value
    set.set("uTest", 1.0f);
    EXPECT_FLOAT_EQ(std::get<float>(*set.get("uTest")), 1.0f);

    // Overwrite with same type
    set.set("uTest", 2.0f);
    EXPECT_FLOAT_EQ(std::get<float>(*set.get("uTest")), 2.0f);

    // Overwrite with different type (variant change)
    set.set("uTest", Vector2{3.0f, 4.0f});
    auto v2 = std::get<Vector2>(*set.get("uTest"));
    EXPECT_FLOAT_EQ(v2.x, 3.0f);
    EXPECT_FLOAT_EQ(v2.y, 4.0f);

    // Overwrite with larger type
    set.set("uTest", Vector4{1.0f, 2.0f, 3.0f, 4.0f});
    auto v4 = std::get<Vector4>(*set.get("uTest"));
    EXPECT_FLOAT_EQ(v4.x, 1.0f);
    EXPECT_FLOAT_EQ(v4.w, 4.0f);

    // Back to smaller type
    set.set("uTest", 0.0f);
    EXPECT_FLOAT_EQ(std::get<float>(*set.get("uTest")), 0.0f);
}

// Test many uniforms - stress test for map operations
TEST_F(ShaderMemorySafetyTest, ManyUniformsStressTest)
{
    shaders::ShaderUniformSet set;
    const int numUniforms = 1000;

    // Add many uniforms
    for (int i = 0; i < numUniforms; i++)
    {
        std::string name = "uUniform_" + std::to_string(i);
        set.set(name, static_cast<float>(i));
    }

    // Verify all exist
    for (int i = 0; i < numUniforms; i++)
    {
        std::string name = "uUniform_" + std::to_string(i);
        ASSERT_NE(set.get(name), nullptr) << "Missing uniform: " << name;
        EXPECT_FLOAT_EQ(std::get<float>(*set.get(name)), static_cast<float>(i));
    }

    // Update all in reverse order
    for (int i = numUniforms - 1; i >= 0; i--)
    {
        std::string name = "uUniform_" + std::to_string(i);
        set.set(name, static_cast<float>(i * 2));
    }

    // Verify updates
    for (int i = 0; i < numUniforms; i++)
    {
        std::string name = "uUniform_" + std::to_string(i);
        EXPECT_FLOAT_EQ(std::get<float>(*set.get(name)), static_cast<float>(i * 2));
    }
}

// Test shader path storage with special characters
TEST_F(ShaderMemorySafetyTest, ShaderPathsWithSpecialCharacters)
{
    std::vector<std::pair<std::string, std::string>> testPaths = {
        {"path/with/slashes.vs", "path/with/slashes.fs"},
        {"path\\with\\backslashes.vs", "path\\with\\backslashes.fs"},
        {"path with spaces.vs", "path with spaces.fs"},
        {"path_with_émojis_🎮.vs", "path_with_émojis_🎮.fs"},
        {"日本語パス.vs", "日本語パス.fs"},
        {"", ""},
        {std::string(500, 'a') + ".vs", std::string(500, 'b') + ".fs"},
    };

    for (size_t i = 0; i < testPaths.size(); i++)
    {
        std::string shaderName = "shader_" + std::to_string(i);
        shaders::shaderPaths[shaderName] = testPaths[i];
    }

    // Verify all paths stored correctly
    for (size_t i = 0; i < testPaths.size(); i++)
    {
        std::string shaderName = "shader_" + std::to_string(i);
        ASSERT_TRUE(shaders::shaderPaths.count(shaderName) > 0);
        EXPECT_EQ(shaders::shaderPaths[shaderName].first, testPaths[i].first);
        EXPECT_EQ(shaders::shaderPaths[shaderName].second, testPaths[i].second);
    }
}

// Test ApplyUniformsToShader with various uniform types
TEST_F(ShaderMemorySafetyTest, ApplyUniformsVariantTypes)
{
    shaders::ShaderUniformSet set;

    // Add all supported uniform types
    set.set("uFloat", 1.0f);
    set.set("uVec2", Vector2{1.0f, 2.0f});
    set.set("uVec3", Vector3{1.0f, 2.0f, 3.0f});
    set.set("uVec4", Vector4{1.0f, 2.0f, 3.0f, 4.0f});
    set.set("uBool", true);
    set.set("uInt", 42);

    Texture2D tex{};
    tex.id = 123;
    tex.width = 256;
    tex.height = 256;
    set.set("uTexture", tex);

    // Apply uniforms - should not crash
    Shader shader{};
    shader.id = 1;
    shaders::ApplyUniformsToShader(shader, set);

    SUCCEED();
}

// Test shader map operations under stress
TEST_F(ShaderMemorySafetyTest, ShaderMapStressOperations)
{
    const int numOperations = 500;
    std::mt19937 rng(12345); // Fixed seed for reproducibility

    for (int i = 0; i < numOperations; i++)
    {
        int op = rng() % 4;
        std::string shaderName = "shader_" + std::to_string(rng() % 50);

        switch (op)
        {
            case 0: // Insert
            {
                Shader shader{};
                shader.id = rng() % 1000;
                shaders::loadedShaders[shaderName] = shader;
                shaders::shaderPaths[shaderName] = {"test.vs", "test.fs"};
                break;
            }
            case 1: // Lookup
            {
                auto it = shaders::loadedShaders.find(shaderName);
                if (it != shaders::loadedShaders.end())
                {
                    [[maybe_unused]] auto id = it->second.id;
                }
                break;
            }
            case 2: // Update
            {
                if (shaders::loadedShaders.count(shaderName) > 0)
                {
                    shaders::loadedShaders[shaderName].id = rng() % 1000;
                }
                break;
            }
            case 3: // Delete
            {
                shaders::loadedShaders.erase(shaderName);
                shaders::shaderPaths.erase(shaderName);
                break;
            }
        }
    }

    // Clear at end
    shaders::loadedShaders.clear();
    shaders::shaderPaths.clear();

    SUCCEED();
}

// Test modification time tracking
TEST_F(ShaderMemorySafetyTest, ModificationTimeTracking)
{
    const int numShaders = 100;

    // Add modification times
    for (int i = 0; i < numShaders; i++)
    {
        std::string name = "shader_" + std::to_string(i);
        shaders::shaderFileModificationTimes[name] = {
            static_cast<long>(i * 1000),
            static_cast<long>(i * 1000 + 500)
        };
    }

    // Verify and update
    for (int i = 0; i < numShaders; i++)
    {
        std::string name = "shader_" + std::to_string(i);
        auto& times = shaders::shaderFileModificationTimes[name];
        EXPECT_EQ(times.first, static_cast<long>(i * 1000));
        EXPECT_EQ(times.second, static_cast<long>(i * 1000 + 500));

        // Update
        times.first += 1;
        times.second += 1;
    }

    // Verify updates
    for (int i = 0; i < numShaders; i++)
    {
        std::string name = "shader_" + std::to_string(i);
        auto& times = shaders::shaderFileModificationTimes[name];
        EXPECT_EQ(times.first, static_cast<long>(i * 1000 + 1));
        EXPECT_EQ(times.second, static_cast<long>(i * 1000 + 501));
    }
}

// Test concurrent-like access patterns (simulated)
TEST_F(ShaderMemorySafetyTest, SimulatedConcurrentAccess)
{
    // Simulate interleaved operations that might happen in a game loop
    const int numIterations = 100;

    for (int iter = 0; iter < numIterations; iter++)
    {
        // Game loop iteration: load new shader
        std::string newShader = "new_shader_" + std::to_string(iter);
        Shader shader{};
        shader.id = 1000 + iter;
        shaders::loadedShaders[newShader] = shader;

        // Apply some uniforms
        shaders::ShaderUniformSet set;
        set.set("uTime", static_cast<float>(iter) * 0.016f);
        set.set("uResolution", Vector2{1920.0f, 1080.0f});
        shaders::ApplyUniformsToShader(shader, set);

        // Unload old shader if exists
        std::string oldShader = "new_shader_" + std::to_string(iter - 10);
        auto it = shaders::loadedShaders.find(oldShader);
        if (it != shaders::loadedShaders.end())
        {
            shaders::GetShaderApiHooks().unload_shader(it->second);
            shaders::loadedShaders.erase(it);
            shaders::shaderPaths.erase(oldShader);
        }
    }

    // Cleanup remaining
    for (auto& [name, shader] : shaders::loadedShaders)
    {
        shaders::GetShaderApiHooks().unload_shader(shader);
    }
    shaders::loadedShaders.clear();

    SUCCEED();
}

// =============================================================================
// String Safety Tests
// =============================================================================

TEST(StringSafetyTest, UniformNameBoundaryConditions)
{
    shaders::ShaderUniformSet set;

    // Test boundary conditions for string keys
    std::vector<std::string> testNames = {
        "",                          // Empty
        "a",                         // Single char
        std::string(1, '\0'),        // Null char (edge case)
        "normal_name",               // Normal
        std::string(255, 'x'),       // At typical buffer boundary
        std::string(256, 'y'),       // Just past boundary
        std::string(1024, 'z'),      // Larger
    };

    for (const auto& name : testNames)
    {
        set.set(name, 1.0f);
        auto* val = set.get(name);
        ASSERT_NE(val, nullptr) << "Failed for name length: " << name.length();
        EXPECT_FLOAT_EQ(std::get<float>(*val), 1.0f);
    }
}

// =============================================================================
// Component/Registry Safety Tests (mock-based)
// =============================================================================

// These tests verify that common component access patterns don't cause memory issues

struct MockComponent
{
    int value = 0;
    std::string name;
    std::vector<float> data;
};

TEST(ComponentMemorySafetyTest, ComponentValueCopySemantics)
{
    MockComponent original;
    original.value = 42;
    original.name = "test";
    original.data = {1.0f, 2.0f, 3.0f};

    // Copy construction
    MockComponent copy1 = original;
    EXPECT_EQ(copy1.value, 42);
    EXPECT_EQ(copy1.name, "test");
    EXPECT_EQ(copy1.data.size(), 3u);

    // Modify copy shouldn't affect original
    copy1.value = 100;
    copy1.name = "modified";
    copy1.data.push_back(4.0f);

    EXPECT_EQ(original.value, 42);
    EXPECT_EQ(original.name, "test");
    EXPECT_EQ(original.data.size(), 3u);

    // Move semantics
    MockComponent moved = std::move(copy1);
    EXPECT_EQ(moved.value, 100);
    EXPECT_EQ(moved.name, "modified");
    EXPECT_EQ(moved.data.size(), 4u);
}

TEST(ComponentMemorySafetyTest, ComponentVectorOperations)
{
    std::vector<MockComponent> components;
    components.reserve(100);

    // Add components
    for (int i = 0; i < 100; i++)
    {
        MockComponent c;
        c.value = i;
        c.name = "component_" + std::to_string(i);
        c.data.resize(i % 10);
        components.push_back(std::move(c));
    }

    // Access and modify
    for (size_t i = 0; i < components.size(); i++)
    {
        EXPECT_EQ(components[i].value, static_cast<int>(i));
        components[i].value *= 2;
    }

    // Remove some (simulates entity destruction)
    components.erase(
        std::remove_if(components.begin(), components.end(),
            [](const MockComponent& c) { return c.value % 20 == 0; }),
        components.end()
    );

    // Verify remaining
    for (const auto& c : components)
    {
        EXPECT_NE(c.value % 20, 0);
    }
}

TEST(ComponentMemorySafetyTest, SmartPointerOwnership)
{
    // Test unique_ptr ownership transfer patterns
    std::vector<std::unique_ptr<MockComponent>> ownedComponents;

    for (int i = 0; i < 50; i++)
    {
        auto comp = std::make_unique<MockComponent>();
        comp->value = i;
        comp->name = "owned_" + std::to_string(i);
        ownedComponents.push_back(std::move(comp));
    }

    // Transfer ownership
    std::vector<std::unique_ptr<MockComponent>> newOwner;
    for (auto& comp : ownedComponents)
    {
        if (comp && comp->value % 2 == 0)
        {
            newOwner.push_back(std::move(comp));
        }
    }

    // Original pointers should be null after move
    for (size_t i = 0; i < ownedComponents.size(); i++)
    {
        if (static_cast<int>(i) % 2 == 0)
        {
            EXPECT_EQ(ownedComponents[i], nullptr);
        }
        else
        {
            EXPECT_NE(ownedComponents[i], nullptr);
        }
    }

    // New owner should have the components
    for (const auto& comp : newOwner)
    {
        ASSERT_NE(comp, nullptr);
        EXPECT_EQ(comp->value % 2, 0);
    }
}

// =============================================================================
// Edge Case Memory Tests
// =============================================================================

TEST(EdgeCaseMemoryTest, EmptyContainerOperations)
{
    // Operations on empty containers should be safe
    shaders::ShaderUniformSet emptySet;

    EXPECT_EQ(emptySet.get("nonexistent"), nullptr);

    Shader shader{};
    shader.id = 1;

    // Should not crash on empty set
    shaders::ApplyUniformsToShader(shader, emptySet);

    std::unordered_map<std::string, Shader> emptyShaderMap;
    EXPECT_TRUE(emptyShaderMap.empty());
    EXPECT_EQ(emptyShaderMap.find("test"), emptyShaderMap.end());

    SUCCEED();
}

TEST(EdgeCaseMemoryTest, SelfAssignment)
{
    MockComponent comp;
    comp.value = 42;
    comp.name = "test";
    comp.data = {1.0f, 2.0f};

    // Self-assignment should be safe
    #pragma GCC diagnostic push
    #pragma GCC diagnostic ignored "-Wself-assign-overloaded"
    comp = comp;
    #pragma GCC diagnostic pop

    EXPECT_EQ(comp.value, 42);
    EXPECT_EQ(comp.name, "test");
    EXPECT_EQ(comp.data.size(), 2u);
}

TEST(EdgeCaseMemoryTest, LargeAllocation)
{
    // Test large allocations that might stress the allocator
    shaders::ShaderUniformSet set;

    // Large vector values (simulating large data in uniforms)
    std::vector<float> largeData(10000);
    std::iota(largeData.begin(), largeData.end(), 0.0f);

    // Store many large strings
    for (int i = 0; i < 100; i++)
    {
        std::string largeName(1000 + i, 'a' + (i % 26));
        set.set(largeName, static_cast<float>(i));
    }

    SUCCEED();
}
