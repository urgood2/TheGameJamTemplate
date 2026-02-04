#include "e2e_supervisor_lib.hpp"

#include <iostream>

int main(int argc, char** argv) {
    e2e_supervisor::ParsedArgs parsed;
    if (!e2e_supervisor::parse_args(argc, argv, parsed)) {
        e2e_supervisor::print_usage(std::cerr, argv[0]);
        return 2;
    }

    const std::string subcommand = parsed.subcommand;
    if (subcommand != "list" && subcommand != "run") {
        e2e_supervisor::print_usage(std::cerr, argv[0]);
        return 2;
    }

    std::string out_stdout;
    std::string out_stderr;
    int exit_code = 0;
    if (subcommand == "list") {
        exit_code = e2e_supervisor::run_list_command(parsed, out_stdout, out_stderr);
    } else {
        exit_code = e2e_supervisor::run_run_command(parsed, out_stdout, out_stderr);
    }

    std::cout << out_stdout;
    std::cerr << out_stderr;
    return exit_code;
}
