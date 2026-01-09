#pragma once

#include <string>
#include <vector>

#include "goap.h"
#include "sol/sol.hpp"

namespace ai {

inline bfield_t mask_from_names(const actionplanner_t& ap, const std::vector<std::string>& names) {
    bfield_t m = 0;
    for (const auto& nm : names) {
        for (int i = 0; i < ap.numatoms; ++i) {
            if (ap.atm_names[i] && nm == ap.atm_names[i]) {
                m |= (1LL << i);
                break;
            }
        }
    }
    return m;
}

inline bfield_t build_watch_mask(const actionplanner_t& ap, sol::table actionTbl) {
    // Explicit watch = "*" returns all atom bits
    if (actionTbl["watch"].valid() && actionTbl["watch"].get_type() == sol::type::string) {
        std::string s = actionTbl["watch"];
        if (s == "*") {
            if (ap.numatoms >= 63) return ~0ULL;
            return ((1ULL << ap.numatoms) - 1ULL);
        }
    }

    // Explicit watch = { "atom1", "atom2", ... } returns specified atoms
    if (actionTbl["watch"].valid() && actionTbl["watch"].get_type() == sol::type::table) {
        std::vector<std::string> names;
        sol::table w = actionTbl["watch"];
        for (auto& kv : w) {
            if (kv.second.get_type() == sol::type::string) {
                names.push_back(kv.second.as<std::string>());
            }
        }
        return mask_from_names(ap, names);
    }

    // No watch provided: auto-watch precondition keys
    std::vector<std::string> preNames;
    if (actionTbl["pre"].valid() && actionTbl["pre"].get_type() == sol::type::table) {
        sol::table pre = actionTbl["pre"];
        for (auto& kv : pre) {
            if (kv.first.get_type() == sol::type::string) {
                preNames.push_back(kv.first.as<std::string>());
            }
        }
    }
    return mask_from_names(ap, preNames);
}

}  // namespace ai

// Backward compatibility
using ai::mask_from_names;
using ai::build_watch_mask;
