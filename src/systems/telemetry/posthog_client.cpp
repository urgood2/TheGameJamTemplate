#include "posthog_client.hpp"

#include <nlohmann/json.hpp>
#include <spdlog/spdlog.h>

#include <string_view>
#include <string>
#include <utility>

#if defined(_WIN32) && defined(NOUSER)
#undef NOUSER
#endif
#if defined(_WIN32)
#define CloseWindow WinAPICloseWindow
#define ShowCursor WinAPIShowCursor
#endif

#if ENABLE_POSTHOG && !defined(__EMSCRIPTEN__)
#include <curl/curl.h>
#endif
#if ENABLE_POSTHOG && defined(__EMSCRIPTEN__)
#include <emscripten/emscripten.h>
EM_JS(void, posthog_fetch, (const char* url, const char* body), {
    const u = UTF8ToString(url);
    const b = UTF8ToString(body);
    fetch(u, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: b,
        keepalive: true
    }).catch((err) => {
        console.warn('posthog fetch failed', err);
    });
});
#endif
#if defined(_WIN32)
#undef CloseWindow
#undef ShowCursor
#endif

namespace telemetry::posthog
{
    namespace
    {
        Config g_cfg{};

        std::string buildCaptureUrl(std::string host)
        {
            if (host.empty())
            {
                host = "https://us.i.posthog.com";
            }

            // Normalize trailing path to ensure /capture/ is present.
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
            if (host.back() != '/')
            {
                host.push_back('/');
            }
            return host + "capture/";
        }

        std::string pickDistinctId(const std::string &overrideId, const std::string &fallback)
        {
            if (!overrideId.empty())
            {
                return overrideId;
            }
            if (!fallback.empty())
            {
                return fallback;
            }
            return "anonymous";
        }
    } // namespace

    void Configure(const Config &cfg)
    {
        g_cfg = cfg;
        if (g_cfg.host.empty())
        {
            g_cfg.host = "https://us.i.posthog.com";
        }

        SPDLOG_INFO("[posthog] configured: enabled={}, host='{}'",
                    g_cfg.enabled, g_cfg.host);
    }

    void Capture(const std::string &event,
                 const nlohmann::json &properties,
                 const std::string &distinctIdOverride)
    {
        if (!g_cfg.enabled)
        {
            return;
        }

#if ENABLE_POSTHOG
        const std::string distinctId = pickDistinctId(distinctIdOverride, g_cfg.defaultDistinctId);
        if (g_cfg.apiKey.empty())
        {
            SPDLOG_WARN("[posthog] missing api_key; skipping event '{}'", event);
            return;
        }

        nlohmann::json payload = nlohmann::json::object();
        payload["api_key"] = g_cfg.apiKey;
        payload["event"] = event;
        payload["properties"] = properties;
        payload["properties"]["distinct_id"] = distinctId;
        payload["distinct_id"] = distinctId;

        const auto body = payload.dump();
        const auto url = buildCaptureUrl(g_cfg.host);

#if defined(__EMSCRIPTEN__)
        SPDLOG_DEBUG("[posthog] web fetch '{}' to {}", event, url);
        posthog_fetch(url.c_str(), body.c_str());
        SPDLOG_DEBUG("[posthog] sent '{}' (web fetch)", event);
        return;
#else
        CURL *curl = curl_easy_init();
        if (!curl)
        {
            SPDLOG_WARN("[posthog] failed to initialize curl; dropping event '{}'", event);
            return;
        }

        curl_slist *headers = nullptr;
        headers = curl_slist_append(headers, "Content-Type: application/json");

        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
        curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body.c_str());
        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, static_cast<long>(body.size()));
        // PostHog endpoints can occasionally take a couple seconds to respond; keep timeouts generous but bounded.
        curl_easy_setopt(curl, CURLOPT_TIMEOUT_MS, 7000L);
        curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT_MS, 3000L);
        curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
        curl_easy_setopt(curl, CURLOPT_USERAGENT, "thegamejamtemplate-posthog/1.0");

        const auto res = curl_easy_perform(curl);
        if (res != CURLE_OK)
        {
            SPDLOG_WARN("[posthog] send failed for '{}': {}", event, curl_easy_strerror(res));
        }
        else
        {
            long status = 0;
            curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &status);
            SPDLOG_DEBUG("[posthog] sent '{}' (status {})", event, status);
        }

        curl_slist_free_all(headers);
        curl_easy_cleanup(curl);
#endif
#else
        SPDLOG_DEBUG("[posthog] compile-time disabled; dropping event '{}'", event);
        (void)properties;
        (void)distinctIdOverride;
#endif
    }

    void Flush()
    {
        // No buffering right now.
    }
} // namespace telemetry::posthog
