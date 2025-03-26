#include "csys_console_sink.hpp"
#include <spdlog/details/log_msg.h>  // For spdlog::details::log_msg
#include <fmt/core.h>  // For fmt::to_string

#include "core/gui.hpp"
#include "imgui_console.h"

// Implementation of the constructor
template <typename Mutex>
csys_console_sink<Mutex>::csys_console_sink(csys::System& console) : console_system(console) {}

// Implementation of the sink_it_ function
template <typename Mutex>
void csys_console_sink<Mutex>::sink_it_(const spdlog::details::log_msg& msg)
{
    // Convert log message to a string
    spdlog::memory_buf_t formatted;
    this->formatter_->format(msg, formatted);

    // Log the message to spdlog's default output (console/file)
    std::string log_message = fmt::to_string(formatted);

    // Determine the log level and log to the csys console
    csys::ItemType log_type = csys::ItemType::INFO;
    switch (msg.level) {
        case spdlog::level::err:
        case spdlog::level::critical:
            log_type = csys::ItemType::ERROR;
            break;
        case spdlog::level::warn:
            log_type = csys::ItemType::WARNING;
            break;
        case spdlog::level::info:
        case spdlog::level::debug:
        default:
            log_type = csys::ItemType::INFO;
            break;
    }

    // Use the csys system to log the message
    console_system.Log(log_type) << log_message << csys::endl;

    // Scroll the ImGui console to the bottom
    gui::consolePtr->PushScrollToBottom();
}

// Implementation of flush_ (empty implementation)
template <typename Mutex>
void csys_console_sink<Mutex>::flush_() {}

// Explicit instantiation for std::mutex
template class csys_console_sink<std::mutex>;
