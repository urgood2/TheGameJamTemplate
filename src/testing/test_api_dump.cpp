#include "testing/test_api_dump.hpp"
#include "testing/test_api_registry.hpp"

namespace testing {

bool write_test_api_json(const TestApiRegistry& registry,
                        const std::filesystem::path& output_path) {
    (void)registry;
    (void)output_path;
    return false;
}

} // namespace testing
