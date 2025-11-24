#include "timer.hpp"

#include "sol/types.hpp"
#include "util/common_headers.hpp"
#include "../../core/globals.hpp"
#include "../../core/game.hpp"
#include "util/error_handling.hpp"

#include "systems/ai/ai_system.hpp"
#include "systems/scripting/binding_recorder.hpp"
#include <cstdlib>

namespace timer
{
    
    // 1) Four-arg version
    static void lua_tween4(std::variant<float,std::pair<float,float>> d,
        const std::function<float()>& getter,
        const std::function<void(float)>& setter,
        float target_value, std::string tag )
    {
        TimerSystem::timer_tween(d, getter, setter, target_value, tag);
    }
    
    static std::function<bool()>
wrap_condition(sol::function f) {
    if (!f.valid()) {
        return []() { return false; };  // Return a no-op condition if the Lua function is invalid
    }
    sol::protected_function pf(std::move(f));
    return [pf=std::move(pf)]() mutable {
        auto r = util::safeLuaCall(pf, "timer condition");
        if (r.isErr()) {
            SPDLOG_ERROR("Timer condition failed: {}", r.error());
            std::abort();
            return false;
        }
        return r.value().get<bool>();
    };
}

static std::function<float(float)>
wrap_ff(sol::function f) {
    if (!f.valid()) {
        return [](float x) { return x; };  // Return identity function if the Lua function is invalid
    }
    sol::protected_function pf(std::move(f));
    return [pf=std::move(pf)](float x) mutable {
        auto r = util::safeLuaCall(pf, "timer float->float", x);
        if (r.isErr()) {
            SPDLOG_ERROR("Timer float→float failed: {}", r.error());
            std::abort();
            return 0.f;
        }
        return r.value().get<float>();
    };
}
    
    // for use with after() functions optionally provided in timer functions
    static std::function<void()>
wrap_noarg_callback(sol::function luaFunc) {


    if (!luaFunc.valid()) {
        return []() {};  // Return a no-op function if the Lua function is invalid
    }
    // Move the raw sol::function into a protected_function for error handling
    sol::protected_function protectedFn(std::move(luaFunc));

    // Return a zero-arg std::function that calls the protected function
    return [protectedFn = std::move(protectedFn)]() mutable {
        auto result = util::safeLuaCall(protectedFn, "timer callback");
        if (result.isErr()) {
            SPDLOG_ERROR("Lua callback failed: {}", result.error());
            std::abort();
        }
    };
}

void dump_lua_state(lua_State* L) {
    // 1) Status (OK, YIELD, ERRRUN, ERRMEM, ERRERR, etc)
    int stat = lua_status(L);
    SPDLOG_DEBUG("Lua status: {} ({})", stat, lua_typename(L, stat));

    // 2) Memory usage (in KBytes)
    int kb = lua_gc(L, LUA_GCCOUNT, 0);
    SPDLOG_DEBUG("Lua memory: {} KB", kb);

    // 3) Stack top
    int top = lua_gettop(L);
    SPDLOG_DEBUG("Lua stack top = {}", top);


    // 5) Backtrace of call frames
    {
      lua_Debug ar;
      int level = 0;
      while (lua_getstack(L, level, &ar)) {
        lua_getinfo(L, "nSl", &ar);
        SPDLOG_DEBUG(
          "[frame {}] {}:{}  function = {}",
          level,
          ar.short_src,
          ar.currentline,
          (ar.name ? ar.name : "<anonymous>")
        );
        ++level;
      }
    }
}

    auto clone_to_main = [](sol::function thread_fn) {
        // 1) get a view of your real, main-state Lua
        sol::state_view main_sv{ ai_system::masterStateLua };

        // 2) stash the passed-in function into a temporary global
        main_sv.set("__timer_import", thread_fn);

        // 3) pull it back out — now it’s bound to the main-state lua_State*
        sol::function main_fn = main_sv.get<sol::function>("__timer_import");

        // 4) clean up the temp
        main_sv["__timer_import"] = sol::lua_nil;

        return main_fn;
    };


