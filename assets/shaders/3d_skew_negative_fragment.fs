#version 330 core
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform vec2 regionRate;
uniform vec2 pivot;

in mat3 invRotMat;
in vec2 worldMouseUV;
in vec2 tiltAmount;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float fov;
uniform float cull_back;
uniform float rand_trans_power;
uniform float rand_seed;
uniform float rotation;
uniform float iTime;
uniform float uv_passthrough;

uniform vec2 uImageSize;
uniform vec4 uGridRect;

uniform float dissolve;
uniform float time;
uniform vec4 texture_details;
uniform vec2 image_details;
uniform bool shadow;
uniform vec4 burn_colour_1;
uniform vec4 burn_colour_2;

uniform float card_rotation;
uniform vec3  material_tint;
uniform float grain_intensity;
uniform float grain_scale;
uniform float sheen_strength;
uniform float sheen_width;
uniform float sheen_speed;
uniform float noise_amount;
uniform float spread_strength;
uniform float distortion_strength;
uniform float fade_start;
uniform vec2  negative;

out vec4 finalColor;

// 2D rotation helper
vec2 rotate(vec2 uv, vec2 pivotPt, float angle)
{
    float s = sin(angle);
    float c = cos(angle);
    uv -= pivotPt;
    uv = vec2(
        c * uv.x - s * uv.y,
        s * uv.x + c * uv.y
    );
    uv += pivotPt;
    return uv;
}

vec2 getSpriteUV(vec2 uv) {
    vec2 pixelUV   = uv * uImageSize;
    vec2 spriteLoc = pixelUV - uGridRect.xy;
    return spriteLoc / uGridRect.zw;
}

vec2 localToAtlas(vec2 localUV) {
    return (uGridRect.xy + localUV * uGridRect.zw) / uImageSize;
}

