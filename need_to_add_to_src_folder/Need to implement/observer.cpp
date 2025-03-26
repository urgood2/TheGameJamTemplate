#include <unordered_map>
#include <string>
#include <functional>
#include <variant>
#include <any>
#include <vector>
#include <memory>
#include <random>
#include <sstream>
#include <uuid.h>

namespace ObserverSystem
{

    // uuid generator
    extern std::shared_ptr<uuids::uuid_random_generator> uuidGenerator;

    // ------------------------------------------------
    // Base timer management functions
    // ------------------------------------------------

    inline void init()
    {
        std::random_device rd;
        auto seed_data = std::array<int, std::mt19937::state_size>{};
        std::generate(std::begin(seed_data), std::end(seed_data), std::ref(rd));
        std::seed_seq seq(std::begin(seed_data), std::end(seed_data));
        std::mt19937 generator(seq);
        uuidGenerator = std::make_shared<uuids::uuid_random_generator>(generator);
    }

    // Utility functions for randomization
    inline std::string random_uid()
    {
        // returns the byte representation of a UUID, as a string
        return uuids::to_string((*uuidGenerator)());
    }

    // Placeholder for an empty function
    inline void emptyFunction() {}

    // Define an Observer struct to represent each observer
    struct Observer
    {
        std::string type;                               // Type of observer: "change", "value", or "condition"
        std::string field;                              // The field to observe (used for "change" and "value")
        std::any current;                               // Current value of the field
        std::any previous;                              // Previous value of the field
        std::function<void(std::any, std::any)> action; // Action to perform
        int times;                                      // Remaining times to trigger
        int maxTimes;                                   // Maximum number of times to trigger
        std::function<void()> after;                    // Function to call after maxTimes is reached
        std::function<std::any()> fetchCurrentValue;    // Lambda to fetch the current value dynamically
        std::function<bool(const std::any&, const std::any&)> compare; // Lambda to compare two values


        // Specific to "value" observers
        std::any targetValue; // Target value for the observer

        // Specific to "condition" observers
        std::function<bool()> condition; // Condition to evaluate
        bool lastCondition = false;      // Last evaluated condition state
    };

    // Observer container to manage all active observers
    class ObserverContainer
    {
    public:
        void addObserver(const std::string &tag, const Observer &observer)
        {
            // Ensure no duplicate observers with the same tag
            observerCancel(tag);
            observers[tag] = observer;
        }

        void removeObserver(const std::string &tag)
        {
            observers.erase(tag);
        }

        Observer *getObserver(const std::string &tag)
        {
            auto it = observers.find(tag);
            return it != observers.end() ? &it->second : nullptr;
        }

        const std::unordered_map<std::string, Observer> &getAllObservers() const
        {
            return observers;
        }

        // ------------------------------------------------
        // Cancels an observer based on its tag.
        // This is automatically called if repeated tags are given to timer actions. 
        void observerCancel(const std::string& tag) {
            removeObserver(tag);
        }

        // ------------------------------------------------
        // Updates all observers and checks their conditions or changes.
        // This function should be called periodically (e.g., every frame).
        void observerUpdate() {
            for (auto it = observers.begin(); it != observers.end();) {
                Observer& o = it->second;
                bool remove = false;

                if (o.type == "change" || o.type == "value") {
                    o.previous = o.current;
                    o.current = o.fetchCurrentValue(); // Dynamically fetch the current value
                }

                if (o.type == "change" && !o.compare(o.previous, o.current)) { // Use compare lambda
                    o.action(o.current, o.previous);
                    if (o.times > 0) {
                        o.times--;
                        if (o.times <= 0) {
                            o.after();
                            remove = true;
                        }
                    }
                } else if (o.type == "value" && o.compare(o.current, o.targetValue) && !o.compare(o.previous, o.current)) { // Use compare lambda
                    o.action(o.current, o.previous);
                    if (o.times > 0) {
                        o.times--;
                        if (o.times <= 0) {
                            o.after();
                            remove = true;
                        }
                    }
                } else if (o.type == "condition") {
                    bool condition = o.condition();
                    if (condition && !o.lastCondition) {
                        o.action(std::any(), std::any());
                        if (o.times > 0) {
                            o.times--;
                            if (o.times <= 0) {
                                o.after();
                                remove = true;
                            }
                        }
                    }
                    o.lastCondition = condition;
                }

                if (remove) {
                    it = observers.erase(it);
                } else {
                    ++it;
                }
            }
        }


