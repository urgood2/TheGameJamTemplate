#pragma once
#include "raylib.h"
#include <utility>
#include <string>
#include <vector>
#include <unordered_map>

#include "shader_system.hpp"

#include "systems/scripting/binding_recorder.hpp"

namespace shader_pipeline {

    // removed storage of shader uniforms from ShaderPass. Just using globals
    struct ShaderPass {
        std::string shaderName;
        bool enabled = true;
        
        
        // custom lamdna for this shader pass, run before activatingt the shader for this pass
        std::function<void()> customPrePassFunction{};
        
        bool injectAtlasUniforms = false; // whether to inject atlas uniforms into this pass


    };
    
    enum class OverlayInputSource { BaseSprite, PostPassResult };

    struct ShaderOverlayDraw {
        OverlayInputSource inputSource;
        std::string shaderName;
        std::function<void()> customPrePassFunction = nullptr;
        BlendMode blendMode = BlendMode::BLEND_ALPHA;
        bool enabled = true;
    };

    struct ShaderPipelineComponent {
        std::vector<ShaderPass> passes;
        std::vector<ShaderOverlayDraw> overlayDraws;
        float padding = 15.f; // Default padding for each side

        // Add a new shader pass (enabled by default)
        ShaderPass addPass(std::string_view name) {
            passes.emplace_back(ShaderPass{std::string(name), true, nullptr});
            return passes.back();
        }

        // Remove a pass by name
        bool removePass(std::string_view name) {
            auto it = std::find_if(passes.begin(), passes.end(),
                [&](auto &p){ return p.shaderName == name; });
            if (it == passes.end()) return false;
            passes.erase(it);
            return true;
        }

        // Toggle a pass on/off
        bool togglePass(std::string_view name) {
            auto it = std::find_if(passes.begin(), passes.end(),
                [&](auto &p){ return p.shaderName == name; });
            if (it == passes.end()) return false;
            it->enabled = !it->enabled;
            return true;
        }

        // Add a new overlay draw
        ShaderOverlayDraw addOverlay(OverlayInputSource src, std::string_view name,
                        BlendMode blend = BlendMode::BLEND_ALPHA) {
            overlayDraws.emplace_back(ShaderOverlayDraw{src, std::string(name), nullptr, blend, true});
            return overlayDraws.back();
        }

        // Remove an overlay by shader name
        bool removeOverlay(std::string_view name) {
            auto it = std::find_if(overlayDraws.begin(), overlayDraws.end(),
                [&](auto &o){ return o.shaderName == name; });
            if (it == overlayDraws.end()) return false;
            overlayDraws.erase(it);
            return true;
        }

        // Toggle an overlay on/off
        bool toggleOverlay(std::string_view name) {
            auto it = std::find_if(overlayDraws.begin(), overlayDraws.end(),
                [&](auto &o){ return o.shaderName == name; });
            if (it == overlayDraws.end()) return false;
            it->enabled = !it->enabled;
            return true;
        }

        // Clear both passes and overlays
        void clearAll() {
            passes.clear();
            overlayDraws.clear();
        }
    };
    
    

    inline RenderTexture2D ping = {};
    inline RenderTexture2D pong = {};
    inline int width = 0;
    inline int height = 0;
    inline RenderTexture2D* lastRenderTarget = nullptr;
    inline Rectangle lastRenderRect = {0, 0, 0, 0};
    inline RenderTexture2D& front() { return ping; }
    inline RenderTexture2D& back() { return pong; }
    //–– New cache state ––//
    inline RenderTexture2D baseCache             = {};
    inline bool            baseCacheValid        = false;
    inline RenderTexture2D postPassCache        = {};
    inline bool            postPassCacheValid    = false;
    
    //–– New API ––//
    inline RenderTexture2D GetBaseRenderTextureCache() {
        return baseCache;
    }
    inline bool IsBaseRenderTextureCacheValid() {
        return baseCache.id != 0;
    }

    inline RenderTexture2D GetPostShaderPassRenderTextureCache() {
        return postPassCache;
    }
    inline bool IsPostShaderPassRenderTextureCacheValid() {
        return  postPassCache.id != 0;
    }

    inline bool IsInitialized() {
        return ping.id != 0 && pong.id != 0;
    }

    inline void ShaderPipelineUnload() {
        if (ping.id != 0) UnloadRenderTexture(ping);
        if (pong.id != 0) UnloadRenderTexture(pong);
        if (baseCache.id != 0) UnloadRenderTexture(baseCache);
        if (postPassCache.id != 0) UnloadRenderTexture(postPassCache);
        ping = {};
        pong = {};
        width = 0;
        height = 0;
    }

