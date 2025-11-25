#include <gtest/gtest.h>

#include <filesystem>
#include <fstream>
#include <string>
#include <vector>
#include <optional>
#include <functional>
#include <unordered_set>

#include "core/misc_fuctions.hpp"
#include "systems/shaders/shader_system.hpp"

namespace
{
    struct ShaderStubStats
    {
        static void Reset()
        {
            loadCount = 0;
            unloadCount = 0;
            setValueCount = 0;
            setTextureCount = 0;
            lastUniformName.clear();
            lastVertexPath.clear();
            lastFragmentPath.clear();
            nextShaderId = 10;
            missingUniforms.clear();
        }

        inline static int loadCount = 0;
        inline static int unloadCount = 0;
        inline static int setValueCount = 0;
        inline static int setTextureCount = 0;
        inline static std::string lastUniformName;
        inline static std::string lastVertexPath;
        inline static std::string lastFragmentPath;
        inline static unsigned int nextShaderId = 10;
        inline static std::unordered_set<std::string> missingUniforms;
    };

    struct ImGuiCallTracker
    {
        static void Reset()
        {
            beginCalls = 0;
            endCalls = 0;
            contentCalls = 0;
        }

        inline static int beginCalls = 0;
        inline static int endCalls = 0;
        inline static int contentCalls = 0;
    };

    inline bool gImGuiBeginReturn = true;

    inline void ResetImGuiStubs()
    {
        ImGuiCallTracker::Reset();
        gImGuiBeginReturn = true;
    }

    long fileWriteTime(const std::filesystem::path &p)
    {
        return static_cast<long>(std::filesystem::last_write_time(p).time_since_epoch().count());
    }

    std::filesystem::path makeTempFile(const std::string &name, const std::string &contents)
    {
        auto path = std::filesystem::temp_directory_path() / name;
        std::ofstream out(path);
        out << contents;
        return path;
    }
} // namespace

namespace game {
    std::function<void()> OnUIScaleChanged = []() {};
}

// Stub shader operations with external linkage so the implementation resolves to them.
Shader TestLoadShader(const char *vertexPath, const char *fragmentPath)
{
    ShaderStubStats::loadCount++;
    ShaderStubStats::lastVertexPath = vertexPath ? vertexPath : "";
    ShaderStubStats::lastFragmentPath = fragmentPath ? fragmentPath : "";
    Shader shader{};
    shader.id = ShaderStubStats::nextShaderId++;
    return shader;
}

void TestUnloadShader(Shader)
{
    ShaderStubStats::unloadCount++;
}

int TestGetShaderLocation(Shader, const char *name)
{
    if (name && ShaderStubStats::missingUniforms.count(name)) {
        return -1;
    }
    ShaderStubStats::lastUniformName = name ? name : "";
    return 0;
}

void TestSetShaderValue(Shader, int, const void *, int)
{
    ShaderStubStats::setValueCount++;
}

void TestSetShaderValueTexture(Shader, int, Texture2D)
{
    ShaderStubStats::setTextureCount++;
}

unsigned int TestRlGetShaderIdDefault()
{
    return 0;
}

void TestBeginShaderMode(Shader) {}
void TestEndShaderMode() {}

void InstallShaderTestHooks()
{
    shaders::SetShaderApiHooks({
        TestLoadShader,
        TestUnloadShader,
        TestGetShaderLocation,
        TestSetShaderValue,
        TestSetShaderValueTexture,
        TestBeginShaderMode,
        TestEndShaderMode,
        TestRlGetShaderIdDefault});
}

struct ShaderSystemTest : ::testing::Test
{
    void SetUp() override
    {
        ShaderStubStats::Reset();
        InstallShaderTestHooks();
    }

    void TearDown() override
    {
        shaders::ResetShaderApiHooks();
        shaders::loadedShaders.clear();
        shaders::shaderPaths.clear();
        shaders::shaderFileModificationTimes.clear();
    }
};

// ImGui UI helpers used by ShowShaderEditorUI; provide no-op stubs.
namespace ImGui
{
    bool Begin(const char *, bool *, ImGuiWindowFlags, std::optional<std::function<void()>>)
    {
        ImGuiCallTracker::beginCalls++;
        return gImGuiBeginReturn;
    }
    void End() { ImGuiCallTracker::endCalls++; }
    bool BeginTabBar(const char *, ImGuiTabBarFlags) { ImGuiCallTracker::contentCalls++; return true; }
    void EndTabBar() {}
    bool BeginTabItem(const char *, bool *, ImGuiTabItemFlags) { ImGuiCallTracker::contentCalls++; return true; }
    void EndTabItem() {}
    bool Button(const char *, const ImVec2 &) { ImGuiCallTracker::contentCalls++; return false; }
    void Separator() { ImGuiCallTracker::contentCalls++; }
    void PushID(const char *) {}
    void PopID() {}
    bool DragFloat(const char *, float *, float, float, float, const char *, ImGuiSliderFlags) { ImGuiCallTracker::contentCalls++; return false; }
    bool DragFloat2(const char *, float *, float, float, float, const char *, ImGuiSliderFlags) { ImGuiCallTracker::contentCalls++; return false; }
    bool DragFloat3(const char *, float *, float, float, float, const char *, ImGuiSliderFlags) { ImGuiCallTracker::contentCalls++; return false; }
    bool DragInt(const char *, int *, float, int, int, const char *, ImGuiSliderFlags) { ImGuiCallTracker::contentCalls++; return false; }
    bool ColorEdit4(const char *, float *, ImGuiColorEditFlags) { ImGuiCallTracker::contentCalls++; return false; }
    bool Checkbox(const char *, bool *) { ImGuiCallTracker::contentCalls++; return false; }
    bool BeginCombo(const char *, const char *, ImGuiComboFlags) { ImGuiCallTracker::contentCalls++; return false; }
    bool Selectable(const char *, bool, ImGuiSelectableFlags, const ImVec2 &) { ImGuiCallTracker::contentCalls++; return false; }
    void SetItemDefaultFocus() {}
    void EndCombo() {}
    void ProgressBar(float, const ImVec2 &, const char *) { ImGuiCallTracker::contentCalls++; }
    void Text(const char *, ...) { ImGuiCallTracker::contentCalls++; }
} // namespace ImGui

