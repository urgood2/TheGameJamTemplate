#version 330 core
// UIEffect: Target Filter
// Applies overlay color selectively based on hue or luminance proximity

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Effect parameters
uniform int targetMode;       // 0 = none, 1 = hue, 2 = luminance
uniform vec4 targetColor;     // Target color for comparison
uniform float targetRange;    // Range of acceptance
uniform float targetSoftness; // Softness near the edge of the range
uniform vec4 overlayColor;    // Overlay applied to matching pixels (rgb) with overlayColor.a as strength
uniform float targetIntensity; // Blend strength for the overlay (0-1)

out vec4 finalColor;

float luminance(vec3 c) {
    return dot(c, vec3(0.299, 0.587, 0.114));
}

vec3 rgbToHsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-4;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float targetRate(vec3 color) {
    if (targetMode == 0) return 1.0;

    float diff = 0.0;
    if (targetMode == 1) { // hue
        float value = rgbToHsv(color).x;
        float target = rgbToHsv(targetColor.rgb).x;
        diff = abs(target - value);
        diff = min(diff, 1.0 - diff);
    } else if (targetMode == 2) { // luminance
        float value = luminance(color);
        float target = luminance(targetColor.rgb);
        diff = abs(target - value);
    }

    float range = max(targetRange, 0.0001);
    float soft = clamp(targetSoftness, 0.0, 1.0);
    float edgeStart = range * (1.0 - soft);
    float rate = 1.0 - clamp((diff - edgeStart) / max(range - edgeStart, 1e-4), 0.0, 1.0);
    return rate;
}

void main() {
    vec4 baseColor = texture(texture0, fragTexCoord) * colDiffuse * fragColor;

    float rate = targetRate(baseColor.rgb) * targetIntensity;
    if (rate <= 0.0) {
        finalColor = baseColor;
        return;
    }

    vec3 tinted = mix(baseColor.rgb, overlayColor.rgb, overlayColor.a);
    vec3 result = mix(baseColor.rgb, tinted, clamp(rate, 0.0, 1.0));

    finalColor = vec4(result, baseColor.a);
}
