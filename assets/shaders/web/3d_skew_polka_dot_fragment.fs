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
uniform vec2  polka_dot;

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

// HSV/RGB conversion for hue shifting
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Circle mask function - sharp edge circle test
float circle(vec2 uv) {
    return 1.0 - step(0.5, distance(uv, vec2(0.5)));
}

// Soft circle for smooth blending
float softCircle(vec2 uv, float softness) {
    float d = distance(uv, vec2(0.5));
    return 1.0 - smoothstep(0.5 - softness, 0.5, d);
}

// Radial gradient for shine effect - creates directional lighting on spheres
float radialGradient(vec2 uv, float targetAngle, float gradientPower, float gradientRotation) {
    float angleToCenter = atan(0.5 - uv.y, 0.5 - uv.x);
    targetAngle += gradientRotation;
    float distanceToAngle = max(
        sin(angleToCenter + targetAngle),
        sin(angleToCenter + targetAngle + 3.14159)
    );
    distanceToAngle = pow(max(distanceToAngle, 0.0), gradientPower);
    return distanceToAngle;
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

    if (effectInactive && (abs(polka_dot.x) + abs(polka_dot.y)) < EPS) {
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

    // Polka dot pattern effect - 3D spherical dots with shine
    // Use local sprite UV (0-1) for pattern to avoid atlas bleeding
    vec2 uv = clampedLocal;

    // Pattern parameters - polka_dot.x controls scale, polka_dot.y controls animation/hue
    float scale = 3.0 + polka_dot.x * 3.0;  // Dot density (3-6 dots across)
    float gradientPower = 10.0;  // Sharper shine highlights
    float gradientRotation = time * 0.4 + polka_dot.y * 2.0;  // Animated shine rotation

    // Color palette for classic polka dot look
    vec3 colorBase = vec3(0.15, 0.08, 0.25);     // Dark purple/navy base (dot shadow)
    vec3 colorShineA = vec3(0.95, 0.3, 0.5);     // Hot pink primary shine
    vec3 colorShineB = vec3(0.4, 0.9, 0.95);     // Cyan secondary shine

    // Circle positions for tiled pattern (diamond/offset arrangement)
    // This creates a proper polka dot grid where dots are offset every other row
    const vec2 POSITIONS[4] = vec2[4](
        vec2(0.0, 0.5),
        vec2(0.5, 0.0),
        vec2(-0.5, 0.0),
        vec2(0.0, -0.5)
    );

    vec2 scaledUV = uv * scale;
    vec2 tiledUV = fract(scaledUV);

    // Background color (between dots)
    vec3 patternColor = vec3(0.0);
    float patternAlpha = 0.0;

    for (int i = 0; i < 4; i++) {
        vec2 offsetUV = tiledUV + POSITIONS[i];

        // Build up sphere shading: base color + two directional shine highlights
        vec3 circleColor = colorBase;

        // Primary shine (from one direction)
        float shine1 = radialGradient(offsetUV, 0.0, gradientPower, gradientRotation);
        circleColor = mix(circleColor, colorShineA, shine1);

        // Secondary shine (perpendicular direction) for iridescent look
        float shine2 = radialGradient(offsetUV, 1.5708, gradientPower, gradientRotation);
        circleColor = mix(circleColor, colorShineB, shine2);

        // Add highlight spot at shine direction for 3D spherical look
        float highlightStrength = max(shine1, shine2);
        vec3 highlight = vec3(1.0) * pow(highlightStrength, 2.0) * 0.3;
        circleColor += highlight;

        // Use soft circle for smoother edges
        float circleMask = softCircle(offsetUV, 0.05);
        patternColor = mix(patternColor, circleColor, circleMask);
        patternAlpha = max(patternAlpha, circleMask);
    }

    // Apply subtle hue variation across the sprite for visual interest
    float hueShift = sin(uv.x * 6.2831 + time * 0.3) * cos(uv.y * 6.2831 - time * 0.2) * 0.08;
    hueShift += polka_dot.y * 0.05;  // User-controlled hue offset
    vec3 patternHSV = rgb2hsv(patternColor);
    patternHSV.x = fract(patternHSV.x + hueShift);
    // Boost saturation for vivid polka dots
    patternHSV.y = min(patternHSV.y * 1.3, 1.0);
    patternColor = hsv2rgb(patternHSV);

    // Blend pattern with base image - stronger blend where dots are
    vec3 blendedColor = mix(base.rgb, patternColor, patternAlpha * 0.85);

    float edgeMask = mix(0.35, 1.0, smoothstep(0.08, 0.62, length(clampedLocal - 0.5)));
    float overlayMask = clamp(abs(grain_intensity) + abs(sheen_strength), 0.0, 1.0) * edgeMask;

    vec3 lit = mix(base.rgb, blendedColor, overlayMask);
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
