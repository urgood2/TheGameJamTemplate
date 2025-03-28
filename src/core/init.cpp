#include "init.hpp"
#include "graphics.hpp"
#include "globals.hpp"
#include "../components/components.hpp"
#include "../util/utilities.hpp"
#include "third_party/unify/unify.hpp"
#include "systems/uuid/uuid.hpp"

#include "../third_party/rlImGui/extras/FA6FreeSolidFontData.h"

#include "../systems/shaders/shader_system.hpp"
#include "../systems/sound/sound_system.hpp"

#include <chrono>

namespace init {
    
    void scanAssetsFolderAndAddAllPaths()
    {
        // read in all items & folders from assets folder for uuid checking & generation
        auto folderPath = util::getRawAssetPathNoUUID("");

        // This vector will store the paths of all files/folders encountered
        std::vector<std::string> subpaths;

        try
        {
            // Use a recursive_directory_iterator to go through subfolders as well.
            for (const auto &entry : std::filesystem::recursive_directory_iterator(folderPath))
            {
                // Convert the path to a string and add it to our vector
                subpaths.push_back(entry.path().string());
            }

            // Print out all the subpaths we collected
            for (const auto &pathStr : subpaths)
            {
                // SPDLOG_DEBUG("Found asset folder subpath: {}", pathStr);
            }
        }
        catch (const std::filesystem::filesystem_error &e)
        {
            // Handle errors (e.g., invalid path, permission issues)
            SPDLOG_ERROR("Filesystem error: {}", e.what());
        }
        catch (const std::exception &e)
        {
            // Handle any other exceptions
            SPDLOG_ERROR("Error: {}", e.what());
        }

        // add every subpath to uuids
        for (const auto &pathStr : subpaths)
        {
            uuid::add(pathStr);
        }
    }

    // Loads JSON data from various files and initializes game data structures.
    auto loadJSONData() -> void
    {

        // get language setting from config file
        // configuration file
        std::ifstream jsonStream{};

        //TODO: add all asset folder items to uuids

        auto path  = util::getAssetPathUUIDVersion("localization/ui_strings.json");
        jsonStream.open(util::getAssetPathUUIDVersion("localization/ui_strings.json"));
        globals::uiStringsJSON = json::parse(jsonStream);

        jsonStream.close();

        jsonStream.open(util::getAssetPathUUIDVersion("raws/colors.json"));
        globals::colorsJSON = json::parse(jsonStream);

        jsonStream.close();

        jsonStream.open(util::getAssetPathUUIDVersion("graphics/sprites.json"));
        globals::spritesJSON = json::parse(jsonStream);

        jsonStream.close();

        jsonStream.open(util::getAssetPathUUIDVersion("graphics/animations.json"));
        globals::animationsJSON = json::parse(jsonStream);

        jsonStream.close();
        
        jsonStream.open(util::getAssetPathUUIDVersion("assets/config.json"));
        globals::configJSON = json::parse(jsonStream);
        
        jsonStream.close();

        // create map for fast draw access of sprites
        // map filename to frame rectangle

        loadInSpriteFramesFromJSON();

        loadColorsFromJSON();

        // load animations map (spriteFrames and colorsMap must be initialized before this part)
        loadAnimationsFromJSON();

        // dump uuids to a file for debugging & reference
        uuid::dump_to_json(util::getRawAssetPathNoUUID("all_uuids.json #auto_generated #verified.json"));
    }

