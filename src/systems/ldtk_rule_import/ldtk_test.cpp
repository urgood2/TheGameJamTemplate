#include "raylib.h"
#include "entt/fwd.hpp"
#include <cstdint>
#include <string>
#include <unordered_map>
#include <iostream>
#include <sstream>
#include <utility>
#include "ldtkimport/include/ldtkimport/LdtkDefFile.hpp"
#include "ldtkimport/include/ldtkimport/Level.h"

#include "../../core/globals.hpp"
#include "../../core/game.hpp"

#include "../../components/components.hpp"

#include "../../core/graphics.hpp"

#include "../../util/utilities.hpp"

using namespace ldtkimport::RunSettings;

namespace ldtk_test {
    struct TileSetImage {
        Texture2D image;
        std::unordered_map<ldtkimport::tileid_t, Rectangle> tiles;
    };

    struct LdtkAssets {
        ldtkimport::LdtkDefFile ldtk;
        std::unordered_map<ldtkimport::uid_t, TileSetImage> tilesetImages;
        
        bool load(std::string filename) {
            bool loadSuccess = ldtk.loadFromFile(filename.c_str(), false);

            if (!loadSuccess) {
                std::cerr << "Could not load: " << filename << std::endl;
                return false;
            }

            size_t lastSlashIdx = filename.find_last_of("\\/");

            for (auto tileset = ldtk.tilesetCBegin(), end = ldtk.tilesetCEnd(); tileset != end; ++tileset) {
                if (tileset->imagePath.empty()) {
                    continue;
                }

                std::string imagePath;
                if (lastSlashIdx != std::string::npos) {
                    imagePath = filename.substr(0, lastSlashIdx + 1) + tileset->imagePath;
                } else {
                    imagePath = tileset->imagePath;
                }

                std::cout << "Loading: " << imagePath << std::endl;

                TileSetImage tileSetImage;
                tileSetImage.image = LoadTexture(imagePath.c_str());

                tilesetImages.insert(std::make_pair(tileset->uid, tileSetImage));
            }

            for (auto layer = ldtk.layerCBegin(), layerEnd = ldtk.layerCEnd(); layer != layerEnd; ++layer) {
                const ldtkimport::TileSet *tileset = ldtk.getTileset(layer->tilesetDefUid);
                if (tileset == nullptr) {
                    std::cerr << "TileSet " << layer->tilesetDefUid << " was not found in ldtk file" << std::endl;
                    continue;
                }

                if (tilesetImages.count(tileset->uid) == 0) {
                    std::cerr << "TileSet " << tileset->uid << " was not found in tilesetImages" << std::endl;
                    continue;
                }

                auto &tilesetImage = tilesetImages[tileset->uid];
                const double cellPixelSize = layer->cellPixelSize;

                for (auto ruleGroup = layer->ruleGroups.cbegin(), ruleGroupEnd = layer->ruleGroups.cend(); ruleGroup != ruleGroupEnd; ++ruleGroup) {
                    for (auto rule = ruleGroup->rules.cbegin(), ruleEnd = ruleGroup->rules.cend(); rule != ruleEnd; ++rule) {
                        auto &tileIds = rule->tileIds;
                        for (auto tile = tileIds.cbegin(), tileEnd = tileIds.cend(); tile != tileEnd; ++tile) {
                            ldtkimport::tileid_t tileId = (*tile);

                            if (tilesetImage.tiles.count(tileId) > 0) {
                                continue;
                            }

                            int16_t tileX, tileY;
                            tileset->getCoordinates(tileId, tileX, tileY);

                            tilesetImage.tiles.insert(std::make_pair(tileId, Rectangle{tileX * (float)cellPixelSize, tileY * (float)cellPixelSize, (float)cellPixelSize, (float)cellPixelSize}));
                        }
                    }
                }
            }
            return true;
        }
        
