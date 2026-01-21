#version 300 es
precision mediump float;

// negative_shine.fs

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform sampler2D texture0;
uniform vec2 negative_shine;
uniform float dissolve;
uniform float time;
uniform vec4 texture_details;
uniform vec2 image_details;
uniform float shadow;
uniform vec4 burn_colour_1;
uniform vec4 burn_colour_2;

vec4 dissolve_mask(vec4 tex, vec2 texcoord, vec2 uv) {
    if (dissolve < 0.001) {
        return vec4(shadow > 0.5 ? vec3(0.0) : tex.rgb, shadow > 0.5 ? tex.a * 0.3 : tex.a);
    }

    float adjusted_dissolve = (dissolve * dissolve * (3.0 - 2.0 * dissolve)) * 1.02 - 0.01;
    float t = time * 10.0 + 2003.0;

    vec2 floored_uv = floor((uv * texture_details.zw)) / max(texture_details.z, texture_details.w);
    vec2 uv_scaled = (floored_uv - 0.5) * 2.3 * max(texture_details.z, texture_details.w);

    vec2 f1 = uv_scaled + 50.0 * vec2(sin(-t / 143.6340), cos(-t / 99.4324));
    vec2 f2 = uv_scaled + 50.0 * vec2(cos(t / 53.1532), cos(t / 61.4532));
    vec2 f3 = uv_scaled + 50.0 * vec2(sin(-t / 87.53218), sin(-t / 49.0));

    float field = (1.0 + (
        cos(length(f1) / 19.483) +
        sin(length(f2) / 33.155) * cos(f2.y / 15.73) +
        cos(length(f3) / 27.193) * sin(f3.x / 21.92)
    )) / 2.0;

    vec2 borders = vec2(0.2, 0.8);

    float res = (0.5 + 0.5 * cos((adjusted_dissolve) / 82.612 + (field - 0.5) * 3.14159))
        - (floored_uv.x > borders.y ? (floored_uv.x - borders.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.y > borders.y ? (floored_uv.y - borders.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.x < borders.x ? (borders.x - floored_uv.x) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.y < borders.x ? (borders.x - floored_uv.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve;

    if (tex.a > 0.01 && burn_colour_1.a > 0.01 && shadow < 0.5 && res < adjusted_dissolve + 0.8 * (0.5 - abs(adjusted_dissolve - 0.5)) && res > adjusted_dissolve) {
        if (res < adjusted_dissolve + 0.5 * (0.5 - abs(adjusted_dissolve - 0.5)) && res > adjusted_dissolve) {
            tex = burn_colour_1;
        } else if (burn_colour_2.a > 0.01) {
            tex = burn_colour_2;
        }
    }

    return vec4(shadow > 0.5 ? vec3(0.0) : tex.rgb, res > adjusted_dissolve ? (shadow > 0.5 ? tex.a * 0.3 : tex.a) : 0.0);
}

void main() {
    vec2 uv = (((fragTexCoord) * image_details) - texture_details.xy * texture_details.zw) / texture_details.zw;
    vec4 tex = texture(texture0, fragTexCoord);

    float low = min(tex.r, min(tex.g, tex.b));
    float high = max(tex.r, max(tex.g, tex.b));
    float delta = high - low - 0.1;

    float fac = 0.8 + 0.9 * sin(11.0 * uv.x + 4.32 * uv.y + negative_shine.x * 12.0 + cos(negative_shine.x * 5.3 + uv.y * 4.2 - uv.x * 4.0));
    float fac2 = 0.5 + 0.5 * sin(8.0 * uv.x + 2.32 * uv.y + negative_shine.x * 5.0 - cos(negative_shine.x * 2.3 + uv.x * 8.2));
    float fac3 = 0.5 + 0.5 * sin(10.0 * uv.x + 5.32 * uv.y + negative_shine.x * 6.111 + sin(negative_shine.x * 5.3 + uv.y * 3.2));
    float fac4 = 0.5 + 0.5 * sin(3.0 * uv.x + 2.32 * uv.y + negative_shine.x * 8.111 + sin(negative_shine.x * 1.3 + uv.y * 11.2));
    float fac5 = sin(0.9 * 16.0 * uv.x + 5.32 * uv.y + negative_shine.x * 12.0 + cos(negative_shine.x * 5.3 + uv.y * 4.2 - uv.x * 4.0));

    float maxfac = 0.7 * max(max(fac, max(fac2, max(fac3, 0.0))) + (fac + fac2 + fac3 * fac4), 0.0);

    tex.rgb = tex.rgb * 0.5 + vec3(0.4, 0.4, 0.8);

    tex.r = tex.r - delta + delta * maxfac * (0.7 + fac5 * 0.27) - 0.1;
    tex.g = tex.g - delta + delta * maxfac * (0.7 - fac5 * 0.27) - 0.1;
    tex.b = tex.b - delta + delta * maxfac * 0.7 - 0.1;
    tex.a = tex.a * (0.5 * max(min(1.0, max(0.0, 0.3 * max(low * 0.2, delta) + min(max(maxfac * 0.1, 0.0), 0.4))), 0.0) + 0.15 * maxfac * (0.1 + delta));

    finalColor = dissolve_mask(tex * fragColor, fragTexCoord, uv);
}
