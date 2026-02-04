#include "e2e_supervisor_lib.hpp"

#include <chrono>
#include <ctime>
#include <fstream>
#include <iomanip>
#include <optional>
#include <sstream>
#include <thread>

#if defined(_WIN32)
#include <windows.h>
#else
#include <fcntl.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#endif

namespace e2e_supervisor {
namespace {

bool parse_int(const std::string& value, int& out) {
    try {
        size_t pos = 0;
        int parsed = std::stoi(value, &pos);
        if (pos != value.size()) {
            return false;
        }
        out = parsed;
        return true;
    } catch (...) {
        return false;
    }
}

std::optional<std::string> find_arg_value(const std::vector<std::string>& args,
                                          const std::string& flag) {
    for (size_t i = 0; i < args.size(); ++i) {
        const std::string& arg = args[i];
        if (arg == flag) {
            if (i + 1 < args.size()) {
                return args[i + 1];
            }
            return std::nullopt;
        }
        const std::string prefix = flag + "=";
        if (arg.rfind(prefix, 0) == 0) {
            return arg.substr(prefix.size());
        }
    }
    return std::nullopt;
}

std::string platform_label() {
#if defined(_WIN32)
    return "windows";
#elif defined(__APPLE__)
    return "mac";
#elif defined(__linux__)
    return "linux";
#else
    return "unknown";
#endif
}

std::string iso_timestamp_utc() {
    using clock = std::chrono::system_clock;
    auto now = clock::now();
    std::time_t tt = clock::to_time_t(now);
    std::tm tm{};
#if defined(_WIN32)
    gmtime_s(&tm, &tt);
#else
    gmtime_r(&tt, &tm);
#endif
    std::ostringstream out;
    out << std::put_time(&tm, "%Y-%m-%dT%H:%M:%SZ");
    return out.str();
}

std::string resolve_resolution(const std::vector<std::string>& args) {
    if (auto res = find_arg_value(args, "--resolution")) {
        return *res;
    }
    return "1280x720";
}

int resolve_seed(const std::vector<std::string>& args) {
    if (auto seed = find_arg_value(args, "--seed")) {
        int value = 0;
        if (parse_int(*seed, value)) {
            return value;
        }
    }
    return 0;
}

std::filesystem::path resolve_run_root(const std::vector<std::string>& args) {
    if (auto report = find_arg_value(args, "--report-json")) {
        return std::filesystem::path(*report).parent_path();
    }
    if (auto junit = find_arg_value(args, "--report-junit")) {
        return std::filesystem::path(*junit).parent_path();
    }
    if (auto artifacts = find_arg_value(args, "--artifacts")) {
        return std::filesystem::path(*artifacts).parent_path();
    }
    auto out_root = std::filesystem::current_path() / "tests" / "out";
    std::error_code ec;
    std::filesystem::create_directories(out_root, ec);
    auto now = std::chrono::steady_clock::now().time_since_epoch().count();
    std::ostringstream name;
    name << "salvage_" << now;
    return out_root / name.str();
}

void write_text_file(const std::filesystem::path& path, const std::string& contents) {
    std::error_code ec;
    std::filesystem::create_directories(path.parent_path(), ec);
    std::ofstream out(path);
    if (out) {
        out << contents;
    }
}

void write_salvage_manifest(const std::filesystem::path& run_root,
                            const std::vector<std::string>& args,
                            int normalized_exit_code,
                            bool timed_out,
                            bool crashed,
                            int term_signal) {
    std::filesystem::path manifest_path = run_root / "run_manifest.json";
    if (std::filesystem::exists(manifest_path)) {
        return;
    }

    std::ostringstream json;
    json << "{\n";
    json << "  \"schema_version\": \"1.0.0\",\n";
    json << "  \"args\": [";
    for (size_t i = 0; i < args.size(); ++i) {
        if (i > 0) {
            json << ", ";
        }
        json << '\"';
        for (char ch : args[i]) {
            if (ch == '\"') {
                json << "\\\"";
            } else if (ch == '\\') {
                json << "\\\\";
            } else {
                json << ch;
            }
        }
        json << '\"';
    }
    json << "],\n";
    json << "  \"seed\": " << resolve_seed(args) << ",\n";
    json << "  \"platform\": \"" << platform_label() << "\",\n";
    json << "  \"resolution\": \"" << resolve_resolution(args) << "\",\n";
    json << "  \"timestamp\": \"" << iso_timestamp_utc() << "\",\n";
    json << "  \"normalized_exit_code\": " << normalized_exit_code << ",\n";
    json << "  \"timed_out\": " << (timed_out ? "true" : "false") << ",\n";
    json << "  \"crashed\": " << (crashed ? "true" : "false") << ",\n";
    json << "  \"term_signal\": " << term_signal << "\n";
    json << "}\n";

    write_text_file(manifest_path, json.str());
}

void write_salvage_if_needed(const ParsedArgs& parsed,
                             const ProcessResult& result,
                             int normalized_exit_code) {
    if (!result.timed_out && !result.crashed) {
        return;
    }
    std::filesystem::path run_root = resolve_run_root(parsed.game_args);
    std::error_code ec;
    std::filesystem::create_directories(run_root, ec);

    std::filesystem::path forensics_dir = run_root / "forensics";
    std::filesystem::create_directories(forensics_dir, ec);
    if (!result.stderr_data.empty()) {
        write_text_file(forensics_dir / "stderr.txt", result.stderr_data);
    }

    write_salvage_manifest(run_root,
                           parsed.game_args,
                           normalized_exit_code,
                           result.timed_out,
                           result.crashed,
                           result.term_signal);
}

#if defined(_WIN32)

std::string quote_arg(const std::string& arg) {
    if (arg.find_first_of(" \t\"") == std::string::npos) {
        return arg;
    }
    std::string quoted = "\"";
    for (char ch : arg) {
        if (ch == '\"') {
            quoted += "\\\"";
        } else {
            quoted.push_back(ch);
        }
    }
    quoted += "\"";
    return quoted;
}

std::string build_command_line(const std::vector<std::string>& args) {
    std::ostringstream out;
    for (size_t i = 0; i < args.size(); ++i) {
        if (i > 0) {
            out << ' ';
        }
        out << quote_arg(args[i]);
    }
    return out.str();
}

bool read_pipe_nonblocking(HANDLE pipe, std::string& output) {
    DWORD available = 0;
    if (!PeekNamedPipe(pipe, nullptr, 0, nullptr, &available, nullptr)) {
        return false;
    }
    if (available == 0) {
        return true;
    }
    std::string buffer;
    buffer.resize(available);
    DWORD read_bytes = 0;
    if (!ReadFile(pipe, buffer.data(), available, &read_bytes, nullptr)) {
        return false;
    }
    if (read_bytes > 0) {
        output.append(buffer.data(), buffer.data() + read_bytes);
    }
    return true;
}

#else

bool set_nonblocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0) {
        return false;
    }
    return fcntl(fd, F_SETFL, flags | O_NONBLOCK) == 0;
}

