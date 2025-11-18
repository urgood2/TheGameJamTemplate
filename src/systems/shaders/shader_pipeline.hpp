#pragma once
#include "raylib.h"
#include <utility>
#include <string>
#include <vector>
#include <unordered_map>
#include <atomic>
#include <algorithm>
#include <cmath>
#include <stack>
#include <mutex>

#include "shader_system.hpp"
#include "systems/scripting/binding_recorder.hpp"

namespace shader_pipeline {
    
    // Forward declarations for RAII guards
    class RenderTargetGuard;
    class MatrixStackGuard;

    // removed storage of shader uniforms from ShaderPass. Just using globals
    struct ShaderPass {
        std::string shaderName;
        bool enabled = true;
        
        // custom lambda for this shader pass, run before activating the shader for this pass
        std::function<void()> customPrePassFunction{};
        
        bool injectAtlasUniforms = true; // whether to inject atlas uniforms into this pass / true by default to avoid bugs
    };
    
    enum class OverlayInputSource { BaseSprite, PostPassResult };

    struct ShaderOverlayDraw {
        OverlayInputSource inputSource;
        std::string shaderName;
        std::function<void()> customPrePassFunction = nullptr;
        BlendMode blendMode = BlendMode::BLEND_ALPHA;
        bool enabled = true;
        bool injectAtlasUniforms = true; // whether to inject atlas uniforms into this overlay draw (uGridSize, uImageSize for location within atlas)
    };

    struct ShaderPipelineComponent {
        std::vector<ShaderPass> passes;
        std::vector<ShaderOverlayDraw> overlayDraws;
        float padding = 30.f; // Default padding for each side

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

        bool hasPassesOrOverlays() const {
            return !passes.empty() || !overlayDraws.empty();
        }

        // Clear both passes and overlays
        void clearAll() {
            passes.clear();
            overlayDraws.clear();
        }
    };
    
    // Core render textures
    inline RenderTexture2D ping = {};
    inline RenderTexture2D pong = {};
    inline int width = 0;
    inline int height = 0;
    
    // FIX: Replaced raw pointer with safe tracking
    inline bool lastWasFront = true;
    inline Rectangle lastRenderRect = {0, 0, 0, 0};
    
    inline RenderTexture2D& front() { return ping; }
    inline RenderTexture2D& back() { return pong; }
    
    // Cache state
    inline RenderTexture2D baseCache = {};
    inline bool baseCacheValid = false;
    inline RenderTexture2D postPassCache = {};
    inline bool postPassCacheValid = false;
    
    // FIX: Thread-safe resize guard
    inline std::atomic<bool> isResizing{false};
    
    // FIX: Entity rendering tracking for debugging concurrent access
    inline std::atomic<int> currentRenderingEntity{-1};
    
    // Cache API - NOW RETURNS REFERENCES, NOT COPIES
    inline RenderTexture2D& GetBaseRenderTextureCache() {
        return baseCache;
    }
    
    inline bool IsBaseRenderTextureCacheValid() {
        return baseCache.id != 0;
    }

    inline RenderTexture2D& GetPostShaderPassRenderTextureCache() {
        return postPassCache;
    }
    
    inline bool IsPostShaderPassRenderTextureCacheValid() {
        return postPassCache.id != 0;
    }

    inline bool IsInitialized() {
        return ping.id != 0 && pong.id != 0;
    }
    
