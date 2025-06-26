#version 330 core
precision highp float;

in vec2    fragTexCoord;
in vec4    fragColor;

out vec4 finalColor;

uniform sampler2D texture0;     // Atlas texture
uniform vec2      uImageSize;   // Atlas dimensions (px)
uniform vec4      uGridRect;    // x,y = top-left (px), z,w = size (px)

// new tunable uniforms
uniform float stripeFreq;       // how many stripes across the sprite
uniform float waveFreq;         // how “wavy” each stripe is
uniform float waveAmp;          // how far stripes deviate
uniform float waveSpeed;        // how fast they slide
uniform float stripeWidth;      // width of each stripe

uniform vec2  polychrome;       // .x = base hue phase, .y = hue drift speed
uniform float time;

//────────────────────────────────────────────────────────
// HSL ↔ RGB helpers  (unchanged)
float hue(float s, float t, float h) {
    float hs = mod(h,1.0)*6.0;
    if (hs < 1.0) return (t - s)*hs + s;
    if (hs < 3.0) return t;
    if (hs < 4.0) return (t - s)*(4.0 - hs) + s;
    return s;
}
vec4 RGB(vec4 c) {
    if (c.y < 0.0001) return vec4(vec3(c.z), c.a);
    float tt = (c.z < 0.5) ? c.y*c.z + c.z : -c.y*c.z + (c.y + c.z);
    float ss = 2.0*c.z - tt;
    return vec4(
        hue(ss,tt,c.x + 1.0/3.0),
        hue(ss,tt,c.x),
        hue(ss,tt,c.x - 1.0/3.0),
        c.w
    );
}
vec4 HSL(vec4 c) {
    float low = min(c.r, min(c.g, c.b));
    float high = max(c.r, max(c.g, c.b));
    float d = high - low;
    float sum = high + low;
    vec4 hsl = vec4(0.0, 0.0, 0.5 * sum, c.a);
    if (d == 0.0) return hsl;
    hsl.y = (hsl.z < 0.5) ? d / sum : d / (2.0 - sum);
    if      (high == c.r) hsl.x = (c.g - c.b) / d;
    else if (high == c.g) hsl.x = (c.b - c.r) / d + 2.0;
    else                  hsl.x = (c.r - c.g) / d + 4.0;
    hsl.x = mod(hsl.x / 6.0, 1.0);
    return hsl;
}

//────────────────────────────────────────────────────────
// Sprite-local UV helper (unchanged)
vec2 getSpriteUV(vec2 uv) {
    vec2 pixelUV   = uv * uImageSize;
    vec2 spriteLoc = pixelUV - uGridRect.xy;
    return spriteLoc / uGridRect.zw;
}

//────────────────────────────────────────────────────────
// HSV-style palette & plot helper (unchanged)
vec3 pal(in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d) {
    return a + b * cos(6.28318 * (c * t + d));
}

void main() {
    // 1) sprite‐local UV & sample
    vec2  spriteUV = getSpriteUV(fragTexCoord);
    vec4  srcColor = texture(texture0, spriteUV);

    // 2) wavy offset
    float yOffset = sin(spriteUV.y * waveFreq + time * waveSpeed) * waveAmp;

    // 3) stripe coord
    float coord = fract(spriteUV.x * stripeFreq + yOffset);

    // 4) stripe mask
    float m0   = smoothstep(0.5 - stripeWidth * 0.5, 0.5, coord);
    float m1   = smoothstep(0.5, 0.5 + stripeWidth * 0.5, coord);
    float mask = m0 - m1;

    // 5) compute rainbow phase & lookup
    float phase = mask + polychrome.x + time * polychrome.y;
    vec3  rainbow = pal(
        phase,
        vec3(0.5),           // base offset
        vec3(0.5),           // amplitude
        vec3(1.0),           // frequency
        vec3(0.0,0.33,0.67)  // R/G/B phase
    );

    // 6) composite
    vec3 outRgb = mix(srcColor.rgb, rainbow, mask);
    finalColor = vec4(outRgb, srcColor.a);
}