        // applies the world tile's colors to the LDTK tile
        auto drawLDTKTileWithWorldContext(entt::entity tile, uint8_t opacity,  Vector2& origin, Vector2& position, Rectangle sourceRect, Rectangle targetRect, Texture2D& atlas) -> void {
            // get tile comp's sprite component
            auto &sc = globals::registry.get<SpriteComponentASCII>(tile);
            auto &lc = globals::registry.get<LocationComponent>(tile);

            // see if the tile in which the entity stands has visibility. Otherwise, return
            if (graphics::isTileVisible((int)lc.x, (int)lc.y) == false && globals::useLineOfSight == true) return;

            // REVIEW: tiles do not have animations atm
            
            Color &fg = sc.fgColor;
            fg.a = opacity;
            Color &bg = sc.bgColor;
            bg.a = opacity;

            Color defaultFG = WHITE;
            defaultFG.a = opacity;
            
            bool drawBackground = sc.noBackgroundColor == false;
            bool drawForeground = sc.noForegroundColor == false;
            
            //TODO drawing background slows rendering. Find a way to optimize this.
            if (drawBackground) DrawRectangle(targetRect.x, targetRect.y, targetRect.width, targetRect.height, bg);
            if (drawForeground) 
                DrawTexturePro(atlas, sourceRect, targetRect, origin, 0.0f, fg);
            else 
                DrawTexturePro(atlas, sourceRect, targetRect, origin, 0.0f, defaultFG);

        }

        void drawTiles(const ldtkimport::tiles_t *tilesToDraw, uint8_t idxToStartDrawing, ldtkimport::dimensions_t cellPixelSize, ldtkimport::dimensions_t cellPixelHalfSize, int x, int y, int cellX, int cellY, TileSetImage &tilesetImage) {
            for (int tileIdx = idxToStartDrawing; tileIdx >= 0; --tileIdx) {
                const auto &tile = (*tilesToDraw)[tileIdx];
                float offsetX = tile.getOffsetX(cellPixelHalfSize);
                float offsetY = tile.getOffsetY(cellPixelHalfSize);
                float scaleX = tile.isFlippedX() ? -1.0f : 1.0f;
                float scaleY = tile.isFlippedY() ? -1.0f : 1.0f;
                float pivotX = tile.isFlippedX() ? cellPixelSize : 0.0f;
                float pivotY = tile.isFlippedY() ? cellPixelSize : 0.0f;

                Color tileColor = WHITE;
                tileColor.a = static_cast<uint8_t>((tile.opacity / 100.0f) * UINT8_MAX);

                Rectangle sourceRect = tilesetImage.tiles[tile.tileId];
                Vector2 position = {x + (cellX * cellPixelSize) + offsetX, y + (cellY * cellPixelSize) + offsetY};
                Vector2 origin = {pivotX, pivotY};
                // DrawTexturePro(tilesetImage.image, sourceRect, Rectangle{position.x, position.y, cellPixelSize, cellPixelSize}, origin, 0.0f, tileColor);
                drawLDTKTileWithWorldContext(globals::map[cellX][cellY], tileColor.a, origin, position, sourceRect, Rectangle{position.x, position.y, (float)cellPixelSize, (float)cellPixelSize}, tilesetImage.image);
            }
        }

