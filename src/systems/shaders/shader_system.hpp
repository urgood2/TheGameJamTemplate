#pragma once

#include <string>
#include "raylib.h"
#include <functional>
#include <variant>
#include <unordered_map>

#include "util/common_headers.hpp"

#include "systems/layer/layer.hpp"

#include "third_party/rlImGui/rlImGui.h"
#include "third_party/rlImGui/imgui.h"

#include "sol/sol.hpp"

using ShaderUniformValue = std::variant<
    float,
    Vector2,
    Vector3,
    Vector4,
    bool,
    Texture2D,
    int
    >;
// #include "third_party/rlImGui/imgui.h"
// #include "third_party/rlImGui/imgui_internal.h"

// 1) A generic overloaded‐lambda helper
template <class... Fs>
struct overloaded : Fs...
{
    using Fs::operator()...;
};
template <class... Fs>
overloaded(Fs...) -> overloaded<Fs...>;

inline void print_uniform_value(const ShaderUniformValue &uv)
{
    std::visit(overloaded{[](float f)
                          {
                              SPDLOG_DEBUG("Uniform value: {}", f);
                          },
                          [](const Vector2 &v)
                          {
                              SPDLOG_DEBUG("Uniform value: Vector2({}, {})", v.x, v.y);
                          },
                          [](const Vector3 &v)
                          {
                              SPDLOG_DEBUG("Uniform value: Vector3({}, {}, {})", v.x, v.y, v.z);
                          },
                          [](const Vector4 &v)
                          {
                              SPDLOG_DEBUG("Uniform value: Vector4({}, {}, {}, {})", v.x, v.y, v.z, v.w);
                          },
                          [](const int &i)
                          {
                              SPDLOG_DEBUG("Uniform value: {}", i);
                          },
                          [](bool b)
                          {
                              SPDLOG_DEBUG("Uniform value: {}", b ? "true" : "false");
                          },
                          [](const Texture2D &t)
                          {
                              // Raylib’s Texture2D has an 'id' (or 'texture.id') and width/height members
                              SPDLOG_DEBUG("Uniform value: Texture2D(id={}, {}x{})", t.id, t.width, t.height);
                          }},
               uv);
}

namespace shaders
{

    template <typename T>
    struct always_false : std::false_type
    {
    };

    /**
     * @struct ShaderUniformSet
     * @brief Represents a collection of shader uniform values, allowing for setting and retrieving them by name.
     *
     * This structure is used to manage a set of shader uniform values, which are stored in an unordered map
     * with their names as keys. It provides methods to set a uniform value and retrieve a uniform value by name.
     */
    struct ShaderUniformSet
    {
        std::unordered_map<std::string, ShaderUniformValue> uniforms;
        /**
         * @brief Sets a shader uniform value in the collection.
         *
         * If a uniform with the specified name already exists, its value is updated. Otherwise, a new uniform
         * is added to the collection.
         *
         * @param name The name of the uniform to set.
         * @param value The value of the uniform to set.
         */
        void set(const std::string &name, ShaderUniformValue value)
        {
            uniforms[name] = std::move(value);
            // print_uniform_value(uniforms[name]);
            // SPDLOG_DEBUG("Set uniform {}", name);
        }
        /**
         * @brief Retrieves a shader uniform value by name.
         *
         * Searches for a uniform with the specified name in the collection. If found, a pointer to the value
         * is returned. If not found, a `nullptr` is returned.
         *
         * @param name The name of the uniform to retrieve.
         * @return A pointer to the ShaderUniformValue if found, or `nullptr` if not found.
         */
        const ShaderUniformValue *get(const std::string &name) const
        {
            auto it = uniforms.find(name);
            // SPDLOG_DEBUG("Get uniform {}", name);
            return it != uniforms.end() ? &it->second : nullptr;
        }
    };

    extern auto ApplyUniformsToShader(Shader shader, const ShaderUniformSet &set) -> void;

    // attach this to a sprite entity, for example
    /**
     * @struct ShaderUniformComponent
     * @brief Manages a collection of shader uniform sets, allowing for setting and retrieving uniform values for specific shaders.
     *
     * This structure provides functionality to store and manage uniform values for multiple shaders. Each shader is identified
     * by its name, and its associated uniform values are stored in a `ShaderUniformSet`.
     *
     * @var shaderUniforms
     * A map that associates shader names (as strings) with their corresponding `ShaderUniformSet` objects.
     *
     * @fn void set(const std::string& shaderName, const std::string& uniformName, ShaderUniformValue value)
     * @brief Sets a uniform value for a specific shader.
     *
     * @param shaderName The name of the shader for which the uniform value is being set.
     * @param uniformName The name of the uniform variable to set.
     * @param value The value to assign to the uniform variable.
     *
     * This function ensures that the specified uniform value is stored in the appropriate `ShaderUniformSet` for the given shader.
     * If the shader does not already exist in the map, it will be created.
     *
     * @fn const ShaderUniformSet* getSet(const std::string& shaderName) const
     * @brief Retrieves the `ShaderUniformSet` associated with a specific shader.
     *
     * @param shaderName The name of the shader whose uniform set is being retrieved.
     * @return A pointer to the `ShaderUniformSet` associated with the shader, or `nullptr` if the shader does not exist in the map.
     *
     * This function allows for read-only access to the uniform set of a specific shader.
     */
    struct ShaderUniformComponent
    {
        std::unordered_map<std::string, ShaderUniformSet> shaderUniforms;

