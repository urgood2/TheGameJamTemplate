#version 330 core
// foil_dissolve.fs (Raylib GLSL 330 version)
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform sampler2D texture0;

uniform vec2 holo;
uniform float dissolve;
uniform float time;
uniform vec4 texture_details;
uniform vec2 image_details;
uniform float shadow;
uniform vec4 burn_colour_1;
uniform vec4 burn_colour_2;

float hue(float s, float t, float h) {
    float hs = mod(h, 1.0) * 6.0;
    if (hs < 1.0) return (t - s) * hs + s;
    if (hs < 3.0) return t;
    if (hs < 4.0) return (t - s) * (4.0 - hs) + s;
    return s;
}

vec4 RGB(vec4 c) {
    if (c.y < 0.0001) return vec4(vec3(c.z), c.a);
    float t = (c.z < 0.5) ? c.y * c.z + c.z : -c.y * c.z + (c.y + c.z);
    float s = 2.0 * c.z - t;
    return vec4(hue(s, t, c.x + 1.0 / 3.0), hue(s, t, c.x), hue(s, t, c.x - 1.0 / 3.0), c.w);
}

vec4 HSL(vec4 c) {
    float low = min(c.r, min(c.g, c.b));
    float high = max(c.r, max(c.g, c.b));
    float delta = high - low;
    float sum = high + low;

    vec4 hsl = vec4(0.0, 0.0, 0.5 * sum, c.a);
    if (delta == 0.0) return hsl;

    hsl.y = (hsl.z < 0.5) ? delta / sum : delta / (2.0 - sum);

    if (high == c.r) hsl.x = (c.g - c.b) / delta;
    else if (high == c.g) hsl.x = (c.b - c.r) / delta + 2.0;
    else hsl.x = (c.r - c.g) / delta + 4.0;

    hsl.x = mod(hsl.x / 6.0, 1.0);
    return hsl;
}

vec4 dissolve_mask(vec4 tex, vec2 uv, vec2 scaled_uv) {
    if (dissolve < 0.001) {
        return vec4(shadow > 0.5 ? vec3(0.0) : tex.rgb, shadow > 0.5 ? tex.a * 0.3 : tex.a);
    }

    float adjusted_dissolve = (dissolve * dissolve * (3.0 - 2.0 * dissolve)) * 1.02 - 0.01;
    float t = time * 10.0 + 2003.0;

    vec2 floored_uv = floor(scaled_uv * texture_details.zw) / texture_details.zw;
    vec2 uv_scaled_centered = (floored_uv - 0.5) * 2.3 * max(texture_details.z, texture_details.w);

    vec2 f1 = uv_scaled_centered + 50.0 * vec2(sin(-t / 143.6340), cos(-t / 99.4324));
    vec2 f2 = uv_scaled_centered + 50.0 * vec2(cos(t / 53.1532), cos(t / 61.4532));
    vec2 f3 = uv_scaled_centered + 50.0 * vec2(sin(-t / 87.53218), sin(-t / 49.0));

    float field = (1.0 + (
        cos(length(f1) / 19.483) +
        sin(length(f2) / 33.155) * cos(f2.y / 15.73) +
        cos(length(f3) / 27.193) * sin(f3.x / 21.92)
    )) / 2.0;

    vec2 borders = vec2(0.2, 0.8);

    float res = (0.5 + 0.5 * cos((adjusted_dissolve) / 82.612 + (field - 0.5) * 3.14159));
    res -= (floored_uv.x > borders.y ? (floored_uv.x - borders.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve;
    res -= (floored_uv.y > borders.y ? (floored_uv.y - borders.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve;
    res -= (floored_uv.x < borders.x ? (borders.x - floored_uv.x) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve;
    res -= (floored_uv.y < borders.x ? (borders.x - floored_uv.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve;

    if (tex.a > 0.01 && burn_colour_1.a > 0.01 && shadow < 0.5 && res < adjusted_dissolve + 0.8 * (0.5 - abs(adjusted_dissolve - 0.5)) && res > adjusted_dissolve) {
        if (res < adjusted_dissolve + 0.5 * (0.5 - abs(adjusted_dissolve - 0.5))) {
            tex = burn_colour_1;
        } else if (burn_colour_2.a > 0.01) {
            tex = burn_colour_2;
        }
    }

    return vec4(shadow > 0.5 ? vec3(0.0) : tex.rgb, res > adjusted_dissolve ? (shadow > 0.5 ? tex.a * 0.3 : tex.a) : 0.0);
}

void main() {
    vec2 uv = fragTexCoord;
    vec4 tex = texture(texture0, uv);

    vec2 scaled_uv = ((uv * image_details) - texture_details.xy * texture_details.zw) / texture_details.zw;
    vec2 adj_uv = scaled_uv - 0.5;
    adj_uv.x *= texture_details.z / texture_details.w;

    float low = min(tex.r, min(tex.g, tex.b));
    float high = max(tex.r, max(tex.g, tex.b));
    float delta = 0.2 + 0.3 * (high - low) + 0.1 * high;

    vec4 hsl = HSL(0.5 * tex + 0.5 * vec4(0.0, 0.0, 1.0, tex.a));

    float t = holo.y * 7.221 + time;
    vec2 uv_scaled_centered = (floor(scaled_uv * texture_details.zw) / texture_details.zw - 0.5) * 250.0;

    vec2 f1 = uv_scaled_centered + 50.0 * vec2(sin(-t / 143.6340), cos(-t / 99.4324));
    vec2 f2 = uv_scaled_centered + 50.0 * vec2(cos(t / 53.1532), cos(t / 61.4532));
    vec2 f3 = uv_scaled_centered + 50.0 * vec2(sin(-t / 87.53218), sin(-t / 49.0));

    float field = (1.0 + (
        cos(length(f1) / 19.483) +
        sin(length(f2) / 33.155) * cos(f2.y / 15.73) +
        cos(length(f3) / 27.193) * sin(f3.x / 21.92)
    )) / 2.0;

    float res = (0.5 + 0.5 * cos(holo.x * 2.612 + (field - 0.5) * 3.14159));

    float gridsize = 0.79;
    float fac = 0.5 * max(max(
        max(0.0, 7.0 * abs(cos(uv.x * gridsize * 20.0)) - 6.0),
        max(0.0, 7.0 * cos(uv.y * gridsize * 45.0 + uv.x * gridsize * 20.0) - 6.0)),
        max(0.0, 7.0 * cos(uv.y * gridsize * 45.0 - uv.x * gridsize * 20.0) - 6.0));

    hsl.x += res + fac;
    hsl.y *= 1.3;
    hsl.z = hsl.z * 0.6 + 0.4;

    tex = (1.0 - delta) * tex + delta * RGB(hsl) * vec4(0.9, 0.8, 1.2, tex.a);
    if (tex.a < 0.7) tex.a = tex.a / 3.0;

    finalColor = dissolve_mask(tex * fragColor, uv, scaled_uv);
}
