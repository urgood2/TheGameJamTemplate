#version 300 es
precision mediump float;

precision mediump float;

// Source: https://godotshaders.com/shader/palette-shader-lospec-compatible
// Converted from Godot to Raylib

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0; // Screen texture
uniform sampler2D palette; // Insert a palette from lospec for instance
uniform vec4 colDiffuse;
uniform int palette_size;

out vec4 finalColor;

void main()
{
    vec4 color = texture(texture0, fragTexCoord);
    vec4 new_color = vec4(0.0);

    for (int i = 0; i < palette_size; i++) {
        vec4 palette_color = texture(palette, vec2(1.0 / float(palette_size) * float(i), 0.0));
        if (distance(palette_color, color) < distance(new_color, color)) {
            new_color = palette_color;
        }
    }

    finalColor = new_color * colDiffuse * fragColor;
}