    void loadAnimationsFromJSON()
    {
        for (auto &animation : globals::animationsJSON.items())
        {

            SPDLOG_DEBUG("Starting load animation {} with UUID: {}", animation.key(), uuid::add(animation.key()));
            AnimationObject ac{};

            // use uuid for animation id
            auto uuid = uuid::add(animation.key());

            ac.id = animation.key();
            ac.uuid = uuid;
            ac.currentAnimIndex = 0;

            for (auto &frameData : animation.value().at("frames"))
            {
                // skip char_cp437 reading for now (utf8 issues)
                uuid::add("NONE"); // for color value NONE

                SpriteComponentASCII frame{};

                string colorNameStringFG = frameData.at("fg_color").get<string>();
                string colorNameStringBG = frameData.at("bg_color").get<string>();

                colorNameStringFG = uuid::lookup(colorNameStringFG);
                colorNameStringBG = uuid::lookup(colorNameStringBG);

                if (colorNameStringBG == uuid::lookup("NONE"))
                {
                    frame.noBackgroundColor = true;
                }
                else
                {
                    frame.bgColor = util::getColor(colorNameStringBG);
                }

                if (colorNameStringFG == uuid::lookup("NONE"))
                {
                    frame.noForegroundColor = true;
                }
                else
                {
                    frame.fgColor = util::getColor(colorNameStringFG);
                }

                frame.fgColor = util::getColor(frameData.at("fg_color"));
                frame.bgColor = util::getColor(frameData.at("bg_color"));
                frame.spriteUUID = frameData.at("sprite_UUID");

                using namespace snowhouse;
                AssertThat(getSpriteFrame(frame.spriteUUID).width, IsGreaterThan(0));
                frame.spriteFrame = getSpriteFrame(frame.spriteUUID);


                double duration = frameData.at("duration_seconds");

                ac.animationList.emplace_back(frame, duration);

            }

            globals::animationsMap[ac.id] = ac;
        }
    }

    void loadColorsFromJSON()
    {
        for (auto &color : globals::colorsJSON)
        {
            // change to uuid
            auto colorName = std::string(color.at("name").get<string>());
            auto uuuid = uuid::add(colorName);

            int r = color.at("r").get<int>();
            int g = color.at("g").get<int>();
            int b = color.at("b").get<int>();
            int a = 255;
            // if alpha is present, use it
            if (color.find("a") != color.end())
            {
                a = color.at("a").get<int>();
            }

            Color c{};
            c.r = r;
            c.g = g;
            c.b = b;
            c.a = a;

            globals::colorsMap[uuuid] = c;

            // B) Append the "auto_generated_uuid" field
            color["auto_generated_uuid"] = uuuid;

            // SPDLOG_DEBUG("Loaded color {} with values r: {} g: {} b: {}", colorName, r, g, b);
        }

        auto filePath = util::getAssetPathUUIDVersion("raws/colors.json");
        std::ofstream outFile(filePath);
        if (!outFile.is_open())
        {
            SPDLOG_ERROR("Failed to open '{}' for writing.", filePath);
            return;
        }
        // Pretty-print with an indentation of 4 spaces
        outFile << globals::colorsJSON.dump(4);
        outFile.close();

        SPDLOG_INFO("Updated colors JSON saved to '{}'.", filePath);
    }

    void loadInSpriteFramesFromJSON()
    {
        for (auto &cp437Sprite : globals::spritesJSON.at("frames"))
        {
            std::string filename = cp437Sprite.at("filename").get<std::string>();

            // Generate UUID using unify
            std::string uuid = uuid::add(filename);

            //  append "uuid" at the end
            cp437Sprite["auto_generated_uuid"] = uuid;

            // Extract frame details
            Rectangle frame{};
            frame.x = cp437Sprite.at("frame").at("x").get<int>();
            frame.y = cp437Sprite.at("frame").at("y").get<int>();
            frame.width = cp437Sprite.at("frame").at("w").get<int>();
            frame.height = cp437Sprite.at("frame").at("h").get<int>();

            // Log the details
            // SPDLOG_DEBUG("Got sprite file {}, UUID {}, frame : [x:{}, y:{}, w:{}, h:{}]", filename, uuid, frame.position.x, frame.position.y, frame.size.x, frame.size.y);

            // Store frame in map, based on raw file name
            globals::spriteDrawFrames[filename] = frame;
        }

        auto filePath = util::getAssetPathUUIDVersion("graphics/sprites.json");
        std::ofstream outFile(filePath);
        if (!outFile.is_open())
        {
            SPDLOG_ERROR("Failed to open '{}' for writing.", filePath);
            return;
        }

        // Dump the JSON with pretty-print (4 spaces indentation)
        outFile << globals::spritesJSON.dump(4);
        outFile.close();

        SPDLOG_INFO("Dumped updated sprites JSON to '{}'.", filePath);
    }

