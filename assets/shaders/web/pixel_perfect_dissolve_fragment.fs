#version 300 es
precision mediump float;

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Custom uniform
uniform float sensitivity;

// Output fragment color
out vec4 finalColor;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 438.5453);
}

void main()
{
    // Get size of texture in pixels
    vec2 textureSize2d = vec2(textureSize(texture0, 0));
    float size_x = textureSize2d.x;
    float size_y = textureSize2d.y;

    vec4 pixelColor = texture(texture0, fragTexCoord);

    // Create a new "UV" which remaps every UV value to a snapped pixel value
    vec2 UVr = vec2(floor(fragTexCoord.x * size_x) / size_x, floor(fragTexCoord.y * size_y) / size_y);

    // Determine whether pixel should be visible or not
    float visible = step(sensitivity, random(UVr));

    // Draw the pixel, or not depending on if it is visible or not
    vec4 dissolvedColor = vec4(pixelColor.r, pixelColor.g, pixelColor.b, min(visible, pixelColor.a));

    finalColor = dissolvedColor * colDiffuse * fragColor;
}
