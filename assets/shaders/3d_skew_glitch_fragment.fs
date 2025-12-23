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
uniform vec2  glitch;

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

// Hash functions for randomness
float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

float hash2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Stepped noise for block glitches
float blockNoise(vec2 uv, float blockSize) {
    vec2 block = floor(uv * blockSize);
    return hash2(block);
}

// Random glitch trigger based on time
float glitchTrigger(float t, float seed) {
    float n = hash(floor(t * 10.0) + seed);
    return step(0.85, n);  // Only trigger ~15% of the time
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

    if (effectInactive && (abs(glitch.x) + abs(glitch.y)) < EPS) {
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

    vec2 clampedLocal = clamp(warpedLocal, 0.0, 1.0);

    // Glitch / Digital distortion effect
    vec2 uv = ((sampleUV * image_details) - texture_details.xy * texture_details.ba) / texture_details.ba;
    // Apply card rotation so the glitch pattern responds to the card's visual orientation
    vec2 rotated_uv = rotate2d(card_rotation) * (uv - 0.5) + 0.5;

    float t = time;
    float glitchIntensity = glitch.x;
    float glitchSpeed = 1.0 + glitch.y * 2.0;

    // Early exit if no glitch effect is active (intensity is zero)
    if (glitchIntensity < 0.0001) {
        vec4 base = sampleTinted(sampleUV);
        float edgeMask = mix(0.35, 1.0, smoothstep(0.08, 0.62, length(clampedLocal - 0.5)));
        float overlayMask = clamp(abs(grain_intensity) + abs(sheen_strength), 0.0, 1.0) * edgeMask;
        vec3 lit = clamp(base.rgb * material_tint, 0.0, 1.0);
        float alphaFactor = 1.0 - smoothstep(fade_start, 1.0, progress);
        float alpha = base.a * alphaFactor;
        if (shadow) {
            return vec4(vec3(0.0), alpha * 0.35);
        }
        return vec4(lit, alpha);
    }

    // Per-card seed offset for unique glitch patterns
    float seedOffset = rand_seed * 100.0;

    // Glitch timing - creates bursts of glitches (with per-card seed variation)
    float burst1 = glitchTrigger(t * glitchSpeed + seedOffset * 0.01, 1.0 + rand_seed);
    float burst2 = glitchTrigger(t * glitchSpeed * 1.3 + seedOffset * 0.013, 2.0 + rand_seed);
    float burst3 = glitchTrigger(t * glitchSpeed * 0.7 + seedOffset * 0.007, 3.0 + rand_seed);
    float burstTotal = max(burst1, max(burst2, burst3));

    // Horizontal line displacement (VHS-style) with seed variation
    float lineNoise = hash(floor(rotated_uv.y * 50.0 + t * 30.0 + seedOffset));
    float lineDisplace = (lineNoise - 0.5) * 0.1 * glitchIntensity * burstTotal;

    // Block displacement with seed variation
    float blockSize = 8.0 + hash(floor(t * 5.0) + seedOffset * 0.1) * 8.0;
    float blockDisplace = (blockNoise(rotated_uv + rand_seed * 0.5, blockSize) - 0.5) * 0.15 * glitchIntensity * burst1;

    // Vertical tear/shift with seed variation
    float tearY = step(0.5, hash(floor(t * 8.0) + seedOffset * 0.2));
    float tearAmount = (hash(floor(rotated_uv.y * 20.0 + t * 15.0 + seedOffset)) - 0.5) * 0.2 * tearY * glitchIntensity;

    // Apply displacements in local sprite UV space to prevent atlas bleeding
    vec2 glitchLocalUV = warpedLocal;
    glitchLocalUV.x += lineDisplace + tearAmount;
    glitchLocalUV.x += blockDisplace * burst2;

    // RGB channel splitting (chromatic aberration on steroids)
    float splitAmount = 0.01 + 0.03 * glitchIntensity * burstTotal;
    splitAmount += 0.02 * sin(rotated_uv.y * 100.0 + t * 50.0) * burst1;

    // Calculate offsets in local UV space and clamp to sprite boundaries
    vec2 localR = glitchLocalUV + vec2(splitAmount, splitAmount * 0.3 * burst2);
    vec2 localG = glitchLocalUV;
    vec2 localB = glitchLocalUV + vec2(-splitAmount, -splitAmount * 0.3 * burst2);

    // Clamp to sprite bounds to prevent atlas bleeding
    localR = clamp(localR, 0.0, 1.0);
    localG = clamp(localG, 0.0, 1.0);
    localB = clamp(localB, 0.0, 1.0);

    // Convert back to atlas coordinates
    vec2 uvR = localToAtlas(localR);
    vec2 uvG = localToAtlas(localG);
    vec2 uvB = localToAtlas(localB);

    vec3 glitchColor;
    glitchColor.r = sampleTinted(uvR).r;
    glitchColor.g = sampleTinted(uvG).g;
    glitchColor.b = sampleTinted(uvB).b;

    // Scanlines
    float scanline = 0.95 + 0.05 * sin(rotated_uv.y * 400.0 + t * 10.0);
    glitchColor *= scanline;

    // Occasional color inversion in blocks (with seed variation)
    float invertBlock = step(0.92, blockNoise(rotated_uv + t * 0.1 + rand_seed * 0.3, 12.0)) * burst1;
    glitchColor = mix(glitchColor, 1.0 - glitchColor, invertBlock);

    // Color quantization (reduce color depth for digital look)
    float quantize = 16.0 - 8.0 * burst2;
    glitchColor = floor(glitchColor * quantize) / quantize;

    // Static noise overlay (with seed variation)
    float staticNoise = hash2(rotated_uv * 500.0 + t * 100.0 + rand_seed * 50.0);
    float staticIntensity = 0.05 + 0.15 * burstTotal * glitchIntensity;
    glitchColor = mix(glitchColor, vec3(staticNoise), staticIntensity);

    // Horizontal noise bands (with seed variation)
    float bandY = floor(rotated_uv.y * 30.0 + t * 20.0 + seedOffset * 0.05);
    float band = step(0.9, hash(bandY + seedOffset * 0.1)) * burstTotal;
    glitchColor = mix(glitchColor, vec3(hash(bandY + 0.5 + seedOffset)), band * 0.5);

    // Rolling bar (like old TV interference) with seed variation
    float rollSpeed = 2.0;
    float rollPos = fract(t * rollSpeed * 0.1 + rand_seed * 0.5);
    float rollBar = smoothstep(0.0, 0.02, abs(rotated_uv.y - rollPos)) *
                    smoothstep(0.0, 0.02, abs(rotated_uv.y - rollPos - 1.0));
    rollBar = 1.0 - (1.0 - rollBar) * 0.3 * step(0.7, hash(floor(t * 2.0) + seedOffset * 0.3));
    glitchColor *= rollBar;

    // Occasional full-frame color shift (with seed variation)
    float colorShift = hash(floor(t * 4.0) + seedOffset * 0.2);
    if (colorShift > 0.95 && burstTotal > 0.5) {
        glitchColor = glitchColor.gbr;  // Rotate color channels
    } else if (colorShift > 0.9 && burstTotal > 0.5) {
        glitchColor = glitchColor.brg;
    }

    // Sample base for blending
    vec4 base = sampleTinted(sampleUV);

    float edgeMask = mix(0.35, 1.0, smoothstep(0.08, 0.62, length(clampedLocal - 0.5)));
    float overlayMask = clamp(abs(grain_intensity) + abs(sheen_strength), 0.0, 1.0) * edgeMask;

    vec3 lit = mix(base.rgb, glitchColor, overlayMask);
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
