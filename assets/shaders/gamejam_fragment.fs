#version 330 core
precision mediump float;

in vec2    fragTexCoord;
in vec4    fragColor;

out vec4 finalColor;

uniform sampler2D texture0;    // Atlas texture
uniform vec2      uImageSize;  // Atlas dimensions (px)
uniform vec4      uGridRect; // x,y = top-left (px), z,w = size (px)

uniform float dissolve;
uniform float time;
uniform vec4 texture_details;  // can remove?
uniform vec2  image_details; // can remove?
uniform bool  shadow;
uniform vec4 burn_colour_1;
uniform vec4 burn_colour_2;

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
// Sprite-local UV helper
vec2 getSpriteUV(vec2 uv) {
    // uv in [0..1] over the full atlas
    vec2 pixelUV   = uv * uImageSize;
    vec2 spriteLoc = pixelUV - uGridRect.xy;
    return spriteLoc / uGridRect.zw;
}

//────────────────────────────────────────────────────────
// Dissolve mask (unchanged)
vec4 dissolve_mask(vec4 tex, vec2 /*texcoord*/, vec2 uv_scaled) {
    if (dissolve < 0.001) {
        return vec4(
            shadow ? vec3(0.0) : tex.rgb,
            shadow ? tex.a * 0.3 : tex.a
        );
    }
    float adj = (dissolve*dissolve*(3.0 - 2.0*dissolve))*1.02 - 0.01;
    float t   = time * 10.0 + 2003.0;

    vec2 floored = floor(uv_scaled * texture_details.zw)
                 / max(texture_details.z, texture_details.w);
    vec2 uv_s     = (floored - 0.5) * 2.3
                  * max(texture_details.z, texture_details.w);

    vec2 f1 = uv_s + 50.0 * vec2(sin(-t/143.634), cos(-t/99.4324));
    vec2 f2 = uv_s + 50.0 * vec2(cos(t/53.1532), cos(t/61.4532));
    vec2 f3 = uv_s + 50.0 * vec2(sin(-t/87.53218), sin(-t/49.0));

    float field = (1.0 + (
        cos(length(f1)/19.483) +
        sin(length(f2)/33.155) * cos(f2.y/15.73) +
        cos(length(f3)/27.193) * sin(f3.x/21.92)
    )) * 0.5;

    vec2 borders = vec2(0.2, 0.8);
    float res = (0.5 + 0.5*cos(adj/82.612 + (field - 0.5)*3.14159))
        - (floored.x > borders.y ? (floored.x - borders.y)*(5.0+5.0*dissolve) : 0.0)*dissolve
        - (floored.y > borders.y ? (floored.y - borders.y)*(5.0+5.0*dissolve) : 0.0)*dissolve
        - (floored.x < borders.x ? (borders.x - floored.x)*(5.0+5.0*dissolve) : 0.0)*dissolve
        - (floored.y < borders.x ? (borders.x - floored.y)*(5.0+5.0*dissolve) : 0.0)*dissolve;

    if (tex.a > 0.01 && burn_colour_1.a > 0.01 && !shadow
        && res < adj + 0.8*(0.5 - abs(adj - 0.5))
        && res > adj) {
        if (res < adj + 0.5*(0.5 - abs(adj - 0.5))) {
            tex = burn_colour_1;
        } else if (burn_colour_2.a > 0.01) {
            tex = burn_colour_2;
        }
    }

    return vec4(
        shadow ? vec3(0.0) : tex.rgb,
        res > adj
            ? (shadow ? tex.a * 0.3 : tex.a)
            : 0.0
    );
}

//────────────────────────────────────────────────────────
// HSV-style palette & plot helper
vec3 pal(in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d) {
    return a + b * cos(6.28318 * (c * t + d));
}
float plot(float r, float pct) {
    return smoothstep(pct - 0.2, pct, r)
         - smoothstep(pct, pct + 0.2, r);
}

