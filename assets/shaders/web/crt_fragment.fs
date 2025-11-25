#version 300 es
precision highp float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform vec4 colDiffuse;
uniform sampler2D texture0;
uniform vec2 resolution; // Screen resolution (e.g. 320x180)

// Core CRT/Noise parameters
uniform float scan_line_amount;
uniform float warp_amount;
uniform float noise_amount;
uniform float interference_amount;
uniform float grille_amount;
uniform float grille_size;
uniform float vignette_amount;
uniform float vignette_intensity;
uniform float aberation_amount;
uniform float roll_line_amount;
uniform float roll_speed;
uniform float scan_line_strength;
uniform float pixel_strength;
uniform float iTime;

// Scanline, bloom, glitch controls
uniform float enable_rgb_scanlines;   // present for uniform parity (unused)
uniform float enable_dark_scanlines;  // 0.0 = off, 1.0 = on
uniform float scanline_density;
uniform float scanline_intensity;
uniform float enable_bloom;           // 0.0 = off, 1.0 = on
uniform float bloom_strength;
uniform float bloom_radius;
uniform float glitch_strength;        // doubles as banding strength
uniform float glitch_speed;
uniform float glitch_density;

out vec4 finalColor;

// --------------------------------------------------------

float random(vec2 uv) {
    return fract(cos(uv.x * 83.4827 + uv.y * 92.2842) * 43758.5453123);
}

vec3 fetch_pixel(vec2 uv, vec2 off) {
    vec2 pos = floor(uv * resolution + off) / resolution + vec2(0.5) / resolution;
    float noise = (noise_amount > 0.0) ? random(pos + fract(iTime)) * noise_amount : 0.0;
    if (max(abs(pos.x - 0.5), abs(pos.y - 0.5)) > 0.5) return vec3(0.0);
    return texture(texture0, pos).rgb + noise;
}

// Horizontal banding (hum bars)
float horizontalBands(vec2 uv, float time, float strength, float density) {
    float v = 0.0;
    v += sin(uv.y * density * 0.8 + time * 1.2);
    v += sin(uv.y * density * 1.3 - time * 0.8);
    v += sin(uv.y * density * 0.5 + time * 0.4);
    v += sin(uv.y * density * 0.25 - time * 0.6);
    v = (v * 0.25 + 0.5);
    return mix(1.0, v, strength);
}

vec2 Dist(vec2 pos) {
    pos *= resolution;
    return -((pos - floor(pos)) - vec2(0.5));
}

float Gaus(float pos, float scale) { return exp2(scale * pos * pos); }

vec3 Horz3(vec2 pos, float off) {
    vec3 b = fetch_pixel(pos, vec2(-1.0, off));
    vec3 c = fetch_pixel(pos, vec2( 0.0, off));
    vec3 d = fetch_pixel(pos, vec2( 1.0, off));
    float dst = Dist(pos).x;
    float scale = pixel_strength;
    float wb = Gaus(dst - 1.0, scale);
    float wc = Gaus(dst + 0.0, scale);
    float wd = Gaus(dst + 1.0, scale);
    return (b * wb + c * wc + d * wd) / (wb + wc + wd);
}

float Scan(vec2 pos, float off) {
    float dst = Dist(pos).y;
    return Gaus(dst + off, scan_line_strength);
}

vec3 Tri(vec2 pos) {
    vec3 clr = fetch_pixel(pos, vec2(0.0));
    if (scan_line_amount > 0.0) {
        vec3 a = Horz3(pos, -1.0);
        vec3 b = Horz3(pos,  0.0);
        vec3 c = Horz3(pos,  1.0);
        float wa = Scan(pos, -1.0);
        float wb = Scan(pos,  0.0);
        float wc = Scan(pos,  1.0);
        vec3 scanlines = a * wa + b * wb + c * wc;
        clr = mix(clr, scanlines, scan_line_amount);
    }
    return clr;
}

vec2 warp(vec2 uv) {
    vec2 delta = uv - 0.5;
    float delta2 = dot(delta.xy, delta.xy);
    float delta4 = delta2 * delta2;
    float delta_offset = delta4 * warp_amount;
    vec2 warped = uv + delta * delta_offset;
    return (warped - 0.5) / mix(1.0, 1.2, warp_amount / 5.0) + 0.5;
}

float vignette(vec2 uv) {
    uv *= 1.0 - uv;
    float v = uv.x * uv.y * 15.0;
    return pow(v, vignette_intensity * vignette_amount);
}

