#version 300 es
precision mediump float;

// UIEffect: Detail/Masking
// Overlays a secondary texture using multiple blend modes

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform sampler2D detailTex;
uniform vec4 colDiffuse;

// Effect parameters
uniform float detailIntensity;   // 0 = off
uniform vec4 detailColor;        // Tint for detail texture
uniform vec2 detailThreshold;    // Used when detailMode == 0 (masking)
uniform int detailMode;          // 0 masking, 1 multiply, 2 additive, 3 subtractive, 4 replace, 5 multiply-additive
uniform vec2 detailTexScale;     // Scale for detail UVs
uniform vec2 detailTexOffset;    // Offset for detail UVs
uniform vec2 detailTexSpeed;     // Scroll speed for detail UVs
uniform float iTime;             // Time for scrolling

out vec4 finalColor;

float clamp01(float v) {
    return clamp(v, 0.0, 1.0);
}

void main() {
    vec4 baseColor = texture(texture0, fragTexCoord) * colDiffuse * fragColor;

    if (detailIntensity <= 0.0) {
        finalColor = baseColor;
        return;
    }

    vec2 detailUV = fragTexCoord * detailTexScale + detailTexOffset + detailTexSpeed * iTime;
    vec4 detail = texture(detailTex, detailUV) * detailColor;

    vec4 color = baseColor;
    if (detailMode == 0) {
        float mask = clamp01((detail.a - detailThreshold.x) / max(1e-4, detailThreshold.y - detailThreshold.x));
        float m = mix(1.0, mask, detailIntensity);
        color.rgb *= m;
        color.a *= m;
    } else if (detailMode == 1) { // multiply
        vec3 blended = color.rgb * detail.rgb;
        color.rgb = mix(color.rgb, blended, detailIntensity * detail.a);
    } else if (detailMode == 2) { // additive
        vec3 blended = color.rgb + detail.rgb * color.a;
        color.rgb = mix(color.rgb, blended, detailIntensity * detail.a);
    } else if (detailMode == 3) { // subtractive
        vec3 blended = color.rgb - detail.rgb * color.a;
        color.rgb = mix(color.rgb, blended, detailIntensity * detail.a);
    } else if (detailMode == 4) { // replace
        vec3 blended = detail.rgb * color.a;
        color.rgb = mix(color.rgb, blended, detailIntensity * detail.a);
    } else { // 5 multiply-additive (default)
        vec3 blended = color.rgb * (1.0 + detail.rgb);
        color.rgb = mix(color.rgb, blended, detailIntensity * detail.a);
    }

    finalColor = color;
}
