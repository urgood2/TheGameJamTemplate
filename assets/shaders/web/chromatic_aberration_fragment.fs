#version 300 es
precision mediump float;

precision mediump float;

// Source: https://godotshaders.com/shader/chromatic-aberration-vignette
// Converted from Godot to Raylib
// Big thanks to both jecovier and axilirate, who's shaders I built upon

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0; // Screen texture
uniform vec4 colDiffuse;
uniform vec2 r_displacement;
uniform vec2 g_displacement;
uniform vec2 b_displacement;
uniform float height;
uniform float width;
uniform float fade;
uniform vec2 screen_pixel_size;

out vec4 finalColor;

void main()
{
    float shrink_width = 2.0 / width;
    float shrink_height = 2.0 / height;
    float dist = distance(vec2(fragTexCoord.x * shrink_width, fragTexCoord.y * shrink_height),
                         vec2(0.5 * shrink_width, 0.5 * shrink_height));

    float r = texture(texture0, fragTexCoord + screen_pixel_size * r_displacement).r;
    float g = texture(texture0, fragTexCoord + screen_pixel_size * g_displacement).g;
    float b = texture(texture0, fragTexCoord + screen_pixel_size * b_displacement).b;

    finalColor = vec4(r, g, b, dist - fade) * colDiffuse * fragColor;
}
