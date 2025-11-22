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

// add these uniforms up top:
uniform float circleFreq;     // controls spacing of rings
uniform float noiseScale;     // scale of the 2D noise sampling
uniform float noiseAmp;       // how much the noise perturbs the radius
uniform float noiseSpeed;     // how fast the noise field drifts
uniform vec2 noisePan;    // e.g. in [−1..1] UV units or noise units


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

float hash(vec2 p) { p = fract(p*vec2(123.34, 456.21)); p += dot(p, p+45.32); return fract(p.x*p.y); }
float noise2d(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    // four corners
    float a = hash(i);
    float b = hash(i+vec2(1,0));
    float c = hash(i+vec2(0,1));
    float d = hash(i+vec2(1,1));
    // smooth interpolation
    vec2 u = f*f*(3.0-2.0*f);
    return mix(a, b, u.x) + (c - a)*u.y*(1.0 - u.x) + (d - b)*u.x*u.y;
}

void main() {
    vec2 uv    = getSpriteUV(fragTexCoord);
    vec4 src   = texture(texture0, uv);

    // compute a perturbed radius
    // adjust for non‐square sprites if needed
    float aspect = uImageSize.x/uImageSize.y;
    vec2  centered = (uv - 0.5) * vec2(aspect, 1.0);

    float baseR = length(centered);
    // sample noise field
    // new:
    float n = noise2d(
        centered * noiseScale
    + noisePan              // <-- pan offset
    + time * noiseSpeed
    );
    float perturbedR = baseR + (n - 0.5) * noiseAmp;

    // turn that into a ring pattern
    float ring = fract(perturbedR * circleFreq);

    // mask for the ring (soft edges)
    float m0 = smoothstep(0.5 - stripeWidth*0.5, 0.5, ring);
    float m1 = smoothstep(0.5, 0.5 + stripeWidth*0.5, ring);
    float mask = m0 - m1;

    // hue phase & lookup (unchanged)
    float phase = mask + polychrome.x + time * polychrome.y;
    vec3  rainbow = pal(phase, vec3(0.5), vec3(0.5), vec3(1.0), vec3(0.0,0.33,0.67));

    // blend as before
    float blendStrength = 0.4; // default blend strength
    float finalMask = mask * blendStrength;
    vec3 outRgb = mix(src.rgb, rainbow, finalMask);

    finalColor = vec4(outRgb, src.a);
}