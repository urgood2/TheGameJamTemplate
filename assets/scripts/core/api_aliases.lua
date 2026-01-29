if _G.__API_ALIASES__ then
    return _G.__API_ALIASES__
end

local aliases = {}

local function install_alias(snake_name, original_name)
    local original = _G[original_name]
    if original then
        _G[snake_name] = original
        aliases[snake_name] = original_name
    end
end

install_alias("get_entity_by_alias", "getEntityByAlias")
install_alias("set_entity_alias", "setEntityAlias")

install_alias("play_sound_effect", "playSoundEffect")
install_alias("play_music", "playMusic")
install_alias("play_playlist", "playPlaylist")
install_alias("stop_all_music", "stopAllMusic")
install_alias("clear_playlist", "clearPlaylist")
install_alias("reset_sound_system", "resetSoundSystem")
install_alias("set_sound_pitch", "setSoundPitch")
install_alias("toggle_low_pass_filter", "toggleLowPassFilter")
install_alias("toggle_delay_effect", "toggleDelayEffect")
install_alias("set_low_pass_target", "setLowPassTarget")
install_alias("set_low_pass_speed", "setLowPassSpeed")

install_alias("pause_game", "pauseGame")
install_alias("unpause_game", "unpauseGame")
install_alias("is_key_pressed", "isKeyPressed")

install_alias("propagate_state_effects_to_ui_box", "propagateStateEffectsToUIBox")

function aliases.get_installed()
    local result = {}
    for snake, original in pairs(aliases) do
        result[snake] = original
    end
    return result
end

_G.__API_ALIASES__ = aliases
return aliases
