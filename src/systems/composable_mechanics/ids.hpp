#pragma once
#include <cstdint>
#include <string_view>

// Simple 32-bit string ID (FNV-1a). Use in content registries.
using Sid = uint32_t;

static inline constexpr Sid fnv1a_32(const char* s, size_t n) {
    Sid hash = 0x811C9DC5u;
    for (size_t i = 0; i < n; ++i) {
        hash ^= static_cast<uint8_t>(s[i]);
        hash *= 0x01000193u;
    }
    return hash;
}

static inline Sid ToSid(std::string_view sv) {
    return fnv1a_32(sv.data(), sv.size());
}