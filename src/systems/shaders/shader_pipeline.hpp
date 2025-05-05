#pragma once
#include "raylib.h"
#include <utility>
#include <string>
#include <vector>
#include <unordered_map>

#include "shader_system.hpp"

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
}
