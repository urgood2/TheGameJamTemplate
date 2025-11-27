#pragma once

#include <algorithm>
#include <chrono>
#include <functional>
#include <memory>
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
    using ListenerId = std::size_t;

    class Subscription {
    public:
        Subscription() = default;
        Subscription(const Subscription &) = delete;
        Subscription &operator=(const Subscription &) = delete;

        Subscription(Subscription &&other) noexcept { *this = std::move(other); }
        Subscription &operator=(Subscription &&other) noexcept {
            if (this != &other) {
                unsubscribe();
                bus_ = other.bus_;
                key_ = other.key_;
                id_ = other.id_;
                active_ = other.active_;
                other.reset();
            }
            return *this;
        }

        ~Subscription() { unsubscribe(); }

        void unsubscribe() {
            if (active_ && bus_) {
                bus_->unsubscribe(key_, id_);
            }
            reset();
        }

        // Releases ownership of the subscription without unsubscribing.
        void release() { reset(); }

        bool active() const { return active_; }

    private:
        Subscription(EventBus *bus, std::type_index key, ListenerId id)
            : bus_(bus), key_(key), id_(id), active_(true) {}

        void reset() {
            bus_ = nullptr;
            key_ = std::type_index(typeid(void));
            id_ = 0;
            active_ = false;
        }

        EventBus *bus_{nullptr};
        std::type_index key_{typeid(void)};
        ListenerId id_{0};
        bool active_{false};

        friend class EventBus;
    };

    EventBus() = default;
    EventBus(const EventBus &) = delete;
    EventBus &operator=(const EventBus &) = delete;

    // Subscribe to an event type. Returns a scoped handle that will unsubscribe on destruction.
    template <typename EventT>
    Subscription subscribeScoped(EventListener<EventT> listener) {
        auto &list = getListeners<EventT>().listeners;
        const ListenerId id = nextId_++;
        list.emplace_back(id, std::move(listener));
        return Subscription{this, std::type_index(typeid(EventT)), id};
    }

    // Subscribe without holding onto the handle (legacy behavior).
    template <typename EventT>
    void subscribe(EventListener<EventT> listener) {
        auto sub = subscribeScoped<EventT>(std::move(listener));
        sub.release();
    }

    // Publish an event. If we're mid-dispatch, defer until the current dispatch completes.
    template <typename EventT>
    void publish(const EventT &event) {
        if (dispatching_) {
            deferred_.emplace_back([this, event]() { publish(event); });
            return;
        }

        dispatching_ = true;
        auto snapshot = getListeners<EventT>().listeners; // copy to avoid iterator invalidation
        for (auto &[id, listener] : snapshot) {
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
        nextId_ = 0;
    }

private:
    struct ListenerListBase {
        virtual ~ListenerListBase() = default;
        virtual void remove(ListenerId id) = 0;
    };

    template <typename EventT>
    struct ListenerList : ListenerListBase {
        std::vector<std::pair<ListenerId, EventListener<EventT>>> listeners;

        void remove(ListenerId id) override {
            auto &vec = listeners;
            vec.erase(std::remove_if(vec.begin(), vec.end(),
                                     [id](const auto &entry) { return entry.first == id; }),
                      vec.end());
        }
    };

    template <typename EventT>
    ListenerList<EventT> &getListeners() {
        const std::type_index key{typeid(EventT)};
        auto it = listeners_.find(key);
        if (it == listeners_.end()) {
            it = listeners_.emplace(key, std::make_unique<ListenerList<EventT>>()).first;
        }
        return *static_cast<ListenerList<EventT> *>(it->second.get());
    }

    void unsubscribe(std::type_index key, ListenerId id) {
        if (dispatching_) {
            deferred_.emplace_back([this, key, id]() { forceUnsubscribe(key, id); });
            return;
        }
        forceUnsubscribe(key, id);
    }

    void forceUnsubscribe(std::type_index key, ListenerId id) {
        auto it = listeners_.find(key);
        if (it == listeners_.end()) return;
        it->second->remove(id);
    }

    std::unordered_map<std::type_index, std::unique_ptr<ListenerListBase>> listeners_;
    std::vector<std::function<void()>> deferred_;
    bool dispatching_{false};
    ListenerId nextId_{0};
};

} // namespace event_bus