void drain_fd(int fd, std::string& output) {
    char buffer[4096];
    while (true) {
        ssize_t count = read(fd, buffer, sizeof(buffer));
        if (count > 0) {
            output.append(buffer, buffer + count);
        } else {
            break;
        }
    }
}

#endif

} // namespace

void print_usage(std::ostream& out, const char* argv0) {
    out << "Usage: " << argv0
        << " <list|run> [--timeout-seconds N] [--dump-grace-seconds N] [--no-dump-request] -- <game args...>\n";
}

bool parse_args(int argc, char** argv, ParsedArgs& out) {
    if (argc < 2) {
        return false;
    }
    out.subcommand = argv[1];
    int i = 2;
    for (; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--") {
            ++i;
            break;
        }
        if (arg == "--timeout-seconds") {
            if (i + 1 >= argc) {
                return false;
            }
            int value = 0;
            if (!parse_int(argv[++i], value)) {
                return false;
            }
            out.options.timeout_seconds = value;
            continue;
        }
        if (arg == "--dump-grace-seconds") {
            if (i + 1 >= argc) {
                return false;
            }
            int value = 0;
            if (!parse_int(argv[++i], value)) {
                return false;
            }
            out.options.dump_grace_seconds = value;
            continue;
        }
        if (arg == "--no-dump-request") {
            out.options.request_dump = false;
            continue;
        }
        return false;
    }
    for (; i < argc; ++i) {
        out.game_args.emplace_back(argv[i]);
    }
    return !out.subcommand.empty() && !out.game_args.empty();
}

