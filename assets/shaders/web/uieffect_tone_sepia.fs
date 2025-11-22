#version 300 es
precision mediump float;

precision mediump float;

// UIEffect: Tone - Sepia
// Applies a sepia tone effect with adjustable intensity

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Effect parameters
uniform float intensity; // 0.0 = no effect, 1.0 = full sepia

out vec4 finalColor;

// Calculate luminance using standard weights
float luminance(vec3 color) {
    return dot(color.rgb, vec3(0.299, 0.587, 0.114));
}

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    vec4 color = texelColor * colDiffuse * fragColor;

    // Convert to sepia
    float lum = luminance(color.rgb);
    vec3 sepiaColor = lum * vec3(1.07, 0.74, 0.43);

    // Mix between original and sepia based on intensity
    color.rgb = mix(color.rgb, sepiaColor, intensity);

    finalColor = color;
}
