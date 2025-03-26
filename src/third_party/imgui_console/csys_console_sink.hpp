#ifndef CSYS_CONSOLE_SINK_HPP
#define CSYS_CONSOLE_SINK_HPP

#include <spdlog/sinks/base_sink.h>
#include "csys/csys.h"  // Assuming csys is your custom console system
#include <mutex>

// Forward declare the csys::System class to avoid including unnecessary headers
namespace csys {
    class System;
}

// Custom sink for spdlog that also logs to the csys console
template <typename Mutex>
class csys_console_sink : public spdlog::sinks::base_sink<Mutex>
{
public:
    explicit csys_console_sink(csys::System& console);

protected:
    // The log message handling function
    void sink_it_(const spdlog::details::log_msg& msg) override;

    // Flush the logs (not needed for csys, but required for the interface)
    void flush_() override;

private:
    csys::System& console_system;  // Reference to the csys console system
};

// Explicit template instantiation (for std::mutex or other specific types)
extern template class csys_console_sink<std::mutex>;

#endif // CSYS_CONSOLE_SINK_HPP
