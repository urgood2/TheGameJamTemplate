#version 330 core
// UIEffect: Transition - Pattern
// Patterned reveal that blends a secondary color using a range mask

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform sampler2D transitionTex;
uniform vec4 colDiffuse;

// Effect parameters
uniform float transitionRate;   // Progress 0-1
uniform vec2 transitionRange;   // Range for ramping (min, max) in UV.x space
uniform int patternReverse;     // If non-zero, reverse mask logic
uniform int patternArea;        // 0 = full, 1 = edge, 2 = interior
uniform vec4 patternColor;      // Color blended into the pattern region

out vec4 finalColor;

float ramp01(float value, float minV, float maxV) {
    float span = max(1e-4, maxV - minV);
    return clamp((value - minV) / span, 0.0, 1.0);
}

void main() {
    // Straight alpha: multiply RGB and alpha separately to prevent darkening
    vec4 tex = texture(texture0, fragTexCoord);
    vec3 baseRGB = tex.rgb * colDiffuse.rgb * fragColor.rgb;
    float baseA = tex.a * colDiffuse.a * fragColor.a;
    vec4 baseColor = vec4(baseRGB, baseA);
    float alpha = texture(transitionTex, fragTexCoord).a;

    float ramp = ramp01(fragTexCoord.x, transitionRange.x, transitionRange.y);
    float compare = (patternReverse != 0) ? alpha : (1.0 - alpha);
    float mask = step(ramp, compare) * (1.0 - transitionRate);

    float areaFactor = 1.0;
    if (patternArea == 1) {
        areaFactor = 1.0 - ramp;
    } else if (patternArea == 2) {
        areaFactor = ramp;
    }

    float mixAmount = mask * areaFactor;
    vec4 patColor = vec4(patternColor.rgb, 1.0) * baseColor.a;

    vec3 outRGB = mix(baseColor.rgb, patColor.rgb, mixAmount);
    float outA = mix(baseColor.a, patColor.a, mixAmount);

    finalColor = vec4(outRGB, outA);
}
