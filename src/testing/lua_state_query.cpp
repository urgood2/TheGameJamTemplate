#include "testing/lua_state_query.hpp"

namespace testing {

bool LuaStateQuery::query_path(const std::string& path, std::string& out_value) const {
    (void)path;
    out_value.clear();
    return false;
}

void LuaStateQuery::clear() {
}

} // namespace testing
