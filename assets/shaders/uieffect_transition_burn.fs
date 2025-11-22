#version 330 core
// UIEffect: Transition - Burn
// Burn transition effect with ember-like edges

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform sampler2D transitionTex; // Pattern texture
uniform vec4 colDiffuse;

// Effect parameters
uniform float transitionRate;    // Transition progress (0.0-1.0)
uniform float transitionWidth;   // Width of the burn effect
uniform float softness;          // Softness of the edge
uniform vec4 edgeColor;          // Color of the burn edge (typically orange/red)
uniform vec4 uvMask;             // UV bounds

out vec4 finalColor;

void main() {
    // Sample transition texture
    float alpha = texture(transitionTex, fragTexCoord).a;

    // Calculate burn offset (upward instead of downward)
    float factor = alpha - transitionRate * (1.0 + transitionWidth * 1.5) + transitionWidth;
    float band = max(0.0, transitionWidth - factor);
    float burnOffset = -band * band * (uvMask.w - uvMask.y) / max(0.01, transitionWidth);

    // Apply burn offset to UV
    vec2 burnUV = fragTexCoord + vec2(0.0, burnOffset);

    vec4 texelColor = texture(texture0, burnUV);
    vec4 color = texelColor * colDiffuse * fragColor;

    // Calculate burn edge effect
    float soft = max(0.0001, transitionWidth * softness);
    float bandLerp = clamp((transitionWidth - factor) * 2.0 / soft, 0.0, 1.0);

    vec4 bandColor = vec4(edgeColor.rgb, 1.0) * color.a;
    color = mix(color, bandColor, bandLerp * 1.25);

    // Fade out the burned areas
    float burnFade = 1.0 - smoothstep(0.85, 1.0, bandLerp * 1.25);
    color.a *= burnFade;
    color.rgb *= burnFade * color.a;

    finalColor = color;
}
