#version 300 es
precision mediump float;


// UIEffect: Transition - Dissolve
// Dissolve transition with optional texture pattern

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform sampler2D transitionTex; // Optional noise/pattern texture
uniform vec4 colDiffuse;

// Effect parameters
uniform float transitionRate;    // Transition progress (0.0-1.0)
uniform float transitionWidth;   // Width of the dissolve edge
uniform float softness;          // Softness of the edge (0.0-1.0)
uniform vec4 edgeColor;          // Color of the dissolve edge
uniform float iTime;             // Time for animation

out vec4 finalColor;

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    vec4 color = texelColor * colDiffuse * fragColor;

    // Sample transition texture (noise pattern)
    float alpha = texture(transitionTex, fragTexCoord).a;

    // Calculate transition factor
    float factor = alpha - transitionRate * (1.0 + transitionWidth) + transitionWidth;
    float soft = max(0.0001, transitionWidth * softness);
    float bandLerp = clamp((transitionWidth - factor) * 2.0 / soft, 0.0, 1.0);
    float softLerp = clamp(factor * 2.0 / soft, 0.0, 1.0);

    // Mix with edge color
    vec4 bandColor = vec4(edgeColor.rgb, 1.0) * color.a;
    float lerpFactor = bandLerp * softLerp;

    color = mix(color, bandColor, lerpFactor);
    color *= softLerp;

    finalColor = color;
}
