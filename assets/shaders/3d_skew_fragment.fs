#version 330 core
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform vec2 regionRate;
uniform vec2 pivot;

in mat3 invRotMat;
in vec2 worldMouseUV;
flat in vec2 tiltSin;
flat in vec2 tiltCos;
flat in float angleFlat;

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

    float stripeFreq = max(6.0, abs(grain_scale) * 55.0);
    float brushedA = sin(rotated.x * stripeFreq + time * 0.6);
    float brushedB = sin((rotated.x + rotated.y * 0.35) * (stripeFreq * 0.35) - time * 0.8);
    float grain = 0.5 + 0.5 * (0.65 * brushedA + 0.35 * brushedB);

    float grainNoise = hash21(rotated * (grain_scale * 90.0 + 1.0) + time * 0.15);
    grain = mix(grain, grain * (0.6 + 0.8 * grainNoise), clamp(noise_amount, 0.0, 1.0));

    float sweepAxis = dot(rotated, normalize(vec2(0.6, 1.0)));
    float sweepTravel = sin(time * sheen_speed + card_rotation * 0.5) * 0.35;
    float bandWidth = max(0.02, sheen_width);
    float sweepMask = exp(-pow((sweepAxis - sweepTravel) / bandWidth, 2.0));
    float ribbon = 0.5 + 0.5 * cos((rotated.y + rotated.x * 0.75) * 18.0 + time * 1.4);
    float sheen = sweepMask * ribbon;

    float edgeMask = mix(0.35, 1.0, smoothstep(0.08, 0.62, length(clampedLocal - 0.5)));

    float foilStrength = abs(grain_intensity) * grain + abs(sheen_strength) * sheen;
    float overlayMask = clamp(foilStrength, 0.0, 1.0) * edgeMask;

    float rotMod = sin(card_rotation * 4.0) * 0.35 + sin(card_rotation * 8.0) * 0.15;
    float brightness = ((grain - 0.5) * 0.4 + (sheen - 0.5) * 0.25 + rotMod * 0.35) * overlayMask;
    float factor = clamp(1.0 + brightness, 0.85, 1.15);
    float detail = ((grain - 0.5) + rotMod * 0.5) * 0.06 * overlayMask;

    vec3 lit = clamp(base.rgb * factor + vec3(detail), 0.0, 1.0);
    lit = clamp(lit * material_tint, 0.0, 1.0);

    float alphaFactor = 1.0 - smoothstep(fade_start, 1.0, progress);
    float alpha = base.a * alphaFactor;

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
