#include "render_groups.hpp"
#include <algorithm>
#include "spdlog/spdlog.h"
#include "sol/sol.hpp"

namespace render_groups {

std::unordered_map<std::string, RenderGroup> groups;

void createGroup(const std::string& name, const std::vector<std::string>& defaultShaders) {
    if (groups.find(name) != groups.end()) {
        SPDLOG_WARN("render_groups::createGroup: group '{}' already exists, overwriting", name);
    }
    groups[name] = RenderGroup{name, defaultShaders, {}};
}

void clearGroup(const std::string& groupName) {
    auto it = groups.find(groupName);
    if (it != groups.end()) {
        it->second.entities.clear();
    }
}

void clearAll() {
    groups.clear();
}

RenderGroup* getGroup(const std::string& groupName) {
    auto it = groups.find(groupName);
    if (it == groups.end()) {
        return nullptr;
    }
    return &it->second;
}

void addEntity(const std::string& groupName, entt::entity e) {
    auto* group = getGroup(groupName);
    if (!group) {
        SPDLOG_WARN("render_groups::addEntity: group '{}' not found", groupName);
        return;
    }
    // Check if already exists
    for (const auto& entry : group->entities) {
        if (entry.entity == e) {
            return;  // Already in group
        }
    }
    group->entities.push_back(EntityEntry{e, {}});
}

void addEntityWithShaders(const std::string& groupName, entt::entity e, const std::vector<std::string>& shaders) {
    auto* group = getGroup(groupName);
    if (!group) {
        SPDLOG_WARN("render_groups::addEntityWithShaders: group '{}' not found", groupName);
        return;
    }
    // Check if already exists, update shaders if so
    for (auto& entry : group->entities) {
        if (entry.entity == e) {
            entry.shaders = shaders;
            return;
        }
    }
    group->entities.push_back(EntityEntry{e, shaders});
}

void removeEntity(const std::string& groupName, entt::entity e) {
    auto* group = getGroup(groupName);
    if (!group) return;

    auto it = std::find_if(group->entities.begin(), group->entities.end(),
        [e](const EntityEntry& entry) { return entry.entity == e; });
    if (it != group->entities.end()) {
        // Swap with last and pop for O(1) removal
        *it = group->entities.back();
        group->entities.pop_back();
    }
}

void removeFromAll(entt::entity e) {
    for (auto& [name, group] : groups) {
        auto it = std::find_if(group.entities.begin(), group.entities.end(),
            [e](const EntityEntry& entry) { return entry.entity == e; });
        if (it != group.entities.end()) {
            *it = group.entities.back();
            group.entities.pop_back();
        }
    }
}

void addShader(const std::string& groupName, entt::entity e, const std::string& shader) {
    auto* group = getGroup(groupName);
    if (!group) return;

    for (auto& entry : group->entities) {
        if (entry.entity == e) {
            // Don't add duplicate
            if (std::find(entry.shaders.begin(), entry.shaders.end(), shader) == entry.shaders.end()) {
                entry.shaders.push_back(shader);
            }
            return;
        }
    }
}

void removeShader(const std::string& groupName, entt::entity e, const std::string& shader) {
    auto* group = getGroup(groupName);
    if (!group) return;

    for (auto& entry : group->entities) {
        if (entry.entity == e) {
            auto it = std::find(entry.shaders.begin(), entry.shaders.end(), shader);
            if (it != entry.shaders.end()) {
                entry.shaders.erase(it);
            }
            return;
        }
    }
}

void setShaders(const std::string& groupName, entt::entity e, const std::vector<std::string>& shaders) {
    auto* group = getGroup(groupName);
    if (!group) return;

    for (auto& entry : group->entities) {
        if (entry.entity == e) {
            entry.shaders = shaders;
            return;
        }
    }
}

void resetToDefault(const std::string& groupName, entt::entity e) {
    auto* group = getGroup(groupName);
    if (!group) return;

    for (auto& entry : group->entities) {
        if (entry.entity == e) {
            entry.shaders.clear();  // Empty = use group defaults
            return;
        }
    }
}

void exposeToLua(sol::state& lua) {
    auto tbl = lua.create_named_table("render_groups");

    // Group management
    tbl["create"] = [](const std::string& name, sol::table shaderList) {
        std::vector<std::string> shaders;
        for (auto& kv : shaderList) {
            if (kv.second.is<std::string>()) {
                shaders.push_back(kv.second.as<std::string>());
            }
        }
        createGroup(name, shaders);
    };

    tbl["clearGroup"] = clearGroup;
    tbl["clearAll"] = clearAll;

    // Entity management - add() with optional shader override
    tbl["add"] = sol::overload(
        [](const std::string& groupName, entt::entity e) {
            addEntity(groupName, e);
        },
        [](const std::string& groupName, entt::entity e, sol::table shaderList) {
            std::vector<std::string> shaders;
            for (auto& kv : shaderList) {
                if (kv.second.is<std::string>()) {
                    shaders.push_back(kv.second.as<std::string>());
                }
            }
            addEntityWithShaders(groupName, e, shaders);
        }
    );

    tbl["remove"] = removeEntity;
    tbl["removeFromAll"] = removeFromAll;

    // Per-entity shader manipulation
    tbl["addShader"] = addShader;
    tbl["removeShader"] = removeShader;

    tbl["setShaders"] = [](const std::string& groupName, entt::entity e, sol::table shaderList) {
        std::vector<std::string> shaders;
        for (auto& kv : shaderList) {
            if (kv.second.is<std::string>()) {
                shaders.push_back(kv.second.as<std::string>());
            }
        }
        setShaders(groupName, e, shaders);
    };

    tbl["resetToDefault"] = resetToDefault;
}

}  // namespace render_groups
