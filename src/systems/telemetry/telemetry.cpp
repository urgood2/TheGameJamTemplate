#include "telemetry.hpp"

#include "util/common_headers.hpp"
#include "systems/scripting/binding_recorder.hpp"
#include "systems/telemetry/posthog_client.hpp"

#include "sol/sol.hpp"

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <chrono>
#include <iomanip>
#include <random>
#include <sstream>

namespace telemetry
{
    namespace
    {
        Config g_config{};
        constexpr const char *kDefaultPosthogKey = "phc_Vge8GE4CRyq3r5OTuMvfzk289hWApGGTKUuj9tYq1rB";
        std::string g_sessionId{};

        bool envFlagSet(const char *name)
        {
            if (const char *v = std::getenv(name))
            {
                std::string val = v;
                std::transform(val.begin(), val.end(), val.begin(),
                               [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
                return (val == "1" || val == "true" || val == "yes" || val == "on");
            }
            return false;
        }

        std::string envOr(const char *name, const std::string &fallback)
        {
            if (const char *v = std::getenv(name))
            {
                return std::string{v};
            }
            return fallback;
        }

        std::string platformTag()
        {
#if defined(__EMSCRIPTEN__)
            return "web";
#elif defined(_WIN32)
            return "windows";
#elif defined(__APPLE__)
            return "macos";
#elif defined(__linux__)
            return "linux";
#else
            return "unknown";
#endif
        }

        std::string buildTypeTag()
        {
#if defined(NDEBUG)
            return "Release";
#else
            return "Debug";
#endif
        }

        std::string buildId()
        {
#ifdef CRASH_REPORT_BUILD_ID
            return CRASH_REPORT_BUILD_ID;
#else
            return "dev-local";
#endif
        }

        std::string generateSessionId()
        {
            const auto now = std::chrono::steady_clock::now().time_since_epoch().count();
            std::mt19937_64 rng{static_cast<std::mt19937_64::result_type>(now)};
            std::uniform_int_distribution<uint64_t> dist;
            std::ostringstream oss;
            oss << std::hex << std::setw(16) << std::setfill('0') << dist(rng);
            return oss.str();
        }
    } // namespace

    Config Config::FromConfigJson(const nlohmann::json &root)
    {
        Config cfg{};

        const auto it = root.find("telemetry");
        const bool hasTelemetryBlock = (it != root.end() && it->is_object());
        const nlohmann::json telemetryJson = hasTelemetryBlock ? *it : nlohmann::json::object();

        const bool envEnabled = envFlagSet("POSTHOG_ENABLED");
        const bool envDisabled = envFlagSet("POSTHOG_DISABLED");

        cfg.enabled = telemetryJson.value("enabled", hasTelemetryBlock);
        if (envEnabled)
        {
            cfg.enabled = true;
        }
        if (envDisabled)
        {
            cfg.enabled = false;
        }

        cfg.endpoint = telemetryJson.value("endpoint", std::string{});
        cfg.apiKey = envOr("POSTHOG_API_KEY", telemetryJson.value("api_key", std::string{}));
        if (cfg.apiKey.empty())
        {
            cfg.apiKey = kDefaultPosthogKey;
        }

        auto hostFromJson = telemetryJson.value("posthog_host", telemetryJson.value("endpoint", std::string{}));
        cfg.posthogHost = envOr("POSTHOG_HOST", hostFromJson);
        if (cfg.posthogHost.empty())
        {
            cfg.posthogHost = "https://us.i.posthog.com";
        }

        cfg.distinctId = envOr("POSTHOG_DISTINCT_ID", telemetryJson.value("distinct_id", std::string{}));
        if (cfg.distinctId.empty())
        {
            cfg.distinctId = "dev-local";
        }
        return cfg;
    }

    void Configure(const Config &cfg)
    {
        g_config = cfg;
        SPDLOG_INFO("[telemetry] configured: enabled={}, host='{}'",
                    g_config.enabled, g_config.posthogHost);

        if (g_sessionId.empty())
        {
            g_sessionId = generateSessionId();
        }

#if ENABLE_POSTHOG
        posthog::Configure({
            g_config.enabled,
            g_config.apiKey,
            g_config.posthogHost,
            g_config.distinctId
        });
#endif
    }

    const Config &GetConfig()
    {
        return g_config;
    }

    std::string PlatformTag()
    {
        return platformTag();
    }

    std::string BuildTypeTag()
    {
        return buildTypeTag();
    }

    std::string BuildId()
    {
        return buildId();
    }

    std::string SessionId()
    {
        if (g_sessionId.empty())
        {
            g_sessionId = generateSessionId();
        }
        return g_sessionId;
    }

    namespace
    {
        nlohmann::json tableToJson(const sol::table &tbl)
        {
            nlohmann::json props = nlohmann::json::object();
            tbl.for_each([&](const sol::object &k, const sol::object &v) {
                if (!k.is<std::string>())
                {
                    return;
                }
                const auto key = k.as<std::string>();
                if (v.is<bool>())
                {
                    props[key] = v.as<bool>();
                }
                else if (v.is<int>())
                {
                    props[key] = v.as<int>();
                }
                else if (v.is<double>())
                {
                    props[key] = v.as<double>();
                }
                else if (v.is<std::string>())
                {
                    props[key] = v.as<std::string>();
                }
            });
            return props;
        }
    } // namespace

    void RecordEvent(const std::string &name, const nlohmann::json &props)
    {
        if (!g_config.enabled)
        {
            return;
        }

#if ENABLE_POSTHOG
        posthog::Capture(name, props, g_config.distinctId);
#else
        SPDLOG_DEBUG("[telemetry] stub event '{}' ({} props) -> {}",
                     name, props.size(), g_config.endpoint);
#endif
    }

    void Flush()
    {
#if ENABLE_POSTHOG
        posthog::Flush();
#endif
    }

    void exposeToLua(sol::state &lua)
    {
        auto &rec = BindingRecorder::instance();

        sol::table t = lua["telemetry"].get_or_create<sol::table>();
        rec.add_type("telemetry").doc = "Telemetry event helpers.";

        t.set_function("record", [](const std::string &name, sol::object props) {
            nlohmann::json payload = nlohmann::json::object();
            if (props.is<sol::table>())
            {
                payload = tableToJson(props.as<sol::table>());
            }
            RecordEvent(name, payload);
        });
        t.set_function("session_id", []() {
            return SessionId();
        });
        rec.record_free_function({"telemetry"}, {
            "record",
            "---@param name string # Event name\n"
            "---@param props table|nil # Key/value properties (string/number/bool)\n"
            "---@return nil",
            "Enqueues a telemetry event if telemetry is enabled.",
            true, false
        });
        rec.record_free_function({"telemetry"}, {
            "session_id",
            "---@return string # Current session id",
            "Returns the current telemetry session id (generated on startup).",
            true, false
        });
    }
} // namespace telemetry
