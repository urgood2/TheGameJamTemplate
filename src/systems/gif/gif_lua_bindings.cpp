#include "gif_lua_bindings.hpp"
#include "gifLoadingAndPlayingSystem.hpp"
#include "systems/scripting/binding_recorder.hpp"

namespace gif_system {

void exposeToLua(sol::state& lua) {
    auto& rec = BindingRecorder::instance();

    // Create the gif module table
    auto gif_table = lua["gif"].get_or_create<sol::table>();

    // ---------------------------------------------------------
    // Core functions from gifLoadingAndPlayingSystem
    // ---------------------------------------------------------

    // gif.load(path, id) - Load a GIF file
    gif_table.set_function("load",
        [](const std::string& path, const std::string& id) {
            gif_system::loadGIF(path, id);
        });

    // gif.update(id) - Advance to next frame (call each frame)
    gif_table.set_function("update",
        [](const std::string& id) {
            gif_system::updateGIFOneFrame(id);
        });

    // gif.getTexture(id) - Get current frame as Texture2D
    gif_table.set_function("getTexture",
        [](const std::string& id) -> Texture2D {
            return gif_system::getCurrentFrame(id);
        });

    // gif.unloadAll() - Unload all loaded GIFs
    gif_table.set_function("unloadAll",
        []() {
            gif_system::unloadGifs();
        });

    // ---------------------------------------------------------
    // Helper functions for finer control
    // ---------------------------------------------------------

    // gif.setFrameDelay(id, delay) - Set frames to wait between animation advances
    gif_table.set_function("setFrameDelay",
        [](const std::string& id, int delay) {
            if (gifs.find(id) != gifs.end()) {
                gifs[id].frameDelay = delay;
            }
        });

    // gif.getFrameDelay(id) - Get current frame delay
    gif_table.set_function("getFrameDelay",
        [](const std::string& id) -> int {
            if (gifs.find(id) != gifs.end()) {
                return gifs[id].frameDelay;
            }
            return 0;
        });

    // gif.getFrameCount(id) - Get total number of frames
    gif_table.set_function("getFrameCount",
        [](const std::string& id) -> int {
            if (gifs.find(id) != gifs.end()) {
                return gifs[id].animFrames;
            }
            return 0;
        });

    // gif.getCurrentFrameIndex(id) - Get current frame index
    gif_table.set_function("getCurrentFrameIndex",
        [](const std::string& id) -> int {
            if (gifs.find(id) != gifs.end()) {
                return gifs[id].currentAnimFrame;
            }
            return 0;
        });

    // gif.isLoaded(id) - Check if a GIF is loaded
    gif_table.set_function("isLoaded",
        [](const std::string& id) -> bool {
            return gifs.find(id) != gifs.end();
        });

    // gif.unload(id) - Unload a specific GIF
    gif_table.set_function("unload",
        [](const std::string& id) {
            auto it = gifs.find(id);
            if (it != gifs.end()) {
                UnloadImage(it->second.image);
                UnloadTexture(it->second.texture);
                gifs.erase(it);
            }
        });

    // ---------------------------------------------------------
    // Documentation for binding recorder
    // ---------------------------------------------------------
    rec.add_type("gif").doc = "GIF loading and animation system for tutorial images";

    rec.record_property("gif", {
        "load",
        "---@param path string Path to GIF file\n---@param id string Unique identifier for this GIF",
        "Load a GIF file into memory"
    });

    rec.record_property("gif", {
        "update",
        "---@param id string GIF identifier",
        "Advance GIF animation by one tick (call each frame)"
    });

    rec.record_property("gif", {
        "getTexture",
        "---@param id string GIF identifier\n---@return Texture2D",
        "Get the current frame as a Texture2D for drawing"
    });

    rec.record_property("gif", {
        "unloadAll",
        "---@return nil",
        "Unload all loaded GIFs and free memory"
    });

    rec.record_property("gif", {
        "setFrameDelay",
        "---@param id string GIF identifier\n---@param delay integer Frames to wait between advances (default: 8)",
        "Set playback speed - lower values = faster animation"
    });

    rec.record_property("gif", {
        "getFrameDelay",
        "---@param id string GIF identifier\n---@return integer",
        "Get current frame delay setting"
    });

    rec.record_property("gif", {
        "getFrameCount",
        "---@param id string GIF identifier\n---@return integer",
        "Get total number of frames in the GIF"
    });

    rec.record_property("gif", {
        "getCurrentFrameIndex",
        "---@param id string GIF identifier\n---@return integer",
        "Get the current frame index (0-based)"
    });

    rec.record_property("gif", {
        "isLoaded",
        "---@param id string GIF identifier\n---@return boolean",
        "Check if a GIF with the given ID is loaded"
    });

    rec.record_property("gif", {
        "unload",
        "---@param id string GIF identifier",
        "Unload a specific GIF and free its memory"
    });
}

} // namespace gif_system
