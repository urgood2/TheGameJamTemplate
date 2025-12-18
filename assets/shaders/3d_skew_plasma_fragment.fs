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
uniform vec2  plasma;

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

// Hash for randomness
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Noise function
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

// Electric arc function - creates branching lightning patterns
float electricArc(vec2 uv, vec2 start, vec2 end, float t, float seed) {
    vec2 dir = end - start;
    float len = length(dir);
    dir /= len;

    vec2 toPoint = uv - start;
    float along = dot(toPoint, dir);
    float across = abs(dot(toPoint, vec2(-dir.y, dir.x)));

    // Only affect points along the arc
    if (along < 0.0 || along > len) return 0.0;

    // Jagged displacement perpendicular to arc
    float displacement = 0.0;
    float freq = 15.0;
    float amp = 0.08;

    for (int i = 0; i < 4; i++) {
        displacement += amp * sin(along * freq + t * (8.0 + float(i) * 2.0) + seed * 100.0);
        freq *= 2.1;
        amp *= 0.5;
    }

    // Distance from the displaced arc center
    float dist = abs(across - displacement);

    // Sharp falloff for electric look
    float arc = smoothstep(0.025, 0.0, dist);

    // Add flickering
    float flicker = 0.7 + 0.3 * sin(t * 20.0 + seed * 50.0);
    arc *= flicker;

    // Taper at ends
    float taper = smoothstep(0.0, 0.1, along / len) * smoothstep(0.0, 0.1, 1.0 - along / len);
    arc *= taper;

    return arc;
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

    if (effectInactive && (abs(plasma.x) + abs(plasma.y)) < EPS) {
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

    // Plasma electric effect
    vec2 uv = ((sampleUV * image_details) - texture_details.xy * texture_details.ba) / texture_details.ba;
    // Apply card rotation so the plasma pattern responds to the card's visual orientation
    vec2 rotated_uv = rotate2d(card_rotation) * (uv - 0.5) + 0.5;

    float t = plasma.y * 3.0 + time * 2.0;

    // Create multiple electric arcs
    float totalArc = 0.0;

    // Arc 1: diagonal
    vec2 start1 = vec2(0.1, 0.2);
    vec2 end1 = vec2(0.9, 0.7);
    totalArc += electricArc(rotated_uv, start1, end1, t, plasma.x);

    // Arc 2: opposite diagonal
    vec2 start2 = vec2(0.15, 0.8);
    vec2 end2 = vec2(0.85, 0.25);
    totalArc += electricArc(rotated_uv, start2, end2, t * 1.1, plasma.x + 1.0);

    // Arc 3: horizontal with offset
    vec2 start3 = vec2(0.05, 0.5 + 0.1 * sin(t * 0.5));
    vec2 end3 = vec2(0.95, 0.5 - 0.1 * sin(t * 0.5 + 1.0));
    totalArc += electricArc(rotated_uv, start3, end3, t * 0.9, plasma.x + 2.0);

    // Arc 4: vertical
    vec2 start4 = vec2(0.5 + 0.1 * cos(t * 0.4), 0.1);
    vec2 end4 = vec2(0.5 - 0.1 * cos(t * 0.4), 0.9);
    totalArc += electricArc(rotated_uv, start4, end4, t * 1.2, plasma.x + 3.0);

    // Background plasma field
    float plasmaField = 0.0;
    plasmaField += sin(rotated_uv.x * 10.0 + t * 3.0) * cos(rotated_uv.y * 8.0 - t * 2.0);
    plasmaField += sin(rotated_uv.x * 15.0 - t * 4.0 + rotated_uv.y * 12.0) * 0.5;
    plasmaField += cos(length(rotated_uv - 0.5) * 20.0 - t * 5.0) * 0.3;
    plasmaField = (plasmaField + 2.0) / 4.0; // Normalize to 0-1

    // Pulsing energy nodes
    float pulse = 0.0;
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        vec2 nodePos = vec2(
            0.5 + 0.3 * cos(t * 0.3 + fi * 1.2),
            0.5 + 0.3 * sin(t * 0.4 + fi * 1.5)
        );
        float nodeDist = length(rotated_uv - nodePos);
        float nodeGlow = smoothstep(0.15, 0.0, nodeDist);
        nodeGlow *= 0.5 + 0.5 * sin(t * 6.0 + fi * 2.0);
        pulse += nodeGlow;
    }

    // Combine effects
    float intensity = totalArc + plasmaField * 0.3 + pulse * 0.5;
    intensity = clamp(intensity, 0.0, 1.0);

    // Plasma colors: cyan core -> purple -> blue edges
    vec4 baseHSL = HSL(base);

    // Hot white-cyan core, purple-blue outer
    float hueVal = mix(0.55, 0.75, 1.0 - intensity); // Cyan to purple
    hueVal += plasma.x * 0.1;

    // Bright arcs are more cyan/white
    float arcBrightness = smoothstep(0.3, 1.0, totalArc);
    hueVal = mix(hueVal, 0.52, arcBrightness); // Shift to cyan for bright arcs

    baseHSL.x = mod(hueVal, 1.0);
    baseHSL.y = min(0.9, 0.5 + 0.5 * intensity);
    baseHSL.z = clamp(baseHSL.z + 0.4 * intensity, 0.0, 0.95);

    vec3 plasmaColor = RGB(baseHSL).rgb;

    // Add bright white core to arcs
    plasmaColor += vec3(1.0, 0.95, 1.0) * pow(totalArc, 2.0) * 0.8;

    // Add glow around arcs
    float glow = smoothstep(0.0, 0.5, totalArc) * 0.4;
    plasmaColor += vec3(0.3, 0.5, 1.0) * glow;

    float edgeMask = mix(0.35, 1.0, smoothstep(0.08, 0.62, length(clampedLocal - 0.5)));
    float overlayMask = clamp(abs(grain_intensity) + abs(sheen_strength), 0.0, 1.0) * edgeMask;

    vec3 lit = mix(base.rgb, plasmaColor, overlayMask);
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
