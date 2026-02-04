#include <gtest/gtest.h>

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <string>

#include "tools/e2e_supervisor_lib.hpp"

#if defined(__linux__)
#include <unistd.h>
#endif

namespace fs = std::filesystem;

namespace {

fs::path find_stub_path() {
    std::vector<fs::path> candidates;
    fs::path cwd = fs::current_path();
    candidates.push_back(cwd / "e2e_supervisor_stub");
    candidates.push_back(cwd / "tests" / "e2e_supervisor_stub");

#if defined(__linux__)
    char buffer[4096];
    ssize_t len = readlink("/proc/self/exe", buffer, sizeof(buffer) - 1);
    if (len > 0) {
        buffer[len] = '\0';
        fs::path exe_dir = fs::path(buffer).parent_path();
        candidates.push_back(exe_dir / "e2e_supervisor_stub");
        candidates.push_back(exe_dir.parent_path() / "e2e_supervisor_stub");
        candidates.push_back(exe_dir.parent_path() / "tests" / "e2e_supervisor_stub");
    }
#endif

    for (const auto& candidate : candidates) {
        if (fs::exists(candidate)) {
            return candidate;
        }
    }
    return {};
}

fs::path temp_file_path(const std::string& name) {
    auto root = fs::temp_directory_path() / "e2e_supervisor_tests";
    fs::create_directories(root);
    return root / name;
}


TEST(E2ESupervisor, ParseArgsList) {
    const char* argv[] = {
        "e2e_supervisor",
        "list",
        "--timeout-seconds",
        "12",
        "--dump-grace-seconds",
        "3",
        "--",
        "/bin/echo",
        "hi"
    };
    e2e_supervisor::ParsedArgs parsed;
    const int argc = static_cast<int>(sizeof(argv) / sizeof(argv[0]));
    ASSERT_TRUE(e2e_supervisor::parse_args(argc, const_cast<char**>(argv), parsed));
    EXPECT_EQ(parsed.subcommand, "list");
    EXPECT_EQ(parsed.options.timeout_seconds, 12);
    EXPECT_EQ(parsed.options.dump_grace_seconds, 3);
    ASSERT_EQ(parsed.game_args.size(), 2u);
    EXPECT_EQ(parsed.game_args[0], "/bin/echo");
    EXPECT_EQ(parsed.game_args[1], "hi");
}

TEST(E2ESupervisor, NormalizeExitCode) {
    e2e_supervisor::ProcessResult result;
    result.exit_code = 1;
    EXPECT_EQ(e2e_supervisor::normalize_exit_code(result), 1);

    result.exit_code = 127;
    EXPECT_EQ(e2e_supervisor::normalize_exit_code(result), 2);

    result.exit_code = 5;
    EXPECT_EQ(e2e_supervisor::normalize_exit_code(result), 4);

    result.exit_code = 0;
    result.timed_out = true;
    EXPECT_EQ(e2e_supervisor::normalize_exit_code(result), 3);

    result.timed_out = false;
    result.crashed = true;
    EXPECT_EQ(e2e_supervisor::normalize_exit_code(result), 4);
}

TEST(E2ESupervisor, RunProcessCapturesOutput) {
    fs::path stub = find_stub_path();
    ASSERT_FALSE(stub.empty());

    std::vector<std::string> args = {
        stub.string(),
        "--stdout", "hello",
        "--stderr", "oops",
        "--exit-code", "0"
    };
    e2e_supervisor::Options options;
    options.timeout_seconds = 5;

    auto result = e2e_supervisor::run_process(args, options);
    EXPECT_EQ(result.exit_code, 0);
    EXPECT_NE(result.stdout_data.find("hello"), std::string::npos);
    EXPECT_NE(result.stderr_data.find("oops"), std::string::npos);
}

TEST(E2ESupervisor, RunProcessTimeoutAndDump) {
    fs::path stub = find_stub_path();
    ASSERT_FALSE(stub.empty());

    fs::path dump_path = temp_file_path("hang_dump.json");
    std::error_code ec;
    fs::remove(dump_path, ec);
#if defined(_WIN32)
    _putenv_s("E2E_SUPERVISOR_DUMP_PATH", dump_path.string().c_str());
#else
    setenv("E2E_SUPERVISOR_DUMP_PATH", dump_path.string().c_str(), 1);
#endif

    std::vector<std::string> args = {
        stub.string(),
        "--sleep-ms", "3000"
    };
    e2e_supervisor::Options options;
    options.timeout_seconds = 1;
    options.dump_grace_seconds = 1;
    options.request_dump = true;

    auto result = e2e_supervisor::run_process(args, options);
    EXPECT_TRUE(result.timed_out);
    EXPECT_EQ(result.exit_code, 3);
#if !defined(_WIN32)
    EXPECT_TRUE(fs::exists(dump_path));
#endif
}

TEST(E2ESupervisor, RunProcessCrash) {
#if defined(_WIN32)
    GTEST_SKIP() << "Crash signal test not supported on Windows in this environment.";
#else
    fs::path stub = find_stub_path();
    ASSERT_FALSE(stub.empty());

    std::vector<std::string> args = {
        stub.string(),
        "--crash"
    };
    e2e_supervisor::Options options;
    options.timeout_seconds = 5;

    auto result = e2e_supervisor::run_process(args, options);
    EXPECT_TRUE(result.crashed);
    EXPECT_EQ(e2e_supervisor::normalize_exit_code(result), 4);
#endif
}

TEST(E2ESupervisor, RunListCommandSuccess) {
    fs::path stub = find_stub_path();
    ASSERT_FALSE(stub.empty());

    e2e_supervisor::ParsedArgs parsed;
    parsed.subcommand = "list";
    parsed.options.timeout_seconds = 5;
    parsed.game_args = {stub.string(), "--stdout", "child"};

    std::string out_stdout;
    std::string out_stderr;
    int code = e2e_supervisor::run_list_command(parsed, out_stdout, out_stderr);

    EXPECT_EQ(code, 0);
    EXPECT_NE(out_stdout.find("child"), std::string::npos);
    EXPECT_NE(out_stdout.find("stub.test"), std::string::npos);
    EXPECT_TRUE(out_stderr.empty());
}

TEST(E2ESupervisor, RunListCommandFailureExitCode) {
    fs::path stub = find_stub_path();
    ASSERT_FALSE(stub.empty());

    e2e_supervisor::ParsedArgs parsed;
    parsed.subcommand = "list";
    parsed.options.timeout_seconds = 5;
    parsed.game_args = {stub.string(), "--exit-code", "1"};

    std::string out_stdout;
    std::string out_stderr;
    int code = e2e_supervisor::run_list_command(parsed, out_stdout, out_stderr);

    EXPECT_EQ(code, 1);
}

TEST(E2ESupervisor, RunListCommandMissingBinary) {
    e2e_supervisor::ParsedArgs parsed;
    parsed.subcommand = "list";
    parsed.options.timeout_seconds = 5;
    parsed.game_args = {"/nonexistent/e2e_supervisor_missing_binary"};

    std::string out_stdout;
    std::string out_stderr;
    int code = e2e_supervisor::run_list_command(parsed, out_stdout, out_stderr);

    EXPECT_EQ(code, 2);
}

TEST(E2ESupervisor, RunListCommandTimeout) {
    fs::path stub = find_stub_path();
    ASSERT_FALSE(stub.empty());

    e2e_supervisor::ParsedArgs parsed;
    parsed.subcommand = "list";
    parsed.options.timeout_seconds = 1;
    parsed.options.dump_grace_seconds = 1;
    parsed.options.request_dump = false;
    parsed.game_args = {stub.string(), "--sleep-ms", "3000"};

    std::string out_stdout;
    std::string out_stderr;
    int code = e2e_supervisor::run_list_command(parsed, out_stdout, out_stderr);

    EXPECT_EQ(code, 3);
}

TEST(E2ESupervisor, SalvageOnTimeoutWritesManifestAndStderr) {
    fs::path stub = find_stub_path();
    ASSERT_FALSE(stub.empty());

    fs::path run_root = fs::temp_directory_path() / "e2e_supervisor_tests" / "salvage_timeout";
    std::error_code ec;
    fs::remove_all(run_root, ec);
    fs::create_directories(run_root, ec);

    fs::path report_json = run_root / "report.json";

    e2e_supervisor::ParsedArgs parsed;
    parsed.subcommand = "run";
    parsed.options.timeout_seconds = 1;
    parsed.options.dump_grace_seconds = 1;
    parsed.options.request_dump = false;
    parsed.game_args = {
        stub.string(),
        "--stderr", "timeout",
        "--sleep-ms", "3000",
        "--report-json", report_json.string()
    };

    std::string out_stdout;
    std::string out_stderr;
    int code = e2e_supervisor::run_run_command(parsed, out_stdout, out_stderr);

    EXPECT_EQ(code, 3);
    EXPECT_TRUE(fs::exists(run_root / "run_manifest.json"));
    EXPECT_TRUE(fs::exists(run_root / "forensics" / "stderr.txt"));

    std::ifstream manifest(run_root / "run_manifest.json");
    std::string content((std::istreambuf_iterator<char>(manifest)), std::istreambuf_iterator<char>());
    EXPECT_NE(content.find("\"schema_version\""), std::string::npos);
}

TEST(E2ESupervisor, RunRunCommandExitCode) {
    fs::path stub = find_stub_path();
    ASSERT_FALSE(stub.empty());

    e2e_supervisor::ParsedArgs parsed;
    parsed.subcommand = "run";
    parsed.options.timeout_seconds = 5;
    parsed.game_args = {stub.string(), "--exit-code", "1"};

    std::string out_stdout;
    std::string out_stderr;
    int code = e2e_supervisor::run_run_command(parsed, out_stdout, out_stderr);

    EXPECT_EQ(code, 1);
}

TEST(E2ESupervisor, RunRunCommandCapturesStdoutStderr) {
    fs::path stub = find_stub_path();
    ASSERT_FALSE(stub.empty());

    e2e_supervisor::ParsedArgs parsed;
    parsed.subcommand = "run";
    parsed.options.timeout_seconds = 5;
    parsed.game_args = {
        stub.string(),
        "--stdout", "hello",
        "--stderr", "oops",
        "--exit-code", "0"
    };

    std::string out_stdout;
    std::string out_stderr;
    int code = e2e_supervisor::run_run_command(parsed, out_stdout, out_stderr);

    EXPECT_EQ(code, 0);
    EXPECT_NE(out_stdout.find("hello"), std::string::npos);
    EXPECT_NE(out_stderr.find("oops"), std::string::npos);
}

} // namespace
