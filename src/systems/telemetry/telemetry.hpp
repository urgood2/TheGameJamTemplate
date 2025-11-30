#pragma once

#include <string>
#include <functional>
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

    using VisibilityChangeCallback = std::function<void(const std::string &reason, bool isVisible)>;

    // Set the active telemetry configuration (no-op sink by default).
    void Configure(const Config &cfg);
    const Config &GetConfig();

    // Helpers for consistent tagging.
    std::string PlatformTag();
    std::string BuildTypeTag();
    std::string BuildId();
    std::string SessionId();

    // Stubbed sink: safe to call even when telemetry is disabled.
    void RecordEvent(const std::string &name, const nlohmann::json &props = nlohmann::json::object());
    void Flush();

    // Optional hook invoked from JS visibilitychange/pagehide events on web.
    void SetVisibilityChangeCallback(VisibilityChangeCallback cb);

    // Lua bindings (telemetry.record(name, propsTable))
    void exposeToLua(sol::state &lua);
} // namespace telemetry
