#include "layer_optimized.hpp"

namespace layer
{
    std::unordered_map<DrawCommandType, RenderFunc> dispatcher{};
}