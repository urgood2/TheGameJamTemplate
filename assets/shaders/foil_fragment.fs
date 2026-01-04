#version 330 core
// foil_dissolve.fs
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

out vec4 finalColor;

uniform sampler2D texture0; // Main texture

uniform vec2 foil;
uniform float dissolve;
uniform float time;
uniform vec4 texture_details;
uniform vec2 image_details;
uniform float shadow;
uniform vec4 burn_colour_1;
uniform vec4 burn_colour_2;

// Functions to convert RGB <-> HSL
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
    vec2 uv = fragTexCoord;
    vec4 tex = texture(texture0, uv);

    vec2 imageSize = image_details;
    vec2 texSize = texture_details.zw;
    vec2 texOffset = texture_details.xy;

    vec2 uv_scaled = (uv * imageSize - texOffset * texSize) / texSize;
    vec2 adj_uv = uv_scaled - 0.5;
    adj_uv.x *= texSize.x / texSize.y;

    float low = min(tex.r, min(tex.g, tex.b));
    float high = max(tex.r, max(tex.g, tex.b));
    float delta = min(high, max(0.5, 1.0 - low));

    float fac = max(min(2.0 * sin(length(90.0 * adj_uv) + foil.x * 2.0 + 3.0 * (1.0 + 0.8 * cos(length(113.1121 * adj_uv) - foil.x * 3.121))) - 1.0 - max(5.0 - length(90.0 * adj_uv), 0.0), 1.0), 0.0);

    vec2 rotater = vec2(cos(foil.x * 0.1221), sin(foil.x * 0.3512));
    float angle = dot(rotater, adj_uv) / (length(rotater) * length(adj_uv));
    float fac2 = max(min(5.0 * cos(foil.y * 0.3 + angle * 3.14159 * (2.2 + 0.9 * sin(foil.x * 1.65 + 0.2 * foil.y))) - 4.0 - max(2.0 - length(20.0 * adj_uv), 0.0), 1.0), 0.0);

    float fac3 = 0.3 * max(min(2.0 * sin(foil.x * 5.0 + uv.x * 3.0 + 3.0 * (1.0 + 0.5 * cos(foil.x * 7.0))) - 1.0, 1.0), -1.0);
    float fac4 = 0.3 * max(min(2.0 * sin(foil.x * 6.66 + uv.y * 3.8 + 3.0 * (1.0 + 0.5 * cos(foil.x * 3.414))) - 1.0, 1.0), -1.0);

    float maxfac = max(max(fac, max(fac2, max(fac3, fac4))) + 2.2 * (fac + fac2 + fac3 + fac4), 0.0);

    tex.r = tex.r - delta + delta * maxfac * 0.3;
    tex.g = tex.g - delta + delta * maxfac * 0.3;
    tex.b = tex.b + delta * maxfac * 1.9;
    tex.a = min(tex.a, 0.3 * tex.a + 0.9 * min(0.5, maxfac * 0.1));

    finalColor = dissolve_mask(tex, uv, uv_scaled);
}
