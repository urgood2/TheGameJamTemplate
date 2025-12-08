#version 300 es
precision mediump float;

precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform vec2 regionRate;
uniform vec2 pivot;

in mat3 invRotMat;
in vec2 worldMouseUV;
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

mat2 rotate2d(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

vec4 sampleTinted(vec2 uv) {
    return texture(texture0, uv) * fragColor * colDiffuse;
}

// Simplex-like noise for organic flow
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p);
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

// More accurate thin-film model with viewing angle
vec3 oilSlickColor(float thickness, float viewAngle) {
    // Adjust thickness based on viewing angle (longer path at oblique angles)
    float effectiveThickness = thickness / max(cos(viewAngle * 1.5), 0.3);

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

    vec2 displaced = centered + dir * progress * spread_strength;
    displaced += distortion_strength * vec2(
        sin(dist * 20.0 - time * 10.0),
        cos(dist * 20.0 - time * 8.0)
    ) * progress;

    vec2 warpedLocal = displaced + vec2(0.5);
    vec2 clampedLocal = clamp(warpedLocal, 0.0, 1.0);

    vec2 sampleUV = localToAtlas(clampedLocal);
    vec4 base = sampleTinted(sampleUV);

    vec2 rotated = rotate2d(card_rotation) * (clampedLocal - 0.5);

    // Oil slick / thin-film interference effect
    vec2 uv = ((sampleUV * image_details) - texture_details.xy * texture_details.ba) / texture_details.ba;

    float t = time * 0.3;

    // Simulate oil spreading/flowing on water
    // Multiple layers of flowing noise create organic patterns
    vec2 flowUV1 = uv * 3.0 + vec2(t * 0.2, t * 0.1);
    vec2 flowUV2 = uv * 5.0 - vec2(t * 0.15, t * 0.25);
    vec2 flowUV3 = uv * 2.0 + vec2(sin(t * 0.1) * 0.5, cos(t * 0.15) * 0.5);

    float flow1 = fbm(flowUV1);
    float flow2 = fbm(flowUV2);
    float flow3 = fbm(flowUV3);

    // Combine flows into oil film thickness variation
    float thickness = (flow1 * 0.5 + flow2 * 0.3 + flow3 * 0.2);

    // Add user control for base thickness
    thickness = thickness * (0.5 + oil_slick.x * 0.5) + oil_slick.y * 0.2;

    // Simulate viewing angle based on UV position (like tilting the surface)
    float viewAngle = length(uv - 0.5) * 0.8;

    // Get interference color
    vec3 slickColor = oilSlickColor(thickness * 4.0, viewAngle);

    // Add swirling patterns where oil pools
    float swirl = sin(atan(uv.y - 0.5, uv.x - 0.5) * 3.0 + thickness * 10.0 + t) * 0.5 + 0.5;
    vec3 swirlColor = oilSlickColor((thickness + swirl * 0.1) * 4.0, viewAngle);
    slickColor = mix(slickColor, swirlColor, 0.3);

    // Dark regions where oil is thickest (absorbs light)
    float darkness = smoothstep(0.6, 0.8, thickness);
    slickColor = mix(slickColor, slickColor * 0.3, darkness * 0.5);

    // Bright specular highlights on the oil surface
    float specular = pow(flow1 * flow2, 3.0) * 2.0;
    slickColor += vec3(1.0, 0.98, 0.95) * specular * 0.3;

    // Edge rainbow effect (oil often shows strongest colors at edges)
    float edgeIntensity = smoothstep(0.3, 0.5, dist);
    vec3 edgeColor = oilSlickColor(thickness * 5.0 + edgeIntensity, viewAngle + 0.2);
    slickColor = mix(slickColor, edgeColor, edgeIntensity * 0.4);

    // Blend with base image
    float blendFactor = 0.6 + 0.2 * sin(thickness * 6.2831);
    vec3 oilColor = mix(base.rgb * 0.7, slickColor, blendFactor);

    float edgeMask = mix(0.35, 1.0, smoothstep(0.08, 0.62, length(clampedLocal - 0.5)));
    float overlayMask = clamp(abs(grain_intensity) + abs(sheen_strength), 0.0, 1.0) * edgeMask;

    vec3 lit = mix(base.rgb, oilColor, overlayMask);
    lit = clamp(lit * material_tint, 0.0, 1.0);

    float alphaFactor = 1.0 - smoothstep(fade_start, 1.0, progress);
    float alpha = base.a * alphaFactor;

    float edgeDistance = length(warpedLocal - clampedLocal);
    float burnMask = smoothstep(0.0, 0.02, edgeDistance) * (1.0 - alphaFactor);

    if (!shadow && burn_colour_1.a > 0.01) {
        vec3 burnMix = burn_colour_1.rgb;
        if (burn_colour_2.a > 0.01) {
            float t = clamp(edgeDistance / 0.04, 0.0, 1.0);
            burnMix = mix(burn_colour_1.rgb, burn_colour_2.rgb, t);
        }
        lit = mix(lit, burnMix, clamp(burnMask * burn_colour_1.a, 0.0, 1.0));
    }

    if (shadow) {
        return vec4(vec3(0.0), alpha * 0.35);
    }

    return vec4(lit, alpha);
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

    float angle = angleFlat;
    uv = rotate(uv, vec2(0.5), angle);
    uv.y /= asp;

    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) discard;

    vec2 finalUV = pivot + uv * regionRate;

    finalColor = applyOverlay(finalUV);
}
