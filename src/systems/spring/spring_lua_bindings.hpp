// spring_bindings.hpp
#pragma once
#include <sol/sol.hpp>
#include "spring.hpp"
#include "entt/entt.hpp"
#include "systems/scripting/binding_recorder.hpp" // your recorder
#include <tuple>

namespace bind {

inline void apply_opts(spring::Spring& s, const sol::optional<sol::table>& opts) {
    if (!opts) return;
    sol::table t = *opts;

    if (auto v = t.get<sol::optional<float>>("value"))           s.value = *v;
    if (auto v = t.get<sol::optional<float>>("target"))          s.targetValue = *v;
    if (auto v = t.get<sol::optional<float>>("stiffness"))       s.stiffness = *v;
    if (auto v = t.get<sol::optional<float>>("damping"))         s.damping = *v;
    if (auto v = t.get<sol::optional<bool>>("enabled"))          s.enabled = *v;
    if (auto v = t.get<sol::optional<bool>>("usingForTransforms")) s.usingForTransforms = *v;
    if (auto v = t.get<sol::optional<bool>>("preventOvershoot")) s.preventOvershoot = *v;

    if (auto v = t.get<sol::optional<float>>("maxVelocity"))     s.maxVelocity = *v;
    if (auto v = t.get<sol::optional<float>>("smoothingFactor")) s.smoothingFactor = *v;

    // time/easing (optional)
    if (auto v = t.get<sol::optional<float>>("timeToTarget"))    s.timeToTarget = *v;
    // easingFunction can be wired separately via animate_to_time from Lua; leave nullptr here.
}

inline std::pair<entt::entity, spring::Spring&>
make_and_attach(entt::registry& reg, float value, float stiffness, float damping, const sol::optional<sol::table>& opts) {
    auto e = reg.create();
    auto &sp = reg.emplace<spring::Spring>(e);
    sp.value = value;
    sp.targetValue = value;
    sp.stiffness = stiffness;
    sp.damping = damping;
    sp.enabled = true;
    sp.usingForTransforms = true;
    apply_opts(sp, opts);
    return { e, sp };
}

inline spring::Spring&
attach_to(entt::registry& reg, entt::entity e, float value, float stiffness, float damping, const sol::optional<sol::table>& opts) {
    auto &sp = reg.emplace_or_replace<spring::Spring>(e);
    sp.value = value;
    sp.targetValue = value;
    sp.stiffness = stiffness;
    sp.damping = damping;
    sp.enabled = true;
    sp.usingForTransforms = true;
    apply_opts(sp, opts);
    return sp;
}

inline void bind_spring(sol::state& lua) {
    using spring::Spring;
    auto &rec = BindingRecorder::instance();

    // Module table
    lua["spring"] = sol::table(lua, sol::create);
    rec.add_type("spring").doc = "Spring module: component, factories, and update helpers.";

    // Usertype
    lua.new_usertype<Spring>("Spring",
        sol::no_constructor,
        // fields
        "value",            &Spring::value,
        "targetValue",      &Spring::targetValue,
        "velocity",         &Spring::velocity,
        "stiffness",        &Spring::stiffness,
        "damping",          &Spring::damping,
        "enabled",          &Spring::enabled,
        "usingForTransforms",&Spring::usingForTransforms,
        "preventOvershoot", &Spring::preventOvershoot,
        "maxVelocity",      &Spring::maxVelocity,
        "smoothingFactor",  &Spring::smoothingFactor,
        "timeToTarget",     &Spring::timeToTarget,
        // methods
        "pull", +[](Spring& s, float force, sol::optional<float> k, sol::optional<float> d) {
            spring::pull(s, force, k ? *k : -1.f, d ? *d : -1.f);
        },
        "animate_to", +[](Spring& s, float target, float k, float d) {
            spring::animateToTarget(s, target, k, d);
        },
        "animate_to_time", +[](Spring& s, float target, float time_to_target, sol::optional<sol::function> easing,
                               sol::optional<float> k0, sol::optional<float> d0) {
            // wrap Lua easing (0..1 -> 0..1) into std::function<double(double)>
            std::function<double(double)> ef{};
            if (easing) {
                sol::function f = *easing;
                ef = [f](double x) -> double {
                    sol::protected_function pf = f;
                    sol::protected_function_result r = pf(x);
                    if (!r.valid()) return x; // fallback
                    return r.get<double>();
                };
            }
            spring::animateToTargetWithTime(s, target, time_to_target, ef,
                                            k0.value_or(100.f), d0.value_or(10.f));
        },
        "enable",  +[](Spring& s){ s.enabled = true; },
        "disable", +[](Spring& s){ s.enabled = false; },
        "snap_to_target", +[](Spring& s){ s.value = s.targetValue; s.velocity = 0.f; }
    );

    rec.add_type("Spring").doc =
        "Critically damped transform-friendly spring component. "
        "Use fields for direct control; call methods for pulls/animations.";
    rec.record_property("Spring", {"value", "number", "Current value."});
    rec.record_property("Spring", {"targetValue", "number", "Current target value."});
    rec.record_property("Spring", {"velocity", "number", "Current velocity."});
    rec.record_property("Spring", {"stiffness", "number", "Hooke coefficient (k)."});
    rec.record_property("Spring", {"damping", "number", "Damping factor (c)."});
    rec.record_property("Spring", {"enabled", "boolean", "If false, update() is skipped."});
    rec.record_property("Spring", {"usingForTransforms", "boolean", "Use transform-safe update path."});
    rec.record_property("Spring", {"preventOvershoot", "boolean", "Clamp crossing to avoid overshoot."});
    rec.record_property("Spring", {"maxVelocity", "number|nil", "Optional velocity clamp."});
    rec.record_property("Spring", {"smoothingFactor", "number|nil", "0..1, scales integration step."});
    rec.record_property("Spring", {"timeToTarget", "number|nil", "If set, animate_to_time controls k/d over time."});
    rec.record_method("Spring", {"pull", "---void(number force, number? k, number? d)", "Impulse-like tug on current value."});
    rec.record_method("Spring", {"animate_to", "---void(number target, number k, number d)", "Move anchor with spring params."});
    rec.record_method("Spring", {"animate_to_time", "---void(number target, number T, function? easing, number? k0, number? d0)", "Time-based targeting with easing."});
    rec.record_method("Spring", {"enable", "---void()", "Enable updates."});
    rec.record_method("Spring", {"disable", "---void()", "Disable updates."});
    rec.record_method("Spring", {"snap_to_target", "---void()", "Snap value to target; zero velocity."});

    // Factories (one-liners)
    lua["spring"]["make"] = +[](entt::registry& reg, float value, float k, float d, sol::optional<sol::table> opts) {
        auto [e, sp] = make_and_attach(reg, value, k, d, opts);
        return std::make_tuple(e, std::ref(sp)); // returns (entity, Spring)
    };
    rec.record_method("spring", {"make", "---(entity, Spring) make(Registry, number value, number k, number d, table? opts)", 
        "Create entity, attach Spring, return both."});
    
    lua["spring"]["get_or_make"] = +[](entt::registry& reg, entt::entity e, float value, float k, float d, sol::optional<sol::table> opts) {
        if (reg.all_of<spring::Spring>(e)) {
            auto &sp = reg.get<spring::Spring>(e);
            return std::ref(sp);
        } else {
            auto &sp = reg.emplace<spring::Spring>(e);
            sp.value = value;
            sp.targetValue = value;
            sp.stiffness = k;
            sp.damping = d;
            sp.enabled = true;
            sp.usingForTransforms = true;
            apply_opts(sp, opts);
            return std::ref(sp);
        }
    };
    rec.record_method("spring", {"get_or_make", "---Spring get_or_make(Registry, entity, number value, number k, number d, table? opts)",
        "Get existing Spring on entity, or create and attach if missing."});    
        
    lua["spring"]["get"] = +[](entt::registry& reg, entt::entity e) -> spring::Spring& {
        return reg.get<spring::Spring>(e);
    };
    rec.record_method("spring", {"get", "---Spring get(Registry, entity)",
        "Get existing Spring on entity; errors if missing."});
        
    lua["spring"]["attach"] = +[](entt::registry& reg, entt::entity e, float value, float k, float d, sol::optional<sol::table> opts) {
        Spring& sp = attach_to(reg, e, value, k, d, opts);
        return std::ref(sp);
    };
    rec.record_method("spring", {"attach", "---Spring attach(Registry, entity, number value, number k, number d, table? opts)",
        "Attach or replace Spring on an existing entity."});

    // Updates
    lua["spring"]["update_all"] = +[](entt::registry& reg, float dt){
        spring::updateAllSprings(reg, dt);
    };
    lua["spring"]["update"] = +[](Spring& s, float dt){
        spring::update(s, dt);
    };
    rec.record_method("spring", {"update_all", "---void(Registry, number dt)", "Update all Spring components in the registry."});
    rec.record_method("spring", {"update", "---void(Spring, number dt)", "Update a single Spring."});

    // Nice sugar: set target only
    lua["spring"]["set_target"] = +[](Spring& s, float target){ s.targetValue = target; };
    rec.record_method("spring", {"set_target", "---void(Spring, number target)", "Set target without touching k/d."});
}

} // namespace bind
