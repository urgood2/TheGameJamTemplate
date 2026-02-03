#include <iostream>
#include <string>

#include "testing/test_mode_config.hpp"

int main(int argc, char** argv) {
    testing::TestModeConfig config;
    std::string error;

    if (!testing::parse_test_mode_args(argc, argv, config, error)) {
        std::cerr << error << "\n";
        return 2;
    }

    if (!testing::validate_and_finalize(config, error)) {
        std::cerr << error << "\n";
        return 2;
    }

    return 0;
}
