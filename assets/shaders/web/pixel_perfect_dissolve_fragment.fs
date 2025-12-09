#version 300 es
precision mediump float;


// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Dissolve uniforms
uniform float sensitivity;

// Output fragment color
out vec4 finalColor;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 438.5453);
}

void main()
{
    // Get size of texture in pixels
    ivec2 texSize = textureSize(texture0, 0);
    float sizeX = float(texSize.x);
    float sizeY = float(texSize.y);

    vec4 pixelColor = texture(texture0, fragTexCoord);

    // Create a new "UV" which remaps every UV value to a snapped pixel value
    vec2 UVr = vec2(floor(fragTexCoord.x * sizeX) / sizeX, floor(fragTexCoord.y * sizeY) / sizeY);

    // Determine whether pixel should be visible or not
    float visible = step(sensitivity, random(UVr));

    // Draw the pixel, or not depending on if it is visible or not
    finalColor = vec4(pixelColor.rgb, min(visible, pixelColor.a)) * colDiffuse * fragColor;
}
