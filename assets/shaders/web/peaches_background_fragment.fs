#version 300 es
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform float iTime;
uniform vec2 resolution;

// === Customizable parameters ===
uniform float blob_count ;
uniform float blob_spacing 1;
uniform float shape_amplitude ;
uniform float wave_strength ;
uniform float highlight_gain ;
uniform float noise_strength ;
uniform float radial_falloff;
uniform float cl_shift ;
uniform float distortion_strength;
uniform float edge_softness_min;
uniform float edge_softness_max;
uniform vec3 colorTint;
uniform float pixel_size;     // Set to > 1.0 to enable pixelation (e.g., 4.0, 8.0)
uniform float pixel_enable;   // 1.0 = on, 0.0 = off
uniform vec2 blob_offset;  // (x, y) offset in UV space
uniform float movement_randomness; // 0.0 = none, 1.0+ = lots

// === New uniforms ===
uniform float hue_shift;
uniform float blob_color_blend; // blend strength between baseColor and per-blob color

out vec4 finalColor;

// === Utility: random hash ===
float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9891, 78.233))) * 43754.6453);
}

// === Blob shape mask ===
float ting(float i, vec2 uv, vec2 loc) {
    float d = distance(uv, loc);
    return smoothstep(edge_softness_max, edge_softness_min, d);
}

// === HSV Helpers ===
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void main() {
    vec2 uv = fragTexCoord;

    if (pixel_enable > 0.5 && pixel_size > 1.0) {
        vec2 screenUV = uv * resolution;
        screenUV = floor(screenUV / pixel_size) * pixel_size;
        uv = screenUV / resolution;
    }
    uv.y /= (resolution.x / resolution.y);
    uv.y -= max(0.0, (resolution.y - resolution.x) / resolution.y);

    float cl = 0.0;
    float dl = 0.0;
    float v = 2.0 - smoothstep(0.0, 1.0, 1.0 - distance(uv, vec2(0.5))) * 2.0;

    int blobCount = min(int(blob_count), 64);
    vec3 totalColor = vec3(0.0);

    for (int i = 0; i < 64; i++) {
        if (i >= blobCount) break;
        float fi = float(i);
        
        float tcos = cos(iTime * float(i - blobCount / 2) * 0.3);

        // Existing position
        float ty = fract(sin(fi * 13.123) * 43758.5453);
        float tx = (fi + 0.5) / blob_count + shape_amplitude * cos(iTime + fi);

        // Add pseudo-random wobble per blob
        float r1 = sin(dot(vec2(fi, 0.0), vec2(12.9898, 78.233))) * 43758.5453;
        float r2 = cos(dot(vec2(fi, 1.0), vec2(12.9898, 78.233))) * 43758.5453;
        vec2 random_offset = vec2(sin(iTime + r1), cos(iTime + r2)) * 0.01 * movement_randomness;

        vec2 pos1 = vec2(tx, ty) + blob_offset + random_offset;
        vec2 pos2 = pos1 + vec2(0.01);

        float tin1 = ting(fi * tcos, uv, pos1);
        float tin2 = ting(fi * tcos, uv, pos2);

        cl += smoothstep(cl, wave_strength, tin1);
        dl += smoothstep(dl, wave_strength - 0.1, tin2);

        // === Per-blob color tint ===
        float hue = fract(sin(fi * 0.8123 + iTime * 0.1));
        vec3 blobColor = hsv2rgb(vec3(hue, 1.0, 1.0));
        totalColor += blobColor * (tin1 + tin2); // accumulate
    }

    cl = sin(acos(clamp(cl - cl_shift, -1.0, 1.0)));
    dl = sin(acos(clamp(dl - cl_shift, -1.0, 1.0)));

    float j = sin(5.0 * smoothstep(0.3, 1.2, dl));
    cl = max(cl, j * highlight_gain);

    cl += rand(uv * resolution + iTime) * noise_strength;
    cl -= v * radial_falloff;

    vec3 baseColor = vec3(cl * 1.44, (cl + dl) / 2.3, cl * 0.9);
    baseColor *= colorTint;

    // === Apply per-blob blended color ===
    vec3 averageBlobColor = totalColor / float(blobCount);
    baseColor = mix(baseColor, averageBlobColor, blob_color_blend);

    // === Final hue rotation ===
    vec3 hsv = rgb2hsv(baseColor);
    hsv.x = fract(hsv.x + hue_shift);
    baseColor = hsv2rgb(hsv);

    finalColor = vec4(baseColor, 1.0);
}
