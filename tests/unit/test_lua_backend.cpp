/**
 * Lua Backend Smoke Test
 *
 * Verifies that the Lua/LuaJIT backend is properly configured and working.
 * This test should pass under both Lua 5.4.4 and LuaJIT 2.1 backends.
 */

#include <gtest/gtest.h>
#include <sol/sol.hpp>
#include <iostream>

// Helper to create state with common libraries opened
static sol::state create_lua_state() {
    sol::state lua;
    lua.open_libraries(sol::lib::base, sol::lib::math,
                       sol::lib::string, sol::lib::table);
    return lua;
}

TEST(LuaBackend, VersionDetection) {
    sol::state lua;
    lua.open_libraries(sol::lib::base, sol::lib::math,
                       sol::lib::string, sol::lib::table);

    // Open jit library if available (LuaJIT only)
#ifdef SOL_LUAJIT
    lua.open_libraries(sol::lib::jit);
#endif

    // Check _VERSION exists and is a string
    std::string version = lua["_VERSION"];
    ASSERT_FALSE(version.empty()) << "_VERSION should not be empty";

    std::cout << "Lua version: " << version << std::endl;

    // Detect LuaJIT via compile-time flag (more reliable than runtime check)
#ifdef SOL_LUAJIT
    std::cout << "Backend: LuaJIT (detected via SOL_LUAJIT)" << std::endl;
    // Verify jit table is available
    ASSERT_TRUE(lua["jit"].valid()) << "jit table should be available in LuaJIT";
    std::string jitVersion = lua["jit"]["version"];
    std::cout << "LuaJIT version: " << jitVersion << std::endl;
    EXPECT_TRUE(jitVersion.find("LuaJIT") != std::string::npos)
        << "jit.version should contain 'LuaJIT'";
    EXPECT_TRUE(version.find("Lua 5.1") != std::string::npos)
        << "_VERSION should contain 'Lua 5.1' for LuaJIT";
#else
    std::cout << "Backend: Standard Lua 5.4" << std::endl;
    EXPECT_TRUE(version.find("Lua 5.4") != std::string::npos)
        << "_VERSION should contain 'Lua 5.4' for standard Lua";
#endif
}

TEST(LuaBackend, GotoSupport) {
    auto lua = create_lua_state();

    // Both Lua 5.4 and LuaJIT 2.1 support goto
    std::string code = R"(
        local sum = 0
        for i = 1, 10 do
            if i == 5 then goto skip end
            sum = sum + i
            ::skip::
        end
        return sum
    )";

    auto result = lua.script(code);
    ASSERT_TRUE(result.valid()) << "Goto test failed: "
        << (result.valid() ? "" : result.get<sol::error>().what());

    int sum = result;
    // Sum of 1..10 minus 5 = 55 - 5 = 50
    EXPECT_EQ(sum, 1 + 2 + 3 + 4 + 6 + 7 + 8 + 9 + 10);
}

TEST(LuaBackend, PcallPropagation) {
    auto lua = create_lua_state();

    std::string code = R"(
        local function safeCall(fn)
            local ok, err = pcall(fn)
            if not ok then
                return "ERROR: " .. tostring(err)
            end
            return "SUCCESS"
        end

        return safeCall(function() error("test error") end)
    )";

    auto result = lua.script(code);
    ASSERT_TRUE(result.valid()) << "Pcall test failed";

    std::string outcome = result;
    EXPECT_TRUE(outcome.find("ERROR") != std::string::npos)
        << "Expected error message, got: " << outcome;
}

TEST(LuaBackend, BasicArithmetic) {
    auto lua = create_lua_state();

    std::string code = R"(
        local a = 10.5
        local b = 20.3
        return a + b, a * b
    )";

    auto result = lua.script(code);
    ASSERT_TRUE(result.valid()) << "Arithmetic test failed";

    // Get multiple return values directly from result
    double sum = result.get<double>(0);
    double product = result.get<double>(1);

    EXPECT_NEAR(sum, 30.8, 0.01);
    EXPECT_NEAR(product, 213.15, 0.01);
}

