#version 330 core
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform vec4 colDiffuse;
uniform sampler2D texture0;

uniform vec4 colour_1;
uniform vec4 colour_2;
uniform vec4 colour_3;
uniform vec2 texelSize;

uniform float iTime;

uniform bool polar_coordinates;
uniform vec2 polar_center;
uniform float polar_zoom;
uniform float polar_repeat;

uniform float spin_rotation;
uniform float spin_speed;
uniform vec2 offset;

uniform float contrast;
uniform float spin_amount;
uniform float pixel_filter;

out vec4 finalColor;

vec2 polar_coords(vec2 uv, vec2 center, float zoom, float repeat)
{
    vec2 dir = uv - center;
    float radius = length(dir) * 2.0;
    float angle = atan(dir.y , dir.x) / (2.0 * 3.14159265);
    return mod(vec2(radius * zoom, angle * repeat), 1.0);
}

vec4 effect(vec2 screenSize, vec2 screen_coords)
{
    float pixel_size = length(screenSize) / pixel_filter;

    vec2 uv = (floor(screen_coords / pixel_size) * pixel_size - 0.5 * screenSize) / length(screenSize) - offset;
    float uv_len = length(uv);

    float speed = (spin_rotation * 0.2) + 302.2;
    float new_angle = atan(uv.y, uv.x) + speed - 20.0 * (spin_amount * uv_len + (1.0 - spin_amount));
    vec2 mid = (screenSize / length(screenSize)) / 2.0;
    uv = vec2(uv_len * cos(new_angle) + mid.x, uv_len * sin(new_angle) + mid.y) - mid;

    uv *= 30.0;
    speed = iTime * spin_speed;
    vec2 uv2 = vec2(uv.x + uv.y);

    for(int i = 0; i < 5; i++) {
        uv2 += sin(max(uv.x, uv.y)) + uv;
        uv += 0.5 * vec2(cos(5.1123314 + 0.353 * uv2.y + speed * 0.131121),
                         sin(uv2.x - 0.113 * speed));
        uv -= cos(uv.x + uv.y) - sin(uv.x * 0.711 - uv.y);
    }

    float contrast_mod = (0.25 * contrast + 0.5 * spin_amount + 1.2);
    float paint_res = clamp(length(uv) * 0.035 * contrast_mod, 0.0, 2.0);
    float c1p = max(0.0, 1.0 - contrast_mod * abs(1.0 - paint_res));
    float c2p = max(0.0, 1.0 - contrast_mod * abs(paint_res));
    float c3p = 1.0 - min(1.0, c1p + c2p);

    vec4 ret_col = (0.3 / contrast) * colour_1 +
                   (1.0 - 0.3 / contrast) * (
                       colour_1 * c1p +
                       colour_2 * c2p +
                       vec4(c3p * colour_3.rgb, c3p * colour_1.a));
    return ret_col;
}

void main()
{
    vec2 screenSize = 1.0 / texelSize;
    vec2 screen_coords = (polar_coordinates
        ? polar_coords(fragTexCoord, polar_center, polar_zoom, polar_repeat)
        : fragTexCoord) * screenSize;

    vec4 paint = effect(screenSize, screen_coords);

    finalColor = paint * fragColor * colDiffuse;
    finalColor.a = paint.a * fragColor.a;
}
