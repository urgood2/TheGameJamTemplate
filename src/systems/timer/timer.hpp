#pragma once

#include <functional>
#include <unordered_map>
#include <vector>
#include <string>
#include <optional>
#include <variant>
#include <iostream>
#include <random>
#include <array>
#include <algorithm> 
#include <cmath>
#include <limits>
#include <map>

#include "sol/sol.hpp"

#include "util/common_headers.hpp" // common headers like json, spdlog, tracy etc.


// TODO: probably use a separate random isntance instead of default one
#include "effolkronium/random.hpp"
#include "spdlog/spdlog.h"
using Random = effolkronium::random_static;

namespace timer
{

    /**
     * @brief Math utility functions
     */
    namespace math
    {

        // Remap a value from one range to another
        inline float remap(float x, float in_min, float in_max, float out_min, float out_max)
        {
            return out_min + ((x - in_min) * (out_max - out_min) / (in_max - in_min));
        }

        inline float lerp(float a, float b, float t) {
            return a + t * (b - a);
        }

    }

    enum class TimerType
    {
        RUN,
        AFTER,
        COOLDOWN,
        EVERY,
        EVERY_STEP,
        FOR,
        TWEEN,
        EVERY_RENDER_FRAME_ONLY
    };

    struct Timer
    {
        TimerType type;
        float timer = 0.0f; // Tracks elapsed time
        float delay = 0.0f;
        std::variant<float, std::pair<float, float>> unresolved_delay; // The original delay (fixed or range)
        float multiplier = 1.0f;
        int times = 0;
        int max_times = 0;
        int index = 1;
        std::function<void(std::optional<float>)> action; // Action to call every frame, (optional dt parameter)
        std::function<void()> after = []() {};            // Function to call after cancellation
        std::function<bool()> condition;
        std::vector<float> delays;
        
        bool paused = false; // Whether the timer is paused

        // Tween-specific fields
        std::function<float()> getter;             // Getter function for the value to be tweened
        std::function<void(float)> setter;         // Setter function to update the value being tweened
        float target_value = 0.0f;                 // Target value for tweening
        std::function<float(float)> easing_method; // Easing function for smooth transitions
    };

    // TODO: document which timers use mutilplier
    //  TODO: what happens if I want to ease values that are not float? what about colors?\
    //TODO: clarify when action gets sent in a dt value and when it does not

    namespace TimerSystem
    {
        // in TimerSystem globals
        extern bool inUpdate;
        extern std::vector<std::string> pendingCancels;
        
        extern std::unordered_map<std::string, Timer> timers; // Timer Storage
        
        // new: store groups of timers by tag, does not interfere with the main timers map
        extern std::unordered_map<std::string, std::vector<std::string>> groups;
        
        const std::string default_group_tag = "default"; // Default group for timers. All timers without a group will be added to this group.

        const int base_uid = 0;
        extern int uuid_counter;
        // ------------------------------------------------
        // Base timer management functions
        // ------------------------------------------------

        inline void init()
        {
            // nothing
        }

        // Utility functions for randomization
        inline std::string random_uid()
        {
            // increment the counter
            uuid_counter++;
            return std::to_string(uuid_counter);
        }

        // Core timer management functions
        inline void add_timer(const std::string &tag, const Timer &timer, const std::string& group=default_group_tag)
        { // add a new timer to the system
            timers[tag] = std::move(timer);
            if (!group.empty())
                groups[group].push_back(tag);
        }
        
        inline void pause_timer(const std::string& tag)   { timers.at(tag).paused = true; }
        inline void resume_timer(const std::string& tag)  { timers.at(tag).paused = false; }

        // inline void cancel_timer(const std::string &tag)
        // {
        //     auto it = timers.find(tag);
        //     if (it != timers.end())
        //     {
        //         // Call the "after" function before removing the timer
        //         if (it->second.after)
        //         {
        //             it->second.after();
        //         }

        //         // Remove the timer
        //         timers.erase(it);

        //         // Debug: Notify the timer was canceled
        //         std::cout << "Canceled timer with tag: " << tag << "\n";
        //     }
        // }
        
        inline void cancel_timer(const std::string &tag)
        {
            auto it = timers.find(tag);
            if (it == timers.end()) return;

            // call the after() if you want
            if (it->second.after) it->second.after();

            // if we’re inside update_timers, defer the actual erase
            if (inUpdate) {
                pendingCancels.push_back(tag);
            } else {
                timers.erase(it);
            }
        }