    //------------------------------------------------------------------------------------
    // FIX #4: Texture Rectangle Validation
    //------------------------------------------------------------------------------------
    inline bool ValidateTextureRect(const RenderTexture2D& tex, const Rectangle& rect, const char* context = "unknown") {
        if (tex.id == 0) {
            SPDLOG_ERROR("[{}] Invalid texture (id=0)", context);
            return false;
        }
        
        // Allow negative dimensions (indicates flipping)
        float absWidth = std::abs(rect.width);
        float absHeight = std::abs(rect.height);
        float rectX = rect.x;
        float rectY = rect.y;
        
        // Adjust for negative dimensions
        if (rect.width < 0) {
            rectX = rect.x - absWidth;
        }
        if (rect.height < 0) {
            rectY = rect.y - absHeight;
        }
        
        // Check bounds with tolerance for floating point errors
        const float TOLERANCE = 1.0f;
        if (rectX < -TOLERANCE || rectY < -TOLERANCE || 
            rectX + absWidth > tex.texture.width + TOLERANCE ||
            rectY + absHeight > tex.texture.height + TOLERANCE) {
            SPDLOG_WARN("[{}] Rectangle out of texture bounds: rect({:.1f},{:.1f},{:.1f}x{:.1f}) vs tex({}x{})",
                context, rect.x, rect.y, rect.width, rect.height, 
                tex.texture.width, tex.texture.height);
            return false;
        }
        
        return true;
    }
    
    //------------------------------------------------------------------------------------
    // FIX #4: Safe DrawTextureRec wrapper with validation
    //------------------------------------------------------------------------------------
    inline void SafeDrawTextureRec(const RenderTexture2D& tex, Rectangle sourceRect, Vector2 pos, Color tint, const char* context = "SafeDrawTextureRec") {
        if (tex.id == 0) {
            SPDLOG_ERROR("[{}] Attempted to draw invalid texture", context);
            return;
        }
        
        // Clamp sourceRect to valid bounds
        float maxY = (float)tex.texture.height;
        float maxX = (float)tex.texture.width;
        
        // Handle flipped rectangles properly
        if (sourceRect.height < 0) {
            // Flipped vertically
            float absHeight = std::abs(sourceRect.height);
            if (sourceRect.y - absHeight < 0) {
                // Adjust to prevent going out of bounds when flipped
                absHeight = sourceRect.y;
                sourceRect.height = -absHeight;
            }
        } else {
            // Normal orientation
            if (sourceRect.y < 0) sourceRect.y = 0;
            if (sourceRect.y > maxY) sourceRect.y = maxY;
            if (sourceRect.y + sourceRect.height > maxY) {
                sourceRect.height = maxY - sourceRect.y;
            }
        }
        
        // Clamp X axis
        if (sourceRect.width < 0) {
            // Flipped horizontally
            float absWidth = std::abs(sourceRect.width);
            if (sourceRect.x - absWidth < 0) {
                absWidth = sourceRect.x;
                sourceRect.width = -absWidth;
            }
        } else {
            // Normal orientation
            if (sourceRect.x < 0) sourceRect.x = 0;
            if (sourceRect.x > maxX) sourceRect.x = maxX;
            if (sourceRect.x + sourceRect.width > maxX) {
                sourceRect.width = maxX - sourceRect.x;
            }
        }
        
        DrawTextureRec(tex.texture, sourceRect, pos, tint);
    }

    // FIX: Safe unload with complete state reset
    inline void ShaderPipelineUnload() {
        if (ping.id != 0) {
            UnloadRenderTexture(ping);
            ping = {};
        }
        if (pong.id != 0) {
            UnloadRenderTexture(pong);
            pong = {};
        }
        if (baseCache.id != 0) {
            UnloadRenderTexture(baseCache);
            baseCache = {};
        }
        if (postPassCache.id != 0) {
            UnloadRenderTexture(postPassCache);
            postPassCache = {};
        }
        
        // Reset all state
        width = 0;
        height = 0;
        lastWasFront = true;
        lastRenderRect = {0, 0, 0, 0};
        baseCacheValid = false;
        postPassCacheValid = false;
    }
    
    // Debug storage & helpers
    inline std::vector<Rectangle> debugRects;

    inline void ResetDebugRects() {
        debugRects.clear();
    }

    inline void RecordDebugRect(const Rectangle &r) {
        debugRects.push_back(r);
    }

