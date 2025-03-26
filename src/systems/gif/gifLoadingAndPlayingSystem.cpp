
#include <raylib.h>
#include <map>
#include <string>

#include "gifLoadingAndPlayingSystem.hpp"

namespace gif_system
{
auto loadGIF(std::string gifPath, std::string identifier) -> void;
    

    std::map<std::string, GifData> gifs;
    
    
    auto loadGIF(std::string gifPath, std::string identifier) -> void {
        GifData gifData;
        gifData.image = LoadImageAnim(gifPath.c_str(), &gifData.animFrames);
        gifData.texture = LoadTextureFromImage(gifData.image);
        gifData.nextFrameDataOffset = 0;
        gifData.currentAnimFrame = 0;
        gifData.frameDelay = 8;
        gifData.frameCounter = 0;
        gifs[identifier] = gifData;
    }
    
    // Update GIF animation frames of a given gif identifier
    auto updateGIFOneFrame(std::string identifier) -> void {
        auto &gifData = gifs[identifier];
        
        gifData.frameCounter++;
        if (gifData.frameCounter >= gifData.frameDelay)
        {
            // Move to next frame
            // NOTE: If final frame is reached we return to first frame
            gifData.currentAnimFrame++;
            if (gifData.currentAnimFrame >= gifData.animFrames) gifData.currentAnimFrame = 0;

            // Get memory offset position for next frame data in image.data
            gifData.nextFrameDataOffset = gifData.image.width*gifData.image.height*4*gifData.currentAnimFrame;

            // Update GPU texture data with next frame image data
            // WARNING: Data size (frame size) and pixel format must match already created texture
            UpdateTexture(gifData.texture, ((unsigned char *)gifData.image.data) + gifData.nextFrameDataOffset);

            gifData.frameCounter = 0;
        }
    }
    
    auto getCurrentFrame(std::string identifier) -> Texture2D {
        return gifs[identifier].texture;
    }
    
    // unload all gifs
    auto unloadGifs() -> void {
        for (auto &gif : gifs) {
            UnloadImage(gif.second.image);
            UnloadTexture(gif.second.texture);
        }
    }

} // namespace gif_system
