#pragma once

#include "../../util/common_headers.hpp"

namespace fade_system {

    enum FadeState {
        FADE_NONE,
        FADE_IN,
        FADE_OUT
    };

    extern Color fadeColor;
    extern float fadeAlpha;
    extern float fadeSpeed;

    auto update(const float dt) -> void;
    auto draw() -> void;
    auto setFade(FadeState state, float seconds) -> void;
}