        void draw(int x, int y, const ldtkimport::Level &level, float deltaTime) {

            // REVIEW: cell counts must match map dimensions

            // taken from drawWorldMap
            auto center = GetScreenToWorld2D(Vector2{GetScreenWidth() / 2.0f, GetScreenHeight() / 2.0f}, globals::camera);
            auto offset = Vector2{GetScreenWidth() / 2 * (1.0f / globals::camera.zoom), GetScreenHeight() / 2 * (1.0f / globals::camera.zoom)};
            
            auto topLeft = graphics::Vector2Subtract(center, offset);
            auto bottomRight = graphics::Vector2Add(center, offset);
            
            const int pad = 1;
            
            // assume every tile has same size
            SpriteComponentASCII &sc = globals::registry.get<SpriteComponentASCII>(globals::map[0][0]);
            const Rectangle &tileSizeRect = sc.spriteData.frame;
            
            int left = (int) topLeft.x;
            int right = (int) bottomRight.x;
            int top = (int) topLeft.y;
            int bottom = (int) bottomRight.y;
            
            left   /= tileSizeRect.width;
            right  /= tileSizeRect.width;
            top    /= tileSizeRect.height;
            bottom /= tileSizeRect.height;
            
            left -= pad;
            right += pad;
            top -= pad;
            bottom += pad;
            
            if (left < 0) left = 0;
            if (right > globals::map.size()) right = globals::map.size();
            if (top < 0) top = 0;
            if (bottom > globals::map[0].size()) bottom = globals::map[0].size();
            
            // Get the world point that is under the mouse
            Vector2 mouseWorldPos = GetScreenToWorld2D(GetMousePosition(), globals::camera);

            // Get the number of cells in the level's grid
            auto cellCountX = level.getWidth();
            auto cellCountY = level.getHeight();

            // Iterate through each layer in reverse order (from top to bottom)
            for (int layerNum = ldtk.getLayerCount(); layerNum > 0; --layerNum) {
                const auto &layer = ldtk.getLayerByIdx(layerNum - 1);
                const auto &tileGrid = level.getTileGridByIdx(layerNum - 1);

                // TODO: check if the layer is active

                // Get the tileset associated with the current layer
                ldtkimport::TileSet *tileset = ldtk.getTileset(layer.tilesetDefUid);
                if (tileset == nullptr) {
                    continue; // Skip if no tileset is found
                }

                // // Check if the tileset image is already loaded
                if (tilesetImages.count(tileset->uid) == 0) {
                    continue; // Skip if tileset image is not loaded
                }

                

                auto &tilesetImage = tilesetImages[tileset->uid];
                const auto cellPixelSize = layer.cellPixelSize;
                const float halfGridSize = cellPixelSize * 0.5f;

                // Variables for delayed tile drawing
                const ldtkimport::tiles_t *tilesDelayedDraw = nullptr;
                uint8_t idxOfDelayedDraw = -1;
                uint8_t rulePriorityOfDelayedDraw = UINT8_MAX;
                int cellXOfDelayedDraw;
                int cellYOfDelayedDraw;

                // Iterate through each cell in the grid
                // for (int cellY = 0; cellY < cellCountY; ++cellY) {
                //     for (int cellX = 0; cellX < cellCountX; ++cellX) {
                for (int cellY = top; cellY < bottom; ++cellY) {
                    for (int cellX = left; cellX < right; ++cellX) {
                        auto &tiles = tileGrid(cellX, cellY);
                        uint8_t tileIdx = tiles.size() - 1;

                        auto &tileComp = globals::registry.get<TileComponent>(globals::map[cellX][cellY]); // reference the tile on the world map

                        // is there a task doer on this tile?
                        bool isTaskDoerOnTile = tileComp.taskDoingEntitiesOnTile.size() > 0;

                        // update draw indices for task doers
                        if (isTaskDoerOnTile && tileComp.isDisplayingTaskDoingEntityTransition == false) tileComp.taskDoingEntityDrawCycleTimer += deltaTime;
                        if (isTaskDoerOnTile 
                                && tileComp.isDisplayingTaskDoingEntityTransition == false
                                && tileComp.taskDoingEntityDrawCycleTimer >= tileComp.taskDoingEntityDrawCycleTime) {
                            tileComp.taskDoingEntityDrawCycleTimer = 0;
                            tileComp.taskDoingEntityDrawIndex++;
                            // reset index if necessary
                            if (tileComp.taskDoingEntityDrawIndex >= tileComp.taskDoingEntitiesOnTile.size()) {
                                tileComp.taskDoingEntityDrawIndex = 0;
                            }

                            // if there is more than one entity on the tile, start displaying transition since we've just finished displaying one
                            if (tileComp.taskDoingEntitiesOnTile.size() > 1) {
                                // SPDLOG_DEBUG("More than one entity on tile. Displaying transition.");
                                // first check that transition object is valid
                                auto &taskDoer = tileComp.taskDoingEntitiesOnTile.at(tileComp.taskDoingEntityDrawIndex);
                                if (globals::registry.valid(tileComp.taskDoingEntityTransition) == false) {
                                    // create a new one
                                    tileComp.taskDoingEntityTransition = globals::registry.create();
                                }
                                // set up transition animation queue component to run once, then disable itself
                                auto &animQTransition = globals::registry.get<AnimationQueueComponent>(tileComp.taskDoingEntityTransition);
                                animQTransition.enabled = true;
                                animQTransition.defaultAnimation = globals::animationsMap["transition_for_showing_multiple_entities"];
                                animQTransition.animationQueue.push_back(globals::animationsMap["transition_for_showing_multiple_entities"]);
                                animQTransition.useCallbackOnAnimationQueueComplete = true;
                                animQTransition.onAnimationQueueCompleteCallback = [&tileComp, &animQTransition]() {
                                    // SPDLOG_DEBUG("Transition animation queue complete callback called");
                                    tileComp.isDisplayingTaskDoingEntityTransition = false;
                                    animQTransition.enabled = false;
                                    animQTransition.onAnimationQueueCompleteCallback = nullptr;
                                    animQTransition.useCallbackOnAnimationQueueComplete = false;
                                };
                                tileComp.isDisplayingTaskDoingEntityTransition = true;
                            }
                        } 
                    
                        // update draw indices for items & non-task doers
                        if (!isTaskDoerOnTile) tileComp.itemOnTileDrawCycleTimer += deltaTime;
                        if (!isTaskDoerOnTile && tileComp.itemOnTileDrawCycleTimer >= tileComp.itemOnTileDrawCycleTime) {
                            tileComp.itemOnTileDrawCycleTimer = 0;
                            tileComp.itemDrawIndex++;
                            // reset index if necessary
                            if (tileComp.itemDrawIndex >= tileComp.entitiesOnTile.size()) {
                                tileComp.itemDrawIndex = 0;
                            }
                            
                        }

                        bool drewItemOnTile = false;
                        if (isTaskDoerOnTile) {
                            // draw the current task doer on the tile
                            // check that tileComp.taskDoingEntityDrawIndex is within bounds
                            if (tileComp.taskDoingEntityDrawIndex >= tileComp.taskDoingEntitiesOnTile.size()) {
                                tileComp.taskDoingEntityDrawIndex = 0;
                            }
                            
                            // is transition required?
                            if (tileComp.isDisplayingTaskDoingEntityTransition) {
                                // draw transition animation queue component
                                graphics::drawSpriteComponentASCII(tileComp.taskDoingEntityTransition);
                            }
                            else {
                                graphics::drawSpriteComponentASCII(tileComp.taskDoingEntitiesOnTile.at(tileComp.taskDoingEntityDrawIndex));
                            }
                            // get transition animation queue component
                            // enable it
                            // set the callback to increment the index
                            // disable and clear callback in the callback
                            
                        }
                        else if (tileComp.entitiesOnTile.size() > 0 && tileComp.itemDrawIndex < tileComp.entitiesOnTile.size()) 
                            // draw the current item on the tile, whatever it is
                        {
                            auto item = tileComp.entitiesOnTile.at(tileComp.itemDrawIndex);
                            graphics::drawSpriteComponentASCII(item);
                            drewItemOnTile = true;
                        }
                        // for (auto it = tileComp.entitiesOnTile.rbegin(); it != tileComp.entitiesOnTile.rend(); ++it) {
                        //     auto item = *it;
                        //     if (registry.any_of<EntityStateComponent>(item) == false) {
                        //         // draw only topmost item on tile, if it's not a human
                        //         drawSpriteComponentASCII(item);
                        //         drewItemOnTile = true;
                        //         break;
                        //     }
                        // }

                        // draw blood if no items have been drawn 
                        tileComp.liquidOnTileDrawCycleTimer += deltaTime;

                        // FIXME: hack to prevent segfault
                        if (tileComp.liquidDrawIndex < 0) {
                            tileComp.liquidDrawIndex = 0;
                        }

                        if (tileComp.liquidsOnTile.size() > 0 && drewItemOnTile == false && isTaskDoerOnTile == false) {
                            // draw liquid just like items above
                            
                            if (tileComp.liquidOnTileDrawCycleTimer >= tileComp.liquidOnTileDrawCycleTime) {
                                tileComp.liquidOnTileDrawCycleTimer = 0;
                                tileComp.liquidDrawIndex++;
                                // reset index if necessary
                                if (tileComp.liquidDrawIndex >= tileComp.liquidsOnTile.size()) {
                                    tileComp.liquidDrawIndex = 0;
                                }
                            }

                            auto liquid = tileComp.liquidsOnTile.at(tileComp.liquidDrawIndex);
                            graphics::drawSpriteComponentASCII(liquid);
                            drewItemOnTile = true;
                        }
                        
                        // draw the tile itself if no items or blood have been drawn
                        if (drewItemOnTile == true || isTaskDoerOnTile == true) {
                            continue;
                        }

                        //REVIEW: so presumably, layers should be safe to ignore, so use the color of the tile at hand for everything
                        SpriteComponentASCII &sc = globals::registry.get<SpriteComponentASCII>(globals::map[cellX][cellY]);
                        Color fg = sc.fgColor;
                        Color bg = sc.bgColor;
                        if (sc.noForegroundColor) fg = BLANK;
                        if (sc.noBackgroundColor) bg = BLANK;

                        // Iterate through each tile in the cell (from top to bottom)
                        for (auto tile = tiles.crbegin(), tileEnd = tiles.crend(); tile != tileEnd; ++tile) {
                            // Check for tile offset and delay drawing if necessary
                            if (tile->hasOffsetRight() && (cellX < cellCountX - 1) && tileGrid(cellX + 1, cellY).size() > 0) {
                                tilesDelayedDraw = &tiles;
                                idxOfDelayedDraw = tileIdx;
                                rulePriorityOfDelayedDraw = tile->priority;
                                cellXOfDelayedDraw = cellX;
                                cellYOfDelayedDraw = cellY;
                                break;
                            }

                            // Draw delayed tiles if conditions are met
                            if (tilesDelayedDraw != nullptr && cellX != cellXOfDelayedDraw && rulePriorityOfDelayedDraw > tile->priority) {
                                drawTiles(tilesDelayedDraw, idxOfDelayedDraw, cellPixelSize, halfGridSize, x, y, cellXOfDelayedDraw, cellYOfDelayedDraw, tilesetImage);
                                tilesDelayedDraw = nullptr;
                            }

                            // Calculate tile drawing properties
                            float offsetX = tile->getOffsetX(halfGridSize);
                            float offsetY = tile->getOffsetY(halfGridSize);
                            float scaleX = tile->isFlippedX() ? -1.0f : 1.0f;
                            float scaleY = tile->isFlippedY() ? -1.0f : 1.0f;
                            float pivotX = tile->isFlippedX() ? cellPixelSize : 0.0f;
                            float pivotY = tile->isFlippedY() ? cellPixelSize : 0.0f;

                            // Set tile color with opacity
                            Color tileColor = WHITE;
                            tileColor.a = static_cast<uint8_t>((tile->opacity / 100.0f) * UINT8_MAX);

                            // Define source and destination rectangles for drawing
                            Rectangle sourceRect = tilesetImage.tiles[tile->tileId];
                            Vector2 position = {x + (cellX * cellPixelSize) + offsetX, y + (cellY * cellPixelSize) + offsetY};
                            Vector2 origin = {pivotX, pivotY};

                            // TODO: create a version of drawsritecomponentascii that takes origin, position, and source rect.

                            // Draw the tile
                            drawLDTKTileWithWorldContext(globals::map[cellX][cellY], tileColor.a, origin, position, sourceRect, Rectangle{position.x, position.y, (float)cellPixelSize, (float)cellPixelSize}, tilesetImage.image);
                            // DrawTexturePro(tilesetImage.image, sourceRect, Rectangle{position.x, position.y, cellPixelSize, cellPixelSize}, origin, 0.0f, tileColor);
                            --tileIdx;
                        }

                        // Draw delayed tiles if conditions are met
                        if (tilesDelayedDraw != nullptr && cellX != cellXOfDelayedDraw && rulePriorityOfDelayedDraw < tiles.front().priority) {
                            drawTiles(tilesDelayedDraw, idxOfDelayedDraw, cellPixelSize, halfGridSize, x, y, cellXOfDelayedDraw, cellYOfDelayedDraw, tilesetImage);
                            tilesDelayedDraw = nullptr;
                        }
                    }
                }
            }
        }

    };

