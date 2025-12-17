#include "csys_console_sink.hpp"
#include <spdlog/details/log_msg.h>  // For spdlog::details::log_msg
#include <fmt/core.h>  // For fmt::to_string
#include <cctype>  // For std::isalnum

#include "core/gui.hpp"
#include "imgui_console.h"

// Implementation of the constructor
template <typename Mutex>
csys_console_sink<Mutex>::csys_console_sink(csys::System& console) : console_system(console) {}

// Implementation of the sink_it_ function
template <typename Mutex>
void csys_console_sink<Mutex>::sink_it_(const spdlog::details::log_msg& msg)
{
    // Skip all processing if console is hidden - zero performance impact
    if (!gui::showConsole) {
        return;
    }

    // Convert log message to a string
    spdlog::memory_buf_t formatted;
    this->formatter_->format(msg, formatted);

    // Log the message to spdlog's default output (console/file)
    std::string log_message = fmt::to_string(formatted);

    // Extract tag if present: "[tag] message" format
    // Tags must be valid identifiers (letters, numbers, underscores) and not look like timestamps
    std::string tag = "general";
    if (log_message.size() > 2 && log_message[0] == '[') {
        auto close_bracket = log_message.find(']');
        if (close_bracket != std::string::npos && close_bracket > 1) {
            std::string potential_tag = log_message.substr(1, close_bracket - 1);

            // Validate tag: must be alphanumeric + underscore only, no colons (timestamps have colons)
            bool valid_tag = !potential_tag.empty() && potential_tag.size() <= 20;
            for (char c : potential_tag) {
                if (!std::isalnum(c) && c != '_') {
                    valid_tag = false;
                    break;
                }
            }

            if (valid_tag) {
                tag = potential_tag;
                // Skip "] " after the tag (2 characters)
                if (close_bracket + 2 < log_message.size()) {
                    log_message = log_message.substr(close_bracket + 2);
                } else {
                    log_message = log_message.substr(close_bracket + 1);
                }
            }
        }
    }

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

    // Use the csys system to log the message with tag
    console_system.Log(log_type, tag) << log_message << csys::endl;

    // Note: Don't force scroll here - let the console's auto-scroll handle it
    // PushScrollToBottom was causing scrolling issues when user wanted to scroll manually
}

// Implementation of flush_ (empty implementation)
template <typename Mutex>
void csys_console_sink<Mutex>::flush_() {}

// Explicit instantiation for std::mutex
template class csys_console_sink<std::mutex>;