ProcessResult run_process(const std::vector<std::string>& args, const Options& options) {
    ProcessResult result;

#if defined(_WIN32)
    SECURITY_ATTRIBUTES sa{};
    sa.nLength = sizeof(sa);
    sa.bInheritHandle = TRUE;

    HANDLE stdout_read = nullptr;
    HANDLE stdout_write = nullptr;
    HANDLE stderr_read = nullptr;
    HANDLE stderr_write = nullptr;

    if (!CreatePipe(&stdout_read, &stdout_write, &sa, 0)) {
        result.exit_code = 2;
        return result;
    }
    if (!CreatePipe(&stderr_read, &stderr_write, &sa, 0)) {
        CloseHandle(stdout_read);
        CloseHandle(stdout_write);
        result.exit_code = 2;
        return result;
    }

    SetHandleInformation(stdout_read, HANDLE_FLAG_INHERIT, 0);
    SetHandleInformation(stderr_read, HANDLE_FLAG_INHERIT, 0);

    STARTUPINFOA si{};
    si.cb = sizeof(si);
    si.dwFlags |= STARTF_USESTDHANDLES;
    si.hStdOutput = stdout_write;
    si.hStdError = stderr_write;
    si.hStdInput = GetStdHandle(STD_INPUT_HANDLE);

    PROCESS_INFORMATION pi{};
    std::string command_line = build_command_line(args);
    BOOL ok = CreateProcessA(nullptr,
                             command_line.data(),
                             nullptr,
                             nullptr,
                             TRUE,
                             0,
                             nullptr,
                             nullptr,
                             &si,
                             &pi);

    CloseHandle(stdout_write);
    CloseHandle(stderr_write);

    if (!ok) {
        CloseHandle(stdout_read);
        CloseHandle(stderr_read);
        result.exit_code = 2;
        return result;
    }

    auto start = std::chrono::steady_clock::now();
    bool timed_out = false;
    bool dump_requested = false;
    auto dump_deadline = start;

    while (true) {
        read_pipe_nonblocking(stdout_read, result.stdout_data);
        read_pipe_nonblocking(stderr_read, result.stderr_data);

        DWORD wait_ms = 50;
        DWORD wait_result = WaitForSingleObject(pi.hProcess, wait_ms);
        if (wait_result == WAIT_OBJECT_0) {
            break;
        }

        auto now = std::chrono::steady_clock::now();
        if (options.timeout_seconds > 0 && !timed_out) {
            auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - start).count();
            if (elapsed >= options.timeout_seconds) {
                timed_out = true;
                result.timed_out = true;
                if (options.request_dump) {
                    dump_requested = true;
                    dump_deadline = now + std::chrono::seconds(options.dump_grace_seconds);
                } else {
                    TerminateProcess(pi.hProcess, 3);
                }
            }
        }
        if (dump_requested && std::chrono::steady_clock::now() >= dump_deadline) {
            TerminateProcess(pi.hProcess, 3);
            dump_requested = false;
        }
    }

    DWORD exit_code = 0;
    if (GetExitCodeProcess(pi.hProcess, &exit_code)) {
        result.exit_code = static_cast<int>(exit_code);
    }

    read_pipe_nonblocking(stdout_read, result.stdout_data);
    read_pipe_nonblocking(stderr_read, result.stderr_data);

    CloseHandle(stdout_read);
    CloseHandle(stderr_read);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);

    if (result.timed_out) {
        result.exit_code = 3;
    }

    return result;
