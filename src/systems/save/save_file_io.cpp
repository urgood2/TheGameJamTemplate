#include "save_file_io.hpp"

#include <filesystem>
#include <fstream>
#include <mutex>
#include <queue>
#include <sstream>
#include <thread>

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

bool write_atomic(const std::string& path, const std::string& content) {
    const std::string temp_path = path + ".tmp";
    const std::string backup_path = path + ".bak";

    // Ensure parent directory exists
    std::error_code ec;
    fs::path parent = fs::path(path).parent_path();
    if (!parent.empty()) {
        fs::create_directories(parent, ec);
        if (ec) {
            SPDLOG_WARN("save_io::write_atomic - failed to create directory: {}", parent.string());
            return false;
        }
    }

    // Write to temp file
    {
        std::ofstream file(temp_path, std::ios::binary | std::ios::trunc);
        if (!file.is_open()) {
            SPDLOG_WARN("save_io::write_atomic - failed to open temp file: {}", temp_path);
            return false;
        }
        file << content;
        file.flush();
        if (file.fail()) {
            SPDLOG_WARN("save_io::write_atomic - write failed: {}", temp_path);
            return false;
        }
    }

    // Atomic rename temp -> target
    fs::rename(temp_path, path, ec);
    if (ec) {
        SPDLOG_WARN("save_io::write_atomic - rename failed: {} -> {}", temp_path, path);
        fs::remove(temp_path, ec);
        return false;
    }

    // Create backup (non-fatal if fails)
    fs::copy_file(path, backup_path, fs::copy_options::overwrite_existing, ec);
    if (ec) {
        SPDLOG_DEBUG("save_io::write_atomic - backup copy failed (non-fatal): {}", backup_path);
    }

    SPDLOG_DEBUG("save_io::write_atomic - saved successfully: {}", path);
    return true;
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

void save_file_async(const std::string& path,
                     const std::string& content,
                     sol::function on_complete) {
#if defined(__EMSCRIPTEN__)
    // Web: Write to MEMFS (sync), then async persist to IndexedDB
    bool success = write_atomic(path, content);

    if (success) {
        // Async sync to IndexedDB
        EM_ASM({
            if (typeof FS !== 'undefined' && FS.syncfs) {
                FS.syncfs(false, function(err) {
                    if (err) {
                        console.warn('IDBFS sync failed:', err);
                    }
                });
            }
        });
    }

    // Callback immediately - MEMFS write is what matters for gameplay
    queue_callback(std::move(on_complete), success);

#else
    // Desktop: Background thread
    // Copy callback to shared_ptr for thread safety
    auto callback_ptr = std::make_shared<sol::function>(std::move(on_complete));

    std::thread([path, content, callback_ptr]() {
        bool success = write_atomic(path, content);
        queue_callback(std::move(*callback_ptr), success);
    }).detach();
#endif
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

void init_filesystem() {
#if defined(__EMSCRIPTEN__)
    // Create saves directory and mount IDBFS for web persistence
    EM_ASM({
        // Create directory if needed
        try {
            FS.mkdir('/saves');
        } catch (e) {
            // Directory may already exist
        }

        // Mount IDBFS for persistent storage
        FS.mount(IDBFS, {}, '/saves');

        // Load existing data from IndexedDB into MEMFS
        FS.syncfs(true, function(err) {
            if (err) {
                console.error('[save_io] Failed to load from IndexedDB:', err);
            } else {
                console.log('[save_io] IDBFS initialized, existing saves loaded');
            }
        });
    });
    SPDLOG_INFO("save_io: IDBFS mounted at /saves");
#else
    // Desktop: just ensure saves directory exists
    fs::create_directories("saves");
    SPDLOG_INFO("save_io: saves directory ready");
#endif
}

void register_lua_bindings(sol::state& lua) {
    sol::table save_io_table = lua.create_named_table("save_io");

    save_io_table.set_function("load_file", &load_file);
    save_io_table.set_function("file_exists", &file_exists);
    save_io_table.set_function("delete_file", &delete_file);
    save_io_table.set_function("save_file_async", &save_file_async);
    save_io_table.set_function("init_filesystem", &init_filesystem);

    SPDLOG_DEBUG("save_io Lua bindings registered");
}

} // namespace save_io
