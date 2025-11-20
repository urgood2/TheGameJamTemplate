#include "sound_system.hpp"
#include "nlohmann/json.hpp"

#include "../../util/utilities.hpp"

#include "sol/sol.hpp"

#include <fstream>
#include <iostream>
#include <queue>
#include <map>
#include <vector>

#include "systems/scripting/binding_recorder.hpp"


using json = nlohmann::json;

namespace sound_system {
    std::unordered_map<std::string, SoundCategory> categories;
    
    std::vector<MusicEntry> activeMusic;
    std::queue<std::pair<std::string,bool>> musicQueue; // legacy queue for “next” tracks
    
    std::vector<std::pair<std::string, bool>> playlist;
    size_t currentIndex = 0;
    bool loopPlaylist = false;

    std::map<std::string, std::string> musicFiles;
    float globalVolume = 1.0f; // global volume (0.0–1.0)
    float musicVolume  = 1.0f;  // global music volume (0.0–1.0)
    bool isMusicLooping = false;

    bool isFading = false;
    bool isPausingSmooth = false;
    float fadeTime = 0.0f;
    float fadeDuration = 0.0f;
    float pauseTargetVolume = 0.0f;

    SoundCallback musicCompletionCallback = nullptr;
    std::map<std::string, SoundCallback> soundCallbacks;

    FadeState fadeState = None;
    
    
    static bool enableLowPassFilter = false;
    static float lowpassL[2] = { 0.0f, 0.0f };
    static const float cutoff = 70.0f / 44100.0f; // 70Hz
    static const float k = cutoff / (cutoff + 0.1591549431f);

    static float* delayBuffer = nullptr;
    static unsigned int delayBufferSize = 0;
    static unsigned int delayReadIndex = 2;
    static unsigned int delayWriteIndex = 0;
    static bool enableDelayEffect = false;
    
    // --- Low-pass filter state ---
    static float lpfStrength = 0.0f;       // 0.0 = off, 1.0 = full
    static float lpfTarget = 0.0f;         // target strength for smooth approach
    static float lpfApproachSpeed = 1.5f;  // how quickly it approaches (Hz per second)
    static float lowpassMemory[2] = { 0.0f, 0.0f };

    static void AudioProcessEffectLPF(void* buffer, unsigned int frames)
    {
        float* buf = (float*)buffer;
        // Base cutoff range: [70Hz..20000Hz]
        // Convert to normalized [0..1] value (frequency / sampleRate)
        const float minCut = 70.0f / 44100.0f;
        const float maxCut = 20000.0f / 44100.0f;

        // Compute effective cutoff and filter coefficient k
        float cutoff = minCut + (maxCut - minCut) * (1.0f - lpfStrength);
        float k = cutoff / (cutoff + 0.1591549431f);

        for (unsigned int i = 0; i < frames * 2; i += 2)
        {
            float l = buf[i];
            float r = buf[i + 1];

            lowpassMemory[0] += k * (l - lowpassMemory[0]);
            lowpassMemory[1] += k * (r - lowpassMemory[1]);

            buf[i] = lowpassMemory[0];
            buf[i + 1] = lowpassMemory[1];
        }
    }

    static void AudioProcessEffectDelay(void* buffer, unsigned int frames) {
        if (!delayBuffer) return;
        float* buf = (float*)buffer;
        for (unsigned int i = 0; i < frames * 2; i += 2) {
            float lDelay = delayBuffer[delayReadIndex++];
            float rDelay = delayBuffer[delayReadIndex++];
            if (delayReadIndex >= delayBufferSize) delayReadIndex = 0;
            buf[i] = 0.5f * buf[i] + 0.5f * lDelay;
            buf[i + 1] = 0.5f * buf[i + 1] + 0.5f * rDelay;
            delayBuffer[delayWriteIndex++] = buf[i];
            delayBuffer[delayWriteIndex++] = buf[i + 1];
            if (delayWriteIndex >= delayBufferSize) delayWriteIndex = 0;
        }
    }
    
    void InitAudioEffects() {
        if (delayBuffer == nullptr) {
            delayBufferSize = 48000 * 2; // 1 second delay (stereo)
            delayBuffer = (float*)RL_CALLOC(delayBufferSize, sizeof(float));
        }
    }
    