    inline void DebugDrawAllRects(int screenX = 0, int screenY = 0) {
        // 1) draw the whole front() canvas in the corner
        (void)screenX;
        (void)screenY;

        // 2) overlay each recorded rect with a distinct color
        const Color colors[] = { RED, GREEN, BLUE, YELLOW, MAGENTA, GRAY };
        for (size_t i = 0; i < debugRects.size(); ++i) {
            Rectangle r = debugRects[i];
            // remember: DebugDrawFront flips Y internally, so flip back:
            float drawY = screenY + (height - (r.y + r.height));
            DrawRectangleLines(
                screenX + (int)r.x,
                (int)drawY,
                (int)r.width,
                (int)r.height,
                colors[i % (sizeof(colors)/sizeof(colors[0]))]
            );
        }
    }

    inline void DebugDrawLastRenderRect(int screenX = 0, int screenY = 0) {
        // draw the entire front() texture so you can see the full canvas
        DrawTextureRec(
            front().texture,
            { 0, 0, (float)width, -(float)height },
            { (float)screenX, (float)screenY },
            WHITE
        );
    
        // overlay the exact sub-rectangle you just rendered, in red
        Rectangle r = lastRenderRect;
        // because DebugDrawFront flips Y internally, r.y is from top of that texture
        DrawRectangleLines(
            screenX + (int)r.x,
            screenY + (int)(height - r.y - r.height),  // flip Y back for screen coords
            (int)r.width,
            (int)r.height,
            RED
        );
    }
    
    // FIX: Added validation to initialization
    inline void ShaderPipelineInit(int w, int h) {
        if (w <= 0 || h <= 0) {
            SPDLOG_ERROR("Invalid dimensions for shader pipeline: {}x{}", w, h);
            return;
        }
        
        width = w;
        height = h;
        SPDLOG_DEBUG("Initializing shader pipeline with dimensions: {}x{}", w, h);
        
        ping = LoadRenderTexture(w, h);
        pong = LoadRenderTexture(w, h);
        baseCache = LoadRenderTexture(w, h);
        postPassCache = LoadRenderTexture(w, h);
        
        // Validate all textures loaded successfully
        if (ping.id == 0 || pong.id == 0 || baseCache.id == 0 || postPassCache.id == 0) {
            SPDLOG_ERROR("Failed to load render textures");
            ShaderPipelineUnload();
        }
    }

    // FIX: Thread-safe resize with validation
    inline bool Resize(int newWidth, int newHeight) {
        if (newWidth <= 0 || newHeight <= 0) {
            SPDLOG_ERROR("Invalid resize dimensions: {}x{}", newWidth, newHeight);
            return false;
        }
        
        if (newWidth == width && newHeight == height) {
            return true; // No resize needed
        }
        
        // Prevent concurrent resize
        bool expected = false;
        if (!isResizing.compare_exchange_strong(expected, true)) {
            SPDLOG_WARN("Resize already in progress, skipping");
            return false;
        }
        
        ShaderPipelineUnload();
        ShaderPipelineInit(newWidth, newHeight);
        
        isResizing.store(false);
        return IsInitialized();
    }

    inline void ClearTextures(Color color = {0, 0, 0, 0}) {
        if (!IsInitialized()) return;
        
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
        if (!IsInitialized()) return;
        
        DrawTextureRec(front().texture,
            {0, 0, (float)width, -(float)height},
            {(float)x, (float)y},
            WHITE
        );
    }

    inline void Swap() {
        std::swap(ping, pong);
    }

    // FIX: Safe render target tracking without raw pointers
    inline void SetLastRenderTarget(RenderTexture2D& tex) {
        lastWasFront = (&tex == &ping);
    }

    inline RenderTexture2D& GetLastRenderTarget() {
        return lastWasFront ? front() : back();
    }

    inline void SetLastRenderRect(Rectangle rect) {
        lastRenderRect = rect;
    }

    inline Rectangle GetLastRenderRect() {
        return lastRenderRect;
    }

    //------------------------------------------------------------------------------------
    // FIX #2: RAII Guard for Render Target Management
    //------------------------------------------------------------------------------------
    class RenderTargetGuard {
    private:
        bool active = false;
        
    public:
        RenderTargetGuard() = default;
        