    // for main actions in timers
    static std::function<void(std::optional<float>)>
wrap_timer_action(sol::function action) {
    sol::protected_function protectedAction(std::move(action));

    return [protectedAction = std::move(protectedAction)]
           (std::optional<float> dt) mutable
    {
        // 1) Grab the raw lua_State pointer
        lua_State* L = protectedAction.lua_state();
        
        // dump_lua_state(L);

        auto luaResult = dt.has_value()
            ? util::safeLuaCall(protectedAction, "timer_action(dt)", *dt)
            : util::safeLuaCall(protectedAction, "timer_action()");

        if (luaResult.isErr()) {
            SPDLOG_ERROR("Timer action failed: {}", luaResult.error());
            std::abort();
        }

        // SPDLOG_DEBUG("<< Timer callback end");
    };
}

    
    /*
    local ed = EventQueueSystem.EaseDataBuilder()
                  :Type(EaseType.QUAD_OUT)
                  :StartValue(0)
                  :EndValue(100)
                  :StartTime(0)
                  :EndTime(2)
                  :SetCallback(function(v) myValue = v end)
                  :Build()

    EventQueueSystem.add_event({
        eventTrigger = TriggerType.EASE,
        delaySeconds = 0,
        ease = ed,
        func = function(t) return true end,
        tag  = "myEasedEvent"
    })
    */
    void exposeToLua(sol::state &lua) {
        
        // BindingRecorder instance
        auto& rec = BindingRecorder::instance();

        // 1) Get or create the `timer` table
        sol::state_view luaView{lua};
        auto t = luaView["timer"].get_or_create<sol::table>();
        if (!t.valid()) {
            t = lua.create_table();
            lua["timer"] = t;
        }
        // Recorder: Top-level namespace
        rec.add_type("timer").doc = "A system for creating, managing, and updating timers.";

        // 2) timer.math sub-table
        auto m = t["math"].get_or_create<sol::table>();
        if (!m.valid()) {
            m = t.create_named("math");
        }
        m.set_function("remap", &timer::math::remap);
        m.set_function("lerp",  &timer::math::lerp);
        // Recorder: Sub-module and its functions
        rec.add_type("timer.math").doc = "Mathematical utility functions for timers.";
        rec.record_free_function({"timer", "math"}, {
            "remap",
            "---@param value number\n---@param from1 number\n---@param to1 number\n---@param from2 number\n---@param to2 number\n---@return number",
            "Re-maps a number from one range to another.",
            true, false
        });
        rec.record_free_function({"timer", "math"}, {
            "lerp",
            "---@param a number\n---@param b number\n---@param t number\n---@return number",
            "Linearly interpolates between two points.",
            true, false
        });

        // 3) TimerType enum
        t.new_enum<timer::TimerType>("TimerType", {
            {"RUN",        timer::TimerType::RUN},
            {"AFTER",      timer::TimerType::AFTER},
            {"COOLDOWN",   timer::TimerType::COOLDOWN},
            {"EVERY",      timer::TimerType::EVERY},
            {"EVERY_STEP", timer::TimerType::EVERY_STEP},
            {"FOR",        timer::TimerType::FOR},
            {"TWEEN",      timer::TimerType::TWEEN},
            {"EVERY_RENDER_FRAME_ONLY", timer::TimerType::EVERY_RENDER_FRAME_ONLY}
        });
        // Recorder: Enum definition as a documented class with properties
        auto& timerType = rec.add_type("timer.TimerType");
        timerType.doc = "Specifies the behavior of a timer.";
        rec.record_property("timer.TimerType", {"RUN",        std::to_string(static_cast<int>(timer::TimerType::RUN)), "Runs once immediately."});
        rec.record_property("timer.TimerType", {"AFTER",      std::to_string(static_cast<int>(timer::TimerType::AFTER)), "Runs once after a delay."});
        rec.record_property("timer.TimerType", {"COOLDOWN",   std::to_string(static_cast<int>(timer::TimerType::COOLDOWN)), "A resettable one-shot timer."});
        rec.record_property("timer.TimerType", {"EVERY",      std::to_string(static_cast<int>(timer::TimerType::EVERY)), "Runs repeatedly at an interval."});
        rec.record_property("timer.TimerType", {"EVERY_STEP", std::to_string(static_cast<int>(timer::TimerType::EVERY_STEP)), "Runs repeatedly every N frames."});
        rec.record_property("timer.TimerType", {"FOR",        std::to_string(static_cast<int>(timer::TimerType::FOR)), "Runs every frame for a duration."});
        rec.record_property("timer.TimerType", {"TWEEN",      std::to_string(static_cast<int>(timer::TimerType::TWEEN)), "Interpolates a value over a duration."});
        rec.record_property("timer.TimerType", {"EVERY_RENDER_FRAME_ONLY", std::to_string(static_cast<int>(timer::TimerType::EVERY_RENDER_FRAME_ONLY)), "Runs every render frame, ignoring time scaling."});

        // 4) Core control/query
        t.set_function("cancel",            &timer::TimerSystem::cancel_timer);
        t.set_function("get_every_index",   &timer::TimerSystem::timer_get_every_index);
        t.set_function("reset",             &timer::TimerSystem::timer_reset);
        t.set_function("get_delay",         &timer::TimerSystem::timer_get_delay);
        t.set_function("set_multiplier",    &timer::TimerSystem::timer_set_multiplier);
        t.set_function("get_multiplier",    &timer::TimerSystem::timer_get_multiplier);
        t.set_function("get_for_elapsed",   &timer::TimerSystem::timer_get_for_elapsed_time);
        t.set_function("get_timer_and_delay",&timer::TimerSystem::timer_get_timer_and_delay);
        
        t.set_function("clear_all", &timer::TimerSystem::clear_all_timers);
        rec.record_free_function({"timer"}, {
            "clear_all",
            "---@return nil",
            "Clears ALL active timers from the system.",
            true, false
        });
        
        // Recorder: control/query functions
        rec.record_free_function({"timer"}, {
            "cancel",
            "---@param timerHandle integer # The handle of the timer to cancel.\n"
            "---@return nil",
            "Cancels and destroys an active timer.",
            true, false
        });

        rec.record_free_function({"timer"}, {
            "get_every_index",
            "---@param timerHandle integer # The handle of an 'every' timer.\n"
            "---@return integer|nil # The current invocation count, or nil if not found.",
            "Gets the current invocation count for an 'every' timer.",
            true, false
        });

        rec.record_free_function({"timer"}, {
            "reset",
            "---@param timerHandle integer # The handle of the timer to reset.\n"
            "---@return nil",
            "Resets a timer's elapsed time, such as for a 'cooldown'.",
            true, false
        });

        rec.record_free_function({"timer"}, {
            "get_delay",
            "---@param timerHandle integer # The handle of the timer.\n"
            "---@return number|nil # The timer's current delay, or nil if not found.",
            "Gets the configured delay time for a timer.",
            true, false
        });

        rec.record_free_function({"timer"}, {
            "set_multiplier",
            // This Lua binding appears to set a global multiplier,
            // whereas the C++ header shows a per-timer setter. The doc reflects the global intent.
            "---@param multiplier number # The new global speed multiplier.\n"
            "---@return nil",
            "Sets the global speed multiplier for all timers.",
            true, false
        });

        rec.record_free_function({"timer"}, {
            "get_multiplier",
            "---@return number",
            "Gets the global timer speed multiplier.",
            true, false
        });

        rec.record_free_function({"timer"}, {
            "get_for_elapsed",
            "---@param timerHandle integer # The handle of a 'for' timer.\n"
            "---@return number|nil # The normalized elapsed time (0.0 to 1.0), or nil if not found.",
            "Gets the elapsed time for a 'for' timer.",
            true, false
        });

        rec.record_free_function({"timer"}, {
            "get_timer_and_delay",
            "---@param timerHandle integer # The handle of the timer.\n"
            "---@return number, number # Returns two values: the elapsed time and the total delay. Returns a single nil if not found.",
            "Returns the timer object's elapsed time and its configured delay.",
            true, false
        });


        // 5) Ticking
        t.set_function("update", &timer::TimerSystem::update_timers);
        // Recorder: ticking function
        rec.record_free_function({"timer"}, {"update", "---@param dt number # Delta time.\n---@return nil", "Updates all active timers, should be called once per frame.", true, false});
        
        // clone whatever function is passed in to the main Lua state, so we won't have issues with lua threads going out of scope (if timers are called from a coroutine)
        auto clone_to_main = [](sol::function thread_fn) {
            // 1) get a view of your real, main-state Lua
            sol::state_view main_sv{ ai_system::masterStateLua };
        
            // 2) stash the passed-in function into a temporary global
            main_sv.set("__timer_import", thread_fn);
        
            // 3) pull it back out — now it’s bound to the main-state lua_State*
            sol::function main_fn = main_sv.get<sol::function>("__timer_import");
        
            // 4) clean up the temp
            main_sv["__timer_import"] = sol::lua_nil;
        
            return main_fn;
        };
        // 6) Creation APIs
        // timer_run(action, after, tag)
        t.set_function("run",
            [clone_to_main](sol::function action,
            sol::function after,
            sol::optional<std::string> maybeTag,
            sol::optional<std::string> maybeGroup)
            {
                auto actionWrapper = wrap_timer_action(clone_to_main(action));
                auto afterWrapper  = wrap_noarg_callback(std::move(after));
                std::string tag = maybeTag.value_or("");
                std::string group = maybeGroup.value_or("");
                timer::TimerSystem::timer_run(actionWrapper, afterWrapper, tag, group);
            });
        // timer_run_every_render_frame(action, after, tag)
        t.set_function("run_every_render_frame", [clone_to_main](sol::function action,
                                                         sol::function after,
                                                         sol::optional<std::string> maybeTag,
                                                         sol::optional<std::string> maybeGroup)
        {
            auto actionWrapper = wrap_timer_action(clone_to_main(action));
            auto afterWrapper = wrap_noarg_callback(std::move(after));
            std::string tag = maybeTag.value_or("");
            std::string group = maybeGroup.value_or("");

            timer::TimerSystem::timer_run_every_render_frame(actionWrapper, afterWrapper, tag, group);
        });
        rec.record_free_function({"timer"}, {
            "run_every_render_frame",
            "---@param action fun(dt:number)\n"
            "---@param after? fun()\n"
            "---@param tag? string\n"
            "---@param group? string\n"
            "---@return integer # timerHandle",
            "Creates a timer that runs once every rendered frame (unaffected by fixed timestep updates).",
            true,
            false
        });

        // timer_after(delay, action, tag)
        t.set_function("after",
            [clone_to_main](std::variant<float,std::pair<float,float>> delay,
            sol::function action,
            sol::optional<std::string> maybeTag,
            sol::optional<std::string> maybeGroup)
            {
                auto actionWrapper = wrap_timer_action(clone_to_main(action));
                std::string tag = maybeTag.value_or("");
                timer::TimerSystem::timer_after(delay, actionWrapper, tag, maybeGroup.value_or(""));
            });
        // timer_cooldown(delay, condition, action, times, after, tag)
        t.set_function("cooldown",
            [clone_to_main](std::variant<float,std::pair<float,float>> delay,
            sol::function condition,
            sol::function action,
            sol::optional<int> maybeTimes,
            sol::function after,
            sol::optional<std::string> maybeTag,
            sol::optional<std::string> maybeGroup)
            {
                int times = maybeTimes.value_or(0);
                auto condWrapper   = wrap_condition(clone_to_main(condition));
                auto actionWrapper = wrap_timer_action(clone_to_main(action));
                auto afterWrapper  = wrap_noarg_callback(clone_to_main(after));
                std::string tag = maybeTag.value_or("");
                timer::TimerSystem::timer_cooldown(
                    delay, condWrapper, actionWrapper, times, afterWrapper, tag, maybeGroup.value_or(""));
            });
        // t.set_function("every",      &timer::TimerSystem::timer_every);
        t.set_function("every",
        [clone_to_main](std::variant<float, std::pair<float, float>> interval,
           sol::function action,
           sol::optional<int> maybeTimes,
           sol::optional<bool> maybeImmediate,
           sol::function maybeAfter,
           sol::optional<std::string> maybeTag,
           sol::optional<std::string> maybeGroup) 
        {
            std::function<void(std::optional<float>)> actionWrapper = wrap_timer_action(clone_to_main(action));
            // if the user passed nil (i.e. no 3rd arg), maybeTimes will be empty
            int times = maybeTimes.value_or(0);
            bool immediate = maybeImmediate.value_or(false);
            // std::function<void()> after = maybeAfter.value_or(sol::function{});
            auto maybeAfterWrapper = wrap_noarg_callback(clone_to_main(maybeAfter));
            std::string tag = maybeTag.value_or("");
            timer::TimerSystem::timer_every(interval, actionWrapper, times, immediate, maybeAfterWrapper, tag, maybeGroup.value_or(""));
        });
        // timer_every_step(start, end, times, action, immediate, step, after, tag)
        t.set_function("every_step",
            [clone_to_main](float start_delay,
            float end_delay,
            int times,
            sol::function action,
            sol::optional<bool> maybeImmediate,
            sol::function step_method,
            sol::function after,
            sol::optional<std::string> maybeTag,
            sol::optional<std::string> maybeGroup)
            {
                bool immediate = maybeImmediate.value_or(false);
                auto actionWrapper = wrap_timer_action(clone_to_main(action));
                auto stepWrapper   = wrap_ff(clone_to_main(step_method));
                auto afterWrapper  = wrap_noarg_callback(clone_to_main(after));
                std::string tag = maybeTag.value_or("");
                timer::TimerSystem::timer_every_step(
                    start_delay, end_delay, times,
                    actionWrapper, immediate,
                    stepWrapper, afterWrapper,
                    tag, maybeGroup.value_or("")
                );
            });
        t.set_function("for_time",
            [clone_to_main](std::variant<float,std::pair<float,float>> duration,
                sol::function action,
                sol::function after,
                sol::optional<std::string> maybeTag,
                sol::optional<std::string> maybeGroup)
            {
                auto actionWrapper = wrap_timer_action(clone_to_main(action));
                auto afterWrapper  = wrap_noarg_callback(clone_to_main(after));
                std::string tag = maybeTag.value_or("");
                timer::TimerSystem::timer_for(duration, actionWrapper, afterWrapper, tag, maybeGroup.value_or(""));
            });
        
        
        
    //     // Now bind them all, *including* the full seven-arg C++ function:
    //     // timer_tween(duration, getter, setter, target, tag, easing, after)
    //     t.set_function("tween",
    //         [clone_to_main](std::variant<float,std::pair<float,float>> duration,
    //         sol::function getter,
    //         sol::function setter,
    //         float target_value,
    //         sol::optional<std::string> maybeTag,
    //         sol::optional<std::string> maybeGroup,
    //         sol::function easing_method,
    //         sol::function after)
    //         {
    //             auto getWrapper = [clone_to_main] (sol::function f) {
    //                 sol::protected_function pf(clone_to_main(f));
    //                 return [pf=std::move(pf)]() mutable {
    //                     auto r = pf();
    //                     if (!r.valid()) {
    //                         sol::error err = r; SPDLOG_ERROR("Tween getter failed: {}", err.what());
    //                         return 0.f;
    //                     }
    //                     return r.get<float>();
    //                 };
    //             }(clone_to_main(getter));

    //             auto setWrapper = [clone_to_main] (sol::function f) {
    //                 sol::protected_function pf(clone_to_main(f));
    //                 return [pf=std::move(pf)](float v) mutable {
    //                     auto r = pf(v);
    //                     if (!r.valid()) {
    //                         sol::error err = r; SPDLOG_ERROR("Tween setter failed: {}", err.what());
    //                     }
    //                 };
    //             }(clone_to_main(setter));

    //             auto easeWrapper = easing_method.valid() ?
    //                 wrap_ff(clone_to_main(easing_method)) :
    //                 [](float t) { return t < 0.5 ? 2 * t * t : t * (4 - 2 * t) - 1; }; // Default easing method (ease-in-out quad)
    //             auto afterWrapper = wrap_noarg_callback(clone_to_main(after));
    //             std::string tag = maybeTag.value_or("");

    //             timer::TimerSystem::timer_tween(
    //                 duration,
    //                 getWrapper,
    //                 setWrapper,
    //                 target_value,
    //                 tag,
    //                 maybeGroup.value_or(""),
    //                 easeWrapper,
    //                 afterWrapper
    //             );
    //         });
            
    //     // Overload: tween(duration, tracks, method?, after?, tag?, group?)
    // // tracks = { {get=function().., set=function(v).., to=number, from?=number}, ... }
    // t.set_function("tween",
    //     [clone_to_main](std::variant<float,std::pair<float,float>> duration,
    //                     sol::table tracksTbl,
    //                     sol::optional<sol::function> maybeMethod,
    //                     sol::optional<sol::function> maybeAfter,
    //                     sol::optional<std::string> maybeTag,
    //                     sol::optional<std::string> maybeGroup)
    //     {
    //         struct Track {
    //             std::function<void(float)> set;
    //             float start = 0.f;
    //             float delta = 0.f;
    //         };

    //         std::vector<Track> tracks;
    //         tracks.reserve(tracksTbl.size());

    //         // Helpers (same wrapping style you already use)
    //         auto wrapGetter = [clone_to_main](sol::function f) {
    //             sol::protected_function pf(clone_to_main(f));
    //             return [pf=std::move(pf)]() mutable -> float {
    //                 auto r = pf();
    //                 if (!r.valid()) { sol::error e = r; SPDLOG_ERROR("Tween get failed: {}", e.what()); return 0.f; }
    //                 return r.get<float>();
    //             };
    //         };
    //         auto wrapSetter = [clone_to_main](sol::function f) {
    //             sol::protected_function pf(clone_to_main(f));
    //             return [pf=std::move(pf)](float v) mutable {
    //                 auto r = pf(v);
    //                 if (!r.valid()) { sol::error e = r; SPDLOG_ERROR("Tween set failed: {}", e.what()); }
    //             };
    //         };

    //         // Build tracks: compute start/delta now
    //         for (auto &kv : tracksTbl) {
    //             sol::table desc = kv.second.as<sol::table>();

    //             sol::object getObj = desc["get"];
    //             sol::object setObj = desc["set"];
    //             if (!getObj.is<sol::function>() || !setObj.is<sol::function>()) {
    //                 SPDLOG_ERROR("tween(): each track needs get=function and set=function");
    //                 continue;
    //             }

    //             float to = 0.f;
    //             if (auto toObj = desc["to"]; toObj.valid() && toObj.is<float>()) {
    //                 to = toObj.get<float>();
    //             } else {
    //                 SPDLOG_ERROR("tween(): each track needs numeric 'to'");
    //                 continue;
    //             }

    //             float start;
    //             if (auto fromObj = desc["from"]; fromObj.valid() && fromObj.is<float>()) {
    //                 start = fromObj.get<float>();
    //             } else {
    //                 start = wrapGetter(getObj.as<sol::function>())();
    //             }

    //             Track tr;
    //             tr.set   = wrapSetter(setObj.as<sol::function>());
    //             tr.start = start;
    //             tr.delta = to - start;
    //             tracks.push_back(std::move(tr));
    //         }

    //         if (tracks.empty()) {
    //             if (maybeAfter && (*maybeAfter).valid()) {
    //                 sol::protected_function pf(clone_to_main(*maybeAfter));
    //                 auto r = pf(); (void)r;
    //             }
    //             return;
    //         }

    //         // Easing: default to linear to match your old Lua behavior
    //         auto ease = (maybeMethod && (*maybeMethod).valid())
    //             ? wrap_ff(clone_to_main(*maybeMethod))
    //             : [](float t){ return t; };

    //         // Compose a single setter that applies progress to all tracks
    //         auto compositeSetter = [tracks = std::move(tracks)](float p) mutable {
    //             for (auto &tr : const_cast<std::vector<Track>&>(tracks)) {
    //                 tr.set(tr.start + tr.delta * p);
    //             }
    //         };

    //         // After callback
    //         auto afterWrapper = (maybeAfter && (*maybeAfter).valid())
    //             ? wrap_noarg_callback(clone_to_main(*maybeAfter))
    //             : [](){};

    //         // Drive progress 0→1 using your existing scalar tween
    //         timer::TimerSystem::timer_tween(
    //             duration,
    //             /*getter*/ [](){ return 0.f; },
    //             /*setter*/ compositeSetter,
    //             /*target*/ 1.f,
    //             /*tag   */ maybeTag.value_or(""),
    //             /*group */ maybeGroup.value_or(""),
    //             /*ease  */ ease,
    //             /*after */ afterWrapper
    //         );
    //     });
        
    //     // Add this overload alongside your existing t.set_function("tween", ...)
    //     t.set_function("tween",
    //         [clone_to_main](std::variant<float, std::pair<float,float>> duration,
    //                         sol::table target,          // table/object whose fields we set
    //                         sol::table source,          // { key = targetValue, ... }
    //                         sol::optional<sol::function> maybeMethod,
    //                         sol::optional<sol::function> maybeAfter,
    //                         sol::optional<std::string> maybeTag,
    //                         sol::optional<std::string> maybeGroup)
    //     {
    //         struct Track { std::string key; double start; double goal; double delta; };
    //         std::vector<Track> tracks;
    //         tracks.reserve(source.size());

    //         // 1) Snapshot initial values and deltas
    //         for (auto &kv : source) {
    //             std::string key = kv.first.as<std::string>();
    //             double goal = kv.second.as<double>();
    //             sol::object cur = target.raw_get<sol::object>(key);
    //             if (!cur.is<double>()) {
    //                 SPDLOG_ERROR("tween(): target.%s is not a number", key.c_str());
    //                 continue;
    //             }
    //             double start = cur.as<double>();
    //             tracks.push_back(Track{key, start, goal, goal - start});
    //         }

    //         // If nothing to tween, just call after and bail
    //         if (tracks.empty()) {
    //             if (maybeAfter && (*maybeAfter).valid()) {
    //                 sol::protected_function pf(clone_to_main(*maybeAfter));
    //                 auto r = pf(); (void)r;
    //             }
    //             return;
    //         }

    //         // 2) Easing (default: linear to match the Lua version)
    //         auto ease = (maybeMethod && (*maybeMethod).valid())
    //             ? wrap_ff(clone_to_main(*maybeMethod))
    //             : [](float t){ return t; };

    //         // 3) Build a "progress" setter that applies to all fields
    //         sol::table target_on_main = target; // or clone_to_main(target) if you truly run off-thread
    //         sol::reference target_ref = target_on_main;

    //         auto setter = [target_ref, tracks = std::move(tracks)](float p) {
    //             sol::table tgt = target_ref;
    //             for (const auto& tr : tracks) {
    //                 const double v = tr.start + tr.delta * p;
    //                 tgt[tr.key] = v;
    //             }
    //         };

    //         // 4) Getter always returns 0; target_value is 1 (progress 0→1)
    //         auto getter = [](){ return 0.0f; };

    //         // 5) After-callback
    //         auto afterWrapper = (maybeAfter && (*maybeAfter).valid())
    //             ? wrap_noarg_callback(clone_to_main(*maybeAfter))
    //             : [](){};

    //         // 6) Dispatch to the existing scalar tween
    //         timer::TimerSystem::timer_tween(
    //             duration,
    //             getter,
    //             setter,
    //             /*target_value*/ 1.0f,
    //             /*tag*/   maybeTag.value_or(""),
    //             /*group*/ maybeGroup.value_or(""),
    //             ease,
    //             afterWrapper
    //         );
    //     });


    
        // 1) scalar: tween(duration, getter, setter, target, [tag], [group], easing, after)
        auto tween_scalar =
        [clone_to_main](std::variant<float,std::pair<float,float>> duration,
                        sol::function getter,
                        sol::function setter,
                        float target_value,
                        sol::optional<std::string> maybeTag,
                        sol::optional<std::string> maybeGroup,
                        sol::function easing_method,
                        sol::function after)
        {
            auto getWrapper = [clone_to_main] (sol::function f) {
                sol::protected_function pf(clone_to_main(f));
                return [pf=std::move(pf)]() mutable {
                    auto r = pf();
                    if (!r.valid()) { sol::error err = r; SPDLOG_ERROR("Tween getter failed: {}", err.what()); return 0.f; }
                    return r.get<float>();
                };
            }(clone_to_main(getter));

            auto setWrapper = [clone_to_main] (sol::function f) {
                sol::protected_function pf(clone_to_main(f));
                return [pf=std::move(pf)](float v) mutable {
                    auto r = pf(v);
                    if (!r.valid()) { sol::error err = r; SPDLOG_ERROR("Tween setter failed: {}", err.what()); }
                };
            }(clone_to_main(setter));

            auto easeWrapper = easing_method.valid()
                ? wrap_ff(clone_to_main(easing_method))
                : [](float t){ return t; }; // recommend unify to linear

            auto afterWrapper = wrap_noarg_callback(clone_to_main(after));

            timer::TimerSystem::timer_tween(
                duration, getWrapper, setWrapper, target_value,
                /*tag*/   maybeTag.value_or(""),
                /*group*/ maybeGroup.value_or(""),
                easeWrapper, afterWrapper
            );
        };

        // 2) tracks: tween(duration, tracksTbl, [method], [after], [tag], [group])
        auto tween_tracks =
        [clone_to_main](std::variant<float,std::pair<float,float>> duration,
                        sol::table tracksTbl,
                        sol::optional<sol::function> maybeMethod,
                        sol::optional<sol::function> maybeAfter,
                        sol::optional<std::string> maybeTag,
                        sol::optional<std::string> maybeGroup)
        {
            struct Track { std::function<void(float)> set; float start=0.f; float delta=0.f; };
            std::vector<Track> tracks;
            tracks.reserve(tracksTbl.size());

            auto wrapGetter = [clone_to_main](sol::function f){
                sol::protected_function pf(clone_to_main(f));
                return [pf=std::move(pf)]() mutable -> float {
                    auto r = pf(); if (!r.valid()) { sol::error e=r; SPDLOG_ERROR("Tween get failed: {}", e.what()); return 0.f; }
                    return r.get<float>();
                };
            };
            auto wrapSetter = [clone_to_main](sol::function f){
                sol::protected_function pf(clone_to_main(f));
                return [pf=std::move(pf)](float v) mutable {
                    auto r = pf(v); if (!r.valid()) { sol::error e=r; SPDLOG_ERROR("Tween set failed: {}", e.what()); }
                };
            };

            for (auto &kv : tracksTbl) {
                sol::table desc = kv.second.as<sol::table>();
                sol::object getObj = desc["get"];
                sol::object setObj = desc["set"];
                if (!getObj.is<sol::function>() || !setObj.is<sol::function>()) { SPDLOG_ERROR("tween(): each track needs get=function and set=function"); continue; }

                float to = desc["to"].is<float>() ? desc["to"].get<float>() : (SPDLOG_ERROR("tween(): each track needs numeric 'to'"), 0.f);
                float start = desc["from"].is<float>() ? desc["from"].get<float>() : wrapGetter(getObj.as<sol::function>())();

                Track tr;
                tr.set   = wrapSetter(setObj.as<sol::function>());
                tr.start = start;
                tr.delta = to - start;
                tracks.push_back(std::move(tr));
            }

            if (tracks.empty()) {
                if (maybeAfter && (*maybeAfter).valid()) { sol::protected_function pf(clone_to_main(*maybeAfter)); auto r = pf(); (void)r; }
                return;
            }

            auto ease = (maybeMethod && (*maybeMethod).valid()) ? wrap_ff(clone_to_main(*maybeMethod))
                                                                : [](float t){ return t; };

            auto compositeSetter = [tracks = std::move(tracks)](float p) mutable {
                for (auto &tr : tracks) tr.set(tr.start + tr.delta * p);
            };

            auto afterWrapper = (maybeAfter && (*maybeAfter).valid()) ? wrap_noarg_callback(clone_to_main(*maybeAfter)) : [](){};

            timer::TimerSystem::timer_tween(
                duration,
                [](){ return 0.f; },
                compositeSetter,
                1.f,
                /*tag*/   maybeTag.value_or(""),
                /*group*/ maybeGroup.value_or(""),
                ease, afterWrapper
            );
        };

        // 3) table fields: tween(duration, targetTable, sourceTable, [method], [after], [tag], [group])
        auto tween_fields =
        [clone_to_main](std::variant<float,std::pair<float,float>> duration,
                        sol::table target,
                        sol::table source,
                        sol::optional<sol::function> maybeMethod,
                        sol::optional<sol::function> maybeAfter,
                        sol::optional<std::string> maybeTag,
                        sol::optional<std::string> maybeGroup)
        {
            struct Track { std::string key; double start; double delta; };
            std::vector<Track> tracks;
            tracks.reserve(source.size());

            for (auto &kv : source) {
                std::string key = kv.first.as<std::string>();
                double goal = kv.second.as<double>();
                sol::object cur = target.raw_get<sol::object>(key);
                if (!cur.is<double>()) { SPDLOG_ERROR("tween(): target.%s is not a number", key.c_str()); continue; }
                double start = cur.as<double>();
                tracks.push_back(Track{key, start, goal - start});
            }

            if (tracks.empty()) {
                if (maybeAfter && (*maybeAfter).valid()) { sol::protected_function pf(clone_to_main(*maybeAfter)); auto r = pf(); (void)r; }
                return;
            }

            auto ease = (maybeMethod && (*maybeMethod).valid()) ? wrap_ff(clone_to_main(*maybeMethod))
                                                                : [](float t){ return t; };

            sol::reference target_ref = target; // pin table
            auto setter = [target_ref, tracks = std::move(tracks)](float p) {
                sol::table tgt = target_ref;
                for (auto& tr : tracks) tgt[tr.key] = tr.start + tr.delta * p;
            };

            auto afterWrapper = (maybeAfter && (*maybeAfter).valid()) ? wrap_noarg_callback(clone_to_main(*maybeAfter)) : [](){};

            timer::TimerSystem::timer_tween(
                duration,
                [](){ return 0.0f; },
                setter,
                1.0f,
                /*tag*/   maybeTag.value_or(""),
                /*group*/ maybeGroup.value_or(""),
                ease, afterWrapper
            );
        };

        // Register all 3 as ONE function:
        t.set_function("tween", sol::overload(tween_scalar, tween_tracks, tween_fields));   
        

        rec.record_free_function({"timer"}, {
            "run",
            "---@param action fun()\n"
            "---@param after? fun()\n"
            "---@param tag? string\n"
            "---@param group? string # Optional group to assign this timer to.\n"
            "---@return integer # timerHandle",
            "Creates a timer that runs an action once immediately.",
            true, false
        });
        
        rec.record_free_function({"timer"}, {
            "after",
            "---@param delay number|{number, number} # A fixed delay or a {min, max} range in seconds.\n"
            "---@param action fun()\n"
            "---@param tag? string\n"
            "---@param group? string # Optional group to assign this timer to.\n"
            "---@return integer # timerHandle",
            "Creates a timer that runs an action once after a delay.",
            true, false
        });
        
        rec.record_free_function({"timer"}, {
            "cooldown",
            "---@param delay number|{number, number} # Cooldown duration in seconds or a {min, max} range.\n"
            "---@param condition fun():boolean # A function that must return true for the action to fire.\n"
            "---@param action fun()\n"
            "---@param times? integer # Number of times to run. 0 for infinite.\n"
            "---@param after? fun()\n"
            "---@param tag? string\n"
            "---@param group? string # Optional group to assign this timer to.\n"
            "---@return integer # timerHandle",
            "Creates a resettable timer that fires an action when a condition is met after a cooldown.",
            true, false
        });
        
        rec.record_free_function({"timer"}, {
            "every",
            "---@param interval number|{number, number} # Interval in seconds or a {min, max} range.\n"
            "---@param action fun()\n"
            "---@param times? integer # Number of times to run. 0 for infinite.\n"
            "---@param immediate? boolean # If true, the action runs immediately on creation.\n"
            "---@param after? fun()\n"
            "---@param tag? string\n"
            "---@param group? string # Optional group to assign this timer to.\n"
            "---@return integer # timerHandle",
            "Creates a timer that runs an action repeatedly at a given interval.",
            true, false
        });
        
        rec.record_free_function({"timer"}, {
            "every_step",
            "---@param start_delay number\n"
            "---@param end_delay number\n"
            "---@param times integer # Total number of steps.\n"
            "---@param action fun()\n"
            "---@param immediate? boolean\n"
            "---@param step_method? fun(t:number):number # Easing function for delay interpolation.\n"
            "---@param after? fun()\n"
            "---@param tag? string\n"
            "---@param group? string # Optional group to assign this timer to.\n"
            "---@return integer # timerHandle",
            "Creates a timer that runs for a set number of steps, interpolating the delay between a start and end value.",
            true, false
        });
        
        rec.record_free_function({"timer"}, {
            "for_time",
            "---@param duration number|{number, number} # Total duration in seconds or a {min, max} range.\n"
            "---@param action fun(dt:number)\n"
            "---@param after? fun()\n"
            "---@param tag? string\n"
            "---@param group? string # Optional group to assign this timer to.\n"
            "---@return integer # timerHandle",
            "Creates a timer that runs an action every frame for a set duration, passing delta time to the action.",
            true, false
        });
        
        rec.record_free_function({"timer"}, {
            "tween",
            "---@param duration number|{number, number} # Duration of the tween in seconds or a {min, max} range.\n"
            "---@param getter fun():number # Function to get the current value.\n"
            "---@param setter fun(value:number) # Function to set the new value.\n"
            "---@param target_value number # The final value for the tween.\n"
            "---@param easing_method? fun(t:number):number # Optional easing function (0.0-1.0).\n"
            "---@param after? fun()\n"
            "---@param tag? string\n"
            "---@param group? string # Optional group to assign this timer to.\n"
            "---@return integer # timerHandle",
            "Creates a timer that interpolates a value towards a target over a duration.",
            true, false
        });
        
        // Overload 1: table fields -> target[sourceKeys] tweened in one timer
        rec.record_free_function({"timer"}, {
            "tween",
            "---@param duration number|{number, number} # Seconds or {min,max} range (randomized at start).\n"
            "---@param target table # Table/object whose numeric fields will be tweened.\n"
            "---@param source table<string, number> # Map of field -> target value (e.g., { sx=0, sy=0 }).\n"
            "---@param method? fun(t:number):number # Easing function; default is linear (t).\n"
            "---@param after? fun() # Called once when all fields reach targets.\n"
            "---@param tag? string # Cancels existing tweens with the same tag.\n"
            "---@param group? string # Optional group bucket for management.\n"
            "---@return integer # timerHandle",
            "Tween multiple numeric fields on a Lua table with a single timer (progress 0→1). Captures start values at creation; one tag/after for the whole batch. Default easing: linear.",
            true, false
        });
        
        // Overload 2: tracks -> array of getter/setter descriptors, all driven by one timer
        rec.record_free_function({"timer"}, {
            "tween",
            "---@param duration number|{number, number} # Seconds or {min,max} range (randomized at start).\n"
            "---@param tracks { {get:fun():number, set:fun(value:number), to:number, from?:number}[] }|table # Array-like table of descriptors.\n"
            "---@param method? fun(t:number):number # Easing function; default is linear (t).\n"
            "---@param after? fun() # Called once when all tracks reach targets.\n"
            "---@param tag? string # Cancels existing tweens with the same tag.\n"
            "---@param group? string # Optional group bucket for management.\n"
            "---@return integer # timerHandle",
            "Tween multiple engine-backed values (get/set pairs) with a single timer. Each track defines get(), set(v), to, and optional from. Captures starts at creation; one tag/after for the whole batch. Default easing: linear.",
            true, false
        });
        
        
        // timer.pause(tag)
        t.set_function("pause",
            [](const std::string& tag) {
                timer::TimerSystem::pause_timer(tag);
            }
        );

        // timer.resume(tag)
        t.set_function("resume",
            [](const std::string& tag) {
                timer::TimerSystem::resume_timer(tag);
            }
        );

        // timer.kill_group(group)
        t.set_function("kill_group",
            [](const std::string& group) {
                timer::TimerSystem::kill_group(group);
            }
        );

        // timer.pause_group(group)
        t.set_function("pause_group",
            [](const std::string& group) {
                timer::TimerSystem::pause_group(group);
            }
        );

        // timer.resume_group(group)
        t.set_function("resume_group",
            [](const std::string& group) {
                timer::TimerSystem::resume_group(group);
            }
        );



        // --- Lua Documentation via recorder ---

        rec.record_free_function({"timer"}, {
            "pause",
            "---@param tag string # The tag/handle of the timer to pause.\n"
            "---@return nil",
            "Pauses the timer with the given tag.",
            true, false
        });

        rec.record_free_function({"timer"}, {
            "resume",
            "---@param tag string # The tag/handle of the timer to resume.\n"
            "---@return nil",
            "Resumes a previously paused timer.",
            true, false
        });

        rec.record_free_function({"timer"}, {
            "kill_group",
            "---@param group string # The name of the timer group to cancel.\n"
            "---@return nil",
            "Cancels (removes) all timers in the specified group.",
            true, false
        });

        rec.record_free_function({"timer"}, {
            "pause_group",
            "---@param group string # The name of the timer group to pause.\n"
            "---@return nil",
            "Pauses all timers in the specified group.",
            true, false
        });

        rec.record_free_function({"timer"}, {
            "resume_group",
            "---@param group string # The name of the timer group to resume.\n"
            "---@return nil",
            "Resumes all timers in the specified group.",
            true, false
        });


        // Recorder: control/query functions
        
        rec.record_free_function({"timer"}, {
            "cancel",
            "---@param timerHandle integer # The handle of the timer to cancel.\n"
            "---@return nil",
            "Cancels and destroys an active timer.",
            true, false
        });

        rec.record_free_function({"timer"}, {
            "get_every_index",
            "---@param timerHandle integer # The handle of an 'every' timer.\n"
            "---@return integer|nil # The current invocation count, or nil if not found.",
            "Gets the current invocation count for an 'every' timer.",
            true, false
        });

        rec.record_free_function({"timer"}, {
            "reset",
            "---@param timerHandle integer # The handle of the timer to reset.\n"
            "---@return nil",
            "Resets a timer's elapsed time, such as for a 'cooldown'.",
            true, false
        });

        rec.record_free_function({"timer"}, {
            "get_delay",
            "---@param timerHandle integer # The handle of the timer.\n"
            "---@return number|nil # The timer's current delay, or nil if not found.",
            "Gets the configured delay time for a timer.",
            true, false
        });

        rec.record_free_function({"timer"}, {
            "set_multiplier",
            // This Lua binding appears to set a global multiplier,
            // whereas the C++ header shows a per-timer setter. The doc reflects the global intent.
            "---@param multiplier number # The new global speed multiplier.\n"
            "---@return nil",
            "Sets the global speed multiplier for all timers.",
            true, false
        });

        rec.record_free_function({"timer"}, {
            "get_multiplier",
            "---@return number",
            "Gets the global timer speed multiplier.",
            true, false
        });

        rec.record_free_function({"timer"}, {
            "get_for_elapsed",
            "---@param timerHandle integer # The handle of a 'for' timer.\n"
            "---@return number|nil # The normalized elapsed time (0.0 to 1.0), or nil if not found.",
            "Gets the elapsed time for a 'for' timer.",
            true, false
        });

        rec.record_free_function({"timer"}, {
            "get_timer_and_delay",
            "---@param timerHandle integer # The handle of the timer.\n"
            "---@return number, number # Returns two values: the elapsed time and the total delay. Returns a single nil if not found.",
            "Returns the timer object's elapsed time and its configured delay.",
            true, false
        });


        // 1) Get or create the `EventQueueSystem` table
        auto eq = luaView["EventQueueSystem"].get_or_create<sol::table>();
        if (!eq.valid()) {
            eq = lua.create_table();
            lua["EventQueueSystem"] = eq;
        }
        // Recorder: Top-level namespace
        rec.add_type("EventQueueSystem").doc = "A system for managing and processing sequential and timed events.";

        // 2) Enums
        eq.new_enum<timer::EventQueueSystem::EaseType>("EaseType", {
            {"LERP",        timer::EventQueueSystem::EaseType::LERP},
            {"ELASTIC_IN",  timer::EventQueueSystem::EaseType::ELASTIC_IN},
            {"ELASTIC_OUT", timer::EventQueueSystem::EaseType::ELASTIC_OUT},
            {"QUAD_IN",     timer::EventQueueSystem::EaseType::QUAD_IN},
            {"QUAD_OUT",    timer::EventQueueSystem::EaseType::QUAD_OUT}
        });
        auto& easeType = rec.add_type("EventQueueSystem.EaseType");
        easeType.doc = "Collection of easing functions for tweening.";
        rec.record_property("EventQueueSystem.EaseType", {"LERP",        std::to_string(static_cast<int>(timer::EventQueueSystem::EaseType::LERP)), "Linear interpolation."});
        rec.record_property("EventQueueSystem.EaseType", {"ELASTIC_IN",  std::to_string(static_cast<int>(timer::EventQueueSystem::EaseType::ELASTIC_IN)), "Elastic in."});
        rec.record_property("EventQueueSystem.EaseType", {"ELASTIC_OUT", std::to_string(static_cast<int>(timer::EventQueueSystem::EaseType::ELASTIC_OUT)), "Elastic out."});
        rec.record_property("EventQueueSystem.EaseType", {"QUAD_IN",     std::to_string(static_cast<int>(timer::EventQueueSystem::EaseType::QUAD_IN)), "Quadratic in."});
        rec.record_property("EventQueueSystem.EaseType", {"QUAD_OUT",    std::to_string(static_cast<int>(timer::EventQueueSystem::EaseType::QUAD_OUT)), "Quadratic out."});

        eq.new_enum<timer::EventQueueSystem::TriggerType>("TriggerType", {
            {"IMMEDIATE", timer::EventQueueSystem::TriggerType::IMMEDIATE},
            {"AFTER",     timer::EventQueueSystem::TriggerType::AFTER},
            {"BEFORE",    timer::EventQueueSystem::TriggerType::BEFORE},
            {"EASE",      timer::EventQueueSystem::TriggerType::EASE},
            {"CONDITION", timer::EventQueueSystem::TriggerType::CONDITION}
        });
        auto& triggerType = rec.add_type("EventQueueSystem.TriggerType");
        triggerType.doc = "Defines when an event in the queue should be triggered.";
        rec.record_property("EventQueueSystem.TriggerType", {"IMMEDIATE", std::to_string(static_cast<int>(timer::EventQueueSystem::TriggerType::IMMEDIATE)), "Triggers immediately."});
        rec.record_property("EventQueueSystem.TriggerType", {"AFTER",     std::to_string(static_cast<int>(timer::EventQueueSystem::TriggerType::AFTER)), "Triggers after a delay."});
        rec.record_property("EventQueueSystem.TriggerType", {"BEFORE",    std::to_string(static_cast<int>(timer::EventQueueSystem::TriggerType::BEFORE)), "Triggers before a delay."});
        rec.record_property("EventQueueSystem.TriggerType", {"EASE",      std::to_string(static_cast<int>(timer::EventQueueSystem::TriggerType::EASE)), "Triggers as part of an ease/tween."});
        rec.record_property("EventQueueSystem.TriggerType", {"CONDITION", std::to_string(static_cast<int>(timer::EventQueueSystem::TriggerType::CONDITION)), "Triggers when a condition is met."});

        eq.new_enum<timer::EventQueueSystem::TimerType>("TimerType", {
            {"REAL_TIME",                   timer::EventQueueSystem::TimerType::REAL_TIME},
            {"TOTAL_TIME_EXCLUDING_PAUSE",  timer::EventQueueSystem::TimerType::TOTAL_TIME_EXCLUDING_PAUSE}
        });
        auto& eqTimerType = rec.add_type("EventQueueSystem.TimerType");
        eqTimerType.doc = "Defines which clock an event timer uses.";
        rec.record_property("EventQueueSystem.TimerType", {"REAL_TIME", std::to_string(static_cast<int>(timer::EventQueueSystem::TimerType::REAL_TIME)), "Uses the real-world clock, unaffected by game pause."});
        rec.record_property("EventQueueSystem.TimerType", {"TOTAL_TIME_EXCLUDING_PAUSE", std::to_string(static_cast<int>(timer::EventQueueSystem::TimerType::TOTAL_TIME_EXCLUDING_PAUSE)), "Uses the game clock, which may be paused."});

        // 3) Plain-old structs (as usertypes)
        eq.new_usertype<timer::EventQueueSystem::EaseData>("EaseData",
            "type",               &timer::EventQueueSystem::EaseData::type,
            "startValue",         &timer::EventQueueSystem::EaseData::startValue,
            "endValue",           &timer::EventQueueSystem::EaseData::endValue,
            "startTime",          &timer::EventQueueSystem::EaseData::startTime,
            "endTime",            &timer::EventQueueSystem::EaseData::endTime,
            "setValueCallback",   &timer::EventQueueSystem::EaseData::set_value_callback,
            "getValueCallback",   &timer::EventQueueSystem::EaseData::get_value_callback
        );
        auto& easeData = rec.add_type("EventQueueSystem.EaseData", /*is_data_class=*/true);
        easeData.doc = "Data for an easing/tweening operation.";
        rec.record_property("EventQueueSystem.EaseData", {"type", "EventQueueSystem.EaseType", "The easing function to use."});
        rec.record_property("EventQueueSystem.EaseData", {"startValue", "number", "The starting value of the tween."});
        rec.record_property("EventQueueSystem.EaseData", {"endValue", "number", "The ending value of the tween."});
        rec.record_property("EventQueueSystem.EaseData", {"startTime", "number", "The start time of the tween."});
        rec.record_property("EventQueueSystem.EaseData", {"endTime", "number", "The end time of the tween."});
        rec.record_property("EventQueueSystem.EaseData", {"setValueCallback", "fun(value:number)", "Callback to apply the tweened value."});
        rec.record_property("EventQueueSystem.EaseData", {"getValueCallback", "fun():number", "Callback to get the current value."});

        eq.new_usertype<timer::EventQueueSystem::ConditionData>("ConditionData",
            "check", &timer::EventQueueSystem::ConditionData::checkConditionCallback
        );
        auto& condData = rec.add_type("EventQueueSystem.ConditionData", /*is_data_class=*/true);
        condData.doc = "A condition that must be met for an event to trigger.";
        rec.record_property("EventQueueSystem.ConditionData", {"check", "fun():boolean", "A function that returns true when the condition is met."});

        eq.new_usertype<timer::EventQueueSystem::Event>("Event",
            "eventTrigger",              &timer::EventQueueSystem::Event::eventTrigger,
            "blocksQueue",               &timer::EventQueueSystem::Event::blocksQueue,
            "canBeBlocked",              &timer::EventQueueSystem::Event::canBeBlocked,
            "complete",                  &timer::EventQueueSystem::Event::complete,
            "timerStarted",              &timer::EventQueueSystem::Event::timerStarted,
            "delaySeconds",              &timer::EventQueueSystem::Event::delaySeconds,
            "retainAfterCompletion",     &timer::EventQueueSystem::Event::retainInQueueAfterCompletion,
            "createdWhilePaused",        &timer::EventQueueSystem::Event::createdWhileGamePaused,
            "func",                      &timer::EventQueueSystem::Event::func,
            "timerType",                 &timer::EventQueueSystem::Event::timerTypeToUse,
            "time",                      &timer::EventQueueSystem::Event::time,
            "ease",                      &timer::EventQueueSystem::Event::ease,
            "condition",                 &timer::EventQueueSystem::Event::condition,
            "tag",                       &timer::EventQueueSystem::Event::tag,
            "debugID",                   &timer::EventQueueSystem::Event::debug_string_id,
            "deleteNextCycleImmediately",&timer::EventQueueSystem::Event::deleteNextCycleImmediately
        );
        auto& event = rec.add_type("EventQueueSystem.Event", /*is_data_class=*/true);
        event.doc = "A single event in the event queue.";
        rec.record_property("EventQueueSystem.Event", {"eventTrigger", "EventQueueSystem.TriggerType", "When the event should trigger."});
        rec.record_property("EventQueueSystem.Event", {"blocksQueue", "boolean", "If true, no other events will process until this one completes."});
        rec.record_property("EventQueueSystem.Event", {"canBeBlocked", "boolean", "If true, this event can be blocked by another."});
        rec.record_property("EventQueueSystem.Event", {"complete", "boolean", "True if the event has finished processing."});
        rec.record_property("EventQueueSystem.Event", {"timerStarted", "boolean", "Internal flag for timed events."});
        rec.record_property("EventQueueSystem.Event", {"delaySeconds", "number", "The delay in seconds for 'AFTER' triggers."});
        rec.record_property("EventQueueSystem.Event", {"retainAfterCompletion", "boolean", "If true, the event remains in the queue after completion."});
        rec.record_property("EventQueueSystem.Event", {"createdWhilePaused", "boolean", "If true, the event was created while the game was paused."});
        rec.record_property("EventQueueSystem.Event", {"func", "function", "The callback function to execute."});
        rec.record_property("EventQueueSystem.Event", {"timerType", "EventQueueSystem.TimerType", "The clock type to use for this event's timer."});
        rec.record_property("EventQueueSystem.Event", {"time", "number", "Internal time tracking for the event."});
        rec.record_property("EventQueueSystem.Event", {"ease", "EventQueueSystem.EaseData", "Easing data for tweening events."});
        rec.record_property("EventQueueSystem.Event", {"condition", "EventQueueSystem.ConditionData", "Condition data for conditional events."});
        rec.record_property("EventQueueSystem.Event", {"tag", "string", "An optional tag for finding the event later."});
        rec.record_property("EventQueueSystem.Event", {"debugID", "string", "A debug identifier for the event."});
        rec.record_property("EventQueueSystem.Event", {"deleteNextCycleImmediately", "boolean", "If true, deletes the event on the next update cycle."});
        
        // 4) Builder types
        eq.new_usertype<timer::EventQueueSystem::EaseDataBuilder>("EaseDataBuilder",
            sol::constructors<timer::EventQueueSystem::EaseDataBuilder()>(),
            "Type",       &timer::EventQueueSystem::EaseDataBuilder::Type,
            "StartValue", &timer::EventQueueSystem::EaseDataBuilder::StartValue,
            "EndValue",   &timer::EventQueueSystem::EaseDataBuilder::EndValue,
            "StartTime",  &timer::EventQueueSystem::EaseDataBuilder::StartTime,
            "EndTime",    &timer::EventQueueSystem::EaseDataBuilder::EndTime,
            "SetCallback",&timer::EventQueueSystem::EaseDataBuilder::SetCallback,
            "GetCallback",&timer::EventQueueSystem::EaseDataBuilder::GetCallback,
            "Build",      &timer::EventQueueSystem::EaseDataBuilder::Build
        );
        auto& easeBuilder = rec.add_type("EventQueueSystem.EaseDataBuilder");
        easeBuilder.doc = "A builder for creating EaseData objects.";
        rec.record_method("EventQueueSystem.EaseDataBuilder", {"Type", "---@param type EventQueueSystem.EaseType\n---@return EventQueueSystem.EaseDataBuilder", "Sets the ease type.", false, false});
        rec.record_method("EventQueueSystem.EaseDataBuilder", {"StartValue", "---@param value number\n---@return EventQueueSystem.EaseDataBuilder", "Sets the starting value.", false, false});
        rec.record_method("EventQueueSystem.EaseDataBuilder", {"EndValue", "---@param value number\n---@return EventQueueSystem.EaseDataBuilder", "Sets the ending value.", false, false});
        rec.record_method("EventQueueSystem.EaseDataBuilder", {"StartTime", "---@param time number\n---@return EventQueueSystem.EaseDataBuilder", "Sets the start time.", false, false});
        rec.record_method("EventQueueSystem.EaseDataBuilder", {"EndTime", "---@param time number\n---@return EventQueueSystem.EaseDataBuilder", "Sets the end time.", false, false});
        rec.record_method("EventQueueSystem.EaseDataBuilder", {"SetCallback", "---@param cb fun(value:number)\n---@return EventQueueSystem.EaseDataBuilder", "Sets the 'set value' callback.", false, false});
        rec.record_method("EventQueueSystem.EaseDataBuilder", {"GetCallback", "---@param cb fun():number\n---@return EventQueueSystem.EaseDataBuilder", "Sets the 'get value' callback.", false, false});
        rec.record_method("EventQueueSystem.EaseDataBuilder", {"Build", "---@return EventQueueSystem.EaseData", "Builds the final EaseData object.", false, false});

        eq.new_usertype<timer::EventQueueSystem::EventBuilder>("EventBuilder",
            sol::constructors<timer::EventQueueSystem::EventBuilder()>(),
            "Trigger",                   &timer::EventQueueSystem::EventBuilder::Trigger,
            "BlocksQueue",               &timer::EventQueueSystem::EventBuilder::BlocksQueue,
            "CanBeBlocked",              &timer::EventQueueSystem::EventBuilder::CanBeBlocked,
            "Delay",                     &timer::EventQueueSystem::EventBuilder::Delay,
            "Func",                      &timer::EventQueueSystem::EventBuilder::Func,
            "Ease",                      &timer::EventQueueSystem::EventBuilder::Ease,
            "Condition",                 &timer::EventQueueSystem::EventBuilder::Condition,
            "Tag",                       &timer::EventQueueSystem::EventBuilder::Tag,
            "DebugID",                   &timer::EventQueueSystem::EventBuilder::DebugID,
            "RetainAfterCompletion",     &timer::EventQueueSystem::EventBuilder::RetainAfterCompletion,
            "CreatedWhilePaused",        &timer::EventQueueSystem::EventBuilder::CreatedWhilePaused,
            "TimerType",                 &timer::EventQueueSystem::EventBuilder::TimerType,
            "StartTimer",                &timer::EventQueueSystem::EventBuilder::StartTimer,
            "DeleteNextCycleImmediately",&timer::EventQueueSystem::EventBuilder::DeleteNextCycleImmediately,
            "Build",                     &timer::EventQueueSystem::EventBuilder::Build,
            "AddToQueue",                &timer::EventQueueSystem::EventBuilder::AddToQueue
        );
        auto& eventBuilder = rec.add_type("EventQueueSystem.EventBuilder");
        eventBuilder.doc = "A builder for creating and queuing events.";
        rec.record_method("EventQueueSystem.EventBuilder", {"Trigger", "---@param type EventQueueSystem.TriggerType\n---@return EventQueueSystem.EventBuilder", "Sets the event trigger type.", false, false});
        rec.record_method("EventQueueSystem.EventBuilder", {"BlocksQueue", "---@param blocks boolean\n---@return EventQueueSystem.EventBuilder", "Sets if the event blocks the queue.", false, false});
        rec.record_method("EventQueueSystem.EventBuilder", {"CanBeBlocked", "---@param can_be_blocked boolean\n---@return EventQueueSystem.EventBuilder", "Sets if the event can be blocked.", false, false});
        rec.record_method("EventQueueSystem.EventBuilder", {"Delay", "---@param seconds number\n---@return EventQueueSystem.EventBuilder", "Sets the delay for an 'AFTER' trigger.", false, false});
        rec.record_method("EventQueueSystem.EventBuilder", {"Func", "---@param cb function\n---@return EventQueueSystem.EventBuilder", "Sets the main callback function.", false, false});
        rec.record_method("EventQueueSystem.EventBuilder", {"Ease", "---@param easeData EventQueueSystem.EaseData\n---@return EventQueueSystem.EventBuilder", "Attaches ease data to the event.", false, false});
        rec.record_method("EventQueueSystem.EventBuilder", {"Condition", "---@param condData EventQueueSystem.ConditionData\n---@return EventQueueSystem.EventBuilder", "Attaches a condition to the event.", false, false});
        rec.record_method("EventQueueSystem.EventBuilder", {"Tag", "---@param tag string\n---@return EventQueueSystem.EventBuilder", "Assigns a string tag to the event.", false, false});
        rec.record_method("EventQueueSystem.EventBuilder", {"DebugID", "---@param id string\n---@return EventQueueSystem.EventBuilder", "Assigns a debug ID to the event.", false, false});
        rec.record_method("EventQueueSystem.EventBuilder", {"RetainAfterCompletion", "---@param retain boolean\n---@return EventQueueSystem.EventBuilder", "Sets if the event is kept after completion.", false, false});
        rec.record_method("EventQueueSystem.EventBuilder", {"CreatedWhilePaused", "---@param was_paused boolean\n---@return EventQueueSystem.EventBuilder", "Marks the event as created while paused.", false, false});
        rec.record_method("EventQueueSystem.EventBuilder", {"TimerType", "---@param type EventQueueSystem.TimerType\n---@return EventQueueSystem.EventBuilder", "Sets the timer clock type for the event.", false, false});
        rec.record_method("EventQueueSystem.EventBuilder", {"StartTimer", "---@return EventQueueSystem.EventBuilder", "Starts the timer immediately.", false, false});
        rec.record_method("EventQueueSystem.EventBuilder", {"DeleteNextCycleImmediately", "---@param delete_next boolean\n---@return EventQueueSystem.EventBuilder", "Flags the event for deletion on the next cycle.", false, false});
        rec.record_method("EventQueueSystem.EventBuilder", {"Build", "---@return EventQueueSystem.Event", "Builds the final Event object.", false, false});
        rec.record_method("EventQueueSystem.EventBuilder", {"AddToQueue", "---@return nil", "Builds the event and adds it directly to the queue.", false, false});

        // 5) Core API
        eq.set_function("add_event",        &timer::EventQueueSystem::EventManager::add_event);
        eq.set_function("get_event_by_tag", &timer::EventQueueSystem::EventManager::get_event_by_tag);
        eq.set_function("clear_queue",      &timer::EventQueueSystem::EventManager::clear_queue);
        eq.set_function("update",           &timer::EventQueueSystem::EventManager::update);
       

        // Recorder: core API functions
        rec.record_free_function({"EventQueueSystem"}, {
            "add_event",
            "---@param event EventQueueSystem.Event\n"
            "---@param queue? string # Optional: The name of the queue to add to (defaults to 'base').\n"
            "---@param front? boolean # Optional: If true, adds the event to the front of the queue.\n"
            "---@return nil",
            "Adds a pre-built event to the queue.",
            true, false
        });

        rec.record_free_function({"EventQueueSystem"}, {
            "get_event_by_tag",
            "---@param tag string # The tag of the event to find.\n"
            "---@param queue? string # Optional: The specific queue to search in. Searches all if omitted.\n"
            "---@return EventQueueSystem.Event|nil",
            "Finds an active event by its tag.",
            true, false
        });

        rec.record_free_function({"EventQueueSystem"}, {
            "clear_queue",
            "---@param queue? string # Optional: The queue to clear. Clears all if omitted.\n"
            "---@return nil",
            "Removes all events from one or all queues.",
            true, false
        });

        rec.record_free_function({"EventQueueSystem"}, {
            "update",
            "---@param forced? boolean # Optional: If true, forces an update step.\n"
            "---@return nil",
            "Updates the event queue, processing active events.",
            true, false
        });

    }