    void ToggleLowPassFilter(bool enabled) {
        enableLowPassFilter = enabled;
        if (!activeMusic.empty()) {
            auto& m = activeMusic.back(); // current track
            if (enabled)
                AttachAudioStreamProcessor(m.stream.stream, AudioProcessEffectLPF);
            else
                DetachAudioStreamProcessor(m.stream.stream, AudioProcessEffectLPF);
        }
    }

    void ToggleDelayEffect(bool enabled) {
        enableDelayEffect = enabled;
        InitAudioEffects();
        if (!activeMusic.empty()) {
            auto& m = activeMusic.back();
            if (enabled)
                AttachAudioStreamProcessor(m.stream.stream, AudioProcessEffectDelay);
            else
                DetachAudioStreamProcessor(m.stream.stream, AudioProcessEffectDelay);
        }
    }

    
    void SetLowPassTarget(float strength) {
        lpfTarget = std::clamp(strength, 0.0f, 1.0f);
        if (!enableLowPassFilter && lpfTarget > 0.0f) {
            enableLowPassFilter = true;
            if (!activeMusic.empty()) {
                auto& m = activeMusic.back();
                AttachAudioStreamProcessor(m.stream.stream, AudioProcessEffectLPF);
            }
        } else if (enableLowPassFilter && lpfTarget <= 0.0f) {
            lpfTarget = 0.0f;
            if (!activeMusic.empty()) {
                auto& m = activeMusic.back();
                DetachAudioStreamProcessor(m.stream.stream, AudioProcessEffectLPF);
            }
            enableLowPassFilter = false;
            lpfStrength = 0.0f;
        }
    }

    void SetLowPassSpeed(float speed) {
        lpfApproachSpeed = std::max(0.01f, speed);
    }

    
    
