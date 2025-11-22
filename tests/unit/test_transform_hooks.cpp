#include <gtest/gtest.h>

#include <any>
#include <string>
#include <unordered_map>
#include <vector>

#include "entt/entt.hpp"
#include "systems/transform/transform_functions.hpp"

// Provide test-local definitions for the transform hook maps used by the inline template.
namespace transform {
    std::unordered_map<TransformMethod, std::any> transformFunctionsDefault;
    std::unordered_map<TransformMethod, std::any> hooksToCallBeforeDefault;
    std::unordered_map<TransformMethod, std::any> hooksToCallAfterDefault;
}

class TransformHookTest : public ::testing::Test {
protected:
    void TearDown() override {
        transform::transformFunctionsDefault.clear();
        transform::hooksToCallBeforeDefault.clear();
        transform::hooksToCallAfterDefault.clear();
    }
};

TEST_F(TransformHookTest, ExecutesHooksAndMainFunctionInOrder) {
    std::vector<std::string> calls;
    float observedDt = -1.0f;

    transform::hooksToCallBeforeDefault[transform::TransformMethod::UpdateAllTransforms] =
        std::function<void(entt::registry*, float)>([&](entt::registry*, float dt) {
            calls.push_back("before");
            observedDt = dt;
        });

    transform::transformFunctionsDefault[transform::TransformMethod::UpdateAllTransforms] =
        std::function<void(entt::registry*, float)>([&](entt::registry*, float dt) {
            calls.push_back("main");
            observedDt = dt;
        });

    transform::hooksToCallAfterDefault[transform::TransformMethod::UpdateAllTransforms] =
        std::function<void(entt::registry*, float)>([&](entt::registry*, float dt) {
            calls.push_back("after");
            observedDt = dt;
        });

    entt::registry registry;
    transform::ExecuteCallsForTransformMethod<void>(registry, entt::null, transform::TransformMethod::UpdateAllTransforms, &registry, 0.5f);

    ASSERT_EQ(calls.size(), 3u);
    EXPECT_EQ(calls[0], "before");
    EXPECT_EQ(calls[1], "main");
    EXPECT_EQ(calls[2], "after");
    EXPECT_FLOAT_EQ(observedDt, 0.5f);
}

TEST_F(TransformHookTest, UsesPerEntityHooksWhenAvailable) {
    entt::registry registry;
    const entt::entity e = registry.create();
    auto& go = registry.emplace<transform::GameObject>(e);

    std::vector<std::string> calls;

    go.hooksToCallBefore[transform::TransformMethod::UpdateAllTransforms] =
        std::function<void(entt::registry*, float)>([&](entt::registry*, float) { calls.push_back("before-entity"); });

    go.transformFunctions[transform::TransformMethod::UpdateAllTransforms] =
        std::function<void(entt::registry*, float)>([&](entt::registry*, float) { calls.push_back("main-entity"); });

    go.hooksToCallAfter[transform::TransformMethod::UpdateAllTransforms] =
        std::function<void(entt::registry*, float)>([&](entt::registry*, float) { calls.push_back("after-entity"); });

    transform::ExecuteCallsForTransformMethod<void>(registry, e, transform::TransformMethod::UpdateAllTransforms, &registry, 0.1f);

    ASSERT_EQ(calls.size(), 3u);
    EXPECT_EQ(calls[0], "before-entity");
    EXPECT_EQ(calls[1], "main-entity");
    EXPECT_EQ(calls[2], "after-entity");
}
