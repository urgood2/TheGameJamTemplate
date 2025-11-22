#version 300 es
precision mediump float;

precision mediump float;

// Source: https://godotshaders.com/shader/darkened-blur
// Converted from Godot to Raylib

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0; // Screen texture
uniform vec4 colDiffuse;
uniform float lod;
uniform float mix_percentage;

out vec4 finalColor;

void main()
{
    // Sample texture with LOD for blur effect
    vec4 color = textureLod(texture0, fragTexCoord, lod);

    // Mix with black for darkening
    color = mix(color, vec4(0.0, 0.0, 0.0, 1.0), mix_percentage);

    finalColor = color * colDiffuse * fragColor;
}
