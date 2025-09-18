#pragma once
#include <sol/sol.hpp>
#include "ability.hpp"
#include "targeters.hpp"

// Minimal Lua loader for two example shapes (enough to demonstrate end-to-end):
//  - A simple on-death buffing trait
//  - A direct-damage spell that applies RR and a status
// The loader compiles to function pointers and packed param arrays — no std::variant.

struct LuaContentLoader {
    AbilityDatabase& db;

    explicit LuaContentLoader(AbilityDatabase& db) : db(db) {}

    void load_traits(sol::table traits);
    void load_spells(sol::table spells);
};