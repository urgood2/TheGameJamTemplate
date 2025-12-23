#version 300 es
precision mediump float;

// UIEffect: Transition - Shiny
// Dissolve-style transition with a squared falloff for a shiny band

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform sampler2D transitionTex;
uniform vec4 colDiffuse;

// Effect parameters
uniform float transitionRate;   // Progress 0-1
uniform float transitionWidth;  // Band width
uniform float softness;         // Edge softness (0-1)
uniform vec4 edgeColor;         // Color applied to the shiny band

out vec4 finalColor;

void main() {
    float alpha = texture(transitionTex, fragTexCoord).a;

    float factor = alpha - transitionRate * (1.0 + transitionWidth) + transitionWidth;
    float soft = max(0.0001, transitionWidth * softness);
    float bandLerp = clamp((transitionWidth - factor) * 2.0 / soft, 0.0, 1.0);
    float softLerp = clamp(factor * 2.0 / soft, 0.0, 1.0);

    // Straight alpha: multiply RGB and alpha separately to prevent darkening
    vec4 tex = texture(texture0, fragTexCoord);
    vec3 baseRGB = tex.rgb * colDiffuse.rgb * fragColor.rgb;
    float baseA = tex.a * colDiffuse.a * fragColor.a;
    vec4 baseColor = vec4(baseRGB, baseA);
    vec4 bandColor = vec4(edgeColor.rgb, 1.0) * baseColor.a;

    float lerpFactor = bandLerp * softLerp;
    lerpFactor *= lerpFactor; // emphasize shiny core

    finalColor = mix(baseColor, bandColor, lerpFactor);
}
