#include <gtest/gtest.h>
#include "benchmark_common.hpp"
#include <sol/sol.hpp>

class CoroutineBenchmark : public ::testing::Test {
protected:
    sol::state lua;

    void SetUp() override {
        lua.open_libraries(sol::lib::base, sol::lib::coroutine, sol::lib::table);
    }
};

TEST_F(CoroutineBenchmark, CoroutineCreationOverhead) {
    lua.script(R"(
        function make_coro()
            return coroutine.create(function()
                for i = 1, 10 do
                    coroutine.yield(i)
                end
            end)
        end
    )");

    std::vector<double> times;
    const int COUNT = 1000;

    for (int i = 0; i < 100; ++i) {
        benchmark::ScopedTimer timer(times);
        for (int j = 0; j < COUNT; ++j) {
            sol::coroutine co = lua["make_coro"]();
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("CoroutineCreation (1k)", result);

    EXPECT_LT(result.mean_ms, 100.0);
}

TEST_F(CoroutineBenchmark, CoroutineResumeOverhead) {
    lua.script(R"(
        function simple_coro()
            while true do
                coroutine.yield()
            end
        end

        test_coro = coroutine.create(simple_coro)
    )");

    sol::thread coro = lua["test_coro"];

    std::vector<double> times;
    const int RESUMES = 10000;

    for (int i = 0; i < 100; ++i) {
        // Reset coroutine
        lua.script("test_coro = coroutine.create(simple_coro)");
        coro = lua["test_coro"];

        benchmark::ScopedTimer timer(times);
        for (int j = 0; j < RESUMES; ++j) {
            lua.script("coroutine.resume(test_coro)");
        }
    }

    auto result = benchmark::analyze(times);
    benchmark::print_result("CoroutineResume (10k)", result);

    EXPECT_LT(result.mean_ms, 500.0);
}

TEST_F(CoroutineBenchmark, PooledVsNewCoroutine) {
    // Compare creating new vs reusing coroutines
    lua.script(R"(
        -- Pool of coroutines
        coro_pool = {}
        pool_size = 0

        function get_pooled_coro(fn)
            if pool_size > 0 then
                pool_size = pool_size - 1
                local co = coro_pool[pool_size + 1]
                coro_pool[pool_size + 1] = nil
                return co
            end
            return coroutine.create(fn)
        end

        function return_to_pool(co)
            pool_size = pool_size + 1
            coro_pool[pool_size] = co
        end

        function task_fn()
            coroutine.yield(1)
            coroutine.yield(2)
            return 3
        end
    )");

    // Benchmark: new coroutines each time
    std::vector<double> times_new;
    for (int i = 0; i < 50; ++i) {
        benchmark::ScopedTimer timer(times_new);
        for (int j = 0; j < 500; ++j) {
            lua.script(R"(
                local co = coroutine.create(task_fn)
                coroutine.resume(co)
                coroutine.resume(co)
                coroutine.resume(co)
            )");
        }
    }

    auto result_new = benchmark::analyze(times_new);
    benchmark::print_result("NewCoroutines (500 tasks)", result_new);

    // Note: True pooling requires wrapping coroutine to reset state
    // This test documents the creation overhead
    SUCCEED();
}
