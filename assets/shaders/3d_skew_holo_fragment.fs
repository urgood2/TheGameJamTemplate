#version 330 core
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform vec2 regionRate;
uniform vec2 pivot;

flat in vec2 tiltSin;
flat in vec2 tiltCos;
flat in float angleFlat;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float fov;
uniform float cull_back;
uniform float rand_trans_power;
// Per-card random seed for unique overlay variations
// Expected range: [0.0, 1.0]
// Used to offset animation phases, noise patterns, and color variations
// so that cards with the same effect type don't look identical
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
uniform vec2  holo;

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
    vec4 tex = texture(texture0, uv);
    vec3 rgb = tex.rgb * fragColor.rgb * colDiffuse.rgb;
    float alpha = tex.a * fragColor.a * colDiffuse.a;
    return vec4(rgb, alpha);
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

    // Holographic overlay: hue shift plus grid shimmer driven by holo vector.
    vec2 uv = ((sampleUV * image_details) - texture_details.xy * texture_details.ba) / texture_details.ba;
    vec4 hsl = HSL(0.5 * base + 0.5 * vec4(0.0, 0.0, 1.0, base.a));

    float t = holo.y * 7.221 + time;
    // Per-card seed offsets for unique holographic patterns
    float seedPhase = rand_seed * 6.2831;
    float seedOffset = rand_seed * 50.0;

    vec2 floored_uv = floor(uv * texture_details.ba) / texture_details.ba;
    // Apply card rotation so the holographic pattern responds to the card's visual orientation
    vec2 rotated_uv = rotate2d(card_rotation) * (floored_uv - 0.5) + 0.5;
    vec2 uv_scaled_centered = (rotated_uv - 0.5) * 250.0 + vec2(seedOffset * 0.3, seedOffset * 0.5);

    vec2 field_part1 = uv_scaled_centered + 50.0 * vec2(sin(-t / 143.6340 + seedPhase * 0.3), cos(-t / 99.4324 + seedPhase * 0.5));
    vec2 field_part2 = uv_scaled_centered + 50.0 * vec2(cos(t / 53.1532 + seedPhase * 0.7), cos(t / 61.4532 + seedPhase * 0.4));
    vec2 field_part3 = uv_scaled_centered + 50.0 * vec2(sin(-t / 87.53218 + seedPhase * 0.6), sin(-t / 49.0000 + seedPhase * 0.8));

    float field = (1.0 + (
        cos(length(field_part1) / 19.483 + seedPhase * 0.2) +
        sin(length(field_part2) / 33.155 + seedPhase * 0.15) * cos(field_part2.y / 15.73) +
        cos(length(field_part3) / 27.193 + seedPhase * 0.25) * sin(field_part3.x / 21.92))) * 0.5;

    float res = 0.5 + 0.5 * cos(holo.x * 2.612 + rand_seed * 0.5 + (field - 0.5) * 3.14);

    float low = min(base.r, min(base.g, base.b));
    float high = max(base.r, max(base.g, base.b));
    float delta = 0.2 + 0.3 * (high - low) + 0.1 * high;

    float gridsize = 0.79;
    // Add seed-based offset to grid pattern for per-card variation
    float gridSeedOffset = rand_seed * 3.14159;
    // Use rotated UV for the grid so it responds to card rotation
    float fac = 0.5 * max(
        max(max(0.0, 7.0 * abs(cos(rotated_uv.x * gridsize * 20.0 + gridSeedOffset)) - 6.0),
            max(0.0, 7.0 * cos(rotated_uv.y * gridsize * 45.0 + rotated_uv.x * gridsize * 20.0 + gridSeedOffset * 1.3) - 6.0)),
        max(0.0, 7.0 * cos(rotated_uv.y * gridsize * 45.0 - rotated_uv.x * gridsize * 20.0 + gridSeedOffset * 0.7) - 6.0));

    hsl.x = hsl.x + res + fac;
    hsl.y = hsl.y * 1.3;
    hsl.z = hsl.z * 0.6 + 0.4;

    vec3 holoColor = RGB(hsl).rgb;
    vec3 mixed = (1.0 - delta) * base.rgb + delta * holoColor * vec3(0.9, 0.8, 1.2);

    float edgeMask = mix(0.35, 1.0, smoothstep(0.08, 0.62, length(clampedLocal - 0.5)));
    float overlayMask = clamp(abs(grain_intensity) + abs(sheen_strength), 0.0, 1.0) * edgeMask;

    vec3 lit = mix(base.rgb, mixed, overlayMask);
    lit = clamp(lit * material_tint, 0.0, 1.0);
    float alpha = base.a;

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
    float angle = angleFlat;

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
        float cosX = tiltCos.x;
        float cosY = tiltCos.y;
        float sinX = tiltSin.x;
        float sinY = tiltSin.y;

        vec2 centered = (uv - pivot) / regionRate;
        vec2 localCentered = centered - vec2(0.5);
        vec2 correctedUV = localCentered;
        correctedUV.x /= max(cosY, 0.5);
        correctedUV.y /= max(cosX, 0.5);
        correctedUV.x -= sinY * 0.1;
        correctedUV.y -= sinX * 0.1;
        uv = correctedUV + vec2(0.5);

        float asp = regionRate.y / regionRate.x;
        uv.y *= asp;

        uv = rotate(uv, vec2(0.5), angle);
        uv.y /= asp;

        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) discard;

        vec2 finalUV = pivot + uv * regionRate;
        finalColor = applyOverlay(finalUV);
    }
}