TEST(LuaBackend, TableOperations) {
    auto lua = create_lua_state();

    std::string code = R"(
        local t = { a = 1, b = 2, c = 3 }
        local sum = 0
        for k, v in pairs(t) do
            sum = sum + v
        end
        return sum, #"hello"
    )";

    auto result = lua.script(code);
    ASSERT_TRUE(result.valid()) << "Table test failed";

    int sum = result.get<int>(0);
    int strLen = result.get<int>(1);

    EXPECT_EQ(sum, 6);
    EXPECT_EQ(strLen, 5);
}

TEST(LuaBackend, MathLibrary) {
    auto lua = create_lua_state();

    std::string code = R"(
        return math.floor(3.7), math.ceil(3.2), math.abs(-5)
    )";

    auto result = lua.script(code);
    ASSERT_TRUE(result.valid()) << "Math library test failed";

    int floor_val = result.get<int>(0);
    int ceil_val = result.get<int>(1);
    int abs_val = result.get<int>(2);

    EXPECT_EQ(floor_val, 3);
    EXPECT_EQ(ceil_val, 4);
    EXPECT_EQ(abs_val, 5);
}

TEST(LuaBackend, StringLibrary) {
    auto lua = create_lua_state();

    std::string code = R"(
        local s = "Hello, World!"
        return string.lower(s), string.upper(s), string.sub(s, 1, 5)
    )";

    auto result = lua.script(code);
    ASSERT_TRUE(result.valid()) << "String library test failed";

    std::string lower = result.get<std::string>(0);
    std::string upper = result.get<std::string>(1);
    std::string sub = result.get<std::string>(2);

    EXPECT_EQ(lower, "hello, world!");
    EXPECT_EQ(upper, "HELLO, WORLD!");
    EXPECT_EQ(sub, "Hello");
}

TEST(LuaBackend, ClosuresAndUpvalues) {
    auto lua = create_lua_state();

    std::string code = R"(
        local function makeCounter()
            local count = 0
            return function()
                count = count + 1
                return count
            end
        end

        local counter = makeCounter()
        local a = counter()
        local b = counter()
        local c = counter()
        return a, b, c
    )";

    auto result = lua.script(code);
    ASSERT_TRUE(result.valid()) << "Closure test failed";

    int a = result.get<int>(0);
    int b = result.get<int>(1);
    int c = result.get<int>(2);

    EXPECT_EQ(a, 1);
    EXPECT_EQ(b, 2);
    EXPECT_EQ(c, 3);
}

TEST(LuaBackend, Coroutines) {
    auto lua = create_lua_state();
    lua.open_libraries(sol::lib::coroutine);

    std::string code = R"(
        local function generator()
            coroutine.yield(1)
            coroutine.yield(2)
            coroutine.yield(3)
            return 4
        end

        local co = coroutine.create(generator)
        local results = {}
        while coroutine.status(co) ~= "dead" do
            local ok, val = coroutine.resume(co)
            if ok then
                table.insert(results, val)
            end
        end
        return results[1], results[2], results[3], results[4]
    )";

    auto result = lua.script(code);
    ASSERT_TRUE(result.valid()) << "Coroutine test failed: "
        << (result.valid() ? "" : result.get<sol::error>().what());

    int v1 = result.get<int>(0);
    int v2 = result.get<int>(1);
    int v3 = result.get<int>(2);
    int v4 = result.get<int>(3);

    EXPECT_EQ(v1, 1);
    EXPECT_EQ(v2, 2);
    EXPECT_EQ(v3, 3);
    EXPECT_EQ(v4, 4);
}

