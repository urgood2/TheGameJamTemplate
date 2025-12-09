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
uniform vec2  oil_slick;

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

// Simplex-like noise for organic flow (seed parameter for per-card variation)
float hash(vec2 p, float seed) {
    p = fract(p * vec2(123.34, 456.21) + seed * vec2(78.91, 32.45));
    p += dot(p, p + 45.32 + seed * 17.89);
    return fract(p.x * p.y);
}

float noise(vec2 p, float seed) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i, seed);
    float b = hash(i + vec2(1.0, 0.0), seed);
    float c = hash(i + vec2(0.0, 1.0), seed);
    float d = hash(i + vec2(1.0, 1.0), seed);

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p, float seed) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p, seed);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// Thin-film interference color based on thickness
// Simulates the physics of light interference in thin oil films
vec3 thinFilmInterference(float thickness) {
    // Wavelength-dependent phase shifts create color
    // Red, green, blue have different wavelengths
    float phase = thickness * 6.2831;

    // Each color channel interferes at different rates
    float r = 0.5 + 0.5 * cos(phase * 1.0);
    float g = 0.5 + 0.5 * cos(phase * 1.2 + 0.5);
    float b = 0.5 + 0.5 * cos(phase * 1.4 + 1.0);

    return vec3(r, g, b);
}

// More accurate thin-film model - simplified without radial viewing angle
vec3 oilSlickColor(float thickness, float flowVariation) {
    // Use flow variation instead of radial viewing angle to avoid circular banding
    float effectiveThickness = thickness * (1.0 + flowVariation * 0.3);

    // Multiple interference orders create richer colors
    vec3 color1 = thinFilmInterference(effectiveThickness);
    vec3 color2 = thinFilmInterference(effectiveThickness * 1.5);
    vec3 color3 = thinFilmInterference(effectiveThickness * 2.0);

    // Blend different orders
    vec3 result = color1 * 0.5 + color2 * 0.3 + color3 * 0.2;

    // Boost saturation
    float gray = dot(result, vec3(0.299, 0.587, 0.114));
    result = mix(vec3(gray), result, 1.5);

    return result;
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

    if (effectInactive && (abs(oil_slick.x) + abs(oil_slick.y)) < EPS) {
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

    // Oil slick / thin-film interference effect
    vec2 uv = ((sampleUV * image_details) - texture_details.xy * texture_details.ba) / texture_details.ba;

    float t = time * 0.3;

    // Per-card seed for unique oil patterns
    float seedOffset = rand_seed * 10.0;

    // Simulate oil spreading/flowing on water
    // Multiple layers of flowing noise create organic, non-radial patterns
    vec2 flowUV1 = uv * 3.0 + vec2(t * 0.2 + seedOffset * 0.1, t * 0.1 + seedOffset * 0.15);
    vec2 flowUV2 = uv * 5.0 - vec2(t * 0.15 - seedOffset * 0.08, t * 0.25 - seedOffset * 0.12);
    vec2 flowUV3 = uv * 2.0 + vec2(sin(t * 0.1 + rand_seed * 3.14) * 0.5, cos(t * 0.15 + rand_seed * 2.71) * 0.5);
    vec2 flowUV4 = uv * 4.0 + vec2(t * 0.08 + seedOffset * 0.05, -t * 0.12 + seedOffset * 0.07);

    float flow1 = fbm(flowUV1, rand_seed);
    float flow2 = fbm(flowUV2, rand_seed + 0.33);
    float flow3 = fbm(flowUV3, rand_seed + 0.66);
    float flow4 = fbm(flowUV4, rand_seed + 0.5);

    // Combine flows into oil film thickness variation
    // Use more flow layers to break up any remaining patterns
    float thickness = (flow1 * 0.35 + flow2 * 0.25 + flow3 * 0.25 + flow4 * 0.15);

    // Add user control for base thickness
    thickness = thickness * (0.5 + oil_slick.x * 0.5) + oil_slick.y * 0.2;

    // Use flow-based variation instead of radial viewing angle to avoid circular banding
    float flowVariation = (flow1 - flow2) * 2.0;

    // Get interference color using flow-based variation
    vec3 slickColor = oilSlickColor(thickness * 4.0, flowVariation);

    // Add flowing/swirling patterns where oil pools (non-radial)
    // Use directional flow instead of radial atan
    float swirl = sin(uv.x * 8.0 + uv.y * 6.0 + thickness * 10.0 + t * 2.0) * 0.5 + 0.5;
    swirl *= sin(uv.x * 5.0 - uv.y * 7.0 + flow1 * 5.0 - t) * 0.5 + 0.5;
    vec3 swirlColor = oilSlickColor((thickness + swirl * 0.15) * 4.0, flowVariation * 0.8);
    slickColor = mix(slickColor, swirlColor, 0.35);

    // Dark regions where oil is thickest (absorbs light)
    float darkness = smoothstep(0.55, 0.75, thickness);
    slickColor = mix(slickColor, slickColor * 0.4, darkness * 0.4);

    // Bright specular highlights on the oil surface
    float specular = pow(flow1 * flow2, 3.0) * 2.0;
    slickColor += vec3(1.0, 0.98, 0.95) * specular * 0.25;

    // Edge color variation based on flow, not radial distance
    float edgeFlow = smoothstep(0.3, 0.7, flow3);
    vec3 edgeColor = oilSlickColor(thickness * 5.0 + edgeFlow * 0.5, flowVariation + 0.2);
    slickColor = mix(slickColor, edgeColor, edgeFlow * 0.3);

    // Blend with base image - use smooth thickness gradient, not sinusoidal bands
    float blendFactor = 0.55 + 0.25 * thickness;
    vec3 oilColor = mix(base.rgb * 0.7, slickColor, blendFactor);

    // Use uniform mask (no radial variation) to avoid circular banding
    float overlayMask = clamp(abs(grain_intensity) + abs(sheen_strength), 0.0, 1.0);

    vec3 lit = mix(base.rgb, oilColor, overlayMask);
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
