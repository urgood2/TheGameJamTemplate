#version 300 es
precision mediump float;

// UIEffect: Transition - Blaze
// Uses a gradient ramp to create a flame-like transition

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform sampler2D transitionTex;
uniform sampler2D transitionGradientTex;
uniform vec4 colDiffuse;

// Effect parameters
uniform float transitionRate;   // Progress 0-1
uniform float transitionWidth;  // Width of blaze front

out vec4 finalColor;

void main() {
    // Straight alpha: multiply RGB and alpha separately to prevent darkening
    vec4 tex = texture(texture0, fragTexCoord);
    vec3 baseRGB = tex.rgb * colDiffuse.rgb * fragColor.rgb;
    float baseA = tex.a * colDiffuse.a * fragColor.a;
    vec4 baseColor = vec4(baseRGB, baseA);
    float alpha = texture(transitionTex, fragTexCoord).a;

    float maxValue = transitionRate;
    float minValue = maxValue - transitionWidth * 0.5;
    float scaledAlpha = alpha * (1.0 - transitionWidth * 0.5);
    float denom = max(maxValue - minValue, 0.0001);
    float rate = 1.0 - clamp((scaledAlpha - minValue) / denom, 0.0, 1.0);

    vec4 grad = texture(transitionGradientTex, vec2(rate, 0.5));
    vec4 burntColor = grad * baseColor;
    vec4 flameColor = vec4(grad.rgb, grad.a * baseColor.a);

    vec4 color = mix(burntColor, flameColor, step(0.5, rate));
    color.rgb *= color.a;

    finalColor = color;
}