        // Push a render target and track it
        void push(RenderTexture2D& target) {
            if (active) {
                SPDLOG_ERROR("RenderTargetGuard: Attempted to push while already active!");
                return;
            }
            if (target.id == 0) {
                SPDLOG_ERROR("RenderTargetGuard: Attempted to push invalid texture (id=0)");
                return;
            }
            BeginTextureMode(target);
            active = true;
        }
        
        // Manual pop if needed
        void pop() {
            if (active) {
                EndTextureMode();
                active = false;
            }
        }
        
        // RAII cleanup
        ~RenderTargetGuard() {
            if (active) {
                EndTextureMode();
                active = false;
            }
        }
        
        // Non-copyable, non-movable for safety
        RenderTargetGuard(const RenderTargetGuard&) = delete;
        RenderTargetGuard& operator=(const RenderTargetGuard&) = delete;
        RenderTargetGuard(RenderTargetGuard&&) = delete;
        RenderTargetGuard& operator=(RenderTargetGuard&&) = delete;
        
        bool isActive() const { return active; }
    };
    
    //------------------------------------------------------------------------------------
    // FIX #8: RAII Guard for Matrix Stack Management
    //------------------------------------------------------------------------------------
    class MatrixStackGuard {
    private:
        bool pushed = false;
        int maxDepth = 32;  // Raylib's default rlgl matrix stack depth
        static inline thread_local int currentDepth = 0;
        
    public:
        MatrixStackGuard() = default;
        
        // Push a matrix transformation
        bool push() {
            if (pushed) {
                SPDLOG_ERROR("MatrixStackGuard: Already pushed!");
                return false;
            }
            
            if (currentDepth >= maxDepth - 1) {
                SPDLOG_ERROR("MatrixStackGuard: Matrix stack overflow! Depth: {}/{}", currentDepth, maxDepth);
                return false;
            }
            
            rlPushMatrix();
            pushed = true;
            currentDepth++;
            return true;
        }
        
        // Manual pop if needed
        void pop() {
            if (pushed) {
                rlPopMatrix();
                pushed = false;
                currentDepth--;
            }
        }
        
        // RAII cleanup
        ~MatrixStackGuard() {
            if (pushed) {
                rlPopMatrix();
                pushed = false;
                currentDepth--;
            }
        }
        
        // Non-copyable, non-movable
        MatrixStackGuard(const MatrixStackGuard&) = delete;
        MatrixStackGuard& operator=(const MatrixStackGuard&) = delete;
        MatrixStackGuard(MatrixStackGuard&&) = delete;
        MatrixStackGuard& operator=(MatrixStackGuard&&) = delete;
        
        static int getDepth() { return currentDepth; }
        static void resetDepth() { currentDepth = 0; }  // Emergency reset
    };
    
    //------------------------------------------------------------------------------------
    // FIX #6: RAII Guard for Render Stack Management
    //------------------------------------------------------------------------------------
    class RenderStackGuard {
    private:
        std::stack<RenderTexture2D>* stackPtr = nullptr;
        bool pushed = false;
        const int MAX_STACK_DEPTH = 16;
        
    public:
        explicit RenderStackGuard(std::stack<RenderTexture2D>& stack) : stackPtr(&stack) {}
        
        bool push(RenderTexture2D& target) {
            if (pushed) {
                SPDLOG_ERROR("RenderStackGuard: Already pushed!");
                return false;
            }
            
            if (stackPtr->size() >= MAX_STACK_DEPTH) {
                SPDLOG_ERROR("RenderStackGuard: Stack overflow! Size: {}", stackPtr->size());
                return false;
            }
            
            if (target.id == 0) {
                SPDLOG_ERROR("RenderStackGuard: Invalid texture (id=0)");
                return false;
            }
            
            // End previous render target if exists
            if (!stackPtr->empty()) {
                EndTextureMode();
            }
            
            stackPtr->push(target);
            BeginTextureMode(target);
            pushed = true;
            return true;
        }
        
