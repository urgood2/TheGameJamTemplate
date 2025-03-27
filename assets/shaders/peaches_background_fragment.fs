#version 330 core
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform float iTime;
uniform vec2 resolution;

// === Customizable parameters ===
uniform float blob_count = 8.0;                // Number of blobs
uniform float blob_spacing = 0.1;              // Horizontal spacing between blobs
uniform float shape_amplitude = 0.03;          // Cosine-based animation offset
uniform float wave_strength = 1.2;             // Affects the smoothstep curve scaling
uniform float highlight_gain = 1.2;            // How much to boost highlights
uniform float noise_strength = 0.14;           // Strength of flickering noise
uniform float radial_falloff = 0.6;            // Falloff from center
uniform float cl_shift = 0.2;                  // Center luminance shift for sin(acos(...))
uniform float distortion_strength = 0.2;       // Affects atan() -> smoothstep response
uniform float edge_softness_min = 0.1;         // Min threshold for smoothstep in ting
uniform float edge_softness_max = 0.7;         // Max threshold for smoothstep in ting

out vec4 finalColor;

float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9891, 78.233))) * 43754.6453);
}

float ting(float i, vec2 uv, vec2 loc)
{
    float d = distance(uv, loc);
    return smoothstep(edge_softness_max, edge_softness_min, d);
}

void main() {
    vec2 uv = fragTexCoord;
    uv.y /= (resolution.x / resolution.y);
    uv.y -= max(0.0, (resolution.y - resolution.x) / resolution.y);

    float cl = 0.0;
    float dl = 0.0;
    float v = 2.0 - smoothstep(0.0, 1.0, 1.0 - distance(uv, vec2(0.5))) * 2.0;
    float t = cos(iTime);

    int blobCount = min(int(blob_count), 64);

    for (int i = 0; i < 64; i++) {
        if (i >= blobCount) break;
        float fi = float(i);
        float ty = fract(sin(fi * 13.123) * 43758.5453); // better hash
        float tx = (fi + 0.5) / blob_count + shape_amplitude * cos(iTime + fi);
        float tcos = cos(iTime * float(i - blobCount / 2) * 0.3);
        vec2 pos1 = vec2(tx, ty);
        vec2 pos2 = pos1 + vec2(0.01);

        float tin1 = ting(fi * tcos, uv, pos1);
        float tin2 = ting(fi * tcos, uv, pos2);

        cl += smoothstep(cl, wave_strength, tin1);
        dl += smoothstep(dl, wave_strength - 0.1, tin2);
    }

    cl = sin(acos(clamp(cl - cl_shift, -1.0, 1.0)));
    dl = sin(acos(clamp(dl - cl_shift, -1.0, 1.0)));

    float j = sin(5.0 * smoothstep(0.3, 1.2, dl));
    cl = max(cl, j * highlight_gain);
    cl += rand(uv * resolution + iTime) * noise_strength;
    cl -= v * radial_falloff;

    finalColor = vec4(cl * 1.44, (cl + dl) / 2.3, cl * 0.9, 1.0);
}
