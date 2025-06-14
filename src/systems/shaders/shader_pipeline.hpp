#pragma once
#include "raylib.h"
#include <utility>
#include <string>
#include <vector>
#include <unordered_map>

#include "shader_system.hpp"

#include "systems/scripting/binding_recorder.hpp"

namespace shader_pipeline {

    struct ShaderPass {
        std::string shaderName;
        bool enabled = true;
        
        // custom uniforms for this shader pass, applied for this pass only
        shaders::ShaderUniformSet uniforms;
        
        // custom lamdna for this shader pass, run before activatingt the shader for this pass
        std::function<void()> customPrePassFunction{};
    };
    
    enum class OverlayInputSource { BaseSprite, PostPassResult };

    struct ShaderOverlayDraw {
        OverlayInputSource inputSource;
        std::string shaderName;
        shaders::ShaderUniformSet uniforms;  // ✅ Now matches ApplyUniformsToShader
        std::function<void()> customPrePassFunction = nullptr;
        BlendMode blendMode = BlendMode::BLEND_ALPHA;
        bool enabled = true;
    };

    struct ShaderPipelineComponent {
        std::vector<ShaderPass> passes;
        std::vector<ShaderOverlayDraw> overlayDraws;
        float padding = 8.0f; // Default padding for each side
    };
    
    

    inline RenderTexture2D ping = {};
    inline RenderTexture2D pong = {};
    inline int width = 0;
    inline int height = 0;
    inline RenderTexture2D* lastRenderTarget = nullptr;
    inline Rectangle lastRenderRect = {0, 0, 0, 0};
    inline RenderTexture2D& front() { return ping; }
    inline RenderTexture2D& back() { return pong; }

    inline bool IsInitialized() {
        return ping.id != 0 && pong.id != 0;
    }

    inline void ShaderPipelineUnload() {
        if (ping.id != 0) UnloadRenderTexture(ping);
        if (pong.id != 0) UnloadRenderTexture(pong);
        ping = {};
        pong = {};
        width = 0;
        height = 0;
    }

    inline void ShaderPipelineInit(int w, int h) {
        if (IsInitialized()) ShaderPipelineUnload(); // Prevent leaks
        width = w;
        height = h;
        ping = LoadRenderTexture(w, h);
        pong = LoadRenderTexture(w, h);
    }

    inline void Resize(int newWidth, int newHeight) {
        if (newWidth != width || newHeight != height) {
            ShaderPipelineUnload();
            ShaderPipelineInit(newWidth, newHeight);
        }
    }

    inline void ClearTextures(Color color = {0, 0, 0, 0}) {
        BeginTextureMode(ping);
        ClearBackground(color);
        EndTextureMode();

        BeginTextureMode(pong);
        ClearBackground(color);
        EndTextureMode();
    }
    /*
        usage:
        ```
        shaderPipeline.passes.push_back(createShaderPass("foil", {
            {"u_color", Vector4{1,1,1,1}},
            {"u_time", 0.0f},
            {"u_resolution", Vector2{globals::screenWidth, globals::screenHeight}}
        }));
        ```
    */
    inline ShaderPass createShaderPass(const std::string& name, std::initializer_list<std::pair<std::string, ShaderUniformValue>> uniformList) {
        ShaderPass pass;
        pass.shaderName = name;
        for (auto& [k, v] : uniformList) {
            pass.uniforms.set(k, v);
        }
        return pass;
    }

    inline void DebugDrawFront(int x = 0, int y = 0) {
        DrawTextureRec(front().texture,
            {0, 0, (float)width, -(float)height},
            {(float)x, (float)y},
            WHITE
        );
    }

    inline void Swap() {
        std::swap(ping, pong);
    }

    

    inline void SetLastRenderTarget(RenderTexture2D& tex) {
        lastRenderTarget = &tex;
    }

    inline RenderTexture2D* GetLastRenderTarget() {
        return lastRenderTarget;
    }

    inline void SetLastRenderRect(Rectangle rect) {
        lastRenderRect = rect;
    }

    inline Rectangle GetLastRenderRect() {
        return lastRenderRect;
    }

