#include "layer_command_buffer.hpp"

namespace layer
{
    namespace CommandBuffer {
        std::vector<std::byte> arena;
        std::vector<DrawCommandV2> commands;
        std::vector<std::function<void()>> destructors;
        bool isSorted = true;
    }
}