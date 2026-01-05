#pragma once

/**
 * @file string_id.hpp
 * @brief Compile-time string hashing for O(1) comparisons
 * 
 * Inspired by Godot Engine's StringName system. Provides:
 * - Compile-time FNV-1a hashing via constexpr
 * - O(1) equality comparisons (just compare hash values)
 * - Zero runtime allocation for literal strings
 * - Optional debug storage of original string
 * 
 * Usage:
 *   // Compile-time (preferred)
 *   constexpr StringId PLAYER_TAG = "player"_sid;
 *   
 *   // Runtime (when string not known at compile time)
 *   StringId dynamicId = StringId::from(someString);
 *   
 *   // Comparison is O(1)
 *   if (entity.tag == PLAYER_TAG) { ... }
 */

#include <cstdint>
#include <string>
#include <string_view>
#include <functional>

#ifdef NDEBUG
    #define STRINGID_STORE_DEBUG_STRING 0
#else
    #define STRINGID_STORE_DEBUG_STRING 1
#endif

namespace core {

namespace detail {
    constexpr uint64_t FNV_OFFSET_BASIS = 14695981039346656037ULL;
    constexpr uint64_t FNV_PRIME = 1099511628211ULL;
    
    constexpr uint64_t fnv1a_hash(const char* str, size_t len) noexcept {
        uint64_t hash = FNV_OFFSET_BASIS;
        for (size_t i = 0; i < len; ++i) {
            hash ^= static_cast<uint64_t>(str[i]);
            hash *= FNV_PRIME;
        }
        return hash;
    }
    
    constexpr size_t const_strlen(const char* str) noexcept {
        size_t len = 0;
        while (str[len] != '\0') ++len;
        return len;
    }
}

class StringId {
public:
    constexpr StringId() noexcept : hash_(0) {}
    
    constexpr StringId(const char* str) noexcept 
        : hash_(detail::fnv1a_hash(str, detail::const_strlen(str)))
#if STRINGID_STORE_DEBUG_STRING
        , debug_str_(str)
#endif
    {}
    
    constexpr StringId(const char* str, size_t len) noexcept 
        : hash_(detail::fnv1a_hash(str, len))
#if STRINGID_STORE_DEBUG_STRING
        , debug_str_(str)
#endif
    {}
    
    static StringId from(const std::string& str) noexcept {
        StringId id;
        id.hash_ = detail::fnv1a_hash(str.data(), str.size());
        return id;
    }
    
    static StringId from(std::string_view str) noexcept {
        StringId id;
        id.hash_ = detail::fnv1a_hash(str.data(), str.size());
        return id;
    }
    
    [[nodiscard]] constexpr uint64_t hash() const noexcept { return hash_; }
    [[nodiscard]] constexpr bool valid() const noexcept { return hash_ != 0; }
    [[nodiscard]] constexpr explicit operator bool() const noexcept { return valid(); }
    
    [[nodiscard]] constexpr bool operator==(const StringId& other) const noexcept {
        return hash_ == other.hash_;
    }
    [[nodiscard]] constexpr bool operator!=(const StringId& other) const noexcept {
        return hash_ != other.hash_;
    }
    [[nodiscard]] constexpr bool operator<(const StringId& other) const noexcept {
        return hash_ < other.hash_;
    }

#if STRINGID_STORE_DEBUG_STRING
    [[nodiscard]] const char* debug_string() const noexcept { return debug_str_; }
#else
    [[nodiscard]] const char* debug_string() const noexcept { return "<release>"; }
#endif

private:
    uint64_t hash_;
#if STRINGID_STORE_DEBUG_STRING
    const char* debug_str_ = nullptr;
#endif
};

constexpr StringId operator""_sid(const char* str, size_t len) noexcept {
    return StringId(str, len);
}

} // namespace core

template<>
struct std::hash<core::StringId> {
    size_t operator()(const core::StringId& id) const noexcept {
        return static_cast<size_t>(id.hash());
    }
};

// Common pre-defined StringIds
namespace string_ids {
    using namespace core;
    
    inline constexpr StringId PLAYER = "player"_sid;
    inline constexpr StringId ENEMY = "enemy"_sid;
    inline constexpr StringId NPC = "npc"_sid;
    inline constexpr StringId PROJECTILE = "projectile"_sid;
    inline constexpr StringId PICKUP = "pickup"_sid;
    inline constexpr StringId OBSTACLE = "obstacle"_sid;
    inline constexpr StringId TRIGGER = "trigger"_sid;
    
    inline constexpr StringId WORLD = "WORLD"_sid;
    inline constexpr StringId SOLID = "solid"_sid;
    inline constexpr StringId SENSOR = "sensor"_sid;
    
    inline constexpr StringId BACKGROUND = "background"_sid;
    inline constexpr StringId FOREGROUND = "foreground"_sid;
    inline constexpr StringId UI = "ui"_sid;
    inline constexpr StringId DEBUG = "debug"_sid;
    
    inline constexpr StringId IDLE = "idle"_sid;
    inline constexpr StringId MOVING = "moving"_sid;
    inline constexpr StringId ATTACKING = "attacking"_sid;
    inline constexpr StringId DEAD = "dead"_sid;
}
