#version 300 es
precision mediump float;


// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Settings
uniform bool snes_transparency;
uniform bool gba_transparency;
uniform bool horizontal_scan_line;
uniform bool vertical_scan_line;
uniform bool enable_palette_cycling;

// Sprite scroll
uniform vec2 sprite_scroll_direction;
uniform float sprite_scroll_speed;

// GBA transparency
uniform vec2 gba_transparency_scroll_direction;
uniform float gba_transparency_scroll_speed;
uniform float gba_transparency_value;

// Horizontal wave
uniform float horizontal_wave_amplitude;
uniform float horizontal_wave_frequency;
uniform float horizontal_wave_speed;

// Vertical wave
uniform float vertical_wave_amplitude;
uniform float vertical_wave_frequency;
uniform float vertical_wave_speed;

// Horizontal deform
uniform float horizontal_deform_amplitude;
uniform float horizontal_deform_frequency;
uniform float horizontal_deform_speed;

// Vertical deform
uniform float vertical_deform_amplitude;
uniform float vertical_deform_frequency;
uniform float vertical_deform_speed;

// Size
uniform float width;
uniform float height;

// Palette cycling
uniform float palette_cycling_speed;
uniform sampler2D palette;

// Time
uniform float time;

// Output fragment color
out vec4 finalColor;

float calculate_diff(float uv, float amp, float freq, float spd) {
    float diff_x = amp * sin((freq * uv) + (time * spd));
    return diff_x;
}

vec2 calculate_move(vec2 dir, float spd) {
    vec2 move = dir * time * sprite_scroll_speed;
    return move;
}

void main()
{
    float def_x = calculate_diff(fragTexCoord.x, horizontal_deform_amplitude, horizontal_deform_frequency, horizontal_deform_speed);
    float def_y = calculate_diff(fragTexCoord.y, vertical_deform_amplitude, vertical_deform_frequency, vertical_deform_speed);
    float wav_x = calculate_diff(fragTexCoord.y, horizontal_wave_amplitude, horizontal_wave_frequency, horizontal_wave_speed);
    float wav_y = calculate_diff(fragTexCoord.x, vertical_wave_amplitude, vertical_wave_frequency, vertical_wave_speed);

    vec2 move = calculate_move(sprite_scroll_direction, sprite_scroll_speed);

    if (int(fragTexCoord.y * height) % 2 == 0 && snes_transparency) {
        wav_x = -wav_x;
    }

    vec4 textube = texture(texture0, vec2(fragTexCoord.x + def_x + wav_x, fragTexCoord.y + def_y + wav_y) + move);

    if (gba_transparency) {
        float copy_wav_x = -calculate_diff(fragTexCoord.y, horizontal_wave_amplitude, horizontal_wave_frequency, horizontal_wave_speed);
        vec4 tex_copy;

        if (int(fragTexCoord.y * height) % 2 == 1 && snes_transparency) {
            copy_wav_x = -copy_wav_x;
        }

        if (gba_transparency_scroll_direction != vec2(0.0)) {
            vec2 copy_move = calculate_move(gba_transparency_scroll_direction, gba_transparency_scroll_speed);
            tex_copy = texture(texture0, vec2(fragTexCoord.x + def_x + copy_wav_x, fragTexCoord.y + def_y + wav_y) + copy_move);
        } else {
            tex_copy = texture(texture0, vec2(fragTexCoord.x + def_x + copy_wav_x, fragTexCoord.y + def_y + wav_y) + move);
        }

        textube = mix(textube, tex_copy, gba_transparency_value);
    }

    float palette_swap = mod(textube.r - time * palette_cycling_speed, 1.0);

    if (enable_palette_cycling) {
        textube = vec4(texture(palette, vec2(palette_swap, 0)).rgb, textube.a);
    }

    finalColor = textube;

    if (horizontal_scan_line) finalColor = mix(vec4(0.0, 0.0, 0.0, 1.0), finalColor, float(int(fragTexCoord.y * height) % 2));
    if (vertical_scan_line) finalColor = mix(vec4(0.0, 0.0, 0.0, 1.0), finalColor, float(int(fragTexCoord.x * width) % 2));

    finalColor *= colDiffuse * fragColor;
}