        inline std::optional<int> timer_get_every_index(const std::string &tag)
        {
            // Find the timer by tag
            auto it = timers.find(tag);

            if (it != timers.end())
            {
                const Timer &timer = it->second;

                // Ensure the timer type is 'Every'
                if (timer.type == TimerType::EVERY)
                {
                    return timer.index; // Return the current iteration index
                }
                else
                {
                    // Debug: Timer is not of type 'Every'
                    std::cout << "Timer with tag: " << tag << " is not of type 'Every'.\n";
                    return std::nullopt;
                }
            }
            else
            {
                // Debug: Timer not found
                std::cout << "Attempted to get index of non-existent timer with tag: " << tag << "\n";
                return std::nullopt; // Timer does not exist
            }
        }

        inline void timer_reset(const std::string &tag)
        {
            // Find the timer by tag
            auto it = timers.find(tag);

            if (it != timers.end())
            {
                Timer &timer = it->second;

                // Reset the timer to zero
                timer.timer = 0.0f;

                // Debug: Notify the timer was reset
                std::cout << "Reset timer with tag: " << tag << "\n";
            }
            else
            {
                // Debug: Timer not found
                std::cout << "Attempted to reset non-existent timer with tag: " << tag << "\n";
            }
        }

        inline std::optional<float> timer_get_delay(const std::string &tag)
        {
            // Find the timer by tag
            auto it = timers.find(tag);

            if (it != timers.end())
            {
                return it->second.delay; // Return the current delay value
            }
            else
            {
                // Debug: Timer not found
                std::cout << "Attempted to get delay of non-existent timer with tag: " << tag << "\n";
                return std::nullopt; // Timer does not exist
            }
        }

        inline void timer_set_multiplier(const std::string &tag, float multiplier)
        {
            // Find the timer by tag
            auto it = timers.find(tag);

            if (it != timers.end())
            {
                Timer &timer = it->second;

                // Set the multiplier
                timer.multiplier = multiplier;

                // Debug: Notify the multiplier was updated
                std::cout << "Updated multiplier for timer with tag: " << tag << " to " << multiplier << "\n";
            }
            else
            {
                // Debug: Timer not found
                std::cout << "Attempted to set multiplier for non-existent timer with tag: " << tag << "\n";
            }
        }

        inline std::optional<float> timer_get_multiplier(const std::string &tag)
        {
            // Find the timer by tag
            auto it = timers.find(tag);

            if (it != timers.end())
            {
                return it->second.multiplier; // Return the current multiplier
            }
            else
            {
                // Debug: Timer not found
                std::cout << "Attempted to get multiplier for non-existent timer with tag: " << tag << "\n";
                return std::nullopt;
            }
        }

        inline std::optional<float> timer_get_for_elapsed_time(const std::string &tag)
        {
            // Find the timer by tag
            auto it = timers.find(tag);

            if (it != timers.end())
            {
                const Timer &timer = it->second;

                // Ensure the timer type is 'For'
                if (timer.type == TimerType::FOR)
                {
                    // Calculate the normalized elapsed time
                    return std::clamp(timer.timer / timer.delay, 0.0f, 1.0f);
                }
                else
                {
                    // Debug: Timer is not of type 'For'
                    std::cout << "Timer with tag: " << tag << " is not of type 'For'.\n";
                    return std::nullopt;
                }
            }
            else
            {
                // Debug: Timer not found
                std::cout << "Attempted to get elapsed time for non-existent timer with tag: " << tag << "\n";
                return std::nullopt;
            }
        }

        inline std::optional<std::pair<float, float>> timer_get_timer_and_delay(const std::string &tag)
        {
            // Find the timer by tag
            auto it = timers.find(tag);

            if (it != timers.end())
            {
                const Timer &timer = it->second;

                // Return both the elapsed time and the delay
                return std::make_pair(timer.timer, timer.delay);
            }
            else
            {
                // Debug: Timer not found
                std::cout << "Attempted to get timer and delay for non-existent timer with tag: " << tag << "\n";
                return std::nullopt;
            }
        }

        inline float timer_resolve_delay(const std::variant<float, std::pair<float, float>> &delay)
        {
            if (std::holds_alternative<float>(delay))
            {
                // Fixed delay
                return std::get<float>(delay);
            }
            else
            {
                // Randomized delay within a range
                const auto &range = std::get<std::pair<float, float>>(delay);
                float min_delay = range.first;
                float max_delay = range.second;

                // Generate a random value within the range
                return Random::get<float>(min_delay, max_delay - std::numeric_limits<float>::epsilon());
            }
        }
        
