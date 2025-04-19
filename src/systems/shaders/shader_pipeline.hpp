#pragma once
#include "raylib.h"
#include <utility>
#include <string>
#include <vector>
#include <unordered_map>

namespace shader_pipeline {

    struct ShaderPass {
        std::string shaderName;
        bool enabled = true;
    };

    struct ShaderPipelineComponent {
        std::vector<ShaderPass> passes;
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
