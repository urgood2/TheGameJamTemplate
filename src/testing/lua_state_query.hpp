#pragma once

#include <string>
#include <vector>

#include "sol/sol.hpp"
#include "testing/test_api_registry.hpp"

namespace testing {

struct LuaValue {
    sol::object value;
    std::string error;

    bool ok() const { return error.empty(); }
};

class LuaStateQuery {
public:
    void initialize(TestApiRegistry& registry, lua_State* L);

    LuaValue get_state(const std::string& path);
    bool set_state(const std::string& path, const LuaValue& value);

    LuaValue execute_query(const std::string& name, const std::vector<LuaValue>& args);
    bool execute_command(const std::string& name, const std::vector<LuaValue>& args);

    const std::string& last_error() const;
    void clear();

private:
    TestApiRegistry* registry_ = nullptr;
    lua_State* lua_ = nullptr;
    std::string last_error_;
};

} // namespace testing