        inline void kill_group(const std::string& group) {
            auto it = groups.find(group);
            if (it == groups.end()) return;
            for (auto& tag : it->second) {
              timers.erase(tag);
            }
            groups.erase(it);
          }
          
        inline void pause_group(const std::string& group) {
            auto it = groups.find(group);
            if (it == groups.end()) return;
            for (auto& tag : it->second) {
                timers[tag].paused = true;
            }
        }
        
        inline void resume_group(const std::string& group) {
            auto it = groups.find(group);
            if (it == groups.end()) return;
            for (auto& tag : it->second) {
                timers[tag].paused = false;
            }
        }
        
        inline void update_render_timers(float dt)
        {
            inUpdate = true;
            std::vector<std::string> toRemove;

            for (auto &[tag, timer] : timers)
            {
                if (timer.type == TimerType::EVERY_RENDER_FRAME_ONLY)
                {
                    timer.action(dt);
                }
            }

            inUpdate = false;
        }


        inline void update_timers(float dt)
        {
            inUpdate = true;

            ZONE_SCOPED("Update Timers"); // custom label
            for (auto it = timers.begin(); it != timers.end();)
            {
                Timer &timer = it->second;
                
                if (timer.paused)
                {
                    // If the timer is paused, skip to the next timer
                    ++it;
                    continue;
                }

                // update timer
                timer.timer += dt;

                // Handle "run" timers
                if (timer.type == TimerType::RUN)
                {
                    timer.action(std::nullopt); // Call the action every frame
                }
                else if (timer.type == TimerType::AFTER)
                {
                    if (timer.timer > timer.delay)
                    {
                        // Execute the action
                        timer.action(std::nullopt);

                        // Remove the timer after execution
                        it = timers.erase(it);

                        // Continue to the next timer
                        continue;
                    }
                }
                else if (timer.type == TimerType::COOLDOWN)
                {
                    // Check if delay has passed and condition is met
                    if (timer.timer > timer.delay * timer.multiplier && timer.condition())
                    {
                        timer.action(std::nullopt);                                // Execute the action
                        timer.timer = 0.0f;                                        // Reset the timer
                        timer.delay = timer_resolve_delay(timer.unresolved_delay); // Recalculate delay

                        // Decrease the remaining times count if applicable
                        if (timer.times > 0)
                        {
                            timer.times--;
                            if (timer.times <= 0)
                            {
                                // Call the after action and remove the timer
                                timer.after();
                                it = timers.erase(it);
                                continue;
                            }
                        }
                    }
                }
                else if (timer.type == TimerType::EVERY)
                {
                    if (timer.timer > timer.delay * timer.multiplier)
                    {
                        timer.action(std::nullopt);                                // Execute the action
                        timer.timer -= timer.delay * timer.multiplier;             // Reset timer for the next interval
                        timer.delay = timer_resolve_delay(timer.unresolved_delay); // Recalculate delay

                        // Decrease the remaining times count if applicable
                        if (timer.times > 0)
                        {
                            timer.times--;
                            if (timer.times <= 0)
                            {
                                // Call the after action and remove the timer
                                timer.after();
                                it = timers.erase(it);
                                continue;
                            }
                        }
                    }
                }
                else if (timer.type == TimerType::EVERY_STEP)
                {
                    if (timer.timer > timer.delays[timer.index] * timer.multiplier)
                    {
                        timer.action(std::nullopt);                                  // Execute the action
                        timer.timer -= timer.delays[timer.index] * timer.multiplier; // Reset timer
                        timer.index++;                                               // Move to the next delay step

                        // Decrease the remaining times count if applicable
                        if (timer.times > 0)
                        {
                            timer.times--;
                            if (timer.times <= 0)
                            {
                                // Call the after action and remove the timer
                                timer.after();
                                it = timers.erase(it);
                                continue;
                            }
                        }
                    }
                }
                else if (timer.type == TimerType::FOR)
                {
                    if (timer.timer <= timer.delay)
                    {
                        timer.action(dt); // Call the action with delta time
                    }
                    else
                    {
                        // Call the after action and remove the timer
                        timer.after();
                        it = timers.erase(it);
                        continue;
                    }
                }
                else if (timer.type == TimerType::TWEEN)
                {
                    float effective = timer.delay * timer.multiplier;  // if you ever use multiplier
                    if (timer.timer < effective)
                    {
                        // Normal interpolated step
                        timer.action(timer.timer);
                    }
                    else
                    {
                        // Final eased step at t = 1.0
                        timer.action(effective);
                        timer.after();
                        it = timers.erase(it);
                        continue;
                    }
                }


                ++it; // Move to the next timer
            }
            inUpdate = false;
            
            // now perform any deferred cancels
            for (auto &tag : pendingCancels) {
                timers.erase(tag);  // safe now, we’re outside the loop
                // Debug: Notify the timer was canceled
                SPDLOG_DEBUG("Canceled timer with tag: {}", tag);
            }
            pendingCancels.clear();
        }
        
