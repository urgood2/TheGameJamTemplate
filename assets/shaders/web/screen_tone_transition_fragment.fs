#version 300 es
precision mediump float;

precision mediump float;

in vec2 fragTexCoord;

uniform vec4 in_color;
uniform vec4 out_color;
uniform float in_out;
uniform float position;
uniform vec2 size;
uniform vec2 screen_pixel_size;

out vec4 finalColor;

void main()
{
    vec2 a = (1.0 / screen_pixel_size) / size;

    vec2 uv = fragTexCoord * a;
    vec2 i_uv = floor(uv);
    vec2 f_uv = fract(uv);

    // Remap normalized position [0.0, 1.0] to [-1.5, 1.0]
    float pos = mix(-1.5, 1.0, position);
    float wave = max(0.0, i_uv.x / a.x - pos);

    vec2 center = f_uv * 2.0 - 1.0;
    float circle = length(center);
    circle = 1.0 - step(wave, circle);

    vec4 color = mix(in_color, out_color, step(0.5, in_out));

    finalColor = vec4(circle) * color;
}