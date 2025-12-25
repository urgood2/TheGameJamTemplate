#pragma once

#include <stdexcept>
#include <string>
#include <sstream>

namespace layer {

/**
 * @brief Exception thrown when render stack operations fail.
 *
 * Provides detailed context about the failure including stack depth
 * and optional operation context for debugging.
 */
class RenderStackError : public std::runtime_error {
public:
    RenderStackError(int depth, const std::string& reason,
                     const std::string& context = "")
        : std::runtime_error(formatMessage(depth, reason, context))
        , depth_(depth)
        , reason_(reason)
        , context_(context) {}

    [[nodiscard]] int depth() const noexcept { return depth_; }
    [[nodiscard]] const std::string& reason() const noexcept { return reason_; }
    [[nodiscard]] const std::string& context() const noexcept { return context_; }

private:
    static std::string formatMessage(int depth, const std::string& reason,
                                     const std::string& context) {
        std::ostringstream oss;
        oss << "RenderStack error at depth " << depth << ": " << reason;
        if (!context.empty()) {
            oss << " (" << context << ")";
        }
        return oss.str();
    }

    int depth_;
    std::string reason_;
    std::string context_;
};

} // namespace layer
