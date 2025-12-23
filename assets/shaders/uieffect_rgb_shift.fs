#version 330 core
// UIEffect: Sampling - RGB Shift
// Offsets color channels separately for a chromatic aberration look

in vec2 fragTexCoord;
in vec4 fragColor;
in vec2 fragPosition;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Effect parameters
uniform float intensity;   // Shift strength (0 = none)
uniform vec2 texelSize;    // 1.0 / texture size
uniform vec2 shiftDir;     // Direction of the shift (defaults to X if zero)

out vec4 finalColor;

void main() {
    // Straight alpha: multiply RGB and alpha separately to prevent darkening
    vec4 baseSample = texture(texture0, fragTexCoord);
    vec3 baseRGB = baseSample.rgb * colDiffuse.rgb * fragColor.rgb;
    float baseA = baseSample.a * colDiffuse.a * fragColor.a;
    vec4 baseColor = vec4(baseRGB, baseA);

    if (intensity <= 0.0) {
        finalColor = baseColor;
        return;
    }

    vec2 dir = shiftDir;
    if (length(dir) == 0.0) {
        dir = vec2(1.0, 0.0);
    } else {
        dir = normalize(dir);
    }

    vec2 shift = dir * texelSize * intensity * 20.0;

    vec4 rTex = texture(texture0, fragTexCoord + shift);
    vec4 rSample = vec4(rTex.rgb * colDiffuse.rgb * fragColor.rgb, rTex.a * colDiffuse.a * fragColor.a);
    vec4 gSample = baseColor;
    vec4 bTex = texture(texture0, fragTexCoord - shift);
    vec4 bSample = vec4(bTex.rgb * colDiffuse.rgb * fragColor.rgb, bTex.a * colDiffuse.a * fragColor.a);

    float alpha = (rSample.a + gSample.a + bSample.a) / 3.0;
    vec3 rgb = vec3(rSample.r, gSample.g, bSample.b);

    finalColor = vec4(rgb, alpha);
}
