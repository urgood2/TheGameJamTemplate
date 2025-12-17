// Minimal stubs for object_pool's aligned memory functions
// These are needed because object_pool.cpp has Catch2 tests that conflict with GoogleTest

#include <cstdlib>
#include <cstddef>

namespace detail
{

void* aligned_malloc(size_t size, size_t align)
{
#if defined(_WIN32)
    return _aligned_malloc(size, align);
#else
    void* ptr;
    int result = posix_memalign(&ptr, align, size);
    return result == 0 ? ptr : nullptr;
#endif
}

void aligned_free(void* ptr)
{
#if defined(_WIN32)
    _aligned_free(ptr);
#else
    std::free(ptr);
#endif
}

} // namespace detail
