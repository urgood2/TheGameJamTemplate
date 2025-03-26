#include "timer.hpp"

#include "util/common_headers.hpp"
#include "../../core/globals.hpp"
#include "../../core/game.hpp"

namespace timer
{

    namespace TimerSystem
    {
        std::unordered_map<std::string, Timer> timers{}; // Timer Storage
        int uuid_counter = base_uid;                     // Counter for generating unique IDs

        // ------------------------------------------------
        // Base timer management functions
        // ------------------------------------------------

        // Timer Run: Calls an action every frame until canceled, then potentially calls an after action
        void timer_run(const std::function<void(std::optional<float>)> &action, const std::function<void()> &after, const std::string &tag)
        {
            // Generate a random tag if none is provided
            std::string final_tag = tag.empty() ? random_uid() : tag;

            // Create and add the timer
            Timer timer;
            timer.type = TimerType::RUN;
            timer.action = action;
            timer.after = after;

            add_timer(final_tag, std::move(timer));

            // Debug: Notify the timer was added
            SPDLOG_DEBUG("Added 'run' timer with tag: {}", final_tag);
        }

        // Timer After: Calls an action after a delay
        void timer_after(std::variant<float, std::pair<float, float>> delay, const std::function<void(std::optional<float>)> &action, const std::string &tag)
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
            add_timer(final_tag, std::move(timer));

            // Debug: Notify the timer was added
            SPDLOG_DEBUG("Added 'after' timer with tag: {} and delay: {}", final_tag, std::visit([](auto &&arg) -> std::string
                                                                                                 {
                    using T = std::decay_t<decltype(arg)>;
                    if constexpr (std::is_same_v<T, float>) {
                        return fmt::format("{}", arg); // Single float
                    } else if constexpr (std::is_same_v<T, std::pair<float, float>>) {
                        return fmt::format("[{}, {}]", arg.first, arg.second); // Pair of floats
                    } }, delay));
        }

        // Timer Cooldown: Calls an action every delay seconds until a condition is met
        void timer_cooldown(std::variant<float, std::pair<float, float>> delay, const std::function<bool()> &condition, const std::function<void(std::optional<float>)> &action, int times, const std::function<void()> &after, const std::string &tag)
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
            add_timer(final_tag, std::move(timer));

