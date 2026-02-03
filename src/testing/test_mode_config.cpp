#include "testing/test_mode_config.hpp"

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cctype>
#include <iomanip>
#include <limits>
#include <sstream>
#include <system_error>

namespace test_mode {

namespace {

std::string toLower(std::string value) {
    std::transform(value.begin(), value.end(), value.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });
    return value;
}

bool parseInt(const std::string& value, int& out, std::string& error) {
    try {
        size_t idx = 0;
        int parsed = std::stoi(value, &idx, 10);
        if (idx != value.size()) {
            error = "Invalid integer value: " + value;
            return false;
        }
        out = parsed;
        return true;
    } catch (const std::exception&) {
        error = "Invalid integer value: " + value;
        return false;
    }
}

bool parseU32(const std::string& value, uint32_t& out, std::string& error) {
    try {
        size_t idx = 0;
        unsigned long parsed = std::stoul(value, &idx, 10);
        if (idx != value.size() || parsed > std::numeric_limits<uint32_t>::max()) {
            error = "Invalid u32 value: " + value;
            return false;
        }
        out = static_cast<uint32_t>(parsed);
        return true;
    } catch (const std::exception&) {
        error = "Invalid u32 value: " + value;
        return false;
    }
}

bool parseBool(const std::optional<std::string>& value, bool& out, std::string& error) {
    if (!value.has_value()) {
        out = true;
        return true;
    }

    std::string normalized = toLower(value.value());
    if (normalized == "1" || normalized == "true" || normalized == "yes" || normalized == "on") {
        out = true;
        return true;
    }
    if (normalized == "0" || normalized == "false" || normalized == "no" || normalized == "off") {
        out = false;
        return true;
    }

    error = "Invalid boolean value: " + value.value();
    return false;
}

bool parseResolution(const std::string& value, int& width, int& height, std::string& error) {
    auto lower = toLower(value);
    auto sep = lower.find('x');
    if (sep == std::string::npos) {
        error = "Invalid resolution value: " + value;
        return false;
    }
    std::string w = lower.substr(0, sep);
    std::string h = lower.substr(sep + 1);
    if (w.empty() || h.empty()) {
        error = "Invalid resolution value: " + value;
        return false;
    }
    int parsedW = 0;
    int parsedH = 0;
    if (!parseInt(w, parsedW, error) || !parseInt(h, parsedH, error)) {
        return false;
    }
    width = parsedW;
    height = parsedH;
    return true;
}

bool parseNetworkMode(const std::string& value, NetworkMode& out, std::string& error) {
    std::string normalized = toLower(value);
    if (normalized == "deny") {
        out = NetworkMode::Deny;
        return true;
    }
    if (normalized == "localhost") {
        out = NetworkMode::Localhost;
        return true;
    }
    if (normalized == "any") {
        out = NetworkMode::Any;
        return true;
    }
    error = "Invalid allow-network value: " + value;
    return false;
}

bool parseBaselineWriteMode(const std::string& value, BaselineWriteMode& out, std::string& error) {
    std::string normalized = toLower(value);
    if (normalized == "deny") {
        out = BaselineWriteMode::Deny;
        return true;
    }
    if (normalized == "stage") {
        out = BaselineWriteMode::Stage;
        return true;
    }
    if (normalized == "apply") {
        out = BaselineWriteMode::Apply;
        return true;
    }
    error = "Invalid baseline-write-mode value: " + value;
    return false;
}

bool parseFailureVideoMode(const std::string& value, FailureVideoMode& out, std::string& error) {
    std::string normalized = toLower(value);
    if (normalized == "off") {
        out = FailureVideoMode::Off;
        return true;
    }
    if (normalized == "on") {
        out = FailureVideoMode::On;
        return true;
    }
    error = "Invalid failure-video value: " + value;
    return false;
}

bool parseRngScope(const std::string& value, RngScope& out, std::string& error) {
    std::string normalized = toLower(value);
    if (normalized == "test") {
        out = RngScope::Test;
        return true;
    }
    if (normalized == "run") {
        out = RngScope::Run;
        return true;
    }
    error = "Invalid rng-scope value: " + value;
    return false;
}

bool parseRendererMode(const std::string& value, RendererMode& out, std::string& error) {
    std::string normalized = toLower(value);
    if (normalized == "null") {
        out = RendererMode::Null;
        return true;
    }
    if (normalized == "offscreen") {
        out = RendererMode::Offscreen;
        return true;
    }
    if (normalized == "windowed") {
        out = RendererMode::Windowed;
        return true;
    }
    error = "Invalid renderer value: " + value;
    return false;
}

bool parseDeterminismAuditScope(const std::string& value, DeterminismAuditScope& out, std::string& error) {
    std::string normalized = toLower(value);
    if (normalized == "test_api") {
        out = DeterminismAuditScope::TestApi;
        return true;
    }
    if (normalized == "engine") {
        out = DeterminismAuditScope::Engine;
        return true;
    }
    if (normalized == "render_hash") {
        out = DeterminismAuditScope::RenderHash;
        return true;
    }
    error = "Invalid determinism-audit-scope value: " + value;
    return false;
}

bool parseDeterminismViolationMode(const std::string& value, DeterminismViolationMode& out, std::string& error) {
    std::string normalized = toLower(value);
    if (normalized == "fatal") {
        out = DeterminismViolationMode::Fatal;
        return true;
    }
    if (normalized == "warn") {
        out = DeterminismViolationMode::Warn;
        return true;
    }
    error = "Invalid determinism-violation value: " + value;
    return false;
}

bool parseIsolateTestsMode(const std::string& value, IsolateTestsMode& out, std::string& error) {
    std::string normalized = toLower(value);
    if (normalized == "none") {
        out = IsolateTestsMode::None;
        return true;
    }
    if (normalized == "process-per-file") {
        out = IsolateTestsMode::ProcessPerFile;
        return true;
    }
    if (normalized == "process-per-test") {
        out = IsolateTestsMode::ProcessPerTest;
        return true;
    }
    error = "Invalid isolate-tests value: " + value;
    return false;
}

bool parseLuaSandboxMode(const std::string& value, LuaSandboxMode& out, std::string& error) {
    std::string normalized = toLower(value);
    if (normalized == "on") {
        out = LuaSandboxMode::On;
        return true;
    }
    if (normalized == "off") {
        out = LuaSandboxMode::Off;
        return true;
    }
    error = "Invalid lua-sandbox value: " + value;
    return false;
}

bool parsePerfMode(const std::string& value, PerfMode& out, std::string& error) {
    std::string normalized = toLower(value);
    if (normalized == "off") {
        out = PerfMode::Off;
        return true;
    }
    if (normalized == "collect") {
        out = PerfMode::Collect;
        return true;
    }
    if (normalized == "enforce") {
        out = PerfMode::Enforce;
        return true;
    }
    error = "Invalid perf-mode value: " + value;
    return false;
}

std::optional<std::string> splitValue(const std::string& arg, std::string& flag) {
    auto pos = arg.find('=');
    if (pos == std::string::npos) {
        flag = arg;
        return std::nullopt;
    }
    flag = arg.substr(0, pos);
    return arg.substr(pos + 1);
}

bool readNextValue(const std::optional<std::string>& inlineValue,
                   int& index,
                   int argc,
                   char** argv,
                   std::string& out,
                   std::string& error) {
    if (inlineValue.has_value()) {
        out = inlineValue.value();
        return true;
    }
    if (index + 1 >= argc) {
        error = "Missing value for flag";
        return false;
    }
    out = argv[++index];
    return true;
}

void splitTags(const std::string& value, std::vector<std::string>& out) {
    size_t start = 0;
    while (start < value.size()) {
        size_t comma = value.find(',', start);
        if (comma == std::string::npos) {
            out.push_back(value.substr(start));
            return;
        }
        out.push_back(value.substr(start, comma - start));
        start = comma + 1;
    }
}

bool isUnderRoot(const std::filesystem::path& root, const std::filesystem::path& candidate, std::string& error) {
    std::error_code ec;
    auto rootAbs = std::filesystem::weakly_canonical(root, ec);
    if (ec) {
        rootAbs = std::filesystem::absolute(root);
    }

    std::filesystem::path candidateAbs = candidate.is_absolute() ? candidate : rootAbs / candidate;
    candidateAbs = candidateAbs.lexically_normal();

    auto rootIt = rootAbs.begin();
    auto candIt = candidateAbs.begin();
    for (; rootIt != rootAbs.end(); ++rootIt, ++candIt) {
        if (candIt == candidateAbs.end() || *candIt != *rootIt) {
            error = "Path escapes project root: " + candidate.string();
            return false;
        }
    }
    return true;
}

bool ensureDir(const std::filesystem::path& dir, std::string& error) {
    std::error_code ec;
    std::filesystem::create_directories(dir, ec);
    if (ec) {
        error = "Failed to create directory: " + dir.string();
        return false;
    }
    return true;
}

uint32_t deriveShuffleSeed(uint32_t seed) {
    uint64_t mixed = static_cast<uint64_t>(seed) * 2654435761u;
    mixed ^= (mixed >> 16);
    return static_cast<uint32_t>(mixed & 0xffffffffu);
}

} // namespace