    void ExposeToLua(sol::state &lua) {

        // BindingRecorder instance
        auto& rec = BindingRecorder::instance();

        lua.set_function("playSoundEffect",
            sol::overload(
                // 2-arg version → no callback, default pitch = 1.0
                [](const std::string& category,
                   const std::string& soundName) {
                    PlaySoundEffectSimple(category, soundName);
                },
                // 3-arg version → specify pitch
                [](const std::string& category,
                   const std::string& soundName,
                   float pitch) {
                    PlaySoundEffectNoCallBack(category, soundName, pitch);
                }
            )
        );
    
        // Now record both signatures in your .lua_defs
        rec.record_free_function({}, {
            "playSoundEffect",
            "---@param category string # The category of the sound.\n"
            "---@param soundName string # The name of the sound effect.\n"
            "---@return nil",
            "Plays a sound effect from the specified category (default pitch = 1.0).",
            true, false
        });
        rec.record_free_function({}, {
            "playSoundEffect",
            "---@param category string # The category of the sound.\n"
            "---@param soundName string # The name of the sound effect.\n"
            "---@param pitch number # Playback pitch multiplier.\n"
            "---@return nil",
            "Plays a sound effect with custom pitch (no Lua callback).",
            true, false
        });
        
        lua.set_function("toggleLowPassFilter", &ToggleLowPassFilter);
        rec.record_free_function({}, {
            "toggleLowPassFilter",
            "---@param enabled boolean # Enables or disables a low-pass filter on the current music.\n"
            "---@return nil",
            "Toggles a low-pass filter for the currently playing music.",
            true, false
        });

        lua.set_function("toggleDelayEffect", &ToggleDelayEffect);
        rec.record_free_function({}, {
            "toggleDelayEffect",
            "---@param enabled boolean # Enables or disables a delay effect on the current music.\n"
            "---@return nil",
            "Toggles a delay effect (echo) for the currently playing music.",
            true, false
        });
        
        lua.set_function("resetSoundSystem", &ResetSoundSystem);
        rec.record_free_function({}, {
            "resetSoundSystem", 
            "---@return nil", 
            "Resets the entire sound system, stopping all sounds and clearing loaded music (not sfx).", 
            true, false
        });
        
        
        lua.set_function("setLowPassTarget", &SetLowPassTarget);
        rec.record_free_function({}, {
            "setLowPassTarget",
            "---@param strength number # Target low-pass intensity (0.0 = off, 1.0 = max muffling)\n"
            "---@return nil",
            "Smoothly transitions the low-pass filter toward the specified intensity.",
            true, false
        });

        lua.set_function("setLowPassSpeed", &SetLowPassSpeed);
        rec.record_free_function({}, {
            "setLowPassSpeed",
            "---@param speed number # How fast the filter transitions per second.\n"
            "---@return nil",
            "Sets the speed at which the low-pass filter transitions between states.",
            true, false
        });

        lua.set_function("playMusic", &PlayMusic);
        rec.record_free_function({}, {
            "playMusic", 
            "---@param musicName string # The name of the music track to play.\n"
            "---@param loop? boolean # If the music should loop. Defaults to false.\n"
            "---@return nil", 
            "Plays a music track.", 
            true, false
        });
        
        // Playlist management
        lua.set_function("playPlaylist",
            [](sol::table luaTracks, bool loop) {
                std::vector<std::string> tracks;

                // Defensive conversion: iterate numerically
                for (std::size_t i = 1;; ++i) {
                    sol::optional<std::string> value = luaTracks[i];
                    if (!value)
                        break;
                    tracks.push_back(*value);
                }

                if (tracks.empty()) {
                    SPDLOG_WARN("[SOUND] playPlaylist called with empty or invalid table");
                    return;
                }

                sound_system::PlayPlaylist(tracks, loop);
            }
        );

        rec.record_free_function({}, {
            "playPlaylist",
            "---@param tracks string[] # Ordered list of music track names to play.\n"
            "---@param loop? boolean # Whether to loop the entire playlist. Defaults to false.\n"
            "---@return nil",
            "Starts playing a playlist of tracks sequentially, with optional looping.",
            true, false
        });


        lua.set_function("clearPlaylist", &ClearPlaylist);
        rec.record_free_function({}, {
            "clearPlaylist",
            "---@return nil",
            "Stops and clears the current playlist (does not unload music assets).",
            true, false
        });

        lua.set_function("stopAllMusic", &StopAllMusic);
        rec.record_free_function({}, {
            "stopAllMusic",
            "---@return nil",
            "Stops and removes all currently playing music tracks immediately.",
            true, false
        });

        //TODO: probably need easier names for music tracks in json
        //TODO: the following have not been tested 
        lua.set_function("queueMusic", &QueueMusic);
        rec.record_free_function({}, {
            "queueMusic", 
            "---@param musicName string # The name of the music track to queue.\n"
            "---@param loop? boolean # If the queued music should loop. Defaults to false.\n"
            "---@return nil", 
            "Adds a music track to the queue to be played next.", 
            true, false
        });
        
        lua.set_function("setTrackVolume", &SetTrackVolume);
        rec.record_free_function({}, {
            "setTrackVolume", 
            "---@param name string # The name of the music track.\n"
            "---@param vol number # The volume level for this track (0.0 to 1.0).\n"
            "---@return nil", 
            "Sets the volume for a specific music track.", 
            true, false
        });
        
        lua.set_function("getTrackVolume", &GetTrackVolume);
        rec.record_free_function({}, {
            "getTrackVolume", 
            "---@param name string # The name of the music track.\n"
            "---@return number # The current volume level for this track (0.0 to 1.0).\n",
            "Gets the volume for a specific music track.", 
            true, false
        });

        lua.set_function("fadeInMusic", &FadeInMusic);
        rec.record_free_function({}, {
            "fadeInMusic", 
            "---@param musicName string # The music track to fade in.\n"
            "---@param duration number # The duration of the fade in seconds.\n"
            "---@return nil", 
            "Fades in and plays a music track over a duration.", 
            true, false
        });

        lua.set_function("fadeOutMusic", &FadeOutMusic);
        rec.record_free_function({}, {
            "fadeOutMusic", 
            "---@param duration number # The duration of the fade in seconds.\n"
            "---@return nil", 
            "Fades out the currently playing music.", 
            true, false
        });

        lua.set_function("pauseMusic", &PauseMusic);
        rec.record_free_function({}, {
            "pauseMusic", 
            "---@param smooth? boolean # Whether to fade out when pausing. Defaults to false.\n"
            "---@param fadeDuration? number # The fade duration if smooth is true. Defaults to 0.\n"
            "---@return nil", 
            "Pauses the current music track.", 
            true, false
        });

        lua.set_function("resumeMusic", &ResumeMusic);
        rec.record_free_function({}, {
            "resumeMusic", 
            "---@param smooth? boolean # Whether to fade in when resuming. Defaults to false.\n"
            "---@param fadeDuration? number # The fade duration if smooth is true. Defaults to 0.\n"
            "---@return nil", 
            "Resumes the paused music track.", 
            true, false
        });

        lua.set_function("setVolume", &SetVolume);
        rec.record_free_function({}, {
            "setVolume", 
            "---@param volume number # The master volume level (0.0 to 1.0).\n"
            "---@return nil", 
            "Sets the master audio volume.", 
            true, false
        });

        lua.set_function("setMusicVolume", &SetMusicVolume);
        rec.record_free_function({}, {
            "setMusicVolume", 
            "---@param volume number # The music volume level (0.0 to 1.0).\n"
            "---@return nil", 
            "Sets the volume for the music category only.", 
            true, false
        });

        lua.set_function("setCategoryVolume", &SetCategoryVolume);
        rec.record_free_function({}, {
            "setCategoryVolume", 
            "---@param category string # The name of the sound category.\n"
            "---@param volume number # The volume for this category (0.0 to 1.0).\n"
            "---@return nil", 
            "Sets the volume for a specific sound effect category.", 
            true, false
        });

        lua.set_function("setSoundPitch", &SetSoundPitch);
        rec.record_free_function({}, {
            "setSoundPitch", 
            "---@param category string # The category of the sound.\n"
            "---@param soundName string # The name of the sound effect.\n"
            "---@param pitch number # The new pitch multiplier (1.0 is default).\n"
            "---@return nil", 
            "Sets the pitch for a specific sound. Note: This may not apply to currently playing instances.", 
            true, false
        });

        // lua.set_function("playSoundEffect", &PlaySoundEffectSimple);
        // lua.set_function("playMusic", &PlayMusic);
        // //TODO: probably need easier nnmes for music tracks in json
        // //TODO: the following have not been tested 
        // lua.set_function("queueMusic", &QueueMusic);
        // lua.set_function("fadeInMusic", &FadeInMusic);
        // lua.set_function("fadeOutMusic", &FadeOutMusic);
        // lua.set_function("pauseMusic", &PauseMusic);
        // lua.set_function("resumeMusic", &ResumeMusic);
        // lua.set_function("setVolume", &SetVolume);
        // lua.set_function("setMusicVolume", &SetMusicVolume);
        // lua.set_function("setCategoryVolume", &SetCategoryVolume);
        // lua.set_function("setSoundPitch", &SetSoundPitch);
        
    }

