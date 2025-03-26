#include "sound_system.hpp"
#include "nlohmann/json.hpp"

#include "../../util/utilities.hpp"

#include "sol/sol.hpp"

#include <fstream>
#include <iostream>
#include <queue>
#include <map>
#include <vector>

using json = nlohmann::json;

namespace sound_system {
    std::unordered_map<std::string, SoundCategory> categories;
    Music currentMusic;
    std::map<std::string, std::string> musicFiles;
    std::queue<std::pair<std::string, bool>> musicQueue;
    float globalVolume = 1.0f;
    bool isMusicLooping = false;

    bool isFading = false;
    bool isPausingSmooth = false;
    float fadeTime = 0.0f;
    float fadeDuration = 0.0f;
    float musicVolume = 1.0f;
    float pauseTargetVolume = 0.0f;

    SoundCallback musicCompletionCallback = nullptr;
    std::map<std::string, SoundCallback> soundCallbacks;

    enum FadeState { None, FadeIn, FadeOut };
    FadeState fadeState = None;

    void ExposeToLua(sol::state &lua) {

        lua.set_function("playSoundEffect", &PlaySoundEffectSimple);
        lua.set_function("playMusic", &PlayMusic);
        //TODO: probably need easier nnmes for music tracks in json
        //TODO: the following have not been tested 
        lua.set_function("queueMusic", &QueueMusic);
        lua.set_function("fadeInMusic", &FadeInMusic);
        lua.set_function("fadeOutMusic", &FadeOutMusic);
        lua.set_function("pauseMusic", &PauseMusic);
        lua.set_function("resumeMusic", &ResumeMusic);
        lua.set_function("setVolume", &SetVolume);
        lua.set_function("setMusicVolume", &SetMusicVolume);
        lua.set_function("setCategoryVolume", &SetCategoryVolume);
        lua.set_function("setSoundPitch", &SetSoundPitch);
        
    }

    void LoadFromJSON(const std::string& filepath) {
        std::ifstream file;
        nlohmann::json soundData;
        file.open(filepath);
        soundData = json::parse(file);
        file.close();

        musicVolume = soundData["music_volume"].get<float>();
        SPDLOG_DEBUG("Got initial music volume: {}", musicVolume);

        for (const auto& category : soundData.at("categories").items()) {
            std::string categoryName = category.key();
            categories[categoryName] = SoundCategory();
            SPDLOG_DEBUG("[SOUND] Loading category: {}", categoryName);

            if (category.value().contains("sounds") && category.value()["sounds"].is_object()) {
                for (const auto& sound : category.value()["sounds"].items()) {
                    std::string soundName = sound.key();
                    std::string filePath = sound.value().get<std::string>();
                    filePath = util::getAssetPathUUIDVersion(filePath);
                    categories[categoryName].sounds[soundName] = LoadSound(filePath.c_str());
                    SPDLOG_DEBUG("[SOUND] Loaded sound: {} from {}", soundName, filePath);
                }
            }

            else if (category.value().contains("volume")) {
                categories[categoryName].volume = category.value()["volume"].get<float>();
                SPDLOG_DEBUG("[SOUND] Set volume for category {}: {}", categoryName, categories[categoryName].volume);
            }

            else if (category.value().contains("music") && category.value()["music"].is_object()) {

            }
        }

        // operate through array
        
        // Process the music section
        if (soundData.contains("music")) {
            for (const auto& music : soundData.at("music").items()) {
                std::string musicName = music.key();
                std::string musicPath = music.value().get<std::string>();
                musicFiles[musicName] = util::getAssetPathUUIDVersion(musicPath);
                SPDLOG_DEBUG("[SOUND] Loaded music {} with file name: {}", musicName, musicPath);
            }
        }


        if (musicFiles.empty()) {
            SPDLOG_WARN("[SOUND] No music files loaded");
        }
        else {
            currentMusic = LoadMusicStream(musicFiles.begin()->second.c_str()); // just load first track for now
        }
    }

    void PlaySoundEffect(const std::string& category, const std::string& soundName, float pitch, SoundCallback callback) {
        if (categories.find(category) != categories.end() && categories[category].sounds.find(soundName) != categories[category].sounds.end()) {
            Sound& sound = categories[category].sounds[soundName];
            SetSoundVolume(sound, globalVolume * categories[category].volume);
            SetSoundPitch(sound, pitch);
            PlaySound(sound);

            // Register callback if provided
            if (callback) {
                soundCallbacks[soundName] = callback;
            }
        }
    }

