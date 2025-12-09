#version 300 es
precision mediump float;


in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Sprite atlas uniforms
uniform vec4 uGridRect;
uniform vec2 uImageSize;

// Effect uniforms
uniform vec4 water_color_1;
uniform vec4 water_color_2;
uniform float water_level_percentage;
uniform float wave_frequency_1;
uniform float wave_amplitude_1;
uniform float wave_frequency_2;
uniform float wave_amplitude_2;
uniform float iTime;

out vec4 finalColor;

// Simple noise function to generate random values
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// Smooth noise function to create more natural noise
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

// Encapsulates wave calculation logic
float calculate_wave_offset(float frequency, float amplitude, float time_multiplier, vec2 uv) {
    return sin(uv.x * frequency + iTime * time_multiplier) * amplitude;
}

// Encapsulates color blending logic
vec4 blend_water_color(vec4 base_color, vec4 water_color, float mask) {
    return mix(base_color, water_color, water_color.a * mask);
}

void main() {
    vec2 uv = fragTexCoord;
    // Get texture color
    vec4 tex_color = texture(texture0, uv);
    // Use texture alpha as mask
    float mask = tex_color.a;

    // Calculate first wave offset
    float wave_offset_1 = calculate_wave_offset(wave_frequency_1, wave_amplitude_1, 2.0, uv);
    // Calculate second wave offset
    float wave_offset_2 = calculate_wave_offset(wave_frequency_2, wave_amplitude_2, 3.0, uv);

    // Adjusted water level for first wave
    float water_level_1 = 1.0 - water_level_percentage + wave_offset_1;
    // Adjusted water level for second wave
    float water_level_2 = 1.0 - water_level_percentage + wave_offset_2;

    // Determine if below first wave water level
    bool is_below_water_1 = uv.y >= water_level_1;
    // Determine if below second wave water level
    bool is_below_water_2 = uv.y >= water_level_2;

    // Add noise and animation to simulate water flow
    vec2 noise_uv = uv * 10.0 + vec2(iTime * 0.5, 0.0);
    float noise = smooth_noise(noise_uv);
    float noise_offset = noise * 0.05;
    vec2 noisy_uv = uv + vec2(noise_offset);

    vec4 final_color = tex_color;

    if (is_below_water_1 && mask > 0.0) {
        final_color = blend_water_color(final_color, water_color_1, mask);
    }

    if (is_below_water_2 && mask > 0.0) {
        final_color = blend_water_color(final_color, water_color_2, mask);
    }

    finalColor = final_color * colDiffuse * fragColor;
}
