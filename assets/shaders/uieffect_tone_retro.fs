#version 330 core
// UIEffect: Tone - Retro
// Applies a retro palette ramp based on luminance

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Effect parameters
uniform float intensity; // 0.0 = no effect, 1.0 = full retro ramp

out vec4 finalColor;

float luminance(vec3 color) {
    return dot(color, vec3(0.299, 0.587, 0.114));
}

vec3 retroPalette(float l) {
    float r0 = step(l, 0.25);
    float r1 = step(l, 0.50);
    float r2 = step(l, 0.75);
    vec3 c0 = vec3(0.06, 0.22, 0.06);
    vec3 c1 = vec3(0.19, 0.38, 0.19);
    vec3 c2 = vec3(0.54, 0.67, 0.06);
    vec3 c3 = vec3(0.60, 0.74, 0.06);
    return c0 * r0 + c1 * (1.0 - r0) * r1 + c2 * (1.0 - r1) * r2 + c3 * (1.0 - r2);
}

void main() {
    vec4 texel = texture(texture0, fragTexCoord);
    vec4 color = texel * colDiffuse * fragColor;

    float l = luminance(color.rgb);
    vec3 retro = retroPalette(l) * color.a;

    color.rgb = mix(color.rgb, retro, intensity);
    finalColor = color;
}
