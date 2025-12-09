#version 300 es
precision mediump float;


// UIEffect: Gradation - Radial
// Applies a radial gradient overlay

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Effect parameters
uniform float intensity;         // Gradient intensity (0.0-1.0)
uniform vec4 color1;             // Center color
uniform vec4 color2;             // Edge color
uniform vec2 center;             // Gradient center (0.0-1.0)
uniform float scale;             // Gradient scale

out vec4 finalColor;

vec4 applyGradient(vec4 inColor, vec4 gradColor) {
    vec3 result = mix(inColor.rgb, inColor.rgb * gradColor.rgb, intensity);
    float alpha = mix(inColor.a, inColor.a * gradColor.a, intensity);
    return vec4(result, alpha);
}

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    vec4 color = texelColor * colDiffuse * fragColor;

    // Calculate radial gradient
    vec2 uv = fragTexCoord - center;
    float dist = length(uv * 2.0 * scale);
    float t = clamp(dist, 0.0, 1.0);

    vec4 gradColor = mix(color1, color2, t);

    // Apply gradient
    finalColor = applyGradient(color, gradColor);
}
