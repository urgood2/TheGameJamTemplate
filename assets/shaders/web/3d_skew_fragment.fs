#version 300 es
precision mediump float;

precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform vec2 regionRate;
uniform vec2 pivot;

in mat3 invRotMat;
in vec2 worldMouseUV;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float fov;
uniform float cull_back;
uniform float rand_trans_power;
uniform float rand_seed;
uniform float rotation;
uniform float iTime;

out vec4 finalColor;

// 2D rotation helper
vec2 rotate(vec2 uv, vec2 pivot, float angle)
{
    float s = sin(angle);
    float c = cos(angle);
    uv -= pivot;
    uv = vec2(
        c * uv.x - s * uv.y,
        s * uv.x + c * uv.y
    );
    uv += pivot;
    return uv;
}

void main()
{
    vec2 uv = fragTexCoord;
    float t = tan(radians(fov) / 2.0);
    vec2 centered = (uv - pivot) / regionRate;

    vec3 p = invRotMat * vec3(centered - 0.5, 0.5 / t);
    float v = (0.5 / t) + 0.5;
    p.xy *= v * invRotMat[2].z;
    vec2 o = v * invRotMat[2].xy;

    if (cull_back > 0.5 && p.z <= 0.0) discard;

    uv = (p.xy / p.z) - o + 0.5;

    float asp = regionRate.y / regionRate.x;
    uv.y *= asp;

    float angle = rotation + rand_trans_power * 0.05 *
        sin(iTime * (0.9 + mod(rand_seed, 0.5)) + rand_seed * 123.8985);
    uv = rotate(uv, vec2(0.5), angle);
    uv.y /= asp;

    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) discard;

    vec2 finalUV = pivot + uv * regionRate;

    vec4 texel = texture(texture0, finalUV);
    finalColor = texel * fragColor * colDiffuse;
}
