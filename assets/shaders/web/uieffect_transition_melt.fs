#version 300 es
precision mediump float;


// UIEffect: Transition - Melt
// Melt transition effect that drips downward

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform sampler2D transitionTex; // Pattern texture
uniform vec4 colDiffuse;

// Effect parameters
uniform float transitionRate;    // Transition progress (0.0-1.0)
uniform float transitionWidth;   // Width of the melt effect
uniform float softness;          // Softness of the edge
uniform vec4 edgeColor;          // Color of the melt edge
uniform vec4 uvMask;             // UV bounds (x, y, z, w) = (left, top, right, bottom)

out vec4 finalColor;

void main() {
    // Sample transition texture
    float alpha = texture(transitionTex, fragTexCoord).a;

    // Calculate melt offset
    float factor = alpha - transitionRate * (1.0 + transitionWidth * 1.5) + transitionWidth;
    float band = max(0.0, transitionWidth - factor);
    float meltOffset = band * band * (uvMask.w - uvMask.y) / max(0.01, transitionWidth);

    // Apply melt offset to UV
    vec2 meltUV = fragTexCoord + vec2(0.0, meltOffset);

    vec4 texelColor = texture(texture0, meltUV);
    vec4 color = texelColor * colDiffuse * fragColor;

    // Calculate band color mixing
    float soft = max(0.0001, transitionWidth * softness);
    float bandLerp = clamp((transitionWidth - factor) * 2.0 / soft, 0.0, 1.0);

    vec4 bandColor = vec4(edgeColor.rgb, 1.0) * color.a;
    color = mix(color, bandColor, bandLerp);

    finalColor = color;
}
