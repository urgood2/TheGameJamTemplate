#include "utilities.hpp"


#include "raylib.h" // raylib
#include "entt/entt.hpp" // ECS
#include "tweeny.h" // tweening library

#include "../components/components.hpp"

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
#include "magic_enum/magic_enum.hpp" // https://github.com/Neargye/magic_enum
// #include "behaviortree_cpp_v3/bt_factory.h" // https://github.com/BehaviorTree/BehaviorTree.CPP/tree/v3.8/

#include "../components/components.hpp"
#include "../components/graphics.hpp"
#include "../core/globals.hpp" // global variables

#include "systems/uuid/uuid.hpp" // uuid
#include "raylib.h"

#include <nlohmann/json.hpp> // nlohmann JSON parsing

#include <string>

#include <boost/regex.hpp> 
#include <boost/algorithm/string/replace.hpp>

using std::string;
using json = nlohmann::json;

namespace util {
    
    std::string getAssetPathUUIDVersion(const std::string path_uuid_or_raw_identifier) { // path below the assets folder {
        auto path = uuid::lookup(path_uuid_or_raw_identifier);
        using namespace snowhouse;
        AssertThat(path, Is().Not().EqualTo(""));
        //  Replace all backslashes with forward slashes for consistency
        std::replace(path.begin(), path.end(), '\\', '/');
        return path;
    }

    auto getRawAssetPathNoUUID(const string assetName) -> string {
        return ASSETS_PATH "" + assetName;
    }

    // a custom version that takes the tint color
    void rlImGuiImageRect(const Texture* image, int destWidth, int destHeight, Rectangle sourceRect, ImVec4 tintColor)
    {
        ImVec2 uv0;
        ImVec2 uv1;

        if (sourceRect.width < 0)
        {
            uv0.x = -((float)sourceRect.x / image->width);
            uv1.x = (uv0.x - (float)(fabs(sourceRect.width) / image->width));
        }
        else
        {
            uv0.x = (float)sourceRect.x / image->width;
            uv1.x = uv0.x + (float)(sourceRect.width / image->width);
        }

        if (sourceRect.height < 0)
        {
            uv0.y = -((float)sourceRect.y / image->height);
            uv1.y = (uv0.y - (float)(fabs(sourceRect.height) / image->height));
        }
        else
        {
            uv0.y = (float)sourceRect.y / image->height;
            uv1.y = uv0.y + (float)(sourceRect.height / image->height);
        }

        ImGui::Image((ImTextureID)image, ImVec2(float(destWidth), float(destHeight)), uv0, uv1, tintColor);
    }

    float easeOutExpo(float x)
    {
        return x == 1 ? 1 : 1 - pow(2, -10 * x);
    }

    ImTextCustomization textCustomization{};

    // draws a color coded string using ImGui::TextUnformatted
    auto drawColorCodedTextUnformatted(const std::string& text) -> void {
        textCustomization.Clear();

        auto entry = processText(text);

        // now draw
        for (int i = 0; i < entry.colorRanges.size(); i++) {
            auto start = entry.colorRanges[i].first;
            auto end = entry.colorRanges[i].second;
            auto color = entry.colors[i];
            textCustomization.Range(entry.text.c_str() + start, entry.text.c_str() + end).TextColor(color);
        }

        //replace chars in the string that are ` with a random char
        for (int i = 0; i < entry.text.size(); i++) {
            if (entry.text[i] == '`') {
                entry.text[i] = Random::get<char>('a', 'z');
            }
        }

        ImGui::TextUnformatted(entry.text.c_str(), NULL, true, false, &textCustomization);
    }


    // surrounds an entire string with color tags in the format [color:r:g:b]text[/color]
    auto surroundWithColorTags(const std::string& text, const std::string& color) -> std::string {

        auto colorRBG = getColor(color);
        std::string colorRGB = std::to_string(colorRBG.r) + ":" + std::to_string(colorRBG.g) + ":" + std::to_string(colorRBG.b);

        return "[color:" + colorRGB + "]" + text + "[/color]";
    }