TEST_F(ShaderSystemTest, ShaderUniformSetStoresAndRetrievesUniforms)
{
    shaders::ShaderUniformSet set;

    set.set("uValue", 3.5f);
    set.set("uVector", Vector2{1.0f, 2.0f});

    const auto *value = set.get("uValue");
    ASSERT_NE(value, nullptr);
    EXPECT_FLOAT_EQ(std::get<float>(*value), 3.5f);

    const auto *vec = set.get("uVector");
    ASSERT_NE(vec, nullptr);
    auto v2 = std::get<Vector2>(*vec);
    EXPECT_FLOAT_EQ(v2.x, 1.0f);
    EXPECT_FLOAT_EQ(v2.y, 2.0f);

    EXPECT_EQ(set.get("missingUniform"), nullptr);
}

TEST_F(ShaderSystemTest, ApplyUniformsInvokesSetters)
{
    shaders::ShaderUniformSet set;
    set.set("uValue", 5.0f);

    Shader shader{};
    shader.id = 1;
    shaders::ApplyUniformsToShader(shader, set);

    EXPECT_EQ(ShaderStubStats::setValueCount, 1);
    EXPECT_EQ(ShaderStubStats::lastUniformName, "uValue");
}

TEST_F(ShaderSystemTest, ApplyUniformsSkipsMissingLocationsButKeepsOthers)
{
    shaders::ShaderUniformSet set;
    set.set("uMissing", 1.0f);
    set.set("uPresent", Vector2{2.0f, 3.0f});

    ShaderStubStats::missingUniforms.insert("uMissing");

    Shader shader{};
    shader.id = 2;
    shaders::ApplyUniformsToShader(shader, set);

    // Only the present uniform should be applied.
    EXPECT_EQ(ShaderStubStats::setValueCount, 1);
    EXPECT_EQ(ShaderStubStats::lastUniformName, "uPresent");
}

TEST_F(ShaderSystemTest, HotReloadsWhenTimestampChanges)
{
    shaders::shaderPaths.clear();
    shaders::shaderFileModificationTimes.clear();
    shaders::loadedShaders.clear();

    auto vertexPath = makeTempFile("hot_reload_vert.glsl", "// vertex");
    auto fragmentPath = makeTempFile("hot_reload_frag.glsl", "// fragment");

    shaders::loadedShaders["basic"] = Shader{.id = 1};
    shaders::shaderPaths["basic"] = {vertexPath.string(), fragmentPath.string()};
    shaders::shaderFileModificationTimes["basic"] = {0, 0};

    shaders::hotReloadShaders();

    EXPECT_EQ(ShaderStubStats::loadCount, 1);
    EXPECT_EQ(ShaderStubStats::unloadCount, 1);
    EXPECT_EQ(shaders::loadedShaders["basic"].id, 10u); // first assigned id after reset

    const auto expectedTimes = std::pair<long, long>{fileWriteTime(vertexPath), fileWriteTime(fragmentPath)};
    EXPECT_EQ(shaders::shaderFileModificationTimes["basic"], expectedTimes);
}

TEST_F(ShaderSystemTest, SkipsReloadWhenUnchanged)
{
    shaders::shaderPaths.clear();
    shaders::shaderFileModificationTimes.clear();
    shaders::loadedShaders.clear();

    auto vertexPath = makeTempFile("hot_reload_vert_same.glsl", "// vertex");
    auto fragmentPath = makeTempFile("hot_reload_frag_same.glsl", "// fragment");
    auto vt = fileWriteTime(vertexPath);
    auto ft = fileWriteTime(fragmentPath);

    shaders::loadedShaders["basic"] = Shader{.id = 2};
    shaders::shaderPaths["basic"] = {vertexPath.string(), fragmentPath.string()};
    shaders::shaderFileModificationTimes["basic"] = {vt, ft};

    shaders::hotReloadShaders();

    EXPECT_EQ(ShaderStubStats::loadCount, 0);
    EXPECT_EQ(ShaderStubStats::unloadCount, 0);
    EXPECT_EQ(shaders::loadedShaders["basic"].id, 2u);
}

TEST(DebugUIImGui, CallsEndWhenWindowCollapsed)
{
    ResetImGuiStubs();
    gImGuiBeginReturn = false; // Simulate a collapsed/hidden window

    game::ShowDebugUI();

    EXPECT_EQ(ImGuiCallTracker::beginCalls, 1);
    EXPECT_EQ(ImGuiCallTracker::endCalls, 1);
    EXPECT_EQ(ImGuiCallTracker::contentCalls, 0);
}