        inline void clear_all_timers()
        {
            timers.clear();
            groups.clear();
        }

        // ------------------------------------------------
        // Timer creation functions
        // ------------------------------------------------

        extern void timer_run(const std::function<void(std::optional<float>)> &action, const std::function<void()> &after = []() {}, const std::string &tag = "", const std::string& group=default_group_tag);
        extern void timer_run_every_render_frame(const std::function<void(std::optional<float>)> &action,
                                  const std::function<void()> &after = []() {},
                                  const std::string &tag = "",
                                  const std::string& group=default_group_tag);
        extern void timer_after(std::variant<float, std::pair<float, float>> delay, const std::function<void(std::optional<float>)> &action, const std::string &tag = "", const std::string& group=default_group_tag);
        extern void timer_cooldown(std::variant<float, std::pair<float, float>> delay, const std::function<bool()> &condition, const std::function<void(std::optional<float>)> &action, int times = 0, const std::function<void()> &after = []() {}, const std::string &tag = "", const std::string& group=default_group_tag);
        extern void timer_every(std::variant<float, std::pair<float, float>> delay, const std::function<void(std::optional<float>)> &action, int times = 0, bool immediate = false, const std::function<void()> &after = []() {}, const std::string &tag = "", const std::string& group=default_group_tag);
        extern void timer_every_step(float start_delay, float end_delay, int times, const std::function<void(std::optional<float>)> &action, bool immediate = false, const std::function<float(float)> &step_method = nullptr, const std::function<void()> &after = []() {}, const std::string &tag = "", const std::string& group=default_group_tag);
        extern void timer_for(std::variant<float, std::pair<float, float>> duration, const std::function<void(std::optional<float>)> &action, const std::function<void()> &after = []() {}, const std::string &tag = "", const std::string& group=default_group_tag);
        extern void timer_tween(std::variant<float, std::pair<float, float>> duration, const std::function<float()> &getter, const std::function<void(float)> &setter, float target_value, const std::string &tag = "", const std::string& group=default_group_tag, const std::function<float(float)> &easing_method = [](float t)
                                                                                                                                                                                           { return t < 0.5 ? 2 * t * t : t * (4 - 2 * t) - 1; }, // Default easing method (ease-in-out quad)
                                const std::function<void()> &after = []() {});
                  
    }

    namespace EventQueueSystem
    {

        enum class EaseType
        {
            LERP,
            ELASTIC_IN,
            ELASTIC_OUT,
            QUAD_IN,
            QUAD_OUT
        };

        struct EaseData
        {
            EaseType type = EaseType::LERP;                // Type of easing
            float startValue = 0.0f;                       // Initial value
            float endValue = 0.0f;                         // Final value
            float startTime = 0.0f;                        // Easing start time
            float endTime = 0.0f;                          // Easing end time
            std::function<void(float)> set_value_callback; // Function to update the value to be eased. This callback should just be a simple setter function which takes the parameter and sets the variable to be eased to that value. This exists because entt components are not pointer stable.
            std::function<float(void)> get_value_callback; // Function to get the value to be eased. This callback should just be a simple getter function which returns the variable to be eased. This exists because entt components are not pointer stable.
        };

        struct ConditionData
        {
            std::function<bool()> checkConditionCallback; // Callback to confirm the condition
        };

        enum class TriggerType
        {
            IMMEDIATE,
            AFTER,
            BEFORE,
            EASE,
            CONDITION
        };

        enum class TimerType
        {
            REAL_TIME,
            TOTAL_TIME_EXCLUDING_PAUSE
        };

        struct Event
        {
            TriggerType eventTrigger = TriggerType::IMMEDIATE; // Trigger type
            bool blocksQueue = true;                           // Blocks other events
            bool canBeBlocked = true;                          // Can be blocked
            bool complete = false;                             // Completion status
            bool timerStarted = false;                         // Timer started
            float delaySeconds = 0.0f;                         // Delay in seconds
            bool retainInQueueAfterCompletion = false;         // Persist after completion //TODO: don't really know what this does
            bool createdWhileGamePaused = false;               // Created during pause
            std::function<bool(float)> func;                   // Function to execute (float is 0.0 to 1.0, indicating progress)
            TimerType timerTypeToUse = TimerType::REAL_TIME;   // Timer type
            float time = 0.0f;                                 // Event start time

