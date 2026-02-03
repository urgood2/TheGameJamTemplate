#pragma once
// TODO: Implement lua_state_query

#include <string>

namespace testing {

class LuaStateQuery {
public:
    bool query_path(const std::string& path, std::string& out_value) const;
    void clear();
};

} // namespace testing
