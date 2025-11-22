#version 300 es
precision mediump float;

precision mediump float;

// Source: https://godotshaders.com/shader/perspective-warp-skew-shader
// Converted from Godot to Raylib

in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0; // Screen texture
uniform vec4 colDiffuse;
uniform vec2 topleft;
uniform vec2 topright;
uniform vec2 bottomleft;
uniform vec2 bottomright;

out vec4 finalColor;

float _cross(in vec2 a, in vec2 b)
{
    return a.x * b.y - a.y * b.x;
}

vec2 invBilinear(in vec2 p, in vec2 a, in vec2 b, in vec2 c, in vec2 d)
{
    vec2 res = vec2(-1.0);

    vec2 e = b - a;
    vec2 f = d - a;
    vec2 g = a - b + c - d;
    vec2 h = p - a;

    float k2 = _cross(g, f);
    float k1 = _cross(e, f) + _cross(h, g);
    float k0 = _cross(h, e);

    // if edges are parallel, use a linear equation.
    if (abs(k2) < 0.001) {
        res = vec2((h.x * k1 + f.x * k0) / (e.x * k1 - g.x * k0), -k0 / k1);
    }
    // otherwise, it's a quadratic
    else {
        float w = k1 * k1 - 4.0 * k0 * k2;
        if (w < 0.0) return vec2(-1.0);
        w = sqrt(w);

        float ik2 = 0.5 / k2;
        float v = (-k1 - w) * ik2;
        float u = (h.x - f.x * v) / (e.x + g.x * v);

        if (u < 0.0 || u > 1.0 || v < 0.0 || v > 1.0) {
            v = (-k1 + w) * ik2;
            u = (h.x - f.x * v) / (e.x + g.x * v);
        }
        res = vec2(u, 1.0 - v);
    }

    return res;
}

void main()
{
    vec2 texSize = vec2(textureSize(texture0, 0));
    vec2 topleftUV = topleft / texSize;
    vec2 toprightUV = vec2(1.0, 0.0) + topright / texSize;
    vec2 bottomrightUV = vec2(1.0, 1.0) + bottomright / texSize;
    vec2 bottomleftUV = vec2(0.0, 1.0) + bottomleft / texSize;

    vec2 newUV = invBilinear(fragTexCoord, topleftUV, toprightUV, bottomrightUV, bottomleftUV);

    if (topleft.x == 0.0 || topright.x == 0.0) {
        finalColor = texture(texture0, fragTexCoord) * colDiffuse * fragColor;
    }
    else {
        if (newUV == vec2(-1.0)) {
            finalColor = vec4(0.0);
        }
        else {
            finalColor = texture(texture0, newUV) * colDiffuse * fragColor;
        }
    }
}