    namespace TimerSystem
    {
        // in TimerSystem globals
        bool inUpdate = false;
        std::vector<std::string> pendingCancels;
        std::unordered_map<std::string, Timer> timers{}; // Timer Storage
        std::unordered_map<std::string, std::vector<std::string>> groups{}; // Groups of timers w/ tags
        int uuid_counter = base_uid;                     // Counter for generating unique IDs

        // ------------------------------------------------
        // Base timer management functions
        // ------------------------------------------------

        // Timer Run: Calls an action every frame until canceled, then potentially calls an after action
        void timer_run(const std::function<void(std::optional<float>)> &action, const std::function<void()> &after, const std::string &tag, const std::string& group)
        {
            // Generate a random tag if none is provided
            std::string final_tag = tag.empty() ? random_uid() : tag;

            // Create and add the timer
            Timer timer;
            timer.type = TimerType::RUN;
            timer.action = action;
            timer.after = after;

            add_timer(final_tag, std::move(timer), group);

            // Debug: Notify the timer was added
            // SPDLOG_DEBUG("Added 'run' timer with tag: {}", final_tag);
        }
        
        // Timer Run Every Render Frame: Calls an action every render frame until canceled, then potentially calls an after action
        void timer_run_every_render_frame(const std::function<void(std::optional<float>)> &action,
                                  const std::function<void()> &after,
                                  const std::string &tag,
                                  const std::string &group)
        {
            std::string final_tag = tag.empty() ? random_uid() : tag;

            Timer timer;
            timer.type = TimerType::EVERY_RENDER_FRAME_ONLY;
            timer.action = action;
            timer.after = after;
            timer.timer = 0.0f;

            add_timer(final_tag, std::move(timer), group);
        }


