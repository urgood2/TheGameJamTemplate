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
uniform float shadow;
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
uniform vec2  thermal;

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
    vec4 tex = texture(texture0, uv);
    vec3 rgb = tex.rgb * fragColor.rgb * colDiffuse.rgb;
    float alpha = tex.a * fragColor.a * colDiffuse.a;
    return vec4(rgb, alpha);
}

mat2 rotate2d(float a) {
    float s = sin(a);
    float c = cos(a);
    return mat2(c, -s, s, c);
}

// Classic thermal/infrared color palette
// Maps temperature (0-1) to color: black -> blue -> cyan -> green -> yellow -> orange -> red -> white
vec3 thermalPalette(float temp) {
    // Clamp temperature
    temp = clamp(temp, 0.0, 1.0);

    vec3 color;

    if (temp < 0.15) {
        // Black to dark blue
        color = mix(vec3(0.0, 0.0, 0.1), vec3(0.0, 0.0, 0.5), temp / 0.15);
    } else if (temp < 0.3) {
        // Dark blue to blue
        float t = (temp - 0.15) / 0.15;
        color = mix(vec3(0.0, 0.0, 0.5), vec3(0.0, 0.2, 0.8), t);
    } else if (temp < 0.4) {
        // Blue to cyan
        float t = (temp - 0.3) / 0.1;
        color = mix(vec3(0.0, 0.2, 0.8), vec3(0.0, 0.8, 0.8), t);
    } else if (temp < 0.5) {
        // Cyan to green
        float t = (temp - 0.4) / 0.1;
        color = mix(vec3(0.0, 0.8, 0.8), vec3(0.0, 0.9, 0.2), t);
    } else if (temp < 0.6) {
        // Green to yellow
        float t = (temp - 0.5) / 0.1;
        color = mix(vec3(0.0, 0.9, 0.2), vec3(0.9, 0.9, 0.0), t);
    } else if (temp < 0.75) {
        // Yellow to orange
        float t = (temp - 0.6) / 0.15;
        color = mix(vec3(0.9, 0.9, 0.0), vec3(1.0, 0.5, 0.0), t);
    } else if (temp < 0.9) {
        // Orange to red
        float t = (temp - 0.75) / 0.15;
        color = mix(vec3(1.0, 0.5, 0.0), vec3(1.0, 0.1, 0.0), t);
    } else {
        // Red to white (hottest)
        float t = (temp - 0.9) / 0.1;
        color = mix(vec3(1.0, 0.1, 0.0), vec3(1.0, 0.9, 0.8), t);
    }

    return color;
}

// Hash for noise
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Smooth noise
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

vec4 applyOverlay(vec2 atlasUV) {
    const float EPS = 0.0001;
    bool effectInactive =
        abs(dissolve) < EPS &&
        abs(grain_intensity) < EPS &&
        abs(sheen_strength) < EPS &&
        burn_colour_1.a < EPS &&
        burn_colour_2.a < EPS &&
        shadow < 0.5 &&
        length(material_tint - vec3(1.0)) < EPS;

    if (effectInactive && (abs(thermal.x) + abs(thermal.y)) < EPS) {
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

    // Thermal imaging effect
    vec2 uv = ((sampleUV * image_details) - texture_details.xy * texture_details.ba) / texture_details.ba;
    // Apply card rotation so the thermal pattern responds to the card's visual orientation
    vec2 rotated_uv = rotate2d(card_rotation) * (uv - 0.5) + 0.5;

    float t = thermal.y * 2.0 + time * 0.5;

    // Base temperature from image luminance
    float luminance = dot(base.rgb, vec3(0.299, 0.587, 0.114));

    // Add thermal variations
    // Heat rises - warmer at top
    float heatRise = rotated_uv.y * 0.15;

    // Radial heat from center (like a heat source)
    float centerHeat = (1.0 - dist * 1.5) * 0.2;
    centerHeat = max(0.0, centerHeat);

    // Pulsing heat waves
    float heatWave = sin(dist * 15.0 - t * 3.0) * 0.08;
    heatWave += sin(rotated_uv.x * 10.0 + t * 2.0) * cos(rotated_uv.y * 8.0 - t * 1.5) * 0.05;

    // Convection currents (rising heat patterns)
    float convection = noise(vec2(rotated_uv.x * 5.0, rotated_uv.y * 3.0 - t * 0.8)) * 0.15;
    convection += noise(vec2(rotated_uv.x * 8.0 + 1.0, rotated_uv.y * 5.0 - t * 1.2)) * 0.08;

    // Hot spots that drift
    float hotSpot1 = smoothstep(0.2, 0.0, length(rotated_uv - vec2(0.3 + 0.1 * sin(t * 0.4), 0.6 + 0.1 * cos(t * 0.3))));
    float hotSpot2 = smoothstep(0.15, 0.0, length(rotated_uv - vec2(0.7 + 0.1 * cos(t * 0.5), 0.4 + 0.1 * sin(t * 0.35))));
    float hotSpots = (hotSpot1 + hotSpot2) * 0.25;

    // Combine all thermal factors
    float temperature = luminance * 0.5;  // Base from image
    temperature += thermal.x * 0.3;       // User control offset
    temperature += heatRise;
    temperature += centerHeat;
    temperature += heatWave;
    temperature += convection;
    temperature += hotSpots;

    // Add sensor noise (thermal cameras have noise)
    float sensorNoise = (hash(rotated_uv * 200.0 + t) - 0.5) * 0.03;
    temperature += sensorNoise;

    // Clamp and apply palette
    temperature = clamp(temperature, 0.0, 1.0);
    vec3 thermalColor = thermalPalette(temperature);

    // Add slight scan line effect (like real thermal cameras)
    float scanLine = 0.97 + 0.03 * sin(rotated_uv.y * 200.0);
    thermalColor *= scanLine;

    // Subtle vignette (thermal cameras often have edge falloff)
    float vignette = 1.0 - smoothstep(0.4, 0.7, dist);
    thermalColor *= 0.85 + 0.15 * vignette;

    float edgeMask = mix(0.35, 1.0, smoothstep(0.08, 0.62, length(clampedLocal - 0.5)));
    float overlayMask = clamp(abs(grain_intensity) + abs(sheen_strength), 0.0, 1.0) * edgeMask;

    vec3 lit = mix(base.rgb, thermalColor, overlayMask);
    lit = clamp(lit * material_tint, 0.0, 1.0);

    float alphaFactor = 1.0 - smoothstep(fade_start, 1.0, progress);
    float alpha = base.a * alphaFactor;

    if (shadow > 0.5) {
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
