#include "graphics.hpp"
#include "game.hpp"
#include "../components/components.hpp"
#include "../components/graphics.hpp"
#include "gui.hpp"

#include <map>
#include <algorithm>

namespace graphics {

    // --------------------------------------------------------
    // Camera
    // ------------------------------------------------

    auto setNextCameraTarget(Vector2 target) -> void {
        globals::nextCameraTarget = target;
    }

    /**
    * Centers the camera on the specified entity by setting the camera's target to the center of the entity's sprite.
    * 
    * @param camera The camera to center on the entity.
    * @param entity The entity to center the camera on.
    * @param globals::registry The globals::registry containing the entity's components.
    */
    void centerCameraOnEntity( entt::entity entity) {
        // return if no animation queue component or location component
        if (globals::registry.any_of<AnimationQueueComponent>(entity) == false) {
            return;
        }
        if (globals::registry.any_of<LocationComponent>(entity) == false) {
            return;
        }
        AnimationQueueComponent &aqc = globals::registry.get<AnimationQueueComponent>(entity);
        LocationComponent &lc = globals::registry.get<LocationComponent>(entity);

        // if there is a sprite component, center the camera on the sprite
        float width=0, height=0;

        // no sprite component. Cannot center camera.
        width = aqc.defaultAnimation.animationList.at(0).first.spriteData.frame.width;
        height = aqc.defaultAnimation.animationList.at(0).first.spriteData.frame.height;
        globals::nextCameraTarget.x = lc.x * width + width / 2;
        globals::nextCameraTarget.y = lc.y * height + height / 2;
    }

    auto updateCameraForSpringierMovement(Vector2 targetPosition, float deltaTime) -> void {
        // // Increase the stiffness for faster response
        // float increasedStiffness = globals::cameraStiffness * 2.0f; // Example: doubling the stiffness

        // // Increase the damping to prevent bouncing
        // float increasedDamping = globals::cameraDamping * 1.5f; // Example: 50% more damping

        // // Calculate the difference between the target and current position
        // Vector2 diff = Vector2Subtract(targetPosition, globals::camera.target);

        // // Apply the spring force with increased stiffness
        // Vector2 force = Vector2Scale(diff, increasedStiffness);

        // // Apply damping to the velocity with increased damping
        // globals::cameraVelocity = Vector2Add(Vector2Scale(globals::cameraVelocity, increasedDamping), force);

        // // Update the camera target position
        // globals::camera.target = Vector2Add(globals::camera.target, Vector2Scale(globals::cameraVelocity, deltaTime));
    }
    
    // --------------------------------------------------------
    // End camera
    // ------------------------------------------------

    auto init() -> void {
    }

    // method to subtract two vectors
    auto Vector2Subtract(Vector2 v1, Vector2 v2) -> Vector2 {
        return Vector2{v1.x - v2.x, v1.y - v2.y};
    }

    // method to add two vectors
    auto Vector2Add(Vector2 v1, Vector2 v2) -> Vector2 {
        return Vector2{v1.x + v2.x, v1.y + v2.y};
    }
    

    auto isTileVisible(int x, int y) -> bool {
        if (util::isTileWithinBounds({static_cast<float>(x), static_cast<float>(y)}) == false) return false;


        return false;
    }

    Vector2 origin{0, 0};
    
