#version 330 core
// UIEffect: Tone - Negative
// Inverts the colors with adjustable intensity

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Effect parameters
uniform float intensity; // 0.0 = no effect, 1.0 = full negative

out vec4 finalColor;

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    vec4 color = texelColor * colDiffuse * fragColor;

    // Invert colors
    vec3 negativeColor = (1.0 - color.rgb) * color.a;

    // Mix between original and negative based on intensity
    color.rgb = mix(color.rgb, negativeColor, intensity);

    finalColor = color;
}
