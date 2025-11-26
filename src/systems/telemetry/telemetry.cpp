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
#include <functional>

#if defined(__EMSCRIPTEN__)
#include <emscripten/emscripten.h>
#endif

namespace telemetry
{
    namespace
    {
        Config g_config{};
        constexpr const char *kDefaultPosthogKey = "phc_Vge8GE4CRyq3r5OTuMvfzk289hWApGGTKUuj9tYq1rB";
        std::string g_sessionId{};
        bool g_sentDebugPing = false;
        bool g_sentSessionEnd = false;
#if defined(__EMSCRIPTEN__)
        bool g_lifecycleHooksRegistered = false;
#endif

#if defined(__EMSCRIPTEN__)
        EM_JS(void, telemetry_set_beacon_cfg, (const char* host,
                                               const char* apiKey,
                                               const char* distinctId,
                                               const char* sessionId,
                                               const char* buildId,
                                               const char* buildType,
                                               int enabled,
                                               const char* captureUrl), {
            const h = UTF8ToString(host);
            Module.__telemetryBeaconCfg = {
                enabled: enabled !== 0,
                apiKey: UTF8ToString(apiKey),
                distinctId: UTF8ToString(distinctId),
                sessionId: UTF8ToString(sessionId),
                buildId: UTF8ToString(buildId),
                buildType: UTF8ToString(buildType),
                telemetryHost: h,
                captureUrl: UTF8ToString(captureUrl)
            };
        });

        bool webDebugOverlayEnabled()
        {
            static int enabled = EM_ASM_INT({
                try {
                    const params = new URLSearchParams(window.location.search);
                    return (params.has('telemetryDebug') || params.has('telemetrydebug') || params.get('telemetry') === 'debug') ? 1 : 0;
                } catch (e) {
                    return 0;
                }
            });
            return enabled != 0;
        }

        void updateWebDebugOverlay(const std::string &status)
        {
            if (!webDebugOverlayEnabled())
            {
                return;
            }

            EM_ASM({
                const text = UTF8ToString($0);
                let el = document.getElementById('telemetry-debug-overlay');
                if (!el) {
                    el = document.createElement('div');
                    el.id = 'telemetry-debug-overlay';
                    el.style.position = 'fixed';
                    el.style.bottom = '8px';
                    el.style.right = '8px';
                    el.style.padding = '6px 8px';
                    el.style.background = 'rgba(20, 20, 20, 0.78)';
                    el.style.color = '#e8f1ff';
                    el.style.font = '12px/1.4 monospace';
                    el.style.borderRadius = '6px';
                    el.style.zIndex = '2147483647';
                    el.style.pointerEvents = 'none';
                    el.style.boxShadow = '0 4px 14px rgba(0,0,0,0.4)';
                    document.body.appendChild(el);
                }
                el.textContent = text;
            }, status.c_str());
        }
#else
        bool webDebugOverlayEnabled() { return false; }
        void updateWebDebugOverlay(const std::string &) {}
#endif

#if defined(__EMSCRIPTEN__)
        EM_JS(void, telemetry_register_lifecycle_hooks, (), {
            if (Module.__telemetryLifecycleRegistered) return;
            Module.__telemetryLifecycleRegistered = true;
            const fire = (reason) => {
                try {
                    const unloadingReasons = ['pagehide', 'pagehide_bfcache', 'beforeunload', 'unload'];
                    Module.__telemetryIsUnloading = unloadingReasons.includes(reason);

                    // Fire a JS-side beacon immediately to avoid relying on wasm runtime during tab close.
                    const cfg = Module.__telemetryBeaconCfg;
                    if (cfg && cfg.enabled) {
                        const payload = {
                            api_key: cfg.apiKey,
                            event: 'session_end',
                            properties: {
                                distinct_id: cfg.distinctId,
                                session_id: cfg.sessionId,
                                platform: 'web',
                                build_id: cfg.buildId,
                                build_type: cfg.buildType,
                                telemetry_host: cfg.telemetryHost,
                                reason: reason || 'unknown'
                            },
                            distinct_id: cfg.distinctId
                        };
                        const body = JSON.stringify(payload);
                        try {
                            if (typeof navigator !== 'undefined' && typeof navigator.sendBeacon === 'function') {
                                const ok = navigator.sendBeacon(cfg.captureUrl, new Blob([body], { type: 'application/json' }));
                                if (!ok) {
                                    fetch(cfg.captureUrl, { method: 'POST', headers: {'Content-Type': 'application/json'}, body, keepalive: true }).catch(() => {});
                                }
                            } else {
                                fetch(cfg.captureUrl, { method: 'POST', headers: {'Content-Type': 'application/json'}, body, keepalive: true }).catch(() => {});
                            }
                        } catch (err) {
                            console.warn('telemetry beacon send failed', err);
                        }
                    }

                    if (Module._telemetry_session_end) Module._telemetry_session_end(stringToUTF8OnStack(reason || 'unknown'));
                } catch (e) {}
            };
            window.addEventListener('pagehide', (ev) => {
                fire(ev && ev.persisted ? 'pagehide_bfcache' : 'pagehide');
            });
            window.addEventListener('beforeunload', () => fire('beforeunload'));
            window.addEventListener('unload', () => fire('unload'));
            document.addEventListener('visibilitychange', () => {
                if (document.visibilityState === 'hidden') fire('visibility_hidden');
            });
            window.addEventListener('error', (ev) => {
                try {
                    const msg = ev && ev.message ? ev.message : 'unknown';
                    const src = ev && ev.filename ? ev.filename : '';
                    if (Module._telemetry_client_error) {
                        Module._telemetry_client_error(stringToUTF8OnStack(msg), stringToUTF8OnStack(src));
                    }
                } catch (e) {}
            });
            window.addEventListener('unhandledrejection', (ev) => {
                try {
                    const msg = ev && ev.reason ? ('' + ev.reason) : 'unhandledrejection';
                    if (Module._telemetry_client_error) {
                        Module._telemetry_client_error(stringToUTF8OnStack(msg), stringToUTF8OnStack('unhandledrejection'));
                    }
                } catch (e) {}
            });
        });
#endif

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

