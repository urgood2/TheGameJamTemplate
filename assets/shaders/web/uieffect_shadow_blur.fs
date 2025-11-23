#version 300 es
precision mediump float;

// UIEffect: Shadow Blur
// Blurs the source alpha and tints it to create a soft shadow

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Effect parameters
uniform float intensity;      // Blur strength (0 = off)
uniform vec2 texelSize;       // 1.0 / texture size
uniform vec2 shadowOffset;    // Offset for shadow sampling (in UV units)
uniform vec4 shadowColor;     // Color/tint for the shadow
uniform float shadowAlpha;    // Extra alpha multiplier for the shadow

out vec4 finalColor;

const float KERNEL[5] = float[](0.2486, 0.7046, 1.0, 0.7046, 0.2486);

void main() {
    vec4 baseColor = texture(texture0, fragTexCoord) * colDiffuse * fragColor;

    if (intensity <= 0.0) {
        finalColor = baseColor;
        return;
    }

    vec2 blur = texelSize * intensity * 2.0;
    vec4 accum = vec4(0.0);
    float weightSum = 0.0;

    for (int x = 0; x < 5; x++) {
        float wx = KERNEL[x];
        float offsetX = blur.x * (float(x) - 2.0);
        for (int y = 0; y < 5; y++) {
            float wy = KERNEL[y];
            float weight = wx * wy;
            vec2 offset = vec2(offsetX, blur.y * (float(y) - 2.0));
            vec4 sample = texture(texture0, fragTexCoord + shadowOffset + offset);
            accum += sample * weight;
            weightSum += weight;
        }
    }

    vec4 shadow = (weightSum > 0.0) ? accum / weightSum : vec4(0.0);
    shadow = vec4(shadowColor.rgb * shadow.a, shadow.a) * shadowAlpha;

    vec4 color = baseColor;
    color.rgb = mix(shadow.rgb, color.rgb, color.a);
    color.a = max(color.a, shadow.a);

    finalColor = color;
}
