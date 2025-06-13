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

        // 5) ShaderPipelineComponent
        sp.new_usertype<shader_pipeline::ShaderPipelineComponent>("ShaderPipelineComponent",
            sol::constructors<>(),
            "passes",      &shader_pipeline::ShaderPipelineComponent::passes,
            "overlayDraws",&shader_pipeline::ShaderPipelineComponent::overlayDraws,
            "padding",     &shader_pipeline::ShaderPipelineComponent::padding
        );
        rec.add_type("shader_pipeline.ShaderPipelineComponent", /*is_data_class=*/true).doc = "Holds a set of shader passes and overlays for rendering.";

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
        rec.add_type("shader_pipeline.createShaderPass").doc = "Create a new ShaderPass and populate uniforms.";

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

        // Optionally register these with rec.bind_function() if you want auto-generated annotation

        // 9) Read-only globals
        sp["front"]   = lua["function"]([]() -> RenderTexture2D& { return shader_pipeline::front(); });
        sp["back"]    = lua["function"]([]() -> RenderTexture2D& { return shader_pipeline::back(); });
        sp["width"]   = &shader_pipeline::width;
        sp["height"]  = &shader_pipeline::height;
        rec.record_property("shader_pipeline", { "front",  "RenderTexture2D", "Current front render texture" });
        rec.record_property("shader_pipeline", { "back",   "RenderTexture2D", "Current back render texture" });
        rec.record_property("shader_pipeline", { "width",  std::to_string(shader_pipeline::width), "Current render width" });
        rec.record_property("shader_pipeline", { "height", std::to_string(shader_pipeline::height), "Current render height" });


        // // 1) Create top‐level table
        // sol::table sp = lua.create_table();
        // lua["shader_pipeline"] = sp;

        // // 2) ShaderPass
        // sp.new_usertype<shader_pipeline::ShaderPass>("ShaderPass",
        //     sol::constructors<>(),
        //     "shaderName",             &shader_pipeline::ShaderPass::shaderName,
        //     "enabled",                &shader_pipeline::ShaderPass::enabled,
        //     "uniforms",               &shader_pipeline::ShaderPass::uniforms,
        //     "customPrePassFunction",  &shader_pipeline::ShaderPass::customPrePassFunction
        // );

        // // 3) OverlayInputSource enum as a Lua table
        // sp["OverlayInputSource"] = lua.create_table_with(
        //     "BaseSprite",  shader_pipeline::OverlayInputSource::BaseSprite,
        //     "PostPassResult", shader_pipeline::OverlayInputSource::PostPassResult
        // );

        // // 4) ShaderOverlayDraw
        // sp.new_usertype<shader_pipeline::ShaderOverlayDraw>("ShaderOverlayDraw",
        //     sol::constructors<>(),
        //     "inputSource",            &shader_pipeline::ShaderOverlayDraw::inputSource,
        //     "shaderName",             &shader_pipeline::ShaderOverlayDraw::shaderName,
        //     "uniforms",               &shader_pipeline::ShaderOverlayDraw::uniforms,
        //     "customPrePassFunction",  &shader_pipeline::ShaderOverlayDraw::customPrePassFunction,
        //     "blendMode",              &shader_pipeline::ShaderOverlayDraw::blendMode,
        //     "enabled",                &shader_pipeline::ShaderOverlayDraw::enabled
        // );

        // // 5) ShaderPipelineComponent
        // sp.new_usertype<shader_pipeline::ShaderPipelineComponent>("ShaderPipelineComponent",
        //     sol::constructors<>(),
        //     "passes",      &shader_pipeline::ShaderPipelineComponent::passes,
        //     "overlayDraws",&shader_pipeline::ShaderPipelineComponent::overlayDraws,
        //     "padding",     &shader_pipeline::ShaderPipelineComponent::padding
        // );

        // // 6) Helper to convert a Lua value to ShaderUniformValue
        // auto to_uniform_value = [&](sol::object obj) -> ShaderUniformValue {
        //     if (obj.is<float>()) {
        //         return obj.as<float>();
        //     } else if (obj.is<bool>()) {
        //         return obj.as<bool>();
        //     } else if (obj.is<sol::table>()) {
        //         // try Vector2, Vector3, Vector4
        //         sol::table t = obj;
        //         if (t["x"] && t["y"] && !t["z"]) {
        //             return Vector2{t["x"], t["y"]};
        //         } else if (t["x"] && t["y"] && t["z"] && !t["w"]) {
        //             return Vector3{t["x"], t["y"], t["z"]};
        //         } else if (t["x"] && t["y"] && t["z"] && t["w"]) {
        //             return Vector4{t["x"], t["y"], t["z"], t["w"]};
        //         }
        //     } else if (obj.is<Texture2D>()) {
        //         return obj.as<Texture2D>();
        //     }
        //     throw std::runtime_error("Unsupported uniform value type");
        // };

        // // 7) createShaderPass wrapper
        // sp.set_function("createShaderPass",
        //     [&](const std::string& name, sol::table tbl) {
        //         shader_pipeline::ShaderPass pass;
        //         pass.shaderName = name;
        //         for (auto& kv : tbl) {
        //             std::string key = kv.first.as<std::string>();
        //             ShaderUniformValue val = to_uniform_value(kv.second);
        //             pass.uniforms.set(key, std::move(val));
        //         }
        //         return pass;
        //     }
        // );

        // // 8) Remaining free‐functions and utilities
        // sp.set_function("ShaderPipelineUnload", &shader_pipeline::ShaderPipelineUnload);
        // sp.set_function("ShaderPipelineInit",   &shader_pipeline::ShaderPipelineInit);
        // sp.set_function("Resize",               &shader_pipeline::Resize);
        // sp.set_function("ClearTextures",        &shader_pipeline::ClearTextures);
        // sp.set_function("DebugDrawFront",       &shader_pipeline::DebugDrawFront);
        // sp.set_function("Swap",                 &shader_pipeline::Swap);
        // sp.set_function("SetLastRenderTarget",  &shader_pipeline::SetLastRenderTarget);
        // sp.set_function("GetLastRenderTarget",  &shader_pipeline::GetLastRenderTarget);
        // sp.set_function("SetLastRenderRect",    &shader_pipeline::SetLastRenderRect);
        // sp.set_function("GetLastRenderRect",    &shader_pipeline::GetLastRenderRect);

        // // 9) Expose front/back/TEX as read‐only globals
        // sp["front"] = lua["function"]([&]() -> RenderTexture2D& { return shader_pipeline::front(); });
        // sp["back"]  = lua["function"]([&]() -> RenderTexture2D& { return shader_pipeline::back(); });
        // sp["width"]  = &shader_pipeline::width;
        // sp["height"] = &shader_pipeline::height;
    }
}
