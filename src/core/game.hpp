#pragma once

#include "raylib.h"

#include <vector>
#include <memory>
#include <string>

#include "systems/layer/layer.hpp"
#include "systems/physics/physics_world.hpp"



namespace game {
    
    extern std::shared_ptr<physics::PhysicsWorld> physicsWorld;
    
    extern std::vector<std::string> fullscreenShaders;
    
    inline void add_fullscreen_shader(const std::string &name) {
        fullscreenShaders.push_back(name);
    }
    
    auto exposeToLua(sol::state &lua) -> void;
    
    inline void remove_fullscreen_shader(const std::string &name) {
        fullscreenShaders.erase(
            std::remove(fullscreenShaders.begin(),
                        fullscreenShaders.end(),
                        name),
            fullscreenShaders.end());
    }
    
    extern void reInitializeGame();
    extern void SetFollowAnchorForEntity(std::shared_ptr<layer::Layer> layer, entt::entity e);

    extern void unload();
    extern void resetLuaRefs();

    extern std::unordered_map<std::string, std::shared_ptr<layer::Layer>> s_layers;

    inline std::shared_ptr<layer::Layer> GetLayer(const std::string& name) {
        auto it = s_layers.find(name);
        return (it != s_layers.end()) ? it->second : nullptr;
    }

    inline void RegisterLayer(const std::string& name, std::shared_ptr<layer::Layer> layer) {
        s_layers[name] = layer;
    }

    inline void ClearLayers() {
        s_layers.clear();
    }


    // part of the main game loop. Place anything that doesn't fit in with systems, etc. in here
    extern auto update(float delta) -> void;

    extern auto init() -> void;
    extern auto draw(float dt) -> void;

    extern bool isPaused, isGameOver;
    extern bool isGameOver;
    extern bool gameStarted; // if game state has begun (not in menu )
    
    
    namespace luaqt {
        using WorldQT = quadtree::Quadtree<
            entt::entity,
            decltype(globals::getBoxWorld),
            std::equal_to<entt::entity>,
            float
        >;    
        extern void bind_quadtrees_lua(sol::state& L, WorldQT& world, WorldQT& ui);
    }
    
}
