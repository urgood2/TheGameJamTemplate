#version 330 core
precision mediump float;

in vec2 fragTexCoord;
in vec4 fragColor;

uniform float iTime;
uniform vec2 resolution;

// === Configurable color uniforms (can change per scene) ===
uniform vec3 color1;          // Primary color
uniform vec3 color2;          // Secondary color  
uniform vec3 color3;          // Tertiary/dark color

// === Effect parameters ===
uniform float flow_speed;     // Speed of the flowing motion
uniform float curl_scale;     // Scale of the curl patterns
uniform float curl_intensity; // How much the curls distort
uniform float color_shift;    // Hue shift amount over time
uniform float iridescence;    // Strength of oil slick rainbow effect
uniform float contrast;       // Overall contrast
uniform float brightness;     // Overall brightness
uniform float noise_octaves;  // Detail level (1-5)
uniform float pixel_size;     // Pixelation (0 = off, >1 = pixelate)
uniform float pixel_enable;   // 1.0 = on, 0.0 = off

out vec4 finalColor;

// === Noise functions ===
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash3(vec3 p) {
    return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
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

// Fractal Brownian Motion - organic flowing patterns
float fbm(vec2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < 5; i++) {
        if (i >= octaves) break;
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// 2D Curl noise - creates divergence-free flow (no compression/expansion)
vec2 curlNoise(vec2 p, float t) {
    float eps = 0.01;
    
    // Sample noise field with time offset for animation
    float n1 = fbm(vec2(p.x, p.y + eps) + t * 0.1, 3);
    float n2 = fbm(vec2(p.x, p.y - eps) + t * 0.1, 3);
    float n3 = fbm(vec2(p.x + eps, p.y) + t * 0.1, 3);
    float n4 = fbm(vec2(p.x - eps, p.y) + t * 0.1, 3);
    
    // Curl: rotate gradient 90 degrees for divergence-free field
    return vec2(n1 - n2, n4 - n3) / (2.0 * eps);
}

// Thin-film interference - oily rainbow colors based on "thickness"
vec3 thinFilmInterference(float thickness, float viewAngle) {
    // Simulate light interference at different wavelengths
    float r = 0.5 + 0.5 * cos(thickness * 6.28318 + 0.0 + viewAngle);
    float g = 0.5 + 0.5 * cos(thickness * 6.28318 + 2.094 + viewAngle);
    float b = 0.5 + 0.5 * cos(thickness * 6.28318 + 4.188 + viewAngle);
    return vec3(r, g, b);
}

// HSV to RGB conversion
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// RGB to HSV conversion  
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void main() {
    vec2 uv = fragTexCoord;
    
    // Optional pixelation
    if (pixel_enable > 0.5 && pixel_size > 1.0) {
        vec2 screenUV = uv * resolution;
        screenUV = floor(screenUV / pixel_size) * pixel_size;
        uv = screenUV / resolution;
    }
    
    // Aspect ratio correction
    float aspect = resolution.x / resolution.y;
    vec2 scaledUV = uv;
    scaledUV.y /= aspect;
    
    float t = iTime * flow_speed;
    int octaves = int(clamp(noise_octaves, 1.0, 5.0));
    
    // === Layer 1: Base flowing noise field ===
    vec2 flowUV1 = scaledUV * curl_scale + vec2(t * 0.15, t * 0.08);
    vec2 flowUV2 = scaledUV * curl_scale * 1.7 - vec2(t * 0.12, t * 0.18);
    vec2 flowUV3 = scaledUV * curl_scale * 0.6 + vec2(sin(t * 0.1) * 0.3, cos(t * 0.08) * 0.3);
    
    float flow1 = fbm(flowUV1, octaves);
    float flow2 = fbm(flowUV2, octaves);
    float flow3 = fbm(flowUV3, octaves);
    
    // === Layer 2: Apply curl distortion for organic motion ===
    vec2 curl = curlNoise(scaledUV * curl_scale * 0.5, t);
    vec2 distortedUV = scaledUV + curl * curl_intensity * 0.1;
    
    float distortedFlow = fbm(distortedUV * curl_scale * 2.0 + t * 0.1, octaves);
    
    // === Combine flows into "oil thickness" ===
    float thickness = flow1 * 0.35 + flow2 * 0.3 + flow3 * 0.2 + distortedFlow * 0.15;
    
    // Flow-based variation (not radial!) for organic look
    float flowVariation = (flow1 - flow2) * 2.0;
    
    // === Thin-film iridescence (the oily rainbow effect) ===
    vec3 oilRainbow = thinFilmInterference(thickness * 4.0, flowVariation + t * 0.5);
    
    // === Mix the three configurable colors based on flow patterns ===
    float colorMix1 = smoothstep(0.3, 0.7, flow1);
    float colorMix2 = smoothstep(0.4, 0.6, flow2);
    
    vec3 baseColor = mix(color3, color1, colorMix1);
    baseColor = mix(baseColor, color2, colorMix2 * 0.6);
    
    // === Add iridescence on top ===
    vec3 finalCol = mix(baseColor, oilRainbow, iridescence * 0.5);
    
    // === Add subtle highlights where flows meet ===
    float highlight = pow(abs(flow1 - flow2), 2.0) * 2.0;
    finalCol += highlight * vec3(0.15);
    
    // === Apply contrast and brightness ===
    finalCol = (finalCol - 0.5) * contrast + 0.5 + brightness;
    
    // === Optional hue shift for scene variation ===
    if (abs(color_shift) > 0.001) {
        vec3 hsv = rgb2hsv(finalCol);
        hsv.x = fract(hsv.x + color_shift + t * 0.02);
        finalCol = hsv2rgb(hsv);
    }
    
    // === Subtle vignette ===
    float vignette = 1.0 - length(uv - 0.5) * 0.3;
    finalCol *= vignette;
    
    finalColor = vec4(clamp(finalCol, 0.0, 1.0), 1.0);
}
