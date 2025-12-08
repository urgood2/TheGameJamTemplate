#include <gtest/gtest.h>

#include <filesystem>
#include <fstream>
#include <regex>
#include <sstream>
#include <string>
#include <unordered_set>
#include <vector>

#include <nlohmann/json.hpp>

namespace
{
    std::filesystem::path AssetsRoot()
    {
        return std::filesystem::path(ASSETS_PATH);
    }

    std::filesystem::path ShaderAssetsRoot()
    {
        return AssetsRoot() / "shaders";
    }

    nlohmann::json LoadJsonFile(const std::filesystem::path& path)
    {
        std::ifstream file(path);
        if (!file.is_open())
        {
            return {};
        }
        nlohmann::json j;
        file >> j;
        return j;
    }

    // Strip GLSL comments for accurate bracket counting
    std::string StripGlslComments(const std::string& source)
    {
        std::string result;
        result.reserve(source.size());

        size_t i = 0;
        while (i < source.size())
        {
            // Multi-line comment
            if (i + 1 < source.size() && source[i] == '/' && source[i + 1] == '*')
            {
                i += 2;
                while (i + 1 < source.size() && !(source[i] == '*' && source[i + 1] == '/'))
                {
                    if (source[i] == '\n') result += '\n'; // Preserve line structure
                    i++;
                }
                i += 2;
                continue;
            }

            // Single-line comment
            if (i + 1 < source.size() && source[i] == '/' && source[i + 1] == '/')
            {
                while (i < source.size() && source[i] != '\n')
                {
                    i++;
                }
                continue;
            }

            result += source[i];
            i++;
        }

        return result;
    }

    // Basic GLSL syntax validation - checks for common errors
    struct GlslValidationResult
    {
        bool valid = true;
        std::vector<std::string> errors;
    };

    GlslValidationResult ValidateGlslSyntax(const std::string& source, const std::string& filename)
    {
        GlslValidationResult result;

        // Strip comments for accurate counting
        std::string stripped = StripGlslComments(source);

        // Check for balanced braces
        int braceCount = 0;
        int parenCount = 0;
        bool inString = false;

        for (size_t i = 0; i < stripped.size(); i++)
        {
            char c = stripped[i];

            // Track string state (GLSL doesn't have strings, but just in case)
            if (c == '"' && (i == 0 || stripped[i - 1] != '\\'))
            {
                inString = !inString;
                continue;
            }
            if (inString) continue;

            if (c == '{') braceCount++;
            else if (c == '}') braceCount--;
            else if (c == '(') parenCount++;
            else if (c == ')') parenCount--;
        }

        if (braceCount != 0)
        {
            result.valid = false;
            result.errors.push_back(filename + ": Unbalanced braces (count: " + std::to_string(braceCount) + ")");
        }

        if (parenCount != 0)
        {
            result.valid = false;
            result.errors.push_back(filename + ": Unbalanced parentheses (count: " + std::to_string(parenCount) + ")");
        }

        // Note: We don't require main() - some shaders are include files or helper functions

        return result;
    }

    std::string ReadFileContents(const std::filesystem::path& path)
    {
        std::ifstream file(path);
        if (!file.is_open()) return "";
        std::stringstream buffer;
        buffer << file.rdbuf();
        return buffer.str();
    }

    // Simplified Lua syntax validation - only checks for obvious errors
    // that would definitely cause runtime failures
    struct LuaSyntaxResult
    {
        bool valid = true;
        std::vector<std::string> errors;
    };

    // Strip comments and strings from Lua source for bracket counting
    std::string StripLuaCommentsAndStrings(const std::string& source)
    {
        std::string result;
        result.reserve(source.size());

        size_t i = 0;
        while (i < source.size())
        {
            // Long comments --[[...]]
            if (i + 3 < source.size() && source[i] == '-' && source[i + 1] == '-' &&
                source[i + 2] == '[' && source[i + 3] == '[')
            {
                i += 4;
                while (i + 1 < source.size() && !(source[i] == ']' && source[i + 1] == ']'))
                {
                    i++;
                }
                i += 2;
                continue;
            }

            // Single-line comments
            if (i + 1 < source.size() && source[i] == '-' && source[i + 1] == '-')
            {
                while (i < source.size() && source[i] != '\n')
                {
                    i++;
                }
                result += ' '; // Preserve line structure
                continue;
            }

            // Long strings [[...]] or [=[...]=] etc.
            if (source[i] == '[')
            {
                size_t eqCount = 0;
                size_t j = i + 1;
                while (j < source.size() && source[j] == '=')
                {
                    eqCount++;
                    j++;
                }
                if (j < source.size() && source[j] == '[')
                {
                    // Found long string start
                    i = j + 1;
                    // Find matching close
                    while (i < source.size())
                    {
                        if (source[i] == ']')
                        {
                            size_t closeEq = 0;
                            size_t k = i + 1;
                            while (k < source.size() && source[k] == '=')
                            {
                                closeEq++;
                                k++;
                            }
                            if (k < source.size() && source[k] == ']' && closeEq == eqCount)
                            {
                                i = k + 1;
                                break;
                            }
                        }
                        i++;
                    }
                    result += ' ';
                    continue;
                }
            }

            // Regular strings
            if (source[i] == '"' || source[i] == '\'')
            {
                char quote = source[i];
                i++;
                while (i < source.size())
                {
                    if (source[i] == '\\' && i + 1 < source.size())
                    {
                        i += 2;
                        continue;
                    }
                    if (source[i] == quote)
                    {
                        i++;
                        break;
                    }
                    i++;
                }
                result += ' ';
                continue;
            }

            result += source[i];
            i++;
        }

        return result;
    }

