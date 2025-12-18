#include <gtest/gtest.h>

#include <filesystem>
#include <fstream>
#include <string>
#include <vector>
#include <optional>
#include <functional>
#include <unordered_set>
#include <sstream>
#include <nlohmann/json.hpp>

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

    std::filesystem::path ShaderAssetsRoot()
    {
        return std::filesystem::path(ASSETS_PATH) / "shaders";
    }

    std::filesystem::path ShaderManifestPath()
    {
        return ShaderAssetsRoot() / "shaders.json";
    }

    nlohmann::json LoadShaderManifest()
    {
        std::ifstream manifestFile(ShaderManifestPath());
        EXPECT_TRUE(manifestFile.is_open()) << "Failed to open shader manifest at " << ShaderManifestPath().string();
        if (!manifestFile.is_open())
        {
            return {};
        }

        nlohmann::json manifest;
        manifestFile >> manifest;
        return manifest;
    }
} // namespace

namespace game {
    std::function<void()> OnUIScaleChanged = []() {};
    double g_lastGcPauseMs = 0.0;
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
    void TextColored(const ImVec4&, const char*, ...) { ImGuiCallTracker::contentCalls++; }
    void Indent(float) { ImGuiCallTracker::contentCalls++; }
    void Unindent(float) { ImGuiCallTracker::contentCalls++; }
    void Image(void*, const ImVec2&, const ImVec2&, const ImVec2&, const ImVec4&, const ImVec4&) { ImGuiCallTracker::contentCalls++; }
    void MemFree(void*) {}
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

TEST(ShaderManifest, DesktopAndWebShaderFilesExistAndAreNonEmpty)
{
    const auto manifest = LoadShaderManifest();
    const auto shadersRoot = ShaderAssetsRoot();

    std::vector<std::string> missing;

    auto checkPath = [&](const std::string &shaderName, const std::string &label, const std::string &relativePath)
    {
        if (relativePath.empty())
        {
            std::ostringstream oss;
            oss << shaderName << " " << label << " path is empty";
            missing.push_back(oss.str());
            return;
        }

        const auto fullPath = shadersRoot / relativePath;
        std::error_code ec;
        const auto exists = std::filesystem::exists(fullPath, ec);
        const auto isFile = std::filesystem::is_regular_file(fullPath, ec);

        if (!exists || !isFile)
        {
            std::ostringstream oss;
            oss << shaderName << " " << label << " missing at " << fullPath.string();
            missing.push_back(oss.str());
            return;
        }

        const auto size = std::filesystem::file_size(fullPath, ec);
        if (ec || size == 0)
        {
            std::ostringstream oss;
            oss << shaderName << " " << label << " is empty at " << fullPath.string();
            missing.push_back(oss.str());
        }
    };

    for (const auto &[name, entry] : manifest.items())
    {
        checkPath(name, "vertex", entry.value("vertex", ""));
        checkPath(name, "fragment", entry.value("fragment", ""));

        if (entry.contains("web"))
        {
            const auto &web = entry["web"];
            checkPath(name, "web vertex", web.value("vertex", ""));
            checkPath(name, "web fragment", web.value("fragment", ""));
        }
    }

    if (!missing.empty())
    {
        std::ostringstream oss;
        for (size_t i = 0; i < missing.size(); ++i)
        {
            if (i > 0)
            {
                oss << "; ";
            }
            oss << missing[i];
        }
        ADD_FAILURE() << oss.str();
    }

    EXPECT_TRUE(missing.empty());
}

TEST_F(ShaderSystemTest, LoadsAllDesktopShadersFromManifest)
{
    const auto manifest = LoadShaderManifest();
    shaders::loadShadersFromJSON("shaders/shaders.json");

    EXPECT_EQ(ShaderStubStats::loadCount, static_cast<int>(manifest.size()));
    EXPECT_EQ(shaders::loadedShaders.size(), manifest.size());

    for (const auto &[shaderName, paths] : shaders::shaderPaths)
    {
        if (!paths.first.empty())
        {
            EXPECT_TRUE(std::filesystem::exists(paths.first)) << "Missing vertex shader for " << shaderName;
        }
        if (!paths.second.empty())
        {
            EXPECT_TRUE(std::filesystem::exists(paths.second)) << "Missing fragment shader for " << shaderName;
        }
    }
}

TEST_F(ShaderSystemTest, WebShaderVariantsCompileWithStubbedLoader)
{
    const auto manifest = LoadShaderManifest();
    const auto shadersRoot = ShaderAssetsRoot();

    for (const auto &[name, entry] : manifest.items())
    {
        ASSERT_TRUE(entry.contains("web")) << "Manifest missing web variant for " << name;
        const auto &web = entry.at("web");
        const auto vertexPath = shadersRoot / web.value("vertex", "");
        const auto fragmentPath = shadersRoot / web.value("fragment", "");

        ASSERT_TRUE(std::filesystem::exists(vertexPath)) << "Web vertex missing for " << name;
        ASSERT_TRUE(std::filesystem::exists(fragmentPath)) << "Web fragment missing for " << name;

        const auto shader = shaders::GetShaderApiHooks().load_shader(
            vertexPath.string().c_str(),
            fragmentPath.string().c_str());

        EXPECT_NE(shader.id, 0u) << "Stubbed compile failed for web shader " << name;
    }

    EXPECT_EQ(ShaderStubStats::loadCount, static_cast<int>(manifest.size()));
}

TEST_F(ShaderSystemTest, MissingUniformsAreSkipped) {
    ShaderStubStats::missingUniforms.insert("missing_uniform");

    shaders::ShaderUniformSet set{};
    set.set("missing_uniform", 1.0f);

    Shader shader{};
    shaders::ApplyUniformsToShader(shader, set);

    EXPECT_EQ(ShaderStubStats::setValueCount, 0);
    EXPECT_EQ(ShaderStubStats::setTextureCount, 0);
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

// Lazy loading tests
TEST_F(ShaderSystemTest, LazyLoadingStoresMetadataOnly)
{
    shaders::enableLazyShaderLoading = true;
    shaders::loadedShaders.clear();
    shaders::shaderMetadata.clear();

    // Directly add metadata (simulating what loadShadersFromJSON does when lazy loading is enabled)
    shaders::shaderMetadata["test_shader"] = {
        "shaders/basic.vert",
        "shaders/basic.frag",
        false
    };

    // Metadata should be stored
    EXPECT_EQ(shaders::shaderMetadata.size(), 1u);
    EXPECT_TRUE(shaders::shaderMetadata.contains("test_shader"));
    EXPECT_FALSE(shaders::shaderMetadata["test_shader"].compiled);

    // No shaders should be compiled yet
    EXPECT_EQ(shaders::loadedShaders.size(), 0u);
    EXPECT_EQ(ShaderStubStats::loadCount, 0);

    // Cleanup
    shaders::enableLazyShaderLoading = false;
}

TEST_F(ShaderSystemTest, LazyLoadingCompilesOnFirstAccess)
{
    shaders::enableLazyShaderLoading = true;
    shaders::loadedShaders.clear();
    shaders::shaderMetadata.clear();

    // Create test shader files
    auto vertexPath = makeTempFile("lazy_load_test.vert", "// vertex shader");
    auto fragmentPath = makeTempFile("lazy_load_test.frag", "// fragment shader");

    // Manually add metadata (simulating what loadShadersFromJSON does)
    shaders::shaderMetadata["lazy_test"] = {
        vertexPath.string(),
        fragmentPath.string(),
        false
    };

    // First access should trigger compilation
    auto shader = shaders::getShader("lazy_test");

    // Shader should be compiled
    EXPECT_NE(shader.id, 0u);
    EXPECT_EQ(ShaderStubStats::loadCount, 1);
    EXPECT_EQ(shaders::loadedShaders.size(), 1u);
    EXPECT_TRUE(shaders::shaderMetadata["lazy_test"].compiled);

    // Second access should return cached shader (no additional compilation)
    ShaderStubStats::loadCount = 0;
    auto shader2 = shaders::getShader("lazy_test");
    EXPECT_EQ(shader.id, shader2.id);
    EXPECT_EQ(ShaderStubStats::loadCount, 0);

    // Cleanup
    shaders::enableLazyShaderLoading = false;
}

TEST_F(ShaderSystemTest, UnloadShadersReleasesMetadata)
{
    shaders::shaderMetadata.clear();
    shaders::loadedShaders.clear();

    // Add test metadata
    shaders::shaderMetadata["test_shader"] = {
        "vertex.vert",
        "fragment.frag",
        true
    };
    shaders::loadedShaders["test_shader"] = Shader{.id = 1};

    EXPECT_EQ(shaders::shaderMetadata.size(), 1u);
    EXPECT_EQ(shaders::loadedShaders.size(), 1u);

    // Unload shaders
    shaders::unloadShaders();

    // Metadata should be cleared
    EXPECT_EQ(shaders::shaderMetadata.size(), 0u);
    EXPECT_EQ(shaders::loadedShaders.size(), 0u);
}