    Color bgColor{};
    ldtkimport::Level level{};
    LdtkAssets demoLdtk;


    auto updateAndDrawLDTKTest(float deltaTime) -> void {
        

        // BeginDrawing();
        // ClearBackground(bgColor);

        demoLdtk.draw(0, 0, level, deltaTime);

        // EndDrawing();

    }

    bool initLDTKTest() {

        std::string file = fmt::format("{}", util::getAssetPathUUIDVersion(globals::configJSON.at("tileset").at("ldtk_file_path").get<std::string>()));
        // bool loadSuccess = demoLdtk.load(fmt::format("{}", util::getAssetPathUUIDVersion("graphics/newTest - ascii.ldtk")).c_str());
        // bool loadSuccess = demoLdtk.load(fmt::format("{}", util::getAssetPathUUIDVersion("graphics/newTest - mrmotext.ldtk")).c_str());
        // bool loadSuccess = demoLdtk.load(fmt::format("{}", util::getAssetPathUUIDVersion("graphics/newTest - graphicTiles.ldtk")).c_str());
        // bool loadSuccess = demoLdtk.load(fmt::format("{}", util::getAssetPathUUIDVersion("graphics/Demo.ldtk")).c_str());
        bool loadSuccess = demoLdtk.load(file);

        if (!loadSuccess) {
            SPDLOG_DEBUG("runLDTLTest - Failed to load LDtk file {}", file);
            return false;
        }

        // I hardcode getting the cell pixel size from the first layer
// because I know the ldtk file used in this demo has at least 1 layer,
        // but proper code should check if the file is empty.
        const int cellPixelSize = demoLdtk.ldtk.layerCBegin()->cellPixelSize;

        std::vector<ldtkimport::intgridvalue_t> intGrid{};
        // fill with 1's
        // std::fill(intGrid.begin(), intGrid.end(), 1);

        SPDLOG_DEBUG("runLDTKTest - map size: {} x {}", globals::map.size(), globals::map[0].size());

        // iterate through the map and create a one-dimensional array of tile ids
        for (int i = 0; i < globals::map[0].size(); i++) { // flip x and why to iterate left to right, top to bottom
            for (int j = 0; j < globals::map.size(); j++) {
                // intGrid.push_back(Random::get<int>(0, 3));
                // is there a stone wall on the tile?
                TileComponent &tile = globals::registry.get<TileComponent>(globals::map[j][i]);
                
                bool isStoneWall = false;
                // check entities on tile for stone wall
                // for (auto entity : tile.entitiesOnTile) {
                //     if (registry.any_of<InfoComponent>(entity)) {
                //         InfoComponent &info = registry.get<InfoComponent>(entity);
                //         if (info.id == "OBJECT_MINEABLE_WALL") {
                //             isStoneWall = true;
                //             break;
                //         }
                //     }
                // }
                if (tile.tileID == "STONE_WALL") {
                    isStoneWall = true;
                }

                //TODO: this code does not work?

                if (isStoneWall) { // natural rock
                    intGrid.push_back(3);
                } 
                else if (tile.tileID == "CAVERN_FLOOR" || tile.tileID == "MUD") { // ground
                    intGrid.push_back(1);
                } 
                else if (tile.tileID == "WATER") { // water
                    intGrid.push_back(2);
                } 
                else { // constructed wall
                    intGrid.push_back(4);
                }
            }
        }

        SPDLOG_DEBUG("runLDTKTest - intGrid size: {}", intGrid.size());
        
        level.setIntGrid(globals::map.size(), globals::map[0].size(), std::move(intGrid));

        // level.setIntGrid(50, 30, {
        //     0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        //     0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,1,
        //     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,
        //     1,1,1,1,1,1,1,1,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,1,1,
        //     1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,1,1,1,1,0,0,0,0,0,
        //     0,0,0,1,1,1,1,1,1,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        //     1,1,1,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,
        //     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,1,1,
        //     1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,
        //     0,1,1,1,1,1,1,0,0,0,0,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        //     0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,1,1,1,1,1,1,0,0,0,0,1,1,1,1,1,1,1,1,1,
        //     0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,1,1,1,1,
        //     1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,
        //     1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,
        //     0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,3,3,3,3,3,
        //     3,3,3,3,3,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,
        //     1,1,1,0,0,0,1,1,1,1,3,3,3,3,3,3,3,3,3,3,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,
        //     0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,1,3,3,3,3,3,3,3,3,3,3,
        //     1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,0,0,0,1,1,1,0,0,
        //     0,1,1,1,1,3,3,3,3,3,3,3,3,3,3,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,
        //     0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        //     1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0,0,0,1,1,
        //     1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,0,
        //     0,0,0,0,0,1,1,1,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        //     1,1,1,1,1,1,1,1,1,1,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0,0,0,1,1,1,1,1,1,1,
        //     1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1,0,0,0,0,0,0,
        //     1,1,1,0,0,0,0,0,1,1,1,1,1,1,2,2,2,2,1,1,1,1,2,1,1,1,1,1,1,1,1,1,1,1,0,
        //     0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,2,1,1,
        //     1,1,2,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        //     1,1,1,1,1,1,1,1,1,2,2,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,
        //     0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,2,1,1,1,1,1,1,1,
        //     1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        //     1,1,1,1,1,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,1,1,1,
        //     1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        //     1,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
        //     1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,
        //     1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,0,
        //     0,0,0,0,0,0,0,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
        //     3,3,3,3,3,3,3,3,3,3,3,3,3,3,0,0,0,0,0,0,0,0,3,3,3,3,3,3,3,3,3,3,3,3,3,
        //     3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,0,0,0,0,0,0,
        //     0,0,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
        //     3,3,3,3,3,3,3,3,3,0,0,0,0,0,0,0,0,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
        //     3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,0,0,0,0,0,0 });

        const int levelPixelWidth = level.getWidth() * cellPixelSize;
        const int levelPixelHeight = level.getHeight() * cellPixelSize;

        const auto &gotBgColor = demoLdtk.ldtk.getBgColor8();
        Color bgColor = {gotBgColor.r, gotBgColor.g, gotBgColor.b, 255};
        demoLdtk.ldtk.runRules(level, RandomizeSeeds | FasterStampBreakOnMatch);

        return true;
    }


}