        void pop() {
            if (!pushed || !stackPtr || stackPtr->empty()) {
                return;
            }
            
            EndTextureMode();
            stackPtr->pop();
            
            // Resume previous target if exists
            if (!stackPtr->empty()) {
                BeginTextureMode(stackPtr->top());
            }
            
            pushed = false;
        }
        
        ~RenderStackGuard() {
            if (pushed && stackPtr && !stackPtr->empty()) {
                EndTextureMode();
                stackPtr->pop();
                
                if (!stackPtr->empty()) {
                    BeginTextureMode(stackPtr->top());
                }
            }
        }
        
        // Non-copyable, non-movable
        RenderStackGuard(const RenderStackGuard&) = delete;
        RenderStackGuard& operator=(const RenderStackGuard&) = delete;
        RenderStackGuard(RenderStackGuard&&) = delete;
        RenderStackGuard& operator=(RenderStackGuard&&) = delete;
    };

    // FIX: Add memory usage tracking
    inline size_t GetMemoryUsage() {
        size_t total = 0;
        if (ping.id != 0) total += width * height * 4; // RGBA
        if (pong.id != 0) total += width * height * 4;
        if (baseCache.id != 0) total += width * height * 4;
        if (postPassCache.id != 0) total += width * height * 4;
        return total;
    }

    inline void LogMemoryUsage() {
        size_t bytes = GetMemoryUsage();
        SPDLOG_INFO("Shader pipeline memory usage: {:.2f} MB", bytes / (1024.0f * 1024.0f));
    }
    
    //------------------------------------------------------------------------------------
    // FIX: Concurrent rendering detection
    //------------------------------------------------------------------------------------
    inline bool CheckConcurrentRender(int entityId) {
        int expected = -1;
        if (!currentRenderingEntity.compare_exchange_strong(expected, entityId)) {
            SPDLOG_ERROR("Concurrent render detected! Current entity: {}, New entity: {}",
                         expected, entityId);
            return false;
        }
        return true;
    }
    
