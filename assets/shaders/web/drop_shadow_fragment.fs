#version 300 es
precision mediump float;

// Source: https://godotshaders.com/shader/2d-drop-shadow
// Converted from Godot to Raylib

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0; // Screen texture
uniform vec4 colDiffuse;
uniform vec4 background_color;
uniform vec4 shadow_color;
uniform vec2 offset_in_pixels;
uniform vec2 screen_pixel_size;

out vec4 finalColor;

void main()
{
    // Read screen texture at current position
    vec4 current_color = texture(texture0, fragTexCoord);

    // Check if the current color is our background color
    if (length(current_color - background_color) < 0.01) {

        // Sample at offset position
        vec2 offset_uv = fragTexCoord - offset_in_pixels * screen_pixel_size;
        vec4 offset_color = texture(texture0, offset_uv);

        // Check if at our offset position we have a color which is not the background
        // (meaning here we need a shadow actually)
        if (length(offset_color - background_color) > 0.01) {
            // If so set it to our shadow color
            current_color = shadow_color;
        }
    }

    finalColor = current_color * colDiffuse * fragColor;
}
