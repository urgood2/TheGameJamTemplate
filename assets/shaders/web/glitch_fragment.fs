#version 300 es
precision mediump float;


in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform vec2 resolution;
uniform float iTime;

uniform float shake_power;       // 0.0 – 0.1    (intensity of shake)
uniform float shake_rate;        // 0.0 – 1.0    (probability of shaking)
uniform float shake_speed;       // > 0.0        (frequency of change)
uniform float shake_block_size;  // > 1.0        (vertical block granularity)
uniform float shake_color_rate;  // 0.0 – 0.1    (how far R/B are offset)

out vec4 finalColor;

// Simple pseudo-random function
float random(float seed) {
    return fract(543.2543 * sin(dot(vec2(seed, seed), vec2(3525.46, -54.3415))));
}

void main() {
    float enable_shift = float(random(floor(iTime * shake_speed)) < shake_rate);

    // Compute per-line jitter
    float line_seed = floor(fragTexCoord.y * resolution.y / shake_block_size);
    float shift = (random(line_seed + iTime) - 0.5) * shake_power * enable_shift;

    vec2 shifted_uv = fragTexCoord + vec2(shift, 0.0);

    // Sample base color
    vec4 color = texture(texture0, shifted_uv);

    // Apply RGB channel shifting
    float r = mix(color.r, texture(texture0, shifted_uv + vec2(shake_color_rate, 0.0)).r, enable_shift);
    float g = color.g;
    float b = mix(color.b, texture(texture0, shifted_uv - vec2(shake_color_rate, 0.0)).b, enable_shift);

    finalColor = vec4(r, g, b, color.a) * fragColor * colDiffuse;
}