    inline void ClearRenderingEntity() {
        currentRenderingEntity.store(-1);
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
            "injectAtlasUniforms",   &shader_pipeline::ShaderPass::injectAtlasUniforms,
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
            "injectAtlasUniforms",   &shader_pipeline::ShaderOverlayDraw::injectAtlasUniforms,
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
        rec.record_property("shader_pipeline.ShaderOverlayDraw",
            { "injectAtlasUniforms",   "bool",               "Whether to inject atlas uniforms" });

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
                        
            "removeOverlay", &shader_pipeline::ShaderPipelineComponent::removeOverlay,
            "toggleOverlay", &shader_pipeline::ShaderPipelineComponent::toggleOverlay,
            "clearAll",      &shader_pipeline::ShaderPipelineComponent::clearAll,
            "type_id", []() { return entt::type_hash<shader_pipeline::ShaderPipelineComponent>::value(); }
        );
        rec.bind_function(lua, {"shader_pipeline", "ShaderPipelineComponent"}, "addOverlay",
            // wrapper lambda so last parameter is optional in Lua
            [](shader_pipeline::ShaderPipelineComponent &self,
               OverlayInputSource src,
               std::string_view name,
               sol::optional<BlendMode> blendOpt
            ) -> ShaderOverlayDraw {
                return self.addOverlay(
                    src,
                    name,
                    blendOpt.value_or(BlendMode::BLEND_ALPHA)
                );
            },
            // EmmyLua docs: mark blend as nullable/optional
            "---@param src ShaderOverlayInputSource    # where the overlay samples from\n"
            "---@param name string                      # your overlay's name\n"
            "---@param blend BlendMode?                 # optional blend mode (default BLEND_ALPHA)\n"
            "---@return ShaderOverlayDraw               # the newly-added overlay draw\n"
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
        (void)to_uniform_value; // suppress unused warning

        // 8) Free functions
        sp.set_function("ShaderPipelineUnload", &shader_pipeline::ShaderPipelineUnload);
        sp.set_function("ShaderPipelineInit",   &shader_pipeline::ShaderPipelineInit);
        sp.set_function("Resize",               &shader_pipeline::Resize);
        sp.set_function("ClearTextures",        &shader_pipeline::ClearTextures);
        sp.set_function("DebugDrawFront",       &shader_pipeline::DebugDrawFront);
        sp.set_function("Swap",                 &shader_pipeline::Swap);
        sp.set_function("SetLastRenderTarget",  &shader_pipeline::SetLastRenderTarget);
        sp.set_function("GetLastRenderTarget",  sol::resolve<RenderTexture2D&()>(&shader_pipeline::GetLastRenderTarget));
        sp.set_function("SetLastRenderRect",    &shader_pipeline::SetLastRenderRect);
        sp.set_function("GetLastRenderRect",    &shader_pipeline::GetLastRenderRect);
        sp.set_function("SafeDrawTextureRec",   [](const RenderTexture2D& tex, Rectangle rect, Vector2 pos, Color tint) {
            shader_pipeline::SafeDrawTextureRec(tex, rect, pos, tint, "Lua");
        });
        sp.set_function("ValidateTextureRect",  [](const RenderTexture2D& tex, Rectangle rect) {
            return shader_pipeline::ValidateTextureRect(tex, rect, "Lua");
        });
        sp.set_function("GetMemoryUsage",       &shader_pipeline::GetMemoryUsage);
        sp.set_function("LogMemoryUsage",       &shader_pipeline::LogMemoryUsage);
        
        // --- Documentation for Free Functions ---
        rec.record_free_function({"shader_pipeline"}, {"ShaderPipelineUnload", "---@return nil", "Unloads the pipeline's internal render textures."});
        rec.record_free_function({"shader_pipeline"}, {"ShaderPipelineInit", "---@param width integer\n---@param height integer\n---@return nil", "Initializes or re-initializes the pipeline's render textures to a new size."});
        rec.record_free_function({"shader_pipeline"}, {"Resize", "---@param newWidth integer\n---@param newHeight integer\n---@return boolean", "Resizes the pipeline's render textures if the new dimensions are different. Returns true on success."});
        rec.record_free_function({"shader_pipeline"}, {"ClearTextures", "---@param color? Color\n---@return nil", "Clears the pipeline's internal textures to a specific color (defaults to transparent).", true});
        rec.record_free_function({"shader_pipeline"}, {"DebugDrawFront", "---@param x? integer\n---@param y? integer\n---@return nil", "Draws the current 'front' render texture for debugging purposes."});
        rec.record_free_function({"shader_pipeline"}, {"Swap", "---@return nil", "Swaps the internal 'ping' and 'pong' render textures."});
        rec.record_free_function({"shader_pipeline"}, {"SetLastRenderTarget", "---@param texture RenderTexture2D\n---@return nil", "Internal helper to track the last used render target."});
        rec.record_free_function({"shader_pipeline"}, {"GetLastRenderTarget", "---@return RenderTexture2D", "Internal helper to retrieve the last used render target."});
        rec.record_free_function({"shader_pipeline"}, {"SetLastRenderRect", "---@param rect Rectangle\n---@return nil", "Internal helper to track the last rendered rectangle area."});
        rec.record_free_function({"shader_pipeline"}, {"GetLastRenderRect", "---@return Rectangle", "Internal helper to retrieve the last rendered rectangle area."});
        rec.record_free_function({"shader_pipeline"}, {"SafeDrawTextureRec", "---@param texture RenderTexture2D\n---@param sourceRect Rectangle\n---@param pos Vector2\n---@param tint Color\n---@return nil", "Safely draws a texture rectangle with bounds validation."});
        rec.record_free_function({"shader_pipeline"}, {"GetMemoryUsage", "---@return integer", "Returns the total memory usage in bytes of all pipeline textures."});
        rec.record_free_function({"shader_pipeline"}, {"LogMemoryUsage", "---@return nil", "Logs the current memory usage of the shader pipeline."});
    }
}