#version 330 core
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform vec2 regionRate;
uniform vec2 pivot;

flat in vec2 tiltSin;
flat in vec2 tiltCos;
flat in float angleFlat;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float fov;
uniform float cull_back;
uniform float rand_trans_power;
uniform float rand_seed;
uniform float rotation;
uniform float iTime;
uniform float uv_passthrough;

uniform vec2 uImageSize;
uniform vec4 uGridRect;

uniform float dissolve;
uniform float time;
uniform vec4 texture_details;
uniform vec2 image_details;
uniform bool shadow;
uniform vec4 burn_colour_1;
uniform vec4 burn_colour_2;

uniform float card_rotation;
uniform vec3  material_tint;
uniform float grain_intensity;
uniform float grain_scale;
uniform float sheen_strength;
uniform float sheen_width;
uniform float sheen_speed;
uniform float noise_amount;
uniform float spread_strength;
uniform float distortion_strength;
uniform float fade_start;
uniform vec2  crystalline;

out vec4 finalColor;

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

vec2 getSpriteUV(vec2 uv) {
    vec2 pixelUV   = uv * uImageSize;
    vec2 spriteLoc = pixelUV - uGridRect.xy;
    return spriteLoc / uGridRect.zw;
}

vec2 localToAtlas(vec2 localUV) {
    return (uGridRect.xy + localUV * uGridRect.zw) / uImageSize;
}

vec4 sampleTinted(vec2 uv) {
    return texture(texture0, uv) * fragColor * colDiffuse;
}

// Hash for randomness
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

// Voronoi distance for crystal facets
float voronoi(vec2 uv, out vec2 cellCenter) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);

    float minDist = 1.0;
    vec2 minPoint = vec2(0.0);

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = hash2(i + neighbor);

            // Animate crystal points slightly
            point = 0.5 + 0.4 * sin(time * 0.3 + 6.2831 * point);

            vec2 diff = neighbor + point - f;
            float d = length(diff);

            if (d < minDist) {
                minDist = d;
                minPoint = i + neighbor + point;
            }
        }
    }

    cellCenter = minPoint;
    return minDist;
}

// Second closest for edge detection
float voronoiEdge(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);

    float minDist1 = 1.0;
    float minDist2 = 1.0;

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = hash2(i + neighbor);
            point = 0.5 + 0.4 * sin(time * 0.3 + 6.2831 * point);

            vec2 diff = neighbor + point - f;
            float d = length(diff);

            if (d < minDist1) {
                minDist2 = minDist1;
                minDist1 = d;
            } else if (d < minDist2) {
                minDist2 = d;
            }
        }
    }

    return minDist2 - minDist1;
}