TEST(LuaBackend, BitCompatibilityLayer) {
    sol::state lua;
    lua.open_libraries(sol::lib::base, sol::lib::math, sol::lib::string,
                       sol::lib::table, sol::lib::package);

// For LuaJIT: We need to manually open the `bit` library.
// Sol2's bit32 library uses luaopen_bit under LuaJIT but registers it as "bit32".
// We need the native LuaJIT `bit` library so bit_compat.lua detects it and exits early.
#ifdef SOL_LUAJIT
    lua.open_libraries(sol::lib::jit);
    // Manually open LuaJIT's bit library as "bit" (not "bit32")
    luaL_requiref(lua.lua_state(), "bit", luaopen_bit, 1);
    lua_pop(lua.lua_state(), 1);
#endif

    // Set up package path to find bit_compat.lua
    lua["package"]["path"] = ASSETS_PATH "scripts/?.lua;" ASSETS_PATH "scripts/init/?.lua";

    // Load bit_compat
    auto loadResult = lua.script("require('init.bit_compat')");
    ASSERT_TRUE(loadResult.valid()) << "Failed to load bit_compat: "
        << (loadResult.valid() ? "" : loadResult.get<sol::error>().what());

    // Test basic bit operations
    std::string testCode = R"(
        assert(bit, "bit library not available")
        assert(bit.bor, "bit.bor not available")
        assert(bit.band, "bit.band not available")
        assert(bit.bxor, "bit.bxor not available")
        assert(bit.lshift, "bit.lshift not available")
        assert(bit.rshift, "bit.rshift not available")

        -- Test operations
        local bor_result = bit.bor(0x0F, 0xF0)
        local band_result = bit.band(0xFF, 0x0F)
        local bxor_result = bit.bxor(0xFF, 0x0F)
        local lshift_result = bit.lshift(1, 4)
        local rshift_result = bit.rshift(16, 2)

        -- Explicit LuaJIT-compat behavior checks
        local tobit_pos = bit.tobit(1.9)
        local tobit_neg = bit.tobit(-1.9)
        local tobit_wrap = bit.tobit(0x1FFFFFFFF)
        local tohex_default = bit.tohex(-1)
        local tohex_upper = bit.tohex(-1, -8)
        local tohex_short = bit.tohex(0x1234, 4)
        local tohex_upper_short = bit.tohex(0x1a2b, -4)
        local tohex_padded = bit.tohex(0x1234, 8)

        return bor_result, band_result, bxor_result, lshift_result, rshift_result,
               tobit_pos, tobit_neg, tobit_wrap,
               tohex_default, tohex_upper, tohex_short, tohex_upper_short, tohex_padded
    )";

    auto result = lua.script(testCode);
    ASSERT_TRUE(result.valid()) << "Bit test failed: "
        << (result.valid() ? "" : result.get<sol::error>().what());

    int bor_result = result.get<int>(0);
    int band_result = result.get<int>(1);
    int bxor_result = result.get<int>(2);
    int lshift_result = result.get<int>(3);
    int rshift_result = result.get<int>(4);
    int tobit_pos = result.get<int>(5);
    int tobit_neg = result.get<int>(6);
    int tobit_wrap = result.get<int>(7);
    std::string tohex_default = result.get<std::string>(8);
    std::string tohex_upper = result.get<std::string>(9);
    std::string tohex_short = result.get<std::string>(10);
    std::string tohex_upper_short = result.get<std::string>(11);
    std::string tohex_padded = result.get<std::string>(12);

    EXPECT_EQ(bor_result, 0xFF) << "bit.bor(0x0F, 0xF0) should equal 0xFF";
    EXPECT_EQ(band_result, 0x0F) << "bit.band(0xFF, 0x0F) should equal 0x0F";
    EXPECT_EQ(bxor_result, 0xF0) << "bit.bxor(0xFF, 0x0F) should equal 0xF0";
    EXPECT_EQ(lshift_result, 16) << "bit.lshift(1, 4) should equal 16";
    EXPECT_EQ(rshift_result, 4) << "bit.rshift(16, 2) should equal 4";
    EXPECT_EQ(tobit_pos, 1) << "bit.tobit(1.9) should truncate toward zero";
    EXPECT_EQ(tobit_neg, -1) << "bit.tobit(-1.9) should truncate toward zero";
    EXPECT_EQ(tobit_wrap, -1) << "bit.tobit(0x1FFFFFFFF) should wrap to 0xFFFFFFFF";
    EXPECT_EQ(tohex_default, "ffffffff") << "bit.tohex(-1) should be 8 lowercase hex digits";
    EXPECT_EQ(tohex_upper, "FFFFFFFF") << "bit.tohex(-1, -8) should be 8 uppercase hex digits";
    EXPECT_EQ(tohex_short, "1234") << "bit.tohex(0x1234, 4) should be 4 hex digits";
    EXPECT_EQ(tohex_upper_short, "1A2B") << "bit.tohex(0x1a2b, -4) should be uppercase";
    EXPECT_EQ(tohex_padded, "00001234") << "bit.tohex(0x1234, 8) should be padded to 8 digits";

    std::cout << "Bit compatibility layer tests passed!" << std::endl;
}
