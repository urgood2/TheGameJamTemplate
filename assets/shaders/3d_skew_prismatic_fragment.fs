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
// Per-card random seed for unique overlay variations
// Expected range: [0.0, 1.0]
// Used to offset animation phases, noise patterns, and color variations
// so that cards with the same effect type don't look identical
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
uniform vec2  prismatic;

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

mat2 rotate2d(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

float hue(float s, float t, float h) {
    float hs = mod(h, 1.0) * 6.0;
    if (hs < 1.0) return (t - s) * hs + s;
    if (hs < 3.0) return t;
    if (hs < 4.0) return (t - s) * (4.0 - hs) + s;
    return s;
}

vec4 RGB(vec4 c) {
    if (c.y < 0.0001) {
        return vec4(vec3(c.z), c.a);
    }
    float t = (c.z < 0.5) ? c.y * c.z + c.z : -c.y * c.z + (c.y + c.z);
    float s = 2.0 * c.z - t;
    return vec4(hue(s, t, c.x + 1.0 / 3.0),
                hue(s, t, c.x),
                hue(s, t, c.x - 1.0 / 3.0),
                c.w);
}

vec4 HSL(vec4 c) {
    float low = min(c.r, min(c.g, c.b));
    float high = max(c.r, max(c.g, c.b));
    float delta = high - low;
    float sum = high + low;

    vec4 hsl = vec4(0.0, 0.0, 0.5 * sum, c.a);
    if (delta == 0.0) {
        return hsl;
    }

    hsl.y = (hsl.z < 0.5) ? delta / sum : delta / (2.0 - sum);

    if (high == c.r) {
        hsl.x = (c.g - c.b) / delta;
    } else if (high == c.g) {
        hsl.x = (c.b - c.r) / delta + 2.0;
    } else {
        hsl.x = (c.r - c.g) / delta + 4.0;
    }

    hsl.x = mod(hsl.x / 6.0, 1.0);
    return hsl;
}

// Calculate distance to nearest facet edge
float facetPattern(vec2 uv, float t, float seed) {
    // Create angular facets like a cut gem
    vec2 centered = uv - 0.5;
    float angle = atan(centered.y, centered.x);
    float radius = length(centered);

    // Number of facets
    float numFacets = 8.0;
    float facetAngle = 3.14159 * 2.0 / numFacets;

    // Rotating facet boundaries with per-card seed offset
    float seedPhase = seed * 6.2831;
    float rotatedAngle = angle + t * 0.3 + prismatic.x * 0.5 + seedPhase * 0.5;
    float facetIndex = floor(rotatedAngle / facetAngle);
    float facetFrac = fract(rotatedAngle / facetAngle);

    // Distance to facet edge (creates sharp lines)
    float edgeDist = min(facetFrac, 1.0 - facetFrac);

    // Concentric rings for internal reflections with seed variation
    float rings = fract(radius * 6.0 - t * 0.5 + seed * 0.3);
    float ringEdge = min(rings, 1.0 - rings);

    return min(edgeDist, ringEdge * 2.0);
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

    if (effectInactive && (abs(prismatic.x) + abs(prismatic.y)) < EPS) {
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

    // Prismatic crystal effect
    vec2 uv = ((sampleUV * image_details) - texture_details.xy * texture_details.ba) / texture_details.ba;
    // Apply card rotation so the prismatic pattern responds to the card's visual orientation
    vec2 rotated_uv = rotate2d(card_rotation) * (uv - 0.5) + 0.5;

    float t = prismatic.y * 2.0 + time;
    // Per-card seed for unique prismatic patterns
    float seedPhase = rand_seed * 6.2831;

    // Get facet pattern
    float facet = facetPattern(rotated_uv, t, rand_seed);

    // Rainbow dispersion along facet edges
    vec2 uvCentered = rotated_uv - 0.5;
    float angle = atan(uvCentered.y, uvCentered.x);
    float radius = length(uvCentered);

    // Hue based on angle (like light splitting through prism) with seed offset
    float baseHue = (angle / 6.28318 + 0.5); // 0-1 around the circle
    baseHue += prismatic.x * 0.3 + rand_seed * 0.25; // Shift with control and seed
    baseHue += t * 0.1; // Slow rotation

    // Sharper rainbow at edges
    float edgeIntensity = 1.0 - smoothstep(0.0, 0.15, facet);

    // Internal light caustics with seed variation
    float caustic1 = sin(radius * 20.0 + angle * 3.0 - t * 2.0 + seedPhase * 0.4);
    float caustic2 = sin(radius * 15.0 - angle * 5.0 + t * 1.5 + seedPhase * 0.6);
    float caustics = (caustic1 * caustic2 + 1.0) * 0.5;
    caustics = pow(caustics, 3.0);

    // Sparkle highlights at facet intersections with seed offset
    float sparkle = pow(1.0 - facet, 8.0);
    sparkle *= 0.5 + 0.5 * sin(t * 8.0 + angle * 12.0 + seedPhase * 0.8);

    // Combine effects
    vec4 baseHSL = HSL(base);

    // Apply rainbow hue shift strongest at edges
    float hueShift = baseHue * edgeIntensity * 0.8;
    hueShift += caustics * 0.2;
    baseHSL.x = mod(baseHSL.x + hueShift, 1.0);

    // Boost saturation for vivid rainbow
    baseHSL.y = min(0.9, baseHSL.y + 0.5 * edgeIntensity);

    // Brighten at sparkle points
    baseHSL.z = clamp(baseHSL.z + sparkle * 0.4 + caustics * 0.15, 0.0, 0.95);

    vec3 prismaticColor = RGB(baseHSL).rgb;

    // Add white sparkle highlights
    prismaticColor += vec3(1.0) * sparkle * 0.6;

    // Subtle chromatic aberration at edges
    float edgeDist = length(clampedLocal - 0.5);
    float aberration = smoothstep(0.3, 0.5, edgeDist) * 0.003;
    vec3 aberrated = vec3(
        texture(texture0, sampleUV + vec2(aberration, 0.0)).r,
        base.g,
        texture(texture0, sampleUV - vec2(aberration, 0.0)).b
    );
    prismaticColor = mix(prismaticColor, prismaticColor * (aberrated / max(base.rgb, vec3(0.01))), edgeIntensity * 0.3);

    float overlayMask = clamp(abs(grain_intensity) + abs(sheen_strength), 0.0, 1.0);

    vec3 lit = mix(base.rgb, prismaticColor, overlayMask);
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