        // NEW: entity-specific uniform update lambdas, called before rendering each entity
        std::unordered_map<std::string, std::function<void(Shader &, entt::entity, entt::registry &)>> entityUniformCallbacks;

        void set(const std::string &shaderName, const std::string &uniformName, ShaderUniformValue value)
        {
            shaderUniforms[shaderName].set(uniformName, std::move(value));
            // SPDLOG_DEBUG("Set uniform {} for shader {}", uniformName, shaderName);
        }

        // returns nullptr if nothing stored
        const ShaderUniformValue *get(const std::string &shaderName,
                                      const std::string &uniformName) const
        {
            // 1) find the ShaderUniformSet for this shader
            auto sit = shaderUniforms.find(shaderName);
            if (sit == shaderUniforms.end())
            {
                SPDLOG_WARN("ShaderUniformComponent::get: shader '{}' not found", shaderName);
                return nullptr;
            }

            // 2) ask that set for the uniform
            const ShaderUniformValue *uv = sit->second.get(uniformName);
            if (!uv)
            {
                SPDLOG_WARN("ShaderUniformComponent::get: uniform '{}' not found in shader '{}'",
                            uniformName, shaderName);
                return nullptr;
            }

            // 3) now you know uv is valid—print it for debug
            // print_uniform_value(*uv);

            // 4) return the pointer out
            return uv;
        }

        // entity-specific uniform update lambdas, called before rendering each entity
        void registerEntityUniformCallback(const std::string &shaderName, std::function<void(Shader &, entt::entity, entt::registry &)> callback)
        {
            entityUniformCallbacks[shaderName] = std::move(callback);
        }

        const ShaderUniformSet *getSet(const std::string &shaderName) const
        {
            auto it = shaderUniforms.find(shaderName);
            // SPDLOG_DEBUG("Get uniform set for shader {}", shaderName);
            return it != shaderUniforms.end() ? &it->second : nullptr;
        }

        void applyToShaderForEntity(Shader &shader, const std::string &shaderName, entt::entity e, entt::registry &registry)
        {
            // Apply static uniform set (if any)
            if (const ShaderUniformSet *uniformSet = getSet(shaderName))
            {
                shaders::ApplyUniformsToShader(shader, *uniformSet);
            }

            // Call per-entity uniform lambda if registered
            auto it = entityUniformCallbacks.find(shaderName);
            if (it != entityUniformCallbacks.end())
            {
                it->second(shader, e, registry);
            }
        }
    };

    inline void TryApplyUniforms(Shader shader, const ShaderUniformComponent &component, const std::string &shaderName)
    {
        if (const auto *uniformSet = component.getSet(shaderName))
        {
            ApplyUniformsToShader(shader, *uniformSet);
        }
    }
    
    /// Injects atlas UV parameters into your ShaderUniformComponent
    inline void injectAtlasUniforms(
        ShaderUniformComponent & component,
        const std::string      & shaderName,
        const Rectangle       & gridRect,   // x, y, width, height in pixels
        const Vector2         & imageSize)  // atlasWidth, atlasHeight
    {
        // // pack the rect: (x, y, w, h)
        // component.set(
        //     shaderName,
        //     "uGridRect",
        //     Vector4{ gridRect.x,
        //                         gridRect.y,
        //                         gridRect.width,
        //                         gridRect.height }
        // );

        // // pack the atlas size: (atlasW, atlasH)
        // component.set(
        //     shaderName,
        //     "uImageSize",
        //     Vector2{ imageSize.x,
        //                         imageSize.y }
        // );
        
        globals::globalShaderUniforms.set(shaderName, "uImageSize",
            imageSize);
        // which grid sprite
        globals::globalShaderUniforms.set(shaderName, "uGridRect",
            Vector4{ gridRect.x,
                                        gridRect.y,
                                        gridRect.width,
                                        gridRect.height});
        
        // SPDLOG_DEBUG("Injected atlas uniforms for shader '{}': gridRect=({}, {}, {}, {}), imageSize=({}, {})",
        //            shaderName, gridRect.x, gridRect.y, gridRect.width, gridRect.height, imageSize.x, imageSize.y);
    }


    extern auto loadShadersFromJSON(std::string jsonPath) -> void;
    extern auto unloadShaders() -> void;

    extern auto disableAllShadersViaOverride(bool enabled) -> void;
    extern auto hotReloadShaders() -> void;

    extern auto setShaderMode(std::string shaderName) -> void;
    extern auto unsetShaderMode() -> void;

    extern auto getShader(std::string shaderName) -> Shader;

    extern auto registerUniformUpdate(std::string shaderName, std::function<void(Shader &)> updateLambda) -> void;
    extern auto updateAllShaderUniforms() -> void;

    // auto checkImGUIWindowExists(std::string windowName) -> void;
    // auto beginImGUIWindowWithCallback(std::string imguiWindow, std::function<void(const ImDrawList*, const ImDrawCmd*)> callback) -> void;
    // auto endImGUIShaderCallback(std::string imguiWindow, std::function<void(const ImDrawList*, const ImDrawCmd*)> callback) ->void;

    extern auto update(float dt) -> void;

    extern void ShowShaderEditorUI(ShaderUniformComponent &component);

    extern auto exposeToLua(sol::state &lua) -> void;
}