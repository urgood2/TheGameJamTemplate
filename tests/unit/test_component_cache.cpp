#include <gtest/gtest.h>

#include "entt/entt.hpp"

namespace {
struct TestComponent {
    int value{};
};
} // namespace

TEST(ComponentCache, StoresAndRetrievesComponents) {
    entt::registry registry;
    const entt::entity entity = registry.create();

    registry.emplace<TestComponent>(entity, 42);

    ASSERT_TRUE(registry.all_of<TestComponent>(entity));
    const auto& component = registry.get<TestComponent>(entity);
    EXPECT_EQ(component.value, 42);
}