    void PlaySoundEffectNoCallBack(const std::string& category, const std::string& soundName, float pitch) {
        PlaySoundEffect(category, soundName, pitch, SoundCallback());
    }

    void PlaySoundEffectSimple(const std::string& category, const std::string& soundName) {
        PlaySoundEffect(category, soundName, 1.0f, SoundCallback());
    }

    void PlayMusic(const std::string& musicName, bool loop) {
        StopMusicStream(currentMusic);
        currentMusic = LoadMusicStream(musicFiles[musicName].c_str());
        isMusicLooping = loop;
        SetMusicVolume(currentMusic, musicVolume);

        PlayMusicStream(currentMusic);
    }

    void QueueMusic(const std::string& musicName, bool loop) {
        musicQueue.push({ musicName, loop });
    }

    void FadeInMusic(const std::string& musicName, float duration) {
        StopMusicStream(currentMusic);
        currentMusic = LoadMusicStream(musicName.c_str());
        fadeState = FadeIn;
        fadeDuration = duration;
        fadeTime = 0.0f;
        isFading = true;
        SetMusicVolume(currentMusic, 0.0f);
        PlayMusicStream(currentMusic);
    }

    void FadeOutMusic(float duration) {
        fadeState = FadeOut;
        fadeDuration = duration;
        fadeTime = 0.0f;
        isFading = true;
    }

    void PauseMusic(bool smooth, float fadeDuration) {
        if (smooth) {
            isPausingSmooth = true;
            FadeOutMusic(fadeDuration);
        } else {
            PauseMusicStream(currentMusic);
        }
    }

    void ResumeMusic(bool smooth, float fadeDuration) {
        if (smooth) {
            isPausingSmooth = false;
            FadeInMusic("", fadeDuration);
        } else {
            ResumeMusicStream(currentMusic);
        }
    }

    void SetVolume(float volume) {
        globalVolume = volume;
        SetMusicVolume(currentMusic, volume);
    }

    void SetMusicVolume(float volume) {
        musicVolume = volume;
        SetMusicVolume(currentMusic, volume);
    }

    void SetCategoryVolume(const std::string& category, float volume) {
        if (categories.find(category) != categories.end()) {
            categories[category].volume = volume;
        }
    }

    void SetSoundPitch(const std::string& category, const std::string& soundName, float pitch) {
        if (categories.find(category) != categories.end() && categories[category].sounds.find(soundName) != categories[category].sounds.end()) {
            SetSoundPitch(categories[category].sounds[soundName], pitch);
        }
    }

    void Update() {

        //TODO: debug this stuff, music not playing
        UpdateMusicStream(currentMusic);

        // Check for music completion and callback
        if (IsMusicStreamPlaying(currentMusic) == false && musicQueue.empty() == false) {
            auto nextTrack = musicQueue.front();
            musicQueue.pop();
            PlayMusic(nextTrack.first, nextTrack.second);
        }

        UpdateFading();
    }

    void UpdateFading() {
        if (!isFading) return;

        fadeTime += GetFrameTime();
        float progress = fadeTime / fadeDuration;

        float volumeToUse = (globalVolume != musicVolume) ? musicVolume : globalVolume;

        if (fadeState == FadeIn) {
            SetMusicVolume(currentMusic, progress * volumeToUse);
            if (progress >= 1.0f) {
                isFading = false;
            }
        } else if (fadeState == FadeOut) {
            SetMusicVolume(currentMusic, (1.0f - progress) * volumeToUse);
            if (progress >= 1.0f) {
                if (isPausingSmooth) {
                    PauseMusicStream(currentMusic);
                } else {
                    StopMusicStream(currentMusic);
                }
                isFading = false;
            }
        }
    }

    void RegisterMusicCallback(SoundCallback callback) {
        musicCompletionCallback = callback;
    }

    void RegisterSoundCallback(const std::string& soundName, SoundCallback callback) {
        soundCallbacks[soundName] = callback;
    }

    void Unload() {
        for (auto& [categoryName, category] : categories) {
            for (auto& [soundName, sound] : category.sounds) {
                UnloadSound(sound);
            }
        }
        UnloadMusicStream(currentMusic);
    }
}