    Texture2D retrieveNotAtlasTexture(string refrence) {
        using namespace snowhouse;
        //AssertThat(textureMap.contains(refrence), IsTrue());
        if(!globals::textureMap.contains(refrence)) {
            SPDLOG_ERROR("Texture {} not found in textureMap", refrence);
            return {};
        }
        return globals::textureMap[refrence];
    }

    /**
     * @brief Draw a texture from the loaded resources with advanced rendering options.
     *
     * @param texId The ID of the texture in the global `allTextures` vector.
     * @param source The source rectangle defining the portion of the texture to draw.
     * @param dest The destination rectangle defining where to draw the texture.
     * @param origin The point of rotation origin within the destination rectangle.
     * @param rotation The rotation angle (in degrees).
     * @param tint The tint color to apply to the texture.
     */
    // void DrawGameTexture(unsigned int texId, mytypes::Rect source, mytypes::Rect dest, mytypes::Vec2 origin, float rotation, mytypes::Col tint)
    // {
    //     // Use DrawTexturePro to draw a texture with the specified parameters
    //     DrawTexturePro(
    //         allTextures[texId],                                                   // Texture to draw
    //         {source.position.x, source.position.y, source.size.x, source.size.y}, // Source rectangle
    //         {dest.position.x, dest.position.y, dest.size.x, dest.size.y},         // Destination rectangle
    //         {origin.x, origin.y},                                                 // Rotation origin
    //         rotation,                                                             // Rotation angle
    //         {tint.r, tint.g, tint.b, tint.a}                                      // Tint color
    //     );
    // }



    AnimationObject getAnimationObject(std::string uuid_or_raw_identifier) {
        using namespace snowhouse;
        AssertThat(globals::animationsMap.find(uuid::lookup(uuid_or_raw_identifier)) != globals::animationsMap.end(), IsTrue());
        return globals::animationsMap[uuid::lookup(uuid_or_raw_identifier)]; 
    }

    std::string getUIString(std::string uuid_or_raw_identifier) {
        using namespace snowhouse;
        AssertThat(globals::uiStringsJSON.find(uuid::lookup(uuid_or_raw_identifier)) != globals::uiStringsJSON.end(), IsTrue());
        return globals::uiStringsJSON[uuid::lookup(uuid_or_raw_identifier)];
    }

    Rectangle getSpriteFrame(std::string uuid_or_raw_identifier) {
        using namespace snowhouse;
        AssertThat(globals::spriteDrawFrames.find(uuid::lookup(uuid_or_raw_identifier)) != globals::spriteDrawFrames.end(), IsTrue());
        return globals::spriteDrawFrames[uuid::lookup(uuid_or_raw_identifier)];
    }

