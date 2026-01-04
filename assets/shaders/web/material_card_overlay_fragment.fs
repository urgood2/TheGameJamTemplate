#version 300 es
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform sampler2D texture0;
uniform vec2 uImageSize;
uniform vec4 uGridRect;

uniform float dissolve;
uniform float time;
uniform vec4 texture_details;
uniform vec2 image_details;
uniform float shadow;
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

vec4 dissolve_mask(vec4 tex, vec2 texcoord, vec2 uv) {
    if (dissolve < 0.001) {
        return vec4(shadow ? vec3(0.0) : tex.rgb, shadow ? tex.a * 0.3 : tex.a);
    }

    float adjusted_dissolve = (dissolve * dissolve * (3.0 - 2.0 * dissolve)) * 1.02 - 0.01;
    float t = time * 10.0 + 2003.0;

    vec2 floored_uv = floor((uv * texture_details.zw)) / max(texture_details.z, texture_details.w);
    vec2 uv_scaled = (floored_uv - 0.5) * 2.3 * max(texture_details.z, texture_details.w);

    vec2 field1 = uv_scaled + 50.0 * vec2(sin(-t / 143.6340), cos(-t / 99.4324));
    vec2 field2 = uv_scaled + 50.0 * vec2(cos(t / 53.1532), cos(t / 61.4532));
    vec2 field3 = uv_scaled + 50.0 * vec2(sin(-t / 87.53218), sin(-t / 49.0));

    float field = (1.0 + (
        cos(length(field1) / 19.483) +
        sin(length(field2) / 33.155) * cos(field2.y / 15.73) +
        cos(length(field3) / 27.193) * sin(field3.x / 21.92)
    )) / 2.0;

    vec2 borders = vec2(0.2, 0.8);

    float res = (0.5 + 0.5 * cos((adjusted_dissolve) / 82.612 + (field - 0.5) * 3.14159))
        - (floored_uv.x > borders.y ? (floored_uv.x - borders.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.y > borders.y ? (floored_uv.y - borders.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.x < borders.x ? (borders.x - floored_uv.x) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.y < borders.x ? (borders.x - floored_uv.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve;

    if (tex.a > 0.01 && burn_colour_1.a > 0.01 && !shadow && res < adjusted_dissolve + 0.8 * (0.5 - abs(adjusted_dissolve - 0.5)) && res > adjusted_dissolve) {
        if (res < adjusted_dissolve + 0.5 * (0.5 - abs(adjusted_dissolve - 0.5)) && res > adjusted_dissolve) {
            tex = burn_colour_1;
        } else if (burn_colour_2.a > 0.01) {
            tex = burn_colour_2;
        }
    }

    return vec4(shadow ? vec3(0.0) : tex.rgb, res > adjusted_dissolve ? (shadow ? tex.a * 0.3 : tex.a) : 0.0);
}

void main() {
    vec2 spriteUV = getSpriteUV(fragTexCoord);
    vec4 base = texture(texture0, spriteUV);

    vec2 centered = spriteUV - 0.5;
    vec2 rotated = rotate2d(card_rotation) * centered;

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

    float edgeMask = mix(0.35, 1.0, smoothstep(0.08, 0.62, length(centered)));
    float luma = dot(base.rgb, vec3(0.299, 0.587, 0.114));

    float foilStrength = abs(grain_intensity) * grain + abs(sheen_strength) * sheen;
    float overlayMask = clamp(foilStrength, 0.0, 1.0) * edgeMask;

    // Tie wobble to rotation, but keep it subtle.
    float rotMod = sin(card_rotation * 4.0) * 0.35 + sin(card_rotation * 8.0) * 0.15;
    float brightness = ((grain - 0.5) * 0.4 + (sheen - 0.5) * 0.25 + rotMod * 0.35) * overlayMask;
    float factor = clamp(1.0 + brightness, 0.85, 1.15);
    float detail = ((grain - 0.5) + rotMod * 0.5) * 0.06 * overlayMask;

    vec3 lit = clamp(base.rgb * factor + vec3(detail), 0.0, 1.0);

    // Temporary: ignore incoming vertex tint to rule out upstream color.
    // Respect only alpha from fragColor to avoid reintroducing vertex color tint.
    vec4 tex = vec4(lit, base.a * fragColor.a);
    // Remove debug tint; only alpha from fragColor is respected.

    vec2 dissolve_uv = (((fragTexCoord) * image_details) - texture_details.xy * texture_details.zw) / texture_details.zw;
    finalColor = dissolve_mask(tex, spriteUV, dissolve_uv);
}
