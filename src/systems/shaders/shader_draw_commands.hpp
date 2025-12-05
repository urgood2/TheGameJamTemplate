#pragma once

#include "raylib.h"
#include "shader_system.hpp"
#include "shader_pipeline.hpp"
#include "systems/layer/layer_optimized.hpp"
#include "systems/layer/layer_command_buffer.hpp"
#include "entt/entt.hpp"
#include <vector>
#include <string>
#include <functional>
#include <memory>
#include <unordered_map>

namespace shader_draw_commands {

struct OwnedDrawCommand {
    layer::DrawCommandV2 cmd;
    std::shared_ptr<void> owner; // keeps command data alive
    bool forceTextPass = false;   // allow routing to text pass (e.g., text)
    bool forceUvPassthrough = false; // force uv_passthrough for 3d_skew without text pass
    bool forceStickerPass = false; // route to sticker pass (identity atlas, after overlays)
};

struct BatchedLocalCommands {
    std::vector<OwnedDrawCommand> commands;
    void clear() { commands.clear(); }
};

/**
 * @enum DrawCommandType
 * @brief Types of draw commands that can be batched
 */
enum class DrawCommandType {
    BeginShader,
    EndShader,
    DrawTexture,
    DrawText,
    SetUniforms,
    Custom
};

/**
 * @struct DrawCommand
 * @brief Represents a single draw command in the batch
 */
struct DrawCommand {
    DrawCommandType type;
    std::string shaderName;
    std::function<void()> customFunction;

    // Data for texture drawing
    Texture2D texture;
    Rectangle sourceRect;
    Rectangle destRect;
    Vector2 origin;
    float rotation;
    Color tint;
    bool useDestRect;

    // Data for text drawing
    std::string text;
    Font font;
    float fontSize{0.0f};
    float spacing{0.0f};
    Vector2 textPos{0.0f, 0.0f};

    // Uniforms to apply
    shaders::ShaderUniformSet uniforms;

    DrawCommand() : type(DrawCommandType::Custom), texture{0},
                    sourceRect{0,0,0,0}, destRect{0,0,0,0},
                    origin{0,0}, rotation(0.0f), tint(WHITE),
                    useDestRect(false), font{0}, fontSize(0.0f),
                    spacing(0.0f), textPos{0.0f, 0.0f} {}
};

/**
 * @class DrawCommandBatch
 * @brief Manages a batch of draw commands for optimized rendering
 *
 * This class allows you to queue up draw commands and execute them
 * in an optimized order, minimizing shader state changes and texture swaps.
 */
class DrawCommandBatch {
private:
    std::vector<DrawCommand> commands;
    bool isRecording = false;

public:
    /**
     * @brief Start recording draw commands
     */
    void beginRecording() {
        commands.clear();
        isRecording = true;
    }

    /**
     * @brief Stop recording draw commands
     */
    void endRecording() {
        isRecording = false;
    }

    /**
     * @brief Check if currently recording
     */
    bool recording() const {
        return isRecording;
    }

    /**
     * @brief Add a shader begin command
     */
    void addBeginShader(const std::string& shaderName) {
        if (!isRecording) return;
        DrawCommand cmd;
        cmd.type = DrawCommandType::BeginShader;
        cmd.shaderName = shaderName;
        commands.push_back(cmd);
    }

    /**
     * @brief Add a shader end command
     */
    void addEndShader() {
        if (!isRecording) return;
        DrawCommand cmd;
        cmd.type = DrawCommandType::EndShader;
        commands.push_back(cmd);
    }

    /**
     * @brief Add a texture draw command
     */
    void addDrawTexture(Texture2D texture, Rectangle sourceRect,
                        Vector2 position, Color tint = WHITE) {
        if (!isRecording) return;
        DrawCommand cmd;
        cmd.type = DrawCommandType::DrawTexture;
        cmd.texture = texture;
        cmd.sourceRect = sourceRect;
        cmd.destRect = {position.x, position.y, sourceRect.width, sourceRect.height};
        cmd.origin = {0.0f, 0.0f};
        cmd.rotation = 0.0f;
        cmd.useDestRect = false;
        cmd.tint = tint;
        commands.push_back(cmd);
    }

