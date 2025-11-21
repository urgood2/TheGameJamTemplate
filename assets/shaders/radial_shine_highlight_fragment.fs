#version 330 core
precision mediump float;

// Source: https://godotshaders.com/shader/radial-shine-highlight
// Converted from Godot to Raylib

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0; // Screen texture
uniform sampler2D gradient;
uniform vec4 colDiffuse;
uniform float spread;
uniform float cutoff;
uniform float size;
uniform float speed;
uniform float ray1_density;
uniform float ray2_density;
uniform float ray2_intensity;
uniform float core_intensity;
uniform float time;
uniform float seed;
uniform int hdr;

out vec4 finalColor;

const float PI = 3.14159265359;

float random(vec2 _uv)
{
    return fract(sin(dot(_uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

float noise(in vec2 uv)
{
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

vec4 screen(vec4 base, vec4 blend)
{
    return vec4(1.0) - (vec4(1.0) - base) * (vec4(1.0) - blend);
}

void main()
{
    vec2 centered_uv = (fragTexCoord - 0.5) * size;
    float radius = length(centered_uv);
    float angle = atan(centered_uv.y, centered_uv.x) + PI; // Add PI to fix left side cutoff

    vec2 ray1 = vec2(angle * ray1_density + time * speed + seed + sin(angle * 3.0), radius * 2.0);
    vec2 ray2 = vec2(angle * ray2_density + time * speed * 1.5 + seed + cos(angle * 2.0), radius * 2.0);

    float cut = 1.0 - smoothstep(cutoff, cutoff + 0.2, radius);
    ray1 *= cut;
    ray2 *= cut;

    float rays = hdr > 0 ?
        noise(ray1) + (noise(ray2) * ray2_intensity) :
        clamp(noise(ray1) + (noise(ray2) * ray2_intensity), 0.0, 1.0);

    rays *= smoothstep(spread, spread * 0.3, radius);
    float core = smoothstep(0.2, 0.0, radius) * core_intensity;
    rays += core;

    vec4 gradient_color = texture(gradient, vec2(rays, 0.5));
    vec3 shine = vec3(rays) * gradient_color.rgb;

    float blur_amount = radius * 0.1;
    vec2 blur_uv = fragTexCoord + centered_uv * blur_amount;
    vec4 blurred = texture(texture0, blur_uv);
    shine = screen(blurred, vec4(shine, rays)).rgb;

    finalColor = vec4(shine, rays * gradient_color.a) * colDiffuse * fragColor;
}
