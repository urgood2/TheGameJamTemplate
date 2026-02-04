#pragma once

#include <cstdint>
#include <filesystem>
#include <map>
#include <optional>
#include <string>
#include <vector>

#include "testing/test_mode_config.hpp"

namespace testing {

struct PerfToken {
    int id = 0;
    int frame_number = 0;
};

struct PerfMetrics {
    int frame_count = 0;
    float total_sim_ms = 0.0f;
    float total_render_ms = 0.0f;
    float max_frame_ms = 0.0f;
    float avg_frame_ms = 0.0f;
    float p95_frame_ms = 0.0f;
    float p99_frame_ms = 0.0f;
    float asset_load_ms = 0.0f;
    size_t peak_rss_bytes = 0;
    size_t alloc_count = 0;
};

struct BudgetDef {
    std::string metric;
    std::string op;
    float value = 0.0f;
    std::string context;
};

struct BudgetViolation {
    std::string metric;
    std::string op;
    float budget_value = 0.0f;
    float actual_value = 0.0f;
    std::string context;
    int frame_number = 0;
};

struct TraceEvent {
    std::string name;
    std::string category;
    std::string phase = "X";
    int64_t timestamp_us = 0;
    int64_t duration_us = 0;
    int pid = 1;
    int tid = 1;
    std::map<std::string, std::string> args;
};

struct FrameTiming {
    int frame_number = 0;
    float sim_ms = 0.0f;
    float render_ms = 0.0f;
};

class PerfTracker {
public:
    void initialize(const TestModeConfig& config);

    PerfToken mark();
    PerfMetrics get_metrics_since(PerfToken token) const;
    void record_frame(int frame_number, float sim_ms, float render_ms);

    void load_budgets(const std::filesystem::path& budget_file);
    void set_budgets(const std::map<std::string, BudgetDef>& budgets);
    void check_budget(const std::string& metric, float value);
    bool has_budget_violations() const;
    std::vector<BudgetViolation> get_violations() const;
    void clear_violations();

    void enable_trace_export(const std::filesystem::path& output);
    void add_trace_event(const TraceEvent& event);
    void write_trace();

    PerfMetrics get_current_metrics() const;

    void begin_test(const std::string& test_id);
    void end_test();
    PerfMetrics get_test_metrics() const;

    void clear();

private:
    PerfMetrics compute_metrics(size_t start_index, size_t end_index) const;
    const BudgetDef* find_budget(const std::string& metric, const std::string& context) const;
    bool evaluate_budget(float actual, const BudgetDef& def) const;
    void record_violation(const BudgetDef& def, float actual);

    std::vector<FrameTiming> frames_;
    std::map<std::string, BudgetDef> budgets_;
    std::vector<BudgetViolation> violations_;
    std::optional<std::filesystem::path> trace_path_;
    std::vector<TraceEvent> trace_events_;
    std::map<int, size_t> marks_;
    int next_token_ = 1;
    int last_frame_number_ = 0;
    int64_t trace_time_us_ = 0;
    std::optional<size_t> test_start_index_;
    std::optional<size_t> test_end_index_;
    std::string current_test_id_;
    PerfMode perf_mode_ = PerfMode::Off;
};

} // namespace testing
