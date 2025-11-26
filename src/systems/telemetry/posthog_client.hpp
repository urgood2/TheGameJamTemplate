#pragma once

#include <string>

#include <nlohmann/json.hpp>

namespace telemetry::posthog
{
    struct Config
    {
        bool enabled = false;
        std::string apiKey;
        std::string host;
        std::string defaultDistinctId;
    };

    void Configure(const Config &cfg);

    // Sends a capture event to PostHog (no-op when disabled or misconfigured).
    void Capture(const std::string &event,
                 const nlohmann::json &properties,
                 const std::string &distinctIdOverride = std::string{});

    void Flush();
} // namespace telemetry::posthog
