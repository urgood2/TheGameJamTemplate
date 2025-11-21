#version 330 core
precision mediump float;

// Source: https://godotshaders.com/shader/custom-2d-light
// Converted from Godot to Raylib

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0; // Screen texture
uniform sampler2D light_texture;
uniform vec4 colDiffuse;
uniform vec3 light_color;
uniform float brightness;
uniform float attenuation_strength;
uniform float intensity;
uniform float max_brightness;

out vec4 finalColor;

void main()
{
    // Sample the light texture at the current UV coordinates
    vec4 light_tex_color = texture(light_texture, fragTexCoord);

    // Sample the underlying texture color from screen
    vec4 under_color = texture(texture0, fragTexCoord);

    // Normalize the light color from 0-255 to 0.0-1.0
    vec3 normalized_light_color = light_color / 255.0;

    // Calculate the brightness of the underlying pixel (using the luminance formula)
    float under_brightness = dot(under_color.rgb, vec3(0.299, 0.587, 0.114));

    // Adjust the final color by modulating the light texture with brightness,
    // light color, and the brightness of the underlying pixel
    float attenuation = mix(1.0, under_brightness, attenuation_strength);
    vec4 light_result = light_tex_color * attenuation * vec4(normalized_light_color, 1.0) * brightness * intensity;

    // Clamp the resulting color to ensure it does not exceed the max_brightness
    float max_rgb = max_brightness;
    vec3 clamped_color = min(light_result.rgb, vec3(max_rgb));

    // Use additive blending with the background
    vec4 screen_blend = vec4(1.0) - (vec4(1.0) - under_color) * (vec4(1.0) - vec4(clamped_color, light_tex_color.a));

    finalColor = screen_blend * colDiffuse * fragColor;
}
