#pragma once

#include <string>
#include <vector>
#include <array>
#include <unordered_map>
#include <chrono>
#include <cstdint>
#include <type_traits>

#include "goap.h"
#include "sol/sol.hpp"

namespace ai {

// Verify bfield_t is signed 64-bit as assumed by get_safe_atom_cap()
static_assert(sizeof(bfield_t) == 8 && std::is_signed_v<bfield_t>,
              "get_safe_atom_cap() assumes bfield_t is a signed 64-bit integer");

// =============================================================================
// AI Trace Buffer (Phase 1.1)
// Per-entity ring buffer for debugging AI decisions
// =============================================================================

/**
 * Event types for AI trace logging.
 */
enum class TraceEventType {
    GOAL_SELECTED,       // A new goal was chosen
    PLAN_BUILT,          // A plan was constructed
    ACTION_START,        // An action began execution
    ACTION_FINISH,       // An action completed successfully
    ACTION_ABORT,        // An action was aborted
    WORLDSTATE_CHANGED,  // World state atoms changed
    REPLAN_TRIGGERED     // A replan was triggered
};

/**
 * A single AI trace event with metadata.
 */
struct TraceEvent {
    TraceEventType type{TraceEventType::GOAL_SELECTED};
    std::string message;
    double timestamp{0.0};
    uint32_t entity_id{0};
    std::unordered_map<std::string, std::string> extra_data;
};

/**
 * Ring buffer for storing AI trace events.
 *
 * Fixed-size buffer that overwrites oldest events when full.
 * Default capacity is 100 events per entity, balancing memory
 * usage with debugging usefulness.
 *
 * NOTE: This class is NOT thread-safe. Each entity's trace buffer
 * should only be accessed from the main game thread.
 */
class AITraceBuffer {
public:
    static constexpr size_t DEFAULT_CAPACITY = 100;

    explicit AITraceBuffer(size_t capacity = DEFAULT_CAPACITY)
        : capacity_(capacity)
        , events_(capacity)
        , head_(0)
        , count_(0)
    {}

    /**
     * Push a new event into the buffer.
     * Sets timestamp automatically if not provided.
     */
    void push(TraceEvent event) {
        if (event.timestamp == 0.0) {
            event.timestamp = get_current_time();
        }
        events_[head_] = std::move(event);
        head_ = (head_ + 1) % capacity_;
        if (count_ < capacity_) {
            ++count_;
        }
    }

    /**
     * Get all events in chronological order (oldest first).
     */
    std::vector<TraceEvent> get_all() const {
        std::vector<TraceEvent> result;
        result.reserve(count_);

        if (count_ == 0) return result;

        // Start from oldest event
        size_t start = (count_ < capacity_) ? 0 : head_;
        for (size_t i = 0; i < count_; ++i) {
            size_t idx = (start + i) % capacity_;
            result.push_back(events_[idx]);
        }
        return result;
    }

    /**
     * Get the most recent N events in chronological order.
     */
    std::vector<TraceEvent> get_recent(size_t n) const {
        auto all = get_all();
        if (n >= all.size()) return all;
        return std::vector<TraceEvent>(all.end() - n, all.end());
    }

    /**
     * Get events filtered by type.
     */
    std::vector<TraceEvent> get_by_type(TraceEventType type) const {
        std::vector<TraceEvent> result;
        auto all = get_all();
        for (const auto& e : all) {
            if (e.type == type) {
                result.push_back(e);
            }
        }
        return result;
    }

    void clear() {
        head_ = 0;
        count_ = 0;
    }

    size_t size() const { return count_; }
    bool empty() const { return count_ == 0; }
    size_t capacity() const { return capacity_; }

private:
    static double get_current_time() {
        using namespace std::chrono;
        auto now = steady_clock::now();
        auto duration = now.time_since_epoch();
        return duration_cast<microseconds>(duration).count() / 1000000.0;
    }

