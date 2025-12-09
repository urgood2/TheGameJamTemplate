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
uniform sampler2D noise_tex;
uniform vec4 root_color;
uniform vec4 tip_color;
uniform float poster_color;
uniform float fire_alpha;
uniform vec2 fire_speed;
uniform float fire_aperture;
uniform float vignette_radius;
uniform float vignette_falloff;
uniform float noise_influence;
uniform float iTime;

out vec4 finalColor;

const float PI = 3.14159265359;

vec2 polar_coordinates(vec2 uv, vec2 center, float zoom, float repeat) {
    vec2 d = uv - center;
    float r = length(d) * 2.0;
    float theta = atan(d.y, d.x) * (1.0 / (2.0 * PI));
    return mod(vec2(r * zoom, theta * repeat), 1.0);
}

void main() {
    vec2 center = vec2(0.5);
    vec2 p = polar_coordinates(fragTexCoord, center, 1.0, 1.0);

    // fire "movement"
    p.x += iTime * fire_speed.y;
    p.y += sin(iTime) * fire_speed.x;

    // noise texture
    float n = texture(noise_tex, p).r;

    // the fire itself
    float dist = distance(fragTexCoord, center);
    float edge = clamp(1.0 - dist, 0.0, 1.0);
    float noise_val = edge * (((edge + fire_aperture) * n - fire_aperture) * 75.0);
    noise_val = clamp(noise_val, 0.0, 1.0);

    // vignette
    float effective_radius = vignette_radius + n * noise_influence * vignette_falloff;
    float mask = smoothstep(effective_radius + vignette_falloff, effective_radius, 1.0 - dist);

    // final alpha
    float alpha = noise_val * fire_alpha * mask;

    // color posterization
    vec4 fire_color;
    if (poster_color >= 1.0) {
        float quantized = floor(n * poster_color) / poster_color;
        fire_color = mix(tip_color, root_color, quantized);
        alpha = floor(alpha * poster_color) / poster_color;
    } else {
        fire_color = mix(tip_color, root_color, n);
    }

    finalColor = vec4(fire_color.rgb, alpha) * colDiffuse * fragColor;
}
