#version 330

// UIEffect: Sampling - Pixelation
// Creates a pixelated/mosaic effect

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Effect parameters
uniform float intensity;     // Pixelation intensity (0.0 = no effect, 1.0 = very pixelated)
uniform vec2 texelSize;      // Size of one texel

out vec4 finalColor;

void main() {
    vec2 uv = fragTexCoord;

    if (intensity > 0.0) {
        // Calculate pixel size based on intensity
        vec2 pixelSize = max(vec2(2.0), (1.0 - mix(0.5, 0.95, intensity)) / texelSize);

        // Snap UV coordinates to pixel grid
        uv = round(uv * pixelSize) / pixelSize;
    }

    vec4 texelColor = texture(texture0, uv);
    finalColor = texelColor * colDiffuse * fragColor;
}
