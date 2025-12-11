#version 300 es
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
uniform vec2  iridescent;

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

// Thin-film interference simulation
// Models the physics of light interference in thin films (oil, soap bubbles, beetle shells)
float thinFilmHue(float thickness, float viewAngle) {
    // Simplified thin-film interference
    // Different wavelengths interfere at different thicknesses
    float n = 1.4; // refractive index approximation
    float pathDiff = 2.0 * n * thickness * cos(viewAngle);

    // This creates the characteristic smooth color bands
    return fract(pathDiff * 2.0);
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

    if (effectInactive && (abs(iridescent.x) + abs(iridescent.y)) < EPS) {
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

    // Iridescent oil-slick / beetle shell effect
    vec2 uv = ((sampleUV * image_details) - texture_details.xy * texture_details.ba) / texture_details.ba;

    float t = iridescent.y * 1.2 + time * 0.4;

    vec2 uvCentered = uv - 0.5;
    float radius = length(uvCentered);
    float angle = atan(uvCentered.y, uvCentered.x);

    // Simulate viewing angle based on position (like looking at curved surface)
    float viewAngle = radius * 1.5;

    // Create organic flowing thickness variation (like oil pooling)
    float flow1 = sin(uvCentered.x * 8.0 + t * 0.7) * cos(uvCentered.y * 6.0 - t * 0.5);
    float flow2 = sin(uvCentered.x * 5.0 - uvCentered.y * 7.0 + t * 0.6);
    float flow3 = cos(radius * 10.0 - t * 0.8);

    // Combine for organic film thickness
    float thickness = 0.5 + 0.3 * flow1 + 0.2 * flow2 + 0.15 * flow3;
    thickness += iridescent.x * 0.3;

    // Add slow drifting movement
    thickness += 0.1 * sin(uv.x * 3.0 + uv.y * 2.0 + t * 0.3);

    // Get interference hue
    float interferenceHue = thinFilmHue(thickness, viewAngle);

    // Iridescent colors favor blue-purple-pink-green transitions
    // Shift the hue to start in the blue range for oil-slick look
    float hueShift = interferenceHue * 0.6 + 0.55; // Concentrate in blue-purple-pink range

    // Add secondary color band for richness
    float hue2 = thinFilmHue(thickness * 1.3 + 0.2, viewAngle * 0.8);
    hueShift = mix(hueShift, hue2 * 0.5 + 0.6, 0.3);

    // Intensity varies with viewing angle (brighter at glancing angles)
    float fresnel = pow(1.0 - cos(viewAngle * 0.5), 2.0);
    float intensity = 0.4 + 0.6 * fresnel;

    // Add subtle shimmer
    float shimmer = 0.5 + 0.5 * sin(angle * 8.0 + t * 3.0);
    shimmer *= 0.5 + 0.5 * sin(radius * 20.0 - t * 2.0);
    intensity += shimmer * 0.15;

    // Apply to base color
    vec4 baseHSL = HSL(base);
    baseHSL.x = mod(hueShift, 1.0);
    baseHSL.y = min(0.85, baseHSL.y + 0.5 * intensity);
    baseHSL.z = clamp(baseHSL.z + 0.1 * intensity, 0.0, 0.9);

    vec3 iridColor = RGB(baseHSL).rgb;

    // Add pearlescent highlight
    float pearl = pow(fresnel, 3.0) * 0.3;
    iridColor += vec3(0.9, 0.85, 1.0) * pearl;

    float overlayMask = clamp(abs(grain_intensity) + abs(sheen_strength), 0.0, 1.0);

    vec3 lit = mix(base.rgb, iridColor, overlayMask);
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
