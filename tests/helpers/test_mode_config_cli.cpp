#include <iostream>

#include "testing/test_mode_config.hpp"

int main(int argc, char** argv) {
    test_mode::TestModeConfig config;
    std::string error;

    if (!test_mode::ParseTestModeArgs(argc, argv, config, error)) {
        std::cerr << error << "\n";
        return 2;
    }

    if (!test_mode::ValidateAndFinalize(config, error)) {
        std::cerr << error << "\n";
        return 2;
    }

    return 0;
}