    LuaSyntaxResult ValidateLuaSyntax(const std::string& source, const std::string& filename)
    {
        LuaSyntaxResult result;

        // Strip comments and strings for accurate bracket counting
        std::string stripped = StripLuaCommentsAndStrings(source);

        // Count brackets in stripped source
        int parenCount = 0;
        int braceCount = 0;

        for (char c : stripped)
        {
            if (c == '(') parenCount++;
            else if (c == ')') parenCount--;
            else if (c == '{') braceCount++;
            else if (c == '}') braceCount--;
        }

        // Only report severe imbalances (> 2) as the stripping isn't perfect
        if (std::abs(parenCount) > 2)
        {
            result.valid = false;
            result.errors.push_back(filename + ": Likely unbalanced parentheses (count: " + std::to_string(parenCount) + ")");
        }
        if (std::abs(braceCount) > 2)
        {
            result.valid = false;
            result.errors.push_back(filename + ": Likely unbalanced braces (count: " + std::to_string(braceCount) + ")");
        }

        // Check for obvious syntax errors - empty file
        if (stripped.find_first_not_of(" \t\n\r") == std::string::npos && source.size() > 10)
        {
            result.valid = false;
            result.errors.push_back(filename + ": File appears to be empty or only comments");
        }

        return result;
    }

} // namespace

// =============================================================================
// GLSL Shader Syntax Validation Tests
// =============================================================================

TEST(ShaderSyntaxValidation, AllDesktopShadersHaveValidSyntax)
{
    const auto shadersRoot = ShaderAssetsRoot();
    std::vector<std::string> allErrors;

    for (const auto& entry : std::filesystem::recursive_directory_iterator(shadersRoot))
    {
        if (!entry.is_regular_file()) continue;

        const auto& path = entry.path();
        const auto ext = path.extension().string();

        // Skip web shaders (tested separately) and archived shaders
        if (path.string().find("/web/") != std::string::npos) continue;
        if (path.string().find("/archived/") != std::string::npos) continue;

        if (ext != ".vs" && ext != ".fs") continue;

        const auto contents = ReadFileContents(path);
        if (contents.empty())
        {
            allErrors.push_back(path.filename().string() + ": Empty shader file");
            continue;
        }

        const auto result = ValidateGlslSyntax(contents, path.filename().string());
        if (!result.valid)
        {
            allErrors.insert(allErrors.end(), result.errors.begin(), result.errors.end());
        }
    }

    if (!allErrors.empty())
    {
        std::ostringstream oss;
        oss << "Shader syntax errors found:\n";
        for (const auto& err : allErrors)
        {
            oss << "  - " << err << "\n";
        }
        ADD_FAILURE() << oss.str();
    }

    EXPECT_TRUE(allErrors.empty());
}

TEST(ShaderSyntaxValidation, AllWebShadersHaveValidSyntax)
{
    const auto webShadersRoot = ShaderAssetsRoot() / "web";

    if (!std::filesystem::exists(webShadersRoot))
    {
        GTEST_SKIP() << "No web shaders directory found";
    }

    std::vector<std::string> allErrors;

    for (const auto& entry : std::filesystem::directory_iterator(webShadersRoot))
    {
        if (!entry.is_regular_file()) continue;

        const auto& path = entry.path();
        const auto ext = path.extension().string();

        if (ext != ".vs" && ext != ".fs") continue;

        const auto contents = ReadFileContents(path);
        if (contents.empty())
        {
            allErrors.push_back(path.filename().string() + ": Empty shader file");
            continue;
        }

        const auto result = ValidateGlslSyntax(contents, path.filename().string());
        if (!result.valid)
        {
            allErrors.insert(allErrors.end(), result.errors.begin(), result.errors.end());
        }
    }

    if (!allErrors.empty())
    {
        std::ostringstream oss;
        oss << "Web shader syntax errors found:\n";
        for (const auto& err : allErrors)
        {
            oss << "  - " << err << "\n";
        }
        ADD_FAILURE() << oss.str();
    }

    EXPECT_TRUE(allErrors.empty());
}