std::string BuildTestModeUsage() {
    std::ostringstream out;
    out << "Test mode flags\n";
    out << "  --test-mode\n";
    out << "  --headless\n";
    out << "  --test-script <path>\n";
    out << "  --test-suite <dir>\n";
    out << "  --list-tests\n";
    out << "  --list-tests-json <path>\n";
    out << "  --test-filter <glob_or_regex>\n";
    out << "  --run-test-id <id>\n";
    out << "  --run-test-exact <full_name>\n";
    out << "  --exclude-tag <tag>\n";
    out << "  --include-tag <tag>\n";
    out << "  --seed <u32> or -s <u32>\n";
    out << "  --fixed-fps <int>\n";
    out << "  --resolution <WxH>\n";
    out << "  --allow-network <deny|localhost|any>\n";
    out << "  --artifacts <dir>\n";
    out << "  --report-json <path>\n";
    out << "  --report-junit <path>\n";
    out << "  --update-baselines\n";
    out << "  --fail-on-missing-baseline\n";
    out << "  --baseline-key <key>\n";
    out << "  --baseline-write-mode <deny|stage|apply>\n";
    out << "  --baseline-staging-dir <dir>\n";
    out << "  --baseline-approve-token <token>\n";
    out << "  --shard <n>\n";
    out << "  --total-shards <k>\n";
    out << "  --timeout-seconds <int>\n";
    out << "  --default-test-timeout-frames <int>\n";
    out << "  --failure-video <off|on>\n";
    out << "  --failure-video-frames <n>\n";
    out << "  --retry-failures <n>\n";
    out << "  --allow-flaky\n";
    out << "  --auto-audit-on-flake\n";
    out << "  --flake-artifacts\n";
    out << "  --run-quarantined\n";
    out << "  --fail-fast\n";
    out << "  --max-failures <n>\n";
    out << "  --shuffle-tests\n";
    out << "  --shuffle-seed <u32>\n";
    out << "  --test-manifest <path>\n";
    out << "  --rng-scope <test|run>\n";
    out << "  --renderer <null|offscreen|windowed>\n";
    out << "  --determinism-audit\n";
    out << "  --determinism-audit-runs <n>\n";
    out << "  --determinism-audit-scope <test_api|engine|render_hash>\n";
    out << "  --determinism-violation <fatal|warn>\n";
    out << "  --fail-on-log-level <level>\n";
    out << "  --fail-on-log-category <glob>\n";
    out << "  --record-input <path>\n";
    out << "  --replay-input <path>\n";
    out << "  --isolate-tests <none|process-per-file|process-per-test>\n";
    out << "  --lua-sandbox <on|off>\n";
    out << "  --perf-mode <off|collect|enforce>\n";
    out << "  --perf-budget <path>\n";
    out << "  --perf-trace <path>\n";
    return out.str();
}