    // Interprets color tags in the input string and returns a TextLogEntry with the processed text and color information.
    // supports named colors as well
    auto processText(const std::string& input) -> TextLogEntry {
        // Modified regex to support both RGB format and named colors
        boost::regex colorTagPattern(R"(\[color:(\d+:\d+:\d+|[a-zA-Z_]+)\](.*?)\[/color\])");
        boost::sregex_iterator iter(input.begin(), input.end(), colorTagPattern);
        boost::sregex_iterator end;

        TextLogEntry entry;
        std::string processedText;
        std::vector<std::pair<int, int>> ranges;
        int currentPos = 0;

        while (iter != end) {
            boost::smatch match = *iter;
            // Append text leading up to the color tag
            processedText += input.substr(currentPos, match.position() - currentPos);

            // Calculate and store the range for the colored text
            int start = processedText.length();
            int end = start + match[2].str().length(); // match[2] is the text inside the color tags
            ranges.push_back(std::make_pair(start, end));

            // Append the colored text
            processedText += match[2].str();

            // Check if it's an RGB color or a named color
            std::string colorValue = match[1].str(); // match[1] is the color part (RGB or name)
            if (colorValue.find(':') != std::string::npos) {
                // RGB format detected, split the values
                int r, g, b;
                sscanf(colorValue.c_str(), "%d:%d:%d", &r, &g, &b);
                entry.colors.push_back(ImColor(r, g, b));
            } else {
                // Named color detected, look it up in the map
                entry.colors.push_back(getColorImVec(colorValue));
            }

            // Update the current position in the input string
            currentPos = match.position() + match.length();
            ++iter;
        }

        // Append any remaining text after the last color tag
        processedText += input.substr(currentPos);

        entry.text = processedText;
        entry.colorRanges = ranges;

        return entry;
    }
    
    auto convertCP437TextToJSON() -> void {
        std::ifstream input_stream(util::getAssetPathUUIDVersion("raws/cp437 temp"));
        
        // check stream status
        if (!input_stream) std::cerr << "Can't open input file!";  
        
        vector<string> fileContents{};
        
        string line;
        
        while (std::getline(input_stream, line)) {
            fileContents.push_back(line);
        }
        
        // read through each line 
        // tokenize by []:
        // first three values are rgb
        // last value, trimmed, is the name
        
        nlohmann::ordered_json root{"[]"};
        
        int lineNo{0};
        
        
        for (string &line : fileContents) {
            boost::trim(line);
            
            if (line.empty()) {
                lineNo++;
                continue;
                
            }
            
            vector<string> result;
            boost::split(result, line, boost::is_any_of("\t */,"), boost::token_compress_on);
            
            // line 44 is comma
            // line 42 is *
            // line 47 is /
            
            //     [ 
            //         "sprite_number": ,
            //         "char_cp437": ,
            //         "codepoint"
            //     ]
            
            string char_cp437 = result.at(1);
            boost::trim(char_cp437);
            
            SPDLOG_DEBUG("Got tokens {}, {} for line \"{}\"", result.at(0), result.at(1), line);
            
            nlohmann::ordered_json charNode{};
            charNode["sprite_number"] = lineNo;
            charNode["char_cp437"] = char_cp437;
            charNode["codepoint_UTF16"] = result.at(0);
            
            SPDLOG_DEBUG("Resulting cp437 node: {}", charNode.dump());
            
            root.insert(root.end(), charNode);
            
            lineNo++;
        }
        std::ofstream o(util::getAssetPathUUIDVersion("raws/save_cp437.json"));
        SPDLOG_DEBUG("Saving json: {}", root.dump());
        o << std::setw(4) << root << std::endl;
    }

    auto convertColorsFileToJSON() -> void {
        
        std::ifstream input_stream(util::getAssetPathUUIDVersion("raws/colors.txt"));
        
        // check stream status
        if (!input_stream) std::cerr << "Can't open input file!";  
        
        vector<string> fileContents{};
        
        string line;
        
        while (std::getline(input_stream, line)) {
            fileContents.push_back(line);
        }
        
        
        // read through each line 
        // tokenize by []:
        // first three values are rgb
        // last value, trimmed, is the name
        
        nlohmann::ordered_json root{"[]"};
        
        string family{"null"};
        for (string &line : fileContents) {
            boost::trim(line);
            
            if (line.empty()) continue;
            
            vector<string> result;
            boost::split(result, line, boost::is_any_of("][:c"), boost::token_compress_on);
            
            // ignore if line has only one token
            if (result.size() <= 2) {
                SPDLOG_DEBUG("Got family name {}", result.at(0));
                family = result.at(0);
                continue;
            }
            
            
            string name = result.at(4);
            boost::trim(name);
            
            SPDLOG_DEBUG("Got tokens {}, {}, {}, and {} for line [{}]", result.at(1), result.at(2), result.at(3), name, line);
            
            nlohmann::ordered_json colorNode{};
            boost::to_upper(name);
            colorNode["name"] = name;
            colorNode["r"] = result.at(1);
            colorNode["g"] = result.at(2);
            colorNode["b"] = result.at(3);
            colorNode["family"] = family;
            
            SPDLOG_DEBUG("Resulting color node: {}", colorNode.dump());
            
            root.insert(root.end(), colorNode);
        }
        
        SPDLOG_DEBUG("Got color array: {}", root.dump());
    }



