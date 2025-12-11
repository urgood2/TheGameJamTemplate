#version 300 es
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
uniform vec2  nebula;

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

// Hash function for star sparkles
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Fractal noise for nebula clouds
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

float fbm(vec2 p, float t) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;

    // Slow rotation for swirling effect
    float angle = t * 0.1;
    mat2 rot = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));

    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(p * frequency);
        p = rot * p;
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// Star field with twinkling
float stars(vec2 uv, float t) {
    vec2 gv = fract(uv * 30.0) - 0.5;
    vec2 id = floor(uv * 30.0);

    float star = 0.0;
    float rnd = hash(id);

    if (rnd > 0.85) {
        float size = (rnd - 0.85) * 6.0;
        float twinkle = 0.5 + 0.5 * sin(t * (3.0 + rnd * 5.0) + rnd * 100.0);
        star = size * twinkle * smoothstep(0.1 * size, 0.0, length(gv));
    }

    return star;
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

    if (effectInactive && (abs(nebula.x) + abs(nebula.y)) < EPS) {
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

    // Nebula cosmic effect
    vec2 uv = ((sampleUV * image_details) - texture_details.xy * texture_details.ba) / texture_details.ba;

    float t = nebula.y * 1.5 + time * 0.5;

    // Create swirling vortex center
    vec2 uvCentered = uv - 0.5;
    float radius = length(uvCentered);
    float angle = atan(uvCentered.y, uvCentered.x);

    // Spiral distortion - increases toward center
    float spiral = angle + radius * 3.0 - t * 0.5;
    vec2 spiralUV = vec2(
        cos(spiral) * radius,
        sin(spiral) * radius
    ) + 0.5;

    // Layered nebula clouds
    float cloud1 = fbm(spiralUV * 3.0 + vec2(t * 0.1, 0.0), t);
    float cloud2 = fbm(spiralUV * 5.0 - vec2(0.0, t * 0.15), t * 1.3);
    float cloud3 = fbm(spiralUV * 2.0 + vec2(t * 0.05, t * 0.08), t * 0.7);

    float nebulaDensity = cloud1 * 0.5 + cloud2 * 0.3 + cloud3 * 0.2;
    nebulaDensity = smoothstep(0.3, 0.7, nebulaDensity);

    // Nebula colors: deep purples, blues, with warm accents
    // Color zones based on position and noise
    float colorZone = fbm(uv * 2.0 + t * 0.05, t);

    // Deep purple base (hue ~0.75-0.85)
    float hueBase = 0.75 + nebula.x * 0.1;

    // Shift to blue in some areas (hue ~0.6)
    hueBase = mix(hueBase, 0.6, smoothstep(0.4, 0.6, colorZone));

    // Warm pink/magenta accents (hue ~0.9)
    float warmZone = smoothstep(0.6, 0.8, cloud2);
    hueBase = mix(hueBase, 0.92, warmZone * 0.5);

    // Orange/gold emission near bright cores (hue ~0.08)
    float coreGlow = pow(1.0 - radius, 3.0) * nebulaDensity;
    hueBase = mix(hueBase, 0.08, coreGlow * 0.4);

    // Apply to base color
    vec4 baseHSL = HSL(base);
    baseHSL.x = mod(baseHSL.x + hueBase + nebula.y * 0.03, 1.0);
    baseHSL.y = min(0.8, baseHSL.y + 0.5 * nebulaDensity);
    baseHSL.z = clamp(baseHSL.z + 0.1 * nebulaDensity + coreGlow * 0.2, 0.0, 0.85);

    vec3 nebulaColor = RGB(baseHSL).rgb;

    // Add glowing dust lanes
    float dustLane = smoothstep(0.45, 0.55, cloud1) * smoothstep(0.55, 0.45, cloud2);
    nebulaColor += vec3(0.4, 0.2, 0.5) * dustLane * 0.3;

    // Star field overlay
    float starField = stars(uv + nebula.x * 0.1, t);
    starField += stars(uv * 1.5 + 0.5, t * 1.1) * 0.7;
    nebulaColor += vec3(1.0, 0.95, 0.9) * starField;

    // Central bright core glow
    float centralGlow = pow(max(0.0, 1.0 - radius * 1.5), 4.0);
    centralGlow *= 0.5 + 0.5 * sin(t * 2.0);
    nebulaColor += vec3(0.8, 0.6, 1.0) * centralGlow * 0.4;

    float overlayMask = clamp(abs(grain_intensity) + abs(sheen_strength), 0.0, 1.0);

    vec3 lit = mix(base.rgb, nebulaColor, overlayMask);
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