std::string GenerateRunId() {
    using clock = std::chrono::system_clock;
    auto now = clock::now();
    auto time = clock::to_time_t(now);
    std::tm tm{};
#if defined(_WIN32)
    localtime_s(&tm, &time);
#else
    localtime_r(&time, &tm);
#endif

    auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()) % 1000;

    static std::atomic<uint32_t> sequence{0};
    uint32_t seq = sequence.fetch_add(1);

    std::ostringstream out;
    out << std::put_time(&tm, "%Y%m%d_%H%M%S");
    out << '_' << std::setw(3) << std::setfill('0') << ms.count();
    if (seq > 0) {
        out << '-' << seq;
    }
    return out.str();
}

bool ParseTestModeArgs(int argc, char** argv, TestModeConfig& out, std::string& error) {
    if (argc <= 1) {
        return true;
    }

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--") {
            error = "Unexpected positional arguments";
            return false;
        }

        if (arg.rfind("--", 0) == 0) {
            std::string flag;
            std::optional<std::string> inlineValue = splitValue(arg, flag);

            if (flag == "--test-mode") {
                out.enabled = true;
                continue;
            }
            if (flag == "--headless") {
                if (!parseBool(inlineValue, out.headless, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--test-script") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                out.test_script = value;
                out.enabled = true;
                continue;
            }
            if (flag == "--test-suite") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                out.test_suite = value;
                out.enabled = true;
                continue;
            }
            if (flag == "--list-tests") {
                bool enabled = true;
                if (!parseBool(inlineValue, enabled, error)) {
                    return false;
                }
                out.list_tests = enabled;
                out.enabled = true;
                continue;
            }
            if (flag == "--list-tests-json") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                out.list_tests_json_path = value;
                out.list_tests = true;
                out.enabled = true;
                continue;
            }
            if (flag == "--test-filter") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                out.test_filter = value;
                out.enabled = true;
                continue;
            }
            if (flag == "--run-test-id") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                out.run_test_id = value;
                out.enabled = true;
                continue;
            }
            if (flag == "--run-test-exact") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                out.run_test_exact = value;
                out.enabled = true;
                continue;
            }
            if (flag == "--exclude-tag") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                splitTags(value, out.exclude_tags);
                out.enabled = true;
                continue;
            }
            if (flag == "--include-tag") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                splitTags(value, out.include_tags);
                out.enabled = true;
                continue;
            }
            if (flag == "--seed") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseU32(value, out.seed, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--fixed-fps") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseInt(value, out.fixed_fps, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--resolution") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseResolution(value, out.resolution_width, out.resolution_height, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--allow-network") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseNetworkMode(value, out.allow_network, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--artifacts") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                out.artifacts_dir = value;
                out.artifacts_dir_set = true;
                out.enabled = true;
                continue;
            }
            if (flag == "--report-json") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                out.report_json_path = value;
                out.report_json_set = true;
                out.enabled = true;
                continue;
            }
            if (flag == "--report-junit") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                out.report_junit_path = value;
                out.report_junit_set = true;
                out.enabled = true;
                continue;
            }
            if (flag == "--update-baselines") {
                bool enabled = true;
                if (!parseBool(inlineValue, enabled, error)) {
                    return false;
                }
                out.update_baselines = enabled;
                out.enabled = true;
                continue;
            }
            if (flag == "--fail-on-missing-baseline") {
                bool enabled = true;
                if (!parseBool(inlineValue, enabled, error)) {
                    return false;
                }
                out.fail_on_missing_baseline = enabled;
                out.enabled = true;
                continue;
            }
            if (flag == "--baseline-key") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                out.baseline_key = value;
                out.enabled = true;
                continue;
            }
            if (flag == "--baseline-write-mode") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseBaselineWriteMode(value, out.baseline_write_mode, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--baseline-staging-dir") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                out.baseline_staging_dir = value;
                out.enabled = true;
                continue;
            }
            if (flag == "--baseline-approve-token") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                out.baseline_approve_token = value;
                out.enabled = true;
                continue;
            }
            if (flag == "--shard") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseInt(value, out.shard, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--total-shards") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseInt(value, out.total_shards, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--timeout-seconds") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseInt(value, out.timeout_seconds, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--default-test-timeout-frames") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseInt(value, out.default_test_timeout_frames, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--failure-video") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseFailureVideoMode(value, out.failure_video, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--failure-video-frames") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseInt(value, out.failure_video_frames, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--retry-failures") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseInt(value, out.retry_failures, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--allow-flaky") {
                bool enabled = true;
                if (!parseBool(inlineValue, enabled, error)) {
                    return false;
                }
                out.allow_flaky = enabled;
                out.enabled = true;
                continue;
            }
            if (flag == "--auto-audit-on-flake") {
                bool enabled = true;
                if (!parseBool(inlineValue, enabled, error)) {
                    return false;
                }
                out.auto_audit_on_flake = enabled;
                out.enabled = true;
                continue;
            }
            if (flag == "--flake-artifacts") {
                bool enabled = true;
                if (!parseBool(inlineValue, enabled, error)) {
                    return false;
                }
                out.flake_artifacts = enabled;
                out.enabled = true;
                continue;
            }
            if (flag == "--run-quarantined") {
                bool enabled = true;
                if (!parseBool(inlineValue, enabled, error)) {
                    return false;
                }
                out.run_quarantined = enabled;
                out.enabled = true;
                continue;
            }
            if (flag == "--fail-fast") {
                bool enabled = true;
                if (!parseBool(inlineValue, enabled, error)) {
                    return false;
                }
                out.fail_fast = enabled;
                out.enabled = true;
                continue;
            }
            if (flag == "--max-failures") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseInt(value, out.max_failures, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--shuffle-tests") {
                bool enabled = true;
                if (!parseBool(inlineValue, enabled, error)) {
                    return false;
                }
                out.shuffle_tests = enabled;
                out.enabled = true;
                continue;
            }
            if (flag == "--shuffle-seed") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseU32(value, out.shuffle_seed, error)) {
                    return false;
                }
                out.shuffle_seed_set = true;
                out.enabled = true;
                continue;
            }
            if (flag == "--test-manifest") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                out.test_manifest_path = value;
                out.enabled = true;
                continue;
            }
            if (flag == "--rng-scope") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseRngScope(value, out.rng_scope, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--renderer") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseRendererMode(value, out.renderer, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--determinism-audit") {
                bool enabled = true;
                if (!parseBool(inlineValue, enabled, error)) {
                    return false;
                }
                out.determinism_audit = enabled;
                out.enabled = true;
                continue;
            }
            if (flag == "--determinism-audit-runs") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseInt(value, out.determinism_audit_runs, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--determinism-audit-scope") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseDeterminismAuditScope(value, out.determinism_audit_scope, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--determinism-violation") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseDeterminismViolationMode(value, out.determinism_violation, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--fail-on-log-level") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                out.fail_on_log_level = value;
                out.enabled = true;
                continue;
            }
            if (flag == "--fail-on-log-category") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                out.fail_on_log_category = value;
                out.enabled = true;
                continue;
            }
            if (flag == "--record-input") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                out.record_input = value;
                out.enabled = true;
                continue;
            }
            if (flag == "--replay-input") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                out.replay_input = value;
                out.enabled = true;
                continue;
            }
            if (flag == "--isolate-tests") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseIsolateTestsMode(value, out.isolate_tests, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--lua-sandbox") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseLuaSandboxMode(value, out.lua_sandbox, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--perf-mode") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parsePerfMode(value, out.perf_mode, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            if (flag == "--perf-budget") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                out.perf_budget = value;
                out.enabled = true;
                continue;
            }
            if (flag == "--perf-trace") {
                std::string value;
                if (!readNextValue(inlineValue, i, argc, argv, value, error)) {
                    return false;
                }
                out.perf_trace = value;
                out.enabled = true;
                continue;
            }

            error = "Unknown flag: " + flag + "\n" + BuildTestModeUsage();
            return false;
        }

        if (arg.rfind("-", 0) == 0) {
            if (arg == "-s") {
                std::string value;
                if (!readNextValue(std::nullopt, i, argc, argv, value, error)) {
                    return false;
                }
                if (!parseU32(value, out.seed, error)) {
                    return false;
                }
                out.enabled = true;
                continue;
            }
            error = "Unknown flag: " + arg + "\n" + BuildTestModeUsage();
            return false;
        }

        error = "Unexpected positional argument: " + arg + "\n" + BuildTestModeUsage();
        return false;
    }

    return true;
}