    inline void exposeToLua(sol::state& lua) {

        // 1) Create top-level table
        sol::table sp = lua.create_named_table("shader_pipeline");

        // For .lua_defs emitter
        auto& rec = BindingRecorder::instance();
        rec.add_type("shader_pipeline").doc = "Root table for shader pipeline helpers and types.";

        // 2) ShaderPass
        sp.new_usertype<shader_pipeline::ShaderPass>("ShaderPass",
            sol::constructors<>(),
            "shaderName",             &shader_pipeline::ShaderPass::shaderName,
            "enabled",                &shader_pipeline::ShaderPass::enabled,
            "uniforms",               &shader_pipeline::ShaderPass::uniforms,
            "customPrePassFunction",  &shader_pipeline::ShaderPass::customPrePassFunction
        );
        rec.add_type("shader_pipeline.ShaderPass", /*is_data_class=*/true).doc = "Defines a single shader pass with configurable uniforms.";
        rec.record_property("shader_pipeline.ShaderPass", { "shaderName", "string", "Name of the shader to use for this pass" });
        rec.record_property("shader_pipeline.ShaderPass", { "enabled", "bool", "Whether this shader pass is enabled" });
        rec.record_property("shader_pipeline.ShaderPass", { "uniforms", "UniformSet", "Shader uniforms to apply for this pass" });
        rec.record_property("shader_pipeline.ShaderPass", { "customPrePassFunction", "fun()", "Custom function to run before activating the shader for this pass" });

        // 3) OverlayInputSource enum
        sp["OverlayInputSource"] = lua.create_table_with(
            "BaseSprite",      shader_pipeline::OverlayInputSource::BaseSprite,
            "PostPassResult",  shader_pipeline::OverlayInputSource::PostPassResult
        );
        auto& enumOverlay = rec.add_type("shader_pipeline.OverlayInputSource");
        enumOverlay.doc = "Source input for shader overlay drawing.";
        rec.record_property("shader_pipeline.OverlayInputSource", { "BaseSprite", std::to_string((int)shader_pipeline::OverlayInputSource::BaseSprite), "Use the base sprite" });
        rec.record_property("shader_pipeline.OverlayInputSource", { "PostPassResult", std::to_string((int)shader_pipeline::OverlayInputSource::PostPassResult), "Use the result from previous pass" });

        // 4) ShaderOverlayDraw
        sp.new_usertype<shader_pipeline::ShaderOverlayDraw>("ShaderOverlayDraw",
            sol::constructors<>(),
            "inputSource",            &shader_pipeline::ShaderOverlayDraw::inputSource,
            "shaderName",             &shader_pipeline::ShaderOverlayDraw::shaderName,
            "uniforms",               &shader_pipeline::ShaderOverlayDraw::uniforms,
            "customPrePassFunction",  &shader_pipeline::ShaderOverlayDraw::customPrePassFunction,
            "blendMode",              &shader_pipeline::ShaderOverlayDraw::blendMode,
            "enabled",                &shader_pipeline::ShaderOverlayDraw::enabled
        );
        rec.add_type("shader_pipeline.ShaderOverlayDraw", /*is_data_class=*/true).doc = "Defines a shader overlay draw operation.";
        rec.record_property("shader_pipeline.ShaderOverlayDraw", { "inputSource", "OverlayInputSource", "Source input for the overlay draw" });
        rec.record_property("shader_pipeline.ShaderOverlayDraw", { "shaderName", "string", "Name of the shader to use for this overlay" });
        rec.record_property("shader_pipeline.ShaderOverlayDraw", { "uniforms", "shaders::ShaderUniformSet", "Shader uniforms to apply for this overlay" });
        rec.record_property("shader_pipeline.ShaderOverlayDraw", { "customPrePassFunction", "fun()", "Custom function to run before activating the shader for this overlay" });
        rec.record_property("shader_pipeline.ShaderOverlayDraw", { "blendMode", "BlendMode", "Blend mode to use for this overlay" });
        rec.record_property("shader_pipeline.ShaderOverlayDraw", { "enabled", "bool", "Whether this overlay draw is enabled" });

        // 5) ShaderPipelineComponent
        sp.new_usertype<shader_pipeline::ShaderPipelineComponent>("ShaderPipelineComponent",
            sol::constructors<>(),
            "passes",      &shader_pipeline::ShaderPipelineComponent::passes,
            "overlayDraws",&shader_pipeline::ShaderPipelineComponent::overlayDraws,
            "padding",     &shader_pipeline::ShaderPipelineComponent::padding
        );
        rec.add_type("shader_pipeline.ShaderPipelineComponent", /*is_data_class=*/true).doc = "Holds a set of shader passes and overlays for rendering.";
        rec.record_property("shader_pipeline.ShaderPipelineComponent", { "passes", "std::vector<ShaderPass>", "List of shader passes to apply" });
        rec.record_property("shader_pipeline.ShaderPipelineComponent", { "overlayDraws", "std::vector<ShaderOverlayDraw>", "List of shader overlays to apply" });
        rec.record_property("shader_pipeline.ShaderPipelineComponent", { "padding", "float", "Padding around the shader overlays" });
        

        // 6) Helper to convert table to ShaderUniformValue
        auto to_uniform_value = [&](sol::object obj) -> ShaderUniformValue {
            if (obj.is<float>()) return obj.as<float>();
            if (obj.is<bool>()) return obj.as<bool>();
            if (obj.is<sol::table>()) {
                auto t = obj.as<sol::table>();
                if (t["x"] && t["y"] && !t["z"]) return Vector2{t["x"], t["y"]};
                if (t["x"] && t["y"] && t["z"] && !t["w"]) return Vector3{t["x"], t["y"], t["z"]};
                if (t["x"] && t["y"] && t["z"] && t["w"]) return Vector4{t["x"], t["y"], t["z"], t["w"]};
            }
            if (obj.is<Texture2D>()) return obj.as<Texture2D>();
            throw std::runtime_error("Unsupported uniform value type");
        };

        // 7) Factory: createShaderPass
        sp.set_function("createShaderPass", [&](const std::string& name, sol::table tbl) {
            shader_pipeline::ShaderPass pass;
            pass.shaderName = name;
            for (auto& kv : tbl) {
                std::string key = kv.first.as<std::string>();
                ShaderUniformValue val = to_uniform_value(kv.second);
                pass.uniforms.set(key, std::move(val));
            }
            return pass;
        });
        // Correctly document createShaderPass as a function
        rec.record_free_function({"shader_pipeline"}, {
            "createShaderPass",
            "---@param name string # The name of the shader to use.\n"
            "---@param uniforms table<string, any> # A Lua table of uniform names to values.\n"
            "---@return shader_pipeline.ShaderPass",
            "Factory function to create a new ShaderPass object from a name and a table of uniforms."
        });

        // 8) Free functions
        sp.set_function("ShaderPipelineUnload", &shader_pipeline::ShaderPipelineUnload);
        sp.set_function("ShaderPipelineInit",   &shader_pipeline::ShaderPipelineInit);
        sp.set_function("Resize",               &shader_pipeline::Resize);
        sp.set_function("ClearTextures",        &shader_pipeline::ClearTextures);
        sp.set_function("DebugDrawFront",       &shader_pipeline::DebugDrawFront);
        sp.set_function("Swap",                 &shader_pipeline::Swap);
        sp.set_function("SetLastRenderTarget",  &shader_pipeline::SetLastRenderTarget);
        sp.set_function("GetLastRenderTarget",  &shader_pipeline::GetLastRenderTarget);
        sp.set_function("SetLastRenderRect",    &shader_pipeline::SetLastRenderRect);
        sp.set_function("GetLastRenderRect",    &shader_pipeline::GetLastRenderRect);
        
        // --- Added Missing Documentation for Free Functions ---
        rec.record_free_function({"shader_pipeline"}, {"ShaderPipelineUnload", "---@return nil", "Unloads the pipeline's internal render textures."});
        rec.record_free_function({"shader_pipeline"}, {"ShaderPipelineInit", "---@param width integer\n---@param height integer\n---@return nil", "Initializes or re-initializes the pipeline's render textures to a new size."});
        rec.record_free_function({"shader_pipeline"}, {"Resize", "---@param newWidth integer\n---@param newHeight integer\n---@return nil", "Resizes the pipeline's render textures if the new dimensions are different."});
        rec.record_free_function({"shader_pipeline"}, {"ClearTextures", "---@param color? Color\n---@return nil", "Clears the pipeline's internal textures to a specific color (defaults to transparent).", true});
        rec.record_free_function({"shader_pipeline"}, {"DebugDrawFront", "---@param x? integer\n---@param y? integer\n---@return nil", "Draws the current 'front' render texture for debugging purposes."});
        rec.record_free_function({"shader_pipeline"}, {"Swap", "---@return nil", "Swaps the internal 'ping' and 'pong' render textures."});
        rec.record_free_function({"shader_pipeline"}, {"SetLastRenderTarget", "---@param texture RenderTexture2D\n---@return nil", "Internal helper to track the last used render target."});
        rec.record_free_function({"shader_pipeline"}, {"GetLastRenderTarget", "---@return RenderTexture2D|nil", "Internal helper to retrieve the last used render target."});
        rec.record_free_function({"shader_pipeline"}, {"SetLastRenderRect", "---@param rect Rectangle\n---@return nil", "Internal helper to track the last rendered rectangle area."});
        rec.record_free_function({"shader_pipeline"}, {"GetLastRenderRect", "---@return Rectangle", "Internal helper to retrieve the last rendered rectangle area."});

    }
}
