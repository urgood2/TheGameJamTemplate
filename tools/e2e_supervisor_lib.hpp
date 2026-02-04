#pragma once

#include <filesystem>
#include <ostream>
#include <string>
#include <vector>

namespace e2e_supervisor {

struct Options {
    int timeout_seconds = 600;
    int dump_grace_seconds = 5;
    bool request_dump = true;
};

struct ProcessResult {
    int exit_code = 0;
    bool timed_out = false;
    bool crashed = false;
    int term_signal = 0;
    std::string stdout_data;
    std::string stderr_data;
};

struct ParsedArgs {
    std::string subcommand;
    Options options;
    std::vector<std::string> game_args;
};

void print_usage(std::ostream& out, const char* argv0);

bool parse_args(int argc, char** argv, ParsedArgs& out);

ProcessResult run_process(const std::vector<std::string>& args, const Options& options);

int normalize_exit_code(const ProcessResult& result);

std::filesystem::path make_temp_json_path(const std::string& prefix);

int run_list_command(const ParsedArgs& parsed, std::string& out_stdout, std::string& out_stderr);

int run_run_command(const ParsedArgs& parsed, std::string& out_stdout, std::string& out_stderr);

} // namespace e2e_supervisor
