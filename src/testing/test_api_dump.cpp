#include "testing/test_api_dump.hpp"
#include "testing/test_api_registry.hpp"

namespace testing {

bool write_test_api_json(const TestApiRegistry& registry,
                        const std::filesystem::path& output_path) {
    return registry.write_json(output_path);
}

} // namespace testing
