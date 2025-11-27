#include <gtest/gtest.h>

#include "systems/physics/physics_manager.hpp"
#include "systems/physics/physics_world.hpp"

class PhysicsManagerTest : public ::testing::Test {
protected:
    entt::registry registry;
};

TEST_F(PhysicsManagerTest, AddsWorldWithNavmeshCache) {
    PhysicsManager pm{registry};
    auto world = std::make_shared<physics::PhysicsWorld>(&registry, 1.0f, 0.0f, 0.0f, &globals::getEventBus());

    pm.add("main", world);

    auto* nav = pm.nav_of("main");
    ASSERT_NE(nav, nullptr);
    EXPECT_TRUE(nav->dirty);

    nav->dirty = false;
    pm.markNavmeshDirty("main");
    EXPECT_TRUE(nav->dirty);
}

TEST_F(PhysicsManagerTest, ClearAllWorldsResetsStorage) {
    PhysicsManager pm{registry};
    auto world = std::make_shared<physics::PhysicsWorld>(&registry, 1.0f, 0.0f, 0.0f, &globals::getEventBus());
    pm.add("main", world);

    pm.clearAllWorlds();

    EXPECT_EQ(pm.get("main"), nullptr);
}
