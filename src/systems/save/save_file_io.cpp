#include "save_file_io.hpp"

#include <filesystem>
#include <fstream>
#include <mutex>
#include <queue>
#include <sstream>

#include "spdlog/spdlog.h"

#if defined(__EMSCRIPTEN__)
#include <emscripten/emscripten.h>
#endif

namespace save_io {
namespace {

namespace fs = std::filesystem;

// Pending callbacks to run on main thread
struct PendingCallback {
    sol::function callback;
    bool success;
};

std::mutex g_callback_mutex;
std::queue<PendingCallback> g_pending_callbacks;

void queue_callback(sol::function callback, bool success) {
    if (!callback.valid()) return;
    std::lock_guard<std::mutex> lock(g_callback_mutex);
    g_pending_callbacks.push({std::move(callback), success});
}

} // anonymous namespace

auto load_file(const std::string& path) -> std::optional<std::string> {
    std::ifstream file(path, std::ios::binary);
    if (!file.is_open()) {
        SPDLOG_DEBUG("save_io::load_file - file not found: {}", path);
        return std::nullopt;
    }

    std::ostringstream ss;
    ss << file.rdbuf();

    if (file.fail() && !file.eof()) {
        SPDLOG_WARN("save_io::load_file - read error: {}", path);
        return std::nullopt;
    }

    return ss.str();
}

auto file_exists(const std::string& path) -> bool {
    std::error_code ec;
    return fs::exists(path, ec);
}

auto delete_file(const std::string& path) -> bool {
    std::error_code ec;
    if (!fs::exists(path, ec)) {
        return true; // Already doesn't exist
    }
    return fs::remove(path, ec);
}

void process_pending_callbacks() {
    std::queue<PendingCallback> to_process;
    {
        std::lock_guard<std::mutex> lock(g_callback_mutex);
        std::swap(to_process, g_pending_callbacks);
    }

    while (!to_process.empty()) {
        auto& pending = to_process.front();
        if (pending.callback.valid()) {
            auto result = pending.callback(pending.success);
            if (!result.valid()) {
                sol::error err = result;
                SPDLOG_WARN("save_io callback error: {}", err.what());
            }
        }
        to_process.pop();
    }
}

} // namespace save_io
