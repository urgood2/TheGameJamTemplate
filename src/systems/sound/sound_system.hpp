#pragma once

/**
 * @file sound_system.hpp
 * @brief Simple audio facade (Raylib-backed) for SFX/music playback and Lua exposure.
 */

#include "raylib.h"
#include <string>
#include <unordered_map>
#include <vector>
#include <functional>

#include "sol/sol.hpp"

namespace sound_system {

    /// Group of sounds by category with volume scalar.
    struct SoundCategory {
        std::unordered_map<std::string, Sound> sounds;
        float volume = 1.0f;
    };
    
    
    /// Callback type for sound completion
    using SoundCallback = std::function<void()>;
    
    enum FadeState { None, FadeIn, FadeOut };
    
    /// Music playback state (owned Raylib stream).
    struct MusicEntry {
        std::string name;            // unique identifier for this track
        Music       stream;
        bool        loop       = false;
        float       volume     = 1.0f;      // per-track volume (0.0-1.0)
        float       fadeTime   = 0.f;
        float       fadeDur    = 0.f;
        FadeState   fadeState  = None;
        SoundCallback onComplete = nullptr;
        bool lowPassEnabled = false;
        float lowPassGain = 1.0f; // 1.0 = no filter, lower = stronger filter

    };
    
    
    


    /// Load sound + music metadata from JSON (categories, playlists, gains).
    void LoadFromJSON(const std::string& filepath);

    /// Play a sound effect with optional pitch and completion callback.
    void PlaySoundEffect(const std::string& category, const std::string& soundName, float pitch = 1.0f, SoundCallback callback = nullptr);
    void PlaySoundEffectNoCallBack(const std::string& category, const std::string& soundName, float pitch);
    void PlaySoundEffectSimple(const std::string& category, const std::string& soundName);

    /// Play and queue music with optional looping.
    void PlayMusic(const std::string& musicName, bool loop = false);
    void QueueMusic(const std::string& musicName, bool loop = false);
    void SetTrackVolume(const std::string& name, float vol);
    float GetTrackVolume(const std::string& name);
    void ResetSoundSystem();
    void PlayPlaylist(const std::vector<std::string>& names, bool loop) ;

void ClearPlaylist();
void StopAllMusic() ;
    
    /// Fading and pausing controls.
    auto FadeInMusic (const std::string &musicName, float duration) -> void;
    void FadeOutMusic(const std::string& name, float duration);
    void PauseMusic(bool smooth = false, float fadeDuration = 0.0f);
    void ResumeMusic(bool smooth = false, float fadeDuration = 0.0f);

    /// Set global and category-specific volumes/pitch.
    void SetVolume(float volume);
    void SetMusicVolume(float volume);
    void SetCategoryVolume(const std::string& category, float volume);
    void SetSoundPitch(const std::string& category, const std::string& soundName, float pitch);

    /// Bind audio controls to Lua.
    void ExposeToLua(sol::state &lua);

    /// Pump Raylib audio each frame.
    void Update(float dt);

    /// Clean up resources.
    void Unload();

}
