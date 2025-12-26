#pragma once

#include "entt/entt.hpp"
#include <string>
#include <vector>
#include <unordered_map>

// Forward declaration for sol
namespace sol {
    class state;
}

namespace render_groups {

struct EntityEntry {
    entt::entity entity;
    std::vector<std::string> shaders;  // empty = use group defaults
};

struct RenderGroup {
    std::string name;
    std::vector<std::string> defaultShaders;
    std::vector<EntityEntry> entities;
};

// Global storage
extern std::unordered_map<std::string, RenderGroup> groups;

// Group management
void createGroup(const std::string& name, const std::vector<std::string>& defaultShaders);
void clearGroup(const std::string& groupName);
void clearAll();
RenderGroup* getGroup(const std::string& groupName);

// Entity management
void addEntity(const std::string& groupName, entt::entity e);
void addEntityWithShaders(const std::string& groupName, entt::entity e, const std::vector<std::string>& shaders);
void removeEntity(const std::string& groupName, entt::entity e);
void removeFromAll(entt::entity e);

// Per-entity shader manipulation
void addShader(const std::string& groupName, entt::entity e, const std::string& shader);
void removeShader(const std::string& groupName, entt::entity e, const std::string& shader);
void setShaders(const std::string& groupName, entt::entity e, const std::vector<std::string>& shaders);
void resetToDefault(const std::string& groupName, entt::entity e);

// Lua bindings
void exposeToLua(sol::state& lua);

}  // namespace render_groups