    inline void ShaderPipelineInit(int w, int h) {
        width = w;
        height = h;
        SPDLOG_DEBUG("Initializing shader pipeline with dimensions: {}x{}", w, h);
        ping = LoadRenderTexture(w, h);
        pong = LoadRenderTexture(w, h);
        baseCache = LoadRenderTexture(w, h);
        postPassCache = LoadRenderTexture(w, h);
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
        
        BeginTextureMode(baseCache);
        ClearBackground(color);
        EndTextureMode();
        
        BeginTextureMode(postPassCache);
        ClearBackground(color);
        EndTextureMode();
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
            "shaderName",            &shader_pipeline::ShaderPass::shaderName,
            "enabled",               &shader_pipeline::ShaderPass::enabled,
            "injectAtlasUniforms", &shader_pipeline::ShaderPass::injectAtlasUniforms,
            "customPrePassFunction", &shader_pipeline::ShaderPass::customPrePassFunction,
            "type_id", []() { return entt::type_hash<shader_pipeline::ShaderPass>::value(); }
        );
        rec.add_type("shader_pipeline.ShaderPass", /*is_data_class=*/true)
        .doc = "Defines a single shader pass.";
        rec.record_property("shader_pipeline.ShaderPass",
            { "shaderName", "string", "Name of the shader to use for this pass" });
        rec.record_property("shader_pipeline.ShaderPass",
            { "injectAtlasUniforms", "bool", "Whether to inject atlas UV uniforms into this pass" });
        rec.record_property("shader_pipeline.ShaderPass",
            { "enabled", "bool", "Whether this shader pass is enabled" });
        rec.record_property("shader_pipeline.ShaderPass",
            { "customPrePassFunction", "fun()", "Function to run before activating this pass" });

        // 3) OverlayInputSource enum
        sp["OverlayInputSource"] = lua.create_table_with(
            "BaseSprite",     shader_pipeline::OverlayInputSource::BaseSprite,
            "PostPassResult", shader_pipeline::OverlayInputSource::PostPassResult
        );
        auto &enumOverlay = rec.add_type("shader_pipeline.OverlayInputSource");
        enumOverlay.doc = "Source input for shader overlay drawing.";
        rec.record_property("shader_pipeline.OverlayInputSource",
            { "BaseSprite",      std::to_string((int)shader_pipeline::OverlayInputSource::BaseSprite),
            "Use the base sprite" });
        rec.record_property("shader_pipeline.OverlayInputSource",
            { "PostPassResult",  std::to_string((int)shader_pipeline::OverlayInputSource::PostPassResult),
            "Use the result from previous passes" });

        // 4) ShaderOverlayDraw
        sp.new_usertype<shader_pipeline::ShaderOverlayDraw>("ShaderOverlayDraw",
            sol::constructors<>(),
            "inputSource",           &shader_pipeline::ShaderOverlayDraw::inputSource,
            "shaderName",            &shader_pipeline::ShaderOverlayDraw::shaderName,
            "customPrePassFunction", &shader_pipeline::ShaderOverlayDraw::customPrePassFunction,
            "blendMode",             &shader_pipeline::ShaderOverlayDraw::blendMode,
            "enabled",               &shader_pipeline::ShaderOverlayDraw::enabled,
            "type_id", []() { return entt::type_hash<shader_pipeline::ShaderOverlayDraw>::value(); }
        );
        rec.add_type("shader_pipeline.ShaderOverlayDraw", /*is_data_class=*/true)
        .doc = "Defines a full-screen shader overlay pass.";
        rec.record_property("shader_pipeline.ShaderOverlayDraw",
            { "inputSource",           "OverlayInputSource", "Where to sample input from" });
        rec.record_property("shader_pipeline.ShaderOverlayDraw",
            { "shaderName",            "string",             "Name of the overlay shader" });
        rec.record_property("shader_pipeline.ShaderOverlayDraw",
            { "customPrePassFunction", "fun()",              "Function to run before this overlay" });
        rec.record_property("shader_pipeline.ShaderOverlayDraw",
            { "blendMode",             "BlendMode",          "Blend mode for this overlay" });
        rec.record_property("shader_pipeline.ShaderOverlayDraw",
            { "enabled",               "bool",               "Whether this overlay is enabled" });

