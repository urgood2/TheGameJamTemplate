#version 300 es
precision mediump float;

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
    vec4 baseSample = texture(texture0, fragTexCoord);
    vec4 baseColor = baseSample * colDiffuse * fragColor;

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

    vec4 rSample = texture(texture0, fragTexCoord + shift) * colDiffuse * fragColor;
    vec4 gSample = baseColor;
    vec4 bSample = texture(texture0, fragTexCoord - shift) * colDiffuse * fragColor;

    float alpha = (rSample.a + gSample.a + bSample.a) / 3.0;
    vec3 rgb = vec3(rSample.r, gSample.g, bSample.b);

    finalColor = vec4(rgb, alpha);
}