            // Debug: Notify the timer was added
            SPDLOG_DEBUG("Added 'cooldown' timer with tag: {} and delay: {}", final_tag, std::visit([](auto &&arg) -> std::string
                                                                                                    {
                    using T = std::decay_t<decltype(arg)>;
                    if constexpr (std::is_same_v<T, float>) {
                        return fmt::format("{}", arg); // Single float
                    } else if constexpr (std::is_same_v<T, std::pair<float, float>>) {
                        return fmt::format("[{}, {}]", arg.first, arg.second); // Pair of floats
                    } }, delay));
        }

        // Timer Every: Calls an action every delay seconds, potentially a limited number of times
        void timer_every(std::variant<float, std::pair<float, float>> delay, const std::function<void(std::optional<float>)> &action, int times, bool immediate, const std::function<void()> &after, const std::string &tag)
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
            add_timer(final_tag, std::move(timer));

            // Execute the action immediately if required
            if (immediate)
            {
                action(std::nullopt);
            }

            // Debug: Notify the timer was added
            SPDLOG_DEBUG("Added 'every' timer with tag: {} and delay: {}", final_tag, std::visit([](auto &&arg) -> std::string
                                                                                                 {
                    using T = std::decay_t<decltype(arg)>;
                    if constexpr (std::is_same_v<T, float>) {
                        return fmt::format("{}", arg); // Single float
                    } else if constexpr (std::is_same_v<T, std::pair<float, float>>) {
                        return fmt::format("[{}, {}]", arg.first, arg.second); // Pair of floats
                    } }, delay));
        }

        // Timer Every Step: Calls an action at regular intervals, potentially a limited number of times
        void timer_every_step(float start_delay, float end_delay, int times, const std::function<void(std::optional<float>)> &action, bool immediate, const std::function<float(float)> &step_method, const std::function<void()> &after, const std::string &tag)
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
            add_timer(final_tag, std::move(timer));

            // Execute the action immediately if required
            if (immediate)
            {
                action(std::nullopt);
            }

            // Debug: Notify the timer was added
            SPDLOG_DEBUG("Added 'every_step' timer with tag: {} from {} to {} with {} steps", final_tag, start_delay, end_delay, times);
        }

        // Timer For: Calls an action every frame for a duration
        void timer_for(std::variant<float, std::pair<float, float>> duration, const std::function<void(std::optional<float>)> &action, const std::function<void()> &after, const std::string &tag)
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
            add_timer(final_tag, std::move(timer));

            // Debug: Notify the timer was added
            SPDLOG_DEBUG("Added 'for' timer with tag: {} and duration: {}", final_tag, std::visit([](auto &&arg) -> std::string
                                                                                                  {
                    using T = std::decay_t<decltype(arg)>;
                    if constexpr (std::is_same_v<T, float>) {
                        return fmt::format("{}", arg); // Single float
                    } else if constexpr (std::is_same_v<T, std::pair<float, float>>) {
                        return fmt::format("[{}, {}]", arg.first, arg.second); // Pair of floats
                    } }, duration));
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
                         const std::function<float(float)> &easing_method,
                         const std::function<void()> &after,
                         const std::string &tag)
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
                float t = std::clamp(elapsed_time.value_or(0.0f) / resolved_delay, 0.0f, 1.0f); // Normalized time
                float eased_t = easing_method(t);                                               // Apply easing
                float interpolated_value = math::lerp(start_value, target_value, eased_t);
                setter(interpolated_value); // Update the value
            };

            // Add the timer to the system
            add_timer(final_tag, std::move(timer));

            // Debug: Notify the timer was added
            SPDLOG_DEBUG("Added 'tween' timer with tag: {} to tween from {} to {} over {} seconds", final_tag, start_value, target_value,
                         std::visit([](auto &&arg) -> std::string
                                    {
            using T = std::decay_t<decltype(arg)>;
            if constexpr (std::is_same_v<T, float>) {
                return fmt::format("{}", arg);
            } else if constexpr (std::is_same_v<T, std::pair<float, float>>) {
                return fmt::format("[{}, {}]", arg.first, arg.second);
            } }, duration));
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

            float queue_timer = globals::G_TIMER_REAL;
            float queue_dt = 1.0f / 60.0f; // 60 FPS
            float queue_last_processed = globals::G_TIMER_REAL;

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
                event.time = (event.timerTypeToUse == TimerType::REAL_TIME) ? globals::G_TIMER_REAL : globals::G_TIMER_TOTAL;

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
                return (event.timerTypeToUse == TimerType::REAL_TIME) ? globals::G_TIMER_REAL : globals::G_TIMER_TOTAL;
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
                    event.time = (event.timerTypeToUse == TimerType::REAL_TIME) ? globals::G_TIMER_REAL : globals::G_TIMER_TOTAL;
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
                            float elastic_progress = -std::pow(2, 10 * (percent_done - 1)) * std::sin((percent_done * 10 - 10.75) * 2 * M_PI / 3);
                            valueToPassToEaseCallback = (1.0f - elastic_progress) * event.ease.startValue + elastic_progress * event.ease.endValue;
                            // SPDLOG_DEBUG("ELASTIC_IN value: {}", valueToPassToEaseCallback);
                        }
                        else if (event.ease.type == EaseType::ELASTIC_OUT)
                        {
                            // Elastic ease-out
                            float elastic_progress = std::pow(2, -10 * percent_done) * std::sin((percent_done * 10 - 0.75) * 2 * M_PI / 3);
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
                queue_timer = globals::G_TIMER_REAL;

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