            EaseData ease;           // Easing data
            ConditionData condition; // Condition data

            std::string tag = "";          // Optional tag for the event (default is empty)
            std::string debug_string_id{}; // Debug string ID

            bool deleteNextCycleImmediately = false; // If true, the event will be deleted immediately next update loop, no matter what. Use sparingly, only intended for internal use
        };

        namespace EventManager
        {
            extern std::map<std::string, std::vector<Event>> queues;
            extern float queue_timer;
            extern float queue_dt;
            extern float queue_last_processed;

            extern void add_event(const Event &event, const std::string &queue = "base", bool front = false);
            extern void init_event(Event &event);
            extern std::optional<Event> get_event_by_tag(const std::string &tag, const std::string &queue = "");
            extern void clear_queue(const std::string &queue = "", const std::string &exception = "");
            extern void handle_event(Event &event, bool &blocked, bool &completed, bool &time_done, bool &pause_skip);
            extern void update(bool forced = false);
        }

        /*
        #############################################################################################################
        ############################## Builder class definitions ####################################################
        #############################################################################################################
        #############################################################################################################
        */

        class EaseDataBuilder
        {
        public:
            EaseDataBuilder() = default;

            EaseDataBuilder &Type(EaseType type)
            {
                ease.type = type;
                return *this;
            }

            EaseDataBuilder &StartValue(float val)
            {
                ease.startValue = val;
                return *this;
            }

            EaseDataBuilder &EndValue(float val)
            {
                ease.endValue = val;
                return *this;
            }

            EaseDataBuilder &StartTime(float time)
            {
                ease.startTime = time;
                return *this;
            }

            EaseDataBuilder &EndTime(float time)
            {
                ease.endTime = time;
                return *this;
            }

            EaseDataBuilder &SetCallback(std::function<void(float)> setter)
            {
                ease.set_value_callback = std::move(setter);
                return *this;
            }

            EaseDataBuilder &GetCallback(std::function<float(void)> getter)
            {
                ease.get_value_callback = std::move(getter);
                return *this;
            }

            EaseData Build()
            {
                return ease;
            }

        private:
            EaseData ease{};
        };

        class EventBuilder
        {
        public:
            EventBuilder() = default;

            EventBuilder &Trigger(TriggerType triggerType)
            {
                event.eventTrigger = triggerType;
                return *this;
            }

            EventBuilder &BlocksQueue(bool blocks)
            {
                event.blocksQueue = blocks;
                return *this;
            }

            EventBuilder &CanBeBlocked(bool canBeBlocked)
            {
                event.canBeBlocked = canBeBlocked;
                return *this;
            }

            EventBuilder &Delay(float seconds)
            {
                event.delaySeconds = seconds;
                return *this;
            }

            EventBuilder &Func(std::function<bool(float)> f)
            {
                event.func = std::move(f);
                return *this;
            }

            EventBuilder &Ease(const EaseData &easeData)
            {
                event.ease = easeData;
                return *this;
            }

            EventBuilder &Condition(const ConditionData &condition)
            {
                event.condition = condition;
                return *this;
            }

            EventBuilder &Tag(const std::string &tagName)
            {
                event.tag = tagName;
                return *this;
            }

            EventBuilder &DebugID(const std::string &id)
            {
                event.debug_string_id = id;
                return *this;
            }

            EventBuilder &RetainAfterCompletion(bool retain = true)
            {
                event.retainInQueueAfterCompletion = retain;
                return *this;
            }

            EventBuilder &CreatedWhilePaused(bool paused = true)
            {
                event.createdWhileGamePaused = paused;
                return *this;
            }

            EventBuilder &TimerType(TimerType timerType)
            {
                event.timerTypeToUse = timerType;
                return *this;
            }

            EventBuilder &StartTimer(bool start = true)
            {
                event.timerStarted = start;
                return *this;
            }

            EventBuilder &DeleteNextCycleImmediately(bool del = true)
            {
                event.deleteNextCycleImmediately = del;
                return *this;
            }

            Event Build() const
            {
                return event;
            }

            void AddToQueue(const std::string &queue = "base", bool front = false)
            {
                EventManager::add_event(event, queue, front);
            }

        private:
            Event event{};
        };

    } // namespace EventQueueSystem


    extern void exposeToLua(sol::state &lua); // Function to expose the timer system to Lua
}
