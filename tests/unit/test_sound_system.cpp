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
