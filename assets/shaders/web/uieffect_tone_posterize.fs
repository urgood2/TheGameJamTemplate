#version 300 es
precision mediump float;

precision mediump float;

// UIEffect: Tone - Posterize
// Reduces the number of colors to create a poster-like effect

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Effect parameters
uniform float intensity; // 0.0 = 48 levels (subtle), 1.0 = 4 levels (extreme)

out vec4 finalColor;

// RGB to HSV conversion
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-4;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// HSV to RGB conversion
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    vec4 color = texelColor * colDiffuse * fragColor;

    // Convert to HSV
    vec3 hsv = rgb2hsv(color.rgb);

    // Calculate number of levels (48 at low intensity, 4 at high intensity)
    float levels = mix(48.0, 4.0, intensity);
    float div = round(levels / 2.0) * 2.0;

    // Posterize by quantizing HSV values
    vec3 posterized = (floor(hsv * div) + 0.5) / div;

    // Convert back to RGB
    color.rgb = hsv2rgb(posterized) * color.a;

    finalColor = color;
}
