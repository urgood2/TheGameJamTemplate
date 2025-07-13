#pragma once
/***
 * Contains general utility functions used throughout the game
*/

#include "raylib.h" // raylib
#include "entt/entt.hpp" // ECS
#include "raygui.h" // raylib gui
// #include "tweeny.h" // tweening library

#include <nlohmann/json.hpp> // nlohmann JSON parsing
using json = nlohmann::json;


// #include "unnamed.rgs.h"

#if defined(_WIN32)           
	#define NOGDI             // All GDI defines and routines
	#define NOUSER            // All USER defines and routines
#endif

#define SPDLOG_ACTIVE_LEVEL SPDLOG_LEVEL_DEBUG // compiler-time log level

#include "spdlog/spdlog.h" // SPD logging lib // or any library that uses Windows.h
#include "spdlog/sinks/basic_file_sink.h"

#if defined(_WIN32)           // raylib uses these names as function parameters
	#undef near
	#undef far
#endif

#if defined(PLATFORM_WEB)
    #include <emscripten/emscripten.h>
#endif

#include "effolkronium/random.hpp" // https://github.com/effolkronium/random
// #include "behaviortree_cpp_v3/bt_factory.h" // https://github.com/BehaviorTree/BehaviorTree.CPP/tree/v3.8/


#include "../core/globals.hpp" // global variables

#include "raylib.h"

#include <nlohmann/json.hpp> // nlohmann JSON parsing

#include <string>
#include <vector>
#include <map>

using std::string;
using json = nlohmann::json;
using std::string;
using std::vector;

namespace util {
	
	
#ifdef PROFILING_ON
    class Profiler {
        public:
            explicit Profiler(std::string_view name = "Unnamed") 
                : label(name), start(std::chrono::high_resolution_clock::now()) {}
        
            ~Profiler() {
                if (!stopped) {
                    Stop();
                }
            }
        
            void Stop() {
                if (stopped) return; // Prevent multiple stops
                auto end = std::chrono::high_resolution_clock::now();
                double duration = std::chrono::duration<double, std::milli>(end - start).count();
                spdlog::debug("[Profiler] {} took {} ms", label, duration);
                stopped = true;
            }
        
        private:
            std::string label;
            std::atomic<bool> stopped{false};
            std::chrono::time_point<std::chrono::high_resolution_clock> start;
        };
#else
    class Profiler {
        public:
            explicit Profiler(std::string_view name = "Unnamed") {}
            ~Profiler() {}
            void Stop() {}
    };
#endif

	struct TextLogEntry {
        std::string text;
        std::vector<ImColor> colors; // each color corresponds to a substring in the text
        // store pairs of integers that represent the start and end of the substring that should be colored
        std::vector<std::pair<int, int>> colorRanges;
    };

    // expose relevant functions to lua
    extern auto exposeToLua(sol::state &lua) -> void;
	
	// convenience methods
	extern auto getRawAssetPathNoUUID(const string assetName) -> string;
	extern auto getColor(string colorName) -> Color;
    extern std::string getAssetPathUUIDVersion(const std::string path_uuid_or_raw_identifier);
	extern auto raylibColorToImVec(const Color &c) -> ImVec4;
	extern auto getRandomSynonymFor(const string &word) -> string;
	extern auto toUnsignedChar(string value) -> unsigned char;


	extern auto getColorImVec(const string& colorName) -> ImVec4;
	extern auto replaceAllTokensInString(const std::string& templateStr, const std::map<std::string, std::string>& tokens) -> std::string;
	extern auto surroundWithColorTags(const std::string& text, const std::string& color) -> std::string;
	extern auto rlImGuiImageRect(const Texture* image, int destWidth, int destHeight, Rectangle sourceRect, ImVec4 tintColor) -> void;
	extern auto getTileCoordsAtMousePos() -> Vector2;
	extern auto isTileWithinBounds(const Vector2 &tileLoc) -> bool;
	extern auto getDistance(float x1, float y1, float x2, float y2) -> float;
	extern float easeOutExpo(float x);
    extern Texture2D GeneratePaletteTexture(const std::vector<Color>& colors);
    extern auto drawColorCodedTextUnformatted(const std::string& text) -> void;

	// text processing
	extern auto processText(const std::string& input) -> TextLogEntry;

	// test methods
	extern auto convertCP437TextToJSON() -> void;
	extern auto convertColorsFileToJSON() -> void;
}
