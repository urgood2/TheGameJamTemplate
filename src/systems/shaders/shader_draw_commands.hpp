#pragma once

#include "raylib.h"
#include "shader_system.hpp"
#include "shader_pipeline.hpp"
#include <vector>
#include <string>
#include <functional>
#include <memory>
#include <unordered_map>

namespace shader_draw_commands {

/**
 * @enum DrawCommandType
 * @brief Types of draw commands that can be batched
 */
enum class DrawCommandType {
    BeginShader,
    EndShader,
    DrawTexture,
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
    Vector2 position;
    Color tint;

    // Uniforms to apply
    shaders::ShaderUniformSet uniforms;

    DrawCommand() : type(DrawCommandType::Custom), texture{0},
                    sourceRect{0,0,0,0}, position{0,0}, tint(WHITE) {}
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
        cmd.position = position;
        cmd.tint = tint;
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
                    DrawTextureRec(cmd.texture, cmd.sourceRect, cmd.position, cmd.tint);
                    break;

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
     * Groups commands by shader to reduce shader switching overhead
     */
    void optimize() {
        // Sort commands to group by shader while preserving drawing order within groups
        // This is a simplified optimization - could be made more sophisticated
        std::stable_sort(commands.begin(), commands.end(),
            [](const DrawCommand& a, const DrawCommand& b) {
                // Keep custom commands in order
                if (a.type == DrawCommandType::Custom || b.type == DrawCommandType::Custom) {
                    return false;
                }
                // Group shader-related commands together
                if (a.type == DrawCommandType::BeginShader && b.type != DrawCommandType::BeginShader) {
                    return true;
                }
                if (a.shaderName < b.shaderName) {
                    return true;
                }
                return false;
            });
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

} // namespace shader_draw_commands
