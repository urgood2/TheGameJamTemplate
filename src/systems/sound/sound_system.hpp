#pragma once
#include "raylib.h"
#include <string>
#include <unordered_map>
#include <vector>
#include <functional>

#include "sol/sol.hpp"

namespace sound_system {

    struct SoundCategory {
        std::unordered_map<std::string, Sound> sounds;
        float volume = 1.0f;
    };

    // Callback type for sound completion
    using SoundCallback = std::function<void()>;

    void LoadFromJSON(const std::string& filepath);

    // Play a sound effect with optional pitch and completion callback
    void PlaySoundEffect(const std::string& category, const std::string& soundName, float pitch = 1.0f, SoundCallback callback = nullptr);
    void PlaySoundEffectNoCallBack(const std::string& category, const std::string& soundName, float pitch);
    void PlaySoundEffectSimple(const std::string& category, const std::string& soundName);

    // Play and queue music with optional looping
    void PlayMusic(const std::string& musicName, bool loop = false);
    void QueueMusic(const std::string& musicName, bool loop = false);
    
    // Fading and pausing
    void FadeInMusic(const std::string& musicName, float duration);
    void FadeOutMusic(float duration);
    void PauseMusic(bool smooth = false, float fadeDuration = 0.0f);
    void ResumeMusic(bool smooth = false, float fadeDuration = 0.0f);
    void UpdateFading();

    // Set global and category-specific volumes
    void SetVolume(float volume);
    void SetMusicVolume(float volume);
    void SetCategoryVolume(const std::string& category, float volume);
    void SetSoundPitch(const std::string& category, const std::string& soundName, float pitch);

    // Expose scripting functions
    void ExposeToLua(sol::state &lua);

    // Update function to be called in game loop
    void Update();

    // Clean up resources
    void Unload();

}
