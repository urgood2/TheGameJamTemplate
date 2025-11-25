#pragma once

#include <string>
#include <nlohmann/json.hpp>

namespace sol {
    class state;
} // namespace sol

namespace telemetry
{
    struct Config
    {
        bool enabled = false;
        std::string endpoint;
        std::string apiKey;
        std::string posthogHost;
        std::string distinctId;

        static Config FromConfigJson(const nlohmann::json &root);
    };

    // Set the active telemetry configuration (no-op sink by default).
    void Configure(const Config &cfg);
    const Config &GetConfig();

    // Stubbed sink: safe to call even when telemetry is disabled.
    void RecordEvent(const std::string &name, const nlohmann::json &props = nlohmann::json::object());
    void Flush();

    // Lua bindings (telemetry.record(name, propsTable))
    void exposeToLua(sol::state &lua);
} // namespace telemetry