    /**
     * Initializes the GUI for the game.
     * Sets up ImGui with a custom style and loads fonts based on the game language.
     * Also sets up toast messages.
     */
    auto initGUI() -> void {
        // before your game loop
        // rlImGuiSetup(true); 	// sets up ImGui with ether a dark or light default theme
        
        std::string englishFontName = globals::configJSON.at("fonts").at("en");
        std::string translationFontName = globals::configJSON.at("fonts").at("ko"); // FIXME: hardcoded rn, should be in config file
        int defaultSize = globals::configJSON.at("fonts").at("default_size").get<int>() + 10;

        //FIXME: config should make clear what is used for ui and what is used for game
        //FIXME: this hardcodes korean, should change this later to read from config file
        // Korean character codepoints (Hangul syllables: 0xAC00 to 0xD7A3)
        std::vector<int> codepoints;

        // // Add English characters (Basic Latin: 0x0020 to 0x007E)
        for (int codepoint = 0x0020; codepoint <= 0x007E; ++codepoint)
        {
            codepoints.push_back(codepoint);
        }
        
        // Hangul Syllables
        for (int i = 0xAC00; i <= 0xD7A3; ++i)
        {
            codepoints.push_back(i);
        }

        // Hangul Jamo
        for (int i = 0x1100; i <= 0x11FF; ++i)
        {
            codepoints.push_back(i);
        }

        // Hangul Compatibility Jamo
        for (int i = 0x3130; i <= 0x318F; ++i)
        {
            codepoints.push_back(i);
        }

        // Basic Latin (ASCII)
        for (int i = 0x0020; i <= 0x007E; ++i)
        {
            codepoints.push_back(i);
        }

        // Font font = GetFontDefault();   
        // Font font = LoadFont(util::getAssetPathUUIDVersion("fonts/pixelplay.png");
        // NOTE: We define a font base size of 32 pixels tall and up-to 250 characters
        // globals::font = LoadFontEx(util::getAssetPathUUIDVersion(englishFontName).c_str(), defaultSize, 0, 250);
        // globals::smallerFont = LoadFontEx(util::getAssetPathUUIDVersion(englishFontName).c_str(), defaultSize / 2, 0, 250);
        // globals::translationFont = LoadFontEx(util::getAssetPathUUIDVersion(translationFontName).c_str(), defaultSize, codepoints.data(), codepoints.size());
        
        // rlImGuiReloadFonts();// build font atlas
    }


    /**
     * Initializes the ECS system by connecting listeners to the registry for updating and destroying LocationComponent.
     * Listeners are invoked after updating the component and before removing the component from the entity.
     * TODO: make sure patch() is used to update location of entities now.
     */
    auto initECS() -> void {
        // registry.on_update<LocationComponent>().connect<&game::onLocationComponentUpdated>(); // call this function whenever location component is changed with replace, emplace_or_replace or patch
        
        // registry.on_destroy<LocationComponent>().connect<&game::onLocationComponentDestroyed>(); // call this function whenever location component is destroyed
        
        // on_construct - Listeners are invoked **after** assigning the component to the entity.
        
        // on_destroy - Listeners are invoked **before** removing the component from the entity.
        
        // on_update - Listeners are invoked **after** updating the component.
    }

    
    /**
     * Loads the required textures for the game.
     */
    auto loadTextures() -> void {
        // load texture
        //TODO: this should load in from json instead of being hard-coded
        globals::spriteAtlas = LoadTexture(util::getAssetPathUUIDVersion("graphics/sprites_atlas.png").c_str());
    }

    auto loadSounds() -> void {
        InitAudioDevice();
    }
    
    /**
     * @brief Initializes the game engine by setting up logging, loading JSON data and configuration file values, 
     * initializing the window, GUI, ECS, AI, and world, loading textures, and performing various tests.
     * 
     * @return void
     */
    auto base_init() -> void {
        
        // logging setup
        spdlog::set_level(spdlog::level::trace);
        
        // load root json and other data init from json
        scanAssetsFolderAndAddAllPaths();
        loadJSONData();
        loadColorsFromJSON();
        loadInSpriteFramesFromJSON();
        loadAnimationsFromJSON();        
        loadConfigFileValues(); // should be called after loadJSONData()
        // in general, loadConfigFileValues() should be called before any pertinent values are used

        SetConfigFlags(FLAG_WINDOW_RESIZABLE);
        
        InitWindow(globals::screenWidth, globals::screenHeight, "Game");
        
        
        // these methods cause crash when taskflow is used
        rlImGuiSetup(true); // sets up ImGui with ether a dark or light default theme
        initGUI();
        loadTextures();
        //InitAudioDevice(); done in audioManager
        loadSounds();
        
        initECS();
        
        // Get the current time
        auto now = std::chrono::system_clock::now();
        // Convert it to a time_t object
        std::time_t now_c = std::chrono::system_clock::to_time_t(now);
        // Use it as a seed for random number generation
        Random::seed(now_c);
        
        
    }

