#include "fade_system.hpp"

#include "../../util/common_headers.hpp"
#include "../../util/utilities.hpp"


namespace fade_system {

    Color fadeColor = BLACK;
    float fadeAlpha = 0.0f;
    float fadeSpeed = 0.02f; // per second, 
    FadeState fadeState = FadeState::FADE_NONE;

    auto update(const float dt) -> void {
        if (fadeState == FadeState::FADE_NONE) return;

        if (fadeState == FadeState::FADE_IN) {
            fadeAlpha -= fadeSpeed * dt;
            if (fadeAlpha <= 0.0f) {
                fadeAlpha = 0.0f;
                fadeState = FadeState::FADE_NONE;
            }
        }
        else if (fadeState == FadeState::FADE_OUT) {
            fadeAlpha += fadeSpeed * dt;
            if (fadeAlpha >= 1.0f) {
                fadeAlpha = 1.0f;
                fadeState = FadeState::FADE_NONE;
            }
        }
    }

    /**
     * @brief Draws a rectangle that fades in or out over the entire screen.
     */
    auto draw() -> void {
        if (fadeAlpha <= 0.0f) return;

        DrawRectangle(0, 0, GetScreenWidth(), GetScreenHeight(), Fade(fadeColor, fadeAlpha));
    }

    auto setFade(FadeState state, float seconds) -> void {
        fadeState = state;
        fadeSpeed = (state == FadeState::FADE_IN) ? (1.0f / seconds) : (1.0f / seconds);
        fadeAlpha = (state == FadeState::FADE_IN) ? 1.0f : 0.0f;
    }
}
