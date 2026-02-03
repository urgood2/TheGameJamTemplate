#include "testing/test_harness_lua.hpp"
#include "testing/test_runtime.hpp"
#include "sol/sol.hpp"

namespace testing {

void expose_to_lua(sol::state& lua, TestRuntime& runtime) {
    (void)lua;
    (void)runtime;
}

} // namespace testing