        // 5) ShaderPipelineComponent
        sp.new_usertype<shader_pipeline::ShaderPipelineComponent>("ShaderPipelineComponent",
            sol::constructors<>(),
            // core data
            "passes",        &shader_pipeline::ShaderPipelineComponent::passes,
            "overlayDraws",  &shader_pipeline::ShaderPipelineComponent::overlayDraws,
            "padding",       &shader_pipeline::ShaderPipelineComponent::padding,
            // new methods
            "addPass", sol::overload(
                // 1) original single-string version
                
                &shader_pipeline::ShaderPipelineComponent::addPass,

                // 2) string+bool version, via a lambda
                [](shader_pipeline::ShaderPipelineComponent &self,
                const std::string &name,
                bool injectAtlasUniforms)
                {
                    // call the existing addPass(name)
                    self.addPass(name);
                    // tweak the just-added pass (assumes passes is a vector)
                    auto &p = self.passes.back();
                    p.injectAtlasUniforms = injectAtlasUniforms;
                    // return the pass for convenience
                    return p;
                }
            ),
            "removePass",    &shader_pipeline::ShaderPipelineComponent::removePass,
            "togglePass",    &shader_pipeline::ShaderPipelineComponent::togglePass,
            "addOverlay",    &shader_pipeline::ShaderPipelineComponent::addOverlay,
            "removeOverlay", &shader_pipeline::ShaderPipelineComponent::removeOverlay,
            "toggleOverlay", &shader_pipeline::ShaderPipelineComponent::toggleOverlay,
            "clearAll",      &shader_pipeline::ShaderPipelineComponent::clearAll,
            "type_id", []() { return entt::type_hash<shader_pipeline::ShaderPipelineComponent>::value(); }
        );
        rec.add_type("shader_pipeline.ShaderPipelineComponent", /*is_data_class=*/true)
        .doc = "Holds a sequence of shader passes and overlays for full-scene rendering.";
        rec.record_property("shader_pipeline.ShaderPipelineComponent",
            { "passes",       "std::vector<ShaderPass>",       "Ordered list of shader passes" });
        rec.record_property("shader_pipeline.ShaderPipelineComponent",
            { "overlayDraws", "std::vector<ShaderOverlayDraw>", "Ordered list of overlays" });
        rec.record_property("shader_pipeline.ShaderPipelineComponent",
            { "padding",      "float",                         "Safe-area padding around overlays" });

        // document your new functions
        rec.record_free_function(
            {"shader_pipeline.ShaderPipelineComponent"},
            {"addPass",
            "---@param name string\n---@return nil",
            "Add a new pass at the end"}
        );

        rec.record_free_function(
            {"shader_pipeline.ShaderPipelineComponent"},
            {"removePass",
            "---@param name string\n---@return boolean",
            "Remove a pass by name"}
        );

        rec.record_free_function(
            {"shader_pipeline.ShaderPipelineComponent"},
            {"togglePass",
            "---@param name string\n---@return boolean",
            "Toggle a pass enabled/disabled"}
        );

        rec.record_free_function(
            {"shader_pipeline.ShaderPipelineComponent"},
            {"addOverlay",
            "---@param src OverlayInputSource\n---@param name string\n---@param blend? BlendMode\n---@return nil",
            "Add a new overlay; blend mode is optional"}
        );

        rec.record_free_function(
            {"shader_pipeline.ShaderPipelineComponent"},
            {"removeOverlay",
            "---@param name string\n---@return boolean",
            "Remove an overlay by name"}
        );

        rec.record_free_function(
            {"shader_pipeline.ShaderPipelineComponent"},
            {"toggleOverlay",
            "---@param name string\n---@return boolean",
            "Toggle an overlay on/off"}
        );

        rec.record_free_function(
            {"shader_pipeline.ShaderPipelineComponent"},
            {"clearAll",
            "---@return nil",
            "Clear both passes and overlays"}
        );
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

        // // 7) Factory: createShaderPass
        // sp.set_function("createShaderPass", [&](const std::string& name, sol::table tbl) {
        //     shader_pipeline::ShaderPass pass;
        //     pass.shaderName = name;
        //     for (auto& kv : tbl) {
        //         std::string key = kv.first.as<std::string>();
        //         ShaderUniformValue val = to_uniform_value(kv.second);
        //         pass.uniforms.set(key, std::move(val));
        //     }
        //     return pass;
        // });
        // // Correctly document createShaderPass as a function
        // rec.record_free_function({"shader_pipeline"}, {
        //     "createShaderPass",
        //     "---@param name string # The name of the shader to use.\n"
        //     "---@param uniforms table<string, any> # A Lua table of uniform names to values.\n"
        //     "---@return shader_pipeline.ShaderPass",
        //     "Factory function to create a new ShaderPass object from a name and a table of uniforms."
        // });

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