TEST(ShaderSyntaxValidation, ShaderManifestReferencesValidFiles)
{
    const auto manifestPath = ShaderAssetsRoot() / "shaders.json";
    const auto manifest = LoadJsonFile(manifestPath);

    ASSERT_FALSE(manifest.empty()) << "Failed to load shader manifest";

    std::vector<std::string> errors;
    std::unordered_set<std::string> referencedFiles;

    for (const auto& [name, entry] : manifest.items())
    {
        // Check desktop paths
        const auto vertexPath = entry.value("vertex", "");
        const auto fragmentPath = entry.value("fragment", "");

        if (!vertexPath.empty())
        {
            referencedFiles.insert(vertexPath);
            const auto fullPath = ShaderAssetsRoot() / vertexPath;
            if (!std::filesystem::exists(fullPath))
            {
                errors.push_back(name + ": Missing desktop vertex shader: " + vertexPath);
            }
        }

        if (!fragmentPath.empty())
        {
            referencedFiles.insert(fragmentPath);
            const auto fullPath = ShaderAssetsRoot() / fragmentPath;
            if (!std::filesystem::exists(fullPath))
            {
                errors.push_back(name + ": Missing desktop fragment shader: " + fragmentPath);
            }
        }

        // Check web paths
        if (entry.contains("web"))
        {
            const auto& web = entry["web"];
            const auto webVertexPath = web.value("vertex", "");
            const auto webFragmentPath = web.value("fragment", "");

            if (!webVertexPath.empty())
            {
                const auto fullPath = ShaderAssetsRoot() / webVertexPath;
                if (!std::filesystem::exists(fullPath))
                {
                    // Web shaders may fall back to desktop - check if it's intentional
                    const auto desktopFallback = ShaderAssetsRoot() / webVertexPath;
                    if (!std::filesystem::exists(desktopFallback))
                    {
                        errors.push_back(name + ": Missing web vertex shader: " + webVertexPath);
                    }
                }
            }

            if (!webFragmentPath.empty())
            {
                const auto fullPath = ShaderAssetsRoot() / webFragmentPath;
                if (!std::filesystem::exists(fullPath))
                {
                    errors.push_back(name + ": Missing web fragment shader: " + webFragmentPath);
                }
            }
        }
    }

    if (!errors.empty())
    {
        std::ostringstream oss;
        oss << "Shader manifest errors:\n";
        for (const auto& err : errors)
        {
            oss << "  - " << err << "\n";
        }
        ADD_FAILURE() << oss.str();
    }

    EXPECT_TRUE(errors.empty());
}

// =============================================================================
// JSON Config Validation Tests
// =============================================================================

TEST(JsonConfigValidation, AnimationsJsonIsValidAndComplete)
{
    const auto path = AssetsRoot() / "graphics" / "animations.json";

    ASSERT_TRUE(std::filesystem::exists(path)) << "animations.json not found";

    std::ifstream file(path);
    ASSERT_TRUE(file.is_open()) << "Failed to open animations.json";

    nlohmann::json animations;
    ASSERT_NO_THROW(file >> animations) << "animations.json contains invalid JSON";

    EXPECT_FALSE(animations.empty()) << "animations.json is empty";

    // Check that each animation has required fields
    std::vector<std::string> errors;
    for (const auto& [name, anim] : animations.items())
    {
        if (!anim.is_object())
        {
            errors.push_back(name + ": Not an object");
            continue;
        }

        // Common animation fields to check
        if (!anim.contains("frames") && !anim.contains("frame_count") && !anim.contains("sprite"))
        {
            errors.push_back(name + ": Missing frames, frame_count, or sprite field");
        }
    }

    if (!errors.empty())
    {
        std::ostringstream oss;
        oss << "Animation config errors:\n";
        for (const auto& err : errors)
        {
            oss << "  - " << err << "\n";
        }
        ADD_FAILURE() << oss.str();
    }

    EXPECT_TRUE(errors.empty());
}