        // Timer After: Calls an action after a delay
        void timer_after(std::variant<float, std::pair<float, float>> delay, const std::function<void(std::optional<float>)> &action, const std::string &tag, const std::string& group)
        {
            // Generate a random tag if none is provided
            std::string final_tag = tag.empty() ? random_uid() : tag;

            // Create the timer and set its attributes
            Timer timer;
            timer.type = TimerType::AFTER;
            timer.timer = 0.0f; // Start timer at 0
            timer.action = action;
            timer.after = []() {}; // No after action for `timer_after`

            // Store delay values
            timer.unresolved_delay = delay;
            timer.delay = timer_resolve_delay(delay);

            // Add the timer to the system
            add_timer(final_tag, std::move(timer), group);

            // Debug: Notify the timer was added
            // SPDLOG_DEBUG("Added 'after' timer with tag: {} and delay: {}", final_tag, std::visit([](auto &&arg) -> std::string
                    //                                                                              {
                    // using T = std::decay_t<decltype(arg)>;
                    // if constexpr (std::is_same_v<T, float>) {
                    //     return fmt::format("{}", arg); // Single float
                    // } else if constexpr (std::is_same_v<T, std::pair<float, float>>) {
                    //     return fmt::format("[{}, {}]", arg.first, arg.second); // Pair of floats
                    // } }, delay));
        }

