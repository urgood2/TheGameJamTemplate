#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

//────────────────────────────────────────────────────────
// Custom uniforms (Raylib compatible)
uniform bool hasNeonEffect;
uniform bool hasDot;
uniform bool haszExpend;

uniform float theta;
uniform float addH;
uniform float scale;

uniform float light_disperse;
uniform float stertch;
uniform float speed;
uniform float modTime;

uniform float rotate_speed;
uniform float rotate_plane_speed;
uniform float theta_sine_change_speed;

uniform bool iswhite;
uniform bool isdarktotransparent;
uniform bool bemask;

uniform int m;
uniform int n;

uniform float iTime;

//────────────────────────────────────────────────────────

out vec4 finalColor;

// Random
float random(in vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

bool vec3lower(vec3 A, float v) {
    return (A.r <= v && A.g <= v && A.b <= v);
}

void main() {
    vec4 texelColor = texture(texture0, fragTexCoord);

    vec4 COLOR = vec4(0.0);

    vec2 suv = (fragTexCoord - 0.5) * 2.0;

    const float PI = 3.14159265359;
    const float TAU = 6.28318530718;

    for (int j = 0; j < n && (hasDot || hasNeonEffect); j++) {

        float seed = random(vec2(2.0 - float(j), float(j) * 37.0));

        for (int i = 0; i < m; i++) {

            float z = mod(
                5.0 + float(n)/float(j) * 10.0
                + iTime * speed + 8.0 + float(i) * scale * stertch,
                modTime
            ) * scale;

            float aphla = seed * TAU + iTime * rotate_speed;

            float H = addH * scale +
                      z * tan((theta + iTime * theta_sine_change_speed) / 180.0 * PI);

            float zscale = haszExpend
                         ? min(z + 0.06, modTime) * scale * modTime * 0.5
                         : scale;

            vec2 nuv = vec2(
                H * cos(aphla + iTime * rotate_plane_speed),
                H * sin(aphla)
            );

            // Neon
            if (hasNeonEffect) {
                float l = max(
                    exp(-distance(suv / zscale, nuv / zscale) / light_disperse), 
                    0.0
                );

                vec4 L = iswhite
                    ? vec4(l)
                    : vec4(
                        random(vec2(seed, float(j) * 37.0)) * l,
                        random(vec2(7.0 + float(j), seed)) * l,
                        random(vec2(seed, 3.0 - float(j))) * l,
                        1.0
                    );

                COLOR = min(COLOR + L, vec4(1.0));
            }

            // Dot mode
            if (distance(suv, nuv) < 1.0 * zscale && hasDot) {
                COLOR = vec4(1.0);
            }
        }
    }

    // Masking logic
    if (isdarktotransparent) {
        COLOR = vec3lower(COLOR.rgb, 0.16) ? vec4(0.0) : COLOR;
    } 
    else {
        COLOR = bemask
              ? (!vec3lower(COLOR.rgb,0.16) ? vec4(0.0) : COLOR)
              : COLOR;
    }

    finalColor = COLOR * texelColor * colDiffuse * fragColor;
}