        bool defaultEnabled = hasTelemetryBlock;
#if defined(__EMSCRIPTEN__)
        // Default to ON for web builds so telemetry works out of the box unless explicitly disabled.
        defaultEnabled = true;
#endif

        cfg.enabled = telemetryJson.value("enabled", defaultEnabled);
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

#if defined(__EMSCRIPTEN__)
        {
            std::ostringstream status;
            status << "Telemetry " << (g_config.enabled ? "ON" : "OFF")
                   << " | host: " << g_config.posthogHost
                   << " | distinct: " << g_config.distinctId
                   << " | session: " << g_sessionId;
            if (!g_config.enabled)
            {
                status << " | enable via config.telemetry.enabled or POSTHOG_ENABLED";
            }
            updateWebDebugOverlay(status.str());
        }
#endif

#if ENABLE_POSTHOG
        posthog::Configure({
            g_config.enabled,
            g_config.apiKey,
            g_config.posthogHost,
            g_config.distinctId
        });
#endif

#if defined(__EMSCRIPTEN__)
        if (g_config.enabled && webDebugOverlayEnabled() && !g_sentDebugPing)
        {
            g_sentDebugPing = true;
            RecordEvent("telemetry_web_debug_ping",
                        {{"platform", PlatformTag()},
                         {"build_type", BuildTypeTag()},
                         {"build_id", BuildId()},
                         {"host", g_config.posthogHost},
                         {"distinct_id", g_config.distinctId},
                         {"session_id", SessionId()}});
        }

        if (!g_lifecycleHooksRegistered)
        {
            telemetry_register_lifecycle_hooks();
            g_lifecycleHooksRegistered = true;
        }

        // Expose capture URL + IDs for JS-side beacons on unload.
        auto buildCaptureUrl = [](std::string host) {
            constexpr std::string_view suffixWithSlash = "/capture/";
            constexpr std::string_view suffixNoSlash = "/capture";
            if (host.size() >= suffixWithSlash.size() &&
                host.compare(host.size() - suffixWithSlash.size(), suffixWithSlash.size(), suffixWithSlash) == 0)
            {
                return host;
            }
            if (host.size() >= suffixNoSlash.size() &&
                host.compare(host.size() - suffixNoSlash.size(), suffixNoSlash.size(), suffixNoSlash) == 0)
            {
                return host + "/";
            }
            if (!host.empty() && host.back() != '/')
            {
                host.push_back('/');
            }
            return host + "capture/";
        };
        const std::string captureUrl = buildCaptureUrl(g_config.posthogHost);
        telemetry_set_beacon_cfg(
            g_config.posthogHost.c_str(),
            g_config.apiKey.c_str(),
            g_config.distinctId.c_str(),
            SessionId().c_str(),
            BuildId().c_str(),
            BuildTypeTag().c_str(),
            g_config.enabled ? 1 : 0,
            captureUrl.c_str());
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
            constexpr int kMaxDepth = 5; // prevent runaway recursion from Lua tables.

            std::function<nlohmann::json(const sol::object &, int)> toJson;
            toJson = [&](const sol::object &obj, int depth) -> nlohmann::json {
                if (depth > kMaxDepth)
                {
                    return nlohmann::json{};
                }

                if (obj.is<bool>())
                {
                    return obj.as<bool>();
                }
                if (obj.is<int64_t>())
                {
                    return obj.as<int64_t>();
                }
                if (obj.is<double>())
                {
                    return obj.as<double>();
                }
                if (obj.is<std::string>())
                {
                    return obj.as<std::string>();
                }
                if (obj.is<sol::table>())
                {
                    return tableToJson(obj.as<sol::table>());
                }
                return nlohmann::json{};
            };