    // Initializes the necessary systems for the application to run.
    // This includes initializing the Lua state shared by all systems and calling name_gen::init().
    auto initSystems() -> void {
        
        graphics::init();
        shaders::loadShadersFromJSON("shaders/shaders.json");
        sound_system::LoadFromJSON(util::getAssetPathUUIDVersion("sounds/sounds.json"));
    }

    /**
     * @brief Initializes the game systems and world generation using Taskflow library.
     * 
     * @param loadingDone A boolean reference that will be set to true when loading is done.
     */
    auto startInit() -> void {
        try {
            SPDLOG_DEBUG("Starting taskflow task INIT.");
            initSystems();
            globals::loadingStateIndex++;
            initECS();
            globals::loadingStateIndex++;
            // init camera
            globals::camera.zoom = 2.5;
            globals::camera.offset = {globals::screenWidth / 2.0f, globals::screenHeight / 2.0f};

            // moved over from next task to see if this helps with crash
            Random::seed(globals::configJSON.at("seed").get<unsigned>());
            // initWorld(worldGenCurrentStep); 
            globals::loadingStateIndex++;
        }
        catch(const std::exception& e) {
            SPDLOG_ERROR("Error in taskflow INIT task: {}", e.what());
        }
        try {
            // Random::seed(configJSON.at("seed").get<unsigned>());
            SPDLOG_DEBUG("Starting taskflow task WORLD_GEN.");\
            globals::loadingStateIndex++;
        }
        catch(const std::exception& e) {
            SPDLOG_ERROR("Error in taskflow WORLD_GEN task: {}", e.what());
        }

        SPDLOG_DEBUG("Loading + worldgen finished.");
        globals::currentGameState = GameState::MAIN_MENU;
    }

    // Function to save the UUID map to a file
    void saveUUIDMapToFile(const std::unordered_map<std::string, std::string>& uuidMap, const std::string& outputPath) {
        nlohmann::json outputJson;

        for (const auto& [filename, uuid] : uuidMap) {
            outputJson[filename] = uuid;
        }

        // Write JSON to file
        std::ofstream outFile(outputPath);
        if (!outFile) {
            SPDLOG_ERROR("Failed to open file '{}' for writing UUID map", outputPath);
            return;
        }
        outFile << outputJson.dump(4); // Pretty-print with 4 spaces
        SPDLOG_INFO("UUID map saved to '{}'", outputPath);
    }

    // Function to extract file number from the filename (filename-X.png or filename-X.json or X-filename.png or X-filename.json)
    // if it fails, it returns -1
    auto extractFileNumber(const std::string& filename) -> int {
        // Pattern for numbers at the end of the filename
        std::regex hyphenNumberPattern(R"(-(\d+)\s*\.\w+$)");

        std::smatch match;

        // Check for a number at the end of the filename
        if (std::regex_search(filename, match, hyphenNumberPattern)) {
            return std::stoi(match[1].str()); // Use match[1] to get the number part
        }

        // Check for a number at the start
        std::regex numberHyphenPattern(R"(^(\d+)-.*\.\w+$)");
        if (std::regex_search(filename, match, numberHyphenPattern)) {
            return std::stoi(match[1].str());
        }

        // If no number is found, return -1
        return -1;
    }


    /**
     * @brief Loads values from the configuration file into the corresponding variables.
     * Note that this function should be called after loadJSONData().
     * 
     * @return void
     */
    auto loadConfigFileValues() -> void {
        globals::screenWidth = globals::configJSON.at("render_data").at("screen").at("width").get<int>();
        globals::screenHeight = globals::configJSON.at("render_data").at("screen").at("height").get<int>();
    }


}