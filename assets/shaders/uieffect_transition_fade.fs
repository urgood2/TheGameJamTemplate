#version 330 core
// UIEffect: Transition - Fade
// Simple fade in/out transition

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Effect parameters
uniform float transitionRate; // Transition progress (0.0-1.0)

out vec4 finalColor;

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    vec4 color = texelColor * colDiffuse * fragColor;

    // Apply fade based on transition rate
    color.a *= clamp(1.0 - transitionRate * 2.0, 0.0, 1.0);

    finalColor = color;
}