            // Detect array-ish tables (1-based contiguous numeric keys) to emit JSON arrays.
            auto isArrayLike = [](const sol::table &t, size_t &maxIndex) {
                maxIndex = 0;
                size_t count = 0;
                bool arrayLike = true;
                t.for_each([&](const sol::object &k, const sol::object &) {
                    if (!k.is<int>() && !k.is<int64_t>())
                    {
                        arrayLike = false;
                        return;
                    }
                    const int64_t idx = k.is<int64_t>() ? k.as<int64_t>() : static_cast<int64_t>(k.as<int>());
                    if (idx <= 0)
                    {
                        arrayLike = false;
                        return;
                    }
                    maxIndex = static_cast<size_t>(std::max<int64_t>(maxIndex, idx));
                    ++count;
                });
                if (!arrayLike)
                {
                    return false;
                }
                return maxIndex == count; // contiguous from 1..maxIndex
            };

            size_t maxIdx = 0;
            const bool isArray = isArrayLike(tbl, maxIdx);
            nlohmann::json out = isArray ? nlohmann::json::array() : nlohmann::json::object();

            tbl.for_each([&](const sol::object &k, const sol::object &v) {
                if (isArray)
                {
                    if (!k.is<int>() && !k.is<int64_t>())
                    {
                        return;
                    }
                    const int64_t idx = k.is<int64_t>() ? k.as<int64_t>() : static_cast<int64_t>(k.as<int>());
                    if (idx <= 0)
                    {
                        return;
                    }
                    while (out.size() < static_cast<size_t>(idx))
                    {
                        out.push_back(nlohmann::json{});
                    }
                    out[static_cast<size_t>(idx) - 1] = toJson(v, 1);
                    return;
                }

                if (!k.is<std::string>())
                {
                    return;
                }
                const auto key = k.as<std::string>();
                out[key] = toJson(v, 1);
            });

            return out;
        }

        nlohmann::json withDefaultProps(const nlohmann::json &props)
        {
            nlohmann::json out;
            if (props.is_object())
            {
                out = props;
            }
            else
            {
                out = nlohmann::json::object();
            }

            auto setIfMissing = [&](const char *key, const nlohmann::json &val) {
                if (!out.contains(key))
                {
                    out[key] = val;
                }
            };

            setIfMissing("platform", PlatformTag());
            setIfMissing("build_id", BuildId());
            setIfMissing("build_type", BuildTypeTag());
            setIfMissing("session_id", SessionId());
            setIfMissing("distinct_id", g_config.distinctId);
            setIfMissing("telemetry_enabled", g_config.enabled);
            setIfMissing("telemetry_host", g_config.posthogHost);

            return out;
        }
    } // namespace

    void RecordEvent(const std::string &name, const nlohmann::json &props)
    {
        if (!g_config.enabled)
        {
#if defined(__EMSCRIPTEN__)
            if (webDebugOverlayEnabled())
            {
                updateWebDebugOverlay("Telemetry OFF (config.telemetry.enabled=false)");
            }
#endif
            return;
        }

#if defined(__EMSCRIPTEN__)
        if (webDebugOverlayEnabled())
        {
            std::ostringstream status;
            status << "Telemetry ON | last event: " << name
                   << " | host: " << g_config.posthogHost;
            updateWebDebugOverlay(status.str());
        }
#endif

#if ENABLE_POSTHOG
        posthog::Capture(name, withDefaultProps(props), g_config.distinctId);
#else
        const auto payload = withDefaultProps(props);
        SPDLOG_DEBUG("[telemetry] stub event '{}' ({} props) -> {}",
                     name, payload.size(), g_config.endpoint);
#endif
    }

#if defined(__EMSCRIPTEN__)
    extern "C" EMSCRIPTEN_KEEPALIVE void telemetry_session_end(const char *reasonCStr)
    {
        if (g_sentSessionEnd)
        {
            return;
        }
        g_sentSessionEnd = true;
        const std::string reason = reasonCStr ? reasonCStr : "unknown";
        RecordEvent("session_end", {{"reason", reason}});
        Flush();
    }

    extern "C" EMSCRIPTEN_KEEPALIVE void telemetry_client_error(const char *messageCStr, const char *sourceCStr)
    {
        static int errorCount = 0;
        if (errorCount > 5)
        {
            return;
        }
        ++errorCount;
        const std::string msg = messageCStr ? messageCStr : "unknown";
        const std::string src = sourceCStr ? sourceCStr : "";
        RecordEvent("web_client_error", {{"message", msg}, {"source", src}});
    }
#endif

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
