#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Input uniform values
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float time;

// Custom uniforms
uniform float s11 = 0.8;
uniform float s33 = 0.13;
uniform float s55 = 0.16;
uniform float s77 = 0.9;
uniform float s99 = 6.5;
uniform int particle_num = 30;
uniform float range_param = 0.75;
uniform float speed = 2.0;
uniform float gravity = 0.5;
uniform int timeStep = 2;
uniform float shineyMagnitude = 1.0;

// Output fragment color
out vec4 finalColor;

const float PI = 3.14159265359;
const float TAU = 6.28318530718;

float randomseed(in float _st) {
    return fract(cos(_st * 12.9898) * 43758.5453123);
}

vec4 boom(int c, vec2 suv, float t) {
    vec4 COL = vec4(0.0);

    for (int i = 0; i < particle_num; i++) {
        float ofx1 = (0.5 - randomseed(float(i + c * particle_num + 1) * 7.325)) * 0.5;
        float ofx2 = (0.5 - randomseed(float(i + c / particle_num + 3) * 17.688)) * 0.5;
        float theta = atan(ofx1, ofx2);
        float mt = pow(t * 7.0, s11);

        float x1 = sin(theta) * (pow(mt, 1.0) + randomseed(float(i / 3) * 7.0) * 0.5);
        float x2 = cos(theta) * (pow(mt, 1.0) + randomseed(float(i / 3) * 12.0) * 0.5);
        x2 += distance(vec2(x1 + ofx1, x2 + ofx2), vec2(ofx1, ofx2)) * gravity;

        float v2 = (1.0 / TAU) * exp(-((pow(x1 - ofx1, 2.0) + pow(x2 + ofx2, 2.0)) / (2.0 * shineyMagnitude))) * s77;
        float v = max(1.0 - pow(distance(vec2(x1 + ofx1, x2 + ofx2), vec2(suv.x + ofx1, suv.y + ofx2) * s99) * s77, s55), 0.0) + v2 * s33;
        float o = v;
        float f = 0.0;

        if (c == 0) {
            COL += vec4(o, f, f, v);
        } else if (c - 1 == 0) {
            COL += vec4(f, o, f, v);
        } else if (c - 2 == 0) {
            COL += vec4(f, f, o, v);
        } else if (c - 3 == 0) {
            COL += vec4(o, o, f, v);
        } else if (c - 4 == 0) {
            COL += vec4(f, o, o, v);
        } else if (c - 5 == 0) {
            COL += vec4(o, f, o, v);
        } else {
            COL += vec4(o, o, o, v);
        }
    }

    return COL;
}

void main()
{
    vec2 suv = (fragTexCoord - 0.5) * 2.0;
    vec4 color = vec4(0.0);

    for (int j = 0; j < 6; j++) {
        float timestep = float(timeStep) * speed;
        float td = 6.0 * float(j) / timestep + time * speed;
        float tf = td / timestep;

        float mt = mod(td, timestep);
        vec2 duv = suv + range_param * (1.0 - vec2(randomseed(float(j) * 37.0 + floor(tf)), randomseed(float(j) * 17.0 + floor(tf))) * 2.0);
        color += boom(j, duv, mt);
    }

    finalColor = color * colDiffuse * fragColor;
}
