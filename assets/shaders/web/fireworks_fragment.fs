#version 300 es
precision mediump float;


in vec2 fragTexCoord;
in vec4 fragColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;

// Sprite atlas uniforms
uniform vec4 uGridRect;
uniform vec2 uImageSize;


// Effect uniforms
uniform float s11;
uniform float s33;
uniform float s55;
uniform float s77;
uniform float s99;

uniform int   Praticle_num;

uniform float Range;
uniform float speed;
uniform float gravity;
uniform int   TimeStep;

uniform float ShneyMagnitude;

uniform float iTime;

out vec4 finalColor;

const float TAU = 6.28318530718;

// ----------------------------------------------------------------------------
// Convert atlas UV → local sprite UV (0..1 inside the sprite)
// ----------------------------------------------------------------------------
vec2 getSpriteUV(vec2 uv) {
    vec2 pixelUV   = uv * uImageSize;
    vec2 spriteLoc = pixelUV - uGridRect.xy;
    return spriteLoc / uGridRect.zw;
}

// ----------------------------------------------------------------------------
// Random (same as Godot version)
// ----------------------------------------------------------------------------
float randomseed(float x) {
    return fract(cos(x * 12.9898) * 43758.5453123);
}

// ----------------------------------------------------------------------------
// Explosion particle contribution
// ----------------------------------------------------------------------------
vec4 boom(int c, vec2 suv, float t)
{
    vec4 COL = vec4(0.0);

    for (int i = 0; i < 15; i++)
    {
        float ofx1 = (0.5 - randomseed(float(i + c * Praticle_num + 1) * 7.325)) * 0.5;
        float ofx2 = (0.5 - randomseed(float(i + c / Praticle_num + 3) * 17.688)) * 0.5;
        float theta = atan(ofx1, ofx2);

        float mt = pow(t * 7.0, s11);

        float x1 = sin(theta) * (pow(mt, 1.0) + randomseed(float(i / 3) * 7.0) * 0.5);
        float x2 = cos(theta) * (pow(mt, 1.0) + randomseed(float(i / 3) * 12.0) * 0.5);

        x2 += distance(vec2(x1 + ofx1, x2 + ofx2), vec2(ofx1, ofx2)) * gravity;

        float v2 = (1.0 / TAU)
            * exp(-((pow(x1 - ofx1, 2.0) + pow(x2 + ofx2, 2.0)) /
                    (2.0 * ShneyMagnitude)))
            * s77;

        float v = max(
            1.0 - pow(distance(
                vec2(x1 + ofx1, x2 + ofx2),
                vec2(suv.x + ofx1, suv.y + ofx2) * s99) * s77,
                s55),
            0.0
        ) + v2 * s33;

        float o = v;
        float f = 0.0;

        if (c == 0)
            COL += vec4(o, f, f, v);
        else if (c - 1 == 0)
            COL += vec4(f, o, f, v);
        else if (c - 2 == 0)
            COL += vec4(f, f, o, v);
        else if (c - 3 == 0)
            COL += vec4(o, o, f, v);
        else if (c - 4 == 0)
            COL += vec4(f, o, o, v);
        else if (c - 5 == 0)
            COL += vec4(o, f, o, v);
        else
            COL += vec4(o, o, o, v);
    }

    return COL;
}

// ----------------------------------------------------------------------------
// Main
// ----------------------------------------------------------------------------
void main()
{

    // First convert to local sprite UV
    // vec2 baseUV = getSpriteUV(fragTexCoord);
    vec2 baseUV = fragTexCoord; // No atlas for fireworks



    // Normalize to [-1,1] just like Godot's (UV - 0.5)*2
    vec2 suv = (baseUV - vec2(0.5)) * 2.0;

    vec4 total = vec4(0.0);

    for (int j = 0; j < 6; j++)
    {
        float timestep = float(TimeStep) * speed;
        float td = 6.0 * float(j) / timestep + iTime * speed;
        float tf = td / timestep;

        float mt = mod(td, timestep);

        // jitter, same as original
        vec2 duv = suv + Range * (
            1.0 - vec2(
                randomseed(float(j) * 37.0 + floor(tf)),
                randomseed(float(j) * 17.0 + floor(tf))
            ) * 2.0
        );

        total += boom(j, duv, mt);
    }

    // The original shader does NOT sample the texture — it's additive only.
    // If needed, you can multiply by the sprite:
    // vec4 tex = texture(texture0, fragTexCoord);

    finalColor = total * colDiffuse * fragColor;
}
