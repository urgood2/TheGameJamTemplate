#include <gtest/gtest.h>
#include <vector>

#include "core/event_bus.hpp"

namespace {
struct SimpleEvent : public event_bus::Event {
    int value{};
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