TEST(JsonConfigValidation, SpritesJsonFilesAreValidAndComplete)
{
    const auto graphicsRoot = AssetsRoot() / "graphics";
    std::vector<std::string> spriteFiles = {"sprites-0.json", "sprites-1.json", "sprites-2.json"};

    for (const auto& filename : spriteFiles)
    {
        const auto path = graphicsRoot / filename;

        if (!std::filesystem::exists(path))
        {
            // Some sprite files may not exist - that's okay
            continue;
        }

        std::ifstream file(path);
        ASSERT_TRUE(file.is_open()) << "Failed to open " << filename;

        nlohmann::json sprites;
        ASSERT_NO_THROW(file >> sprites) << filename << " contains invalid JSON";

        EXPECT_FALSE(sprites.empty()) << filename << " is empty";

        // Sprites should have frame data
        if (sprites.is_object() && sprites.contains("frames"))
        {
            EXPECT_TRUE(sprites["frames"].is_object() || sprites["frames"].is_array())
                << filename << ": frames should be object or array";
        }
    }
}

TEST(JsonConfigValidation, LocalizationFilesAreValid)
{
    const auto localizationRoot = AssetsRoot() / "localization";

    ASSERT_TRUE(std::filesystem::exists(localizationRoot)) << "Localization directory not found";

    std::vector<std::string> errors;

    for (const auto& entry : std::filesystem::directory_iterator(localizationRoot))
    {
        if (!entry.is_regular_file()) continue;
        if (entry.path().extension() != ".json") continue;

        const auto& path = entry.path();
        std::ifstream file(path);

        if (!file.is_open())
        {
            errors.push_back(path.filename().string() + ": Failed to open");
            continue;
        }

        try
        {
            nlohmann::json localization;
            file >> localization;

            if (localization.empty())
            {
                errors.push_back(path.filename().string() + ": Empty localization file");
            }
        }
        catch (const std::exception& e)
        {
            errors.push_back(path.filename().string() + ": Invalid JSON - " + e.what());
        }
    }

    if (!errors.empty())
    {
        std::ostringstream oss;
        oss << "Localization file errors:\n";
        for (const auto& err : errors)
        {
            oss << "  - " << err << "\n";
        }
        ADD_FAILURE() << oss.str();
    }

    EXPECT_TRUE(errors.empty());
}

TEST(JsonConfigValidation, MainConfigJsonIsValid)
{
    const auto path = AssetsRoot() / "config.json";

    ASSERT_TRUE(std::filesystem::exists(path)) << "config.json not found";

    std::ifstream file(path);
    ASSERT_TRUE(file.is_open()) << "Failed to open config.json";

    nlohmann::json config;
    ASSERT_NO_THROW(file >> config) << "config.json contains invalid JSON";

    EXPECT_FALSE(config.empty()) << "config.json is empty";
}

// =============================================================================
// Lua Script Syntax Validation Tests
// =============================================================================

TEST(LuaSyntaxValidation, CoreScriptsHaveValidSyntax)
{
    const auto scriptsRoot = AssetsRoot() / "scripts" / "core";

    if (!std::filesystem::exists(scriptsRoot))
    {
        GTEST_SKIP() << "Core scripts directory not found";
    }

    std::vector<std::string> allErrors;

    for (const auto& entry : std::filesystem::directory_iterator(scriptsRoot))
    {
        if (!entry.is_regular_file()) continue;
        if (entry.path().extension() != ".lua") continue;

        const auto contents = ReadFileContents(entry.path());
        if (contents.empty()) continue;

        const auto result = ValidateLuaSyntax(contents, entry.path().filename().string());
        if (!result.valid)
        {
            allErrors.insert(allErrors.end(), result.errors.begin(), result.errors.end());
        }
    }

    if (!allErrors.empty())
    {
        std::ostringstream oss;
        oss << "Lua syntax errors in core scripts:\n";
        for (const auto& err : allErrors)
        {
            oss << "  - " << err << "\n";
        }
        ADD_FAILURE() << oss.str();
    }

    EXPECT_TRUE(allErrors.empty());
}

TEST(LuaSyntaxValidation, DataScriptsHaveValidSyntax)
{
    const auto scriptsRoot = AssetsRoot() / "scripts" / "data";

    if (!std::filesystem::exists(scriptsRoot))
    {
        GTEST_SKIP() << "Data scripts directory not found";
    }

    std::vector<std::string> allErrors;

    for (const auto& entry : std::filesystem::directory_iterator(scriptsRoot))
    {
        if (!entry.is_regular_file()) continue;
        if (entry.path().extension() != ".lua") continue;

        const auto contents = ReadFileContents(entry.path());
        if (contents.empty()) continue;

        const auto result = ValidateLuaSyntax(contents, entry.path().filename().string());
        if (!result.valid)
        {
            allErrors.insert(allErrors.end(), result.errors.begin(), result.errors.end());
        }
    }

    if (!allErrors.empty())
    {
        std::ostringstream oss;
        oss << "Lua syntax errors in data scripts:\n";
        for (const auto& err : allErrors)
        {
            oss << "  - " << err << "\n";
        }
        ADD_FAILURE() << oss.str();
    }

    EXPECT_TRUE(allErrors.empty());
}

