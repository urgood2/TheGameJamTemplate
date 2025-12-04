#version 300 es
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform sampler2D texture0;
uniform vec2 uImageSize;
uniform vec4 uGridRect;

uniform float dissolve;    // Drives the collapse (0 → 1)
uniform float time;
uniform vec4 texture_details; // kept for uniform parity
uniform vec2 image_details;   // kept for uniform parity
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

void main() {
    // --- Collapse UVs (vacuum_collapse-inspired) ---
    float progress = clamp(dissolve, 0.0, 1.0);
    vec2 localUV = getSpriteUV(fragTexCoord);
    vec2 centered = localUV - 0.5;
    float dist = length(centered);
    vec2 dir = dist > 0.0001 ? centered / dist : vec2(0.0);

    const float SPREAD = 0.85;
    const float WOBBLE = 0.035;
    const float FADE_START = 0.45;

    vec2 displaced = centered + dir * progress * SPREAD;
    displaced += WOBBLE * vec2(
        sin(dist * 20.0 - time * 10.0),
        cos(dist * 20.0 - time * 8.0)
    ) * progress;

    vec2 warpedLocal = displaced + vec2(0.5);
    vec2 clampedLocal = clamp(warpedLocal, 0.0, 1.0);
    float inside = step(0.0, warpedLocal.x) * step(warpedLocal.x, 1.0) *
                   step(0.0, warpedLocal.y) * step(warpedLocal.y, 1.0);

    vec2 sampleUV = localToAtlas(clampedLocal);
    vec4 base = texture(texture0, sampleUV);

    // --- Material sheen / foil look ---
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

    vec4 tex = vec4(lit, base.a * fragColor.a);

    // --- Collapse fade + burn edge ---
    float alphaFactor = 1.0 - smoothstep(FADE_START, 1.0, progress);
    float alpha = tex.a * alphaFactor * inside;

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

    // --- Shadow / final output ---
    if (shadow) {
        finalColor = vec4(vec3(0.0), alpha * 0.35);
    } else {
        finalColor = vec4(lit, alpha);
    }
}
