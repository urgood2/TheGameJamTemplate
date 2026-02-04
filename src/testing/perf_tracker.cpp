#include "testing/perf_tracker.hpp"

#include <algorithm>
#include <cmath>
#include <fstream>

#include "nlohmann/json.hpp"
#include "spdlog/spdlog.h"

namespace testing {

namespace {

const char* perf_mode_label(PerfMode mode) {
    switch (mode) {
        case PerfMode::Off:
            return "off";
        case PerfMode::Collect:
            return "collect";
        case PerfMode::Enforce:
            return "enforce";
        default:
            return "off";
    }
}

std::string budget_key(const std::string& metric, const std::string& context) {
    if (context.empty()) {
        return metric;
    }
    return context + ":" + metric;
}

float percentile(std::vector<float> values, double p) {
    if (values.empty()) {
        return 0.0f;
    }
    std::sort(values.begin(), values.end());
    const double clamped = std::max(0.0, std::min(1.0, p));
    const double raw_index = std::ceil(clamped * static_cast<double>(values.size()));
    size_t index = raw_index > 0 ? static_cast<size_t>(raw_index - 1.0) : 0u;
    if (index >= values.size()) {
        index = values.size() - 1;
    }
    return values[index];
}

} // namespace

void PerfTracker::initialize(const TestModeConfig& config) {
    clear();
    perf_mode_ = config.perf_mode;
    SPDLOG_DEBUG("[perf] Initialized perf tracker (mode: {})", perf_mode_label(perf_mode_));

    if (config.perf_budget_path.has_value()) {
        load_budgets(*config.perf_budget_path);
    }
    if (config.perf_trace_path.has_value()) {
        enable_trace_export(*config.perf_trace_path);
    }
}

PerfToken PerfTracker::mark() {
    PerfToken token{};
    token.id = next_token_++;
    token.frame_number = last_frame_number_;
    marks_[token.id] = frames_.size();
    SPDLOG_DEBUG("[perf] Mark created: token={}, frame={}", token.id, token.frame_number);
    return token;
}

PerfMetrics PerfTracker::get_metrics_since(PerfToken token) const {
    auto it = marks_.find(token.id);
    if (it == marks_.end()) {
        return {};
    }
    return compute_metrics(it->second, frames_.size());
}

void PerfTracker::record_frame(int frame_number, float sim_ms, float render_ms) {
    if (perf_mode_ == PerfMode::Off) {
        return;
    }

    FrameTiming timing{};
    timing.frame_number = frame_number;
    timing.sim_ms = sim_ms;
    timing.render_ms = render_ms;
    frames_.push_back(timing);
    last_frame_number_ = frame_number;

    SPDLOG_DEBUG("[perf] Recording frame {}: sim={}ms, render={}ms", frame_number, sim_ms, render_ms);

    if (trace_path_.has_value()) {
        TraceEvent event{};
        event.name = "frame";
        event.category = "frame";
        event.phase = "X";
        event.timestamp_us = trace_time_us_;
        event.duration_us = static_cast<int64_t>((sim_ms + render_ms) * 1000.0f);
        trace_time_us_ += event.duration_us;
        trace_events_.push_back(event);
    }
}

void PerfTracker::load_budgets(const std::filesystem::path& budget_file) {
    budgets_.clear();

    std::ifstream input(budget_file);
    if (!input) {
        SPDLOG_WARN("[perf] Budget file missing: {}", budget_file.string());
        return;
    }

    nlohmann::json data;
    input >> data;
    if (!data.is_object()) {
        SPDLOG_WARN("[perf] Budget file invalid: {}", budget_file.string());
        return;
    }

    auto parse_block = [&](const nlohmann::json& block, const std::string& context) {
        if (!block.is_object()) {
            return;
        }
        for (auto it = block.begin(); it != block.end(); ++it) {
            BudgetDef def;
            def.metric = it.key();
            def.op = "lte";
            def.context = context;

            if (it.value().is_number()) {
                def.value = it.value().get<float>();
            } else if (it.value().is_object()) {
                def.op = it.value().value("op", "lte");
                def.value = it.value().value("value", 0.0f);
                def.context = it.value().value("context", context);
            } else {
                continue;
            }

            budgets_[budget_key(def.metric, def.context)] = def;
        }
    };

    if (data.contains("defaults")) {
        parse_block(data["defaults"], "");
    }
    if (data.contains("tests") && data["tests"].is_object()) {
        for (auto it = data["tests"].begin(); it != data["tests"].end(); ++it) {
            parse_block(it.value(), it.key());
        }
    }

    SPDLOG_INFO("[perf] Budget loaded: {} definitions", budgets_.size());
}

void PerfTracker::set_budgets(const std::map<std::string, BudgetDef>& budgets) {
    budgets_ = budgets;
}

void PerfTracker::check_budget(const std::string& metric, float value) {
    const BudgetDef* def = find_budget(metric, current_test_id_);
    if (!def) {
        def = find_budget(metric, "");
    }
    if (!def) {
        return;
    }

    SPDLOG_DEBUG("[perf] Checking budget: {} {} {}", def->metric, def->op, def->value);

    if (!evaluate_budget(value, *def)) {
        record_violation(*def, value);
    }
}

bool PerfTracker::has_budget_violations() const {
    return !violations_.empty();
}

std::vector<BudgetViolation> PerfTracker::get_violations() const {
    return violations_;
}

void PerfTracker::clear_violations() {
    violations_.clear();
}

void PerfTracker::enable_trace_export(const std::filesystem::path& output) {
    trace_path_ = output;
    trace_events_.clear();
    trace_time_us_ = 0;

    std::error_code ec;
    if (output.has_parent_path()) {
        std::filesystem::create_directories(output.parent_path(), ec);
    }
}

void PerfTracker::add_trace_event(const TraceEvent& event) {
    trace_events_.push_back(event);
}

void PerfTracker::write_trace() {
    if (!trace_path_.has_value()) {
        return;
    }

    nlohmann::json trace;
    trace["traceEvents"] = nlohmann::json::array();
    trace["displayTimeUnit"] = "ms";

    for (const auto& event : trace_events_) {
        nlohmann::json entry;
        entry["name"] = event.name;
        entry["cat"] = event.category;
        entry["ph"] = event.phase;
        entry["ts"] = event.timestamp_us;
        entry["dur"] = event.duration_us;
        entry["pid"] = event.pid;
        entry["tid"] = event.tid;
        if (!event.args.empty()) {
            nlohmann::json args = nlohmann::json::object();
            for (const auto& pair : event.args) {
                args[pair.first] = pair.second;
            }
            entry["args"] = std::move(args);
        }
        trace["traceEvents"].push_back(std::move(entry));
    }

    std::ofstream output(*trace_path_);
    if (!output) {
        SPDLOG_WARN("[perf] Unable to write trace: {}", trace_path_->string());
        return;
    }

    output << trace.dump(2);
    SPDLOG_DEBUG("[perf] Writing Chrome trace: {}", trace_path_->string());
}

PerfMetrics PerfTracker::get_current_metrics() const {
    return compute_metrics(0, frames_.size());
}

void PerfTracker::begin_test(const std::string& test_id) {
    current_test_id_ = test_id;
    test_start_index_ = frames_.size();
    test_end_index_.reset();

    if (trace_path_.has_value()) {
        TraceEvent event;
        event.name = "test:" + test_id;
        event.category = "test";
        event.phase = "B";
        event.timestamp_us = trace_time_us_;
        trace_events_.push_back(event);
    }
}

void PerfTracker::end_test() {
    test_end_index_ = frames_.size();

    if (trace_path_.has_value()) {
        TraceEvent event;
        event.name = "test:" + current_test_id_;
        event.category = "test";
        event.phase = "E";
        event.timestamp_us = trace_time_us_;
        trace_events_.push_back(event);
    }

    current_test_id_.clear();
}

PerfMetrics PerfTracker::get_test_metrics() const {
    if (!test_start_index_.has_value()) {
        return {};
    }
    const size_t start = *test_start_index_;
    const size_t end = test_end_index_.has_value() ? *test_end_index_ : frames_.size();
    return compute_metrics(start, end);
}

void PerfTracker::clear() {
    frames_.clear();
    budgets_.clear();
    violations_.clear();
    trace_events_.clear();
    marks_.clear();
    next_token_ = 1;
    last_frame_number_ = 0;
    trace_time_us_ = 0;
    test_start_index_.reset();
    test_end_index_.reset();
    current_test_id_.clear();
    perf_mode_ = PerfMode::Off;
    trace_path_.reset();
}

PerfMetrics PerfTracker::compute_metrics(size_t start_index, size_t end_index) const {
    PerfMetrics metrics{};
    if (end_index <= start_index || start_index >= frames_.size()) {
        return metrics;
    }

    end_index = std::min(end_index, frames_.size());

    const size_t count = end_index - start_index;
    metrics.frame_count = static_cast<int>(count);

    float total_sim = 0.0f;
    float total_render = 0.0f;
    float max_frame = 0.0f;
    std::vector<float> totals;
    totals.reserve(count);

    for (size_t i = start_index; i < end_index; ++i) {
        const auto& frame = frames_[i];
        total_sim += frame.sim_ms;
        total_render += frame.render_ms;
        const float total = frame.sim_ms + frame.render_ms;
        totals.push_back(total);
        if (total > max_frame) {
            max_frame = total;
        }
    }

    metrics.total_sim_ms = total_sim;
    metrics.total_render_ms = total_render;
    metrics.max_frame_ms = max_frame;
    const float total_ms = total_sim + total_render;
    metrics.avg_frame_ms = count > 0 ? total_ms / static_cast<float>(count) : 0.0f;
    metrics.p95_frame_ms = percentile(totals, 0.95);
    metrics.p99_frame_ms = percentile(totals, 0.99);
    return metrics;
}

const BudgetDef* PerfTracker::find_budget(const std::string& metric, const std::string& context) const {
    if (!context.empty()) {
        auto it = budgets_.find(budget_key(metric, context));
        if (it != budgets_.end()) {
            return &it->second;
        }
    }
    auto it = budgets_.find(metric);
    if (it != budgets_.end()) {
        return &it->second;
    }
    return nullptr;
}

bool PerfTracker::evaluate_budget(float actual, const BudgetDef& def) const {
    const std::string op = def.op.empty() ? "lte" : def.op;
    const float value = def.value;

    if (op == "lt") {
        return actual < value;
    }
    if (op == "lte") {
        return actual <= value;
    }
    if (op == "gt") {
        return actual > value;
    }
    if (op == "gte") {
        return actual >= value;
    }
    if (op == "eq") {
        return std::fabs(actual - value) <= 1e-3f;
    }
    return actual <= value;
}

void PerfTracker::record_violation(const BudgetDef& def, float actual) {
    BudgetViolation violation{};
    violation.metric = def.metric;
    violation.op = def.op;
    violation.budget_value = def.value;
    violation.actual_value = actual;
    violation.context = def.context.empty() ? current_test_id_ : def.context;
    violation.frame_number = last_frame_number_;
    violations_.push_back(violation);

    SPDLOG_WARN("[perf] Budget violation: {} = {} (budget: {} {})",
                def.metric,
                actual,
                def.op,
                def.value);
}

} // namespace testing
