#pragma once

#include <any>
#include <chrono>
#include <functional>
#include <utility>
#include <typeindex>
#include <unordered_map>
#include <vector>

#include "spdlog/spdlog.h"

namespace event_bus {

// Base event with a timestamp to help future ordering/latency tracking.
struct Event {
    Event() : timestamp(std::chrono::system_clock::now()) {}
    virtual ~Event() = default;

    std::chrono::system_clock::time_point timestamp;
};

template <typename EventT>
using EventListener = std::function<void(const EventT &)>;

class EventBus {
public:
    EventBus() = default;

    // Subscribe to an event type.
    template <typename EventT>
    void subscribe(EventListener<EventT> listener) {
        auto &list = getListeners<EventT>();
        list.push_back(std::move(listener));
    }

    // Publish an event. If we're mid-dispatch, defer until the current dispatch completes.
    template <typename EventT>
    void publish(const EventT &event) {
        if (dispatching_) {
            deferred_.emplace_back([this, event]() { publish(event); });
            return;
        }

        dispatching_ = true;
        auto &list = getListeners<EventT>();
        for (auto &listener : list) {
            try {
                listener(event);
            } catch (const std::exception &e) {
                SPDLOG_ERROR("Event listener threw: {}", e.what());
            } catch (...) {
                SPDLOG_ERROR("Event listener threw an unknown exception");
            }
        }
        dispatching_ = false;
        processDeferred();
    }

    // Flush any deferred events accumulated during nested dispatch.
    void processDeferred() {
        // Drain in FIFO order while allowing newly deferred events to chain.
        while (!deferred_.empty()) {
            auto pending = std::move(deferred_);
            deferred_.clear();
            for (auto &fn : pending) {
                if (fn) fn();
            }
        }
    }

    void clear() {
        listeners_.clear();
        deferred_.clear();
        dispatching_ = false;
    }

private:
    template <typename EventT>
    using ListenerList = std::vector<EventListener<EventT>>;

    template <typename EventT>
    ListenerList<EventT> &getListeners() {
        const std::type_index key{typeid(EventT)};
        auto it = listeners_.find(key);
        if (it == listeners_.end()) {
            it = listeners_.emplace(key, ListenerList<EventT>{}).first;
        }
        return *std::any_cast<ListenerList<EventT>>(&it->second);
    }

    std::unordered_map<std::type_index, std::any> listeners_;
    std::vector<std::function<void()>> deferred_;
    bool dispatching_{false};
};

} // namespace event_bus