    void PlayPlaylist(const std::vector<std::string>& names, bool loop) {
    playlist.clear();
    for (auto &n : names) playlist.emplace_back(n, false);
    currentIndex = 0;
    loopPlaylist = loop;
    if (!playlist.empty())
        PlayMusic(playlist.front().first, false);
}

void ClearPlaylist() {
    playlist.clear();
    currentIndex = 0;
    loopPlaylist = false;
}

void StopAllMusic() {
    for (auto &me : activeMusic) {
        StopMusicStream(me.stream);
        UnloadMusicStream(me.stream);
    }
    activeMusic.clear();
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
                    filePath = util::getRawAssetPathNoUUID("sounds/" + filePath);
                    categories[categoryName].sounds[soundName] = LoadSound(filePath.c_str());
                    SPDLOG_DEBUG("[SOUND] Loaded sound: {} from {}", soundName, filePath);
                }
            }

            else if (category.value().contains("volume")) {
                categories[categoryName].volume = category.value()["volume"].get<float>();
                SPDLOG_DEBUG("[SOUND] Set volume for category {}: {}", categoryName, categories[categoryName].volume);
            }
        }

        // operate through array
        
        // Process the music section
        if (soundData.contains("music")) {
            for (const auto& music : soundData.at("music").items()) {
                std::string musicName = music.key();
                std::string musicPath = music.value().get<std::string>();
                musicFiles[musicName] = util::getRawAssetPathNoUUID("sounds/" + musicPath);
                SPDLOG_DEBUG("[SOUND] Loaded music {} with file name: {}", musicName, musicPath);
            }
        }


        if (musicFiles.empty()) {
            SPDLOG_WARN("[SOUND] No music files loaded");
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

    // Play a new music track immediately
    void PlayMusic(const std::string& name, bool loop) {
        Music m = LoadMusicStream(musicFiles.at(name).c_str());
        // apply combined volume: per-track * musicVolume * globalVolume
        SetMusicVolume(m, 1.0f * musicVolume * globalVolume);
        PlayMusicStream(m);

        activeMusic.push_back({
            .name       = name,
            .stream     = m,
            .loop       = loop,
            .volume     = 1.0f,
            .onComplete = musicCompletionCallback
        });
    }

    // Queue up a track if nothing is playing
    void QueueMusic(const std::string& name, bool loop) {
        musicQueue.push({ name, loop });
    }

    // Fade out a named track
    void FadeOutMusic(const std::string& name, float duration) {
        for (auto &me : activeMusic) {
            if (me.name == name) {
                me.fadeState = FadeOut;
                me.fadeDur   = duration;
                me.fadeTime  = 0.f;
            }
        }
    }
    // Set per-track volume (0.0–1.0)
    void SetTrackVolume(const std::string& name, float vol) {
        float v = std::clamp(vol, 0.f, 1.f);
        for (auto &me : activeMusic) {
            if (me.name == name) {
                me.volume = v;
                // if (me.fadeState == None) {
                    SetMusicVolume(me.stream, me.volume * musicVolume * globalVolume);
                // }
                break;
            }
        }
    }

    // Get effective volume of a named track
    float GetTrackVolume(const std::string& name) {
        for (auto &me : activeMusic) {
            if (me.name == name) {
                return me.volume * musicVolume * globalVolume;
            }
        }
        return 0.f;
    }

    // Set the global music volume (affects all tracks)
    void SetMusicVolume(float vol) {
        musicVolume = std::clamp(vol, 0.f, 1.f);
        for (auto &me : activeMusic) {
            if (me.fadeState == None) {
                SetMusicVolume(me.stream, me.volume * musicVolume * globalVolume);
            }
        }
    }

    // Set the master volume (affects all audio including music and sfx)
    void SetglobalVolume(float vol) {
        globalVolume = std::clamp(vol, 0.f, 1.f);
        // update music streams
        for (auto &me : activeMusic) {
            if (me.fadeState == None) {
                SetMusicVolume(me.stream, me.volume * musicVolume * globalVolume);
            }
        }
        // NOTE: also apply to sound effects when playing
    }
    
    // Fade in a new music track over `duration`, pushes into activeMusic list
    auto FadeInMusic (const std::string &musicName, float duration) -> void{
        // Load and start at zero volume
        Music m = LoadMusicStream(musicFiles[musicName].c_str());
        SetMusicVolume(m, 0.0f);
        PlayMusicStream(m);
        // Track this stream in our active list
        activeMusic.push_back({
            .name       = musicName,
            .stream     = m,
            .loop       = false,
            .fadeTime   = 0.0f,
            .fadeDur    = duration,
            .fadeState  = FadeIn,
            .onComplete = musicCompletionCallback
        });
    }

    // Pause all active streams (smooth fade-out or immediate pause)
    void PauseMusic(bool smooth, float fadeDuration) {
        for (auto &me : activeMusic) {
            if (smooth) {
                me.fadeState = FadeOut;
                me.fadeDur   = fadeDuration;
                me.fadeTime  = 0.0f;
            } else {
                PauseMusicStream(me.stream);
            }
        }
    }

    // Resume all paused streams (smooth fade-in or immediate resume)
    void ResumeMusic(bool smooth, float fadeDuration) {
        for (auto &me : activeMusic) {
            if (smooth) {
                // Reset fade parameters and restart stream
                me.fadeState = FadeIn;
                me.fadeDur   = fadeDuration;
                me.fadeTime  = 0.0f;
                PlayMusicStream(me.stream);
                SetMusicVolume(me.stream, 0.0f);
            } else {
                ResumeMusicStream(me.stream);
            }
        }
    }

    // Set global volume and apply to all non-fading streams
    void SetVolume(float volume) {
        globalVolume = volume;
        for (auto &me : activeMusic) {
            if (me.fadeState == None) {
                SetMusicVolume(me.stream, globalVolume * musicVolume);
            }
        }
    }

    // Main update: advance streams, handle fades and completion
    void Update(float dt) {
        static float musicUpdateAccum = 0.0f;
        const float musicUpdateRate = 1.0f / 120.0f; // update 120 Hz no matter what

        musicUpdateAccum += dt;

        // Run UpdateMusicStream() as many times as needed to stay in sync
        while (musicUpdateAccum >= musicUpdateRate) {
            for (auto &me : activeMusic) {
                UpdateMusicStream(me.stream);
            }
            musicUpdateAccum -= musicUpdateRate;
        }

        // ---- Existing fade + logic follows ----
        for (auto it = activeMusic.begin(); it != activeMusic.end();) {
            auto &me = *it;

            // Fading
            if (me.fadeState != None) {
                me.fadeTime += dt;
                float t = std::clamp(me.fadeTime / me.fadeDur, 0.f, 1.f);
                float target = me.volume * musicVolume * globalVolume;
                float vol = std::max(0.f, (me.fadeState == FadeIn ? t : (1.f - t)) * target);
                SetMusicVolume(me.stream, vol);
                if (t >= 1.f) {
                    if (me.fadeState == FadeOut) {
                        SetMusicVolume(me.stream, 0.0f);
                        StopMusicStream(me.stream);
                    }
                    me.fadeState = None;
                }
            }

            // Completion / looping logic ...
            bool playing = IsMusicStreamPlaying(me.stream);
            if (!playing && me.loop && me.fadeState == None) {
                PlayMusicStream(me.stream);
            } else if (!playing && !me.loop && me.fadeState == None) {
                if (me.onComplete) me.onComplete();
                UnloadMusicStream(me.stream);
                it = activeMusic.erase(it);

                if (!playlist.empty()) {
                    currentIndex = (currentIndex + 1) % playlist.size();
                    if (currentIndex == 0 && !loopPlaylist) {
                        playlist.clear(); // stop
                    } else {
                        PlayMusic(playlist[currentIndex].first, false);
                    }
                }
                continue;
            }

            ++it;
        }

        // Legacy queue logic unchanged
        if (activeMusic.empty() && !musicQueue.empty()) {
            auto [nextName, nextLoop] = musicQueue.front();
            musicQueue.pop();
            PlayMusic(nextName, nextLoop);
        }
        
        // --- Low-pass smoothing ---
        if (enableLowPassFilter) {
            float diff = lpfTarget - lpfStrength;
            float step = lpfApproachSpeed * dt;
            if (fabs(diff) <= step) lpfStrength = lpfTarget;
            else lpfStrength += (diff > 0 ? step : -step);
        }

    }
    
    // for resetting game state, rather than unloading completely
    void ResetSoundSystem() {
        // Clear active music streams
        for (auto &me : activeMusic) {
            UnloadMusicStream(me.stream);
        }
        activeMusic.clear();
        // Clear sound callbacks
        soundCallbacks.clear();
        // Clear music queue
        std::queue<std::pair<std::string,bool>> emptyQueue;
        std::swap(musicQueue, emptyQueue);
    }

    // Unload all active streams on shutdown
    void Unload() {
        for (auto &me : activeMusic) {
            UnloadMusicStream(me.stream);
        }
        activeMusic.clear();
        // Existing Sound unloads as before...
        for (auto & [categoryName, cat] : categories) {
            for (auto & [soundName, snd] : cat.sounds) {
                UnloadSound(snd);
            }
        }
        if (delayBuffer) {
            RL_FREE(delayBuffer);
            delayBuffer = nullptr;
        }
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

    void RegisterMusicCallback(SoundCallback callback) {
        musicCompletionCallback = callback;
    }

    void RegisterSoundCallback(const std::string& soundName, SoundCallback callback) {
        soundCallbacks[soundName] = callback;
    }
}