    size_t capacity_;
    std::vector<TraceEvent> events_;
    size_t head_;  // Next write position
    size_t count_; // Current number of events
};

// =============================================================================
// Trace Event Helper Functions
// Convenience functions for recording common trace events
// =============================================================================

/**
 * Get event type name as string for debugging.
 */
inline const char* trace_event_type_name(TraceEventType type) {
    switch (type) {
        case TraceEventType::GOAL_SELECTED:      return "GOAL_SELECTED";
        case TraceEventType::PLAN_BUILT:         return "PLAN_BUILT";
        case TraceEventType::ACTION_START:       return "ACTION_START";
        case TraceEventType::ACTION_FINISH:      return "ACTION_FINISH";
        case TraceEventType::ACTION_ABORT:       return "ACTION_ABORT";
        case TraceEventType::WORLDSTATE_CHANGED: return "WORLDSTATE_CHANGED";
        case TraceEventType::REPLAN_TRIGGERED:   return "REPLAN_TRIGGERED";
        default: return "UNKNOWN";
    }
}

/**
 * Record a goal selection event.
 */
inline void trace_goal_selected(AITraceBuffer& buffer, uint32_t entity_id,
                                 const std::string& goal_name,
                                 const std::string& band = "",
                                 int score = 0) {
    TraceEvent event{
        .type = TraceEventType::GOAL_SELECTED,
        .message = "Selected goal: " + goal_name,
        .entity_id = entity_id,
        .extra_data = {{"goal", goal_name}}
    };
    if (!band.empty()) event.extra_data["band"] = band;
    if (score != 0) event.extra_data["score"] = std::to_string(score);
    buffer.push(std::move(event));
}

/**
 * Record a plan built event.
 */
inline void trace_plan_built(AITraceBuffer& buffer, uint32_t entity_id,
                              int num_steps, int cost,
                              const std::string& first_action = "") {
    std::string msg = "Plan built: " + std::to_string(num_steps) + " steps, cost " + std::to_string(cost);
    TraceEvent event{
        .type = TraceEventType::PLAN_BUILT,
        .message = msg,
        .entity_id = entity_id,
        .extra_data = {
            {"steps", std::to_string(num_steps)},
            {"cost", std::to_string(cost)}
        }
    };
    if (!first_action.empty()) event.extra_data["first_action"] = first_action;
    buffer.push(std::move(event));
}

/**
 * Record an action start event.
 */
inline void trace_action_start(AITraceBuffer& buffer, uint32_t entity_id,
                                const std::string& action_name) {
    buffer.push(TraceEvent{
        .type = TraceEventType::ACTION_START,
        .message = "Started action: " + action_name,
        .entity_id = entity_id,
        .extra_data = {{"action", action_name}}
    });
}

/**
 * Record an action finish event.
 */
inline void trace_action_finish(AITraceBuffer& buffer, uint32_t entity_id,
                                 const std::string& action_name,
                                 const std::string& result = "success") {
    buffer.push(TraceEvent{
        .type = TraceEventType::ACTION_FINISH,
        .message = "Finished action: " + action_name + " (" + result + ")",
        .entity_id = entity_id,
        .extra_data = {{"action", action_name}, {"result", result}}
    });
}

/**
 * Record an action abort event.
 */
inline void trace_action_abort(AITraceBuffer& buffer, uint32_t entity_id,
                                const std::string& action_name,
                                const std::string& reason = "") {
    std::string msg = "Aborted action: " + action_name;
    if (!reason.empty()) msg += " (" + reason + ")";
    TraceEvent event{
        .type = TraceEventType::ACTION_ABORT,
        .message = msg,
        .entity_id = entity_id,
        .extra_data = {{"action", action_name}}
    };
    if (!reason.empty()) event.extra_data["reason"] = reason;
    buffer.push(std::move(event));
}

/**
 * Record a worldstate changed event.
 */
inline void trace_worldstate_changed(AITraceBuffer& buffer, uint32_t entity_id,
                                      bfield_t changed_bits,
                                      const std::string& description = "") {
    std::string msg = "Worldstate changed";
    if (!description.empty()) msg += ": " + description;
    buffer.push(TraceEvent{
        .type = TraceEventType::WORLDSTATE_CHANGED,
        .message = msg,
        .entity_id = entity_id,
        .extra_data = {{"changed_bits", std::to_string(changed_bits)}}
    });
}

/**
 * Record a replan triggered event.
 */
inline void trace_replan_triggered(AITraceBuffer& buffer, uint32_t entity_id,
                                    const std::string& reason) {
    buffer.push(TraceEvent{
        .type = TraceEventType::REPLAN_TRIGGERED,
        .message = "Replan triggered: " + reason,
        .entity_id = entity_id,
        .extra_data = {{"reason", reason}}
    });
}

// =============================================================================
// Existing GOAP Utility Functions
// =============================================================================

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

/**
 * Compute changed bits for reactive replanning.
 *
 * This function computes which world state atoms changed due to world state
 * updaters (sensors), excluding changes that came from action postconditions.
 *
 * The key insight is that we need THREE states:
 * - state_after_action: World state immediately after action execution
 *   (includes postcondition changes)
 * - current_state: World state after updaters ran (the final state)
 * - cached_state: World state from the previous tick (for dontcare mask)
 *
 * We compare current_state vs state_after_action to find updater-only changes.
 *
 * @param state_after_action World state after action postconditions applied
 * @param current_state World state after world state updaters ran
 * @param cached_state Previous tick's state (used for dontcare bits)
 * @return Bitmask of atoms changed by updaters (not by action postconditions)
 */
inline bfield_t compute_replan_changed_bits(
    const worldstate_t& state_after_action,
    const worldstate_t& current_state,
    const worldstate_t& cached_state)
{
    // Compute relevant bits: ignore dontcare on all three states
    bfield_t dontcare_mask = state_after_action.dontcare |
                             current_state.dontcare |
                             cached_state.dontcare;
    bfield_t relevant = ~dontcare_mask;

    // Compare current state vs state_after_action to find ONLY updater changes
    // This excludes changes from action postconditions
    bfield_t changed = (current_state.values ^ state_after_action.values) & relevant;

    return changed;
}

/**
 * Compute drift from plan creation state.
 *
 * This function computes which world state atoms have changed since the plan
 * was created. This is useful for detecting significant environmental drift
 * that might invalidate the plan even if it's still technically executable.
 *
 * @param plan_start_state World state when the plan was created
 * @param current_state Current world state
 * @return Bitmask of atoms that have changed since plan creation
 */
inline bfield_t compute_plan_drift(
    const worldstate_t& plan_start_state,
    const worldstate_t& current_state)
{
    // Ignore dontcare bits from both states
    bfield_t dontcare_mask = plan_start_state.dontcare | current_state.dontcare;
    bfield_t relevant = ~dontcare_mask;

    // XOR to find differences, masked by relevant bits
    bfield_t drift = (plan_start_state.values ^ current_state.values) & relevant;

    return drift;
}

/**
 * Get the maximum safe atom count for the bitfield type.
 *
 * Since bfield_t is int64_t (signed), shifting 1LL << 63 is undefined behavior.
 * We cap at 62 atoms to ensure all bit operations are safe.
 *
 * @return Maximum safe atom count (62 for int64_t)
 */
constexpr int get_safe_atom_cap() {
    // For int64_t, we can safely use bits 0-61
    // Bit 62 is safe in practice but bit 63 (sign bit) is problematic
    // We use 62 to be conservative and avoid any sign-related issues
    return 62;
}

/**
 * Validate that the atom count is within safe limits.
 *
 * This should be called when loading actions from Lua or modifying the
 * action planner to ensure we don't exceed the bitfield capacity.
 *
 * @param ap The action planner to validate
 * @return true if atom count is safe, false if it exceeds the cap
 */
inline bool validate_atom_count(const actionplanner_t& ap) {
    return ap.numatoms <= get_safe_atom_cap();
}

/**
 * Merge an explicit goal state into a current goal state.
 *
 * This is used by replan_to_goal to allow explicit goals to override
 * specific atoms while preserving the rest of the current goal.
 *
 * The explicit goal takes precedence for any atoms it specifies
 * (i.e., atoms that are NOT dontcare in explicit_goal).
 *
 * @param current_goal The current goal state
 * @param explicit_goal The explicit goal to merge in (takes precedence)
 * @return Merged goal state
 */
inline worldstate_t merge_goal_state(
    const worldstate_t& current_goal,
    const worldstate_t& explicit_goal)
{
    worldstate_t merged;

    // Start with current goal
    merged.values = current_goal.values;
    merged.dontcare = current_goal.dontcare;

    // For atoms specified in explicit_goal (not dontcare), override current
    bfield_t explicit_specified = ~explicit_goal.dontcare;

    // Clear dontcare for atoms specified by explicit goal
    merged.dontcare &= ~explicit_specified;

    // Set values from explicit goal for specified atoms
    merged.values = (merged.values & ~explicit_specified) |
                    (explicit_goal.values & explicit_specified);

    return merged;
}

}  // namespace ai

// Backward compatibility
using ai::mask_from_names;
using ai::build_watch_mask;
using ai::compute_replan_changed_bits;
using ai::compute_plan_drift;
using ai::get_safe_atom_cap;
using ai::validate_atom_count;
using ai::merge_goal_state;
// Phase 1.1: AI trace buffer and helpers
using ai::TraceEventType;
using ai::TraceEvent;
using ai::AITraceBuffer;
using ai::trace_event_type_name;
using ai::trace_goal_selected;
using ai::trace_plan_built;
using ai::trace_action_start;
using ai::trace_action_finish;
using ai::trace_action_abort;
using ai::trace_worldstate_changed;
using ai::trace_replan_triggered;
