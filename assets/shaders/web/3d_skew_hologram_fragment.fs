#version 300 es
precision mediump float;

precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform vec2 regionRate;
uniform vec2 pivot;

in mat3 invRotMat;
in vec2 worldMouseUV;
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
vec2 rotate(vec2 uv, vec2 pivot, float angle)
{
    float s = sin(angle);
    float c = cos(angle);
    uv -= pivot;
    uv = vec2(
        c * uv.x - s * uv.y,
        s * uv.x + c * uv.y
    );
    uv += pivot;
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

    float progress = clamp(dissolve, 0.0, 1.0);
    vec2 localUV = getSpriteUV(atlasUV);
    vec2 centered = localUV - 0.5;
    float dist = length(centered);
    vec2 dir = dist > 0.0001 ? centered / dist : vec2(0.0);

    vec2 displaced = centered + dir * progress * spread_strength;
    displaced += distortion_strength * vec2(
        sin(dist * 20.0 - time * 10.0),
        cos(dist * 20.0 - time * 8.0)
    ) * progress;

    vec2 warpedLocal = displaced + vec2(0.5);
    vec2 clampedLocal = clamp(warpedLocal, 0.0, 1.0);

    vec2 sampleUV = localToAtlas(clampedLocal);
    vec4 base = sampleTinted(sampleUV);

    vec2 rotated = rotate2d(card_rotation) * (clampedLocal - 0.5);

    // Hologram overlay: animated scan lines + shimmer, respecting the existing dissolve warp.
    float lineFreq = max(40.0, abs(grain_scale) * 90.0);
    float linePhase = time * (1.2 * abs(sheen_speed) + 0.6) + card_rotation * 0.6;
    float scanLines = 0.5 + 0.5 * sin(rotated.y * lineFreq + linePhase);

    float diagSweep = 0.5 + 0.5 * sin(dot(rotated, normalize(vec2(0.7, 1.3))) * 32.0 + time * 1.4);
    float noiseVal = hash21(rotated * (80.0 + abs(grain_scale) * 50.0) + time * 0.6);
    float glitch = step(0.82, noiseVal); // occasional stutters
    float flicker = 0.4 + 0.6 * abs(sin(time * (1.0 + abs(sheen_speed) * 0.5) + rand_seed * 2.1));

    float edgeMask = mix(0.35, 1.0, smoothstep(0.08, 0.62, length(clampedLocal - 0.5)));

    float holoMask = (scanLines * 0.6 + diagSweep * 0.4);
    holoMask *= (0.7 + 0.3 * noiseVal);
    holoMask = mix(holoMask, 1.0 - holoMask, glitch * 0.35);
    holoMask *= flicker * edgeMask;
    float overlayMask = clamp(holoMask * abs(grain_intensity), 0.0, 1.0);

    vec3 holoTint = mix(vec3(0.08, 0.85, 1.05), material_tint, 0.4);
    vec3 shifted = vec3(
        texture(texture0, sampleUV + vec2(0.0015, 0.0)).r,
        texture(texture0, sampleUV + vec2(-0.0010, 0.0007)).g,
        texture(texture0, sampleUV + vec2(0.0, -0.0012)).b
    );
    vec3 baseColor = mix(base.rgb, shifted, 0.25);

    float intensity = 0.35 + 0.65 * abs(sheen_strength);
    vec3 lit = clamp(baseColor + holoTint * overlayMask * intensity, 0.0, 1.0);
    lit = clamp(lit * (1.0 + overlayMask * 0.12), 0.0, 1.0);

    float alphaFactor = 1.0 - smoothstep(fade_start, 1.0, progress);
    float alpha = base.a * alphaFactor;

    float edgeDistance = length(warpedLocal - clampedLocal);
    float burnMask = smoothstep(0.0, 0.02, edgeDistance) * (1.0 - alphaFactor);

    if (!shadow && burn_colour_1.a > 0.01) {
        vec3 burnMix = burn_colour_1.rgb;
        if (burn_colour_2.a > 0.01) {
            float t = clamp(edgeDistance / 0.04, 0.0, 1.0);
            burnMix = mix(burn_colour_1.rgb, burn_colour_2.rgb, t);
        }
        lit = mix(lit, burnMix, clamp(burnMask * burn_colour_1.a, 0.0, 1.0));
    }

    if (shadow) {
        return vec4(vec3(0.0), alpha * 0.35);
    }

    return vec4(lit, alpha);
}

void main()
{
    vec2 uv = fragTexCoord;
    float t = tan(radians(fov) / 2.0);
    vec2 centered = (uv - pivot) / regionRate;

    vec3 p = invRotMat * vec3(centered - 0.5, 0.5 / t);
    float v = (0.5 / t) + 0.5;
    p.xy *= v * invRotMat[2].z;
    vec2 o = v * invRotMat[2].xy;

    if (cull_back > 0.5 && p.z <= 0.0) discard;

    uv = (p.xy / p.z) - o + 0.5;

    float asp = regionRate.y / regionRate.x;
    uv.y *= asp;

    float angle = angleFlat;
    uv = rotate(uv, vec2(0.5), angle);
    uv.y /= asp;

    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) discard;

    vec2 finalUV = pivot + uv * regionRate;

    finalColor = applyOverlay(finalUV);
}
