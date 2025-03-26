#pragma once

#include <raylib.h>
#include <map>
#include <string>


namespace gif_system
{
    
    struct GifData {
        // Load all GIF animation frames into a single Image
        // NOTE: GIF data is always loaded as RGBA (32bit) by default
        // NOTE: Frames are just appended one after another in image.data memory

        Image image;
        // Load texture from image
        // NOTE: We will update this texture when required with next frame data
        // WARNING: It's not recommended to use this technique for sprites animation,
        // use spritesheets instead, like illustrated in textures_sprite_anim example
        Texture2D texture;
        int animFrames = 0;
        int nextFrameDataOffset = 0;  // Current byte offset to next frame in image.data
        int currentAnimFrame = 0;       // Current animation frame to load and draw
        int frameDelay = 8;             // Frame delay to switch between animation frames
        int frameCounter = 0;		   // General frames counter
    };

    extern std::map<std::string, GifData> gifs;
    
    
    extern auto loadGIF(std::string gifPath, std::string identifier) -> void;
    
    extern auto updateGIFOneFrame(std::string identifier) -> void;
    
    extern auto getCurrentFrame(std::string identifier) -> Texture2D;
    
    extern auto unloadGifs() -> void ;

} // namespace gif_system