#else
    int stdout_pipe[2];
    int stderr_pipe[2];
    if (pipe(stdout_pipe) != 0 || pipe(stderr_pipe) != 0) {
        result.exit_code = 2;
        result.crashed = true;
        return result;
    }

    pid_t pid = fork();
    if (pid == 0) {
        dup2(stdout_pipe[1], STDOUT_FILENO);
        dup2(stderr_pipe[1], STDERR_FILENO);
        close(stdout_pipe[0]);
        close(stdout_pipe[1]);
        close(stderr_pipe[0]);
        close(stderr_pipe[1]);

        std::vector<char*> argv_exec;
        argv_exec.reserve(args.size() + 1);
        for (const auto& arg : args) {
            argv_exec.push_back(const_cast<char*>(arg.c_str()));
        }
        argv_exec.push_back(nullptr);
        execvp(argv_exec[0], argv_exec.data());
        _exit(127);
    }

    close(stdout_pipe[1]);
    close(stderr_pipe[1]);
    set_nonblocking(stdout_pipe[0]);
    set_nonblocking(stderr_pipe[0]);

    auto start = std::chrono::steady_clock::now();
    bool timed_out = false;
    bool dump_requested = false;
    auto dump_deadline = start;

    int status = 0;
    while (true) {
        drain_fd(stdout_pipe[0], result.stdout_data);
        drain_fd(stderr_pipe[0], result.stderr_data);

        pid_t wait_result = waitpid(pid, &status, WNOHANG);
        if (wait_result == pid) {
            break;
        }

        auto now = std::chrono::steady_clock::now();
        if (options.timeout_seconds > 0 && !timed_out) {
            auto elapsed = std::chrono::duration_cast<std::chrono::seconds>(now - start).count();
            if (elapsed >= options.timeout_seconds) {
                timed_out = true;
                result.timed_out = true;
                if (options.request_dump) {
                    kill(pid, SIGUSR1);
                    dump_requested = true;
                    dump_deadline = now + std::chrono::seconds(options.dump_grace_seconds);
                } else {
                    kill(pid, SIGKILL);
                }
            }
        }
        if (dump_requested && std::chrono::steady_clock::now() >= dump_deadline) {
            kill(pid, SIGKILL);
            dump_requested = false;
        }

        std::this_thread::sleep_for(std::chrono::milliseconds(50));
    }

    drain_fd(stdout_pipe[0], result.stdout_data);
    drain_fd(stderr_pipe[0], result.stderr_data);
    close(stdout_pipe[0]);
    close(stderr_pipe[0]);

    if (WIFEXITED(status)) {
        result.exit_code = WEXITSTATUS(status);
    } else if (WIFSIGNALED(status)) {
        result.crashed = true;
        result.term_signal = WTERMSIG(status);
    }

    if (result.timed_out) {
        result.exit_code = 3;
    }

    return result;
#endif
}

int normalize_exit_code(const ProcessResult& result) {
    if (result.timed_out) {
        return 3;
    }
    if (result.crashed) {
        return 4;
    }
    if (result.exit_code == 127) {
        return 2;
    }
    if (result.exit_code == 0 || result.exit_code == 1 || result.exit_code == 2) {
        return result.exit_code;
    }
    return 4;
}

std::filesystem::path make_temp_json_path(const std::string& prefix) {
    auto now = std::chrono::steady_clock::now().time_since_epoch().count();
    std::ostringstream name;
    name << prefix << "_" << now << "_" << std::this_thread::get_id() << ".json";
    auto out_root = std::filesystem::current_path() / "tests" / "out";
    std::error_code ec;
    std::filesystem::create_directories(out_root, ec);
    return out_root / name.str();
}

int run_list_command(const ParsedArgs& parsed, std::string& out_stdout, std::string& out_stderr) {
    std::vector<std::string> game_args = parsed.game_args;
    std::filesystem::path list_path = make_temp_json_path("test_list");
    game_args.push_back("--test-mode");
    game_args.push_back("--list-tests-json");
    game_args.push_back(list_path.string());

    ProcessResult result = run_process(game_args, parsed.options);
    out_stdout = result.stdout_data;
    out_stderr = result.stderr_data;

    int exit_code = normalize_exit_code(result);
    if (exit_code != 0) {
        return exit_code;
    }

    if (!std::filesystem::exists(list_path)) {
        out_stderr += "list output missing: \"" + list_path.string() + "\"\n";
        return 2;
    }

    std::ifstream in(list_path);
    if (!in) {
        out_stderr += "failed to read list output: \"" + list_path.string() + "\"\n";
        return 2;
    }
    std::ostringstream contents;
    contents << in.rdbuf();
    out_stdout += contents.str();
    return 0;
}

int run_run_command(const ParsedArgs& parsed, std::string& out_stdout, std::string& out_stderr) {
    ProcessResult result = run_process(parsed.game_args, parsed.options);
    out_stdout = result.stdout_data;
    out_stderr = result.stderr_data;
    int exit_code = normalize_exit_code(result);
    write_salvage_if_needed(parsed, result, exit_code);
    return exit_code;
}

} // namespace e2e_supervisor