        // ------------------------------------------------
        // Returns the current iteration of an observer with the given tag.
        // Useful if you need to know that it's the nth time an observer action has been called.
        // Example usage:
        // int iteration = observerGetIteration("some_tag");
        // std::cout << "Iteration: " << iteration << std::endl;
        int observerGetIteration(const std::string& tag) {
            Observer* observer = getObserver(tag);
            if (observer) {
                return observer->maxTimes - observer->times;
            }
            return -1; // Return -1 if the observer does not exist
        }

        // ------------------------------------------------
        // Calls the action when the specified field changes.
        // If times is provided, it only calls action that many times.
        // If after is provided, it is called after the last time action is called.
        // If tag is provided, any other observer actions with the same tag are automatically canceled.
        // Example usage:
        // observer_change("hp", [](auto current, auto previous) { std::cout << current << ", " << previous << "\n"; });
        // Calls the action whenever the "hp" field changes.
        // observer_change("can_attack", [](auto current, auto previous) { if (std::any_cast<bool>(current)) attack(); }, 5);
        // Calls "attack" function when "can_attack" becomes true, up to 5 times.
        void observerChange(const std::string& field,
                    const std::function<void(std::any, std::any)>& action,
                    const std::function<std::any()>& fetchCurrentValue,
                    const std::function<bool(const std::any&, const std::any&)>& compare = [](const std::any& a, const std::any& b) { return  true; },
                    int times = 0,
                    const std::function<void()>& after = emptyFunction,
                    const std::string& tag = random_uid()) {
            Observer observer;
            observer.type = "change";
            observer.field = field;
            observer.fetchCurrentValue = fetchCurrentValue;
            observer.compare = compare; // Save the comparison lambda
            observer.current = fetchCurrentValue();
            observer.previous = observer.current;
            observer.action = action;
            observer.times = times;
            observer.maxTimes = times;
            observer.after = after;
            addObserver(tag, observer);
        }

        // ------------------------------------------------
        // Calls the action when the specified field changes to a specific value.
        // If times is provided, it only calls action that many times.
        // If after is provided, it is called after the last time action is called.
        // If tag is provided, any other observer actions with the same tag are automatically canceled.
        // Example usage:
        // observerValue("hp", 0, []() { dead = true; });
        // Sets "dead" to true when "hp" becomes 0.
        void observerValue(const std::string& field,
                   const std::any& targetValue,
                   const std::function<void(std::any, std::any)>& action,
                   const std::function<std::any()>& fetchCurrentValue,
                   const std::function<bool(const std::any&, const std::any&)>& compare = [](const std::any& a, const std::any& b) { return true; },
                   int times = 0,
                   const std::function<void()>& after = emptyFunction,
                   const std::string& tag = random_uid()) {
            Observer observer;
            observer.type = "value";
            observer.field = field;
            observer.targetValue = targetValue;
            observer.fetchCurrentValue = fetchCurrentValue;
            observer.compare = compare; // Save the comparison lambda
            observer.current = fetchCurrentValue();
            observer.previous = observer.current;
            observer.action = action;
            observer.times = times;
            observer.maxTimes = times;
            observer.after = after;
            addObserver(tag, observer);
        }

        // ------------------------------------------------
        // Calls the action once when the condition becomes true.
        // This allows for logic to be locally contained instead of spread across the codebase.
        // If times is provided, it only calls action that many times.
        // If after is provided, it is called after the last time action is called.
        // If tag is provided, any other observer actions with the same tag are automatically canceled.
        // Example usage:
        // observerCondition([]() { return hp == 0; }, []() { dead = true; });
        // Sets "dead" to true when "hp" becomes 0.
        void observerCondition(const std::function<bool()>& condition,
                       const std::function<void()>& action,
                       const std::function<bool(const std::any&, const std::any&)>& compare = [](const std::any&, const std::any&) { return false; }, // Default comparison
                       int times = 0,
                       const std::function<void()>& after = emptyFunction,
                       const std::string& tag = random_uid()) {
            Observer observer;
            observer.type = "condition";
            observer.condition = condition;
            observer.lastCondition = condition(); // Initialize with the current condition state
            observer.compare = compare; // Save the comparison lambda, though not used directly here
            observer.action = [action](std::any, std::any) { action(); };
            observer.times = times;
            observer.maxTimes = times;
            observer.after = after;
            addObserver(tag, observer);
        }


    private:
        std::unordered_map<std::string, Observer> observers;
    };

} // namespace ObserverSystem
