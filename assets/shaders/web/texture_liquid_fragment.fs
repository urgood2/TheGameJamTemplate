#version 300 es
precision mediump float;

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float time;

// Custom uniforms
uniform vec4 water_color_1;
uniform vec4 water_color_2;
uniform float water_level_percentage;
uniform float wave_frequency_1;
uniform float wave_amplitude_1;
uniform float wave_frequency_2;
uniform float wave_amplitude_2;

// Output fragment color
out vec4 finalColor;

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float smooth_noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(rand(i), rand(i + vec2(1.0, 0.0)), u.x),
        mix(rand(i + vec2(0.0, 1.0)), rand(i + vec2(1.0, 1.0)), u.x),
        u.y
    );
}

float calculate_wave_offset(float frequency, float amplitude, float time_multiplier, vec2 uv) {
    return sin(uv.x * frequency + time * time_multiplier) * amplitude;
}

vec4 blend_water_color(vec4 base_color, vec4 water_color, float mask) {
    return mix(base_color, water_color, water_color.a * mask);
}

void main()
{
    vec2 uv = fragTexCoord;
    vec4 tex_color = texture(texture0, uv);
    float mask = tex_color.a;

    float wave_offset_1 = calculate_wave_offset(wave_frequency_1, wave_amplitude_1, 2.0, uv);
    float wave_offset_2 = calculate_wave_offset(wave_frequency_2, wave_amplitude_2, 3.0, uv);

    float water_level_1 = 1.0 - water_level_percentage + wave_offset_1;
    float water_level_2 = 1.0 - water_level_percentage + wave_offset_2;

    bool is_below_water_1 = uv.y >= water_level_1;
    bool is_below_water_2 = uv.y >= water_level_2;

    vec2 noise_uv = uv * 10.0 + vec2(time * 0.5, 0.0);
    float noise = smooth_noise(noise_uv);
    float noise_offset = noise * 0.05;

    vec4 final_color = tex_color;

    if (is_below_water_1 && mask > 0.0) {
        final_color = blend_water_color(final_color, water_color_1, mask);
    }

    if (is_below_water_2 && mask > 0.0) {
        final_color = blend_water_color(final_color, water_color_2, mask);
    }

    finalColor = final_color * colDiffuse * fragColor;
}
