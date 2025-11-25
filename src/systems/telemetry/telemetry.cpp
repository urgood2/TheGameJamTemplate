#include "telemetry.hpp"

#include "util/common_headers.hpp"
#include "systems/scripting/binding_recorder.hpp"

#include "sol/sol.hpp"

namespace telemetry
{
    namespace
    {
        Config g_config{};
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
        cfg.enabled = telemetryJson.value("enabled", false);
        cfg.endpoint = telemetryJson.value("endpoint", std::string{});
        cfg.apiKey = telemetryJson.value("api_key", std::string{});
        return cfg;
    }

    void Configure(const Config &cfg)
    {
        g_config = cfg;
        SPDLOG_INFO("[telemetry] configured: enabled={}, endpoint='{}'",
                    g_config.enabled, g_config.endpoint);
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

        SPDLOG_DEBUG("[telemetry] stub event '{}' ({} props) -> {}",
                     name, props.size(), g_config.endpoint);
    }

    void Flush()
    {
        // Stub sink: nothing buffered yet.
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
