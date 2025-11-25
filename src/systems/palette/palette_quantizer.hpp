#pragma once

#include <string>
#include "raylib.h"
#include "core/globals.hpp"
#include "systems/shaders/shader_system.hpp"



namespace palette_quantizer {

// Inline storage for the loaded palette texture
static inline Texture2D paletteTex = {0};

/**
 * @brief Loads a palette texture from a file, unloads any previous one,
 *        sets point filtering, and uploads it to the given shader. The palette should be a 1D texture (think lospec palette).
 * 
 * @param shaderName Name of the shader in globalShaderUniforms.
 * @param filePath   Path to the palette image file.
 * @return true      If loading and upload succeed.
 * @return false     If loading fails.
 */
inline bool setPaletteTexture(const std::string &shaderName, const std::string &filePath)
{
    // Unload previous texture if present
    if (paletteTex.id != 0) {
        UnloadTexture(paletteTex);
    }

    // Load new palette texture
    paletteTex = LoadTexture(filePath.c_str());
    if (paletteTex.id == 0) {
        return false;
    }

    // Use point filtering for exact palette lookups
    SetTextureFilter(paletteTex, TEXTURE_FILTER_POINT);

    // Upload to shader uniforms
    globals::getGlobalShaderUniforms().set(shaderName, "palette", paletteTex);

    return true;
}

/**
 * @brief Unloads the currently loaded palette texture, if any.
 */
inline void unloadPaletteTexture()
{
    if (paletteTex.id != 0) {
        UnloadTexture(paletteTex);
        paletteTex.id = 0;
    }
}

} // namespace PaletteQuantizer