        // Timer Cooldown: Calls an action every delay seconds until a condition is met
        void timer_cooldown(std::variant<float, std::pair<float, float>> delay, const std::function<bool()> &condition, const std::function<void(std::optional<float>)> &action, int times, const std::function<void()> &after, const std::string &tag, const std::string& group)
        {
            // Generate a random tag if none is provided
            std::string final_tag = tag.empty() ? random_uid() : tag;

            // Create the timer and set its attributes
            Timer timer;
            timer.type = TimerType::COOLDOWN;
            timer.timer = 0.0f;
            timer.unresolved_delay = delay;
            timer.delay = timer_resolve_delay(delay);
            timer.condition = condition;
            timer.action = action;
            timer.times = times;
            timer.max_times = times;
            timer.after = after;

            // Add the timer to the system
            add_timer(final_tag, std::move(timer), group);

            // Debug: Notify the timer was added
            // SPDLOG_DEBUG("Added 'cooldown' timer with tag: {} and delay: {}", final_tag, std::visit([](auto &&arg) -> std::string
            //                                                                                         {
            //         using T = std::decay_t<decltype(arg)>;
            //         if constexpr (std::is_same_v<T, float>) {
            //             return fmt::format("{}", arg); // Single float
            //         } else if constexpr (std::is_same_v<T, std::pair<float, float>>) {
            //             return fmt::format("[{}, {}]", arg.first, arg.second); // Pair of floats
            //         } }, delay));
        }

