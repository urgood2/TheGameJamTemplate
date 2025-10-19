#include "lua_hot_reload.hpp"


namespace lua_hot_reload {


    std::unordered_map<std::string, LuaFile> trackedFiles{};
    std::vector<std::string> changedFiles{};
}