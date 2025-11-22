#version 330 core
// UIEffect: Edge - Plain
// Adds a colored edge/outline to sprites

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Effect parameters
uniform float edgeWidth;         // Width of the edge (0.0-1.0)
uniform vec4 edgeColor;          // Color of the edge
uniform vec2 texelSize;          // Size of one texel

out vec4 finalColor;

float invLerp(float from, float to, float value) {
    return clamp(max(0.0, value - from) / max(0.001, to - from), 0.0, 1.0);
}

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);
    vec4 color = texelColor * colDiffuse * fragColor;

    // Calculate edge detection by sampling neighbors
    vec2 d = texelSize * mix(1.0, 20.0, edgeWidth);
    float e = 1.0;

    // Sample 12 neighbors in a circle
    e = min(e, texture(texture0, fragTexCoord + d * vec2(1.0, 0.0)).a);
    e = min(e, texture(texture0, fragTexCoord + d * vec2(0.866025, 0.5)).a);
    e = min(e, texture(texture0, fragTexCoord + d * vec2(0.5, 0.866025)).a);
    e = min(e, texture(texture0, fragTexCoord + d * vec2(0.0, 1.0)).a);
    e = min(e, texture(texture0, fragTexCoord + d * vec2(-0.5, 0.866025)).a);
    e = min(e, texture(texture0, fragTexCoord + d * vec2(-0.866025, 0.5)).a);
    e = min(e, texture(texture0, fragTexCoord + d * vec2(-1.0, 0.0)).a);
    e = min(e, texture(texture0, fragTexCoord + d * vec2(-0.866025, -0.5)).a);
    e = min(e, texture(texture0, fragTexCoord + d * vec2(-0.5, -0.866025)).a);
    e = min(e, texture(texture0, fragTexCoord + d * vec2(0.0, -1.0)).a);
    e = min(e, texture(texture0, fragTexCoord + d * vec2(0.5, -0.866025)).a);
    e = min(e, texture(texture0, fragTexCoord + d * vec2(0.866025, -0.5)).a);

    // Calculate edge factor
    float edgeFactor = 1.0 - invLerp(0.15, 0.3, e);

    // Mix color with edge color
    vec4 finalEdgeColor = vec4(edgeColor.rgb * color.a, color.a);
    finalColor = mix(color, finalEdgeColor, edgeFactor);
}