//────────────────────────────────────────────────────────
void main() {
    // 1) Compute sprite-local UV
    vec2 spriteUV  = getSpriteUV(fragTexCoord);
    // 2) Sample atlas
    vec4 tex       = texture(texture0, spriteUV);

    // 3) Now run Reva’s radial shimmer in place of the old foil logic:
    //    — “uv” for Reva is FULLSCREEN UV [0..1], but since we want it to
    //      track the sprite’s center, we can remap spriteUV back into [0..1]:
    vec2 uv        = spriteUV;
    //    — aspect correction from atlas-to-screen:
    vec2 pos       = vec2(0.5) - uv;
    pos.x         *= (uImageSize.x / uGridRect.z) 
                   / (uImageSize.y / uGridRect.w);
    pos          *= cos(time) + 1.5;

    float r        = length(pos) * 2.0;
    float a        = atan(pos.y, pos.x);
    float f        = abs(cos(a * 2.5 + time * 0.5))
                   * sin(time * 2.0) * 0.698
                   + cos(time) - 4.0;
    float d        = f - r;

    // glow bands
    vec3 bandColor = (vec3(
                         smoothstep(fract(d), fract(d) - 0.200, 0.160))
                     - vec3(
                         smoothstep(fract(d), fract(d) - 1.184, 0.160)))
                   * pal(f,
                         vec3(0.725,0.475,0.440),
                         vec3(0.605,0.587,0.007),
                         vec3(1.0,1.0,1.0),
                         vec3(0.310,0.410,0.154));

    // ring pulse
    float pct     = plot(r * 0.272, fract(d * (sin(time)*0.45 + 0.5)));
    vec3 ringColor = pct * pal(r,
                               vec3(0.750,0.360,0.352),
                               vec3(0.450,0.372,0.271),
                               vec3(0.540,0.442,0.264),
                               vec3(0.038,0.350,0.107));
    
    // throw away negative values
    bandColor = max(bandColor, vec3(0.0));
    ringColor = max(ringColor, vec3(0.0));

    vec3 foilColor = bandColor + ringColor;
    // blend shimmer onto the sprite
    // tex.rgb        = mix(tex.rgb, foilColor, 0.5);
    
    float shimmerStrength = 0.7; // Adjust this value to control shimmer intensity
    
    float minAlpha = 0.0;         // e.g. 0.2 → fully faded where there’s no shimmer
    float maxAlphaModifier = 0.99; // e.g. 1.0 → full α×1.0 where shimmer is strong

    
    // compute how “bright” the shimmer is
    float shimmerLum = max(max(foilColor.r, foilColor.g), foilColor.b);

    // new “bite-sharpened” mask
    float maskLow   = 0.35;             // nothing under 0.25 even starts
    float maskHigh  = 0.99;             // full strength by 0.85
    float rawMask   = smoothstep(maskLow, maskHigh, shimmerLum);
    // optional gamma-sharpen:
    float mask2     = pow(rawMask, 2.0);
    
    // lighten
    // vec3 shimmer = foilColor * shimmerStrength * mask;
    // tex.rgb = 1.0 - (1.0 - tex.rgb) * (1.0 - shimmer);
    
    // throw away small values
    float colorFloor = 0.1;            // tune this up to cut out more low-level shimmer
    vec3 hpFoil = max(foilColor - vec3(colorFloor), vec3(0.0));

    // build shimmer from the high-passed color
    vec3 shimmer    = hpFoil * shimmerStrength * mask2;
    tex.rgb         = max(tex.rgb, shimmer);
    
    // screen blend
    // vec3 shimmer = foilColor * shimmerStrength * mask;
    // tex.rgb = max(tex.rgb, shimmer);
    
    // only blend where mask > 0
    // tex.rgb = mix(tex.rgb, foilColor, shimmerStrength * mask);
    
    
    // tex.a         *= 0.9 + 0.1 * pct;
    
    // original sprite α
    float baseA = tex.a;

    // compute a per-pixel α between minAlpha and baseA*maxAlphaModifier,
    // driven by your shimmer mask [0..1]
    float alpha = mix(
        minAlpha,             // mask=0 → fully faded
        baseA * maxAlphaModifier,  // mask=1 → full α (or even boosted)
        mask2
    );

    tex.a = alpha;

    // 4) Finally, hand off into your existing dissolve_mask
    //    (we pass spriteUV and uv_scaled == spriteUV so that border/noise
    //     logic still uses per-sprite coords)
    finalColor = dissolve_mask(tex, spriteUV, spriteUV);
}