    /**
     * @brief Add a texture draw command with destination rectangle and rotation
     */
    void addDrawTexturePro(Texture2D texture, Rectangle sourceRect,
                           Rectangle destRect, Vector2 origin,
                           float rotationDeg, Color tint = WHITE) {
        if (!isRecording) return;
        DrawCommand cmd;
        cmd.type = DrawCommandType::DrawTexture;
        cmd.texture = texture;
        cmd.sourceRect = sourceRect;
        cmd.destRect = destRect;
        cmd.origin = origin;
        cmd.rotation = rotationDeg;
        cmd.useDestRect = true;
        cmd.tint = tint;
        commands.push_back(cmd);
    }

    /**
     * @brief Add a text draw command
     */
    void addDrawText(const std::string& text, Vector2 position, float fontSize,
                     float spacing, Color color = WHITE, Font font = GetFontDefault()) {
        if (!isRecording) return;
        DrawCommand cmd;
        cmd.type = DrawCommandType::DrawText;
        cmd.text = text;
        cmd.textPos = position;
        cmd.fontSize = fontSize;
        cmd.spacing = spacing;
        cmd.tint = color;
        cmd.font = font;
        commands.push_back(cmd);
    }

    /**
     * @brief Add a uniform set command
     */
    void addSetUniforms(const std::string& shaderName,
                        const shaders::ShaderUniformSet& uniforms) {
        if (!isRecording) return;
        DrawCommand cmd;
        cmd.type = DrawCommandType::SetUniforms;
        cmd.shaderName = shaderName;
        cmd.uniforms = uniforms;
        commands.push_back(cmd);
    }

    /**
     * @brief Add a custom function command
     */
    void addCustomCommand(std::function<void()> func) {
        if (!isRecording) return;
        DrawCommand cmd;
        cmd.type = DrawCommandType::Custom;
        cmd.customFunction = func;
        commands.push_back(cmd);
    }

    /**
     * @brief Execute all recorded commands in order
     */
    void execute() {
        std::string currentShader;
        bool shaderActive = false;

        for (const auto& cmd : commands) {
            switch (cmd.type) {
                case DrawCommandType::BeginShader: {
                    if (shaderActive) {
                        EndShaderMode();
                    }
                    Shader shader = shaders::getShader(cmd.shaderName);
                    if (shader.id > 0) {
                        BeginShaderMode(shader);
                        currentShader = cmd.shaderName;
                        shaderActive = true;
                    }
                    break;
                }

                case DrawCommandType::EndShader:
                    if (shaderActive) {
                        EndShaderMode();
                        shaderActive = false;
                        currentShader.clear();
                    }
                    break;

                case DrawCommandType::DrawTexture:
                    if (cmd.useDestRect) {
                        DrawTexturePro(cmd.texture, cmd.sourceRect, cmd.destRect, cmd.origin, cmd.rotation, cmd.tint);
                    } else {
                        DrawTextureRec(cmd.texture, cmd.sourceRect, {cmd.destRect.x, cmd.destRect.y}, cmd.tint);
                    }
                    break;

                case DrawCommandType::DrawText: {
                    Font fontToUse = (cmd.font.texture.id != 0) ? cmd.font : GetFontDefault();
                    DrawTextEx(fontToUse,
                               cmd.text.c_str(),
                               cmd.textPos,
                               cmd.fontSize,
                               cmd.spacing,
                               cmd.tint);
                    break;
                }

                case DrawCommandType::SetUniforms:
                    if (shaderActive && cmd.shaderName == currentShader) {
                        Shader shader = shaders::getShader(cmd.shaderName);
                        shaders::ApplyUniformsToShader(shader, cmd.uniforms);
                    }
                    break;

                case DrawCommandType::Custom:
                    if (cmd.customFunction) {
                        cmd.customFunction();
                    }
                    break;
            }
        }

        // Clean up if shader still active
        if (shaderActive) {
            EndShaderMode();
        }
    }