    // Draws a sprite component in ASCII format on the screen.
    // If the entity has an AnimationQueueComponent, it will use the current animation in the queue.
    // If the entity has a TweenedLocationComponent, it will use the tweened location.
    // If the entity has a TaskDesignationDisplayComponent, it will change the background and foreground colors.
    // Parameters:
    // - e: the entity to draw
    // Returns: void
    auto drawSpriteComponentASCII(entt::entity e) -> void {
        
        if (globals::registry.any_of<LocationComponent>(e) == false) {
            // just add one
            SPDLOG_ERROR("Entity {} does not have a location component. Cannot draw.", static_cast<int>(e));
            return;
        }
        
        // see if the tile in which the entity stands has visibility. Otherwise, return
        LocationComponent &lc = globals::registry.get<LocationComponent>(e);
        if (isTileVisible((int)lc.x, (int)lc.y) == false) return;
        
        SpriteComponentASCII *sc = nullptr;

        
        
        
        // does the entity have a animation queue component? 
        if (globals::registry.any_of<AnimationQueueComponent>(e)) {
            auto &aqc = globals::registry.get<AnimationQueueComponent>(e);

            auto debugSize = aqc.defaultAnimation.animationList.size();
            
            // is the animation queue empty? Use default animation
            if (aqc.animationQueue.empty()) {
                // FIXME: weird out of bounds error here - possibly only on windows?
                sc = &aqc.defaultAnimation.animationList.at(aqc.defaultAnimation.currentAnimIndex).first;
            }
            else {
                auto &currentAnimObject = aqc.animationQueue.at(aqc.currentAnimationIndex);
                sc = &currentAnimObject.animationList.at(currentAnimObject.currentAnimIndex).first;
            }
        }
        else if (globals::registry.any_of<SpriteComponentASCII>(e) == true) {
            sc = &globals::registry.get<SpriteComponentASCII>(e);
        }  
        else {
            // no sprite or animation. Nothing to draw.
            // note error
            SPDLOG_ERROR("Entity {} has no sprite or animation component. Nothing to draw.", static_cast<int>(e));
            return;
        }
        
        
        Texture2D atlasTexture = *sc->spriteData.texture;
        
        
        
        float entityX, entityY;
        if (globals::registry.any_of<TweenedLocationComponent>(e)) {
            // auto &tlc = globals::registry.get<TweenedLocationComponent>(e);
            // auto &tween = tlc.locationTween.peek();
            // entityX = tween.at(0);
            // entityY = tween.at(1);
            
            // debug section ----------------
        
            // if (globals::registry.any_of<TaskDoerComponent>(e)) {
            //     // print out location of test human
            //     // SPDLOG_DEBUG("[Render debug] Test human {} location: ({}, {}). Tweening progress {}", static_cast<int>(e), entityX, entityY, tlc.locationTween.progress());
                
            //     if (entityX == 0 && entityY == 0) {
            //         // SPDLOG_DEBUG("[Render debug] Test human {} location has been reset to origin (0, 0) at tweening progress {}", static_cast<int>(e), tlc.locationTween.progress());
            //     }
            // }
            
            // end debug section ------------
        
        } else {
            entityX = lc.x;
            entityY = lc.y;
        }
        
        Rectangle &sourceRec = sc->spriteData.frame;
        // 1:1 render
        // take into account sprites that aren't 20x20
        const float baseDestW = 20.0f;
        const float baseDestH = 20.0f;
        
        float destW = sourceRec.width;
        float destH = sourceRec.height;
        
        float x = entityX * baseDestW;
        float y = entityY * baseDestH;
        Rectangle destRec{x, y, destW, destH};
        
        // alter x and y so that destRec is centered on the entity's location
        destRec.x -= (destW - baseDestW) / 2;
        destRec.y -= (destH - baseDestH) / 2;
        
        Color &fg = sc->fgColor;
        Color &bg = sc->bgColor;
        
        
        bool drawBackground = sc->noBackgroundColor == false;
        bool drawForeground = sc->noForegroundColor == false;
        
        //TODO drawing background slows rendering. Find a way to optimize this.
        if (drawBackground) DrawRectangle(destRec.x, destRec.y, destRec.width, destRec.height, bg);
        if (drawForeground) 
            DrawTexturePro(atlasTexture, sourceRec, destRec, origin, 0, fg); 
        else 
            DrawTexturePro(atlasTexture, sourceRec, destRec, origin, 0, WHITE);

        
        // DrawRectangle(destRec.x, destRec.y, destRec.width, destRec.height, bg);
        // DrawTexturePro(spriteAtlas, sourceRec, destRec, origin, 0, fg);
    }

    auto drawEntityAtArbitraryLocation(entt::entity entity, Vector2 location) -> void {
        // draw entity at arbitrary location

        if (globals::registry.any_of<LocationComponent>(entity) == false) {
            // just add one
            SPDLOG_ERROR("Entity {} does not have a location component. Adding one arbitrarily with default value of 0, 0.", static_cast<int>(entity));
            globals::registry.emplace<LocationComponent>(entity, 0.0f, 0.0f);
        }

        auto &loc = globals::registry.get<LocationComponent>(entity);

        Vector2 formerLocation = Vector2{loc.x, loc.y};

        // change the location without using patch (which will not alert the system)
        loc.x = location.x;
        loc.y = location.y;

        // draw
        drawSpriteComponentASCII(entity);

        // put back the location
        loc.x = formerLocation.x;
        loc.y = formerLocation.y;
    }
    
    
    // /**
    //  * Draws a sprite from the sprite atlas onto the screen.
    //  * 
    //  * @param spriteNumber The index of the sprite in the sprite atlas.
    //  * @param destRec The destination rectangle where the sprite will be drawn.
    //  * @param fg The foreground color of the sprite.
    //  */
    // auto drawSpriteFromAtlas(int spriteNumber, Rectangle destRec, Color fg) -> void {


        
    //     Rectangle &sourceRec = spriteDrawFrames.at(spriteNumber);
        
    //     // fix these values later
    //     bool drawBackground = false;
    //     bool drawForeground = true;
        
    //     //TODO drawing background slows rendering. Find a way to optimize this.
    //     // if (drawBackground) DrawRectangle(destRec.x, destRec.y, destRec.width, destRec.height, bg);
    //     if (drawForeground) 
    //         DrawTexturePro(globals::spriteAtlas, sourceRec, destRec, origin, 0, fg); 
    //     else 
    //         DrawTexturePro(globals::spriteAtlas, sourceRec, destRec, origin, 0, WHITE);
    // }


    auto Vector2Scale(Vector2 v, float scale) -> Vector2 {
        return Vector2{v.x * scale, v.y * scale};
    }

    auto Vector2Normalize(Vector2 v) -> Vector2 {
        float magnitude = sqrtf(v.x * v.x + v.y * v.y);
        if (magnitude == 0) {
            return v;
        }
        return Vector2{v.x / magnitude, v.y / magnitude};
    }

    auto Vector2Length(Vector2 v) -> float {
        return sqrtf(v.x * v.x + v.y * v.y);
    }
    
}

