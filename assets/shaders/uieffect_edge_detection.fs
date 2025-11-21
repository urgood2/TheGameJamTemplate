#version 330

// UIEffect: Sampling - Edge Detection
// Detects edges using Sobel operator on luminance or alpha

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Effect parameters
uniform float intensity;     // Edge detection intensity (0.0-1.0)
uniform float width;         // Edge detection kernel width
uniform vec2 texelSize;      // Size of one texel
uniform int mode;            // 0 = luminance, 1 = alpha

out vec4 finalColor;

// Calculate luminance
float luminance(vec3 color) {
    return dot(color.rgb, vec3(0.299, 0.587, 0.114));
}

float getValue(vec4 color) {
    if (mode == 0) {
        return luminance(color.rgb) * color.a;
    } else {
        return color.a;
    }
}

void main() {
    vec2 d = texelSize * width;

    // Sample 3x3 neighborhood
    float v00 = getValue(texture(texture0, fragTexCoord + vec2(-d.x, -d.y)));
    float v01 = getValue(texture(texture0, fragTexCoord + vec2(-d.x, 0.0)));
    float v02 = getValue(texture(texture0, fragTexCoord + vec2(-d.x, d.y)));
    float v10 = getValue(texture(texture0, fragTexCoord + vec2(0.0, -d.y)));
    float v12 = getValue(texture(texture0, fragTexCoord + vec2(0.0, d.y)));
    float v20 = getValue(texture(texture0, fragTexCoord + vec2(d.x, -d.y)));
    float v21 = getValue(texture(texture0, fragTexCoord + vec2(d.x, 0.0)));
    float v22 = getValue(texture(texture0, fragTexCoord + vec2(d.x, d.y)));

    // Apply Sobel operator
    float sobel_h = v00 * -1.0 + v01 * -2.0 + v02 * -1.0 + v20 * 1.0 + v21 * 2.0 + v22 * 1.0;
    float sobel_v = v00 * -1.0 + v10 * -2.0 + v20 * -1.0 + v02 * 1.0 + v12 * 2.0 + v22 * 1.0;

    float sobel = sqrt(sobel_h * sobel_h + sobel_v * sobel_v) * intensity;
    float edgeFactor = smoothstep(0.5, 1.0, sobel);

    vec4 texelColor = texture(texture0, fragTexCoord);
    vec4 color = texelColor * colDiffuse * fragColor;

    // Mix between no effect and edge-only
    finalColor = mix(vec4(0.0), color, edgeFactor);
}
