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
#include <condition_variable>
#include <curl/curl.h>
#include <deque>
#include <mutex>
#include <thread>
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

        std::string dumpForWire(const nlohmann::json &payload)
        {
            // Use replacement error handling so NaN/invalid UTF-8 never throw (wasm builds disable exceptions).
            return payload.dump(-1, ' ', false, nlohmann::json::error_handler_t::replace);
        }

#if ENABLE_POSTHOG && !defined(__EMSCRIPTEN__)
        struct EventJob
        {
            std::string event;
            nlohmann::json properties;
            std::string distinctId;
            std::string apiKey;
            std::string host;
        };

        void sendEvent(const EventJob &job)
        {
            nlohmann::json payload = nlohmann::json::object();
            payload["api_key"] = job.apiKey;
            payload["event"] = job.event;
            payload["properties"] = job.properties;
            payload["properties"]["distinct_id"] = job.distinctId;
            payload["distinct_id"] = job.distinctId;

            const auto body = dumpForWire(payload);
            const auto url = buildCaptureUrl(job.host);

            CURL *curl = curl_easy_init();
            if (!curl)
            {
                SPDLOG_WARN("[posthog] failed to initialize curl; dropping event '{}'", job.event);
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
                SPDLOG_WARN("[posthog] send failed for '{}': {}", job.event, curl_easy_strerror(res));
            }
            else
            {
                long status = 0;
                curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &status);
                SPDLOG_DEBUG("[posthog] sent '{}' (status {})", job.event, status);
            }

            curl_slist_free_all(headers);
            curl_easy_cleanup(curl);
        }

        class AsyncSender
        {
        public:
            void enqueue(EventJob job)
            {
                {
                    std::lock_guard<std::mutex> lock(mutex_);
                    startWorkerLocked();
                    queue_.push_back(std::move(job));
                }
                cv_.notify_one();
            }

            void flush()
            {
                std::unique_lock<std::mutex> lock(mutex_);
                if (!running_)
                {
                    return;
                }
                cv_.wait(lock, [&] { return queue_.empty() && inFlight_ == 0; });
            }

            ~AsyncSender()
            {
                shutdown();
            }

        private:
            void startWorkerLocked()
            {
                if (running_)
                {
                    return;
                }
                running_ = true;
                worker_ = std::thread([this] { workerLoop(); });
            }

            void workerLoop()
            {
                for (;;)
                {
                    EventJob job;
                    {
                        std::unique_lock<std::mutex> lock(mutex_);
                        cv_.wait(lock, [&] { return stop_ || !queue_.empty(); });
                        if (stop_ && queue_.empty())
                        {
                            return;
                        }
                        job = std::move(queue_.front());
                        queue_.pop_front();
                        ++inFlight_;
                    }

                    sendEvent(job);

                    {
                        std::lock_guard<std::mutex> lock(mutex_);
                        --inFlight_;
                    }
                    cv_.notify_all();
                }
            }

            void shutdown()
            {
                std::unique_lock<std::mutex> lock(mutex_);
                if (!running_)
                {
                    return;
                }
                stop_ = true;
                cv_.notify_all();
                lock.unlock();
                if (worker_.joinable())
                {
                    worker_.join();
                }
                lock.lock();
                running_ = false;
            }

            std::mutex mutex_;
            std::condition_variable cv_;
            std::deque<EventJob> queue_;
            std::thread worker_;
            bool running_ = false;
            bool stop_ = false;
            size_t inFlight_ = 0;
        };

        AsyncSender &asyncSender()
        {
            static AsyncSender sender;
            return sender;
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

#if defined(__EMSCRIPTEN__)
        nlohmann::json payload = nlohmann::json::object();
        payload["api_key"] = g_cfg.apiKey;
        payload["event"] = event;
        payload["properties"] = properties;
        payload["properties"]["distinct_id"] = distinctId;
        payload["distinct_id"] = distinctId;

        const auto body = dumpForWire(payload);
        const auto url = buildCaptureUrl(g_cfg.host);

        SPDLOG_DEBUG("[posthog] web fetch '{}' to {}", event, url);
        posthog_fetch(url.c_str(), body.c_str());
        SPDLOG_DEBUG("[posthog] sent '{}' (web fetch)", event);
        return;
#else
        EventJob job;
        job.event = event;
        job.properties = properties;
        job.distinctId = distinctId;
        job.apiKey = g_cfg.apiKey;
        job.host = g_cfg.host;

        asyncSender().enqueue(std::move(job));
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
        if (!g_cfg.enabled)
        {
            return;
        }
        asyncSender().flush();
#endif
    }
} // namespace telemetry::posthog