mat2 rotate2d(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

vec4 sampleTinted(vec2 uv) {
    return texture(texture0, uv) * fragColor * colDiffuse;
}

float hue(float s, float t, float h) {
    float hs = mod(h, 1.0) * 6.0;
    if (hs < 1.0) return (t - s) * hs + s;
    if (hs < 3.0) return t;
    if (hs < 4.0) return (t - s) * (4.0 - hs) + s;
    return s;
}

vec4 RGB(vec4 c) {
    if (c.y < 0.0001) {
        return vec4(vec3(c.z), c.a);
    }
    float t = (c.z < 0.5) ? c.y * c.z + c.z : -c.y * c.z + (c.y + c.z);
    float s = 2.0 * c.z - t;
    return vec4(hue(s, t, c.x + 1.0 / 3.0),
                hue(s, t, c.x),
                hue(s, t, c.x - 1.0 / 3.0),
                c.w);
}

vec4 HSL(vec4 c) {
    float low = min(c.r, min(c.g, c.b));
    float high = max(c.r, max(c.g, c.b));
    float delta = high - low;
    float sum = high + low;

    vec4 hsl = vec4(0.0, 0.0, 0.5 * sum, c.a);
    if (delta == 0.0) {
        return hsl;
    }

    hsl.y = (hsl.z < 0.5) ? delta / sum : delta / (2.0 - sum);

    if (high == c.r) {
        hsl.x = (c.g - c.b) / delta;
    } else if (high == c.g) {
        hsl.x = (c.b - c.r) / delta + 2.0;
    } else {
        hsl.x = (c.r - c.g) / delta + 4.0;
    }

    hsl.x = mod(hsl.x / 6.0, 1.0);
    return hsl;
}

vec4 applyOverlay(vec2 atlasUV) {
    const float EPS = 0.0001;
    bool effectInactive =
        abs(dissolve) < EPS &&
        abs(grain_intensity) < EPS &&
        abs(sheen_strength) < EPS &&
        burn_colour_1.a < EPS &&
        burn_colour_2.a < EPS &&
        !shadow &&
        length(material_tint - vec3(1.0)) < EPS;

    if (effectInactive) {
        return sampleTinted(atlasUV);
    }

    // Godot-style dissolve: push pixels outward with wobble, then fade alpha.
    float progress = clamp(dissolve, 0.0, 1.0);
    vec2 localUV = getSpriteUV(atlasUV);
    vec2 centered = localUV - 0.5;
    float dist = length(centered);
    vec2 dir = dist > 0.0001 ? centered / dist : vec2(0.0);

    vec2 uvOutward = centered + dir * progress * spread_strength;
    uvOutward += distortion_strength * vec2(
        sin(dist * 20.0 - time * 10.0),
        cos(dist * 20.0 - time * 8.0)
    ) * progress;

    vec2 warpedLocal = uvOutward + vec2(0.5);
    vec2 sampleUV = localToAtlas(warpedLocal);
    vec4 base = sampleTinted(sampleUV);

    vec2 clampedLocal = clamp(warpedLocal, 0.0, 1.0);
    vec2 rotated = rotate2d(card_rotation) * (clampedLocal - 0.5);

    // Negative shine overlay: inverted tint with animated sine fields.
    vec2 uv = ((sampleUV * image_details) - texture_details.xy * texture_details.ba) / texture_details.ba;
    vec2 adjusted_uv = uv - vec2(0.5);
    adjusted_uv.x *= texture_details.b / texture_details.a;

    float low = min(base.r, min(base.g, base.b));
    float high = max(base.r, max(base.g, base.b));
    float delta = high - low - 0.1;

    float fac = 0.8 + 0.9 * sin(11.0 * uv.x + 4.32 * uv.y + negative.x * 12.0 + cos(negative.x * 5.3 + uv.y * 4.2 - uv.x * 4.0));
    float fac2 = 0.5 + 0.5 * sin(8.0 * uv.x + 2.32 * uv.y + negative.x * 5.0 - cos(negative.x * 2.3 + uv.x * 8.2));
    float fac3 = 0.5 + 0.5 * sin(10.0 * uv.x + 5.32 * uv.y + negative.x * 6.111 + sin(negative.x * 5.3 + uv.y * 3.2));
    float fac4 = 0.5 + 0.5 * sin(3.0 * uv.x + 2.32 * uv.y + negative.x * 8.111 + sin(negative.x * 1.3 + uv.y * 11.2));
    float fac5 = sin(0.9 * 16.0 * uv.x + 5.32 * uv.y + negative.x * 12.0 + cos(negative.x * 5.3 + uv.y * 4.2 - uv.x * 4.0));

    float maxfac = 0.7 * max(max(fac, max(fac2, max(fac3, 0.0))) + (fac + fac2 + fac3 * fac4), 0.0);

    vec3 inverted = base.rgb * 0.5 + vec3(0.4, 0.4, 0.8);
    vec3 negColor = vec3(
        inverted.r - delta + delta * maxfac * (0.7 + fac5 * 0.27) - 0.1,
        inverted.g - delta + delta * maxfac * (0.7 - fac5 * 0.27) - 0.1,
        inverted.b - delta + delta * maxfac * 0.7 - 0.1
    );

    float edgeMask = mix(0.35, 1.0, smoothstep(0.08, 0.62, length(clampedLocal - 0.5)));
    float overlayMask = clamp(abs(grain_intensity) + abs(sheen_strength), 0.0, 1.0) * edgeMask;

    vec3 lit = mix(base.rgb, negColor, overlayMask);
    lit = clamp(lit * material_tint, 0.0, 1.0);
    float alpha = base.a * (0.5 * clamp(max(0.0, 0.3 * max(low * 0.2, delta) + min(max(maxfac * 0.1, 0.0), 0.4)), 0.0, 1.0)
                            + 0.15 * maxfac * (0.1 + delta));

    float alphaFactor = 1.0 - smoothstep(fade_start, 1.0, progress);
    alpha *= alphaFactor;

    if (shadow) {
        return vec4(vec3(0.0), alpha * 0.35);
    }

    return vec4(lit, alpha);
}

void main()
{
    vec2 uv = fragTexCoord;

    bool identityAtlas = abs(regionRate.x - 1.0) < 0.0001 &&
                         abs(regionRate.y - 1.0) < 0.0001 &&
                         abs(pivot.x) < 0.0001 &&
                         abs(pivot.y) < 0.0001;

    // Apply ambient jitter to all passes (including text) so overlay text follows card wobble.
    float jitter = rand_trans_power * 0.05 *
        sin(iTime * (0.9 + mod(rand_seed, 0.5)) + rand_seed * 123.8985);
    float angle = rotation + jitter;

    if (identityAtlas || uv_passthrough > 0.5) {
        // Passthrough: rely on vertex-stage skew for motion; clamp UVs to stay inside
        // the intended region (identity or atlas sub-rect). Apply the ambient
        // rotation jitter so text/stickers follow rand_trans_power motion.
        vec2 rotated = rotate(uv, vec2(0.5), angle);

        float inset = 0.0035; // tiny padding to reduce bleed
        vec2 clamped = clamp(rotated, vec2(inset), vec2(1.0 - inset));
        vec2 finalUV = identityAtlas
            ? clamped
            : (pivot + clamped * regionRate);
        finalColor = applyOverlay(finalUV);
    } else {
        // Full atlas-aware path for sprites.
        float tiltStrength = abs(fov) * 2.0;
        float tiltX = tiltAmount.y * tiltStrength;
        float tiltY = tiltAmount.x * tiltStrength;
        float cosX = cos(tiltX);
        float cosY = cos(tiltY);

        vec2 centered = (uv - pivot) / regionRate;
        vec2 localCentered = centered - vec2(0.5);
        vec2 correctedUV = localCentered;
        correctedUV.x /= max(cosY, 0.5);
        correctedUV.y /= max(cosX, 0.5);
        correctedUV.x -= sin(tiltY) * 0.1;
        correctedUV.y -= sin(tiltX) * 0.1;
        uv = correctedUV + vec2(0.5);

        float asp = regionRate.y / regionRate.x;
        uv.y *= asp;

        float angle = rotation + rand_trans_power * 0.05 *
            sin(iTime * (0.9 + mod(rand_seed, 0.5)) + rand_seed * 123.8985);
        uv = rotate(uv, vec2(0.5), angle);
        uv.y /= asp;

        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) discard;

        vec2 finalUV = pivot + uv * regionRate;
        finalColor = applyOverlay(finalUV);
    }
}
