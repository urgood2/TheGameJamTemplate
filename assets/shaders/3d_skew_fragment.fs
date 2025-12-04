#version 330 core
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform vec2 regionRate;
uniform vec2 pivot;

in mat3 invRotMat;
in vec2 worldMouseUV;
in vec2 tiltAmount;

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
vec2 rotate(vec2 uv, vec2 pivotPt, float angle)
{
    float s = sin(angle);
    float c = cos(angle);
    uv -= pivotPt;
    uv = vec2(
        c * uv.x - s * uv.y,
        s * uv.x + c * uv.y
    );
    uv += pivotPt;
    return uv;
}

void main()
{
    vec2 uv = fragTexCoord;

    bool identityAtlas = abs(regionRate.x - 1.0) < 0.0001 &&
                         abs(regionRate.y - 1.0) < 0.0001 &&
                         abs(pivot.x) < 0.0001 &&
                         abs(pivot.y) < 0.0001;

    if (identityAtlas) {
        // Text path: rely on vertex-stage skew for motion; keep UVs fixed and clamp
        // to avoid sampling outside glyphs.
        float inset = 0.0035; // tiny padding to kill bleed
        vec2 finalUV = clamp(uv, vec2(inset), vec2(1.0 - inset));
        vec4 texel = texture(texture0, finalUV);
        finalColor = texel * fragColor * colDiffuse;
    } else {
        // Full atlas-aware path for sprites.
        float tiltStrength = abs(fov) * 2.0;
        float tiltX = tiltAmount.y * tiltStrength;
        float tiltY = tiltAmount.x * tiltStrength;
        float cosX = cos(tiltX);
        float cosY = cos(tiltY);

        vec2 centered = (uv - pivot) / regionRate;
        vec2 localCentered = centered - vec2(0.5);
        vec2 correctedUV = localCentered;
        correctedUV.x /= max(cosY, 0.5);
        correctedUV.y /= max(cosX, 0.5);
        correctedUV.x -= sin(tiltY) * 0.1;
        correctedUV.y -= sin(tiltX) * 0.1;
        uv = correctedUV + vec2(0.5);

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
}
