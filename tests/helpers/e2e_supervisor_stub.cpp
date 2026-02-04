#include <chrono>
#include <csignal>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <thread>

#if defined(_WIN32)
#include <windows.h>
#endif

namespace {

std::string g_dump_path;

#if !defined(_WIN32)
void handle_sigusr1(int) {
    if (g_dump_path.empty()) {
        return;
    }
    std::ofstream out(g_dump_path);
    if (out) {
        out << "hang dump";
    }
}
#endif

} // namespace

int main(int argc, char** argv) {
    int exit_code = 0;
    int sleep_ms = 0;
    bool crash = false;
    std::string stdout_msg;
    std::string stderr_msg;
    std::string list_path;
    std::string report_path;
    std::string junit_path;

    const char* dump_env = std::getenv("E2E_SUPERVISOR_DUMP_PATH");
    if (dump_env) {
        g_dump_path = dump_env;
        if (!g_dump_path.empty()) {
            std::error_code ec;
            std::filesystem::path dump_parent = std::filesystem::path(g_dump_path).parent_path();
            if (!dump_parent.empty()) {
                std::filesystem::create_directories(dump_parent, ec);
            }
        }
    }

#if !defined(_WIN32)
    std::signal(SIGUSR1, handle_sigusr1);
#endif

    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--exit-code" && i + 1 < argc) {
            exit_code = std::stoi(argv[++i]);
        } else if (arg == "--sleep-ms" && i + 1 < argc) {
            sleep_ms = std::stoi(argv[++i]);
        } else if (arg == "--crash") {
            crash = true;
        } else if (arg == "--stdout" && i + 1 < argc) {
            stdout_msg = argv[++i];
        } else if (arg == "--stderr" && i + 1 < argc) {
            stderr_msg = argv[++i];
        } else if (arg == "--list-tests-json" && i + 1 < argc) {
            list_path = argv[++i];
        } else if (arg == "--write-report" && i + 1 < argc) {
            report_path = argv[++i];
        } else if (arg == "--write-junit" && i + 1 < argc) {
            junit_path = argv[++i];
        }
    }

    if (!list_path.empty()) {
        std::filesystem::path path(list_path);
        std::filesystem::create_directories(path.parent_path());
        std::ofstream out(path);
        out << "{\"tests\":[{\"id\":\"stub.test\"}]}";
    }

    if (!report_path.empty()) {
        std::filesystem::path path(report_path);
        std::filesystem::create_directories(path.parent_path());
        std::ofstream out(path);
        out << "{\"schema_version\":\"1.0.0\",\"tests\":[]}";
    }

    if (!junit_path.empty()) {
        std::filesystem::path path(junit_path);
        std::filesystem::create_directories(path.parent_path());
        std::ofstream out(path);
        out << "<testsuite name=\"stub\" tests=\"0\"></testsuite>";
    }

    if (!stdout_msg.empty()) {
        std::cout << stdout_msg;
    }
    if (!stderr_msg.empty()) {
        std::cerr << stderr_msg;
    }

    if (sleep_ms > 0) {
        std::this_thread::sleep_for(std::chrono::milliseconds(sleep_ms));
    }

    if (crash) {
#if defined(_WIN32)
        // Windows equivalent: access violation
        int* ptr = nullptr;
        *ptr = 1;
#else
        std::raise(SIGSEGV);
#endif
    }

    return exit_code;
}
