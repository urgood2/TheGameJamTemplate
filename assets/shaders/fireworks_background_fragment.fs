#version 330 core
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform float iTime;
uniform vec2 resolution;

// === Customizable parameters ===
uniform int num_particles;       // Default: 75
uniform int num_fireworks;       // Default: 5
uniform float time_scale;        // Animation speed multiplier (default: 1.0)
uniform float gravity_strength;  // How fast particles fall (default: 0.1)
uniform float brightness;        // Overall brightness (default: 1.0)
uniform float particle_size;     // Particle glow size (default: 50.0)
uniform float spread;            // Particle spread distance (default: 1.5)
uniform float color_power;       // Color intensity curve (default: 1.25)

// Flag effect uniforms
uniform float flag_enable;       // 1.0 = show flag, 0.0 = hide
uniform vec3 flag_color_top;     // Top stripe color (default: white)
uniform vec3 flag_color_bottom;  // Bottom stripe color (default: red)
uniform float flag_wave_speed;   // Wave animation speed
uniform float flag_wave_amp;     // Wave amplitude
uniform float flag_brightness;   // Flag contribution (default: 0.15)

out vec4 finalColor;

// ----------------------------------------------------------------------------
// Procedural noise (replaces iChannel0 texture lookup)
// Uses hash-based pseudo-random for deterministic randomness per firework/particle
// ----------------------------------------------------------------------------
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

vec2 noise(vec2 tc) {
    // Return values in range [-1, 1]
    return vec2(
        hash(tc) * 2.0 - 1.0,
        hash(tc + vec2(0.5, 0.5)) * 2.0 - 1.0
    );
}

// ----------------------------------------------------------------------------
// Power function that handles negative values
// ----------------------------------------------------------------------------
vec3 pow3(vec3 v, float p) {
    return pow(abs(v), vec3(p));
}

// ----------------------------------------------------------------------------
// Fireworks effect
// ----------------------------------------------------------------------------
vec3 fireworks(vec2 p, int maxParticles, int maxFireworks) {
    vec3 color = vec3(0.0);

    for (int fw = 0; fw < 8; fw++) {
        if (fw >= maxFireworks) break;

        vec2 pos = noise(vec2(0.82, 0.11) * float(fw)) * spread;
        float time = mod(iTime * 3.0 * time_scale, 6.0 * (1.0 + noise(vec2(0.123, 0.987) * float(fw)).x));

        for (int i = 0; i < 100; i++) {
            if (i >= maxParticles) break;

            vec2 dir = noise(vec2(0.512, 0.133) * float(i));
            dir.y -= time * gravity_strength;

            float term = 1.0 / length(p - pos - dir * time) / particle_size;

            color += pow3(vec3(
                term * noise(vec2(0.123, 0.133) * float(i)).y,
                0.8 * term * noise(vec2(0.533, 0.133) * float(i)).x,
                0.5 * term * noise(vec2(0.512, 0.133) * float(i)).x
            ), color_power);
        }
    }

    return color * brightness;
}

// ----------------------------------------------------------------------------
// Flag effect (optional wavy flag overlay)
// ----------------------------------------------------------------------------
vec3 flag(vec2 p) {
    if (flag_enable < 0.5) return vec3(0.0);

    vec3 color;

    p.y += sin(p.x * 1.3 + iTime * flag_wave_speed) * flag_wave_amp;

    if (p.y > 0.0)
        color = flag_color_top;
    else
        color = flag_color_bottom;

    color *= sin(3.1415 / 2.0 + p.x * 1.3 + iTime * flag_wave_speed) * 0.3 + 0.7;

    return color * flag_brightness;
}

// ----------------------------------------------------------------------------
// Main
// ----------------------------------------------------------------------------
void main() {
    // Normalize coordinates to [-1, 1] with aspect ratio correction
    vec2 p = 2.0 * fragTexCoord - 1.0;
    p.x *= resolution.x / resolution.y;

    // Clamp particle/firework counts for safety
    int particles = clamp(num_particles, 1, 100);
    int fworks = clamp(num_fireworks, 1, 8);

    vec3 color = fireworks(p, particles, fworks) + flag(p);

    finalColor = vec4(color, 1.0) * fragColor;
}