        // Timer Every: Calls an action every delay seconds, potentially a limited number of times
        void timer_every(std::variant<float, std::pair<float, float>> delay, const std::function<void(std::optional<float>)> &action, int times, bool immediate, const std::function<void()> &after, const std::string &tag, const std::string& group)
        {
            // Generate a random tag if none is provided
            std::string final_tag = tag.empty() ? random_uid() : tag;

            // Create the timer and set its attributes
            Timer timer;
            timer.type = TimerType::EVERY;
            timer.timer = 0.0f;
            timer.unresolved_delay = delay;
            timer.delay = timer_resolve_delay(delay);
            timer.action = action;
            timer.times = times;
            timer.max_times = times;
            timer.after = after;

            // Add the timer to the system
            add_timer(final_tag, std::move(timer), group);

            // Execute the action immediately if required
            if (immediate)
            {
                action(std::nullopt);
            }

            // Debug: Notify the timer was added
            // SPDLOG_DEBUG("Added 'every' timer with tag: {} and delay: {}", final_tag, std::visit([](auto &&arg) -> std::string
            //                                                                                      {
            //         using T = std::decay_t<decltype(arg)>;
            //         if constexpr (std::is_same_v<T, float>) {
            //             return fmt::format("{}", arg); // Single float
            //         } else if constexpr (std::is_same_v<T, std::pair<float, float>>) {
            //             return fmt::format("[{}, {}]", arg.first, arg.second); // Pair of floats
            //         } }, delay));
        }

