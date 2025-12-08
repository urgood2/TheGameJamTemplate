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

// Circle mask function
float circle(vec2 uv) {
    return 1.0 - step(0.5, distance(uv, vec2(0.5)));
}

// Radial gradient for shine effect
float radialGradient(vec2 uv, float targetAngle, float gradientPower, float gradientRotation) {
    float angleToCenter = atan(0.5 - uv.y, 0.5 - uv.x);
    targetAngle += gradientRotation;
    float distanceToAngle = max(
        sin(angleToCenter + targetAngle),
        sin(angleToCenter + targetAngle + 3.14159)
    );
    distanceToAngle = pow(distanceToAngle, gradientPower);
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

    vec2 uvOutward = centered + dir * progress * spread_strength;
    uvOutward += distortion_strength * vec2(
        sin(dist * 20.0 - time * 10.0),
        cos(dist * 20.0 - time * 8.0)
    ) * progress;

    vec2 warpedLocal = uvOutward + vec2(0.5);
    vec2 sampleUV = localToAtlas(warpedLocal);
    vec4 base = sampleTinted(sampleUV);

    vec2 clampedLocal = clamp(warpedLocal, 0.0, 1.0);

    // Polka dot / circle pattern effect
    vec2 uv = ((sampleUV * image_details) - texture_details.xy * texture_details.ba) / texture_details.ba;

    // Pattern parameters
    float scale = 2.0 + polka_dot.x * 2.0;  // Dot density
    float gradientPower = 8.0;
    float gradientRotation = time * 0.3 + polka_dot.y;

    // Color palette - holographic/iridescent feel
    vec3 colorBase = vec3(0.2, 0.1, 0.3);      // Deep purple base
    vec3 colorShineA = vec3(0.0, 0.8, 0.9);    // Cyan shine
    vec3 colorShineB = vec3(1.0, 0.4, 0.7);    // Pink shine

    // Circle positions for tiled pattern (diamond arrangement)
    const vec2 POSITIONS[4] = vec2[4](
        vec2(0.0, 0.5),
        vec2(0.5, 0.0),
        vec2(-0.5, 0.0),
        vec2(0.0, -0.5)
    );

    vec2 scaledUV = uv * scale;
    vec2 tiledUV = fract(scaledUV);

    vec3 patternColor = vec3(0.0);

    for (int i = 0; i < 4; i++) {
        vec2 offsetUV = tiledUV + POSITIONS[i];

        vec3 circleColor = colorBase;
        circleColor = mix(circleColor, colorShineA, radialGradient(offsetUV, 0.0, gradientPower, gradientRotation));
        circleColor = mix(circleColor, colorShineB, radialGradient(offsetUV, 1.5708, gradientPower, gradientRotation));

        patternColor = mix(patternColor, circleColor, circle(offsetUV));
    }

    // Apply hue shift based on position for extra iridescence
    float hueShift = sin(uv.x * 3.14159 + time * 0.5) * cos(uv.y * 3.14159 - time * 0.3) * 0.15;
    vec3 patternHSV = rgb2hsv(patternColor);
    patternHSV.x = fract(patternHSV.x + hueShift + polka_dot.y * 0.1);
    patternColor = hsv2rgb(patternHSV);

    // Blend pattern with base image
    float patternIntensity = length(patternColor);
    vec3 blendedColor = mix(base.rgb, patternColor, patternIntensity * 0.7);

    float edgeMask = mix(0.35, 1.0, smoothstep(0.08, 0.62, length(clampedLocal - 0.5)));
    float overlayMask = clamp(abs(grain_intensity) + abs(sheen_strength), 0.0, 1.0) * edgeMask;

    vec3 lit = mix(base.rgb, blendedColor, overlayMask);
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
