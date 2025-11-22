#version 330 core
in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Sprite atlas uniforms
uniform vec4 uGridRect;
uniform vec2 uImageSize;

// Effect uniforms
uniform float sensitivity;

out vec4 finalColor;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 438.5453);
}

void main() {
    // Get size of texture in pixels
    float size_x = float(textureSize(texture0, 0).x);
    float size_y = float(textureSize(texture0, 0).y);

    vec4 pixelColor = texture(texture0, fragTexCoord);

    // Create a new "UV" which remaps every UV value to a snapped pixel value
    vec2 UVr = vec2(floor(fragTexCoord.x * size_x) / size_x, floor(fragTexCoord.y * size_y) / size_y);

    // Determine whether pixel should be visible or not
    float visible = step(sensitivity, random(UVr));

    // Draw the pixel, or not depending on if it is visible or not
    finalColor = vec4(pixelColor.rgb, min(visible, pixelColor.a)) * colDiffuse * fragColor;
}
