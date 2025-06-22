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
    
    enum FadeState { None, FadeIn, FadeOut };
    
    struct MusicEntry {
        std::string name;            // unique identifier for this track
        Music       stream;
        bool        loop       = false;
        float       volume     = 1.0f;      // per-track volume (0.0–1.0)
        float       fadeTime   = 0.f;
        float       fadeDur    = 0.f;
        FadeState   fadeState  = None;
        SoundCallback onComplete = nullptr;
    };
    
    
    


    void LoadFromJSON(const std::string& filepath);

    // Play a sound effect with optional pitch and completion callback
    void PlaySoundEffect(const std::string& category, const std::string& soundName, float pitch = 1.0f, SoundCallback callback = nullptr);
    void PlaySoundEffectNoCallBack(const std::string& category, const std::string& soundName, float pitch);
    void PlaySoundEffectSimple(const std::string& category, const std::string& soundName);

    // Play and queue music with optional looping
    void PlayMusic(const std::string& musicName, bool loop = false);
    void QueueMusic(const std::string& musicName, bool loop = false);
    void SetTrackVolume(const std::string& name, float vol);
    float GetTrackVolume(const std::string& name);
    
    // Fading and pausing
    auto FadeInMusic (const std::string &musicName, float duration) -> void;
    void FadeOutMusic(const std::string& name, float duration);
    void PauseMusic(bool smooth = false, float fadeDuration = 0.0f);
    void ResumeMusic(bool smooth = false, float fadeDuration = 0.0f);

    // Set global and category-specific volumes
    void SetVolume(float volume);
    void SetMusicVolume(float volume);
    void SetCategoryVolume(const std::string& category, float volume);
    void SetSoundPitch(const std::string& category, const std::string& soundName, float pitch);

    // Expose scripting functions
    void ExposeToLua(sol::state &lua);

    // Update function to be called in game loop
    void Update(float dt);

    // Clean up resources
    void Unload();

}
