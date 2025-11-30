#include <gtest/gtest.h>

#include <fstream>
#include <filesystem>

#include "systems/sound/sound_system.hpp"
#include "util/error_handling.hpp"

// Minimal harness to ensure guarded loading returns/handles errors gracefully.
TEST(SoundSystem, LoadFromJSONSkipsMissingSoundFiles) {
    // Build a tiny sound_data object in JSON form (points to a missing wav file)
    const char* jsonText = R"({
        "music_volume": 0.5,
        "categories": {
            "ui": {
                "sounds": { "click": "missing_click.wav" },
                "volume": 0.8
            }
        }
    })";

    // Write to a temp file
    const std::filesystem::path tmpPath = std::filesystem::temp_directory_path() / "test_missing_sound.json";
    {
        std::ofstream out(tmpPath);
        ASSERT_TRUE(out.good());
        out << jsonText;
    }

    // Ensure missing sound file does not throw; logging should happen inside.
    ASSERT_NO_THROW({ sound_system::LoadFromJSON(tmpPath.string()); });
}

// Fail-fast on invalid JSON
TEST(SoundSystem, LoadFromJSONThrowsOnInvalidJson) {
    const auto tmpPath = std::filesystem::temp_directory_path() / "test_invalid_sound.json";
    {
        std::ofstream out(tmpPath);
        out << "{ this is not json ";
    }
    EXPECT_THROW(sound_system::LoadFromJSON(tmpPath.string()), std::exception);
}

// Fail-fast when required keys are missing
TEST(SoundSystem, LoadFromJSONThrowsWhenMusicVolumeMissing) {
    const char* jsonText = R"({
        "categories": { }
    })";
    const auto tmpPath = std::filesystem::temp_directory_path() / "test_missing_music_volume.json";
    {
        std::ofstream out(tmpPath);
        out << jsonText;
    }
    EXPECT_THROW(sound_system::LoadFromJSON(tmpPath.string()), std::exception);
}

TEST(SoundSystem, LoadFromJSONThrowsWhenCategoriesMissing) {
    const char* jsonText = R"({
        "music_volume": 0.3
    })";
    const auto tmpPath = std::filesystem::temp_directory_path() / "test_missing_categories.json";
    {
        std::ofstream out(tmpPath);
        out << jsonText;
    }
    EXPECT_THROW(sound_system::LoadFromJSON(tmpPath.string()), std::exception);
}

TEST(SoundSystem, LoadFromJSONThrowsWhenMusicVolumeTypeInvalid) {
    const char* jsonText = R"({
        "music_volume": "loud",
        "categories": { "ui": { "sounds": {} } }
    })";
    const auto tmpPath = std::filesystem::temp_directory_path() / "test_music_volume_type_invalid.json";
    {
        std::ofstream out(tmpPath);
        out << jsonText;
    }
    EXPECT_THROW(sound_system::LoadFromJSON(tmpPath.string()), std::exception);
}

TEST(SoundSystem, LoadFromJSONThrowsWhenSoundPathTypeInvalid) {
    const char* jsonText = R"({
        "music_volume": 0.3,
        "categories": {
            "ui": {
                "sounds": { "click": 123 }
            }
        }
    })";
    const auto tmpPath = std::filesystem::temp_directory_path() / "test_sound_path_type_invalid.json";
    {
        std::ofstream out(tmpPath);
        out << jsonText;
    }
    EXPECT_THROW(sound_system::LoadFromJSON(tmpPath.string()), std::exception);
}

TEST(SoundSystem, ResetSoundSystemIsIdempotent) {
    // Should be safe to call repeatedly even when nothing is loaded.
    ASSERT_NO_THROW(sound_system::ResetSoundSystem());
    ASSERT_NO_THROW(sound_system::ResetSoundSystem());
}
