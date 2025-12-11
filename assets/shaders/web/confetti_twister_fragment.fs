#version 300 es
precision mediump float;

// 3D confetti twister effect with rotating layers
// Source: Shadertoy (ported to Raylib GLSL ES 300)
// Performance note: Heavy raymarching - 156 steps

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

uniform float iTime;
uniform vec2 iResolution;

out vec4 finalColor;

#define MAX_STEPS 156
#define MIN_DISTANCE 0.001
#define MAX_DISTANCE 10.0
#define LAYERS 10.0
#define LAYER_SIZE 6.0

struct TraceResult {
    vec3 id;
    float dt;
    float ds;
    float alpha;
};

float n21(vec2 p) {
    return fract(sin(p.x * 123.231 + p.y * 1432.342 + iTime * 0.01) * 15344.22);
}

vec3 getIdColor(vec3 id) {
    float n = max(0.2, n21(vec2(id.x + id.y, id.z)));
    vec3 rcol = vec3(n, fract(n * 4567.433), fract(n * 45689.33));
    return rcol;
}

TraceResult trace(vec3 ro, vec3 rd) {
    float ds = 0.0;
    float dt = 0.0;
    float n;
    vec3 id = vec3(0.0);
    float baseSize = 0.05;
    vec3 baseSpacing = vec3(baseSize * 4.0);
    vec3 bounds = vec3(LAYER_SIZE, LAYER_SIZE, LAYERS);
    vec3 l = bounds;

    TraceResult res;
    res.alpha = 1.0;

    for (int i = 0; i < MAX_STEPS; i++) {
        vec3 p = ro + rd * ds;

        // Initial rotation (90 degrees on YZ plane)
        float a = 3.14 / 2.0;
        p.yz *= mat2(vec2(sin(a), cos(a)), vec2(-cos(a), sin(a)));

        // Time-based rotation on XY plane
        float aa = sin(iTime / 4.0) * 6.26;
        p.xy *= mat2(vec2(sin(aa), cos(aa)), vec2(-cos(aa), sin(aa)));

        vec3 rc1 = vec3(baseSpacing);
        vec3 q1 = p - rc1 * clamp(round(p / rc1), -l, l);

        id = round(p / rc1).xyz;

        // Per-layer rotation based on z-depth
        float pa = sin(id.z + iTime * id.z * 0.05) * 6.28;

        // z-layer interval scale - creates breathing effect
        rc1.xy *= (1.0 + (sin(id.z / 5.0 + iTime * 3.0) * 0.5 + 0.5) * 2.0);

        // z-layer rotation
        p.xy *= mat2(vec2(sin(pa), cos(pa)), vec2(-cos(pa), sin(pa)));

        q1 = p - rc1 * clamp(round(p / rc1), -l, l);
        id = round(p / rc1).xyz;

        n = n21(vec2(id.x * id.y, id.z * id.x * id.z));

        dt = length(q1 + vec3(0.04 * n, 0.04 * fract(n * 567.43), 0.01)) - baseSize;

        ds += dt * 0.5;
        if (abs(dt) < MIN_DISTANCE || dt > MAX_DISTANCE) {
            // Confetti culling threshold - skip particles outside radius
            if (length(id.xy) > 1.6 && fract(n * 718.54) > 0.5) {
                break;
            } else {
                ds += 0.1;
            }
        }
    }

    res.id = id;
    res.dt = dt;
    res.ds = ds;

    return res;
}

void main() {
    vec2 uv = ((fragTexCoord) - 0.5) * vec2(iResolution.x / iResolution.y, 1.0);

    vec3 col = vec3(0.0);

    vec3 ro = vec3(0.0 + sin(iTime), 0.0 + cos(iTime), -3.0 + sin(iTime));
    vec3 lookat = vec3(0.0, 0.0, 0.0);
    float zoom = 0.6;

    vec3 f = normalize(lookat - ro);
    vec3 r = normalize(cross(vec3(0.0, 1.0, 0.0), f));
    vec3 u = cross(f, r);

    vec3 c = ro + f * zoom;
    vec3 I = c + uv.x * r + uv.y * u;

    vec3 rd = normalize(I - ro);

    TraceResult tr = trace(ro, rd);

    if (tr.dt < MIN_DISTANCE) {
        vec3 id = tr.id;
        vec3 rcol = getIdColor(id);
        col += rcol;
    }

    finalColor = vec4(col, 1.0);
    finalColor *= colDiffuse * fragColor;
}
