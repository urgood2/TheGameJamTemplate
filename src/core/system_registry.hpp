#pragma once

#include <functional>
#include <vector>
#include <string>
#include <algorithm>

class SystemRegistry {
public:
    using UpdateFn = std::function<void(float dt)>;
    using InitFn = std::function<void()>;
    using DrawFn = std::function<void(float dt)>;

    struct SystemEntry {
        std::string name;
        int priority;
        UpdateFn update;
        InitFn init;
        DrawFn draw;
        bool enabled = true;
    };

    static SystemRegistry& global() {
        static SystemRegistry instance;
        return instance;
    }

    void registerSystem(const std::string& name, int priority, 
                       UpdateFn update = nullptr, 
                       InitFn init = nullptr,
                       DrawFn draw = nullptr) {
        systems.push_back({name, priority, update, init, draw, true});
        sorted = false;
    }

    void initAll() {
        ensureSorted();
        for (auto& sys : systems) {
            if (sys.init && sys.enabled) {
                sys.init();
            }
        }
    }

    void updateAll(float dt) {
        ensureSorted();
        for (auto& sys : systems) {
            if (sys.update && sys.enabled) {
                sys.update(dt);
            }
        }
    }

    void drawAll(float dt) {
        ensureSorted();
        for (auto& sys : systems) {
            if (sys.draw && sys.enabled) {
                sys.draw(dt);
            }
        }
    }

    void setEnabled(const std::string& name, bool enabled) {
        for (auto& sys : systems) {
            if (sys.name == name) {
                sys.enabled = enabled;
                return;
            }
        }
    }

    [[nodiscard]] bool isEnabled(const std::string& name) const {
        for (const auto& sys : systems) {
            if (sys.name == name) {
                return sys.enabled;
            }
        }
        return false;
    }

    [[nodiscard]] const std::vector<SystemEntry>& getSystems() const { return systems; }

private:
    void ensureSorted() {
        if (!sorted) {
            std::stable_sort(systems.begin(), systems.end(),
                [](const SystemEntry& a, const SystemEntry& b) {
                    return a.priority < b.priority;
                });
            sorted = true;
        }
    }

    std::vector<SystemEntry> systems;
    bool sorted = false;
};

#define REGISTER_SYSTEM(name, priority, updateFn, initFn, drawFn) \
    namespace { \
        struct name##_Registrar { \
            name##_Registrar() { \
                SystemRegistry::global().registerSystem(#name, priority, updateFn, initFn, drawFn); \
            } \
        } name##_registrar_instance; \
    }

#define REGISTER_UPDATE_SYSTEM(name, priority, updateFn) \
    REGISTER_SYSTEM(name, priority, updateFn, nullptr, nullptr)

#define REGISTER_DRAW_SYSTEM(name, priority, drawFn) \
    REGISTER_SYSTEM(name, priority, nullptr, nullptr, drawFn)
