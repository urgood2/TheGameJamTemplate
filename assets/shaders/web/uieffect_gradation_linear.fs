#version 300 es
precision mediump float;


// UIEffect: Gradation - Linear
// Applies a linear gradient overlay

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Effect parameters
uniform float intensity;         // Gradient intensity (0.0-1.0)
uniform vec4 color1;             // Start color
uniform vec4 color2;             // End color
uniform float rotation;          // Gradient rotation in degrees
uniform vec2 scale;              // Gradient scale
uniform vec2 offset;             // Gradient offset

out vec4 finalColor;

vec4 applyGradient(vec4 inColor, vec4 gradColor) {
    vec3 result = mix(inColor.rgb, inColor.rgb * gradColor.rgb, intensity);
    float alpha = mix(inColor.a, inColor.a * gradColor.a, intensity);
    return vec4(result, alpha);
}

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    vec4 color = texelColor * colDiffuse * fragColor;

    // Calculate gradient UV with rotation, scale, and offset
    vec2 center = vec2(0.5);
    vec2 uv = fragTexCoord - center;

    // Apply rotation
    float rad = radians(rotation);
    float s = sin(rad);
    float c = cos(rad);
    mat2 rotMatrix = mat2(c, -s, s, c);
    uv = rotMatrix * uv;

    // Apply scale and offset
    uv = uv * scale + center + offset;

    // Calculate gradient factor
    float t = clamp(uv.x, 0.0, 1.0);
    vec4 gradColor = mix(color1, color2, t);

    // Apply gradient
    finalColor = applyGradient(color, gradColor);
}