        // Timer Every Step: Calls an action at regular intervals, potentially a limited number of times
        void timer_every_step(float start_delay, float end_delay, int times, const std::function<void(std::optional<float>)> &action, bool immediate, const std::function<float(float)> &step_method, const std::function<void()> &after, const std::string &tag, const std::string& group)
        {
            if (times < 2)
            {
                throw std::invalid_argument("timer_every_step: 'times' must be >= 2");
            }

            // Generate a random tag if none is provided
            std::string final_tag = tag.empty() ? random_uid() : tag;

            // Calculate the step delay values
            std::vector<float> delays(times);
            float step = (end_delay - start_delay) / (times - 1);

            for (int i = 0; i < times; ++i)
            {
                delays[i] = start_delay + (i * step);
            }

            // Apply step curve if provided
            if (step_method)
            {
                for (int i = 1; i < times - 1; ++i)
                {
                    float normalized_step = static_cast<float>(i) / (times - 1);
                    delays[i] = math::remap(step_method(normalized_step), 0.0f, 1.0f, start_delay, end_delay);
                }
            }

            // Create the timer and set its attributes
            Timer timer;
            timer.type = TimerType::EVERY_STEP;
            timer.timer = 0.0f;
            timer.delays = delays;
            timer.action = action;
            timer.times = times;
            timer.max_times = times;
            timer.after = after;

            // Add the timer to the system
            add_timer(final_tag, std::move(timer), group);

            // Execute the action immediately if required
            if (immediate)
            {
                action(std::nullopt);
            }

            // Debug: Notify the timer was added
            // SPDLOG_DEBUG("Added 'every_step' timer with tag: {} from {} to {} with {} steps", final_tag, start_delay, end_delay, times);
        }

        // Timer For: Calls an action every frame for a duration
        void timer_for(std::variant<float, std::pair<float, float>> duration, const std::function<void(std::optional<float>)> &action, const std::function<void()> &after, const std::string &tag, const std::string& group)
        {
            // Generate a random tag if none is provided
            std::string final_tag = tag.empty() ? random_uid() : tag;

            // Create the timer and set its attributes
            Timer timer;
            timer.type = TimerType::FOR;
            timer.timer = 0.0f;
            timer.unresolved_delay = duration;
            timer.delay = timer_resolve_delay(duration);
            timer.action = [action](std::optional<float> dt)
            { action(dt); }; // Pass delta time to the action
            timer.after = after;

            // Add the timer to the system
            add_timer(final_tag, std::move(timer), group);

            // Debug: Notify the timer was added
            // SPDLOG_DEBUG("Added 'for' timer with tag: {} and duration: {}", final_tag, std::visit([](auto &&arg) -> std::string
            //                                                                                       {
            //         using T = std::decay_t<decltype(arg)>;
            //         if constexpr (std::is_same_v<T, float>) {
            //             return fmt::format("{}", arg); // Single float
            //         } else if constexpr (std::is_same_v<T, std::pair<float, float>>) {
            //             return fmt::format("[{}, {}]", arg.first, arg.second); // Pair of floats
            //         } }, duration));
        }

        /**
         * @brief Creates a tweening timer that interpolates a value over a specified duration using an easing method.
         *
         * @param duration A `std::variant` representing the duration of the tween. It can either be:
         *                 - A single `float` value representing the duration in seconds.
         *                 - A `std::pair<float, float>` representing a range of durations, where the actual duration
         *                   will be randomly selected within the range.
         * @param getter A `std::function<float()>` that retrieves the current value to be tweened.
         * @param setter A `std::function<void(float)>` that sets the interpolated value during the tween.
         * @param target_value The target value to tween towards.
         * @param easing_method A `std::function<float(float)>` that defines the easing method to apply. The input
         *                      is a normalized time value (0.0 to 1.0), and the output is the eased time.
         * @param after A `std::function<void()>` that will be called after the tween completes.
         * @param tag A string identifier for the timer. If empty, a random unique identifier will be generated.
         *
         * @details This function creates a timer of type `TWEEN` that interpolates a value from its current state
         *          (retrieved via `getter`) to the specified `target_value` over the resolved duration. The interpolation
         *          is performed using the provided `easing_method`. The timer is added to the system with the specified
         *          or generated tag. Once the tween completes, the `after` callback is invoked.
         *
         * @note The function logs debug information about the created timer, including its tag, start value, target value,
         *       and duration.
         */
        void timer_tween(std::variant<float, std::pair<float, float>> duration,
                         const std::function<float()> &getter,
                         const std::function<void(float)> &setter,
                         float target_value,
                         const std::string &tag,
                         const std::string& group,
                         const std::function<float(float)> &easing_method,
                         const std::function<void()> &after
                         )
        {
            // Generate a random tag if none is provided
            std::string final_tag = tag.empty() ? random_uid() : tag;

            // Resolve delay
            float resolved_delay = timer_resolve_delay(duration);

            // Cache the start value at the time of tween creation
            float start_value = getter();

            // Create the timer and set its attributes
            Timer timer;
            timer.type = TimerType::TWEEN;
            timer.timer = 0.0f;
            timer.unresolved_delay = duration;
            timer.delay = resolved_delay;
            timer.getter = getter;
            timer.setter = setter;
            timer.target_value = target_value;
            timer.easing_method = easing_method;
            timer.after = after;

            // Set up the tweening action
            timer.action = [start_value, setter, easing_method, resolved_delay, target_value](std::optional<float> elapsed_time)
            {
                // SPDLOG_DEBUG("Tweening from {} to {} with elapsed time: {}", start_value, target_value, elapsed_time.value_or(0.0f));
                float t = std::clamp(elapsed_time.value_or(0.0f) / resolved_delay, 0.0f, 1.0f); // Normalized time
                float eased_t = easing_method(t);                                               // Apply easing
                float interpolated_value = math::lerp(start_value, target_value, eased_t);
                setter(interpolated_value); // Update the value
            };

            // Add the timer to the system
            add_timer(final_tag, std::move(timer), group);

            // Debug: Notify the timer was added
            // SPDLOG_DEBUG("Added 'tween' timer with tag: {} to tween from {} to {} over {} seconds", final_tag, start_value, target_value,
            //              std::visit([](auto &&arg) -> std::string
            //                         {
            // using T = std::decay_t<decltype(arg)>;
            // if constexpr (std::is_same_v<T, float>) {
            //     return fmt::format("{}", arg);
            // } else if constexpr (std::is_same_v<T, std::pair<float, float>>) {
            //     return fmt::format("[{}, {}]", arg.first, arg.second);
            // } }, duration));
        }

    }

    namespace EventQueueSystem
    {

        namespace EventManager
        {
            // Main queues for processing events
            std::map<std::string, std::vector<Event>> queues = {
                {"unlock", {}},
                {"base", {}},
                {"tutorial", {}},
                {"achievement", {}},
                {"other", {}}};

            // Deferred queues for events added during processing
            std::map<std::string, std::vector<Event>> deferred_queues;

            float queue_timer = globals::getTimerReal();
            float queue_dt = 1.0f / 60.0f; // 60 FPS
            float queue_last_processed = globals::getTimerReal();

            // Flag to indicate if events are being processed
            bool processing_events = false;

            // Function to add an event to a queue
            void add_event(const Event &event, const std::string &queue, bool front)
            {
                // Use the appropriate queue based on whether events are being processed
                auto &target_queue = processing_events ? deferred_queues[queue] : queues[queue];

                // Check for tag collision if the event has a tag
                if (!event.tag.empty())
                {
                    auto it = std::find_if(target_queue.begin(), target_queue.end(), [&](const Event &e)
                                           { return e.tag == event.tag; });

                    if (it != target_queue.end())
                    {
                        // Replace the existing event with the new one
                        *it = event;
                        init_event(const_cast<Event &>(*it));
                        return;
                    }
                }

                // Add the event to the appropriate queue
                if (front)
                {
                    init_event(const_cast<Event &>(event));
                    target_queue.insert(target_queue.begin(), event);
                }
                else
                {
                    target_queue.push_back(event);
                }
            }

            // use "tag" to remove all events with a specific tag. This will make replacing certain events easier.
            // if no queue is provided or is empty, events with the tag will be removed from all queues
            void remove_event_by_tag(const std::string &tag, const std::string &queue = "")
            {
                if (processing_events)
                {
                    if (queue.empty())
                    {
                        // Mark events for deletion across all queues
                        for (auto &[key, events] : queues)
                        {
                            for (auto &event : events)
                            {
                                if (event.tag == tag)
                                {
                                    event.deleteNextCycleImmediately = true;
                                }
                            }
                        }
                    }
                    else
                    {
                        // Mark events for deletion in a specific queue
                        auto &events = queues[queue];
                        for (auto &event : events)
                        {
                            if (event.tag == tag)
                            {
                                event.deleteNextCycleImmediately = true;
                            }
                        }
                    }
                }
                else
                {
                    if (queue.empty())
                    {
                        // Remove events directly across all queues
                        for (auto &[key, events] : queues)
                        {
                            events.erase(std::remove_if(events.begin(), events.end(),
                                                        [&](const Event &e)
                                                        { return e.tag == tag; }),
                                         events.end());
                        }
                    }
                    else
                    {
                        // Remove events directly from a specific queue
                        auto &events = queues[queue];
                        events.erase(std::remove_if(events.begin(), events.end(),
                                                    [&](const Event &e)
                                                    { return e.tag == tag; }),
                                     events.end());
                    }
                }
            }

            // Function to query if an event with a specific tag exists and return it
            std::optional<Event> get_event_by_tag(const std::string &tag, const std::string &queue)
            {
                // Search all queues if no specific queue is provided
                if (queue.empty())
                {
                    for (const auto &[key, events] : queues)
                    {
                        auto it = std::find_if(events.begin(), events.end(), [&](const Event &e)
                                               { return e.tag == tag; });

                        if (it != events.end())
                        {
                            return *it; // Return the found event
                        }
                    }
                }
                else
                {
                    // Search within the specified queue
                    auto &events = queues[queue];
                    auto it = std::find_if(events.begin(), events.end(), [&](const Event &e)
                                           { return e.tag == tag; });

                    if (it != events.end())
                    {
                        return *it; // Return the found event
                    }
                }

                // Return an empty optional if no event is found
                return std::nullopt;
            }