bool ValidateAndFinalize(TestModeConfig& config, std::string& error) {
    const std::filesystem::path root = std::filesystem::current_path();

    if (config.test_script.has_value() && config.test_suite.has_value()) {
        error = "test-script and test-suite are mutually exclusive";
        return false;
    }

    if (config.run_test_id.has_value() && config.run_test_exact.has_value()) {
        error = "run-test-id and run-test-exact are mutually exclusive";
        return false;
    }

    if (!config.test_filter.empty() && (config.run_test_id.has_value() || config.run_test_exact.has_value())) {
        error = "test-filter is mutually exclusive with run-test-id and run-test-exact";
        return false;
    }

    if (config.shard <= 0 || config.total_shards <= 0 || config.shard > config.total_shards) {
        error = "Invalid shard configuration";
        return false;
    }

    if (config.timeout_seconds <= 0) {
        error = "timeout-seconds must be greater than zero";
        return false;
    }

    if (config.fixed_fps <= 0) {
        error = "fixed-fps must be greater than zero";
        return false;
    }

    if (config.resolution_width <= 0 || config.resolution_height <= 0) {
        error = "resolution must be positive";
        return false;
    }

    if (config.default_test_timeout_frames <= 0) {
        error = "default-test-timeout-frames must be greater than zero";
        return false;
    }

    if (config.failure_video_frames <= 0) {
        error = "failure-video-frames must be greater than zero";
        return false;
    }

    if (config.determinism_audit_runs <= 0) {
        error = "determinism-audit-runs must be greater than zero";
        return false;
    }

    if (config.update_baselines) {
        config.fail_on_missing_baseline = false;
        if (config.baseline_write_mode == BaselineWriteMode::Deny) {
            config.baseline_write_mode = BaselineWriteMode::Stage;
        }
    }

    if (config.shuffle_tests && !config.shuffle_seed_set) {
        config.shuffle_seed = deriveShuffleSeed(config.seed);
    }

    if (config.enabled && !config.test_script.has_value() && !config.test_suite.has_value()) {
        config.test_suite = std::filesystem::path("assets") / "scripts" / "tests" / "e2e";
    }

    auto validatePath = [&](const std::filesystem::path& path, bool mustExist, bool mustBeDir) -> bool {
        if (!isUnderRoot(root, path, error)) {
            return false;
        }
        std::filesystem::path resolved = path.is_absolute() ? path : root / path;
        std::error_code ec;
        resolved = std::filesystem::weakly_canonical(resolved, ec);
        if (ec) {
            resolved = resolved.lexically_normal();
        }
        if (mustExist && !std::filesystem::exists(resolved)) {
            error = "Missing required path: " + path.string();
            return false;
        }
        if (mustBeDir && std::filesystem::exists(resolved) && !std::filesystem::is_directory(resolved)) {
            error = "Expected directory path: " + path.string();
            return false;
        }
        return true;
    };

    if (config.test_script.has_value()) {
        if (!validatePath(config.test_script.value(), true, false)) {
            return false;
        }
    }

    if (config.test_suite.has_value()) {
        if (!validatePath(config.test_suite.value(), true, true)) {
            return false;
        }
    }

    if (config.list_tests_json_path.has_value()) {
        if (!validatePath(config.list_tests_json_path.value(), false, false)) {
            return false;
        }
    }

    if (!validatePath(config.test_manifest_path, false, false)) {
        return false;
    }

    if (!validatePath(config.baseline_staging_dir, false, true)) {
        return false;
    }

    if (config.record_input.has_value()) {
        if (!validatePath(config.record_input.value(), false, false)) {
            return false;
        }
    }

    if (config.replay_input.has_value()) {
        if (!validatePath(config.replay_input.value(), true, false)) {
            return false;
        }
    }

    if (config.perf_budget.has_value()) {
        if (!validatePath(config.perf_budget.value(), false, false)) {
            return false;
        }
    }

    if (config.perf_trace.has_value()) {
        if (!validatePath(config.perf_trace.value(), false, false)) {
            return false;
        }
    }

    if (!config.enabled) {
        return true;
    }

    if (config.run_id.empty()) {
        config.run_id = GenerateRunId();
    }

    config.out_dir = std::filesystem::path("tests") / "out" / config.run_id;
    if (!config.artifacts_dir_set) {
        config.artifacts_dir = config.out_dir / "artifacts";
    }
    if (!config.report_json_set) {
        config.report_json_path = config.out_dir / "report.json";
    }
    if (!config.report_junit_set) {
        config.report_junit_path = config.out_dir / "report.junit.xml";
    }
    config.forensics_dir = config.out_dir / "forensics";

    if (!validatePath(config.out_dir, false, true)) {
        return false;
    }
    if (!validatePath(config.artifacts_dir, false, true)) {
        return false;
    }
    if (!validatePath(config.forensics_dir, false, true)) {
        return false;
    }
    if (!validatePath(config.report_json_path, false, false)) {
        return false;
    }
    if (!validatePath(config.report_junit_path, false, false)) {
        return false;
    }

    if (!ensureDir(config.out_dir, error)) {
        return false;
    }
    if (!ensureDir(config.artifacts_dir, error)) {
        return false;
    }
    if (!ensureDir(config.forensics_dir, error)) {
        return false;
    }

    if (config.list_tests_json_path.has_value()) {
        auto jsonPath = config.list_tests_json_path.value();
        std::filesystem::path resolved = jsonPath.is_absolute() ? jsonPath : root / jsonPath;
        if (!ensureDir(resolved.parent_path(), error)) {
            return false;
        }
    }

    std::filesystem::path reportJsonParent = config.report_json_path.parent_path();
    if (!reportJsonParent.empty()) {
        std::filesystem::path resolved = reportJsonParent.is_absolute() ? reportJsonParent : root / reportJsonParent;
        if (!ensureDir(resolved, error)) {
            return false;
        }
    }

    std::filesystem::path reportJunitParent = config.report_junit_path.parent_path();
    if (!reportJunitParent.empty()) {
        std::filesystem::path resolved = reportJunitParent.is_absolute() ? reportJunitParent : root / reportJunitParent;
        if (!ensureDir(resolved, error)) {
            return false;
        }
    }

    return true;
}

} // namespace test_mode
