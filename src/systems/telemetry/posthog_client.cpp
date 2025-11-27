#include "posthog_client.hpp"

#include <nlohmann/json.hpp>
#include <spdlog/spdlog.h>

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdlib>
#include <mutex>
#include <queue>
#include <string_view>
#include <string>
#include <thread>
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
    try {
        const module = (typeof Module !== 'undefined') ? Module : {};
        const forceBeacon = !!module.__telemetryIsUnloading;
        // Try a beacon first when the page is hiding/unloading; fetch with keepalive
        // is less reliable in that phase across browsers.
        const isDocAvailable = typeof document !== 'undefined';
        const isUnloading = forceBeacon ||
            (isDocAvailable && (document.visibilityState === 'hidden' || document.readyState === 'unloading'));
        if (typeof navigator !== 'undefined' &&
            isDocAvailable &&
            isUnloading &&
            typeof navigator.sendBeacon === 'function') {
            const ok = navigator.sendBeacon(u, new Blob([b], { type: 'application/json' }));
            if (ok) {
                return;
            }
        }
    } catch (err) {
        console.warn('posthog beacon failed; falling back to fetch', err);
    }

    try {
        fetch(u, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: b,
            keepalive: true
        }).catch((err) => {
            console.warn('posthog fetch failed', err);
        });
    } catch (err) {
        console.warn('posthog fetch threw', err);
    }
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

#if ENABLE_POSTHOG && !defined(__EMSCRIPTEN__)
        struct PendingEvent
        {
            std::string name;
            std::string url;
            std::string body;
        };

        std::mutex g_queueMutex;
        std::condition_variable g_queueCv;
        std::condition_variable g_idleCv;
        std::queue<PendingEvent> g_queue;
        std::atomic<bool> g_workerStarted{false};
        std::atomic<bool> g_shutdown{false};
        std::thread g_worker;
        size_t g_inFlight = 0;

        constexpr long kRequestTimeoutMs = 4000L;
        constexpr long kConnectTimeoutMs = 2000L;
        constexpr auto kFlushWait = std::chrono::milliseconds(600);
#endif

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

#if ENABLE_POSTHOG && !defined(__EMSCRIPTEN__)
        void sendNow(const PendingEvent &evt)
        {
            CURL *curl = curl_easy_init();
            if (!curl)
            {
                SPDLOG_WARN("[posthog] failed to initialize curl; dropping event '{}'", evt.name);
                return;
            }

            curl_slist *headers = nullptr;
            headers = curl_slist_append(headers, "Content-Type: application/json");

            curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
            curl_easy_setopt(curl, CURLOPT_URL, evt.url.c_str());
            curl_easy_setopt(curl, CURLOPT_POSTFIELDS, evt.body.c_str());
            curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, static_cast<long>(evt.body.size()));
            // Keep timeouts bounded so shutdowns don't hang if the endpoint stalls.
            curl_easy_setopt(curl, CURLOPT_TIMEOUT_MS, kRequestTimeoutMs);
            curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT_MS, kConnectTimeoutMs);
            curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
            curl_easy_setopt(curl, CURLOPT_USERAGENT, "thegamejamtemplate-posthog/1.0");
            curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);

            const auto res = curl_easy_perform(curl);
            if (res != CURLE_OK)
            {
                SPDLOG_WARN("[posthog] send failed for '{}': {}", evt.name, curl_easy_strerror(res));
            }
            else
            {
                long status = 0;
                curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &status);
                SPDLOG_DEBUG("[posthog] sent '{}' (status {})", evt.name, status);
            }

            curl_slist_free_all(headers);
            curl_easy_cleanup(curl);
        }

        void finishWorker();

        void workerLoop()
        {
            const auto curlInit = curl_global_init(CURL_GLOBAL_DEFAULT);
            if (curlInit != 0)
            {
                SPDLOG_WARN("[posthog] curl_global_init failed (code {}); events may be dropped", curlInit);
            }

            while (true)
            {
                PendingEvent evt;
                {
                    std::unique_lock<std::mutex> lock(g_queueMutex);
                    g_queueCv.wait(lock, [] { return g_shutdown.load() || !g_queue.empty(); });
                    if (g_shutdown.load() && g_queue.empty())
                    {
                        break;
                    }
                    evt = std::move(g_queue.front());
                    g_queue.pop();
                    ++g_inFlight;
                }

                sendNow(evt);

                {
                    std::lock_guard<std::mutex> lock(g_queueMutex);
                    --g_inFlight;
                    if (g_queue.empty() && g_inFlight == 0)
                    {
                        g_idleCv.notify_all();
                    }
                }
            }

            if (curlInit == 0)
            {
                curl_global_cleanup();
            }

            g_idleCv.notify_all();
        }

        void finishWorker()
        {
            if (!g_workerStarted.load())
            {
                return;
            }

            {
                std::lock_guard<std::mutex> lock(g_queueMutex);
                g_shutdown = true;
            }
            g_queueCv.notify_all();

            if (g_worker.joinable() && std::this_thread::get_id() != g_worker.get_id())
            {
                g_worker.join();
            }
        }

        void ensureWorkerStarted()
        {
            if (g_workerStarted.exchange(true))
            {
                return;
            }

            g_worker = std::thread(workerLoop);
            std::atexit(finishWorker);
        }
#endif
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
        ensureWorkerStarted();
        {
            std::lock_guard<std::mutex> lock(g_queueMutex);
            g_queue.push({event, url, body});
        }
        g_queueCv.notify_one();
#endif
#else
        SPDLOG_DEBUG("[posthog] compile-time disabled; dropping event '{}'", event);
        (void)properties;
        (void)distinctIdOverride;
#endif
    }

    void Flush()
    {
#if ENABLE_POSTHOG && !defined(__EMSCRIPTEN__)
        if (!g_workerStarted.load())
        {
            return;
        }

        std::unique_lock<std::mutex> lock(g_queueMutex);
        const auto deadline = std::chrono::steady_clock::now() + kFlushWait;
        g_idleCv.wait_until(lock, deadline, [] { return g_queue.empty() && g_inFlight == 0; });
#endif
    }
} // namespace telemetry::posthog
