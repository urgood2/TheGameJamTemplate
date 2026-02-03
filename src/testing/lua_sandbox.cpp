#include "testing/lua_sandbox.hpp"
#include "sol/sol.hpp"

namespace testing {

void LuaSandbox::apply(sol::state& lua) {
    (void)lua;
}

bool LuaSandbox::is_enabled() const {
    return enabled_;
}

void LuaSandbox::set_enabled(bool enabled) {
    enabled_ = enabled;
}

} // namespace testing
