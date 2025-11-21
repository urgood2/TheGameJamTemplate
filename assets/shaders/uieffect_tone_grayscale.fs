#version 330

// UIEffect: Tone - Grayscale
// Converts the texture to grayscale with adjustable intensity

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Effect parameters
uniform float intensity; // 0.0 = no effect, 1.0 = full grayscale

out vec4 finalColor;

// Calculate luminance using standard weights
float luminance(vec3 color) {
    return dot(color.rgb, vec3(0.299, 0.587, 0.114));
}

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    vec4 color = texelColor * colDiffuse * fragColor;

    // Convert to grayscale
    float gray = luminance(color.rgb);
    vec3 grayColor = vec3(gray);

    // Mix between original and grayscale based on intensity
    color.rgb = mix(color.rgb, grayColor, intensity);

    finalColor = color;
}