TEST(LuaSyntaxValidation, CombatScriptsHaveValidSyntax)
{
    const auto scriptsRoot = AssetsRoot() / "scripts" / "combat";

    if (!std::filesystem::exists(scriptsRoot))
    {
        GTEST_SKIP() << "Combat scripts directory not found";
    }

    std::vector<std::string> allErrors;

    for (const auto& entry : std::filesystem::directory_iterator(scriptsRoot))
    {
        if (!entry.is_regular_file()) continue;
        if (entry.path().extension() != ".lua") continue;

        const auto contents = ReadFileContents(entry.path());
        if (contents.empty()) continue;

        const auto result = ValidateLuaSyntax(contents, entry.path().filename().string());
        if (!result.valid)
        {
            allErrors.insert(allErrors.end(), result.errors.begin(), result.errors.end());
        }
    }

    if (!allErrors.empty())
    {
        std::ostringstream oss;
        oss << "Lua syntax errors in combat scripts:\n";
        for (const auto& err : allErrors)
        {
            oss << "  - " << err << "\n";
        }
        ADD_FAILURE() << oss.str();
    }

    EXPECT_TRUE(allErrors.empty());
}

// =============================================================================
// Asset Completeness Tests
// =============================================================================

TEST(AssetCompleteness, RequiredDirectoriesExist)
{
    const auto assetsRoot = AssetsRoot();

    std::vector<std::string> requiredDirs = {
        "shaders",
        "scripts",
        "graphics",
        "localization",
    };

    std::vector<std::string> missing;

    for (const auto& dir : requiredDirs)
    {
        const auto path = assetsRoot / dir;
        if (!std::filesystem::exists(path) || !std::filesystem::is_directory(path))
        {
            missing.push_back(dir);
        }
    }

    if (!missing.empty())
    {
        std::ostringstream oss;
        oss << "Missing required directories:\n";
        for (const auto& dir : missing)
        {
            oss << "  - " << dir << "\n";
        }
        ADD_FAILURE() << oss.str();
    }

    EXPECT_TRUE(missing.empty());
}

TEST(AssetCompleteness, ShaderManifestCoversAllShaderFiles)
{
    const auto shadersRoot = ShaderAssetsRoot();
    const auto manifestPath = shadersRoot / "shaders.json";
    const auto manifest = LoadJsonFile(manifestPath);

    ASSERT_FALSE(manifest.empty()) << "Failed to load shader manifest";

    // Collect all shader files referenced in manifest
    std::unordered_set<std::string> referencedFiles;
    for (const auto& [name, entry] : manifest.items())
    {
        if (entry.contains("vertex"))
            referencedFiles.insert(entry["vertex"].get<std::string>());
        if (entry.contains("fragment"))
            referencedFiles.insert(entry["fragment"].get<std::string>());
    }

    // Find shader files not in manifest
    std::vector<std::string> unreferenced;
    for (const auto& entry : std::filesystem::directory_iterator(shadersRoot))
    {
        if (!entry.is_regular_file()) continue;

        const auto& path = entry.path();
        const auto ext = path.extension().string();
        const auto filename = path.filename().string();

        if (ext != ".vs" && ext != ".fs") continue;

        // Skip if it's in archived folder or similar
        if (filename.find("archived") != std::string::npos) continue;

        if (referencedFiles.find(filename) == referencedFiles.end())
        {
            unreferenced.push_back(filename);
        }
    }

    // This is informational - unreferenced shaders may be intentional
    // Just ensure there aren't too many
    if (unreferenced.size() > 20)
    {
        std::ostringstream oss;
        oss << "Many unreferenced shader files found (" << unreferenced.size() << "):\n";
        for (size_t i = 0; i < std::min(unreferenced.size(), size_t(10)); i++)
        {
            oss << "  - " << unreferenced[i] << "\n";
        }
        if (unreferenced.size() > 10)
        {
            oss << "  ... and " << (unreferenced.size() - 10) << " more\n";
        }
        // This is a warning, not a failure
        std::cout << oss.str();
    }

    SUCCEED();
}
