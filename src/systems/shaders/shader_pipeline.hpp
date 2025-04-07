#pragma once
#include "raylib.h"
#include <utility>
#include <string>
#include <vector>
#include <unordered_map>

// helper class for shader pipeline for sprites (for chaining shaders)
namespace shader_pipeline {
    
    struct ShaderPass {
        std::string shaderName;
        bool enabled = true;
    };
    
    struct ShaderPipelineComponent {
        std::vector<ShaderPass> passes;
        float padding = 8.0f; // Default padding on each side (left, right, top, bottom)
    };
    
    inline RenderTexture2D ping;
    inline RenderTexture2D pong;
    inline int width = 0;
    inline int height = 0;
    inline RenderTexture2D* lastRenderTarget = nullptr;
    inline Rectangle lastRenderRect = {0, 0, 0, 0};


    inline void init(int w, int h) {
        width = w;
        height = h;
        ping = LoadRenderTexture(w, h);
        pong = LoadRenderTexture(w, h);
    }

    inline void unload() {
        UnloadRenderTexture(ping);
        UnloadRenderTexture(pong);
    }

    inline void swap() {
        std::swap(ping, pong);
    }

    inline RenderTexture2D& front() { return ping; }
    inline RenderTexture2D& back() { return pong; }

    inline void setLastRenderTarget(RenderTexture2D& tex) {
        lastRenderTarget = &tex;
    }

    inline RenderTexture2D* getLastRenderTarget() {
        return lastRenderTarget;
    }
    
    inline void setLastRenderRect(Rectangle rect) {
        lastRenderRect = rect;
    }

    inline Rectangle getLastRenderRect() {
        return lastRenderRect;
    }


    inline bool isInitialized() {
        return ping.id != 0 && pong.id != 0;
    }
}