    /**
     * @brief Optimize command order to minimize state changes
     * Keeps Begin/End ordering intact and removes redundant shader toggles.
     */
    void optimize() {
        if (commands.empty()) return;

        std::vector<DrawCommand> optimized;
        optimized.reserve(commands.size());

        bool shaderActive = false;
        std::string activeShader;

        auto endCurrentShader = [&](bool emitEnd) {
            if (!shaderActive) return;
            if (emitEnd) {
                DrawCommand endCmd;
                endCmd.type = DrawCommandType::EndShader;
                optimized.push_back(endCmd);
            }
            shaderActive = false;
            activeShader.clear();
        };

        for (const auto& cmd : commands) {
            switch (cmd.type) {
                case DrawCommandType::BeginShader: {
                    // If the same shader is already active, skip redundant begin.
                    if (shaderActive && cmd.shaderName == activeShader) {
                        continue;
                    }
                    // Close any different active shader before switching.
                    if (shaderActive && cmd.shaderName != activeShader) {
                        endCurrentShader(true);
                    }
                    optimized.push_back(cmd);
                    shaderActive = true;
                    activeShader = cmd.shaderName;
                    break;
                }
                case DrawCommandType::EndShader: {
                    if (shaderActive) {
                        optimized.push_back(cmd);
                        shaderActive = false;
                        activeShader.clear();
                    }
                    // Ignore stray end commands when no shader is active.
                    break;
                }
                default:
                    optimized.push_back(cmd);
                    break;
            }
        }

        // Ensure we don't leave a shader active at the end of the batch.
        endCurrentShader(true);

        commands.swap(optimized);
    }

    /**
     * @brief Clear all commands
     */
    void clear() {
        commands.clear();
    }

    /**
     * @brief Get the number of commands
     */
    size_t size() const {
        return commands.size();
    }

    /**
     * @brief Get command at index (for debugging)
     */
    const DrawCommand& getCommand(size_t index) const {
        return commands[index];
    }
};

/**
 * @brief Global draw command batch instance
 */
inline DrawCommandBatch globalBatch;

/**
 * @brief Helper function to execute a shader pipeline using draw commands
 * This is similar to DrawTransformEntityWithAnimationWithPipeline but uses
 * the command batching system for better performance
 */
void executeEntityPipelineWithCommands(
    entt::registry& registry,
    entt::entity e,
    DrawCommandBatch& batch,
    bool autoOptimize = false
);

/**
 * @brief Expose draw command system to Lua
 */
void exposeToLua(sol::state& lua);

// Utility: add a layer command (local space) to be drawn with the entity's shader pipeline.
template <typename T, typename Initializer>
inline void AddLocalCommand(entt::registry& registry, entt::entity e, int z,
                            layer::DrawCommandSpace space, Initializer&& init,
                            bool forceTextPass = false,
                            bool forceUvPassthrough = false,
                            bool forceStickerPass = false) {
    auto* comp = registry.try_get<BatchedLocalCommands>(e);
    if (!comp) {
        comp = &registry.emplace<BatchedLocalCommands>(e);
    }
    auto data = std::make_shared<T>();
    init(data.get());
    layer::DrawCommandV2 dc{};
    dc.type = layer::layer_command_buffer::GetDrawCommandType<T>();
    dc.data = data.get();
    dc.z = z;
    dc.space = space;
    OwnedDrawCommand owned{dc, data, forceTextPass, forceUvPassthrough, forceStickerPass};
    comp->commands.push_back(std::move(owned));
}

} // namespace shader_draw_commands