vec4 applyOverlay(vec2 atlasUV) {
    const float EPS = 0.0001;
    bool effectInactive =
        abs(dissolve) < EPS &&
        abs(grain_intensity) < EPS &&
        abs(sheen_strength) < EPS &&
        burn_colour_1.a < EPS &&
        burn_colour_2.a < EPS &&
        !shadow &&
        length(material_tint - vec3(1.0)) < EPS;

    if (effectInactive && (abs(crystalline.x) + abs(crystalline.y)) < EPS) {
        return sampleTinted(atlasUV);
    }

    // Dissolve effect
    float progress = clamp(dissolve, 0.0, 1.0);
    vec2 localUV = getSpriteUV(atlasUV);
    vec2 centered = localUV - 0.5;
    float dist = length(centered);
    vec2 dir = dist > 0.0001 ? centered / dist : vec2(0.0);

    vec2 uvOutward = centered + dir * progress * spread_strength;
    uvOutward += distortion_strength * vec2(
        sin(dist * 20.0 - time * 10.0),
        cos(dist * 20.0 - time * 8.0)
    ) * progress;

    vec2 warpedLocal = uvOutward + vec2(0.5);
    vec2 sampleUV = localToAtlas(warpedLocal);
    vec4 base = sampleTinted(sampleUV);

    vec2 clampedLocal = clamp(warpedLocal, 0.0, 1.0);

    // Crystalline/Faceted effect
    vec2 uv = ((sampleUV * image_details) - texture_details.xy * texture_details.ba) / texture_details.ba;

    // Crystal facet scale
    float facetScale = 6.0 + crystalline.x * 4.0;
    vec2 scaledUV = uv * facetScale;

    // Get voronoi cell info
    vec2 cellCenter;
    float cellDist = voronoi(scaledUV, cellCenter);
    float edgeDist = voronoiEdge(scaledUV);

    // Each facet has unique properties based on cell center
    float facetHue = fract(dot(cellCenter, vec2(0.1, 0.17)) + crystalline.y * 0.1);
    float facetBrightness = 0.5 + 0.5 * sin(dot(cellCenter, vec2(1.3, 0.9)) + time * 0.5);

    // Prismatic refraction - split into RGB channels
    float refractStrength = 0.02 * (1.0 + crystalline.x);
    vec2 refractDir = normalize(cellCenter - scaledUV / facetScale);

    vec2 uvR = sampleUV + refractDir * refractStrength * 1.0;
    vec2 uvG = sampleUV + refractDir * refractStrength * 0.5;
    vec2 uvB = sampleUV - refractDir * refractStrength * 0.5;

    vec3 refractedColor;
    refractedColor.r = sampleTinted(uvR).r;
    refractedColor.g = sampleTinted(uvG).g;
    refractedColor.b = sampleTinted(uvB).b;

    // Rainbow caustics within each facet
    float caustic = pow(1.0 - cellDist, 3.0);
    vec3 rainbow = vec3(
        sin(facetHue * 6.2831) * 0.5 + 0.5,
        sin(facetHue * 6.2831 + 2.094) * 0.5 + 0.5,
        sin(facetHue * 6.2831 + 4.188) * 0.5 + 0.5
    );

    // Bright edge highlights (crystal edges catch light)
    float edgeHighlight = smoothstep(0.02, 0.0, edgeDist);
    float edgeGlow = smoothstep(0.08, 0.02, edgeDist);

    // Combine effects
    vec3 crystalColor = refractedColor;

    // Add rainbow caustics
    crystalColor = mix(crystalColor, crystalColor + rainbow * 0.4, caustic * facetBrightness);

    // Add bright edge highlights
    crystalColor += vec3(1.0, 0.95, 0.9) * edgeHighlight * 0.8;
    crystalColor += vec3(0.6, 0.7, 1.0) * edgeGlow * 0.3;

    // Inner facet glow
    float innerGlow = pow(cellDist, 2.0) * 0.3;
    crystalColor += rainbow * innerGlow * facetBrightness;

    float edgeMask = mix(0.35, 1.0, smoothstep(0.08, 0.62, length(clampedLocal - 0.5)));
    float overlayMask = clamp(abs(grain_intensity) + abs(sheen_strength), 0.0, 1.0) * edgeMask;

    vec3 lit = mix(base.rgb, crystalColor, overlayMask);
    lit = clamp(lit * material_tint, 0.0, 1.0);

    float alphaFactor = 1.0 - smoothstep(fade_start, 1.0, progress);
    float alpha = base.a * alphaFactor;

    if (shadow) {
        return vec4(vec3(0.0), alpha * 0.35);
    }

    return vec4(lit, alpha);
}

void main()
{
    vec2 uv = fragTexCoord;

    bool identityAtlas = abs(regionRate.x - 1.0) < 0.0001 &&
                         abs(regionRate.y - 1.0) < 0.0001 &&
                         abs(pivot.x) < 0.0001 &&
                         abs(pivot.y) < 0.0001;

    float angle = angleFlat;

    if (identityAtlas || uv_passthrough > 0.5) {
        vec2 rotated = rotate(uv, vec2(0.5), angle);

        float inset = 0.0035;
        vec2 clamped = clamp(rotated, vec2(inset), vec2(1.0 - inset));
        vec2 finalUV = identityAtlas
            ? clamped
            : (pivot + clamped * regionRate);
        finalColor = applyOverlay(finalUV);
    } else {
        float cosX = tiltCos.x;
        float cosY = tiltCos.y;
        float sinX = tiltSin.x;
        float sinY = tiltSin.y;

        vec2 centered = (uv - pivot) / regionRate;
        vec2 localCentered = centered - vec2(0.5);
        vec2 correctedUV = localCentered;
        correctedUV.x /= max(cosY, 0.5);
        correctedUV.y /= max(cosX, 0.5);
        correctedUV.x -= sinY * 0.1;
        correctedUV.y -= sinX * 0.1;
        uv = correctedUV + vec2(0.5);

        float asp = regionRate.y / regionRate.x;
        uv.y *= asp;

        uv = rotate(uv, vec2(0.5), angle);
        uv.y /= asp;

        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) discard;

        vec2 finalUV = pivot + uv * regionRate;
        finalColor = applyOverlay(finalUV);
    }
}
