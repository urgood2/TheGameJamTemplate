/**
 * Deprecated event queue system, use timer.hpp instead
 */

#pragma once

#include <entt/entt.hpp>
#include <functional>
#include <vector>
#include <string>
#include <map>
#include <cmath>
#include <optional>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// TODO: rename variables, move things around to obfuscate, rename methods

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

}