            // Function to merge deferred events into the main queues
            void merge_deferred_events()
            {
                for (auto &[queue, deferred_events] : deferred_queues)
                {
                    queues[queue].insert(
                        queues[queue].end(),
                        std::make_move_iterator(deferred_events.begin()),
                        std::make_move_iterator(deferred_events.end()));
                    deferred_events.clear(); // Clear the deferred queue after merging
                }
            }

            void init_event(Event &event)
            {
                event.timerTypeToUse = event.createdWhileGamePaused ? TimerType::REAL_TIME : TimerType::TOTAL_TIME_EXCLUDING_PAUSE;
                event.time = (event.timerTypeToUse == TimerType::REAL_TIME) ? globals::getTimerReal() : globals::getTimerTotal();

                if (event.eventTrigger == TriggerType::EASE)
                {
                    event.ease.startValue = event.ease.get_value_callback();
                }

                if (event.eventTrigger == TriggerType::CONDITION)
                {
                    assert(event.condition.checkConditionCallback);
                }

                if (!event.func)
                {
                    event.func = [](float)
                    { return true; };
                }
            }

            void clear_queue(const std::string &queue, const std::string &exception)
            {
                if (queue.empty())
                {
                    for (auto &[key, events] : queues)
                    {
                        events.erase(std::remove_if(events.begin(), events.end(),
                                                    [](const Event &event)
                                                    { return !event.retainInQueueAfterCompletion; }),
                                     events.end());
                    }
                }
                else if (!exception.empty())
                {
                    for (auto &[key, events] : queues)
                    {
                        if (key != exception)
                        {
                            events.erase(std::remove_if(events.begin(), events.end(),
                                                        [](const Event &event)
                                                        { return !event.retainInQueueAfterCompletion; }),
                                         events.end());
                        }
                    }
                }
                else
                {
                    queues[queue].erase(std::remove_if(queues[queue].begin(), queues[queue].end(),
                                                       [](const Event &event)
                                                       { return !event.retainInQueueAfterCompletion; }),
                                        queues[queue].end());
                }
            }

            float getTimer(Event &event)
            {
                return (event.timerTypeToUse == TimerType::REAL_TIME) ? globals::getTimerReal() : globals::getTimerTotal();
            }

            // Function to handle an individual event
            void handle_event(Event &event, bool &blocked, bool &completed, bool &time_done, bool &pause_skip)
            {

                // SPDLOG_DEBUG("Processing event. Trigger: {}", magic_enum::enum_name(event.trigger));

                // Check if the event should be skipped due to pause
                if (!event.createdWhileGamePaused && game::isPaused)
                {
                    // SPDLOG_DEBUG("Event created on pause: {}. Skipping because game is paused", event.created_on_pause);
                    pause_skip = true;
                    return; // Skip event processing if the game is paused and event was not created during the pause
                }

                // Initialize the event's time based on its timer (REAL or TOTAL)
                if (!event.timerStarted)
                {
                    // SPDLOG_DEBUG("Starting timer for event at time: {}", getTimer(event));
                    event.time = (event.timerTypeToUse == TimerType::REAL_TIME) ? globals::getTimerReal() : globals::getTimerTotal();
                    event.timerStarted = true;
                }

                // Handle the "after" trigger, which activates after a certain delay
                if (event.eventTrigger == TriggerType::AFTER)
                {
                    if (event.time + event.delaySeconds <= getTimer(event))
                    {
                        // SPDLOG_DEBUG("Handling after event.");
                        // debugEventPrint( event);

                        time_done = true;
                        completed = event.func(1.0f); // Call event's function and mark as complete TODO: what does the number mean?
                    }
                    else
                    {
                        // SPDLOG_DEBUG("Event not ready to run yet.");
                        // SPDLOG_DEBUG("Event time: {} + Event delay: {} <= Current time: {}", event.time, event.delay, getTimer(event));
                        // debugEventPrint( event);
                    }
                }

                // Handle the "before" trigger, which runs before a certain delay passes
                if (event.eventTrigger == TriggerType::BEFORE)
                {

                    if (!event.complete)
                    {
                        // SPDLOG_DEBUG("Executing before event.");
                        // debugEventPrint( event);
                        completed = event.func(1.0f); // Run the event function before the delay is over
                    }

                    if (event.time + event.delaySeconds <= getTimer(event))
                    {
                        // SPDLOG_DEBUG("Before event time is up:");
                        // debugEventPrint( event);
                        time_done = true; // The event is done after the delay
                    }
                }

                // Handle the "ease" trigger, which involves gradual transitions or animations
                if (event.eventTrigger == TriggerType::EASE)
                {
                    SPDLOG_DEBUG("Handling ease event.");
                    // debugEventPrint( event);
                    if (!event.ease.startTime)
                    {
                        event.ease.startTime = getTimer(event);
                        event.ease.endTime = getTimer(event) + event.delaySeconds;
                        event.ease.startValue = event.ease.get_value_callback();
                    }

                    if (!event.complete)
                    {
                        // Calculate percentage of easing progress
                        float percent_done = (getTimer(event) - event.ease.startTime) / (event.ease.endTime - event.ease.startTime);
                        percent_done = std::clamp(percent_done, 0.0f, 1.0f); // Ensure percent_done stays within [0.0, 1.0]

                        float valueToPassToEaseCallback{};

                        // Apply easing functions
                        if (event.ease.type == EaseType::LERP)
                        {
                            // Linear interpolation from start to end
                            valueToPassToEaseCallback = (1.0f - percent_done) * event.ease.startValue + percent_done * event.ease.endValue;
                            // SPDLOG_DEBUG("LERP value: {}", valueToPassToEaseCallback);
                        }
                        else if (event.ease.type == EaseType::ELASTIC_IN)
                        {
                            // Elastic ease-in
                            float elastic_progress = -std::pow(2, 10 * (percent_done - 1)) * std::sin((percent_done * 10 - 10.75) * 2 * PI / 3);
                            valueToPassToEaseCallback = (1.0f - elastic_progress) * event.ease.startValue + elastic_progress * event.ease.endValue;
                            // SPDLOG_DEBUG("ELASTIC_IN value: {}", valueToPassToEaseCallback);
                        }
                        else if (event.ease.type == EaseType::ELASTIC_OUT)
                        {
                            // Elastic ease-out
                            float elastic_progress = std::pow(2, -10 * percent_done) * std::sin((percent_done * 10 - 0.75) * 2 * PI / 3);
                            valueToPassToEaseCallback = (1.0f - elastic_progress) * event.ease.startValue + elastic_progress * event.ease.endValue;
                            // SPDLOG_DEBUG("ELASTIC_OUT value: {}", valueToPassToEaseCallback);
                        }
                        else if (event.ease.type == EaseType::QUAD_IN)
                        {
                            // Quadratic ease-in
                            float quad_progress = percent_done * percent_done;
                            valueToPassToEaseCallback = (1.0f - quad_progress) * event.ease.startValue + quad_progress * event.ease.endValue;
                            // SPDLOG_DEBUG("QUAD_IN value: {}", valueToPassToEaseCallback);
                        }
                        else if (event.ease.type == EaseType::QUAD_OUT)
                        {
                            // Quadratic ease-out
                            float quad_progress = 1 - (1 - percent_done) * (1 - percent_done);
                            valueToPassToEaseCallback = (1.0f - quad_progress) * event.ease.startValue + quad_progress * event.ease.endValue;
                            SPDLOG_DEBUG("QUAD_OUT value: {}", valueToPassToEaseCallback);
                        }

                        // Finalize easing when the time is up
                        if (getTimer(event) >= event.ease.endTime)
                        {
                            valueToPassToEaseCallback = event.ease.endValue;
                            event.complete = true;
                            completed = true;
                            time_done = true;
                        }

                        event.ease.set_value_callback(valueToPassToEaseCallback);
                    }
                }

                // Handle the "condition" trigger, which completes when a condition is met

                //         if self.trigger == 'condition' then
                //     if not self.complete then _results.completed = self.func() end
                //     _results.time_done = true
                // end
                // REVIEW: so this is supposed to call teh condition function instead of the event's actual function. How to communicate this through the api?
                if (event.eventTrigger == TriggerType::CONDITION)
                {
                    // SPDLOG_DEBUG("Handling condition event.");
                    // debugEventPrint( event);
                    if (event.condition.checkConditionCallback() == true)
                    {                                 // run event function only when condtion is met
                        completed = event.func(1.0f); // Call condition function
                    }
                    time_done = true; // Conditions don't have delays, mark time as done
                }

                // Handle the "immediate" trigger, which executes instantly
                if (event.eventTrigger == TriggerType::IMMEDIATE)
                {
                    // SPDLOG_DEBUG("Handling immediate event.");
                    // debugEventPrint( event);
                    // FIXME: sometimes this causes segfault for some reason, patching with this for now
                    if (event.func)
                    { // Check if the function is valid
                        try
                        {
                            completed = event.func(1.0f); // Execute the function immediately
                        }
                        catch (const std::exception &e)
                        {
                            SPDLOG_ERROR("Event function threw an exception: {}", e.what());
                        }
                        time_done = true;
                    }
                    else
                    {
                        SPDLOG_ERROR("Event function is null.");
                    }
                }

                // If the event is blocking, stop other events from processing
                if (event.blocksQueue)
                {
                    // SPDLOG_DEBUG("Blocking other events after event:");
                    // debugEventPrint( event);
                    blocked = true; // Set blocked flag to prevent other events from processing
                }

                // If the event is completed, mark it as such
                if (completed)
                {
                    // SPDLOG_DEBUG("Completing event:");
                    // debugEventPrint( event);
                    event.complete = true;
                }

                // The event could have been completed in a previous loop (like before trigger)
                if (event.complete)
                {
                    // SPDLOG_DEBUG("Event is complete. Marking handle() return value as complete.");
                    completed = true;
                }
            }

            // Update function to process events
            void update(bool forced)
            {
                ZONE_SCOPED("Update event queue");
                queue_timer = globals::getTimerReal();

                if (queue_timer >= queue_last_processed + queue_dt || forced)
                {
                    queue_last_processed += (forced ? 0 : queue_dt);

                    processing_events = true;

                    for (auto &[key, events] : queues)
                    {
                        bool blocked = false;
                        auto it = events.begin();
                        while (it != events.end())
                        {
                            // Check if the event is marked for immediate deletion
                            if (it->deleteNextCycleImmediately)
                            {
                                it = events.erase(it);
                                continue;
                            }

                            bool blocking = false;
                            bool completed = false;
                            bool time_done = false;
                            bool pause_skip = false;

                            if (!blocked || !it->canBeBlocked)
                            {
                                handle_event(*it, blocking, completed, time_done, pause_skip);
                            }

                            if (pause_skip)
                            {
                                ++it;
                                continue;
                            }

                            if (!blocked && blocking)
                            {
                                blocked = true;
                            }

                            if (completed && time_done)
                            {
                                if (!it->retainInQueueAfterCompletion)
                                {
                                    it = events.erase(it);
                                    if (events.empty())
                                    {
                                        break;
                                    }
                                }
                                else
                                {
                                    ++it;
                                }
                            }
                            else
                            {
                                ++it;
                            }
                        }
                    }

                    processing_events = false;

                    // Merge deferred events into main queues
                    merge_deferred_events();
                }
            }
        } // namespace EventManager
    } // namespace EventQueueSystem

}