vec3 grille(vec2 uv) {
    float unit = 3.14159 / 3.0;
    float scale = 2.0 * unit / grille_size;
    float r = smoothstep(0.5, 0.8, cos(uv.x * scale - unit));
    float g = smoothstep(0.5, 0.8, cos(uv.x * scale + unit));
    float b = smoothstep(0.5, 0.8, cos(uv.x * scale + 3.0 * unit));
    return mix(vec3(1.0), vec3(r, g, b), grille_amount);
}

float roll_line(vec2 uv) {
    float x = uv.y * 3.0 - iTime * roll_speed;
    float f = cos(x) * cos(x * 2.35 + 1.1) * cos(x * 4.45 + 2.3);
    float roll_line = smoothstep(0.5, 0.9, f);
    return roll_line * roll_line_amount;
}

// Horizontal glitch offset (optional)
void applyHorizontalGlitch(inout vec2 pos) {
    if (glitch_strength <= 0.0001) return;

    float t = iTime * glitch_speed;
    float y = pos.y * resolution.y / glitch_density;

    float offset_l = (
        -3.5
        + sin(t * 0.512 + y * 40.0)
        + sin(-t * 0.8233 + y * 81.532)
        + sin(t * 0.333 + y * 30.3)
        + sin(-t * 0.1112331 + y * 13.0)
    );

    float offset_r = (
        -3.5
        + sin(t * 0.6924 + y * 29.0)
        + sin(-t * 0.9661 + y * 41.532)
        + sin(t * 0.4423 + y * 40.3)
        + sin(-t * 0.13321312 + y * 11.0)
    );

    float offset = mix(offset_l, offset_r, fract(sin(y * 12.345)));
    pos.x += glitch_strength * offset;
}

// Soft Gaussian bloom (with bright-pass)
vec3 bloom_sample(vec2 uv, float radius) {
    vec2 texel = 1.0 / resolution;
    vec3 acc = vec3(0.0);
    float wsum = 0.0;

    const int BLOOM_RADIUS = 6;
    float sigma = radius * 0.5;

    for (int x = -BLOOM_RADIUS; x <= BLOOM_RADIUS; ++x) {
        for (int y = -BLOOM_RADIUS; y <= BLOOM_RADIUS; ++y) {
            float dist2 = float(x * x + y * y);
            float w = exp(-dist2 / (2.0 * sigma * sigma));
            acc += texture(texture0, uv + texel * vec2(x, y) * radius).rgb * w;
            wsum += w;
        }
    }
    return acc / wsum;
}

// --------------------------------------------------------

void main() {
    vec2 uv = fragTexCoord;
    vec2 pos = warp(uv);

    float line = (roll_line_amount > 0.0) ? roll_line(pos) : 0.0;

    // applyHorizontalGlitch(pos); // optional drift

    vec2 sq_pix = floor(pos * resolution) / resolution + vec2(0.5) / resolution;
    if (interference_amount + roll_line_amount > 0.0) {
        float interference = random(sq_pix.yy + fract(iTime));
        pos.x += (interference * (interference_amount + line * 6.0)) / resolution.x;
    }

    vec3 clr = Tri(pos);

    // Horizontal banding
    float bands = horizontalBands(uv, iTime, glitch_strength, glitch_density);
    clr *= bands;

    if (aberation_amount > 0.0) {
        float chromatic = aberation_amount + line * 2.0;
        vec2 chromatic_x = vec2(chromatic, 0.0) / resolution.x;
        vec2 chromatic_y = vec2(0.0, chromatic / 2.0) / resolution.y;
        float r = Tri(pos - chromatic_x).r;
        float g = Tri(pos + chromatic_y).g;
        float b = Tri(pos + chromatic_x).b;
        clr = vec3(r, g, b);
    }

    if (grille_amount > 0.0) clr *= grille(uv);

    clr *= 1.0 + scan_line_amount * 0.6 + line * 3.0 + grille_amount * 2.0;

    // Dark scanlines to restore the classic look
    if (enable_dark_scanlines > 0.5) {
        float scan = sin(uv.y * scanline_density * 3.14159);
        float mask = mix(1.0, 0.25, smoothstep(0.0, 1.0, scan * scan));
        clr *= mix(1.0, mask, scanline_intensity);
    }

    // Bloom
    if (enable_bloom > 0.5) {
        vec3 bright = max(clr - 0.7, 0.0);
        vec3 blurred = bloom_sample(uv, bloom_radius);
        clr += blurred * bloom_strength;
    }

    if (vignette_amount > 0.0) clr *= vignette(pos);

    finalColor = vec4(clr, 1.0) * fragColor * colDiffuse;
}
