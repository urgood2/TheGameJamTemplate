#pragma once

#include <chrono>
#include "entt/process/process.hpp"
#include "entt/process/scheduler.hpp"
#include "sol/sol.hpp"
#include "sol/state_view.hpp"

// -------------------------------------------------------
// Script Process Class - for task management & chaining w/ lua coroutines
// -------------------------------------------------------

namespace scripting
{

    namespace coroutine_scheduler
    {

#define AUTO_ARG(x) decltype(x), x

        using fsec = std::chrono::duration<float>;

        class script_process : public entt::process<script_process, fsec>
        {
        public:
            script_process(const sol::table &t,
                           const fsec freq = std::chrono::milliseconds{16})
                : m_self{t},
                  m_frequency{freq}
            {
                // grab the raw Lua-side update(self, dt)
                sol::function raw_update = m_self["update"];
                if (raw_update.valid()) {
                    // 1) spin up a fresh Lua thread
                    m_thread = sol::thread::create(m_self.lua_state());
                    
                    // 2) bind our raw_update on that thread
                    sol::state_view thread_view = m_thread.state();
                    thread_view["__update_fn"] = raw_update;

                    // 3) grab it back as a function in that thread
                    sol::function thread_fn = thread_view["__update_fn"];
                    
                    // 4) make a coroutine out of it
                    m_coroutine = sol::coroutine{ thread_fn };
                }

                // Bind C++ methods into the script table
#define BIND(func) m_self.set_function(#func, &script_process::func, this)
                BIND(succeed);
                BIND(fail);
                BIND(pause);
                BIND(unpause);
                BIND(abort);
                BIND(alive);
                BIND(finished);
                BIND(paused);
                BIND(rejected);
#undef BIND
            }

            ~script_process()
            {
                std::cout << "script_process: " << m_self.pointer() << " terminated\n";
                m_self.clear();
                m_self.abandon();
            }

            void init()
            {
                std::cout << "script_process: " << m_self.pointer() << " joined\n";
                _call("init");
            }

            void update(fsec dt, void *)
            {
                if (!m_coroutine || m_coroutine_done)
                    return succeed();

                // **only** pass the number into the coroutine now:
                sol::protected_function_result result = m_coroutine(dt.count());

                if (!result.valid())
                {
                    sol::error err = result;
                    std::cerr << "Coroutine error: " << err.what() << std::endl;
                    return fail();
                }

                if (result.status() == sol::call_status::ok)
                {
                    m_coroutine_done = true;
                    return succeed();
                }
            }

            void succeeded() { _call("succeeded"); }
            void failed() { _call("failed"); }
            void aborted() { _call("aborted"); }

        private:
            void _call(std::string_view function_name)
            {
                if (auto f = m_self[function_name]; f.valid())
                    f(m_self);
            }

        private:
            sol::table m_self;
            sol::coroutine m_coroutine;
            sol::thread    m_thread;      // keep it alive
            bool m_coroutine_done = false;

            fsec m_frequency;
            fsec m_wait_timer{0};
            fsec m_elapsed{0};
        };

        using scheduler = entt::basic_scheduler<fsec>;

        [[nodiscard]] inline sol::table open_scheduler(sol::state &s)
        {
            sol::state_view lua{s};
            auto entt_module = lua["entt"].get_or_create<sol::table>();

            // clang-format off
        entt_module.new_usertype<scheduler>("scheduler",
            sol::meta_function::construct,
            sol::factories([]{ return scheduler{}; }),
            "size", &scheduler::size,
            "empty", &scheduler::empty,
            "clear", &scheduler::clear,
            "attach",
            [](scheduler &self, const sol::table &process,
                const sol::variadic_args &va) {
                auto &continuator = self.template attach<script_process>(process);
                for (sol::table child_process : va) {
                continuator.template then<script_process>(std::move(child_process));
                }
            },
                   "update", [](scheduler &self, float dt) {
                         self.update(fsec{dt}, nullptr);
                    },
            "abort",
            sol::overload(
                [](scheduler &self) { self.abort(); },
                sol::resolve<void(bool)>(&scheduler::abort)
            )
        );
        
        auto& rec = BindingRecorder::instance();
        
        rec.add_type("scheduler")
            .doc = "Task scheduler.";
            
        rec.record_method("scheduler", {
            "size",
            "---@return integer",
            "Returns the number of processes in the scheduler."
        });
        rec.record_method("scheduler", {
            "empty",
            "---@return boolean",
            "Checks if the scheduler has no processes."
        });
        rec.record_method("scheduler", {
            "clear",
            "---@return nil",
            "Clears all processes from the scheduler."
        });
        rec.record_method("scheduler", {
            "attach",
            "---@param process table # The Lua table representing the process.\n---@param ... table # Optional child processes to chain.\n",
            "Attaches a script process to the scheduler, optionally chaining child processes."
        });
        rec.record_method("scheduler", {
            "update",
            "---@param delta_time number # The time elapsed since the last update.\n---@param data any # Optional data to pass to the process.\n",
            "Updates all processes in the scheduler, passing the elapsed time and optional data."
        });
        rec.record_method("scheduler", {
            "abort",
            "---@overload fun():void\n---@overload fun(terminate: boolean):void\n",
            "Aborts all processes in the scheduler. If `terminate` is true, it will terminate all processes immediately."
        });

            // clang-format on

            // lua.require("scheduler", sol::c_call<AUTO_ARG(&open_scheduler)>, false);

            return entt_module;
        }

    }
}

/*
    In main:


    lua.require("scheduler", sol::c_call<AUTO_ARG(&open_scheduler)>, false);

    scheduler scheduler;
    lua["scheduler"] = std::ref(scheduler);


    loop:

    scheduler.update(delta_time);


*/
