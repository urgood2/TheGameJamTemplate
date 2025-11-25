#include <gtest/gtest.h>
#include <vector>
#include <string>

#include "core/event_bus.hpp"

namespace {
struct SimpleEvent : public event_bus::Event {
    int value{};
    SimpleEvent() = default;
    explicit SimpleEvent(int v) : value(v) {}
};
} // namespace

TEST(EventBus, PublishesToSubscribers) {
    event_bus::EventBus bus;
    int seen = 0;
    bus.subscribe<SimpleEvent>([&](const SimpleEvent &ev) { seen = ev.value; });

    SimpleEvent ev{};
    ev.value = 42;
    bus.publish(ev);

    EXPECT_EQ(seen, 42);
}

TEST(EventBus, DefersNestedDispatch) {
    event_bus::EventBus bus;
    std::vector<int> order;
    bool first = true;

    bus.subscribe<SimpleEvent>([&](const SimpleEvent &ev) {
        order.push_back(ev.value);
        if (first) {
            first = false;
            SimpleEvent next{};
            next.value = ev.value + 1;
            bus.publish(next); // should defer
        }
    });

    SimpleEvent start{};
    start.value = 1;
    bus.publish(start);

    ASSERT_EQ(order.size(), 2u);
    EXPECT_EQ(order[0], 1);
    EXPECT_EQ(order[1], 2);
}

TEST(EventBus, ClearRemovesListenersAndDeferred) {
    event_bus::EventBus bus;
    int count = 0;
    bus.subscribe<SimpleEvent>([&](const SimpleEvent &) { count++; });

    bus.publish(SimpleEvent{});
    EXPECT_EQ(count, 1);

    bus.clear();
    bus.publish(SimpleEvent{});
    EXPECT_EQ(count, 1); // unchanged after clear
}

TEST(EventBus, NestedPublishRunsEachListenerOncePerEvent) {
    event_bus::EventBus bus;
    std::vector<std::string> calls;

    bus.subscribe<SimpleEvent>([&](const SimpleEvent &ev) {
        calls.push_back("first:" + std::to_string(ev.value));
        if (ev.value == 1) {
            bus.publish(SimpleEvent{2}); // should be deferred, not doubled
        }
    });
    bus.subscribe<SimpleEvent>([&](const SimpleEvent &ev) {
        calls.push_back("second:" + std::to_string(ev.value));
    });

    bus.publish(SimpleEvent{1});

    // Expect exactly two callbacks for each of the two events (1 and 2), in FIFO order.
    ASSERT_EQ(calls.size(), 4u);
    EXPECT_EQ(calls[0], "first:1");
    EXPECT_EQ(calls[1], "second:1");
    EXPECT_EQ(calls[2], "first:2");
    EXPECT_EQ(calls[3], "second:2");
}

TEST(EventBus, ExceptionsDoNotBlockOtherListeners) {
    event_bus::EventBus bus;
    bool called = false;

    bus.subscribe<SimpleEvent>([](const SimpleEvent&) {
        throw std::runtime_error("boom");
    });
    bus.subscribe<SimpleEvent>([&](const SimpleEvent&) {
        called = true;
    });

    SimpleEvent ev{10};
    bus.publish(ev);

    EXPECT_TRUE(called);
}
