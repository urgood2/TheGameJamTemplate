#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

uniform float iTime;
uniform vec2 iResolution;

out vec4 finalColor;

#define NOISINESS   0.445
#define HUEOFFSET   0.53
#define DONUTWIDTH  0.3

vec2 hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1,311.7)), dot(p, vec2(269.5,183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float noise(vec2 p) {
    const float K1 = 0.366025404;
    const float K2 = 0.211324865;
    vec2 i = floor(p + (p.x + p.y) * K1);
    vec2 a = p - i + (i.x + i.y) * K2;
    float m = step(a.y, a.x);
    vec2 o = vec2(m, 1.0 - m);
    vec2 b = a - o + K2;
    vec2 c = a - 1.0 + 2.0 * K2;
    vec3 h = max(0.5 - vec3(dot(a,a), dot(b,b), dot(c,c)), 0.0);
    vec3 n = h*h*h*h * vec3(dot(a, hash(i + 0.0)), dot(b, hash(i + o)), dot(c, hash(i + 1.0)));
    return dot(n, vec3(70.0));
}

vec2 cartesian2polar(vec2 cartesian){
    return vec2(atan(cartesian.x, cartesian.y), length(cartesian));
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float donutFade(float distToMid, float radius, float thickness) {
    return clamp((distToMid - radius) / thickness + 0.5, 0.0, 1.0);
}

void main() {
    vec2 uv = (fragTexCoord * iResolution - 0.5 * iResolution) / iResolution.y;
    uv *= 3.0;
    uv += noise(uv + (iTime + sin(iTime * 0.1) * 10.0 + vec2(cos(iTime * 0.144), sin(iTime * 0.2) * 14.0)) * 0.2) * NOISINESS;

    vec2 uvPol = cartesian2polar(uv);
    vec3 col = vec3(0.0);
    float colorAccum = 0.5;

    for (int i = 0; i < 4; i++) {
        float radius = fract(iTime / 3.0) * 5.0;
        if (i == 1) radius = 0.5;
        else if (i == 2) radius = 1.1;
        else if (i == 3) radius = 1.5;

        float torus = donutFade(uvPol.y, radius, DONUTWIDTH);
        float contrib = min(smoothstep(torus, 1.0, 0.95), smoothstep(torus, 0.0, 0.05));
        colorAccum += contrib;
        col += hsv2rgb(vec3(torus * 1.3 + HUEOFFSET, 1.0, 1.0)) * contrib;
    }

    finalColor = vec4(col, 1.0) * colDiffuse * fragColor;
}
