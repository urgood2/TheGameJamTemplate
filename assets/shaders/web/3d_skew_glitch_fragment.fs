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

    vec2 displaced = centered + dir * progress * spread_strength;
    displaced += distortion_strength * vec2(
        sin(dist * 20.0 - time * 10.0),
        cos(dist * 20.0 - time * 8.0)
    ) * progress;

    vec2 warpedLocal = displaced + vec2(0.5);
    vec2 clampedLocal = clamp(warpedLocal, 0.0, 1.0);

    vec2 sampleUV = localToAtlas(clampedLocal);

    vec2 rotated = rotate2d(card_rotation) * (clampedLocal - 0.5);

    // Glitch / Digital distortion effect
    vec2 uv = ((sampleUV * image_details) - texture_details.xy * texture_details.ba) / texture_details.ba;

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

    // Glitch timing - creates bursts of glitches
    float burst1 = glitchTrigger(t * glitchSpeed, 1.0);
    float burst2 = glitchTrigger(t * glitchSpeed * 1.3, 2.0);
    float burst3 = glitchTrigger(t * glitchSpeed * 0.7, 3.0);
    float burstTotal = max(burst1, max(burst2, burst3));

    // Horizontal line displacement (VHS-style)
    float lineNoise = hash(floor(uv.y * 50.0 + t * 30.0));
    float lineDisplace = (lineNoise - 0.5) * 0.1 * glitchIntensity * burstTotal;

    // Block displacement
    float blockSize = 8.0 + hash(floor(t * 5.0)) * 8.0;
    float blockDisplace = (blockNoise(uv, blockSize) - 0.5) * 0.15 * glitchIntensity * burst1;

    // Vertical tear/shift
    float tearY = step(0.5, hash(floor(t * 8.0)));
    float tearAmount = (hash(floor(uv.y * 20.0 + t * 15.0)) - 0.5) * 0.2 * tearY * glitchIntensity;

    // Apply displacements in local sprite UV space to prevent atlas bleeding
    vec2 glitchLocalUV = clampedLocal;
    glitchLocalUV.x += lineDisplace + tearAmount;
    glitchLocalUV.x += blockDisplace * burst2;

    // RGB channel splitting (chromatic aberration on steroids)
    float splitAmount = 0.01 + 0.03 * glitchIntensity * burstTotal;
    splitAmount += 0.02 * sin(uv.y * 100.0 + t * 50.0) * burst1;

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
    float scanline = 0.95 + 0.05 * sin(uv.y * 400.0 + t * 10.0);
    glitchColor *= scanline;

    // Occasional color inversion in blocks
    float invertBlock = step(0.92, blockNoise(uv + t * 0.1, 12.0)) * burst1;
    glitchColor = mix(glitchColor, 1.0 - glitchColor, invertBlock);

    // Color quantization (reduce color depth for digital look)
    float quantize = 16.0 - 8.0 * burst2;
    glitchColor = floor(glitchColor * quantize) / quantize;

    // Static noise overlay
    float staticNoise = hash2(uv * 500.0 + t * 100.0);
    float staticIntensity = 0.05 + 0.15 * burstTotal * glitchIntensity;
    glitchColor = mix(glitchColor, vec3(staticNoise), staticIntensity);

    // Horizontal noise bands
    float bandY = floor(uv.y * 30.0 + t * 20.0);
    float band = step(0.9, hash(bandY)) * burstTotal;
    glitchColor = mix(glitchColor, vec3(hash(bandY + 0.5)), band * 0.5);

    // Rolling bar (like old TV interference)
    float rollSpeed = 2.0;
    float rollPos = fract(t * rollSpeed * 0.1);
    float rollBar = smoothstep(0.0, 0.02, abs(uv.y - rollPos)) *
                    smoothstep(0.0, 0.02, abs(uv.y - rollPos - 1.0));
    rollBar = 1.0 - (1.0 - rollBar) * 0.3 * step(0.7, hash(floor(t * 2.0)));
    glitchColor *= rollBar;

    // Occasional full-frame color shift
    float colorShift = hash(floor(t * 4.0));
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