    // Converts a raylib Color to an ImVec4 color.
    // The resulting ImVec4 color has its components normalized to the range [0, 1].
    // Parameters:
    // - c: the raylib Color to convert.
    // Returns: the resulting ImVec4 color.
    auto raylibColorToImVec(const Color &c) -> ImVec4 {
        return ImVec4(c.r / 255.0f, c.g / 255.0f, c.b / 255.0f, c.a / 255.0f);
    }

    // Replaces all tokens in the given string with the corresponding values in the given map.
    // Token format: [tokenName], e.g., [ATTACKER_NAME], but do not include the brackets in the token map.
    auto replaceAllTokensInString(const std::string& templateStr, const std::map<std::string, std::string>& tokens) -> std::string {
        std::string result = templateStr;
        for (const auto& token : tokens) {
            std::string placeholder = token.first ;
            // SPDLOG_DEBUG("Calling replace_all on [{}] with token {}", result, placeholder);
            boost::replace_all(result, placeholder, token.second);
            // SPDLOG_DEBUG("---Result after replace_all: [{}]", result);
        }
        return result;
    }

    /**
     * Returns a random synonym for the given word, using thesaurusJSON data.
     * If an error occurs during processing, an error message is logged and "ERROR" is returned.
     *
     * @param word The word to find a synonym for.
     * @return A random synonym for the given word, or "ERROR" if an error occurs.
     */
    auto getRandomSynonymFor(const string &word) -> string {
        try
        {
            int synEntries = globals::thesaurusJSON.at(word).size();
            return globals::thesaurusJSON.at(word).at(Random::get<int>(0, synEntries - 1));
        }
        catch(const std::exception& e)
        {
            SPDLOG_ERROR("Synonym processing error for {}: {}", word, e.what());
            return "ERROR";
        }
    }

    // Returns the tile coordinates of the mouse position in world space.
    // Uses the camera and the SpriteComponentASCII of the first tile in the map to calculate the tile coordinates.
    auto getTileCoordsAtMousePos() -> Vector2 {
        auto pos = GetScreenToWorld2D(GetMousePosition(), globals::camera);
        
        // translate to world space
        
        // get tile location, make sure is valid
        SpriteComponentASCII &sc = globals::registry.get<SpriteComponentASCII>(globals::map[0][0]);
        
        pos.x = (int)(pos.x / sc.spriteFrame.width);
        pos.y = (int)(pos.y / sc.spriteFrame.height);
        
        
        
        return pos;
    }


    // Determines if a given tile location is within the bounds of the map.
    // Returns true if the tile is within bounds, false otherwise.
    auto isTileWithinBounds(const Vector2 &tileLoc) -> bool {
        bool isWithinBounds = (tileLoc.x >= 0 && tileLoc.y >= 0 && tileLoc.x < globals::map.size() && tileLoc.y < globals::map[0].size());
        return isWithinBounds;
    }
    
    auto getDistance(float x1, float y1, float x2, float y2) -> float {
        return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
    }

    // color name should be from colors.json
    auto getColorImVec(const string& colorName) -> ImVec4 {
        auto c = getColor(colorName);
        return ImVec4(c.r / 255.0f, c.g / 255.0f, c.b / 255.0f, c.a / 255.0f);
    }

    // color name from colors.json
    // Note that this method is not case sensitive - all names are converted to uppercase
    Color getColor(std::string colorName_or_uuid) {
    return globals::colorsMap[uuid::lookup(colorName_or_uuid)];
}

    auto toUnsignedChar(string value) -> unsigned char {
        
        int i = std::stoi(value);
        unsigned char c{};
        
        c = i & 0xFF;
        
        return c;
    }


}