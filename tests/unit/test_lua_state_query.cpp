#include <gtest/gtest.h>

#include <string>

#include "sol/sol.hpp"
#include "testing/lua_state_query.hpp"
#include "testing/test_api_registry.hpp"

namespace {

sol::state make_lua_state() {
    sol::state lua;
    lua.open_libraries(sol::lib::base, sol::lib::table, sol::lib::string);
    return lua;
}

bool starts_with(const std::string& value, const std::string& prefix) {
    return value.rfind(prefix, 0) == 0;
}

} // namespace

TEST(LuaStateQuery, DotNotationTraversal) {
    auto lua = make_lua_state();
    lua["game"] = lua.create_table();
    lua["game"]["player"] = lua.create_table();
    lua["game"]["player"]["health"] = 42;

    testing::TestApiRegistry registry;
    registry.register_state_path({"game.player.health", "number", true, "player health"});

    testing::LuaStateQuery query;
    query.initialize(registry, lua.lua_state());

    auto value = query.get_state("game.player.health");
    ASSERT_TRUE(value.ok());
    ASSERT_TRUE(value.value.is<int>());
    EXPECT_EQ(value.value.as<int>(), 42);
}

TEST(LuaStateQuery, NumericIndexTraversal) {
    auto lua = make_lua_state();
    lua["inventory"] = lua.create_table();
    lua["inventory"]["items"] = lua.create_table();
    lua["inventory"]["items"][1] = "sword";
    lua["inventory"]["items"][2] = "shield";

    testing::TestApiRegistry registry;
    registry.register_state_path({"inventory.items[0]", "string", false, "first item"});
    registry.register_state_path({"inventory.items[1]", "string", false, "second item"});

    testing::LuaStateQuery query;
    query.initialize(registry, lua.lua_state());

    auto value = query.get_state("inventory.items[0]");
    ASSERT_TRUE(value.ok());
    EXPECT_EQ(value.value.as<std::string>(), "sword");

    auto value2 = query.get_state("inventory.items[1]");
    ASSERT_TRUE(value2.ok());
    EXPECT_EQ(value2.value.as<std::string>(), "shield");
}

TEST(LuaStateQuery, BracketStringTraversal) {
    auto lua = make_lua_state();
    lua["entities"] = lua.create_table();
    lua["entities"]["player"] = lua.create_table();
    lua["entities"]["player"]["hp"] = 9;

    testing::TestApiRegistry registry;
    registry.register_state_path({"entities[\"player\"].hp", "number", false, "player hp"});

    testing::LuaStateQuery query;
    query.initialize(registry, lua.lua_state());

    auto value = query.get_state("entities[\"player\"].hp");
    ASSERT_TRUE(value.ok());
    EXPECT_EQ(value.value.as<int>(), 9);
}

TEST(LuaStateQuery, MixedTraversal) {
    auto lua = make_lua_state();
    lua["game"] = lua.create_table();
    lua["game"]["ui"] = lua.create_table();
    lua["game"]["ui"]["buttons"] = lua.create_table();
    lua["game"]["ui"]["buttons"][1] = lua.create_table();
    lua["game"]["ui"]["buttons"][1]["text"] = "Play";

    testing::TestApiRegistry registry;
    registry.register_state_path({"game.ui.buttons[0].text", "string", false, "button text"});

    testing::LuaStateQuery query;
    query.initialize(registry, lua.lua_state());

    auto value = query.get_state("game.ui.buttons[0].text");
    ASSERT_TRUE(value.ok());
    EXPECT_EQ(value.value.as<std::string>(), "Play");
}

TEST(LuaStateQuery, CapabilityMissing) {
    auto lua = make_lua_state();
    testing::TestApiRegistry registry;

    testing::LuaStateQuery query;
    query.initialize(registry, lua.lua_state());

    auto value = query.get_state("game.player.health");
    ASSERT_FALSE(value.ok());
    EXPECT_TRUE(starts_with(value.error, "capability_missing:"));
}

TEST(LuaStateQuery, InvalidPathSyntax) {
    auto lua = make_lua_state();
    testing::TestApiRegistry registry;
    registry.register_state_path({"game..player", "table", false, "invalid"});

    testing::LuaStateQuery query;
    query.initialize(registry, lua.lua_state());

    auto value = query.get_state("game..player");
    ASSERT_FALSE(value.ok());
    EXPECT_TRUE(starts_with(value.error, "invalid_path:"));
}

TEST(LuaStateQuery, TypeErrorTraversal) {
    auto lua = make_lua_state();
    lua["game"] = lua.create_table();
    lua["game"]["player"] = 7;

    testing::TestApiRegistry registry;
    registry.register_state_path({"game.player.health", "number", false, "player health"});

    testing::LuaStateQuery query;
    query.initialize(registry, lua.lua_state());

    auto value = query.get_state("game.player.health");
    ASSERT_FALSE(value.ok());
    EXPECT_TRUE(starts_with(value.error, "type_error:"));
}

TEST(LuaStateQuery, ReadOnlySetState) {
    auto lua = make_lua_state();
    lua["game"] = lua.create_table();
    lua["game"]["player"] = lua.create_table();
    lua["game"]["player"]["health"] = 5;

    testing::TestApiRegistry registry;
    registry.register_state_path({"game.player.health", "number", false, "player health"});

    testing::LuaStateQuery query;
    query.initialize(registry, lua.lua_state());

    testing::LuaValue value;
    value.value = sol::make_object(lua, 10);
    EXPECT_FALSE(query.set_state("game.player.health", value));
    EXPECT_TRUE(starts_with(query.last_error(), "read_only:"));
}

TEST(LuaStateQuery, SetStateWritable) {
    auto lua = make_lua_state();
    lua["game"] = lua.create_table();
    lua["game"]["player"] = lua.create_table();
    lua["game"]["player"]["health"] = 5;

    testing::TestApiRegistry registry;
    registry.register_state_path({"game.player.health", "number", true, "player health"});

    testing::LuaStateQuery query;
    query.initialize(registry, lua.lua_state());

    testing::LuaValue value;
    value.value = sol::make_object(lua, 20);
    EXPECT_TRUE(query.set_state("game.player.health", value));

    auto updated = query.get_state("game.player.health");
    ASSERT_TRUE(updated.ok());
    EXPECT_EQ(updated.value.as<int>(), 20);
}

