#include "telemetry.hpp"

#include "util/common_headers.hpp"
#include "systems/scripting/binding_recorder.hpp"
#include "systems/telemetry/posthog_client.hpp"

#include "sol/sol.hpp"

#include <algorithm>
#include <cctype>
#include <cstdlib>

namespace telemetry
{
    namespace
    {
        Config g_config{};
        constexpr const char *kDefaultPosthogKey = "phc_Vge8GE4CRyq3r5OTuMvfzk289hWApGGTKUuj9tYq1rB";

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
    } // namespace

    Config Config::FromConfigJson(const nlohmann::json &root)
    {
        Config cfg{};

        auto it = root.find("telemetry");
        if (it == root.end() || !it->is_object())
        {
            return cfg;
        }

        const auto &telemetryJson = *it;
        const bool envEnabled = envFlagSet("POSTHOG_ENABLED");
        const bool envDisabled = envFlagSet("POSTHOG_DISABLED");

        cfg.enabled = telemetryJson.value("enabled", true);
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
        rec.record_free_function({"telemetry"}, {
            "record",
            "---@param name string # Event name\n"
            "---@param props table|nil # Key/value properties (string/number/bool)\n"
            "---@return nil",
            "Enqueues a telemetry event if telemetry is enabled.",
            true, false
        });
    }
} // namespace telemetry
