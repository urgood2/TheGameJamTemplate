#pragma once
// TODO: Implement test_harness_lua bindings

namespace sol {
class state;
}

namespace testing {

class TestRuntime;

void expose_to_lua(sol::state& lua, TestRuntime& runtime);

} // namespace testing
