#version 300 es
precision mediump float;

precision mediump float;

#define PI 3.14159265359

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float time;
uniform float amplitude;
uniform float frequency;
uniform float light_magnitude;
uniform float color_spread;
uniform float light_distance;
uniform float speed;
uniform bool cut_angle;
uniform float angle;
uniform float yshift;

// Output fragment color
out vec4 finalColor;

float yget(float x, float fc1, float fc2, float fc3, float fc4, float tc1, float tc2, float tc3, float tc4, float amc1, float amc2, float amc3, float amc4, float addt) {
    float t = speed * (time * 130.0) + addt;
    float y = sin(x * frequency);

    y += sin(x * frequency * fc1 + t * tc1) * amc1;
    y += sin(x * frequency * fc2 + t * tc2) * amc2;
    y += sin(x * frequency * fc3 + t * tc3) * amc3;
    y += sin(x * frequency * fc4 + t * tc4) * amc4;
    y *= amplitude / (amc1 * amc2 * amc3 * amc4);

    return y;
}

void main()
{
    vec2 st = (fragTexCoord - 0.5) * 2.0;
    float x = st.x;
    float y = st.y + yshift * 2.0;
    float d = 1.0 - distance(vec2(0.0), vec2(x, y)) * (1.0 - light_distance);

    float theta = atan(y, x);
    float aphla = (90.0 - angle * 0.5) * PI / 180.0;

    if ((theta < -aphla) && (theta > -(PI - aphla)) || !cut_angle) {
        float sa = sin(atan(y, x) + PI * 0.5);

        float alpha_r = distance(vec2(0.0), vec2(sa, yget(sa, 1.30, 1.72, 2.221, 3.1122, 1., 1.121, 0.437, 4., 4.5, 4., 5., 2.5, 0.) / amplitude)) * light_magnitude;
        float alpha_g = distance(vec2(0.0), vec2(sa, yget(sa, 1.31, 1.72, 2.221, 3.1122, 1., 1.121, 0.437, 4.269, 4.5, 4., 5., 2.5, color_spread) / amplitude)) * light_magnitude;
        float alpha_b = distance(vec2(0.0), vec2(sa, yget(sa, 1.29, 1.72, 2.221, 3.1122, 1., 1.121, 0.437, 5., 4.5, 4., 5., 2.5, -color_spread) / amplitude)) * light_magnitude;

        finalColor = alpha_r * vec4(d, 0., 0., d) + alpha_g * vec4(0., d, 0., d) + alpha_b * vec4(0., 0., d, d);
    } else {
        finalColor = vec4(0.0);
    }

    finalColor *= colDiffuse * fragColor;
}
